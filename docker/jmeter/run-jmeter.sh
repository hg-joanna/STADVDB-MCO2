#!/bin/bash
set -e

# Set environment variables for headless operation
export JAVA_OPTS="-Djava.awt.headless=true -Xms512m -Xmx1024m"

# Create results directory if it doesn't exist
mkdir -p /test/results

# Generate timestamp for results file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Starting JMeter load test..."
echo "Target: ${APP_HOST}:${APP_PORT}"
echo "Results will be saved to: test_results_${TIMESTAMP}.jtl"

# Run JMeter in non-GUI mode
/opt/apache-jmeter-5.6.3/bin/jmeter \
    -n \
    -t /test/FlightBookingLoadTest.jmx \
    -l /test/results/test_results_${TIMESTAMP}.jtl \
    -JAPP_HOST=${APP_HOST} \
    -JAPP_PORT=${APP_PORT} \
    -Djava.awt.headless=true

echo "Load test completed successfully!"
echo "Results saved to: test_results_${TIMESTAMP}.jtl"