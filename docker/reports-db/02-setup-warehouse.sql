-- =====================================================
-- INITIALIZE REPORTS DATABASE (OLAP)
-- =====================================================

\echo 'Setting up reports/warehouse database...'

-- First, create the OLTP schema to receive replicated data
\i /docker-entrypoint-initdb.d/flights_oltp_schema.sql

-- Create subscription to primary database for logical replication
-- This will start replicating data from the primary database
CREATE SUBSCRIPTION reports_subscription
    CONNECTION 'host=primary_db port=5432 dbname=flight_booking user=replicator password=replicator_password'
    PUBLICATION reports_publication
    WITH (copy_data = true, create_slot = false, slot_name = 'reports_slot');

\echo 'Logical replication subscription created.'
\echo 'Waiting a moment for initial data sync...'

-- Wait for initial sync (in production, you'd monitor this)
SELECT pg_sleep(5);

\echo 'Creating warehouse schema for analytics...'

-- Create the data warehouse schema
\i /docker-entrypoint-initdb.d/ddl_warehouse_schema.sql

\echo 'Creating ETL functions and procedures...'

-- Create ETL procedures
\i /docker-entrypoint-initdb.d/etl_dimensions.sql
\i /docker-entrypoint-initdb.d/etl_facts.sql
\i /docker-entrypoint-initdb.d/etl_master_pipeline.sql

\echo 'Running initial ETL to populate warehouse...'

-- Run initial ETL to populate the warehouse
-- The ETL master pipeline is a DO block that executes automatically
\i /docker-entrypoint-initdb.d/etl_master_pipeline.sql

\echo 'Reports database initialization complete!'
\echo 'OLTP tables are being replicated from primary.'
\echo 'Warehouse schema is ready for analytical queries.'
