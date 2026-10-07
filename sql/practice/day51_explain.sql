-- ============================================================
-- QueryForge
-- Day 51 - PostgreSQL EXPLAIN
-- Goal: Read and understand query execution plans
-- ============================================================


-- ------------------------------------------------------------
-- 1. Check large tables and estimated row counts
-- ------------------------------------------------------------

SELECT
    schemaname,
    relname AS table_name,
    n_live_tup AS estimated_rows
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;


-- ------------------------------------------------------------
-- 2. Check customers_big structure
-- ------------------------------------------------------------

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'scale'
  AND table_name = 'customers_big'
ORDER BY ordinal_position;


-- ------------------------------------------------------------
-- 3. Sequential Scan
-- ------------------------------------------------------------

EXPLAIN
SELECT *
FROM scale.customers_big
WHERE city = 'Hyderabad';


-- ------------------------------------------------------------
-- 4. Index Scan using Primary Key
-- ------------------------------------------------------------

EXPLAIN
SELECT *
FROM scale.customers_big
WHERE customer_id = 50000;


-- ------------------------------------------------------------
-- 5. Low-selectivity filter
-- ------------------------------------------------------------

EXPLAIN
SELECT *
FROM scale.customers_big
WHERE is_active = TRUE;


-- ------------------------------------------------------------
-- 6. Sort
-- ------------------------------------------------------------

EXPLAIN
SELECT *
FROM scale.customers_big
ORDER BY credit_limit DESC;


-- ------------------------------------------------------------
-- 7. Aggregate
-- ------------------------------------------------------------

EXPLAIN
SELECT
    city,
    COUNT(*)
FROM scale.customers_big
GROUP BY city;


-- ------------------------------------------------------------
-- 8. Filter + Sort
-- ------------------------------------------------------------

EXPLAIN
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM scale.customers_big
WHERE city = 'Hyderabad'
ORDER BY credit_limit DESC;


-- ------------------------------------------------------------
-- 9. Limit + Primary Key Index
-- ------------------------------------------------------------

EXPLAIN
SELECT *
FROM scale.customers_big
ORDER BY customer_id
LIMIT 10;