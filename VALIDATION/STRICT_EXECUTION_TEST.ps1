#!/usr/bin/env powershell
<#
.SYNOPSIS
    STRICT EXECUTION TEST - Catches ALL Errors
    
.DESCRIPTION
    Actually executes GUI code and fails immediately on ANY error.
    This is the gatekeeper - if ANY error occurs, test FAILS.
#>

param(
    [string]$OutputPath = ".\VALIDATION\TEST_LOGS\STRICT_EXECUTION_TEST.log"
)

$ErrorActionPreference = 'Stop'

# Ensure log directory exists
$logDir = Split-Path $OutputPath
if (-not (Test-Path $logDir)) {
    mkdir $logDir -Force | Out-Null
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "STRICT EXECUTION TEST - ALL ERRORS FAIL" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$log = @()
$hasErrors = $false
$errorCount = 0

$log += "=== STRICT EXECUTION TEST LOG ==="
$log += "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$log += ""

# Test 1: Load assemblies
Write-Host "TEST 1: Loading assemblies..." -ForegroundColor Yellow
$log += "TEST 1: Loading assemblies"
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Write-Host "  [OK] PresentationFramework" -ForegroundColor Green
    $log += "  [OK] PresentationFramework"
} catch {
    Write-Host "  [ERROR] PresentationFramework: $_" -ForegroundColor Red
    $log += "  [ERROR] PresentationFramework: $_"
    $hasErrors = $true
    $errorCount++
}

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Write-Host "  [OK] System.Windows.Forms" -ForegroundColor Green
    $log += "  [OK] System.Windows.Forms"
} catch {
    Write-Host "  [ERROR] System.Windows.Forms: $_" -ForegroundColor Red
    $log += "  [ERROR] System.Windows.Forms: $_"
    $hasErrors = $true
    $errorCount++
}

# Test 2: Load WinRepairCore
Write-Host ""
Write-Host "TEST 2: Loading WinRepairCore..." -ForegroundColor Yellow
$log += ""
$log += "TEST 2: Loading WinRepairCore"
try {
    . ".\HELPER SCRIPTS\WinRepairCore.ps1" -ErrorAction Stop
    Write-Host "  [OK] WinRepairCore.ps1 loaded" -ForegroundColor Green
    $log += "  [OK] WinRepairCore.ps1 loaded"
} catch {
    Write-Host "  [ERROR] $_" -ForegroundColor Red
    $log += "  [ERROR] $_"
    $hasErrors = $true
    $errorCount++
}

# Test 3: Load GUI (THIS IS THE REAL TEST)
Write-Host ""
Write-Host "TEST 3: Loading WinRepairGUI..." -ForegroundColor Yellow
$log += ""
$log += "TEST 3: Loading WinRepairGUI - REAL EXECUTION TEST"

# Capture any errors that occur during GUI loading
$errorBefore = $global:Error.Count
$warningBefore = $global:WarningPreference

try {
    $VerbosePreference = 'SilentlyContinue'
    $WarningPreference = 'SilentlyContinue'
    
    # Actually source the GUI file - this WILL error if there are problems
    . ".\HELPER SCRIPTS\WinRepairGUI.ps1" -ErrorAction Stop
    
    Write-Host "  [OK] GUI module loaded successfully" -ForegroundColor Green
    $log += "  [OK] GUI module loaded successfully"
    
} catch {
    Write-Host "  [ERROR] GUI loading failed: $($_.Exception.Message)" -ForegroundColor Red
    $log += "  [ERROR] GUI loading failed: $($_.Exception.Message)"
    $log += "  Stack: $($_.ScriptStackTrace)"
    $hasErrors = $true
    $errorCount++
}

# Test 4: Verify Start-GUI function
Write-Host ""
Write-Host "TEST 4: Verifying Start-GUI function..." -ForegroundColor Yellow
$log += ""
$log += "TEST 4: Verifying Start-GUI function"
if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
    Write-Host "  [OK] Start-GUI function found" -ForegroundColor Green
    $log += "  [OK] Start-GUI function found"
} else {
    Write-Host "  [ERROR] Start-GUI function not found" -ForegroundColor Red
    $log += "  [ERROR] Start-GUI function not found"
    $hasErrors = $true
    $errorCount++
}

# Test 5: Check for unhandled errors
Write-Host ""
Write-Host "TEST 5: Checking for runtime errors..." -ForegroundColor Yellow
$log += ""
$log += "TEST 5: Checking for runtime errors"

$errorAfter = $global:Error.Count
$runtimeErrors = $errorAfter - $errorBefore

if ($runtimeErrors -gt 0) {
    Write-Host "  [ERROR] $runtimeErrors error(s) detected during execution:" -ForegroundColor Red
    $log += "  [ERROR] $runtimeErrors error(s) detected during execution:"
    
    $global:Error | Select-Object -First $runtimeErrors | ForEach-Object {
        Write-Host "    - $($_.Exception.Message)" -ForegroundColor Red
        $log += "    - $($_.Exception.Message)"
    }
    $hasErrors = $true
} else {
    Write-Host "  [OK] No runtime errors detected" -ForegroundColor Green
    $log += "  [OK] No runtime errors detected"
}

# Final verdict
$log += ""
$log += "=== FINAL RESULT ==="
$log += "Total Errors: $errorCount"
$log += "End: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$log | Out-File $OutputPath -Force

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan

if ($hasErrors) {
    Write-Host "[FAIL] STRICT TEST FAILED - ERRORS DETECTED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Total Errors: $errorCount" -ForegroundColor Red
    Write-Host ""
    Write-Host "Log saved to: $OutputPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "DO NOT DEPLOY - Fix all errors before proceeding" -ForegroundColor Red
    exit 1
} else {
    Write-Host "[PASS] STRICT TEST PASSED - NO ERRORS" -ForegroundColor Green
    Write-Host ""
    Write-Host "Log saved to: $OutputPath" -ForegroundColor Gray
    exit 0
}
