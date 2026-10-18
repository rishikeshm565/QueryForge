
"""QueryForge Day 75: safe logical backup and isolated restore audit."""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

import psycopg
from psycopg import sql
from dotenv import load_dotenv


SOURCE = "queryforge_dev"

TABLES = (
    "scale.customers_big",
    "scale.orders_big",
    "scale.payments_big",
    "scale.orders_partitioned",
    "analytics.mv_monthly_order_summary",
    "etl.file_upload_registry",
    "etl.customer_upload_rows",
    "qf_day72.file_uploads",
    "qf_day72.customer_rows",
    "qf_day72.rejected_rows",
    "qf_day73.jobs",
    "qf_day73.processed_customers",
    "qf_day73.batch_history",
    "qf_day74.jobs",
    "qf_day74.source_snapshot",
    "qf_day74.processed_rows",
    "qf_day74.batch_history",
)


class BackupError(Exception):
    pass


def backup_name(moment: datetime, unique: str) -> str:
    return (
        f"queryforge_day75_"
        f"{moment:%Y%m%d_%H%M%S}_{unique}.backup"
    )


def restore_name(moment: datetime, unique: str) -> str:
    return (
        f"qf_restore_d75_"
        f"{moment:%Y%m%d_%H%M%S}_{unique}"
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as stream:
        for chunk in iter(
            lambda: stream.read(1024 * 1024),
            b"",
        ):
            digest.update(chunk)

    return digest.hexdigest()


def binary(name: str) -> str:

    pg_bin = (
        Path(
            os.getenv(
                "ProgramFiles",
                "C:/Program Files",
            )
        )
        / "PostgreSQL"
        / "18"
        / "bin"
    )

    preferred = pg_bin / (
        name + (".exe" if os.name == "nt" else "")
    )

    if preferred.is_file():
        return str(preferred)

    found = shutil.which(name)

    if found:
        return found

    raise BackupError(
        f"Cannot locate {name}"
    )


def credentials() -> dict:

    load_dotenv()

    if os.getenv("DB_NAME", SOURCE) != SOURCE:
        raise BackupError(
            "DB_NAME must be queryforge_dev"
        )

    config = dict(
        host=os.getenv(
            "DB_HOST",
            "localhost",
        ),
        port=os.getenv(
            "DB_PORT",
            "5432",
        ),
        user=os.getenv(
            "DB_USER",
            "postgres",
        ),
    )

    if os.getenv("DB_PASSWORD"):
        config["password"] = os.getenv(
            "DB_PASSWORD"
        )

    return config


def run_command(
    args: list[str],
    env: dict,
) -> str:

    try:
        result = subprocess.run(
            args,
            env=env,
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=7200,
            check=False,
        )

    except (
        OSError,
        subprocess.TimeoutExpired,
    ) as exc:

        raise BackupError(
            f"PostgreSQL tool could not finish: {exc}"
        ) from exc

    if result.returncode != 0:

        raise BackupError(
            f"PostgreSQL tool failed "
            f"(exit {result.returncode}): "
            f"{result.stderr[-2500:]}"
        )

    return result.stdout


def counts(conn) -> dict[str, int]:

    found = {}

    with conn.cursor() as cur:

        for item in TABLES:

            schema, name = item.split(".")

            query = sql.SQL(
                "SELECT COUNT(*) FROM {}.{}"
            ).format(
                sql.Identifier(schema),
                sql.Identifier(name),
            )

            cur.execute(query)

            found[item] = cur.fetchone()[0]

    return found


def structure(conn) -> tuple[str, int, bool]:

    with conn.cursor() as cur:

        cur.execute(
            """
            SELECT pg_get_partkeydef(
                'scale.orders_partitioned'::regclass
            )
            """
        )

        key = cur.fetchone()[0]

        cur.execute(
            """
            SELECT COUNT(*)
            FROM pg_inherits
            WHERE inhparent =
                'scale.orders_partitioned'::regclass
            """
        )

        number = cur.fetchone()[0]

        cur.execute(
            """
            SELECT ispopulated
            FROM pg_matviews
            WHERE schemaname = 'analytics'
              AND matviewname =
                'mv_monthly_order_summary'
            """
        )

        mv_row = cur.fetchone()

    if (
        not key
        or number < 1
        or mv_row is None
    ):
        raise BackupError(
            "Partition or materialized-view "
            "structure missing"
        )

    return key, number, bool(mv_row[0])


def render_report(
    archive: Path,
    digest: str,
    restored_db: str,
    source: dict[str, int],
    structure_result: tuple[str, int, bool],
    time_utc: datetime,
) -> str:

    lines = [
        "# QueryForge Day 75 - Backup and Disaster Recovery",
        "",
        "Generated UTC: "
        + time_utc.strftime("%Y-%m-%d %H:%M:%S"),
        "",
        "## Results",
        "",
        "- Source: `queryforge_dev`",
        f"- Restore test database: `{restored_db}`",
        f"- Backup archive (outside Git): `{archive.name}`",
        f"- Archive bytes: {archive.stat().st_size}",
        f"- SHA-256: `{digest}`",
        "- Custom archive inspection: PASS",
        "- Restored database table counts: PASS",
        "- Partition and materialized view structure: PASS",
        "- Source database was not changed by this script",
        "- Restored test database retained for inspection",
        "",
        "## Row counts",
        "",
        "| Table | Source | Restored | Check |",
        "|---|---:|---:|---|",
    ]

    for name, amount in source.items():

        lines.append(
            f"| `{name}` | {amount} | "
            f"{amount} | PASS |"
        )

    lines.extend(
        [
            "",
            "## Structure",
            "",
            f"- Partition key: `{structure_result[0]}`",
            f"- Direct partitions: {structure_result[1]}",
            f"- Materialized view populated: "
            f"{structure_result[2]}",
            "",
            "## Limitations",
            "",
            "- Same-server restore, not an offsite disaster simulation.",
            "- Database-global roles, filesystem permissions, replication, and recovery time targets need separate validation.",
            "- Concurrent source writes can cause the before-dump count comparison to differ; pause ETL writers during this audit.",
            "- Do not commit backup archives or secrets to Git.",
            "",
        ]
    )

    return "\n".join(lines)


def execute(
    backup_dir: Path,
    report_path: Path,
) -> None:

    settings = credentials()

    dump_path = binary("pg_dump")
    restore_path = binary("pg_restore")

    if report_path.exists():
        raise BackupError(
            f"Report already exists: {report_path}"
        )

    backup_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    if (
        shutil.disk_usage(backup_dir).free
        < 2 * 1024**3
    ):
        raise BackupError(
            "Less than 2 GB free on backup drive; STOP"
        )

    now = datetime.now(timezone.utc)

    unique = uuid.uuid4().hex[:8]

    archive = backup_dir / backup_name(
        now,
        unique,
    )

    target_db = restore_name(
        now,
        unique,
    )

    if archive.exists():
        raise BackupError(
            f"Refusing to overwrite archive: {archive}"
        )

    environment = os.environ.copy()

    if settings.get("password"):
        environment["PGPASSWORD"] = settings[
            "password"
        ]

    # ========================================================
    # 1. SOURCE PREFLIGHT
    # ========================================================

    print(
        "===== SOURCE PREFLIGHT =====",
        flush=True,
    )

    with psycopg.connect(
        **settings,
        dbname=SOURCE,
    ) as source_conn:

        with source_conn.cursor() as cur:

            cur.execute(
                "SELECT current_database()"
            )

            if cur.fetchone()[0] != SOURCE:
                raise BackupError(
                    "Wrong source database"
                )

        source_counts = counts(source_conn)

        source_structure = structure(
            source_conn
        )

    print(
        f"Source: {SOURCE}; "
        f"checked tables: {len(source_counts)}",
        flush=True,
    )

    # ========================================================
    # 2. FULL DATABASE BACKUP
    # ========================================================

    print(
        "===== FULL DATABASE BACKUP =====",
        flush=True,
    )

    run_command(
        [
            dump_path,
            "--no-password",
            "--format=custom",
            "--file",
            str(archive),
            "--host",
            settings["host"],
            "--port",
            str(settings["port"]),
            "--username",
            settings["user"],
            SOURCE,
        ],
        environment,
    )

    if (
        not archive.is_file()
        or archive.stat().st_size < 1024
    ):
        raise BackupError(
            "Backup archive missing "
            "or unexpectedly small"
        )

    checksum = sha256_file(archive)

    archive_listing = run_command(
        [
            restore_path,
            "--list",
            str(archive),
        ],
        environment,
    )

    if (
        "TABLE DATA" not in archive_listing
        or "SCHEMA" not in archive_listing
    ):
        raise BackupError(
            "Expected entries missing "
            "from backup archive"
        )

    print(
        f"Backup: {archive.name}",
        flush=True,
    )

    print(
        f"SHA256: {checksum}",
        flush=True,
    )

    # ========================================================
    # 3. CREATE ISOLATED RESTORE DATABASE
    # ========================================================

    print(
        f"===== CREATE NEW DATABASE: "
        f"{target_db} =====",
        flush=True,
    )

    with psycopg.connect(
        **settings,
        dbname="postgres",
        autocommit=True,
    ) as admin:

        with admin.cursor() as cur:

            cur.execute(
                """
                SELECT 1
                FROM pg_database
                WHERE datname = %s
                """,
                (target_db,),
            )

            if cur.fetchone() is not None:
                raise BackupError(
                    "Target restore database "
                    "already exists"
                )

            cur.execute(
                sql.SQL(
                    "CREATE DATABASE {} "
                    "TEMPLATE template0"
                ).format(
                    sql.Identifier(target_db)
                )
            )

    # ========================================================
    # 4. RESTORE ARCHIVE
    # ========================================================

    print(
        "===== RESTORE ARCHIVE =====",
        flush=True,
    )

    run_command(
        [
            restore_path,
            "--no-password",
            "--exit-on-error",
            "--single-transaction",
            "--no-owner",
            "--no-acl",
            "--dbname",
            target_db,
            "--host",
            settings["host"],
            "--port",
            str(settings["port"]),
            "--username",
            settings["user"],
            str(archive),
        ],
        environment,
    )

    # ========================================================
    # 5. COMPARE SOURCE AND RESTORE
    # ========================================================

    print(
        "===== COMPARE SOURCE AND RESTORE =====",
        flush=True,
    )

    with psycopg.connect(
        **settings,
        dbname=target_db,
    ) as restored:

        restored_counts = counts(restored)

        restored_structure = structure(
            restored
        )

    if source_counts != restored_counts:

        differences = {
            name: (
                source_counts[name],
                restored_counts[name],
            )
            for name in TABLES
            if source_counts[name]
            != restored_counts[name]
        }

        raise BackupError(
            f"Source/restore count mismatch: "
            f"{differences}"
        )

    if source_structure != restored_structure:
        raise BackupError(
            "Partition/materialized-view "
            "structure mismatch"
        )

    # ========================================================
    # 6. GENERATE REPORT
    # ========================================================

    if report_path.exists():
        raise BackupError(
            "Report appeared while running: "
            "refusing overwrite"
        )

    report_path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    report_path.write_text(
        render_report(
            archive,
            checksum,
            target_db,
            source_counts,
            source_structure,
            now,
        ),
        encoding="utf-8",
    )

    print(
        f"REPORT: {report_path}",
        flush=True,
    )

    print(
        f"RESTORE DATABASE RETAINED: {target_db}",
        flush=True,
    )

    print(
        "DAY 75 BACKUP AND RESTORE: PASS",
        flush=True,
    )


def main(argv=None) -> int:

    parser = argparse.ArgumentParser(
        description=__doc__
    )

    parser.add_argument(
        "--run-full",
        action="store_true",
    )

    parser.add_argument(
        "--backup-dir",
        type=Path,
        default=Path("backups"),
    )

    parser.add_argument(
        "--report",
        type=Path,
        default=Path(
            "docs/day75_backup_restore.md"
        ),
    )

    args = parser.parse_args(argv)

    if not args.run_full:
        parser.error(
            "Explicit --run-full is required"
        )

    try:
        execute(
            args.backup_dir,
            args.report,
        )

        return 0

    except (
        BackupError,
        psycopg.Error,
        OSError,
    ) as exc:

        print(
            f"DAY 75 FAILED: {exc}",
            file=sys.stderr,
        )

        print(
            "Any backup archive or test database "
            "created was retained, not deleted.",
            file=sys.stderr,
        )

        return 1


if __name__ == "__main__":
    raise SystemExit(main())
