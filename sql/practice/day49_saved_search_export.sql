-- ============================================================
-- QueryForge / DataVault 360
-- Day 49 - Saved Search & Export
-- ============================================================


-- ------------------------------------------------------------
-- TASK 1: Create saved searches table
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.saved_customer_searches (
    search_id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    search_name         VARCHAR(100) NOT NULL,
    city_filter         VARCHAR(80),
    min_credit_limit    NUMERIC(12,2),
    active_only         BOOLEAN NOT NULL DEFAULT TRUE,
    saved_by            TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_saved_customer_search
        UNIQUE (saved_by, search_name)
);


-- ------------------------------------------------------------
-- TASK 2: Save first filter
-- ------------------------------------------------------------

INSERT INTO public.saved_customer_searches (
    search_name,
    city_filter,
    min_credit_limit,
    active_only,
    saved_by
)
VALUES (
    'Hyderabad Active Customers',
    'Hyderabad',
    20000,
    TRUE,
    'qf_demo_user'
)
ON CONFLICT (saved_by, search_name)
DO UPDATE SET
    city_filter = EXCLUDED.city_filter,
    min_credit_limit = EXCLUDED.min_credit_limit,
    active_only = EXCLUDED.active_only;


-- ------------------------------------------------------------
-- TASK 3: Save second filter
-- ------------------------------------------------------------

INSERT INTO public.saved_customer_searches (
    search_name,
    city_filter,
    min_credit_limit,
    active_only,
    saved_by
)
VALUES (
    'High Credit Customers',
    NULL,
    20000,
    TRUE,
    'qf_demo_user'
)
ON CONFLICT (saved_by, search_name)
DO UPDATE SET
    city_filter = EXCLUDED.city_filter,
    min_credit_limit = EXCLUDED.min_credit_limit,
    active_only = EXCLUDED.active_only;


-- ------------------------------------------------------------
-- TASK 4: View saved searches
-- ------------------------------------------------------------

SELECT
    search_id,
    search_name,
    city_filter,
    min_credit_limit,
    active_only,
    saved_by,
    created_at
FROM public.saved_customer_searches
ORDER BY search_id;


-- ------------------------------------------------------------
-- TASK 5: Execute saved search
-- ------------------------------------------------------------

WITH selected_search AS (
    SELECT
        city_filter,
        min_credit_limit,
        active_only
    FROM public.saved_customer_searches
    WHERE saved_by = 'qf_demo_user'
      AND search_name = 'Hyderabad Active Customers'
)

SELECT
    c.customer_id,
    c.full_name,
    c.email,
    c.city,
    c.credit_limit,
    c.is_active
FROM public.customers c
CROSS JOIN selected_search s
WHERE
    (
        s.city_filter IS NULL
        OR c.city = s.city_filter
    )
    AND
    (
        s.min_credit_limit IS NULL
        OR c.credit_limit >= s.min_credit_limit
    )
    AND
    (
        s.active_only = FALSE
        OR c.is_active = TRUE
    )
ORDER BY
    c.credit_limit DESC,
    c.customer_id;