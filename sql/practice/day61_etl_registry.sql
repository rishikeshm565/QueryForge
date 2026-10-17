
-- ============================================================
-- QUERYFORGE - DAY 61
-- SAFE POSTGRESQL ETL REGISTRY SETUP
--
-- Creates missing schema/table only.
-- Preserves all existing data.
-- Stops on incompatible table structure.
-- ============================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

-- ------------------------------------------------------------
-- 1. DATABASE SAFETY GUARD
-- ------------------------------------------------------------

DO $$
BEGIN
    IF current_database() <> 'queryforge_dev' THEN
        RAISE EXCEPTION
            'STOP: Expected queryforge_dev, connected to %',
            current_database();
    END IF;
END
$$;


-- ------------------------------------------------------------
-- 2. CREATE ETL SCHEMA IF MISSING
-- ------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS etl;


-- ------------------------------------------------------------
-- 3. CREATE FILE UPLOAD REGISTRY IF MISSING
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS etl.file_upload_registry
(
    upload_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    file_name TEXT NOT NULL,

    file_hash TEXT NOT NULL UNIQUE,

    uploaded_at TIMESTAMPTZ
        NOT NULL DEFAULT NOW()
);


-- ------------------------------------------------------------
-- 4. VALIDATE STRUCTURE AND CONSTRAINTS
-- ------------------------------------------------------------

DO $$
DECLARE
    matched_columns INTEGER;
    total_columns INTEGER;
    primary_key_ok BOOLEAN;
    unique_hash_ok BOOLEAN;
BEGIN

    SELECT COUNT(*)
    INTO total_columns
    FROM information_schema.columns
    WHERE table_schema = 'etl'
      AND table_name = 'file_upload_registry';

    SELECT COUNT(*)
    INTO matched_columns
    FROM information_schema.columns
    WHERE table_schema = 'etl'
      AND table_name = 'file_upload_registry'
      AND (
          (
              column_name = 'upload_id'
              AND data_type = 'bigint'
              AND is_nullable = 'NO'
              AND is_identity = 'YES'
          )
          OR
          (
              column_name = 'file_name'
              AND data_type = 'text'
              AND is_nullable = 'NO'
          )
          OR
          (
              column_name = 'file_hash'
              AND data_type = 'text'
              AND is_nullable = 'NO'
          )
          OR
          (
              column_name = 'uploaded_at'
              AND data_type = 'timestamp with time zone'
              AND is_nullable = 'NO'
              AND column_default IS NOT NULL
          )
      );

    IF total_columns <> 4
       OR matched_columns <> 4 THEN
        RAISE EXCEPTION
            'STOP: Existing upload registry structure is incompatible';
    END IF;


    SELECT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'etl.file_upload_registry'::regclass
          AND contype = 'p'
          AND pg_get_constraintdef(oid)
              LIKE 'PRIMARY KEY (upload_id)%'
    )
    INTO primary_key_ok;


    SELECT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'etl.file_upload_registry'::regclass
          AND contype = 'u'
          AND pg_get_constraintdef(oid)
              LIKE 'UNIQUE (file_hash)%'
    )
    INTO unique_hash_ok;


    IF NOT primary_key_ok THEN
        RAISE EXCEPTION
            'STOP: Expected upload_id primary key missing';
    END IF;

    IF NOT unique_hash_ok THEN
        RAISE EXCEPTION
            'STOP: Expected file_hash unique constraint missing';
    END IF;

    RAISE NOTICE
        'DAY 61: Registry structure and constraints PASS';

END
$$;

COMMIT;


-- ------------------------------------------------------------
-- 5. VERIFY CREATED OBJECT
-- ------------------------------------------------------------

SELECT
    current_database() AS database_name,
    TO_REGNAMESPACE('etl') AS etl_schema,
    TO_REGCLASS(
        'etl.file_upload_registry'
    ) AS registry_table;


-- ------------------------------------------------------------
-- 6. VERIFY REGISTRY COLUMNS
-- ------------------------------------------------------------

SELECT
    column_name,
    data_type,
    is_nullable,
    is_identity,
    column_default
FROM information_schema.columns
WHERE table_schema = 'etl'
  AND table_name = 'file_upload_registry'
ORDER BY ordinal_position;


-- ------------------------------------------------------------
-- 7. VERIFY DATABASE CONSTRAINTS
-- ------------------------------------------------------------

SELECT
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid =
    'etl.file_upload_registry'::regclass
ORDER BY conname;


-- ------------------------------------------------------------
-- 8. VERIFY ROW COUNT
-- ------------------------------------------------------------

SELECT COUNT(*) AS registered_files
FROM etl.file_upload_registry;


-- ============================================================
-- END DAY 61 SETUP
-- ============================================================
