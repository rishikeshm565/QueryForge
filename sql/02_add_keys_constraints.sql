-- QueryForge
-- Version: V0.1
-- Day 3: Keys and Constraints

-- =====================================================
-- Add constraints to customers table
-- =====================================================

ALTER TABLE customers
    ADD CONSTRAINT pk_customers
        PRIMARY KEY (customer_id);

ALTER TABLE customers
    ALTER COLUMN full_name SET NOT NULL;

ALTER TABLE customers
    ALTER COLUMN email SET NOT NULL;

ALTER TABLE customers
    ADD CONSTRAINT uq_customers_email
        UNIQUE (email);

ALTER TABLE customers
    ALTER COLUMN credit_limit SET DEFAULT 0.00;

ALTER TABLE customers
    ALTER COLUMN is_active SET DEFAULT TRUE;

ALTER TABLE customers
    ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE customers
    ADD CONSTRAINT chk_customers_credit_limit
        CHECK (credit_limit >= 0);


-- =====================================================
-- Create child table for Foreign Key demonstration
-- =====================================================

CREATE TABLE customer_notes (
    note_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    note_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_customer_notes_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);