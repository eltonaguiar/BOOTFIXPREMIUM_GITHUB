#!/usr/bin/env powershell
# Complete GUI loading test with raw output capture

$ErrorActionPreference = 'Continue'
$VerbosePreference = 'Continue'  
$DebugPreference = 'Continue'

$logFile = "GUI_DETAILED_LOG.txt"
$output = @()

function WriteLog {
    param([string]$Message)
    $output += $Message
    Write-Host $Message
}

WriteLog "========================================="
WriteLog "GUI LOADING TEST - COMPLETE TRACE"
WriteLog "========================================="
WriteLog ""

# Load WinRepairCore
WriteLog "[1] Loading WinRepairCore.ps1..."
try {
    . ".\HELPER SCRIPTS\WinRepairCore.ps1"
    WriteLog "    [OK] WinRepairCore loaded"
} catch {
    WriteLog "    [ERROR] $_"
}

# Load WinRepairGUI
WriteLog "[2] Loading WinRepairGUI.ps1..."
try {
    . ".\HELPER SCRIPTS\WinRepairGUI.ps1"
    WriteLog "    [OK] WinRepairGUI loaded"
} catch {
    WriteLog "    [ERROR] $_"
    WriteLog "    [STACK] $($_.ScriptStackTrace)"
}

#Check function exists
WriteLog "[3] Verifying Start-GUI function..."
if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
    WriteLog "    [OK] Start-GUI function found"
} else {
    WriteLog "    [ERROR] Start-GUI function NOT found"
}

WriteLog ""
WriteLog "========================================="
WriteLog "STARTING GUI..."
WriteLog "========================================="
WriteLog ""

# Actual Start-GUI call with full error capture
try {
    $global:Error.Clear()
    
    Start-GUI 2>&1 | ForEach-Object {
        $line = "$_"
        WriteLog $line
    }
    
    WriteLog ""
    WriteLog "[OK] Start-GUI completed successfully"
} catch {
    WriteLog "[CRITICAL ERROR] $_"
    WriteLog "[CRITICAL STACK] $($_.ScriptStackTrace)"
    WriteLog "[CRITICAL POSITION] $($_.InvocationInfo.PositionMessage)"
}

WriteLog ""
WriteLog "========================================="
WriteLog "GLOBAL ERROR CHECK"
WriteLog "========================================="
if ($global:Error.Count -gt 0) {
    WriteLog "[ERROR COUNT] $($global:Error.Count) errors found in `$global:Error"
    $global:Error | ForEach-Object {
        WriteLog "[GLOBAL ERROR] $_"
    }
} else {
    WriteLog "[OK] No errors in `$global:Error"
}

WriteLog ""
WriteLog "========================================="
WriteLog "TEST COMPLETE"
WriteLog "========================================="

# Save to file
$output | Out-File -FilePath $logFile -Encoding UTF8
WriteLog ""
WriteLog "Log saved to: $logFile"
WriteLog ""

# Count errors in output
$errorCount = ($output | Where-Object { $_ -match '\[ERROR\]|\[CRITICAL' }).Count
WriteLog "Error lines found: $errorCount"

if ($errorCount -gt 0) {
    WriteLog ""
    WriteLog "=== ERRORS FOUND ==="
    $output | Where-Object { $_ -match '\[ERROR\]|\[CRITICAL' } | ForEach-Object {
        WriteLog "$_"
    }
}
