-- =====================================================
-- ETL: DIMENSION TABLE POPULATION
-- Extract-Transform-Load from OLTP to OLAP
-- =====================================================

-- =====================================================
-- 1. POPULATE dim_date (Pre-populate for 10 years)
-- =====================================================

-- This should be run once to populate the date dimension
-- Generates dates from 2020-01-01 to 2030-12-31

INSERT INTO dim_date (
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    day,
    day_of_week,
    day_name,
    week_of_year,
    is_weekend,
    fiscal_year,
    fiscal_quarter
)
SELECT
    TO_CHAR(date_series, 'YYYYMMDD')::INT AS date_key,
    date_series::DATE AS full_date,
    EXTRACT(YEAR FROM date_series)::INT AS year,
    EXTRACT(QUARTER FROM date_series)::INT AS quarter,
    EXTRACT(MONTH FROM date_series)::INT AS month,
    TO_CHAR(date_series, 'Month') AS month_name,
    EXTRACT(DAY FROM date_series)::INT AS day,
    EXTRACT(ISODOW FROM date_series)::INT AS day_of_week, -- 1=Monday, 7=Sunday
    TO_CHAR(date_series, 'Day') AS day_name,
    EXTRACT(WEEK FROM date_series)::INT AS week_of_year,
    CASE WHEN EXTRACT(ISODOW FROM date_series) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend,
    EXTRACT(YEAR FROM date_series)::INT AS fiscal_year, -- Adjust if fiscal year differs
    EXTRACT(QUARTER FROM date_series)::INT AS fiscal_quarter
FROM
    generate_series('2020-01-01'::DATE, '2030-12-31'::DATE, '1 day'::INTERVAL) AS date_series
ON CONFLICT (date_key) DO NOTHING;

-- Optional: Mark Philippine holidays (example)
UPDATE dim_date SET is_holiday = TRUE, holiday_name = 'New Year' WHERE month = 1 AND day = 1;
UPDATE dim_date SET is_holiday = TRUE, holiday_name = 'Independence Day' WHERE month = 6 AND day = 12;
UPDATE dim_date SET is_holiday = TRUE, holiday_name = 'Christmas' WHERE month = 12 AND day = 25;
-- Add more holidays as needed

-- =====================================================
-- 2. POPULATE dim_route (Extract unique routes)
-- =====================================================

-- Initial full load
INSERT INTO dim_route (
    origin,
    destination,
    route_code,
    region
)
SELECT DISTINCT
    f.origin,
    f.destination,
    CONCAT(LEFT(f.origin, 3), '-', LEFT(f.destination, 3)) AS route_code,
    'Domestic' AS region -- Default; can be enhanced with lookup table
FROM
    flights f
ON CONFLICT (origin, destination) DO NOTHING;

-- Incremental load (run periodically to catch new routes)
INSERT INTO dim_route (origin, destination, route_code, region)
SELECT DISTINCT
    f.origin,
    f.destination,
    CONCAT(LEFT(f.origin, 3), '-', LEFT(f.destination, 3)) AS route_code,
    'Domestic' AS region
FROM
    flights f
WHERE
    NOT EXISTS (
        SELECT 1 FROM dim_route dr
        WHERE dr.origin = f.origin AND dr.destination = f.destination
    );

-- =====================================================
-- 3. POPULATE dim_customer (SCD Type 1)
-- =====================================================

-- Initial full load
INSERT INTO dim_customer (
    customer_id,
    full_name,
    email,
    phone,
    created_at,
    updated_at
)
SELECT
    c.customer_id,
    c.full_name,
    c.email,
    c.phone,
    NOW() AS created_at,
    NOW() AS updated_at
FROM
    customers c
ON CONFLICT (customer_id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    updated_at = NOW();

-- Incremental load with SCD Type 1 (overwrite changes)
-- Run this periodically to sync new/updated customers

MERGE INTO dim_customer AS target
USING (
    SELECT
        c.customer_id,
        c.full_name,
        c.email,
        c.phone
    FROM
        customers c
    WHERE
        c.customer_id IN (
            -- Only customers modified since last ETL
            SELECT customer_id FROM customers
            -- Assuming you add updated_at to OLTP customers table
        )
) AS source
ON target.customer_id = source.customer_id
WHEN MATCHED THEN
    UPDATE SET
        full_name = source.full_name,
        email = source.email,
        phone = source.phone,
        updated_at = NOW()
WHEN NOT MATCHED THEN
    INSERT (customer_id, full_name, email, phone, created_at, updated_at)
    VALUES (source.customer_id, source.full_name, source.email, source.phone, NOW(), NOW());

-- Note: PostgreSQL 15+ supports MERGE. For older versions, use INSERT ... ON CONFLICT.

-- Alternative for PostgreSQL < 15 (using INSERT with ON CONFLICT):
INSERT INTO dim_customer (customer_id, full_name, email, phone, created_at, updated_at)
SELECT
    c.customer_id,
    c.full_name,
    c.email,
    c.phone,
    NOW(),
    NOW()
FROM
    customers c
ON CONFLICT (customer_id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    updated_at = NOW();

-- Update derived metrics (run after fact table load)
UPDATE dim_customer dc SET
    first_booking_date = (
        SELECT MIN(dd.full_date)
        FROM fact_bookings fb
        JOIN dim_date dd ON fb.booking_date_key = dd.date_key
        WHERE fb.customer_key = dc.customer_key
    ),
    total_bookings = (
        SELECT COUNT(DISTINCT fb.booking_id)
        FROM fact_bookings fb
        WHERE fb.customer_key = dc.customer_key AND fb.is_cancelled = FALSE
    ),
    total_spent = (
        SELECT COALESCE(SUM(fb.price), 0)
        FROM fact_bookings fb
        WHERE fb.customer_key = dc.customer_key AND fb.is_cancelled = FALSE
    );

-- Update customer segments
UPDATE dim_customer SET
    customer_segment = CASE
        WHEN total_spent > 50000 THEN 'VIP'
        WHEN total_bookings > 5 THEN 'Regular'
        ELSE 'One-time'
    END;

-- =====================================================
-- 4. POPULATE dim_seat
-- =====================================================

-- Initial full load
INSERT INTO dim_seat (
    seat_id,
    seat_number,
    seat_class,
    is_window_seat,
    is_aisle_seat,
    seat_row,
    created_at
)
SELECT
    s.seat_id,
    s.seat_number,
    s.seat_class,
    -- Window seats typically end with A or F
    CASE WHEN RIGHT(s.seat_number, 1) IN ('A', 'F') THEN TRUE ELSE FALSE END AS is_window_seat,
    -- Aisle seats typically end with C or D
    CASE WHEN RIGHT(s.seat_number, 1) IN ('C', 'D') THEN TRUE ELSE FALSE END AS is_aisle_seat,
    -- Extract row number (numeric part)
    SUBSTRING(s.seat_number FROM '^\d+')::INT AS seat_row,
    NOW() AS created_at
FROM
    seats s
ON CONFLICT (seat_id) DO NOTHING;

-- Incremental load for new seats
INSERT INTO dim_seat (seat_id, seat_number, seat_class, is_window_seat, is_aisle_seat, seat_row, created_at)
SELECT
    s.seat_id,
    s.seat_number,
    s.seat_class,
    CASE WHEN RIGHT(s.seat_number, 1) IN ('A', 'F') THEN TRUE ELSE FALSE END,
    CASE WHEN RIGHT(s.seat_number, 1) IN ('C', 'D') THEN TRUE ELSE FALSE END,
    SUBSTRING(s.seat_number FROM '^\d+')::INT,
    NOW()
FROM
    seats s
WHERE
    NOT EXISTS (
        SELECT 1 FROM dim_seat ds WHERE ds.seat_id = s.seat_id
    );

-- =====================================================
-- 5. POPULATE dim_flight
-- =====================================================

-- Initial full load with route lookup
INSERT INTO dim_flight (
    flight_id,
    flight_number,
    route_key,
    departure_time,
    arrival_time,
    flight_duration_minutes,
    departure_hour,
    departure_day_of_week,
    is_weekend_flight,
    created_at,
    updated_at
)
SELECT
    f.flight_id,
    f.flight_number,
    dr.route_key, -- Lookup route dimension
    f.departure_time,
    f.arrival_time,
    EXTRACT(EPOCH FROM (f.arrival_time - f.departure_time)) / 60 AS flight_duration_minutes,
    EXTRACT(HOUR FROM f.departure_time)::INT AS departure_hour,
    EXTRACT(ISODOW FROM f.departure_time)::INT AS departure_day_of_week,
    CASE WHEN EXTRACT(ISODOW FROM f.departure_time) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend_flight,
    NOW() AS created_at,
    NOW() AS updated_at
FROM
    flights f
LEFT JOIN dim_route dr ON f.origin = dr.origin AND f.destination = dr.destination
ON CONFLICT (flight_id) DO UPDATE SET
    flight_number = EXCLUDED.flight_number,
    departure_time = EXCLUDED.departure_time,
    arrival_time = EXCLUDED.arrival_time,
    flight_duration_minutes = EXCLUDED.flight_duration_minutes,
    updated_at = NOW();

-- Incremental load for new flights
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
FROM
    flights f
LEFT JOIN dim_route dr ON f.origin = dr.origin AND f.destination = dr.destination
WHERE
    NOT EXISTS (
        SELECT 1 FROM dim_flight df WHERE df.flight_id = f.flight_id
    );

-- =====================================================
-- Update ETL metadata after dimension loads
-- =====================================================

UPDATE etl_metadata SET
    last_etl_timestamp = NOW(),
    records_processed = (SELECT COUNT(*) FROM dim_customer),
    status = 'SUCCESS'
WHERE table_name = 'dim_customer';

UPDATE etl_metadata SET
    last_etl_timestamp = NOW(),
    records_processed = (SELECT COUNT(*) FROM dim_flight),
    status = 'SUCCESS'
WHERE table_name = 'dim_flight';

UPDATE etl_metadata SET
    last_etl_timestamp = NOW(),
    records_processed = (SELECT COUNT(*) FROM dim_route),
    status = 'SUCCESS'
WHERE table_name = 'dim_route';

UPDATE etl_metadata SET
    last_etl_timestamp = NOW(),
    records_processed = (SELECT COUNT(*) FROM dim_seat),
    status = 'SUCCESS'
WHERE table_name = 'dim_seat';
