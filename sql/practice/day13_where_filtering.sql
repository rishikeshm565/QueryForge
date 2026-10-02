-- ============================================================
-- QueryForge
-- Day 13 - WHERE & Filtering
-- ============================================================


-- ============================================================
-- 1. BASIC WHERE
-- Hyderabad customers
-- ============================================================

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE city = 'Hyderabad'
ORDER BY customer_id;


-- ============================================================
-- 2. GREATER THAN
-- Credit limit above 20000
-- ============================================================

SELECT
    customer_id,
    full_name,
    credit_limit
FROM customers
WHERE credit_limit > 20000
ORDER BY credit_limit DESC;


-- ============================================================
-- 3. GREATER THAN OR EQUAL TO
-- ============================================================

SELECT
    customer_id,
    full_name,
    credit_limit
FROM customers
WHERE credit_limit >= 20000
ORDER BY customer_id;


-- ============================================================
-- 4. NOT EQUAL
-- ============================================================

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE city <> 'Hyderabad'
ORDER BY customer_id;


-- ============================================================
-- 5. AND CONDITION
-- Active customers with credit limit >= 18000
-- ============================================================

SELECT
    customer_id,
    full_name,
    credit_limit,
    is_active
FROM customers
WHERE is_active = TRUE
  AND credit_limit >= 18000
ORDER BY customer_id;


-- ============================================================
-- 6. OR CONDITION
-- Hyderabad OR Pune customers
-- ============================================================

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE city = 'Hyderabad'
   OR city = 'Pune'
ORDER BY customer_id;


-- ============================================================
-- 7. IN
-- Same idea using IN
-- ============================================================

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE city IN (
    'Hyderabad',
    'Pune',
    'Chennai'
)
ORDER BY customer_id;


-- ============================================================
-- 8. NOT IN
-- ============================================================

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE city NOT IN (
    'Hyderabad',
    'Pune'
)
ORDER BY customer_id;


-- ============================================================
-- 9. BETWEEN
-- Credit limits between 18000 and 23000
-- ============================================================

SELECT
    customer_id,
    full_name,
    credit_limit
FROM customers
WHERE credit_limit BETWEEN 18000 AND 23000
ORDER BY credit_limit;


-- ============================================================
-- 10. CUSTOMER ID RANGE
-- ============================================================

SELECT
    customer_id,
    full_name
FROM customers
WHERE customer_id BETWEEN 4102 AND 4104
ORDER BY customer_id;


-- ============================================================
-- 11. LIKE
-- Names starting with R
-- ============================================================

SELECT
    customer_id,
    full_name
FROM customers
WHERE full_name LIKE 'R%';


-- ============================================================
-- 12. LIKE
-- Names containing "Singh"
-- ============================================================

SELECT
    customer_id,
    full_name
FROM customers
WHERE full_name LIKE '%Singh%';


-- ============================================================
-- 13. ILIKE
-- Case-insensitive search
-- ============================================================

SELECT
    customer_id,
    full_name
FROM customers
WHERE full_name ILIKE '%RAHUL%';


-- ============================================================
-- 14. IS NULL
-- ============================================================

SELECT
    customer_id,
    full_name,
    phone
FROM customers
WHERE phone IS NULL;


-- ============================================================
-- 15. IS NOT NULL
-- ============================================================

SELECT
    customer_id,
    full_name,
    email
FROM customers
WHERE email IS NOT NULL
ORDER BY customer_id;


-- ============================================================
-- 16. BOOLEAN FILTER
-- ============================================================

SELECT
    customer_id,
    full_name,
    is_active
FROM customers
WHERE is_active = FALSE
ORDER BY customer_id;


-- ============================================================
-- 17. COMBINED FILTER
-- ============================================================

SELECT
    customer_id,
    full_name,
    city,
    credit_limit,
    is_active
FROM customers
WHERE city IN (
    'Hyderabad',
    'Bengaluru'
)
AND credit_limit >= 18000
ORDER BY credit_limit DESC;