-- ============================================================
-- QueryForge
-- Day 56 - Materialized Views
-- ============================================================


CREATE SCHEMA IF NOT EXISTS analytics;


-- ------------------------------------------------------------
-- 1. Normal analytical query
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    DATE_TRUNC('month', order_date)::DATE AS month,
    status,
    COUNT(*) AS total_orders,
    SUM(amount) AS total_amount

FROM scale.orders_partitioned

GROUP BY
    DATE_TRUNC('month', order_date)::DATE,
    status

ORDER BY month, status;


-- ------------------------------------------------------------
-- 2. Create Materialized View
-- ------------------------------------------------------------

DROP MATERIALIZED VIEW IF EXISTS
analytics.mv_monthly_order_summary;


CREATE MATERIALIZED VIEW
analytics.mv_monthly_order_summary
AS

SELECT
    DATE_TRUNC('month', order_date)::DATE AS month,
    status,
    COUNT(*) AS total_orders,
    SUM(amount) AS total_amount

FROM scale.orders_partitioned

GROUP BY
    DATE_TRUNC('month', order_date)::DATE,
    status;


-- ------------------------------------------------------------
-- 3. Index materialized view
-- ------------------------------------------------------------

CREATE UNIQUE INDEX
idx_mv_monthly_order_summary
ON analytics.mv_monthly_order_summary
(
    month,
    status
);


-- ------------------------------------------------------------
-- 4. Query materialized view
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM analytics.mv_monthly_order_summary
WHERE month = DATE '2026-01-01';


-- ------------------------------------------------------------
-- 5. Add new source data
-- ------------------------------------------------------------

INSERT INTO scale.orders_partitioned
(
    customer_id,
    order_date,
    amount,
    status
)

SELECT
    50000 + g,
    DATE '2026-10-01',
    1000.00,
    'PAID'

FROM generate_series(1,100) AS g;


-- ------------------------------------------------------------
-- 6. Refresh materialized view
-- ------------------------------------------------------------

REFRESH MATERIALIZED VIEW
analytics.mv_monthly_order_summary;


-- ------------------------------------------------------------
-- 7. Verify refreshed result
-- ------------------------------------------------------------

SELECT *
FROM analytics.mv_monthly_order_summary
WHERE month = DATE '2026-10-01'
ORDER BY status;