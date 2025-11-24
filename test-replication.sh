#!/bin/bash

# Test script for verifying replication setup
# Usage: ./test-replication.sh

set -e

echo "========================================="
echo "Testing Flight Booking System Replication"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper function for testing
test_step() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if services are running
test_step "Checking if all services are running..."
if ! docker compose ps | grep -q "running"; then
    error "Services are not running. Please start with: docker compose up -d"
    exit 1
fi
success "All services are running"
echo ""

# Test 1: Check Primary Database
test_step "Test 1: Checking Primary Database connection..."
if docker compose exec -T primary_db psql -U postgres -d flight_booking -c "SELECT 1;" > /dev/null 2>&1; then
    success "Primary database is accessible"
else
    error "Cannot connect to primary database"
    exit 1
fi
echo ""

# Test 2: Check Hot Backup Database
test_step "Test 2: Checking Hot Backup Database connection..."
if docker compose exec -T hot_backup_db psql -U postgres -d flight_booking -c "SELECT 1;" > /dev/null 2>&1; then
    success "Hot backup database is accessible"
else
    error "Cannot connect to hot backup database"
    exit 1
fi
echo ""

# Test 3: Check Reports Database
test_step "Test 3: Checking Reports Database connection..."
if docker compose exec -T reports_db psql -U postgres -d flight_booking_reports -c "SELECT 1;" > /dev/null 2>&1; then
    success "Reports database is accessible"
else
    error "Cannot connect to reports database"
    exit 1
fi
echo ""

# Test 4: Check Physical Replication Status
test_step "Test 4: Checking physical replication status (Primary -> Hot Backup)..."
REPL_STATUS=$(docker compose exec -T primary_db psql -U postgres -t -c "SELECT COUNT(*) FROM pg_stat_replication WHERE application_name='hot_backup';" | xargs)
if [ "$REPL_STATUS" -eq "1" ]; then
    success "Physical replication is active"
    docker compose exec -T primary_db psql -U postgres -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
else
    error "Physical replication is not active (expected 1, got $REPL_STATUS)"
fi
echo ""

# Test 5: Check Logical Replication Status
test_step "Test 5: Checking logical replication status (Primary -> Reports)..."
SUB_STATUS=$(docker compose exec -T reports_db psql -U postgres -d flight_booking_reports -t -c "SELECT COUNT(*) FROM pg_stat_subscription WHERE subname='reports_subscription';" | xargs)
if [ "$SUB_STATUS" -eq "1" ]; then
    success "Logical replication subscription exists"
    docker compose exec -T reports_db psql -U postgres -d flight_booking_reports -c "SELECT subname, subenabled, pid IS NOT NULL as is_running FROM pg_stat_subscription;"
else
    error "Logical replication subscription not found"
fi
echo ""

# Test 6: Test Physical Replication Data Sync
test_step "Test 6: Testing physical replication data sync..."
PRIMARY_COUNT=$(docker compose exec -T primary_db psql -U postgres -d flight_booking -t -c "SELECT COUNT(*) FROM customers;" | xargs)
BACKUP_COUNT=$(docker compose exec -T hot_backup_db psql -U postgres -d flight_booking -t -c "SELECT COUNT(*) FROM customers;" | xargs)
if [ "$PRIMARY_COUNT" -eq "$BACKUP_COUNT" ]; then
    success "Physical replication data is in sync (customers: $PRIMARY_COUNT rows)"
else
    error "Physical replication data mismatch (Primary: $PRIMARY_COUNT, Backup: $BACKUP_COUNT)"
fi
echo ""

# Test 7: Test Logical Replication Data Sync
test_step "Test 7: Testing logical replication data sync..."
PRIMARY_COUNT=$(docker compose exec -T primary_db psql -U postgres -d flight_booking -t -c "SELECT COUNT(*) FROM bookings;" | xargs)
REPORTS_COUNT=$(docker compose exec -T reports_db psql -U postgres -d flight_booking_reports -t -c "SELECT COUNT(*) FROM bookings;" | xargs)
if [ "$PRIMARY_COUNT" -eq "$REPORTS_COUNT" ]; then
    success "Logical replication data is in sync (bookings: $PRIMARY_COUNT rows)"
else
    error "Logical replication data mismatch (Primary: $PRIMARY_COUNT, Reports: $REPORTS_COUNT)"
fi
echo ""

# Test 8: Check Warehouse Schema
test_step "Test 8: Checking warehouse schema on reports database..."
if docker compose exec -T reports_db psql -U postgres -d flight_booking_reports -c "\dt fact_bookings" | grep -q "fact_bookings"; then
    success "Warehouse schema exists"
    FACT_COUNT=$(docker compose exec -T reports_db psql -U postgres -d flight_booking_reports -t -c "SELECT COUNT(*) FROM fact_bookings;" | xargs)
    echo "    Fact tables populated with $FACT_COUNT booking records"
else
    error "Warehouse schema not found"
fi
echo ""

# Test 9: Check WAL Archiving
test_step "Test 9: Checking WAL archiving..."
WAL_COUNT=$(docker compose exec -T primary_db bash -c "ls -1 /var/lib/postgresql/wal_archive/ | wc -l" 2>/dev/null | xargs)
if [ "$WAL_COUNT" -gt "0" ]; then
    success "WAL archiving is working ($WAL_COUNT files archived)"
else
    echo "    WAL archiving: No archived files yet (may need to wait for first archive cycle)"
fi
echo ""

# Test 10: Check Replication Slots
test_step "Test 10: Checking replication slots..."
docker compose exec -T primary_db psql -U postgres -c "SELECT slot_name, slot_type, active FROM pg_replication_slots;"
success "Replication slots listed above"
echo ""

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo ""
echo "Infrastructure Status:"
echo "  - Primary Database: $(docker compose ps primary_db | grep -q 'running' && echo '✓ Running' || echo '✗ Not running')"
echo "  - Hot Backup Database: $(docker compose ps hot_backup_db | grep -q 'running' && echo '✓ Running' || echo '✗ Not running')"
echo "  - Reports Database: $(docker compose ps reports_db | grep -q 'running' && echo '✓ Running' || echo '✗ Not running')"
echo "  - Application Server: $(docker compose ps app_server | grep -q 'running' && echo '✓ Running' || echo '✗ Not running')"
echo ""
echo "Replication Status:"
echo "  - Physical Replication: $([ "$REPL_STATUS" -eq "1" ] && echo '✓ Active' || echo '✗ Inactive')"
echo "  - Logical Replication: $([ "$SUB_STATUS" -eq "1" ] && echo '✓ Active' || echo '✗ Inactive')"
echo ""
echo "For detailed logs, run: docker compose logs -f [service_name]"
echo "========================================="
