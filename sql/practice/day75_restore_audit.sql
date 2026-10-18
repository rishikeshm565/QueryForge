
-- ============================================================
-- QUERYFORGE DAY 75
-- RESTORED DATABASE AUDIT
-- READ ONLY
-- ============================================================

BEGIN TRANSACTION READ ONLY;


-- 1. DATABASE INFORMATION

SELECT
    current_database() AS database_name,
    current_user AS db_user,
    pg_size_pretty(
        pg_database_size(current_database())
    ) AS db_size;


-- 2. MAIN DATABASE TABLES

SELECT
    (
        SELECT COUNT(*)
        FROM scale.customers_big
    ) AS customers,

    (
        SELECT COUNT(*)
        FROM scale.orders_big
    ) AS orders,

    (
        SELECT COUNT(*)
        FROM scale.payments_big
    ) AS payments,

    (
        SELECT COUNT(*)
        FROM scale.orders_partitioned
    ) AS partitioned_orders;


-- 3. ETL DATA

SELECT
    (
        SELECT COUNT(*)
        FROM qf_day72.customer_rows
    ) AS day72_valid,

    (
        SELECT COUNT(*)
        FROM qf_day72.rejected_rows
    ) AS day72_rejected,

    (
        SELECT COUNT(*)
        FROM qf_day73.processed_customers
    ) AS day73_processed,

    (
        SELECT COUNT(*)
        FROM qf_day74.processed_rows
    ) AS day74_processed;


-- 4. CRASH RECOVERY STATUS

SELECT
    j.upload_id,
    j.status,
    j.expected_rows,
    j.processed_rows,

    (
        SELECT COUNT(*)
        FROM qf_day74.batch_history b
        WHERE b.upload_id = j.upload_id
    ) AS committed_batches

FROM qf_day74.jobs j
ORDER BY j.upload_id;


-- 5. PARTITION HEALTH

SELECT
    pg_get_partkeydef(
        'scale.orders_partitioned'::regclass
    ) AS partition_key,

    (
        SELECT COUNT(*)
        FROM pg_inherits
        WHERE inhparent =
            'scale.orders_partitioned'::regclass
    ) AS partition_count;


-- 6. MATERIALIZED VIEW

SELECT
    schemaname,
    matviewname,
    ispopulated

FROM pg_matviews

WHERE schemaname = 'analytics';


-- 7. INVALID INDEXES

SELECT
    n.nspname AS schema_name,
    t.relname AS table_name,
    i.relname AS invalid_index

FROM pg_index x

JOIN pg_class t
    ON t.oid = x.indrelid

JOIN pg_class i
    ON i.oid = x.indexrelid

JOIN pg_namespace n
    ON n.oid = t.relnamespace

WHERE n.nspname IN (
    'scale',
    'analytics',
    'qf_day72',
    'qf_day73',
    'qf_day74'
)

AND NOT x.indisvalid

ORDER BY
    n.nspname,
    t.relname,
    i.relname;


ROLLBACK;
