-- ============================================================
-- QueryForge
-- Day 50 - Large Scale Dataset
-- Purpose:
--   Build large tables for performance/index/query testing
--
-- Final Dataset:
--   customers_big  =   100,000 rows
--   orders_big     = 1,000,000 rows
--   payments_big   = 2,000,000 rows
--   Total          = 3,100,000 rows
-- ============================================================


-- ============================================================
-- TASK 1: CREATE SCALE SCHEMA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS scale;


-- ============================================================
-- TASK 2: CREATE CUSTOMERS_BIG
-- ============================================================

DROP TABLE IF EXISTS scale.payments_big;
DROP TABLE IF EXISTS scale.orders_big;
DROP TABLE IF EXISTS scale.customers_big;


CREATE TABLE scale.customers_big (
    customer_id     BIGINT PRIMARY KEY,
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL,
    city            VARCHAR(80),
    credit_limit    NUMERIC(12,2),
    is_active       BOOLEAN,
    created_at      TIMESTAMPTZ
);


-- ============================================================
-- TASK 3: LOAD 100,000 CUSTOMERS
-- ============================================================

INSERT INTO scale.customers_big (
    customer_id,
    full_name,
    email,
    city,
    credit_limit,
    is_active,
    created_at
)
SELECT
    g AS customer_id,

    CASE ((g - 1) % 10)
        WHEN 0 THEN 'Rahul Verma'
        WHEN 1 THEN 'Sneha Verma'
        WHEN 2 THEN 'Arjun Verma'
        WHEN 3 THEN 'Meera Verma'
        WHEN 4 THEN 'Vikram Verma'
        WHEN 5 THEN 'Aisha Verma'
        WHEN 6 THEN 'Rohan Verma'
        WHEN 7 THEN 'Priya Verma'
        WHEN 8 THEN 'Karan Verma'
        ELSE 'Neha Verma'
    END AS full_name,

    'customer' || g || '@queryforge.test' AS email,

    CASE ((g - 1) % 10)
        WHEN 0 THEN 'Hyderabad'
        WHEN 1 THEN 'Bengaluru'
        WHEN 2 THEN 'Pune'
        WHEN 3 THEN 'Chennai'
        WHEN 4 THEN 'Mumbai'
        WHEN 5 THEN 'Delhi'
        WHEN 6 THEN 'Kolkata'
        WHEN 7 THEN 'Jaipur'
        WHEN 8 THEN 'Ahmedabad'
        ELSE 'Kochi'
    END AS city,

    (5000 + (g % 45001))::NUMERIC(12,2)
        AS credit_limit,

    CASE
        WHEN g % 10 = 0 THEN FALSE
        ELSE TRUE
    END AS is_active,

    CURRENT_TIMESTAMP - (g || ' days')::INTERVAL
        AS created_at

FROM generate_series(1, 100000) AS g;


ANALYZE scale.customers_big;


-- ============================================================
-- TASK 4: VALIDATE CUSTOMERS
-- ============================================================

SELECT
    COUNT(*) AS total_customers,

    COUNT(*) FILTER (
        WHERE is_active = TRUE
    ) AS active_customers,

    COUNT(*) FILTER (
        WHERE is_active = FALSE
    ) AS inactive_customers

FROM scale.customers_big;


-- Expected:
-- total_customers    = 100000
-- active_customers   = 90000
-- inactive_customers = 10000


-- First 10 rows

SELECT
    customer_id,
    full_name,
    email,
    city,
    credit_limit,
    is_active,
    created_at
FROM scale.customers_big
ORDER BY customer_id
LIMIT 10;


-- City distribution

SELECT
    city,
    COUNT(*) AS customer_count
FROM scale.customers_big
GROUP BY city
ORDER BY city;


-- Expected:
-- 10 cities
-- 10,000 customers per city


-- Customer table size

SELECT
    pg_size_pretty(
        pg_total_relation_size('scale.customers_big')
    ) AS total_table_size;



-- ============================================================
-- TASK 5: CREATE ORDERS_BIG
-- ============================================================

CREATE TABLE scale.orders_big (
    order_id        BIGINT PRIMARY KEY,
    customer_id     BIGINT NOT NULL,
    order_date      TIMESTAMPTZ,
    order_status    VARCHAR(20),
    order_amount    NUMERIC(12,2)
);


-- ============================================================
-- TASK 6: LOAD 1,000,000 ORDERS
-- ============================================================

INSERT INTO scale.orders_big (
    order_id,
    customer_id,
    order_date,
    order_status,
    order_amount
)
SELECT
    g AS order_id,

    ((g - 1) % 100000) + 1
        AS customer_id,

    CURRENT_TIMESTAMP
        - ((g % 730) || ' days')::INTERVAL
        AS order_date,

    CASE (g % 4)
        WHEN 0 THEN 'COMPLETED'
        WHEN 1 THEN 'PENDING'
        WHEN 2 THEN 'SHIPPED'
        ELSE 'CANCELLED'
    END AS order_status,

    (
        100 + (g % 49901)
    )::NUMERIC(12,2)
        AS order_amount

FROM generate_series(1, 1000000) AS g;


ANALYZE scale.orders_big;


-- ============================================================
-- TASK 7: VALIDATE ORDERS
-- ============================================================

SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT customer_id) AS customers_with_orders,
    MIN(order_id) AS first_order,
    MAX(order_id) AS last_order
FROM scale.orders_big;


-- Expected:
-- total_orders          = 1000000
-- customers_with_orders = 100000
-- first_order           = 1
-- last_order            = 1000000



-- ============================================================
-- TASK 8: CREATE PAYMENTS_BIG
-- ============================================================

CREATE TABLE scale.payments_big (
    payment_id        BIGINT PRIMARY KEY,
    order_id          BIGINT NOT NULL,
    payment_date      TIMESTAMPTZ,
    payment_method    VARCHAR(30),
    payment_status    VARCHAR(20),
    payment_amount    NUMERIC(12,2)
);


-- ============================================================
-- TASK 9: LOAD 2,000,000 PAYMENTS
-- ============================================================

INSERT INTO scale.payments_big (
    payment_id,
    order_id,
    payment_date,
    payment_method,
    payment_status,
    payment_amount
)
SELECT
    g AS payment_id,

    ((g - 1) % 1000000) + 1
        AS order_id,

    CURRENT_TIMESTAMP
        - ((g % 730) || ' days')::INTERVAL
        AS payment_date,

    CASE (g % 4)
        WHEN 0 THEN 'UPI'
        WHEN 1 THEN 'CARD'
        WHEN 2 THEN 'NET_BANKING'
        ELSE 'WALLET'
    END AS payment_method,

    CASE
        WHEN g % 20 = 0 THEN 'FAILED'
        ELSE 'SUCCESS'
    END AS payment_status,

    (
        100 + (g % 49901)
    )::NUMERIC(12,2)
        AS payment_amount

FROM generate_series(1, 2000000) AS g;


ANALYZE scale.payments_big;


-- ============================================================
-- TASK 10: VALIDATE PAYMENTS
-- ============================================================

SELECT
    COUNT(*) AS total_payments,
    COUNT(DISTINCT order_id) AS orders_with_payments,
    MIN(payment_id) AS first_payment,
    MAX(payment_id) AS last_payment
FROM scale.payments_big;


-- Expected:
-- total_payments       = 2000000
-- orders_with_payments = 1000000
-- first_payment        = 1
-- last_payment         = 2000000



-- ============================================================
-- TASK 11: FINAL ROW COUNT VALIDATION
-- ============================================================

SELECT
    (SELECT COUNT(*)
     FROM scale.customers_big) AS customers,

    (SELECT COUNT(*)
     FROM scale.orders_big) AS orders,

    (SELECT COUNT(*)
     FROM scale.payments_big) AS payments,

    (
        (SELECT COUNT(*) FROM scale.customers_big)
        +
        (SELECT COUNT(*) FROM scale.orders_big)
        +
        (SELECT COUNT(*) FROM scale.payments_big)
    ) AS total_rows;


-- Expected:
-- customers = 100000
-- orders    = 1000000
-- payments  = 2000000
-- total     = 3100000



-- ============================================================
-- TASK 12: TABLE SIZE VALIDATION
-- ============================================================

SELECT
    pg_size_pretty(
        pg_total_relation_size('scale.customers_big')
    ) AS customers_size,

    pg_size_pretty(
        pg_total_relation_size('scale.orders_big')
    ) AS orders_size,

    pg_size_pretty(
        pg_total_relation_size('scale.payments_big')
    ) AS payments_size;


-- Current observed approximate sizes:
-- customers_big ≈ 12 MB
-- orders_big    ≈ 92 MB
-- payments_big  ≈ 192 MB


-- ============================================================
-- DAY 50 COMPLETE
--
-- Dataset:
--   Customers :   100,000
--   Orders    : 1,000,000
--   Payments  : 2,000,000
--   TOTAL     : 3,100,000
--
-- This dataset will be used from Day 51 onward for
-- query performance, EXPLAIN ANALYZE, indexing and optimization.
-- ============================================================