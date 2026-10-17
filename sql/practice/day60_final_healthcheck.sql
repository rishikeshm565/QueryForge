
-- ============================================================
-- QUERYFORGE - DAY 60
-- FINAL DATABASE HEALTH CHECK
-- PostgreSQL 18
--
-- SAFE: READ ONLY
-- No INSERT / UPDATE / DELETE / DROP / CREATE
-- No changes to existing project data
-- ============================================================

BEGIN TRANSACTION READ ONLY;

SET LOCAL statement_timeout = '180s';


-- ============================================================
-- 1. DATABASE CONNECTION
-- ============================================================

SELECT
    current_database() AS database_name,
    current_user AS connected_user,
    current_setting('server_version') AS postgres_version,
    current_setting('transaction_read_only') AS read_only_mode;


-- ============================================================
-- 2. SCHEMA DISCOVERY
-- ============================================================

SELECT
    expected.schema_name,
    CASE
        WHEN n.oid IS NULL THEN 'MISSING'
        ELSE 'EXISTS'
    END AS schema_status
FROM (
    VALUES
        ('core'),
        ('staging'),
        ('dq'),
        ('audit'),
        ('scale'),
        ('analytics'),
        ('etl')
) AS expected(schema_name)
LEFT JOIN pg_namespace n
    ON n.nspname = expected.schema_name
ORDER BY expected.schema_name;


-- ============================================================
-- 3. COMPLETE HEALTH AUDIT
-- All table counts and data comparisons run dynamically,
-- only when the required database objects exist.
-- Results appear in pgAdmin -> Messages.
-- ============================================================

DO $day60$
DECLARE
    r RECORD;

    v_object REGCLASS;
    v_kind "char";
    v_populated BOOLEAN;
    v_rows BIGINT;

    v_customer_count BIGINT;
    v_order_count BIGINT;

    v_parent REGCLASS;
    v_partition_key TEXT;
    v_partition_count INTEGER;
    v_partition_ok BOOLEAN := TRUE;
    v_boundary TEXT;
    v_expected TEXT;
    v_wrong_routes BIGINT;
    v_default_count BIGINT;

    v_mv_ready BOOLEAN := FALSE;
    v_mv_count BIGINT;
    v_source_count BIGINT;
    v_mismatch_count BIGINT;

    v_index_valid BOOLEAN;
    v_index_ready BOOLEAN;
    v_index_live BOOLEAN;
    v_bad_indexes BIGINT;

    v_duplicate_hashes BIGINT;
    v_roles BIGINT;

    v_pass INTEGER := 0;
    v_warn INTEGER := 0;
    v_fail INTEGER := 0;
BEGIN

    RAISE NOTICE '=====================================';
    RAISE NOTICE 'QUERYFORGE DAY 60 - FINAL HEALTH AUDIT';
    RAISE NOTICE '=====================================';

    -- --------------------------------------------------------
    -- CHECK A: Correct database
    -- --------------------------------------------------------

    IF current_database() = 'queryforge_dev' THEN
        RAISE NOTICE 'PASS: Connected to queryforge_dev';
        v_pass := v_pass + 1;
    ELSE
        RAISE NOTICE 'FAIL: Wrong database: %',
            current_database();
        v_fail := v_fail + 1;
    END IF;


    -- --------------------------------------------------------
    -- CHECK B: Database tables and row counts
    --
    -- Required = objects used in the original Day 60
    -- plus Day 55 partitioned orders.
    --
    -- ETL registry is optional because Day 58 unit tests
    -- did not prove a real registry was created.
    -- --------------------------------------------------------

    FOR r IN
        SELECT *
        FROM (
            VALUES
                ('core.customer_master', TRUE, NULL::BIGINT),
                ('staging.customer_upload', TRUE, NULL::BIGINT),
                ('dq.customer_quarantine', TRUE, NULL::BIGINT),
                ('audit.customer_change_log', TRUE, NULL::BIGINT),

                ('scale.customers_big', TRUE, 100000::BIGINT),
                ('scale.orders_big', TRUE, NULL::BIGINT),
                ('scale.payments_big', TRUE, NULL::BIGINT),
                ('scale.orders_partitioned', TRUE, 300000::BIGINT),

                ('analytics.mv_monthly_order_summary', TRUE, NULL::BIGINT),

                ('etl.file_upload_registry', FALSE, NULL::BIGINT)
        ) AS expected(object_name, required, minimum_rows)

    LOOP
        v_object := TO_REGCLASS(r.object_name);

        IF v_object IS NULL THEN

            IF r.required THEN
                RAISE NOTICE 'FAIL: Required object missing: %',
                    r.object_name;
                v_fail := v_fail + 1;
            ELSE
                RAISE NOTICE 'WARN: Optional object missing: %',
                    r.object_name;
                v_warn := v_warn + 1;
            END IF;

            CONTINUE;
        END IF;

        SELECT
            c.relkind,
            c.relispopulated
        INTO
            v_kind,
            v_populated
        FROM pg_class c
        WHERE c.oid = v_object;

        IF v_kind NOT IN ('r', 'p', 'm') THEN

            RAISE NOTICE 'FAIL: Unexpected object type: %',
                r.object_name;
            v_fail := v_fail + 1;
            CONTINUE;

        END IF;

        IF v_kind = 'm' AND NOT v_populated THEN

            RAISE NOTICE 'FAIL: Materialized view not populated: %',
                r.object_name;
            v_fail := v_fail + 1;
            CONTINUE;

        END IF;

        -- Exact row count. No data modifications.
        EXECUTE FORMAT(
            'SELECT COUNT(*) FROM %s',
            v_object
        )
        INTO v_rows;

        IF r.object_name = 'scale.customers_big' THEN
            v_customer_count := v_rows;
        END IF;

        IF r.object_name = 'scale.orders_partitioned' THEN
            v_order_count := v_rows;
        END IF;

        IF r.object_name =
            'analytics.mv_monthly_order_summary' THEN
            v_mv_ready := TRUE;
        END IF;

        IF r.minimum_rows IS NOT NULL
           AND v_rows < r.minimum_rows THEN

            RAISE NOTICE
                'FAIL: % has % rows; minimum expected %',
                r.object_name,
                v_rows,
                r.minimum_rows;

            v_fail := v_fail + 1;

        ELSE

            RAISE NOTICE 'PASS: % | rows=%',
                r.object_name,
                v_rows;

            v_pass := v_pass + 1;

        END IF;

    END LOOP;


    -- --------------------------------------------------------
    -- CHECK C: Day 55 partitioning
    -- --------------------------------------------------------

    RAISE NOTICE '-------------------------------------';
    RAISE NOTICE 'DAY 55: PARTITION HEALTH';
    RAISE NOTICE '-------------------------------------';

    v_parent := TO_REGCLASS('scale.orders_partitioned');

    IF v_parent IS NOT NULL THEN

        SELECT pg_get_partkeydef(v_parent)
        INTO v_partition_key;

        IF v_partition_key = 'RANGE (order_date)' THEN

            RAISE NOTICE 'PASS: Partition key = %',
                v_partition_key;
            v_pass := v_pass + 1;

        ELSE

            RAISE NOTICE 'FAIL: Incorrect partition key: %',
                v_partition_key;
            v_fail := v_fail + 1;
            v_partition_ok := FALSE;

        END IF;


        SELECT COUNT(*)
        INTO v_partition_count
        FROM pg_inherits
        WHERE inhparent = v_parent;

        IF v_partition_count = 4 THEN

            RAISE NOTICE 'PASS: Four partitions attached';
            v_pass := v_pass + 1;

        ELSE

            RAISE NOTICE 'FAIL: Expected 4 partitions, found %',
                v_partition_count;
            v_fail := v_fail + 1;
            v_partition_ok := FALSE;

        END IF;


        -- Verify expected partitions and boundaries.

        FOR r IN
            SELECT *
            FROM (
                VALUES
                    (
                        'orders_2024',
                        'FOR VALUES FROM (''2024-01-01'') TO (''2025-01-01'')'
                    ),
                    (
                        'orders_2025',
                        'FOR VALUES FROM (''2025-01-01'') TO (''2026-01-01'')'
                    ),
                    (
                        'orders_2026',
                        'FOR VALUES FROM (''2026-01-01'') TO (''2027-01-01'')'
                    ),
                    (
                        'orders_default',
                        'DEFAULT'
                    )
            ) AS expected(partition_name, expected_boundary)

        LOOP

            v_boundary := NULL;

            SELECT
                pg_get_expr(
                    child.relpartbound,
                    child.oid
                )
            INTO v_boundary
            FROM pg_inherits i
            JOIN pg_class child
                ON child.oid = i.inhrelid
            WHERE i.inhparent = v_parent
              AND child.oid = TO_REGCLASS(
                  'scale.' || r.partition_name
              );

            IF v_boundary IS DISTINCT FROM
                r.expected_boundary THEN

                RAISE NOTICE
                    'FAIL: Partition or boundary incorrect: % | actual=%',
                    r.partition_name,
                    v_boundary;

                v_fail := v_fail + 1;
                v_partition_ok := FALSE;

            ELSE

                RAISE NOTICE
                    'PASS: Partition % | %',
                    r.partition_name,
                    v_boundary;

                v_pass := v_pass + 1;

            END IF;

        END LOOP;


        -- Count physical rows in each attached partition.

        FOR r IN
            SELECT
                child.oid::REGCLASS AS partition_table
            FROM pg_inherits i
            JOIN pg_class child
                ON child.oid = i.inhrelid
            WHERE i.inhparent = v_parent
            ORDER BY child.relname

        LOOP

            EXECUTE FORMAT(
                'SELECT COUNT(*) FROM %s',
                r.partition_table
            )
            INTO v_rows;

            RAISE NOTICE
                'INFO: Partition % contains % rows',
                r.partition_table,
                v_rows;

        END LOOP;


        -- Verify 2024 / 2025 / 2026 rows are routed
        -- into their expected physical partitions.

        IF v_partition_ok THEN

            SELECT COUNT(*)
            INTO v_wrong_routes
            FROM scale.orders_partitioned
            WHERE
                (
                    order_date >= DATE '2024-01-01'
                    AND order_date < DATE '2025-01-01'
                    AND tableoid <>
                        'scale.orders_2024'::REGCLASS
                )
                OR
                (
                    order_date >= DATE '2025-01-01'
                    AND order_date < DATE '2026-01-01'
                    AND tableoid <>
                        'scale.orders_2025'::REGCLASS
                )
                OR
                (
                    order_date >= DATE '2026-01-01'
                    AND order_date < DATE '2027-01-01'
                    AND tableoid <>
                        'scale.orders_2026'::REGCLASS
                );

            IF v_wrong_routes = 0 THEN
                RAISE NOTICE 'PASS: Wrong partition routing = 0';
                v_pass := v_pass + 1;
            ELSE
                RAISE NOTICE 'FAIL: Wrong partition routing = %',
                    v_wrong_routes;
                v_fail := v_fail + 1;
            END IF;


            SELECT COUNT(*)
            INTO v_default_count
            FROM scale.orders_default;

            IF v_default_count = 0 THEN
                RAISE NOTICE 'PASS: Default partition is empty';
                v_pass := v_pass + 1;
            ELSE
                RAISE NOTICE
                    'WARN: Default partition has % orders',
                    v_default_count;
                v_warn := v_warn + 1;
            END IF;

        ELSE

            RAISE NOTICE
                'WARN: Routing check skipped due to partition metadata failure';

            v_warn := v_warn + 1;

        END IF;

    END IF;


    -- --------------------------------------------------------
    -- CHECK D: Day 56 materialized view
    -- Compare original source to stored monthly summary.
    -- --------------------------------------------------------

    RAISE NOTICE '-------------------------------------';
    RAISE NOTICE 'DAY 56: MATERIALIZED VIEW';
    RAISE NOTICE '-------------------------------------';

    IF v_order_count IS NOT NULL
       AND v_mv_ready THEN

        SELECT
            COALESCE(SUM(total_orders), 0)
        INTO v_source_count
        FROM analytics.mv_monthly_order_summary;

        IF v_source_count = v_order_count THEN

            RAISE NOTICE
                'PASS: Source orders % = summarized orders %',
                v_order_count,
                v_source_count;

            v_pass := v_pass + 1;

        ELSE

            RAISE NOTICE
                'FAIL: Source count %, summary count %',
                v_order_count,
                v_source_count;

            v_fail := v_fail + 1;

        END IF;


        WITH source_summary AS (
            SELECT
                DATE_TRUNC('month', order_date)::DATE
                    AS month,
                status,
                COUNT(*) AS total_orders,
                SUM(amount) AS total_amount
            FROM scale.orders_partitioned
            GROUP BY
                DATE_TRUNC('month', order_date)::DATE,
                status
        ),
        mismatches AS (
            SELECT
                s.month AS source_month,
                m.month AS view_month,
                s.status AS source_status,
                m.status AS view_status
            FROM source_summary s
            FULL OUTER JOIN analytics.mv_monthly_order_summary m
                ON m.month = s.month
               AND m.status = s.status
            WHERE
                s.month IS NULL
                OR m.month IS NULL
                OR s.total_orders IS DISTINCT FROM
                    m.total_orders
                OR s.total_amount IS DISTINCT FROM
                    m.total_amount
        )
        SELECT COUNT(*)
        INTO v_mismatch_count
        FROM mismatches;

        IF v_mismatch_count = 0 THEN

            RAISE NOTICE
                'PASS: Monthly aggregate mismatches = 0';

            v_pass := v_pass + 1;

        ELSE

            RAISE NOTICE
                'FAIL: Monthly aggregate mismatches = %',
                v_mismatch_count;

            v_fail := v_fail + 1;

        END IF;

    ELSE

        RAISE NOTICE
            'WARN: Materialized view comparison skipped';

        v_warn := v_warn + 1;

    END IF;


    -- --------------------------------------------------------
    -- CHECK E: Day 53 advanced indexes
    -- --------------------------------------------------------

    RAISE NOTICE '-------------------------------------';
    RAISE NOTICE 'DAY 53: INDEX VALIDATION';
    RAISE NOTICE '-------------------------------------';

    FOR r IN
        SELECT index_name
        FROM (
            VALUES
                ('customers_big_pkey'),
                ('idx_customers_big_city_credit'),
                ('idx_customers_big_inactive_customer'),
                ('idx_customers_big_city_cover')
        ) AS expected(index_name)

    LOOP

        v_index_valid := NULL;
        v_index_ready := NULL;
        v_index_live := NULL;

        SELECT
            i.indisvalid,
            i.indisready,
            i.indislive
        INTO
            v_index_valid,
            v_index_ready,
            v_index_live
        FROM pg_index i
        JOIN pg_class idx
            ON idx.oid = i.indexrelid
        JOIN pg_namespace n
            ON n.oid = idx.relnamespace
        WHERE n.nspname = 'scale'
          AND idx.relname = r.index_name
          AND i.indrelid =
              TO_REGCLASS('scale.customers_big');

        IF v_index_valid IS TRUE
           AND v_index_ready IS TRUE
           AND v_index_live IS TRUE THEN

            RAISE NOTICE 'PASS: Index % is valid and ready',
                r.index_name;

            v_pass := v_pass + 1;

        ELSE

            RAISE NOTICE 'FAIL: Index % missing or invalid',
                r.index_name;

            v_fail := v_fail + 1;

        END IF;

    END LOOP;


    -- Detect invalid indexes in project schemas.

    SELECT COUNT(*)
    INTO v_bad_indexes
    FROM pg_index i
    JOIN pg_class t
        ON t.oid = i.indrelid
    JOIN pg_namespace n
        ON n.oid = t.relnamespace
    WHERE n.nspname IN (
        'core', 'scale', 'analytics', 'etl'
    )
    AND (
        NOT i.indisvalid
        OR NOT i.indisready
        OR NOT i.indislive
    );

    IF v_bad_indexes = 0 THEN
        RAISE NOTICE 'PASS: No invalid project indexes';
        v_pass := v_pass + 1;
    ELSE
        RAISE NOTICE 'FAIL: Found % invalid project indexes',
            v_bad_indexes;
        v_fail := v_fail + 1;
    END IF;


    -- --------------------------------------------------------
    -- CHECK F: Day 58 upload registry
    -- --------------------------------------------------------

    RAISE NOTICE '-------------------------------------';
    RAISE NOTICE 'DAY 58: UPLOAD REGISTRY';
    RAISE NOTICE '-------------------------------------';

    IF TO_REGCLASS('etl.file_upload_registry')
       IS NOT NULL THEN

        SELECT COUNT(*)
        INTO v_duplicate_hashes
        FROM (
            SELECT file_hash
            FROM etl.file_upload_registry
            GROUP BY file_hash
            HAVING COUNT(*) > 1
        ) duplicates;

        IF v_duplicate_hashes = 0 THEN

            RAISE NOTICE
                'PASS: Upload registry has no duplicate file hashes';

            v_pass := v_pass + 1;

        ELSE

            RAISE NOTICE
                'FAIL: Duplicate file hashes = %',
                v_duplicate_hashes;

            v_fail := v_fail + 1;

        END IF;

    ELSE

        RAISE NOTICE
            'WARN: Day 58 upload registry not created in database';

        v_warn := v_warn + 1;

    END IF;


    -- --------------------------------------------------------
    -- CHECK G: Database roles
    -- --------------------------------------------------------

    SELECT COUNT(*)
    INTO v_roles
    FROM pg_roles
    WHERE LEFT(rolname, 3) = 'qf_';

    IF v_roles > 0 THEN

        RAISE NOTICE 'PASS: qf_ roles found = %',
            v_roles;

        v_pass := v_pass + 1;

    ELSE

        RAISE NOTICE 'WARN: No qf_ roles found';
        v_warn := v_warn + 1;

    END IF;


    -- --------------------------------------------------------
    -- FINAL REPORT
    -- --------------------------------------------------------

    RAISE NOTICE '=====================================';
    RAISE NOTICE 'DAY 60 FINAL RESULT';
    RAISE NOTICE 'PASSED CHECKS: %', v_pass;
    RAISE NOTICE 'WARNINGS: %', v_warn;
    RAISE NOTICE 'FAILED CHECKS: %', v_fail;

    IF v_fail = 0 THEN
        RAISE NOTICE 'DAY 60 STATUS: PASS';
    ELSE
        RAISE NOTICE 'DAY 60 STATUS: FAIL - REVIEW REQUIRED';
    END IF;

    RAISE NOTICE '=====================================';

END
$day60$;


-- ============================================================
-- 4. LIST PROJECT INDEXES
-- ============================================================

SELECT
    n.nspname AS schema_name,
    t.relname AS table_name,
    idx.relname AS index_name,
    i.indisvalid AS is_valid,
    i.indisready AS is_ready,
    i.indislive AS is_live,
    pg_size_pretty(
        pg_relation_size(idx.oid)
    ) AS index_size
FROM pg_index i
JOIN pg_class t
    ON t.oid = i.indrelid
JOIN pg_class idx
    ON idx.oid = i.indexrelid
JOIN pg_namespace n
    ON n.oid = t.relnamespace
WHERE n.nspname IN (
    'core',
    'scale',
    'analytics',
    'etl'
)
ORDER BY
    n.nspname,
    t.relname,
    idx.relname;


-- ============================================================
-- 5. CHECK MATERIALIZED VIEW STATUS
-- ============================================================

SELECT
    schemaname,
    matviewname,
    ispopulated,
    hasindexes
FROM pg_matviews
WHERE schemaname = 'analytics'
ORDER BY matviewname;


-- ============================================================
-- 6. PROJECT ROLES
-- ============================================================

SELECT
    rolname,
    rolcanlogin
FROM pg_roles
WHERE LEFT(rolname, 3) = 'qf_'
ORDER BY rolname;


-- ============================================================
-- 7. END READ-ONLY TRANSACTION
-- ============================================================

ROLLBACK;

-- END OF QUERYFORGE DAY 60
