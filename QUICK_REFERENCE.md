# Quick Reference Card - Flight Booking System

## Quick Start

```bash
# Start everything
./start.sh

# Test replication
./test-replication.sh

# Stop everything
docker compose down

# Reset everything (WARNING: deletes all data)
docker compose down -v && docker compose up -d
```

## Database Connections

| Database | Port | Purpose | Command |
|----------|------|---------|---------|
| Primary | 5432 | OLTP (Read/Write) | `psql -h localhost -p 5432 -U postgres -d flight_booking` |
| Hot Backup | 5433 | OLTP (Read-Only) | `psql -h localhost -p 5433 -U postgres -d flight_booking` |
| Reports | 5434 | OLAP (Read/Write) | `psql -h localhost -p 5434 -U postgres -d flight_booking_reports` |

**Password**: `yourpassword`

## Service Management

```bash
# View all services
docker compose ps

# View logs
docker compose logs -f
docker compose logs -f primary_db
docker compose logs -f hot_backup_db
docker compose logs -f reports_db
docker compose logs -f app_server

# Restart a service
docker compose restart primary_db

# Rebuild a service
docker compose up -d --build app_server
```

## Replication Status

### Check Physical Replication (Primary → Hot Backup)
```sql
-- On primary_db
SELECT application_name, state, sync_state, write_lag, replay_lag 
FROM pg_stat_replication;

SELECT slot_name, slot_type, active 
FROM pg_replication_slots;
```

### Check Logical Replication (Primary → Reports)
```sql
-- On primary_db
SELECT * FROM pg_publication_tables 
WHERE pubname = 'reports_publication';

-- On reports_db
SELECT subname, subenabled, pid IS NOT NULL as is_running, latest_end_lsn
FROM pg_stat_subscription;
```

## Useful Queries

### OLTP Queries (Primary/Hot Backup)
```sql
-- Check available flights
SELECT * FROM flights 
WHERE departure_time > NOW() 
ORDER BY departure_time;

-- Check seat availability
SELECT f.flight_number, s.seat_class, 
       COUNT(*) FILTER (WHERE s.is_available) as available_seats,
       COUNT(*) as total_seats
FROM flights f
JOIN seats s ON f.flight_id = s.flight_id
WHERE f.flight_id = 1
GROUP BY f.flight_number, s.seat_class;

-- Recent bookings
SELECT b.booking_reference, c.full_name, f.flight_number, b.booked_at
FROM bookings b
JOIN customers c ON b.customer_id = c.customer_id
JOIN flights f ON b.flight_id = f.flight_id
ORDER BY b.booked_at DESC
LIMIT 10;
```

### OLAP Queries (Reports DB)
```sql
-- Revenue by route
SELECT r.origin, r.destination, 
       COUNT(*) as total_bookings,
       SUM(fb.price) as total_revenue
FROM fact_bookings fb
JOIN dim_flight df ON fb.flight_key = df.flight_key
JOIN dim_route r ON df.route_key = r.route_key
WHERE fb.is_cancelled = false
GROUP BY r.origin, r.destination
ORDER BY total_revenue DESC;

-- Bookings by day of week
SELECT dd.day_name,
       COUNT(*) as bookings,
       AVG(fb.price) as avg_price
FROM fact_bookings fb
JOIN dim_date dd ON fb.booking_date_key = dd.date_key
GROUP BY dd.day_name, dd.day_of_week
ORDER BY dd.day_of_week;

-- Customer segmentation
SELECT customer_segment,
       COUNT(*) as customer_count,
       AVG(total_spent) as avg_lifetime_value
FROM dim_customer
GROUP BY customer_segment
ORDER BY avg_lifetime_value DESC;
```

## Run ETL Manually

```bash
# Execute ETL on reports database
docker compose exec reports_db psql -U postgres -d flight_booking_reports \
  -f /docker-entrypoint-initdb.d/etl_master_pipeline.sql
```

## WAL Archive

```bash
# List archived WAL files
docker compose exec primary_db ls -lh /var/lib/postgresql/wal_archive/

# Check archive status
docker compose exec primary_db psql -U postgres -c \
  "SELECT archived_count, failed_count FROM pg_stat_archiver;"
```

## Troubleshooting

### Service Won't Start
```bash
# Check Docker is running
docker info

# Check ports are available
netstat -an | grep 5432
netstat -an | grep 5433
netstat -an | grep 5434
netstat -an | grep 4000

# View detailed logs
docker compose logs --tail=100 [service_name]

# Restart specific service
docker compose restart [service_name]
```

### Replication Issues
```bash
# Run automated tests
./test-replication.sh

# Check primary database is healthy
docker compose ps primary_db

# Verify replication slot exists
docker compose exec primary_db psql -U postgres -c \
  "SELECT * FROM pg_replication_slots;"

# Check subscription status
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c \
  "SELECT * FROM pg_stat_subscription;"
```

### Reset Hot Backup
```bash
# Stop and remove hot backup data
docker compose stop hot_backup_db
docker volume rm stadvdb-mco2_hot_backup_data
docker compose up -d hot_backup_db
```

### Reset Reports Database
```bash
# Stop and remove reports data
docker compose stop reports_db
docker volume rm stadvdb-mco2_reports_db_data
docker compose up -d reports_db
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | http://localhost:4000/flights | List all flights |
| GET | http://localhost:4000/flights/:id | Get flight details |
| POST | http://localhost:4000/booking | Create booking |
| DELETE | http://localhost:4000/booking/:id | Cancel booking |

### Example API Calls
```bash
# Get all flights
curl http://localhost:4000/flights

# Get flight details
curl http://localhost:4000/flights/1

# Create booking (example)
curl -X POST http://localhost:4000/booking \
  -H "Content-Type: application/json" \
  -d '{"flight_id": 1, "customer_id": 1, "seats": ["1A"]}'
```

## File Locations

| Purpose | Location |
|---------|----------|
| Application Code | `/home/runner/work/STADVDB-MCO2/STADVDB-MCO2/` |
| OLTP Schema | `db_scripts/flights_oltp_schema.sql` |
| Sample Data | `db_scripts/db_data.sql` |
| Warehouse Schema | `warehouse/ddl_warehouse_schema.sql` |
| ETL Scripts | `warehouse/etl_*.sql` |
| Sample Queries | `warehouse/sample_olap_queries.sql` |
| Init Scripts | `docker/*/` |
| Documentation | `DOCKER_SETUP.md`, `IMPLEMENTATION_SUMMARY.md` |

## Performance Monitoring

```sql
-- Database size
SELECT pg_database.datname, 
       pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database;

-- Table sizes
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Active connections
SELECT datname, count(*) 
FROM pg_stat_activity 
GROUP BY datname;

-- Replication lag (bytes)
SELECT client_addr, 
       write_lag, 
       flush_lag, 
       replay_lag
FROM pg_stat_replication;
```

## Docker Volumes

```bash
# List volumes
docker volume ls | grep stadvdb-mco2

# Inspect volume
docker volume inspect stadvdb-mco2_primary_db_data

# Backup volume (example)
docker run --rm -v stadvdb-mco2_primary_db_data:/data \
  -v $(pwd):/backup alpine tar czf /backup/primary_backup.tar.gz /data
```

## Emergency Commands

```bash
# Stop all services immediately
docker compose kill

# Force remove all containers
docker compose rm -f

# Clean up everything (DANGER: deletes all data)
docker compose down -v
docker system prune -f

# Restart from scratch
docker compose down -v && docker compose build --no-cache && docker compose up -d
```

## Next Steps

1. **Implement Reports**: Use queries in `warehouse/sample_olap_queries.sql`
2. **Load Testing**: Set up JMeter tests
3. **Visualizations**: Add charts to application
4. **Monitoring**: Consider adding Grafana/Prometheus
5. **Failover**: Implement automatic failover (bonus)

## Support

- **Documentation**: See `DOCKER_SETUP.md` for detailed information
- **Implementation**: See `IMPLEMENTATION_SUMMARY.md` for what was built
- **Project Overview**: See `README.md` for high-level info
