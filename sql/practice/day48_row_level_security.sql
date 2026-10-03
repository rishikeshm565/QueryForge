-- ============================================================
-- QueryForge / DataVault 360
-- Day 48 - Row-Level Security
-- Record-specific access
-- ============================================================


-- ------------------------------------------------------------
-- TASK 1: Create safe RLS practice table
-- ------------------------------------------------------------

DROP TABLE IF EXISTS public.customer_access_demo;

CREATE TABLE public.customer_access_demo (
    record_id      INTEGER PRIMARY KEY,
    customer_name  VARCHAR(100) NOT NULL,
    city           VARCHAR(80),
    assigned_to    TEXT NOT NULL
);


-- ------------------------------------------------------------
-- TASK 2: Insert controlled test records
-- ------------------------------------------------------------

INSERT INTO public.customer_access_demo (
    record_id,
    customer_name,
    city,
    assigned_to
)
VALUES
    (1, 'Rahul Verma', 'Hyderabad', 'qf_demo_user'),
    (2, 'Sneha Rao', 'Bengaluru',  'qf_analyst'),
    (3, 'Meera Reddy', 'Hyderabad','qf_demo_user'),
    (4, 'Vikram Shah', 'Chennai',  'qf_analyst');


-- ------------------------------------------------------------
-- TASK 3: Grant SELECT
-- ------------------------------------------------------------

GRANT SELECT
ON public.customer_access_demo
TO qf_readonly;


-- ------------------------------------------------------------
-- TASK 4: Enable Row-Level Security
-- ------------------------------------------------------------

ALTER TABLE public.customer_access_demo
ENABLE ROW LEVEL SECURITY;


-- ------------------------------------------------------------
-- TASK 5: Create SELECT policy
-- User sees only rows assigned to current_user
-- ------------------------------------------------------------

DROP POLICY IF EXISTS customer_access_policy
ON public.customer_access_demo;

CREATE POLICY customer_access_policy
ON public.customer_access_demo
FOR SELECT
TO qf_demo_user, qf_analyst
USING (
    assigned_to = current_user
);


-- ------------------------------------------------------------
-- TASK 6: Verify RLS and policy
-- ------------------------------------------------------------

SELECT
    schemaname,
    tablename,
    policyname,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'customer_access_demo';