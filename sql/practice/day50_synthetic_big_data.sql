-- ============================================================
-- QueryForge / DataVault 360
-- Day 50 - Large Synthetic Dataset
-- Scale Testing Dataset
-- ============================================================


-- ------------------------------------------------------------
-- TASK 1: Create dedicated scale schema
-- ------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS scale;


-- ------------------------------------------------------------
-- TASK 2: Recreate synthetic customers table
-- ------------------------------------------------------------

DROP TABLE IF EXISTS scale.customers_big CASCADE;

CREATE TABLE scale.customers_big (
    customer_id     BIGINT PRIMARY KEY,
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL,
    city            VARCHAR(80),
    credit_limit    NUMERIC(12,2),
    is_active       BOOLEAN NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL
);


-- ------------------------------------------------------------
-- TASK 3: Generate 100,000 synthetic customers
-- ------------------------------------------------------------

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

    first_names[((g - 1) % 10 + 1)::int]
        || ' ' ||
    last_names[(((g - 1) / 10) % 10 + 1)::int]
        AS full_name,

    'customer'
        || g
        || '@queryforge.test'
        AS email,

    cities[((g - 1) % 10 + 1)::int]
        AS city,

    (
        5000
        + (g % 95001)
    )::NUMERIC(12,2)
        AS credit_limit,

    CASE
        WHEN g % 10 = 0 THEN FALSE
        ELSE TRUE
    END AS is_active,

    CURRENT_TIMESTAMP
        - make_interval(
            days => (g % 1825)::int
        )
        AS created_at

FROM generate_series(1, 100000) AS g

CROSS JOIN (
    SELECT
        ARRAY[
            'Rahul',
            'Sneha',
            'Arjun',
            'Meera',
            'Vikram',
            'Aisha',
            'Rohan',
            'Priya',
            'Karan',
            'Neha'
        ] AS first_names,

        ARRAY[
            'Verma',
            'Rao',
            'Singh',
            'Reddy',
            'Shah',
            'Khan',
            'Patel',
            'Iyer',
            'Mehta',
            'Nair'
        ] AS last_names,

        ARRAY[
            'Hyderabad',
            'Bengaluru',
            'Pune',
            'Chennai',
            'Mumbai',
            'Delhi',
            'Kolkata',
            'Jaipur',
            'Ahmedabad',
            'Kochi'
        ] AS cities
) AS synthetic_data;


-- ------------------------------------------------------------
-- TASK 4: Refresh PostgreSQL statistics
-- ------------------------------------------------------------

ANALYZE scale.customers_big;




-- ============================================================
-- TASK 5: CREATE 1,000,000 SYNTHETIC ORDERS
-- ============================================================

DROP TABLE IF EXISTS scale.payments_big CASCADE;
DROP TABLE IF EXISTS scale.orders_big CASCADE;


CREATE TABLE scale.orders_big (
    order_id        BIGINT PRIMARY KEY,
    customer_id     BIGINT NOT NULL,
    order_date      TIMESTAMPTZ NOT NULL,
    order_status    VARCHAR(20) NOT NULL,
    order_amount    NUMERIC(12,2) NOT NULL
);


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
        - make_interval(
            days => (g % 730)::int
        )
        AS order_date,

    CASE
        WHEN g % 20 < 14 THEN 'COMPLETED'
        WHEN g % 20 < 17 THEN 'PENDING'
        WHEN g % 20 < 19 THEN 'CANCELLED'
        ELSE 'REFUNDED'
    END AS order_status,

    (
        100
        + (g % 49901)
    )::NUMERIC(12,2)
        AS order_amount

FROM generate_series(1, 1000000) AS g;


ANALYZE scale.orders_big;