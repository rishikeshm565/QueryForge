
BEGIN TRANSACTION READ ONLY;

SET LOCAL statement_timeout = '60s';

-- QueryForge Day 70
-- Final database verification
-- READ ONLY - no persistent changes

-- 1. Database identity and transaction safety

SELECT
    current_database() AS database_name,
    current_setting('transaction_read_only') AS read_only;


-- 2. Main project tables

SELECT
    'core.customer_master' AS relation_name,
    COUNT(*) AS rows_found
FROM core.customer_master

UNION ALL
SELECT
    'staging.customer_upload',
    COUNT(*)
FROM staging.customer_upload

UNION ALL
SELECT
    'dq.customer_quarantine',
    COUNT(*)
FROM dq.customer_quarantine

UNION ALL
SELECT
    'audit.customer_change_log',
    COUNT(*)
FROM audit.customer_change_log

UNION ALL
SELECT
    'scale.customers_big',
    COUNT(*)
FROM scale.customers_big

UNION ALL
SELECT
    'scale.orders_big',
    COUNT(*)
FROM scale.orders_big

UNION ALL
SELECT
    'scale.payments_big',
    COUNT(*)
FROM scale.payments_big

UNION ALL
SELECT
    'scale.orders_partitioned',
    COUNT(*)
FROM scale.orders_partitioned

UNION ALL
SELECT
    'analytics.mv_monthly_order_summary',
    COUNT(*)
FROM analytics.mv_monthly_order_summary

UNION ALL
SELECT
    'etl.file_upload_registry',
    COUNT(*)
FROM etl.file_upload_registry

UNION ALL
SELECT
    'etl.customer_upload_rows',
    COUNT(*)
FROM etl.customer_upload_rows

ORDER BY relation_name;


-- 3. Partition strategy

SELECT
    pg_get_partkeydef(
        to_regclass('scale.orders_partitioned')
    ) AS partition_key;


-- 4. Attached partitions and boundaries

SELECT
    child.relname AS child_partition,
    pg_get_expr(
        child.relpartbound,
        child.oid
    ) AS partition_bounds
FROM pg_inherits i
JOIN pg_class child
    ON child.oid = i.inhrelid
WHERE i.inhparent =
    to_regclass('scale.orders_partitioned')
ORDER BY child.relname;


-- 5. Source versus materialized summary

SELECT
    (
        SELECT COUNT(*)
        FROM scale.orders_partitioned
    ) AS source_orders,

    (
        SELECT COALESCE(SUM(total_orders), 0)
        FROM analytics.mv_monthly_order_summary
    ) AS summarized_orders,

    (
        SELECT COALESCE(SUM(amount), 0)
        FROM scale.orders_partitioned
    ) AS source_amount,

    (
        SELECT COALESCE(SUM(total_amount), 0)
        FROM analytics.mv_monthly_order_summary
    ) AS summarized_amount;


-- 6. Valid unique index on materialized view

SELECT EXISTS (
    SELECT 1
    FROM pg_index i
    WHERE i.indrelid =
        to_regclass(
            'analytics.mv_monthly_order_summary'
        )
      AND i.indisunique
      AND i.indisvalid
      AND i.indisready
      AND i.indnkeyatts = 2
      AND pg_get_indexdef(
          i.indexrelid, 1, TRUE
      ) = 'month'
      AND pg_get_indexdef(
          i.indexrelid, 2, TRUE
      ) = 'status'
) AS unique_materialized_view_index_valid;


-- 7. End read-only transaction

ROLLBACK;
