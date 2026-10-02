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