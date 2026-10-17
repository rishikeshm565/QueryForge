
"""QueryForge Day 69: synthetic ETL batch recovery demo."""

from __future__ import annotations

from datetime import date, datetime, timezone
from hashlib import sha256
from pathlib import Path
import json
import os


SQL_FILE = Path(__file__).with_suffix(".sql")
REPORT_FILE = Path("docs/day69_batch_recovery.md")


class BatchValidationError(ValueError):
    pass


class BatchConflictError(ValueError):
    pass


class SimulatedCrash(RuntimeError):
    pass


def process_batch(
    target,
    checkpoints,
    batch_id,
    rows,
    fail_after=None,
):
    """
    Process a batch using copy-on-write simulation.

    target:
        customer_id -> (customer_name, updated_date)

    checkpoints:
        batch_id -> SHA256 fingerprint
    """

    if (
        isinstance(batch_id, bool)
        or not isinstance(batch_id, int)
        or batch_id <= 0
    ):
        raise BatchValidationError(
            "batch_id must be a positive integer"
        )

    if not isinstance(rows, list) or not rows:
        raise BatchValidationError(
            "Batch must contain at least one row"
        )

    if fail_after is not None and (
        isinstance(fail_after, bool)
        or not isinstance(fail_after, int)
        or not (1 <= fail_after <= len(rows))
    ):
        raise BatchValidationError(
            "fail_after must be within batch size"
        )

    validated = []
    seen = set()

    for row in rows:

        if not isinstance(row, dict):
            raise BatchValidationError(
                "Each row must be an object"
            )

        customer_id = row.get("customer_id")
        name = row.get("customer_name")
        updated = row.get("source_updated_at")

        if (
            isinstance(customer_id, bool)
            or not isinstance(customer_id, int)
            or customer_id <= 0
        ):
            raise BatchValidationError(
                "Invalid customer_id"
            )

        if customer_id in seen:
            raise BatchValidationError(
                "Duplicate customer_id within batch"
            )

        seen.add(customer_id)

        if not isinstance(name, str) or not name.strip():
            raise BatchValidationError(
                "Blank customer_name"
            )

        if not isinstance(updated, str):
            raise BatchValidationError(
                "Invalid source_updated_at"
            )

        try:
            normalized_date = date.fromisoformat(
                updated
            ).isoformat()
        except ValueError as exc:
            raise BatchValidationError(
                "Invalid source_updated_at"
            ) from exc

        validated.append({
            "customer_id": customer_id,
            "customer_name": name.strip(),
            "source_updated_at": normalized_date,
        })

    # Fingerprint prevents a batch ID from being reused
    # with different content.

    payload = json.dumps(
        validated,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    )

    fingerprint = sha256(
        payload.encode("utf-8")
    ).hexdigest()

    if batch_id in checkpoints:

        if checkpoints[batch_id] != fingerprint:
            raise BatchConflictError(
                "Batch ID reused with different contents"
            )

        return {
            "status": "SKIPPED",
            "changed": 0,
        }

    # Stage changes in separate memory.

    staged = target.copy()
    changed = 0

    for processed, row in enumerate(
        validated,
        start=1,
    ):

        customer_id = row["customer_id"]
        incoming_date = row["source_updated_at"]

        existing = staged.get(customer_id)

        if (
            existing is None
            or incoming_date > existing[1]
        ):
            staged[customer_id] = (
                row["customer_name"],
                incoming_date,
            )
            changed += 1

        if fail_after == processed:
            raise SimulatedCrash(
                "Simulated failure before checkpoint commit"
            )

    # Only successful processing updates state
    # and its checkpoint.

    target.update(staged)
    checkpoints[batch_id] = fingerprint

    return {
        "status": "APPLIED",
        "changed": changed,
    }


def sample_batches():

    batch101 = [
        {
            "customer_id": 1,
            "customer_name": "Rahul Updated",
            "source_updated_at": "2026-10-01",
        },
        {
            "customer_id": 2,
            "customer_name": "Meera",
            "source_updated_at": "2026-10-02",
        },
    ]

    batch102 = [
        {
            "customer_id": 3,
            "customer_name": "Zoya",
            "source_updated_at": "2026-10-03",
        },
    ]

    return batch101, batch102


def run_python_demo():

    state = {
        1: ("Rahul Old", "2026-09-01")
    }

    checkpoints = {}

    batch101, batch102 = sample_batches()

    first = process_batch(
        state,
        checkpoints,
        101,
        batch101,
    )

    replay = process_batch(
        state,
        checkpoints,
        101,
        batch101,
    )

    # Simulated failure

    try:
        process_batch(
            state,
            checkpoints,
            102,
            batch102,
            fail_after=1,
        )
    except SimulatedCrash:
        pass
    else:
        raise RuntimeError(
            "Failure simulation did not run"
        )

    if 3 in state or 102 in checkpoints:
        raise RuntimeError(
            "Failed batch changed simulation state"
        )

    # Successful retry

    retry = process_batch(
        state,
        checkpoints,
        102,
        batch102,
    )

    result = (
        first["changed"],
        replay["changed"],
        retry["changed"],
    )

    if result != (2, 0, 1):
        raise RuntimeError(
            "Unexpected batch change counts"
        )

    if len(state) != 3 or len(checkpoints) != 2:
        raise RuntimeError(
            "Recovery simulation state mismatch"
        )

    return state, checkpoints


def run_postgresql_demo():

    from dotenv import load_dotenv
    import psycopg

    load_dotenv()

    notices = []

    sql = SQL_FILE.read_text(
        encoding="utf-8"
    )

    with psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "queryforge_dev"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
        autocommit=True,
    ) as conn:

        conn.add_notice_handler(
            lambda d: notices.append(
                d.message_primary
            )
        )

        try:
            with conn.cursor() as cursor:
                cursor.execute(sql)

        except Exception:
            conn.execute("ROLLBACK")
            raise

    matching = [
        notice
        for notice in notices
        if notice.startswith("DAY 69 PASS:")
    ]

    if len(matching) != 1:
        raise RuntimeError(
            "PostgreSQL verification notice missing"
        )

    return matching[0]


def save_report(
    state,
    checkpoints,
    postgres_message,
):

    REPORT_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    created = datetime.now(
        timezone.utc
    ).strftime("%Y-%m-%d %H:%M:%S UTC")

    report = (
        "# QueryForge Day 69 - Batch Recovery and Checkpoints\n\n"
        f"Generated: {created}\n\n"
        "## Status: PASS (synthetic demo)\n\n"
        f"- Customers after recovery: {len(state)}\n"
        f"- Completed checkpoint entries: {len(checkpoints)}\n"
        "- First batch applied 2 changes\n"
        "- Replay of same batch applied 0 changes\n"
        "- Simulated failure left no partial batch results\n"
        "- Retry successfully applied 1 change\n\n"
        "## PostgreSQL verification\n\n"
        f"{postgres_message}\n\n"
        "## Limitations\n\n"
        "- PostgreSQL demonstration uses temporary tables and ROLLBACK\n"
        "- Python checkpoint dictionary is in memory, not durable\n"
        "- Production job persistence, locking, and multi-worker concurrency remain pending\n"
    )

    REPORT_FILE.write_text(
        report,
        encoding="utf-8",
    )


def main():

    try:

        print(
            "===== DAY 69 CHECKPOINT AND RECOVERY ====="
        )

        state, checkpoints = run_python_demo()

        print(
            "Python: first 2, replay 0, "
            "crash rolled back, retry 1"
        )

        message = run_postgresql_demo()

        print(message)

        save_report(
            state,
            checkpoints,
            message,
        )

        print(
            f"Report saved: {REPORT_FILE}"
        )

        print("DAY 69 STATUS: PASS")

        return 0

    except Exception as exc:

        print(
            f"DAY 69 STATUS: FAIL - {exc}"
        )

        return 1


if __name__ == "__main__":
    raise SystemExit(main())
