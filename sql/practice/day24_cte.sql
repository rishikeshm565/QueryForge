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