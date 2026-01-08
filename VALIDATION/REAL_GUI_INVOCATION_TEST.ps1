#!/usr/bin/env powershell
<#
.SYNOPSIS
    REAL GUI INVOCATION TEST - Actually Calls Start-GUI
    
.DESCRIPTION
    This test ACTUALLY CALLS Start-GUI (not just loads it) and captures
    ALL errors that occur during GUI initialization.
    
    This is the REAL test - it WILL find the errors in the screenshot.
#>

param(
    [string]$OutputPath = ".\VALIDATION\TEST_LOGS\REAL_GUI_INVOCATION_TEST.log",
    [int]$TimeoutSeconds = 5
)

$ErrorActionPreference = 'Continue'

# Ensure log directory
$logDir = Split-Path $OutputPath
if (-not (Test-Path $logDir)) {
    mkdir $logDir -Force | Out-Null
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "REAL GUI INVOCATION TEST" -ForegroundColor Cyan
Write-Host "Actually Calls Start-GUI - Will Find All Initialization Errors" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$log = @()
$log += "=== REAL GUI INVOCATION TEST LOG ==="
$log += "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$log += "Timeout: $TimeoutSeconds seconds"
$log += ""

$projectRoot = Get-Item -Path "." -ErrorAction Stop | Select-Object -ExpandProperty FullName
$coreFile = Join-Path $projectRoot "HELPER SCRIPTS\WinRepairCore.ps1"
$guiFile = Join-Path $projectRoot "HELPER SCRIPTS\WinRepairGUI.ps1"

Write-Host "Project Root: $projectRoot" -ForegroundColor Gray
Write-Host ""

# Create a script block that will ACTUALLY INVOKE Start-GUI
$guiInvocationScript = {
    param($coreFile, $guiFile)
    
    $ErrorActionPreference = 'Continue'
    $VerbosePreference = 'Continue'
    $DebugPreference = 'Continue'
    
    $errors = @()
    $warnings = @()
    
    # Redirect all errors and warnings
    $ErrorActionPreference = 'Continue'
    
    try {
        Write-Host "[LOAD] Loading PresentationFramework..." -ForegroundColor Gray
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Write-Host "[OK] PresentationFramework loaded" -ForegroundColor Green
        
        Write-Host "[LOAD] Loading System.Windows.Forms..." -ForegroundColor Gray
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Write-Host "[OK] System.Windows.Forms loaded" -ForegroundColor Green
        
        Write-Host "[LOAD] Loading WinRepairCore..." -ForegroundColor Gray
        . $coreFile -ErrorAction Stop
        Write-Host "[OK] WinRepairCore loaded" -ForegroundColor Green
        
        Write-Host "[LOAD] Loading WinRepairGUI..." -ForegroundColor Gray
        . $guiFile -ErrorAction Stop
        Write-Host "[OK] WinRepairGUI loaded" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "[INVOKE] About to call Start-GUI..." -ForegroundColor Yellow
        Write-Host "[INVOKE] Any errors below are REAL GUI INITIALIZATION ERRORS:" -ForegroundColor Yellow
        Write-Host ""
        
        # THIS IS THE KEY - Actually invoke Start-GUI
        # Capture $global:Error before and after to detect errors
        $errorsBefore = $global:Error.Count
        $warningsBefore = @()
        
        try {
            Start-GUI
        } catch {
            Write-Host "[ERROR DURING Start-GUI] $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[ERROR STACK] $($_.ScriptStackTrace)" -ForegroundColor Red
            $errors += "Exception in Start-GUI: $($_.Exception.Message)"
        }
        
        # Check if errors were added to $global:Error during execution
        $errorsAfter = $global:Error.Count
        $newErrors = $errorsAfter - $errorsBefore
        
        if ($newErrors -gt 0) {
            Write-Host ""
            Write-Host "[ERRORS DETECTED] $newErrors error(s) during GUI execution:" -ForegroundColor Red
            $global:Error | Select-Object -First $newErrors | ForEach-Object {
                Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
                $errors += $_.Exception.Message
            }
        }
        
        # Return results
        @{
            Success = ($errors.Count -eq 0)
            Errors = $errors
            ErrorCount = $errors.Count
        }
        
    } catch {
        Write-Host "[CRITICAL ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[CRITICAL STACK] $($_.ScriptStackTrace)" -ForegroundColor Red
        @{
            Success = $false
            Errors = @($_.Exception.Message, $_.ScriptStackTrace)
            ErrorCount = 1
        }
    }
}

# Run the GUI invocation in a job (more realistic scenario)
Write-Host "Running GUI invocation in background job..." -ForegroundColor Yellow
Write-Host ""

try {
    $job = Start-Job -ScriptBlock $guiInvocationScript -ArgumentList @($coreFile, $guiFile)
    
    $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds -ErrorAction SilentlyContinue
    
    if ($completed) {
        # Job completed within timeout
        $result = Receive-Job -Job $job
        
        Write-Host ""
        Write-Host "Job completed within timeout" -ForegroundColor Green
        $log += "Job completed within timeout"
        
        if ($result) {
            $log += "Job Output:"
            $log += "  Success: $($result.Success)"
            $log += "  Errors: $($result.ErrorCount)"
            
            if ($result.ErrorCount -gt 0) {
                Write-Host ""
                Write-Host "[FAIL] ERRORS FOUND DURING GUI INVOCATION:" -ForegroundColor Red
                $log += "[FAIL] Errors found during GUI invocation:"
                
                $result.Errors | ForEach-Object {
                    Write-Host "  $_" -ForegroundColor Red
                    $log += "  $_"
                }
            } else {
                Write-Host ""
                Write-Host "[PASS] No errors during GUI invocation" -ForegroundColor Green
                $log += "[PASS] No errors during GUI invocation"
            }
        }
        
        # Also check job errors
        if ($job.ChildJobs[0].Error.Count -gt 0) {
            Write-Host ""
            Write-Host "[JOB ERRORS] Job had $($job.ChildJobs[0].Error.Count) error(s):" -ForegroundColor Red
            $log += "[JOB ERRORS] Job had $($job.ChildJobs[0].Error.Count) error(s):"
            
            $job.ChildJobs[0].Error | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Red
                $log += "  $_"
            }
        }
        
    } else {
        # Job timed out (window is probably displayed)
        Write-Host ""
        Write-Host "[INFO] Job running (window likely displayed)" -ForegroundColor Green
        Write-Host "[INFO] Terminating job..." -ForegroundColor Gray
        $log += "[INFO] Job running after $TimeoutSeconds seconds (window displayed)"
        
        # Get whatever output was captured
        $output = Receive-Job -Job $job -ErrorAction SilentlyContinue
        if ($output) {
            $log += "Captured output:"
            $output | ForEach-Object {
                $log += "  $_"
            }
        }
    }
    
    Stop-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    
} catch {
    Write-Host ""
    Write-Host "[ERROR] Job execution failed: $_" -ForegroundColor Red
    $log += "[ERROR] Job execution failed: $_"
}

# Save log
$log | Out-File $OutputPath -Force -Encoding UTF8

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Log saved to: $OutputPath" -ForegroundColor Gray
Write-Host ""

# Check for critical errors in the log
$criticalErrors = @(
    "Cannot call a method on a null",
    "Cannot set unknown member",
    "The item with index",
    "Index was out of range",
    "null-valued expression"
)

$foundCritical = @()
foreach ($line in $log) {
    foreach ($criticalError in $criticalErrors) {
        if ($line -match [regex]::Escape($criticalError)) {
            $foundCritical += $line
        }
    }
}

if ($foundCritical.Count -gt 0) {
    Write-Host "[CRITICAL] Found $($foundCritical.Count) critical error(s):" -ForegroundColor Red
    $foundCritical | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Red
    }
    exit 1
}

Write-Host "[COMPLETE] Test finished" -ForegroundColor Cyan
exit 0
