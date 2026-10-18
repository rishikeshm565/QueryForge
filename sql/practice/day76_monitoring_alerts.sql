
-- QueryForge Day 76
-- Read-only ETL monitoring audit
-- Database: queryforge_dev

BEGIN TRANSACTION READ ONLY;

SET LOCAL statement_timeout = '30s';


-- 1. Verify database and required objects.

SELECT
    current_database() AS database_name,

    TO_REGCLASS(
        'qf_day72.file_uploads'
    ) AS day72_uploads,

    TO_REGCLASS(
        'qf_day73.jobs'
    ) AS day73_jobs,

    TO_REGCLASS(
        'qf_day74.jobs'
    ) AS day74_jobs,

    TO_REGCLASS(
        'analytics.mv_monthly_order_summary'
    ) AS monthly_view;


-- 2. Aggregate ETL data.

SELECT
    (
        SELECT COUNT(*)
        FROM qf_day72.file_uploads
    ) AS uploaded_files,

    (
        SELECT COUNT(*)
        FROM qf_day72.customer_rows
    ) AS accepted_rows,

    (
        SELECT COUNT(*)
        FROM qf_day72.rejected_rows
    ) AS rejected_rows,

    (
        SELECT COUNT(*)
        FROM qf_day73.jobs
    ) AS checkpoint_jobs,

    (
        SELECT COUNT(*)
        FROM qf_day74.processed_rows
    ) AS concurrency_rows,

    (
        SELECT COUNT(*)
        FROM qf_day74.batch_history
    ) AS committed_batches;


-- 3. Check stalled and inconsistent jobs.

SELECT
    COUNT(*) FILTER (
        WHERE status = 'RUNNING'
    ) AS running_jobs,

    COUNT(*) FILTER (
        WHERE status = 'COMPLETED'
    ) AS completed_jobs,

    COUNT(*) FILTER (
        WHERE status = 'RUNNING'
          AND updated_at <
              NOW() - INTERVAL '60 minutes'
    ) AS stalled_jobs,

    COUNT(*) FILTER (
        WHERE processed_rows > expected_rows
           OR (
               status = 'COMPLETED'
               AND processed_rows <> expected_rows
           )
    ) AS inconsistent_jobs

FROM qf_day74.jobs;


-- 4. Check checkpoint/batch mismatches.
-- Expected: 0 rows.

SELECT
    j.upload_id,
    j.processed_rows,
    COALESCE(p.n, 0) AS stored_rows,
    COALESCE(b.n, 0) AS batch_row_sum

FROM qf_day74.jobs AS j

LEFT JOIN (
    SELECT
        upload_id,
        COUNT(*) AS n
    FROM qf_day74.processed_rows
    GROUP BY upload_id
) AS p
    ON p.upload_id = j.upload_id

LEFT JOIN (
    SELECT
        upload_id,
        SUM(batch_rows) AS n
    FROM qf_day74.batch_history
    GROUP BY upload_id
) AS b
    ON b.upload_id = j.upload_id

WHERE
    j.processed_rows <> COALESCE(p.n, 0)
    OR j.processed_rows <> COALESCE(b.n, 0);


-- 5. Invalid or unready indexes.
-- Expected: 0 rows.

SELECT
    n.nspname AS schema_name,
    t.relname AS table_name,
    x.relname AS index_name

FROM pg_index AS i

JOIN pg_class AS t
    ON t.oid = i.indrelid

JOIN pg_class AS x
    ON x.oid = i.indexrelid

JOIN pg_namespace AS n
    ON n.oid = t.relnamespace

WHERE n.nspname IN (
    'scale',
    'analytics',
    'etl',
    'qf_day72',
    'qf_day73',
    'qf_day74'
)

AND (
    NOT i.indisvalid
    OR NOT i.indisready
)

ORDER BY
    n.nspname,
    t.relname,
    x.relname;


-- 6. Partition health.

SELECT
    COUNT(*) AS partition_count

FROM pg_inherits

WHERE inhparent =
    'scale.orders_partitioned'::regclass;


-- 7. Materialized view health.

SELECT
    schemaname,
    matviewname,
    ispopulated

FROM pg_matviews

WHERE schemaname = 'analytics'
  AND matviewname = 'mv_monthly_order_summary';


ROLLBACK;
