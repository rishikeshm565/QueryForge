-- ============================================================
-- QueryForge
-- Day 12 - SELECT Practice
-- Basic Data Retrieval
-- ============================================================


-- ============================================================
-- 1. SELECT ALL COLUMNS
-- ============================================================

SELECT *
FROM customers;


-- ============================================================
-- 2. SELECT SPECIFIC COLUMNS
-- ============================================================

SELECT
    customer_id,
    full_name,
    email
FROM customers;


-- ============================================================
-- 3. CHANGE COLUMN DISPLAY NAME USING ALIAS
-- ============================================================

SELECT
    customer_id AS id,
    full_name AS customer_name,
    email AS customer_email
FROM customers;


-- ============================================================
-- 4. SELECT DISTINCT VALUES
-- ============================================================

SELECT DISTINCT
    city
FROM customers
ORDER BY city;


-- ============================================================
-- 5. LIMIT RESULT
-- ============================================================

SELECT
    customer_id,
    full_name,
    city
FROM customers
ORDER BY customer_id
LIMIT 3;


-- ============================================================
-- 6. OFFSET RESULT
-- ============================================================

SELECT
    customer_id,
    full_name,
    city
FROM customers
ORDER BY customer_id
LIMIT 2
OFFSET 2;


-- ============================================================
-- 7. ALIAS + DISTINCT TOGETHER
-- ============================================================

SELECT DISTINCT
    city AS customer_city
FROM customers
ORDER BY customer_city;

-- ============================================================
-- DAY 12 - SELF PRACTICE
-- Queries written without copying the solution
-- ============================================================

-- ============================================================
-- DAY 12 - PART 3
-- EXPRESSIONS AND CALCULATED OUTPUT
-- ============================================================


-- Q6 - Concatenation

SELECT
    full_name,
    city,
    full_name || ' - ' || city AS customer_info
FROM customers;


-- Q7 - Calculated Column

SELECT
    customer_id,
    full_name,
    credit_limit,
    credit_limit + 5000 AS increased_credit_limit
FROM customers
ORDER BY customer_id;


-- Q8 - Percentage Calculation
-- Calculate 10% of existing credit limit

SELECT
    customer_id,
    full_name,
    credit_limit,
    credit_limit * 0.10 AS ten_percent_value
FROM customers
ORDER BY customer_id;


-- Q9 - New Credit Limit After 10% Increase

SELECT
    customer_id,
    full_name,
    credit_limit,
    credit_limit * 1.10 AS credit_limit_after_10_percent_increase
FROM customers
ORDER BY customer_id;


-- Q10 - Constant / Literal Column

SELECT
    customer_id,
    full_name,
    'QueryForge Customer' AS customer_type
FROM customers
ORDER BY customer_id;


-- ============================================================
-- DAY 12 - FINAL COMBINED PRACTICE
-- ============================================================

SELECT
    customer_id AS id,
    full_name AS customer_name,
    city AS customer_city,
    credit_limit,
    credit_limit + 5000 AS increased_credit_limit,
    full_name || ' - ' || city AS customer_info
FROM customers
ORDER BY customer_id
LIMIT 5;