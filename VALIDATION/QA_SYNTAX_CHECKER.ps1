#!/usr/bin/env powershell
<#
.SYNOPSIS
    Syntax Checker for PowerShell Scripts
    
.DESCRIPTION
    Validates syntax of all PowerShell files in the project.
#>

param(
    [string]$ScriptsPath = ".",
    [string]$ReportPath = ".\VALIDATION\TEST_LOGS\SYNTAX_CHECK_REPORT.txt"
)

$ErrorActionPreference = 'Continue'

$results = @()
$totalErrors = 0
$totalWarnings = 0

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "POWERSHELL SYNTAX VALIDATION" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$psFiles = @(Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue)
Write-Host "Found $($psFiles.Count) PowerShell files to validate" -ForegroundColor Yellow
Write-Host ""

foreach ($file in $psFiles) {
    $errors = @()
    $warnings = @()
    
    try {
        $content = Get-Content $file.FullName -Raw -ErrorAction Stop
        $tokens = @()
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
        
        if ($errors.Count -eq 0) {
            Write-Host "[OK] $($file.Name)" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] $($file.Name) - $($errors.Count) errors" -ForegroundColor Red
            $totalErrors += $errors.Count
            foreach ($err in $errors) {
                $warnings += "Line $($err.Token.StartLine): $($err.Message)"
            }
        }
    } catch {
        Write-Host "[FAIL] $($file.Name) - Parse error: $_" -ForegroundColor Red
        $totalErrors++
    }
    
    $results += @{
        Script = $file.Name
        Errors = $errors.Count
        Warnings = $warnings
    }
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "RESULTS:" -ForegroundColor Cyan
Write-Host "  Total Files: $($psFiles.Count)" -ForegroundColor Gray
Write-Host "  Errors: $totalErrors" -ForegroundColor $(if ($totalErrors -gt 0) { "Red" } else { "Green" })
Write-Host "  Warnings: $totalWarnings" -ForegroundColor Gray
Write-Host ""

if ($totalErrors -gt 0) {
    Write-Host "[FAIL] SYNTAX ERRORS DETECTED - Fix before proceeding" -ForegroundColor Red
    exit 1
} else {
    Write-Host "[OK] ALL SCRIPTS PASSED SYNTAX VALIDATION" -ForegroundColor Green
    exit 0
}
