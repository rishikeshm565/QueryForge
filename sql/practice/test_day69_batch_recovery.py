
"""QueryForge Day 69 tests."""

import copy

import pytest

from day69_batch_recovery import (
    BatchConflictError,
    BatchValidationError,
    SimulatedCrash,
    SQL_FILE,
    process_batch,
    run_python_demo,
)


def row(
    cid=1,
    name="Asha",
    updated="2026-10-01",
):
    return {
        "customer_id": cid,
        "customer_name": name,
        "source_updated_at": updated,
    }


def test_01_insert_new():
    target, ledger = {}, {}

    result = process_batch(
        target, ledger, 1, [row()]
    )

    assert result["changed"] == 1
    assert target[1][0] == "Asha"


def test_02_update_newer():
    target = {
        1: ("Old", "2026-09-01")
    }

    ledger = {}

    result = process_batch(
        target, ledger, 1, [row()]
    )

    assert result["changed"] == 1
    assert target[1][0] == "Asha"


def test_03_stale_record_ignored():
    target = {
        1: ("Latest", "2026-12-01")
    }

    ledger = {}

    result = process_batch(
        target, ledger, 1, [row()]
    )

    assert result["changed"] == 0
    assert target[1][0] == "Latest"
    assert 1 in ledger


def test_04_exact_batch_replay():
    target, ledger = {}, {}

    first = process_batch(
        target, ledger, 1, [row()]
    )

    second = process_batch(
        target, ledger, 1, [row()]
    )

    assert first["status"] == "APPLIED"
    assert second["status"] == "SKIPPED"


def test_05_changed_replay_rejected():
    target, ledger = {}, {}

    process_batch(
        target, ledger, 1, [row()]
    )

    with pytest.raises(BatchConflictError):
        process_batch(
            target,
            ledger,
            1,
            [row(name="Different")],
        )


def test_06_crash_is_atomic():
    target = {
        1: ("Old", "2026-09-01")
    }

    ledger = {}
    original = target.copy()

    with pytest.raises(SimulatedCrash):
        process_batch(
            target,
            ledger,
            1,
            [row(), row(2)],
            fail_after=1,
        )

    assert target == original
    assert ledger == {}


def test_07_retry_after_crash():
    target, ledger = {}, {}
    rows = [row()]

    with pytest.raises(SimulatedCrash):
        process_batch(
            target,
            ledger,
            1,
            rows,
            fail_after=1,
        )

    result = process_batch(
        target, ledger, 1, rows
    )

    assert result["changed"] == 1


def test_08_duplicate_ids_rejected():
    with pytest.raises(BatchValidationError):
        process_batch(
            {}, {}, 1, [row(), row()]
        )


def test_09_invalid_id_rejected():
    with pytest.raises(BatchValidationError):
        process_batch(
            {}, {}, 1, [row(cid=0)]
        )


def test_10_blank_name_rejected():
    with pytest.raises(BatchValidationError):
        process_batch(
            {}, {}, 1, [row(name=" ")]
        )


def test_11_invalid_date_rejected():
    with pytest.raises(BatchValidationError):
        process_batch(
            {}, {}, 1,
            [row(updated="not-a-date")]
        )


def test_12_empty_batch_rejected():
    with pytest.raises(BatchValidationError):
        process_batch(
            {}, {}, 1, []
        )


def test_13_original_rows_unchanged():
    batch = [
        row(name="  Asha  ")
    ]

    before = copy.deepcopy(batch)

    process_batch(
        {}, {}, 1, batch
    )

    assert batch == before


def test_14_hash_ignores_dictionary_key_order():
    original = row()

    reordered = dict(
        reversed(list(original.items()))
    )

    target, ledger = {}, {}

    process_batch(
        target, ledger, 1, [original]
    )

    result = process_batch(
        target, ledger, 1, [reordered]
    )

    assert result["status"] == "SKIPPED"


def test_15_validation_does_not_create_checkpoint():
    target, ledger = {}, {}

    with pytest.raises(BatchValidationError):
        process_batch(
            target,
            ledger,
            1,
            [
                row(),
                row(2, updated="bad"),
            ],
        )

    assert not target
    assert not ledger


def test_16_sql_temp_and_rollback():
    sql = SQL_FILE.read_text(
        encoding="utf-8"
    ).upper()

    assert sql.count("CREATE TEMP TABLE") == 2
    assert "SAVEPOINT" in sql
    assert "ROLLBACK TO SAVEPOINT" in sql
    assert sql.rstrip().endswith("ROLLBACK;")
    assert "DROP TABLE" not in sql


def test_17_full_simulation():
    state, checkpoints = run_python_demo()

    assert len(state) == 3
    assert set(checkpoints) == {101, 102}
    assert state[1][0] == "Rahul Updated"


def test_18_invalid_failure_position():
    with pytest.raises(BatchValidationError):
        process_batch(
            {},
            {},
            1,
            [row()],
            fail_after=2,
        )
