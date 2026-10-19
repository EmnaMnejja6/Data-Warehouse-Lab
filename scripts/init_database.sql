/*
===============================================================================
Init: Create Warehouse Schemas
===============================================================================
Purpose:
    Creates the three medallion layers (bronze, silver, gold) as schemas
    inside the 'datawarehouse' database.

Prerequisite:
    The 'datawarehouse' database was created manually first (via the pgAdmin
    UI), so this script does not create or drop the database itself. Make
    sure the Query Tool is connected to 'datawarehouse' (not 'postgres')
    before running it.

WARNING:
    Re-running this script DROPS the three schemas and everything in them.
    That is intentional: the whole warehouse rebuilds from the CSVs, so a
    from-scratch run is always possible.
===============================================================================
*/

DROP SCHEMA IF EXISTS bronze CASCADE;
DROP SCHEMA IF EXISTS silver CASCADE;
DROP SCHEMA IF EXISTS gold CASCADE;

CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;