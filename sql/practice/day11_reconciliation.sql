-- ============================================================
-- QueryForge
-- Day 11 - SQL Reconciliation Practice
-- Source Customer IDs vs PostgreSQL customers table
-- ============================================================


-- ============================================================
-- CHECK 1: View the expected customer records in PostgreSQL
-- ============================================================

SELECT
    customer_id,
    full_name,
    email,
    city,
    credit_limit,
    is_active
FROM customers
WHERE customer_id IN (
    4101,
    4102,
    4103,
    4104,
    4105
)
ORDER BY customer_id;


-- ============================================================
-- CHECK 2: Expected vs Matched vs Missing row counts
-- ============================================================

WITH source_ids(customer_id) AS (
    VALUES
        (4101),
        (4102),
        (4103),
        (4104),
        (4105)
)

SELECT
    COUNT(*) AS expected_rows,
    COUNT(c.customer_id) AS matched_rows,
    COUNT(*) - COUNT(c.customer_id) AS missing_rows
FROM source_ids s
LEFT JOIN customers c
    ON s.customer_id = c.customer_id;


-- ============================================================
-- CHECK 3: Show exact missing customer IDs
-- ============================================================

WITH source_ids(customer_id) AS (
    VALUES
        (4101),
        (4102),
        (4103),
        (4104),
        (4105)
)

SELECT
    s.customer_id AS missing_customer_id
FROM source_ids s
LEFT JOIN customers c
    ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL
ORDER BY s.customer_id;


-- ============================================================
-- CHECK 4: Check duplicates in PostgreSQL target
-- ============================================================

SELECT
    customer_id,
    COUNT(*) AS record_count
FROM customers
WHERE customer_id IN (
    4101,
    4102,
    4103,
    4104,
    4105
)
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY customer_id;


-- ============================================================
-- CHECK 5: Check required-field problems in target
-- ============================================================

SELECT
    customer_id,
    full_name,
    email
FROM customers
WHERE customer_id IN (
    4101,
    4102,
    4103,
    4104,
    4105
)
AND (
    full_name IS NULL
    OR email IS NULL
)
ORDER BY customer_id;