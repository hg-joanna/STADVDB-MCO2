#!/bin/bash
set -e

echo "Waiting for primary database to be ready..."
until PGPASSWORD=yourpassword pg_isready -h primary_db -U postgres; do
  echo "Primary database is unavailable - sleeping"
  sleep 2
done

echo "Primary database is ready. Setting up hot backup replica..."

# Stop PostgreSQL temporarily
pg_ctl -D "$PGDATA" -m fast -w stop || true

# Remove any existing data
rm -rf "$PGDATA"/*

# Create base backup from primary database using physical replication
echo "Creating base backup from primary database..."
PGPASSWORD=replicator_password pg_basebackup -h primary_db -D "$PGDATA" -U replicator -Fp -Xs -P -R

# Configure hot standby
cat >> "$PGDATA/postgresql.conf" <<EOF

# ========================================
# HOT STANDBY CONFIGURATION
# ========================================

hot_standby = on
hot_standby_feedback = on
max_standby_streaming_delay = 30s
wal_receiver_status_interval = 10s

# Recovery settings (for continuous replication)
primary_conninfo = 'host=primary_db port=5432 user=replicator password=replicator_password application_name=hot_backup'
primary_slot_name = 'hot_backup_slot'
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'

EOF

# Create standby.signal file to indicate this is a replica
touch "$PGDATA/standby.signal"

echo "Hot backup replica setup complete. Starting PostgreSQL..."

# Start PostgreSQL
pg_ctl -D "$PGDATA" -w start

echo "Hot backup database is now streaming from primary!"
