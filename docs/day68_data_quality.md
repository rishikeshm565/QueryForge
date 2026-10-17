# QueryForge Day 68 - Advanced Data Quality

Generated: 2026-10-17 15:00:01 UTC

Status: PASS (synthetic demo)

| Metric | Count |
|---|---:|
| Total input rows | 10 |
| Accepted rows | 2 |
| Quarantined rows | 8 |

## Data-quality issues

| Reason | Affected rows |
|---|---:|
| blank_customer_name | 1 |
| credit_limit_outlier | 1 |
| duplicate_customer_id | 2 |
| invalid_credit_limit | 1 |
| invalid_email | 1 |
| missing_or_invalid_id | 1 |
| negative_credit_limit | 1 |

## PostgreSQL verification

DAY 68 PASS: total 10, accepted 2, rejected 8, duplicate rows 2

## Safety and scope

- Synthetic sample rows only
- Temporary PostgreSQL tables and ROLLBACK
- Existing ETL/customer tables are not modified
- Production quarantine deployment is pending
