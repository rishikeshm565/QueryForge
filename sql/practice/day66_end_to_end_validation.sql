
-- ==================================================
-- QueryForge Day 66
-- Read-only ETL Integration Verification
-- ==================================================

BEGIN TRANSACTION READ ONLY;

-- 1. Database and safety
SELECT
    current_database() AS database_name,
    current_setting('transaction_read_only')
        AS read_only_mode;

-- 2. Required objects
SELECT
    TO_REGCLASS('etl.file_upload_registry')
        AS upload_registry,
    TO_REGCLASS('etl.customer_upload_rows')
        AS customer_upload_rows;

-- 3. File and row counts
SELECT
    (SELECT COUNT(*)
     FROM etl.file_upload_registry)
        AS registered_files,

    (SELECT COUNT(*)
     FROM etl.customer_upload_rows)
        AS customer_rows;

-- 4. Orphan customer rows
SELECT COUNT(*) AS orphan_rows
FROM etl.customer_upload_rows r
LEFT JOIN etl.file_upload_registry f
    ON f.upload_id = r.upload_id
WHERE f.upload_id IS NULL;

-- 5. Duplicate file hashes
SELECT COUNT(*) AS duplicate_hash_groups
FROM (
    SELECT file_hash
    FROM etl.file_upload_registry
    GROUP BY file_hash
    HAVING COUNT(*) > 1
) AS d;

-- 6. Duplicate customer IDs within an upload
SELECT COUNT(*) AS duplicate_customer_groups
FROM (
    SELECT upload_id, customer_id
    FROM etl.customer_upload_rows
    GROUP BY upload_id, customer_id
    HAVING COUNT(*) > 1
) AS d;

-- 7. Empty uploaded files
SELECT COUNT(*) AS empty_uploads
FROM etl.file_upload_registry f
WHERE NOT EXISTS (
    SELECT 1
    FROM etl.customer_upload_rows r
    WHERE r.upload_id = f.upload_id
);

ROLLBACK;
