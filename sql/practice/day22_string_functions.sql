-- =========================================================
-- QueryForge
-- Day 22 - String Functions & Text Cleaning
-- =========================================================


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