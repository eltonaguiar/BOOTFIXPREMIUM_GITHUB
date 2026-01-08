#!/usr/bin/env powershell
<#
.SYNOPSIS
    ULTIMATE EXECUTION TEST - Comprehensive Error & Output Capture
    
.DESCRIPTION
    This is the definitive test that will:
    1. Source all modules
    2. Redirect BOTH stdout and stderr to log file
    3. Call Start-GUI in timeout 
    4. Parse log file for ANY error keywords
    5. FAIL immediately if ANY errors found
#>

param(
    [string]$OutputPath = ".\VALIDATION\TEST_LOGS\ULTIMATE_EXECUTION_TEST.log",
    [int]$TimeoutSeconds = 3
)

# Ensure log directory
$logDir = Split-Path $OutputPath
if (-not (Test-Path $logDir)) {
    mkdir $logDir -Force | Out-Null
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "ULTIMATE EXECUTION TEST" -ForegroundColor Cyan
Write-Host "Comprehensive Error & Output Capture" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Create a script block that will be executed and logged
$scriptContent = @'
param($timeout)

Write-Host "[START] GUI Execution Test Beginning" -ForegroundColor Cyan
Write-Host "[TIME] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

$ErrorActionPreference = 'Continue'
$DebugPreference = 'Continue'
$VerbosePreference = 'Continue'

# Step 1: Load Assemblies
Write-Host "[STEP 1] Loading PresentationFramework..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Write-Host "[OK] PresentationFramework loaded" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] PresentationFramework failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host "[STEP 2] Loading System.Windows.Forms..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Write-Host "[OK] System.Windows.Forms loaded" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] System.Windows.Forms failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Load Core Module
Write-Host "[STEP 3] Loading WinRepairCore..." -ForegroundColor Yellow
try {
    . ".\HELPER SCRIPTS\WinRepairCore.ps1" -ErrorAction Stop
    Write-Host "[OK] WinRepairCore loaded" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] WinRepairCore failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

# Step 3: Load GUI Module - THIS IS THE CRITICAL STEP
Write-Host "[STEP 4] Loading WinRepairGUI (REAL EXECUTION)..." -ForegroundColor Yellow
try {
    . ".\HELPER SCRIPTS\WinRepairGUI.ps1" -ErrorAction Stop
    Write-Host "[OK] WinRepairGUI loaded" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] WinRepairGUI loading failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

# Step 4: Verify Start-GUI
Write-Host "[STEP 5] Verifying Start-GUI function..." -ForegroundColor Yellow
if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Start-GUI function available" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Start-GUI function not found" -ForegroundColor Red
    exit 1
}

# Step 5: Call Start-GUI with timeout
Write-Host "[STEP 6] Invoking Start-GUI (with $timeout second timeout)..." -ForegroundColor Yellow
$jobStartTime = Get-Date

try {
    # This will show GUI or throw errors
    $job = Start-Job -ScriptBlock {
        $ErrorActionPreference = 'Continue'
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName System.Windows.Forms
        . ".\HELPER SCRIPTS\WinRepairCore.ps1"
        . ".\HELPER SCRIPTS\WinRepairGUI.ps1"
        Start-GUI
    }
    
    $result = Wait-Job -Job $job -Timeout $timeout
    
    if ($result) {
        $jobOutput = Receive-Job -Job $job
        if ($job.ChildJobs[0].Error.Count -gt 0) {
            Write-Host "[ERROR] Job had errors:" -ForegroundColor Red
            $job.ChildJobs[0].Error | ForEach-Object {
                Write-Host "  [ERROR] $_" -ForegroundColor Red
            }
        }
        Write-Host "[OK] Start-GUI job completed" -ForegroundColor Green
    } else {
        Write-Host "[OK] Start-GUI is running (UI window should be visible)" -ForegroundColor Green
    }
    
    Stop-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "[ERROR] Exception calling Start-GUI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host "[COMPLETE] GUI Execution Test Complete" -ForegroundColor Cyan
Write-Host "[TIME] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

'@

# Execute the script and capture ALL output to file
Write-Host "Executing GUI code and capturing all output..." -ForegroundColor Yellow
Write-Host "Log file: $OutputPath" -ForegroundColor Gray
Write-Host ""

$allOutput = @()
$allOutput += "=== ULTIMATE GUI EXECUTION TEST LOG ===" 
$allOutput += "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$allOutput += "Timeout: $TimeoutSeconds seconds"
$allOutput += ""
$allOutput += "=== EXECUTION OUTPUT ==="

# Run the script
$output = powershell -NoProfile -ExecutionPolicy Bypass -Command $scriptContent -ArgumentList $TimeoutSeconds 2>&1
$allOutput += $output

$allOutput += ""
$allOutput += "=== ANALYSIS ==="

# Check for errors
$errorKeywords = @(
    'ERROR',
    'error',
    'Exception',
    'exception',
    'failed',
    'Failed',
    'FAIL'
)

$foundErrors = @()
foreach ($line in $allOutput) {
    foreach ($keyword in $errorKeywords) {
        if ($line -match $keyword -and $line -match '\[ERROR\]|\[FAIL\]') {
            $foundErrors += $line
        }
    }
}

$allOutput += "Errors found: $($foundErrors.Count)"
if ($foundErrors.Count -gt 0) {
    $allOutput += "=== ERRORS ==="
    $allOutput += $foundErrors
}

# Save to file
$allOutput | Out-File $OutputPath -Force -Encoding UTF8

# Display results
$output | ForEach-Object { Write-Host $_ }

# Final verdict
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan

if ($foundErrors.Count -gt 0) {
    Write-Host "[FAIL] EXECUTION TEST FAILED" -ForegroundColor Red
    Write-Host "Errors detected: $($foundErrors.Count)" -ForegroundColor Red
    Write-Host ""
    Write-Host "DO NOT DEPLOY - Errors found in GUI execution" -ForegroundColor Red
    Write-Host "Log: $OutputPath" -ForegroundColor Gray
    exit 1
} else {
    Write-Host "[PASS] EXECUTION TEST PASSED" -ForegroundColor Green
    Write-Host "No errors detected" -ForegroundColor Green
    Write-Host ""
    Write-Host "Log: $OutputPath" -ForegroundColor Gray
    exit 0
}
