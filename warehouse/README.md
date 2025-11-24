# OLAP Data Warehouse - Quick Start Guide

## Overview
This warehouse transforms the OLTP airline booking system into a star schema optimized for analytics and reporting.

## File Structure

```
warehouse/
├── WAREHOUSE_DESIGN.md           # Comprehensive design documentation
├── ddl_warehouse_schema.sql      # Create all dimension and fact tables
├── etl_dimensions.sql            # Load dimension tables from OLTP
├── etl_facts.sql                 # Load fact tables with surrogate keys
├── sample_olap_queries.sql       # 30+ ready-to-use analytics queries
└── README.md                     # This file
```

## Quick Setup (5 Steps)

### 1. Create Warehouse Schema
```sql
-- Run in your OLAP database (can be same or different from OLTP)
psql -h localhost -U postgres -d flight_booking -f ddl_warehouse_schema.sql
```

### 2. Populate Date Dimension
```sql
-- Pre-populate 10 years of dates (run once)
psql -h localhost -U postgres -d flight_booking -c "
-- Run the dim_date population from etl_dimensions.sql
"
```

### 3. Initial Dimension Load
```sql
-- Load all dimensions from OLTP source
psql -h localhost -U postgres -d flight_booking -f etl_dimensions.sql
```

### 4. Initial Fact Load
```sql
-- Load historical bookings and inventory snapshots
psql -h localhost -U postgres -d flight_booking -f etl_facts.sql
```

### 5. Schedule Daily ETL
```bash
# Add to cron for daily execution
0 2 * * * psql -h localhost -U postgres -d flight_booking -c "
-- Run incremental ETL from etl_facts.sql
"
```

## Star Schema Structure

```
Dimensions:
- dim_customer  (Who books)
- dim_flight    (What flight)
- dim_route     (Origin-Destination)
- dim_seat      (Seat details)
- dim_date      (When)

Facts:
- fact_bookings         (Transaction: Each booking)
- fact_seat_inventory   (Snapshot: Daily seat status)
```

## Key Features

### ✅ Surrogate Keys
All dimensions use auto-incrementing surrogate keys (e.g., `customer_key`, `flight_key`)

### ✅ SCD Type 1
Dimensions track current state with `updated_at` timestamps

### ✅ Incremental ETL
Uses `etl_metadata` table to track watermarks and load only new/changed records

### ✅ Data Quality
- Unknown dimension records for orphaned data
- Validation checks in ETL
- Error tracking in metadata

### ✅ Performance
- Indexes on all FK columns
- Composite indexes for common queries
- Partitioning strategy for large facts

## Common Use Cases

### Revenue Analysis
```sql
-- Monthly revenue by route
SELECT dr.route_code, dd.month_name, SUM(fb.price) AS revenue
FROM fact_bookings fb
JOIN dim_flight df ON fb.flight_key = df.flight_key
JOIN dim_route dr ON df.route_key = dr.route_key
JOIN dim_date dd ON fb.booking_date_key = dd.date_key
WHERE fb.is_cancelled = FALSE
GROUP BY dr.route_code, dd.month_name;
```

### Load Factor
```sql
-- Percentage of seats sold per flight
SELECT df.flight_number, 
       COUNT(DISTINCT fb.seat_key) * 100.0 / 10 AS load_factor_pct
FROM dim_flight df
LEFT JOIN fact_bookings fb ON df.flight_key = fb.flight_key
WHERE fb.is_cancelled = FALSE OR fb.booking_fact_key IS NULL
GROUP BY df.flight_number;
```

### Customer Lifetime Value
```sql
-- Top customers by total spend
SELECT dc.full_name, dc.email, SUM(fb.price) AS lifetime_value
FROM fact_bookings fb
JOIN dim_customer dc ON fb.customer_key = dc.customer_key
WHERE fb.is_cancelled = FALSE
GROUP BY dc.full_name, dc.email
ORDER BY lifetime_value DESC
LIMIT 10;
```

## ETL Schedule Recommendations

| Task | Frequency | Time | Notes |
|------|-----------|------|-------|
| Dimension Load | Daily | 1:00 AM | Catch new customers/flights |
| Fact Bookings | Daily | 2:00 AM | Load yesterday's bookings |
| Seat Inventory Snapshot | Daily | 3:00 AM | Capture current state |
| Aggregates Refresh | Daily | 4:00 AM | Update materialized views |
| Customer Metrics Update | Weekly | Sunday 5:00 AM | Recalculate segments |

## Performance Tuning

### Partitioning (For Large Datasets)
```sql
-- Partition fact_bookings by month
CREATE TABLE fact_bookings (
    -- columns...
) PARTITION BY RANGE (booking_date_key);

CREATE TABLE fact_bookings_202512 PARTITION OF fact_bookings
    FOR VALUES FROM (20251201) TO (20260101);
```

### Materialized Views (For Heavy Queries)
```sql
-- Pre-aggregate monthly revenue
CREATE MATERIALIZED VIEW mv_monthly_revenue AS
SELECT dr.route_code, dd.year, dd.month, SUM(fb.price) AS revenue
FROM fact_bookings fb
JOIN dim_flight df ON fb.flight_key = df.flight_key
JOIN dim_route dr ON df.route_key = dr.route_key
JOIN dim_date dd ON fb.booking_date_key = dd.date_key
WHERE fb.is_cancelled = FALSE
GROUP BY dr.route_code, dd.year, dd.month;

-- Refresh daily
REFRESH MATERIALIZED VIEW mv_monthly_revenue;
```

### Indexes for Common Patterns
```sql
-- Already included in ddl_warehouse_schema.sql
-- Add custom indexes based on your query patterns:
CREATE INDEX idx_custom_pattern ON fact_bookings(flight_key, booking_date_key)
WHERE is_cancelled = FALSE;
```

## Monitoring

### Check ETL Status
```sql
SELECT * FROM etl_metadata ORDER BY last_etl_timestamp DESC;
```

### Data Quality Checks
```sql
-- Orphaned records
SELECT COUNT(*) FROM fact_bookings fb
LEFT JOIN dim_customer dc ON fb.customer_key = dc.customer_key
WHERE dc.customer_key IS NULL;

-- Missing dates
SELECT COUNT(*) FROM fact_bookings fb
LEFT JOIN dim_date dd ON fb.booking_date_key = dd.date_key
WHERE dd.date_key IS NULL;
```

### Table Sizes
```sql
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE tablename LIKE 'dim_%' OR tablename LIKE 'fact_%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Extending the Warehouse

### Add New Dimensions
1. Create dimension table in `ddl_warehouse_schema.sql`
2. Add ETL logic in `etl_dimensions.sql`
3. Add FK to relevant fact tables
4. Update `etl_metadata` with new entry

### Add New Facts
1. Identify grain (one row represents what?)
2. Design fact table with appropriate measures
3. Add dimension FKs
4. Create ETL in `etl_facts.sql`
5. Add indexes and partitioning

### Add New Measures
```sql
-- Example: Add discount_amount to fact_bookings
ALTER TABLE fact_bookings ADD COLUMN discount_amount NUMERIC(10,2) DEFAULT 0;

-- Update ETL to populate
UPDATE fact_bookings fb SET
    discount_amount = b.discount_amount
FROM bookings b
WHERE fb.booking_id = b.booking_id;
```

## Troubleshooting

### ETL Fails
```sql
-- Check error messages
SELECT * FROM etl_metadata WHERE status = 'FAILED';

-- Reset watermark to re-run
UPDATE etl_metadata SET last_etl_timestamp = '2025-11-01 00:00:00'
WHERE table_name = 'fact_bookings';
```

### Slow Queries
- Use `EXPLAIN ANALYZE` to identify bottlenecks
- Add indexes on frequently filtered columns
- Consider partitioning large fact tables
- Use materialized views for complex aggregations

### Data Inconsistencies
- Run data quality checks regularly
- Ensure dimension tables are loaded before facts
- Validate surrogate key mappings
- Check for missing "Unknown" dimension records

## Best Practices

1. **Always load dimensions before facts** - FK constraints require valid dimension keys
2. **Use transactions** - Wrap ETL in BEGIN/COMMIT blocks
3. **Track watermarks** - Use `etl_metadata` to avoid reprocessing
4. **Test on sample data** - Validate ETL logic with small datasets first
5. **Monitor performance** - Track query execution times and optimize indexes
6. **Document custom changes** - Keep this README updated with modifications

## Support & Documentation

- Full design: See `WAREHOUSE_DESIGN.md`
- Sample queries: See `sample_olap_queries.sql`
- Schema details: See `ddl_warehouse_schema.sql`

## Version History

- **v1.0** (2025-11-25): Initial warehouse design with core dimensions and facts
