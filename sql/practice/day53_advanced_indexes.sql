-- ============================================================
-- QueryForge
-- Day 53 - Advanced Indexes
-- Composite, Partial and Covering Indexes
-- ============================================================


-- ------------------------------------------------------------
-- 1. Existing indexes
-- ------------------------------------------------------------

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'scale'
  AND tablename = 'customers_big'
ORDER BY indexname;


-- ------------------------------------------------------------
-- 2. BEFORE Composite Index
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM scale.customers_big
WHERE city = 'Hyderabad'
ORDER BY credit_limit DESC
LIMIT 20;


-- ------------------------------------------------------------
-- 3. Composite Index
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_customers_big_city_credit
ON scale.customers_big (city, credit_limit DESC);

ANALYZE scale.customers_big;


-- AFTER Composite Index

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM scale.customers_big
WHERE city = 'Hyderabad'
ORDER BY credit_limit DESC
LIMIT 20;


-- ------------------------------------------------------------
-- 4. BEFORE Partial Index
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    is_active
FROM scale.customers_big
WHERE is_active = FALSE
  AND customer_id > 90000;


-- ------------------------------------------------------------
-- 5. Partial Index
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_customers_big_inactive_customer
ON scale.customers_big (customer_id)
WHERE is_active = FALSE;

ANALYZE scale.customers_big;


-- AFTER Partial Index

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    is_active
FROM scale.customers_big
WHERE is_active = FALSE
  AND customer_id > 90000;


-- ------------------------------------------------------------
-- 6. Verify Partial Index
-- ------------------------------------------------------------

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'scale'
  AND tablename = 'customers_big'
  AND indexname = 'idx_customers_big_inactive_customer';


-- ------------------------------------------------------------
-- 7. Covering Index
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_customers_big_city_cover
ON scale.customers_big (city)
INCLUDE (full_name, credit_limit);

ANALYZE scale.customers_big;


-- ------------------------------------------------------------
-- NOTE:
-- Run this VACUUM command separately in pgAdmin
-- ------------------------------------------------------------

VACUUM (ANALYZE) scale.customers_big;


-- ------------------------------------------------------------
-- 8. Covering / Index Only Scan Test
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    city,
    full_name,
    credit_limit
FROM scale.customers_big
WHERE city = 'Hyderabad';


-- ------------------------------------------------------------
-- 9. Verify all indexes
-- ------------------------------------------------------------

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'scale'
  AND tablename = 'customers_big'
ORDER BY indexname;


-- ------------------------------------------------------------
-- 10. Compare Index Sizes
-- ------------------------------------------------------------

SELECT
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'scale'
  AND relname = 'customers_big'
ORDER BY pg_relation_size(indexrelid) DESC;