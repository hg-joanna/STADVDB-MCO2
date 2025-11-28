#!/bin/sh
set -e

# =================================================================
# PostgreSQL Automatic Failover Script
# =================================================================
# This script monitors the primary database and promotes the replica
# if the primary becomes unavailable.
# =================================================================

# -----------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------
# Number of failed checks before triggering failover
FAILURE_THRESHOLD=3

# Seconds to wait between health checks
CHECK_INTERVAL=10

# Database connection details (from environment variables)
PG_PRIMARY_HOST=${PG_PRIMARY_HOST:-primary_db}
PG_REPLICA_HOST=${PG_REPLICA_HOST:-hot_backup_db}
PG_USER=${PG_USER:-postgres}
PG_DB=${PG_DB:-flight_booking}
PG_PASSWORD=${PG_PASSWORD:-yourpassword}

# Counter for consecutive failed checks
failure_count=0

echo "🚀 Starting automatic failover monitor..."
echo "Primary DB: $PG_PRIMARY_HOST"
echo "Replica DB: $PG_REPLICA_HOST"
echo "Failure Threshold: $FAILURE_THRESHOLD checks"
echo "Check Interval: $CHECK_INTERVAL seconds"

# -----------------------------------------------------------------
# Main Monitoring Loop
# -----------------------------------------------------------------
while true; do
    # Check if the replica is already promoted
    is_replica_in_recovery=$(psql "postgres://$PG_USER:$PG_PASSWORD@$PG_REPLICA_HOST/$PG_DB" -t -c "SELECT pg_is_in_recovery();")
    
    if [ "$(echo "$is_replica_in_recovery" | xargs)" = "f" ]; then
        echo "✅ Replica is already promoted and running as the new primary. No further action needed."
        # Exit the script gracefully as its job is done
        exit 0
    fi

    # Check the health of the primary database
    if pg_isready -h "$PG_PRIMARY_HOST" -U "$PG_USER" -d "$PG_DB" -q; then
        # If check is successful, reset the failure count
        if [ $failure_count -gt 0 ]; then
            echo "✅ Primary database is back online. Resetting failure count."
        fi
        failure_count=0
        echo "🔍 Primary is healthy. Current failure count: $failure_count/$FAILURE_THRESHOLD"
    else
        # If check fails, increment the failure count
        failure_count=$((failure_count + 1))
        echo "⚠️ Primary database connection failed. Current failure count: $failure_count/$FAILURE_THRESHOLD"
    fi

    # If failure threshold is reached, trigger failover
    if [ $failure_count -ge $FAILURE_THRESHOLD ]; then
        echo "🚨 FAILURE THRESHOLD REACHED! Primary database is down."
        echo "🚀 Initiating failover to replica: $PG_REPLICA_HOST"

        # Promote the replica using pg_ctl promote
        # We use `docker exec` to run the command inside the replica's container as the 'postgres' user
        docker exec -u postgres "$PG_REPLICA_HOST" pg_ctl promote -D "/var/lib/postgresql/data"

        echo "✅ Failover complete! The replica at $PG_REPLICA_HOST has been promoted to the new primary."
        echo "The application will now connect to the new primary."
        
        # Exit the script as the failover is done
        exit 0
    fi

    # Wait for the next check
    sleep "$CHECK_INTERVAL"
done
