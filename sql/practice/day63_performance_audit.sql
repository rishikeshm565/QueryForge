
-- ============================================================
-- QUERYFORGE - DAY 63
-- DATABASE PERFORMANCE AUDIT
-- READ ONLY - NO DATA MODIFICATION
-- ============================================================

BEGIN TRANSACTION READ ONLY;

SET LOCAL statement_timeout = '30s';

-- ============================================================
-- 1. VERIFY DATABASE
-- ============================================================

SELECT
    current_database() AS database_name,
    current_user AS connected_user,
    version() AS postgres_version;


-- ============================================================
-- 2. VERIFY REQUIRED TABLES
-- ============================================================

SELECT
    object_name,
    TO_REGCLASS(object_name) AS existing_object
FROM (
    VALUES
        ('scale.customers_big'),
        ('scale.orders_partitioned'),
        ('analytics.mv_monthly_order_summary'),
        ('etl.file_upload_registry'),
        ('etl.customer_upload_rows')
) AS required(object_name);


-- ============================================================
-- 3. CHECK INDEX HEALTH
-- ============================================================

SELECT
    t.relname AS table_name,
    idx.relname AS index_name,
    i.indisvalid AS is_valid,
    i.indisready AS is_ready,
    i.indisunique AS is_unique
FROM pg_index i
JOIN pg_class t
    ON t.oid = i.indrelid
JOIN pg_class idx
    ON idx.oid = i.indexrelid
JOIN pg_namespace n
    ON n.oid = t.relnamespace
WHERE
    (n.nspname = 'scale'
     AND t.relname = 'customers_big')
    OR
    (n.nspname = 'analytics'
     AND t.relname = 'mv_monthly_order_summary')
ORDER BY t.relname, idx.relname;


-- ============================================================
-- 4. PRIMARY KEY LOOKUP
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, full_name
FROM scale.customers_big
WHERE customer_id = 50000;


-- ============================================================
-- 5. CAST ON PRIMARY KEY
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, full_name
FROM scale.customers_big
WHERE customer_id::text = '50000';


-- ============================================================
-- 6. COMPOSITE INDEX
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, city, credit_limit
FROM scale.customers_big
WHERE city = 'Mumbai'
ORDER BY credit_limit DESC
LIMIT 20;


-- ============================================================
-- 7. PARTIAL INDEX
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, is_active
FROM scale.customers_big
WHERE is_active = FALSE
  AND customer_id BETWEEN 1 AND 1000
ORDER BY customer_id
LIMIT 20;


-- ============================================================
-- 8. COVERING INDEX
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT city, full_name, credit_limit
FROM scale.customers_big
WHERE city = 'Mumbai'
LIMIT 100;


-- ============================================================
-- 9. ORDER BY EXPRESSION
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, city, credit_limit
FROM scale.customers_big
WHERE city = 'Mumbai'
ORDER BY credit_limit + 0 DESC
LIMIT 20;


-- ============================================================
-- 10. PARTITION PRUNING
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM scale.orders_partitioned
WHERE order_date >= DATE '2026-01-01'
  AND order_date < DATE '2026-04-01';


-- ============================================================
-- 11. MATERIALIZED VIEW
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    month,
    status,
    total_orders,
    total_amount
FROM analytics.mv_monthly_order_summary
WHERE month = DATE '2026-01-01';


-- ============================================================
-- 12. DATABASE ROW COUNTS
-- ============================================================

SELECT
    (SELECT COUNT(*)
     FROM scale.customers_big) AS customers,

    (SELECT COUNT(*)
     FROM scale.orders_partitioned) AS orders,

    (SELECT COUNT(*)
     FROM analytics.mv_monthly_order_summary)
        AS materialized_rows,

    (SELECT COUNT(*)
     FROM etl.file_upload_registry) AS registered_files,

    (SELECT COUNT(*)
     FROM etl.customer_upload_rows) AS uploaded_customers;


-- ============================================================
-- 13. COMPLETE READ-ONLY AUDIT
-- ============================================================

ROLLBACK;
