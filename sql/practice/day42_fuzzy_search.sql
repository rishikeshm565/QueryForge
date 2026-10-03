-- ============================================================
-- QueryForge / DataVault 360
-- Day 42 - PostgreSQL Fuzzy Search
-- pg_trgm + similarity()
-- ============================================================


-- ------------------------------------------------------------
-- TASK 1: Enable pg_trgm extension
-- ------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pg_trgm;


-- ------------------------------------------------------------
-- TASK 2: Check extension
-- ------------------------------------------------------------

SELECT
    extname,
    extversion
FROM pg_extension
WHERE extname = 'pg_trgm';


-- ------------------------------------------------------------
-- TASK 3: Normal search with spelling mistake
-- Expected: 0 rows
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE LOWER(full_name) LIKE '%meera redy%';


-- ------------------------------------------------------------
-- TASK 4: Calculate similarity
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    similarity(
        LOWER(full_name),
        LOWER('meera redy')
    ) AS similarity_score
FROM customers
ORDER BY similarity_score DESC;


-- ------------------------------------------------------------
-- TASK 5: Fuzzy search
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    city,
    similarity(
        LOWER(full_name),
        LOWER('meera redy')
    ) AS similarity_score
FROM customers
WHERE similarity(
        LOWER(full_name),
        LOWER('meera redy')
      ) >= 0.30
ORDER BY similarity_score DESC;


-- ------------------------------------------------------------
-- TASK 6: Typo search on city
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    city,
    similarity(
        LOWER(city),
        LOWER('hydrebad')
    ) AS similarity_score
FROM customers
WHERE similarity(
        LOWER(city),
        LOWER('hydrebad')
      ) >= 0.30
ORDER BY similarity_score DESC;