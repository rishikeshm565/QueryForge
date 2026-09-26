-- QueryForge
-- Version: V0.1
-- Day 4: Relationships and ERD

-- =====================================================
-- 1:1 Relationship
-- customers <-> customer_profiles
-- =====================================================

CREATE TABLE customer_profiles (
    customer_id INTEGER PRIMARY KEY,
    address TEXT,
    preferred_language VARCHAR(50),
    loyalty_level VARCHAR(30),

    CONSTRAINT fk_customer_profiles_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);


-- =====================================================
-- 1:M Relationship
-- customers -> orders
-- =====================================================

CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date DATE NOT NULL,
    order_status VARCHAR(30) NOT NULL,
    total_amount NUMERIC(12,2) CHECK (total_amount >= 0),

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);


-- =====================================================
-- Products master table
-- =====================================================

CREATE TABLE products (
    product_id INTEGER PRIMARY KEY,
    product_name VARCHAR(120) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL
        CHECK (unit_price >= 0),
    is_active BOOLEAN DEFAULT TRUE
);


-- =====================================================
-- M:M Relationship
-- orders <-> products
-- through order_items
-- =====================================================

CREATE TABLE order_items (
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL
        CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL
        CHECK (unit_price >= 0),

    CONSTRAINT pk_order_items
        PRIMARY KEY (order_id, product_id),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id),

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
);