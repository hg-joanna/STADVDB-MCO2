#!/bin/bash
set -e

echo "Waiting for primary database to be ready..."
until PGPASSWORD=yourpassword pg_isready -h primary_db -U postgres; do
  echo "Primary database is unavailable - sleeping"
  sleep 2
done

echo "Primary database is ready. Configuring reports database..."

# Configure PostgreSQL for logical replication
cat >> "$PGDATA/postgresql.conf" <<EOF

# ========================================
# LOGICAL REPLICATION SETTINGS
# ========================================

max_logical_replication_workers = 4
max_sync_workers_per_subscription = 2
wal_level = logical

# Performance settings for analytical workload
shared_buffers = 512MB
effective_cache_size = 2GB
maintenance_work_mem = 128MB
work_mem = 8MB
random_page_cost = 1.1

EOF

echo "Reports database configuration complete."
