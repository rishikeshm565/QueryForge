-- =========================================================
-- QueryForge
-- Day 21 - Date & Time Functions
-- =========================================================


-- Q1. Current date and current timestamp
SELECT
    CURRENT_DATE AS today,
    CURRENT_TIMESTAMP AS current_time;


-- Q2. Customer date of birth + calculated age
SELECT
    customer_id,
    full_name,
    date_of_birth,
    AGE(CURRENT_DATE, date_of_birth) AS customer_age
FROM customers
ORDER BY customer_id;


-- Q3. Extract birth year and birth month
SELECT
    customer_id,
    full_name,
    date_of_birth,
    EXTRACT(YEAR FROM date_of_birth) AS birth_year,
    EXTRACT(MONTH FROM date_of_birth) AS birth_month
FROM customers
ORDER BY customer_id;


-- Q4. Customer account creation date details
SELECT
    customer_id,
    full_name,
    created_at,
    created_at::DATE AS created_date,
    EXTRACT(YEAR FROM created_at) AS created_year,
    EXTRACT(MONTH FROM created_at) AS created_month
FROM customers
ORDER BY customer_id;


-- Q5. How long ago customer record was created
SELECT
    customer_id,
    full_name,
    created_at,
    AGE(CURRENT_TIMESTAMP, created_at) AS customer_since
FROM customers
ORDER BY customer_id;


-- Q6. Customers created within the last 1 year
SELECT
    customer_id,
    full_name,
    created_at
FROM customers
WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '1 year'
ORDER BY created_at DESC;


-- Q7. Group customers by account creation month
SELECT
    DATE_TRUNC('month', created_at) AS creation_month,
    COUNT(*) AS total_customers
FROM customers
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY creation_month;


-- Q8. Format date for reporting
SELECT
    customer_id,
    full_name,
    TO_CHAR(date_of_birth, 'DD-Mon-YYYY') AS formatted_dob,
    TO_CHAR(created_at, 'DD-Mon-YYYY HH24:MI') AS formatted_created_at
FROM customers
ORDER BY customer_id;


-- Q9. Customer age in completed years
SELECT
    customer_id,
    full_name,
    date_of_birth,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) AS age_years
FROM customers
ORDER BY customer_id;


-- Q10. Final Day 21 customer date profile
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