
-- =====================================================
-- QueryForge Day 64
-- ETL Data Reconciliation and Integrity Audit
-- PostgreSQL 18
--
-- READ ONLY: SELECT statements only.
-- =====================================================


-- 1. Verify required database objects

SELECT
    current_database() AS database_name,
    TO_REGNAMESPACE('etl') AS etl_schema,
    TO_REGCLASS(
        'etl.file_upload_registry'
    ) AS registry_table,
    TO_REGCLASS(
        'etl.customer_upload_rows'
    ) AS customer_rows_table;


-- 2. Check latest uploaded files

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


-- 3. Complete reconciliation summary
-- This is the final output of the script.

WITH metrics AS
(
    SELECT

        -- Registered files
        (
            SELECT COUNT(*)
            FROM etl.file_upload_registry
        ) AS registered_files,

        -- Customer rows
        (
            SELECT COUNT(*)
            FROM etl.customer_upload_rows
        ) AS customer_rows,

        -- Correctly linked rows
        (
            SELECT COUNT(*)
            FROM etl.customer_upload_rows r
            JOIN etl.file_upload_registry f
                ON f.upload_id = r.upload_id
        ) AS matched_rows,

        -- Rows without valid parent upload
        (
            SELECT COUNT(*)
            FROM etl.customer_upload_rows r
            LEFT JOIN etl.file_upload_registry f
                ON f.upload_id = r.upload_id
            WHERE f.upload_id IS NULL
        ) AS orphan_rows,

        -- Duplicate file hashes
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT file_hash
                FROM etl.file_upload_registry
                GROUP BY file_hash
                HAVING COUNT(*) > 1
            ) d
        ) AS duplicate_file_hashes,

        -- Duplicate customer IDs in same upload
        (
            SELECT COUNT(*)
            FROM
            (
                SELECT
                    upload_id,
                    customer_id
                FROM etl.customer_upload_rows
                GROUP BY
                    upload_id,
                    customer_id
                HAVING COUNT(*) > 1
            ) d
        ) AS duplicate_customer_keys,

        -- Missing customer IDs
        (
            SELECT COUNT(*)
            FROM etl.customer_upload_rows
            WHERE customer_id IS NULL
        ) AS null_customer_ids,

        -- Registry entries with no customer rows
        (
            SELECT COUNT(*)
            FROM etl.file_upload_registry f
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM etl.customer_upload_rows r
                WHERE r.upload_id = f.upload_id
            )
        ) AS empty_uploads
)

SELECT
    *,
    CASE
        WHEN orphan_rows > 0
          OR duplicate_file_hashes > 0
          OR duplicate_customer_keys > 0
          OR null_customer_ids > 0
          OR matched_rows + orphan_rows
                <> customer_rows
        THEN 'FAIL'

        WHEN registered_files = 0
         AND customer_rows = 0
        THEN 'NO DATA'

        ELSE 'PASS'
    END AS audit_status

FROM metrics;
