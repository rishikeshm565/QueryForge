-- ============================================================
-- QueryForge / DataVault 360
-- Day 44 - Search Ranking
-- Exact -> Prefix -> Fuzzy
-- ============================================================


-- ------------------------------------------------------------
-- TASK 1: Exact Match
-- Highest priority
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE LOWER(full_name) = LOWER('Meera Reddy');


-- ------------------------------------------------------------
-- TASK 2: Prefix Match
-- Second priority
-- ------------------------------------------------------------

SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE LOWER(full_name) LIKE LOWER('mee') || '%';


-- ------------------------------------------------------------
-- TASK 3: Fuzzy Match
-- Third priority
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
WHERE LOWER(full_name) % LOWER('meera redy')
ORDER BY similarity_score DESC;


-- ------------------------------------------------------------
-- TASK 4: Combined Ranking
-- Exact = 1
-- Prefix = 2
-- Fuzzy = 3
-- ------------------------------------------------------------

WITH search_input AS (
    SELECT 'Meera Reddy'::text AS search_text
)

SELECT
    c.customer_id,
    c.full_name,
    c.city,

    CASE
        WHEN LOWER(c.full_name) = LOWER(s.search_text)
            THEN 1

        WHEN LOWER(c.full_name)
             LIKE LOWER(s.search_text) || '%'
            THEN 2

        ELSE 3
    END AS relevance_rank,

    similarity(
        LOWER(c.full_name),
        LOWER(s.search_text)
    ) AS similarity_score

FROM customers c
CROSS JOIN search_input s

WHERE
       LOWER(c.full_name) = LOWER(s.search_text)

    OR LOWER(c.full_name)
       LIKE LOWER(s.search_text) || '%'

    OR LOWER(c.full_name) % LOWER(s.search_text)

ORDER BY
    relevance_rank ASC,
    similarity_score DESC,
    c.customer_id;