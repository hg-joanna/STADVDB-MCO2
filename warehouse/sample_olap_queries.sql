-- =====================================================
-- SAMPLE OLAP QUERIES FOR REPORTING
-- Business Intelligence and Analytics Queries
-- =====================================================

-- =====================================================
-- 1. REVENUE ANALYSIS
-- =====================================================

-- 1.1: Total Revenue by Route (Top 10 Most Profitable Routes)
SELECT
    dr.route_code,
    dr.origin,
    dr.destination,
    COUNT(DISTINCT fb.booking_id) AS total_bookings,
    SUM(fb.price) AS total_revenue,
    AVG(fb.price) AS avg_price_per_seat,
    SUM(CASE WHEN fb.is_cancelled THEN 0 ELSE fb.price END) AS revenue_after_cancellations
FROM
    fact_bookings fb
INNER JOIN dim_flight df ON fb.flight_key = df.flight_key
INNER JOIN dim_route dr ON df.route_key = dr.route_key
GROUP BY
    dr.route_code, dr.origin, dr.destination
ORDER BY
    total_revenue DESC
LIMIT 10;

-- 1.2: Monthly Revenue Trend (2025)
SELECT
    dd.year,
    dd.month,
    dd.month_name,
    COUNT(DISTINCT fb.booking_id) AS bookings,
    SUM(fb.price) AS revenue,
    SUM(CASE WHEN fb.is_cancelled THEN fb.price ELSE 0 END) AS cancelled_revenue,
    ROUND(SUM(CASE WHEN fb.is_cancelled THEN fb.price ELSE 0 END) * 100.0 / NULLIF(SUM(fb.price), 0), 2) AS cancellation_rate_pct
FROM
    fact_bookings fb
INNER JOIN dim_date dd ON fb.booking_date_key = dd.date_key
WHERE
    dd.year = 2025
GROUP BY
    dd.year, dd.month, dd.month_name
ORDER BY
    dd.month;

-- 1.3: Revenue by Seat Class
SELECT
    ds.seat_class,
    COUNT(fb.booking_fact_key) AS seats_booked,
    SUM(fb.price) AS total_revenue,
    AVG(fb.price) AS avg_price,
    MIN(fb.price) AS min_price,
    MAX(fb.price) AS max_price
FROM
    fact_bookings fb
INNER JOIN dim_seat ds ON fb.seat_key = ds.seat_key
WHERE
    fb.is_cancelled = FALSE
GROUP BY
    ds.seat_class
ORDER BY
    total_revenue DESC;

-- 1.4: Daily Revenue with Moving Average (Last 30 Days)
SELECT
    dd.full_date,
    SUM(fb.price) AS daily_revenue,
    AVG(SUM(fb.price)) OVER (
        ORDER BY dd.full_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7_days
FROM
    fact_bookings fb
INNER JOIN dim_date dd ON fb.booking_date_key = dd.date_key
WHERE
    dd.full_date >= CURRENT_DATE - INTERVAL '30 days'
    AND fb.is_cancelled = FALSE
GROUP BY
    dd.full_date
ORDER BY
    dd.full_date;

-- =====================================================
-- 2. BOOKING PATTERNS & BEHAVIOR
-- =====================================================

-- 2.1: Booking Lead Time Distribution (How Far in Advance Customers Book)
SELECT
    CASE
        WHEN booking_to_departure_days <= 1 THEN '0-1 days'
        WHEN booking_to_departure_days <= 3 THEN '2-3 days'
        WHEN booking_to_departure_days <= 7 THEN '4-7 days'
        WHEN booking_to_departure_days <= 14 THEN '8-14 days'
        WHEN booking_to_departure_days <= 30 THEN '15-30 days'
        ELSE '30+ days'
    END AS lead_time_bucket,
    COUNT(*) AS booking_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM
    fact_bookings
WHERE
    is_cancelled = FALSE
GROUP BY
    lead_time_bucket
ORDER BY
    MIN(booking_to_departure_days);

-- 2.2: Peak Booking Hours (Hour of Day Analysis)
SELECT
    booking_hour,
    COUNT(*) AS bookings,
    SUM(price) AS revenue,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS booking_percentage
FROM
    fact_bookings
WHERE
    is_cancelled = FALSE
GROUP BY
    booking_hour
ORDER BY
    booking_hour;

-- 2.3: Booking Velocity by Flight (Bookings Over Time Before Departure)
WITH booking_timeline AS (
    SELECT
        df.flight_number,
        df.departure_time,
        fb.booking_to_departure_days,
        COUNT(*) OVER (
            PARTITION BY fb.flight_key 
            ORDER BY fb.booking_to_departure_days DESC
            ROWS UNBOUNDED PRECEDING
        ) AS cumulative_bookings
    FROM
        fact_bookings fb
    INNER JOIN dim_flight df ON fb.flight_key = df.flight_key
    WHERE
        fb.is_cancelled = FALSE
)
SELECT
    flight_number,
    departure_time,
    booking_to_departure_days AS days_before_departure,
    cumulative_bookings
FROM
    booking_timeline
WHERE
    flight_number = 'FL001' -- Example: Track FL001
ORDER BY
    booking_to_departure_days DESC;

-- 2.4: Weekend vs Weekday Booking Patterns
SELECT
    dd.is_weekend,
    CASE WHEN dd.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS period_type,
    COUNT(*) AS bookings,
    SUM(fb.price) AS revenue,
    AVG(fb.price) AS avg_price
FROM
    fact_bookings fb
INNER JOIN dim_date dd ON fb.booking_date_key = dd.date_key
WHERE
    fb.is_cancelled = FALSE
GROUP BY
    dd.is_weekend
ORDER BY
    dd.is_weekend;

-- =====================================================
-- 3. CUSTOMER ANALYTICS
-- =====================================================

-- 3.1: Top 20 Customers by Total Spend
SELECT
    dc.customer_id,
    dc.full_name,
    dc.email,
    dc.customer_segment,
    COUNT(DISTINCT fb.booking_id) AS total_bookings,
    SUM(fb.price) AS total_spent,
    AVG(fb.price) AS avg_booking_value,
    MIN(dd.full_date) AS first_booking_date,
    MAX(dd.full_date) AS last_booking_date
FROM
    fact_bookings fb
INNER JOIN dim_customer dc ON fb.customer_key = dc.customer_key
INNER JOIN dim_date dd ON fb.booking_date_key = dd.date_key
WHERE
    fb.is_cancelled = FALSE
GROUP BY
    dc.customer_id, dc.full_name, dc.email, dc.customer_segment
ORDER BY
    total_spent DESC
LIMIT 20;

-- 3.2: Customer Segmentation Analysis
SELECT
    dc.customer_segment,
    COUNT(DISTINCT dc.customer_key) AS customer_count,
    COUNT(DISTINCT fb.booking_id) AS total_bookings,
    SUM(fb.price) AS total_revenue,
    AVG(fb.price) AS avg_booking_value,
    ROUND(SUM(fb.price) * 100.0 / SUM(SUM(fb.price)) OVER (), 2) AS revenue_share_pct
FROM
    fact_bookings fb
INNER JOIN dim_customer dc ON fb.customer_key = dc.customer_key
WHERE
    fb.is_cancelled = FALSE
GROUP BY
    dc.customer_segment
ORDER BY
    total_revenue DESC;

-- 3.3: Repeat Customer Rate
WITH customer_booking_counts AS (
    SELECT
        customer_key,
        COUNT(DISTINCT booking_id) AS booking_count
    FROM
        fact_bookings
    WHERE
        is_cancelled = FALSE
    GROUP BY
        customer_key
)
SELECT
    CASE
        WHEN booking_count = 1 THEN 'One-time'
        WHEN booking_count BETWEEN 2 AND 3 THEN 'Occasional (2-3)'
        WHEN booking_count BETWEEN 4 AND 10 THEN 'Frequent (4-10)'
        ELSE 'Very Frequent (10+)'
    END AS customer_type,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM
    customer_booking_counts
GROUP BY
    customer_type;

-- =====================================================
-- 4. OPERATIONAL METRICS
-- =====================================================

-- 4.1: Load Factor by Flight (% Seats Sold)
WITH flight_capacity AS (
    SELECT
        df.flight_key,
        df.flight_number,
        dr.route_code,
        df.departure_time,
        COUNT(DISTINCT ds.seat_key) AS total_seats,
        COUNT(DISTINCT CASE WHEN fb.booking_fact_key IS NOT NULL AND fb.is_cancelled = FALSE THEN ds.seat_key END) AS booked_seats
    FROM
        dim_flight df
    INNER JOIN dim_route dr ON df.route_key = dr.route_key
    CROSS JOIN dim_seat ds  -- All possible seats
    LEFT JOIN fact_bookings fb ON fb.flight_key = df.flight_key AND fb.seat_key = ds.seat_key
    WHERE
        df.departure_time >= CURRENT_DATE
    GROUP BY
        df.flight_key, df.flight_number, dr.route_code, df.departure_time
)
SELECT
    flight_number,
    route_code,
    departure_time,
    total_seats,
    booked_seats,
    total_seats - booked_seats AS available_seats,
    ROUND(booked_seats * 100.0 / NULLIF(total_seats, 0), 2) AS load_factor_pct
FROM
    flight_capacity
ORDER BY
    departure_time;

-- 4.2: Cancellation Rate by Route
SELECT
    dr.route_code,
    dr.origin,
    dr.destination,
    COUNT(*) AS total_bookings,
    SUM(CASE WHEN fb.is_cancelled THEN 1 ELSE 0 END) AS cancelled_bookings,
    ROUND(SUM(CASE WHEN fb.is_cancelled THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate_pct
FROM
    fact_bookings fb
INNER JOIN dim_flight df ON fb.flight_key = df.flight_key
INNER JOIN dim_route dr ON df.route_key = dr.route_key
GROUP BY
    dr.route_code, dr.origin, dr.destination
HAVING
    COUNT(*) > 10  -- Only routes with significant bookings
ORDER BY
    cancellation_rate_pct DESC;

-- 4.3: Seat Utilization by Class Over Time
SELECT
    dd.full_date,
    ds.seat_class,
    COUNT(DISTINCT fb.seat_key) AS seats_booked,
    SUM(fb.price) AS revenue
FROM
    fact_bookings fb
INNER JOIN dim_seat ds ON fb.seat_key = ds.seat_key
INNER JOIN dim_date dd ON fb.departure_date_key = dd.date_key
WHERE
    fb.is_cancelled = FALSE
    AND dd.full_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY
    dd.full_date, ds.seat_class
ORDER BY
    dd.full_date, ds.seat_class;

-- =====================================================
-- 5. INVENTORY ANALYSIS (Using Snapshot Fact)
-- =====================================================

-- 5.1: Seat Availability Trend (Last 30 Days for Upcoming Flights)
SELECT
    fsi.snapshot_date,
    COUNT(*) AS total_seats_tracked,
    SUM(CASE WHEN fsi.is_available THEN 1 ELSE 0 END) AS available_seats,
    SUM(CASE WHEN fsi.is_booked THEN 1 ELSE 0 END) AS booked_seats,
    ROUND(SUM(CASE WHEN fsi.is_booked THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS occupancy_rate_pct
FROM
    fact_seat_inventory fsi
WHERE
    fsi.snapshot_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY
    fsi.snapshot_date
ORDER BY
    fsi.snapshot_date;

-- 5.2: Booking Velocity by Days Until Departure
SELECT
    days_until_departure,
    COUNT(*) AS total_seats,
    SUM(CASE WHEN is_booked THEN 1 ELSE 0 END) AS booked_seats,
    ROUND(SUM(CASE WHEN is_booked THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS booking_rate_pct
FROM
    fact_seat_inventory
WHERE
    snapshot_date = CURRENT_DATE
    AND days_until_departure BETWEEN 0 AND 30
GROUP BY
    days_until_departure
ORDER BY
    days_until_departure;

-- =====================================================
-- 6. ADVANCED ANALYTICS
-- =====================================================

-- 6.1: Revenue per Available Seat Mile (RASM) by Route
SELECT
    dr.route_code,
    dr.origin,
    dr.destination,
    COUNT(DISTINCT fb.booking_id) AS bookings,
    SUM(fb.price) AS total_revenue,
    -- Assuming distance is populated; otherwise use a constant or lookup
    COALESCE(dr.distance_km, 500) AS distance_km,
    COUNT(DISTINCT ds.seat_key) AS total_seats,
    ROUND(
        SUM(fb.price) / NULLIF(COALESCE(dr.distance_km, 500) * COUNT(DISTINCT ds.seat_key), 0),
        4
    ) AS rasm
FROM
    fact_bookings fb
INNER JOIN dim_flight df ON fb.flight_key = df.flight_key
INNER JOIN dim_route dr ON df.route_key = dr.route_key
INNER JOIN dim_seat ds ON fb.seat_key = ds.seat_key
WHERE
    fb.is_cancelled = FALSE
GROUP BY
    dr.route_code, dr.origin, dr.destination, dr.distance_km
ORDER BY
    rasm DESC;

-- 6.2: Cohort Analysis - Customer Retention by First Booking Month
WITH customer_cohorts AS (
    SELECT
        dc.customer_key,
        DATE_TRUNC('month', MIN(dd.full_date)) AS cohort_month,
        DATE_TRUNC('month', dd2.full_date) AS booking_month
    FROM
        dim_customer dc
    INNER JOIN fact_bookings fb ON dc.customer_key = fb.customer_key
    INNER JOIN dim_date dd ON fb.booking_date_key = dd.date_key
    INNER JOIN fact_bookings fb2 ON dc.customer_key = fb2.customer_key
    INNER JOIN dim_date dd2 ON fb2.booking_date_key = dd2.date_key
    WHERE
        fb.is_cancelled = FALSE
    GROUP BY
        dc.customer_key, dd2.full_date
)
SELECT
    cohort_month,
    booking_month,
    COUNT(DISTINCT customer_key) AS active_customers,
    EXTRACT(MONTH FROM AGE(booking_month, cohort_month))::INT AS months_since_first_booking
FROM
    customer_cohorts
GROUP BY
    cohort_month, booking_month
ORDER BY
    cohort_month, booking_month;

-- 6.3: Peak Travel Days (Most Popular Departure Dates)
SELECT
    dd.full_date AS departure_date,
    dd.day_name,
    dd.is_weekend,
    COUNT(DISTINCT fb.booking_id) AS bookings,
    SUM(fb.price) AS revenue,
    COUNT(DISTINCT df.flight_key) AS flights
FROM
    fact_bookings fb
INNER JOIN dim_date dd ON fb.departure_date_key = dd.date_key
INNER JOIN dim_flight df ON fb.flight_key = df.flight_key
WHERE
    fb.is_cancelled = FALSE
    AND dd.full_date >= CURRENT_DATE
GROUP BY
    dd.full_date, dd.day_name, dd.is_weekend
ORDER BY
    bookings DESC
LIMIT 20;
