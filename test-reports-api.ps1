# Test Reports API Endpoints
Write-Host "=== TESTING REPORTS API ===" -ForegroundColor Cyan

# Start Docker if not running
$dockerStatus = docker compose ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Starting Docker containers..." -ForegroundColor Yellow
    docker compose up -d
    Start-Sleep -Seconds 20
}

Write-Host "`nTesting Reports API endpoints...`n" -ForegroundColor Yellow

# Test 1: Dashboard Summary
Write-Host "1. Dashboard Summary:" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:4000/api/reports/dashboard/summary" -Method Get
    $response | ConvertTo-Json -Depth 3
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# Test 2: Top Routes
Write-Host "`n2. Top Routes:" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:4000/api/reports/routes/top" -Method Get
    $response | Select-Object -First 3 | Format-Table
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# Test 3: Seat Utilization
Write-Host "`n3. Seat Utilization:" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:4000/api/reports/operations/seat-utilization" -Method Get
    $response | Format-Table
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# Test 4: Customer Segments
Write-Host "`n4. Customer Segments:" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:4000/api/reports/customers/segments" -Method Get
    $response | Format-Table
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# Test 5: Revenue by Seat Class
Write-Host "`n5. Revenue by Seat Class:" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:4000/api/reports/revenue/by-class" -Method Get
    $response | Format-Table
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# Test 6: Monthly Revenue (2025)
Write-Host "`n6. Monthly Revenue (2025):" -ForegroundColor Green
try {
    $response = Invoke-RestMethod -Uri "http://localhost:4000/api/reports/revenue/monthly?year=2025" -Method Get
    $response | Select-Object -First 3 | Format-Table
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`n=== ALL TESTS COMPLETE ===" -ForegroundColor Cyan
Write-Host "API Documentation: See REPORTS_API.md" -ForegroundColor Yellow
