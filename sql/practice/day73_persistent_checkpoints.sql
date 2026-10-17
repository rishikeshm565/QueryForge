
-- QueryForge Day 73: independent persistent checkpoints.
-- No DROP, TRUNCATE, or writes to qf_day72.

CREATE SCHEMA IF NOT EXISTS qf_day73;

CREATE TABLE IF NOT EXISTS qf_day73.jobs (
    source_upload_id BIGINT PRIMARY KEY
        REFERENCES qf_day72.file_uploads(upload_id),

    source_hash CHAR(64) NOT NULL,

    expected_rows INTEGER NOT NULL
        CHECK (expected_rows > 0),

    processed_rows INTEGER NOT NULL DEFAULT 0
        CHECK (
            processed_rows >= 0
            AND processed_rows <= expected_rows
        ),

    last_source_row INTEGER NOT NULL DEFAULT 0
        CHECK (last_source_row >= 0),

    status TEXT NOT NULL DEFAULT 'RUNNING'
        CHECK (status IN ('RUNNING', 'COMPLETED')),

    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (
        status <> 'COMPLETED'
        OR processed_rows = expected_rows
    )
);

CREATE TABLE IF NOT EXISTS qf_day73.processed_customers (
    source_upload_id BIGINT NOT NULL
        REFERENCES qf_day73.jobs(source_upload_id),

    source_row INTEGER NOT NULL
        CHECK (source_row >= 2),

    customer_id BIGINT NOT NULL,
    customer_name VARCHAR(150) NOT NULL,
    city VARCHAR(100) NOT NULL,
    email VARCHAR(254) NOT NULL,
    credit_limit NUMERIC(12,2) NOT NULL,

    PRIMARY KEY (source_upload_id, source_row),
    UNIQUE (source_upload_id, customer_id)
);

CREATE TABLE IF NOT EXISTS qf_day73.batch_history (
    source_upload_id BIGINT NOT NULL
        REFERENCES qf_day73.jobs(source_upload_id),

    batch_number INTEGER NOT NULL
        CHECK (batch_number >= 1),

    first_source_row INTEGER NOT NULL,
    last_source_row INTEGER NOT NULL,

    batch_rows INTEGER NOT NULL
        CHECK (batch_rows >= 1),

    committed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (source_upload_id, batch_number),

    CHECK (last_source_row >= first_source_row)
);
