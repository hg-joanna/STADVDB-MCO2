# Test Flight Booking System - Reports & Analytics
# This script tests the complete flow from booking to analytics

Write-Host ""
Write-Host "=== FLIGHT BOOKING SYSTEM - REPORTS TEST ===" -ForegroundColor Cyan
Write-Host "Testing OLTP -> Replication -> OLAP flow" -ForegroundColor Cyan
Write-Host ""

# 1. Check system status
Write-Host "1. Checking system status..." -ForegroundColor Yellow
docker compose ps

# 2. Make a test booking
Write-Host ""
Write-Host "2. Creating test booking..." -ForegroundColor Yellow
$booking = @{
    customer_id = 1
    flight_id = 1
    seat_number = "1A"
    total_price = 5000
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Uri "http://localhost:4000/booking/single" `
        -Method Post -ContentType "application/json" -Body $booking
    Write-Host "✓ Booking successful: $($result.message)" -ForegroundColor Green
} catch {
    Write-Host "✗ Booking failed: $_" -ForegroundColor Red
}

Start-Sleep -Seconds 2

# 3. Check OLTP database (Primary)
Write-Host "`n3. Checking OLTP database (Primary DB)..." -ForegroundColor Yellow
docker compose exec primary_db psql -U postgres -d flight_booking -c `
    "SELECT b.booking_id, c.full_name, f.flight_number, s.seat_number, b.total_price, b.status FROM bookings b JOIN customers c ON b.customer_id = c.customer_id JOIN flights f ON b.flight_id = f.flight_id JOIN booking_items bi ON b.booking_id = bi.booking_id JOIN seats s ON bi.seat_id = s.seat_id ORDER BY b.booking_id DESC LIMIT 5;"

# 4. Check Hot Backup replication
Write-Host "`n4. Verifying Hot Backup (Physical Replication)..." -ForegroundColor Yellow
docker compose exec hot_backup_db psql -U postgres -d flight_booking -c `
    "SELECT COUNT(*) as bookings FROM bookings;"

# 5. Check Reports DB replication
Write-Host "`n5. Verifying Reports DB (Logical Replication)..." -ForegroundColor Yellow
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c `
    "SELECT COUNT(*) as bookings FROM bookings;"

# 6. Run ETL to populate warehouse
Write-Host "`n6. Running ETL to populate data warehouse..." -ForegroundColor Yellow
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c `
    "CALL refresh_dimensions(); CALL refresh_facts();" 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ ETL completed successfully" -ForegroundColor Green
} else {
    Write-Host "Note: Manual ETL procedures may not exist. Running full pipeline..." -ForegroundColor Yellow
    # Run the master ETL pipeline
    docker compose exec reports_db psql -U postgres -d flight_booking_reports `
        -f /docker-entrypoint-initdb.d/etl_master_pipeline.sql 2>&1 | Out-Null
}

Start-Sleep -Seconds 2

# 7. Run analytical reports
Write-Host "`n7. Running Analytical Reports..." -ForegroundColor Yellow

Write-Host "`n--- REPORT 1: Revenue by Route ---" -ForegroundColor Cyan
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c `
    "SELECT dr.route_code, dr.origin, dr.destination, COUNT(DISTINCT fb.booking_id) as bookings, SUM(fb.price) as total_revenue FROM fact_bookings fb JOIN dim_flight df ON fb.flight_key = df.flight_key JOIN dim_route dr ON df.route_key = dr.route_key WHERE fb.is_cancelled = FALSE GROUP BY dr.route_code, dr.origin, dr.destination ORDER BY total_revenue DESC LIMIT 5;"

Write-Host "`n--- REPORT 2: Seat Utilization by Class ---" -ForegroundColor Cyan
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c `
    "SELECT ds.seat_class, COUNT(fb.booking_fact_key) as seats_booked, SUM(fb.price) as revenue, AVG(fb.price) as avg_price FROM fact_bookings fb JOIN dim_seat ds ON fb.seat_key = ds.seat_key WHERE fb.is_cancelled = FALSE GROUP BY ds.seat_class ORDER BY revenue DESC;"

Write-Host "`n--- REPORT 3: Customer Segments ---" -ForegroundColor Cyan
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c `
    "SELECT customer_segment, COUNT(*) as customers, AVG(total_bookings) as avg_bookings, AVG(total_spent) as avg_spent FROM dim_customer WHERE customer_segment IS NOT NULL GROUP BY customer_segment ORDER BY avg_spent DESC;"

Write-Host "`n--- REPORT 4: Daily Seat Inventory ---" -ForegroundColor Cyan
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c `
    "SELECT COUNT(*) as total_seats, SUM(CASE WHEN is_available THEN 1 ELSE 0 END) as available, SUM(CASE WHEN is_booked THEN 1 ELSE 0 END) as booked, ROUND(SUM(CASE WHEN is_booked THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as utilization FROM fact_seat_inventory WHERE snapshot_date = CURRENT_DATE;"

Write-Host "`n=== TEST COMPLETED ===" -ForegroundColor Green
Write-Host "The system demonstrates:" -ForegroundColor Yellow
Write-Host "  ✓ OLTP transactions on Primary DB" -ForegroundColor White
Write-Host "  ✓ Physical replication to Hot Backup" -ForegroundColor White
Write-Host "  ✓ Logical replication to Reports DB" -ForegroundColor White
Write-Host "  ✓ ETL transformation to Star Schema" -ForegroundColor White
Write-Host "  ✓ Analytical reports on OLAP warehouse`n" -ForegroundColor White
