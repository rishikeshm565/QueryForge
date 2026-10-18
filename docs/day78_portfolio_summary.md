# QueryForge — SQL, PostgreSQL and Python ETL Portfolio

## Project overview

QueryForge demonstrates SQL, data validation, Excel ingestion, resilient ETL, PostgreSQL checkpoints, concurrency, backup/restore, monitoring and GitHub Actions automated testing.

## Architecture

Excel/data inputs → Python validation → PostgreSQL ETL → audit/reconciliation → monitoring → GitHub Actions CI.

## Project milestones

- **Day 72:** Excel ETL validation and rejected row handling.
- **Day 73:** Durable checkpoints and resume processing.
- **Day 74:** Concurrent workers and rollback verification.
- **Day 75:** Isolated restore `qf_restore_d75_20261018_165559_5a45cd89` with 17 matching table counts.
- **Day 76:** Read-only ETL monitoring and alerts.
- **Day 77:** Offline CI for Python 3.12 and 3.13.
- **Day 78:** Non-destructive evidence audit.

## Project demonstration

1. Show `docs/day75_backup_restore.md`.
2. Explain how restoring a backup was verified.
3. Show `docs/day76_monitoring_alerts.md`.
4. Demonstrate ETL checkpoint and concurrency recovery.
5. Show current GitHub Actions results.

## Interview talking points

**Why checkpoints?** Resume ETL from committed progress.

**Why restore testing?** A backup should be proven restorable.

**Why offline CI?** Test pure logic without production credentials.

**Why separate database integration tests?** They require a controlled PostgreSQL environment.

## Production readiness gaps

- Dedicated least-privilege database accounts and secret management.
- Approved deployments and migration rollback procedures.
- Offsite backup and independent recovery testing.
- Scheduled monitoring and external alert delivery.

## Evidence limitations

- Backup and monitoring reports are timestamped historical evidence.
- No automated production deployment is claimed.
- Final GitHub Actions status must be checked independently.
