-- =========================================================
-- QueryForge
-- Day 30 - Triggers & Audit Logging
-- =========================================================


-- =========================================================
-- Q1. Create safe demo customer table
-- =========================================================

DROP TABLE IF EXISTS trigger_audit_log;
DROP TABLE IF EXISTS trigger_demo_customers;

CREATE TABLE trigger_demo_customers AS
SELECT
    customer_id,
    full_name,
    city,
    credit_limit
FROM customers;


CREATE TABLE trigger_audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    action_type TEXT NOT NULL,
    customer_id INTEGER,
    old_city VARCHAR(80),
    new_city VARCHAR(80),
    old_credit_limit NUMERIC(12,2),
    new_credit_limit NUMERIC(12,2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


SELECT *
FROM trigger_demo_customers
ORDER BY customer_id;


-- =========================================================
-- Q2. Create trigger function
-- Uses TG_OP to detect INSERT / UPDATE / DELETE
-- =========================================================

DROP FUNCTION IF EXISTS fn_log_customer_changes();

CREATE FUNCTION fn_log_customer_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF TG_OP = 'INSERT' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            new_city,
            new_credit_limit
        )
        VALUES (
            'INSERT',
            NEW.customer_id,
            NEW.city,
            NEW.credit_limit
        );

        RETURN NEW;


    ELSIF TG_OP = 'UPDATE' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            old_city,
            new_city,
            old_credit_limit,
            new_credit_limit
        )
        VALUES (
            'UPDATE',
            NEW.customer_id,
            OLD.city,
            NEW.city,
            OLD.credit_limit,
            NEW.credit_limit
        );

        RETURN NEW;


    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO trigger_audit_log (
            action_type,
            customer_id,
            old_city,
            old_credit_limit
        )
        VALUES (
            'DELETE',
            OLD.customer_id,
            OLD.city,
            OLD.credit_limit
        );

        RETURN OLD;

    END IF;

    RETURN NULL;

END;
$$;


-- =========================================================
-- Q3. Create AFTER trigger
-- =========================================================

DROP TRIGGER IF EXISTS trg_customer_audit
ON trigger_demo_customers;


CREATE TRIGGER trg_customer_audit

AFTER INSERT OR UPDATE OR DELETE
ON trigger_demo_customers

FOR EACH ROW

EXECUTE FUNCTION fn_log_customer_changes();


-- =========================================================
-- Q4. UPDATE test
-- Automatically creates audit record
-- =========================================================

UPDATE trigger_demo_customers
SET credit_limit = credit_limit + 3000
WHERE customer_id = 4101;


SELECT *
FROM trigger_demo_customers
WHERE customer_id = 4101;


SELECT *
FROM trigger_audit_log
ORDER BY audit_id;


-- =========================================================
-- Q5. INSERT test
-- =========================================================

INSERT INTO trigger_demo_customers (
    customer_id,
    full_name,
    city,
    credit_limit
)
VALUES (
    4106,
    'Amit Kumar',
    'Mumbai',
    21000
);


SELECT *
FROM trigger_demo_customers
WHERE customer_id = 4106;


-- =========================================================
-- Q6. DELETE test
-- =========================================================

DELETE FROM trigger_demo_customers
WHERE customer_id = 4105;


SELECT *
FROM trigger_demo_customers
ORDER BY customer_id;


-- =========================================================
-- Q7. Full audit history
-- =========================================================

SELECT
    audit_id,
    action_type,
    customer_id,
    old_city,
    new_city,
    old_credit_limit,
    new_credit_limit,
    changed_at
FROM trigger_audit_log
ORDER BY audit_id;


-- =========================================================
-- Q8. Show only UPDATE history
-- Demonstrates OLD vs NEW values
-- =========================================================

SELECT
    customer_id,
    old_credit_limit,
    new_credit_limit,
    new_credit_limit - old_credit_limit AS credit_change
FROM trigger_audit_log
WHERE action_type = 'UPDATE'
ORDER BY audit_id;


-- =========================================================
-- Q9. Count audit events by type
-- =========================================================

SELECT
    action_type,
    COUNT(*) AS event_count
FROM trigger_audit_log
GROUP BY action_type
ORDER BY action_type;


-- =========================================================
-- Q10. Final Day 30 audit report
-- =========================================================

SELECT
    audit_id,
    action_type,
    customer_id,

    CASE
        WHEN action_type = 'INSERT'
            THEN 'New customer created'

        WHEN action_type = 'UPDATE'
            THEN 'Customer data updated'

        WHEN action_type = 'DELETE'
            THEN 'Customer deleted'

        ELSE 'Unknown action'
    END AS audit_description,

    old_city,
    new_city,
    old_credit_limit,
    new_credit_limit,
    changed_at

FROM trigger_audit_log
ORDER BY audit_id;