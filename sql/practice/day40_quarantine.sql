DROP TABLE IF EXISTS dq.customer_quarantine;

CREATE TABLE dq.customer_quarantine
(
    quarantine_id BIGSERIAL PRIMARY KEY,

    source_row_no INTEGER NOT NULL UNIQUE,
    customer_id INTEGER,

    customer_name VARCHAR(100),
    city VARCHAR(80),
    email VARCHAR(150),
    credit_limit NUMERIC(12,2),

    quarantine_type VARCHAR(30) NOT NULL,
    quarantine_reason TEXT NOT NULL,

    quarantined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_quarantine_type
        CHECK
        (
            quarantine_type IN
            (
                'DATA_QUALITY',
                'EXACT_DUPLICATE',
                'BUSINESS_DUPLICATE'
            )
        )
);

SELECT *
FROM dq.customer_quarantine;

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
    101,
    88001,
    '',
    'Hyderabad',
    'invalid-email',
    50000
),
(
    102,
    88002,
    'DQ Test Customer',
    '',
    'dqtest@example.com',
    -1000
),
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

INSERT INTO dq.customer_quarantine
(
    source_row_no,
    customer_id,
    customer_name,
    city,
    email,
    credit_limit,
    quarantine_type,
    quarantine_reason
)

SELECT
    source_row_no,
    customer_id,
    customer_name,
    city,
    email,
    credit_limit,

    'DATA_QUALITY',

    CONCAT_WS(
        ' | ',

        CASE
            WHEN customer_name IS NULL
              OR BTRIM(customer_name) = ''
            THEN 'customer_name missing'
        END,

        CASE
            WHEN city IS NULL
              OR BTRIM(city) = ''
            THEN 'city missing'
        END,

        CASE
            WHEN email IS NULL
              OR email NOT LIKE '%@%.%'
            THEN 'invalid email'
        END,

        CASE
            WHEN credit_limit < 0
            THEN 'negative credit_limit'
        END
    )

FROM staging.customer_upload

WHERE
       customer_name IS NULL
    OR BTRIM(customer_name) = ''
    OR city IS NULL
    OR BTRIM(city) = ''
    OR email IS NULL
    OR email NOT LIKE '%@%.%'
    OR credit_limit < 0

ON CONFLICT (source_row_no)
DO NOTHING;



INSERT INTO dq.customer_quarantine
(
    source_row_no,
    customer_id,
    customer_name,
    city,
    email,
    credit_limit,
    quarantine_type,
    quarantine_reason
)

SELECT
    s.source_row_no,
    s.customer_id,
    s.customer_name,
    s.city,
    s.email,
    s.credit_limit,

    'EXACT_DUPLICATE',

    'Same customer_id already exists'

FROM staging.customer_upload s

WHERE EXISTS
(
    SELECT 1
    FROM staging.customer_upload original

    WHERE original.customer_id = s.customer_id
      AND original.source_row_no < s.source_row_no
)

ON CONFLICT (source_row_no)
DO NOTHING;

INSERT INTO dq.customer_quarantine
(
    source_row_no,
    customer_id,
    customer_name,
    city,
    email,
    credit_limit,
    quarantine_type,
    quarantine_reason
)

SELECT
    s.source_row_no,
    s.customer_id,
    s.customer_name,
    s.city,
    s.email,
    s.credit_limit,

    'BUSINESS_DUPLICATE',

    'Email already belongs to another customer_id'

FROM staging.customer_upload s

WHERE s.email IS NOT NULL
  AND BTRIM(s.email) <> ''

  AND EXISTS
  (
      SELECT 1

      FROM staging.customer_upload original

      WHERE LOWER(BTRIM(original.email))
            = LOWER(BTRIM(s.email))

        AND original.customer_id
            <> s.customer_id

        AND original.source_row_no
            < s.source_row_no
  )

ON CONFLICT (source_row_no)
DO NOTHING;




SELECT
    quarantine_id,
    source_row_no,
    customer_id,
    quarantine_type,
    quarantine_reason
FROM dq.customer_quarantine
ORDER BY source_row_no;


SELECT
    quarantine_type,
    COUNT(*) AS row_count
FROM dq.customer_quarantine
GROUP BY quarantine_type
ORDER BY quarantine_type;


BEGIN;

DELETE FROM staging.customer_upload s
USING dq.customer_quarantine q
WHERE s.source_row_no = q.source_row_no;

COMMIT;

SELECT COUNT(*) AS staging_rows
FROM staging.customer_upload;

SELECT COUNT(*) AS quarantine_rows
FROM dq.customer_quarantine;


SELECT
    14 AS source_rows_before_quarantine,
    10 AS clean_staging_rows,
    4 AS quarantine_rows,
    10 + 4 AS reconciled_rows;