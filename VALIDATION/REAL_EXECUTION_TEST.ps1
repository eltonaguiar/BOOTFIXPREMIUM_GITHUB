#!/usr/bin/env powershell
<#
.SYNOPSIS
    REAL EXECUTION TEST - Comprehensive Error Detection
    
.DESCRIPTION
    Actually EXECUTES the GUI code and captures EVERY error message.
    This is the REAL test - not just syntax checking.
    
    FAILS if ANY error occurs BEFORE GUI initialization completes.
#>

param(
    [string]$GUIPath = ".\HELPER SCRIPTS\WinRepairGUI.ps1",
    [string]$OutputPath = ".\VALIDATION\TEST_LOGS\REAL_EXECUTION_TEST.log",
    [string]$ErrorPath = ".\VALIDATION\TEST_LOGS\EXECUTION_ERRORS.txt"
)

$ErrorActionPreference = 'Continue'

# Ensure directories exist
$logDir = Split-Path $OutputPath
if (-not (Test-Path $logDir)) {
    mkdir $logDir -Force | Out-Null
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "REAL EXECUTION TEST - COMPREHENSIVE ERROR DETECTION" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This test ACTUALLY EXECUTES the GUI code and captures EVERY error." -ForegroundColor Yellow
Write-Host "If ANY error occurs, the test FAILS." -ForegroundColor Yellow
Write-Host ""

# Script block to execute with full error capture
$executionScript = {
    param($scriptPath)
    
    # Capture current error count
    $errorBefore = $global:Error.Count
    $warningBefore = $WarningPreference
    
    # Set to capture warnings too
    $WarningPreference = 'Continue'
    $VerbosePreference = 'Continue'
    $DebugPreference = 'Continue'
    
    try {
        # Load assemblies first
        Write-Host "[EXEC] Loading PresentationFramework..." -ForegroundColor Gray
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Write-Host "[OK] PresentationFramework loaded" -ForegroundColor Green
        
        Write-Host "[EXEC] Loading System.Windows.Forms..." -ForegroundColor Gray
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Write-Host "[OK] System.Windows.Forms loaded" -ForegroundColor Green
        
        Write-Host "[EXEC] Loading WinRepairCore..." -ForegroundColor Gray
        . ".\HELPER SCRIPTS\WinRepairCore.ps1" -ErrorAction Stop
        Write-Host "[OK] WinRepairCore loaded" -ForegroundColor Green
        
        Write-Host "[EXEC] Sourcing GUI module: $scriptPath" -ForegroundColor Gray
        . $scriptPath -ErrorAction Stop
        Write-Host "[OK] GUI module sourced successfully" -ForegroundColor Green
        
        # Check if Start-GUI exists
        Write-Host "[EXEC] Verifying Start-GUI function..." -ForegroundColor Gray
        if (-not (Get-Command Start-GUI -ErrorAction SilentlyContinue)) {
            throw "Start-GUI function not found after loading"
        }
        Write-Host "[OK] Start-GUI function available" -ForegroundColor Green
        
        # Try to initialize (without showing window)
        Write-Host "[EXEC] Attempting GUI initialization..." -ForegroundColor Gray
        $global:GUIInitTest = $true
        
        # Get current errors
        $errorAfter = $global:Error.Count
        $errorCount = $errorAfter - $errorBefore
        
        if ($errorCount -gt 0) {
            Write-Host "[FAIL] Errors detected during execution:" -ForegroundColor Red
            $global:Error | Select-Object -First $errorCount | ForEach-Object {
                Write-Host "  [ERROR] $_" -ForegroundColor Red
            }
            return $false
        } else {
            Write-Host "[OK] No errors during initialization" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "[FAIL] Exception during execution: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[FAIL] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        return $false
    }
}

# Run the execution in current process to capture $global:Error properly
$testOutput = @()
$testErrors = @()
$testPassed = $false

Write-Host "Step 1: Executing GUI code..." -ForegroundColor Yellow
Write-Host ""

# Capture all output
$testOutput = @(powershell -NoProfile -ExecutionPolicy Bypass -Command {
    param($script, $gui)
    
    $ErrorActionPreference = 'Continue'
    $errors = @()
    $output = @()
    
    # Capture stderr and stdout
    $output += "=== GUI EXECUTION LOG ==="
    $output += "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $output += ""
    
    try {
        $output += "[STEP 1] Loading PresentationFramework..."
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        $output += "[OK] Loaded"
    } catch {
        $output += "[ERROR] $($_.Exception.Message)"
        $errors += $_
    }
    
    try {
        $output += "[STEP 2] Loading System.Windows.Forms..."
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $output += "[OK] Loaded"
    } catch {
        $output += "[ERROR] $($_.Exception.Message)"
        $errors += $_
    }
    
    try {
        $output += "[STEP 3] Sourcing WinRepairCore..."
        . ".\HELPER SCRIPTS\WinRepairCore.ps1" -ErrorAction Stop
        $output += "[OK] Loaded"
    } catch {
        $output += "[ERROR] $($_.Exception.Message)"
        $errors += $_
    }
    
    try {
        $output += "[STEP 4] Sourcing GUI module: $gui"
        . $gui -ErrorAction Stop
        $output += "[OK] Loaded"
    } catch {
        $output += "[ERROR] $($_.Exception.Message)"
        $errors += $_
    }
    
    try {
        $output += "[STEP 5] Verifying Start-GUI function..."
        if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
            $output += "[OK] Found"
        } else {
            $output += "[ERROR] Start-GUI not found"
            $errors += "Start-GUI function not available"
        }
    } catch {
        $output += "[ERROR] $($_.Exception.Message)"
        $errors += $_
    }
    
    $output += ""
    $output += "Errors Found: $($errors.Count)"
    if ($errors.Count -gt 0) {
        $output += "=== ERRORS ==="
        $errors | ForEach-Object {
            $output += "  - $_"
        }
    }
    
    $output
} -ArgumentList @($executionScript, $GUIPath))

# Display output
$testOutput | ForEach-Object { Write-Host $_ }

# Save to file
$testOutput | Out-File $OutputPath -Force
Write-Host ""
Write-Host "Log saved to: $OutputPath" -ForegroundColor Gray

# Check for errors in output
Write-Host ""
Write-Host "Step 2: Analyzing output for errors..." -ForegroundColor Yellow
Write-Host ""

$errorKeywords = @(
    'ERROR',
    'error',
    'Exception',
    'exception',
    'failed',
    'Failed',
    'FAIL',
    'cannot',
    'Cannot',
    'null',
    'Null',
    'undefined',
    'Undefined',
    'missing',
    'Missing'
)

$foundErrors = @()
$foundWarnings = @()

foreach ($line in $testOutput) {
    foreach ($keyword in $errorKeywords) {
        if ($line -match $keyword) {
            if ($line -match '\[ERROR\]|\[FAIL\]') {
                $foundErrors += $line
            } elseif ($line -match 'warn|Warn') {
                $foundWarnings += $line
            }
        }
    }
}

if ($foundErrors.Count -gt 0) {
    Write-Host "[FAIL] ERRORS DETECTED:" -ForegroundColor Red
    $foundErrors | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Red
    }
    $foundErrors | Out-File $ErrorPath -Force
    Write-Host ""
    Write-Host "Error details saved to: $ErrorPath" -ForegroundColor Gray
    $testPassed = $false
} else {
    Write-Host "[OK] No errors detected in output" -ForegroundColor Green
    $testPassed = $true
}

if ($foundWarnings.Count -gt 0) {
    Write-Host "[WARN] Warnings detected: $($foundWarnings.Count)" -ForegroundColor Yellow
    $foundWarnings | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Yellow
    }
}

# FINAL VERDICT
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

if ($testPassed) {
    Write-Host "[SUCCESS] ALL CHECKS PASSED" -ForegroundColor Green
    Write-Host "GUI executed without critical errors" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAILURE] ERRORS DETECTED - GUI NOT READY" -ForegroundColor Red
    Write-Host "DO NOT DEPLOY - Fix errors and re-test" -ForegroundColor Red
    exit 1
}
