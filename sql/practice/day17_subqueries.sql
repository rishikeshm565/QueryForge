-- ============================================================
-- QueryForge
-- Day 17 - Subqueries
-- ============================================================


-- ============================================================
-- 1. SCALAR SUBQUERY
-- Customers above average credit limit
-- ============================================================

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


-- ============================================================
-- 2. SUBQUERY WITH =
-- Customer having maximum credit limit
-- ============================================================

SELECT
    customer_id,
    full_name,
    credit_limit
FROM customers
WHERE credit_limit = (
    SELECT MAX(credit_limit)
    FROM customers
);


-- ============================================================
-- 3. MULTI-ROW SUBQUERY USING IN
-- Customers who placed orders
-- ============================================================

SELECT
    customer_id,
    full_name
FROM customers
WHERE customer_id IN (
    SELECT customer_id
    FROM orders
)
ORDER BY customer_id;


-- ============================================================
-- 4. NOT IN SUBQUERY
-- Customers without orders
-- ============================================================

SELECT
    customer_id,
    full_name
FROM customers
WHERE customer_id NOT IN (
    SELECT customer_id
    FROM orders
)
ORDER BY customer_id;


-- ============================================================
-- 5. SUBQUERY INSIDE SELECT
-- Order count per customer
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    (
        SELECT COUNT(*)
        FROM orders o
        WHERE o.customer_id = c.customer_id
    ) AS order_count
FROM customers c
ORDER BY c.customer_id;


-- ============================================================
-- 6. EXISTS
-- Customers having at least one order
-- ============================================================

SELECT
    c.customer_id,
    c.full_name
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
)
ORDER BY c.customer_id;


-- ============================================================
-- 7. NOT EXISTS
-- Customers without orders
-- ============================================================

SELECT
    c.customer_id,
    c.full_name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.customer_id
)
ORDER BY c.customer_id;


-- ============================================================
-- 8. CORRELATED SUBQUERY
-- Orders above customer's own average order value
-- ============================================================

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


-- ============================================================
-- 9. NESTED SUBQUERY
-- Customer(s) with highest order total
-- ============================================================

SELECT
    customer_id,
    full_name
FROM customers
WHERE customer_id IN (
    SELECT customer_id
    FROM orders
    WHERE total_amount = (
        SELECT MAX(total_amount)
        FROM orders
    )
);


-- ============================================================
-- 10. FINAL SUBQUERY PRACTICE
-- Customer + order count + highest order value
-- ============================================================

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