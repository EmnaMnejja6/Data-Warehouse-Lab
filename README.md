# Data Warehouse Lab

A PostgreSQL data warehouse that combines CRM and ERP CSV data into bronze,
silver, and gold layers. The gold layer is a star schema (three dimensions and
one fact table) built for analysis.

## Architecture

![High-level data warehouse architecture](docs/high%20level%20architecture.jpg)

- **Bronze:** raw source data loaded into tables, no transformations.
- **Silver:** cleaned and standardized tables, with quality gates that stop the run on bad data.
- **Gold:** analysis-ready views arranged as a star schema.

## Data flow

![Data flow diagram](docs/Data%20Flow%20Diagram.jpg)

## Data integration

![Data integration model](docs/Data%20Integration%20Model.jpg)

## Star schema

![Gold-layer star schema](docs/star_schema.png)

`fact_sales` (one row per order line) connects to `dim_customers`, `dim_products`,
and `dim_date`. The date dimension is used three times, for order, shipping, and
due dates. Column details and relationships are in the
[data catalog](docs/data_catalog.md).

## Prerequisites

| Tool | Windows | Linux |
| --- | --- | --- |
| Docker with Compose v2 | [Docker Desktop](https://www.docker.com/products/docker-desktop/) (WSL 2 backend recommended) | Docker Engine plus the Compose plugin |
| Python 3.10+ (notebooks only) | [python.org](https://www.python.org/downloads/) installer, tick "Add python.exe to PATH" | `python3` and `python3-venv` from your package manager |
| Git | Git for Windows | `git` from your package manager |

Check your setup:

```sh
docker compose version
python --version      # on Linux you may need: python3 --version
```

## Getting started

### 1. Clone and start the database

Windows (PowerShell) and Linux (bash) use the same commands:

```sh
git clone https://github.com/EmnaMnejja6/Data-Warehouse-Lab.git
cd Data-Warehouse-Lab
docker compose up -d
docker compose ps
```

> **Linux:** if you get "permission denied" talking to the Docker daemon, add
> your user to the `docker` group (`sudo usermod -aG docker $USER`, then log out
> and back in) or prefix the commands with `sudo`.

Services:

- PostgreSQL: `localhost:5433`
- pgAdmin: `http://localhost:5050` (login: `admin@example.com`, password: `postgres`)

The CSV files are mounted read-only in the PostgreSQL container under `/datasets`.

### 2. Connect

The easiest way is pgAdmin in your browser. When you register the server in
pgAdmin, use the **service name from `compose.yml`** as the host (not
`localhost`), because pgAdmin runs inside Docker. Any other client on your own
machine connects to `localhost:5433`.

If you have `psql` installed you can also use:

```sh
psql -h localhost -p 5433 -U postgres -d datawarehouse
```

### 3. Build the layers

Run the files in [scripts/](scripts/) in this order. Use the pgAdmin **Query
Tool** (open the file, press F5) or `psql -f <file>`.

| Step | File | What it does |
| --- | --- | --- |
| 1 | database and schema setup script | Creates the `datawarehouse` database and the `bronze`, `silver`, `gold` schemas |
| 2 | `ddl_bronze.sql` | Creates the bronze tables |
| 3 | `proc_load_bronze.sql` | Creates the loader; then run `CALL bronze.load_bronze();` |
| 4 | `ddl_silver.sql` | Creates the silver tables |
| 5 | `load_silver.ipynb` | Cleans bronze into silver and runs the silver quality gates |
| 6 | `load_gold.ipynb` | Creates the gold views from `ddl_gold.sql` and runs the gold quality gates |

> Re-running step 4 after gold exists fails because the gold views depend on the
> silver tables. Drop the gold views first (`ddl_gold.sql` does this when run
> alone), or use `DROP TABLE ... CASCADE` and rebuild gold afterwards.

### 4. Run the notebooks

Create a virtual environment and install the dependencies.

**Windows (PowerShell):**

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install pandas sqlalchemy psycopg2-binary jupyter
$env:DW_URL = "postgresql+psycopg2://postgres:postgres@localhost:5433/datawarehouse"
jupyter notebook
```

If PowerShell blocks the activation script, run
`Set-ExecutionPolicy -Scope Process RemoteSigned` once in that window. In
Command Prompt, activate with `.venv\Scripts\activate.bat` and set the variable
with `set DW_URL=...`.

**Linux / macOS (bash):**

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install pandas sqlalchemy psycopg2-binary jupyter
export DW_URL="postgresql+psycopg2://postgres:postgres@localhost:5433/datawarehouse"
jupyter notebook
```

Adjust the user, password, and database name in `DW_URL` if they differ in your
`compose.yml`. Open the notebooks from the folder that holds the SQL files they
read (for example `ddl_gold.sql`), since they load them by relative path.

## Using the gold layer

Business questions become simple joins:

```sql
SELECT d.year, p.category, SUM(f.sales_amount) AS revenue
FROM gold.fact_sales f
JOIN gold.dim_date     d ON f.order_date_key = d.date_key
JOIN gold.dim_products p ON f.product_key    = p.product_key
GROUP BY d.year, p.category
ORDER BY d.year, revenue DESC;
```

## Quality gates

Gold is made of views, so keys and row counts are not enforced by the database.
`load_gold.ipynb` checks them instead:

- Dimension keys are unique and there is no join fan-out.
- `dim_date` has no gaps and covers every date in the fact.
- `fact_sales` matches silver in row count and total revenue.
- Every foreign key points to an existing dimension row.
- Orphan rows and invalid dates are reported as warnings.

A failing hard gate stops the run, so a passing notebook means the layer is consistent.

## Troubleshooting

- **Port 5433 or 5050 already in use:** change the left side of the port mapping in `compose.yml`, or stop the other service.
- **`COPY` cannot find a CSV file:** paths inside the container are case-sensitive on Linux (`LOC_A101.csv`, not `loc_a101.csv`). Make sure the `datasets/` folder is mounted at `/datasets`.
- **Notebook cannot connect:** confirm `docker compose ps` shows the database as running and that `DW_URL` uses port `5433`.
- **Start fresh:** `docker compose down -v` removes the containers and the database volume (all loaded data is deleted).

## Project layout

- `datasets/`: CRM and ERP source CSV files
- `scripts/`: database setup and bronze, silver, and gold SQL and notebook files
- `docs/`: architecture diagrams and the [data catalog](docs/data_catalog.md)

## Acknowledgments

This project follows the data warehouse course by **Data With Baraa**. The
source CRM and ERP datasets come from his tutorial.
My changes: ported the SQL to PostgreSQL and Docker, replaced the silver
transformations with a Python notebook that includes quality gates, and added
`dim_date` plus gold-layer validation.