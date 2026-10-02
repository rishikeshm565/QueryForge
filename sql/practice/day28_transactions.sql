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