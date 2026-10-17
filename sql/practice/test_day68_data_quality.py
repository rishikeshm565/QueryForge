
"""QueryForge Day 68 unit tests."""

from decimal import Decimal

import pandas as pd
import pytest

from day68_data_quality import (
    DataQualityError,
    SQL_FILE,
    audit_dataframe,
    sample_data,
)


def make_row(
    cid=1,
    name="Rahul",
    city="Hyderabad",
    email="rahul@example.com",
    credit="50000",
):
    return {
        "customer_id": cid,
        "customer_name": name,
        "city": city,
        "email": email,
        "credit_limit": credit,
    }


def run(*rows):
    return audit_dataframe(
        pd.DataFrame(list(rows))
    )


def test_01_valid_row():
    result = run(make_row())

    assert result.total == 1
    assert len(result.accepted) == 1


def test_02_missing_id():
    result = run(make_row(cid=None))

    assert "missing_or_invalid_id" in (
        result.quarantined[0]["reasons"]
    )


def test_03_duplicate_both_rejected():
    result = run(
        make_row(),
        make_row(),
    )

    assert len(result.quarantined) == 2
    assert (
        result.reason_counts["duplicate_customer_id"]
        == 2
    )


def test_04_invalid_email():
    result = run(
        make_row(email="bad")
    )

    assert "invalid_email" in (
        result.quarantined[0]["reasons"]
    )


def test_05_negative_credit():
    result = run(
        make_row(credit="-1")
    )

    assert "negative_credit_limit" in (
        result.quarantined[0]["reasons"]
    )


def test_06_non_numeric_credit():
    result = run(
        make_row(credit="abc")
    )

    assert "invalid_credit_limit" in (
        result.quarantined[0]["reasons"]
    )


def test_07_outlier():
    result = run(
        make_row(credit="1000001")
    )

    assert "credit_limit_outlier" in (
        result.quarantined[0]["reasons"]
    )


def test_08_blank_name():
    result = run(
        make_row(name="   ")
    )

    assert "blank_customer_name" in (
        result.quarantined[0]["reasons"]
    )


def test_09_blank_city():
    result = run(
        make_row(city=" ")
    )

    assert "blank_city" in (
        result.quarantined[0]["reasons"]
    )


def test_10_missing_column():
    df = pd.DataFrame(
        [make_row()]
    ).drop(columns=["email"])

    with pytest.raises(DataQualityError):
        audit_dataframe(df)


def test_11_credit_two_decimals():
    result = run(
        make_row(credit="250.75")
    )

    assert (
        result.accepted[0]["credit_limit"]
        == Decimal("250.75")
    )

    invalid = run(
        make_row(credit="250.755")
    )

    assert "invalid_credit_limit" in (
        invalid.quarantined[0]["reasons"]
    )


def test_12_original_data_not_changed():
    df = pd.DataFrame([
        make_row(name=" Rahul ")
    ])

    audit_dataframe(df)

    assert (
        df.iloc[0]["customer_name"]
        == " Rahul "
    )


def test_13_sample_totals():
    result = audit_dataframe(
        sample_data()
    )

    assert result.total == 10
    assert len(result.accepted) == 2
    assert len(result.quarantined) == 8
    assert (
        result.reason_counts["duplicate_customer_id"]
        == 2
    )


def test_14_sql_has_rollback_and_temp_tables():
    sql = SQL_FILE.read_text(
        encoding="utf-8"
    ).upper()

    assert sql.count("CREATE TEMP TABLE") == 3
    assert "ROLLBACK;" in sql
    assert "DROP TABLE" not in sql


def test_15_empty_dataframe():
    df = pd.DataFrame(
        columns=list(make_row())
    )

    result = audit_dataframe(df)

    assert result.total == 0
