
"""
QueryForge Day 65
ETL Monitoring and Data Quality Alerts

Read-only PostgreSQL audit.
Uses verified Day 64 reconciliation functions.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

from day64_etl_reconciliation import (
    assess,
    collect_metrics,
)


ROOT = Path(__file__).resolve().parents[2]

REPORT_PATH = (
    ROOT / "docs" / "day65_etl_monitoring.md"
)

# Store historical counts outside Git repository.
STATE_PATH = (
    Path.home()
    / ".queryforge"
    / "day65_etl_monitor_snapshot.json"
)

TRACKED = (
    "registered_files",
    "customer_rows",
)


def read_snapshot(path: Path):
    """Read previous audit totals."""

    if not path.exists():
        return None

    try:
        data = json.loads(
            path.read_text(encoding="utf-8")
        )
    except (ValueError, OSError) as exc:
        raise ValueError(
            f"Cannot read previous snapshot: {exc}"
        ) from exc

    if (
        not isinstance(data, dict)
        or data.get("version") != 1
    ):
        raise ValueError(
            "Invalid Day 65 snapshot version"
        )

    metrics = data.get("metrics")

    if not isinstance(metrics, dict):
        raise ValueError(
            "Day 65 snapshot metrics are missing"
        )

    for key in TRACKED:
        value = metrics.get(key)

        if type(value) is not int or value < 0:
            raise ValueError(
                f"Invalid previous metric: {key}"
            )

    return {
        key: metrics[key]
        for key in TRACKED
    }


def evaluate(metrics, previous):
    """
    Assess data integrity and changes
    since the previous monitoring run.
    """

    status, failures, warnings = assess(metrics)

    failures = list(failures)
    warnings = list(warnings)

    if previous is not None:

        for key in TRACKED:

            if (
                key not in previous
                or type(previous[key]) is not int
                or previous[key] < 0
            ):
                raise ValueError(
                    f"Invalid previous metric: {key}"
                )

            if metrics[key] < previous[key]:
                failures.append(
                    f"{key} decreased: "
                    f"{previous[key]} -> {metrics[key]}"
                )

        # Potential unexpected addition to existing uploads.
        if (
            metrics["registered_files"] > 0
            and metrics["registered_files"]
                == previous["registered_files"]
            and metrics["customer_rows"]
                > previous["customer_rows"]
        ):
            warnings.append(
                "Customer rows increased without "
                "a new registered file"
            )

    if failures:
        level = "FAIL"

    elif status == "NO DATA":
        level = "NO DATA"

    elif warnings:
        level = "WARN"

    else:
        level = "PASS"

    return level, failures, warnings


def make_report(
    metrics,
    previous,
    level,
    failures,
    warnings,
):
    """Generate Markdown monitoring report."""

    timestamp = datetime.now(
        timezone.utc
    ).strftime("%Y-%m-%d %H:%M:%S UTC")

    lines = [
        "# QueryForge Day 65 - ETL Monitoring",
        "",
        f"Generated: {timestamp}",
        "",
        f"## Status: {level}",
        "",
        "## Current metrics",
        "",
        "| Metric | Count |",
        "|---|---:|",
    ]

    for key, value in metrics.items():
        lines.append(
            f"| {key} | {value} |"
        )

    lines.extend([
        "",
        "## Changes since previous run",
        "",
    ])

    if previous is None:
        lines.append(
            "No previous monitoring snapshot exists."
        )

    else:
        lines.extend([
            "| Metric | Previous | Current | Delta |",
            "|---|---:|---:|---:|",
        ])

        for key in TRACKED:
            delta = metrics[key] - previous[key]

            lines.append(
                f"| {key} | {previous[key]} | "
                f"{metrics[key]} | {delta:+d} |"
            )

    lines.extend([
        "",
        "## Failures",
        "",
    ])

    lines.extend(
        f"- {item}"
        for item in failures or ["None"]
    )

    lines.extend([
        "",
        "## Warnings",
        "",
    ])

    lines.extend(
        f"- {item}"
        for item in warnings or ["None"]
    )

    lines.extend([
        "",
        "## Safety",
        "",
        "Database metrics collected with the "
        "Day 64 read-only transaction.",
        "",
        "Snapshots contain aggregate counts only "
        "and remain outside Git.",
        "",
    ])

    return "\n".join(lines)


def write_snapshot(path: Path, metrics):
    """
    Save aggregate counts locally.
    Never modify database records.
    """

    for key in TRACKED:
        if (
            key not in metrics
            or type(metrics[key]) is not int
            or metrics[key] < 0
        ):
            raise ValueError(
                f"Invalid metric for snapshot: {key}"
            )

    payload = {
        "version": 1,
        "checked_at": datetime.now(
            timezone.utc
        ).isoformat(),
        "metrics": {
            key: metrics[key]
            for key in TRACKED
        },
    }

    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    temp_path = path.with_name(
        path.name + ".tmp"
    )

    temp_path.write_text(
        json.dumps(payload, indent=2) + "\n",
        encoding="utf-8",
    )

    os.replace(temp_path, path)


def main():

    print("===== DAY 65 ETL MONITORING =====")

    try:
        previous = read_snapshot(STATE_PATH)

        metrics, _recent = collect_metrics()

        level, failures, warnings = evaluate(
            metrics,
            previous,
        )

        report = make_report(
            metrics,
            previous,
            level,
            failures,
            warnings,
        )

        REPORT_PATH.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        REPORT_PATH.write_text(
            report,
            encoding="utf-8",
        )

        for name, count in metrics.items():
            print(f"{name}: {count}")

        for item in failures:
            print(f"FAIL: {item}")

        for item in warnings:
            print(f"WARN: {item}")

        print(f"DAY 65 STATUS: {level}")

        print(
            f"Report saved: {REPORT_PATH}"
        )

        if level == "FAIL":
            print(
                "Snapshot NOT updated "
                "because failures exist."
            )
            return 1

        write_snapshot(
            STATE_PATH,
            metrics,
        )

        print(
            "Snapshot saved outside Git: "
            f"{STATE_PATH}"
        )

        return 0

    except Exception as exc:
        print(
            f"DAY 65 ERROR: {exc}",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
