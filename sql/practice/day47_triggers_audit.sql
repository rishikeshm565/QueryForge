-- ============================================================
-- QueryForge / DataVault 360
-- Day 47 - Triggers & Audit
-- Track who changed what
-- ============================================================


-- ------------------------------------------------------------
-- TASK 1: Create audit schema
-- ------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS audit;


-- ------------------------------------------------------------
-- TASK 2: Create customer audit table
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit.customer_change_log (
    audit_id       BIGSERIAL PRIMARY KEY,
    customer_id    INTEGER,
    operation      VARCHAR(10) NOT NULL,
    old_data       JSONB,
    new_data       JSONB,
    changed_by     TEXT NOT NULL,
    session_user_name TEXT NOT NULL,
    changed_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ------------------------------------------------------------
-- TASK 3: Create trigger function
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit.fn_customer_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF TG_OP = 'INSERT' THEN

        INSERT INTO audit.customer_change_log (
            customer_id,
            operation,
            old_data,
            new_data,
            changed_by,
            session_user_name
        )
        VALUES (
            NEW.customer_id,
            TG_OP,
            NULL,
            to_jsonb(NEW),
            current_user,
            session_user
        );

        RETURN NEW;


    ELSIF TG_OP = 'UPDATE' THEN

        INSERT INTO audit.customer_change_log (
            customer_id,
            operation,
            old_data,
            new_data,
            changed_by,
            session_user_name
        )
        VALUES (
            NEW.customer_id,
            TG_OP,
            to_jsonb(OLD),
            to_jsonb(NEW),
            current_user,
            session_user
        );

        RETURN NEW;


    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO audit.customer_change_log (
            customer_id,
            operation,
            old_data,
            new_data,
            changed_by,
            session_user_name
        )
        VALUES (
            OLD.customer_id,
            TG_OP,
            to_jsonb(OLD),
            NULL,
            current_user,
            session_user
        );

        RETURN OLD;

    END IF;

    RETURN NULL;
END;
$$;


-- ------------------------------------------------------------
-- TASK 4: Create trigger on customers
-- ------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_customer_audit
ON customers;

CREATE TRIGGER trg_customer_audit
AFTER INSERT OR UPDATE OR DELETE
ON customers
FOR EACH ROW
EXECUTE FUNCTION audit.fn_customer_changes();


-- ------------------------------------------------------------
-- TASK 5: Verify trigger
-- ------------------------------------------------------------

SELECT
    trigger_name,
    event_manipulation,
    event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'trg_customer_audit'
ORDER BY event_manipulation;