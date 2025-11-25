#!/bin/bash

# Quick start script for Flight Booking System
# This script starts all services and monitors their startup

set -e

echo "========================================="
echo "Starting Flight Booking System"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

echo "Building and starting services..."
echo ""

# Start services
docker compose up -d --build

echo ""
echo "Waiting for services to be healthy..."
echo ""

# Wait for services
max_wait=180  # 3 minutes
elapsed=0

while [ $elapsed -lt $max_wait ]; do
    # Check health status more reliably
    primary_healthy=$(docker compose ps primary_db --format json 2>/dev/null | grep -o '"Health":"healthy"' | wc -l)
    backup_healthy=$(docker compose ps hot_backup_db --format json 2>/dev/null | grep -o '"Health":"healthy"' | wc -l)
    reports_healthy=$(docker compose ps reports_db --format json 2>/dev/null | grep -o '"Health":"healthy"' | wc -l)
    app_running=$(docker compose ps app_server --format json 2>/dev/null | grep -o '"State":"running"' | wc -l)
    
    # Fallback to simpler check if JSON format not available
    if [ -z "$primary_healthy" ] || [ "$primary_healthy" = "0" ]; then
        primary_healthy=$(docker compose ps primary_db 2>/dev/null | grep -c "healthy" || echo "0")
        backup_healthy=$(docker compose ps hot_backup_db 2>/dev/null | grep -c "healthy" || echo "0")
        reports_healthy=$(docker compose ps reports_db 2>/dev/null | grep -c "healthy" || echo "0")
        app_running=$(docker compose ps app_server 2>/dev/null | grep -c "running" || echo "0")
    fi
    
    if [ "$primary_healthy" -ge "1" ] && [ "$backup_healthy" -ge "1" ] && [ "$reports_healthy" -ge "1" ] && [ "$app_running" -ge "1" ]; then
        echo -e "${GREEN}All services are healthy!${NC}"
        break
    fi
    
    echo "Status: Primary: $primary_healthy | Hot Backup: $backup_healthy | Reports: $reports_healthy | App: $app_running"
    sleep 5
    elapsed=$((elapsed + 5))
done

if [ $elapsed -ge $max_wait ]; then
    echo "Warning: Services took longer than expected to start. Check logs with: docker compose logs"
fi

echo ""
echo "========================================="
echo "System Status"
echo "========================================="
docker compose ps
echo ""

echo "========================================="
echo "Access Information"
echo "========================================="
echo ""
echo "Application API:"
echo "  http://localhost:4000"
echo ""
echo "Databases:"
echo "  Primary DB (OLTP):     psql -h localhost -p 5432 -U postgres -d flight_booking"
echo "  Hot Backup DB:         psql -h localhost -p 5433 -U postgres -d flight_booking"
echo "  Reports DB (OLAP):     psql -h localhost -p 5434 -U postgres -d flight_booking_reports"
echo "  Password: yourpassword"
echo ""
echo "Useful Commands:"
echo "  View logs:         docker compose logs -f [service_name]"
echo "  Stop system:       docker compose down"
echo "  Test replication:  ./test-replication.sh"
echo ""
echo "========================================="
echo -e "${GREEN}Flight Booking System is ready!${NC}"
echo "========================================="
