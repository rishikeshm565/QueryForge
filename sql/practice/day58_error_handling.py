from pathlib import Path
import hashlib
import os
import re

import pandas as pd
import psycopg
from dotenv import load_dotenv


load_dotenv()


REQUIRED_COLUMNS = {
    "customer_id",
    "customer_name",
    "city",
    "email",
    "credit_limit",
}

EMAIL_PATTERN = re.compile(
    r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"
)


class UploadValidationError(Exception):
    pass


def validate_dataframe(df: pd.DataFrame) -> None:

    missing = REQUIRED_COLUMNS - set(df.columns)

    if missing:
        raise UploadValidationError(
            f"Missing required columns: {sorted(missing)}"
        )

    if df["customer_id"].duplicated().any():
        raise UploadValidationError(
            "Duplicate customer_id detected."
        )

    invalid_email = ~df["email"].astype(str).str.match(
        EMAIL_PATTERN
    )

    if invalid_email.any():
        raise UploadValidationError(
            "Invalid email detected."
        )

    credit = pd.to_numeric(
        df["credit_limit"],
        errors="coerce",
    )

    if credit.isna().any():
        raise UploadValidationError(
            "Non-numeric credit_limit detected."
        )

    if (credit < 0).any():
        raise UploadValidationError(
            "Negative credit_limit detected."
        )


def read_excel_safe(path: str) -> pd.DataFrame:

    file_path = Path(path)

    if not file_path.exists():
        raise UploadValidationError(
            f"File does not exist: {file_path}"
        )

    if file_path.suffix.lower() != ".xlsx":
        raise UploadValidationError(
            "Only .xlsx files are allowed."
        )

    try:
        df = pd.read_excel(file_path)

    except Exception as exc:
        raise UploadValidationError(
            f"Excel file could not be read: {exc}"
        ) from exc

    validate_dataframe(df)

    return df


def calculate_file_hash(path: str) -> str:

    sha256 = hashlib.sha256()

    with open(path, "rb") as file:
        while chunk := file.read(8192):
            sha256.update(chunk)

    return sha256.hexdigest()


def connect_db():

    try:
        return psycopg.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5432"),
            dbname=os.getenv(
                "DB_NAME",
                "queryforge_dev",
            ),
            user=os.getenv(
                "DB_USER",
                "postgres",
            ),
            password=os.getenv("DB_PASSWORD"),
        )

    except psycopg.Error as exc:
        raise RuntimeError(
            f"Database connection failed: {exc}"
        ) from exc


def create_upload_registry(conn):

    with conn.cursor() as cur:

        cur.execute(
            """
            CREATE SCHEMA IF NOT EXISTS etl;

            CREATE TABLE IF NOT EXISTS
            etl.file_upload_registry
            (
                upload_id BIGINT
                    GENERATED ALWAYS AS IDENTITY
                    PRIMARY KEY,

                file_name TEXT NOT NULL,

                file_hash TEXT NOT NULL UNIQUE,

                uploaded_at TIMESTAMPTZ
                    NOT NULL
                    DEFAULT NOW()
            );
            """
        )

    conn.commit()


def register_file(conn, path: str):

    file_hash = calculate_file_hash(path)

    try:

        with conn.cursor() as cur:

            cur.execute(
                """
                INSERT INTO etl.file_upload_registry
                (
                    file_name,
                    file_hash
                )
                VALUES (%s, %s);
                """,
                (
                    Path(path).name,
                    file_hash,
                ),
            )

        conn.commit()

    except psycopg.errors.UniqueViolation:

        conn.rollback()

        raise UploadValidationError(
            "Duplicate file upload detected."
        )


def process_upload(path: str):

    try:

        df = read_excel_safe(path)

        print(
            f"Validation passed: {len(df)} rows"
        )

        with connect_db() as conn:

            create_upload_registry(conn)

            register_file(
                conn,
                path,
            )

        print("Upload accepted successfully.")

    except UploadValidationError as exc:
        print(f"VALIDATION ERROR: {exc}")

    except RuntimeError as exc:
        print(f"DATABASE ERROR: {exc}")

    except Exception as exc:
        print(f"UNEXPECTED ERROR: {exc}")


if __name__ == "__main__":

    import sys

    if len(sys.argv) != 2:

        print(
            "Usage: python "
            "src/day58_error_handling.py "
            "<excel-file>"
        )

        raise SystemExit(1)

    process_upload(sys.argv[1])