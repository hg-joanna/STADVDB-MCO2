-- =====================================================
-- INITIALIZE PRIMARY DATABASE (OLTP)
-- =====================================================

-- Create replication user
CREATE ROLE replicator WITH REPLICATION PASSWORD 'replicator_password' LOGIN;

-- Grant necessary permissions
GRANT CONNECT ON DATABASE flight_booking TO replicator;
GRANT USAGE ON SCHEMA public TO replicator;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO replicator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO replicator;

-- Create OLTP schema
\i /docker-entrypoint-initdb.d/flights_oltp_schema.sql

-- Load sample data
\i /docker-entrypoint-initdb.d/db_data.sql

-- Create publication for logical replication to reports database
CREATE PUBLICATION reports_publication FOR ALL TABLES;

-- Create replication slot for hot backup (physical replication)
SELECT pg_create_physical_replication_slot('hot_backup_slot');

-- Create replication slot for reports database (logical replication)
-- Note: This will be used by the reports_db subscription
SELECT pg_create_logical_replication_slot('reports_slot', 'pgoutput');

-- Grant replication permissions
GRANT USAGE ON SCHEMA public TO replicator;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO replicator;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO replicator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO replicator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO replicator;

-- Success message
\echo 'Primary database initialization complete!'
\echo 'Publications and replication slots created.'
