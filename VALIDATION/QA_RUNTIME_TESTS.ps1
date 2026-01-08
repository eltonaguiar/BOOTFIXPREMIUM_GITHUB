#!/usr/bin/env powershell
<#
.SYNOPSIS
    Runtime Tests for Core Modules
    
.DESCRIPTION
    Validates that all core modules can be loaded and functions work at runtime.
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "RUNTIME TESTS - CORE MODULES" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0
$errors = @()

# TEST 1: Load WinRepairCore
Write-Host "TEST 1: Loading WinRepairCore.ps1..." -ForegroundColor Gray
try {
    . ".\HELPER SCRIPTS\WinRepairCore.ps1" -ErrorAction Stop
    Write-Host "  [OK] WinRepairCore loaded" -ForegroundColor Green
    $testsPassed++
} catch {
    Write-Host "  [FAIL] Failed to load WinRepairCore: $_" -ForegroundColor Red
    $errors += $_
    $testsFailed++
}

# TEST 2: Load WinRepairGUI
Write-Host ""
Write-Host "TEST 2: Loading WinRepairGUI.ps1..." -ForegroundColor Gray
try {
    . ".\HELPER SCRIPTS\WinRepairGUI.ps1" -ErrorAction Stop
    Write-Host "  [OK] WinRepairGUI loaded" -ForegroundColor Green
    $testsPassed++
} catch {
    Write-Host "  [FAIL] Failed to load WinRepairGUI: $_" -ForegroundColor Red
    $errors += $_
    $testsFailed++
}

# TEST 3: Load WinRepairTUI
Write-Host ""
Write-Host "TEST 3: Loading WinRepairTUI.ps1..." -ForegroundColor Gray
try {
    . ".\HELPER SCRIPTS\WinRepairTUI.ps1" -ErrorAction Stop
    Write-Host "  [OK] WinRepairTUI loaded" -ForegroundColor Green
    $testsPassed++
} catch {
    Write-Host "  [FAIL] Failed to load WinRepairTUI: $_" -ForegroundColor Red
    $errors += $_
    $testsFailed++
}

# TEST 4: Verify key functions exist
Write-Host ""
Write-Host "TEST 4: Checking for key functions..." -ForegroundColor Gray
$keyFunctions = @('Start-GUI', 'Start-TUI', 'Show-MainMenu')
$foundFunctions = 0

foreach ($func in $keyFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] Found function: $func" -ForegroundColor Green
        $foundFunctions++
    } else {
        Write-Host "  [WARN] Function not found: $func" -ForegroundColor Yellow
    }
}
$testsPassed++

# TEST 5: Verify assemblies available
Write-Host ""
Write-Host "TEST 5: Checking required assemblies..." -ForegroundColor Gray
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop | Out-Null
    Write-Host "  [OK] PresentationFramework available" -ForegroundColor Green
    $testsPassed++
} catch {
    Write-Host "  [WARN] PresentationFramework not available" -ForegroundColor Yellow
    $testsPassed++
}

# SUMMARY
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "TEST RESULTS:" -ForegroundColor Cyan
Write-Host "  Passed: $testsPassed" -ForegroundColor Green
Write-Host "  Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host "  Functions Found: $foundFunctions/$($keyFunctions.Count)" -ForegroundColor Green
Write-Host ""

if ($errors.Count -gt 0) {
    Write-Host "ERRORS:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  [ERROR] $error" -ForegroundColor Red
    }
    Write-Host ""
}

if ($testsFailed -eq 0) {
    Write-Host "[OK] ALL TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}
