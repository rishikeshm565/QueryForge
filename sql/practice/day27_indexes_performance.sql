-- =========================================================
-- QueryForge
-- Day 27 - Indexes & Query Performance
-- =========================================================


-- =========================================================
-- Q1. Check existing indexes on customers table
-- =========================================================

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'customers'
ORDER BY indexname;


-- =========================================================
-- Q2. Create index on city
-- =========================================================

DROP INDEX IF EXISTS idx_customers_city;

CREATE INDEX idx_customers_city
ON customers(city);


-- =========================================================
-- Q3. Create index on credit_limit
-- =========================================================

DROP INDEX IF EXISTS idx_customers_credit_limit;

CREATE INDEX idx_customers_credit_limit
ON customers(credit_limit);


-- =========================================================
-- Q4. Create composite index
-- city + credit_limit
-- =========================================================

DROP INDEX IF EXISTS idx_customers_city_credit;

CREATE INDEX idx_customers_city_credit
ON customers(city, credit_limit DESC);


-- =========================================================
-- Q5. Verify newly created indexes
-- =========================================================

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'customers'
ORDER BY indexname;


-- =========================================================
-- Q6. EXPLAIN a filtered query
-- Shows PostgreSQL execution plan
-- =========================================================

EXPLAIN
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
WHERE city = 'Hyderabad';


-- =========================================================
-- Q7. EXPLAIN ANALYZE
-- Actually executes query and shows runtime information
-- =========================================================

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
WHERE credit_limit >= 20000
ORDER BY credit_limit DESC;


-- =========================================================
-- Q8. EXPLAIN query using city + credit limit
-- =========================================================

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
WHERE city = 'Hyderabad'
  AND credit_limit >= 20000
ORDER BY credit_limit DESC;


-- =========================================================
-- Q9. Check index size
-- =========================================================

SELECT
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE relname = 'customers'
ORDER BY indexrelname;


-- =========================================================
-- Q10. Final performance inspection
-- =========================================================

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
WHERE city = 'Hyderabad'
ORDER BY credit_limit DESC;