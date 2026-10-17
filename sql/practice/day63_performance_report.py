
"""QueryForge Day 63 - Read-only performance report."""

from __future__ import annotations

import json
import os
import sys

from datetime import datetime, timezone
from pathlib import Path

import psycopg
from dotenv import load_dotenv


load_dotenv()

REPORT_PATH = Path(
    "docs/day63_performance_report.md"
)

REQUIRED_OBJECTS = {
    "scale.customers_big": "r",
    "scale.orders_partitioned": "p",
    "analytics.mv_monthly_order_summary": "m",
    "etl.file_upload_registry": "r",
    "etl.customer_upload_rows": "r",
}

REQUIRED_INDEXES = {
    "scale.customers_big": (
        "customers_big_pkey",
        "idx_customers_big_city_credit",
        "idx_customers_big_inactive_customer",
        "idx_customers_big_city_cover",
    ),
    "analytics.mv_monthly_order_summary": (
        "idx_mv_monthly_order_summary",
    ),
}

QUERIES = {
    "1. Primary-key lookup": """
        SELECT customer_id, full_name
        FROM scale.customers_big
        WHERE customer_id = 50000
    """,

    "2. CAST on primary key": """
        SELECT customer_id, full_name
        FROM scale.customers_big
        WHERE customer_id::text = '50000'
    """,

    "3. Composite index": """
        SELECT customer_id, city, credit_limit
        FROM scale.customers_big
        WHERE city = 'Mumbai'
        ORDER BY credit_limit DESC
        LIMIT 20
    """,

    "4. Partial index": """
        SELECT customer_id, is_active
        FROM scale.customers_big
        WHERE is_active = false
          AND customer_id BETWEEN 1 AND 1000
        ORDER BY customer_id
        LIMIT 20
    """,

    "5. Covering index": """
        SELECT city, full_name, credit_limit
        FROM scale.customers_big
        WHERE city = 'Mumbai'
        LIMIT 100
    """,

    "6. ORDER BY expression": """
        SELECT customer_id, city, credit_limit
        FROM scale.customers_big
        WHERE city = 'Mumbai'
        ORDER BY credit_limit + 0 DESC
        LIMIT 20
    """,

    "7. Partition pruning": """
        SELECT COUNT(*)
        FROM scale.orders_partitioned
        WHERE order_date >= DATE '2026-01-01'
          AND order_date < DATE '2026-04-01'
    """,

    "8. Materialized view": """
        SELECT
            month, status, total_orders, total_amount
        FROM analytics.mv_monthly_order_summary
        WHERE month = DATE '2026-01-01'
    """,
}

COUNTS = {
    "customers_big":
        "SELECT COUNT(*) FROM scale.customers_big",

    "orders_partitioned":
        "SELECT COUNT(*) FROM scale.orders_partitioned",

    "monthly_summary_rows":
        "SELECT COUNT(*) FROM analytics.mv_monthly_order_summary",

    "registered_uploads":
        "SELECT COUNT(*) FROM etl.file_upload_registry",

    "uploaded_customer_rows":
        "SELECT COUNT(*) FROM etl.customer_upload_rows",
}


class AuditError(RuntimeError):
    """Raised when a database audit check fails."""


def normalize_plan(raw):
    if isinstance(raw, str):
        raw = json.loads(raw)

    if isinstance(raw, list):
        if len(raw) != 1:
            raise AuditError(
                "Expected one EXPLAIN JSON document"
            )
        raw = raw[0]

    if (
        not isinstance(raw, dict)
        or not isinstance(raw.get("Plan"), dict)
    ):
        raise AuditError(
            "Unexpected EXPLAIN JSON structure"
        )

    return raw


def walk_nodes(node):
    yield node

    for child in node.get("Plans", []):
        yield from walk_nodes(child)


def partition_relations(document):
    return {
        str(node["Relation Name"])
        for node in walk_nodes(document["Plan"])
        if str(
            node.get("Relation Name", "")
        ).startswith("orders_")
    }


def verify_pruning(document):
    found = partition_relations(document)

    if found != {"orders_2026"}:
        raise AuditError(
            f"Partition pruning unexpected: {sorted(found)}"
        )


def validate_index_status(actual, required):
    for name in required:
        if name not in actual:
            raise AuditError(
                f"Missing index: {name}"
            )

        valid, ready, unique = actual[name]

        if not valid or not ready:
            raise AuditError(
                f"Invalid/not-ready index: {name}"
            )

        if (
            name == "idx_mv_monthly_order_summary"
            and not unique
        ):
            raise AuditError(
                "Materialized-view index must be UNIQUE"
            )


def explain_metric(cur, label, sql):
    if not sql.lstrip().upper().lstrip().upper().split()[:1] == ["SELECT"]:
        raise AuditError(
            "Only SELECT benchmarks are allowed"
        )

    cur.execute(
        "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) "
        + sql
    )

    document = normalize_plan(cur.fetchone()[0])

    nodes = list(
        walk_nodes(document["Plan"])
    )

    return {
        "label": label,

        "execution_ms":
            float(document["Execution Time"]),

        "planning_ms":
            float(document.get("Planning Time", 0)),

        "shared_hits":
            int(document["Plan"].get(
                "Shared Hit Blocks", 0
            )),

        "shared_reads":
            int(document["Plan"].get(
                "Shared Read Blocks", 0
            )),

        "nodes": ", ".join(
            str(n["Node Type"]) for n in nodes
        ),

        "index_names": ", ".join(
            str(n["Index Name"])
            for n in nodes
            if "Index Name" in n
        ) or "-",

        "relations": ", ".join(
            sorted(partition_relations(document))
        ) or "-",

        "plan": document,
    }


def make_report(database, counts, metrics):
    lines = [
        "# QueryForge — Day 63 Performance Report",
        "",
        (
            "- Generated (UTC): "
            + datetime.now(timezone.utc).isoformat(
                timespec="seconds"
            )
        ),
        f"- Database: `{database}`",
        "- Audit: PostgreSQL read-only transaction.",
        "- No source rows changed.",
        "- Timings are observations, not fixed thresholds.",
        "",
        "## Data counts",
        "",
        "| Object | Rows |",
        "|---|---:|",
    ]

    lines += [
        f"| `{key}` | {value:,} |"
        for key, value in counts.items()
    ]

    lines += [
        "",
        "## Query plans and timings",
        "",
        (
            "| Benchmark | Execution (ms) | "
            "Planning (ms) | Shared hits | Shared reads |"
        ),
        "|---|---:|---:|---:|---:|",
    ]

    for m in metrics:
        lines.append(
            f"| {m['label']} | "
            f"{m['execution_ms']:.3f} | "
            f"{m['planning_ms']:.3f} | "
            f"{m['shared_hits']} | "
            f"{m['shared_reads']} |"
        )

    lines += [
        "",
        "## Plan details",
        "",
    ]

    for m in metrics:
        lines += [
            f"### {m['label']}",
            "",
            f"- Nodes: `{m['nodes']}`",
            f"- Indexes: `{m['index_names']}`",
            (
                "- Order partitions scanned: "
                f"`{m['relations']}`"
            ),
            "",
        ]

    lines += [
        "## Verification",
        "",
        "- Required objects: PASS",
        "- Required indexes valid and ready: PASS",
        "- Materialized view populated: PASS",
        "- 2026-Q1 partition pruning: PASS",
        "",
        (
            "Note: A timing difference alone does not "
            "prove a regression. Compare execution plans "
            "and multiple runs."
        ),
        "",
    ]

    return "\n".join(lines)


def main():
    kwargs = {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": os.getenv("DB_PORT", "5432"),
        "dbname": os.getenv(
            "DB_NAME", "queryforge_dev"
        ),
        "user": os.getenv("DB_USER", "postgres"),
        "connect_timeout": 10,
        "autocommit": True,
    }

    if os.getenv("DB_PASSWORD"):
        kwargs["password"] = os.environ["DB_PASSWORD"]

    with psycopg.connect(**kwargs) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "BEGIN TRANSACTION READ ONLY"
            )

            try:
                cur.execute(
                    "SET LOCAL statement_timeout = '30000ms'"
                )

                cur.execute(
                    "SELECT current_database()"
                )

                database = cur.fetchone()[0]

                if database != "queryforge_dev":
                    raise AuditError(
                        f"Wrong database: {database}"
                    )

                # Check all required objects
                for name, expected_kind in REQUIRED_OBJECTS.items():
                    cur.execute(
                        """
                        SELECT relkind
                        FROM pg_class
                        WHERE oid = to_regclass(%s)
                        """,
                        (name,),
                    )

                    result = cur.fetchone()

                    if (
                        result is None
                        or result[0] != expected_kind
                    ):
                        raise AuditError(
                            f"Missing/unexpected object: {name}"
                        )

                # Verify populated materialized view
                cur.execute(
                    """
                    SELECT ispopulated
                    FROM pg_matviews
                    WHERE schemaname = 'analytics'
                      AND matviewname =
                          'mv_monthly_order_summary'
                    """
                )

                populated = cur.fetchone()

                if populated is None or not populated[0]:
                    raise AuditError(
                        "Monthly materialized view is unpopulated"
                    )

                # Verify index health
                for table, required in REQUIRED_INDEXES.items():
                    cur.execute(
                        """
                        SELECT
                            ci.relname,
                            i.indisvalid,
                            i.indisready,
                            i.indisunique
                        FROM pg_index i
                        JOIN pg_class ci
                            ON ci.oid = i.indexrelid
                        WHERE i.indrelid = to_regclass(%s)
                        """,
                        (table,),
                    )

                    actual = {
                        name: (valid, ready, unique)
                        for name, valid, ready, unique
                        in cur.fetchall()
                    }

                    validate_index_status(
                        actual,
                        required,
                    )

                # Count source rows
                counts = {}

                for key, query in COUNTS.items():
                    cur.execute(query)
                    counts[key] = cur.fetchone()[0]

                # Run benchmarks
                metrics = []

                for label, query in QUERIES.items():
                    metric = explain_metric(
                        cur,
                        label,
                        query,
                    )

                    if label == "7. Partition pruning":
                        verify_pruning(metric["plan"])

                    metrics.append(metric)

                    print(
                        f"{label}: "
                        f"{metric['execution_ms']:.3f} ms"
                    )

            finally:
                # End transaction without changing data
                cur.execute("ROLLBACK")

    # Write local Markdown report only after checks pass
    text = make_report(
        database,
        counts,
        metrics,
    )

    REPORT_PATH.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    REPORT_PATH.write_text(
        text,
        encoding="utf-8",
    )

    print(
        f"PASS: Day 63 report saved to {REPORT_PATH}"
    )


if __name__ == "__main__":
    try:
        main()

    except (
        AuditError,
        psycopg.Error,
        OSError,
        ValueError,
    ) as exc:

        print(
            f"DAY 63 FAILED: {exc}",
            file=sys.stderr,
        )

        raise SystemExit(1)
