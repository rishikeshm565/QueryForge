-- ============================================================
-- QueryForge
-- Day 20 - CASE WHEN / Conditional SQL Logic
-- ============================================================


-- ============================================================
-- 1. CREDIT LIMIT SEGMENT
-- ============================================================

SELECT
    customer_id,
    full_name,
    credit_limit,

    CASE
        WHEN credit_limit >= 23000 THEN 'High'
        WHEN credit_limit >= 18000 THEN 'Medium'
        ELSE 'Low'
    END AS credit_segment

FROM customers
ORDER BY customer_id;


-- ============================================================
-- 2. ACTIVE STATUS LABEL
-- ============================================================

SELECT
    customer_id,
    full_name,
    is_active,

    CASE
        WHEN is_active = TRUE THEN 'Active Customer'
        ELSE 'Inactive Customer'
    END AS customer_status

FROM customers
ORDER BY customer_id;


-- ============================================================
-- 3. ORDER VALUE CATEGORY
-- ============================================================

SELECT
    order_id,
    customer_id,
    total_amount,

    CASE
        WHEN total_amount >= 3500 THEN 'High Value Order'
        WHEN total_amount >= 2800 THEN 'Medium Value Order'
        ELSE 'Low Value Order'
    END AS order_category

FROM orders
ORDER BY total_amount DESC;


-- ============================================================
-- 4. CASE WITH NULL / LEFT JOIN
-- Customers with and without orders
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    o.order_id,

    CASE
        WHEN o.order_id IS NULL THEN 'No Order'
        ELSE 'Has Order'
    END AS order_status

FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id

ORDER BY
    c.customer_id,
    o.order_id;


-- ============================================================
-- 5. CONDITIONAL AGGREGATION
-- ============================================================

SELECT
    COUNT(*) AS total_customers,

    SUM(
        CASE
            WHEN is_active = TRUE THEN 1
            ELSE 0
        END
    ) AS active_customers,

    SUM(
        CASE
            WHEN is_active = FALSE THEN 1
            ELSE 0
        END
    ) AS inactive_customers

FROM customers;


-- ============================================================
-- 6. CUSTOMER ORDER ACTIVITY CATEGORY
-- ============================================================

WITH order_counts AS (
    SELECT
        customer_id,
        COUNT(*) AS order_count
    FROM orders
    GROUP BY customer_id
)

SELECT
    c.customer_id,
    c.full_name,
    COALESCE(oc.order_count, 0) AS order_count,

    CASE
        WHEN COALESCE(oc.order_count, 0) >= 2
            THEN 'Repeat Customer'

        WHEN COALESCE(oc.order_count, 0) = 1
            THEN 'Single Order Customer'

        ELSE 'No Order Customer'
    END AS activity_segment

FROM customers c
LEFT JOIN order_counts oc
    ON c.customer_id = oc.customer_id

ORDER BY
    order_count DESC,
    c.customer_id;


-- ============================================================
-- 7. FINAL CUSTOMER SEGMENT REPORT
-- ============================================================

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