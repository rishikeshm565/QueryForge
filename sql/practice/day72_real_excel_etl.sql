
-- ============================================================
-- QUERYFORGE - DAY 72
-- ISOLATED EXCEL ETL STORAGE
-- ============================================================

-- Executed inside a transaction by Python.
-- No DROP or TRUNCATE statements.

CREATE SCHEMA IF NOT EXISTS qf_day72;


-- 1. File upload registry

CREATE TABLE IF NOT EXISTS qf_day72.file_uploads
(
    upload_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    file_name TEXT NOT NULL,

    file_hash CHAR(64) NOT NULL UNIQUE,

    total_rows INTEGER NOT NULL
        CHECK (total_rows >= 0),

    accepted_rows INTEGER NOT NULL
        CHECK (accepted_rows >= 0),

    rejected_rows INTEGER NOT NULL
        CHECK (rejected_rows >= 0),

    uploaded_at TIMESTAMPTZ NOT NULL
        DEFAULT NOW(),

    CONSTRAINT day72_totals_match
        CHECK (
            total_rows = accepted_rows + rejected_rows
        )
);


-- 2. Validated customer records

CREATE TABLE IF NOT EXISTS qf_day72.customer_rows
(
    upload_id BIGINT NOT NULL
        REFERENCES qf_day72.file_uploads(upload_id),

    source_row INTEGER NOT NULL
        CHECK (source_row >= 2),

    customer_id BIGINT NOT NULL
        CHECK (customer_id > 0),

    customer_name VARCHAR(150) NOT NULL,

    city VARCHAR(100) NOT NULL,

    email VARCHAR(254) NOT NULL,

    credit_limit NUMERIC(12,2) NOT NULL
        CHECK (credit_limit >= 0),

    PRIMARY KEY (upload_id, source_row),

    UNIQUE (upload_id, customer_id)
);


-- 3. Rejected records / quarantine reasons

CREATE TABLE IF NOT EXISTS qf_day72.rejected_rows
(
    upload_id BIGINT NOT NULL
        REFERENCES qf_day72.file_uploads(upload_id),

    source_row INTEGER NOT NULL
        CHECK (source_row >= 2),

    reason TEXT NOT NULL,

    PRIMARY KEY (upload_id, source_row)
);
