
"""Day 75 offline safety tests. No database writes."""

from datetime import datetime, timezone
from pathlib import Path
import hashlib
import inspect

import pytest

import day75_backup_restore as module

from day75_backup_restore import (
    BackupError,
    SOURCE,
    TABLES,
    backup_name,
    restore_name,
    sha256_file,
    render_report,
    credentials,
    binary,
    main,
)


@pytest.fixture
def fixed_time():

    return datetime(
        2026,
        10,
        17,
        12,
        34,
        56,
        tzinfo=timezone.utc,
    )


def test_01_source_name():

    assert SOURCE == "queryforge_dev"


def test_02_archive_name(fixed_time):

    assert backup_name(
        fixed_time,
        "aabb1122",
    ) == (
        "queryforge_day75_"
        "20261017_123456_aabb1122.backup"
    )


def test_03_restore_name(fixed_time):

    assert restore_name(
        fixed_time,
        "aabb1122",
    ) == (
        "qf_restore_d75_"
        "20261017_123456_aabb1122"
    )


def test_04_restore_not_source(fixed_time):

    assert restore_name(
        fixed_time,
        "aabb1122",
    ) != SOURCE


def test_05_names_unique(fixed_time):

    assert backup_name(
        fixed_time,
        "abc",
    ) != backup_name(
        fixed_time,
        "def",
    )


def test_06_sha256(tmp_path):

    path = tmp_path / "abc.txt"

    path.write_bytes(b"abc")

    assert sha256_file(path) == hashlib.sha256(
        b"abc"
    ).hexdigest()


def test_07_hash_changes(tmp_path):

    path = tmp_path / "demo.txt"

    path.write_bytes(b"one")

    first = sha256_file(path)

    path.write_bytes(b"two")

    assert first != sha256_file(path)


def test_08_critical_tables():

    assert "qf_day72.customer_rows" in TABLES

    assert "qf_day73.jobs" in TABLES

    assert "qf_day74.processed_rows" in TABLES


def test_09_no_duplicate_table_names():

    assert len(TABLES) == len(set(TABLES))


def test_10_tables_qualified():

    assert all(
        len(name.split(".")) == 2
        for name in TABLES
    )


def test_11_report_summary(
    tmp_path,
    fixed_time,
):

    archive = tmp_path / "data.backup"

    archive.write_bytes(b"PGDMPexample")

    result = render_report(
        archive,
        "a" * 64,
        "qf_restore_d75_demo",
        {
            "qf_day72.customer_rows": 4,
        },
        (
            "RANGE (order_date)",
            4,
            True,
        ),
        fixed_time,
    )

    assert (
        "| `qf_day72.customer_rows` | "
        "4 | 4 | PASS |"
    ) in result

    assert "Custom archive inspection: PASS" in result

    assert "qf_restore_d75_demo" in result


def test_12_report_hides_path(
    tmp_path,
    fixed_time,
):

    folder = tmp_path / "private"

    folder.mkdir()

    archive = folder / "safe.backup"

    archive.write_bytes(b"PGDMPexample")

    text = render_report(
        archive,
        "b" * 64,
        "demo",
        {},
        (
            "RANGE (order_date)",
            4,
            True,
        ),
        fixed_time,
    )

    assert str(folder) not in text


def test_13_reject_wrong_db(monkeypatch):

    monkeypatch.setenv(
        "DB_NAME",
        "postgres",
    )

    with pytest.raises(
        BackupError,
        match="DB_NAME",
    ):
        credentials()


def test_14_require_explicit_flag():

    with pytest.raises(SystemExit) as exc:

        main([])

    assert exc.value.code == 2


def test_15_missing_binary(monkeypatch):

    monkeypatch.setenv(
        "ProgramFiles",
        "/path-that-does-not-exist",
    )

    monkeypatch.setattr(
        module.shutil,
        "which",
        lambda name: None,
    )

    with pytest.raises(
        BackupError,
        match="Cannot locate",
    ):
        binary("pg_dump")


def test_16_partition_table_included():

    assert "scale.orders_partitioned" in TABLES


def test_17_restore_safety_flags():

    source = inspect.getsource(
        module.execute
    )

    for flag in (
        "--single-transaction",
        "--exit-on-error",
        "--no-owner",
        "--no-acl",
    ):
        assert flag in source


def test_18_no_drop_database():

    source = inspect.getsource(
        module.execute
    ).upper()

    assert "DROP DATABASE" not in source
