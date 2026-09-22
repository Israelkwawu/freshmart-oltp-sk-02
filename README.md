# SQL & Data Modeling Specialist

This repository contains my practical work and exercises for the **AmaliTech Data Engineering T-Shaped Program — SQL & Data Modeling Specialist** track.

The work is based on the official AmaliTech training labs and focuses on building practical SQL and data modeling skills using PostgreSQL.

## Course Reference

Official training repository:

https://github.com/AmaliTech-Training-Academy/DE-T-Shaped-Program

### Lab 01 — SQL Foundations

Official lab:

https://github.com/AmaliTech-Training-Academy/DE-T-Shaped-Program/blob/main/SK-02_SQL_and_Data_Modeling_Specialist/Granular%20Labs/Lab_01_SQL_Foundations.md

---

# Prerequisites

Install the following:

- PostgreSQL
- `psql` command-line client
- Git
- Git Bash
- A PostgreSQL database named `freshmart`

Check PostgreSQL:

```bash
psql --version
```

Example:

```text
psql (PostgreSQL) 18.6
```

Check Git:

```bash
git --version
```

---

# Project Structure

```text
dataeng/
│
├── README.md
│
└── sk02/
    │
    ├── sql/
    │   ├── 01_create_oltp.sql
    │   ├── 02_joins_windows.sql
    │   ├── 03_tuning.sql
    │   ├── 04_star_schema.sql
    │   ├── 05_etl.sql
    │   └── 06_hardening.sql
    ├── logs/
    │   └── .gitkeep
    ├── notes.md
    └── connection_info.md
```

All executable lab scripts live in `sql/`; command output and validation logs
live in `logs/`. This is the project-local equivalent of the separate Lab 06
folder suggested by the upstream guide.

---

# Database Setup

The labs use a PostgreSQL database called `freshmart`.

## Create the database

If the database does not exist:

```bash
psql -U postgres -c "CREATE DATABASE freshmart;"
```

Verify that it exists:

```bash
psql -U postgres -l
```

You should see:

```text
freshmart
```

---

# Connect to the Database

Connect using:

```bash
psql -U postgres -d freshmart
```

You will be prompted for your PostgreSQL password.

Once connected, the terminal will look similar to:

```text
freshmart=#
```

---

# Running SQL Scripts

SQL scripts can be executed directly from Git Bash using `psql`.

## Run a SQL script

From the project root:

```bash
psql -U postgres -d freshmart -f /c/dataeng/sk02/sql/01_create_oltp.sql
```

General syntax:

```bash
psql -U <username> -d <database> -f <sql-file>
```

Example:

```bash
psql -U postgres -d freshmart -f ./sk02/sql/01_create_oltp.sql
```

---

## Run a script while connected to PostgreSQL

First connect:

```bash
psql -U postgres -d freshmart
```

Then execute:

```sql
\i '/c/dataeng/sk02/sql/01_create_oltp.sql'
```

---

# Verify the Script

After running the setup script, connect to the database:

```bash
psql -U postgres -d freshmart
```

List all tables:

```sql
\dt
```

Expected tables include:

```text
customers
stores
products
orders
order_lines
```

---

# Check Table Structure

To inspect a table:

```sql
\d customers
```

For more detailed information:

```sql
\d+ customers
```

Example:

```sql
\d orders
```

---

# Check Row Counts

Run:

```sql
SELECT COUNT(*) FROM customers;
```

Or check multiple tables at once:

```sql
SELECT
    (SELECT COUNT(*) FROM customers) AS customers,
    (SELECT COUNT(*) FROM stores) AS stores,
    (SELECT COUNT(*) FROM products) AS products,
    (SELECT COUNT(*) FROM orders) AS orders,
    (SELECT COUNT(*) FROM order_lines) AS order_lines;
```

---

# Run Queries

You can execute queries directly from the PostgreSQL terminal.

Example:

```sql
SELECT *
FROM customers
LIMIT 10;
```

Filtering:

```sql
SELECT first_name, country, score
FROM customers
WHERE score > 300;
```

Multiple conditions:

```sql
SELECT first_name, country, score
FROM customers
WHERE score > 450
  AND country = 'UK';
```

Using `IN`:

```sql
SELECT first_name, country, score
FROM customers
WHERE country IN ('USA', 'UK');
```

---

# Run SQL Without Entering PostgreSQL

You can execute a query directly from Git Bash.

Example:

```bash
psql -U postgres -d freshmart -c "SELECT COUNT(*) FROM customers;"
```

Another example:

```bash
psql -U postgres -d freshmart -c "SELECT * FROM customers LIMIT 10;"
```

This is useful for quick database checks and automation.

---

# Run Multiple SQL Scripts

If several scripts need to be executed:

```bash
psql -U postgres -d freshmart -f ./sk02/sql/01_create_oltp.sql
psql -U postgres -d freshmart -f ./sk02/sql/02_queries.sql
```

Or execute a script containing multiple SQL statements:

```bash
psql -U postgres -d freshmart -f ./sk02/sql/setup.sql
```

---

# Rerun / Reset the Database

If the SQL script is designed to be idempotent, it can safely be executed multiple times:

```bash
psql -U postgres -d freshmart -f ./sk02/sql/01_create_oltp.sql
```

If a complete database reset is required, drop and recreate the database.

### Drop database

First disconnect from `freshmart`:

```bash
psql -U postgres -c "DROP DATABASE freshmart;"
```

Create it again:

```bash
psql -U postgres -c "CREATE DATABASE freshmart;"
```

Then run the setup script:

```bash
psql -U postgres -d freshmart -f ./sk02/sql/01_create_oltp.sql
```

> Warning: Dropping the database permanently removes all data inside it.

---

# Useful PostgreSQL Commands

These commands are available inside `psql`.

| Command         | Purpose                    |
| --------------- | -------------------------- |
| `\l`            | List databases             |
| `\c freshmart`  | Connect to `freshmart`     |
| `\dt`           | List tables                |
| `\d customers`  | Describe a table           |
| `\d+ customers` | Detailed table information |
| `\dn`           | List schemas               |
| `\du`           | List users/roles           |
| `\conninfo`     | Show current connection    |
| `\q`            | Exit PostgreSQL            |

---

# Clear the Terminal

Inside `psql`:

```sql
\! clear
```

From Git Bash:

```bash
clear
```

On Windows Command Prompt:

```cmd
cls
```

---

# Export Query Results

Export a query result to CSV:

```bash
psql -U postgres -d freshmart -c "SELECT * FROM customers;" > customers.csv
```

For a larger query:

```bash
psql -U postgres -d freshmart -c "SELECT first_name, country, score FROM customers WHERE score > 300;" > high_score_customers.csv
```

---

# Execute SQL From a File

For a SQL file containing queries:

```bash
psql -U postgres -d freshmart -f ./sk02/sql/queries.sql
```

Save the output to a file:

```bash
psql -U postgres -d freshmart -f ./sk02/sql/queries.sql > output.txt
```

---

# FreshMart Database

The exercises use a fictional grocery company called **FreshMart**.

The database represents an operational OLTP system containing:

- Customers
- Stores
- Products
- Orders
- Order Lines

Relationship:

```text
Customers
    │
    │ customer_id
    ▼
 Orders ────────────── Stores
    │
    │ order_id
    ▼
Order Lines
    │
    │ product_id
    ▼
 Products
```

---

# Lab Sequence

Run the scripts in this order from `C:\dataeng`:

```bash
psql -U postgres -d freshmart -v ON_ERROR_STOP=1 -f ./sk02/sql/01_create_oltp.sql
psql -U postgres -d freshmart -v ON_ERROR_STOP=1 -f ./sk02/sql/02_joins_windows.sql
psql -U postgres -d freshmart -v ON_ERROR_STOP=1 -f ./sk02/sql/03_tuning.sql
psql -U postgres -d freshmart -v ON_ERROR_STOP=1 -f ./sk02/sql/04_star_schema.sql
psql -U postgres -d freshmart -v ON_ERROR_STOP=1 -f ./sk02/sql/05_etl.sql
psql -U postgres -d freshmart -v ON_ERROR_STOP=1 -f ./sk02/sql/06_hardening.sql
```

Lab 01 resets and reloads the OLTP source. Labs 03-06 should be run after the
preceding lab has completed. Lab 05 and the DDL portions of later scripts are
designed for reruns; use `ON_ERROR_STOP=1` in automation.

## Lab Artifacts

| Script                 | Focus                                                         |
| ---------------------- | ------------------------------------------------------------- |
| `01_create_oltp.sql`   | FreshMart source tables and generated data                    |
| `02_joins_windows.sql` | Joins, aggregation, CTEs, and window functions                |
| `03_tuning.sql`        | EXPLAIN, indexes, statistics, and a materialized view         |
| `04_star_schema.sql`   | `dw` dimensions, SCD2 plumbing, and `fact_sales`              |
| `05_etl.sql`           | Date/dimension loads, SCD2, HWM, idempotent facts, audit log  |
| `06_hardening.sql`     | Constraints, dead letters, staging validation, quality checks |

## Verification Queries

```sql
SELECT COUNT(*) FROM public.customers;
SELECT COUNT(*) FROM public.orders;
SELECT COUNT(*) FROM public.order_lines;
SELECT COUNT(*) FROM dw.fact_sales;
SELECT * FROM dw.etl_control;
```

The expected source shape is 8 stores, 25 products, 2,000 customers, 50,000
orders, and roughly 120,000-160,000 order lines. Random data means exact
counts and revenue vary between clean Lab 01 runs.

# Lab 01 - SQL Foundations

Topics covered:

- PostgreSQL environment setup
- Database and table creation
- DDL and DML
- Primary keys
- Foreign keys
- Constraints
- `SELECT`
- `WHERE`
- `ORDER BY`
- `LIMIT`
- `IN`
- `BETWEEN`
- `LIKE`
- `ILIKE`
- `NULL`
- `COALESCE`
- `CASE`
- Type casting
- `EXTRACT`
- Date and timestamp filtering
- SQL logical execution order
- `generate_series()`
- Idempotent SQL scripts

---

# SQL Logical Execution Order

SQL is written in:

```text
SELECT
FROM
WHERE
GROUP BY
HAVING
ORDER BY
LIMIT
```

But logically processed as:

```text
FROM
WHERE
GROUP BY
HAVING
SELECT
ORDER BY
LIMIT
```

This explains why a `SELECT` alias can normally be used in `ORDER BY` but not in `WHERE`.

---

# Safe Date Filtering

For timestamp columns, use a half-open date range:

```sql
SELECT *
FROM orders
WHERE order_ts >= '2025-01-01'
  AND order_ts < '2025-02-01';
```

This includes all timestamps from January 1 through January 31 without accidentally excluding records later on January 31.

---

# Working With NULL

Incorrect:

```sql
SELECT *
FROM customers
WHERE email = NULL;
```

Correct:

```sql
SELECT *
FROM customers
WHERE email IS NULL;
```

Use `COALESCE()` for fallback values:

```sql
SELECT
    full_name,
    COALESCE(email, '(no email on file)') AS contact
FROM customers;
```

---

# Working With Money

Use `NUMERIC` for financial values:

```sql
unit_price NUMERIC(10,2)
```

This provides exact decimal arithmetic and avoids many floating-point precision issues.

---

# Git Workflow

Check the current branch:

```bash
git branch
```

Check repository status:

```bash
git status
```

Add changes:

```bash
git add .
```

Commit:

```bash
git commit -m "feat: complete SQL lab exercises"
```

Push to the remote `main` branch:

```bash
git push origin main
```

Pull the latest changes:

```bash
git pull origin main
```

View commit history:

```bash
git log --oneline
```

---

# Recommended Workflow for Each Lab

### 1. Pull the latest repository changes

```bash
git pull origin main
```

### 2. Navigate to the project

```bash
cd /c/dataeng
```

### 3. Connect to PostgreSQL

```bash
psql -U postgres -d freshmart
```

### 4. Check the database

```sql
\dt
```

### 5. Run the lab SQL script

```bash
psql -U postgres -d freshmart -f ./sk02/sql/01_create_oltp.sql
```

### 6. Verify the results

```sql
SELECT COUNT(*) FROM customers;
```

### 7. Work through the exercises

Execute the queries in the lab and save useful solutions in the appropriate SQL file.

### 8. Check Git changes

```bash
git status
```

### 9. Commit your work

```bash
git add .
git commit -m "feat: complete Lab 01 SQL foundations"
```

### 10. Push

```bash
git push origin main
```

---

# Learning Outcomes

After completing the SQL Foundations lab, I should be able to:

- Create PostgreSQL databases and tables
- Define primary and foreign keys
- Apply database constraints
- Insert and generate test data
- Query relational data
- Filter and sort records
- Work correctly with `NULL`
- Use `COALESCE`
- Use `CASE`
- Work with dates and timestamps
- Understand SQL execution order
- Write reusable SQL scripts
- Create idempotent database setup scripts
- Execute SQL from the command line
- Verify database objects and data
- Use Git to track SQL development

---

# Progress

## SQL & Data Modeling Specialist

- [x] PostgreSQL environment setup
- [x] Lab 01 - SQL Foundations
- [x] Lab 02 - Joins, Aggregations, and Window Functions
- [x] Lab 03 - Advanced SQL and Query Tuning
- [x] Lab 04 - Dimensional Modeling
- [x] Lab 05 - Warehouse SQL ETL
- [x] Lab 06 - Data Quality and Production Hardening

---

## Author

**Israel Kwawu**

Data Engineering T-Shaped Program
SQL & Data Modeling Specialist
