BEGIN;

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

-- Existing materialized view is preserved.


CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.mv_monthly_order_summary AS

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

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_monthly_order_summary
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

-- Repeated 100-row INSERT removed to protect source data.


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

-- ============================================
-- AUTOMATIC FINAL VALIDATION
-- ============================================

DO $day56$
DECLARE
    source_count BIGINT;
    summarized_count BIGINT;
    mismatches BIGINT;
    index_valid BOOLEAN;
BEGIN

    SELECT COUNT(*)
    INTO source_count
    FROM scale.orders_partitioned;

    SELECT COALESCE(SUM(total_orders), 0)
    INTO summarized_count
    FROM analytics.mv_monthly_order_summary;

    WITH live_data AS (
        SELECT
            DATE_TRUNC('month', order_date)::DATE AS month,
            status,
            COUNT(*) AS total_orders,
            SUM(amount) AS total_amount
        FROM scale.orders_partitioned
        GROUP BY 1, 2
    )
    SELECT COUNT(*)
    INTO mismatches
    FROM live_data s
    FULL OUTER JOIN
        analytics.mv_monthly_order_summary m
        ON s.month = m.month
       AND s.status = m.status
    WHERE s.month IS NULL
       OR m.month IS NULL
       OR s.total_orders IS DISTINCT FROM m.total_orders
       OR s.total_amount IS DISTINCT FROM m.total_amount;

    SELECT EXISTS (
        SELECT 1
        FROM pg_index i
        WHERE i.indrelid =
            'analytics.mv_monthly_order_summary'::regclass
          AND i.indisunique
          AND i.indisvalid
          AND i.indnkeyatts = 2
          AND pg_get_indexdef(i.indexrelid, 1, TRUE) = 'month'
          AND pg_get_indexdef(i.indexrelid, 2, TRUE) = 'status'
    )
    INTO index_valid;

    IF source_count <> 300000
       OR summarized_count <> source_count
       OR mismatches <> 0
       OR NOT index_valid
    THEN
        RAISE EXCEPTION
            'DAY 56 FAIL: source %, summary %, mismatches %, valid index %',
            source_count,
            summarized_count,
            mismatches,
            index_valid;
    END IF;

    RAISE NOTICE 'DAY 56 VALIDATION: PASS';
    RAISE NOTICE 'Source orders: %', source_count;
    RAISE NOTICE 'Summarized orders: %', summarized_count;
    RAISE NOTICE 'Aggregate mismatches: %', mismatches;
    RAISE NOTICE 'Unique index valid: %', index_valid;

END
$day56$;
COMMIT;
