
"""
QueryForge - Day 66
Read-only ETL Integration Audit
"""

from pathlib import Path
from datetime import datetime, timezone
from tempfile import TemporaryDirectory
import os
import shutil

import pandas as pd
import psycopg
from dotenv import load_dotenv

from day58_error_handling import (
    read_excel_safe,
    calculate_file_hash,
)

load_dotenv()

REPORT = Path("docs/day66_end_to_end_validation.md")

REQUIRED_TABLES = {
    "etl.file_upload_registry": {
        "upload_id",
        "file_name",
        "file_hash",
    },
    "etl.customer_upload_rows": {
        "upload_id",
        "customer_id",
    },
}

METRIC_QUERIES = {
    "registered_files": """
        SELECT COUNT(*)
        FROM etl.file_upload_registry
    """,

    "customer_rows": """
        SELECT COUNT(*)
        FROM etl.customer_upload_rows
    """,

    "matched_rows": """
        SELECT COUNT(*)
        FROM etl.customer_upload_rows r
        JOIN etl.file_upload_registry f
          ON f.upload_id = r.upload_id
    """,

    "orphan_rows": """
        SELECT COUNT(*)
        FROM etl.customer_upload_rows r
        LEFT JOIN etl.file_upload_registry f
          ON f.upload_id = r.upload_id
        WHERE f.upload_id IS NULL
    """,

    "duplicate_file_hashes": """
        SELECT COUNT(*)
        FROM (
            SELECT file_hash
            FROM etl.file_upload_registry
            GROUP BY file_hash
            HAVING COUNT(*) > 1
        ) AS duplicates
    """,

    "duplicate_customer_keys": """
        SELECT COUNT(*)
        FROM (
            SELECT upload_id, customer_id
            FROM etl.customer_upload_rows
            GROUP BY upload_id, customer_id
            HAVING COUNT(*) > 1
        ) AS duplicates
    """,

    "null_customer_ids": """
        SELECT COUNT(*)
        FROM etl.customer_upload_rows
        WHERE customer_id IS NULL
    """,

    "empty_uploads": """
        SELECT COUNT(*)
        FROM etl.file_upload_registry f
        WHERE NOT EXISTS (
            SELECT 1
            FROM etl.customer_upload_rows r
            WHERE r.upload_id = f.upload_id
        )
    """,
}


def create_sample_excel():
    """Test Excel handling without database writes."""

    sample = pd.DataFrame({
        "customer_id": [66001, 66002],
        "customer_name": ["Rahul", "Meera"],
        "city": ["Hyderabad", "Mumbai"],
        "email": [
            "rahul@example.com",
            "meera@example.com",
        ],
        "credit_limit": [50000, 60000],
    })

    with TemporaryDirectory() as directory:
        folder = Path(directory)

        original = folder / "day66_sample.xlsx"
        duplicate = folder / "day66_copy.xlsx"

        sample.to_excel(original, index=False)

        validated = read_excel_safe(str(original))

        if len(validated) != 2:
            raise RuntimeError(
                "Sample Excel validation failed."
            )

        shutil.copyfile(original, duplicate)

        hash_1 = calculate_file_hash(str(original))
        hash_2 = calculate_file_hash(str(duplicate))

        if hash_1 != hash_2:
            raise RuntimeError(
                "Duplicate file hashing failed."
            )

    return 2


def assess_metrics(metrics):
    """Classify database integrity results."""

    problems = []

    checks = {
        "orphan_rows": "Orphan customer rows found",
        "duplicate_file_hashes": "Duplicate file hashes",
        "duplicate_customer_keys": "Duplicate customer keys",
        "null_customer_ids": "NULL customer IDs",
    }

    for key, message in checks.items():
        if metrics[key] > 0:
            problems.append(message)

    if (
        metrics["registered_files"] == 0
        and metrics["customer_rows"] > 0
    ):
        problems.append(
            "Customer rows exist without registered files"
        )

    if (
        metrics["matched_rows"]
        + metrics["orphan_rows"]
        != metrics["customer_rows"]
    ):
        problems.append(
            "Customer row reconciliation mismatch"
        )

    if problems:
        return "FAIL", problems

    if (
        metrics["registered_files"] == 0
        and metrics["customer_rows"] == 0
    ):
        return "NO DATA", [
            "No actual Excel uploads exist yet."
        ]

    if metrics["customer_rows"] == 0:
        return "WARNING", [
            "Registered files exist but no customer rows."
        ]

    if metrics["empty_uploads"] > 0:
        return "WARNING", [
            "Some registered uploads have no customer rows."
        ]

    return "PASS", []


def check_database():
    """Read live PostgreSQL data without modifying it."""

    expected_database = os.getenv(
        "DB_NAME", "queryforge_dev"
    )

    parameters = {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": os.getenv("DB_PORT", "5432"),
        "dbname": expected_database,
        "user": os.getenv("DB_USER", "postgres"),
        "password": os.getenv("DB_PASSWORD"),
        "options": "-c default_transaction_read_only=on",
    }

    with psycopg.connect(**parameters) as conn:
        with conn.cursor() as cur:

            cur.execute("""
                SELECT
                    current_database(),
                    current_setting(
                        'transaction_read_only'
                    )
            """)

            database_name, read_only = cur.fetchone()

            if database_name != expected_database:
                raise RuntimeError(
                    "Incorrect database connection."
                )

            if read_only != "on":
                raise RuntimeError(
                    "Database is not in read-only mode."
                )

            for table, required in REQUIRED_TABLES.items():

                cur.execute(
                    "SELECT to_regclass(%s)",
                    (table,),
                )

                if cur.fetchone()[0] is None:
                    raise RuntimeError(
                        f"Required table missing: {table}"
                    )

                schema, name = table.split(".", 1)

                cur.execute("""
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_schema = %s
                      AND table_name = %s
                """, (schema, name))

                columns = {
                    row[0] for row in cur.fetchall()
                }

                missing = required - columns

                if missing:
                    raise RuntimeError(
                        f"Missing columns in {table}: "
                        f"{sorted(missing)}"
                    )

            metrics = {}

            for name, query in METRIC_QUERIES.items():
                cur.execute(query)
                metrics[name] = int(cur.fetchone()[0])

    return database_name, metrics


def save_report(database_name, metrics, status, messages):
    """Save aggregate results only."""

    REPORT.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    timestamp = datetime.now(
        timezone.utc
    ).strftime("%Y-%m-%d %H:%M:%S UTC")

    lines = [
        "# QueryForge Day 66 - ETL Integration Audit",
        "",
        f"Generated: {timestamp}",
        "",
        f"Database: {database_name}",
        "",
        f"## Status: {status}",
        "",
        "## Excel validation",
        "",
        "- Synthetic Excel validation: PASS",
        "- Identical-file SHA256 comparison: PASS",
        "- Sample rows validated: 2",
        "",
        "## Database reconciliation",
        "",
        "| Metric | Count |",
        "|---|---:|",
    ]

    for name, value in metrics.items():
        lines.append(f"| {name} | {value} |")

    lines.extend([
        "",
        "## Findings",
        "",
    ])

    if messages:
        for message in messages:
            lines.append(f"- {message}")
    else:
        lines.append("- No integrity issues detected.")

    lines.extend([
        "",
        "## Safety",
        "",
        "Database access was read-only.",
        "Synthetic Excel was temporary.",
        "No upload records were committed.",
        "Existing Day 62 tests cover rollback behavior.",
        "",
    ])

    REPORT.write_text(
        "\n".join(lines),
        encoding="utf-8",
    )


def main():
    print("===== DAY 66 ETL VALIDATION =====")

    try:
        sample_rows = create_sample_excel()

        print(
            f"PASS: Sample Excel rows = {sample_rows}"
        )
        print("PASS: File hash comparison")

        database_name, metrics = check_database()

        print(f"Database: {database_name}")

        for key, value in metrics.items():
            print(f"{key}: {value}")

        status, messages = assess_metrics(metrics)

        print(f"DAY 66 STATUS: {status}")

        for message in messages:
            print(f"NOTICE: {message}")

        save_report(
            database_name,
            metrics,
            status,
            messages,
        )

        print(f"Report saved: {REPORT}")

        return 2 if status == "FAIL" else 0

    except Exception as exc:
        print(f"DAY 66 FAILED: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
