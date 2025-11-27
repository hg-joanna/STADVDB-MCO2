# Architecture Review: Flight Booking System Database Design

**Reviewer:** Senior Backend/Data Engineer & Database Architect  
**Date:** November 2025  
**Repository:** STADVDB-MCO2

---

## Executive Summary

This document provides a comprehensive architecture review of the Flight Booking System, mapping implementation to requirements, explaining design choices, and identifying gaps and risks. The system demonstrates a **solid understanding of database architecture principles** with proper separation of OLTP and OLAP workloads, appropriate replication strategies, and a well-designed star schema for analytics.

**Overall Assessment:** ✅ **Well Implemented** with some areas for improvement

---

## 1. Overall Architecture Summary

### High-Level Database Topology

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DOCKER NETWORK                                     │
│                      (flight_booking_network)                               │
│                                                                             │
│  ┌────────────────┐                                                         │
│  │  App Server    │──────────────┐                                          │
│  │  (Node.js)     │              │                                          │
│  │  Port: 4000    │              │                                          │
│  └────────────────┘              │                                          │
│         │                         │                                          │
│         │ OLTP Operations         │ Analytical Queries                       │
│         │ (db/db.js)              │ (db/reportsDb.js)                        │
│         ▼                         ▼                                          │
│  ┌────────────────┐        ┌────────────────┐                               │
│  │  Primary DB    │        │  Reports DB    │                               │
│  │  (OLTP)        │═══════>│  (OLAP)        │                               │
│  │  Port: 5432    │ Logical│  Port: 5434    │                               │
│  └────────────────┘ Replic │                │                               │
│         │                   │  Star Schema   │                               │
│         │ Physical         │  Warehouse     │                               │
│         │ Replication      └────────────────┘                               │
│         ▼                                                                    │
│  ┌────────────────┐                                                         │
│  │  Hot Backup DB │                                                         │
│  │  (Standby)     │                                                         │
│  │  Port: 5433    │                                                         │
│  └────────────────┘                                                         │
│                                                                             │
│  ┌────────────────┐                                                         │
│  │  WAL Archive   │ (Shared volume: /var/lib/postgresql/wal_archive)        │
│  └────────────────┘                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Database Connections in Application Code

| Connection | File | Target | Purpose |
|------------|------|--------|---------|
| Primary Pool | `db/db.js` | `primary_db:5432` | All transactional operations |
| Reports Pool | `db/reportsDb.js` | `reports_db:5432` | All analytical/reporting queries |

**✅ Good Pattern:** Clean separation of connection pools ensures OLTP and OLAP workloads don't interfere with each other.

---

## 2. Schema Design for Analytics

### 2.1 OLTP Schema (Normalized)

**Location:** `db_scripts/flights_oltp_schema.sql`

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   flights    │     │    seats     │     │  customers   │
├──────────────┤     ├──────────────┤     ├──────────────┤
│ flight_id PK │<───>│ flight_id FK │     │ customer_id  │
│ flight_number│     │ seat_id PK   │     │ full_name    │
│ origin       │     │ seat_number  │     │ email (UQ)   │
│ destination  │     │ seat_class   │     │ phone        │
│ departure_at │     │ price        │     └──────┬───────┘
│ arrival_at   │     │ is_available │            │
└──────────────┘     └──────┬───────┘            │
                            │                    │
                    ┌───────┴───────┐            │
                    │               │            │
              ┌─────▼─────┐   ┌─────▼────────────▼─────┐
              │ booking   │   │      bookings          │
              │  items    │   ├────────────────────────┤
              ├───────────┤   │ booking_id PK          │
              │ item_id PK│   │ booking_reference UUID │
              │ booking_id│<──│ customer_id FK         │
              │ seat_id FK│   │ flight_id FK           │
              │ price     │   │ total_price            │
              └───────────┘   │ booked_at              │
                              │ status                 │
                              └────────────────────────┘
```

**Design Assessment:**
- ✅ **Properly normalized** to 3NF for transactional integrity
- ✅ **Appropriate indexes** on foreign keys and frequently queried columns
- ✅ **Check constraints** on status and seat_class fields
- ✅ **UUID booking references** for external communication (good security practice)

### 2.2 OLAP Schema (Denormalized Star Schema)

**Location:** `warehouse/ddl_warehouse_schema.sql`

```
                     ┌───────────────┐
                     │  dim_customer │
                     ├───────────────┤
                     │ customer_key  │ (Surrogate)
                     │ customer_id   │ (Natural)
                     │ full_name     │
                     │ email         │
                     │ customer_segment │ (Derived: VIP/Regular/One-time)
                     │ total_bookings   │ (Pre-aggregated)
                     │ total_spent      │ (Pre-aggregated)
                     └───────┬───────┘
                             │
┌───────────────┐           │           ┌───────────────┐
│   dim_route   │           │           │   dim_seat    │
├───────────────┤           │           ├───────────────┤
│ route_key     │           │           │ seat_key      │
│ origin        │           │           │ seat_id       │
│ destination   │           │           │ seat_number   │
│ route_code    │           │           │ seat_class    │
│ region        │           │           │ is_window     │ (Derived)
└───────┬───────┘           │           │ is_aisle      │ (Derived)
        │                   │           └───────┬───────┘
        │          ┌────────┴────────┐          │
        │          │ fact_bookings   │          │
        │          ├─────────────────┤          │
        │          │ booking_fact_key│          │
        └──────────│ customer_key FK │──────────┘
                   │ flight_key FK   │
                   │ seat_key FK     │
                   │ booking_date_key│──────┐
                   │ departure_date_key│────│──┐
                   │ price (MEASURE) │     │  │
                   │ is_cancelled    │     │  │
                   │ booking_to_departure_days│ │  (Derived)
                   └─────────────────┘     │  │
                             │              │  │
                    ┌────────┴────────┐    │  │
                    │   dim_flight    │    │  │
                    ├─────────────────┤    │  │
                    │ flight_key      │    │  │
                    │ flight_id       │    │  │
                    │ route_key FK    │    │  │
                    │ departure_hour  │ (Derived)
                    │ departure_dow   │ (Derived)
                    │ is_weekend_flight│(Derived)
                    └─────────────────┘    │  │
                                           │  │
                    ┌──────────────────────┴──┴─┐
                    │        dim_date           │
                    ├───────────────────────────┤
                    │ date_key (YYYYMMDD)       │
                    │ full_date                 │
                    │ year, quarter, month      │
                    │ day, day_of_week          │
                    │ is_weekend, is_holiday    │
                    │ fiscal_year, fiscal_qtr   │
                    └───────────────────────────┘
```

**Design Assessment:**

✅ **Excellent Practices:**
1. **Surrogate keys** used throughout (customer_key, flight_key, etc.) - enables SCD handling
2. **Conformed dimensions** shared between fact tables
3. **Pre-aggregated metrics** in dim_customer (total_spent, total_bookings)
4. **Derived attributes** for common analytical slices (is_weekend, is_window_seat)
5. **Date dimension** pre-populated with 10 years of data (2020-2030)
6. **Integer date keys** (YYYYMMDD format) for efficient range scans
7. **Two fact tables** supporting different analytical patterns (see `warehouse/ddl_warehouse_schema.sql` lines 159-245):
   - `fact_bookings`: Transaction grain (one row per seat booked) - lines 159-207
   - `fact_seat_inventory`: Periodic snapshot (daily seat availability) - lines 209-245

✅ **Index Strategy:**
```sql
-- Fact table indexes for common query patterns
CREATE INDEX idx_fact_bookings_customer ON fact_bookings(customer_key);
CREATE INDEX idx_fact_bookings_flight ON fact_bookings(flight_key);
CREATE INDEX idx_fact_bookings_booking_date ON fact_bookings(booking_date_key);

-- Composite indexes for common joins
CREATE INDEX idx_fact_bookings_flight_date ON fact_bookings(flight_key, booking_date_key);
```

**Challenge Question:** *"Does this really separate OLTP vs OLAP cleanly?"*

**Answer:** Yes, and here's why:
- OLTP tables in the reports DB are populated via logical replication (source data)
- Warehouse tables (dim_*, fact_*) are populated via ETL from OLTP tables
- Application code uses separate connection pools (`db.js` vs `reportsDb.js`)
- Controllers route to correct database (booking operations → primary, reports → reports_db)

---

## 3. Primary DB Usage

### 3.1 Transactional Operations

**All OLTP operations correctly hit the primary database:**

| Operation | Controller | SQL File | Database |
|-----------|------------|----------|----------|
| Single seat booking | `bookingController.singleSeatBooking` | `single_seat_booking.sql` | Primary |
| Batch booking | `bookingController.batchBooking` | `batch_booking.sql` | Primary |
| Cancel booking | `bookingController.cancelBooking` | `cancel_booking.sql` | Primary |
| Get flights | `flightController.getAllFlights` | `get_all_flights.sql` | Primary |
| Get available seats | `flightController.getAvailableSeats` | inline SQL | Primary |

**Code Evidence:**
```javascript
// bookingController.js - Uses db/db.js (primary)
const db = require('../db/db');
const client = await db.getClient();
await client.query('BEGIN');
const result = await client.query(singleSeatSQL, [customer_id, flight_id, seat_number, total_price]);
await client.query('COMMIT');
```

✅ **Good Patterns Observed:**
1. Proper transaction management with BEGIN/COMMIT/ROLLBACK
2. Client acquisition from pool for transaction scope
3. Row-level locking with `FOR UPDATE` in booking queries
4. Error handling with proper rollback on failure

### 3.2 Analytical Operations on Primary DB

**Question:** *"Are any analytical queries still hitting primary (and are they real-time use-cases)?"*

**Answer:** No - all analytical queries are routed to the reports database:

```javascript
// reportsController.js - Uses db/reportsDb.js (reports)
const reportsDb = require('../db/reportsDb');
const result = await reportsDb.query(query);
```

The flight availability query (`getAvailableSeats`) hits the primary, but this is correctly a **real-time requirement** - customers need current seat availability, not stale data.

✅ **Correctly separated:** Real-time operational queries → Primary; Historical analytics → Reports DB

---

## 4. Hot Backup / Physical Replication / Failover

### 4.1 Physical Replication Configuration

**Location:** `docker-compose.yml` (lines 63-104), `docker/primary-db/01-init-primary.sh`

**Primary DB Configuration:**
```yaml
command: ["postgres", "-c", "wal_level=logical", "-c", "max_wal_senders=10", 
          "-c", "max_replication_slots=10", "-c", "wal_keep_size=64"]
```

**Additional settings in init script:**
```bash
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f'
archive_timeout = 3600  # Archive every hour
hot_standby = on
```

**Hot Backup Setup:**
```yaml
# docker-compose.yml - hot_backup_db (lines 83-97)
# Note: PGPASSWORD usage is acceptable for development/Docker environments.
# For production, use .pgpass file or certificate-based authentication.
command: |
  if [ ! -f /var/lib/postgresql/data/pgdata/PG_VERSION ]; then
    PGPASSWORD=replicator_password pg_basebackup -h primary_db -D /var/lib/postgresql/data/pgdata -U replicator -Fp -Xs -P -R
    echo "primary_conninfo = 'host=primary_db port=5432 user=replicator password=replicator_password application_name=hot_backup'" >> postgresql.conf
    echo "primary_slot_name = 'hot_backup_slot'" >> postgresql.conf
    touch /var/lib/postgresql/data/pgdata/standby.signal
  fi
```

⚠️ **Security Note:** The PGPASSWORD environment variable exposes the password in process lists. For production, consider:
- Using `.pgpass` file with proper permissions (600)
- Certificate-based authentication (SSL client certs)
- Docker secrets for password management

✅ **Correctly Implemented:**
- Streaming replication with replication slot (`hot_backup_slot`)
- Base backup created on first startup
- Hot standby mode enabled (can serve read queries)
- WAL archive available for point-in-time recovery

### 4.2 Automatic Failover Assessment

**Challenge Question:** *"Is the automatic failover robust?"*

**Current Status:** ⚠️ **Partially Implemented (Manual)**

The current setup provides the infrastructure for failover but **does not include automatic failover tooling**:

| Failover Capability | Status | Notes |
|---------------------|--------|-------|
| Hot standby ready | ✅ | `hot_standby = on` |
| Replication slot | ✅ | Prevents WAL deletion |
| Manual promotion | ✅ | Can run `pg_promote()` |
| Automatic detection | ❌ | No monitoring/detection |
| Automatic promotion | ❌ | No automation tool |
| Connection string switching | ❌ | App hardcoded to primary |

**Risk:** If the primary fails, manual intervention is required to:
1. Promote hot backup: `SELECT pg_promote();`
2. Update application connection strings
3. Restart application

**Recommendation for Production:**
```yaml
# Add Patroni or repmgr for automatic failover
patroni:
  image: patroni/patroni:latest
  environment:
    - PATRONI_NAME=primary
    - PATRONI_SCOPE=flight_booking
```

---

## 5. Reports & Visualizations DB (Data Warehouse)

### 5.1 Logical Replication Configuration

**Location:** `docker/primary-db/02-init-schema.sql`, `docker/reports-db/02-setup-warehouse.sql`

**Primary DB - Publication:**
```sql
-- All OLTP tables published
CREATE PUBLICATION reports_publication FOR ALL TABLES;
SELECT pg_create_logical_replication_slot('reports_slot', 'pgoutput');
```

**Reports DB - Subscription:**
```sql
CREATE SUBSCRIPTION reports_subscription
    CONNECTION 'host=primary_db port=5432 dbname=flight_booking user=replicator password=replicator_password'
    PUBLICATION reports_publication
    WITH (copy_data = true, create_slot = false, slot_name = 'reports_slot');
```

✅ **Good Pattern:** Using `copy_data = true` ensures initial data sync on subscription creation.

### 5.2 Tables Replicated

**All OLTP tables are replicated:**
- `flights`
- `seats`
- `customers`
- `bookings`
- `booking_items`

**Challenge Question:** *"Is this subset appropriate for reporting?"*

**Answer:** Yes, but with a nuance:
- All source tables are needed for the ETL to build the warehouse schema
- The publication could be more selective if we only needed specific tables
- Current approach (`FOR ALL TABLES`) is simpler but replicates more than strictly necessary

**Note:** The warehouse schema (dim_*, fact_*) is **not replicated** - it's populated via ETL locally on the reports database.

### 5.3 ETL Procedures

**Location:** `warehouse/etl_dimensions.sql`, `warehouse/etl_facts.sql`, `warehouse/etl_master_pipeline.sql`

**ETL Flow:**
```
OLTP Tables (Replicated) ──┐
                          │
    ┌─────────────────────┴────────────────────────┐
    │         etl_master_pipeline.sql              │
    │                                              │
    │  1. Pre-flight checks (table existence)      │
    │  2. Load dim_route (no dependencies)         │
    │  3. Load dim_customer (SCD Type 1)           │
    │  4. Load dim_flight (depends on dim_route)   │
    │  5. Load dim_seat                            │
    │  6. Load fact_bookings (incremental)         │
    │  7. Load fact_seat_inventory (daily snapshot)│
    │  8. Update derived metrics                   │
    │  9. Data quality checks                      │
    │ 10. ANALYZE tables                           │
    └──────────────────────────────────────────────┘
                          │
    Warehouse Tables ◄────┘
```

✅ **Good ETL Practices:**
1. **Incremental loading** using watermarks (`etl_metadata.last_etl_timestamp`)
2. **Idempotent operations** with `ON CONFLICT DO NOTHING/UPDATE`
3. **Error handling** with `EXCEPTION WHEN OTHERS` blocks
4. **Metadata tracking** for audit and debugging
5. **Data quality checks** for orphaned records, missing keys
6. **Statistics updates** with `ANALYZE` after loads

**ETL Trigger in Application:**
```javascript
// bookingController.js - Triggers ETL after bookings (lines 6-20)
const reportsDb = require('../db/reportsDb');
const fs = require('fs');
const path = require('path');

const triggerETLRefresh = async () => {
  try {
    const etlPath = path.join(__dirname, '../warehouse/etl_master_pipeline.sql');
    if (fs.existsSync(etlPath)) {
      const etlScript = fs.readFileSync(etlPath, 'utf-8');
      reportsDb.query(etlScript)
        .then(() => console.log('✓ Warehouse ETL refresh completed'))
        .catch(err => console.error('⚠ ETL refresh failed:', err.message));
    }
  } catch (err) {
    console.error('⚠ ETL trigger error:', err.message);
  }
};
```

⚠️ **Concern:** Running full ETL synchronously after every booking could be expensive at scale. Consider:
- Scheduled ETL (cron job) instead of per-transaction
- Incremental micro-batches
- Event-driven ETL with message queue

### 5.4 Reports Implemented (3+ Required)

**Location:** `controllers/reportsController.js`, `routes/reportsRoutes.js`

| Report Category | Endpoint | Query Type |
|-----------------|----------|------------|
| **Revenue Analysis** | | |
| Revenue by Route | `/api/reports/revenue/by-route` | Aggregation with joins |
| Revenue by Seat Class | `/api/reports/revenue/by-class` | Group by dimension |
| Monthly Revenue Trend | `/api/reports/revenue/monthly` | Time-series |
| **Booking Analytics** | | |
| Booking Lead Time | `/api/reports/bookings/lead-time` | Bucketed distribution |
| Peak Booking Hours | `/api/reports/bookings/peak-hours` | Hourly aggregation |
| Booking Patterns | `/api/reports/bookings/patterns` | Weekend vs Weekday |
| **Customer Analytics** | | |
| Customer Segments | `/api/reports/customers/segments` | Segment distribution |
| Top Customers | `/api/reports/customers/top-spenders` | Ranked list |
| **Operational Metrics** | | |
| Seat Utilization | `/api/reports/operations/seat-utilization` | Snapshot analysis |
| Cancellation Rate | `/api/reports/operations/cancellation-rate` | Ratio calculation |
| Load Factor | `/api/reports/operations/load-factor` | Capacity analysis |

✅ **Requirements Met:** More than 3 analytical reports implemented with proper queries against the star schema.

---

## 6. WAL Archiving

### 6.1 Configuration

**Location:** `docker/primary-db/01-init-primary.sh` (lines 19-21)

```bash
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f && chmod 0600 /var/lib/postgresql/wal_archive/%f'
archive_timeout = 3600  # Archive every hour (3600 seconds)
```

⚠️ **Archive Command Note:** The current command could silently fail if the copy operation fails after passing the existence test. A more robust version would be:
```bash
archive_command = 'cp %p /var/lib/postgresql/wal_archive/%f && test -f /var/lib/postgresql/wal_archive/%f'
```
This verifies the file was actually created, providing better failure detection.

**Shared Volume:**
```yaml
volumes:
  wal_archive:
    driver: local
```

### 6.2 Assessment

**Challenge Question:** *"Is the WAL archiving strategy sufficient?"*

| Aspect | Status | Notes |
|--------|--------|-------|
| Archive mode enabled | ✅ | `archive_mode = on` |
| Archive command | ⚠️ | Works but could mask failures |
| Archive timeout | ✅ | Hourly (3600s) |
| External backup | ⚠️ | Local volume only |
| Rotation policy | ❌ | No cleanup configured |
| Restore testing | ❌ | No automated testing |

**Risks:**
1. **Single point of failure:** WAL archive on local Docker volume could be lost with host failure
2. **Disk space:** No rotation policy could fill disk over time
3. **Untested recovery:** No scripts for point-in-time recovery testing

**Recommendations:**
```bash
# Add WAL rotation (cleanup older than 7 days)
find /var/lib/postgresql/wal_archive -mtime +7 -delete

# For production: ship to S3/GCS
archive_command = 'aws s3 cp %p s3://bucket/wal_archive/%f'
```

---

## 7. Gaps, Risks, and Nice Touches

### 7.1 Gaps

| Gap | Impact | Severity |
|-----|--------|----------|
| No automatic failover | Manual intervention required on primary failure | Medium |
| ETL triggered per-transaction | Performance impact at scale | Medium |
| No external WAL backup | Data loss risk on host failure | High |
| No monitoring/alerting | Silent failures possible | Medium |
| Hardcoded passwords | Security risk | High (for production) |

### 7.2 Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Replication lag during high load | Medium | Stale analytics data | Monitor pg_stat_subscription |
| Logical replication slot bloat | Low | Disk space exhaustion | Monitor pg_replication_slots |
| ETL failure corrupting warehouse | Low | Inconsistent reports | Transaction-wrapped ETL |
| Connection pool exhaustion | Medium | App unavailability | Increase pool size, add PgBouncer |

### 7.3 Nice Touches / Best Practices

✅ **Excellent implementations worth highlighting:**

1. **Proper surrogate key management:**
   ```sql
   CREATE TABLE dim_customer (
       customer_key SERIAL PRIMARY KEY,  -- Surrogate
       customer_id INT NOT NULL UNIQUE,  -- Natural key preserved
   ```

2. **Derived attributes for analytics:**
   ```sql
   -- Pre-calculated booking lead time
   booking_to_departure_days INT, -- How far in advance booked
   booking_hour INT, -- Hour of day booking was made (0-23)
   ```

3. **Customer segmentation logic:**
   ```sql
   customer_segment = CASE
       WHEN total_spent >= 50000 THEN 'VIP'
       WHEN total_bookings >= 5 THEN 'Regular'
       ELSE 'One-time'
   END;
   ```

4. **Comprehensive date dimension:**
   ```sql
   -- Pre-populated 10 years with all attributes
   INSERT INTO dim_date ... FROM generate_series('2020-01-01', '2030-12-31', '1 day');
   ```

5. **ETL metadata tracking:**
   ```sql
   CREATE TABLE etl_metadata (
       table_name VARCHAR(50) NOT NULL,
       last_etl_timestamp TIMESTAMP NOT NULL,
       records_processed INT,
       status VARCHAR(20),
       error_message TEXT
   );
   ```

6. **Data quality checks in ETL:**
   ```sql
   -- Check for orphaned bookings
   SELECT 'Orphaned Bookings' AS issue_type, COUNT(*) AS issue_count
   FROM fact_bookings fb
   LEFT JOIN dim_customer dc ON fb.customer_key = dc.customer_key
   WHERE dc.customer_key IS NULL;
   ```

7. **Transaction-safe booking with row locking:**
   ```sql
   WITH locked_seat AS (
       SELECT seat_id, price
       FROM seats
       WHERE flight_id = $2 AND seat_number = $3 AND is_available = TRUE
       FOR UPDATE  -- Prevents race conditions
   )
   ```

8. **Separate database connection pools:**
   ```javascript
   // Clean separation
   const db = require('../db/db');        // OLTP
   const reportsDb = require('../db/reportsDb');  // OLAP
   ```

---

## 8. Requirements Checklist Summary

| Requirement | Status | Evidence |
|-------------|--------|----------|
| **Analytical Operations** | | |
| ≥3 reports/visualizations | ✅ | 12+ report endpoints in reportsController.js |
| Schema optimized for analytics | ✅ | Star schema with fact/dimension tables |
| **Primary Database** | | |
| Transactional ops hit primary | ✅ | bookingController uses db/db.js |
| Real-time queries hit primary | ✅ | getAvailableSeats uses primary |
| Non-real-time from reports DB | ✅ | All /api/reports use reportsDb.js |
| Normalized appropriately | ✅ | OLTP schema in 3NF |
| **Hot Backup** | | |
| Physical replication | ✅ | pg_basebackup + streaming |
| (Bonus) Automatic failover | ⚠️ | Infrastructure ready, no automation |
| **Reports/Warehouse DB** | | |
| Logical replication | ✅ | Publication + Subscription configured |
| Denormalized for reports | ✅ | Star schema implemented |
| Triggers/functions for sync | ✅ | ETL procedures in warehouse/*.sql |
| Replicate only needed data | ⚠️ | Currently replicates all tables |
| **WAL Archiving** | | |
| Hourly archiving | ✅ | archive_timeout = 3600 |
| Archive location configured | ✅ | Shared volume /wal_archive |

---

## 9. Final Verdict

### Strengths
1. **Clear OLTP/OLAP separation** - Application correctly routes queries
2. **Well-designed star schema** - Proper dimensions, facts, surrogate keys
3. **Comprehensive ETL** - Incremental loading, error handling, metadata
4. **Good replication setup** - Both physical and logical properly configured
5. **Extensive documentation** - Multiple README files explaining architecture

### Areas for Improvement
1. Add automatic failover (Patroni/repmgr)
2. Move ETL to scheduled jobs instead of per-transaction
3. Add external WAL archiving (S3/GCS)
4. Implement monitoring (Prometheus/Grafana)
5. Use Docker secrets for passwords in production

### Conclusion

This implementation demonstrates a **strong understanding of database architecture principles** and successfully meets the stated requirements. The separation between OLTP and OLAP workloads is well-executed, replication strategies are appropriate, and the star schema design follows best practices. The main gaps are around production-readiness (failover automation, external backups, monitoring) rather than fundamental architecture issues.

**Grade: A- (Excellent with minor improvements needed)**

---

*End of Architecture Review*
