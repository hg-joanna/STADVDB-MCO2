# STADVDB-MCO2 - Flight Booking System

A distributed flight booking system with database replication for high availability and analytics.

## Features

- **OLTP Operations**: Real-time flight booking and cancellation
- **High Availability**: Physical replication with hot backup database
- **Analytics**: Logical replication to dedicated reports database with data warehouse
- **WAL Archiving**: Point-in-time recovery capability
- **Containerized**: Complete Docker Compose setup

## Quick Start

```bash
# Start the system
./start.sh

# Or manually with docker compose
docker compose up -d

# Test replication
./test-replication.sh
```

## Architecture

- **App Server** (Port 4000): Node.js/Express REST API
- **Primary DB** (Port 5432): PostgreSQL master database (OLTP)
- **Hot Backup DB** (Port 5433): Physical replication replica
- **Reports DB** (Port 5434): Logical replication for analytics (OLAP)

## Documentation

See [DOCKER_SETUP.md](DOCKER_SETUP.md) for detailed setup and usage instructions.

## Project Structure

```
├── app.js                  # Main application entry point
├── controllers/            # Request handlers
├── routes/                 # API routes
├── db/                     # Database connection
├── db_scripts/             # OLTP schema and queries
├── warehouse/              # OLAP schema and ETL scripts
├── docker/                 # Database initialization scripts
│   ├── primary-db/         # Primary database setup
│   ├── hot-backup-db/      # Hot backup configuration
│   └── reports-db/         # Reports database setup
├── docker-compose.yml      # Docker Compose configuration
└── DOCKER_SETUP.md         # Detailed documentation

```

## API Endpoints

### Flights
- `GET /flights` - List all flights
- `GET /flights/:id` - Get flight details

### Bookings
- `POST /booking` - Create a new booking
- `DELETE /booking/:id` - Cancel a booking

## Development

```bash
# View logs
docker compose logs -f

# Access databases
psql -h localhost -p 5432 -U postgres -d flight_booking          # Primary
psql -h localhost -p 5433 -U postgres -d flight_booking          # Hot Backup
psql -h localhost -p 5434 -U postgres -d flight_booking_reports  # Reports

# Stop system
docker compose down

# Complete reset (WARNING: deletes all data)
docker compose down -v
```

## Requirements Met

- ✅ Docker Compose with app, primary DB, hot backup DB, and reports DB
- ✅ Physical replication (streaming) for hot backup
- ✅ Logical replication for reports/analytics
- ✅ WAL archiving (hourly)
- ✅ OLTP schema optimized for transactions
- ✅ OLAP schema (star schema) for analytics
- ⏳ 3+ analytical reports (in progress)
- ⏳ Load testing with JMeter (in progress)