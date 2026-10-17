
"""
QueryForge - Day 64
ETL Data Reconciliation and Integrity Audit

READ-ONLY DATABASE AUDIT.
No INSERT, UPDATE, DELETE, DROP or CREATE.
"""

from __future__ import annotations

import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import psycopg
from dotenv import load_dotenv


ROOT = Path(__file__).resolve().parents[2]
REPORT_PATH = ROOT / "docs" / "day64_etl_reconciliation.md"

load_dotenv(ROOT / ".env")


# All database audit queries are SELECT only.

QUERIES = {
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
        ) duplicates
    """,

    "duplicate_customer_keys": """
        SELECT COUNT(*)
        FROM (
            SELECT upload_id, customer_id
            FROM etl.customer_upload_rows
            GROUP BY upload_id, customer_id
            HAVING COUNT(*) > 1
        ) duplicates
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


RECENT_UPLOADS_QUERY = """
    SELECT
        f.upload_id,
        f.file_name,
        COUNT(r.upload_id) AS customer_rows
    FROM etl.file_upload_registry f
    LEFT JOIN etl.customer_upload_rows r
      ON r.upload_id = f.upload_id
    GROUP BY f.upload_id, f.file_name
    ORDER BY f.upload_id DESC
    LIMIT 20
"""


def assess(metrics):
    """
    Return audit status, failures and warnings.
    Does not connect to the database.
    """

    missing = set(QUERIES) - set(metrics)

    if missing:
        raise ValueError(
            f"Missing audit metrics: {sorted(missing)}"
        )

    for name in QUERIES:
        value = metrics[name]

        if not isinstance(value, int) or value < 0:
            raise ValueError(
                f"Invalid metric {name}: {value}"
            )

    failures = []
    warnings = []

    checks = {
        "orphan_rows": "Orphan customer rows detected",
        "duplicate_file_hashes": "Duplicate file hashes detected",
        "duplicate_customer_keys": "Duplicate customer IDs within an upload",
        "null_customer_ids": "NULL customer IDs detected",
    }

    for key, message in checks.items():
        if metrics[key] > 0:
            failures.append(
                f"{message}: {metrics[key]}"
            )

    if (
        metrics["matched_rows"] + metrics["orphan_rows"]
        != metrics["customer_rows"]
    ):
        failures.append(
            "Customer row reconciliation mismatch"
        )

    if metrics["empty_uploads"] > 0:
        warnings.append(
            f"Uploads without customer rows: "
            f"{metrics['empty_uploads']}"
        )

    if (
        metrics["registered_files"] == 0
        and metrics["customer_rows"] == 0
    ):
        warnings.append(
            "No upload data exists yet."
        )

    if failures:
        status = "FAIL"
    elif (
        metrics["registered_files"] == 0
        and metrics["customer_rows"] == 0
    ):
        status = "NO DATA"
    else:
        status = "PASS"

    return status, failures, warnings


def connect_db():
    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "queryforge_dev"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
        autocommit=True,
    )


def collect_metrics():
    """
    Read PostgreSQL inside a read-only transaction.
    """

    metrics = {}
    recent_uploads = []

    with connect_db() as conn:
        with conn.transaction():
            with conn.cursor() as cur:

                # Must run before the first SELECT.
                cur.execute(
                    "SET TRANSACTION READ ONLY"
                )

                cur.execute(
                    """
                    SELECT
                        TO_REGCLASS(
                            'etl.file_upload_registry'
                        ),
                        TO_REGCLASS(
                            'etl.customer_upload_rows'
                        )
                    """
                )

                registry, rows_table = cur.fetchone()

                if registry is None or rows_table is None:
                    raise RuntimeError(
                        "Required ETL tables are missing. "
                        "Verify Day 61 and Day 62."
                    )

                for name, query in QUERIES.items():
                    cur.execute(query)
                    metrics[name] = int(
                        cur.fetchone()[0]
                    )

                cur.execute(RECENT_UPLOADS_QUERY)
                recent_uploads = cur.fetchall()

    return metrics, recent_uploads


def markdown_cell(value):
    return (
        str(value)
        .replace("|", "\\|")
        .replace("\r", " ")
        .replace("\n", " ")
    )


def render_report(
    metrics,
    recent_uploads,
    status,
    failures,
    warnings,
):
    """
    Generate a readable Markdown audit report.
    """

    timestamp = datetime.now(
        timezone.utc
    ).strftime("%Y-%m-%d %H:%M:%S UTC")

    lines = [
        "# QueryForge Day 64 - ETL Reconciliation",
        "",
        f"Generated: {timestamp}",
        "",
        f"## Overall status: {status}",
        "",
        "## Audit metrics",
        "",
        "| Metric | Count |",
        "|---|---:|",
    ]

    for name in QUERIES:
        lines.append(
            f"| {name} | {metrics[name]} |"
        )

    lines.extend([
        "",
        "## Failures",
        "",
    ])

    if failures:
        for message in failures:
            lines.append(f"- {message}")
    else:
        lines.append("- None")

    lines.extend([
        "",
        "## Warnings",
        "",
    ])

    if warnings:
        for message in warnings:
            lines.append(f"- {message}")
    else:
        lines.append("- None")

    lines.extend([
        "",
        "## Latest 20 uploads",
        "",
        "| Upload ID | File name | Customer rows |",
        "|---:|---|---:|",
    ])

    if recent_uploads:
        for upload_id, file_name, row_count in recent_uploads:
            lines.append(
                f"| {upload_id} | "
                f"{markdown_cell(file_name)} | "
                f"{row_count} |"
            )
    else:
        lines.append(
            "| - | No registered uploads | 0 |"
        )

    lines.extend([
        "",
        "## Safety",
        "",
        "Database audit executed using a "
        "read-only transaction.",
        "",
    ])

    return "\n".join(lines)


def main():
    print("===== QUERYFORGE DAY 64 =====")
    print("===== READ-ONLY ETL AUDIT =====")

    try:
        metrics, recent_uploads = collect_metrics()

        status, failures, warnings = assess(metrics)

        for name, count in metrics.items():
            print(f"{name}: {count}")

        print(f"\nAUDIT STATUS: {status}")

        for message in failures:
            print(f"FAIL: {message}")

        for message in warnings:
            print(f"WARN: {message}")

        report = render_report(
            metrics,
            recent_uploads,
            status,
            failures,
            warnings,
        )

        REPORT_PATH.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        REPORT_PATH.write_text(
            report,
            encoding="utf-8",
        )

        print(f"Report saved: {REPORT_PATH}")

        if status == "FAIL":
            return 1

        return 0

    except (psycopg.Error, RuntimeError, ValueError, OSError) as exc:
        print(
            f"DAY 64 ERROR: {exc}",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
