
-- =====================================================
-- QueryForge Day 65
-- ETL Monitoring and Data Quality Alerts
-- Read-only PostgreSQL verification
-- =====================================================

BEGIN TRANSACTION READ ONLY;

-- 1. Verify ETL objects

SELECT
    current_database() AS database_name,
    TO_REGCLASS(
        'etl.file_upload_registry'
    ) AS registry_table,
    TO_REGCLASS(
        'etl.customer_upload_rows'
    ) AS customer_rows_table;


-- 2. Monitor recent uploads

SELECT
    f.upload_id,
    f.file_name,
    f.uploaded_at,
    COUNT(r.upload_id) AS customer_rows

FROM etl.file_upload_registry f

LEFT JOIN etl.customer_upload_rows r
    ON r.upload_id = f.upload_id

GROUP BY
    f.upload_id,
    f.file_name,
    f.uploaded_at

ORDER BY f.upload_id DESC

LIMIT 20;


-- 3. Current data quality

WITH audit AS
(
    SELECT

        (
            SELECT COUNT(*)
            FROM etl.file_upload_registry
        ) AS registered_files,

        (
            SELECT COUNT(*)
            FROM etl.customer_upload_rows
        ) AS customer_rows,

        (
            SELECT COUNT(*)
            FROM etl.customer_upload_rows r
            LEFT JOIN etl.file_upload_registry f
                ON f.upload_id = r.upload_id
            WHERE f.upload_id IS NULL
        ) AS orphan_rows,

        (
            SELECT COUNT(*)
            FROM (
                SELECT upload_id, customer_id
                FROM etl.customer_upload_rows
                GROUP BY upload_id, customer_id
                HAVING COUNT(*) > 1
            ) d
        ) AS duplicate_customer_keys,

        (
            SELECT COUNT(*)
            FROM etl.customer_upload_rows
            WHERE customer_id IS NULL
        ) AS null_customer_ids
)

SELECT
    *,
    CASE

        WHEN orphan_rows > 0
          OR duplicate_customer_keys > 0
          OR null_customer_ids > 0
        THEN 'FAIL'

        WHEN registered_files = 0
         AND customer_rows = 0
        THEN 'NO DATA'

        ELSE 'PASS'

    END AS monitoring_status

FROM audit;

ROLLBACK;
