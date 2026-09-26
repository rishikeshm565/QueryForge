-- Day 4 Relationship Practice

-- Parent customer
INSERT INTO customers (
    customer_id,
    full_name,
    email
)
VALUES (
    2001,
    'Day 4 Customer',
    'day4.customer@queryforge.dev'
);


-- 1:1 profile
INSERT INTO customer_profiles (
    customer_id,
    address,
    preferred_language,
    loyalty_level
)
VALUES (
    2001,
    'Hyderabad',
    'English',
    'Gold'
);


-- 1:M orders
INSERT INTO orders (
    order_id,
    customer_id,
    order_date,
    order_status,
    total_amount
)
VALUES
(
    5001,
    2001,
    CURRENT_DATE,
    'PLACED',
    2500.00
),
(
    5002,
    2001,
    CURRENT_DATE,
    'PLACED',
    1500.00
);


-- Products
INSERT INTO products (
    product_id,
    product_name,
    unit_price
)
VALUES
(
    301,
    'Mechanical Keyboard',
    2000.00
),
(
    302,
    'Wireless Mouse',
    500.00
);


-- M:M bridge data
INSERT INTO order_items (
    order_id,
    product_id,
    quantity,
    unit_price
)
VALUES
(
    5001,
    301,
    1,
    2000.00
),
(
    5001,
    302,
    1,
    500.00
),
(
    5002,
    302,
    3,
    500.00
);

SELECT * FROM customers
WHERE customer_id = 2001;

SELECT * FROM customer_profiles
WHERE customer_id = 2001;

SELECT * FROM orders
WHERE customer_id = 2001;

SELECT * FROM order_items;

INSERT INTO customer_profiles (
    customer_id,
    address
)
VALUES (
    2001,
    'Mumbai'
);


INSERT INTO orders (
    order_id,
    customer_id,
    order_date,
    order_status,
    total_amount
)
VALUES (
    5003,
    9999,
    CURRENT_DATE,
    'PLACED',
    1000.00
);

DELETE FROM order_items;

DELETE FROM orders
WHERE customer_id = 2001;

DELETE FROM customer_profiles
WHERE customer_id = 2001;



DELETE FROM products
WHERE product_id IN (301, 302);

DELETE FROM customers
WHERE customer_id = 2001;
