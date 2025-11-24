-- =====================================================
-- OLAP DATA WAREHOUSE SCHEMA
-- Star Schema for Airline Booking System
-- =====================================================

-- Drop existing warehouse tables if they exist
DROP TABLE IF EXISTS fact_bookings CASCADE;
DROP TABLE IF EXISTS fact_seat_inventory CASCADE;
DROP TABLE IF EXISTS dim_customer CASCADE;
DROP TABLE IF EXISTS dim_flight CASCADE;
DROP TABLE IF EXISTS dim_route CASCADE;
DROP TABLE IF EXISTS dim_seat CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;
DROP TABLE IF EXISTS etl_metadata CASCADE;

-- =====================================================
-- DIMENSION TABLES
-- =====================================================

-- -----------------------------------------------------
-- dim_customer: Customer dimension (SCD Type 1)
-- -----------------------------------------------------
CREATE TABLE dim_customer (
    customer_key SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,  -- Natural key from OLTP
    full_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    
    -- Derived attributes for analytics
    first_booking_date DATE,
    total_bookings INT DEFAULT 0,
    total_spent NUMERIC(12,2) DEFAULT 0.00,
    customer_segment VARCHAR(20), -- 'VIP', 'Regular', 'One-time'
    
    -- SCD Type 1 metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_customer_id UNIQUE (customer_id)
);

CREATE INDEX idx_dim_customer_segment ON dim_customer(customer_segment);
CREATE INDEX idx_dim_customer_email ON dim_customer(email);

-- -----------------------------------------------------
-- dim_route: Route dimension (Origin-Destination pairs)
-- -----------------------------------------------------
CREATE TABLE dim_route (
    route_key SERIAL PRIMARY KEY,
    origin TEXT NOT NULL,
    destination TEXT NOT NULL,
    
    -- Derived attributes
    route_code VARCHAR(10), -- e.g., 'MNL-CEB'
    distance_km INT, -- Future enhancement
    region VARCHAR(50), -- 'Domestic', 'International'
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_route UNIQUE (origin, destination)
);

CREATE INDEX idx_dim_route_origin ON dim_route(origin);
CREATE INDEX idx_dim_route_destination ON dim_route(destination);
CREATE INDEX idx_dim_route_code ON dim_route(route_code);

-- -----------------------------------------------------
-- dim_flight: Flight dimension (SCD Type 1)
-- -----------------------------------------------------
CREATE TABLE dim_flight (
    flight_key SERIAL PRIMARY KEY,
    flight_id INT NOT NULL,  -- Natural key from OLTP
    flight_number VARCHAR(10) NOT NULL,
    
    -- Route foreign key
    route_key INT REFERENCES dim_route(route_key),
    
    -- Flight details
    departure_time TIMESTAMPTZ NOT NULL,
    arrival_time TIMESTAMPTZ NOT NULL,
    flight_duration_minutes INT,
    
    -- Derived time attributes
    departure_hour INT, -- 0-23
    departure_day_of_week INT, -- 1=Monday, 7=Sunday
    is_weekend_flight BOOLEAN,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_flight_id UNIQUE (flight_id)
);

CREATE INDEX idx_dim_flight_number ON dim_flight(flight_number);
CREATE INDEX idx_dim_flight_route ON dim_flight(route_key);
CREATE INDEX idx_dim_flight_departure ON dim_flight(departure_time);
CREATE INDEX idx_dim_flight_dow ON dim_flight(departure_day_of_week);

-- -----------------------------------------------------
-- dim_seat: Seat dimension
-- -----------------------------------------------------
CREATE TABLE dim_seat (
    seat_key SERIAL PRIMARY KEY,
    seat_id INT NOT NULL,  -- Natural key from OLTP
    seat_number VARCHAR(5) NOT NULL,
    seat_class VARCHAR(20) NOT NULL, -- 'ECONOMY', 'BUSINESS'
    
    -- Derived attributes
    is_window_seat BOOLEAN, -- Based on seat letter (A, F)
    is_aisle_seat BOOLEAN,  -- Based on seat letter (C, D)
    seat_row INT, -- Numeric part of seat_number
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_seat_id UNIQUE (seat_id)
);

CREATE INDEX idx_dim_seat_class ON dim_seat(seat_class);
CREATE INDEX idx_dim_seat_number ON dim_seat(seat_number);

-- -----------------------------------------------------
-- dim_date: Date dimension (pre-populated)
-- -----------------------------------------------------
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY, -- Format: YYYYMMDD (e.g., 20251201)
    full_date DATE NOT NULL UNIQUE,
    
    -- Date components
    year INT NOT NULL,
    quarter INT NOT NULL, -- 1-4
    month INT NOT NULL, -- 1-12
    month_name VARCHAR(10) NOT NULL, -- 'January', 'February', etc.
    day INT NOT NULL, -- 1-31
    day_of_week INT NOT NULL, -- 1=Monday, 7=Sunday
    day_name VARCHAR(10) NOT NULL, -- 'Monday', 'Tuesday', etc.
    week_of_year INT NOT NULL, -- 1-53
    
    -- Flags
    is_weekend BOOLEAN NOT NULL,
    is_holiday BOOLEAN DEFAULT FALSE,
    holiday_name VARCHAR(50),
    
    -- Business attributes
    fiscal_year INT,
    fiscal_quarter INT,
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_dim_date_full_date ON dim_date(full_date);
CREATE INDEX idx_dim_date_year_month ON dim_date(year, month);
CREATE INDEX idx_dim_date_is_weekend ON dim_date(is_weekend);

-- =====================================================
-- FACT TABLES
-- =====================================================

-- -----------------------------------------------------
-- fact_bookings: Transaction fact table
-- Grain: One row per booking item (each seat booked)
-- -----------------------------------------------------
CREATE TABLE fact_bookings (
    booking_fact_key BIGSERIAL PRIMARY KEY,
    
    -- Dimension foreign keys (surrogate keys)
    customer_key INT NOT NULL REFERENCES dim_customer(customer_key),
    flight_key INT NOT NULL REFERENCES dim_flight(flight_key),
    seat_key INT NOT NULL REFERENCES dim_seat(seat_key),
    booking_date_key INT NOT NULL REFERENCES dim_date(date_key),
    departure_date_key INT NOT NULL REFERENCES dim_date(date_key),
    
    -- Degenerate dimensions (transaction identifiers)
    booking_id INT NOT NULL,
    booking_reference UUID NOT NULL,
    booking_item_id INT NOT NULL,
    
    -- Measures (additive facts)
    price NUMERIC(10,2) NOT NULL,
    
    -- Semi-additive/Non-additive facts
    is_cancelled BOOLEAN DEFAULT FALSE,
    cancelled_at TIMESTAMP,
    
    -- Derived metrics
    booking_to_departure_days INT, -- How far in advance booked
    booking_hour INT, -- Hour of day booking was made (0-23)
    
    -- Timestamps
    booked_at TIMESTAMPTZ NOT NULL,
    etl_loaded_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_booking_item UNIQUE (booking_item_id)
);

-- Indexes for fact_bookings (critical for query performance)
CREATE INDEX idx_fact_bookings_customer ON fact_bookings(customer_key);
CREATE INDEX idx_fact_bookings_flight ON fact_bookings(flight_key);
CREATE INDEX idx_fact_bookings_seat ON fact_bookings(seat_key);
CREATE INDEX idx_fact_bookings_booking_date ON fact_bookings(booking_date_key);
CREATE INDEX idx_fact_bookings_departure_date ON fact_bookings(departure_date_key);
CREATE INDEX idx_fact_bookings_cancelled ON fact_bookings(is_cancelled);
CREATE INDEX idx_fact_bookings_booked_at ON fact_bookings(booked_at);

-- Composite indexes for common query patterns
CREATE INDEX idx_fact_bookings_flight_date ON fact_bookings(flight_key, booking_date_key);
CREATE INDEX idx_fact_bookings_customer_date ON fact_bookings(customer_key, booking_date_key);

-- -----------------------------------------------------
-- fact_seat_inventory: Periodic snapshot fact table
-- Grain: One row per seat per flight per day (snapshot)
-- -----------------------------------------------------
CREATE TABLE fact_seat_inventory (
    inventory_fact_key BIGSERIAL PRIMARY KEY,
    
    -- Dimension foreign keys
    flight_key INT NOT NULL REFERENCES dim_flight(flight_key),
    seat_key INT NOT NULL REFERENCES dim_seat(seat_key),
    snapshot_date_key INT NOT NULL REFERENCES dim_date(date_key),
    
    -- Snapshot date (actual date of snapshot)
    snapshot_date DATE NOT NULL,
    
    -- Measures (semi-additive - snapshot values)
    is_available BOOLEAN NOT NULL,
    is_booked BOOLEAN NOT NULL,
    
    -- Derived metrics
    days_until_departure INT NOT NULL,
    
    -- Timestamps
    etl_loaded_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_seat_snapshot UNIQUE (flight_key, seat_key, snapshot_date)
);

-- Indexes for fact_seat_inventory
CREATE INDEX idx_fact_inventory_flight ON fact_seat_inventory(flight_key);
CREATE INDEX idx_fact_inventory_seat ON fact_seat_inventory(seat_key);
CREATE INDEX idx_fact_inventory_snapshot_date ON fact_seat_inventory(snapshot_date_key);
CREATE INDEX idx_fact_inventory_date ON fact_seat_inventory(snapshot_date);

-- Composite indexes
CREATE INDEX idx_fact_inventory_flight_date ON fact_seat_inventory(flight_key, snapshot_date);

-- =====================================================
-- PARTITIONING (PostgreSQL 10+)
-- =====================================================

-- Partition fact_bookings by booking_date_key (range partitioning by month)
-- Note: This requires creating the table with PARTITION BY clause
-- Example for manual partitioning strategy:

-- DROP TABLE IF EXISTS fact_bookings CASCADE;
-- CREATE TABLE fact_bookings (
--     -- ... same columns as above ...
-- ) PARTITION BY RANGE (booking_date_key);

-- -- Create partitions for each month
-- CREATE TABLE fact_bookings_202512 PARTITION OF fact_bookings
--     FOR VALUES FROM (20251201) TO (20260101);
-- 
-- CREATE TABLE fact_bookings_202601 PARTITION OF fact_bookings
--     FOR VALUES FROM (20260101) TO (20260201);

-- =====================================================
-- ETL METADATA TABLE
-- =====================================================

CREATE TABLE etl_metadata (
    etl_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    last_etl_timestamp TIMESTAMP NOT NULL,
    records_processed INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'SUCCESS', -- 'SUCCESS', 'FAILED', 'RUNNING'
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_table_name UNIQUE (table_name)
);

-- Initialize ETL metadata
INSERT INTO etl_metadata (table_name, last_etl_timestamp) VALUES
('dim_customer', '1970-01-01 00:00:00'),
('dim_flight', '1970-01-01 00:00:00'),
('dim_route', '1970-01-01 00:00:00'),
('dim_seat', '1970-01-01 00:00:00'),
('fact_bookings', '1970-01-01 00:00:00'),
('fact_seat_inventory', '1970-01-01 00:00:00');

-- =====================================================
-- COMMENTS FOR DOCUMENTATION
-- =====================================================

COMMENT ON TABLE dim_customer IS 'Customer dimension - SCD Type 1';
COMMENT ON TABLE dim_flight IS 'Flight dimension with route and time attributes';
COMMENT ON TABLE dim_route IS 'Route dimension for origin-destination analysis';
COMMENT ON TABLE dim_seat IS 'Seat dimension with class and position attributes';
COMMENT ON TABLE dim_date IS 'Date dimension for temporal analysis';
COMMENT ON TABLE fact_bookings IS 'Transaction fact: One row per booking item (seat)';
COMMENT ON TABLE fact_seat_inventory IS 'Periodic snapshot: Daily seat availability per flight';
COMMENT ON TABLE etl_metadata IS 'ETL tracking and watermark management';

COMMENT ON COLUMN fact_bookings.booking_to_departure_days IS 'Booking lead time in days';
COMMENT ON COLUMN fact_seat_inventory.days_until_departure IS 'Days remaining until flight departure';
