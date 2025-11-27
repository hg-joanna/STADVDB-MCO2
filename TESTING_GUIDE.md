# 🧪 Complete Testing Guide - Flight Booking System

## 📋 System Overview

Your flight booking system has these components running:
- **Frontend UI**: http://localhost:5173 (React + Vite)
- **Backend API**: http://localhost:4000 (Node.js + Express)
- **Primary Database**: localhost:5432 (PostgreSQL - OLTP)
- **Hot Backup Database**: localhost:5433 (Physical Replication)
- **Reports Database**: localhost:5434 (Logical Replication + OLAP)

---

## ✅ Test Checklist

### 1. Frontend Features (Web UI)
- [ ] View all available flights
- [ ] Search/filter flights
- [ ] Check seat availability
- [ ] Book a single seat
- [ ] Book multiple seats (batch)
- [ ] Cancel a booking
- [ ] View booking confirmation
- [ ] View reports and analytics

### 2. Backend API Features
- [ ] Flight listing endpoint
- [ ] Flight details endpoint
- [ ] Seat availability endpoint
- [ ] Single seat booking endpoint
- [ ] Batch booking endpoint
- [ ] Booking cancellation endpoint
- [ ] Reports endpoints (7 different reports)

### 3. Database Features
- [ ] OLTP transactions (bookings)
- [ ] Physical replication (Hot Backup)
- [ ] Logical replication (Reports DB)
- [ ] Data warehouse (Star Schema)
- [ ] ETL processes
- [ ] Analytical queries

---

## 🖥️ Part 1: Frontend Testing (Web UI)

### Test 1: Flight Browsing
**URL**: http://localhost:5173

**Steps**:
1. Open http://localhost:5173 in your browser
2. Navigate to "Flight Availability" page
3. You should see a list of flights with:
   - Flight number
   - Route (origin → destination)
   - Departure/Arrival times
   - Available seats count
   - Price

**Expected Result**: All flights display correctly with their details

---

### Test 2: View Available Seats
**Steps**:
1. On the Flight Availability page
2. Click "View Details" or "Book" on any flight
3. You should see a seat map showing:
   - Seat numbers (e.g., 1A, 1B, 2A, etc.)
   - Seat class (Economy/Business)
   - Seat status (Available/Booked)
   - Price per seat

**Expected Result**: Seat map displays with current availability status

---

### Test 3: Single Seat Booking
**Steps**:
1. Select an available seat (should be highlighted or clickable)
2. Click "Book" button
3. Enter customer details:
   - Customer ID (or select from dropdown if available)
   - Confirm booking details
4. Submit the booking
5. Check for confirmation message

**Expected Result**: 
- Booking succeeds
- Confirmation message shows booking ID
- Seat status changes to "Booked"
- Seat becomes unavailable for other users

**Verification**:
- Refresh the page - booked seat should still show as unavailable
- Check the database (see Part 3)

---

### Test 4: Batch Booking (Multiple Seats)
**Steps**:
1. On the seat selection page
2. Select multiple available seats (2-5 seats)
3. Click "Book Selected Seats" or batch booking button
4. Enter customer details
5. Submit the booking

**Expected Result**: 
- All selected seats are booked in a single transaction
- All seats show as booked
- One booking ID is generated for the entire batch

---

### Test 5: Booking Cancellation
**Steps**:
1. Navigate to "My Bookings" or "Cancel Booking" page
2. Enter a booking ID from a previous test
3. Click "Cancel Booking"
4. Confirm the cancellation

**Expected Result**: 
- Booking status changes to "CANCELLED"
- Seats become available again
- Price is refunded (in the system)

**Verification**:
- Go back to seat selection - cancelled seats should be available
- Check booking status in database

---

### Test 6: Reports & Analytics Dashboard
**Steps**:
1. Navigate to "Reports" page in the UI
2. View different report types:
   - Revenue by Route
   - Revenue by Seat Class
   - Monthly Revenue Trends
   - Booking Lead Time
   - Peak Booking Hours
   - Customer Segments
   - Flight Occupancy

**Expected Result**: Each report displays data in tables/charts with meaningful insights

---

## 🔌 Part 2: API Testing (Backend)

You can test the API using PowerShell, curl, or Postman.

### Test 7: Get All Flights
**PowerShell**:
```powershell
Invoke-RestMethod -Uri "http://localhost:4000/api/flight/all" -Method Get | ConvertTo-Json
```

**Expected Response**: JSON array of all flights with details

---

### Test 8: Get Flight Details
**PowerShell**:
```powershell
Invoke-RestMethod -Uri "http://localhost:4000/api/flight/1" -Method Get | ConvertTo-Json
```

**Expected Response**: Flight details for flight ID 1

---

### Test 9: Get Available Seats for a Flight
**PowerShell**:
```powershell
Invoke-RestMethod -Uri "http://localhost:4000/api/flight/1/seats" -Method Get | ConvertTo-Json
```

**Expected Response**: List of available seats with prices

---

### Test 10: Book a Single Seat (API)
**PowerShell**:
```powershell
$booking = @{
    customer_id = 1
    flight_id = 1
    seat_number = "3A"
    total_price = 5000
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:4000/api/booking/single" `
    -Method Post `
    -ContentType "application/json" `
    -Body $booking
```

**Expected Response**: 
```json
{
  "success": true,
  "booking_id": 123,
  "message": "Booking successful"
}
```

---

### Test 11: Book Multiple Seats (API)
**PowerShell**:
```powershell
$batchBooking = @{
    customer_id = 2
    flight_id = 1
    seat_numbers = @("4A", "4B", "4C")
    total_price = 15000
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:4000/api/booking/batch" `
    -Method Post `
    -ContentType "application/json" `
    -Body $batchBooking
```

**Expected Response**: Success message with booking ID for all seats

---

### Test 12: Cancel a Booking (API)
**PowerShell**:
```powershell
$cancellation = @{
    booking_id = 123
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:4000/api/booking/cancel" `
    -Method Post `
    -ContentType "application/json" `
    -Body $cancellation
```

**Expected Response**: Confirmation that booking was cancelled

---

### Test 13: Revenue Reports (API)

**Revenue by Route**:
```powershell
Invoke-RestMethod -Uri "http://localhost:4000/api/reports/revenue/by-route" -Method Get
```

**Revenue by Seat Class**:
```powershell
Invoke-RestMethod -Uri "http://localhost:4000/api/reports/revenue/by-class" -Method Get
```

**Monthly Revenue**:
```powershell
Invoke-RestMethod -Uri "http://localhost:4000/api/reports/revenue/monthly?year=2025" -Method Get
```

**Booking Analytics**:
```powershell
Invoke-RestMethod -Uri "http://localhost:4000/api/reports/bookings/lead-time" -Method Get
Invoke-RestMethod -Uri "http://localhost:4000/api/reports/bookings/peak-hours" -Method Get
```

**Customer & Occupancy**:
```powershell
Invoke-RestMethod -Uri "http://localhost:4000/api/reports/customers/segments" -Method Get
Invoke-RestMethod -Uri "http://localhost:4000/api/reports/occupancy" -Method Get
```

**Dashboard Summary**:
```powershell
Invoke-RestMethod -Uri "http://localhost:4000/api/reports/dashboard/summary" -Method Get
```

---

## 💾 Part 3: Database Testing

### Test 14: Check OLTP Data (Primary Database)

**PowerShell**:
```powershell
docker compose exec primary_db psql -U postgres -d flight_booking -c "SELECT * FROM bookings ORDER BY booking_id DESC LIMIT 10;"
```

**View all tables**:
```powershell
docker compose exec primary_db psql -U postgres -d flight_booking -c "\dt"
```

**Check booking counts**:
```powershell
docker compose exec primary_db psql -U postgres -d flight_booking -c "SELECT status, COUNT(*) FROM bookings GROUP BY status;"
```

---

### Test 15: Verify Physical Replication (Hot Backup)

**Check replication status**:
```powershell
docker compose exec primary_db psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

**Verify data on Hot Backup**:
```powershell
docker compose exec hot_backup_db psql -U postgres -d flight_booking -c "SELECT COUNT(*) FROM bookings;"
```

**Compare data between Primary and Hot Backup**:
```powershell
# Count on Primary
docker compose exec primary_db psql -U postgres -d flight_booking -c "SELECT COUNT(*) as primary_count FROM bookings;"

# Count on Hot Backup
docker compose exec hot_backup_db psql -U postgres -d flight_booking -c "SELECT COUNT(*) as backup_count FROM bookings;"
```

**Expected Result**: Counts should be identical (data is replicated)

---

### Test 16: Verify Logical Replication (Reports DB)

**Check subscription status**:
```powershell
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "SELECT * FROM pg_stat_subscription;"
```

**Verify OLTP data replicated**:
```powershell
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "SELECT COUNT(*) FROM bookings;"
```

**Expected Result**: Bookings table exists and has data from primary

---

### Test 17: Test Data Warehouse (OLAP)

**Run ETL to refresh warehouse**:
```powershell
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "CALL refresh_all_warehouse();"
```

**Check dimension tables**:
```powershell
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "
SELECT 'dim_customer' as table_name, COUNT(*) as row_count FROM warehouse.dim_customer
UNION ALL
SELECT 'dim_flight', COUNT(*) FROM warehouse.dim_flight
UNION ALL
SELECT 'dim_route', COUNT(*) FROM warehouse.dim_route
UNION ALL
SELECT 'dim_seat', COUNT(*) FROM warehouse.dim_seat
UNION ALL
SELECT 'dim_date', COUNT(*) FROM warehouse.dim_date;"
```

**Check fact tables**:
```powershell
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "
SELECT 'fact_bookings' as table_name, COUNT(*) as row_count FROM warehouse.fact_bookings
UNION ALL
SELECT 'fact_seat_inventory', COUNT(*) FROM warehouse.fact_seat_inventory;"
```

**Run an analytical query**:
```powershell
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "
SELECT 
    dr.route_code,
    dr.origin,
    dr.destination,
    COUNT(fb.booking_id) as total_bookings,
    SUM(fb.price) as total_revenue,
    AVG(fb.price) as avg_price
FROM warehouse.fact_bookings fb
JOIN warehouse.dim_flight df ON fb.flight_key = df.flight_key
JOIN warehouse.dim_route dr ON df.route_key = dr.route_key
WHERE fb.is_cancelled = FALSE
GROUP BY dr.route_code, dr.origin, dr.destination
ORDER BY total_revenue DESC
LIMIT 10;"
```

**Expected Result**: Star schema analytical query returns aggregated business insights

---

## 🔄 Part 4: End-to-End Replication Test

### Test 18: Full Replication Flow

This automated test script verifies the complete data flow:

**Run the test script**:
```powershell
.\test-reports.ps1
```

**What it tests**:
1. ✅ Creates a booking on Primary DB (OLTP)
2. ✅ Verifies data appears on Hot Backup DB (Physical Replication)
3. ✅ Verifies data appears on Reports DB (Logical Replication)
4. ✅ Runs ETL to transform data into warehouse
5. ✅ Runs analytical reports on OLAP schema

**Expected Output**: All steps complete successfully with matching data counts

---

## 🧪 Part 5: Automated Test Scripts

Your project has several test scripts you can run:

### Test Script 1: Warehouse Testing
```powershell
.\test-warehouse.ps1
```
Tests the data warehouse ETL and OLAP queries.

### Test Script 2: Reports API Testing
```powershell
.\test-reports-api.ps1
```
Tests all the reports API endpoints.

### Test Script 3: Full System Test
```powershell
.\test-reports.ps1
```
Comprehensive test from booking to analytics.

---

## 🎯 Part 6: Advanced Testing Scenarios

### Scenario 1: Concurrent Bookings (Race Condition)

Test what happens when two users try to book the same seat simultaneously.

**Terminal 1**:
```powershell
$booking = @{customer_id=1; flight_id=1; seat_number="5A"; total_price=5000} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:4000/api/booking/single" -Method Post -ContentType "application/json" -Body $booking
```

**Terminal 2** (run immediately):
```powershell
$booking = @{customer_id=2; flight_id=1; seat_number="5A"; total_price=5000} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:4000/api/booking/single" -Method Post -ContentType "application/json" -Body $booking
```

**Expected Result**: 
- One booking succeeds
- Second booking fails with error (seat already booked)
- Database maintains consistency (seat only booked once)

---

### Scenario 2: Overbooking Prevention

Try to book more seats than available on a flight.

```powershell
# First check how many seats are available
Invoke-RestMethod -Uri "http://localhost:4000/api/flight/1/seats" -Method Get

# Try to book all available seats + 1 more
# This should fail for the last seat
```

---

### Scenario 3: Cancellation and Re-booking

1. Book a seat
2. Cancel the booking
3. Immediately try to book the same seat again

**Expected Result**: Seat becomes available after cancellation and can be rebooked

---

### Scenario 4: Replication Lag Testing

1. Create multiple bookings rapidly on Primary DB
2. Immediately check Hot Backup DB
3. Check Reports DB

**Test replication lag**:
```powershell
# Make 5 rapid bookings
1..5 | ForEach-Object {
    $booking = @{customer_id=1; flight_id=1; seat_number="$_A"; total_price=5000} | ConvertTo-Json
    Invoke-RestMethod -Uri "http://localhost:4000/api/booking/single" -Method Post -ContentType "application/json" -Body $booking
    Start-Sleep -Milliseconds 100
}

# Check counts on all databases
docker compose exec primary_db psql -U postgres -d flight_booking -c "SELECT COUNT(*) FROM bookings;"
docker compose exec hot_backup_db psql -U postgres -d flight_booking -c "SELECT COUNT(*) FROM bookings;"
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "SELECT COUNT(*) FROM bookings;"
```

**Expected Result**: 
- Physical replication (Hot Backup) should have minimal lag (< 1 second)
- Logical replication (Reports) might have slightly more lag

---

## 📊 Part 7: Performance & Load Testing

### Test 19: Bulk Booking Test

Create many bookings to test system performance:

```powershell
# Create 50 bookings
1..50 | ForEach-Object {
    $seatRow = [math]::Floor($_ / 6) + 1
    $seatLetter = @('A','B','C','D','E','F')[$_ % 6]
    $seatNumber = "$seatRow$seatLetter"
    
    $booking = @{
        customer_id = ($_ % 10) + 1
        flight_id = (($_ % 3) + 1)
        seat_number = $seatNumber
        total_price = 5000
    } | ConvertTo-Json
    
    Write-Host "Booking seat $seatNumber..." -ForegroundColor Cyan
    try {
        Invoke-RestMethod -Uri "http://localhost:4000/api/booking/single" `
            -Method Post -ContentType "application/json" -Body $booking
        Write-Host "✓ Success" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed: $_" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 200
}
```

---

## 🔍 Part 8: Database Inspection

### Useful Database Queries

**View recent bookings**:
```sql
SELECT 
    b.booking_id,
    c.full_name as customer,
    f.flight_number,
    s.seat_number,
    b.total_price,
    b.status,
    b.booking_date
FROM bookings b
JOIN customers c ON b.customer_id = c.customer_id
JOIN flights f ON b.flight_id = f.flight_id
JOIN booking_items bi ON b.booking_id = bi.booking_id
JOIN seats s ON bi.seat_id = s.seat_id
ORDER BY b.booking_date DESC
LIMIT 20;
```

**Flight occupancy**:
```sql
SELECT 
    f.flight_number,
    f.origin || ' → ' || f.destination as route,
    COUNT(s.seat_id) as total_seats,
    COUNT(CASE WHEN s.is_available = FALSE THEN 1 END) as booked_seats,
    ROUND(COUNT(CASE WHEN s.is_available = FALSE THEN 1 END) * 100.0 / COUNT(s.seat_id), 2) as occupancy_rate
FROM flights f
JOIN seats s ON f.flight_id = s.flight_id
GROUP BY f.flight_id, f.flight_number, route
ORDER BY occupancy_rate DESC;
```

**Revenue analysis**:
```sql
SELECT 
    DATE(b.booking_date) as booking_day,
    COUNT(*) as bookings,
    SUM(b.total_price) as revenue,
    AVG(b.total_price) as avg_booking_value
FROM bookings b
WHERE b.status = 'CONFIRMED'
GROUP BY DATE(b.booking_date)
ORDER BY booking_day DESC;
```

---

## ✅ Testing Checklist Summary

After completing all tests, you should have verified:

### Frontend ✅
- [x] Flight browsing works
- [x] Seat selection interface works
- [x] Single seat booking works
- [x] Batch booking works
- [x] Cancellation works
- [x] Reports display correctly

### Backend API ✅
- [x] All flight endpoints respond correctly
- [x] Booking endpoints handle transactions properly
- [x] Reports endpoints return analytics data
- [x] Error handling works (duplicate bookings, invalid data)

### Database ✅
- [x] OLTP transactions complete successfully
- [x] Physical replication syncs data to Hot Backup
- [x] Logical replication syncs data to Reports DB
- [x] Star schema warehouse is populated
- [x] ETL processes transform data correctly
- [x] Analytical queries return insights

### System Features ✅
- [x] High availability (Hot Backup can take over)
- [x] Data consistency (ACID properties maintained)
- [x] Replication lag is minimal
- [x] Concurrent bookings handled correctly
- [x] Analytics separated from OLTP workload

---

## 🚀 Quick Start Testing

**Run everything in order**:

```powershell
# 1. Open the web UI
Start-Process "http://localhost:5173"

# 2. Test a booking via UI
# (Use the web interface to book a seat)

# 3. Run the comprehensive test script
.\test-reports.ps1

# 4. Test all API reports
.\test-reports-api.ps1

# 5. Check replication
docker compose exec primary_db psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# 6. View data in warehouse
docker compose exec reports_db psql -U postgres -d flight_booking_reports -c "SELECT COUNT(*) FROM warehouse.fact_bookings;"
```

---

## 🐛 Troubleshooting

### Frontend not loading?
```powershell
cd frontend
npm install
npm run dev
```

### Backend API not responding?
```powershell
docker compose restart app_server
docker compose logs app_server
```

### Database connection issues?
```powershell
docker compose ps
docker compose logs primary_db
```

### Replication not working?
```powershell
# Check replication status
docker compose exec primary_db psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Restart databases
docker compose restart primary_db hot_backup_db reports_db
```

---

## 📝 Notes

- **Customer IDs**: The system has pre-populated customers (IDs 1-10)
- **Flight IDs**: Sample flights (IDs 1-5) are available
- **Seat Numbers**: Format is `RowLetter` (e.g., 1A, 2B, 3C)
- **Prices**: Vary by seat class (Business > Economy)
- **Test Data**: You can reset all data with `docker compose down -v` (WARNING: deletes everything)

---

## 🎉 Success Criteria

Your system is working correctly if:
1. ✅ You can book seats through the UI
2. ✅ Bookings appear in all three databases
3. ✅ Reports show meaningful analytics
4. ✅ Replication happens automatically
5. ✅ Cancellations free up seats
6. ✅ No duplicate bookings for same seat
7. ✅ System handles concurrent requests

---

**Happy Testing! 🧪✨**
