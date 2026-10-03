DROP TABLE IF EXISTS dq.duplicate_issue;

CREATE TABLE dq.duplicate_issue
(
    duplicate_id BIGSERIAL PRIMARY KEY,

    duplicate_type VARCHAR(30) NOT NULL,

    source_row_no INTEGER,
    customer_id INTEGER,

    matched_source_row_no INTEGER,
    matched_customer_id INTEGER,

    match_key TEXT,
    duplicate_message TEXT,

    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_duplicate_type
        CHECK (
            duplicate_type IN
            (
                'EXACT_DUPLICATE',
                'BUSINESS_DUPLICATE'
            )
        )
);


SELECT *
FROM dq.duplicate_issue;

INSERT INTO staging.customer_upload
(
    source_row_no,
    customer_id,
    customer_name,
    city,
    email,
    credit_limit
)
VALUES
(
    201,
    5001,
    'Aarav Sharma',
    'Hyderabad',
    'aarav.sharma@example.com',
    50000
),
(
    202,
    6001,
    'Meera Reddy Duplicate',
    'Hyderabad',
    'meera.reddy@example.com',
    75000
);

SELECT COUNT(*) AS staging_rows
FROM staging.customer_upload;

TRUNCATE TABLE dq.duplicate_issue
RESTART IDENTITY;




WITH ranked_duplicates AS
(
    SELECT
        source_row_no,
        customer_id,

        FIRST_VALUE(source_row_no)
        OVER
        (
            PARTITION BY customer_id
            ORDER BY source_row_no
        ) AS matched_source_row_no,

        ROW_NUMBER()
        OVER
        (
            PARTITION BY customer_id
            ORDER BY source_row_no
        ) AS duplicate_rank,

        COUNT(*)
        OVER
        (
            PARTITION BY customer_id
        ) AS duplicate_count

    FROM staging.customer_upload
)

INSERT INTO dq.duplicate_issue
(
    duplicate_type,
    source_row_no,
    customer_id,
    matched_source_row_no,
    matched_customer_id,
    match_key,
    duplicate_message
)

SELECT
    'EXACT_DUPLICATE',
    source_row_no,
    customer_id,
    matched_source_row_no,
    customer_id,
    customer_id::TEXT,
    'Same customer_id already exists'

FROM ranked_duplicates

WHERE duplicate_count > 1
  AND duplicate_rank > 1;


SELECT *
FROM dq.duplicate_issue;



WITH email_matches AS
(
    SELECT
        source_row_no,
        customer_id,
        email,

        FIRST_VALUE(source_row_no)
        OVER
        (
            PARTITION BY LOWER(BTRIM(email))
            ORDER BY source_row_no
        ) AS matched_source_row_no,

        FIRST_VALUE(customer_id)
        OVER
        (
            PARTITION BY LOWER(BTRIM(email))
            ORDER BY source_row_no
        ) AS matched_customer_id,

        ROW_NUMBER()
        OVER
        (
            PARTITION BY LOWER(BTRIM(email))
            ORDER BY source_row_no
        ) AS duplicate_rank,

        COUNT(*)
        OVER
        (
            PARTITION BY LOWER(BTRIM(email))
        ) AS duplicate_count

    FROM staging.customer_upload

    WHERE email IS NOT NULL
      AND BTRIM(email) <> ''
)

INSERT INTO dq.duplicate_issue
(
    duplicate_type,
    source_row_no,
    customer_id,
    matched_source_row_no,
    matched_customer_id,
    match_key,
    duplicate_message
)

SELECT
    'BUSINESS_DUPLICATE',
    source_row_no,
    customer_id,
    matched_source_row_no,
    matched_customer_id,
    LOWER(BTRIM(email)),
    'Different customer_id uses an existing email address'

FROM email_matches

WHERE duplicate_count > 1
  AND duplicate_rank > 1
  AND customer_id <> matched_customer_id;

  SELECT
    duplicate_id,
    duplicate_type,
    source_row_no,
    customer_id,
    matched_source_row_no,
    matched_customer_id,
    match_key,
    duplicate_message
FROM dq.duplicate_issue
ORDER BY duplicate_id;

SELECT
    duplicate_type,
    COUNT(*) AS duplicate_count
FROM dq.duplicate_issue
GROUP BY duplicate_type
ORDER BY duplicate_type;

DELETE FROM staging.customer_upload
WHERE source_row_no IN (201, 202);


SELECT COUNT(*) AS staging_rows
FROM staging.customer_upload;