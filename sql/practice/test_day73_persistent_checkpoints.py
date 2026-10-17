
"""Day 73 offline tests; no database connection required."""

import re
import sys
from pathlib import Path

import pytest

sys.path.insert(
    0,
    str(Path(__file__).resolve().parent),
)

from day73_persistent_checkpoints import (
    CheckpointError,
    State,
    advance,
    main,
    validate_options,
    write_report,
)


def test_01_initial_state():
    assert State(4) == State(4, 0, 0, "RUNNING")


def test_02_first_batch():
    assert advance(
        State(4),
        [(2,), (3,)],
    ) == State(4, 2, 3, "RUNNING")


def test_03_resume_remaining_batch():
    state = advance(
        State(4, 2, 3),
        [(4,), (7,)],
    )

    assert state == State(4, 4, 7, "COMPLETED")


def test_04_single_batch_completion():
    assert advance(
        State(2),
        [(2,), (6,)],
    ).status == "COMPLETED"


def test_05_no_rows_before_expected_is_error():
    with pytest.raises(
        CheckpointError,
        match="missing",
    ):
        advance(State(3, 2, 3), [])


def test_06_empty_final_page_can_complete():
    state = advance(State(2, 2, 3), [])

    assert state.status == "COMPLETED"


def test_07_duplicate_source_position_is_error():
    with pytest.raises(
        CheckpointError,
        match="strictly increasing",
    ):
        advance(State(4), [(2,), (2,)])


def test_08_unsorted_batch_is_error():
    with pytest.raises(
        CheckpointError,
        match="strictly increasing",
    ):
        advance(State(4), [(3,), (2,)])


def test_09_position_behind_checkpoint_is_error():
    with pytest.raises(
        CheckpointError,
        match="backwards",
    ):
        advance(State(4, 2, 5), [(5,)])


def test_10_batch_cannot_exceed_expected_count():
    with pytest.raises(
        CheckpointError,
        match="exceeds",
    ):
        advance(
            State(2, 1, 2),
            [(3,), (4,)],
        )


def test_11_completed_job_cannot_accept_rows():
    with pytest.raises(
        CheckpointError,
        match="completed",
    ):
        advance(
            State(2, 2, 3, "COMPLETED"),
            [(4,)],
        )


@pytest.mark.parametrize(
    "upload_id",
    [0, -1, 2_147_483_648],
)
def test_12_invalid_upload_id(upload_id):
    with pytest.raises(
        CheckpointError,
        match="upload_id",
    ):
        validate_options(upload_id, 2)


@pytest.mark.parametrize(
    "size",
    [0, -1, 1001],
)
def test_13_invalid_batch_size(size):
    with pytest.raises(
        CheckpointError,
        match="batch_size",
    ):
        validate_options(1, size)


def test_14_valid_options():
    validate_options(1, 1000)


def test_15_report_contains_only_metadata_and_refuses_overwrite(
    tmp_path,
):
    path = tmp_path / "report.md"

    details = dict(
        upload_id=1,
        status="COMPLETED",
        expected_rows=4,
        processed_rows=4,
        stored_rows=4,
        batch_count=2,
        last_source_row=7,
    )

    write_report(path, details)

    content = path.read_text(encoding="utf-8")

    assert "Processed rows: 4" in content
    assert "COMPLETED" in content
    assert "customer@example.com" not in content

    with pytest.raises(
        CheckpointError,
        match="already exists",
    ):
        write_report(path, details)


def test_16_schema_no_destructive_sql():
    ddl = Path(__file__).with_name(
        "day73_persistent_checkpoints.sql"
    ).read_text()

    statements = "\n".join(
        line
        for line in ddl.splitlines()
        if not line.lstrip().startswith("--")
    )

    assert re.search(
        r"\b(DROP|TRUNCATE|DELETE|UPDATE)\b",
        statements,
        re.I,
    ) is None

    assert (
        "CREATE SCHEMA IF NOT EXISTS qf_day73"
        in statements
    )

    assert (
        "REFERENCES qf_day72.file_uploads"
        in statements
    )


def test_17_invalid_report_mode_returns_failure_without_db(
    tmp_path,
):
    assert main(
        [
            "--upload-id",
            "1",
            "--run",
            "--report",
            str(tmp_path / "report.md"),
        ]
    ) == 1
