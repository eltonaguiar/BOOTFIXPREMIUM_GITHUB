# MiracleBoot v7.2 - Direct Admin PowerShell Test Command
# 
# INSTRUCTIONS:
# 1. Open PowerShell AS ADMINISTRATOR
# 2. Copy and paste the entire command below
# 3. Press Enter
# 4. Watch as pre-flight verification runs, then the main script launches
#
# ============================================================================

Set-Location 'c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code'

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      MiracleBoot v7.2 - Admin Test Sequence                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "STEP 1: Pre-Flight Verification" -ForegroundColor Yellow
Write-Host "(Running 19 automated checks for pre-UI viability)" -ForegroundColor Gray
Write-Host ""

. .\HARDENED_PRE_FLIGHT_VERIFICATION.ps1 -Verbose

Write-Host ""

if ($LASTEXITCODE -eq 0) {
    Write-Host "STEP 1: PRE-FLIGHT VERIFICATION PASSED" -ForegroundColor Green
    Write-Host "Status: Code is ready for testing" -ForegroundColor Green
    Write-Host ""
    Write-Host "STEP 2: Launching MiracleBoot.ps1" -ForegroundColor Yellow
    Write-Host "(Main script is about to launch)" -ForegroundColor Gray
    Write-Host ""
    
    . .\MiracleBoot.ps1
    
    Write-Host ""
    Write-Host "Test Complete!" -ForegroundColor Green
} else {
    Write-Host "STEP 1: PRE-FLIGHT VERIFICATION FAILED" -ForegroundColor Red
    Write-Host "Status: Code has critical failures" -ForegroundColor Red
    Write-Host ""
    Write-Host "The code is NOT ready for testing." -ForegroundColor Red
    Write-Host "Review the failures above and fix before trying again." -ForegroundColor Red
    Write-Host ""
    Write-Host "Log file: LOGS\PREFLIGHT_*.log" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
