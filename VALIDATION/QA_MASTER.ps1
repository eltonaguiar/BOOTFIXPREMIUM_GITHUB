#!/usr/bin/env powershell
<#
.SYNOPSIS
    MiracleBoot QA Master - Complete Quality Assurance Suite
#>

Write-Host ""
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "MIRACLEBOOT QA - COMPREHENSIVE QUALITY ASSURANCE SUITE" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$totalErrors = 0
$totalWarnings = 0
$testsRun = 0
$testsPassed = 0

Write-Host "Project Root: $projectRoot" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# STAGE 1: SYNTAX VALIDATION
# ============================================================

Write-Host "STAGE 1: SYNTAX VALIDATION" -ForegroundColor Cyan
Write-Host "--------" -ForegroundColor Gray

$psScripts = @()
$psScripts += Get-ChildItem -Path $projectRoot -Filter "*.ps1" -File -ErrorAction SilentlyContinue
$psScripts += Get-ChildItem -Path (Join-Path $projectRoot "HELPER SCRIPTS") -Filter "*.ps1" -File -ErrorAction SilentlyContinue
$psScripts += Get-ChildItem -Path (Join-Path $projectRoot "VALIDATION") -Filter "*.ps1" -File -ErrorAction SilentlyContinue
$psScripts += Get-ChildItem -Path (Join-Path $projectRoot "TEST") -Filter "*.ps1" -File -ErrorAction SilentlyContinue

$psScripts = $psScripts | Select-Object -Unique -Property FullName | Where-Object { $_.FullName -notmatch 'QA_SYNTAX_CHECKER|QA_RUNTIME_TESTS|QA_ORCHESTRATOR|PRE_EXECUTION_HEALTH_CHECK' }

Write-Host "Checking $($psScripts.Count) PowerShell scripts..."

$syntaxPass = 0
$syntaxFail = 0

foreach ($script in $psScripts) {
    $scriptName = Split-Path -Leaf $script.FullName
    $testsRun++
    
    try {
        $content = Get-Content $script.FullName -Raw -ErrorAction Stop
        
        # Test parsing
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        
        # Check braces
        $ob = ([regex]::Matches($content, '\{').Count)
        $cb = ([regex]::Matches($content, '\}').Count)
        
        if ($ob -eq $cb) {
            Write-Host "  [PASS] $scriptName" -ForegroundColor Green
            $syntaxPass++
            $testsPassed++
        } else {
            Write-Host "  [FAIL] $scriptName - Brace mismatch: $ob open, $cb close" -ForegroundColor Red
            $syntaxFail++
            $totalErrors++
        }
        
    } catch {
        Write-Host "  [FAIL] $scriptName - Syntax error" -ForegroundColor Red
        $syntaxFail++
        $totalErrors++
    }
}

Write-Host ""
Write-Host "Syntax Results: $syntaxPass passed, $syntaxFail failed" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# STAGE 2: ENVIRONMENT CHECKS
# ============================================================

Write-Host "STAGE 2: ENVIRONMENT CHECKS" -ForegroundColor Cyan
Write-Host "--------" -ForegroundColor Gray

$envPass = 0
$envFail = 0

# Check admin
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$testsRun++
if ($isAdmin) {
    Write-Host "  [PASS] Administrator privileges" -ForegroundColor Green
    $envPass++
    $testsPassed++
} else {
    Write-Host "  [FAIL] Not running as administrator" -ForegroundColor Red
    $envFail++
    $totalErrors++
}

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
$ps5Plus = $psVersion.Major -ge 5
$testsRun++
if ($ps5Plus) {
    Write-Host "  [PASS] PowerShell version: v$($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Green
    $envPass++
    $testsPassed++
} else {
    Write-Host "  [FAIL] PowerShell version: v$($psVersion.Major).$($psVersion.Minor) (need 5+)" -ForegroundColor Red
    $envFail++
    $totalErrors++
}

# Check Windows
$isWindows = Test-Path "$env:SystemDrive\Windows"
$testsRun++
if ($isWindows) {
    Write-Host "  [PASS] Windows installation detected" -ForegroundColor Green
    $envPass++
    $testsPassed++
} else {
    Write-Host "  [FAIL] Windows installation not found" -ForegroundColor Red
    $envFail++
    $totalErrors++
}

Write-Host ""
Write-Host "Environment Results: $envPass passed, $envFail failed" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# STAGE 3: PROJECT STRUCTURE CHECKS
# ============================================================

Write-Host "STAGE 3: PROJECT STRUCTURE CHECKS" -ForegroundColor Cyan
Write-Host "--------" -ForegroundColor Gray

$structPass = 0
$structFail = 0

# Check main script
$mainScript = Join-Path $projectRoot "MiracleBoot.ps1"
$testsRun++
if (Test-Path $mainScript) {
    Write-Host "  [PASS] Main script found" -ForegroundColor Green
    $structPass++
    $testsPassed++
} else {
    Write-Host "  [FAIL] Main script not found" -ForegroundColor Red
    $structFail++
    $totalErrors++
}

# Check helper scripts folder
$helperFolder = Join-Path $projectRoot "HELPER SCRIPTS"
$testsRun++
if (Test-Path $helperFolder) {
    Write-Host "  [PASS] Helper scripts folder found" -ForegroundColor Green
    $structPass++
    $testsPassed++
} else {
    Write-Host "  [FAIL] Helper scripts folder not found" -ForegroundColor Red
    $structFail++
    $totalErrors++
}

# Check core modules
$coreModules = @("WinRepairCore.ps1", "WinRepairGUI.ps1", "WinRepairTUI.ps1")
foreach ($module in $coreModules) {
    $modulePath = Join-Path $helperFolder $module
    $testsRun++
    if (Test-Path $modulePath) {
        Write-Host "  [PASS] Core module: $module" -ForegroundColor Green
        $structPass++
        $testsPassed++
    } else {
        Write-Host "  [FAIL] Core module not found: $module" -ForegroundColor Red
        $structFail++
        $totalErrors++
    }
}

Write-Host ""
Write-Host "Structure Results: $structPass passed, $structFail failed" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# STAGE 4: DEPENDENCY CHECKS
# ============================================================

Write-Host "STAGE 4: DEPENDENCY CHECKS" -ForegroundColor Cyan
Write-Host "--------" -ForegroundColor Gray

$depsPass = 0
$depsFail = 0

# Check bcdedit
$bcdeditAvailable = $null -ne (Get-Command bcdedit -ErrorAction SilentlyContinue)
$testsRun++
if ($bcdeditAvailable) {
    Write-Host "  [PASS] bcdedit command available" -ForegroundColor Green
    $depsPass++
    $testsPassed++
} else {
    Write-Host "  [WARN] bcdedit command not available" -ForegroundColor Yellow
    $depsFail++
    $totalWarnings++
}

# Check WPF
$wpfAvailable = $true
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop | Out-Null
} catch {
    $wpfAvailable = $false
}
$testsRun++
if ($wpfAvailable) {
    Write-Host "  [PASS] WPF framework available" -ForegroundColor Green
    $depsPass++
    $testsPassed++
} else {
    Write-Host "  [WARN] WPF framework not available (GUI mode will use fallback)" -ForegroundColor Yellow
    $depsFail++
    $totalWarnings++
}

Write-Host ""
Write-Host "Dependency Results: $depsPass passed, $depsFail failed/warnings" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# FINAL REPORT
# ============================================================

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "QA SUMMARY REPORT" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Tests Run:         $testsRun" -ForegroundColor Yellow
Write-Host "Tests Passed:      $testsPassed" -ForegroundColor Green
Write-Host "Total Errors:      $totalErrors" -ForegroundColor $(if ($totalErrors -eq 0) { "Green" } else { "Red" })
Write-Host "Total Warnings:    $totalWarnings" -ForegroundColor $(if ($totalWarnings -eq 0) { "Green" } else { "Yellow" })
Write-Host ""

if ($totalErrors -eq 0) {
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host "ALL QA CHECKS PASSED - CODE IS READY FOR TESTING" -ForegroundColor Green
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "========================================================================" -ForegroundColor Red
    Write-Host "QA CHECKS FAILED - FIX ERRORS BEFORE PROCEEDING" -ForegroundColor Red
    Write-Host "========================================================================" -ForegroundColor Red
    Write-Host ""
    exit 1
}
