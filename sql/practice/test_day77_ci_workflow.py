
"""Day 77: offline GitHub Actions CI safety tests."""

from pathlib import Path
import re

import pytest


ROOT = Path(__file__).resolve().parents[2]

WORKFLOW = (
    ROOT / ".github/workflows/queryforge-ci.yml"
)

REQUIREMENTS = ROOT / "requirements-ci.txt"

DOC = ROOT / "docs/day77_ci_cd.md"


DAYS = (
    "58_error_handling",
    "59_validation",
    "61_etl_registry",
    "62_etl_pipeline",
    "63_performance_report",
    "64_etl_reconciliation",
    "65_etl_monitoring",
    "66_end_to_end_validation",
    "67_incremental_upsert",
    "68_data_quality",
    "69_batch_recovery",
    "70_final_project_audit",
    "72_real_excel_etl",
    "73_persistent_checkpoints",
    "74_crash_concurrency",
    "75_backup_restore",
    "76_monitoring_alerts",
    "77_ci_workflow",
)


def content() -> str:
    return WORKFLOW.read_text(
        encoding="utf-8"
    )


def test_01_workflow_exists():
    assert WORKFLOW.is_file()


def test_02_requirements_exists():
    assert REQUIREMENTS.is_file()


def test_03_documentation_exists():
    assert DOC.is_file()


def test_04_push_pr_manual_triggers():

    data = content()

    assert re.search(
        r"(?m)^on:\s*$",
        data,
    )

    for event in (
        "push",
        "pull_request",
        "workflow_dispatch",
    ):

        assert re.search(
            rf"(?m)^  {event}:\s*$",
            data,
        )


def test_05_only_main_branch():

    assert content().count(
        "branches: [main]"
    ) == 2


def test_06_minimal_permissions():

    data = content()

    assert re.search(
        r"(?m)^permissions:\s*\n  contents: read\s*$",
        data,
    )

    assert "contents: write" not in data


def test_07_no_privileged_pr_trigger():

    assert "pull_request_target" not in content()


def test_08_no_secrets_used():

    assert "secrets." not in content()


def test_09_database_is_unreachable_in_ci():

    data = content()

    assert "DB_HOST: '127.0.0.1'" in data
    assert "DB_PORT: '1'" in data

    assert "services:" not in data


def test_10_two_python_versions():

    assert (
        "python-version: ['3.12', '3.13']"
        in content()
    )


def test_11_uses_standard_actions():

    data = content()

    for name in (
        "actions/checkout@v4",
        "actions/setup-python@v5",
        "actions/upload-artifact@v4",
    ):

        assert name in data


def test_12_timeout_and_cancellation():

    data = content()

    assert "timeout-minutes: 20" in data

    assert "cancel-in-progress: true" in data


def test_13_dependencies_installed():

    assert (
        "python -m pip install -r requirements-ci.txt"
        in content()
    )


def test_14_compilation_check():

    data = content()

    assert "python -m py_compile" in data

    assert (
        "sql/practice/day76_monitoring_alerts.py"
        in data
    )


@pytest.mark.parametrize("day", DAYS)
def test_15_every_training_test_is_in_ci(day):

    file = f"sql/practice/test_day{day}.py"

    assert file in content(), (
        f"CI missing: {file}"
    )

    assert (ROOT / file).is_file(), (
        f"File missing: {file}"
    )


def test_16_junit_results():

    data = content()

    assert (
        "--junitxml=reports/pytest-"
        in data
    )

    assert "retention-days: 7" in data


def test_17_no_deployment_step():

    data = content().lower()

    for dangerous in (
        "kubectl",
        "terraform apply",
        "docker push",
        "git push",
        "pg_restore",
        "pg_dump",
    ):

        assert dangerous not in data


def test_18_no_database_live_scripts():

    data = content()

    assert "--run-full" not in data

    assert "--run-live" not in data

    assert "--mode commit" not in data


def test_19_minimum_requirements():

    req = REQUIREMENTS.read_text(
        encoding="utf-8"
    ).lower()

    for package in (
        "pytest",
        "pytest-subtests",
        "pandas",
        "numpy",
        "openpyxl",
        "python-dotenv",
        "psycopg",
    ):

        assert package in req


def test_20_documentation_marks_actions_pending():

    doc = DOC.read_text(
        encoding="utf-8"
    ).lower()

    assert (
        "pending until the run is verified"
        in doc
    )

    assert (
        "no automated production deployment"
        in doc
    )
