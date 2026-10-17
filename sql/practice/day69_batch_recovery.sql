
-- QueryForge Day 69
-- Synthetic batch recovery and checkpoints.
-- All database changes are temporary and rolled back.

BEGIN;

SET LOCAL statement_timeout = '30s';

-- 1. Temporary customer target

CREATE TEMP TABLE qf_day69_customers (
    customer_id BIGINT PRIMARY KEY,
    customer_name TEXT NOT NULL,
    source_updated_at DATE NOT NULL
) ON COMMIT DROP;

-- 2. Temporary checkpoint registry

CREATE TEMP TABLE qf_day69_checkpoints (
    batch_id BIGINT PRIMARY KEY,
    expected_rows INTEGER NOT NULL
        CHECK (expected_rows > 0)
) ON COMMIT DROP;

-- Existing customer

INSERT INTO qf_day69_customers VALUES
(1, 'Rahul Old', DATE '2026-09-01');

-- 3. Batch 101: one update and one insert

INSERT INTO qf_day69_customers AS t (
    customer_id,
    customer_name,
    source_updated_at
)
VALUES
    (1, 'Rahul Updated', DATE '2026-10-01'),
    (2, 'Meera', DATE '2026-10-02')
ON CONFLICT (customer_id)
DO UPDATE
SET
    customer_name = EXCLUDED.customer_name,
    source_updated_at = EXCLUDED.source_updated_at
WHERE
    t.source_updated_at <
        EXCLUDED.source_updated_at;

-- Record successful batch

INSERT INTO qf_day69_checkpoints
VALUES (101, 2);

-- 4. Replay Batch 101
-- Checkpoint exists, so skip processing.

INSERT INTO qf_day69_customers AS t (
    customer_id,
    customer_name,
    source_updated_at
)
SELECT
    v.customer_id,
    v.customer_name,
    v.source_updated_at
FROM (
    VALUES
        (1, 'Rahul Updated', DATE '2026-10-01'),
        (2, 'Meera', DATE '2026-10-02')
) AS v(
    customer_id,
    customer_name,
    source_updated_at
)
WHERE NOT EXISTS (
    SELECT 1
    FROM qf_day69_checkpoints
    WHERE batch_id = 101
)
ON CONFLICT (customer_id)
DO UPDATE
SET
    customer_name = EXCLUDED.customer_name,
    source_updated_at = EXCLUDED.source_updated_at
WHERE
    t.source_updated_at <
        EXCLUDED.source_updated_at;

-- 5. Simulate failure during Batch 102

SAVEPOINT qf_day69_before_crash;

INSERT INTO qf_day69_customers
VALUES (3, 'Zoya', DATE '2026-10-03');

-- Simulated crash: undo partial changes

ROLLBACK TO SAVEPOINT qf_day69_before_crash;

-- Verify no partial data remains

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM qf_day69_customers
        WHERE customer_id = 3
    )
    OR EXISTS (
        SELECT 1
        FROM qf_day69_checkpoints
        WHERE batch_id = 102
    )
    THEN
        RAISE EXCEPTION
            'DAY 69 FAIL: crash left partial results';
    END IF;
END $$;

-- 6. Retry Batch 102

INSERT INTO qf_day69_customers
VALUES (3, 'Zoya', DATE '2026-10-03');

INSERT INTO qf_day69_checkpoints
VALUES (102, 1);

RELEASE SAVEPOINT qf_day69_before_crash;

-- 7. Final validation

DO $$
DECLARE
    customer_count INTEGER;
    checkpoint_count INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO customer_count
    FROM qf_day69_customers;

    SELECT COUNT(*)
    INTO checkpoint_count
    FROM qf_day69_checkpoints;

    IF customer_count <> 3
       OR checkpoint_count <> 2
       OR NOT EXISTS (
           SELECT 1
           FROM qf_day69_customers
           WHERE customer_id = 1
             AND customer_name = 'Rahul Updated'
             AND source_updated_at =
                 DATE '2026-10-01'
       )
    THEN
        RAISE EXCEPTION
            'DAY 69 FAIL: customers %, checkpoints %',
            customer_count,
            checkpoint_count;
    END IF;

    RAISE NOTICE
        'DAY 69 PASS: customers %, checkpoints %, recovery verified',
        customer_count,
        checkpoint_count;

END $$;

-- 8. Inspect customer records

SELECT
    customer_id,
    customer_name,
    source_updated_at
FROM qf_day69_customers
ORDER BY customer_id;

-- 9. Inspect checkpoint records

SELECT
    batch_id,
    expected_rows
FROM qf_day69_checkpoints
ORDER BY batch_id;

-- 10. Leave existing database unchanged

ROLLBACK;
