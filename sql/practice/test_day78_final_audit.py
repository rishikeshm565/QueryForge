
"""Day 78 offline tests. No PostgreSQL connection required."""

from __future__ import annotations

import hashlib
from pathlib import Path

import pytest

import day78_final_audit as m


@pytest.fixture
def day75():

    rows = "".join(
        f"| `s.t{i}` | {i} | {i} | PASS |\n"
        for i in range(17)
    )

    return (
        "- Custom archive inspection: PASS\n"
        "- Restored database table counts: PASS\n"
        "- Partition and materialized view structure: PASS\n"
        "- Restore test database: "
        "`qf_restore_d75_20261018_165559_5a45cd89`\n"
        "- Backup archive (outside Git): "
        "`queryforge_day75_20261018_165559_5a45cd89.backup`\n"
        "- SHA-256: `"
        + "a" * 64
        + "`\n"
        + rows
    )


@pytest.fixture
def day76():

    return (
        "## Status: PASS\n"
        "- PostgreSQL transaction: READ ONLY\n"
        "| `day74_checkpoint_mismatches` | 0 |\n"
        "| `day74_invalid_jobs` | 0 |\n"
        "| `day74_stalled_jobs` | 0 |\n"
        "| `invalid_indexes` | 0 |\n"
        "| `materialized_view_populated` | 1 |\n"
        "| `partition_count` | 4 |\n"
    )


@pytest.fixture
def workflow():

    bs = chr(92)

    return (
        "permissions:\n"
        "  contents: read\n"
        "pull_request:\n"
        "workflow_dispatch:\n"
        "python-version: ['3.12', '3.13']\n"
        "            sql/practice/day76_monitoring_alerts.py "
        + bs
        + "\n"
        "            sql/practice/test_day77_ci_workflow.py\n"
        "            sql/practice/test_day77_ci_workflow.py "
        + bs
        + "\n"
        "            --junitxml=reports/results.xml\n"
        + "".join(
            "--deselect=sql/practice/" + item + "\n"
            for item in m.EXCLUDED
        )
    )


def test_01_required_days():

    assert len(m.DAYS) == 19
    assert m.DAYS[-1] == 78


def test_02_exact_exclusion_count():

    assert len(m.EXCLUDED) == 11
    assert len(set(m.EXCLUDED)) == 11


def test_03_day75_valid(day75):

    data = m.backup_report(day75)

    assert data["tables"] == 17

    assert data["rows"] == sum(range(17))


def test_04_day75_missing_pass(day75):

    with pytest.raises(m.AuditError):

        m.backup_report(
            day75.replace(
                "Custom archive inspection: PASS",
                "FAIL",
            )
        )


def test_05_day75_missing_table(day75):

    with pytest.raises(m.AuditError):

        m.backup_report(
            day75.replace(
                "| `s.t0` | 0 | 0 | PASS |\n",
                "",
            )
        )


def test_06_day75_unsafe_filename(day75):

    with pytest.raises(m.AuditError):

        m.backup_report(
            day75.replace(
                "queryforge_day75_20261018_165559_5a45cd89.backup",
                "../bad.backup",
            )
        )


def test_07_day75_bad_hash(day75):

    with pytest.raises(m.AuditError):

        m.backup_report(
            day75.replace(
                "a" * 64,
                "bad",
            )
        )


def test_08_day75_count_mismatch(day75):

    with pytest.raises(m.AuditError):

        m.backup_report(
            day75.replace(
                "| `s.t1` | 1 | 1 | PASS |",
                "| `s.t1` | 1 | 2 | PASS |",
            )
        )


def test_09_day76_valid(day76):

    assert (
        m.monitor_report(day76)["status"]
        == "PASS"
    )


def test_10_day76_bad_index(day76):

    with pytest.raises(m.AuditError):

        m.monitor_report(
            day76.replace(
                "`invalid_indexes` | 0",
                "`invalid_indexes` | 1",
            )
        )


def test_11_day76_missing_metric(day76):

    with pytest.raises(m.AuditError):

        m.monitor_report(
            day76.replace(
                "| `partition_count` | 4 |\n",
                "",
            )
        )


def test_12_day76_warn(day76):

    with pytest.raises(m.AuditError):

        m.monitor_report(
            day76.replace(
                "## Status: PASS",
                "## Status: WARN",
            )
        )


def test_13_ci_patch(workflow):

    output = m.ci_updated(workflow)

    assert (
        "sql/practice/test_day78_final_audit.py"
        in output
    )

    assert (
        "sql/practice/day78_final_audit.py"
        in output
    )

    assert output.count("--deselect=") == 11


def test_14_ci_patch_idempotent(workflow):

    once = m.ci_updated(workflow)

    assert m.ci_updated(once) == once


def test_15_ci_patch_rejects_unknown(workflow):

    with pytest.raises(m.AuditError):

        m.ci_updated(
            workflow.replace(
                "            --junitxml=",
                "            --other=",
            )
        )


def test_16_ci_patch_rejects_partial(workflow):

    with pytest.raises(m.AuditError):

        m.ci_updated(
            workflow
            + "sql/practice/test_day78_final_audit.py"
        )


def test_17_ci_valid_after_patch(workflow):

    m.validate_ci(
        m.ci_updated(workflow)
    )


def test_18_ci_rejects_write_permission(workflow):

    with pytest.raises(m.AuditError):

        m.validate_ci(
            m.ci_updated(workflow)
            + "\ncontents: write\n"
        )


def test_19_ci_rejects_missing_exclusion(workflow):

    with pytest.raises(m.AuditError):

        m.validate_ci(
            m.ci_updated(workflow).replace(
                "--deselect=",
                "--skip=",
                1,
            )
        )


def test_20_secret_filename_detection():

    with pytest.raises(m.AuditError):

        m.check_tracked_files(
            ["README.md", ".env"]
        )


def test_21_backup_filename_detection():

    with pytest.raises(m.AuditError):

        m.check_tracked_files(
            ["backups/private.backup"]
        )


def test_22_example_env_allowed():

    m.check_tracked_files(
        [".env.example", "README.md"]
    )


def test_23_sha256(tmp_path):

    sample = tmp_path / "sample.backup"

    sample.write_bytes(
        b"PGDMPdemo"
    )

    expected = hashlib.sha256(
        b"PGDMPdemo"
    ).hexdigest()

    assert m.sha256_file(sample) == expected


@pytest.fixture
def facts():

    return {
        "at": "2026-10-19 00:00:00",
        "commit": "ab1395b",
        "restore": "qf_restore_d75_test",
        "archive": "demo.backup",
        "tables": 17,
        "digest": "a" * 64,
        "test_groups": 19,
    }


def test_24_audit_discloses_limitations(facts):

    text = m.make_audit(facts)

    assert (
        "does not connect to PostgreSQL"
        in text
    )

    assert (
        "confirmed in Actions after pushing"
        in text
    )

    assert "Result: PASS" in text


def test_25_portfolio_includes_evidence(facts):

    text = m.make_portfolio(facts)

    assert "Day 75" in text
    assert "Day 78" in text

    assert (
        "No automated production deployment is claimed"
        in text
    )


def test_26_explicit_cli_flag_required():

    with pytest.raises(SystemExit) as exc:

        m.main([])

    assert exc.value.code == 2


def test_27_no_report_overwrite(tmp_path):

    docs = tmp_path / "docs"
    docs.mkdir()

    report = (
        docs / "day78_final_project_audit.md"
    )

    report.write_text(
        "KEEP"
    )

    result = m.main(
        [
            "--repo",
            str(tmp_path),
            "--audit",
        ]
    )

    assert result == 1
    assert report.read_text() == "KEEP"


def test_28_real_ci_has_day78_inclusion():

    root = (
        Path(__file__).resolve().parents[2]
    )

    workflow_file = (
        root
        / ".github/workflows/queryforge-ci.yml"
    )

    content = workflow_file.read_text(
        encoding="utf-8"
    )

    m.validate_ci(content)


def test_29_requirements_present():

    root = (
        Path(__file__).resolve().parents[2]
    )

    assert (
        root / "requirements-ci.txt"
    ).is_file()
