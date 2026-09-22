-- Lab 05: idempotent FreshMart warehouse ETL.
-- Run after 04_star_schema.sql. All statements are safe to rerun.
CREATE SCHEMA IF NOT EXISTS etl;
CREATE TABLE IF NOT EXISTS dw.etl_control (
    table_name TEXT PRIMARY KEY,
    high_water_mark TIMESTAMPTZ NOT NULL
);
INSERT INTO dw.etl_control (table_name, high_water_mark)
VALUES ('fact_sales', TIMESTAMPTZ '1900-01-01') ON CONFLICT (table_name) DO NOTHING;
CREATE TABLE IF NOT EXISTS dw.etl_run_log (
    run_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ,
    rows_loaded BIGINT,
    status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'success', 'failed'))
);
CREATE TABLE IF NOT EXISTS etl.run_audit (
    run_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    step_name TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ,
    rows_read BIGINT,
    rows_loaded BIGINT,
    rows_rejected BIGINT,
    status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'success', 'failed'))
);
-- The date dimension is static and can be populated repeatedly.
INSERT INTO dw.dim_date (
        date_key,
        full_date,
        year,
        quarter,
        month,
        month_name,
        day_of_month,
        day_of_week,
        day_name,
        is_weekend
    )
SELECT TO_CHAR(d, 'YYYYMMDD')::int,
    d::date,
    EXTRACT(
        YEAR
        FROM d
    )::int,
    EXTRACT(
        QUARTER
        FROM d
    )::int,
    EXTRACT(
        MONTH
        FROM d
    )::int,
    TO_CHAR(d, 'FMMonth'),
    EXTRACT(
        DAY
        FROM d
    )::int,
    EXTRACT(
        ISODOW
        FROM d
    )::int,
    TO_CHAR(d, 'FMDay'),
    EXTRACT(
        ISODOW
        FROM d
    )::int IN (6, 7)
FROM generate_series(
        DATE '2023-01-01',
        DATE '2032-12-31',
        INTERVAL '1 day'
    ) AS d ON CONFLICT (date_key) DO NOTHING;
-- Type 1 dimensions and the initial Type 2 customer versions.
INSERT INTO dw.dim_store (store_id, store_name, region)
SELECT s.store_id,
    s.store_name,
    s.region
FROM public.stores s
WHERE NOT EXISTS (
        SELECT 1
        FROM dw.dim_store d
        WHERE d.store_id = s.store_id
    );
INSERT INTO dw.dim_product (
        product_id,
        product_name,
        category,
        unit_price,
        valid_from
    )
SELECT p.product_id,
    p.product_name,
    p.category,
    p.unit_price,
    COALESCE(
        (
            SELECT MIN(o.order_ts::date)
            FROM public.orders o
                JOIN public.order_lines ol ON ol.order_id = o.order_id
            WHERE ol.product_id = p.product_id
        ),
        CURRENT_DATE
    )
FROM public.products p
WHERE NOT EXISTS (
        SELECT 1
        FROM dw.dim_product d
        WHERE d.product_id = p.product_id
            AND d.is_current
    );
INSERT INTO dw.dim_customer (
        customer_id,
        full_name,
        email,
        city,
        segment,
        valid_from
    )
SELECT c.customer_id,
    c.full_name,
    c.email,
    c.city,
    c.segment,
    LEAST(
        c.signup_date,
        COALESCE(
            (
                SELECT MIN(o.order_ts::date)
                FROM public.orders o
                WHERE o.customer_id = c.customer_id
            ),
            c.signup_date
        )
    )
FROM public.customers c
WHERE NOT EXISTS (
        SELECT 1
        FROM dw.dim_customer d
        WHERE d.customer_id = c.customer_id
            AND d.is_current
    );
-- SCD Type 2 close-then-insert. IS DISTINCT FROM detects NULL changes too.
BEGIN;
INSERT INTO etl.run_audit (step_name)
VALUES ('load_fact_sales');
CREATE TEMP TABLE changed_customers ON COMMIT DROP AS
SELECT s.customer_id,
    s.full_name,
    s.email,
    s.city,
    s.segment
FROM public.customers s
    JOIN dw.dim_customer d ON d.customer_id = s.customer_id
    AND d.is_current
WHERE s.city IS DISTINCT
FROM d.city
    OR s.segment IS DISTINCT
FROM d.segment;
UPDATE dw.dim_customer d
SET valid_to = CURRENT_DATE,
    is_current = FALSE,
    full_name = c.full_name,
    email = c.email
FROM changed_customers c
WHERE d.customer_id = c.customer_id
    AND d.is_current;
INSERT INTO dw.dim_customer (
        customer_id,
        full_name,
        email,
        city,
        segment,
        valid_from
    )
SELECT c.customer_id,
    c.full_name,
    c.email,
    c.city,
    c.segment,
    CURRENT_DATE
FROM changed_customers c;
INSERT INTO dw.dim_customer (
        customer_id,
        full_name,
        email,
        city,
        segment,
        valid_from
    )
SELECT s.customer_id,
    s.full_name,
    s.email,
    s.city,
    s.segment,
    CURRENT_DATE
FROM public.customers s
WHERE NOT EXISTS (
        SELECT 1
        FROM dw.dim_customer d
        WHERE d.customer_id = s.customer_id
            AND d.is_current
    );
-- Load only completed orders newer than the committed high-water mark.
WITH mark AS (
    SELECT high_water_mark
    FROM dw.etl_control
    WHERE table_name = 'fact_sales'
),
new_lines AS (
    SELECT o.order_id,
        o.order_ts,
        o.store_id,
        o.customer_id,
        ol.order_line_id,
        ol.product_id,
        ol.quantity,
        ol.line_amount
    FROM public.orders o
        JOIN public.order_lines ol ON ol.order_id = o.order_id
        CROSS JOIN mark m
    WHERE o.status = 'completed'
        AND o.order_ts > m.high_water_mark
),
inserted AS (
    INSERT INTO dw.fact_sales (
            date_key,
            customer_key,
            product_key,
            store_key,
            order_id,
            order_line_id,
            quantity,
            unit_price,
            line_amount
        )
    SELECT TO_CHAR(n.order_ts, 'YYYYMMDD')::int,
        dc.customer_key,
        dp.product_key,
        ds.store_key,
        n.order_id,
        n.order_line_id,
        n.quantity,
        dp.unit_price,
        n.line_amount
    FROM new_lines n
        JOIN dw.dim_customer dc ON dc.customer_id = n.customer_id
        AND n.order_ts::date >= dc.valid_from
        AND n.order_ts::date < dc.valid_to
        JOIN dw.dim_product dp ON dp.product_id = n.product_id
        AND dp.is_current
        JOIN dw.dim_store ds ON ds.store_id = n.store_id ON CONFLICT (order_line_id) DO NOTHING
    RETURNING 1
)
UPDATE dw.etl_control
SET high_water_mark = GREATEST(
        high_water_mark,
        COALESCE(
            (
                SELECT MAX(order_ts)
                FROM new_lines
            ),
            high_water_mark
        )
    )
WHERE table_name = 'fact_sales';
UPDATE etl.run_audit
SET finished_at = now(),
    rows_read = (
        SELECT COUNT(*)
        FROM public.orders o
            JOIN public.order_lines ol ON ol.order_id = o.order_id
        WHERE o.status = 'completed'
    ),
    rows_loaded = (
        SELECT COUNT(*)
        FROM dw.fact_sales
    ),
    rows_rejected = 0,
    status = 'success'
WHERE run_id = currval('etl.run_audit_run_id_seq');
COMMIT;
-- Record a successful run and its resulting fact count.
INSERT INTO dw.etl_run_log (table_name, finished_at, rows_loaded, status)
SELECT 'fact_sales',
    now(),
    COUNT(*),
    'success'
FROM dw.fact_sales;
ANALYZE dw.fact_sales;
SELECT table_name,
    high_water_mark
FROM dw.etl_control;
SELECT COUNT(*) AS fact_rows,
    SUM(line_amount) AS fact_revenue
FROM dw.fact_sales;