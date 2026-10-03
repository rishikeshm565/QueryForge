CREATE SCHEMA IF NOT EXISTS dq;

DROP TABLE IF EXISTS dq.data_quality_issue;
DROP TABLE IF EXISTS dq.rule_catalog;


CREATE TABLE dq.rule_catalog
(
    rule_id BIGSERIAL PRIMARY KEY,
    rule_code VARCHAR(20) UNIQUE NOT NULL,
    rule_name VARCHAR(150) NOT NULL,
    target_column VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL,

    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_dq_severity
        CHECK (severity IN ('ERROR', 'WARNING'))
);


CREATE TABLE dq.data_quality_issue
(
    issue_id BIGSERIAL PRIMARY KEY,

    rule_id BIGINT NOT NULL
        REFERENCES dq.rule_catalog(rule_id),

    source_row_no INTEGER,
    customer_id INTEGER,

    issue_value TEXT,
    issue_message TEXT,

    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dq.rule_catalog
(
    rule_code,
    rule_name,
    target_column,
    severity
)
VALUES
(
    'DQ001',
    'Customer Name Required',
    'customer_name',
    'ERROR'
),
(
    'DQ002',
    'City Required',
    'city',
    'ERROR'
),
(
    'DQ003',
    'Valid Email Format',
    'email',
    'ERROR'
),
(
    'DQ004',
    'Credit Limit Cannot Be Negative',
    'credit_limit',
    'ERROR'
);

SELECT
    rule_id,
    rule_code,
    rule_name,
    target_column,
    severity,
    is_active
FROM dq.rule_catalog
ORDER BY rule_id;


TRUNCATE TABLE dq.data_quality_issue
RESTART IDENTITY;

WITH detected_issues AS
(
    -- DQ001 - Customer name required

    SELECT
        source_row_no,
        customer_id,
        'DQ001' AS rule_code,
        customer_name::TEXT AS issue_value,
        'customer_name is missing or blank' AS issue_message

    FROM staging.customer_upload

    WHERE customer_name IS NULL
       OR BTRIM(customer_name) = ''


    UNION ALL


    -- DQ002 - City required

    SELECT
        source_row_no,
        customer_id,
        'DQ002',
        city::TEXT,
        'city is missing or blank'

    FROM staging.customer_upload

    WHERE city IS NULL
       OR BTRIM(city) = ''


    UNION ALL


    -- DQ003 - Email format

    SELECT
        source_row_no,
        customer_id,
        'DQ003',
        email::TEXT,
        'invalid email format'

    FROM staging.customer_upload

    WHERE email IS NULL
       OR email NOT LIKE '%@%.%'


    UNION ALL


    -- DQ004 - Negative credit limit

    SELECT
        source_row_no,
        customer_id,
        'DQ004',
        credit_limit::TEXT,
        'credit_limit cannot be negative'

    FROM staging.customer_upload

    WHERE credit_limit < 0
)

INSERT INTO dq.data_quality_issue
(
    rule_id,
    source_row_no,
    customer_id,
    issue_value,
    issue_message
)

SELECT
    r.rule_id,
    d.source_row_no,
    d.customer_id,
    d.issue_value,
    d.issue_message

FROM detected_issues d

JOIN dq.rule_catalog r
    ON r.rule_code = d.rule_code

WHERE r.is_active = TRUE;


SELECT COUNT(*) AS quality_issues
FROM dq.data_quality_issue;


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
);

SELECT COUNT(*) AS staging_rows
FROM staging.customer_upload;

TRUNCATE TABLE dq.data_quality_issue
RESTART IDENTITY;


SELECT
    i.issue_id,
    r.rule_code,
    r.rule_name,
    r.severity,
    i.source_row_no,
    i.customer_id,
    i.issue_value,
    i.issue_message
FROM dq.data_quality_issue i

JOIN dq.rule_catalog r
    ON r.rule_id = i.rule_id

ORDER BY
    i.source_row_no,
    r.rule_code;




	SELECT COUNT(*) AS quality_issues
FROM dq.data_quality_issue;


DELETE FROM staging.customer_upload
WHERE customer_id IN (88001, 88002);


SELECT COUNT(*) AS staging_rows
FROM staging.customer_upload;


