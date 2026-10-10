-- ============================================================
-- QueryForge
-- Day 54 - Query Optimization
-- ============================================================


-- 1. GOOD: Primary-key lookup

EXPLAIN ANALYZE
SELECT *
FROM scale.customers_big
WHERE customer_id = 50000;


-- 2. BAD: CAST on indexed column

EXPLAIN ANALYZE
SELECT *
FROM scale.customers_big
WHERE customer_id::text = '50000';


-- 3. BAD: Function on indexed city column

EXPLAIN ANALYZE
SELECT
    city,
    full_name,
    credit_limit
FROM scale.customers_big
WHERE LOWER(city) = 'hyderabad';


-- 4. GOOD: Direct comparison

EXPLAIN ANALYZE
SELECT
    city,
    full_name,
    credit_limit
FROM scale.customers_big
WHERE city = 'Hyderabad';


-- 5. SELECT *

EXPLAIN ANALYZE
SELECT *
FROM scale.customers_big
WHERE city = 'Hyderabad';


-- 6. Only required columns

EXPLAIN ANALYZE
SELECT
    city,
    full_name,
    credit_limit
FROM scale.customers_big
WHERE city = 'Hyderabad';


-- 7. GOOD ORDER BY
-- Day 53 composite index should help

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


-- 8. BAD ORDER BY expression

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM scale.customers_big
WHERE city = 'Hyderabad'
ORDER BY credit_limit + 0 DESC
LIMIT 20;


-- 9. Full matching result

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM scale.customers_big
WHERE city = 'Hyderabad'
ORDER BY credit_limit DESC;


-- 10. Same query with LIMIT

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


-- 11. Leading wildcard

EXPLAIN ANALYZE
SELECT *
FROM scale.customers_big
WHERE full_name LIKE '%Customer 999%';