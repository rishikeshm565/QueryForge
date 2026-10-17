
"""
QueryForge Day 58: validate Excel and register its SHA256 file hash.
Customer rows are NOT inserted into the database.
"""

import argparse
import hashlib
import math
import os
import re
from pathlib import Path

import pandas as pd
import psycopg
from dotenv import load_dotenv

load_dotenv()

REQUIRED_COLUMNS = {
    "customer_id", "customer_name", "city", "email", "credit_limit"
}
EMAIL_PATTERN = re.compile(
    r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"
)


class UploadValidationError(ValueError):
    """Invalid Excel data or duplicate file."""


class DatabaseOperationError(RuntimeError):
    """Unable to establish a PostgreSQL connection."""


# ====================================================
# 1. VALIDATE EXCEL DATA
# ====================================================

def validate_dataframe(df: pd.DataFrame) -> None:
    missing = REQUIRED_COLUMNS - set(df.columns)
    if missing:
        raise UploadValidationError(f"Missing required columns: {sorted(missing)}")
    if df.empty:
        raise UploadValidationError("Excel file has no data rows.")

    for column in ("customer_name", "city", "email"):
        values = df[column].astype("string").str.strip()
        if values.isna().any() or values.eq("").fillna(True).any():
            raise UploadValidationError(f"Blank {column} detected.")

    ids = pd.to_numeric(df["customer_id"], errors="coerce")
    if (ids.isna().any() or not ids.map(math.isfinite).all()
            or (ids <= 0).any() or (ids % 1 != 0).any()):
        raise UploadValidationError("customer_id must be a positive whole number.")
    if ids.duplicated().any():
        raise UploadValidationError("Duplicate customer_id detected.")

    emails = df["email"].astype("string").str.strip()
    if not emails.str.fullmatch(EMAIL_PATTERN, na=False).all():
        raise UploadValidationError("Invalid email detected.")

    credit = pd.to_numeric(df["credit_limit"], errors="coerce")
    if (credit.isna().any() or not credit.map(math.isfinite).all()
            or (credit < 0).any()):
        raise UploadValidationError("Invalid credit_limit: must be finite and non-negative.")


# ====================================================
# 2. READ EXCEL SAFELY
# ====================================================

def read_excel_safe(path: str) -> pd.DataFrame:
    file_path = Path(path)
    if not file_path.is_file():
        raise UploadValidationError(f"File does not exist: {file_path}")
    if file_path.suffix.lower() != ".xlsx":
        raise UploadValidationError("Only .xlsx files are allowed.")
    try:
        df = pd.read_excel(file_path, engine="openpyxl")
    except Exception as exc:
        raise UploadValidationError(f"Excel file could not be read: {exc}") from exc
    validate_dataframe(df)
    return df


# ====================================================
# 3. CALCULATE SHA256 HASH
# ====================================================

def calculate_file_hash(path: str) -> str:
    digest = hashlib.sha256()
    try:
        with open(path, "rb") as source:
            for chunk in iter(lambda: source.read(8192), b""):
                digest.update(chunk)
    except OSError as exc:
        raise UploadValidationError(f"Cannot hash file: {exc}") from exc
    return digest.hexdigest()


# ====================================================
# 4. DATABASE CONNECTION
# ====================================================

def connect_db():
    try:
        return psycopg.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5432"),
            dbname=os.getenv("DB_NAME", "queryforge_dev"),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD"),
            connect_timeout=10,
        )
    except psycopg.Error as exc:
        raise DatabaseOperationError(
            "Database connection failed. Check the DB_* environment settings."
        ) from exc


# ====================================================
# 5. CREATE FILE UPLOAD REGISTRY
# ====================================================

def create_upload_registry(conn) -> None:
    with conn.cursor() as cur:
        cur.execute("CREATE SCHEMA IF NOT EXISTS etl;")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS etl.file_upload_registry (
                upload_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                file_name TEXT NOT NULL,
                file_hash TEXT NOT NULL UNIQUE,
                uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
        """)
    # Do not commit here: connection context handles commit/rollback.


# ====================================================
# 6. REGISTER FILE
# ====================================================

def register_file(conn, path: str, file_hash: str) -> int:
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO etl.file_upload_registry (file_name, file_hash)
            VALUES (%s, %s)
            ON CONFLICT (file_hash) DO NOTHING
            RETURNING upload_id;
        """, (Path(path).name, file_hash))
        row = cur.fetchone()
    if row is None:
        raise UploadValidationError("Duplicate file upload detected.")
    return int(row[0])


# ====================================================
# 7. MAIN UPLOAD PROCESS
# ====================================================

def process_upload(path: str) -> int:
    try:
        before = calculate_file_hash(path)
        df = read_excel_safe(path)
        after = calculate_file_hash(path)
        if before != after:
            raise UploadValidationError("Excel file changed during validation.")
        print(f"Validation passed: {len(df)} rows")

        # psycopg connection context commits on success or rolls back on error.
        with connect_db() as conn:
            create_upload_registry(conn)
            upload_id = register_file(conn, path, after)
        print(f"File registered successfully. Upload ID: {upload_id}")
        return 0
    except UploadValidationError as exc:
        print(f"VALIDATION ERROR: {exc}")
        return 2
    except (DatabaseOperationError, psycopg.Error) as exc:
        print(f"DATABASE ERROR: {exc}")
        return 3
    except Exception as exc:
        print(f"UNEXPECTED ERROR: {type(exc).__name__}: {exc}")
        return 4


# ====================================================
# 8. COMMAND LINE ENTRY
# ====================================================

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate a .xlsx file and register its SHA256 hash."
    )
    parser.add_argument("excel_file", help="Path to .xlsx Excel file")
    args = parser.parse_args()
    return process_upload(args.excel_file)


if __name__ == "__main__":
    raise SystemExit(main())
