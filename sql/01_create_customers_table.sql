-- QueryForge
-- Version: V0.1
-- Day 2: Create initial customers table

CREATE TABLE customers (
    customer_id INTEGER,
    full_name VARCHAR(100),
    email VARCHAR(150),
    phone VARCHAR(20),
    city VARCHAR(80),
    credit_limit NUMERIC(12,2),
    is_active BOOLEAN,
    date_of_birth DATE,
    created_at TIMESTAMP,
    notes TEXT
);