# Docker Setup Guide - Flight Booking System

This guide explains the Docker Compose setup for the Flight Booking System with database replication.

## Architecture Overview

The system consists of 4 main components:

```
┌─────────────────────────────────────────────────────────────────┐
│                      Docker Network                              │
│                                                                   │
│  ┌──────────────┐                                                │
│  │  App Server  │──┐                                             │
│  │  (Node.js)   │  │                                             │
│  │  Port: 4000  │  │                                             │
│  └──────────────┘  │                                             │
│         │           │                                             │
│         ├───────────┼────────────────────────────────┐           │
│         │           │                                 │           │
│         ▼           │                                 │           │
│  ┌──────────────┐  │  Physical Replication          │           │
│  │  Primary DB  │──┼──────────────────────┐         │           │
│  │  (OLTP)      │  │                       │         │           │
│  │  Port: 5432  │  │                       ▼         │           │
│  └──────────────┘  │              ┌──────────────┐  │           │
│         │           │              │ Hot Backup   │  │           │
│         │           │              │   DB         │  │           │
│         │           │              │ Port: 5433   │  │           │
│         │           │              └──────────────┘  │           │
│         │           │                                 │           │
│         └───────────┼─────────────────────────────────┘           │
│                     │  Logical Replication                        │
│                     │                                             │
│                     ▼                                             │
│              ┌──────────────┐                                     │
│              │ Reports DB   │                                     │
│              │ (OLAP)       │                                     │
│              │ Port: 5434   │                                     │
│              └──────────────┘                                     │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Components

1. **Application Server** (Port 4000)
   - Node.js/Express REST API
   - Handles flight booking operations
   - Connects to Primary DB for OLTP operations

2. **Primary Database** (Port 5432)
   - PostgreSQL 16 with OLTP schema
   - Master database for all write operations
   - Configured for both physical and logical replication
   - WAL archiving enabled (hourly)

3. **Hot Backup Database** (Port 5433)
   - Physical replication (streaming replication)
   - Read-only replica for high availability
   - Can be promoted to primary in case of failure
   - Uses replication slots to prevent WAL deletion

4. **Reports Database** (Port 5434)
   - Logical replication from Primary DB
   - Contains both OLTP tables (replicated) and OLAP warehouse schema
   - Optimized for analytical queries
   - Denormalized star schema for reporting

## Quick Start

### Prerequisites

- Docker Desktop or Docker Engine with Docker Compose
- At least 4GB of available RAM
- Ports 4000, 5432, 5433, 5434 available

### Starting the System

```bash
# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f primary_db
docker compose logs -f hot_backup_db
docker compose logs -f reports_db
docker compose logs -f app_server
```

### Stopping the System

```bash
# Stop all services
docker compose down

# Stop and remove volumes (WARNING: deletes all data)
docker compose down -v
```

## Database Setup Details

### Primary Database Initialization

The primary database is initialized with:
1. Replication user and permissions
2. OLTP schema (flights, seats, bookings, customers, booking_items)
3. Sample data for testing
4. Publication for logical replication
5. Replication slots for physical and logical replication

**Scripts executed:**
- `docker/primary-db/01-init-primary.sh` - Configures PostgreSQL for replication
- `docker/primary-db/02-init-schema.sql` - Creates schema and publications
- `db_scripts/flights_oltp_schema.sql` - OLTP schema
- `db_scripts/db_data.sql` - Sample data

### Hot Backup Database Setup

Physical replication setup using streaming replication:
- Creates base backup from primary using `pg_basebackup`
- Configures as hot standby with `standby.signal`
- Uses replication slot `hot_backup_slot`
- Can read data but not write

**First-time setup:**
The hot backup automatically creates a base backup on first run. This may take a minute depending on the database size.

### Reports Database Setup

Logical replication setup for analytics:
1. OLTP schema created (to receive replicated data)
2. Subscription created to primary's publication
3. Warehouse schema created (star schema)
4. ETL procedures loaded
5. Initial ETL run to populate warehouse

**Scripts executed:**
- `docker/reports-db/01-init-reports.sh` - Configures PostgreSQL
- `docker/reports-db/02-setup-warehouse.sql` - Sets up replication and warehouse
- `warehouse/ddl_warehouse_schema.sql` - Warehouse schema
- `warehouse/etl_dimensions.sql` - Dimension ETL logic
- `warehouse/etl_facts.sql` - Fact ETL logic
- `warehouse/etl_master_pipeline.sql` - Complete ETL orchestration

## Replication Details

### Physical Replication (Primary → Hot Backup)

- **Type:** Streaming Replication
- **Replication Slot:** `hot_backup_slot`
- **WAL Archiving:** Enabled, archives every hour
- **Recovery:** Can restore from WAL archives
- **Lag Monitoring:** Check with `pg_stat_replication` on primary

```sql
-- Check replication status on primary
SELECT * FROM pg_stat_replication;
```

### Logical Replication (Primary → Reports)

- **Publication:** `reports_publication` (all tables)
- **Subscription:** `reports_subscription`
- **Replication Slot:** `reports_slot`
- **Initial Data:** Copied during subscription creation

```sql
-- Check publication on primary
SELECT * FROM pg_publication_tables WHERE pubname = 'reports_publication';

-- Check subscription status on reports_db
SELECT * FROM pg_stat_subscription;
```

## WAL Archiving

WAL (Write-Ahead Log) archiving is configured for point-in-time recovery:

- **Archive Location:** `/var/lib/postgresql/wal_archive` (shared volume)
- **Archive Interval:** Every 1 hour (3600 seconds)
- **Archive Command:** Copies WAL files to archive directory

**View archived WAL files:**
```bash
docker compose exec primary_db ls -lh /var/lib/postgresql/wal_archive/
```

## Connecting to Databases

### From Host Machine

```bash
# Primary DB
psql -h localhost -p 5432 -U postgres -d flight_booking

# Hot Backup DB (read-only)
psql -h localhost -p 5433 -U postgres -d flight_booking

# Reports DB
psql -h localhost -p 5434 -U postgres -d flight_booking_reports
```

### From Application Container

The application automatically connects to `primary_db:5432` using environment variables.

### Connection Details

- **Username:** postgres
- **Password:** yourpassword
- **Primary DB:** flight_booking
- **Reports DB:** flight_booking_reports

## Testing Replication

### Test Physical Replication (Hot Backup)

```bash
# Insert data on primary
docker compose exec primary_db psql -U postgres -d flight_booking -c \
  "INSERT INTO customers (full_name, email) VALUES ('Test User', 'test@example.com');"

# Check if replicated to hot backup
docker compose exec hot_backup_db psql -U postgres -d flight_booking -c \
  "SELECT * FROM customers WHERE email = 'test@example.com';"
```

### Test Logical Replication (Reports)

```bash
# Insert booking on primary
docker compose exec primary_db psql -U postgres -d flight_booking -c \
  "SELECT COUNT(*) FROM bookings;"

# Check if replicated to reports DB
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c \
  "SELECT COUNT(*) FROM bookings;"
```

### Run ETL on Reports Database

```bash
# Execute ETL pipeline manually
docker compose exec reports_db psql -U postgres -d flight_booking_reports -f \
  /docker-entrypoint-initdb.d/etl_master_pipeline.sql
```

## Troubleshooting

### Hot Backup Not Starting

If the hot backup fails to start:
1. Check primary database is healthy: `docker compose ps primary_db`
2. View hot backup logs: `docker compose logs hot_backup_db`
3. Verify replication slot exists on primary:
   ```bash
   docker compose exec primary_db psql -U postgres -c \
     "SELECT * FROM pg_replication_slots WHERE slot_name = 'hot_backup_slot';"
   ```

### Logical Replication Issues

If reports database subscription fails:
1. Check subscription status:
   ```bash
   docker compose exec reports_db psql -U postgres -d flight_booking_reports -c \
     "SELECT * FROM pg_stat_subscription;"
   ```
2. Check publication on primary:
   ```bash
   docker compose exec primary_db psql -U postgres -d flight_booking -c \
     "SELECT * FROM pg_publication;"
   ```

### Reset Everything

To completely reset and rebuild:
```bash
# Stop and remove everything including volumes
docker compose down -v

# Remove orphaned containers
docker compose rm -f

# Start fresh
docker compose up -d --build
```

## Health Checks

All databases have health checks configured:
- **Interval:** 10 seconds
- **Timeout:** 5 seconds
- **Retries:** 5

View health status:
```bash
docker compose ps
```

## Performance Considerations

### Primary Database
- Optimized for OLTP (transactional) workloads
- Indexes on foreign keys and frequently queried columns
- Connection pooling in application

### Hot Backup Database
- Read-only queries only
- Can be used for reporting to offload primary
- Identical performance characteristics as primary

### Reports Database
- Optimized for OLAP (analytical) workloads
- Star schema with fact and dimension tables
- Materialized views for common aggregations
- Higher work_mem for complex queries

## Next Steps

After setting up the infrastructure:
1. Implement analytical reports (3+ required)
2. Add visualizations in the application
3. Set up JMeter for load testing
4. Configure automatic failover (bonus)
5. Monitor replication lag

## Security Notes

**⚠️ WARNING:** This setup uses default passwords and is intended for development/testing only.

For production:
1. Change all passwords
2. Use Docker secrets for sensitive data
3. Configure SSL/TLS for database connections
4. Restrict network access
5. Enable authentication on replication connections
6. Regularly backup WAL archives to external storage
