-- ============================================================
-- QueryForge
-- Day 18 - Common Table Expressions (CTEs)
-- ============================================================


-- ============================================================
-- 1. BASIC CTE
-- ============================================================

WITH active_customers AS (
    SELECT
        customer_id,
        full_name,
        city
    FROM customers
    WHERE is_active = TRUE
)

SELECT *
FROM active_customers
ORDER BY customer_id;


-- ============================================================
-- 2. CTE WITH AGGREGATION
-- ============================================================

WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(*) AS order_count,
        SUM(total_amount) AS total_order_amount
    FROM orders
    GROUP BY customer_id
)

SELECT
    c.customer_id,
    c.full_name,
    COALESCE(co.order_count, 0) AS order_count,
    COALESCE(co.total_order_amount, 0) AS total_order_amount
FROM customers c
LEFT JOIN customer_orders co
    ON c.customer_id = co.customer_id
ORDER BY c.customer_id;


-- ============================================================
-- 3. CTE + FILTER
-- Customers with total order amount > 3000
-- ============================================================

WITH customer_spend AS (
    SELECT
        customer_id,
        SUM(total_amount) AS total_spend
    FROM orders
    GROUP BY customer_id
)

SELECT
    c.customer_id,
    c.full_name,
    cs.total_spend
FROM customers c
INNER JOIN customer_spend cs
    ON c.customer_id = cs.customer_id
WHERE cs.total_spend > 3000
ORDER BY cs.total_spend DESC;


-- ============================================================
-- 4. MULTIPLE CTEs
-- ============================================================

WITH order_summary AS (
    SELECT
        customer_id,
        COUNT(*) AS order_count,
        SUM(total_amount) AS total_spend
    FROM orders
    GROUP BY customer_id
),

customer_details AS (
    SELECT
        customer_id,
        full_name,
        city,
        credit_limit
    FROM customers
)

SELECT
    cd.customer_id,
    cd.full_name,
    cd.city,
    cd.credit_limit,
    COALESCE(os.order_count, 0) AS order_count,
    COALESCE(os.total_spend, 0) AS total_spend
FROM customer_details cd
LEFT JOIN order_summary os
    ON cd.customer_id = os.customer_id
ORDER BY
    total_spend DESC,
    cd.customer_id;


-- ============================================================
-- 5. CTE WITH ORDER ITEMS
-- ============================================================

WITH product_sales AS (
    SELECT
        product_id,
        SUM(quantity) AS total_quantity
    FROM order_items
    GROUP BY product_id
)

SELECT
    p.product_id,
    p.product_name,
    p.unit_price,
    ps.total_quantity
FROM products p
INNER JOIN product_sales ps
    ON p.product_id = ps.product_id
ORDER BY ps.total_quantity DESC;


-- ============================================================
-- 6. CTE WITH CALCULATED SALES VALUE
-- ============================================================

WITH item_sales AS (
    SELECT
        product_id,
        SUM(quantity * unit_price) AS sales_value
    FROM order_items
    GROUP BY product_id
)

SELECT
    p.product_id,
    p.product_name,
    i.sales_value
FROM products p
INNER JOIN item_sales i
    ON p.product_id = i.product_id
ORDER BY i.sales_value DESC;


-- ============================================================
-- 7. FINAL CTE REPORT
-- Customer order summary
-- ============================================================

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