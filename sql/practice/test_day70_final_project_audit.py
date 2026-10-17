
"""Database-independent verification of Day 70 audit logic."""

from decimal import Decimal
import re

import pytest

import day70_final_project_audit as audit


def complete_counts():

    result = {
        name: 0
        for name in audit.TABLE_KINDS
    }

    for name in audit.MUST_HAVE_ROWS:
        result[name] = 10

    return result


def test_01_expected_database():
    assert audit.EXPECTED_DB == "queryforge_dev"


def test_02_all_required_relations_defined():
    assert len(audit.TABLE_KINDS) == 11


def test_03_required_partitioned_parent():
    assert (
        audit.TABLE_KINDS["scale.orders_partitioned"]
        == "p"
    )


def test_04_required_materialized_view():
    assert (
        audit.TABLE_KINDS[
            "analytics.mv_monthly_order_summary"
        ]
        == "m"
    )


def test_05_complete_counts_pass():
    assert audit.check_counts(complete_counts()) == []


def test_06_missing_relation_fails():

    counts = complete_counts()
    counts.pop("core.customer_master")

    assert any(
        "core.customer_master" in x
        for x in audit.check_counts(counts)
    )


def test_07_empty_training_table_fails():

    counts = complete_counts()
    counts["scale.customers_big"] = 0

    assert any(
        "scale.customers_big" in x
        for x in audit.check_counts(counts)
    )


def test_08_zero_upload_rows_allowed():

    counts = complete_counts()

    assert counts["etl.customer_upload_rows"] == 0
    assert audit.check_counts(counts) == []


def test_09_negative_rowcount_fails():

    counts = complete_counts()
    counts["core.customer_master"] = -1

    assert audit.check_counts(counts)


def test_10_correct_partitions_pass():

    assert audit.check_partition_names(
        set(audit.EXPECTED_PARTITIONS)
    ) == []


def test_11_missing_partition_fails():

    names = (
        set(audit.EXPECTED_PARTITIONS)
        - {"orders_2025"}
    )

    assert audit.check_partition_names(names)


def test_12_extra_partition_fails():

    names = (
        set(audit.EXPECTED_PARTITIONS)
        | {"orders_2027"}
    )

    assert audit.check_partition_names(names)


def test_13_matview_equal():

    assert audit.check_summary(
        10,
        10,
        Decimal("2.50"),
        Decimal("2.50"),
    ) == []


def test_14_matview_count_mismatch():

    assert audit.check_summary(
        10,
        9,
        Decimal("2.50"),
        Decimal("2.50"),
    )


def test_15_matview_amount_mismatch():

    assert audit.check_summary(
        10,
        10,
        Decimal("2.50"),
        Decimal("2.49"),
    )


def test_16_status_pass():

    assert audit.report_status([], []) == "PASS"


def test_17_status_warning():

    assert (
        audit.report_status([], ["pending"])
        == "PASS WITH WARNINGS"
    )


def test_18_status_failure_priority():

    assert (
        audit.report_status(
            ["failure"],
            ["pending"],
        )
        == "FAIL"
    )


def test_19_report_contents(
    tmp_path,
    monkeypatch,
):

    monkeypatch.setattr(
        audit,
        "REPORT_PATH",
        tmp_path / "report.md",
    )

    result = {
        "database": audit.EXPECTED_DB,
        "counts": complete_counts(),
        "partition_key": "RANGE (order_date)",
        "partitions": sorted(
            audit.EXPECTED_PARTITIONS
        ),
        "unique_mv_index": True,
        "summary": (
            10,
            10,
            Decimal("99.00"),
            Decimal("99.00"),
        ),
        "warnings": [
            "Real uploads not tested"
        ],
        "failures": [],
        "status": "PASS WITH WARNINGS",
    }

    report = audit.write_report(
        result
    ).read_text(
        encoding="utf-8"
    )

    assert "PASS WITH WARNINGS" in report
    assert "READ ONLY" in report
    assert "Real uploads not tested" in report
    assert "scale.orders_partitioned" in report
    assert "Production" not in report


def test_20_sql_read_only_and_rollback():

    sql_text = (
        audit.Path(__file__)
        .with_name(
            "day70_final_project_audit.sql"
        )
        .read_text(
            encoding="utf-8"
        )
    )

    upper = sql_text.upper().strip()

    assert upper.startswith(
        "BEGIN TRANSACTION READ ONLY;"
    )

    assert upper.endswith("ROLLBACK;")

    assert "TRANSACTION_READ_ONLY" in upper

    assert not re.search(
        r"\b(?:INSERT|UPDATE|DELETE|DROP|TRUNCATE|CREATE|ALTER|REFRESH|VACUUM)\b",
        upper,
    )
