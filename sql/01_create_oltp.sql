DROP TABLE IF EXISTS order_lines, orders, products, stores, customers;
-- ... then all CREATE TABLE and INSERT statements ...

-- FreshMart OLTP schema (simplified slice)
CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    full_name     TEXT        NOT NULL,
    email         TEXT,                        -- nullable: in-store customers may not give one
    city          TEXT        NOT NULL,
    segment       TEXT        NOT NULL DEFAULT 'Standard',  -- Standard | Loyalty | Premium
    signup_date   DATE        NOT NULL
);

CREATE TABLE stores (
    store_id      SERIAL PRIMARY KEY,
    store_name    TEXT NOT NULL,
    region        TEXT NOT NULL                -- North | South | East | West
);

CREATE TABLE products (
    product_id    SERIAL PRIMARY KEY,
    product_name  TEXT          NOT NULL,
    category      TEXT          NOT NULL,      -- Produce | Dairy | Bakery | Beverages | Household
    unit_price    NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE orders (
    order_id      SERIAL PRIMARY KEY,
    customer_id   INT  NOT NULL REFERENCES customers(customer_id),
    store_id      INT  NOT NULL REFERENCES stores(store_id),
    order_ts      TIMESTAMPTZ NOT NULL,
    status        TEXT NOT NULL DEFAULT 'completed'   -- completed | cancelled | returned
);

CREATE TABLE order_lines (
    order_line_id SERIAL PRIMARY KEY,
    order_id      INT NOT NULL REFERENCES orders(order_id),
    product_id    INT NOT NULL REFERENCES products(product_id),
    quantity      INT NOT NULL CHECK (quantity > 0),
    line_amount   NUMERIC(12,2) NOT NULL       -- quantity * price after discounts
);

-- 8 stores
INSERT INTO stores (store_name, region) VALUES
 ('Accra Central','South'),('Kumasi Main','North'),('Tema Harbour','East'),
 ('Takoradi Mall','West'),('Accra East','South'),('Tamale Plaza','North'),
 ('Cape Coast','West'),('Ho Market','East');

-- 25 products across 5 categories
INSERT INTO products (product_name, category, unit_price)
SELECT
    'Product ' || gs,
    (ARRAY['Produce','Dairy','Bakery','Beverages','Household'])[1 + (gs % 5)],
    ROUND((2 + random() * 48)::numeric, 2)
FROM generate_series(1, 25) AS gs;

-- 2,000 customers; ~15% have no email (NULL); mixed segments
INSERT INTO customers (full_name, email, city, segment, signup_date)
SELECT
    'Customer ' || gs,
    CASE WHEN random() < 0.15 THEN NULL
         ELSE 'customer' || gs || '@example.com' END,
    (ARRAY['Accra','Kumasi','Tema','Takoradi','Tamale'])[1 + (gs % 5)],
    CASE WHEN random() < 0.10 THEN 'Premium'
         WHEN random() < 0.40 THEN 'Loyalty'
         ELSE 'Standard' END,
    DATE '2023-01-01' + (random() * 900)::int
FROM generate_series(1, 2000) AS gs;

-- 50,000 orders over ~18 months; ~4% cancelled, ~2% returned
INSERT INTO orders (customer_id, store_id, order_ts, status)
SELECT
    1 + (random() * 1999)::int,
    1 + (random() * 7)::int,
    TIMESTAMPTZ '2024-06-01' + (random() * 540) * INTERVAL '1 day'
        + (random() * 86400) * INTERVAL '1 second',
    CASE WHEN random() < 0.04 THEN 'cancelled'
         WHEN random() < 0.06 THEN 'returned'
         ELSE 'completed' END
FROM generate_series(1, 50000);

-- ~150,000 order lines: 1–5 lines per order
INSERT INTO order_lines (order_id, product_id, quantity, line_amount)
SELECT
    o.order_id,
    p.product_id,
    q.quantity,
    ROUND(q.quantity * p.unit_price, 2)
FROM orders o
CROSS JOIN LATERAL (
    SELECT 1 + (random() * 4)::int AS n_lines
) AS lines
CROSS JOIN LATERAL (
    SELECT 1 + (random() * 24)::int AS product_id,
           1 + (random() * 3)::int  AS quantity,
           gs
    FROM generate_series(1, lines.n_lines) AS gs
) AS q
JOIN products p ON p.product_id = q.product_id;