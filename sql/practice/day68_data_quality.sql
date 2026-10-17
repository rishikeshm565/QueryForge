
-- QueryForge Day 68 - Safe Advanced Data Quality Demo
-- Synthetic rows only; all changes are temporary
-- and rolled back.

BEGIN;
SET LOCAL statement_timeout = '30s';

-- 1. Create synthetic staging table

CREATE TEMP TABLE qf_day68_staging (
    source_line INTEGER PRIMARY KEY,
    customer_id BIGINT,
    customer_name TEXT,
    city TEXT,
    email TEXT,
    credit_limit TEXT
) ON COMMIT DROP;

-- 2. Insert test data

INSERT INTO qf_day68_staging VALUES
(1, 1, 'Rahul', 'Hyderabad',
 'rahul@example.com', '50000'),
(2, 2, 'Meera', 'Mumbai',
 'meera@example.com', '60000'),
(3, 2, 'Meera Again', 'Mumbai',
 'meera2@example.com', '60000'),
(4, 3, 'Arjun', 'Delhi',
 'not-an-email', '70000'),
(5, 4, 'Priya', 'Pune',
 'priya@example.com', '-1000'),
(6, NULL, 'Missing ID', 'Pune',
 'missing@example.com', '1000'),
(7, 5, 'Sneha', 'Chennai',
 'sneha@example.com', 'ABC'),
(8, 6, '   ', 'Jaipur',
 'blank@example.com', '20000'),
(9, 7, 'Zoya', 'Kolkata',
 'zoya@example.com', '2000000'),
(10, 8, 'Aarav', 'Pune',
 'aarav@example.com', '40000');

-- 3. Detect rejected records

CREATE TEMP TABLE qf_day68_quarantine AS
WITH tagged AS (
    SELECT
        s.*,
        COUNT(*) FILTER (
            WHERE customer_id IS NOT NULL
        ) OVER (
            PARTITION BY customer_id
        ) AS id_count
    FROM qf_day68_staging s
),
rules AS (
    SELECT
        source_line,
        customer_id,
        ARRAY_REMOVE(
            ARRAY[
                CASE
                    WHEN customer_id IS NULL
                      OR customer_id <= 0
                    THEN 'missing_or_invalid_id'
                END,

                CASE
                    WHEN customer_id IS NOT NULL
                     AND id_count > 1
                    THEN 'duplicate_customer_id'
                END,

                CASE
                    WHEN NULLIF(
                        BTRIM(customer_name), ''
                    ) IS NULL
                    THEN 'blank_customer_name'
                END,

                CASE
                    WHEN NULLIF(
                        BTRIM(city), ''
                    ) IS NULL
                    THEN 'blank_city'
                END,

                CASE
                    WHEN email IS NULL
                      OR BTRIM(email) !~*
                      '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
                    THEN 'invalid_email'
                END,

                CASE
                    WHEN credit_limit IS NULL
                      OR BTRIM(credit_limit) !~
                      '^-?[0-9]+(\.[0-9]{1,2})?$'
                    THEN 'invalid_credit_limit'
                END,

                CASE
                    WHEN BTRIM(credit_limit) ~
                         '^-?[0-9]+(\.[0-9]{1,2})?$'
                    THEN
                        CASE
                            WHEN BTRIM(credit_limit)::NUMERIC < 0
                            THEN 'negative_credit_limit'
                        END
                END,

                CASE
                    WHEN BTRIM(credit_limit) ~
                         '^-?[0-9]+(\.[0-9]{1,2})?$'
                    THEN
                        CASE
                            WHEN BTRIM(credit_limit)::NUMERIC > 1000000
                            THEN 'credit_limit_outlier'
                        END
                END
            ]::TEXT[],
            NULL
        ) AS reasons
    FROM tagged
)
SELECT source_line, customer_id, reasons
FROM rules
WHERE CARDINALITY(reasons) > 0;

-- 4. Accept clean records only

CREATE TEMP TABLE qf_day68_accepted AS
SELECT
    s.source_line,
    s.customer_id,
    BTRIM(s.customer_name) AS customer_name,
    BTRIM(s.city) AS city,
    LOWER(BTRIM(s.email)) AS email,
    BTRIM(s.credit_limit)::NUMERIC(12,2)
        AS credit_limit
FROM qf_day68_staging s
LEFT JOIN qf_day68_quarantine q
    USING (source_line)
WHERE q.source_line IS NULL;

-- 5. Automatic verification

DO $$
DECLARE
    total_count INTEGER;
    accepted_count INTEGER;
    rejected_count INTEGER;
    duplicate_count INTEGER;
BEGIN

    SELECT COUNT(*) INTO total_count
    FROM qf_day68_staging;

    SELECT COUNT(*) INTO accepted_count
    FROM qf_day68_accepted;

    SELECT COUNT(*) INTO rejected_count
    FROM qf_day68_quarantine;

    SELECT COUNT(*) INTO duplicate_count
    FROM qf_day68_quarantine
    WHERE 'duplicate_customer_id' = ANY(reasons);

    IF total_count <> 10
       OR accepted_count <> 2
       OR rejected_count <> 8
       OR duplicate_count <> 2
    THEN
        RAISE EXCEPTION
            'DAY 68 FAIL: total %, accepted %, rejected %, duplicates %',
            total_count,
            accepted_count,
            rejected_count,
            duplicate_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM qf_day68_accepted
        WHERE customer_id = 1
    )
    OR NOT EXISTS (
        SELECT 1
        FROM qf_day68_accepted
        WHERE customer_id = 8
    )
    OR EXISTS (
        SELECT 1
        FROM qf_day68_accepted
        WHERE customer_id = 2
    )
    THEN
        RAISE EXCEPTION
            'DAY 68 FAIL: incorrect accepted IDs';
    END IF;

    RAISE NOTICE
        'DAY 68 PASS: total %, accepted %, rejected %, duplicate rows %',
        total_count,
        accepted_count,
        rejected_count,
        duplicate_count;

END $$;

-- 6. Inspect rejected records

SELECT
    source_line,
    customer_id,
    reasons
FROM qf_day68_quarantine
ORDER BY source_line;

-- 7. Inspect accepted records

SELECT
    source_line,
    customer_id,
    customer_name,
    city,
    email,
    credit_limit
FROM qf_day68_accepted
ORDER BY customer_id;

-- 8. Undo demonstration tables

ROLLBACK;
