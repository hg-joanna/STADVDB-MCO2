const reportsDb = require('../db/reportsDb');

// =====================================================
// REVENUE REPORTS
// =====================================================

// Get revenue by route
exports.getRevenueByRoute = async (req, res) => {
  try {
    const query = `
      SELECT
        dr.route_code,
        dr.origin,
        dr.destination,
        COUNT(DISTINCT fb.booking_id) AS total_bookings,
        SUM(fb.price) AS total_revenue,
        ROUND(AVG(fb.price), 2) AS avg_price_per_seat,
        SUM(CASE WHEN fb.is_cancelled THEN 0 ELSE fb.price END) AS revenue_after_cancellations
      FROM fact_bookings fb
      INNER JOIN dim_flight df ON fb.flight_key = df.flight_key
      INNER JOIN dim_route dr ON df.route_key = dr.route_key
      GROUP BY dr.route_code, dr.origin, dr.destination
      ORDER BY total_revenue DESC
      LIMIT 10;
    `;
    const result = await reportsDb.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch revenue by route' });
  }
};

// Get revenue by seat class
exports.getRevenueBySeatClass = async (req, res) => {
  try {
    const query = `
      SELECT
        ds.seat_class,
        COUNT(fb.booking_fact_key) AS seats_booked,
        SUM(fb.price) AS total_revenue,
        ROUND(AVG(fb.price), 2) AS avg_price,
        MIN(fb.price) AS min_price,
        MAX(fb.price) AS max_price
      FROM fact_bookings fb
      INNER JOIN dim_seat ds ON fb.seat_key = ds.seat_key
      WHERE fb.is_cancelled = FALSE
      GROUP BY ds.seat_class
      ORDER BY total_revenue DESC;
    `;
    const result = await reportsDb.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch revenue by seat class' });
  }
};

// Get monthly revenue trend
exports.getMonthlyRevenue = async (req, res) => {
  try {
    const { year } = req.query;
    const selectedYear = year || 2025;
    
    const query = `
      SELECT
        dd.year,
        dd.month,
        dd.month_name,
        COUNT(DISTINCT fb.booking_id) AS bookings,
        COALESCE(SUM(fb.price), 0) AS revenue,
        COALESCE(SUM(CASE WHEN fb.is_cancelled THEN fb.price ELSE 0 END), 0) AS cancelled_revenue,
        ROUND(COALESCE(SUM(CASE WHEN fb.is_cancelled THEN fb.price ELSE 0 END) * 100.0 / NULLIF(SUM(fb.price), 0), 0), 2) AS cancellation_rate_pct
      FROM dim_date dd
      LEFT JOIN fact_bookings fb ON fb.booking_date_key = dd.date_key
      WHERE dd.year = $1
      GROUP BY dd.year, dd.month, dd.month_name
      ORDER BY dd.month;
    `;
    const result = await reportsDb.query(query, [selectedYear]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch monthly revenue' });
  }
};

// =====================================================
// BOOKING ANALYTICS
// =====================================================

// Get booking lead time distribution
exports.getBookingLeadTime = async (req, res) => {
  try {
    const query = `
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
      FROM fact_bookings
      WHERE is_cancelled = FALSE
      GROUP BY lead_time_bucket
      ORDER BY MIN(booking_to_departure_days);
    `;
    const result = await reportsDb.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch booking lead time' });
  }
};

// Get peak booking hours
exports.getPeakBookingHours = async (req, res) => {
  try {
    const query = `
      SELECT
        booking_hour,
        COUNT(*) AS bookings,
        SUM(price) AS revenue,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS booking_percentage
      FROM fact_bookings
      WHERE is_cancelled = FALSE
      GROUP BY booking_hour
      ORDER BY booking_hour;
    `;
    const result = await reportsDb.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch peak booking hours' });
  }
};

// Get booking patterns (weekend vs weekday)
exports.getBookingPatterns = async (req, res) => {
  try {
    const query = `
      SELECT
        dd.is_weekend,
        CASE WHEN dd.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS period_type,
        COUNT(*) AS bookings,
        SUM(fb.price) AS revenue,
        ROUND(AVG(fb.price), 2) AS avg_price
      FROM fact_bookings fb
      INNER JOIN dim_date dd ON fb.booking_date_key = dd.date_key
      WHERE fb.is_cancelled = FALSE
      GROUP BY dd.is_weekend
      ORDER BY dd.is_weekend;
    `;
    const result = await reportsDb.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch booking patterns' });
  }
};

// =====================================================
// CUSTOMER ANALYTICS
// =====================================================

// Get customer segments
exports.getCustomerSegments = async (req, res) => {
  try {
    const query = `
      SELECT
        dc.customer_segment,
        COUNT(DISTINCT dc.customer_key) AS customer_count,
        COUNT(DISTINCT fb.booking_id) AS total_bookings,
        COALESCE(SUM(fb.price), 0) AS total_revenue,
        ROUND(COALESCE(AVG(fb.price), 0), 2) AS avg_booking_value,
        ROUND(COALESCE(SUM(fb.price) * 100.0 / NULLIF(SUM(SUM(fb.price)) OVER (), 0), 0), 2) AS revenue_share_pct
      FROM dim_customer dc
      LEFT JOIN fact_bookings fb ON dc.customer_key = fb.customer_key AND fb.is_cancelled = FALSE
      WHERE dc.customer_segment IS NOT NULL
      GROUP BY dc.customer_segment
      ORDER BY total_revenue DESC;
    `;
    const result = await reportsDb.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch customer segments' });
  }
};

// Get top customers by spend
exports.getTopCustomers = async (req, res) => {
  try {
    const { limit } = req.query;
    const topLimit = limit || 20;
    
    const query = `
      SELECT
        dc.customer_id,
        dc.full_name,
        dc.email,
        dc.customer_segment,
        COUNT(DISTINCT fb.booking_id) AS total_bookings,
        COALESCE(SUM(fb.price), 0) AS total_spent,
        ROUND(COALESCE(AVG(fb.price), 0), 2) AS avg_booking_value,
        MIN(dd.full_date) AS first_booking_date,
        MAX(dd.full_date) AS last_booking_date
      FROM dim_customer dc
      LEFT JOIN fact_bookings fb ON dc.customer_key = fb.customer_key
      LEFT JOIN dim_date dd ON fb.booking_date_key = dd.date_key
      WHERE fb.is_cancelled = FALSE OR fb.is_cancelled IS NULL
      GROUP BY dc.customer_id, dc.full_name, dc.email, dc.customer_segment
      ORDER BY total_spent DESC
      LIMIT $1;
    `;
    const result = await reportsDb.query(query, [topLimit]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch top customers' });
  }
};

// =====================================================
// OPERATIONAL METRICS
// =====================================================

// Get seat utilization by class
exports.getSeatUtilization = async (req, res) => {
  try {
    const query = `
      SELECT
        ds.seat_class,
        COUNT(*) AS total_seats,
        SUM(CASE WHEN fsi.is_available THEN 1 ELSE 0 END) AS available_seats,
        SUM(CASE WHEN fsi.is_booked THEN 1 ELSE 0 END) AS booked_seats,
        ROUND(SUM(CASE WHEN fsi.is_booked THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS utilization_pct
      FROM dim_seat ds
      JOIN fact_seat_inventory fsi ON ds.seat_key = fsi.seat_key
      WHERE fsi.snapshot_date = CURRENT_DATE
      GROUP BY ds.seat_class
      ORDER BY ds.seat_class;
    `;
    const result = await reportsDb.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch seat utilization' });
  }
};

// Get cancellation rate by route
exports.getCancellationRate = async (req, res) => {
  try {
    const query = `
      SELECT
        dr.route_code,
        dr.origin,
        dr.destination,
        COUNT(*) AS total_bookings,
        SUM(CASE WHEN fb.is_cancelled THEN 1 ELSE 0 END) AS cancelled_bookings,
        ROUND(SUM(CASE WHEN fb.is_cancelled THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate_pct
      FROM fact_bookings fb
      INNER JOIN dim_flight df ON fb.flight_key = df.flight_key
      INNER JOIN dim_route dr ON df.route_key = dr.route_key
      GROUP BY dr.route_code, dr.origin, dr.destination
      HAVING COUNT(*) > 5
      ORDER BY cancellation_rate_pct DESC;
    `;
    const result = await reportsDb.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch cancellation rates' });
  }
};

// Get load factor (flights with % seats sold)
exports.getLoadFactor = async (req, res) => {
  try {
    const query = `
      WITH flight_capacity AS (
        SELECT
          df.flight_key,
          df.flight_number,
          dr.route_code,
          df.departure_time,
          COUNT(DISTINCT fsi.seat_key) AS total_seats,
          SUM(CASE WHEN fsi.is_booked THEN 1 ELSE 0 END) AS booked_seats
        FROM dim_flight df
        INNER JOIN dim_route dr ON df.route_key = dr.route_key
        LEFT JOIN fact_seat_inventory fsi ON df.flight_key = fsi.flight_key AND fsi.snapshot_date = CURRENT_DATE
        WHERE df.departure_time >= CURRENT_DATE
        GROUP BY df.flight_key, df.flight_number, dr.route_code, df.departure_time
      )
      SELECT
        flight_number,
        route_code,
        departure_time,
        total_seats,
        booked_seats,
        total_seats - booked_seats AS available_seats,
        ROUND(booked_seats * 100.0 / NULLIF(total_seats, 0), 2) AS load_factor_pct
      FROM flight_capacity
      WHERE total_seats > 0
      ORDER BY departure_time
      LIMIT 20;
    `;
    const result = await reportsDb.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch load factor' });
  }
};

// =====================================================
// ROUTE ANALYTICS
// =====================================================

// Get top routes by flight volume
exports.getTopRoutes = async (req, res) => {
  try {
    const query = `
      SELECT
        dr.route_code,
        dr.origin,
        dr.destination,
        COUNT(DISTINCT df.flight_key) AS total_flights,
        COUNT(DISTINCT fb.booking_id) AS total_bookings,
        COALESCE(SUM(fb.price), 0) AS total_revenue
      FROM dim_route dr
      LEFT JOIN dim_flight df ON dr.route_key = df.route_key
      LEFT JOIN fact_bookings fb ON df.flight_key = fb.flight_key AND fb.is_cancelled = FALSE
      GROUP BY dr.route_code, dr.origin, dr.destination
      ORDER BY total_flights DESC, total_revenue DESC
      LIMIT 10;
    `;
    const result = await reportsDb.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch top routes' });
  }
};

// =====================================================
// DASHBOARD SUMMARY
// =====================================================

// Get dashboard summary with key metrics
exports.getDashboardSummary = async (req, res) => {
  try {
    const queries = {
      totalRevenue: `
        SELECT COALESCE(SUM(price), 0) as total_revenue 
        FROM fact_bookings 
        WHERE is_cancelled = FALSE
      `,
      totalBookings: `
        SELECT COUNT(DISTINCT booking_id) as total_bookings 
        FROM fact_bookings 
        WHERE is_cancelled = FALSE
      `,
      totalCustomers: `
        SELECT COUNT(*) as total_customers 
        FROM dim_customer
      `,
      avgBookingValue: `
        SELECT ROUND(AVG(price), 2) as avg_booking_value 
        FROM fact_bookings 
        WHERE is_cancelled = FALSE
      `,
      currentUtilization: `
        SELECT ROUND(SUM(CASE WHEN is_booked THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as utilization_pct
        FROM fact_seat_inventory 
        WHERE snapshot_date = CURRENT_DATE
      `,
      cancellationRate: `
        SELECT ROUND(SUM(CASE WHEN is_cancelled THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as cancellation_rate
        FROM fact_bookings
      `
    };

    const results = {};
    for (const [key, query] of Object.entries(queries)) {
      const result = await reportsDb.query(query);
      results[key] = result.rows[0];
    }

    res.json(results);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch dashboard summary' });
  }
};

// =====================================================
// FLIGHT OCCUPANCY (Frontend Compatibility)
// =====================================================

// Get flight occupancy for the frontend report page
exports.getFlightOccupancy = async (req, res) => {
  try {
    const query = `
      SELECT 
        CONCAT(df.flight_number, ' (', dr.origin, ' → ', dr.destination, ')') AS flight,
        SUM(CASE WHEN fsi.is_booked THEN 1 ELSE 0 END)::int AS booked,
        SUM(CASE WHEN fsi.is_available THEN 1 ELSE 0 END)::int AS available
      FROM fact_seat_inventory fsi
      INNER JOIN dim_flight df ON fsi.flight_key = df.flight_key
      INNER JOIN dim_route dr ON df.route_key = dr.route_key
      WHERE fsi.snapshot_date = (SELECT MAX(snapshot_date) FROM fact_seat_inventory)
      GROUP BY df.flight_number, dr.origin, dr.destination
      ORDER BY df.flight_number
    `;
    const result = await reportsDb.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch flight occupancy' });
  }
};
