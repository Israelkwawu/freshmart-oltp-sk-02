# SK-02 Working Notes

## Environment

- Database: `freshmart`
- Host: `localhost:5432`
- User: `postgres`
- SQL scripts: `C:\dataeng\sk02\sql`
- Validation logs: `C:\dataeng\sk02\logs`

## Lab 04 design decisions

1. Business process: retail sales at order-line grain.
2. Grain: one row per product line on a completed order.
3. Dimensions: date, customer, product, and store.
4. Facts: quantity, unit price, and line amount. `order_id` is a degenerate dimension.

Customer city and segment use SCD Type 2. Customer name and email are Type 1 attributes.
Store is Type 1 because the lab treats store regions as stable.

## Lab 02 fanout note

Joining `order_lines` twice by `order_id` multiplies each order's lines by its own line count.
Detect fanout by checking uniqueness at the join grain before joining:

```sql
SELECT order_id, COUNT(*)
FROM order_lines
GROUP BY order_id
HAVING COUNT(*) > 1;
```

Prevent it by pre-aggregating to one row per order in a CTE, then joining that result.

## Lab 05 ETL notes

- The high-water mark and fact load are updated in one transaction.
- `order_line_id` is the fact idempotency key.
- SCD2 changes use `IS DISTINCT FROM` so NULL changes are detected.
- Fact-to-customer joins use validity dates to preserve the customer context at sale time.

## Guided-lab extensions

FreshMart's fiscal year starts on 1 February, so January belongs to the prior fiscal year and to fiscal quarter 4. `dw.dim_date` carries that calendar plus New Year's Day, Independence Day (4 July), and Christmas.

`dw.dim_promotion` is Type 1. `promotion_key = -1` means "No Promotion". The OLTP slice has no promotion id, so every fact row points there instead of using NULL.

`dw.fact_sales` stays unpartitioned because its idempotency key is `order_line_id` alone. A table partitioned by `date_key` cannot enforce that uniqueness. `dw.fact_sales_partitioned` is the yearly copy used to show partition pruning.

`dw.mv_daily_store_category_sales` is current as of its last refresh, which belongs after the nightly fact load.

An order-grain fact would repeat line measures such as product revenue once per line, so a product total would be multiplied by the number of lines on the order. The `-1` promotion row keeps every fact joinable without a NULL check. A late order still finds the customer version whose `valid_from`/`valid_to` covered the original sale date. Adding `product_name` to the dashboard view makes drill-through possible and makes the view much larger, so refresh time and storage go up. If analysis is mostly by store, partition `fact_sales` by `store_key` instead of year so store filters prune the other stores.

## Lab 06 quality notes

- Row-level constraints protect the warehouse schema.
- `etl.dead_letter` retains rejected staging rows as JSONB with a rule name.
- `etl.run_audit` is the monitoring hook for freshness and reject-rate alerts.
- The quality report checks orphan keys, duplicate current customers, amount consistency, and future dates.
