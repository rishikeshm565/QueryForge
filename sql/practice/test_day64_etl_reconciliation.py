
"""
QueryForge Day 64 - Automated Unit Tests

Tests use sample metrics only.
No database modifications.
"""

from pathlib import Path
import sys

import pytest


sys.path.insert(
    0,
    str(Path(__file__).resolve().parent),
)

from day64_etl_reconciliation import (
    QUERIES,
    assess,
    markdown_cell,
    render_report,
)


def valid_metrics():
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


def test_01_valid_reconciliation():
    status, failures, warnings = assess(
        valid_metrics()
    )

    assert status == "PASS"
    assert failures == []
    assert warnings == []


def test_02_empty_database():
    data = valid_metrics()

    data["registered_files"] = 0
    data["customer_rows"] = 0
    data["matched_rows"] = 0

    status, failures, warnings = assess(data)

    assert status == "NO DATA"
    assert failures == []
    assert warnings


def test_03_orphan_rows():
    data = valid_metrics()

    data["matched_rows"] = 2
    data["orphan_rows"] = 1

    status, failures, _ = assess(data)

    assert status == "FAIL"
    assert any("Orphan" in x for x in failures)


def test_04_duplicate_file_hash():
    data = valid_metrics()
    data["duplicate_file_hashes"] = 1

    status, failures, _ = assess(data)

    assert status == "FAIL"
    assert any("hash" in x for x in failures)


def test_05_duplicate_customer():
    data = valid_metrics()
    data["duplicate_customer_keys"] = 2

    status, failures, _ = assess(data)

    assert status == "FAIL"
    assert any("Duplicate customer" in x for x in failures)


def test_06_null_customer_id():
    data = valid_metrics()
    data["null_customer_ids"] = 1

    status, failures, _ = assess(data)

    assert status == "FAIL"
    assert any("NULL" in x for x in failures)


def test_07_reconciliation_mismatch():
    data = valid_metrics()
    data["matched_rows"] = 2

    status, failures, _ = assess(data)

    assert status == "FAIL"
    assert any("mismatch" in x for x in failures)


def test_08_empty_upload_warning():
    data = valid_metrics()
    data["empty_uploads"] = 1

    status, failures, warnings = assess(data)

    assert status == "PASS"
    assert failures == []
    assert warnings


def test_09_missing_metric():
    data = valid_metrics()
    del data["orphan_rows"]

    with pytest.raises(ValueError):
        assess(data)


def test_10_negative_metric():
    data = valid_metrics()
    data["customer_rows"] = -1

    with pytest.raises(ValueError):
        assess(data)


def test_11_queries_are_select_only():
    assert all(
        query.strip().split(maxsplit=1)[0].upper()
        == "SELECT"
        for query in QUERIES.values()
    )

    assert (
        len(QUERIES) == 8
    )


def test_12_markdown_report():
    data = valid_metrics()

    status, failures, warnings = assess(data)

    report = render_report(
        data,
        [
            (1, "customers.xlsx", 2),
            (2, "update.xlsx", 1),
        ],
        status,
        failures,
        warnings,
    )

    assert "Overall status: PASS" in report
    assert "registered_files" in report
    assert "customers.xlsx" in report
    assert "update.xlsx" in report


def test_13_markdown_escaping():
    assert (
        markdown_cell("a|b\nc")
        == "a\\|b c"
    )
