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