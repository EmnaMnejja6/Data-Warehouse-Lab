/*
===============================================================================
DDL: Gold Views (Star Schema)
===============================================================================
Purpose:
    Business-ready dimensional model over silver: three dimensions and one fact,
    exposed as views. Grain of fact_sales: one row per order line.

    Views instead of tables: cheap to rebuild, nothing to drift out of date.
    Materialize only if volume ever demands it.

    dim_date is a role-playing dimension: fact_sales carries three date keys
    (order, shipping, due) that all point to the same dim_date.date_key.
    date_key is the integer YYYYMMDD (e.g. 20101229). A NULL date in the
    fact gives a NULL date key, never a fake date.
===============================================================================
*/

-- Drop dependants first (fact depends on both dimensions)
DROP VIEW IF EXISTS gold.fact_sales;
DROP VIEW IF EXISTS gold.dim_date;
DROP VIEW IF EXISTS gold.dim_customers;
DROP VIEW IF EXISTS gold.dim_products;

-- =============================================================================
-- Dimension: gold.dim_customers
-- =============================================================================
CREATE VIEW gold.dim_customers AS
SELECT
    -- surrogate key; ordering by cst_id keeps it deterministic for the same data
    ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key,
    ci.cst_id             AS customer_id,
    ci.cst_key            AS customer_number,
    ci.cst_firstname      AS first_name,
    ci.cst_lastname       AS last_name,
    la.cntry              AS country,
    ci.cst_marital_status AS marital_status,
    CASE
        WHEN ci.cst_gndr <> 'n/a' THEN ci.cst_gndr   -- CRM is the master for gender
        ELSE COALESCE(ca.gen, 'n/a')                 -- ERP fills the gaps
    END                   AS gender,
    ca.bdate              AS birthdate,
    ci.cst_create_date    AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101  la ON ci.cst_key = la.cid;

-- =============================================================================
-- Dimension: gold.dim_products
-- =============================================================================
CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,
    pn.prd_id       AS product_id,
    pn.prd_key      AS product_number,
    pn.prd_nm       AS product_name,
    pn.cat_id       AS category_id,
    pc.cat          AS category,
    pc.subcat       AS subcategory,
    pc.maintenance  AS maintenance,
    pn.prd_cost     AS cost,
    pn.prd_line     AS product_line,
    pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL;   -- current version of each product only

-- =============================================================================
-- Dimension: gold.dim_date  (one row per calendar day)
-- Range: 1 January of the earliest year to 31 December of the latest year
-- found in the sales dates, so every fact date is covered and years are whole.
-- =============================================================================
CREATE VIEW gold.dim_date AS
WITH all_dates AS (
    SELECT sls_order_dt AS d FROM silver.crm_sales_details
    UNION ALL
    SELECT sls_ship_dt       FROM silver.crm_sales_details
    UNION ALL
    SELECT sls_due_dt        FROM silver.crm_sales_details
),
bounds AS (
    SELECT
        date_trunc('year', MIN(d))::date                                   AS start_d,
        (date_trunc('year', MAX(d)) + INTERVAL '1 year - 1 day')::date     AS end_d
    FROM all_dates
)
SELECT
    TO_CHAR(g.d, 'YYYYMMDD')::int          AS date_key,
    g.d                                    AS full_date,
    EXTRACT(YEAR    FROM g.d)::int         AS year,
    EXTRACT(QUARTER FROM g.d)::int         AS quarter,
    EXTRACT(MONTH   FROM g.d)::int         AS month,
    TO_CHAR(g.d, 'FMMonth')                AS month_name,
    EXTRACT(DAY     FROM g.d)::int         AS day,
    EXTRACT(ISODOW  FROM g.d)::int         AS day_of_week,     -- 1 = Monday ... 7 = Sunday
    TO_CHAR(g.d, 'FMDay')                  AS day_name,
    EXTRACT(WEEK    FROM g.d)::int         AS week_of_year,    -- ISO week
    (EXTRACT(ISODOW FROM g.d) IN (6, 7))   AS is_weekend
FROM bounds b
CROSS JOIN LATERAL (
    SELECT gs::date AS d
    FROM generate_series(b.start_d, b.end_d, INTERVAL '1 day') AS gs
) g;

-- =============================================================================
-- Fact: gold.fact_sales  (grain: one row per order line)
-- =============================================================================
CREATE VIEW gold.fact_sales AS
SELECT
    sd.sls_ord_num  AS order_number,
    pr.product_key,
    cu.customer_key,
    TO_CHAR(sd.sls_order_dt, 'YYYYMMDD')::int AS order_date_key,     -- FK -> dim_date
    TO_CHAR(sd.sls_ship_dt,  'YYYYMMDD')::int AS shipping_date_key,  -- FK -> dim_date
    TO_CHAR(sd.sls_due_dt,   'YYYYMMDD')::int AS due_date_key,       -- FK -> dim_date
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt  AS shipping_date,
    sd.sls_due_dt   AS due_date,
    sd.sls_sales    AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price    AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products  pr ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu ON sd.sls_cust_id = cu.customer_id;