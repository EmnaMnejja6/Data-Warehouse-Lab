/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    Loads data into the 'bronze' schema from the CSV files mounted in the
    Postgres container at /datasets. For each table it:
    - Truncates the table.
    - Loads the CSV with COPY.

Parameters:
    None.

Usage Example:
    CALL bronze.load_bronze();

Note:
    Paths are container paths (see the ./datasets:/datasets:ro mount in
    compose.yml). File names are case-sensitive on Linux.
===============================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS $$
DECLARE
    rec              RECORD;
    start_time       TIMESTAMPTZ;
    batch_start_time TIMESTAMPTZ := clock_timestamp();
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Loading Bronze Layer';
    RAISE NOTICE '================================================';

    FOR rec IN
        SELECT * FROM (VALUES
            ('bronze.crm_cust_info',     '/datasets/source_crm/cust_info.csv'),
            ('bronze.crm_prd_info',      '/datasets/source_crm/prd_info.csv'),
            ('bronze.crm_sales_details', '/datasets/source_crm/sales_details.csv'),
            ('bronze.erp_loc_a101',      '/datasets/source_erp/LOC_A101.csv'),
            ('bronze.erp_cust_az12',     '/datasets/source_erp/CUST_AZ12.csv'),
            ('bronze.erp_px_cat_g1v2',   '/datasets/source_erp/PX_CAT_G1V2.csv')
        ) AS t(tbl, path)
    LOOP
        start_time := clock_timestamp();

        RAISE NOTICE '>> Truncating Table: %', rec.tbl;
        EXECUTE format('TRUNCATE TABLE %s', rec.tbl);

        RAISE NOTICE '>> Inserting Data Into: %', rec.tbl;
        EXECUTE format('COPY %s FROM %L WITH (FORMAT csv, HEADER true)', rec.tbl, rec.path);

        RAISE NOTICE '>> Load Duration: % seconds',
            round(EXTRACT(EPOCH FROM clock_timestamp() - start_time)::numeric, 2);
        RAISE NOTICE '>> -------------';
    END LOOP;

    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Loading Bronze Layer is Completed';
    RAISE NOTICE '   - Total Load Duration: % seconds',
        round(EXTRACT(EPOCH FROM clock_timestamp() - batch_start_time)::numeric, 2);
    RAISE NOTICE '==========================================';
END;
$$;