
"""
QueryForge - Day 59: Automated Testing with Pytest

Tests Day 58 Excel validation, file hashing,
database registry and upload error handling.

IMPORTANT:
Database operations are mocked.
No real PostgreSQL data will be modified.
"""

import hashlib
from unittest.mock import MagicMock, Mock

import pandas as pd
import pytest

import day58_error_handling as app


# ============================================================
# 1. PYTEST FIXTURES
# ============================================================

@pytest.fixture
def valid_df():
    """Create fresh customer test data for every test."""

    return pd.DataFrame({
        "customer_id": [1, 2],
        "customer_name": ["Rahul", "Meera"],
        "city": ["Hyderabad", "Mumbai"],
        "email": [
            "rahul@example.com",
            "meera@example.com",
        ],
        "credit_limit": [50000, 60000],
    })


@pytest.fixture
def fake_connection():
    """Mock a database connection without using PostgreSQL."""

    conn = MagicMock()

    cursor = (
        conn.cursor.return_value
        .__enter__.return_value
    )

    return conn, cursor


# ============================================================
# 2. CUSTOMER DATA VALIDATION
# ============================================================

def test_valid_data_passes(valid_df):

    assert app.validate_dataframe(valid_df) is None


@pytest.mark.parametrize(
    "column",
    sorted(app.REQUIRED_COLUMNS)
)
def test_required_column_missing(valid_df, column):

    df = valid_df.drop(columns=[column])

    with pytest.raises(
        app.UploadValidationError,
        match="Missing required columns"
    ):
        app.validate_dataframe(df)


def test_empty_dataframe_fails(valid_df):

    df = valid_df.iloc[:0]

    with pytest.raises(
        app.UploadValidationError,
        match="no data rows"
    ):
        app.validate_dataframe(df)


def test_duplicate_customer_id_fails(valid_df):

    valid_df.loc[1, "customer_id"] = 1

    with pytest.raises(
        app.UploadValidationError,
        match="Duplicate customer_id"
    ):
        app.validate_dataframe(valid_df)


@pytest.mark.parametrize(
    "bad_id",
    [0, -1, 1.5, "ABC", None, float("inf")]
)
def test_bad_customer_id_fails(valid_df, bad_id):

    valid_df["customer_id"] = (
        valid_df["customer_id"].astype(object)
    )

    valid_df.loc[0, "customer_id"] = bad_id

    with pytest.raises(
        app.UploadValidationError,
        match="customer_id"
    ):
        app.validate_dataframe(valid_df)


@pytest.mark.parametrize(
    "column",
    ["customer_name", "city", "email"]
)
@pytest.mark.parametrize(
    "blank",
    ["   ", None]
)
def test_required_text_blank_fails(
    valid_df,
    column,
    blank
):

    valid_df.loc[0, column] = blank

    with pytest.raises(
        app.UploadValidationError,
        match="Blank"
    ):
        app.validate_dataframe(valid_df)


@pytest.mark.parametrize(
    "bad_email",
    [
        "wrong-email",
        "person@",
        "a@b",
        "@example.com",
    ]
)
def test_invalid_email_fails(valid_df, bad_email):

    valid_df.loc[0, "email"] = bad_email

    with pytest.raises(
        app.UploadValidationError,
        match="Invalid email"
    ):
        app.validate_dataframe(valid_df)


@pytest.mark.parametrize(
    "bad_credit",
    [
        -1,
        "abc",
        None,
        float("inf"),
        float("-inf"),
    ]
)
def test_invalid_credit_fails(
    valid_df,
    bad_credit
):

    valid_df["credit_limit"] = (
        valid_df["credit_limit"].astype(object)
    )

    valid_df.loc[0, "credit_limit"] = bad_credit

    with pytest.raises(
        app.UploadValidationError,
        match="credit_limit"
    ):
        app.validate_dataframe(valid_df)


def test_zero_credit_is_allowed(valid_df):

    valid_df.loc[0, "credit_limit"] = 0

    app.validate_dataframe(valid_df)


# ============================================================
# 3. EXCEL FILE VALIDATION
# ============================================================

def test_valid_excel_can_be_read(tmp_path, valid_df):

    path = tmp_path / "customers.xlsx"

    valid_df.to_excel(path, index=False)

    result = app.read_excel_safe(str(path))

    assert len(result) == 2

    assert set(app.REQUIRED_COLUMNS).issubset(
        result.columns
    )


def test_missing_excel_is_rejected(tmp_path):

    path = tmp_path / "not_found.xlsx"

    with pytest.raises(
        app.UploadValidationError,
        match="does not exist"
    ):
        app.read_excel_safe(str(path))


def test_wrong_extension_is_rejected(tmp_path):

    path = tmp_path / "customers.csv"

    path.write_text(
        "customer_id\n1",
        encoding="utf-8"
    )

    with pytest.raises(
        app.UploadValidationError,
        match="xlsx"
    ):
        app.read_excel_safe(str(path))


def test_corrupt_excel_is_rejected(tmp_path):

    path = tmp_path / "bad.xlsx"

    path.write_bytes(
        b"not a valid Excel workbook"
    )

    with pytest.raises(
        app.UploadValidationError,
        match="could not be read"
    ):
        app.read_excel_safe(str(path))


# ============================================================
# 4. SHA256 FILE HASH VALIDATION
# ============================================================

def test_file_hash_is_sha256(tmp_path):

    path = tmp_path / "sample.xlsx"

    path.write_bytes(
        b"QueryForge Day 59"
    )

    expected = hashlib.sha256(
        path.read_bytes()
    ).hexdigest()

    actual = app.calculate_file_hash(
        str(path)
    )

    assert actual == expected

    assert len(actual) == 64


def test_missing_file_cannot_be_hashed(tmp_path):

    path = tmp_path / "missing.xlsx"

    with pytest.raises(
        app.UploadValidationError,
        match="Cannot hash file"
    ):
        app.calculate_file_hash(str(path))


# ============================================================
# 5. DATABASE REGISTRY MOCK TESTS
# ============================================================

def test_registry_setup_does_not_commit_early(
    fake_connection
):

    conn, cursor = fake_connection

    app.create_upload_registry(conn)

    assert cursor.execute.call_count == 2

    conn.commit.assert_not_called()


def test_register_file_success(fake_connection):

    conn, cursor = fake_connection

    cursor.fetchone.return_value = (123,)

    result = app.register_file(
        conn,
        "sample.xlsx",
        "sample_hash"
    )

    assert result == 123

    sql, params = cursor.execute.call_args.args

    assert "ON CONFLICT" in sql

    assert params == (
        "sample.xlsx",
        "sample_hash"
    )

    conn.commit.assert_not_called()


def test_register_duplicate_is_rejected(
    fake_connection
):

    conn, cursor = fake_connection

    cursor.fetchone.return_value = None

    with pytest.raises(
        app.UploadValidationError,
        match="Duplicate file upload"
    ):
        app.register_file(
            conn,
            "sample.xlsx",
            "same_hash"
        )


# ============================================================
# 6. COMPLETE UPLOAD WORKFLOW TESTS
# ============================================================

def test_upload_success_without_real_database(
    monkeypatch,
    valid_df,
    capsys
):

    conn = MagicMock()

    connect = Mock(return_value=conn)

    setup = Mock()

    register = Mock(return_value=81)

    hashes = iter([
        "same_hash",
        "same_hash"
    ])

    monkeypatch.setattr(
        app,
        "calculate_file_hash",
        lambda _: next(hashes)
    )

    monkeypatch.setattr(
        app,
        "read_excel_safe",
        lambda _: valid_df
    )

    monkeypatch.setattr(
        app,
        "connect_db",
        connect
    )

    monkeypatch.setattr(
        app,
        "create_upload_registry",
        setup
    )

    monkeypatch.setattr(
        app,
        "register_file",
        register
    )

    result = app.process_upload(
        "sample.xlsx"
    )

    assert result == 0

    assert "Upload ID: 81" in (
        capsys.readouterr().out
    )

    connect.assert_called_once()

    setup.assert_called_once_with(
        conn.__enter__.return_value
    )

    register.assert_called_once_with(
        conn.__enter__.return_value,
        "sample.xlsx",
        "same_hash"
    )


def test_invalid_upload_never_connects(monkeypatch):

    connect = Mock()

    monkeypatch.setattr(
        app,
        "calculate_file_hash",
        lambda _: "hash"
    )

    def reject(_):
        raise app.UploadValidationError(
            "invalid workbook"
        )

    monkeypatch.setattr(
        app,
        "read_excel_safe",
        reject
    )

    monkeypatch.setattr(
        app,
        "connect_db",
        connect
    )

    result = app.process_upload(
        "invalid.xlsx"
    )

    assert result == 2

    connect.assert_not_called()


def test_database_failure_returns_code_3(
    monkeypatch,
    valid_df
):

    monkeypatch.setattr(
        app,
        "calculate_file_hash",
        lambda _: "same"
    )

    monkeypatch.setattr(
        app,
        "read_excel_safe",
        lambda _: valid_df
    )

    def fail_connection():
        raise app.DatabaseOperationError(
            "offline"
        )

    monkeypatch.setattr(
        app,
        "connect_db",
        fail_connection
    )

    assert app.process_upload(
        "sample.xlsx"
    ) == 3


def test_changed_file_is_rejected_before_database(
    monkeypatch,
    valid_df
):

    hashes = iter([
        "before",
        "after"
    ])

    connect = Mock()

    monkeypatch.setattr(
        app,
        "calculate_file_hash",
        lambda _: next(hashes)
    )

    monkeypatch.setattr(
        app,
        "read_excel_safe",
        lambda _: valid_df
    )

    monkeypatch.setattr(
        app,
        "connect_db",
        connect
    )

    assert app.process_upload(
        "changed.xlsx"
    ) == 2

    connect.assert_not_called()


def test_unexpected_error_returns_code_4(
    monkeypatch
):

    def fail_hash(_):
        raise RuntimeError("unexpected")

    monkeypatch.setattr(
        app,
        "calculate_file_hash",
        fail_hash
    )

    assert app.process_upload(
        "sample.xlsx"
    ) == 4
