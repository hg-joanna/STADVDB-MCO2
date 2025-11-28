#!/usr/bin/env pwsh
# JMeter Load Test Runner for Flight Booking System

param(
    [switch]$GUI,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Help {
    Write-Host ""
    Write-Host "JMeter Load Test Runner" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "    .\run-jmeter-test.ps1          Run test in CLI mode (recommended)"
    Write-Host "    .\run-jmeter-test.ps1 -GUI     Open JMeter GUI for test development"
    Write-Host "    .\run-jmeter-test.ps1 -Help    Show this help message"
    Write-Host ""
    Write-Host "Requirements:" -ForegroundColor Yellow
    Write-Host "    - JMeter installed and in PATH"
    Write-Host "    - Docker containers running (docker compose up -d)"
    Write-Host ""
}

if ($Help) {
    Show-Help
    exit 0
}

Write-Host ""
Write-Host "=== Flight Booking System Load Test ===" -ForegroundColor Cyan
Write-Host "Starting load test execution..." -ForegroundColor Cyan
Write-Host ""

# Check if JMeter is installed
Write-Host "[1/5] Checking JMeter installation..." -ForegroundColor Yellow
try {
    $jmeterVersion = jmeter --version 2>&1 | Select-Object -First 1
    Write-Host "  [OK] JMeter found: $jmeterVersion" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] JMeter not found in PATH" -ForegroundColor Red
    Write-Host "  Please install JMeter and add it to your PATH" -ForegroundColor Red
    Write-Host "  Download: https://jmeter.apache.org/download_jmeter.cgi" -ForegroundColor Yellow
    exit 1
}

# Check if application is running
Write-Host ""
Write-Host "[2/5] Checking if application is running..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:4000/api/flight" -Method GET -TimeoutSec 5 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "  [OK] Application is running on port 4000" -ForegroundColor Green
    }
} catch {
    Write-Host "  [ERROR] Application is not running or not accessible" -ForegroundColor Red
    Write-Host "  Please start the application: docker compose up -d" -ForegroundColor Yellow
    exit 1
}

# Check if test file exists
Write-Host ""
Write-Host "[3/5] Checking test file..." -ForegroundColor Yellow
$testFile = "FlightBookingLoadTest.jmx"
if (-not (Test-Path $testFile)) {
    Write-Host "  [ERROR] Test file not found: $testFile" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Test file found: $testFile" -ForegroundColor Green

# Create results directory
Write-Host ""
Write-Host "[4/5] Preparing results directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path ".\results" | Out-Null
Write-Host "  [OK] Results directory ready" -ForegroundColor Green

# Run JMeter
Write-Host ""
Write-Host "[5/5] Running JMeter load test..." -ForegroundColor Yellow

if ($GUI) {
    Write-Host "  -> Opening JMeter GUI..." -ForegroundColor Cyan
    Write-Host "  -> Click the green 'Start' button to run the test" -ForegroundColor Cyan
    jmeter -t $testFile
} else {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = "results/test_results_$timestamp.jtl"
    $reportDir = "results/report_$timestamp"
    
    Write-Host "  -> Running in non-GUI mode (optimal for performance)" -ForegroundColor Cyan
    Write-Host "  -> Log file: $logFile" -ForegroundColor Gray
    Write-Host "  -> Report directory: $reportDir" -ForegroundColor Gray
    Write-Host ""
    
    try {
        jmeter -n -t $testFile -l $logFile -e -o $reportDir
        
        Write-Host ""
        Write-Host "[SUCCESS] Test completed successfully!" -ForegroundColor Green
        
        # Parse results
        Write-Host ""
        Write-Host "=== Test Results Summary ===" -ForegroundColor Cyan
        
        if (Test-Path $logFile) {
            $results = Import-Csv $logFile
            $total = $results.Count
            $errors = ($results | Where-Object { $_.success -eq "false" }).Count
            $successful = $total - $errors
            $avgTime = ($results | Measure-Object -Property elapsed -Average).Average
            $errorRate = if ($total -gt 0) { [math]::Round(($errors / $total) * 100, 2) } else { 0 }
            
            Write-Host "Total Requests:    $total" -ForegroundColor White
            Write-Host "Successful:        $successful" -ForegroundColor Green
            Write-Host "Failed:            $errors" -ForegroundColor $(if ($errors -gt 0) { "Red" } else { "Green" })
            Write-Host "Error Rate:        $errorRate%" -ForegroundColor $(if ($errorRate -gt 5) { "Red" } elseif ($errorRate -gt 1) { "Yellow" } else { "Green" })
            Write-Host "Avg Response Time: $([math]::Round($avgTime, 2)) ms" -ForegroundColor White
            
            Write-Host ""
            Write-Host "-> View detailed HTML report:" -ForegroundColor Cyan
            Write-Host "  $reportDir\index.html" -ForegroundColor Yellow
            
            # Open report in browser
            $reportPath = Resolve-Path "$reportDir\index.html"
            Write-Host ""
            Write-Host "Opening report in browser..." -ForegroundColor Cyan
            Start-Process $reportPath
            
        } else {
            Write-Host "Warning: Could not parse results file" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host ""
        Write-Host "[ERROR] Test failed with error:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "=== Test Execution Complete ===" -ForegroundColor Cyan
Write-Host ""
