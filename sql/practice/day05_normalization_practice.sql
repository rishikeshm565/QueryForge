-- QueryForge
-- Day 5: Normalization Practice

-- =============================================
-- STEP 1: Unnormalized Excel-style data
-- =============================================

CREATE TABLE normalization_unf (
    order_id INTEGER,
    customer_id INTEGER,
    customer_name VARCHAR(100),
    customer_email VARCHAR(150),
    customer_city VARCHAR(80),
    order_date DATE,
    products TEXT
);

INSERT INTO normalization_unf (
    order_id,
    customer_id,
    customer_name,
    customer_email,
    customer_city,
    order_date,
    products
)
VALUES
(
    9001,
    3001,
    'Rahul Sharma',
    'rahul.normalization@queryforge.dev',
    'Hyderabad',
    '2026-09-26',
    '401-Mechanical Keyboard-1-2000; 402-Wireless Mouse-1-500'
),
(
    9002,
    3001,
    'Rahul Sharma',
    'rahul.normalization@queryforge.dev',
    'Hyderabad',
    '2026-09-26',
    '402-Wireless Mouse-2-500'
),
(
    9003,
    3002,
    'Priya Rao',
    'priya.normalization@queryforge.dev',
    'Bengaluru',
    '2026-09-26',
    '403-USB Hub-1-1500'
);

SELECT * FROM normalization_unf;


CREATE TABLE normalization_1nf (
    order_id INTEGER,
    customer_id INTEGER,
    customer_name VARCHAR(100),
    customer_email VARCHAR(150),
    customer_city VARCHAR(80),
    order_date DATE,
    order_status VARCHAR(30),

    product_id INTEGER,
    product_name VARCHAR(120),
    quantity INTEGER,
    unit_price NUMERIC(12,2)
);

INSERT INTO normalization_1nf (
    order_id,
    customer_id,
    customer_name,
    customer_email,
    customer_city,
    order_date,
    order_status,
    product_id,
    product_name,
    quantity,
    unit_price
)
VALUES
(
    9001,
    3001,
    'Rahul Sharma',
    'rahul.normalization@queryforge.dev',
    'Hyderabad',
    '2026-09-26',
    'PLACED',
    401,
    'Mechanical Keyboard',
    1,
    2000.00
),
(
    9001,
    3001,
    'Rahul Sharma',
    'rahul.normalization@queryforge.dev',
    'Hyderabad',
    '2026-09-26',
    'PLACED',
    402,
    'Wireless Mouse',
    1,
    500.00
),
(
    9002,
    3001,
    'Rahul Sharma',
    'rahul.normalization@queryforge.dev',
    'Hyderabad',
    '2026-09-26',
    'PLACED',
    402,
    'Wireless Mouse',
    2,
    500.00
),
(
    9003,
    3002,
    'Priya Rao',
    'priya.normalization@queryforge.dev',
    'Bengaluru',
    '2026-09-26',
    'PLACED',
    403,
    'USB Hub',
    1,
    1500.00
);

SELECT * FROM normalization_1nf;

SELECT
    order_id,
    customer_id,
    customer_name,
    customer_email,
    product_id,
    product_name
FROM normalization_1nf;

INSERT INTO customers (
    customer_id,
    full_name,
    email,
    city
)
VALUES
(
    3001,
    'Rahul Sharma',
    'rahul.normalization@queryforge.dev',
    'Hyderabad'
),
(
    3002,
    'Priya Rao',
    'priya.normalization@queryforge.dev',
    'Bengaluru'
);

INSERT INTO products (
    product_id,
    product_name,
    unit_price
)
VALUES
(
    401,
    'Mechanical Keyboard',
    2000.00
),
(
    402,
    'Wireless Mouse',
    500.00
),
(
    403,
    'USB Hub',
    1500.00
);



INSERT INTO orders (
    order_id,
    customer_id,
    order_date,
    order_status,
    total_amount
)
VALUES
(
    9001,
    3001,
    '2026-09-26',
    'PLACED',
    2500.00
),
(
    9002,
    3001,
    '2026-09-26',
    'PLACED',
    1000.00
),
(
    9003,
    3002,
    '2026-09-26',
    'PLACED',
    1500.00
);

INSERT INTO order_items (
    order_id,
    product_id,
    quantity,
    unit_price
)
VALUES
(
    9001,
    401,
    1,
    2000.00
),
(
    9001,
    402,
    1,
    500.00
),
(
    9002,
    402,
    2,
    500.00
),
(
    9003,
    403,
    1,
    1500.00
);

SELECT * FROM customers
WHERE customer_id IN (3001, 3002);

SELECT * FROM orders
WHERE order_id IN (9001, 9002, 9003);

SELECT * FROM order_items
WHERE order_id IN (9001, 9002, 9003);

INSERT INTO customers (
    customer_id,
    full_name,
    email,
    city
)
VALUES (
    3003,
    'Rahul Duplicate',
    'rahul.normalization@queryforge.dev',
    'Mumbai'
);
DELETE FROM order_items
WHERE order_id IN (9001, 9002, 9003);

DELETE FROM orders
WHERE order_id IN (9001, 9002, 9003);

DELETE FROM products
WHERE product_id IN (401, 402, 403);

DELETE FROM customers
WHERE customer_id IN (3001, 3002);

DROP TABLE normalization_1nf;
DROP TABLE normalization_unf;


