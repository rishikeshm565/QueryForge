
"""
QueryForge Day 67
Incremental loading and PostgreSQL UPSERT demo.
"""

from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
import os

import psycopg
from dotenv import load_dotenv

load_dotenv()

SQL_FILE = Path(__file__).with_suffix(".sql")
REPORT_FILE = Path("docs/day67_incremental_upsert.md")


@dataclass(frozen=True)
class Customer:
    customer_id: int
    customer_name: str
    city: str
    credit_limit: Decimal
    source_updated_at: datetime


def validate_customer(customer):
    if customer.customer_id <= 0:
        raise ValueError("Invalid customer ID")

    if customer.credit_limit < 0:
        raise ValueError("Negative credit limit")

    if (
        customer.source_updated_at.tzinfo is None
        or customer.source_updated_at.utcoffset() is None
    ):
        raise ValueError("Timestamp must include timezone")


def simulate_upsert(current, incoming):
    """
    Pure Python model of the SQL UPSERT.

    Returns: (sorted customer rows, changed row count).
    Does not modify the input collections.
    """

    target = {}

    for row in current:
        validate_customer(row)

        if row.customer_id in target:
            raise ValueError("Duplicate existing ID")

        target[row.customer_id] = row

    seen = set()
    changed = 0

    for row in incoming:
        validate_customer(row)

        if row.customer_id in seen:
            raise ValueError("Duplicate incoming ID")

        seen.add(row.customer_id)

        existing = target.get(row.customer_id)

        if (
            existing is None
            or row.source_updated_at
            > existing.source_updated_at
        ):
            target[row.customer_id] = row
            changed += 1

    return (
        sorted(target.values(),
               key=lambda row: row.customer_id),
        changed,
    )


def run_database_demo():
    """
    Execute the SQL demo.
    All database changes use temporary tables
    and the SQL ends with ROLLBACK.
    """

    if not SQL_FILE.is_file():
        raise FileNotFoundError(SQL_FILE)

    sql = SQL_FILE.read_text(encoding="utf-8")

    notices = []

    def notice_handler(diagnostic):
        message = diagnostic.message_primary

        if message:
            notices.append(message)

    params = {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": os.getenv("DB_PORT", "5432"),
        "dbname": os.getenv(
            "DB_NAME", "queryforge_dev"
        ),
        "user": os.getenv("DB_USER", "postgres"),
        "password": os.getenv("DB_PASSWORD"),
        "autocommit": True,
    }

    with psycopg.connect(**params) as conn:
        conn.add_notice_handler(notice_handler)

        try:
            with conn.cursor() as cur:
                cur.execute(sql)

        except Exception:
            # Recover even if a SQL assertion fails.
            conn.execute("ROLLBACK;")
            raise

    passes = [
        message for message in notices
        if "DAY 67 PASS:" in message
    ]

    if len(passes) != 1:
        raise RuntimeError(
            "Expected Day 67 SQL PASS notice missing"
        )

    return passes[0]


def save_report(result):
    REPORT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    timestamp = datetime.now(
        timezone.utc
    ).strftime("%Y-%m-%d %H:%M:%S UTC")

    content = f"""# QueryForge Day 67

Generated: {timestamp}

## Incremental Loading and UPSERT

Result: PASS

{result}

## Verified

- New customer inserted
- Existing newer record updated
- Equal timestamp skipped
- Stale record skipped
- Second identical batch changed zero rows
- Primary-key conflicts handled

## Safety

- PostgreSQL temporary tables only
- Transaction ended with ROLLBACK
- No persistent customer data modified

## Limitation

This validates the UPSERT algorithm using
synthetic data. Production ETL integration
and persistent checkpointing remain pending.
"""

    REPORT_FILE.write_text(
        content,
        encoding="utf-8",
    )


def main():
    try:
        print("===== DAY 67 UPSERT DEMO =====")

        result = run_database_demo()

        print(result)

        save_report(result)

        print(f"Report saved: {REPORT_FILE}")
        print("DAY 67 STATUS: PASS")

        return 0

    except Exception as exc:
        print(f"DAY 67 STATUS: FAIL - {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
