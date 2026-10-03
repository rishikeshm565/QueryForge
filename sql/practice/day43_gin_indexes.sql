-- ============================================================
-- QueryForge / DataVault 360
-- Day 43 - GIN Indexes
-- B-tree vs GIN
-- ============================================================


-- ------------------------------------------------------------
-- TASK 1: Check all indexes on customers
-- ------------------------------------------------------------

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'customers'
ORDER BY indexname;


-- ------------------------------------------------------------
-- TASK 2: Check actual index access method
-- ------------------------------------------------------------

SELECT
    i.relname AS index_name,
    am.amname AS index_type
FROM pg_class t
JOIN pg_index ix
    ON t.oid = ix.indrelid
JOIN pg_class i
    ON i.oid = ix.indexrelid
JOIN pg_am am
    ON i.relam = am.oid
WHERE t.relname = 'customers'
ORDER BY i.relname;


-- ------------------------------------------------------------
-- TASK 3: B-tree query
-- Equality search
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE city = 'Hyderabad';


-- ------------------------------------------------------------
-- TASK 4: GIN Full-Text Search
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE search_vector
      @@ plainto_tsquery('english', 'hyderabad');


-- ------------------------------------------------------------
-- TASK 5: GIN Trigram Fuzzy Search
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city
FROM customers
WHERE LOWER(full_name) % LOWER('meera redy');