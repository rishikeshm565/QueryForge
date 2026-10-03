-- ============================================================
-- QueryForge / DataVault 360
-- Day 41 - PostgreSQL Full-Text Search
-- ============================================================


-- ------------------------------------------------------------
-- TASK 1: Check current customer data
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
ORDER BY customer_id;


-- ------------------------------------------------------------
-- TASK 2: Traditional search using LIKE
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE LOWER(full_name) LIKE '%meera%';


-- ------------------------------------------------------------
-- TASK 3: Convert text into TSVECTOR
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    to_tsvector('english', full_name) AS search_vector
FROM customers;


-- ------------------------------------------------------------
-- TASK 4: Basic Full-Text Search
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE to_tsvector('english', full_name)
      @@ plainto_tsquery('english', 'meera');


-- ============================================================
-- TASK 5: Search across multiple columns
-- ============================================================

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE to_tsvector(
        'english',
        COALESCE(full_name, '') || ' ' || COALESCE(city, '')
      )
      @@ plainto_tsquery('english', 'hyderabad');