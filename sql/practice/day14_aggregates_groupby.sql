-- ============================================================
-- QueryForge
-- Day 14 - Aggregate Functions, GROUP BY and HAVING
-- ============================================================


-- ============================================================
-- 1. COUNT ALL CUSTOMERS
-- ============================================================

SELECT
    COUNT(*) AS total_customers
FROM customers;


-- ============================================================
-- 2. COUNT ACTIVE CUSTOMERS
-- ============================================================

SELECT
    COUNT(*) AS active_customers
FROM customers
WHERE is_active = TRUE;


-- ============================================================
-- 3. SUM OF CREDIT LIMIT
-- ============================================================

SELECT
    SUM(credit_limit) AS total_credit_limit
FROM customers;


-- ============================================================
-- 4. AVERAGE CREDIT LIMIT
-- ============================================================

SELECT
    AVG(credit_limit) AS average_credit_limit
FROM customers;


-- ============================================================
-- 5. MINIMUM AND MAXIMUM CREDIT LIMIT
-- ============================================================

SELECT
    MIN(credit_limit) AS minimum_credit_limit,
    MAX(credit_limit) AS maximum_credit_limit
FROM customers;


-- ============================================================
-- 6. MULTIPLE AGGREGATES TOGETHER
-- ============================================================

SELECT
    COUNT(*) AS total_customers,
    SUM(credit_limit) AS total_credit_limit,
    AVG(credit_limit) AS average_credit_limit,
    MIN(credit_limit) AS minimum_credit_limit,
    MAX(credit_limit) AS maximum_credit_limit
FROM customers;


-- ============================================================
-- 7. CUSTOMERS BY CITY
-- ============================================================

SELECT
    city,
    COUNT(*) AS customer_count
FROM customers
GROUP BY city
ORDER BY city;


-- ============================================================
-- 8. TOTAL CREDIT LIMIT BY CITY
-- ============================================================

SELECT
    city,
    SUM(credit_limit) AS total_credit_limit
FROM customers
GROUP BY city
ORDER BY total_credit_limit DESC;


-- ============================================================
-- 9. AVERAGE CREDIT LIMIT BY CITY
-- ============================================================

SELECT
    city,
    AVG(credit_limit) AS average_credit_limit
FROM customers
GROUP BY city
ORDER BY average_credit_limit DESC;


-- ============================================================
-- 10. CUSTOMERS BY ACTIVE STATUS
-- ============================================================

SELECT
    is_active,
    COUNT(*) AS customer_count
FROM customers
GROUP BY is_active
ORDER BY is_active DESC;


-- ============================================================
-- 11. GROUP BY MULTIPLE COLUMNS
-- ============================================================

SELECT
    city,
    is_active,
    COUNT(*) AS customer_count
FROM customers
GROUP BY
    city,
    is_active
ORDER BY
    city,
    is_active DESC;


-- ============================================================
-- 12. HAVING
-- Show cities with more than 1 customer
-- ============================================================

SELECT
    city,
    COUNT(*) AS customer_count
FROM customers
GROUP BY city
HAVING COUNT(*) > 1
ORDER BY customer_count DESC;


-- ============================================================
-- 13. HAVING WITH SUM
-- ============================================================

SELECT
    city,
    SUM(credit_limit) AS total_credit_limit
FROM customers
GROUP BY city
HAVING SUM(credit_limit) > 30000
ORDER BY total_credit_limit DESC;


-- ============================================================
-- 14. WHERE + GROUP BY
-- Active customers grouped by city
-- ============================================================

SELECT
    city,
    COUNT(*) AS active_customer_count
FROM customers
WHERE is_active = TRUE
GROUP BY city
ORDER BY city;


-- ============================================================
-- 15. FINAL COMBINED AGGREGATION
-- ============================================================

SELECT
    city,
    COUNT(*) AS customer_count,
    SUM(credit_limit) AS total_credit_limit,
    ROUND(AVG(credit_limit), 2) AS average_credit_limit,
    MIN(credit_limit) AS minimum_credit_limit,
    MAX(credit_limit) AS maximum_credit_limit
FROM customers
GROUP BY city
ORDER BY total_credit_limit DESC;