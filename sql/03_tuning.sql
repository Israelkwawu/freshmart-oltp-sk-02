-- Lab 03: Advanced SQL and query tuning
-- Run after 01_create_oltp.sql and 02_joins_windows.sql.
-- Baseline plan for a selective lookup.
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id,
    store_id,
    order_ts,
    status
FROM orders
WHERE customer_id = 42;
-- Indexes for selective filters and foreign-key joins.
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_order_lines_order_id ON order_lines (order_id);
CREATE INDEX IF NOT EXISTS idx_order_lines_product_id ON order_lines (product_id);
CREATE INDEX IF NOT EXISTS idx_orders_store_id ON orders (store_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_ts ON orders (order_ts);
CREATE INDEX IF NOT EXISTS idx_orders_store_ts ON orders (store_id, order_ts);
ANALYZE orders;
ANALYZE order_lines;
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id,
    store_id,
    order_ts,
    status
FROM orders
WHERE customer_id = 42;
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM orders
WHERE store_id = 3
    AND order_ts >= TIMESTAMPTZ '2025-01-01'
    AND order_ts < TIMESTAMPTZ '2025-02-01';
-- Broad aggregations can correctly use sequential scans; inspect before adding indexes.
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.region,
    DATE_TRUNC('month', o.order_ts)::date AS month,
    SUM(ol.line_amount) AS revenue
FROM orders o
    JOIN order_lines ol ON ol.order_id = o.order_id
    JOIN stores s ON s.store_id = o.store_id
WHERE o.status = 'completed'
GROUP BY s.region,
    DATE_TRUNC('month', o.order_ts)::date;
-- Precompute the broad report for dashboard reads.
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_monthly_region_revenue AS
SELECT s.region,
    DATE_TRUNC('month', o.order_ts)::date AS month,
    SUM(ol.line_amount) AS revenue,
    COUNT(DISTINCT o.order_id) AS orders
FROM orders o
    JOIN order_lines ol ON ol.order_id = o.order_id
    JOIN stores s ON s.store_id = o.store_id
WHERE o.status = 'completed'
GROUP BY s.region,
    DATE_TRUNC('month', o.order_ts)::date;
CREATE UNIQUE INDEX IF NOT EXISTS uq_mv_monthly_region_revenue ON mv_monthly_region_revenue (region, month);
REFRESH MATERIALIZED VIEW mv_monthly_region_revenue;
SELECT region,
    month,
    revenue,
    orders
FROM mv_monthly_region_revenue
ORDER BY month,
    region;
-- Production refreshes should use REFRESH MATERIALIZED VIEW CONCURRENTLY after
-- the unique index above exists and should document the resulting freshness SLA.