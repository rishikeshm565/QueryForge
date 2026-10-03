-- ============================================================
-- QueryForge / DataVault 360
-- Day 45 - Autocomplete
-- ============================================================


-- ------------------------------------------------------------
-- TASK 1: Basic prefix autocomplete
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE LOWER(full_name) LIKE LOWER('me') || '%'
ORDER BY full_name;


-- ------------------------------------------------------------
-- TASK 2: Another prefix test
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE LOWER(full_name) LIKE LOWER('ra') || '%'
ORDER BY full_name;


-- ------------------------------------------------------------
-- TASK 3: Search input using CTE
-- ------------------------------------------------------------

WITH search_input AS (
    SELECT 'me'::text AS search_text
)

SELECT
    c.customer_id,
    c.full_name,
    c.city
FROM customers c
CROSS JOIN search_input s
WHERE LOWER(c.full_name)
      LIKE LOWER(s.search_text) || '%'
ORDER BY c.full_name
LIMIT 5;


-- ------------------------------------------------------------
-- TASK 4: Autocomplete on name OR city
-- ------------------------------------------------------------

WITH search_input AS (
    SELECT 'hyd'::text AS search_text
)

SELECT
    c.customer_id,
    c.full_name,
    c.city
FROM customers c
CROSS JOIN search_input s
WHERE
       LOWER(c.full_name)
       LIKE LOWER(s.search_text) || '%'

    OR LOWER(c.city)
       LIKE LOWER(s.search_text) || '%'

ORDER BY
    c.full_name
LIMIT 5;










-- ------------------------------------------------------------
-- TASK 5: Reusable autocomplete function
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION customer_autocomplete(
    p_search_text TEXT,
    p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
    customer_id INTEGER,
    full_name VARCHAR(100),
    city VARCHAR(80)
)
LANGUAGE SQL
STABLE
AS $$
    SELECT
        c.customer_id,
        c.full_name,
        c.city
    FROM customers c
    WHERE
           LOWER(c.full_name) LIKE LOWER(p_search_text) || '%'
        OR LOWER(c.city)      LIKE LOWER(p_search_text) || '%'
    ORDER BY c.full_name
    LIMIT p_limit;
$$;