
-- =====================================================
-- QueryForge - Day 67
-- Incremental Loading and UPSERT
-- Safe demonstration: TEMP tables + ROLLBACK
-- =====================================================

BEGIN;

SET LOCAL statement_timeout = '30s';

-- 1. Existing customer records

CREATE TEMP TABLE qf_day67_current (
    customer_id BIGINT PRIMARY KEY,
    customer_name TEXT NOT NULL,
    city TEXT NOT NULL,
    credit_limit NUMERIC(12,2) NOT NULL
        CHECK (credit_limit >= 0),
    source_updated_at TIMESTAMPTZ NOT NULL
) ON COMMIT DROP;

INSERT INTO qf_day67_current VALUES
(1, 'Rahul', 'Hyderabad', 50000,
 '2026-10-01 10:00+00'),
(2, 'Meera', 'Mumbai', 60000,
 '2026-10-01 10:00+00'),
(4, 'Priya', 'Pune', 20000,
 '2026-10-08 10:00+00');

-- 2. Incoming incremental batch

CREATE TEMP TABLE qf_day67_incoming (
    customer_id BIGINT PRIMARY KEY,
    customer_name TEXT NOT NULL,
    city TEXT NOT NULL,
    credit_limit NUMERIC(12,2) NOT NULL
        CHECK (credit_limit >= 0),
    source_updated_at TIMESTAMPTZ NOT NULL
) ON COMMIT DROP;

INSERT INTO qf_day67_incoming VALUES
(1, 'Rahul', 'Hyderabad', 55000,
 '2026-10-05 10:00+00'),
(2, 'Meera', 'Mumbai', 60000,
 '2026-10-01 10:00+00'),
(3, 'Arjun', 'Delhi', 70000,
 '2026-10-05 10:00+00'),
(4, 'Priya', 'Pune', 99000,
 '2026-10-04 10:00+00');

-- 3. Metrics for both runs

CREATE TEMP TABLE qf_day67_metrics (
    run_name TEXT PRIMARY KEY,
    changed_rows BIGINT NOT NULL
) ON COMMIT DROP;

-- 4. First UPSERT
-- New customer: INSERT
-- Newer record: UPDATE
-- Same or older record: SKIP

WITH changes AS (
    INSERT INTO qf_day67_current AS target (
        customer_id,
        customer_name,
        city,
        credit_limit,
        source_updated_at
    )
    SELECT
        customer_id,
        customer_name,
        city,
        credit_limit,
        source_updated_at
    FROM qf_day67_incoming
    WHERE TRUE

    ON CONFLICT (customer_id)
    DO UPDATE SET
        customer_name = EXCLUDED.customer_name,
        city = EXCLUDED.city,
        credit_limit = EXCLUDED.credit_limit,
        source_updated_at = EXCLUDED.source_updated_at

    WHERE EXCLUDED.source_updated_at
        > target.source_updated_at

    RETURNING customer_id
)
INSERT INTO qf_day67_metrics
SELECT 'first_run', COUNT(*)
FROM changes;

-- 5. Repeat identical batch
-- Idempotency check: zero changes expected

WITH changes AS (
    INSERT INTO qf_day67_current AS target (
        customer_id,
        customer_name,
        city,
        credit_limit,
        source_updated_at
    )
    SELECT
        customer_id,
        customer_name,
        city,
        credit_limit,
        source_updated_at
    FROM qf_day67_incoming
    WHERE TRUE

    ON CONFLICT (customer_id)
    DO UPDATE SET
        customer_name = EXCLUDED.customer_name,
        city = EXCLUDED.city,
        credit_limit = EXCLUDED.credit_limit,
        source_updated_at = EXCLUDED.source_updated_at

    WHERE EXCLUDED.source_updated_at
        > target.source_updated_at

    RETURNING customer_id
)
INSERT INTO qf_day67_metrics
SELECT 'second_run', COUNT(*)
FROM changes;

-- 6. Automated verification

DO $$
DECLARE
    first_changed BIGINT;
    second_changed BIGINT;
    final_count BIGINT;
BEGIN

    SELECT changed_rows INTO STRICT first_changed
    FROM qf_day67_metrics
    WHERE run_name = 'first_run';

    SELECT changed_rows INTO STRICT second_changed
    FROM qf_day67_metrics
    WHERE run_name = 'second_run';

    SELECT COUNT(*) INTO final_count
    FROM qf_day67_current;

    IF first_changed <> 2 THEN
        RAISE EXCEPTION
            'DAY 67 FAIL: first run expected 2, got %',
            first_changed;
    END IF;

    IF second_changed <> 0 THEN
        RAISE EXCEPTION
            'DAY 67 FAIL: second run expected 0, got %',
            second_changed;
    END IF;

    IF final_count <> 4 THEN
        RAISE EXCEPTION
            'DAY 67 FAIL: expected 4 customers, got %',
            final_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM qf_day67_current
        WHERE customer_id = 1
          AND credit_limit = 55000
    ) THEN
        RAISE EXCEPTION 'DAY 67 FAIL: UPDATE';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM qf_day67_current
        WHERE customer_id = 3
          AND credit_limit = 70000
    ) THEN
        RAISE EXCEPTION 'DAY 67 FAIL: INSERT';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM qf_day67_current
        WHERE customer_id = 4
          AND credit_limit = 20000
    ) THEN
        RAISE EXCEPTION
            'DAY 67 FAIL: stale record overwrite';
    END IF;

    RAISE NOTICE
        'DAY 67 PASS: first changed %, second changed %, final rows %',
        first_changed, second_changed, final_count;

END $$;

-- 7. Final result inside the transaction

SELECT
    customer_id,
    customer_name,
    city,
    credit_limit,
    source_updated_at
FROM qf_day67_current
ORDER BY customer_id;

SELECT *
FROM qf_day67_metrics
ORDER BY run_name;

-- 8. Undo all demonstration changes

ROLLBACK;
