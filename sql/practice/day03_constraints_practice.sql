INSERT INTO customers (
    customer_id,
    full_name,
    email
)
VALUES (
    1001,
    'Test Customer',
    'test.customer@queryforge.dev'
);

SELECT
    customer_id,
    full_name,
    email,
    credit_limit,
    is_active,
    created_at
FROM customers
WHERE customer_id = 1001;


INSERT INTO customers (
    customer_id,
    full_name,
    email
)
VALUES (
    1002,
    'Another Customer',
    'test.customer@queryforge.dev'
);

INSERT INTO customers (
    customer_id,
    email
)
VALUES (
    1003,
    'nulltest@queryforge.dev'
);


INSERT INTO customers (
    customer_id,
    full_name,
    email,
    credit_limit
)
VALUES (
    1004,
    'Negative Credit Test',
    'credit.test@queryforge.dev',
    -500
);

INSERT INTO customer_notes (
    note_id,
    customer_id,
    note_text
)
VALUES (
    1,
    1001,
    'Day 3 foreign key test'
);

INSERT INTO customer_notes (
    note_id,
    customer_id,
    note_text
)
VALUES (
    2,
    9999,
    'This record should fail'
);

SELECT * FROM customers;

SELECT * FROM customer_notes;

DELETE FROM customer_notes
WHERE note_id = 1;

DELETE FROM customers
WHERE customer_id = 1001;