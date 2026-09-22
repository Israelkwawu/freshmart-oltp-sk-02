-- Lab 04: FreshMart dimensional model
-- Grain: one row per product line on a completed order.
CREATE SCHEMA IF NOT EXISTS dw;
CREATE TABLE IF NOT EXISTS dw.dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    month_name TEXT NOT NULL,
    day_of_month INT NOT NULL,
    day_of_week INT NOT NULL,
    day_name TEXT NOT NULL,
    is_weekend BOOLEAN NOT NULL
);
CREATE TABLE IF NOT EXISTS dw.dim_customer (
    customer_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT,
    city TEXT NOT NULL,
    segment TEXT NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX IF NOT EXISTS idx_dim_customer_nk ON dw.dim_customer (customer_id, is_current);
CREATE TABLE IF NOT EXISTS dw.dim_product (
    product_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id INT NOT NULL,
    product_name TEXT NOT NULL,
    category TEXT NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL DEFAULT DATE '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE IF NOT EXISTS dw.dim_store (
    store_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id INT NOT NULL,
    store_name TEXT NOT NULL,
    region TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS dw.fact_sales (
    sales_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_key INT NOT NULL REFERENCES dw.dim_date (date_key),
    customer_key BIGINT NOT NULL REFERENCES dw.dim_customer (customer_key),
    product_key BIGINT NOT NULL REFERENCES dw.dim_product (product_key),
    store_key BIGINT NOT NULL REFERENCES dw.dim_store (store_key),
    order_id INT NOT NULL,
    order_line_id INT NOT NULL UNIQUE,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    line_amount NUMERIC(12, 2) NOT NULL CHECK (line_amount >= 0)
);
CREATE INDEX IF NOT EXISTS idx_fact_sales_date ON dw.fact_sales (date_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_customer ON dw.fact_sales (customer_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_product ON dw.fact_sales (product_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_store ON dw.fact_sales (store_key);
-- Design check: this query should answer revenue by month, region, and the
-- customer's segment at the time of sale once Lab 05 has loaded the facts.
SELECT d.year,
    d.month,
    s.region,
    c.segment,
    SUM(f.line_amount) AS revenue
FROM dw.fact_sales f
    JOIN dw.dim_date d ON d.date_key = f.date_key
    JOIN dw.dim_store s ON s.store_key = f.store_key
    JOIN dw.dim_customer c ON c.customer_key = f.customer_key
GROUP BY d.year,
    d.month,
    s.region,
    c.segment;