
"""QueryForge Day 74: transaction rollback and two-worker concurrency demo."""

from __future__ import annotations

import argparse
import os
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import psycopg
from dotenv import load_dotenv


class Day74Error(Exception):
    pass


class SimulatedCrash(Exception):
    pass


@dataclass(frozen=True)
class Progress:
    expected: int
    done: int
    last_row: int
    status: str = "RUNNING"


def next_progress(progress: Progress, rows: list[tuple]) -> Progress:

    if progress.status != "RUNNING":
        raise Day74Error("Cannot extend a completed job")

    if not rows:
        if progress.done != progress.expected:
            raise Day74Error("Missing source rows")

        return Progress(
            progress.expected,
            progress.done,
            progress.last_row,
            "COMPLETED",
        )

    positions = [row[0] for row in rows]

    if any(
        position <= progress.last_row
        for position in positions
    ):
        raise Day74Error("Source position behind checkpoint")

    if positions != sorted(set(positions)):
        raise Day74Error(
            "Source positions must be strictly increasing"
        )

    count = progress.done + len(rows)

    if count > progress.expected:
        raise Day74Error("Batch exceeds expected row count")

    return Progress(
        progress.expected,
        count,
        positions[-1],
        "COMPLETED" if count == progress.expected else "RUNNING",
    )


def connect():

    load_dotenv()

    conn = psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "queryforge_dev"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
        connect_timeout=10,
        autocommit=True,
    )

    with conn.cursor() as cur:
        cur.execute("SELECT current_database()")

        if cur.fetchone()[0] != "queryforge_dev":
            conn.close()
            raise Day74Error(
                "Wrong database; expected queryforge_dev"
            )

    return conn


def source_info(conn, upload_id: int) -> tuple[str, int]:

    with conn.cursor() as cur:

        cur.execute(
            """
            SELECT file_hash, accepted_rows
            FROM qf_day72.file_uploads
            WHERE upload_id = %s
            """,
            (upload_id,),
        )

        item = cur.fetchone()

        if item is None:
            raise Day74Error("Day 72 upload not found")

        digest, expected = item

        cur.execute(
            """
            SELECT COUNT(*)
            FROM qf_day72.customer_rows
            WHERE upload_id = %s
            """,
            (upload_id,),
        )

        if expected < 1 or cur.fetchone()[0] != expected:
            raise Day74Error("Day 72 source count mismatch")

        return str(digest).strip(), expected


def inspect(conn, upload_id: int) -> dict:

    digest, expected = source_info(conn, upload_id)

    with conn.cursor() as cur:

        cur.execute(
            "SELECT TO_REGCLASS('qf_day74.jobs')"
        )

        if cur.fetchone()[0] is None:
            return dict(
                status="NOT_STARTED",
                expected=expected,
                processed=0,
                stored=0,
                batches=0,
                snapshot=0,
                last_row=0,
            )

        cur.execute(
            """
            SELECT
                source_hash,
                expected_rows,
                processed_rows,
                last_source_row,
                status
            FROM qf_day74.jobs
            WHERE upload_id = %s
            """,
            (upload_id,),
        )

        job = cur.fetchone()

        if job is None:
            return dict(
                status="NOT_STARTED",
                expected=expected,
                processed=0,
                stored=0,
                batches=0,
                snapshot=0,
                last_row=0,
            )

        db_digest, total, done, last, status = job

        if str(db_digest).strip() != digest or total != expected:
            raise Day74Error(
                "Source identity or expected row count changed"
            )

        cur.execute(
            """
            SELECT COUNT(*)
            FROM qf_day74.source_snapshot
            WHERE upload_id = %s
            """,
            (upload_id,),
        )

        snapshot = cur.fetchone()[0]

        cur.execute(
            """
            SELECT
                COUNT(*),
                COALESCE(MAX(source_row), 0)
            FROM qf_day74.processed_rows
            WHERE upload_id = %s
            """,
            (upload_id,),
        )

        stored, max_row = cur.fetchone()

        cur.execute(
            """
            SELECT
                COUNT(*),
                COALESCE(SUM(batch_rows), 0)
            FROM qf_day74.batch_history
            WHERE upload_id = %s
            """,
            (upload_id,),
        )

        batches, summed = cur.fetchone()

        if (
            snapshot != expected
            or stored != done
            or summed != done
            or max_row != last
            or (status == "COMPLETED" and done != expected)
        ):
            raise Day74Error(
                "Checkpoint / snapshot / batch counts disagree"
            )

        return dict(
            status=status,
            expected=expected,
            processed=done,
            stored=stored,
            batches=batches,
            snapshot=snapshot,
            last_row=last,
        )


def setup(conn, upload_id: int) -> None:

    ddl_path = Path(__file__).with_suffix(".sql")
    ddl = ddl_path.read_text(encoding="utf-8-sig")

    digest, expected = source_info(conn, upload_id)

    if inspect(conn, upload_id)["status"] != "NOT_STARTED":
        raise Day74Error(
            "Day 74 job already exists; do not reset"
        )

    with conn.transaction():

        with conn.cursor() as cur:

            for statement in ddl.split(";"):
                if statement.strip():
                    cur.execute(statement)

            cur.execute(
                """
                INSERT INTO qf_day74.jobs
                (upload_id, source_hash, expected_rows)
                VALUES (%s, %s, %s)
                """,
                (upload_id, digest, expected),
            )

            cur.execute(
                """
                INSERT INTO qf_day74.source_snapshot
                (
                    upload_id,
                    source_row,
                    customer_id,
                    customer_name,
                    city,
                    email,
                    credit_limit
                )
                SELECT
                    upload_id,
                    source_row,
                    customer_id,
                    customer_name,
                    city,
                    email,
                    credit_limit
                FROM qf_day72.customer_rows
                WHERE upload_id = %s
                """,
                (upload_id,),
            )

            if cur.rowcount != expected:
                raise Day74Error("Snapshot row count mismatch")

    print(
        "DAY 74 SETUP: source snapshot and empty checkpoint committed"
    )


def one_batch(
    conn,
    upload_id: int,
    size: int,
    hold: float = 0,
    crash: bool = False,
) -> bool:

    with conn.transaction():

        with conn.cursor() as cur:

            # Locks the job row until transaction completion.
            cur.execute(
                """
                SELECT
                    expected_rows,
                    processed_rows,
                    last_source_row,
                    status
                FROM qf_day74.jobs
                WHERE upload_id = %s
                FOR UPDATE
                """,
                (upload_id,),
            )

            record = cur.fetchone()

            if record is None:
                raise Day74Error(
                    "Job missing: run --mode setup"
                )

            progress = Progress(*record)

            if progress.status == "COMPLETED":
                return False

            cur.execute(
                """
                SELECT source_row, customer_id
                FROM qf_day74.source_snapshot
                WHERE upload_id = %s
                  AND source_row > %s
                ORDER BY source_row
                LIMIT %s
                """,
                (
                    upload_id,
                    progress.last_row,
                    size,
                ),
            )

            rows = cur.fetchall()

            next_state = next_progress(progress, rows)

            if not rows:
                cur.execute(
                    """
                    UPDATE qf_day74.jobs
                    SET
                        status = 'COMPLETED',
                        updated_at = NOW()
                    WHERE upload_id = %s
                    """,
                    (upload_id,),
                )
                return False

            # Step A: insert processed rows.
            cur.executemany(
                """
                INSERT INTO qf_day74.processed_rows
                (upload_id, source_row, customer_id)
                VALUES (%s, %s, %s)
                """,
                [
                    (upload_id, *row)
                    for row in rows
                ],
            )

            # Step B: record batch.
            cur.execute(
                """
                SELECT COALESCE(MAX(batch_number), 0) + 1
                FROM qf_day74.batch_history
                WHERE upload_id = %s
                """,
                (upload_id,),
            )

            batch_no = cur.fetchone()[0]

            cur.execute(
                """
                INSERT INTO qf_day74.batch_history
                (
                    upload_id,
                    batch_number,
                    first_source_row,
                    last_source_row,
                    batch_rows
                )
                VALUES (%s, %s, %s, %s, %s)
                """,
                (
                    upload_id,
                    batch_no,
                    rows[0][0],
                    rows[-1][0],
                    len(rows),
                ),
            )

            # Step C: update durable checkpoint.
            cur.execute(
                """
                UPDATE qf_day74.jobs
                SET
                    processed_rows = %s,
                    last_source_row = %s,
                    status = %s,
                    updated_at = NOW()
                WHERE upload_id = %s
                """,
                (
                    next_state.done,
                    next_state.last_row,
                    next_state.status,
                    upload_id,
                ),
            )

            if hold:
                # Keeps the row lock briefly during concurrency testing.
                time.sleep(hold)

            if crash:
                # Deliberate failure BEFORE transaction commit.
                # All three writes must roll back.
                raise SimulatedCrash(
                    "Failure injected BEFORE transaction commit"
                )

    print(
        f"Committed batch {batch_no}: {len(rows)} rows"
    )

    return True


def write_report(
    path: Path,
    state: dict,
    upload_id: int,
) -> None:

    if path.exists():
        raise Day74Error(
            "Report already exists; refusing overwrite"
        )

    if state["status"] != "COMPLETED":
        raise Day74Error(
            "Cannot write report for incomplete job"
        )

    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    stamp = datetime.now(timezone.utc).strftime(
        "%Y-%m-%d %H:%M UTC"
    )

    report = (
        "# QueryForge Day 74 - Crash Recovery & Concurrency\n\n"
        f"Generated: {stamp}\n\n"
        f"- Day 72 upload ID: {upload_id}\n"
        f"- Status: {state['status']}\n"
        f"- Source snapshot rows: {state['snapshot']}\n"
        f"- Processed rows: {state['processed']}\n"
        f"- Stored rows: {state['stored']}\n"
        f"- Committed batches: {state['batches']}\n"
        f"- Last source row: {state['last_row']}\n\n"
        "- Crash injection: deliberately raised before commit; "
        "verified separately by the PowerShell runner.\n"
        "- Two worker processes: verified separately by the PowerShell runner.\n"
        "- qf_day72 and qf_day73 were not modified by this demo.\n"
        "- Production crash and multi-host guarantees remain untested.\n"
    )

    path.write_text(
        report,
        encoding="utf-8",
    )


def main(argv=None) -> int:

    parser = argparse.ArgumentParser(
        description=__doc__
    )

    parser.add_argument(
        "--mode",
        required=True,
        choices=("check", "setup", "crash", "worker"),
    )

    parser.add_argument(
        "--upload-id",
        type=int,
        required=True,
    )

    parser.add_argument(
        "--batch-size",
        type=int,
        default=2,
    )

    parser.add_argument(
        "--hold-seconds",
        type=float,
        default=0,
    )

    parser.add_argument(
        "--expect-status",
        choices=("NOT_STARTED", "RUNNING", "COMPLETED"),
    )

    parser.add_argument(
        "--expected-processed",
        type=int,
    )

    parser.add_argument(
        "--report",
        type=Path,
    )

    args = parser.parse_args(argv)

    try:

        if not 1 <= args.upload_id <= 2_147_483_647:
            raise Day74Error("Invalid upload ID")

        if not 1 <= args.batch_size <= 1000:
            raise Day74Error("Batch size must be 1..1000")

        if not 0 <= args.hold_seconds <= 2:
            raise Day74Error("Hold seconds must be 0..2")

        if args.report and args.mode != "check":
            raise Day74Error(
                "Report is only allowed in check mode"
            )

        if (
            args.expect_status
            or args.expected_processed is not None
        ) and args.mode != "check":
            raise Day74Error(
                "Expectations are only allowed in check mode"
            )

        with connect() as conn:

            if args.mode == "setup":
                setup(conn, args.upload_id)

            elif args.mode == "crash":

                try:
                    if not one_batch(
                        conn,
                        args.upload_id,
                        args.batch_size,
                        crash=True,
                    ):
                        raise Day74Error(
                            "Job already complete; crash not tested"
                        )

                except SimulatedCrash:
                    print(
                        "EXPECTED CRASH: changes rolled back by PostgreSQL"
                    )
                    return 3

            elif args.mode == "worker":

                while one_batch(
                    conn,
                    args.upload_id,
                    args.batch_size,
                    hold=args.hold_seconds,
                ):
                    pass

            state = inspect(
                conn,
                args.upload_id,
            )

            print(
                f"DAY 74: status={state['status']} "
                f"processed={state['processed']}/{state['expected']} "
                f"stored={state['stored']} "
                f"batches={state['batches']}"
            )

            if (
                args.expect_status
                and state["status"] != args.expect_status
            ):
                raise Day74Error("Unexpected status")

            if (
                args.expected_processed is not None
                and state["processed"] != args.expected_processed
            ):
                raise Day74Error(
                    "Unexpected processed count"
                )

            if args.report:
                write_report(
                    args.report,
                    state,
                    args.upload_id,
                )

                print(f"Report saved: {args.report}")

        return 0

    except (
        Day74Error,
        psycopg.Error,
        OSError,
    ) as exc:

        print(
            f"DAY 74 ERROR: {exc}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
