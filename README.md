# Data Warehouse Lab

A PostgreSQL data warehouse that combines CRM and ERP CSV data into bronze,
silver, and gold layers. The gold layer provides customer and product
dimensions and a sales fact table for analysis.

## Architecture

![High-level data warehouse architecture](docs/high%20level%20architecture.jpg)

- **Bronze:** Raw source data loaded into tables.
- **Silver:** Cleaned and transformed data.
- **Gold:** Analysis-ready views arranged as a star schema.

## Data flow

![Data flow diagram](docs/Data%20Flow%20Diagram.jpg)

## Data integration

![Data integration model](docs/Data%20Integration%20Model.jpg)

## Star schema

![Gold-layer star schema](docs/star%20schema.jpg)

## Getting started

Start PostgreSQL and pgAdmin with Docker Compose:

```sh
docker compose up -d
```

Services:

- PostgreSQL: `localhost:5433`
- pgAdmin: `http://localhost:5050` (login: `admin@example.com`, password: `postgres`)

The CSV files are available to the PostgreSQL container under `/datasets`.
See [scripts](scripts/) for the database setup and loading SQL, and
[docs/data_catalog.md](docs/data_catalog.md) for the gold-layer tables.

## Project layout

- `datasets/` — CRM and ERP source CSV files
- `scripts/` — database setup and bronze, silver, and gold SQL/notebook files
- `docs/` — architecture diagrams and data catalog
