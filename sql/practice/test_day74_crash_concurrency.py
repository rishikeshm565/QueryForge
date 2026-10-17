
"""Day 74 unit tests: all offline, no PostgreSQL mutation."""

from pathlib import Path

import pytest

from day74_crash_concurrency import (
    Day74Error,
    Progress,
    main,
    next_progress,
    write_report,
)


def test_01_batch_one():
    assert next_progress(
        Progress(4, 0, 0),
        [(2,), (3,)],
    ) == Progress(4, 2, 3)


def test_02_resume_final_batch():
    assert next_progress(
        Progress(4, 2, 3),
        [(4,), (7,)],
    ) == Progress(4, 4, 7, "COMPLETED")


def test_03_one_batch_completion():
    assert next_progress(
        Progress(1, 0, 0),
        [(9,)],
    ).status == "COMPLETED"


def test_04_empty_at_final_checkpoint():
    assert next_progress(
        Progress(2, 2, 6),
        [],
    ).status == "COMPLETED"


def test_05_empty_before_final_is_rejected():
    with pytest.raises(
        Day74Error,
        match="Missing source",
    ):
        next_progress(Progress(4, 2, 3), [])


def test_06_completed_not_extended():
    with pytest.raises(
        Day74Error,
        match="completed",
    ):
        next_progress(
            Progress(4, 4, 7, "COMPLETED"),
            [(9,)],
        )


def test_07_checkpoint_not_replayed():
    with pytest.raises(
        Day74Error,
        match="behind checkpoint",
    ):
        next_progress(
            Progress(4, 2, 3),
            [(3,)],
        )


def test_08_duplicate_source_rows_rejected():
    with pytest.raises(
        Day74Error,
        match="strictly increasing",
    ):
        next_progress(
            Progress(4, 0, 0),
            [(2,), (2,)],
        )


def test_09_unsorted_source_rows_rejected():
    with pytest.raises(
        Day74Error,
        match="strictly increasing",
    ):
        next_progress(
            Progress(4, 0, 0),
            [(4,), (2,)],
        )


def test_10_oversized_batch_rejected():
    with pytest.raises(
        Day74Error,
        match="exceeds",
    ):
        next_progress(
            Progress(2, 1, 2),
            [(3,), (4,)],
        )


@pytest.mark.parametrize(
    "bad_id",
    [0, -1, 2_147_483_648],
)
def test_11_invalid_upload_id(bad_id):
    assert main(
        [
            "--mode", "check",
            "--upload-id", str(bad_id),
        ]
    ) == 1


@pytest.mark.parametrize(
    "bad_size",
    [0, -1, 1001],
)
def test_12_invalid_batch_size(bad_size):
    assert main(
        [
            "--mode", "check",
            "--upload-id", "1",
            "--batch-size", str(bad_size),
        ]
    ) == 1


@pytest.mark.parametrize(
    "bad_hold",
    [-1, 3],
)
def test_13_invalid_hold_seconds(bad_hold):
    assert main(
        [
            "--mode", "check",
            "--upload-id", "1",
            "--hold-seconds", str(bad_hold),
        ]
    ) == 1


def test_14_cannot_make_report_while_processing(tmp_path):
    assert main(
        [
            "--mode", "worker",
            "--upload-id", "1",
            "--report", str(tmp_path / "result.md"),
        ]
    ) == 1


def test_15_report_counts_and_no_sensitive_rows(tmp_path):

    path = tmp_path / "report.md"

    state = dict(
        status="COMPLETED",
        snapshot=4,
        processed=4,
        stored=4,
        batches=2,
        last_row=7,
    )

    write_report(path, state, 1)

    content = path.read_text()

    assert "Stored rows: 4" in content
    assert "Committed batches: 2" in content
    assert "@example.com" not in content

    with pytest.raises(
        Day74Error,
        match="already exists",
    ):
        write_report(path, state, 1)


def test_16_no_report_before_completion(tmp_path):

    path = tmp_path / "report.md"

    with pytest.raises(
        Day74Error,
        match="incomplete",
    ):
        write_report(
            path,
            {"status": "RUNNING"},
            1,
        )

    assert not path.exists()


def test_17_isolated_schema_definition():

    sql = Path(__file__).with_name(
        "day74_crash_concurrency.sql"
    ).read_text()

    assert "CREATE SCHEMA IF NOT EXISTS qf_day74" in sql
    assert "REFERENCES qf_day72.file_uploads" in sql

    statements = "\n".join(
        ln
        for ln in sql.splitlines()
        if not ln.lstrip().startswith("--")
    ).upper()

    for forbidden in (
        "DROP TABLE",
        "TRUNCATE",
        "DELETE FROM",
        "UPDATE QF_DAY72",
    ):
        assert forbidden not in statements


def test_18_sql_checkpoint_and_unique_keys():

    sql = Path(__file__).with_name(
        "day74_crash_concurrency.sql"
    ).read_text()

    assert "UNIQUE (upload_id, customer_id)" in sql
    assert "PRIMARY KEY (upload_id, source_row)" in sql
    assert "processed_rows INTEGER" in sql
