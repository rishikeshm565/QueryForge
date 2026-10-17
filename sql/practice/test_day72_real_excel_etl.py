
"""Day 72 offline unit tests: no database writes."""

import sys
from decimal import Decimal
from pathlib import Path

import pandas as pd
import pytest

sys.path.insert(
    0,
    str(Path(__file__).resolve().parent),
)

from day72_real_excel_etl import (
    ETLError,
    REQUIRED,
    file_hash,
    make_sample,
    parse_credit,
    parse_id,
    read_workbook,
    validate_rows,
    main,
)


def valid_frame():

    return pd.DataFrame(
        [
            (
                1, "Asha", "Hyderabad",
                "asha@example.com", 25000
            ),
            (
                2, "Rahul", "Mumbai",
                "rahul@example.com", 30000
            ),
        ],
        columns=REQUIRED,
    )


def test_01_two_accepted():

    ok, bad = validate_rows(valid_frame())

    assert len(ok) == 2
    assert not bad


def test_02_missing_email_column():

    df = valid_frame().drop(columns=["email"])

    with pytest.raises(
        ETLError,
        match="Missing columns",
    ):
        validate_rows(df)


def test_03_empty_file():

    df = valid_frame().iloc[:0]

    with pytest.raises(
        ETLError,
        match="no customer rows",
    ):
        validate_rows(df)


def test_04_duplicate_id_quarantined():

    df = valid_frame()
    df.loc[1, "customer_id"] = 1

    ok, bad = validate_rows(df)

    assert len(ok) == 1
    assert bad[0][1] == "duplicate_customer_id_in_file"


def test_05_invalid_email_quarantined():

    df = valid_frame()
    df.loc[0, "email"] = "bad"

    ok, bad = validate_rows(df)

    assert len(ok) == 1
    assert bad[0][1] == "invalid_email"


def test_06_negative_credit_quarantined():

    df = valid_frame()
    df.loc[0, "credit_limit"] = -1

    ok, bad = validate_rows(df)

    assert len(ok) == 1
    assert bad[0][1] == "invalid_credit_limit"


def test_07_blank_city_quarantined():

    df = valid_frame()
    df.loc[0, "city"] = " "

    ok, bad = validate_rows(df)

    assert len(ok) == 1
    assert bad[0][1] == "invalid_city"


def test_08_invalid_customer_id():

    with pytest.raises(
        ValueError,
        match="invalid_customer_id",
    ):
        parse_id("10.5")


def test_09_large_customer_id():

    with pytest.raises(
        ValueError,
        match="invalid_customer_id",
    ):
        parse_id("9999999999999999")


def test_10_credit_exact_two_decimals():

    assert parse_credit("12.30") == Decimal("12.30")

    with pytest.raises(
        ValueError,
        match="invalid_credit_limit",
    ):
        parse_credit("12.345")


def test_11_missing_file(tmp_path):

    with pytest.raises(
        ETLError,
        match="Missing Excel file",
    ):
        read_workbook(tmp_path / "missing.xlsx")


def test_12_reject_wrong_extension(tmp_path):

    bad_file = tmp_path / "data.csv"
    bad_file.write_text("data")

    with pytest.raises(
        ETLError,
        match="Only .xlsx",
    ):
        read_workbook(bad_file)


def test_13_generate_and_validate_real_xlsx(tmp_path):

    path = tmp_path / "demo.xlsx"

    make_sample(path)

    ok, bad = validate_rows(read_workbook(path))

    assert (len(ok), len(bad)) == (4, 2)


def test_14_refuse_sample_overwrite(tmp_path):

    path = tmp_path / "demo.xlsx"

    make_sample(path)

    with pytest.raises(
        ETLError,
        match="Refusing to overwrite",
    ):
        make_sample(path)


def test_15_file_sha256(tmp_path):

    path = tmp_path / "test.txt"

    path.write_bytes(b"abc")

    assert file_hash(path) == (
        "ba7816bf8f01cfea414140de5dae2223"
        "b00361a396177a9cb410ff61f20015ad"
    )


def test_16_dry_run_creates_report_without_db(tmp_path):

    source = tmp_path / "demo.xlsx"

    make_sample(source)

    report_path = tmp_path / "report.md"

    assert main(
        [
            "--file",
            str(source),
            "--report",
            str(report_path),
        ]
    ) == 0

    content = report_path.read_text(
        encoding="utf-8"
    )

    assert "VALIDATED_ONLY" in content
    assert "Accepted: 4" in content
    assert "Rejected: 2" in content


def test_17_reject_all_invalid_without_db(tmp_path):

    path = tmp_path / "invalid.xlsx"

    frame = valid_frame()

    frame["email"] = "bad"

    frame.to_excel(path, index=False)

    assert main(
        ["--file", str(path)]
    ) == 1
