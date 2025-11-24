-- =====================================================
-- ETL: FACT TABLE POPULATION
-- Extract-Transform-Load from OLTP to OLAP
-- =====================================================

-- =====================================================
-- 1. POPULATE fact_bookings (Transaction Fact Table)
-- =====================================================

-- -----------------------------------------------------
-- Initial Full Load
-- -----------------------------------------------------

INSERT INTO fact_bookings (
    customer_key,
    flight_key,
    seat_key,
    booking_date_key,
    departure_date_key,
    booking_id,
    booking_reference,
    booking_item_id,
    price,
    is_cancelled,
    cancelled_at,
    booking_to_departure_days,
    booking_hour,
    booked_at,
    etl_loaded_at
)
SELECT
    dc.customer_key,
    df.flight_key,
    ds.seat_key,
    TO_CHAR(b.booked_at, 'YYYYMMDD')::INT AS booking_date_key,
    TO_CHAR(f.departure_time, 'YYYYMMDD')::INT AS departure_date_key,
    b.booking_id,
    b.booking_reference,
    bi.booking_item_id,
    bi.price,
    CASE WHEN b.status = 'CANCELLED' THEN TRUE ELSE FALSE END AS is_cancelled,
    NULL AS cancelled_at, -- Will be updated separately if cancellation tracking is added
    EXTRACT(DAY FROM (f.departure_time - b.booked_at))::INT AS booking_to_departure_days,
    EXTRACT(HOUR FROM b.booked_at)::INT AS booking_hour,
    b.booked_at,
    NOW() AS etl_loaded_at
FROM
    booking_items bi
INNER JOIN bookings b ON bi.booking_id = b.booking_id
INNER JOIN seats s ON bi.seat_id = s.seat_id
INNER JOIN flights f ON s.flight_id = f.flight_id
-- Dimension lookups (surrogate key mapping)
INNER JOIN dim_customer dc ON b.customer_id = dc.customer_id
INNER JOIN dim_flight df ON f.flight_id = df.flight_id
INNER JOIN dim_seat ds ON s.seat_id = ds.seat_id
ON CONFLICT (booking_item_id) DO NOTHING;

-- -----------------------------------------------------
-- Incremental Load (Delta Load)
-- Load only new bookings since last ETL run
-- -----------------------------------------------------

INSERT INTO fact_bookings (
    customer_key,
    flight_key,
    seat_key,
    booking_date_key,
    departure_date_key,
    booking_id,
    booking_reference,
    booking_item_id,
    price,
    is_cancelled,
    cancelled_at,
    booking_to_departure_days,
    booking_hour,
    booked_at,
    etl_loaded_at
)
SELECT
    dc.customer_key,
    df.flight_key,
    ds.seat_key,
    TO_CHAR(b.booked_at, 'YYYYMMDD')::INT AS booking_date_key,
    TO_CHAR(f.departure_time, 'YYYYMMDD')::INT AS departure_date_key,
    b.booking_id,
    b.booking_reference,
    bi.booking_item_id,
    bi.price,
    CASE WHEN b.status = 'CANCELLED' THEN TRUE ELSE FALSE END AS is_cancelled,
    NULL AS cancelled_at,
    EXTRACT(DAY FROM (f.departure_time - b.booked_at))::INT AS booking_to_departure_days,
    EXTRACT(HOUR FROM b.booked_at)::INT AS booking_hour,
    b.booked_at,
    NOW() AS etl_loaded_at
FROM
    booking_items bi
INNER JOIN bookings b ON bi.booking_id = b.booking_id
INNER JOIN seats s ON bi.seat_id = s.seat_id
INNER JOIN flights f ON s.flight_id = f.flight_id
INNER JOIN dim_customer dc ON b.customer_id = dc.customer_id
INNER JOIN dim_flight df ON f.flight_id = df.flight_id
INNER JOIN dim_seat ds ON s.seat_id = ds.seat_id
WHERE
    -- Only load bookings created/updated since last ETL run
    b.booked_at > (SELECT last_etl_timestamp FROM etl_metadata WHERE table_name = 'fact_bookings')
ON CONFLICT (booking_item_id) DO NOTHING;

-- -----------------------------------------------------
-- Update cancellations (for existing bookings)
-- -----------------------------------------------------

UPDATE fact_bookings fb SET
    is_cancelled = TRUE,
    cancelled_at = NOW()
FROM bookings b
WHERE
    fb.booking_id = b.booking_id
    AND b.status = 'CANCELLED'
    AND fb.is_cancelled = FALSE;

-- Update ETL metadata
UPDATE etl_metadata SET
    last_etl_timestamp = NOW(),
    records_processed = (SELECT COUNT(*) FROM fact_bookings),
    status = 'SUCCESS'
WHERE table_name = 'fact_bookings';

-- =====================================================
-- 2. POPULATE fact_seat_inventory (Periodic Snapshot)
-- =====================================================

-- This should be run daily to capture seat availability snapshots
-- Captures the state of all seats for all future flights

-- -----------------------------------------------------
-- Daily Snapshot Load
-- -----------------------------------------------------

-- Delete today's snapshot if re-running (idempotent)
DELETE FROM fact_seat_inventory
WHERE snapshot_date = CURRENT_DATE;

-- Insert today's snapshot for all future flights
INSERT INTO fact_seat_inventory (
    flight_key,
    seat_key,
    snapshot_date_key,
    snapshot_date,
    is_available,
    is_booked,
    days_until_departure,
    etl_loaded_at
)
SELECT
    df.flight_key,
    ds.seat_key,
    TO_CHAR(CURRENT_DATE, 'YYYYMMDD')::INT AS snapshot_date_key,
    CURRENT_DATE AS snapshot_date,
    s.is_available,
    NOT s.is_available AS is_booked, -- Inverse of is_available
    EXTRACT(DAY FROM (f.departure_time - CURRENT_TIMESTAMP))::INT AS days_until_departure,
    NOW() AS etl_loaded_at
FROM
    seats s
INNER JOIN flights f ON s.flight_id = f.flight_id
INNER JOIN dim_flight df ON f.flight_id = df.flight_id
INNER JOIN dim_seat ds ON s.seat_id = ds.seat_id
WHERE
    -- Only snapshot future flights (not past flights)
    f.departure_time > CURRENT_TIMESTAMP;

-- Update ETL metadata
UPDATE etl_metadata SET
    last_etl_timestamp = NOW(),
    records_processed = (SELECT COUNT(*) FROM fact_seat_inventory WHERE snapshot_date = CURRENT_DATE),
    status = 'SUCCESS'
WHERE table_name = 'fact_seat_inventory';

-- =====================================================
-- 3. HELPER: Handle Missing Dimension Keys
-- =====================================================

-- Create "Unknown" records for missing dimension references
-- This ensures referential integrity even if source data has orphans

-- Unknown Customer
INSERT INTO dim_customer (customer_id, full_name, email, phone, customer_segment)
VALUES (-1, 'Unknown Customer', 'unknown@example.com', 'N/A', 'Unknown')
ON CONFLICT (customer_id) DO NOTHING;

-- Unknown Flight (requires an unknown route first)
INSERT INTO dim_route (origin, destination, route_code, region)
VALUES ('Unknown', 'Unknown', 'UNK-UNK', 'Unknown')
ON CONFLICT (origin, destination) DO NOTHING;

INSERT INTO dim_flight (flight_id, flight_number, route_key, departure_time, arrival_time, flight_duration_minutes)
VALUES (
    -1, 
    'UNK000', 
    (SELECT route_key FROM dim_route WHERE origin = 'Unknown' AND destination = 'Unknown'),
    '1970-01-01 00:00:00+00',
    '1970-01-01 00:00:00+00',
    0
)
ON CONFLICT (flight_id) DO NOTHING;

-- Unknown Seat
INSERT INTO dim_seat (seat_id, seat_number, seat_class, is_window_seat, is_aisle_seat, seat_row)
VALUES (-1, 'UNK', 'ECONOMY', FALSE, FALSE, 0)
ON CONFLICT (seat_id) DO NOTHING;

-- =====================================================
-- 4. DATA QUALITY CHECKS
-- =====================================================

-- Check for orphaned bookings (bookings without valid customer/flight/seat)
SELECT 
    'Orphaned Bookings' AS issue_type,
    COUNT(*) AS issue_count
FROM booking_items bi
LEFT JOIN dim_customer dc ON bi.booking_id = dc.customer_id
LEFT JOIN seats s ON bi.seat_id = s.seat_id
LEFT JOIN dim_seat ds ON s.seat_id = ds.seat_id
WHERE dc.customer_key IS NULL OR ds.seat_key IS NULL;

-- Check for missing date keys
SELECT 
    'Missing Date Keys' AS issue_type,
    COUNT(*) AS issue_count
FROM fact_bookings fb
LEFT JOIN dim_date dd ON fb.booking_date_key = dd.date_key
WHERE dd.date_key IS NULL;

-- Check for negative booking lead times (bookings made after departure)
SELECT 
    'Negative Lead Time' AS issue_type,
    COUNT(*) AS issue_count
FROM fact_bookings
WHERE booking_to_departure_days < 0;

-- =====================================================
-- 5. INCREMENTAL ETL WRAPPER (Complete Pipeline)
-- =====================================================

-- This is a complete incremental ETL procedure that can be scheduled daily

DO $$
DECLARE
    v_start_time TIMESTAMP;
    v_records_processed INT;
BEGIN
    v_start_time := NOW();
    
    -- Step 1: Load new customers
    INSERT INTO dim_customer (customer_id, full_name, email, phone, created_at, updated_at)
    SELECT customer_id, full_name, email, phone, NOW(), NOW()
    FROM customers
    ON CONFLICT (customer_id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        phone = EXCLUDED.phone,
        updated_at = NOW();
    
    -- Step 2: Load new routes
    INSERT INTO dim_route (origin, destination, route_code, region)
    SELECT DISTINCT
        origin, destination,
        CONCAT(LEFT(origin, 3), '-', LEFT(destination, 3)),
        'Domestic'
    FROM flights
    ON CONFLICT (origin, destination) DO NOTHING;
    
    -- Step 3: Load new flights
    INSERT INTO dim_flight (
        flight_id, flight_number, route_key, departure_time, arrival_time,
        flight_duration_minutes, departure_hour, departure_day_of_week, is_weekend_flight,
        created_at, updated_at
    )
    SELECT
        f.flight_id, f.flight_number, dr.route_key, f.departure_time, f.arrival_time,
        EXTRACT(EPOCH FROM (f.arrival_time - f.departure_time)) / 60,
        EXTRACT(HOUR FROM f.departure_time)::INT,
        EXTRACT(ISODOW FROM f.departure_time)::INT,
        CASE WHEN EXTRACT(ISODOW FROM f.departure_time) IN (6, 7) THEN TRUE ELSE FALSE END,
        NOW(), NOW()
    FROM flights f
    LEFT JOIN dim_route dr ON f.origin = dr.origin AND f.destination = dr.destination
    ON CONFLICT (flight_id) DO UPDATE SET
        departure_time = EXCLUDED.departure_time,
        arrival_time = EXCLUDED.arrival_time,
        updated_at = NOW();
    
    -- Step 4: Load new seats
    INSERT INTO dim_seat (seat_id, seat_number, seat_class, is_window_seat, is_aisle_seat, seat_row, created_at)
    SELECT
        seat_id, seat_number, seat_class,
        CASE WHEN RIGHT(seat_number, 1) IN ('A', 'F') THEN TRUE ELSE FALSE END,
        CASE WHEN RIGHT(seat_number, 1) IN ('C', 'D') THEN TRUE ELSE FALSE END,
        SUBSTRING(seat_number FROM '^\d+')::INT,
        NOW()
    FROM seats
    ON CONFLICT (seat_id) DO NOTHING;
    
    -- Step 5: Load new bookings (fact table)
    INSERT INTO fact_bookings (
        customer_key, flight_key, seat_key, booking_date_key, departure_date_key,
        booking_id, booking_reference, booking_item_id, price, is_cancelled,
        booking_to_departure_days, booking_hour, booked_at, etl_loaded_at
    )
    SELECT
        dc.customer_key, df.flight_key, ds.seat_key,
        TO_CHAR(b.booked_at, 'YYYYMMDD')::INT,
        TO_CHAR(f.departure_time, 'YYYYMMDD')::INT,
        b.booking_id, b.booking_reference, bi.booking_item_id, bi.price,
        CASE WHEN b.status = 'CANCELLED' THEN TRUE ELSE FALSE END,
        EXTRACT(DAY FROM (f.departure_time - b.booked_at))::INT,
        EXTRACT(HOUR FROM b.booked_at)::INT,
        b.booked_at, NOW()
    FROM booking_items bi
    INNER JOIN bookings b ON bi.booking_id = b.booking_id
    INNER JOIN seats s ON bi.seat_id = s.seat_id
    INNER JOIN flights f ON s.flight_id = f.flight_id
    INNER JOIN dim_customer dc ON b.customer_id = dc.customer_id
    INNER JOIN dim_flight df ON f.flight_id = df.flight_id
    INNER JOIN dim_seat ds ON s.seat_id = ds.seat_id
    WHERE b.booked_at > (SELECT last_etl_timestamp FROM etl_metadata WHERE table_name = 'fact_bookings')
    ON CONFLICT (booking_item_id) DO NOTHING;
    
    GET DIAGNOSTICS v_records_processed = ROW_COUNT;
    
    -- Update metadata
    UPDATE etl_metadata SET
        last_etl_timestamp = v_start_time,
        records_processed = v_records_processed,
        status = 'SUCCESS'
    WHERE table_name = 'fact_bookings';
    
    RAISE NOTICE 'ETL completed successfully. Records processed: %', v_records_processed;
    
EXCEPTION WHEN OTHERS THEN
    UPDATE etl_metadata SET
        status = 'FAILED',
        error_message = SQLERRM
    WHERE table_name = 'fact_bookings';
    
    RAISE NOTICE 'ETL failed: %', SQLERRM;
    RAISE;
END $$;
