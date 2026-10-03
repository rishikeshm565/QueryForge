-- ============================================================
-- QueryForge / DataVault 360
-- Day 36 - ETL Logging / Load Tracking
-- ============================================================


-- ============================================================
-- STEP 1 - CREATE ETL SCHEMA AND LOAD LOG TABLE
-- ============================================================

CREATE SCHEMA IF NOT EXISTS etl;

DROP TABLE IF EXISTS etl.load_log;

CREATE TABLE etl.load_log
(
    run_id BIGSERIAL PRIMARY KEY,

    file_name VARCHAR(255) NOT NULL,

    started_at TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    completed_at TIMESTAMP,

    source_rows INTEGER NOT NULL DEFAULT 0,
    loaded_rows INTEGER NOT NULL DEFAULT 0,
    rejected_rows INTEGER NOT NULL DEFAULT 0,
    duplicate_rows INTEGER NOT NULL DEFAULT 0,

    status VARCHAR(20) NOT NULL,

    error_message TEXT,

    loaded_by VARCHAR(100)
        DEFAULT CURRENT_USER,

    CONSTRAINT chk_load_status
        CHECK
        (
            status IN
            (
                'STARTED',
                'SUCCESS',
                'PARTIAL_SUCCESS',
                'FAILED'
            )
        )
);


-- Verify empty log table

SELECT *
FROM etl.load_log;


-- ============================================================
-- STEP 2 - START FIRST ETL RUN
-- ============================================================

INSERT INTO etl.load_log
(
    file_name,
    status
)
VALUES
(
    'day36_customer_upload.xlsx',
    'STARTED'
)
RETURNING
    run_id,
    file_name,
    started_at,
    status;


-- ============================================================
-- STEP 3 - COMPLETE FIRST ETL RUN AS SUCCESS
-- ============================================================

UPDATE etl.load_log
SET
    completed_at = CURRENT_TIMESTAMP,

    source_rows =
    (
        SELECT COUNT(*)
        FROM staging.customer_upload
    ),

    loaded_rows =
    (
        SELECT COUNT(*)
        FROM staging.customer_upload
    ),

    rejected_rows = 0,
    duplicate_rows = 0,

    status = 'SUCCESS'

WHERE run_id =
(
    SELECT MAX(run_id)
    FROM etl.load_log
    WHERE file_name = 'day36_customer_upload.xlsx'
);


-- Validate successful load

SELECT
    run_id,
    file_name,
    source_rows,
    loaded_rows,
    rejected_rows,
    duplicate_rows,
    status
FROM etl.load_log
ORDER BY run_id;


-- ============================================================
-- STEP 4 - START SECOND / INVALID ETL RUN
-- ============================================================

INSERT INTO etl.load_log
(
    file_name,
    status
)
VALUES
(
    'day36_invalid_customer_upload.xlsx',
    'STARTED'
)
RETURNING
    run_id,
    file_name,
    status;


-- ============================================================
-- STEP 5 - COMPLETE SECOND RUN AS PARTIAL SUCCESS
-- ============================================================

UPDATE etl.load_log
SET
    completed_at = CURRENT_TIMESTAMP,

    source_rows = 5,
    loaded_rows = 3,
    rejected_rows = 2,
    duplicate_rows = 1,

    status = 'PARTIAL_SUCCESS',

    error_message =
        '2 rows rejected during validation'

WHERE run_id =
(
    SELECT MAX(run_id)
    FROM etl.load_log
    WHERE file_name =
        'day36_invalid_customer_upload.xlsx'
);


-- ============================================================
-- STEP 6 - COMPLETE ETL LOAD HISTORY
-- ============================================================

SELECT
    run_id,
    file_name,
    started_at,
    completed_at,
    source_rows,
    loaded_rows,
    rejected_rows,
    duplicate_rows,
    status,
    error_message,
    loaded_by
FROM etl.load_log
ORDER BY run_id;


-- ============================================================
-- STEP 7 - FINAL COMPACT VALIDATION
-- ============================================================

SELECT
    run_id,
    source_rows,
    loaded_rows,
    rejected_rows,
    duplicate_rows,
    status
FROM etl.load_log
ORDER BY run_id;