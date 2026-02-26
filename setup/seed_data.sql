-- =============================================================
-- Acme Commerce: Raw Data Seed Script
-- Run this against ECOM_ANALYTICS database on the demo account
-- =============================================================

CREATE DATABASE IF NOT EXISTS ECOM_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS ECOM_ANALYTICS.RAW;
CREATE SCHEMA IF NOT EXISTS ECOM_ANALYTICS.DBT_DEV;

USE SCHEMA ECOM_ANALYTICS.RAW;

-- ----- RAW CUSTOMERS -----
CREATE OR REPLACE TABLE customers (
    id INT,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    created_at TIMESTAMP
);

INSERT INTO customers VALUES
(1,  'Michael',  'Chen',      'michael.chen@gmail.com',      '2023-01-15 08:30:00'),
(2,  'Sarah',    'Williams',  'sarah.w@outlook.com',         '2023-01-22 14:15:00'),
(3,  'James',    'Park',      'james.park@yahoo.com',        '2023-02-03 09:45:00'),
(4,  'Emily',    'Santos',    'emily.santos@gmail.com',      '2023-02-14 11:20:00'),
(5,  'David',    'Thompson',  'david.t@company.com.au',      '2023-03-01 16:00:00'),
(6,  'Lisa',     'Nguyen',    'lisa.nguyen@hotmail.com',      '2023-03-10 10:30:00'),
(7,  'Daniel',   'Brown',     'daniel.brown@gmail.com',       '2023-04-05 13:45:00'),
(8,  'Rachel',   'Kim',       'rachel.kim@outlook.com',       '2023-04-18 08:00:00'),
(9,  'Tom',      'Martinez',  'tom.martinez@yahoo.com',       '2023-05-02 15:30:00'),
(10, 'Sophie',   'Anderson',  'sophie.a@company.com.au',      '2023-05-20 09:15:00'),
(11, 'Chris',    'Lee',       'chris.lee@gmail.com',          '2023-06-01 12:00:00'),
(12, 'Emma',     'Wilson',    'emma.wilson@outlook.com',      '2023-06-15 14:30:00'),
(13, 'Ryan',     'Taylor',    'ryan.taylor@yahoo.com',        '2023-07-03 10:00:00'),
(14, 'Olivia',   'White',     'olivia.w@hotmail.com',         '2023-07-22 16:45:00'),
(15, 'Nathan',   'Harris',    'nathan.harris@gmail.com',      '2023-08-10 08:30:00'),
(16, 'Mia',      'Clark',     'mia.clark@outlook.com',        '2023-08-25 11:15:00'),
(17, 'Josh',     'Lewis',     'josh.lewis@company.com.au',    '2023-09-05 13:00:00'),
(18, 'Chloe',    'Walker',    'chloe.walker@gmail.com',       '2023-09-18 09:45:00'),
(19, 'Ben',      'Hall',      'ben.hall@yahoo.com',           '2023-10-01 15:00:00'),
(20, 'Grace',    'Young',     'grace.young@hotmail.com',      '2023-10-15 10:30:00');

-- ----- RAW ORDERS -----
CREATE OR REPLACE TABLE orders (
    id INT,
    customer_id INT,
    order_date DATE,
    status VARCHAR
);

INSERT INTO orders VALUES
(1,  1,  '2023-02-01', 'completed'),
(2,  2,  '2023-02-05', 'completed'),
(3,  3,  '2023-02-10', 'completed'),
(4,  1,  '2023-03-01', 'completed'),
(5,  4,  '2023-03-05', 'completed'),
(6,  5,  '2023-03-15', 'shipped'),
(7,  6,  '2023-03-20', 'completed'),
(8,  2,  '2023-04-01', 'completed'),
(9,  7,  '2023-04-10', 'completed'),
(10, 8,  '2023-04-15', 'returned'),
(11, 1,  '2023-05-01', 'completed'),
(12, 9,  '2023-05-10', 'completed'),
(13, 3,  '2023-05-20', 'completed'),
(14, 10, '2023-06-01', 'shipped'),
(15, 11, '2023-06-15', 'completed'),
(16, 4,  '2023-06-20', 'completed'),
(17, 12, '2023-07-01', 'completed'),
(18, 5,  '2023-07-10', 'completed'),
(19, 13, '2023-07-25', 'placed'),
(20, 14, '2023-08-01', 'completed'),
(21, 1,  '2023-08-15', 'completed'),
(22, 15, '2023-08-20', 'completed'),
(23, 6,  '2023-09-01', 'completed'),
(24, 16, '2023-09-10', 'shipped'),
(25, 2,  '2023-09-15', 'completed'),
(26, 17, '2023-10-01', 'completed'),
(27, 18, '2023-10-10', 'placed'),
(28, 3,  '2023-10-20', 'completed'),
(29, 19, '2023-11-01', 'completed'),
(30, 20, '2023-11-15', 'completed');

-- ----- RAW PAYMENTS -----
CREATE OR REPLACE TABLE payments (
    id INT,
    order_id INT,
    payment_method VARCHAR,
    amount DECIMAL(10,2)
);

INSERT INTO payments VALUES
(1,  1,  'credit_card',   29.99),
(2,  2,  'credit_card',   45.50),
(3,  3,  'bank_transfer', 120.00),
(4,  4,  'credit_card',   15.75),
(5,  5,  'gift_card',     89.99),
(6,  6,  'credit_card',   200.00),
(7,  7,  'bank_transfer', 35.25),
(8,  8,  'credit_card',   67.80),
(9,  9,  'coupon',        12.50),
(10, 10, 'credit_card',   155.00),
(11, 11, 'credit_card',   42.30),
(12, 12, 'bank_transfer', 78.90),
(13, 13, 'credit_card',   99.99),
(14, 14, 'gift_card',     55.00),
(15, 15, 'credit_card',   33.45),
(16, 16, 'credit_card',   110.25),
(17, 17, 'bank_transfer', 22.00),
(18, 18, 'credit_card',   175.50),
(19, 19, 'coupon',        8.99),
(20, 20, 'credit_card',   65.75),
(21, 21, 'credit_card',   48.90),
(22, 22, 'bank_transfer', 92.00),
(23, 23, 'credit_card',   27.30),
(24, 24, 'gift_card',     140.00),
(25, 25, 'credit_card',   56.80),
(26, 26, 'bank_transfer', 88.50),
(27, 27, 'credit_card',   19.99),
(28, 28, 'credit_card',   73.25),
(29, 29, 'coupon',        15.00),
(30, 30, 'credit_card',   105.75),
-- Some orders have split payments
(31, 1,  'gift_card',     10.00),
(32, 5,  'coupon',        20.00),
(33, 11, 'bank_transfer', 15.00),
(34, 18, 'gift_card',     25.00),
(35, 21, 'coupon',        10.00);
