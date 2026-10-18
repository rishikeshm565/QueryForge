
"""Day 76 offline unit tests; no PostgreSQL connections required."""

import json
from datetime import datetime, timezone

import pytest

import day76_monitoring_alerts as monitor


@pytest.fixture
def metrics():

    result = {
        name: 0
        for name in monitor.COUNT_TABLES
    }

    result.update(
        day74_running_jobs=0,
        day74_completed_jobs=1,
        day74_stalled_jobs=0,
        day74_invalid_jobs=0,
        day74_checkpoint_mismatches=0,
        invalid_indexes=0,
        partition_count=4,
        materialized_view_populated=1,
    )

    result.update(
        {
            "qf_day72.file_uploads": 1,
            "qf_day72.customer_rows": 4,
            "qf_day72.rejected_rows": 2,
            "qf_day73.processed_customers": 4,
            "qf_day74.processed_rows": 4,
            "qf_day74.batch_history": 2,
        }
    )

    return result


def test_01_expected_database():

    assert monitor.DATABASE == "queryforge_dev"


def test_02_count_tables_unique():

    assert len(
        monitor.COUNT_TABLES
    ) == len(
        set(monitor.COUNT_TABLES)
    )


def test_03_valid_baseline(metrics):

    assert monitor.evaluate(
        metrics,
        None,
        3,
    ) == (
        "PASS",
        [],
    )


def test_04_no_backup_warn(metrics):

    status, alerts = monitor.evaluate(
        metrics,
        None,
        None,
    )

    assert status == "WARN"
    assert "backup" in alerts[0][1]


def test_05_stale_backup_warn(metrics):

    status, alerts = monitor.evaluate(
        metrics,
        None,
        200,
    )

    assert status == "WARN"

    assert any(
        "hours old" in item[1]
        for item in alerts
    )


def test_06_fresh_backup_pass(metrics):

    assert monitor.evaluate(
        metrics,
        None,
        168,
    )[0] == "PASS"


def test_07_stalled_jobs_warn(metrics):

    metrics["day74_stalled_jobs"] = 1

    assert monitor.evaluate(
        metrics,
        None,
        1,
    )[0] == "WARN"


def test_08_invalid_index_fails(metrics):

    metrics["invalid_indexes"] = 1

    assert monitor.evaluate(
        metrics,
        None,
        1,
    )[0] == "FAIL"


def test_09_checkpoint_mismatch_fails(metrics):

    metrics["day74_checkpoint_mismatches"] = 1

    assert monitor.evaluate(
        metrics,
        None,
        1,
    )[0] == "FAIL"


def test_10_invalid_jobs_fail(metrics):

    metrics["day74_invalid_jobs"] = 1

    assert monitor.evaluate(
        metrics,
        None,
        1,
    )[0] == "FAIL"


def test_11_partition_missing_fails(metrics):

    metrics["partition_count"] = 0

    assert monitor.evaluate(
        metrics,
        None,
        1,
    )[0] == "FAIL"


def test_12_mv_unpopulated_fails(metrics):

    metrics["materialized_view_populated"] = 0

    assert monitor.evaluate(
        metrics,
        None,
        1,
    )[0] == "FAIL"


def test_13_count_drop_warns(metrics):

    previous = metrics.copy()

    previous["qf_day74.processed_rows"] = 6

    status, alerts = monitor.evaluate(
        metrics,
        previous,
        1,
    )

    assert status == "WARN"

    assert any(
        "Count decreased" in message
        for _, message in alerts
    )


def test_14_rejections_increased_warns(metrics):

    previous = metrics.copy()

    previous["qf_day72.rejected_rows"] = 1

    status, alerts = monitor.evaluate(
        metrics,
        previous,
        1,
    )

    assert status == "WARN"

    assert any(
        "New rejected" in message
        for _, message in alerts
    )


def test_15_report_contains_no_sensitive_values(metrics):

    content = monitor.build_report(
        datetime(
            2026,
            10,
            18,
            tzinfo=timezone.utc,
        ),
        metrics,
        "PASS",
        [],
        1,
        False,
    )

    assert "## Status: PASS" in content
    assert "@example.com" not in content
    assert "- None" in content
    assert "qf_day74.processed_rows" in content


def test_16_no_previous_snapshot(tmp_path):

    assert monitor.read_latest_snapshot(
        tmp_path
    ) is None


def test_17_read_latest_snapshot(tmp_path, metrics):

    payload = {
        "version": 1,
        "metrics": metrics,
    }

    (
        tmp_path / "day76_20261017_100000_a.json"
    ).write_text(
        json.dumps(payload)
    )

    (
        tmp_path / "day76_20261018_100000_b.json"
    ).write_text(
        json.dumps(payload)
    )

    assert monitor.read_latest_snapshot(
        tmp_path
    ) == metrics


def test_18_corrupt_snapshot_rejected(tmp_path):

    (
        tmp_path / "day76_20261018_100000_bad.json"
    ).write_text(
        "oops"
    )

    with pytest.raises(
        monitor.MonitoringError
    ):

        monitor.read_latest_snapshot(
            tmp_path
        )


def test_19_missing_snapshot_metric_rejected(tmp_path):

    (
        tmp_path / "day76_20261018_100000_bad.json"
    ).write_text(
        json.dumps(
            {
                "version": 1,
                "metrics": {
                    "x": 1,
                },
            }
        )
    )

    with pytest.raises(
        monitor.MonitoringError
    ):

        monitor.read_latest_snapshot(
            tmp_path
        )


def test_20_backup_age(tmp_path):

    now = datetime.now(
        timezone.utc
    )

    path = (
        tmp_path / "queryforge_day75_test.backup"
    )

    path.write_bytes(
        b"a"
    )

    assert monitor.find_backup_age_hours(
        tmp_path,
        now,
    ) == 0


def test_21_no_backup_age(tmp_path):

    assert monitor.find_backup_age_hours(
        tmp_path,
        datetime.now(timezone.utc),
    ) is None


def test_22_report_refuses_overwrite(
    tmp_path,
    monkeypatch,
    metrics,
):

    report = (
        tmp_path / "docs" / "day76.md"
    )

    report.parent.mkdir()

    report.write_text(
        "KEEP"
    )

    monkeypatch.setattr(
        monitor,
        "collect_metrics",
        lambda: metrics,
    )

    with pytest.raises(
        monitor.MonitoringError,
        match="already exists",
    ):

        monitor.run_monitor(
            tmp_path / "backups" / "snap",
            tmp_path / "backups",
            report,
        )

    assert report.read_text() == "KEEP"


def test_23_snapshot_must_be_under_backup(
    tmp_path,
    monkeypatch,
    metrics,
):

    monkeypatch.setattr(
        monitor,
        "collect_metrics",
        lambda: metrics,
    )

    with pytest.raises(
        monitor.MonitoringError,
        match="inside",
    ):

        monitor.run_monitor(
            tmp_path / "elsewhere",
            tmp_path / "backups",
            None,
        )


def test_24_run_monitor_without_db_using_mock(
    tmp_path,
    monkeypatch,
    metrics,
):

    backups = (
        tmp_path / "backups"
    )

    backups.mkdir()

    (
        backups / "queryforge_day75_test.backup"
    ).write_bytes(
        b"abc"
    )

    monkeypatch.setattr(
        monitor,
        "collect_metrics",
        lambda: metrics,
    )

    report = (
        tmp_path / "docs" / "report.md"
    )

    assert monitor.run_monitor(
        backups / "day76_monitor",
        backups,
        report,
    ) == 0

    assert "## Status: PASS" in report.read_text()

    saved = list(
        (
            backups / "day76_monitor"
        ).glob("*.json")
    )

    assert len(saved) == 1

    assert json.loads(
        saved[0].read_text()
    )["status"] == "PASS"


def test_25_wrong_database_rejected(monkeypatch):

    monkeypatch.setenv(
        "DB_NAME",
        "postgres",
    )

    with pytest.raises(
        monitor.MonitoringError
    ):

        monitor.connection_settings()


def test_26_explicit_run_required():

    with pytest.raises(SystemExit) as error:

        monitor.main([])

    assert error.value.code == 2


def test_27_live_failure_exit_code(
    tmp_path,
    monkeypatch,
):

    def fail():
        raise monitor.MonitoringError(
            "intentionally offline"
        )

    monkeypatch.setattr(
        monitor,
        "collect_metrics",
        fail,
    )

    assert monitor.main(
        [
            "--run-live",
            "--backup-dir",
            str(tmp_path / "backups"),
            "--snapshot-dir",
            str(
                tmp_path / "backups" / "monitor"
            ),
        ]
    ) == 1


def test_28_fail_overrides_warning(metrics):

    metrics["invalid_indexes"] = 2
    metrics["day74_stalled_jobs"] = 1

    assert monitor.evaluate(
        metrics,
        None,
        None,
    )[0] == "FAIL"
