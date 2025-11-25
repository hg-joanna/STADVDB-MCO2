#!/bin/bash
set -e

# This script initializes the primary database with:
# 1. Additional configuration for archiving and performance
# 2. Host-based authentication for replication

echo "Setting up primary database..."

# Configure PostgreSQL for archiving and performance
# Note: wal_level, max_wal_senders, max_replication_slots are set via command line
cat >> "$PGDATA/postgresql.conf" <<EOF

# ========================================
# ARCHIVING & PERFORMANCE SETTINGS
# ========================================

# Enable WAL archiving for point-in-time recovery
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f && chmod 0600 /var/lib/postgresql/wal_archive/%f'
archive_timeout = 3600  # Archive every hour (3600 seconds)

# Additional replication settings
hot_standby = on
max_logical_replication_workers = 4
max_sync_workers_per_subscription = 2

# Performance settings
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB

EOF

# Configure host-based authentication for replication
cat >> "$PGDATA/pg_hba.conf" <<EOF

# Replication connections
host    replication     replicator      hot_backup_db           trust
host    replication     replicator      reports_db              trust
host    replication     replicator      0.0.0.0/0               md5

# Allow logical replication connections
host    all             replicator      reports_db              trust
host    all             replicator      0.0.0.0/0               md5

EOF

echo "Primary database replication configuration complete."
