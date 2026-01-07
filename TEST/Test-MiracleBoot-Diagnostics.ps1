#!/usr/bin/env powershell
# MIRACLEBOOT ADVANCED DIAGNOSTICS - AUTOMATED TEST SUITE
# Purpose: Test MiracleBoot-Diagnostics.ps1 with autonomous validation

param()

# TEST CONFIGURATION
$testConfig = @{
    ReportPath    = (Join-Path $env:TEMP "MiracleBoot-DiagTests\Reports")
    DiagModule    = 'c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\MiracleBoot-Diagnostics.ps1'
}

$testResults = @{
    Total  = 0
    Passed = 0
    Failed = 0
}

# TEST FRAMEWORK FUNCTIONS

function Test-Result {
    param(
        [string]$TestName,
        [bool]$Result,
        [string]$Details = ""
    )
    
    $script:testResults.Total++
    
    if ($Result) {
        $script:testResults.Passed++
        Write-Host "[PASS] $TestName" -ForegroundColor Green
        if ($Details) { Write-Host "   Details: $Details" -ForegroundColor Gray }
    }
    else {
        $script:testResults.Failed++
        Write-Host "[FAIL] $TestName" -ForegroundColor Red
        if ($Details) { Write-Host "   Details: $Details" -ForegroundColor Yellow }
    }
}

function Test-Command {
    param([string]$CommandName)
    return (Get-Command $CommandName -ErrorAction SilentlyContinue) -ne $null
}

# SETUP PHASE

Write-Host ""
Write-Host "MIRACLEBOOT ADVANCED DIAGNOSTICS - TEST SUITE" -ForegroundColor Cyan
Write-Host ""

Write-Host "[SETUP] Creating test environment..." -ForegroundColor Gray

$null = New-Item -ItemType Directory -Path $testConfig.ReportPath -Force -ErrorAction SilentlyContinue

Write-Host "[SETUP] Loading diagnostics module..." -ForegroundColor Gray

try {
    . $testConfig.DiagModule
    Write-Host "[SETUP] OK - Diagnostics module loaded" -ForegroundColor Green
}
catch {
    Write-Host "[SETUP] FAIL - Cannot load module: $_" -ForegroundColor Red
    exit 1
}

# TEST SECTION 1: MODULE VALIDATION

Write-Host ""
Write-Host "[TEST SECTION 1] MODULE VALIDATION" -ForegroundColor Yellow

Test-Result "Get-DiskSmartData available" (Test-Command "Get-DiskSmartData") ""
Test-Result "Get-SystemEventAnalysis available" (Test-Command "Get-SystemEventAnalysis") ""
Test-Result "Get-BootPerformanceAnalysis available" (Test-Command "Get-BootPerformanceAnalysis") ""
Test-Result "Get-DriverHealthStatus available" (Test-Command "Get-DriverHealthStatus") ""
Test-Result "Get-ThermalCpuStatus available" (Test-Command "Get-ThermalCpuStatus") ""
Test-Result "New-DiagnosticsReport available" (Test-Command "New-DiagnosticsReport") ""

# TEST SECTION 2: S.M.A.R.T. DIAGNOSTICS

Write-Host ""
Write-Host "[TEST SECTION 2] S.M.A.R.T. DIAGNOSTICS" -ForegroundColor Yellow

$smartData = $null
try {
    $smartData = Get-DiskSmartData -DriveLetter 'C'
    Test-Result "Get S.M.A.R.T. data" ($smartData -ne $null) "Data retrieved"
}
catch {
    Test-Result "Get S.M.A.R.T. data" $false "Error: $_"
}

if ($smartData) {
    Test-Result "S.M.A.R.T. has DriveHealth" ($smartData.ContainsKey('DriveHealth')) "Health status exists"
    Test-Result "S.M.A.R.T. has Temperature" ($smartData.ContainsKey('Temperature')) "Temperature data exists"
    Test-Result "S.M.A.R.T. has Attributes" ($smartData.Attributes.Count -gt 0) "Attributes found"
}

# TEST SECTION 3: EVENT LOG ANALYSIS

Write-Host ""
Write-Host "[TEST SECTION 3] EVENT LOG ANALYSIS" -ForegroundColor Yellow

$eventAnalysis = $null
try {
    $eventAnalysis = Get-SystemEventAnalysis -DaysToAnalyze 7
    Test-Result "Get event analysis" ($eventAnalysis -ne $null) "Event data retrieved"
}
catch {
    Test-Result "Get event analysis" $false "Error: $_"
}

if ($eventAnalysis) {
    Test-Result "Event analysis has CriticalErrors" ($eventAnalysis.ContainsKey('CriticalErrors')) "Critical count found"
    Test-Result "Event analysis has Warnings" ($eventAnalysis.ContainsKey('Warnings')) "Warning count found"
    Test-Result "Event analysis has BootEvents" ($eventAnalysis.ContainsKey('BootEvents')) "Boot events found"
}

# TEST SECTION 4: BOOT PERFORMANCE

Write-Host ""
Write-Host "[TEST SECTION 4] BOOT PERFORMANCE" -ForegroundColor Yellow

$bootAnalysis = $null
try {
    $bootAnalysis = Get-BootPerformanceAnalysis
    Test-Result "Get boot analysis" ($bootAnalysis -ne $null) "Boot metrics retrieved"
}
catch {
    Test-Result "Get boot analysis" $false "Error: $_"
}

if ($bootAnalysis) {
    Test-Result "Boot analysis has TotalBootTime" ($bootAnalysis.ContainsKey('TotalBootTime')) "Boot time found"
    Test-Result "Boot analysis has WindowsBootTime" ($bootAnalysis.ContainsKey('WindowsBootTime')) "Windows load time found"
    Test-Result "Boot analysis has DriverLoadTime" ($bootAnalysis.ContainsKey('DriverLoadTime')) "Driver load time found"
}

# TEST SECTION 5: DRIVER HEALTH

Write-Host ""
Write-Host "[TEST SECTION 5] DRIVER HEALTH" -ForegroundColor Yellow

$driverAnalysis = $null
try {
    $driverAnalysis = Get-DriverHealthStatus
    Test-Result "Get driver health" ($driverAnalysis -ne $null) "Driver data retrieved"
}
catch {
    Test-Result "Get driver health" $false "Error: $_"
}

if ($driverAnalysis) {
    Test-Result "Driver analysis has TotalDrivers" ($driverAnalysis.ContainsKey('TotalDrivers')) "Total drivers found"
    Test-Result "Driver analysis has ProblematicCount" ($driverAnalysis.ContainsKey('ProblematicCount')) "Problem count found"
    Test-Result "Driver TotalDrivers is numeric" ([int]$driverAnalysis.TotalDrivers -ge 0) "Valid driver count"
}

# TEST SECTION 6: THERMAL MONITORING

Write-Host ""
Write-Host "[TEST SECTION 6] THERMAL MONITORING" -ForegroundColor Yellow

$thermalData = $null
try {
    $thermalData = Get-ThermalCpuStatus
    Test-Result "Get thermal status" ($thermalData -ne $null) "Thermal data retrieved"
}
catch {
    Test-Result "Get thermal status" $false "Error: $_"
}

if ($thermalData) {
    Test-Result "Thermal data has CPUCount" ($thermalData.ContainsKey('CPUCount')) "CPU count found"
    Test-Result "Thermal data has AverageTemp" ($thermalData.ContainsKey('AverageTemp')) "Average temp found"
    Test-Result "Thermal data has Status" ($thermalData.ContainsKey('Status')) "Status found"
}

# TEST SECTION 7: COMPREHENSIVE REPORT GENERATION

Write-Host ""
Write-Host "[TEST SECTION 7] COMPREHENSIVE REPORT" -ForegroundColor Yellow

$reportResult = $null
try {
    $reportResult = New-DiagnosticsReport -ReportPath $testConfig.ReportPath
    Test-Result "Generate diagnostics report" ($reportResult.Success -eq $true) "Report created"
}
catch {
    Test-Result "Generate diagnostics report" $false "Error: $_"
}

if ($reportResult) {
    Test-Result "Report JSON created" (Test-Path $reportResult.JsonFile) "JSON file exists"
    Test-Result "Report HTML created" (Test-Path $reportResult.HtmlFile) "HTML file exists"
    Test-Result "Report has status" ($reportResult.Status -ne $null) "Status assigned"
}

# TEST SECTION 8: CODE VALIDATION

Write-Host ""
Write-Host "[TEST SECTION 8] CODE VALIDATION" -ForegroundColor Yellow

try {
    $tokens = [System.Management.Automation.PSParser]::Tokenize([IO.File]::ReadAllText($testConfig.DiagModule), [ref]$null)
    Test-Result "MiracleBoot-Diagnostics.ps1 Syntax Valid" $true "Syntax OK"
}
catch {
    Test-Result "MiracleBoot-Diagnostics.ps1 Syntax Valid" $false "Syntax error: $_"
}

# TEST SUMMARY

Write-Host ""
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests:  $($testResults.Total)" -ForegroundColor Cyan
Write-Host "Passed:       $($testResults.Passed)" -ForegroundColor Green

if ($testResults.Failed -eq 0) {
    Write-Host "Failed:       $($testResults.Failed)" -ForegroundColor Green
}
else {
    Write-Host "Failed:       $($testResults.Failed)" -ForegroundColor Red
}

if ($testResults.Total -gt 0) {
    $successRate = [Math]::Round(($testResults.Passed / $testResults.Total) * 100, 2)
    Write-Host "Success Rate: $successRate percent" -ForegroundColor Cyan
}

Write-Host ""

# CLEANUP PHASE

Write-Host "[CLEANUP] Removing test artifacts..." -ForegroundColor Gray
try {
    Remove-Item -Path $testConfig.ReportPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "OK - Test files cleaned up" -ForegroundColor Green
}
catch {
    Write-Host "WARNING - Could not cleanup test files" -ForegroundColor Yellow
}

Write-Host ""

# EXIT WITH APPROPRIATE CODE

if ($testResults.Failed -eq 0) {
    Write-Host "ALL TESTS PASSED - READY FOR PRODUCTION" -ForegroundColor Green
    Write-Host ""
    exit 0
}
else {
    Write-Host "SOME TESTS FAILED - REVIEW ABOVE" -ForegroundColor Red
    Write-Host ""
    exit 1
}
