-- PRODUCTS

INSERT INTO products (
    product_id,
    product_name,
    unit_price,
    is_active
)
VALUES
    (5101, 'Laptop Stand',         1200.00, TRUE),
    (5102, 'Wireless Mouse',        800.00, TRUE),
    (5103, 'Mechanical Keyboard',  2500.00, TRUE),
    (5104, 'USB-C Hub',            1500.00, TRUE),
    (5105, 'Headset',              1800.00, TRUE)
ON CONFLICT (product_id) DO NOTHING;


-- ORDERS

INSERT INTO orders (
    order_id,
    customer_id,
    order_date,
    order_status,
    total_amount
)
VALUES
    (6101, 4101, '2026-09-01', 'Completed', 2800.00),
    (6102, 4102, '2026-09-05', 'Completed', 2500.00),
    (6103, 4101, '2026-09-10', 'Completed', 3300.00),
    (6104, 4103, '2026-09-15', 'Completed', 3800.00),
    (6105, 4105, '2026-09-20', 'Completed', 3600.00)
ON CONFLICT (order_id) DO NOTHING;


-- ORDER ITEMS

INSERT INTO order_items (
    order_id,
    product_id,
    quantity,
    unit_price
)
VALUES
    (6101, 5101, 1, 1200.00),
    (6101, 5102, 2, 800.00),

    (6102, 5103, 1, 2500.00),

    (6103, 5104, 1, 1500.00),
    (6103, 5105, 1, 1800.00),

    (6104, 5102, 1, 800.00),
    (6104, 5104, 2, 1500.00),

    (6105, 5105, 2, 1800.00)
ON CONFLICT (order_id, product_id) DO NOTHING;



SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM customers

UNION ALL

SELECT 'orders', COUNT(*)
FROM orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM order_items

UNION ALL

SELECT 'products', COUNT(*)
FROM products;


SELECT
    c.customer_id,
    c.full_name,
    o.order_id,
    oi.product_id,
    p.*
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
INNER JOIN products p
    ON oi.product_id = p.product_id
ORDER BY
    c.customer_id,
    o.order_id,
    oi.product_id;




	SELECT
    c.customer_id,
    c.full_name,
    o.order_id
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
ORDER BY
    c.customer_id,
    o.order_id;


	SELECT
    customer_id,
    full_name
FROM customers
WHERE customer_id NOT IN (
    SELECT customer_id
    FROM orders
)
ORDER BY customer_id;

-- Q1: Above-average credit limit

SELECT
    customer_id,
    full_name,
    credit_limit
FROM customers
WHERE credit_limit > (
    SELECT AVG(credit_limit)
    FROM customers
)
ORDER BY credit_limit DESC;


-- Q4: Customers without orders

SELECT
    customer_id,
    full_name
FROM customers
WHERE customer_id NOT IN (
    SELECT customer_id
    FROM orders
)
ORDER BY customer_id;

-- Q8: Correlated subquery
-- Customer ke apne average order se bada order

SELECT
    o.order_id,
    o.customer_id,
    o.total_amount
FROM orders o
WHERE o.total_amount > (
    SELECT AVG(o2.total_amount)
    FROM orders o2
    WHERE o2.customer_id = o.customer_id
)
ORDER BY
    o.customer_id,
    o.total_amount DESC;



	-- Q10: Final combined result

SELECT
    c.customer_id,
    c.full_name,

    (
        SELECT COUNT(*)
        FROM orders o
        WHERE o.customer_id = c.customer_id
    ) AS order_count,

    (
        SELECT MAX(o.total_amount)
        FROM orders o
        WHERE o.customer_id = c.customer_id
    ) AS highest_order_amount

FROM customers c
ORDER BY
    order_count DESC,
    c.customer_id;











	WITH order_summary AS (
    SELECT
        customer_id,
        COUNT(*) AS order_count,
        SUM(total_amount) AS total_spend,
        AVG(total_amount) AS average_order_value,
        MAX(total_amount) AS highest_order_value
    FROM orders
    GROUP BY customer_id
)

SELECT
    c.customer_id,
    c.full_name,
    c.city,

    COALESCE(os.order_count, 0) AS order_count,

    COALESCE(
        os.total_spend,
        0
    ) AS total_spend,

    ROUND(
        COALESCE(
            os.average_order_value,
            0
        ),
        2
    ) AS average_order_value,

    COALESCE(
        os.highest_order_value,
        0
    ) AS highest_order_value

FROM customers c
LEFT JOIN order_summary os
    ON c.customer_id = os.customer_id
ORDER BY
    total_spend DESC,
    c.customer_id;

	SELECT
    c.customer_id,
    c.full_name,
    o.order_id,
    o.order_date,
    o.total_amount,

    ROW_NUMBER() OVER (
        PARTITION BY c.customer_id
        ORDER BY o.order_date
    ) AS order_sequence,

    SUM(o.total_amount) OVER (
        PARTITION BY c.customer_id
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING
        AND CURRENT ROW
    ) AS running_customer_spend,

    RANK() OVER (
        ORDER BY o.total_amount DESC
    ) AS overall_order_rank

FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id

ORDER BY
    c.customer_id,
    o.order_date;


























	WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(*) AS order_count,
        SUM(total_amount) AS total_spend
    FROM orders
    GROUP BY customer_id
)

SELECT
    c.customer_id,
    c.full_name,
    c.city,
    c.credit_limit,

    CASE
        WHEN c.credit_limit >= 23000 THEN 'High Credit'
        WHEN c.credit_limit >= 18000 THEN 'Medium Credit'
        ELSE 'Low Credit'
    END AS credit_segment,

    CASE
        WHEN c.is_active = TRUE THEN 'Active'
        ELSE 'Inactive'
    END AS status,

    COALESCE(co.order_count, 0) AS order_count,
    COALESCE(co.total_spend, 0) AS total_spend,

    CASE
        WHEN COALESCE(co.total_spend, 0) >= 5000
            THEN 'High Value Customer'

        WHEN COALESCE(co.total_spend, 0) >= 3000
            THEN 'Medium Value Customer'

        WHEN COALESCE(co.total_spend, 0) > 0
            THEN 'Low Value Customer'

        ELSE 'No Spend'
    END AS customer_value_segment

FROM customers c
LEFT JOIN customer_orders co
    ON c.customer_id = co.customer_id

ORDER BY
    total_spend DESC,
    c.customer_id;



	SELECT
    CURRENT_DATE AS today,
    CURRENT_TIMESTAMP AS current_time;



SELECT
    customer_id,
    full_name,
    date_of_birth,
    AGE(CURRENT_DATE, date_of_birth) AS customer_age
FROM customers
ORDER BY customer_id;


SELECT
    customer_id,
    full_name,
    date_of_birth,
    EXTRACT(YEAR FROM date_of_birth) AS birth_year,
    EXTRACT(MONTH FROM date_of_birth) AS birth_month
FROM customers
ORDER BY customer_id;


SELECT
    DATE_TRUNC('month', created_at) AS creation_month,
    COUNT(*) AS total_customers
FROM customers
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY creation_month;



SELECT
    customer_id,
    full_name,
    date_of_birth,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) AS age_years,
    created_at::DATE AS joined_date,
    DATE_TRUNC('month', created_at)::DATE AS joined_month,
    AGE(CURRENT_TIMESTAMP, created_at) AS customer_since
FROM customers
ORDER BY customer_id;


-- Q1. Convert customer names to upper and lower case
SELECT
    customer_id,
    full_name,
    UPPER(full_name) AS upper_name,
    LOWER(full_name) AS lower_name
FROM customers
ORDER BY customer_id;


-- Q2. Proper case formatting
SELECT
    customer_id,
    full_name,
    INITCAP(full_name) AS proper_name
FROM customers
ORDER BY customer_id;


-- Q3. Find length of customer names
SELECT
    customer_id,
    full_name,
    LENGTH(full_name) AS name_length
FROM customers
ORDER BY customer_id;


-- Q4. Remove extra spaces
SELECT
    customer_id,
    full_name,
    TRIM(full_name) AS cleaned_name
FROM customers
ORDER BY customer_id;


-- Q5. Concatenate text
SELECT
    customer_id,
    CONCAT('Customer: ', full_name) AS customer_label
FROM customers
ORDER BY customer_id;


-- Q6. Extract first 5 characters
SELECT
    customer_id,
    full_name,
    SUBSTRING(full_name FROM 1 FOR 5) AS first_five_characters
FROM customers
ORDER BY customer_id;


-- Q7. Replace spaces with underscore
SELECT
    customer_id,
    full_name,
    REPLACE(full_name, ' ', '_') AS formatted_name
FROM customers
ORDER BY customer_id;


-- Q8. Find position of first space
SELECT
    customer_id,
    full_name,
    POSITION(' ' IN full_name) AS space_position
FROM customers
ORDER BY customer_id;


-- Q9. Split first and last name
SELECT
    customer_id,
    full_name,
    SPLIT_PART(full_name, ' ', 1) AS first_name,
    SPLIT_PART(full_name, ' ', 2) AS last_name
FROM customers
ORDER BY customer_id;


-- Q10. Final cleaned customer text profile
SELECT
    customer_id,
    full_name,
    INITCAP(TRIM(full_name)) AS cleaned_full_name,
    UPPER(SPLIT_PART(TRIM(full_name), ' ', 1)) AS first_name_upper,
    LOWER(SPLIT_PART(TRIM(full_name), ' ', 2)) AS last_name_lower,
    LENGTH(TRIM(full_name)) AS name_length,
    REPLACE(LOWER(TRIM(full_name)), ' ', '_') AS customer_text_key
FROM customers
ORDER BY customer_id;



-- =========================================================
-- QueryForge
-- Day 23 - Window Functions
-- =========================================================


-- Q1. ROW_NUMBER()
-- Give every customer a unique number based on credit limit
SELECT
    customer_id,
    full_name,
    credit_limit,
    ROW_NUMBER() OVER (
        ORDER BY credit_limit DESC
    ) AS row_number
FROM customers
ORDER BY row_number;


-- Q2. RANK() and DENSE_RANK()
SELECT
    customer_id,
    full_name,
    credit_limit,

    RANK() OVER (
        ORDER BY credit_limit DESC
    ) AS credit_rank,

    DENSE_RANK() OVER (
        ORDER BY credit_limit DESC
    ) AS dense_credit_rank

FROM customers
ORDER BY credit_limit DESC;


-- Q3. PARTITION BY city
-- Rank customers separately inside each city
SELECT
    customer_id,
    full_name,
    city,
    credit_limit,

    ROW_NUMBER() OVER (
        PARTITION BY city
        ORDER BY credit_limit DESC
    ) AS city_row_number

FROM customers
ORDER BY city, city_row_number;


-- Q4. Running total of credit limit
SELECT
    customer_id,
    full_name,
    credit_limit,

    SUM(credit_limit) OVER (
        ORDER BY customer_id
    ) AS running_credit_limit

FROM customers
ORDER BY customer_id;


-- Q5. Average credit limit inside each city
SELECT
    customer_id,
    full_name,
    city,
    credit_limit,

    AVG(credit_limit) OVER (
        PARTITION BY city
    ) AS city_avg_credit_limit

FROM customers
ORDER BY city, customer_id;


-- Q6. Number of customers in each city
SELECT
    customer_id,
    full_name,
    city,

    COUNT(*) OVER (
        PARTITION BY city
    ) AS customers_in_city

FROM customers
ORDER BY city, customer_id;


-- Q7. LAG()
-- Compare current customer credit limit with previous row
SELECT
    customer_id,
    full_name,
    credit_limit,

    LAG(credit_limit) OVER (
        ORDER BY customer_id
    ) AS previous_credit_limit

FROM customers
ORDER BY customer_id;


-- Q8. LEAD()
-- Show next customer's credit limit
SELECT
    customer_id,
    full_name,
    credit_limit,

    LEAD(credit_limit) OVER (
        ORDER BY customer_id
    ) AS next_credit_limit

FROM customers
ORDER BY customer_id;


-- Q9. Highest-credit customer inside each city
SELECT
    customer_id,
    full_name,
    city,
    credit_limit,

    FIRST_VALUE(full_name) OVER (
        PARTITION BY city
        ORDER BY credit_limit DESC
    ) AS highest_credit_customer

FROM customers
ORDER BY city, credit_limit DESC;


-- Q10. Final customer window-function report
SELECT
    customer_id,
    full_name,
    city,
    credit_limit,

    ROW_NUMBER() OVER (
        ORDER BY credit_limit DESC
    ) AS overall_row_number,

    DENSE_RANK() OVER (
        ORDER BY credit_limit DESC
    ) AS overall_credit_rank,

    RANK() OVER (
        PARTITION BY city
        ORDER BY credit_limit DESC
    ) AS city_credit_rank,

    COUNT(*) OVER (
        PARTITION BY city
    ) AS customers_in_city,

    ROUND(
        AVG(credit_limit) OVER (
            PARTITION BY city
        ),
        2
    ) AS city_avg_credit_limit,

    SUM(credit_limit) OVER (
        ORDER BY customer_id
    ) AS running_credit_limit

FROM customers
ORDER BY overall_row_number;


























-- =========================================================
-- QueryForge
-- Day 24 - Common Table Expressions (CTEs)
-- =========================================================


-- Q1. Basic CTE
-- Store filtered customers temporarily and query them
WITH high_credit_customers AS (
    SELECT
        customer_id,
        full_name,
        city,
        credit_limit
    FROM customers
    WHERE credit_limit >= 20000
)
SELECT *
FROM high_credit_customers
ORDER BY credit_limit DESC;


-- Q2. CTE with calculated column
WITH customer_credit_profile AS (
    SELECT
        customer_id,
        full_name,
        credit_limit,
        credit_limit * 0.10 AS ten_percent_credit
    FROM customers
)
SELECT *
FROM customer_credit_profile
ORDER BY customer_id;


-- Q3. Aggregation inside CTE
WITH city_summary AS (
    SELECT
        city,
        COUNT(*) AS total_customers,
        ROUND(AVG(credit_limit), 2) AS avg_credit_limit,
        SUM(credit_limit) AS total_credit_limit
    FROM customers
    GROUP BY city
)
SELECT *
FROM city_summary
ORDER BY total_credit_limit DESC;


-- Q4. Filter aggregated CTE result
WITH city_summary AS (
    SELECT
        city,
        COUNT(*) AS total_customers,
        AVG(credit_limit) AS avg_credit_limit
    FROM customers
    GROUP BY city
)
SELECT
    city,
    total_customers,
    ROUND(avg_credit_limit, 2) AS avg_credit_limit
FROM city_summary
WHERE avg_credit_limit >= 20000
ORDER BY avg_credit_limit DESC;


-- Q5. Multiple CTEs
WITH high_credit AS (
    SELECT
        customer_id,
        full_name,
        city,
        credit_limit
    FROM customers
    WHERE credit_limit >= 20000
),

city_counts AS (
    SELECT
        city,
        COUNT(*) AS high_credit_customer_count
    FROM high_credit
    GROUP BY city
)

SELECT *
FROM city_counts
ORDER BY high_credit_customer_count DESC, city;


-- Q6. CTE with window function
WITH ranked_customers AS (
    SELECT
        customer_id,
        full_name,
        city,
        credit_limit,

        DENSE_RANK() OVER (
            ORDER BY credit_limit DESC
        ) AS credit_rank

    FROM customers
)

SELECT *
FROM ranked_customers
ORDER BY credit_rank;


-- Q7. Highest credit-limit customer from each city
WITH city_ranked_customers AS (
    SELECT
        customer_id,
        full_name,
        city,
        credit_limit,

        ROW_NUMBER() OVER (
            PARTITION BY city
            ORDER BY credit_limit DESC
        ) AS city_rank

    FROM customers
)

SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM city_ranked_customers
WHERE city_rank = 1
ORDER BY credit_limit DESC;


-- Q8. Customers above overall average credit limit
WITH overall_average AS (
    SELECT
        AVG(credit_limit) AS avg_credit_limit
    FROM customers
)

SELECT
    c.customer_id,
    c.full_name,
    c.city,
    c.credit_limit,
    ROUND(o.avg_credit_limit, 2) AS overall_avg_credit_limit
FROM customers c
CROSS JOIN overall_average o
WHERE c.credit_limit > o.avg_credit_limit
ORDER BY c.credit_limit DESC;


-- Q9. Chained CTEs
WITH city_stats AS (
    SELECT
        city,
        AVG(credit_limit) AS city_avg_credit
    FROM customers
    GROUP BY city
),

customer_comparison AS (
    SELECT
        c.customer_id,
        c.full_name,
        c.city,
        c.credit_limit,
        cs.city_avg_credit
    FROM customers c
    JOIN city_stats cs
        ON c.city = cs.city
)

SELECT
    customer_id,
    full_name,
    city,
    credit_limit,
    ROUND(city_avg_credit, 2) AS city_avg_credit
FROM customer_comparison
WHERE credit_limit >= city_avg_credit
ORDER BY credit_limit DESC;


-- Q10. Final CTE customer analysis report
WITH city_stats AS (
    SELECT
        city,
        COUNT(*) AS customers_in_city,
        AVG(credit_limit) AS city_avg_credit,
        SUM(credit_limit) AS city_total_credit
    FROM customers
    GROUP BY city
),

customer_rankings AS (
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

    FROM customers
)

SELECT
    cr.customer_id,
    cr.full_name,
    cr.city,
    cr.credit_limit,
    cr.overall_credit_rank,
    cr.city_credit_rank,
    cs.customers_in_city,
    ROUND(cs.city_avg_credit, 2) AS city_avg_credit,
    cs.city_total_credit

FROM customer_rankings cr

JOIN city_stats cs
    ON cr.city = cs.city

ORDER BY cr.overall_credit_rank;














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


SELECT *
FROM vw_high_credit_customers
ORDER BY credit_limit DESC;


SELECT *
FROM vw_customer_credit_rankings
ORDER BY overall_credit_rank;


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



	SELECT *
FROM vw_customer_final_report
ORDER BY overall_credit_rank;



CREATE OR REPLACE VIEW vw_city_credit_summary AS
SELECT
    city,
    COUNT(*) AS total_customers,
    ROUND(AVG(credit_limit), 2) AS avg_credit_limit,
    SUM(credit_limit) AS total_credit_limit
FROM customers
GROUP BY city;


SELECT *
FROM vw_city_credit_summary
ORDER BY total_credit_limit DESC;


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


	SELECT *
FROM vw_customer_final_report
ORDER BY overall_credit_rank;



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


-- =========================================================
-- QueryForge
-- Day 27 - Indexes & Query Performance
-- =========================================================


-- =========================================================
-- Q1. Check existing indexes on customers table
-- =========================================================

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'customers'
ORDER BY indexname;


-- =========================================================
-- Q2. Create index on city
-- =========================================================

DROP INDEX IF EXISTS idx_customers_city;

CREATE INDEX idx_customers_city
ON customers(city);


-- =========================================================
-- Q3. Create index on credit_limit
-- =========================================================

DROP INDEX IF EXISTS idx_customers_credit_limit;

CREATE INDEX idx_customers_credit_limit
ON customers(credit_limit);


-- =========================================================
-- Q4. Create composite index
-- city + credit_limit
-- =========================================================

DROP INDEX IF EXISTS idx_customers_city_credit;

CREATE INDEX idx_customers_city_credit
ON customers(city, credit_limit DESC);


-- =========================================================
-- Q5. Verify newly created indexes
-- =========================================================

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'customers'
ORDER BY indexname;


-- =========================================================
-- Q6. EXPLAIN a filtered query
-- Shows PostgreSQL execution plan
-- =========================================================

EXPLAIN
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
WHERE city = 'Hyderabad';


-- =========================================================
-- Q7. EXPLAIN ANALYZE
-- Actually executes query and shows runtime information
-- =========================================================

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
WHERE credit_limit >= 20000
ORDER BY credit_limit DESC;


-- =========================================================
-- Q8. EXPLAIN query using city + credit limit
-- =========================================================

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
WHERE city = 'Hyderabad'
  AND credit_limit >= 20000
ORDER BY credit_limit DESC;


-- =========================================================
-- Q9. Check index size
-- =========================================================

SELECT
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE relname = 'customers'
ORDER BY indexrelname;


-- =========================================================
-- Q10. Final performance inspection
-- =========================================================

EXPLAIN ANALYZE
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers
WHERE city = 'Hyderabad'
ORDER BY credit_limit DESC;




-- =========================================================
-- QueryForge
-- Day 28 - Transactions & Transaction Control
-- =========================================================


-- =========================================================
-- Q1. Create safe temporary practice table
-- =========================================================

DROP TABLE IF EXISTS temp_transaction_customers;

CREATE TEMP TABLE temp_transaction_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers;


SELECT *
FROM temp_transaction_customers
ORDER BY customer_id;


-- =========================================================
-- Q2. BEGIN + UPDATE
-- Start transaction and modify data
-- =========================================================

BEGIN;

UPDATE temp_transaction_customers
SET credit_limit = credit_limit + 5000
WHERE customer_id = 4101;


SELECT *
FROM temp_transaction_customers
WHERE customer_id = 4101;


-- =========================================================
-- Q3. ROLLBACK
-- Undo entire transaction
-- =========================================================

ROLLBACK;


SELECT *
FROM temp_transaction_customers
WHERE customer_id = 4101;


-- =========================================================
-- Q4. BEGIN + COMMIT
-- Permanently keep change inside temp table session
-- =========================================================

BEGIN;

UPDATE temp_transaction_customers
SET credit_limit = credit_limit + 1000
WHERE customer_id = 4102;

COMMIT;


SELECT *
FROM temp_transaction_customers
WHERE customer_id = 4102;


-- =========================================================
-- Q5. Transaction with SAVEPOINT
-- =========================================================

BEGIN;

UPDATE temp_transaction_customers
SET credit_limit = credit_limit + 2000
WHERE customer_id = 4103;


SAVEPOINT after_first_update;


UPDATE temp_transaction_customers
SET credit_limit = credit_limit + 5000
WHERE customer_id = 4104;


SELECT *
FROM temp_transaction_customers
WHERE customer_id IN (4103, 4104)
ORDER BY customer_id;


-- =========================================================
-- Q6. Roll back only to SAVEPOINT
-- Keeps first update, removes second update
-- =========================================================

ROLLBACK TO SAVEPOINT after_first_update;


SELECT *
FROM temp_transaction_customers
WHERE customer_id IN (4103, 4104)
ORDER BY customer_id;


-- =========================================================
-- Q7. Commit remaining transaction
-- =========================================================

COMMIT;


SELECT *
FROM temp_transaction_customers
WHERE customer_id IN (4103, 4104)
ORDER BY customer_id;


-- =========================================================
-- Q8. Multiple updates then full rollback
-- =========================================================

BEGIN;

UPDATE temp_transaction_customers
SET credit_limit = credit_limit + 10000
WHERE customer_id = 4101;

UPDATE temp_transaction_customers
SET credit_limit = credit_limit + 10000
WHERE customer_id = 4105;


SELECT *
FROM temp_transaction_customers
WHERE customer_id IN (4101, 4105)
ORDER BY customer_id;


ROLLBACK;


SELECT *
FROM temp_transaction_customers
WHERE customer_id IN (4101, 4105)
ORDER BY customer_id;


-- =========================================================
-- Q9. Check final temporary-table state
-- =========================================================

SELECT *
FROM temp_transaction_customers
ORDER BY customer_id;


-- =========================================================
-- Q10. Final transaction summary
-- =========================================================

SELECT
    customer_id,
    full_name,
    city,
    credit_limit,

    CASE
        WHEN customer_id = 4102 THEN 'Committed +1000'
        WHEN customer_id = 4103 THEN 'Committed +2000'
        ELSE 'No committed change'
    END AS transaction_result

FROM temp_transaction_customers
ORDER BY customer_id;
















-- =========================================================
-- QueryForge
-- Day 29 - PostgreSQL Functions & Stored Procedures
-- =========================================================


-- =========================================================
-- Q1. Simple scalar function
-- Returns 10% of given credit limit
-- =========================================================

DROP FUNCTION IF EXISTS fn_credit_ten_percent(NUMERIC);

CREATE FUNCTION fn_credit_ten_percent(p_credit_limit NUMERIC)
RETURNS NUMERIC
LANGUAGE SQL
AS $$
    SELECT p_credit_limit * 0.10;
$$;


-- Test function
SELECT
    customer_id,
    full_name,
    credit_limit,
    fn_credit_ten_percent(credit_limit) AS ten_percent_credit
FROM customers
ORDER BY customer_id;


-- =========================================================
-- Q2. Function with conditional logic
-- Returns customer credit category
-- =========================================================

DROP FUNCTION IF EXISTS fn_credit_category(NUMERIC);

CREATE FUNCTION fn_credit_category(p_credit_limit NUMERIC)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_credit_limit >= 23000 THEN
        RETURN 'High Credit';

    ELSIF p_credit_limit >= 18000 THEN
        RETURN 'Medium Credit';

    ELSE
        RETURN 'Low Credit';
    END IF;
END;
$$;


-- Test function
SELECT
    customer_id,
    full_name,
    credit_limit,
    fn_credit_category(credit_limit) AS credit_category
FROM customers
ORDER BY credit_limit DESC;


-- =========================================================
-- Q3. Function with customer_id parameter
-- Returns customer name
-- =========================================================

DROP FUNCTION IF EXISTS fn_customer_name(INTEGER);

CREATE FUNCTION fn_customer_name(p_customer_id INTEGER)
RETURNS TEXT
LANGUAGE SQL
AS $$
    SELECT full_name
    FROM customers
    WHERE customer_id = p_customer_id;
$$;


-- Test
SELECT fn_customer_name(4101) AS customer_name;


-- =========================================================
-- Q4. Function returning table
-- Returns customers from selected city
-- =========================================================

DROP FUNCTION IF EXISTS fn_customers_by_city(TEXT);

CREATE FUNCTION fn_customers_by_city(p_city TEXT)
RETURNS TABLE (
    customer_id INTEGER,
    full_name VARCHAR,
    city VARCHAR,
    credit_limit NUMERIC
)
LANGUAGE SQL
AS $$
    SELECT
        c.customer_id,
        c.full_name,
        c.city,
        c.credit_limit
    FROM customers c
    WHERE c.city = p_city
    ORDER BY c.credit_limit DESC;
$$;


-- Test
SELECT *
FROM fn_customers_by_city('Hyderabad');


-- =========================================================
-- Q5. Function with aggregate result
-- Returns average credit limit for selected city
-- =========================================================

DROP FUNCTION IF EXISTS fn_city_avg_credit(TEXT);

CREATE FUNCTION fn_city_avg_credit(p_city TEXT)
RETURNS NUMERIC
LANGUAGE SQL
AS $$
    SELECT ROUND(AVG(credit_limit), 2)
    FROM customers
    WHERE city = p_city;
$$;


-- Test
SELECT
    'Hyderabad' AS city,
    fn_city_avg_credit('Hyderabad') AS avg_credit_limit;


-- =========================================================
-- Q6. Create safe temp table for procedure practice
-- =========================================================

DROP TABLE IF EXISTS temp_procedure_customers;

CREATE TEMP TABLE temp_procedure_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers;


SELECT *
FROM temp_procedure_customers
ORDER BY customer_id;


-- =========================================================
-- Q7. Create stored procedure
-- Adds amount to a customer's credit limit
-- =========================================================

DROP PROCEDURE IF EXISTS sp_increase_credit(INTEGER, NUMERIC);

CREATE PROCEDURE sp_increase_credit(
    p_customer_id INTEGER,
    p_amount NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE temp_procedure_customers
    SET credit_limit = credit_limit + p_amount
    WHERE customer_id = p_customer_id;
END;
$$;


-- =========================================================
-- Q8. CALL stored procedure
-- =========================================================

CALL sp_increase_credit(4101, 2500);


SELECT *
FROM temp_procedure_customers
WHERE customer_id = 4101;


-- =========================================================
-- Q9. Call procedure again for another customer
-- =========================================================

CALL sp_increase_credit(4102, 1500);


SELECT *
FROM temp_procedure_customers
WHERE customer_id IN (4101, 4102)
ORDER BY customer_id;


-- =========================================================
-- Q10. Final Day 29 function + procedure report
-- =========================================================

SELECT
    t.customer_id,
    t.full_name,
    t.city,
    t.credit_limit,

    fn_credit_category(t.credit_limit) AS credit_category,

    fn_credit_ten_percent(t.credit_limit) AS ten_percent_credit

FROM temp_procedure_customers t
ORDER BY t.credit_limit DESC;



-- Reset temp table
DROP TABLE IF EXISTS temp_procedure_customers;

CREATE TEMP TABLE temp_procedure_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers;


CALL sp_increase_credit(4101, 2500);

CALL sp_increase_credit(4102, 1500);


SELECT
    t.customer_id,
    t.full_name,
    t.city,
    t.credit_limit,
    fn_credit_category(t.credit_limit) AS credit_category,
    fn_credit_ten_percent(t.credit_limit) AS ten_percent_credit
FROM temp_procedure_customers t
ORDER BY t.credit_limit DESC;


-- =========================================================
-- QueryForge
-- Day 30 - Triggers & Audit Logging
-- =========================================================


-- =========================================================
-- Q1. Create safe demo customer table
-- =========================================================

DROP TABLE IF EXISTS trigger_audit_log;
DROP TABLE IF EXISTS trigger_demo_customers;

CREATE TABLE trigger_demo_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers;


CREATE TABLE trigger_audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    action_type TEXT NOT NULL,
    customer_id INTEGER,
    old_city VARCHAR(80),
    new_city VARCHAR(80),
    old_credit_limit NUMERIC(12,2),
    new_credit_limit NUMERIC(12,2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


SELECT *
FROM trigger_demo_customers
ORDER BY customer_id;


-- =========================================================
-- Q2. Create trigger function
-- Uses TG_OP to detect INSERT / UPDATE / DELETE
-- =========================================================

DROP FUNCTION IF EXISTS fn_log_customer_changes();

CREATE FUNCTION fn_log_customer_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF TG_OP = 'INSERT' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            new_city,
            new_credit_limit
        )
        VALUES (
            'INSERT',
            NEW.customer_id,
            NEW.city,
            NEW.credit_limit
        );

        RETURN NEW;


    ELSIF TG_OP = 'UPDATE' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            old_city,
            new_city,
            old_credit_limit,
            new_credit_limit
        )
        VALUES (
            'UPDATE',
            NEW.customer_id,
            OLD.city,
            NEW.city,
            OLD.credit_limit,
            NEW.credit_limit
        );

        RETURN NEW;


    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            old_city,
            old_credit_limit
        )
        VALUES (
            'DELETE',
            OLD.customer_id,
            OLD.city,
            OLD.credit_limit
        );

        RETURN OLD;

    END IF;

    RETURN NULL;

END;
$$;


-- =========================================================
-- Q3. Create AFTER trigger
-- =========================================================

DROP TRIGGER IF EXISTS trg_customer_audit
ON trigger_demo_customers;


CREATE TRIGGER trg_customer_audit

AFTER INSERT OR UPDATE OR DELETE
ON trigger_demo_customers

FOR EACH ROW

EXECUTE FUNCTION fn_log_customer_changes();


-- =========================================================
-- Q4. UPDATE test
-- Automatically creates audit record
-- =========================================================

UPDATE trigger_demo_customers
SET credit_limit = credit_limit + 3000
WHERE customer_id = 4101;


SELECT *
FROM trigger_demo_customers
WHERE customer_id = 4101;


SELECT *
FROM trigger_audit_log
ORDER BY audit_id;


-- =========================================================
-- Q5. INSERT test
-- =========================================================

INSERT INTO trigger_demo_customers (
    customer_id,
    full_name,
    city,
    credit_limit
)
VALUES (
    4106,
    'Amit Kumar',
    'Mumbai',
    21000
);


SELECT *
FROM trigger_demo_customers
WHERE customer_id = 4106;


-- =========================================================
-- Q6. DELETE test
-- =========================================================

DELETE FROM trigger_demo_customers
WHERE customer_id = 4105;


SELECT *
FROM trigger_demo_customers
ORDER BY customer_id;


-- =========================================================
-- Q7. Full audit history
-- =========================================================

SELECT
    audit_id,
    action_type,
    customer_id,
    old_city,
    new_city,
    old_credit_limit,
    new_credit_limit,
    changed_at
FROM trigger_audit_log
ORDER BY audit_id;


-- =========================================================
-- Q8. Show only UPDATE history
-- Demonstrates OLD vs NEW values
-- =========================================================

SELECT
    customer_id,
    old_credit_limit,
    new_credit_limit,
    new_credit_limit - old_credit_limit AS credit_change
FROM trigger_audit_log
WHERE action_type = 'UPDATE'
ORDER BY audit_id;


-- =========================================================
-- Q9. Count audit events by type
-- =========================================================

SELECT
    action_type,
    COUNT(*) AS event_count
FROM trigger_audit_log
GROUP BY action_type
ORDER BY action_type;


-- =========================================================
-- Q10. Final Day 30 audit report
-- =========================================================

SELECT
    audit_id,
    action_type,
    customer_id,

    CASE
        WHEN action_type = 'INSERT'
            THEN 'New customer created'

        WHEN action_type = 'UPDATE'
            THEN 'Customer data updated'

        WHEN action_type = 'DELETE'
            THEN 'Customer deleted'

        ELSE 'Unknown action'
    END AS audit_description,

    old_city,
    new_city,
    old_credit_limit,
    new_credit_limit,
    changed_at

FROM trigger_audit_log
ORDER BY audit_id;




DROP TABLE IF EXISTS trigger_audit_log;
DROP TABLE IF EXISTS trigger_demo_customers;

CREATE TABLE trigger_demo_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers;

CREATE TABLE trigger_audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    action_type TEXT NOT NULL,
    customer_id INTEGER,
    old_city VARCHAR(80),
    new_city VARCHAR(80),
    old_credit_limit NUMERIC(12,2),
    new_credit_limit NUMERIC(12,2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);





UPDATE trigger_demo_customers
SET credit_limit = credit_limit + 3000
WHERE customer_id = 4101;

INSERT INTO trigger_demo_customers (
    customer_id,
    full_name,
    city,
    credit_limit
)
VALUES (
    4106,
    'Amit Kumar',
    'Mumbai',
    21000
);

DELETE FROM trigger_demo_customers
WHERE customer_id = 4105;

SELECT
    audit_id,
    action_type,
    customer_id,
    old_city,
    new_city,
    old_credit_limit,
    new_credit_limit,
    changed_at
FROM trigger_audit_log
ORDER BY audit_id;


SELECT
    audit_id,
    action_type,
    customer_id,
    old_city,
    new_city,
    old_credit_limit,
    new_credit_limit,
    changed_at
FROM trigger_audit_log
ORDER BY audit_id;



DROP TABLE IF EXISTS trigger_audit_log;
DROP TABLE IF EXISTS trigger_demo_customers;

CREATE TABLE trigger_demo_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers;

CREATE TABLE trigger_audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    action_type TEXT NOT NULL,
    customer_id INTEGER,
    old_city VARCHAR(80),
    new_city VARCHAR(80),
    old_credit_limit NUMERIC(12,2),
    new_credit_limit NUMERIC(12,2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

UPDATE trigger_demo_customers
SET credit_limit = credit_limit + 3000
WHERE customer_id = 4101;

INSERT INTO trigger_demo_customers (
    customer_id,
    full_name,
    city,
    credit_limit
)
VALUES (
    4106,
    'Amit Kumar',
    'Mumbai',
    21000
);

DELETE FROM trigger_demo_customers
WHERE customer_id = 4105;

SELECT
    audit_id,
    action_type,
    customer_id,
    old_city,	
    new_city,
    old_credit_limit,
    new_credit_limit,
    changed_at
FROM trigger_audit_log
ORDER BY audit_id;


SELECT
    t.customer_id,
    t.full_name,
    t.city,
    t.credit_limit,

    fn_credit_category(t.credit_limit) AS credit_category,

    fn_credit_ten_percent(t.credit_limit) AS ten_percent_credit

FROM temp_procedure_customers t
ORDER BY t.credit_limit DESC;


DROP TABLE IF EXISTS trigger_audit_log;
DROP TABLE IF EXISTS trigger_demo_customers;

CREATE TABLE trigger_demo_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers;

CREATE TABLE trigger_audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    action_type TEXT NOT NULL,
    customer_id INTEGER,
    old_city VARCHAR(80),
    new_city VARCHAR(80),
    old_credit_limit NUMERIC(12,2),
    new_credit_limit NUMERIC(12,2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

UPDATE trigger_demo_customers
SET credit_limit = credit_limit + 3000
WHERE customer_id = 4101;

INSERT INTO trigger_demo_customers (
    customer_id,
    full_name,
    city,
    credit_limit
)
VALUES (
    4106,
    'Amit Kumar',
    'Mumbai',
    21000
);

DELETE FROM trigger_demo_customers
WHERE customer_id = 4105;


SELECT
    audit_id,
    action_type,
    customer_id,
    old_city,
    new_city,
    old_credit_limit,
    new_credit_limit,
    changed_at
FROM trigger_audit_log
ORDER BY audit_id;






DROP FUNCTION IF EXISTS fn_log_customer_changes();

CREATE FUNCTION fn_log_customer_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF TG_OP = 'INSERT' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            new_city,
            new_credit_limit
        )
        VALUES (
            'INSERT',
            NEW.customer_id,
            NEW.city,
            NEW.credit_limit
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            old_city,
            new_city,
            old_credit_limit,
            new_credit_limit
        )
        VALUES (
            'UPDATE',
            NEW.customer_id,
            OLD.city,
            NEW.city,
            OLD.credit_limit,
            NEW.credit_limit
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            old_city,
            old_credit_limit
        )
        VALUES (
            'DELETE',
            OLD.customer_id,
            OLD.city,
            OLD.credit_limit
        );

        RETURN OLD;

    END IF;

    RETURN NULL;
END;
$$;


CREATE TRIGGER trg_customer_audit
AFTER INSERT OR UPDATE OR DELETE
ON trigger_demo_customers
FOR EACH ROW
EXECUTE FUNCTION fn_log_customer_changes();

UPDATE trigger_demo_customers
SET credit_limit = credit_limit + 3000
WHERE customer_id = 4101;

INSERT INTO trigger_demo_customers (
    customer_id,
    full_name,
    city,
    credit_limit
)
VALUES (
    4106,
    'Amit Kumar',
    'Mumbai',
    21000
);

DELETE FROM trigger_demo_customers
WHERE customer_id = 4105;

SELECT
    audit_id,
    action_type,
    customer_id,
    old_city,
    new_city,
    old_credit_limit,
    new_credit_limit,
    changed_at
FROM trigger_audit_log
ORDER BY audit_id;


-- =========================================================
-- CLEAN DAY 30 RESET + FINAL TEST
-- =========================================================

DROP TABLE IF EXISTS trigger_audit_log;
DROP TABLE IF EXISTS trigger_demo_customers;

DROP FUNCTION IF EXISTS fn_log_customer_changes();


-- 1. Fresh demo table
CREATE TABLE trigger_demo_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers;


-- 2. Fresh audit table
CREATE TABLE trigger_audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    action_type TEXT NOT NULL,
    customer_id INTEGER,
    old_city VARCHAR(80),
    new_city VARCHAR(80),
    old_credit_limit NUMERIC(12,2),
    new_credit_limit NUMERIC(12,2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- 3. Trigger function
CREATE FUNCTION fn_log_customer_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF TG_OP = 'INSERT' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            new_city,
            new_credit_limit
        )
        VALUES (
            'INSERT',
            NEW.customer_id,
            NEW.city,
            NEW.credit_limit
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            old_city,
            new_city,
            old_credit_limit,
            new_credit_limit
        )
        VALUES (
            'UPDATE',
            NEW.customer_id,
            OLD.city,
            NEW.city,
            OLD.credit_limit,
            NEW.credit_limit
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            old_city,
            old_credit_limit
        )
        VALUES (
            'DELETE',
            OLD.customer_id,
            OLD.city,
            OLD.credit_limit
        );

        RETURN OLD;

    END IF;

    RETURN NULL;

END;
$$;


-- 4. Attach trigger
CREATE TRIGGER trg_customer_audit
AFTER INSERT OR UPDATE OR DELETE
ON trigger_demo_customers
FOR EACH ROW
EXECUTE FUNCTION fn_log_customer_changes();


-- 5. UPDATE exactly once
UPDATE trigger_demo_customers
SET credit_limit = credit_limit + 3000
WHERE customer_id = 4101;


-- 6. INSERT exactly once
INSERT INTO trigger_demo_customers (
    customer_id,
    full_name,
    city,
    credit_limit
)
VALUES (
    4106,
    'Amit Kumar',
    'Mumbai',
    21000
);


-- 7. DELETE exactly once
DELETE FROM trigger_demo_customers
WHERE customer_id = 4105;


-- 8. Final verification
SELECT
    audit_id,
    action_type,
    customer_id,
    old_city,
    new_city,
    old_credit_limit,
    new_credit_limit,
    changed_at
FROM trigger_audit_log
ORDER BY audit_id;

-- =========================================================
-- CLEAN DAY 30 RESET + FINAL TEST
-- =========================================================

DROP TABLE IF EXISTS trigger_audit_log;
DROP TABLE IF EXISTS trigger_demo_customers;

DROP FUNCTION IF EXISTS fn_log_customer_changes();


-- 1. Fresh demo table
CREATE TABLE trigger_demo_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers;


-- 2. Fresh audit table
CREATE TABLE trigger_audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    action_type TEXT NOT NULL,
    customer_id INTEGER,
    old_city VARCHAR(80),
    new_city VARCHAR(80),
    old_credit_limit NUMERIC(12,2),
    new_credit_limit NUMERIC(12,2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- 3. Trigger function
CREATE FUNCTION fn_log_customer_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF TG_OP = 'INSERT' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            new_city,
            new_credit_limit
        )
        VALUES (
            'INSERT',
            NEW.customer_id,
            NEW.city,
            NEW.credit_limit
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            old_city,
            new_city,
            old_credit_limit,
            new_credit_limit
        )
        VALUES (
            'UPDATE',
            NEW.customer_id,
            OLD.city,
            NEW.city,
            OLD.credit_limit,
            NEW.credit_limit
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            old_city,
            old_credit_limit
        )
        VALUES (
            'DELETE',
            OLD.customer_id,
            OLD.city,
            OLD.credit_limit
        );

        RETURN OLD;

    END IF;

    RETURN NULL;

END;
$$;


-- 4. Attach trigger
CREATE TRIGGER trg_customer_audit
AFTER INSERT OR UPDATE OR DELETE
ON trigger_demo_customers
FOR EACH ROW
EXECUTE FUNCTION fn_log_customer_changes();


-- 5. UPDATE exactly once
UPDATE trigger_demo_customers
SET credit_limit = credit_limit + 3000
WHERE customer_id = 4101;


-- 6. INSERT exactly once
INSERT INTO trigger_demo_customers (
    customer_id,
    full_name,
    city,
    credit_limit
)
VALUES (
    4106,
    'Amit Kumar',
    'Mumbai',
    21000
);


-- 7. DELETE exactly once
DELETE FROM trigger_demo_customers
WHERE customer_id = 4105;


-- 8. Final verification
SELECT
    audit_id,
    action_type,
    customer_id,
    old_city,
    new_city,
    old_credit_limit,
    new_credit_limit,
    changed_at
FROM trigger_audit_log
ORDER BY audit_id;





SELECT current_database(), current_user;










CREATE SCHEMA IF NOT EXISTS staging;

DROP TABLE IF EXISTS staging.customer_upload;

CREATE TABLE staging.customer_upload
(
    source_row_no INTEGER,
    customer_id INTEGER,
    customer_name VARCHAR(100),
    city VARCHAR(80),
    email VARCHAR(150),
    credit_limit NUMERIC(12,2),
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT *
FROM staging.customer_upload;


BEGIN;

INSERT INTO staging.customer_upload
(
    source_row_no,
    customer_id,
    customer_name,
    city,
    email,
    credit_limit
)
VALUES
(1, 99001, 'Transaction Test A', 'Hyderabad', 'testa@example.com', 50000),
(2, 99002, 'Transaction Test B', 'Mumbai', 'testb@example.com', 60000);

SELECT *
FROM staging.customer_upload
ORDER BY customer_id;


ROLLBACK;

SELECT *
FROM staging.customer_upload
ORDER BY customer_id;





BEGIN;

INSERT INTO staging.customer_upload
(
    source_row_no,
    customer_id,
    customer_name,
    city,
    email,
    credit_limit
)
VALUES
(1, 99001, 'Transaction Test A', 'Hyderabad', 'testa@example.com', 50000),
(2, 99002, 'Transaction Test B', 'Mumbai', 'testb@example.com', 60000);

COMMIT;


SELECT
    customer_id,
    customer_name,
    city,
    credit_limit
FROM staging.customer_upload
ORDER BY customer_id;


BEGIN;

INSERT INTO staging.customer_upload
(
    source_row_no,
    customer_id,
    customer_name,
    city,
    email,
    credit_limit
)
VALUES
(3, 99003, 'Savepoint Keep', 'Pune', 'keep@example.com', 70000);

SAVEPOINT keep_first_insert;

INSERT INTO staging.customer_upload
(
    source_row_no,
    customer_id,
    customer_name,
    city,
    email,
    credit_limit
)
VALUES
(4, 99004, 'Savepoint Remove', 'Delhi', 'remove@example.com', 80000);

ROLLBACK TO SAVEPOINT keep_first_insert;

COMMIT;



SELECT
    customer_id,
    customer_name
FROM staging.customer_upload
ORDER BY customer_id;