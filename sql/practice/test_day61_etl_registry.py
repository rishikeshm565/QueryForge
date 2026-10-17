
"""
QueryForge - Day 61
Real PostgreSQL ETL Registry Integration Tests

All test inserts are rolled back.
Explicit test IDs avoid advancing the identity sequence.
Do not run against production without approval.
"""

import hashlib
import os
import uuid
from pathlib import Path

import psycopg
import pytest
from dotenv import load_dotenv


load_dotenv(
    dotenv_path=Path.cwd() / ".env"
)


# ============================================================
# 1. DATABASE CONNECTION
# ============================================================

@pytest.fixture
def db():

    conn = psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv(
            "DB_NAME", "queryforge_dev"
        ),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
    )

    try:
        yield conn

    finally:
        conn.rollback()
        conn.close()


# ============================================================
# 2. TEST CORRECT DATABASE
# ============================================================

def test_01_correct_database(db):

    with db.cursor() as cur:
        cur.execute(
            "SELECT current_database()"
        )

        result = cur.fetchone()[0]

    assert result == "queryforge_dev"


# ============================================================
# 3. TEST REGISTRY STRUCTURE
# ============================================================

def test_02_registry_structure(db):

    with db.cursor() as cur:

        cur.execute("""
            SELECT column_name, data_type,
                   is_nullable, is_identity
            FROM information_schema.columns
            WHERE table_schema = 'etl'
              AND table_name = 'file_upload_registry'
        """)

        rows = cur.fetchall()

    actual = {
        row[0]: row[1:]
        for row in rows
    }

    expected = {
        "upload_id": ("bigint", "NO", "YES"),
        "file_name": ("text", "NO", "NO"),
        "file_hash": ("text", "NO", "NO"),
        "uploaded_at": (
            "timestamp with time zone",
            "NO",
            "NO",
        ),
    }

    assert actual == expected


# ============================================================
# 4. VERIFY PRIMARY KEY AND UNIQUE CONSTRAINT
# ============================================================

def test_03_registry_constraints(db):

    with db.cursor() as cur:

        cur.execute("""
            SELECT contype, pg_get_constraintdef(oid)
            FROM pg_constraint
            WHERE conrelid =
                'etl.file_upload_registry'::regclass
        """)

        constraints = cur.fetchall()

    definitions = {
        definition
        for _, definition in constraints
    }

    assert any(
        x.startswith("PRIMARY KEY (upload_id)")
        for x in definitions
    )

    assert any(
        x.startswith("UNIQUE (file_hash)")
        for x in definitions
    )


# ============================================================
# 5. VERIFY EXISTING HASHES HAVE NO DUPLICATES
# ============================================================

def test_04_no_duplicate_hashes(db):

    with db.cursor() as cur:

        cur.execute("""
            SELECT COUNT(*)
            FROM (
                SELECT file_hash
                FROM etl.file_upload_registry
                GROUP BY file_hash
                HAVING COUNT(*) > 1
            ) AS duplicates
        """)

        result = cur.fetchone()[0]

    assert result == 0


# ============================================================
# 6. REAL INSERT AND ROLLBACK
# ============================================================

def make_test_record():

    token = uuid.uuid4()

    file_name = (
        f"day61_{token.hex}.xlsx"
    )

    file_hash = hashlib.sha256(
        file_name.encode("utf-8")
    ).hexdigest()

    # Explicit negative ID - identity sequence unchanged.
    upload_id = -(
        token.int % 9_000_000_000_000_000_000
    ) - 1

    return upload_id, file_name, file_hash


def insert_test_record(db, record):

    with db.cursor() as cur:

        cur.execute("""
            INSERT INTO etl.file_upload_registry
                (upload_id, file_name, file_hash)
            OVERRIDING SYSTEM VALUE
            VALUES (%s, %s, %s)
            RETURNING upload_id
        """, record)

        return cur.fetchone()[0]


def test_05_insert_and_rollback(db):

    record = make_test_record()

    result = insert_test_record(
        db, record
    )

    assert result == record[0]

    with db.cursor() as cur:

        cur.execute("""
            SELECT COUNT(*)
            FROM etl.file_upload_registry
            WHERE file_hash = %s
        """, (record[2],))

        assert cur.fetchone()[0] == 1

    db.rollback()

    with db.cursor() as cur:

        cur.execute("""
            SELECT COUNT(*)
            FROM etl.file_upload_registry
            WHERE file_hash = %s
        """, (record[2],))

        assert cur.fetchone()[0] == 0


# ============================================================
# 7. DUPLICATE FILE HASH TEST
# ============================================================

def test_06_duplicate_hash_rejected(db):

    first = make_test_record()

    insert_test_record(db, first)

    second = make_test_record()

    duplicate = (
        second[0],
        second[1],
        first[2],
    )

    with db.cursor() as cur:

        cur.execute(
            "SAVEPOINT day61_duplicate_test"
        )

        with pytest.raises(
            psycopg.errors.UniqueViolation
        ):
            cur.execute("""
                INSERT INTO etl.file_upload_registry
                    (upload_id, file_name, file_hash)
                OVERRIDING SYSTEM VALUE
                VALUES (%s, %s, %s)
            """, duplicate)

        cur.execute(
            "ROLLBACK TO SAVEPOINT day61_duplicate_test"
        )

    db.rollback()

    with db.cursor() as cur:

        cur.execute("""
            SELECT COUNT(*)
            FROM etl.file_upload_registry
            WHERE file_hash = %s
        """, (first[2],))

        assert cur.fetchone()[0] == 0
