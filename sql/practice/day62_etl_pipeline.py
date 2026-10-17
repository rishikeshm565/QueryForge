
"""
QueryForge Day 62
Transactional Excel -> PostgreSQL ETL Pipeline

Only inserts into:
    etl.file_upload_registry
    etl.customer_upload_rows

CLI uploads commit atomically.
Automated tests use outer transactions and rollback.
"""

import argparse
import hashlib
import os
import sys

from decimal import Decimal, InvalidOperation
from io import BytesIO
from pathlib import Path

import pandas as pd
import psycopg

from dotenv import load_dotenv

from day58_error_handling import (
    UploadValidationError,
    validate_dataframe,
)


# ============================================================
# 1. CONFIGURATION
# ============================================================

load_dotenv(
    Path(__file__).resolve().parents[2] / ".env"
)

MAX_FILE_BYTES = 5 * 1024 * 1024
MAX_ROWS = 5000

MAX_CREDIT = Decimal("9999999999.99")


INSERT_ROW_SQL = """
INSERT INTO etl.customer_upload_rows
    (
        upload_id,
        customer_id,
        customer_name,
        city,
        email,
        credit_limit
    )
VALUES (%s, %s, %s, %s, %s, %s)
"""


# ============================================================
# 2. CUSTOM EXCEPTIONS
# ============================================================

class DuplicateUploadError(Exception):
    pass


class PipelineConfigurationError(Exception):
    pass


# ============================================================
# 3. DATABASE CONFIGURATION
# ============================================================

def database_settings():

    return {
        "host": os.getenv("DB_HOST", "localhost"),

        "port": os.getenv("DB_PORT", "5432"),

        "dbname": os.getenv(
            "DB_NAME",
            "queryforge_dev"
        ),

        "user": os.getenv(
            "DB_USER",
            "postgres"
        ),

        "password": os.getenv("DB_PASSWORD"),
    }


# ============================================================
# 4. READ AND VALIDATE EXCEL
# ============================================================

def load_excel(file_path):

    path = Path(file_path)

    if not path.is_file():
        raise UploadValidationError(
            f"Excel file not found: {path}"
        )

    if path.suffix.lower() != ".xlsx":
        raise UploadValidationError(
            "Only .xlsx files are supported"
        )

    if path.stat().st_size > MAX_FILE_BYTES:
        raise UploadValidationError(
            "Excel file exceeds 5 MB"
        )

    # Read bytes once so hash and parsed content match.
    data = path.read_bytes()

    if len(data) > MAX_FILE_BYTES:
        raise UploadValidationError(
            "Excel file exceeds 5 MB"
        )

    digest = hashlib.sha256(data).hexdigest()

    try:
        df = pd.read_excel(
            BytesIO(data),
            engine="openpyxl"
        )

    except Exception as exc:
        raise UploadValidationError(
            f"Could not read Excel: {exc}"
        ) from exc

    df.columns = [
        str(col).strip()
        for col in df.columns
    ]

    if df.columns.duplicated().any():
        raise UploadValidationError(
            "Duplicate column headings detected"
        )

    if df.empty or len(df) > MAX_ROWS:
        raise UploadValidationError(
            "Excel must contain 1 to 5000 data rows"
        )

    # Reuse Day 58 business validation.
    validate_dataframe(df)

    rows = []
    seen_ids = set()

    for number, item in enumerate(
        df.to_dict("records"),
        start=2
    ):

        try:
            raw_id = item["customer_id"]

            if isinstance(raw_id, bool):
                raise ValueError(
                    "boolean is not a customer ID"
                )

            dec_id = Decimal(str(raw_id))

            if (
                not dec_id.is_finite()
                or dec_id != dec_id.to_integral_value()
            ):
                raise ValueError(
                    "customer ID must be an integer"
                )

            customer_id = int(dec_id)

            if not 1 <= customer_id <= 9223372036854775807:
                raise ValueError(
                    "customer ID outside BIGINT range"
                )

            credit = Decimal(
                str(item["credit_limit"])
            )

            if (
                not credit.is_finite()
                or not 0 <= credit <= MAX_CREDIT
            ):
                raise ValueError(
                    "credit limit outside NUMERIC(12,2) range"
                )

            if credit != credit.quantize(
                Decimal("0.01")
            ):
                raise ValueError(
                    "credit limit exceeds two decimal places"
                )

        except (
            InvalidOperation,
            ValueError,
            TypeError,
            KeyError
        ) as exc:

            raise UploadValidationError(
                f"Invalid numeric value at Excel row "
                f"{number}: {exc}"
            ) from exc

        if customer_id in seen_ids:
            raise UploadValidationError(
                f"Duplicate customer ID at Excel row {number}"
            )

        seen_ids.add(customer_id)

        values = []

        for column in (
            "customer_name",
            "city",
            "email"
        ):

            value = item[column]

            if (
                not isinstance(value, str)
                or not value.strip()
            ):
                raise UploadValidationError(
                    f"Invalid {column} at Excel row {number}"
                )

            values.append(value.strip())

        rows.append(
            (
                customer_id,
                *values,
                credit
            )
        )

    return path.name, digest, rows


# ============================================================
# 5. CHECK CORRECT DATABASE
# ============================================================

def check_database(conn):

    with conn.cursor() as cur:

        cur.execute("""
            SELECT
                current_database(),

                to_regclass(
                    'etl.file_upload_registry'
                ),

                to_regclass(
                    'etl.customer_upload_rows'
                )
        """)

        db_name, registry, row_table = cur.fetchone()

    if db_name != "queryforge_dev":
        raise PipelineConfigurationError(
            f"STOP: connected to {db_name}"
        )

    if registry is None or row_table is None:
        raise PipelineConfigurationError(
            "Run Day 61 and Day 62 setup SQL first"
        )


# ============================================================
# 6. TRANSACTIONAL EXCEL UPLOAD
# ============================================================

def ingest_excel(conn, file_path):

    # Validate before database insert.
    file_name, file_hash, rows = load_excel(
        file_path
    )

    # Inside an existing transaction, psycopg uses
    # a SAVEPOINT. Otherwise this is a transaction.
    with conn.transaction():

        check_database(conn)

        with conn.cursor() as cur:

            # Register file only if hash is new.
            cur.execute("""
                INSERT INTO etl.file_upload_registry
                    (
                        file_name,
                        file_hash
                    )
                VALUES (%s, %s)

                ON CONFLICT (file_hash)
                DO NOTHING

                RETURNING upload_id
            """, (file_name, file_hash))

            row = cur.fetchone()

            if row is None:
                raise DuplicateUploadError(
                    "This exact Excel file was already uploaded"
                )

            upload_id = row[0]

            # Insert all validated customer records.
            cur.executemany(
                INSERT_ROW_SQL,
                [
                    (upload_id, *entry)
                    for entry in rows
                ]
            )

            # Verify inserted row count.
            cur.execute("""
                SELECT COUNT(*)
                FROM etl.customer_upload_rows
                WHERE upload_id = %s
            """, (upload_id,))

            inserted_count = cur.fetchone()[0]

            if inserted_count != len(rows):
                raise RuntimeError(
                    "Inserted row count mismatch; "
                    "transaction rolled back"
                )

    return upload_id, len(rows), file_hash


# ============================================================
# 7. COMMAND-LINE WORKFLOW
# ============================================================

def main(argv=None):

    parser = argparse.ArgumentParser(
        description=(
            "Day 62 Excel to PostgreSQL ETL"
        )
    )

    parser.add_argument(
        "excel_file",
        help="Path to a .xlsx workbook"
    )

    args = parser.parse_args(argv)

    try:

        with psycopg.connect(
            **database_settings()
        ) as conn:

            upload_id, count, digest = ingest_excel(
                conn,
                args.excel_file
            )

    except (
        UploadValidationError,
        DuplicateUploadError,
        PipelineConfigurationError
    ) as exc:

        print(
            f"UPLOAD REJECTED: {exc}",
            file=sys.stderr
        )

        return 2

    except (
        psycopg.Error,
        RuntimeError
    ) as exc:

        print(
            f"UPLOAD FAILED: {exc}",
            file=sys.stderr
        )

        return 1

    print(
        f"UPLOAD ACCEPTED: "
        f"upload_id={upload_id}, "
        f"rows={count}, "
        f"sha256={digest}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
