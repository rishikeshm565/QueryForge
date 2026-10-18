# QueryForge Day 75 - Backup and Disaster Recovery

Generated UTC: 2026-10-18 16:55:59

## Results

- Source: `queryforge_dev`
- Restore test database: `qf_restore_d75_20261018_165559_5a45cd89`
- Backup archive (outside Git): `queryforge_day75_20261018_165559_5a45cd89.backup`
- Archive bytes: 36677521
- SHA-256: `c73f10e22c39af53a40af6953700e843225b4ab37e4cc561a0d6bc312da59de1`
- Custom archive inspection: PASS
- Restored database table counts: PASS
- Partition and materialized view structure: PASS
- Source database was not changed by this script
- Restored test database retained for inspection

## Row counts

| Table | Source | Restored | Check |
|---|---:|---:|---|
| `scale.customers_big` | 100000 | 100000 | PASS |
| `scale.orders_big` | 1000000 | 1000000 | PASS |
| `scale.payments_big` | 2000000 | 2000000 | PASS |
| `scale.orders_partitioned` | 300000 | 300000 | PASS |
| `analytics.mv_monthly_order_summary` | 144 | 144 | PASS |
| `etl.file_upload_registry` | 0 | 0 | PASS |
| `etl.customer_upload_rows` | 0 | 0 | PASS |
| `qf_day72.file_uploads` | 1 | 1 | PASS |
| `qf_day72.customer_rows` | 4 | 4 | PASS |
| `qf_day72.rejected_rows` | 2 | 2 | PASS |
| `qf_day73.jobs` | 1 | 1 | PASS |
| `qf_day73.processed_customers` | 4 | 4 | PASS |
| `qf_day73.batch_history` | 2 | 2 | PASS |
| `qf_day74.jobs` | 1 | 1 | PASS |
| `qf_day74.source_snapshot` | 4 | 4 | PASS |
| `qf_day74.processed_rows` | 4 | 4 | PASS |
| `qf_day74.batch_history` | 2 | 2 | PASS |

## Structure

- Partition key: `RANGE (order_date)`
- Direct partitions: 4
- Materialized view populated: True

## Limitations

- Same-server restore, not an offsite disaster simulation.
- Database-global roles, filesystem permissions, replication, and recovery time targets need separate validation.
- Concurrent source writes can cause the before-dump count comparison to differ; pause ETL writers during this audit.
- Do not commit backup archives or secrets to Git.
