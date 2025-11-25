-- =====================================================
-- CREATE LOGICAL REPLICATION SLOT (SAFE/IDEMPOTENT)
-- =====================================================
-- This script safely creates the logical replication slot
-- only when wal_level=logical is enabled

DO $$
DECLARE
    v_wal_level text;
BEGIN
    SELECT setting INTO v_wal_level FROM pg_settings WHERE name = 'wal_level';
    
    IF v_wal_level = 'logical' THEN
        IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'reports_slot') THEN
            PERFORM pg_create_logical_replication_slot('reports_slot', 'pgoutput');
            RAISE NOTICE 'Created logical replication slot: reports_slot';
        ELSE
            RAISE NOTICE 'Logical replication slot reports_slot already exists - skipping';
        END IF;
    ELSE
        RAISE NOTICE 'wal_level is % - skipping logical slot creation', v_wal_level;
    END IF;
EXCEPTION WHEN others THEN
    RAISE NOTICE 'Failed to create logical slot (non-fatal in init): %', SQLERRM;
END;
$$;
