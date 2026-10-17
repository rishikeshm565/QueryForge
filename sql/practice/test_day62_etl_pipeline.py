
"""
QueryForge Day 62
Real PostgreSQL ETL integration tests.

Each test runs with an outer transaction.
Test database changes are rolled back.
"""

import uuid

import pandas as pd
import psycopg
import pytest

import day62_etl_pipeline as app

from day58_error_handling import (
    UploadValidationError
)


# ============================================================
# 1. DATABASE FIXTURE
# ============================================================

@pytest.fixture
def db():

    conn = psycopg.connect(
        **app.database_settings()
    )

    try:
        # Start an outer transaction.
        # Application transaction becomes a SAVEPOINT.
        conn.execute("SELECT 1")

        yield conn

    finally:
        conn.rollback()
        conn.close()


# ============================================================
# 2. TEMPORARY EXCEL GENERATOR
# ============================================================

@pytest.fixture
def make_excel(tmp_path):

    def make(
        *,
        credit=5000.25,
        invalid_email=False
    ):

        identifier = uuid.uuid4().hex

        path = tmp_path / (
            f"day62_{identifier}.xlsx"
        )

        df = pd.DataFrame({
            "customer_id": [
                62001,
                62002
            ],

            "customer_name": [
                "Asha Rao",
                "Imran Shah"
            ],

            "city": [
                "Hyderabad",
                "Mumbai"
            ],

            "email": [
                (
                    "wrong"
                    if invalid_email
                    else "asha@example.com"
                ),
                "imran@example.com"
            ],

            "credit_limit": [
                credit,
                7000.00
            ],
        })

        df.to_excel(
            path,
            index=False,
            engine="openpyxl"
        )

        return path

    return make


# ============================================================
# TEST 01 - VALID EXCEL
# ============================================================

def test_01_excel_read_and_validation(make_excel):

    name, digest, rows = app.load_excel(
        make_excel()
    )

    assert name.endswith(".xlsx")
    assert len(digest) == 64
    assert len(rows) == 2
    assert rows[0][0] == 62001


# ============================================================
# TEST 02 - MISSING FILE
# ============================================================

def test_02_missing_file_rejected(tmp_path):

    with pytest.raises(
        UploadValidationError
    ):

        app.load_excel(
            tmp_path / "missing.xlsx"
        )


# ============================================================
# TEST 03 - WRONG FILE EXTENSION
# ============================================================

def test_03_wrong_extension_rejected(tmp_path):

    path = tmp_path / "customers.csv"

    path.write_text(
        "hello",
        encoding="utf-8"
    )

    with pytest.raises(
        UploadValidationError
    ):

        app.load_excel(path)


# ============================================================
# TEST 04 - INVALID EMAIL
# ============================================================

def test_04_invalid_excel_rejected_before_insert(
    db,
    make_excel
):

    with pytest.raises(
        UploadValidationError
    ):

        app.ingest_excel(
            db,
            make_excel(invalid_email=True)
        )


# ============================================================
# TEST 05 - REAL INSERT AND ROLLBACK
# ============================================================

def test_05_actual_insert_and_rollback(
    db,
    make_excel
):

    path = make_excel()

    upload_id, count, digest = app.ingest_excel(
        db,
        path
    )

    assert count == 2

    result = db.execute(
        """
        SELECT COUNT(*)
        FROM etl.customer_upload_rows
        WHERE upload_id = %s
        """,
        (upload_id,)
    ).fetchone()[0]

    assert result == 2

    registry_count = db.execute(
        """
        SELECT COUNT(*)
        FROM etl.file_upload_registry
        WHERE file_hash = %s
        """,
        (digest,)
    ).fetchone()[0]

    assert registry_count == 1

    db.rollback()

    after_rollback = db.execute(
        """
        SELECT COUNT(*)
        FROM etl.file_upload_registry
        WHERE file_hash = %s
        """,
        (digest,)
    ).fetchone()[0]

    assert after_rollback == 0


# ============================================================
# TEST 06 - DUPLICATE FILE REJECTED
# ============================================================

def test_06_duplicate_file_blocked(
    db,
    make_excel
):

    path = make_excel()

    first_id, _, digest = app.ingest_excel(
        db,
        path
    )

    with pytest.raises(
        app.DuplicateUploadError
    ):

        app.ingest_excel(
            db,
            path
        )

    registry_count = db.execute(
        """
        SELECT COUNT(*)
        FROM etl.file_upload_registry
        WHERE file_hash = %s
        """,
        (digest,)
    ).fetchone()[0]

    assert registry_count == 1

    rows_count = db.execute(
        """
        SELECT COUNT(*)
        FROM etl.customer_upload_rows
        WHERE upload_id = %s
        """,
        (first_id,)
    ).fetchone()[0]

    assert rows_count == 2


# ============================================================
# TEST 07 - SAME IDS IN DIFFERENT UPLOADS
# ============================================================

def test_07_same_customer_ids_in_different_uploads(
    db,
    make_excel
):

    first = make_excel(
        credit=5000.25
    )

    second = make_excel(
        credit=6000.25
    )

    first_id, _, _ = app.ingest_excel(
        db,
        first
    )

    second_id, _, _ = app.ingest_excel(
        db,
        second
    )

    assert first_id != second_id

    result = db.execute(
        """
        SELECT COUNT(*)
        FROM etl.customer_upload_rows
        WHERE upload_id IN (%s, %s)
        """,
        (first_id, second_id)
    ).fetchone()[0]

    assert result == 4


# ============================================================
# TEST 08 - DATABASE FAILURE ROLLBACK
# ============================================================

def test_08_db_failure_rolls_back_registry_savepoint(
    db,
    make_excel,
    monkeypatch
):

    path = make_excel()

    _, digest, _ = app.load_excel(
        path
    )

    # Simulate a SQL error during customer row insertion.
    broken = app.INSERT_ROW_SQL.replace(
        "customer_name",
        "column_does_not_exist"
    )

    monkeypatch.setattr(
        app,
        "INSERT_ROW_SQL",
        broken
    )

    with pytest.raises(
        psycopg.errors.UndefinedColumn
    ):

        app.ingest_excel(
            db,
            path
        )

    # The registry insert must also have rolled back.
    result = db.execute(
        """
        SELECT COUNT(*)
        FROM etl.file_upload_registry
        WHERE file_hash = %s
        """,
        (digest,)
    ).fetchone()[0]

    assert result == 0
