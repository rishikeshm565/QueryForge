
"""QueryForge Day 67 unit tests."""

from datetime import datetime, timezone
from decimal import Decimal

import pytest

from day67_incremental_upsert import (
    Customer,
    SQL_FILE,
    simulate_upsert,
)


def customer(cid, credit, day=1):
    return Customer(
        customer_id=cid,
        customer_name=f"Customer {cid}",
        city="Hyderabad",
        credit_limit=Decimal(str(credit)),
        source_updated_at=datetime(
            2026, 10, day,
            tzinfo=timezone.utc,
        ),
    )


def test_01_insert_new_customer():
    result, changed = simulate_upsert(
        [], [customer(1, 50000)]
    )

    assert len(result) == 1
    assert changed == 1


def test_02_update_newer_record():
    result, changed = simulate_upsert(
        [customer(1, 50000, 1)],
        [customer(1, 55000, 5)],
    )

    assert changed == 1
    assert result[0].credit_limit == 55000


def test_03_skip_same_timestamp():
    result, changed = simulate_upsert(
        [customer(1, 50000, 1)],
        [customer(1, 90000, 1)],
    )

    assert changed == 0
    assert result[0].credit_limit == 50000


def test_04_skip_stale_record():
    result, changed = simulate_upsert(
        [customer(1, 50000, 8)],
        [customer(1, 90000, 4)],
    )

    assert changed == 0
    assert result[0].credit_limit == 50000


def test_05_idempotent_replay():
    first, first_count = simulate_upsert(
        [], [customer(1, 50000)]
    )

    second, second_count = simulate_upsert(
        first, [customer(1, 50000)]
    )

    assert first_count == 1
    assert second_count == 0
    assert first == second


def test_06_duplicate_incoming():
    with pytest.raises(ValueError):
        simulate_upsert(
            [],
            [
                customer(1, 50000),
                customer(1, 60000),
            ],
        )


def test_07_duplicate_existing():
    with pytest.raises(ValueError):
        simulate_upsert(
            [
                customer(1, 50000),
                customer(1, 60000),
            ],
            [],
        )


def test_08_negative_credit():
    with pytest.raises(ValueError):
        simulate_upsert(
            [], [customer(1, -500)]
        )


def test_09_invalid_customer_id():
    with pytest.raises(ValueError):
        simulate_upsert(
            [], [customer(0, 50000)]
        )


def test_10_original_input_unchanged():
    old = [customer(1, 50000, 1)]

    simulate_upsert(
        old,
        [customer(1, 60000, 5)],
    )

    assert old[0].credit_limit == 50000


def test_11_naive_timestamp_rejected():
    row = Customer(
        1,
        "Rahul",
        "Mumbai",
        Decimal("50000"),
        datetime(2026, 10, 1),
    )

    with pytest.raises(ValueError):
        simulate_upsert([], [row])


def test_12_sql_safety():
    sql = SQL_FILE.read_text(
        encoding="utf-8"
    ).upper()

    assert "CREATE TEMP TABLE" in sql
    assert "ON CONFLICT (CUSTOMER_ID)" in sql
    assert "ROLLBACK;" in sql
    assert "DROP TABLE" not in sql


def test_13_full_incremental_batch():
    current = [
        customer(1, 50000, 1),
        customer(2, 60000, 1),
        customer(4, 20000, 8),
    ]

    incoming = [
        customer(1, 55000, 5),
        customer(2, 60000, 1),
        customer(3, 70000, 5),
        customer(4, 99000, 4),
    ]

    first, first_changed = simulate_upsert(
        current, incoming
    )

    second, second_changed = simulate_upsert(
        first, incoming
    )

    values = {
        row.customer_id: row.credit_limit
        for row in second
    }

    assert first_changed == 2
    assert second_changed == 0
    assert len(second) == 4
    assert values[1] == 55000
    assert values[2] == 60000
    assert values[3] == 70000
    assert values[4] == 20000
