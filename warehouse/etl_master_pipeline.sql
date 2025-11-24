-- =====================================================
-- MASTER ETL ORCHESTRATION SCRIPT
-- Complete Daily ETL Pipeline
-- =====================================================

-- This script orchestrates the complete ETL process:
-- 1. Validates prerequisites
-- 2. Loads dimensions (order matters!)
-- 3. Loads facts with surrogate key mapping
-- 4. Updates derived metrics
-- 5. Performs data quality checks
-- 6. Updates metadata

-- =====================================================
-- CONFIGURATION
-- =====================================================

-- Set batch size for large tables (prevents memory issues)
DO $$
DECLARE
    v_batch_size INT := 10000;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
    v_total_records INT := 0;
    v_error_count INT := 0;
BEGIN
    v_start_time := NOW();
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ETL Pipeline Started: %', v_start_time;
    RAISE NOTICE '========================================';

    -- =====================================================
    -- STEP 0: PRE-FLIGHT CHECKS
    -- =====================================================
    RAISE NOTICE '[STEP 0] Running pre-flight checks...';
    
    -- Check if source tables exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customers') THEN
        RAISE EXCEPTION 'Source table customers not found';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'flights') THEN
        RAISE EXCEPTION 'Source table flights not found';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bookings') THEN
        RAISE EXCEPTION 'Source table bookings not found';
    END IF;
    
    -- Check if warehouse tables exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'fact_bookings') THEN
        RAISE EXCEPTION 'Warehouse table fact_bookings not found. Run ddl_warehouse_schema.sql first.';
    END IF;
    
    RAISE NOTICE '[STEP 0] ✓ Pre-flight checks passed';

    -- =====================================================
    -- STEP 1: LOAD DIMENSION TABLES
    -- =====================================================
    RAISE NOTICE '[STEP 1] Loading dimension tables...';
    
    -- 1.1: Load dim_route (foundation for dim_flight)
    RAISE NOTICE '[STEP 1.1] Loading dim_route...';
    INSERT INTO dim_route (origin, destination, route_code, region)
    SELECT DISTINCT
        f.origin,
        f.destination,
        CONCAT(LEFT(f.origin, 3), '-', LEFT(f.destination, 3)) AS route_code,
        'Domestic' AS region
    FROM flights f
    ON CONFLICT (origin, destination) DO NOTHING;
    
    GET DIAGNOSTICS v_total_records = ROW_COUNT;
    RAISE NOTICE '[STEP 1.1] ✓ dim_route: % new records', v_total_records;
    
    -- 1.2: Load dim_customer (SCD Type 1)
    RAISE NOTICE '[STEP 1.2] Loading dim_customer...';
    INSERT INTO dim_customer (customer_id, full_name, email, phone, created_at, updated_at)
    SELECT customer_id, full_name, email, phone, NOW(), NOW()
    FROM customers
    ON CONFLICT (customer_id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        phone = EXCLUDED.phone,
        updated_at = NOW();
    
    GET DIAGNOSTICS v_total_records = ROW_COUNT;
    RAISE NOTICE '[STEP 1.2] ✓ dim_customer: % records processed', v_total_records;
    
    -- 1.3: Load dim_flight (depends on dim_route)
    RAISE NOTICE '[STEP 1.3] Loading dim_flight...';
    INSERT INTO dim_flight (
        flight_id, flight_number, route_key, departure_time, arrival_time,
        flight_duration_minutes, departure_hour, departure_day_of_week, is_weekend_flight,
        created_at, updated_at
    )
    SELECT
        f.flight_id,
        f.flight_number,
        dr.route_key,
        f.departure_time,
        f.arrival_time,
        EXTRACT(EPOCH FROM (f.arrival_time - f.departure_time)) / 60,
        EXTRACT(HOUR FROM f.departure_time)::INT,
        EXTRACT(ISODOW FROM f.departure_time)::INT,
        CASE WHEN EXTRACT(ISODOW FROM f.departure_time) IN (6, 7) THEN TRUE ELSE FALSE END,
        NOW(),
        NOW()
    FROM flights f
    LEFT JOIN dim_route dr ON f.origin = dr.origin AND f.destination = dr.destination
    ON CONFLICT (flight_id) DO UPDATE SET
        flight_number = EXCLUDED.flight_number,
        departure_time = EXCLUDED.departure_time,
        arrival_time = EXCLUDED.arrival_time,
        flight_duration_minutes = EXCLUDED.flight_duration_minutes,
        updated_at = NOW();
    
    GET DIAGNOSTICS v_total_records = ROW_COUNT;
    RAISE NOTICE '[STEP 1.3] ✓ dim_flight: % records processed', v_total_records;
    
    -- 1.4: Load dim_seat
    RAISE NOTICE '[STEP 1.4] Loading dim_seat...';
    INSERT INTO dim_seat (seat_id, seat_number, seat_class, is_window_seat, is_aisle_seat, seat_row, created_at)
    SELECT
        seat_id,
        seat_number,
        seat_class,
        CASE WHEN RIGHT(seat_number, 1) IN ('A', 'F') THEN TRUE ELSE FALSE END,
        CASE WHEN RIGHT(seat_number, 1) IN ('C', 'D') THEN TRUE ELSE FALSE END,
        SUBSTRING(seat_number FROM '^\d+')::INT,
        NOW()
    FROM seats
    ON CONFLICT (seat_id) DO NOTHING;
    
    GET DIAGNOSTICS v_total_records = ROW_COUNT;
    RAISE NOTICE '[STEP 1.4] ✓ dim_seat: % new records', v_total_records;
    
    RAISE NOTICE '[STEP 1] ✓ All dimensions loaded successfully';
    
    -- =====================================================
    -- STEP 2: LOAD FACT TABLES
    -- =====================================================
    RAISE NOTICE '[STEP 2] Loading fact tables...';
    
    -- 2.1: Load fact_bookings (incremental)
    RAISE NOTICE '[STEP 2.1] Loading fact_bookings (incremental)...';
    INSERT INTO fact_bookings (
        customer_key, flight_key, seat_key, booking_date_key, departure_date_key,
        booking_id, booking_reference, booking_item_id, price, is_cancelled,
        booking_to_departure_days, booking_hour, booked_at, etl_loaded_at
    )
    SELECT
        dc.customer_key,
        df.flight_key,
        ds.seat_key,
        TO_CHAR(b.booked_at, 'YYYYMMDD')::INT,
        TO_CHAR(f.departure_time, 'YYYYMMDD')::INT,
        b.booking_id,
        b.booking_reference,
        bi.booking_item_id,
        bi.price,
        CASE WHEN b.status = 'CANCELLED' THEN TRUE ELSE FALSE END,
        EXTRACT(DAY FROM (f.departure_time - b.booked_at))::INT,
        EXTRACT(HOUR FROM b.booked_at)::INT,
        b.booked_at,
        NOW()
    FROM booking_items bi
    INNER JOIN bookings b ON bi.booking_id = b.booking_id
    INNER JOIN seats s ON bi.seat_id = s.seat_id
    INNER JOIN flights f ON s.flight_id = f.flight_id
    INNER JOIN dim_customer dc ON b.customer_id = dc.customer_id
    INNER JOIN dim_flight df ON f.flight_id = df.flight_id
    INNER JOIN dim_seat ds ON s.seat_id = ds.seat_id
    WHERE
        b.booked_at > (
            SELECT COALESCE(last_etl_timestamp, '1970-01-01'::TIMESTAMP)
            FROM etl_metadata 
            WHERE table_name = 'fact_bookings'
        )
    ON CONFLICT (booking_item_id) DO NOTHING;
    
    GET DIAGNOSTICS v_total_records = ROW_COUNT;
    RAISE NOTICE '[STEP 2.1] ✓ fact_bookings: % new records', v_total_records;
    
    -- Update metadata for fact_bookings
    UPDATE etl_metadata SET
        last_etl_timestamp = v_start_time,
        records_processed = v_total_records,
        status = 'SUCCESS',
        error_message = NULL
    WHERE table_name = 'fact_bookings';
    
    -- 2.2: Load fact_seat_inventory (daily snapshot)
    RAISE NOTICE '[STEP 2.2] Loading fact_seat_inventory (daily snapshot)...';
    
    -- Delete today's snapshot if exists (idempotent)
    DELETE FROM fact_seat_inventory WHERE snapshot_date = CURRENT_DATE;
    
    -- Insert fresh snapshot
    INSERT INTO fact_seat_inventory (
        flight_key, seat_key, snapshot_date_key, snapshot_date,
        is_available, is_booked, days_until_departure, etl_loaded_at
    )
    SELECT
        df.flight_key,
        ds.seat_key,
        TO_CHAR(CURRENT_DATE, 'YYYYMMDD')::INT,
        CURRENT_DATE,
        s.is_available,
        NOT s.is_available,
        EXTRACT(DAY FROM (f.departure_time - CURRENT_TIMESTAMP))::INT,
        NOW()
    FROM seats s
    INNER JOIN flights f ON s.flight_id = f.flight_id
    INNER JOIN dim_flight df ON f.flight_id = df.flight_id
    INNER JOIN dim_seat ds ON s.seat_id = ds.seat_id
    WHERE f.departure_time > CURRENT_TIMESTAMP;
    
    GET DIAGNOSTICS v_total_records = ROW_COUNT;
    RAISE NOTICE '[STEP 2.2] ✓ fact_seat_inventory: % snapshot records', v_total_records;
    
    -- Update metadata for fact_seat_inventory
    UPDATE etl_metadata SET
        last_etl_timestamp = v_start_time,
        records_processed = v_total_records,
        status = 'SUCCESS',
        error_message = NULL
    WHERE table_name = 'fact_seat_inventory';
    
    RAISE NOTICE '[STEP 2] ✓ All fact tables loaded successfully';
    
    -- =====================================================
    -- STEP 3: UPDATE DERIVED METRICS
    -- =====================================================
    RAISE NOTICE '[STEP 3] Updating derived metrics...';
    
    -- 3.1: Update customer aggregates
    RAISE NOTICE '[STEP 3.1] Updating customer metrics...';
    UPDATE dim_customer dc SET
        first_booking_date = subq.first_booking,
        total_bookings = subq.booking_count,
        total_spent = subq.total_revenue
    FROM (
        SELECT
            fb.customer_key,
            MIN(dd.full_date) AS first_booking,
            COUNT(DISTINCT fb.booking_id) AS booking_count,
            COALESCE(SUM(fb.price), 0) AS total_revenue
        FROM fact_bookings fb
        JOIN dim_date dd ON fb.booking_date_key = dd.date_key
        WHERE fb.is_cancelled = FALSE
        GROUP BY fb.customer_key
    ) AS subq
    WHERE dc.customer_key = subq.customer_key;
    
    -- 3.2: Update customer segments
    UPDATE dim_customer SET
        customer_segment = CASE
            WHEN total_spent >= 50000 THEN 'VIP'
            WHEN total_bookings >= 5 THEN 'Regular'
            WHEN total_bookings > 1 THEN 'Occasional'
            ELSE 'One-time'
        END;
    
    RAISE NOTICE '[STEP 3] ✓ Derived metrics updated';
    
    -- =====================================================
    -- STEP 4: DATA QUALITY CHECKS
    -- =====================================================
    RAISE NOTICE '[STEP 4] Running data quality checks...';
    
    -- 4.1: Check for orphaned bookings
    SELECT COUNT(*) INTO v_error_count
    FROM fact_bookings fb
    LEFT JOIN dim_customer dc ON fb.customer_key = dc.customer_key
    WHERE dc.customer_key IS NULL;
    
    IF v_error_count > 0 THEN
        RAISE WARNING '[STEP 4.1] ⚠ Found % orphaned bookings (no customer)', v_error_count;
    ELSE
        RAISE NOTICE '[STEP 4.1] ✓ No orphaned bookings';
    END IF;
    
    -- 4.2: Check for missing date keys
    SELECT COUNT(*) INTO v_error_count
    FROM fact_bookings fb
    LEFT JOIN dim_date dd ON fb.booking_date_key = dd.date_key
    WHERE dd.date_key IS NULL;
    
    IF v_error_count > 0 THEN
        RAISE WARNING '[STEP 4.2] ⚠ Found % bookings with missing date keys', v_error_count;
    ELSE
        RAISE NOTICE '[STEP 4.2] ✓ All date keys valid';
    END IF;
    
    -- 4.3: Check for negative lead times
    SELECT COUNT(*) INTO v_error_count
    FROM fact_bookings
    WHERE booking_to_departure_days < 0;
    
    IF v_error_count > 0 THEN
        RAISE WARNING '[STEP 4.3] ⚠ Found % bookings with negative lead time', v_error_count;
    ELSE
        RAISE NOTICE '[STEP 4.3] ✓ All lead times valid';
    END IF;
    
    RAISE NOTICE '[STEP 4] ✓ Data quality checks completed';
    
    -- =====================================================
    -- STEP 5: CLEANUP & FINALIZATION
    -- =====================================================
    RAISE NOTICE '[STEP 5] Performing cleanup...';
    
    -- 5.1: Analyze tables for query optimization
    ANALYZE dim_customer;
    ANALYZE dim_flight;
    ANALYZE dim_route;
    ANALYZE dim_seat;
    ANALYZE fact_bookings;
    ANALYZE fact_seat_inventory;
    
    RAISE NOTICE '[STEP 5.1] ✓ Statistics updated';
    
    -- 5.2: Optional: Vacuum old partitions (if using partitioning)
    -- VACUUM ANALYZE fact_bookings;
    
    RAISE NOTICE '[STEP 5] ✓ Cleanup completed';
    
    -- =====================================================
    -- FINAL SUMMARY
    -- =====================================================
    v_end_time := NOW();
    v_duration := v_end_time - v_start_time;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ETL Pipeline Completed Successfully!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Start Time: %', v_start_time;
    RAISE NOTICE 'End Time: %', v_end_time;
    RAISE NOTICE 'Duration: %', v_duration;
    RAISE NOTICE '';
    RAISE NOTICE 'Table Counts:';
    RAISE NOTICE '  - dim_customer: % records', (SELECT COUNT(*) FROM dim_customer);
    RAISE NOTICE '  - dim_flight: % records', (SELECT COUNT(*) FROM dim_flight);
    RAISE NOTICE '  - dim_route: % records', (SELECT COUNT(*) FROM dim_route);
    RAISE NOTICE '  - dim_seat: % records', (SELECT COUNT(*) FROM dim_seat);
    RAISE NOTICE '  - fact_bookings: % records', (SELECT COUNT(*) FROM fact_bookings);
    RAISE NOTICE '  - fact_seat_inventory: % records', (SELECT COUNT(*) FROM fact_seat_inventory WHERE snapshot_date = CURRENT_DATE);
    RAISE NOTICE '========================================';

EXCEPTION WHEN OTHERS THEN
    -- Log error to metadata
    UPDATE etl_metadata SET
        status = 'FAILED',
        error_message = SQLERRM
    WHERE table_name = 'fact_bookings';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ETL Pipeline FAILED!';
    RAISE NOTICE 'Error: %', SQLERRM;
    RAISE NOTICE 'Detail: %', SQLSTATE;
    RAISE NOTICE '========================================';
    
    -- Re-raise to ensure transaction rollback
    RAISE;
END $$;
