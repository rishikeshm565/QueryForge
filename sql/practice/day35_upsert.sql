TRUNCATE TABLE staging.customer_upload;

CREATE SCHEMA IF NOT EXISTS core;

DROP TABLE IF EXISTS core.customer_master;

CREATE TABLE core.customer_master
(
    customer_id INTEGER PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    city VARCHAR(80),
    email VARCHAR(150),
    credit_limit NUMERIC(12,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT *
FROM core.customer_master;

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
(1, 99001, 'Aarav Sharma', 'Hyderabad', 'aarav@example.com', 50000),
(2, 99002, 'Meera Reddy', 'Mumbai', 'meera@example.com', 60000);


SELECT *
FROM staging.customer_upload
ORDER BY customer_id;


INSERT INTO core.customer_master
(
    customer_id,
    customer_name,
    city,
    email,
    credit_limit
)
SELECT
    customer_id,
    customer_name,
    city,
    email,
    credit_limit
FROM staging.customer_upload

ON CONFLICT (customer_id)

DO UPDATE SET
    customer_name = EXCLUDED.customer_name,
    city = EXCLUDED.city,
    email = EXCLUDED.email,
    credit_limit = EXCLUDED.credit_limit,
    updated_at = CURRENT_TIMESTAMP;

SELECT
    customer_id,
    customer_name,
    city,
    email,
    credit_limit
FROM core.customer_master
ORDER BY customer_id;


UPDATE staging.customer_upload
SET
    city = 'Bengaluru',
    credit_limit = 75000
WHERE customer_id = 99001;


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
(3, 99003, 'Rahul Verma', 'Pune', 'rahul@example.com', 70000);


	SELECT
    customer_id,
    customer_name,
    city,
    credit_limit
FROM staging.customer_upload
ORDER BY customer_id;



INSERT INTO core.customer_master
(
    customer_id,
    customer_name,
    city,
    email,
    credit_limit
)
SELECT
    customer_id,
    customer_name,
    city,
    email,
    credit_limit
FROM staging.customer_upload

ON CONFLICT (customer_id)

DO UPDATE SET
    customer_name = EXCLUDED.customer_name,
    city = EXCLUDED.city,
    email = EXCLUDED.email,
    credit_limit = EXCLUDED.credit_limit,
    updated_at = CURRENT_TIMESTAMP;


	SELECT
    customer_id,
    customer_name,
    city,
    credit_limit
FROM core.customer_master
ORDER BY customer_id;