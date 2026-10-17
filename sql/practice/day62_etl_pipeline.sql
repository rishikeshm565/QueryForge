
-- ============================================================
-- QueryForge - Day 62: Excel ETL staging table
-- Existing Day 61 registry and records are preserved.
-- NO DROP / TRUNCATE / DELETE.
-- Execute in queryforge_dev.
-- ============================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

-- 1. Safety checks

DO $$
BEGIN
    IF current_database() <> 'queryforge_dev' THEN
        RAISE EXCEPTION
            'STOP: wrong database: %', current_database();
    END IF;

    IF to_regclass('etl.file_upload_registry') IS NULL THEN
        RAISE EXCEPTION
            'STOP: run Day 61 registry setup first';
    END IF;
END
$$;


-- 2. Create customer upload detail table

CREATE TABLE IF NOT EXISTS etl.customer_upload_rows
(
    upload_id BIGINT NOT NULL
        REFERENCES etl.file_upload_registry(upload_id)
        ON DELETE RESTRICT,

    customer_id BIGINT NOT NULL
        CHECK (customer_id > 0),

    customer_name TEXT NOT NULL
        CHECK (btrim(customer_name) <> ''),

    city TEXT NOT NULL
        CHECK (btrim(city) <> ''),

    email TEXT NOT NULL
        CHECK (btrim(email) <> ''),

    credit_limit NUMERIC(12,2) NOT NULL
        CHECK (credit_limit >= 0),

    PRIMARY KEY (upload_id, customer_id)
);


-- 3. Validate existing or newly created structure

DO $$
DECLARE
    matching_columns INTEGER;
    all_columns INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO all_columns
    FROM information_schema.columns
    WHERE table_schema = 'etl'
      AND table_name = 'customer_upload_rows';

    SELECT COUNT(*)
    INTO matching_columns
    FROM information_schema.columns
    WHERE table_schema = 'etl'
      AND table_name = 'customer_upload_rows'
      AND (
         (column_name = 'upload_id'
          AND data_type = 'bigint'
          AND is_nullable = 'NO')

         OR

         (column_name = 'customer_id'
          AND data_type = 'bigint'
          AND is_nullable = 'NO')

         OR

         (column_name = 'customer_name'
          AND data_type = 'text'
          AND is_nullable = 'NO')

         OR

         (column_name = 'city'
          AND data_type = 'text'
          AND is_nullable = 'NO')

         OR

         (column_name = 'email'
          AND data_type = 'text'
          AND is_nullable = 'NO')

         OR

         (column_name = 'credit_limit'
          AND data_type = 'numeric'
          AND numeric_precision = 12
          AND numeric_scale = 2
          AND is_nullable = 'NO')
      );

    IF all_columns <> 6 OR matching_columns <> 6 THEN
        RAISE EXCEPTION
            'STOP: incompatible customer_upload_rows columns';
    END IF;


    -- Verify composite primary key

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'etl.customer_upload_rows'::regclass
          AND contype = 'p'
          AND pg_get_constraintdef(oid) =
              'PRIMARY KEY (upload_id, customer_id)'
    ) THEN
        RAISE EXCEPTION
            'STOP: required composite primary key missing';
    END IF;


    -- Verify foreign key to upload registry

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'etl.customer_upload_rows'::regclass
          AND contype = 'f'
          AND confrelid =
            'etl.file_upload_registry'::regclass
    ) THEN
        RAISE EXCEPTION
            'STOP: required registry foreign key missing';
    END IF;

    RAISE NOTICE 'DAY 62 SETUP: PASS';

END
$$;

COMMIT;


-- 4. Verify both tables

SELECT
    current_database() AS database_name,
    to_regclass(
        'etl.file_upload_registry'
    ) AS registry,
    to_regclass(
        'etl.customer_upload_rows'
    ) AS detail_table;


-- 5. Verify existing row counts

SELECT
    (
        SELECT COUNT(*)
        FROM etl.file_upload_registry
    ) AS uploads,

    (
        SELECT COUNT(*)
        FROM etl.customer_upload_rows
    ) AS uploaded_rows;
