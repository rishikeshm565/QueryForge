-- =========================================================
-- QueryForge
-- Day 26 - Temporary Tables & Materialized Views
-- =========================================================


-- =========================================================
-- Q1. Create temporary table
-- =========================================================

DROP TABLE IF EXISTS temp_high_credit_customers;

CREATE TEMP TABLE temp_high_credit_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
WHERE credit_limit >= 20000;


-- =========================================================
-- Q2. Query temporary table
-- =========================================================

SELECT *
FROM temp_high_credit_customers
ORDER BY credit_limit DESC;


-- =========================================================
-- Q3. Create temporary city summary table
-- =========================================================

DROP TABLE IF EXISTS temp_city_credit_summary;

CREATE TEMP TABLE temp_city_credit_summary AS
SELECT
    city,
    COUNT(*) AS total_customers,
    ROUND(AVG(credit_limit), 2) AS avg_credit_limit,
    SUM(credit_limit) AS total_credit_limit
FROM customers
GROUP BY city;


SELECT *
FROM temp_city_credit_summary
ORDER BY total_credit_limit DESC;


-- =========================================================
-- Q4. Use temporary table in a JOIN
-- =========================================================

SELECT
    c.customer_id,
    c.full_name,
    c.city,
    c.credit_limit,
    t.avg_credit_limit
FROM customers c
JOIN temp_city_credit_summary t
    ON c.city = t.city
ORDER BY c.credit_limit DESC;


-- =========================================================
-- Q5. Create materialized view
-- PostgreSQL does NOT support CREATE OR REPLACE
-- for materialized views
-- =========================================================

DROP MATERIALIZED VIEW IF EXISTS mv_city_credit_summary;

CREATE MATERIALIZED VIEW mv_city_credit_summary AS
SELECT
    city,
    COUNT(*) AS total_customers,
    ROUND(AVG(credit_limit), 2) AS avg_credit_limit,
    SUM(credit_limit) AS total_credit_limit
FROM customers
GROUP BY city;


-- =========================================================
-- Q6. Query materialized view
-- =========================================================

SELECT *
FROM mv_city_credit_summary
ORDER BY total_credit_limit DESC;


-- =========================================================
-- Q7. Create customer ranking materialized view
-- =========================================================

DROP MATERIALIZED VIEW IF EXISTS mv_customer_credit_rankings;

CREATE MATERIALIZED VIEW mv_customer_credit_rankings AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit,

    DENSE_RANK() OVER (
        ORDER BY credit_limit DESC
    ) AS overall_credit_rank,

    ROW_NUMBER() OVER (
        PARTITION BY city
        ORDER BY credit_limit DESC
    ) AS city_credit_rank

FROM customers;


-- =========================================================
-- Q8. Query ranking materialized view
-- =========================================================

SELECT *
FROM mv_customer_credit_rankings
ORDER BY overall_credit_rank;


-- =========================================================
-- Q9. Refresh materialized view
-- Re-runs underlying query and stores latest result
-- =========================================================

REFRESH MATERIALIZED VIEW mv_city_credit_summary;

SELECT *
FROM mv_city_credit_summary
ORDER BY total_credit_limit DESC;


-- =========================================================
-- Q10. Final materialized-view report
-- =========================================================

SELECT
    r.customer_id,
    r.full_name,
    r.city,
    r.credit_limit,
    r.overall_credit_rank,
    r.city_credit_rank,

    s.total_customers AS customers_in_city,
    s.avg_credit_limit AS city_avg_credit_limit,
    s.total_credit_limit AS city_total_credit_limit

FROM mv_customer_credit_rankings r

JOIN mv_city_credit_summary s
    ON r.city = s.city

ORDER BY r.overall_credit_rank;