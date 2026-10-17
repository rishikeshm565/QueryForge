
"""QueryForge Day 72: isolated Excel-to-PostgreSQL ETL."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path

import pandas as pd
import psycopg
from dotenv import load_dotenv


REQUIRED = (
    "customer_id",
    "customer_name",
    "city",
    "email",
    "credit_limit",
)

EMAIL = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
MAX_CREDIT = Decimal("9999999999.99")
MAX_ID = 999999999999999


class ETLError(Exception):
    pass


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as source:
        for block in iter(
            lambda: source.read(1024 * 1024), b""
        ):
            digest.update(block)

    return digest.hexdigest()


def text_field(
    value: object,
    label: str,
    limit: int,
) -> str:

    if pd.isna(value):
        raise ValueError(f"blank_{label}")

    result = str(value).strip()

    if not result or len(result) > limit:
        raise ValueError(f"invalid_{label}")

    return result


def parse_id(value: object) -> int:

    if isinstance(value, bool) or pd.isna(value):
        raise ValueError("invalid_customer_id")

    try:
        number = Decimal(str(value).strip())

        if (
            not number.is_finite()
            or number != number.to_integral_value()
            or not 1 <= number <= MAX_ID
        ):
            raise ValueError("invalid_customer_id")

        return int(number)

    except (InvalidOperation, ValueError, TypeError) as exc:
        raise ValueError("invalid_customer_id") from exc


def parse_credit(value: object) -> Decimal:

    if isinstance(value, bool) or pd.isna(value):
        raise ValueError("invalid_credit_limit")

    try:
        number = Decimal(str(value).strip())

        if (
            not number.is_finite()
            or not 0 <= number <= MAX_CREDIT
            or number != number.quantize(Decimal("0.01"))
        ):
            raise ValueError("invalid_credit_limit")

        return number.quantize(Decimal("0.01"))

    except (InvalidOperation, ValueError, TypeError) as exc:
        raise ValueError("invalid_credit_limit") from exc


def validate_rows(
    frame: pd.DataFrame,
) -> tuple[list[tuple], list[tuple]]:

    if frame.empty:
        raise ETLError("Workbook has no customer rows")

    if len(frame) > 50000:
        raise ETLError("Maximum 50000 rows per file")

    missing = set(REQUIRED) - set(frame.columns)

    if missing:
        raise ETLError(
            f"Missing columns: {sorted(missing)}"
        )

    accepted = []
    rejected = []
    seen = set()

    for row_number, row in enumerate(
        frame.to_dict(orient="records"),
        start=2,
    ):

        try:
            customer_id = parse_id(
                row["customer_id"]
            )

            name = text_field(
                row["customer_name"],
                "customer_name",
                150,
            )

            city = text_field(
                row["city"],
                "city",
                100,
            )

            email = text_field(
                row["email"],
                "email",
                254,
            ).lower()

            if not EMAIL.fullmatch(email):
                raise ValueError("invalid_email")

            credit = parse_credit(
                row["credit_limit"]
            )

            if customer_id in seen:
                raise ValueError(
                    "duplicate_customer_id_in_file"
                )

            seen.add(customer_id)

            accepted.append(
                (
                    row_number,
                    customer_id,
                    name,
                    city,
                    email,
                    credit,
                )
            )

        except ValueError as exc:
            rejected.append(
                (row_number, str(exc))
            )

    return accepted, rejected


def read_workbook(path: Path) -> pd.DataFrame:

    if not path.is_file():
        raise ETLError(
            f"Missing Excel file: {path}"
        )

    if path.suffix.lower() != ".xlsx":
        raise ETLError("Only .xlsx accepted")

    if path.stat().st_size > 20 * 1024 * 1024:
        raise ETLError(
            "File exceeds 20 MB limit"
        )

    try:
        return pd.read_excel(
            path,
            engine="openpyxl",
            dtype=object,
        )

    except Exception as exc:
        raise ETLError(
            f"Cannot read Excel file: {exc}"
        ) from exc


def make_sample(path: Path) -> None:

    if path.exists():
        raise ETLError(
            f"Refusing to overwrite: {path}"
        )

    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    pd.DataFrame(
        [
            (
                72001, "Asha", "Hyderabad",
                "asha@example.com", 50000
            ),
            (
                72002, "Rahul", "Mumbai",
                "rahul@example.com", 60000
            ),
            (
                72003, "Meera", "Pune",
                "meera@example.com", 48000
            ),
            (
                72003, "Repeated", "Pune",
                "repeat@example.com", 48000
            ),
            (
                72004, "Invalid", "Delhi",
                "invalid-email", 30000
            ),
            (
                72005, "Priya", "Hyderabad",
                "priya@example.com", 70000
            ),
        ],
        columns=REQUIRED,
    ).to_excel(path, index=False)


def run_database(
    path: Path,
    accepted: list[tuple],
    rejected: list[tuple],
    *,
    commit: bool,
) -> str:

    load_dotenv()

    sql_path = Path(__file__).with_suffix(".sql")

    if not sql_path.is_file():
        raise ETLError(
            f"Missing SQL setup file: {sql_path}"
        )

    ddl = sql_path.read_text(
        encoding="utf-8-sig"
    )

    digest = file_hash(path)

    try:
        with psycopg.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5432"),
            dbname=os.getenv(
                "DB_NAME", "queryforge_dev"
            ),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD"),
            connect_timeout=10,
        ) as conn:

            with conn.cursor() as cur:

                cur.execute(
                    "SELECT current_database()"
                )

                if cur.fetchone()[0] != "queryforge_dev":
                    raise ETLError(
                        "STOP: must connect to queryforge_dev"
                    )

                # Schema and inserts share one transaction.
                cur.execute(ddl)

                cur.execute(
                    """
                    SELECT upload_id
                    FROM qf_day72.file_uploads
                    WHERE file_hash = %s
                    """,
                    (digest,),
                )

                if cur.fetchone() is not None:
                    raise ETLError(
                        "This exact file was already committed"
                    )

                cur.execute(
                    """
                    INSERT INTO qf_day72.file_uploads
                    (
                        file_name,
                        file_hash,
                        total_rows,
                        accepted_rows,
                        rejected_rows
                    )
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING upload_id
                    """,
                    (
                        path.name,
                        digest,
                        len(accepted) + len(rejected),
                        len(accepted),
                        len(rejected),
                    ),
                )

                upload_id = cur.fetchone()[0]

                if accepted:
                    cur.executemany(
                        """
                        INSERT INTO qf_day72.customer_rows
                        (
                            upload_id,
                            source_row,
                            customer_id,
                            customer_name,
                            city,
                            email,
                            credit_limit
                        )
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                        """,
                        [
                            (upload_id, *record)
                            for record in accepted
                        ],
                    )

                if rejected:
                    cur.executemany(
                        """
                        INSERT INTO qf_day72.rejected_rows
                        (
                            upload_id,
                            source_row,
                            reason
                        )
                        VALUES (%s, %s, %s)
                        """,
                        [
                            (upload_id, *record)
                            for record in rejected
                        ],
                    )

                cur.execute(
                    """
                    SELECT
                        (
                            SELECT COUNT(*)
                            FROM qf_day72.customer_rows
                            WHERE upload_id = %s
                        ),
                        (
                            SELECT COUNT(*)
                            FROM qf_day72.rejected_rows
                            WHERE upload_id = %s
                        )
                    """,
                    (upload_id, upload_id),
                )

                counts = cur.fetchone()

                if counts != (
                    len(accepted),
                    len(rejected),
                ):
                    raise ETLError(
                        f"Database count mismatch: {counts}"
                    )

                if not commit:
                    conn.rollback()
                    return "VERIFIED_AND_ROLLED_BACK"

        return "COMMITTED"

    except psycopg.Error as exc:
        raise ETLError(
            f"PostgreSQL operation failed: {exc}"
        ) from exc


def report(
    path: Path,
    source: Path,
    mode: str,
    result: str,
    accepted: list[tuple],
    rejected: list[tuple],
) -> None:

    if path.exists():
        raise ETLError(
            f"Report already exists: {path}"
        )

    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    lines = [
        "# QueryForge Day 72 - Excel ETL Verification",
        "",
        f"- Input: `{source.name}`",
        f"- Mode: `{mode}`",
        f"- Status: `{result}`",
        f"- Total rows: {len(accepted) + len(rejected)}",
        f"- Accepted: {len(accepted)}",
        f"- Rejected: {len(rejected)}",
        "",
        "## Rejection summary",
        "",
    ]

    summary = {}

    for _, reason in rejected:
        summary[reason] = summary.get(reason, 0) + 1

    lines.extend(
        f"- {reason}: {count}"
        for reason, count in sorted(summary.items())
    )

    lines += [
        "",
        "No customer names, emails, or passwords "
        "are stored in this report.",
    ]

    path.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )


def main(argv: list[str] | None = None) -> int:

    parser = argparse.ArgumentParser(
        description=__doc__
    )

    group = parser.add_mutually_exclusive_group(
        required=True
    )

    group.add_argument(
        "--make-sample",
        type=Path,
    )

    group.add_argument(
        "--file",
        type=Path,
    )

    parser.add_argument(
        "--mode",
        choices=(
            "dry-run",
            "verify-db",
            "commit",
        ),
        default="dry-run",
    )

    parser.add_argument(
        "--report",
        type=Path,
    )

    args = parser.parse_args(argv)

    try:
        if args.make_sample:

            if (
                args.mode != "dry-run"
                or args.report
            ):
                raise ETLError(
                    "--make-sample cannot use "
                    "--mode or --report"
                )

            make_sample(args.make_sample)

            print(
                f"Sample generated: {args.make_sample}"
            )

            return 0

        if args.report and args.report.exists():
            raise ETLError(
                "Report exists; choose a new report path"
            )

        frame = read_workbook(args.file)

        accepted, rejected = validate_rows(frame)

        print(
            f"Excel rows: {len(frame)} | "
            f"accepted: {len(accepted)} | "
            f"rejected: {len(rejected)}"
        )

        if not accepted:
            raise ETLError(
                "No accepted rows; nothing to upload"
            )

        result = "VALIDATED_ONLY"

        if args.mode != "dry-run":
            result = run_database(
                args.file,
                accepted,
                rejected,
                commit=args.mode == "commit",
            )

        if args.report:
            report(
                args.report,
                args.file,
                args.mode,
                result,
                accepted,
                rejected,
            )

        print(f"DAY 72 STATUS: {result}")

        return 0

    except (ETLError, OSError) as exc:
        print(
            f"DAY 72 ERROR: {exc}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
