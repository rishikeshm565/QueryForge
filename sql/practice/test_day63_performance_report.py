
import json

import pytest

from day63_performance_report import (
    AuditError,
    QUERIES,
    make_report,
    normalize_plan,
    partition_relations,
    validate_index_status,
    verify_pruning,
    walk_nodes,
)


def example_plan(relation="orders_2026"):
    return {
        "Plan": {
            "Node Type": "Aggregate",
            "Plans": [
                {
                    "Node Type": "Seq Scan",
                    "Relation Name": relation,
                },
            ],
        },
        "Execution Time": 2.4,
        "Planning Time": 0.1,
    }


def test_01_normalize_list():
    assert (
        normalize_plan([example_plan()])["Execution Time"]
        == 2.4
    )


def test_02_normalize_json_string():
    raw = json.dumps([example_plan()])

    assert (
        normalize_plan(raw)["Plan"]["Node Type"]
        == "Aggregate"
    )


def test_03_reject_bad_plan():
    with pytest.raises(AuditError):
        normalize_plan([])


def test_04_walk_nested_nodes():
    nodes = [
        p["Node Type"]
        for p in walk_nodes(example_plan()["Plan"])
    ]

    assert nodes == [
        "Aggregate",
        "Seq Scan",
    ]


def test_05_partition_relations():
    assert partition_relations(
        example_plan()
    ) == {"orders_2026"}


def test_06_pruning_passes():
    verify_pruning(example_plan())


def test_07_pruning_fails_for_wrong_year():
    with pytest.raises(AuditError):
        verify_pruning(
            example_plan("orders_2025")
        )


def test_08_index_health():
    validate_index_status(
        {"idx": (True, True, False)},
        ("idx",),
    )


def test_09_missing_index():
    with pytest.raises(AuditError):
        validate_index_status(
            {},
            ("idx",),
        )


def test_10_unique_mv_index():
    with pytest.raises(AuditError):
        validate_index_status(
            {
                "idx_mv_monthly_order_summary": (
                    True,
                    True,
                    False,
                )
            },
            ("idx_mv_monthly_order_summary",),
        )


def test_11_queries_are_select_only():
    assert all(
        query.lstrip().upper().split()[:1] == ["SELECT"]
        for query in QUERIES.values()
    )


def test_12_report_contents():
    metric = {
        "label": "Example",
        "execution_ms": 1.0,
        "planning_ms": 0.2,
        "shared_hits": 2,
        "shared_reads": 0,
        "nodes": "Index Scan",
        "index_names": "idx",
        "relations": "orders_2026",
    }

    report = make_report(
        "queryforge_dev",
        {"customers_big": 10},
        [metric],
    )

    assert "| Example |" in report
    assert "customers_big" in report
