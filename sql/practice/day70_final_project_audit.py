
"""QueryForge Day 70: read-only final milestone audit."""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
import os

import psycopg
from psycopg import sql
from dotenv import load_dotenv


load_dotenv()

EXPECTED_DB = "queryforge_dev"

REPORT_PATH = (
    Path(__file__).resolve().parents[2]
    / "docs/day70_final_project_audit.md"
)

# Fixed trusted relation names.
TABLE_KINDS = {
    "core.customer_master": "r",
    "staging.customer_upload": "r",
    "dq.customer_quarantine": "r",
    "audit.customer_change_log": "r",
    "scale.customers_big": "r",
    "scale.orders_big": "r",
    "scale.payments_big": "r",
    "scale.orders_partitioned": "p",
    "analytics.mv_monthly_order_summary": "m",
    "etl.file_upload_registry": "r",
    "etl.customer_upload_rows": "r",
}

MUST_HAVE_ROWS = {
    "scale.customers_big",
    "scale.orders_big",
    "scale.payments_big",
    "scale.orders_partitioned",
    "analytics.mv_monthly_order_summary",
}

EXPECTED_PARTITIONS = {
    "orders_2024",
    "orders_2025",
    "orders_2026",
    "orders_default",
}


def check_counts(counts: dict[str, int]) -> list[str]:

    failures = []

    for name in TABLE_KINDS:

        if name not in counts:
            failures.append(
                f"Missing relation: {name}"
            )

        elif counts[name] < 0:
            failures.append(
                f"Invalid count for {name}"
            )

        elif (
            name in MUST_HAVE_ROWS
            and counts[name] == 0
        ):
            failures.append(
                f"Unexpected empty training relation: {name}"
            )

    return failures


def check_partition_names(
    names: set[str],
) -> list[str]:

    if names != EXPECTED_PARTITIONS:

        return [
            "Partition mismatch: "
            f"expected {sorted(EXPECTED_PARTITIONS)}, "
            f"got {sorted(names)}"
        ]

    return []


def check_summary(
    source_rows: int,
    view_rows: int,
    source_amount: Decimal,
    view_amount: Decimal,
) -> list[str]:

    if (
        source_rows != view_rows
        or source_amount != view_amount
    ):

        return [
            "Materialized view out of sync with source "
            f"(rows {source_rows}/{view_rows}, "
            f"amount {source_amount}/{view_amount})"
        ]

    return []


def report_status(
    failures: list[str],
    warnings: list[str],
) -> str:

    if failures:
        return "FAIL"

    if warnings:
        return "PASS WITH WARNINGS"

    return "PASS"


def collect_audit(conn) -> dict:

    counts = {}
    failures = []
    warnings = []

    partition_names = set()
    partition_key = None
    summary = None
    index_valid = False

    with conn.cursor() as cur:

        cur.execute(
            "BEGIN TRANSACTION READ ONLY"
        )

        try:

            cur.execute(
                "SET LOCAL statement_timeout = '60s'"
            )

            cur.execute(
                "SHOW transaction_read_only"
            )

            if cur.fetchone()[0] != "on":
                raise RuntimeError(
                    "Transaction is not read-only"
                )

            cur.execute(
                "SELECT current_database()"
            )

            database = cur.fetchone()[0]

            if database != EXPECTED_DB:
                raise RuntimeError(
                    f"Unexpected database: {database}"
                )

            # Check all project relations.

            for name, required_kind in TABLE_KINDS.items():

                cur.execute(
                    "SELECT c.relkind "
                    "FROM pg_class c "
                    "WHERE c.oid = to_regclass(%s)",
                    (name,),
                )

                item = cur.fetchone()

                if item is None:
                    failures.append(
                        f"Missing relation: {name}"
                    )
                    continue

                if item[0] != required_kind:
                    failures.append(
                        f"Unexpected relation kind "
                        f"for {name}: {item[0]}"
                    )
                    continue

                schema, table = name.split(".", 1)

                query = sql.SQL(
                    "SELECT COUNT(*) FROM {}"
                ).format(
                    sql.Identifier(schema, table)
                )

                cur.execute(query)

                counts[name] = cur.fetchone()[0]

            for issue in check_counts(counts):

                if issue not in failures:
                    failures.append(issue)

            # Verify partition key and child tables.

            if "scale.orders_partitioned" in counts:

                cur.execute(
                    "SELECT pg_get_partkeydef("
                    "to_regclass(%s))",
                    ("scale.orders_partitioned",),
                )

                partition_key = cur.fetchone()[0]

                if partition_key != "RANGE (order_date)":
                    failures.append(
                        f"Unexpected partition key: "
                        f"{partition_key}"
                    )

                cur.execute(
                    "SELECT child.relname "
                    "FROM pg_inherits i "
                    "JOIN pg_class child "
                    "ON child.oid = i.inhrelid "
                    "WHERE i.inhparent = to_regclass(%s)",
                    ("scale.orders_partitioned",),
                )

                partition_names = {
                    row[0]
                    for row in cur.fetchall()
                }

                failures.extend(
                    check_partition_names(partition_names)
                )

            # Verify materialized view and index.

            if (
                "analytics.mv_monthly_order_summary"
                in counts
            ):

                cur.execute(
                    "SELECT ispopulated "
                    "FROM pg_matviews "
                    "WHERE schemaname = 'analytics' "
                    "AND matviewname = "
                    "'mv_monthly_order_summary'"
                )

                populated = cur.fetchone()

                if (
                    populated is None
                    or not populated[0]
                ):
                    failures.append(
                        "Materialized view is not populated"
                    )

                cur.execute(
                    """
                    SELECT EXISTS (
                        SELECT 1
                        FROM pg_index i
                        WHERE i.indrelid = to_regclass(%s)
                          AND i.indisunique
                          AND i.indisvalid
                          AND i.indisready
                          AND i.indnkeyatts = 2
                          AND pg_get_indexdef(
                              i.indexrelid, 1, TRUE
                          ) = 'month'
                          AND pg_get_indexdef(
                              i.indexrelid, 2, TRUE
                          ) = 'status'
                    )
                    """,
                    (
                        "analytics.mv_monthly_order_summary",
                    ),
                )

                index_valid = cur.fetchone()[0]

                if not index_valid:
                    failures.append(
                        "Unique valid materialized-view "
                        "index missing"
                    )

            # Reconcile source and summary.

            if (
                "scale.orders_partitioned" in counts
                and "analytics.mv_monthly_order_summary"
                in counts
            ):

                cur.execute(
                    """
                    SELECT
                        (
                            SELECT COUNT(*)
                            FROM scale.orders_partitioned
                        ),
                        (
                            SELECT COALESCE(
                                SUM(total_orders), 0
                            )
                            FROM analytics.mv_monthly_order_summary
                        ),
                        (
                            SELECT COALESCE(
                                SUM(amount), 0
                            )
                            FROM scale.orders_partitioned
                        ),
                        (
                            SELECT COALESCE(
                                SUM(total_amount), 0
                            )
                            FROM analytics.mv_monthly_order_summary
                        )
                    """
                )

                summary = cur.fetchone()

                failures.extend(
                    check_summary(*summary)
                )

            # Upload absence is a warning, not a pass
            # for production ingestion.

            if (
                counts.get("etl.file_upload_registry") == 0
                and counts.get("etl.customer_upload_rows") == 0
            ):

                warnings.append(
                    "No real ETL uploads: "
                    "production-source ingestion is unverified"
                )

        finally:

            cur.execute("ROLLBACK")

    return {
        "database": database,
        "counts": counts,
        "partition_key": partition_key,
        "partitions": sorted(partition_names),
        "unique_mv_index": index_valid,
        "summary": summary,
        "failures": failures,
        "warnings": warnings,
        "status": report_status(
            failures,
            warnings,
        ),
    }


def write_report(result: dict) -> Path:

    REPORT_PATH.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    date_string = datetime.now(
        timezone.utc
    ).strftime("%Y-%m-%d %H:%M:%S UTC")

    lines = [
        "# QueryForge Day 70 - Final Project Audit",
        "",
        f"Generated: {date_string}",
        f"Database: `{result['database']}`",
        f"Status: **{result['status']}**",
        "",
        "## Relation counts",
        "",
        "| Relation | Rows |",
        "|---|---:|",
    ]

    for name in TABLE_KINDS:

        count = result["counts"].get(
            name,
            "MISSING",
        )

        lines.append(
            f"| `{name}` | {count} |"
        )

    lines += [
        "",
        "## Structural checks",
        "",
        f"- Partition key: `{result['partition_key']}`",
        (
            "- Attached partitions: "
            + (
                ", ".join(result["partitions"])
                or "none"
            )
        ),
        (
            "- Unique valid materialized-view index: "
            f"{result['unique_mv_index']}"
        ),
    ]

    if result["summary"] is not None:

        src_rows, mv_rows, src_amt, mv_amt = (
            result["summary"]
        )

        lines += [
            (
                "- Source / summarized orders: "
                f"{src_rows} / {mv_rows}"
            ),
            (
                "- Source / summarized amount: "
                f"{src_amt} / {mv_amt}"
            ),
        ]

    lines += [
        "",
        "## Failures",
        "",
    ]

    lines += (
        [f"- {v}" for v in result["failures"]]
        or ["- None"]
    )

    lines += [
        "",
        "## Warnings",
        "",
    ]

    lines += (
        [f"- {v}" for v in result["warnings"]]
        or ["- None"]
    )

    lines += [
        "",
        "## Scope / open work",
        "",
        "- Audit ran inside a PostgreSQL READ ONLY transaction followed by ROLLBACK.",
        "- Python Day 69 checkpoints remain in memory; durable checkpointing is not implemented.",
        "- Automated unit/regression tests are run separately by the PowerShell verification command.",
        "- Real-source ETL, deployment, operational backup restore, and concurrency require further validation.",
        "- Review older modified/untracked Git files independently before claiming a clean repository.",
    ]

    REPORT_PATH.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )

    return REPORT_PATH


def main() -> int:

    try:

        with psycopg.connect(
            host=os.getenv(
                "DB_HOST", "localhost"
            ),
            port=os.getenv(
                "DB_PORT", "5432"
            ),
            dbname=os.getenv(
                "DB_NAME", EXPECTED_DB
            ),
            user=os.getenv(
                "DB_USER", "postgres"
            ),
            password=os.getenv("DB_PASSWORD"),
            autocommit=True,
        ) as conn:

            result = collect_audit(conn)

        path = write_report(result)

        for name, count in result["counts"].items():
            print(f"{name}: {count}")

        for issue in result["failures"]:
            print(f"FAIL: {issue}")

        for issue in result["warnings"]:
            print(f"WARN: {issue}")

        print(
            f"DAY 70 STATUS: {result['status']}"
        )

        print(
            f"Report saved: {path}"
        )

        return 1 if result["failures"] else 0

    except Exception as exc:

        print(
            f"DAY 70 STATUS: FAIL - "
            f"{type(exc).__name__}: {exc}"
        )

        return 1


if __name__ == "__main__":
    raise SystemExit(main())
