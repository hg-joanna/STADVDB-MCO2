# Test Data Warehouse and Reports
Write-Host "=== DATA WAREHOUSE & REPORTS TEST ===" -ForegroundColor Cyan

# Check warehouse tables exist
Write-Host "`n1. Checking warehouse schema..." -ForegroundColor Yellow
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE 'dim_%' OR table_name LIKE 'fact_%' ORDER BY table_name;"

# Check dimension data
Write-Host "`n2. Checking dimension tables data..." -ForegroundColor Yellow
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "SELECT 'dim_customer' as table_name, COUNT(*) as rows FROM dim_customer UNION ALL SELECT 'dim_flight', COUNT(*) FROM dim_flight UNION ALL SELECT 'dim_route', COUNT(*) FROM dim_route UNION ALL SELECT 'dim_seat', COUNT(*) FROM dim_seat UNION ALL SELECT 'fact_bookings', COUNT(*) FROM fact_bookings UNION ALL SELECT 'fact_seat_inventory', COUNT(*) FROM fact_seat_inventory;"

# Run Report 1: Top Routes
Write-Host "`n3. REPORT 1: Top Routes by Number of Flights..." -ForegroundColor Yellow
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "SELECT dr.route_code, dr.origin, dr.destination, COUNT(df.flight_key) as total_flights FROM dim_route dr LEFT JOIN dim_flight df ON dr.route_key = df.route_key GROUP BY dr.route_code, dr.origin, dr.destination ORDER BY total_flights DESC LIMIT 5;"

# Run Report 2: Seat Utilization
Write-Host "`n4. REPORT 2: Current Seat Utilization by Class..." -ForegroundColor Yellow
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "SELECT ds.seat_class, COUNT(*) as total_seats, SUM(CASE WHEN fsi.is_available THEN 1 ELSE 0 END) as available, SUM(CASE WHEN fsi.is_booked THEN 1 ELSE 0 END) as booked FROM dim_seat ds JOIN fact_seat_inventory fsi ON ds.seat_key = fsi.seat_key WHERE fsi.snapshot_date = CURRENT_DATE GROUP BY ds.seat_class;"

# Run Report 3: Customer Segments
Write-Host "`n5. REPORT 3: Customer Segmentation..." -ForegroundColor Yellow
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "SELECT customer_segment, COUNT(*) as customers, ROUND(AVG(total_bookings), 2) as avg_bookings, ROUND(AVG(total_spent), 2) as avg_lifetime_value FROM dim_customer WHERE customer_segment IS NOT NULL GROUP BY customer_segment ORDER BY avg_lifetime_value DESC;"

Write-Host "`n=== TEST COMPLETE ===" -ForegroundColor Green
