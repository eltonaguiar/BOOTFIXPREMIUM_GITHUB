#!/usr/bin/env powershell
<#
.SYNOPSIS
    Comprehensive test validation suite for MiracleBoot v7.2.0
    
.DESCRIPTION
    Validates code quality, syntax, and basic functionality across all modules.
    
.PARAMETER TestLevel
    1: Syntax only
    2: Syntax + Module loading
    3: Full validation
#>

param(
    [ValidateSet(1, 2, 3)]
    [int]$TestLevel = 2
)

$ErrorActionPreference = 'Continue'

$testResults = @{
    StartTime = Get-Date
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    WarningTests = 0
}

Write-Host "`nMiracleBoot v7.2.0 - Test Suite" -ForegroundColor Cyan
Write-Host "Level $TestLevel - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Cyan

# Get the working directory (where script is run from)
$dir = Get-Location

# LEVEL 1: Syntax Validation
Write-Host "LEVEL 1: Syntax Validation" -ForegroundColor Yellow
Write-Host ("-" * 50)

$psFiles = @()
$psFiles += Get-ChildItem -Path $dir -Filter '*.ps1' -File -ErrorAction SilentlyContinue
$psFiles += Get-ChildItem -Path "$dir\TEST" -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Select-Object -ErrorAction SilentlyContinue

foreach ($file in $psFiles) {
    $testResults.TotalTests++
    
    $parseErrors = $null
    $tokens = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, 
        [ref]$tokens, 
        [ref]$parseErrors
    ) | Out-Null
    
    if ($parseErrors.Count -eq 0) {
        Write-Host "  [OK]    $($file.Name)" -ForegroundColor Green
        $testResults.PassedTests++
    } else {
        Write-Host "  [FAIL]  $($file.Name) - $($parseErrors.Count) errors" -ForegroundColor Red
        $testResults.FailedTests++
    }
}

if ($TestLevel -ge 2) {
    # LEVEL 2: Module Loading
    Write-Host "`nLEVEL 2: Module Loading" -ForegroundColor Yellow
    Write-Host ("-" * 50)

    $coreModules = @(
        'MiracleBoot.ps1',
        'WinRepairCore.ps1',
        'WinRepairTUI.ps1',
        'MiracleBoot-Backup.ps1',
        'MiracleBoot-BootRecovery.ps1'
    )

    foreach ($moduleName in $coreModules) {
        $testResults.TotalTests++
        $modulePath = Join-Path $dir $moduleName
        
        if (-not (Test-Path $modulePath)) {
            Write-Host "  [SKIP]  $moduleName (not found)" -ForegroundColor Yellow
            $testResults.WarningTests++
            continue
        }
        
        try {
            $null = & {
                Set-StrictMode -Off
                . $modulePath 2>&1 | Out-Null
            }
            Write-Host "  [OK]    $moduleName" -ForegroundColor Green
            $testResults.PassedTests++
        } catch {
            Write-Host "  [FAIL]  $moduleName" -ForegroundColor Red
            $testResults.FailedTests++
        }
    }
}

if ($TestLevel -ge 3) {
    # LEVEL 3: System Info
    Write-Host "`nLEVEL 3: System Check" -ForegroundColor Yellow
    Write-Host ("-" * 50)

    $sysChecks = @(
        @{ Name = 'PowerShell'; Check = {$PSVersionTable.PSVersion.Major -ge 5}; Info = "v$($PSVersionTable.PSVersion.Major)" },
        @{ Name = 'Admin'; Check = {([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}; Info = "" }
    )

    foreach ($check in $sysChecks) {
        $testResults.TotalTests++
        
        if (& $check.Check) {
            Write-Host "  [OK]    $($check.Name) $($check.Info)" -ForegroundColor Green
            $testResults.PassedTests++
        } else {
            Write-Host "  [WARN]  $($check.Name) $($check.Info)" -ForegroundColor Yellow
            $testResults.WarningTests++
        }
    }
}

# Summary
Write-Host "`nTest Results" -ForegroundColor Cyan
Write-Host ("-" * 50)
Write-Host "Total:      $($testResults.TotalTests)"
Write-Host "Passed:     $($testResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed:     $($testResults.FailedTests)" -ForegroundColor $(if ($testResults.FailedTests -gt 0) { 'Red' } else { 'Green' })
Write-Host "Warnings:   $($testResults.WarningTests)" -ForegroundColor Yellow

$passRate = if ($testResults.TotalTests -gt 0) { [Math]::Round(($testResults.PassedTests / $testResults.TotalTests) * 100, 1) } else { 0 }
Write-Host "Pass Rate:  $passRate%`n" -ForegroundColor Cyan

if ($testResults.FailedTests -eq 0) {
    Write-Host "SUCCESS: All critical tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILURE: Some tests failed. Review output above." -ForegroundColor Red
    exit 1
}
