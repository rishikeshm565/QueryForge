-- ============================================================
-- QueryForge
-- Day 52 - EXPLAIN ANALYZE
-- Goal: Compare estimated query plans with actual execution
-- ============================================================


-- ------------------------------------------------------------
-- 1. Sequential Scan
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM scale.customers_big
WHERE city = 'Hyderabad';


-- ------------------------------------------------------------
-- 2. Primary Key Index Scan
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM scale.customers_big
WHERE customer_id = 50000;


-- ------------------------------------------------------------
-- 3. Low-selectivity filter
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM scale.customers_big
WHERE is_active = TRUE;


-- ------------------------------------------------------------
-- 4. Sort
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM scale.customers_big
ORDER BY credit_limit DESC;


-- ------------------------------------------------------------
-- 5. Aggregate
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    city,
    COUNT(*)
FROM scale.customers_big
GROUP BY city;


-- ------------------------------------------------------------
-- 6. Filter + Sort
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM scale.customers_big
WHERE city = 'Hyderabad'
ORDER BY credit_limit DESC;


-- ------------------------------------------------------------
-- 7. LIMIT + Index
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM scale.customers_big
ORDER BY customer_id
LIMIT 10;


-- ------------------------------------------------------------
-- 8. Multiple Filters - Estimate vs Actual
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM scale.customers_big
WHERE city = 'Hyderabad'
  AND is_active = TRUE;