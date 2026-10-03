-- ============================================================
-- QueryForge / DataVault 360
-- Day 46 - Database Users & Roles
-- ============================================================


-- ------------------------------------------------------------
-- TASK 1: Check current database user
-- ------------------------------------------------------------

SELECT
    current_user,
    session_user;


-- ------------------------------------------------------------
-- TASK 2: Create project roles
-- Rerunnable
-- ------------------------------------------------------------

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'qf_readonly'
    ) THEN
        CREATE ROLE qf_readonly NOLOGIN;
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'qf_analyst'
    ) THEN
        CREATE ROLE qf_analyst NOLOGIN;
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'qf_demo_user'
    ) THEN
        CREATE ROLE qf_demo_user LOGIN;
    END IF;

END
$$;


-- ------------------------------------------------------------
-- TASK 3: View QueryForge roles
-- ------------------------------------------------------------

SELECT
    rolname,
    rolcanlogin,
    rolsuper,
    rolcreatedb,
    rolcreaterole
FROM pg_roles
WHERE rolname LIKE 'qf_%'
ORDER BY rolname;


-- ------------------------------------------------------------
-- TASK 4: Grant database/schema permissions
-- ------------------------------------------------------------

GRANT CONNECT
ON DATABASE queryforge_dev
TO qf_readonly;

GRANT USAGE
ON SCHEMA public
TO qf_readonly;

GRANT SELECT
ON ALL TABLES IN SCHEMA public
TO qf_readonly;


-- Analyst inherits readonly permissions
GRANT qf_readonly
TO qf_analyst;

-- Demo user becomes analyst
GRANT qf_analyst
TO qf_demo_user;


-- ------------------------------------------------------------
-- TASK 5: Explicitly remove write access
-- ------------------------------------------------------------

REVOKE INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public
FROM qf_readonly;


-- ------------------------------------------------------------
-- TASK 6: Verify permissions
-- ------------------------------------------------------------

SELECT
    has_table_privilege(
        'qf_demo_user',
        'public.customers',
        'SELECT'
    ) AS can_select,

    has_table_privilege(
        'qf_demo_user',
        'public.customers',
        'UPDATE'
    ) AS can_update;