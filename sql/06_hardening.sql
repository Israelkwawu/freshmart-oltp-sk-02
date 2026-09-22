-- Lab 06: data quality and production hardening.
-- All Lab 06 artifacts live in this project under sql/ and logs/.
CREATE SCHEMA IF NOT EXISTS etl;
CREATE SCHEMA IF NOT EXISTS staging;
-- Database-level guards.
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_fact_sales_unit_price_non_negative'
) THEN
ALTER TABLE dw.fact_sales
ADD CONSTRAINT chk_fact_sales_unit_price_non_negative CHECK (unit_price >= 0);
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_fact_sales_quantity_positive'
) THEN
ALTER TABLE dw.fact_sales
ADD CONSTRAINT chk_fact_sales_quantity_positive CHECK (quantity > 0);
END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS uq_dim_customer_current ON dw.dim_customer (customer_id)
WHERE is_current;
CREATE TABLE IF NOT EXISTS etl.dead_letter (
    dead_letter_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rejected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_table TEXT NOT NULL,
    rule_violated TEXT NOT NULL,
    raw_row JSONB NOT NULL
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
-- A generic staging shape for the classify-once/dead-letter pattern.
CREATE TABLE IF NOT EXISTS staging.sales (
    order_id INT NOT NULL,
    order_line_id INT NOT NULL,
    sale_ts TIMESTAMPTZ NOT NULL,
    customer_id INT,
    product_id INT,
    store_id INT,
    quantity INT,
    unit_price NUMERIC(10, 2),
    line_amount NUMERIC(12, 2)
);
CREATE TABLE IF NOT EXISTS staging.sales_clean (LIKE staging.sales);
-- Classify each staged row once, retain rejected evidence, and pass only clean
-- rows to the next stage. The transaction makes the two destinations atomic.
BEGIN;
WITH classified AS (
    SELECT s.*,
        CASE
            WHEN s.quantity IS NULL
            OR s.quantity <= 0 THEN 'quantity_not_positive'
            WHEN s.unit_price IS NULL
            OR s.unit_price < 0 THEN 'unit_price_invalid'
            WHEN s.line_amount IS NULL
            OR s.line_amount < 0 THEN 'line_amount_invalid'
            WHEN c.customer_id IS NULL THEN 'unknown_customer'
            WHEN p.product_id IS NULL THEN 'unknown_product'
            WHEN st.store_id IS NULL THEN 'unknown_store'
            ELSE NULL
        END AS violation
    FROM staging.sales s
        LEFT JOIN public.customers c ON c.customer_id = s.customer_id
        LEFT JOIN public.products p ON p.product_id = s.product_id
        LEFT JOIN public.stores st ON st.store_id = s.store_id
),
rejected AS (
    INSERT INTO etl.dead_letter (source_table, rule_violated, raw_row)
    SELECT 'staging.sales',
        violation,
        to_jsonb(c)
    FROM classified c
    WHERE violation IS NOT NULL
    RETURNING 1
)
INSERT INTO staging.sales_clean (
        order_id,
        order_line_id,
        sale_ts,
        customer_id,
        product_id,
        store_id,
        quantity,
        unit_price,
        line_amount
    )
SELECT order_id,
    order_line_id,
    sale_ts,
    customer_id,
    product_id,
    store_id,
    quantity,
    unit_price,
    line_amount
FROM classified
WHERE violation IS NULL;
COMMIT;
-- Quality report: failed must be zero before a production publish.
WITH checks AS (
    SELECT 'fact_sales.no_orphan_customers' AS check_name,
        COUNT(*) AS failed
    FROM dw.fact_sales f
        LEFT JOIN dw.dim_customer c ON c.customer_key = f.customer_key
    WHERE c.customer_key IS NULL
    UNION ALL
    SELECT 'dim_customer.one_current_per_id',
        COUNT(*)
    FROM (
            SELECT customer_id
            FROM dw.dim_customer
            WHERE is_current
            GROUP BY customer_id
            HAVING COUNT(*) > 1
        ) duplicates
    UNION ALL
    SELECT 'fact_sales.amount_consistency',
        COUNT(*)
    FROM dw.fact_sales
    WHERE ROUND(quantity * unit_price, 2) <> ROUND(line_amount, 2)
    UNION ALL
    SELECT 'fact_sales.no_future_dates',
        COUNT(*)
    FROM dw.fact_sales
    WHERE date_key > TO_CHAR(CURRENT_DATE, 'YYYYMMDD')::int
)
SELECT check_name,
    failed,
    CASE
        WHEN failed = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM checks
ORDER BY failed DESC,
    check_name;
-- Operator monitoring queries.
SELECT *
FROM etl.run_audit
ORDER BY run_id DESC
LIMIT 5;
SELECT COUNT(*) = 0 AS should_alert
FROM etl.run_audit
WHERE step_name = 'load_fact_sales'
    AND status = 'success'
    AND finished_at > now() - INTERVAL '26 hours';
SELECT rows_rejected::numeric / NULLIF(rows_read, 0) > 0.01 AS should_alert
FROM etl.run_audit
ORDER BY run_id DESC
LIMIT 1;