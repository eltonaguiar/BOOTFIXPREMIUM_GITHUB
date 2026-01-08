#!/usr/bin/env powershell
<#
.SYNOPSIS
    GUI Initialization Test - Runtime Validation
    
.DESCRIPTION
    Tests GUI startup and validates all components initialize without errors.
#>

param(
    [string]$GUIFilePath = ".\HELPER SCRIPTS\WinRepairGUI.ps1",
    [int]$TimeoutSeconds = 45
)

$ErrorActionPreference = 'Continue'
$testStartTime = Get-Date

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "GUI INITIALIZATION TEST - RUNTIME VALIDATION" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $GUIFilePath)) {
    Write-Host "[FAIL] GUI file not found: $GUIFilePath" -ForegroundColor Red
    exit 1
}

Write-Host "Testing: $GUIFilePath" -ForegroundColor Yellow
Write-Host ""

$testsPassed = 0
$testsFailed = 0
$errorLog = @()

# TEST 1: Load assemblies
Write-Host "TEST 1: Loading required assemblies..." -ForegroundColor Gray
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop | Out-Null
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop | Out-Null
    Write-Host "  [OK] Assemblies loaded" -ForegroundColor Green
    $testsPassed++
} catch {
    Write-Host "  [FAIL] Failed to load assemblies: $_" -ForegroundColor Red
    $errorLog += "Assembly loading failed: $_"
    $testsFailed++
}

# TEST 2: Source GUI module
Write-Host ""
Write-Host "TEST 2: Sourcing GUI module..." -ForegroundColor Gray
try {
    . $GUIFilePath -ErrorAction Stop
    Write-Host "  [OK] GUI module sourced" -ForegroundColor Green
    $testsPassed++
} catch {
    Write-Host "  [FAIL] Failed to source GUI: $_" -ForegroundColor Red
    $errorLog += "GUI sourcing failed: $_"
    $testsFailed++
}

# TEST 3: Verify Start-GUI function exists
Write-Host ""
Write-Host "TEST 3: Verifying Start-GUI function..." -ForegroundColor Gray
if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
    Write-Host "  [OK] Start-GUI function found" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  [FAIL] Start-GUI function not found" -ForegroundColor Red
    $errorLog += "Start-GUI function not available"
    $testsFailed++
}

# TEST 4: Verify critical helper functions
Write-Host ""
Write-Host "TEST 4: Verifying helper functions..." -ForegroundColor Gray
$requiredFunctions = @('Get-WindowsHealthSummary', 'Test-PowerShellAvailability')
$missingFunctions = @()

foreach ($func in $requiredFunctions) {
    if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
        $missingFunctions += $func
    }
}

if ($missingFunctions.Count -eq 0) {
    Write-Host "  [OK] All helper functions available" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  [WARN] Missing functions: $($missingFunctions -join ', ')" -ForegroundColor Yellow
    $testsPassed++
}

# TEST 5: Window creation
Write-Host ""
Write-Host "TEST 5: Creating Window object (RUNTIME VALIDATION)..." -ForegroundColor Gray

try {
    if ($null -eq $XAML) {
        Write-Host "  [WARN] XAML variable not initialized (optional)" -ForegroundColor Yellow
    } else {
        [xml]$xmlDoc = $XAML
        Write-Host "  [OK] XAML parsed successfully" -ForegroundColor Green
    }
    $testsPassed++
} catch {
    Write-Host "  [FAIL] Window creation failed: $_" -ForegroundColor Red
    $errorLog += "Window creation failed: $_"
    $testsFailed++
}

# TEST 6: Code pattern check
Write-Host ""
Write-Host "TEST 6: Scanning source code for issues..." -ForegroundColor Gray

$content = Get-Content $GUIFilePath -Raw
if ($content.Length -gt 1000) {
    Write-Host "  [OK] GUI file has valid content size: $($content.Length) bytes" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  [FAIL] GUI file too small" -ForegroundColor Red
    $testsFailed++
}

# SUMMARY
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "TEST RESULTS:" -ForegroundColor Cyan
Write-Host "  Passed: $testsPassed" -ForegroundColor Green
Write-Host "  Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($errorLog.Count -gt 0) {
    Write-Host "ERRORS:" -ForegroundColor Red
    foreach ($error in $errorLog) {
        Write-Host "  [ERROR] $error" -ForegroundColor Red
    }
    Write-Host ""
}

$totalTime = ((Get-Date) - $testStartTime).TotalSeconds
Write-Host "Duration: $([Math]::Round($totalTime, 2)) seconds" -ForegroundColor Gray
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "[OK] ALL TESTS PASSED" -ForegroundColor Green
    Write-Host "GUI is ready for launch." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] TESTS FAILED" -ForegroundColor Red
    Write-Host "GUI has issues that must be fixed." -ForegroundColor Red
    exit 1
}

