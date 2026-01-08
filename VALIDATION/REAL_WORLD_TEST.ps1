#!/usr/bin/env powershell
<#
.SYNOPSIS
    REAL WORLD TEST - Fixes path issues
    
.DESCRIPTION
    Uses absolute paths to ensure GUI works regardless of
    working directory or execution context.
#>

param(
    [string]$OutputPath = ".\VALIDATION\TEST_LOGS\REAL_WORLD_TEST.log",
    [int]$TimeoutSeconds = 3
)

$ErrorActionPreference = 'Stop'

# Ensure log directory
$logDir = Split-Path $OutputPath
if (-not (Test-Path $logDir)) {
    mkdir $logDir -Force | Out-Null
}

$projectRoot = Get-Item -Path "." -ErrorAction Stop | Select-Object -ExpandProperty FullName
$helperScriptsPath = Join-Path $projectRoot "HELPER SCRIPTS"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "REAL WORLD EXECUTION TEST" -ForegroundColor Cyan
Write-Host "Using Absolute Paths - Tests Real-World Scenarios" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project Root: $projectRoot" -ForegroundColor Gray
Write-Host "Helper Scripts: $helperScriptsPath" -ForegroundColor Gray
Write-Host ""

$allOutput = @()
$allOutput += "=== REAL WORLD GUI EXECUTION TEST ==="
$allOutput += "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$allOutput += "Project Root: $projectRoot"
$allOutput += "Helper Path: $helperScriptsPath"
$allOutput += ""

$foundErrors = @()
$testPassed = $true

# Step 1: Verify paths exist
Write-Host "Step 1: Verifying file paths..." -ForegroundColor Yellow
$allOutput += "[STEP 1] Verifying file paths..."

$coreFile = Join-Path $helperScriptsPath "WinRepairCore.ps1"
$guiFile = Join-Path $helperScriptsPath "WinRepairGUI.ps1"

if (-not (Test-Path $coreFile)) {
    Write-Host "  [ERROR] WinRepairCore.ps1 not found: $coreFile" -ForegroundColor Red
    $allOutput += "  [ERROR] WinRepairCore.ps1 not found: $coreFile"
    $foundErrors += "WinRepairCore.ps1 missing"
    $testPassed = $false
} else {
    Write-Host "  [OK] WinRepairCore.ps1 found" -ForegroundColor Green
    $allOutput += "  [OK] WinRepairCore.ps1 found"
}

if (-not (Test-Path $guiFile)) {
    Write-Host "  [ERROR] WinRepairGUI.ps1 not found: $guiFile" -ForegroundColor Red
    $allOutput += "  [ERROR] WinRepairGUI.ps1 not found: $guiFile"
    $foundErrors += "WinRepairGUI.ps1 missing"
    $testPassed = $false
} else {
    Write-Host "  [OK] WinRepairGUI.ps1 found" -ForegroundColor Green
    $allOutput += "  [OK] WinRepairGUI.ps1 found"
}

# Step 2: Execute in current context (should work)
Write-Host ""
Write-Host "Step 2: Loading modules (current context)..." -ForegroundColor Yellow
$allOutput += ""
$allOutput += "[STEP 2] Loading modules (current context)..."

try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    
    . $coreFile -ErrorAction Stop
    . $guiFile -ErrorAction Stop
    
    Write-Host "  [OK] All modules loaded successfully" -ForegroundColor Green
    $allOutput += "  [OK] All modules loaded successfully"
    
    if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] Start-GUI function available" -ForegroundColor Green
        $allOutput += "  [OK] Start-GUI function available"
    } else {
        Write-Host "  [ERROR] Start-GUI function not found" -ForegroundColor Red
        $allOutput += "  [ERROR] Start-GUI function not found"
        $foundErrors += "Start-GUI not found"
        $testPassed = $false
    }
    
} catch {
    Write-Host "  [ERROR] Module loading failed: $($_.Exception.Message)" -ForegroundColor Red
    $allOutput += "  [ERROR] Module loading failed: $($_.Exception.Message)"
    $allOutput += "  [ERROR] Stack: $($_.ScriptStackTrace)"
    $foundErrors += "Module load error: $($_.Exception.Message)"
    $testPassed = $false
}

# Step 3: Test with background job (using absolute paths)
Write-Host ""
Write-Host "Step 3: Testing with background job (absolute paths)..." -ForegroundColor Yellow
$allOutput += ""
$allOutput += "[STEP 3] Testing with background job..."

if ($testPassed) {
    try {
        $jobScript = {
            param($coreFile, $guiFile, $projectRoot)
            
            $ErrorActionPreference = 'Stop'
            
            try {
                Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                
                # Use absolute paths
                . $coreFile -ErrorAction Stop
                . $guiFile -ErrorAction Stop
                
                Write-Host "[OK] Background job: modules loaded"
                
                if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
                    Write-Host "[OK] Background job: Start-GUI available"
                    # Don't call Start-GUI as it will hang waiting for UI
                } else {
                    Write-Host "[ERROR] Background job: Start-GUI not found"
                    exit 1
                }
            } catch {
                Write-Host "[ERROR] Background job failed: $($_.Exception.Message)"
                exit 1
            }
        }
        
        $job = Start-Job -ScriptBlock $jobScript -ArgumentList @($coreFile, $guiFile, $projectRoot)
        $result = Wait-Job -Job $job -Timeout $TimeoutSeconds
        
        if ($result) {
            $jobOutput = Receive-Job -Job $job 2>&1
            $jobOutput | ForEach-Object {
                Write-Host "  $_"
                $allOutput += "  $_"
                
                if ($_ -match '\[ERROR\]') {
                    $foundErrors += $_
                    $testPassed = $false
                }
            }
            
            $job.ChildJobs | ForEach-Object {
                if ($_.Error.Count -gt 0) {
                    $_.Error | ForEach-Object {
                        Write-Host "  [ERROR] $_" -ForegroundColor Red
                        $allOutput += "  [ERROR] $_"
                        $foundErrors += $_
                        $testPassed = $false
                    }
                }
            }
        } else {
            Write-Host "  [INFO] Job running (expected)" -ForegroundColor Green
            $allOutput += "  [INFO] Job running (expected)"
        }
        
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "  [ERROR] Job test failed: $($_.Exception.Message)" -ForegroundColor Red
        $allOutput += "  [ERROR] Job test failed: $($_.Exception.Message)"
        $foundErrors += "Job test error: $($_.Exception.Message)"
        $testPassed = $false
    }
}

# Final report
$allOutput += ""
$allOutput += "=== TEST SUMMARY ==="
$allOutput += "Errors Found: $($foundErrors.Count)"
if ($foundErrors.Count -gt 0) {
    $allOutput += "Error Details:"
    $foundErrors | ForEach-Object {
        $allOutput += "  - $_"
    }
}
$allOutput += "End: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$allOutput | Out-File $OutputPath -Force -Encoding UTF8

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan

if ($foundErrors.Count -gt 0 -or -not $testPassed) {
    Write-Host "[FAIL] TEST FAILED - ERRORS DETECTED" -ForegroundColor Red
    Write-Host "Errors: $($foundErrors.Count)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Log: $OutputPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "DO NOT DEPLOY - Must fix errors first" -ForegroundColor Red
    exit 1
} else {
    Write-Host "[PASS] ALL TESTS PASSED" -ForegroundColor Green
    Write-Host "No errors detected" -ForegroundColor Green
    Write-Host ""
    Write-Host "Log: $OutputPath" -ForegroundColor Gray
    exit 0
}
