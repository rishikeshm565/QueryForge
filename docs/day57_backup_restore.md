# QueryForge - Day 57: Backup and Restore

## Verification status

Historical backup and restore notes were recovered.

The original notes claimed a successful backup and
restore, but the database counts and complete restore
logs were not recorded in the supplied document.

Therefore operational restore validation remains
PENDING, not PASS.

## Tools

PostgreSQL 18 utilities:

- pg_dump
- pg_restore
- psql

## Backup location

Local backup directory: D:\QueryForge\backups

This directory is excluded from Git.

Database backups must never be committed to GitHub.

## Backup procedure

1. Confirm connection to queryforge_dev.
2. Confirm the PostgreSQL command-line tools work.
3. Create a custom-format pg_dump archive.
4. Record backup filename, size, date and exit status.
5. Inspect the archive using pg_restore --list.
6. Preserve logs showing the result.

Do not overwrite an existing backup unintentionally.

## Restore verification procedure

1. Choose a new, isolated test database name.
2. Confirm that test database does not already exist.
3. Create the new test database.
4. Restore the archive using pg_restore.
5. Check the restore command exit status.
6. Compare source and restored database row counts.
7. Check important schemas, tables and constraints.
8. Record the actual evidence.

Never automatically drop an existing database.
Never run restore verification against queryforge_dev.

## Required verification evidence

- Backup archive exists
- Backup archive can be listed
- Restore succeeds without unexpected errors
- scale.customers_big counts match
- scale.orders_partitioned counts match
- Important schemas and constraints exist
- Source database remains unchanged

## Final status

Documentation reviewed.
Historical backup/restore PASS claim not independently
verified.

Operational disaster-recovery test: PENDING.
