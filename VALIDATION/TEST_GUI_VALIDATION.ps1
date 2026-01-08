#!/usr/bin/env powershell
<#
.SYNOPSIS
    GUI Validation Test
    
.DESCRIPTION
    Validates the GUI can be loaded and functions as expected.
#>

param(
    [string]$GUIPath = ".\HELPER SCRIPTS\WinRepairGUI.ps1",
    [string]$ReportPath = ".\VALIDATION\TEST_LOGS\GUI_VALIDATION_REPORT.txt"
)

$ErrorActionPreference = 'Continue'
$report = @()
$issues = @()

$report += "GUI VALIDATION TEST REPORT"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += ""

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "GUI VALIDATION TEST" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Check file exists
if (-not (Test-Path $GUIPath)) {
    $report += "[FAIL] GUI file not found: $GUIPath"
    $issues += "GUI file missing"
    Write-Host "[FAIL] GUI file not found" -ForegroundColor Red
} else {
    $report += "[OK] GUI file found"
    Write-Host "[OK] GUI file found" -ForegroundColor Green
    
    # Check file size
    $file = Get-Item $GUIPath
    $sizeKB = [math]::Round($file.Length / 1KB, 2)
    $report += "[OK] File size: $sizeKB KB"
    Write-Host "[OK] File size: $sizeKB KB" -ForegroundColor Green
    
    # Try to load GUI
    Write-Host "[TEST] Attempting to load GUI..." -ForegroundColor Yellow
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop | Out-Null
        . $GUIPath -ErrorAction Stop
        
        if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
            $report += "[OK] GUI loaded successfully"
            Write-Host "[OK] GUI loaded successfully" -ForegroundColor Green
        } else {
            $report += "[WARN] Start-GUI function not found"
            $issues += "Start-GUI function missing"
            Write-Host "[WARN] Start-GUI function not found" -ForegroundColor Yellow
        }
    } catch {
        $report += "[FAIL] Error loading GUI: $_"
        $issues += "GUI load error: $_"
        Write-Host "[FAIL] Error loading GUI: $_" -ForegroundColor Red
    }
}

$report += ""
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Save report
if (-not (Test-Path (Split-Path $ReportPath))) {
    mkdir -Path (Split-Path $ReportPath) -Force | Out-Null
}

Set-Content -Path $ReportPath -Value ($report -join "`n") -Force
Write-Host ""
Write-Host "Report saved to: $ReportPath" -ForegroundColor Cyan
Write-Host ""

exit $(if ($issues.Count -eq 0) { 0 } else { 1 })
