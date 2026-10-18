
"""QueryForge Day 78: non-destructive final evidence audit."""

from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys

from datetime import datetime, timezone
from pathlib import Path


DAYS = (
    58, 59, 61, 62, 63, 64, 65,
    66, 67, 68, 69, 70, 72, 73,
    74, 75, 76, 77, 78,
)

EXCLUDED = (
    "test_day61_etl_registry.py::test_01_correct_database",
    "test_day61_etl_registry.py::test_02_registry_structure",
    "test_day61_etl_registry.py::test_03_registry_constraints",
    "test_day61_etl_registry.py::test_04_no_duplicate_hashes",
    "test_day61_etl_registry.py::test_05_insert_and_rollback",
    "test_day61_etl_registry.py::test_06_duplicate_hash_rejected",
    "test_day62_etl_pipeline.py::test_04_invalid_excel_rejected_before_insert",
    "test_day62_etl_pipeline.py::test_05_actual_insert_and_rollback",
    "test_day62_etl_pipeline.py::test_06_duplicate_file_blocked",
    "test_day62_etl_pipeline.py::test_07_same_customer_ids_in_different_uploads",
    "test_day62_etl_pipeline.py::test_08_db_failure_rolls_back_registry_savepoint",
)


class AuditError(RuntimeError):
    pass


def ci_updated(original: str) -> str:
    """Safely add Day 78 to the existing CI workflow."""

    if "sql/practice/test_day78_final_audit.py" in original:

        if "sql/practice/day78_final_audit.py" not in original:
            raise AuditError(
                "Day 78 CI configuration is partially updated"
            )

        return original

    newline = "\r\n" if "\r\n" in original else "\n"
    backslash = chr(92)

    first = (
        "            sql/practice/day76_monitoring_alerts.py "
        + backslash
        + newline
        + "            sql/practice/test_day77_ci_workflow.py"
    )

    replacement = (
        "            sql/practice/day76_monitoring_alerts.py "
        + backslash
        + newline
        + "            sql/practice/day78_final_audit.py "
        + backslash
        + newline
        + "            sql/practice/test_day77_ci_workflow.py"
    )

    second = (
        "            sql/practice/test_day77_ci_workflow.py "
        + backslash
        + newline
        + "            --junitxml="
    )

    second_new = (
        "            sql/practice/test_day77_ci_workflow.py "
        + backslash
        + newline
        + "            sql/practice/test_day78_final_audit.py "
        + backslash
        + newline
        + "            --junitxml="
    )

    if (
        original.count(first) != 1
        or original.count(second) != 1
    ):
        raise AuditError(
            "Workflow structure changed. Refusing automatic edit."
        )

    return (
        original
        .replace(first, replacement, 1)
        .replace(second, second_new, 1)
    )


def backup_report(text: str) -> dict:

    required = (
        "Custom archive inspection: PASS",
        "Restored database table counts: PASS",
        "Partition and materialized view structure: PASS",
    )

    for marker in required:

        if marker not in text:
            raise AuditError(
                "Day 75 evidence missing: " + marker
            )

    archive = re.search(
        r"^- Backup archive \(outside Git\): `([^`]+)`$",
        text,
        re.M,
    )

    digest = re.search(
        r"^- SHA-256: `([0-9a-f]{64})`$",
        text,
        re.M,
    )

    restored_db = re.search(
        r"^- Restore test database: `(qf_restore_d75_[a-zA-Z0-9_]+)`$",
        text,
        re.M,
    )

    if not archive or not digest or not restored_db:
        raise AuditError(
            "Day 75 backup metadata is incomplete"
        )

    archive_name = archive.group(1)

    if not re.fullmatch(
        r"queryforge_day75_\d{8}_\d{6}_[0-9a-f]{8}\.backup",
        archive_name,
    ):
        raise AuditError(
            "Invalid backup archive filename"
        )

    rows = re.findall(
        r"^\| `([^`]+)` \| (\d+) \| (\d+) \| PASS \|$",
        text,
        re.M,
    )

    if (
        len(rows) != 17
        or len({row[0] for row in rows}) != 17
    ):
        raise AuditError(
            "Expected exactly 17 unique table comparisons"
        )

    if any(
        source != restored
        for _, source, restored in rows
    ):
        raise AuditError(
            "Source and restored table counts differ"
        )

    return {
        "archive": archive_name,
        "digest": digest.group(1),
        "restore": restored_db.group(1),
        "tables": len(rows),
        "rows": sum(int(row[1]) for row in rows),
    }


def monitor_report(text: str) -> dict:

    if (
        "## Status: PASS" not in text
        or "- PostgreSQL transaction: READ ONLY" not in text
    ):
        raise AuditError(
            "Day 76 saved monitoring report is not PASS/read-only"
        )

    values = {
        key: int(value)
        for key, value in re.findall(
            r"^\| `([a-z0-9_.]+)` \| (\d+) \|$",
            text,
            re.M,
        )
    }

    required = {
        "day74_checkpoint_mismatches": 0,
        "day74_invalid_jobs": 0,
        "day74_stalled_jobs": 0,
        "invalid_indexes": 0,
        "materialized_view_populated": 1,
        "partition_count": 4,
    }

    for key, expected in required.items():

        if values.get(key) != expected:
            raise AuditError(
                f"Day 76 metric {key}: expected "
                f"{expected}, got {values.get(key)}"
            )

    return {
        "metrics": len(values),
        "status": "PASS",
    }


def validate_ci(text: str) -> None:

    required = (
        "pull_request:",
        "workflow_dispatch:",
        "contents: read",
        "python-version: ['3.12', '3.13']",
        "sql/practice/day78_final_audit.py",
        "sql/practice/test_day78_final_audit.py",
        "--junitxml=",
    )

    for item in required:

        if item not in text:
            raise AuditError(
                "CI workflow missing: " + item
            )

    if text.count("--deselect=") != 11:
        raise AuditError(
            "CI must exclude exactly 11 database tests"
        )

    for test in EXCLUDED:

        if "--deselect=sql/practice/" + test not in text:
            raise AuditError(
                "Missing CI database exclusion: " + test
            )

    forbidden = (
        "pull_request_target:",
        "contents: write",
        "secrets.",
        "pg_restore ",
        "--run-full",
        "--run-live",
        "docker push",
    )

    for item in forbidden:

        if item in text:
            raise AuditError(
                "Unsafe CI action: " + item
            )


def sha256_file(path: Path) -> str:

    digest = hashlib.sha256()

    with path.open("rb") as handle:

        for piece in iter(
            lambda: handle.read(1024 * 1024),
            b"",
        ):
            digest.update(piece)

    return digest.hexdigest()


def git(root: Path, *args: str) -> str:

    result = subprocess.run(
        ["git", *args],
        cwd=root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )

    if result.returncode != 0:
        raise AuditError(
            f"Git command failed: {' '.join(args)} "
            f"{result.stderr.strip()}"
        )

    return result.stdout.strip()


def check_tracked_files(names: list[str]) -> None:

    for path in names:

        name = Path(path).name.lower()

        if (
            name in {
                ".env",
                ".env.local",
                ".pgpass",
                "id_rsa",
            }
            or name.endswith(
                (
                    ".backup",
                    ".pem",
                    ".p12",
                    ".key",
                    ".sqlite",
                )
            )
        ):
            raise AuditError(
                "Potential secret or backup tracked by Git: "
                + path
            )


def make_audit(data: dict) -> str:

    lines = [
        "# QueryForge — Day 78 Final Project Audit",
        "",
        f"Generated UTC: {data['at']}",
        "",
        "**Result: PASS (historical evidence and archive integrity)**",
        "",
        "## Verification evidence",
        "",
        f"- Git base commit: `{data['commit']}`",
        f"- Day 75 restore comparison: {data['tables']} tables matched.",
        f"- Isolated restore database: `{data['restore']}`.",
        f"- Local archive: `{data['archive']}`.",
        f"- Independently verified SHA-256: `{data['digest']}`.",
        "- Day 76 saved monitoring report: PASS.",
        "- Invalid indexes, stalled jobs and checkpoint mismatches: 0.",
        "- GitHub Actions: Python 3.12 and 3.13 offline CI.",
        "- CI excludes 11 database integration tests.",
        f"- Test-day groups found: {data['test_groups']}.",
        "- Tracked Git paths scanned for obvious backup/secret filenames.",
        "",
        "## Safety and scope",
        "",
        "- This audit does not connect to PostgreSQL, execute SQL, restore data, or deploy.",
        "- Day 75 and Day 76 reports are historical snapshots.",
        "- Same-server restore is not an offsite disaster recovery test.",
        "- Database integration tests need a separate controlled database environment.",
        "- GitHub-hosted CI for the final Day 78 commit must be confirmed in Actions after pushing.",
        "- Production CD and scheduled alert delivery are not configured.",
        "",
        "## Final checklist",
        "",
        "- [x] Backup integrity",
        "- [x] Restore evidence",
        "- [x] Monitoring evidence",
        "- [x] CI configuration audit",
        "- [x] Tracked filename audit",
        "- [ ] Verify final GitHub Actions run after pushing",
        "- [ ] Define offsite recovery and production deployment before production use",
        "",
    ]

    return "\n".join(lines)


def make_portfolio(data: dict) -> str:

    lines = [
        "# QueryForge — SQL, PostgreSQL and Python ETL Portfolio",
        "",
        "## Project overview",
        "",
        "QueryForge demonstrates SQL, data validation, Excel ingestion, "
        "resilient ETL, PostgreSQL checkpoints, concurrency, backup/restore, "
        "monitoring and GitHub Actions automated testing.",
        "",
        "## Architecture",
        "",
        "Excel/data inputs → Python validation → PostgreSQL ETL "
        "→ audit/reconciliation → monitoring → GitHub Actions CI.",
        "",
        "## Project milestones",
        "",
        "- **Day 72:** Excel ETL validation and rejected row handling.",
        "- **Day 73:** Durable checkpoints and resume processing.",
        "- **Day 74:** Concurrent workers and rollback verification.",
        f"- **Day 75:** Isolated restore `{data['restore']}` "
        f"with {data['tables']} matching table counts.",
        "- **Day 76:** Read-only ETL monitoring and alerts.",
        "- **Day 77:** Offline CI for Python 3.12 and 3.13.",
        "- **Day 78:** Non-destructive evidence audit.",
        "",
        "## Project demonstration",
        "",
        "1. Show `docs/day75_backup_restore.md`.",
        "2. Explain how restoring a backup was verified.",
        "3. Show `docs/day76_monitoring_alerts.md`.",
        "4. Demonstrate ETL checkpoint and concurrency recovery.",
        "5. Show current GitHub Actions results.",
        "",
        "## Interview talking points",
        "",
        "**Why checkpoints?** Resume ETL from committed progress.",
        "",
        "**Why restore testing?** A backup should be proven restorable.",
        "",
        "**Why offline CI?** Test pure logic without production credentials.",
        "",
        "**Why separate database integration tests?** "
        "They require a controlled PostgreSQL environment.",
        "",
        "## Production readiness gaps",
        "",
        "- Dedicated least-privilege database accounts and secret management.",
        "- Approved deployments and migration rollback procedures.",
        "- Offsite backup and independent recovery testing.",
        "- Scheduled monitoring and external alert delivery.",
        "",
        "## Evidence limitations",
        "",
        "- Backup and monitoring reports are timestamped historical evidence.",
        "- No automated production deployment is claimed.",
        "- Final GitHub Actions status must be checked independently.",
        "",
    ]

    return "\n".join(lines)


def audit(root: Path) -> dict:

    root = root.resolve()

    required = (
        "README.md",
        "requirements-ci.txt",
        ".github/workflows/queryforge-ci.yml",
        "docs/day75_backup_restore.md",
        "docs/day76_monitoring_alerts.md",
        "docs/day77_ci_cd.md",
        "sql/practice/day78_final_audit.py",
        "sql/practice/test_day78_final_audit.py",
    )

    for filename in required:

        path = root / filename

        if (
            not path.is_file()
            or path.stat().st_size == 0
        ):
            raise AuditError(
                "Required file missing or empty: " + filename
            )

    for day in DAYS:

        found = list(
            (root / "sql/practice").glob(
                f"test_day{day}_*.py"
            )
        )

        if not found:
            raise AuditError(
                f"Missing test file group for Day {day}"
            )

    backup = backup_report(
        (
            root / "docs/day75_backup_restore.md"
        ).read_text(encoding="utf-8")
    )

    monitor = monitor_report(
        (
            root / "docs/day76_monitoring_alerts.md"
        ).read_text(encoding="utf-8")
    )

    workflow = (
        root / ".github/workflows/queryforge-ci.yml"
    ).read_text(encoding="utf-8")

    validate_ci(workflow)

    archive = (
        root / "backups" / backup["archive"]
    )

    if (
        not archive.is_file()
        or archive.stat().st_size < 1024
    ):
        raise AuditError(
            "Day 75 backup archive missing"
        )

    if sha256_file(archive) != backup["digest"]:
        raise AuditError(
            "Day 75 backup archive SHA256 mismatch"
        )

    ignored = subprocess.run(
        [
            "git",
            "check-ignore",
            "-q",
            "--",
            str(archive),
        ],
        cwd=root,
        capture_output=True,
        timeout=30,
    )

    if ignored.returncode != 0:
        raise AuditError(
            "Backup archive is not excluded by Git"
        )

    check_tracked_files(
        git(root, "ls-files").splitlines()
    )

    if git(root, "branch", "--show-current") != "main":
        raise AuditError(
            "Expected main branch"
        )

    return {
        "at": datetime.now(
            timezone.utc
        ).strftime("%Y-%m-%d %H:%M:%S"),
        "commit": git(
            root,
            "rev-parse",
            "--short",
            "HEAD",
        ),
        "archive": backup["archive"],
        "digest": backup["digest"],
        "restore": backup["restore"],
        "tables": backup["tables"],
        "monitor": monitor["status"],
        "test_groups": len(DAYS),
    }


def main(argv=None) -> int:

    parser = argparse.ArgumentParser(
        description=__doc__
    )

    parser.add_argument(
        "--repo",
        type=Path,
        default=Path.cwd(),
    )

    choice = parser.add_mutually_exclusive_group(
        required=True
    )

    choice.add_argument(
        "--prepare-ci",
        action="store_true",
    )

    choice.add_argument(
        "--audit",
        action="store_true",
    )

    args = parser.parse_args(argv)
    root = args.repo.resolve()

    try:

        workflow = (
            root / ".github/workflows/queryforge-ci.yml"
        )

        if args.prepare_ci:

            original = workflow.read_text(
                encoding="utf-8"
            )

            updated = ci_updated(
                original
            )

            if updated != original:

                workflow.write_text(
                    updated,
                    encoding="utf-8",
                    newline="",
                )

                print(
                    "DAY 78 CI WORKFLOW UPDATE: PASS"
                )

            else:

                print(
                    "DAY 78 CI WORKFLOW: ALREADY UPDATED"
                )

            return 0

        report = (
            root / "docs/day78_final_project_audit.md"
        )

        portfolio = (
            root / "docs/day78_portfolio_summary.md"
        )

        if report.exists() or portfolio.exists():
            raise AuditError(
                "Day 78 output already exists; "
                "refusing overwrite"
            )

        data = audit(root)

        report.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        report.write_text(
            make_audit(data),
            encoding="utf-8",
        )

        portfolio.write_text(
            make_portfolio(data),
            encoding="utf-8",
        )

        print(
            "DAY 78 EVIDENCE AUDIT: PASS"
        )

        print(
            "Day 75 archive SHA256: PASS"
        )

        print(
            "Day 76 monitoring evidence: PASS"
        )

        print(
            f"Historical test groups found: "
            f"{data['test_groups']}"
        )

        print(
            "Output: docs/day78_final_project_audit.md"
        )

        print(
            "Output: docs/day78_portfolio_summary.md"
        )

        return 0

    except (
        OSError,
        AuditError,
        subprocess.TimeoutExpired,
    ) as exc:

        print(
            f"DAY 78 FAILED: {exc}",
            file=sys.stderr,
        )

        return 1


if __name__ == "__main__":
    raise SystemExit(main())
