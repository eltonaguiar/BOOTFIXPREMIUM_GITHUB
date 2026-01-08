@echo off
REM MiracleBoot v7.2 - Admin Test Command
REM Copy and paste this into a PowerShell window run as Administrator
REM
REM This runs:
REM 1. Pre-flight verification (gates pre-UI checks)
REM 2. MiracleBoot.ps1 (main script)
REM 3. Captures output to log

powershell -NoProfile -ExecutionPolicy Bypass -Command "
Set-Location 'c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code'

Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'MiracleBoot v7.2 - Admin Test Sequence' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

Write-Host 'STEP 1: Pre-Flight Verification' -ForegroundColor Yellow
Write-Host '(19 automated checks for pre-UI viability)' -ForegroundColor Gray
Write-Host ''

. .\HARDENED_PRE_FLIGHT_VERIFICATION.ps1 -Verbose

if (\$LASTEXITCODE -eq 0) {
    Write-Host ''
    Write-Host 'STEP 2: Pre-Flight PASSED - Proceeding to Main Script' -ForegroundColor Green
    Write-Host ''
    
    Write-Host 'STEP 2: Launching MiracleBoot.ps1' -ForegroundColor Yellow
    Write-Host '(This will attempt to launch the GUI)' -ForegroundColor Gray
    Write-Host ''
    
    . .\MiracleBoot.ps1
} else {
    Write-Host ''
    Write-Host 'STEP 2: Pre-Flight FAILED' -ForegroundColor Red
    Write-Host 'Code has critical failures and is NOT ready for testing' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Review LOGS\PREFLIGHT_*.log for details' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}
"

pause
