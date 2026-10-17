
"""QueryForge Day 73: durable, resumable batches from Day 72."""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import psycopg
from dotenv import load_dotenv


class CheckpointError(Exception):
    pass


class SimulatedInterruption(Exception):
    pass


@dataclass(frozen=True)
class State:
    expected: int
    processed: int = 0
    last_row: int = 0
    status: str = "RUNNING"


def validate_options(upload_id: int, batch_size: int) -> None:
    if not 1 <= upload_id <= 2_147_483_647:
        raise CheckpointError(
            "upload_id must be a positive 32-bit integer"
        )

    if not 1 <= batch_size <= 1000:
        raise CheckpointError(
            "batch_size must be between 1 and 1000"
        )


def advance(state: State, source_rows: list[tuple]) -> State:
    if state.status != "RUNNING":
        raise CheckpointError("Cannot process a completed job")

    if not source_rows:
        if state.processed != state.expected:
            raise CheckpointError(
                "Source rows missing before completion"
            )

        return State(
            state.expected,
            state.processed,
            state.last_row,
            "COMPLETED",
        )

    positions = [row[0] for row in source_rows]

    if any(
        position <= state.last_row
        for position in positions
    ):
        raise CheckpointError("Source row moved backwards")

    if positions != sorted(set(positions)):
        raise CheckpointError(
            "Source rows are not strictly increasing"
        )

    new_count = state.processed + len(source_rows)

    if new_count > state.expected:
        raise CheckpointError(
            "Batch exceeds expected source count"
        )

    return State(
        state.expected,
        new_count,
        positions[-1],
        (
            "COMPLETED"
            if new_count == state.expected
            else "RUNNING"
        ),
    )


def connect():
    load_dotenv()

    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "queryforge_dev"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
        connect_timeout=10,
        autocommit=True,
    )


def source_info(
    conn,
    upload_id: int,
) -> tuple[str, int]:

    with conn.cursor() as cur:
        cur.execute("SELECT current_database()")

        if cur.fetchone()[0] != "queryforge_dev":
            raise CheckpointError(
                "Only queryforge_dev is allowed"
            )

        cur.execute(
            """
            SELECT
                file_hash,
                accepted_rows,
                total_rows,
                rejected_rows
            FROM qf_day72.file_uploads
            WHERE upload_id = %s
            """,
            (upload_id,),
        )

        row = cur.fetchone()

        if row is None:
            raise CheckpointError(
                "Day 72 source upload not found"
            )

        digest, expected, total, rejected = row

        cur.execute(
            """
            SELECT COUNT(*)
            FROM qf_day72.customer_rows
            WHERE upload_id = %s
            """,
            (upload_id,),
        )

        actual = cur.fetchone()[0]

        if (
            actual != expected
            or total != expected + rejected
            or expected == 0
        ):
            raise CheckpointError(
                "Day 72 source counts are inconsistent"
            )

        return str(digest), expected


def create_schema(conn) -> None:
    path = Path(__file__).with_suffix(".sql")

    if not path.is_file():
        raise CheckpointError(
            f"Day 73 SQL missing: {path}"
        )

    ddl = path.read_text(
        encoding="utf-8-sig"
    )

    with conn.cursor() as cur:
        for statement in ddl.split(";"):
            if statement.strip():
                cur.execute(statement)


def row_state(
    conn,
    upload_id: int,
    expected: int,
) -> State:

    with conn.cursor() as cur:
        cur.execute(
            "SELECT TO_REGCLASS('qf_day73.jobs')"
        )

        if cur.fetchone()[0] is None:
            return State(
                expected,
                status="NOT_STARTED",
            )

        cur.execute(
            """
            SELECT
                expected_rows,
                processed_rows,
                last_source_row,
                status
            FROM qf_day73.jobs
            WHERE source_upload_id = %s
            """,
            (upload_id,),
        )

        record = cur.fetchone()

        if record is None:
            return State(
                expected,
                status="NOT_STARTED",
            )

        return State(*record)


def summary(
    conn,
    upload_id: int,
    expected: int,
) -> dict:

    state = row_state(
        conn,
        upload_id,
        expected,
    )

    result = {
        "upload_id": upload_id,
        "expected_rows": expected,
        "processed_rows": state.processed,
        "last_source_row": state.last_row,
        "status": state.status,
        "stored_rows": 0,
        "batch_count": 0,
    }

    if state.status != "NOT_STARTED":

        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT COUNT(*)
                FROM qf_day73.processed_customers
                WHERE source_upload_id = %s
                """,
                (upload_id,),
            )

            result["stored_rows"] = cur.fetchone()[0]

            cur.execute(
                """
                SELECT
                    COUNT(*),
                    COALESCE(SUM(batch_rows), 0)
                FROM qf_day73.batch_history
                WHERE source_upload_id = %s
                """,
                (upload_id,),
            )

            batches, batch_rows = cur.fetchone()

            result["batch_count"] = batches

            if (
                result["stored_rows"] != state.processed
                or batch_rows != state.processed
                or state.expected != expected
            ):
                raise CheckpointError(
                    "Checkpoint and stored rows disagree"
                )

    return result


def process(
    conn,
    upload_id: int,
    size: int,
    stop_after: int,
) -> None:

    # Prevent another worker from processing the same upload
    # simultaneously in this demonstration.

    with conn.cursor() as cur:
        cur.execute(
            "SELECT pg_try_advisory_lock(%s, %s)",
            (73, upload_id),
        )

        if not cur.fetchone()[0]:
            raise CheckpointError(
                "Another process owns this upload lock"
            )

    try:
        # Only create objects in qf_day73.
        # Day 72 source is read-only.

        with conn.transaction():
            create_schema(conn)

            digest, expected = source_info(
                conn,
                upload_id,
            )

            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO qf_day73.jobs
                    (
                        source_upload_id,
                        source_hash,
                        expected_rows
                    )
                    VALUES (%s, %s, %s)
                    ON CONFLICT (source_upload_id)
                    DO NOTHING
                    """,
                    (
                        upload_id,
                        digest,
                        expected,
                    ),
                )

                cur.execute(
                    """
                    SELECT
                        source_hash,
                        expected_rows
                    FROM qf_day73.jobs
                    WHERE source_upload_id = %s
                    FOR UPDATE
                    """,
                    (upload_id,),
                )

                registered_hash, registered_count = (
                    cur.fetchone()
                )

                if (
                    str(registered_hash).strip()
                    != digest.strip()
                    or registered_count != expected
                ):
                    raise CheckpointError(
                        "Registered source identity changed"
                    )

        # Confirm checkpoint integrity before resuming.
        summary(conn, upload_id, expected)

        committed_batches = 0

        while True:

            # One transaction per batch.
            # Customer rows, history and checkpoint
            # commit or roll back together.

            with conn.transaction():
                with conn.cursor() as cur:

                    cur.execute(
                        """
                        SELECT
                            expected_rows,
                            processed_rows,
                            last_source_row,
                            status
                        FROM qf_day73.jobs
                        WHERE source_upload_id = %s
                        FOR UPDATE
                        """,
                        (upload_id,),
                    )

                    state = State(*cur.fetchone())

                    if state.status == "COMPLETED":
                        print(
                            "Job already completed; "
                            "no duplicate inserts"
                        )
                        break

                    cur.execute(
                        """
                        SELECT
                            source_row,
                            customer_id,
                            customer_name,
                            city,
                            email,
                            credit_limit
                        FROM qf_day72.customer_rows
                        WHERE upload_id = %s
                          AND source_row > %s
                        ORDER BY source_row
                        LIMIT %s
                        """,
                        (
                            upload_id,
                            state.last_row,
                            size,
                        ),
                    )

                    rows = cur.fetchall()

                    next_state = advance(
                        state,
                        rows,
                    )

                    if not rows:
                        cur.execute(
                            """
                            UPDATE qf_day73.jobs
                            SET
                                status = 'COMPLETED',
                                updated_at = NOW()
                            WHERE source_upload_id = %s
                            """,
                            (upload_id,),
                        )
                        break

                    cur.executemany(
                        """
                        INSERT INTO qf_day73.processed_customers
                        (
                            source_upload_id,
                            source_row,
                            customer_id,
                            customer_name,
                            city,
                            email,
                            credit_limit
                        )
                        VALUES
                        (%s, %s, %s, %s, %s, %s, %s)
                        """,
                        [
                            (upload_id, *row)
                            for row in rows
                        ],
                    )

                    cur.execute(
                        """
                        SELECT
                            COALESCE(MAX(batch_number), 0) + 1
                        FROM qf_day73.batch_history
                        WHERE source_upload_id = %s
                        """,
                        (upload_id,),
                    )

                    batch_number = cur.fetchone()[0]

                    cur.execute(
                        """
                        INSERT INTO qf_day73.batch_history
                        (
                            source_upload_id,
                            batch_number,
                            first_source_row,
                            last_source_row,
                            batch_rows
                        )
                        VALUES (%s, %s, %s, %s, %s)
                        """,
                        (
                            upload_id,
                            batch_number,
                            rows[0][0],
                            rows[-1][0],
                            len(rows),
                        ),
                    )

                    cur.execute(
                        """
                        UPDATE qf_day73.jobs
                        SET
                            processed_rows = %s,
                            last_source_row = %s,
                            status = %s,
                            updated_at = NOW()
                        WHERE source_upload_id = %s
                        """,
                        (
                            next_state.processed,
                            next_state.last_row,
                            next_state.status,
                            upload_id,
                        ),
                    )

            # Batch transaction successfully committed here.

            committed_batches += 1

            print(
                f"Batch {batch_number} committed: "
                f"{len(rows)} rows; "
                f"checkpoint="
                f"{next_state.processed}/"
                f"{next_state.expected}"
            )

            if (
                stop_after
                and committed_batches >= stop_after
                and next_state.status != "COMPLETED"
            ):
                raise SimulatedInterruption(
                    "Simulated interruption "
                    "AFTER committed checkpoint"
                )

            if next_state.status == "COMPLETED":
                break

        result = summary(
            conn,
            upload_id,
            expected,
        )

        if (
            result["status"] != "COMPLETED"
            or result["stored_rows"] != expected
        ):
            raise CheckpointError(
                "Final row count/status verification failed"
            )

    finally:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT pg_advisory_unlock(%s, %s)",
                (73, upload_id),
            )


def write_report(
    path: Path,
    details: dict,
) -> None:

    if path.exists():
        raise CheckpointError(
            f"Report already exists: {path}"
        )

    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    timestamp = datetime.now(timezone.utc).strftime(
        "%Y-%m-%d %H:%M UTC"
    )

    content = (
        "# QueryForge Day 73 - Persistent Checkpoints\n\n"
        f"Generated: {timestamp}\n\n"
        f"- Source upload ID: {details['upload_id']}\n"
        f"- Status: {details['status']}\n"
        f"- Expected accepted rows: "
        f"{details['expected_rows']}\n"
        f"- Processed rows: {details['processed_rows']}\n"
        f"- Persisted rows: {details['stored_rows']}\n"
        f"- Committed batches: {details['batch_count']}\n"
        f"- Last source row: {details['last_source_row']}\n\n"
        "Day 72 source records were not changed.\n"
        "Only the new qf_day73 schema holds checkpoint "
        "and processing data.\n"
        "The interruption was intentionally simulated "
        "after batch commit.\n"
        "This is not a production crash/concurrency "
        "certification.\n"
    )

    path.write_text(
        content,
        encoding="utf-8",
    )


def main(argv=None) -> int:

    parser = argparse.ArgumentParser(
        description=__doc__
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
        "--run",
        action="store_true",
        help="Writes to qf_day73 tables",
    )

    parser.add_argument(
        "--stop-after-batches",
        type=int,
        default=0,
    )

    parser.add_argument(
        "--report",
        type=Path,
    )

    args = parser.parse_args(argv)

    try:
        validate_options(
            args.upload_id,
            args.batch_size,
        )

        if (
            args.stop_after_batches < 0
            or (
                args.stop_after_batches
                and not args.run
            )
        ):
            raise CheckpointError(
                "--stop-after-batches requires "
                "--run and a nonnegative value"
            )

        if args.report and args.run:
            raise CheckpointError(
                "Create the report in a separate "
                "read-only --plan call"
            )

        if args.report and args.report.exists():
            raise CheckpointError(
                "Existing report will not be overwritten"
            )

        with connect() as conn:

            digest, expected = source_info(
                conn,
                args.upload_id,
            )

            if args.run:
                process(
                    conn,
                    args.upload_id,
                    args.batch_size,
                    args.stop_after_batches,
                )

            details = summary(
                conn,
                args.upload_id,
                expected,
            )

        print(
            f"DAY 73: upload={args.upload_id} "
            f"status={details['status']} "
            f"processed={details['processed_rows']}/"
            f"{expected} "
            f"stored={details['stored_rows']} "
            f"batches={details['batch_count']}"
        )

        if args.report:

            if details["status"] != "COMPLETED":
                raise CheckpointError(
                    "Cannot write final report "
                    "until job is completed"
                )

            write_report(
                args.report,
                details,
            )

            print(f"Report saved: {args.report}")

        return 0

    except SimulatedInterruption as exc:
        print(f"EXPECTED INTERRUPT: {exc}")
        return 3

    except (
        CheckpointError,
        psycopg.Error,
        OSError,
    ) as exc:

        print(
            f"DAY 73 ERROR: {exc}",
            file=sys.stderr,
        )

        return 1


if __name__ == "__main__":
    raise SystemExit(main())
