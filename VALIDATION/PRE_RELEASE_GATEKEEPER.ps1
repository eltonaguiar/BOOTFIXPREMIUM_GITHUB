#!/usr/bin/env powershell
<#
.SYNOPSIS
    Pre-Release Gatekeeper - Mandatory validation before code can leave development phase
    
.DESCRIPTION
    This script enforces that SUPER_TEST_MANDATORY.ps1 must PASS before any modifications
    can be committed or deployed. Acts as the primary gatekeeper for code quality.
    
.PARAMETER AllowWarnings
    If $true, allows code to proceed with warnings. Default: $false (fails on any warning)
    
.PARAMETER AutoFix
    If $true, attempts automatic fixes for common issues. Default: $false
#>

param(
    [bool]$AllowWarnings = $false,
    [bool]$AutoFix = $false
)

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  MIRACLEBOOT PRE-RELEASE GATEKEEPER v1.0                   ║" -ForegroundColor Cyan
Write-Host "║  Mandatory Testing Before Code Release                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$superTestPath = Join-Path $scriptDir "SUPER_TEST_MANDATORY.ps1"

if (-not (Test-Path $superTestPath)) {
    Write-Host "ERROR: SUPER_TEST_MANDATORY.ps1 not found at: $superTestPath" -ForegroundColor Red
    Write-Host "Cannot proceed without mandatory test suite." -ForegroundColor Red
    exit 1
}

Write-Host "Starting Mandatory Test Suite..." -ForegroundColor Yellow
Write-Host "Test Script: $superTestPath" -ForegroundColor Gray
Write-Host ""

# Run the super test
$testArgs = @()
if ($AllowWarnings) {
    $testArgs += "-Strict", "`$false"
}

try {
    & $superTestPath @testArgs
    $testExitCode = $LASTEXITCODE
} catch {
    Write-Host "ERROR executing test suite: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan

if ($testExitCode -eq 0) {
    Write-Host "║  [PASSED] TEST PASSED - CODE IS READY FOR RELEASE          ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Your code has successfully passed all mandatory validation checks." -ForegroundColor Green
    Write-Host "You may proceed with deployment/release." -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "║  [FAILED] TEST FAILED - CODE CANNOT BE RELEASED            ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "Your code has FAILED mandatory validation checks." -ForegroundColor Red
    Write-Host "Fix all reported errors before attempting release." -ForegroundColor Red
    Write-Host ""
    Write-Host "Recent test logs are in: TEST_LOGS/" -ForegroundColor Yellow
    Write-Host "Review the error logs to identify and fix issues." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
