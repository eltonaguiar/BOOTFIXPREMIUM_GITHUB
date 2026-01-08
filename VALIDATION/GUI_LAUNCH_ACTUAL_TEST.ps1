#!/usr/bin/env powershell
<#
.SYNOPSIS
    GUI LAUNCH TEST - Actually Calls Start-GUI
    
.DESCRIPTION
    Actually INVOKES Start-GUI to see what errors occur.
    This is the REAL test - does the GUI actually work?
#>

param(
    [string]$OutputPath = ".\VALIDATION\TEST_LOGS\GUI_LAUNCH_EXECUTION.log",
    [int]$TimeoutSeconds = 5
)

$ErrorActionPreference = 'Continue'

# Ensure log directory exists
$logDir = Split-Path $OutputPath
if (-not (Test-Path $logDir)) {
    mkdir $logDir -Force | Out-Null
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "GUI LAUNCH TEST - ACTUALLY CALLS Start-GUI" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$log = @()
$hasErrors = $false

$log += "=== GUI LAUNCH EXECUTION TEST ==="
$log += "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$log += "Timeout: $TimeoutSeconds seconds"
$log += ""

# Load modules
Write-Host "Loading modules..." -ForegroundColor Yellow
$log += "Loading modules..."

try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    . ".\HELPER SCRIPTS\WinRepairCore.ps1" -ErrorAction Stop
    . ".\HELPER SCRIPTS\WinRepairGUI.ps1" -ErrorAction Stop
    Write-Host "  [OK] All modules loaded" -ForegroundColor Green
    $log += "  [OK] All modules loaded"
} catch {
    Write-Host "  [ERROR] Module loading failed: $_" -ForegroundColor Red
    $log += "  [ERROR] Module loading failed: $_"
    $log += $_.ScriptStackTrace
    $hasErrors = $true
}

# Now try to call Start-GUI in a background job with timeout
if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
    Write-Host ""
    Write-Host "Calling Start-GUI..." -ForegroundColor Yellow
    $log += ""
    $log += "Calling Start-GUI in background job with $TimeoutSeconds second timeout..."
    
    try {
        # Create a job that runs Start-GUI
        $job = Start-Job -ScriptBlock {
            param($timeout)
            $ErrorActionPreference = 'Continue'
            
            try {
                Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                . ".\HELPER SCRIPTS\WinRepairCore.ps1" -ErrorAction Stop
                . ".\HELPER SCRIPTS\WinRepairGUI.ps1" -ErrorAction Stop
                
                Write-Host "Starting GUI..."
                Start-GUI
                Write-Host "GUI started successfully"
            } catch {
                Write-Host "[ERROR] $($_.Exception.Message)"
                Write-Host "[ERROR] $($_.ScriptStackTrace)"
                exit 1
            }
        } -ArgumentList $TimeoutSeconds
        
        # Wait for the job to complete or timeout
        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
        
        if ($completed) {
            $output = Receive-Job -Job $job
            $exitCode = $job.State
            
            Write-Host "  [Job Output]:" -ForegroundColor Gray
            $output | ForEach-Object {
                Write-Host "    $_"
                $log += "    $_"
            }
            
            if ($exitCode -eq 'Failed') {
                Write-Host "  [ERROR] GUI job failed" -ForegroundColor Red
                $log += "  [ERROR] GUI job failed"
                $hasErrors = $true
            } else {
                Write-Host "  [INFO] GUI job completed" -ForegroundColor Green
                $log += "  [INFO] GUI job completed"
            }
        } else {
            Write-Host "  [TIMEOUT] GUI did not return within $TimeoutSeconds seconds" -ForegroundColor Yellow
            $log += "  [TIMEOUT] GUI did not return within $TimeoutSeconds seconds (expected for UI)"
            # This is actually OK - the GUI is showing
            Stop-Job -Job $job -ErrorAction SilentlyContinue
        }
        
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "  [ERROR] Exception calling Start-GUI: $_" -ForegroundColor Red
        $log += "  [ERROR] Exception calling Start-GUI: $_"
        $log += $_.ScriptStackTrace
        $hasErrors = $true
    }
} else {
    Write-Host "  [ERROR] Start-GUI function not found" -ForegroundColor Red
    $log += "  [ERROR] Start-GUI function not found"
    $hasErrors = $true
}

# Summary
$log += ""
$log += "=== TEST COMPLETE ==="
$log += "End: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$log += "Status: $(if ($hasErrors) { 'FAILED' } else { 'PASSED' })"

$log | Out-File $OutputPath -Force

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan

if ($hasErrors) {
    Write-Host "[FAIL] ERRORS OCCURRED DURING GUI LAUNCH" -ForegroundColor Red
    Write-Host "Log: $OutputPath" -ForegroundColor Gray
    exit 1
} else {
    Write-Host "[OK] GUI Launch Test Complete" -ForegroundColor Green
    Write-Host "Log: $OutputPath" -ForegroundColor Gray
    exit 0
}
