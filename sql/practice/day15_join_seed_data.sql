-- ============================================================
-- QueryForge
-- Day 15 - Sample Data for JOIN Practice
-- ============================================================


-- ============================================================
-- 1. PRODUCTS
-- ============================================================

INSERT INTO products (
    product_id,
    product_name,
    unit_price,
    is_active
)
VALUES
    (5101, 'Laptop Stand',         1200.00, TRUE),
    (5102, 'Wireless Mouse',        800.00, TRUE),
    (5103, 'Mechanical Keyboard',  2500.00, TRUE),
    (5104, 'USB-C Hub',            1500.00, TRUE),
    (5105, 'Headset',              1800.00, TRUE)
ON CONFLICT (product_id) DO NOTHING;


-- ============================================================
-- 2. ORDERS
-- ============================================================

INSERT INTO orders (
    order_id,
    customer_id,
    order_date,
    order_status,
    total_amount
)
VALUES
    (6101, 4101, '2026-09-01', 'Completed', 2800.00),
    (6102, 4102, '2026-09-05', 'Completed', 2500.00),
    (6103, 4101, '2026-09-10', 'Completed', 3300.00),
    (6104, 4103, '2026-09-15', 'Completed', 3800.00),
    (6105, 4105, '2026-09-20', 'Completed', 3600.00)
ON CONFLICT (order_id) DO NOTHING;


-- ============================================================
-- 3. ORDER ITEMS
-- ============================================================

INSERT INTO order_items (
    order_id,
    product_id,
    quantity,
    unit_price
)
VALUES
    (6101, 5101, 1, 1200.00),
    (6101, 5102, 2,  800.00),

    (6102, 5103, 1, 2500.00),

    (6103, 5104, 1, 1500.00),
    (6103, 5105, 1, 1800.00),

    (6104, 5102, 1,  800.00),
    (6104, 5104, 2, 1500.00),

    (6105, 5105, 2, 1800.00)
ON CONFLICT (order_id, product_id) DO NOTHING;


-- ============================================================
-- 4. VERIFY COUNTS
-- ============================================================

SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM customers

UNION ALL

SELECT 'orders', COUNT(*)
FROM orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM order_items

UNION ALL

SELECT 'products', COUNT(*)
FROM products;