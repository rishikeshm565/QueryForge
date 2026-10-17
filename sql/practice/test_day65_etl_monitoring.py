
"""
QueryForge Day 65
Automated monitoring tests.

No database modifications.
"""

from pathlib import Path
import sys
import json

import pytest


sys.path.insert(
    0,
    str(Path(__file__).resolve().parent),
)

from day65_etl_monitoring import (
    evaluate,
    make_report,
    read_snapshot,
    write_snapshot,
)


def sample():
    return {
        "registered_files": 2,
        "customer_rows": 3,
        "matched_rows": 3,
        "orphan_rows": 0,
        "duplicate_file_hashes": 0,
        "duplicate_customer_keys": 0,
        "null_customer_ids": 0,
        "empty_uploads": 0,
    }


def test_01_first_audit_pass():
    assert evaluate(sample(), None)[0] == "PASS"


def test_02_no_data_is_not_failure():
    data = {
        key: 0
        for key in sample()
    }

    level, failures, warnings = evaluate(
        data,
        None,
    )

    assert level == "NO DATA"
    assert not failures
    assert warnings


def test_03_orphan_is_failure():
    data = sample()

    data["orphan_rows"] = 1
    data["matched_rows"] = 2

    assert evaluate(data, None)[0] == "FAIL"


def test_04_file_count_decrease_is_failure():
    previous = {
        "registered_files": 3,
        "customer_rows": 3,
    }

    assert evaluate(
        sample(),
        previous,
    )[0] == "FAIL"


def test_05_row_count_decrease_is_failure():
    previous = {
        "registered_files": 2,
        "customer_rows": 4,
    }

    assert evaluate(
        sample(),
        previous,
    )[0] == "FAIL"


def test_06_empty_upload_is_warning():
    data = sample()
    data["empty_uploads"] = 1

    assert evaluate(data, None)[0] == "WARN"


def test_07_rows_increased_without_file_warn():
    data = sample()

    data["customer_rows"] = 4
    data["matched_rows"] = 4

    previous = {
        "registered_files": 2,
        "customer_rows": 3,
    }

    assert evaluate(
        data,
        previous,
    )[0] == "WARN"


def test_08_normal_new_file_and_rows_pass():
    data = sample()

    data["registered_files"] = 3
    data["customer_rows"] = 4
    data["matched_rows"] = 4

    previous = {
        "registered_files": 2,
        "customer_rows": 3,
    }

    assert evaluate(
        data,
        previous,
    )[0] == "PASS"


def test_09_negative_value_rejected():
    data = sample()
    data["customer_rows"] = -1

    with pytest.raises(ValueError):
        evaluate(data, None)


def test_10_snapshot_roundtrip(tmp_path):
    path = tmp_path / "snapshot.json"

    assert read_snapshot(path) is None

    write_snapshot(
        path,
        sample(),
    )

    assert read_snapshot(path) == {
        "registered_files": 2,
        "customer_rows": 3,
    }


def test_11_bad_json_rejected(tmp_path):
    path = tmp_path / "snapshot.json"

    path.write_text(
        "{broken",
        encoding="utf-8",
    )

    with pytest.raises(ValueError):
        read_snapshot(path)


def test_12_bad_snapshot_version_rejected(tmp_path):
    path = tmp_path / "snapshot.json"

    path.write_text(
        json.dumps({
            "version": 99,
            "metrics": {},
        }),
        encoding="utf-8",
    )

    with pytest.raises(ValueError):
        read_snapshot(path)


def test_13_report_contains_status_and_deltas():
    data = sample()

    previous = {
        "registered_files": 1,
        "customer_rows": 1,
    }

    report = make_report(
        data,
        previous,
        "PASS",
        [],
        [],
    )

    assert "Status: PASS" in report

    assert (
        "| registered_files | 1 | 2 | +1 |"
        in report
    )

    assert (
        "| customer_rows | 1 | 3 | +2 |"
        in report
    )


def test_14_invalid_previous_metric_rejected():
    previous = {
        "registered_files": -1,
        "customer_rows": 3,
    }

    with pytest.raises(ValueError):
        evaluate(
            sample(),
            previous,
        )


def test_15_same_counts_pass():
    previous = {
        "registered_files": 2,
        "customer_rows": 3,
    }

    assert evaluate(
        sample(),
        previous,
    )[0] == "PASS"
