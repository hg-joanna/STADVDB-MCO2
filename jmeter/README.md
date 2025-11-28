# JMeter Load Testing for Flight Booking System

## Overview
This directory contains JMeter test plans for load testing the Flight Booking System, covering both OLTP (transactional) and OLAP (analytical) operations.

## Test Plan: FlightBookingLoadTest.jmx

### Thread Groups

1. **Read Operations - Flights & Seats** (50 users, 10 loops)
   - Get All Flights
   - Get Seats for Flight

2. **Write Operations - Single Seat Booking** (20 users, 5 loops)
   - Create Single Booking transactions

3. **Write Operations - Batch Booking** (10 users, 3 loops)
   - Create Batch Booking transactions (multiple seats)

4. **Analytics Operations - Reports** (30 users, 5 loops)
   - Top Routes Report
   - Seat Utilization Report
   - Customer Segments Report
   - Flight Occupancy Report

### Total Load
- **Read Operations**: 500 requests (50 users × 10 loops)
- **Single Bookings**: 100 requests (20 users × 5 loops)
- **Batch Bookings**: 30 requests (10 users × 3 loops)
- **Analytics**: 600 requests (30 users × 5 loops × 4 endpoints)
- **Total**: ~1,230 requests

## Prerequisites

1. **Install JMeter**
   - Download from: https://jmeter.apache.org/download_jmeter.cgi
   - Extract to a directory (e.g., `C:\apache-jmeter`)
   - Add JMeter's `bin` directory to PATH

2. **Ensure the application is running**
   ```powershell
   docker compose up -d
   docker ps  # Verify all containers are healthy
   ```

3. **Verify the backend is accessible**
   ```powershell
   curl http://localhost:4000/api/flight
   ```

## Running Tests

### Option 1: GUI Mode (for development/debugging)
```powershell
# Navigate to jmeter directory
cd C:\Users\Ken Cheng\STADVDB-MCO2\jmeter

# Run JMeter GUI
jmeter -t FlightBookingLoadTest.jmx
```

In the GUI:
1. Click the green "Start" button (▶️) to run the test
2. View results in real-time using the listeners:
   - View Results Tree
   - Summary Report
   - Aggregate Report
   - Graph Results

### Option 2: CLI Mode (for production/CI)
```powershell
# Navigate to jmeter directory
cd C:\Users\Ken Cheng\STADVDB-MCO2\jmeter

# Run in non-GUI mode
jmeter -n -t FlightBookingLoadTest.jmx -l results/test_results.jtl -e -o results/report

# Options:
# -n: Non-GUI mode
# -t: Test file
# -l: Log file
# -e: Generate report dashboard
# -o: Output folder for HTML report
```

### Option 3: Using PowerShell Script
Create a `run-jmeter-test.ps1` file:
```powershell
# Ensure application is running
Write-Host "Checking if application is running..." -ForegroundColor Cyan
$response = try { curl http://localhost:4000/api/flight -TimeoutSec 5 } catch { $null }
if (-not $response) {
    Write-Host "ERROR: Application is not running. Start with 'docker compose up -d'" -ForegroundColor Red
    exit 1
}

# Create results directory
New-Item -ItemType Directory -Force -Path ".\results" | Out-Null

# Run JMeter test
Write-Host "Running JMeter load test..." -ForegroundColor Green
jmeter -n -t FlightBookingLoadTest.jmx `
    -l results/test_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').jtl `
    -e -o results/report_$(Get-Date -Format 'yyyyMMdd_HHmmss')

Write-Host "Test completed! Check the results folder." -ForegroundColor Green
```

## Analyzing Results

### Key Metrics to Monitor

1. **Response Time**
   - Average: Should be < 200ms for reads, < 500ms for writes
   - 90th Percentile: Should be < 1000ms
   - Max: Should be < 3000ms

2. **Throughput**
   - Requests per second
   - Higher is better

3. **Error Rate**
   - Should be < 1%
   - Check for 500 errors (server issues) vs 409 errors (concurrency conflicts)

4. **Database Performance**
   - Monitor PostgreSQL during tests
   ```powershell
   docker stats primary_db hot_backup_db reports_db
   ```

### Expected Behavior

- **Read Operations**: Very fast (< 100ms), no errors
- **Single Bookings**: May have some 409 errors (seat already booked)
- **Batch Bookings**: Higher chance of 409 errors due to concurrent seat locking
- **Analytics**: Slower but consistent (< 500ms), no errors

## Test Scenarios

### Scenario 1: Normal Load (Current Configuration)
- Simulates typical usage with mixed read/write/analytics operations

### Scenario 2: Peak Load (Modify thread counts)
Edit the test plan to increase:
- Read Operations: 100 users
- Single Bookings: 50 users
- Batch Bookings: 20 users
- Analytics: 50 users

### Scenario 3: Stress Test
- Gradually increase users until error rate exceeds 5%
- Identify system breaking point

## Troubleshooting

### High Error Rate (409 Conflicts)
- Expected for booking operations due to concurrent access
- Reduce concurrent threads or increase seat pool

### High Response Times
- Check Docker container resources: `docker stats`
- Check database connections
- Consider increasing PostgreSQL max_connections

### Connection Refused
- Verify application is running: `docker ps`
- Check port 4000 is accessible: `netstat -an | findstr 4000`

## Results Files

- `test_results.jtl`: Raw test results (CSV format)
- `summary_report.csv`: Summary statistics
- `aggregate_report.csv`: Aggregated metrics per request type
- `report/`: HTML dashboard with graphs and charts

## CI/CD Integration

Add to your pipeline:
```yaml
- name: Run JMeter Load Test
  run: |
    jmeter -n -t jmeter/FlightBookingLoadTest.jmx -l results/test.jtl
    # Check for acceptable error rate
    $errors = (Import-Csv results/test.jtl | Where-Object {$_.success -eq "false"}).Count
    $total = (Import-Csv results/test.jtl).Count
    $errorRate = ($errors / $total) * 100
    if ($errorRate -gt 5) { exit 1 }
```

## Next Steps

1. Run baseline test and record results
2. Make performance optimizations
3. Re-run and compare results
4. Add more complex scenarios (cancellations, concurrent ETL refresh, etc.)
5. Set up continuous performance monitoring
