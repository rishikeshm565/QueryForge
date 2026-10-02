-- ============================================================
-- QueryForge
-- Day 19 - Window Functions
-- ============================================================


-- ============================================================
-- 1. ROW_NUMBER
-- Rank all orders by total amount
-- ============================================================

SELECT
    order_id,
    customer_id,
    total_amount,
    ROW_NUMBER() OVER (
        ORDER BY total_amount DESC
    ) AS row_number
FROM orders
ORDER BY row_number;


-- ============================================================
-- 2. RANK AND DENSE_RANK
-- ============================================================

SELECT
    order_id,
    customer_id,
    total_amount,

    RANK() OVER (
        ORDER BY total_amount DESC
    ) AS amount_rank,

    DENSE_RANK() OVER (
        ORDER BY total_amount DESC
    ) AS dense_amount_rank

FROM orders
ORDER BY total_amount DESC;


-- ============================================================
-- 3. PARTITION BY CUSTOMER
-- Number orders separately for each customer
-- ============================================================

SELECT
    customer_id,
    order_id,
    order_date,
    total_amount,

    ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS customer_order_number

FROM orders
ORDER BY
    customer_id,
    order_date;


-- ============================================================
-- 4. RUNNING TOTAL BY CUSTOMER
-- ============================================================

SELECT
    customer_id,
    order_id,
    order_date,
    total_amount,

    SUM(total_amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING
        AND CURRENT ROW
    ) AS running_total

FROM orders
ORDER BY
    customer_id,
    order_date;


-- ============================================================
-- 5. PREVIOUS ORDER USING LAG
-- ============================================================

SELECT
    customer_id,
    order_id,
    order_date,
    total_amount,

    LAG(total_amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS previous_order_amount

FROM orders
ORDER BY
    customer_id,
    order_date;


-- ============================================================
-- 6. DIFFERENCE FROM PREVIOUS ORDER
-- ============================================================

SELECT
    customer_id,
    order_id,
    order_date,
    total_amount,

    LAG(total_amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS previous_order_amount,

    total_amount
    -
    LAG(total_amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_date
    ) AS difference_from_previous

FROM orders
ORDER BY
    customer_id,
    order_date;


-- ============================================================
-- 7. CUSTOMER-WISE ORDER RANK
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    o.order_id,
    o.total_amount,

    RANK() OVER (
        PARTITION BY c.customer_id
        ORDER BY o.total_amount DESC
    ) AS customer_order_rank

FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id

ORDER BY
    c.customer_id,
    customer_order_rank;


-- ============================================================
-- 8. FINAL WINDOW FUNCTION REPORT
-- ============================================================

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