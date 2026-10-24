# Data Catalog: Gold Layer

The gold layer is the consumption interface of the warehouse: a star schema with three dimensions
and one fact, exposed as views over silver. Query gold, not silver.

![Gold-layer star schema](star_schema.png)

## gold.dim_customers

One row per customer (18,484 rows). Integrates CRM master data with ERP demographics and location.

| Column | Type | Description |
| --- | --- | --- |
| `customer_key` | bigint | Surrogate key (`ROW_NUMBER()` over `cst_id`). Join key for `fact_sales`. |
| `customer_id` | int | Business id from the CRM (`cst_id`). |
| `customer_number` | varchar | Alphanumeric CRM key (`AW…`), used to join the ERP sources. |
| `first_name` / `last_name` | varchar | Trimmed customer names. |
| `country` | varchar | From ERP locations; decoded (`US`/`USA` → `United States`, `DE` → `Germany`), `n/a` when unknown. |
| `marital_status` | varchar | `Single` · `Married` · `n/a`. |
| `gender` | varchar | `Female` · `Male` · `n/a`. CRM is the master; ERP fills gaps. |
| `birthdate` | date | From ERP; future birthdates removed as data-entry errors. |
| `create_date` | date | Customer record creation date in the CRM. |

## gold.dim_products

One row per **current** product version (295 rows; historical versions are filtered out).

| Column | Type | Description |
| --- | --- | --- |
| `product_key` | bigint | Surrogate key (`ROW_NUMBER()` over start date + product key). Join key for `fact_sales`. |
| `product_id` | int | Business id from the CRM (`prd_id`). |
| `product_number` | varchar | Product key as used by sales order lines. |
| `product_name` | varchar | Descriptive name. |
| `category_id` | varchar | First 5 chars of the raw key, normalized to the ERP format. |
| `category` / `subcategory` | varchar | From the ERP category table (`Bikes`, `Accessories`, `Clothing`). |
| `maintenance` | varchar | Whether the product requires maintenance (`Yes`/`No`). |
| `cost` | int | Standard cost; missing costs default to 0. |
| `product_line` | varchar | `Mountain` · `Road` · `Touring` · `Other Sales` · `n/a`. |
| `start_date` | date | Start of the current product version. |

## gold.dim_date

One row per calendar day, from 1 January of the earliest year to 31 December of the latest year found
in the sales dates, so every fact date is covered and years are complete.

| Column | Type | Description |
| --- | --- | --- |
| `date_key` | int | Surrogate key as `YYYYMMDD` (e.g. `20101229`). Join key for the three date keys in `fact_sales`. |
| `full_date` | date | The calendar date. |
| `year` | int | Calendar year. |
| `quarter` | int | 1–4. |
| `month` | int | 1–12. |
| `month_name` | text | `January` … `December`. |
| `day` | int | Day of the month. |
| `day_of_week` | int | ISO weekday: 1 = Monday … 7 = Sunday. |
| `day_name` | text | `Monday` … `Sunday`. |
| `week_of_year` | int | ISO week number. |
| `is_weekend` | boolean | `true` for Saturday and Sunday. |

## gold.fact_sales

**Grain: one row per order line** (60,398 rows). Reconciles 1:1 in rows and revenue with silver
(checked by the gold gates in `load_gold.ipynb`).

| Column | Type | Description |
| --- | --- | --- |
| `order_number` | varchar | Sales order id (`SO…`); orders have 1..n lines. |
| `product_key` | bigint | FK → `dim_products.product_key`. `NULL` when the product is not in the dimension. |
| `customer_key` | bigint | FK → `dim_customers.customer_key`. `NULL` when the customer is not in the dimension. |
| `order_date_key` | int | FK → `dim_date.date_key`. `NULL` when the order date is invalid. |
| `shipping_date_key` | int | FK → `dim_date.date_key`. |
| `due_date_key` | int | FK → `dim_date.date_key`. |
| `order_date` | date | Order date; invalid source values (`0`, malformed) are `NULL`, never fake dates. |
| `shipping_date` / `due_date` | date | Fulfilment dates; never before `order_date` (gate S08). |
| `sales_amount` | int | Line revenue. Enforced: `sales_amount = quantity × price` (gate S09). |
| `quantity` | int | Units in the line. |
| `price` | int | Unit price. |

## Relationships

All relationships are one-to-many: one dimension row can appear on many fact rows, and a fact row
points to at most one row per dimension role.

| Fact column | Dimension | Join |
| --- | --- | --- |
| `product_key` | `dim_products.product_key` | `fact_sales` is built from `sls_prd_key = product_number` |
| `customer_key` | `dim_customers.customer_key` | `fact_sales` is built from `sls_cust_id = customer_id` |
| `order_date_key` | `dim_date.date_key` | same `YYYYMMDD` integer |
| `shipping_date_key` | `dim_date.date_key` | same |
| `due_date_key` | `dim_date.date_key` | same |

`dim_date` is a role-playing dimension: choose the role by choosing which key you join on. To compare
two roles in one query, join `dim_date` twice with different aliases.

## Design notes and limitations

- **Views, not tables.** Keys and relationships are not enforced by the database; `load_gold.ipynb` checks them.
- **Surrogate keys are regenerated on every query.** They are stable only while the underlying data is unchanged (a new customer with a lower `cst_id` shifts later keys). Materialize the views before persisting keys anywhere.
- **Products use the current version only.** A sale of an older product version is reported with today's cost and name (no point-in-time history).
- **Orphans keep their row.** Sales without a matching customer or product stay in the fact with a `NULL` key and are reported as warnings by the gold gates.