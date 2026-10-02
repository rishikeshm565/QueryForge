-- ============================================================
-- QueryForge
-- Day 15 - SQL JOINS
-- ============================================================


-- ============================================================
-- 1. INNER JOIN
-- Customers who have orders
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    o.order_id
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
ORDER BY
    c.customer_id,
    o.order_id;


-- ============================================================
-- 2. LEFT JOIN
-- Show all customers even if they have no orders
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    o.order_id
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
ORDER BY
    c.customer_id,
    o.order_id;


-- ============================================================
-- 3. FIND CUSTOMERS WITH NO ORDERS
-- ============================================================

SELECT
    c.customer_id,
    c.full_name
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL
ORDER BY c.customer_id;


-- ============================================================
-- 4. CUSTOMER + PROFILE
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    cp.address,
    cp.preferred_language,
    cp.loyalty_level
FROM customers c
LEFT JOIN customer_profiles cp
    ON c.customer_id = cp.customer_id
ORDER BY c.customer_id;


-- ============================================================
-- 5. ORDERS + ORDER ITEMS
-- ============================================================

SELECT
    o.order_id,
    o.customer_id,
    oi.product_id
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
ORDER BY
    o.order_id,
    oi.product_id;


-- ============================================================
-- 6. ORDER ITEMS + PRODUCTS
-- ============================================================

SELECT
    oi.order_id,
    oi.product_id,
    p.*
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
ORDER BY
    oi.order_id,
    oi.product_id;


-- ============================================================
-- 7. THREE-TABLE JOIN
-- CUSTOMER → ORDER → ORDER ITEMS
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    o.order_id,
    oi.product_id
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
ORDER BY
    c.customer_id,
    o.order_id,
    oi.product_id;


-- ============================================================
-- 8. FOUR-TABLE JOIN
-- CUSTOMER → ORDER → ORDER ITEM → PRODUCT
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    o.order_id,
    oi.product_id,
    p.*
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
INNER JOIN products p
    ON oi.product_id = p.product_id
ORDER BY
    c.customer_id,
    o.order_id,
    oi.product_id;


-- ============================================================
-- 9. ORDER COUNT PER CUSTOMER
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    COUNT(o.order_id) AS order_count
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.full_name
ORDER BY
    order_count DESC,
    c.customer_id;


-- ============================================================
-- 10. CUSTOMER + PROFILE + ORDER COUNT
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    cp.loyalty_level,
    COUNT(o.order_id) AS order_count
FROM customers c
LEFT JOIN customer_profiles cp
    ON c.customer_id = cp.customer_id
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.full_name,
    cp.loyalty_level
ORDER BY
    order_count DESC,
    c.customer_id;


-- ============================================================
-- 11. FINAL JOIN VIEW
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    o.order_id,
    oi.product_id,
    p.*
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
LEFT JOIN products p
    ON oi.product_id = p.product_id
ORDER BY
    c.customer_id,
    o.order_id,
    oi.product_id;