# OLAP Data Warehouse - Complete Architecture

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        OLTP SOURCE SYSTEM                        │
│                    (Transactional Database)                      │
├─────────────────────────────────────────────────────────────────┤
│  • customers (100 records)                                       │
│  • flights (10+ routes, multiple schedules)                      │
│  • seats (10 seats per flight)                                   │
│  • bookings (transaction records)                                │
│  • booking_items (individual seat bookings)                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ ETL Process (Daily)
                         │ • Extract: Query OLTP
                         │ • Transform: Surrogate keys, aggregations
                         │ • Load: Incremental updates
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OLAP DATA WAREHOUSE                           │
│                      (Star Schema)                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │ dim_customer │    │  dim_flight  │    │   dim_seat   │     │
│  ├──────────────┤    ├──────────────┤    ├──────────────┤     │
│  │customer_key  │    │ flight_key   │    │  seat_key    │     │
│  │customer_id   │    │ flight_id    │    │  seat_id     │     │
│  │full_name     │    │ flight_number│    │ seat_number  │     │
│  │email         │    │ route_key FK │    │ seat_class   │     │
│  │segment       │    │ departure    │    │ is_window    │     │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘     │
│         │                   │                    │              │
│         │      ┌──────────────┐                  │              │
│         │      │  dim_route   │                  │              │
│         │      ├──────────────┤                  │              │
│         │      │  route_key   │                  │              │
│         │      │  origin      │                  │              │
│         │      │  destination │                  │              │
│         │      │  route_code  │                  │              │
│         │      └──────────────┘                  │              │
│         │                                         │              │
│         │         ┌──────────────┐               │              │
│         │         │   dim_date   │               │              │
│         │         ├──────────────┤               │              │
│         │         │  date_key    │               │              │
│         │         │  full_date   │               │              │
│         │         │  year/month  │               │              │
│         │         │  is_weekend  │               │              │
│         │         └──────┬───────┘               │              │
│         │                │                       │              │
│         └────────────────┼───────────────────────┘              │
│                          │                                      │
│                          ▼                                      │
│              ┌────────────────────────┐                         │
│              │   fact_bookings        │◄─── Transaction Fact   │
│              ├────────────────────────┤      (Booking events)  │
│              │ booking_fact_key (PK)  │                         │
│              │ customer_key (FK)      │                         │
│              │ flight_key (FK)        │                         │
│              │ seat_key (FK)          │                         │
│              │ booking_date_key (FK)  │                         │
│              │ departure_date_key(FK) │                         │
│              ├────────────────────────┤                         │
│              │ price (measure)        │                         │
│              │ is_cancelled (flag)    │                         │
│              │ booking_lead_days      │                         │
│              └────────────────────────┘                         │
│                                                                  │
│              ┌────────────────────────┐                         │
│              │ fact_seat_inventory    │◄─── Snapshot Fact      │
│              ├────────────────────────┤      (Daily snapshot)  │
│              │ inventory_fact_key(PK) │                         │
│              │ flight_key (FK)        │                         │
│              │ seat_key (FK)          │                         │
│              │ snapshot_date_key (FK) │                         │
│              ├────────────────────────┤                         │
│              │ is_available (flag)    │                         │
│              │ is_booked (flag)       │                         │
│              │ days_until_departure   │                         │
│              └────────────────────────┘                         │
│                                                                  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ANALYTICS & REPORTING                        │
├─────────────────────────────────────────────────────────────────┤
│  • Revenue Analysis (by route, time, class)                      │
│  • Customer Analytics (LTV, segments, retention)                 │
│  • Operational Metrics (load factor, cancellations)              │
│  • Booking Patterns (lead time, velocity)                        │
│  • Inventory Trends (seat availability over time)                │
└─────────────────────────────────────────────────────────────────┘
```

## Star Schema Relationships

```
                    fact_bookings
                    ┌───────────┐
                    │  Measures │
                    │  - price  │
                    └─────┬─────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        │                 │                 │
   ┌────▼────┐      ┌─────▼─────┐    ┌─────▼─────┐
   │customer │      │   flight  │    │   seat    │
   │  dim    │      │    dim    │    │   dim     │
   └─────────┘      └─────┬─────┘    └───────────┘
                          │
                    ┌─────▼─────┐
                    │   route   │
                    │    dim    │
                    └───────────┘
```

## Data Flow Diagram

```
┌─────────────┐
│   OLTP DB   │
│  (Source)   │
└──────┬──────┘
       │
       │ 1. Extract
       │    - Query new/changed records
       │    - Use watermarks from etl_metadata
       │
       ▼
┌─────────────┐
│ Staging     │ (Optional)
│ Area        │
└──────┬──────┘
       │
       │ 2. Transform
       │    - Generate surrogate keys
       │    - Calculate derived metrics
       │    - Data quality checks
       │
       ▼
┌─────────────┐
│ Dimensions  │
│  (Load 1st) │
└──────┬──────┘
       │
       │ 3. Load Facts
       │    - Map surrogate keys
       │    - Validate referential integrity
       │
       ▼
┌─────────────┐
│   Facts     │
│ (Load 2nd)  │
└──────┬──────┘
       │
       │ 4. Post-Processing
       │    - Update aggregates
       │    - Refresh materialized views
       │    - Update metadata
       │
       ▼
┌─────────────┐
│  Analytics  │
│   Ready!    │
└─────────────┘
```

## Dimensional Model Details

### Dimension Tables (5)

| Dimension | Purpose | Rows (Est) | SCD Type | Key Attributes |
|-----------|---------|------------|----------|----------------|
| dim_customer | Who books | 100+ | Type 1 | segment, total_spent |
| dim_flight | What flight | 100+ | Type 1 | departure_time, route |
| dim_route | Where (O-D) | 20-50 | Type 0 | origin, destination |
| dim_seat | Which seat | 1,000+ | Type 0 | class, position |
| dim_date | When | 3,650 | Type 0 | year, month, is_weekend |

### Fact Tables (2)

| Fact Table | Type | Grain | Rows (Est) | Growth |
|------------|------|-------|------------|--------|
| fact_bookings | Transaction | One row per seat booked | 10,000+/mo | High |
| fact_seat_inventory | Periodic Snapshot | One row per seat per day | 10,000/day | Medium |

## ETL Pipeline Execution Flow

```
┌────────────────────────────────────────────────────────────┐
│                  DAILY ETL SCHEDULE                        │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  01:00 AM  ┌─────────────────────────┐                    │
│            │  Load Dimensions        │                    │
│            │  - dim_customer         │                    │
│            │  - dim_route            │                    │
│            │  - dim_flight           │                    │
│            │  - dim_seat             │                    │
│            └────────┬────────────────┘                    │
│                     │                                      │
│  02:00 AM           ▼                                      │
│            ┌─────────────────────────┐                    │
│            │  Load fact_bookings     │                    │
│            │  (Incremental)          │                    │
│            └────────┬────────────────┘                    │
│                     │                                      │
│  03:00 AM           ▼                                      │
│            ┌─────────────────────────┐                    │
│            │ Load fact_seat_inventory│                    │
│            │  (Daily Snapshot)       │                    │
│            └────────┬────────────────┘                    │
│                     │                                      │
│  04:00 AM           ▼                                      │
│            ┌─────────────────────────┐                    │
│            │  Update Derived Metrics │                    │
│            │  - Customer aggregates  │                    │
│            │  - Segments             │                    │
│            └────────┬────────────────┘                    │
│                     │                                      │
│  05:00 AM           ▼                                      │
│            ┌─────────────────────────┐                    │
│            │  Data Quality Checks    │                    │
│            │  - Orphaned records     │                    │
│            │  - Missing keys         │                    │
│            └────────┬────────────────┘                    │
│                     │                                      │
│                     ▼                                      │
│            ┌─────────────────────────┐                    │
│            │  Update Metadata        │                    │
│            │  - etl_metadata table   │                    │
│            │  - ANALYZE tables       │                    │
│            └─────────────────────────┘                    │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

## Key Design Patterns

### 1. Surrogate Keys
```
OLTP (Natural Key)          OLAP (Surrogate Key)
customer_id = 42     ────►  customer_key = 1
flight_id = 7        ────►  flight_key = 3
```

### 2. Slowly Changing Dimensions (Type 1)
```
Before:  customer_key=1, email='old@email.com', updated_at='2025-01-01'
Change:  Customer updates email
After:   customer_key=1, email='new@email.com', updated_at='2025-11-25'
         (Old value is overwritten - no history)
```

### 3. Fact Table Grain
```
fact_bookings:
- Grain: One row = One seat in one booking
- Example: Booking #123 has 2 seats → 2 rows in fact table
- Allows: Sum(price) for total revenue per booking
```

### 4. Conformed Dimensions
```
dim_flight ──┐
             ├──► Used by both fact tables
             │
fact_bookings ──┐
                 ├──► dim_flight (shared)
fact_seat_inventory ──┘
```

## Performance Optimization

### Indexing Strategy
```sql
-- Fact Table Indexes (already created)
CREATE INDEX idx_fact_bookings_customer ON fact_bookings(customer_key);
CREATE INDEX idx_fact_bookings_flight ON fact_bookings(flight_key);
CREATE INDEX idx_fact_bookings_date ON fact_bookings(booking_date_key);

-- Composite indexes for common patterns
CREATE INDEX idx_fact_route_time ON fact_bookings(flight_key, booking_date_key);
```

### Partitioning (For Large Datasets)
```sql
-- Partition by month
CREATE TABLE fact_bookings_202512 PARTITION OF fact_bookings
    FOR VALUES FROM (20251201) TO (20260101);
```

### Query Optimization
```sql
-- Use date dimension for filtering (indexed)
WHERE dd.year = 2025 AND dd.month = 12

-- Avoid function calls on fact columns
WHERE booking_date_key >= 20251201  -- Good
WHERE DATE(booked_at) >= '2025-12-01'  -- Bad (no index)
```

## File Organization

```
warehouse/
├── WAREHOUSE_DESIGN.md           # Comprehensive design doc
├── ARCHITECTURE.md                # This file - visual guide
├── README.md                      # Quick start guide
├── ddl_warehouse_schema.sql      # Create all tables
├── etl_dimensions.sql            # Load dimensions
├── etl_facts.sql                 # Load facts
├── etl_master_pipeline.sql       # Complete orchestrated ETL
└── sample_olap_queries.sql       # 30+ ready queries
```

## Implementation Checklist

- [ ] 1. Review WAREHOUSE_DESIGN.md for concepts
- [ ] 2. Run ddl_warehouse_schema.sql to create tables
- [ ] 3. Populate dim_date (10 years)
- [ ] 4. Run initial dimension load (etl_dimensions.sql)
- [ ] 5. Run initial fact load (etl_facts.sql)
- [ ] 6. Verify data with sample queries
- [ ] 7. Schedule daily ETL (etl_master_pipeline.sql)
- [ ] 8. Set up monitoring (etl_metadata checks)
- [ ] 9. Test report queries (sample_olap_queries.sql)
- [ ] 10. Document custom modifications

## Next Steps

1. **Deploy**: Run DDL scripts to create warehouse
2. **Populate**: Execute initial ETL load
3. **Validate**: Run sample queries to verify
4. **Schedule**: Set up daily ETL automation
5. **Monitor**: Track ETL success via metadata
6. **Extend**: Add custom dimensions/facts as needed

## Support Resources

- **Design Philosophy**: See `WAREHOUSE_DESIGN.md`
- **Setup Guide**: See `README.md`
- **Sample Queries**: See `sample_olap_queries.sql`
- **Full ETL**: Use `etl_master_pipeline.sql` for production
