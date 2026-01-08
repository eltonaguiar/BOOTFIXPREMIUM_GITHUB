#!/usr/bin/env powershell
# Debug GUI Loading Errors

$ErrorActionPreference = 'Continue'
$VerbosePreference = 'Continue'
$DebugPreference = 'Continue'

Write-Host "Loading files..." -ForegroundColor Cyan

# Load with error capture
try {
    . ".\HELPER SCRIPTS\WinRepairCore.ps1" 2>&1 | Where-Object { $_ -match 'error|Error|ERROR' } | ForEach-Object {
        Write-Host "[CORE ERROR] $_" -ForegroundColor Red
    }
} catch {
    Write-Host "[CORE LOAD ERROR] $_" -ForegroundColor Red
}

try {
    . ".\HELPER SCRIPTS\WinRepairGUI.ps1" 2>&1 | Where-Object { $_ -match 'error|Error|ERROR|null|Null' } | ForEach-Object {
        Write-Host "[GUI LOAD ERROR] $_" -ForegroundColor Red
    }
} catch {
    Write-Host "[GUI LOAD ERROR] $_" -ForegroundColor Red
}

Write-Host "Calling Start-GUI..." -ForegroundColor Cyan
Write-Host ""

$global:Error.Clear()

Start-GUI 2>&1 | ForEach-Object {
    Write-Host $_
}

Write-Host ""
if ($global:Error.Count -gt 0) {
    Write-Host "=== Errors in `$global:Error ===" -ForegroundColor Red
    $global:Error | ForEach-Object {
        Write-Host "ERROR: $_" -ForegroundColor Red
    }
}

Write-Host "Done" -ForegroundColor Green
