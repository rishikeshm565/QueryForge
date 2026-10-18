# QueryForge Day 76 - ETL Monitoring and Alerts

Generated UTC: 2026-10-18 18:58:49

## Status: PASS

- PostgreSQL transaction: READ ONLY
- Source database: `queryforge_dev`
- Previous monitoring snapshot: YES
- Latest Day 75 backup age (hours): 2
- Customer names, emails, passwords and individual records: NOT INCLUDED

## Metrics

| Metric | Count |
|---|---:|
| `analytics.mv_monthly_order_summary` | 144 |
| `day74_checkpoint_mismatches` | 0 |
| `day74_completed_jobs` | 1 |
| `day74_invalid_jobs` | 0 |
| `day74_running_jobs` | 0 |
| `day74_stalled_jobs` | 0 |
| `etl.file_upload_registry` | 0 |
| `invalid_indexes` | 0 |
| `materialized_view_populated` | 1 |
| `partition_count` | 4 |
| `qf_day72.customer_rows` | 4 |
| `qf_day72.file_uploads` | 1 |
| `qf_day72.rejected_rows` | 2 |
| `qf_day73.batch_history` | 2 |
| `qf_day73.jobs` | 1 |
| `qf_day73.processed_customers` | 4 |
| `qf_day74.batch_history` | 2 |
| `qf_day74.jobs` | 1 |
| `qf_day74.processed_rows` | 4 |
| `scale.orders_partitioned` | 300000 |

## Alerts

- None

## Scope

- Checks counts, Day 74 checkpoint invariants, stale running jobs, indexes, partitions and materialized view state.
- Compares aggregate counts with the preceding local snapshot if present.
- Local snapshots and backup archives stay outside Git.
- This is a point-in-time check; it is not a continuously running alert service.
- Backup presence/age alone does not prove restorability; Day 75 verified one isolated restore.
