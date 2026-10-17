
"""QueryForge Day 68: advanced data-quality demo."""

from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
import os
import re

import pandas as pd
import psycopg
from dotenv import load_dotenv

load_dotenv()

SQL_FILE = Path(__file__).with_suffix(".sql")
REPORT_FILE = Path("docs/day68_data_quality.md")

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
CREDIT_PATTERN = re.compile(
    r"^-?[0-9]+(?:\.[0-9]{1,2})?$"
)
ID_PATTERN = re.compile(
    r"^[0-9]+(?:\.0+)?$"
)
MAX_CREDIT = Decimal("1000000")


class DataQualityError(ValueError):
    pass


@dataclass(frozen=True)
class AuditResult:
    accepted: list[dict]
    quarantined: list[dict]

    @property
    def total(self):
        return (
            len(self.accepted)
            + len(self.quarantined)
        )

    @property
    def reason_counts(self):
        return dict(sorted(Counter(
            reason
            for item in self.quarantined
            for reason in item["reasons"]
        ).items()))


def _id(value):
    if isinstance(value, bool) or pd.isna(value):
        return None

    raw = str(value).strip()

    if not ID_PATTERN.fullmatch(raw):
        return None

    return int(Decimal(raw))


def _text(value):
    if pd.isna(value):
        return ""

    return str(value).strip()


def audit_dataframe(df: pd.DataFrame) -> AuditResult:

    missing = REQUIRED_COLUMNS - set(df.columns)

    if missing:
        raise DataQualityError(
            f"Missing columns: {sorted(missing)}"
        )

    records = df.to_dict(orient="records")

    keys = [
        _id(row["customer_id"])
        for row in records
    ]

    counts = Counter(
        key
        for key in keys
        if key is not None and key > 0
    )

    accepted = []
    quarantined = []

    for source_line, (row, key) in enumerate(
        zip(records, keys),
        start=1,
    ):

        reasons = []

        name = _text(row["customer_name"])
        city = _text(row["city"])
        email = _text(row["email"])
        credit_text = _text(row["credit_limit"])

        if key is None or key <= 0:
            reasons.append(
                "missing_or_invalid_id"
            )
        elif counts[key] > 1:
            reasons.append(
                "duplicate_customer_id"
            )

        if not name:
            reasons.append(
                "blank_customer_name"
            )

        if not city:
            reasons.append(
                "blank_city"
            )

        if not EMAIL_PATTERN.fullmatch(email):
            reasons.append(
                "invalid_email"
            )

        if not CREDIT_PATTERN.fullmatch(
            credit_text
        ):
            reasons.append(
                "invalid_credit_limit"
            )

        else:
            credit = Decimal(credit_text)

            if credit < 0:
                reasons.append(
                    "negative_credit_limit"
                )

            if credit > MAX_CREDIT:
                reasons.append(
                    "credit_limit_outlier"
                )

        if reasons:
            quarantined.append({
                "source_line": source_line,
                "customer_id": key,
                "reasons": reasons,
            })

        else:
            accepted.append({
                "source_line": source_line,
                "customer_id": key,
                "customer_name": name,
                "city": city,
                "email": email.lower(),
                "credit_limit": Decimal(
                    credit_text
                ),
            })

    return AuditResult(
        accepted,
        quarantined,
    )


def sample_data():

    return pd.DataFrame(
        [
            (1, "Rahul", "Hyderabad",
             "rahul@example.com", "50000"),

            (2, "Meera", "Mumbai",
             "meera@example.com", "60000"),

            (2, "Meera Again", "Mumbai",
             "meera2@example.com", "60000"),

            (3, "Arjun", "Delhi",
             "not-an-email", "70000"),

            (4, "Priya", "Pune",
             "priya@example.com", "-1000"),

            (None, "Missing ID", "Pune",
             "missing@example.com", "1000"),

            (5, "Sneha", "Chennai",
             "sneha@example.com", "ABC"),

            (6, "   ", "Jaipur",
             "blank@example.com", "20000"),

            (7, "Zoya", "Kolkata",
             "zoya@example.com", "2000000"),

            (8, "Aarav", "Pune",
             "aarav@example.com", "40000"),
        ],
        columns=[
            "customer_id",
            "customer_name",
            "city",
            "email",
            "credit_limit",
        ],
    )


def run_postgresql_demo():

    if not SQL_FILE.is_file():
        raise FileNotFoundError(SQL_FILE)

    notices = []

    params = {
        "host": os.getenv(
            "DB_HOST", "localhost"
        ),
        "port": os.getenv(
            "DB_PORT", "5432"
        ),
        "dbname": os.getenv(
            "DB_NAME", "queryforge_dev"
        ),
        "user": os.getenv(
            "DB_USER", "postgres"
        ),
        "password": os.getenv("DB_PASSWORD"),
        "autocommit": True,
    }

    with psycopg.connect(**params) as conn:

        conn.add_notice_handler(
            lambda diagnostic: notices.append(
                diagnostic.message_primary
            )
        )

        try:
            with conn.cursor() as cursor:
                cursor.execute(
                    SQL_FILE.read_text(
                        encoding="utf-8"
                    )
                )

        except Exception:
            conn.execute("ROLLBACK;")
            raise

    passed = [
        message
        for message in notices
        if message.startswith("DAY 68 PASS:")
    ]

    if len(passed) != 1:
        raise RuntimeError(
            "PostgreSQL audit PASS notice missing"
        )

    return passed[0]


def save_report(audit, postgres_result):

    REPORT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    timestamp = datetime.now(
        timezone.utc
    ).strftime("%Y-%m-%d %H:%M:%S UTC")

    reason_table = "\n".join(
        f"| {reason} | {count} |"
        for reason, count
        in audit.reason_counts.items()
    )

    report = f"""# QueryForge Day 68 - Advanced Data Quality

Generated: {timestamp}

Status: PASS (synthetic demo)

| Metric | Count |
|---|---:|
| Total input rows | {audit.total} |
| Accepted rows | {len(audit.accepted)} |
| Quarantined rows | {len(audit.quarantined)} |

## Data-quality issues

| Reason | Affected rows |
|---|---:|
{reason_table}

## PostgreSQL verification

{postgres_result}

## Safety and scope

- Synthetic sample rows only
- Temporary PostgreSQL tables and ROLLBACK
- Existing ETL/customer tables are not modified
- Production quarantine deployment is pending
"""

    REPORT_FILE.write_text(
        report,
        encoding="utf-8",
    )


def main():

    try:
        print("===== DAY 68 DATA QUALITY =====")

        audit = audit_dataframe(
            sample_data()
        )

        actual = (
            audit.total,
            len(audit.accepted),
            len(audit.quarantined),
        )

        if actual != (10, 2, 8):
            raise RuntimeError(
                "Python sample counts mismatch"
            )

        print(
            "Python: total 10, accepted 2, "
            "quarantined 8"
        )

        postgres_result = run_postgresql_demo()

        print(postgres_result)

        save_report(
            audit,
            postgres_result,
        )

        print(
            f"Report saved: {REPORT_FILE}"
        )

        print("DAY 68 STATUS: PASS")

        return 0

    except Exception as exc:

        print(f"DAY 68 STATUS: FAIL - {exc}")

        return 1


if __name__ == "__main__":
    raise SystemExit(main())
