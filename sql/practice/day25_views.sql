-- =========================================================
-- QueryForge
-- Day 25 - SQL Views
-- =========================================================


-- =========================================================
-- Q1. Create a basic view
-- High-credit customers
-- =========================================================

CREATE OR REPLACE VIEW vw_high_credit_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
WHERE credit_limit >= 20000;


-- =========================================================
-- Q2. Query the view
-- =========================================================

SELECT *
FROM vw_high_credit_customers
ORDER BY credit_limit DESC;


-- =========================================================
-- Q3. Create city-level summary view
-- =========================================================

CREATE OR REPLACE VIEW vw_city_credit_summary AS
SELECT
    city,
    COUNT(*) AS total_customers,
    ROUND(AVG(credit_limit), 2) AS avg_credit_limit,
    SUM(credit_limit) AS total_credit_limit
FROM customers
GROUP BY city;


-- =========================================================
-- Q4. Query city summary view
-- =========================================================

SELECT *
FROM vw_city_credit_summary
ORDER BY total_credit_limit DESC;


-- =========================================================
-- Q5. Create customer segmentation view
-- =========================================================

CREATE OR REPLACE VIEW vw_customer_credit_segments AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit,

    CASE
        WHEN credit_limit >= 23000 THEN 'High Credit'
        WHEN credit_limit >= 18000 THEN 'Medium Credit'
        ELSE 'Low Credit'
    END AS credit_segment

FROM customers;


-- Query segmentation view
SELECT *
FROM vw_customer_credit_segments
ORDER BY credit_limit DESC;


-- =========================================================
-- Q6. Replace existing view
-- Change high-credit threshold
-- =========================================================

CREATE OR REPLACE VIEW vw_high_credit_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
WHERE credit_limit >= 22000;


-- Check modified view
SELECT *
FROM vw_high_credit_customers
ORDER BY credit_limit DESC;


-- =========================================================
-- Q7. View with window functions
-- =========================================================

CREATE OR REPLACE VIEW vw_customer_credit_rankings AS
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


-- Query ranking view
SELECT *
FROM vw_customer_credit_rankings
ORDER BY overall_credit_rank;


-- =========================================================
-- Q8. Filter data from a view
-- =========================================================

SELECT
    customer_id,
    full_name,
    city,
    credit_limit,
    overall_credit_rank
FROM vw_customer_credit_rankings
WHERE overall_credit_rank <= 3
ORDER BY overall_credit_rank;


-- =========================================================
-- Q9. Create final reporting view
-- View using another view
-- =========================================================

CREATE OR REPLACE VIEW vw_customer_final_report AS
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

FROM vw_customer_credit_rankings r

JOIN vw_city_credit_summary s
    ON r.city = s.city;


-- =========================================================
-- Q10. Final Day 25 reporting output
-- =========================================================

SELECT *
FROM vw_customer_final_report
ORDER BY overall_credit_rank;