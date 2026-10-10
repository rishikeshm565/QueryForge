-- ============================================================
-- QueryForge
-- Day 55 - Range Partitioning
-- ============================================================


-- ------------------------------------------------------------
-- 1. Create partitioned table
-- ------------------------------------------------------------

DROP TABLE IF EXISTS scale.orders_partitioned CASCADE;

CREATE TABLE scale.orders_partitioned
(
    order_id      BIGINT GENERATED ALWAYS AS IDENTITY,
    customer_id   BIGINT NOT NULL,
    order_date    DATE NOT NULL,
    amount        NUMERIC(12,2) NOT NULL,
    status        VARCHAR(20) NOT NULL,

    PRIMARY KEY (order_id, order_date)
)
PARTITION BY RANGE (order_date);


-- ------------------------------------------------------------
-- 2. Create yearly partitions
-- ------------------------------------------------------------

CREATE TABLE scale.orders_2024
PARTITION OF scale.orders_partitioned
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');


CREATE TABLE scale.orders_2025
PARTITION OF scale.orders_partitioned
FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');


CREATE TABLE scale.orders_2026
PARTITION OF scale.orders_partitioned
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');


CREATE TABLE scale.orders_default
PARTITION OF scale.orders_partitioned
DEFAULT;


-- ------------------------------------------------------------
-- 3. Generate 300,000 rows
-- ------------------------------------------------------------

INSERT INTO scale.orders_partitioned
(
    customer_id,
    order_date,
    amount,
    status
)
SELECT
    1 + (g % 100000),

    DATE '2024-01-01'
        + (g % 1096),

    ROUND(
        (100 + RANDOM() * 4900)::NUMERIC,
        2
    ),

    CASE g % 4
        WHEN 0 THEN 'NEW'
        WHEN 1 THEN 'PAID'
        WHEN 2 THEN 'SHIPPED'
        ELSE 'CLOSED'
    END

FROM generate_series(1,300000) AS g;


ANALYZE scale.orders_partitioned;


-- ------------------------------------------------------------
-- 4. Verify distribution
-- ------------------------------------------------------------

SELECT
    tableoid::regclass AS partition_name,
    COUNT(*) AS row_count
FROM scale.orders_partitioned
GROUP BY tableoid
ORDER BY partition_name;


-- ------------------------------------------------------------
-- 5. Partition pruning
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM scale.orders_partitioned
WHERE order_date >= DATE '2026-01-01'
  AND order_date <  DATE '2026-04-01';


-- ------------------------------------------------------------
-- 6. Query touching all partitions
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM scale.orders_partitioned;


-- ------------------------------------------------------------
-- 7. Check partitions
-- ------------------------------------------------------------

SELECT
    parent.relname AS parent_table,
    child.relname  AS partition_table

FROM pg_inherits

JOIN pg_class parent
    ON pg_inherits.inhparent = parent.oid

JOIN pg_class child
    ON pg_inherits.inhrelid = child.oid

WHERE parent.relname = 'orders_partitioned'

ORDER BY child.relname;