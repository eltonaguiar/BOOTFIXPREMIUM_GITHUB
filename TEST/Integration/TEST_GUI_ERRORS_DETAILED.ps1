#!/usr/bin/env powershell
# Test that captures all errors when starting GUI

$ErrorActionPreference = 'Continue'
$VerbosePreference = 'Continue'
$DebugPreference = 'Continue'

# Redirect error stream
$errors = @()
$warnings = @()

$origErrorActionPreference = $ErrorActionPreference

try {
    Write-Host "Loading files..." -ForegroundColor Cyan
    
    # Load WinRepairCore
    . ".\HELPER SCRIPTS\WinRepairCore.ps1" 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            $errors += $_
            Write-Host "CORE ERROR: $_" -ForegroundColor Red
        }
    }
    
    # Load WinRepairGUI
    . ".\HELPER SCRIPTS\WinRepairGUI.ps1" 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            $errors += $_
            Write-Host "GUI LOAD ERROR: $_" -ForegroundColor Red
        }
    }
    
    Write-Host "Starting GUI..." -ForegroundColor Cyan
    Write-Host ""
    
    # Clear error history
    $global:Error.Clear()
    
    # Set error action to Stop to catch all errors
    $ErrorActionPreference = 'Stop'
    
    try {
        Start-GUI
    } catch {
        $errors += $_
        Write-Host "START-GUI ERROR: $_" -ForegroundColor Red
        Write-Host "  Position: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Red
    }
    
} finally {
    $ErrorActionPreference = $origErrorActionPreference
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Errors caught: $($errors.Count)"
if ($global:Error.Count -gt 0) {
    Write-Host "Global errors: $($global:Error.Count)"
    Write-Host ""
    $global:Error | ForEach-Object {
        Write-Host "GLOBAL ERROR: $_" -ForegroundColor Red
    }
}

if ($errors.Count -eq 0 -and $global:Error.Count -eq 0) {
    Write-Host "NO ERRORS FOUND" -ForegroundColor Green
}
