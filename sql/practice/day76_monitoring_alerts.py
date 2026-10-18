
"""QueryForge Day 76: read-only PostgreSQL ETL health monitoring."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import uuid

from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv


DATABASE = "queryforge_dev"

COUNT_TABLES = (
    "scale.orders_partitioned",
    "analytics.mv_monthly_order_summary",
    "etl.file_upload_registry",
    "qf_day72.file_uploads",
    "qf_day72.customer_rows",
    "qf_day72.rejected_rows",
    "qf_day73.jobs",
    "qf_day73.processed_customers",
    "qf_day73.batch_history",
    "qf_day74.jobs",
    "qf_day74.processed_rows",
    "qf_day74.batch_history",
)

COMPARE_KEYS = (
    "qf_day72.file_uploads",
    "qf_day72.customer_rows",
    "qf_day73.processed_customers",
    "qf_day74.processed_rows",
    "qf_day74.batch_history",
)


class MonitoringError(Exception):
    pass


def connection_settings() -> dict:

    load_dotenv()

    if os.getenv("DB_NAME", DATABASE) != DATABASE:
        raise MonitoringError(
            "STOP: expected DB_NAME=queryforge_dev"
        )

    return dict(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=DATABASE,
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
        connect_timeout=10,
        autocommit=True,
    )


def collect_metrics() -> dict[str, int]:
    """Collect aggregate metrics in a read-only transaction."""

    import psycopg

    metrics = {}

    with psycopg.connect(**connection_settings()) as conn:

        with conn.cursor() as cur:

            cur.execute("BEGIN TRANSACTION READ ONLY")

            try:

                cur.execute(
                    "SET LOCAL statement_timeout = '30s'"
                )

                cur.execute(
                    "SELECT current_database()"
                )

                if cur.fetchone()[0] != DATABASE:
                    raise MonitoringError(
                        "Connected to unexpected database"
                    )

                # Check required project tables.

                for name in COUNT_TABLES:

                    if not re.fullmatch(
                        r"[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*",
                        name,
                    ):
                        raise MonitoringError(
                            "Untrusted relation identifier"
                        )

                    cur.execute(
                        "SELECT to_regclass(%s)",
                        (name,),
                    )

                    if cur.fetchone()[0] is None:
                        raise MonitoringError(
                            f"Required table missing: {name}"
                        )

                    # Only fixed, trusted table names are used.
                    cur.execute(
                        f"SELECT COUNT(*) FROM {name}"
                    )

                    metrics[name] = int(
                        cur.fetchone()[0]
                    )

                # Day 74 job status and stalled jobs.

                cur.execute(
                    """
                    SELECT
                        COUNT(*) FILTER (
                            WHERE status = 'RUNNING'
                        ),

                        COUNT(*) FILTER (
                            WHERE status = 'COMPLETED'
                        ),

                        COUNT(*) FILTER (
                            WHERE status = 'RUNNING'
                              AND updated_at <
                                  NOW() - INTERVAL '60 minutes'
                        ),

                        COUNT(*) FILTER (
                            WHERE processed_rows < 0
                               OR processed_rows > expected_rows
                               OR (
                                   status = 'COMPLETED'
                                   AND processed_rows <> expected_rows
                               )
                        )

                    FROM qf_day74.jobs
                    """
                )

                running, completed, stalled, invalid = (
                    cur.fetchone()
                )

                metrics.update(
                    day74_running_jobs=int(running),
                    day74_completed_jobs=int(completed),
                    day74_stalled_jobs=int(stalled),
                    day74_invalid_jobs=int(invalid),
                )

                # Verify processed rows equal checkpoints
                # and committed batch row totals.

                cur.execute(
                    """
                    SELECT COUNT(*)

                    FROM qf_day74.jobs j

                    LEFT JOIN (
                        SELECT
                            upload_id,
                            COUNT(*) AS n
                        FROM qf_day74.processed_rows
                        GROUP BY upload_id
                    ) p
                        ON p.upload_id = j.upload_id

                    LEFT JOIN (
                        SELECT
                            upload_id,
                            COALESCE(SUM(batch_rows), 0) AS n
                        FROM qf_day74.batch_history
                        GROUP BY upload_id
                    ) b
                        ON b.upload_id = j.upload_id

                    WHERE
                        j.processed_rows <> COALESCE(p.n, 0)
                        OR
                        j.processed_rows <> COALESCE(b.n, 0)
                    """
                )

                metrics["day74_checkpoint_mismatches"] = int(
                    cur.fetchone()[0]
                )

                # Check invalid/unready indexes.

                cur.execute(
                    """
                    SELECT COUNT(*)

                    FROM pg_index i

                    JOIN pg_class t
                        ON t.oid = i.indrelid

                    JOIN pg_namespace n
                        ON n.oid = t.relnamespace

                    WHERE n.nspname IN (
                        'scale',
                        'analytics',
                        'etl',
                        'qf_day72',
                        'qf_day73',
                        'qf_day74'
                    )

                    AND (
                        NOT i.indisvalid
                        OR NOT i.indisready
                    )
                    """
                )

                metrics["invalid_indexes"] = int(
                    cur.fetchone()[0]
                )

                # Verify partitions.

                cur.execute(
                    """
                    SELECT COUNT(*)
                    FROM pg_inherits
                    WHERE inhparent =
                        'scale.orders_partitioned'::regclass
                    """
                )

                metrics["partition_count"] = int(
                    cur.fetchone()[0]
                )

                # Verify materialized view.

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

                if populated is None:
                    raise MonitoringError(
                        "Monthly materialized view missing"
                    )

                metrics["materialized_view_populated"] = int(
                    populated[0]
                )

            finally:

                cur.execute("ROLLBACK")

    return metrics


def find_backup_age_hours(
    folder: Path,
    now: datetime,
) -> int | None:

    archives = [
        path
        for path in folder.glob(
            "queryforge_day75_*.backup"
        )
        if path.is_file()
        and path.stat().st_size > 0
    ]

    if not archives:
        return None

    latest = max(
        path.stat().st_mtime
        for path in archives
    )

    return max(
        0,
        int(
            (now.timestamp() - latest) // 3600
        ),
    )


def evaluate(
    metrics: dict[str, int],
    previous: dict[str, int] | None,
    backup_age_hours: int | None,
) -> tuple[str, list[tuple[str, str]]]:

    alerts: list[tuple[str, str]] = []

    # Critical failures.

    for key in (
        "invalid_indexes",
        "day74_invalid_jobs",
        "day74_checkpoint_mismatches",
    ):

        if metrics[key] > 0:

            alerts.append(
                (
                    "FAIL",
                    f"{key}: {metrics[key]}",
                )
            )

    if metrics["partition_count"] == 0:

        alerts.append(
            (
                "FAIL",
                "Partitioned orders table has no partitions",
            )
        )

    if metrics["materialized_view_populated"] != 1:

        alerts.append(
            (
                "FAIL",
                "Monthly materialized view is not populated",
            )
        )

    # Warnings.

    if metrics["day74_stalled_jobs"] > 0:

        alerts.append(
            (
                "WARN",
                "Stalled Day 74 jobs: "
                f"{metrics['day74_stalled_jobs']}",
            )
        )

    if backup_age_hours is None:

        alerts.append(
            (
                "WARN",
                "No Day 75 local backup archive found",
            )
        )

    elif backup_age_hours > 24 * 7:

        alerts.append(
            (
                "WARN",
                "Most recent Day 75 backup is "
                f"{backup_age_hours} hours old",
            )
        )

    # Compare current counts against previous snapshot.

    if previous is not None:

        for key in COMPARE_KEYS:

            if metrics[key] < previous[key]:

                alerts.append(
                    (
                        "WARN",
                        f"Count decreased: {key} "
                        f"({previous[key]} -> {metrics[key]})",
                    )
                )

        rejected = "qf_day72.rejected_rows"

        if metrics[rejected] > previous[rejected]:

            alerts.append(
                (
                    "WARN",
                    "New rejected Day 72 rows: "
                    f"{metrics[rejected] - previous[rejected]}",
                )
            )

    if any(
        severity == "FAIL"
        for severity, _ in alerts
    ):
        status = "FAIL"

    elif alerts:
        status = "WARN"

    else:
        status = "PASS"

    return status, alerts


def read_latest_snapshot(
    folder: Path,
) -> dict[str, int] | None:

    files = sorted(
        folder.glob("day76_*.json")
    )

    if not files:
        return None

    try:

        payload = json.loads(
            files[-1].read_text(
                encoding="utf-8"
            )
        )

        previous = payload["metrics"]

        if (
            payload["version"] != 1
            or not isinstance(previous, dict)
        ):
            raise ValueError(
                "Invalid snapshot version"
            )

        expected = set(COUNT_TABLES) | {
            "day74_running_jobs",
            "day74_completed_jobs",
            "day74_stalled_jobs",
            "day74_invalid_jobs",
            "day74_checkpoint_mismatches",
            "invalid_indexes",
            "partition_count",
            "materialized_view_populated",
        }

        if (
            set(previous) != expected
            or any(
                type(value) is not int
                or value < 0
                for value in previous.values()
            )
        ):
            raise ValueError(
                "Unexpected snapshot metrics"
            )

        return previous

    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
    ) as exc:

        raise MonitoringError(
            f"Invalid prior monitoring snapshot: {exc}"
        ) from exc


def build_report(
    when: datetime,
    metrics: dict[str, int],
    status: str,
    alerts: list[tuple[str, str]],
    backup_age_hours: int | None,
    had_previous: bool,
) -> str:

    lines = [
        "# QueryForge Day 76 - ETL Monitoring and Alerts",
        "",
        f"Generated UTC: {when:%Y-%m-%d %H:%M:%S}",
        "",
        f"## Status: {status}",
        "",
        "- PostgreSQL transaction: READ ONLY",
        "- Source database: `queryforge_dev`",
        "- Previous monitoring snapshot: "
        + (
            "YES"
            if had_previous
            else "NO (baseline)"
        ),
        "- Latest Day 75 backup age (hours): "
        + (
            str(backup_age_hours)
            if backup_age_hours is not None
            else "NOT FOUND"
        ),
        "- Customer names, emails, passwords and "
        "individual records: NOT INCLUDED",
        "",
        "## Metrics",
        "",
        "| Metric | Count |",
        "|---|---:|",
    ]

    for name, value in sorted(
        metrics.items()
    ):

        lines.append(
            f"| `{name}` | {value} |"
        )

    lines.extend(
        [
            "",
            "## Alerts",
            "",
        ]
    )

    for severity, message in alerts:

        lines.append(
            f"- **{severity}**: {message}"
        )

    if not alerts:
        lines.append("- None")

    lines.extend(
        [
            "",
            "## Scope",
            "",
            "- Checks counts, Day 74 checkpoint invariants, "
            "stale running jobs, indexes, partitions and "
            "materialized view state.",
            "- Compares aggregate counts with the preceding "
            "local snapshot if present.",
            "- Local snapshots and backup archives "
            "stay outside Git.",
            "- This is a point-in-time check; it is not "
            "a continuously running alert service.",
            "- Backup presence/age alone does not prove "
            "restorability; Day 75 verified one "
            "isolated restore.",
            "",
        ]
    )

    return "\n".join(lines)


def run_monitor(
    snapshot_dir: Path,
    backup_dir: Path,
    report: Path | None,
) -> int:

    if report is not None and report.exists():

        raise MonitoringError(
            "Report already exists; "
            f"refusing overwrite: {report}"
        )

    if not snapshot_dir.is_relative_to(
        backup_dir
    ):

        raise MonitoringError(
            "Snapshot folder must be inside "
            "the local backups folder"
        )

    now = datetime.now(
        timezone.utc
    )

    previous = read_latest_snapshot(
        snapshot_dir
    )

    metrics = collect_metrics()

    backup_age = find_backup_age_hours(
        backup_dir,
        now,
    )

    status, alerts = evaluate(
        metrics,
        previous,
        backup_age,
    )

    content = build_report(
        now,
        metrics,
        status,
        alerts,
        backup_age,
        previous is not None,
    )

    snapshot_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    name = (
        "day76_"
        + now.strftime("%Y%m%d_%H%M%S_")
        + uuid.uuid4().hex[:8]
        + ".json"
    )

    snapshot_path = snapshot_dir / name

    snapshot = {
        "version": 1,
        "generated_utc": now.isoformat(),
        "status": status,
        "metrics": metrics,
    }

    with snapshot_path.open(
        "x",
        encoding="utf-8",
    ) as handle:

        json.dump(
            snapshot,
            handle,
            indent=2,
            sort_keys=True,
        )

        handle.write("\n")

    if report is not None:

        report.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        with report.open(
            "x",
            encoding="utf-8",
        ) as handle:

            handle.write(content)

        print(
            f"REPORT: {report}"
        )

    print(
        f"DAY 76 STATUS: {status}"
    )

    print(
        f"SNAPSHOT: {snapshot_path}"
    )

    print(
        f"ALERTS: {len(alerts)}"
    )

    for severity, message in alerts:

        print(
            f"{severity}: {message}"
        )

    if status == "FAIL":
        return 1

    return 0


def main(argv=None) -> int:

    parser = argparse.ArgumentParser(
        description=__doc__
    )

    parser.add_argument(
        "--run-live",
        action="store_true",
    )

    parser.add_argument(
        "--backup-dir",
        type=Path,
        default=Path("backups"),
    )

    parser.add_argument(
        "--snapshot-dir",
        type=Path,
        default=Path(
            "backups/day76_monitor"
        ),
    )

    parser.add_argument(
        "--report",
        type=Path,
    )

    args = parser.parse_args(argv)

    if not args.run_live:

        parser.error(
            "Use --run-live for explicit "
            "read-only database monitoring"
        )

    try:

        return run_monitor(
            args.snapshot_dir.resolve(),
            args.backup_dir.resolve(),
            (
                args.report.resolve()
                if args.report
                else None
            ),
        )

    except Exception as exc:

        print(
            f"DAY 76 ERROR "
            f"({type(exc).__name__}): {exc}",
            file=sys.stderr,
        )

        return 1


if __name__ == "__main__":

    raise SystemExit(
        main()
    )
