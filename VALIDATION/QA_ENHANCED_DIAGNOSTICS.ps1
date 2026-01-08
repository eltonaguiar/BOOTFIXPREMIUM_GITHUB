# QA_ENHANCED_DIAGNOSTICS.ps1
# Advanced diagnostic suite for code quality and runtime analysis
# Version: 1.0
# Purpose: Comprehensive code health checks, error detection, and performance analysis

param(
    [switch]$Verbose,
    [switch]$PerformanceTest
)

$ErrorActionPreference = "Continue"
$diagnosticResults = @{
    Passed = 0
    Failed = 0
    Warnings = 0
    Errors = @()
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ENHANCED QA DIAGNOSTIC SUITE v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# DIAGNOSTIC 1: CODE SYNTAX ANALYSIS
# ============================================================================

Write-Host "[DIAGNOSTIC 1] Advanced Syntax Analysis..." -ForegroundColor Yellow

$scriptFiles = @(
    ".\HELPER SCRIPTS\WinRepairCore.ps1",
    ".\HELPER SCRIPTS\WinRepairGUI.ps1",
    ".\HELPER SCRIPTS\WinRepairTUI.ps1"
)

foreach ($file in $scriptFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "  [WARN] File not found: $file" -ForegroundColor Yellow
        $diagnosticResults.Warnings++
        continue
    }
    
    try {
        $content = Get-Content $file -Raw
        $tokens = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        Write-Host "  [OK] $((Split-Path $file -Leaf)): $($tokens.Count) tokens" -ForegroundColor Green
        $diagnosticResults.Passed++
    } catch {
        Write-Host "  [ERROR] $(Split-Path $file -Leaf): $($_.Exception.Message)" -ForegroundColor Red
        $diagnosticResults.Failed++
        $diagnosticResults.Errors += $_.Exception.Message
    }
}

Write-Host ""

# ============================================================================
# DIAGNOSTIC 2: IMPORT AND DEPENDENCY CHAIN
# ============================================================================

Write-Host "[DIAGNOSTIC 2] Module Dependency Chain Analysis..." -ForegroundColor Yellow

try {
    Write-Host "  Loading WinRepairCore..." -ForegroundColor Gray
    . ".\HELPER SCRIPTS\WinRepairCore.ps1" -ErrorAction Stop
    Write-Host "    [OK] WinRepairCore loaded" -ForegroundColor Green
    $diagnosticResults.Passed++
    
    Write-Host "  Loading WinRepairGUI..." -ForegroundColor Gray
    . ".\HELPER SCRIPTS\WinRepairGUI.ps1" -ErrorAction Stop
    Write-Host "    [OK] WinRepairGUI loaded" -ForegroundColor Green
    $diagnosticResults.Passed++
    
    Write-Host "  Checking function definitions..." -ForegroundColor Gray
    $importantFuncs = @("Start-GUI", "Get-SystemInfo")
    
    foreach ($func in $importantFuncs) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            Write-Host "    [OK] $func available" -ForegroundColor Green
            $diagnosticResults.Passed++
        } else {
            Write-Host "    [WARN] $func not found" -ForegroundColor Yellow
            $diagnosticResults.Warnings++
        }
    }
} catch {
    Write-Host "  [ERROR] Module loading failed: $($_.Exception.Message)" -ForegroundColor Red
    $diagnosticResults.Failed++
    $diagnosticResults.Errors += $_.Exception.Message
}

Write-Host ""

# ============================================================================
# DIAGNOSTIC 3: XAML STRUCTURE VALIDATION
# ============================================================================

Write-Host "[DIAGNOSTIC 3] XAML Structure and Binding Analysis..." -ForegroundColor Yellow

try {
    $xamlFile = ".\HELPER SCRIPTS\WinRepairGUI.ps1"
    $content = Get-Content $xamlFile -Raw
    
    # Extract XAML
    $start = $content.IndexOf('$XAML = @"')
    $end = $content.IndexOf('"@', $start + 10)
    
    if ($start -lt 0 -or $end -lt 0) {
        throw "XAML block not found in WinRepairGUI.ps1"
    }
    
    $xaml = $content.Substring($start + 11, $end - $start - 11)
    
    # Validate XML
    [xml]$xmlDoc = $xaml
    Write-Host "  [OK] XAML parsed successfully" -ForegroundColor Green
    $diagnosticResults.Passed++
    
    # Check critical elements
    $window = $xmlDoc.SelectSingleNode("//Window")
    if ($window) {
        Write-Host "    [OK] Main Window element found" -ForegroundColor Green
        $diagnosticResults.Passed++
    }
    
    $tabControl = $xmlDoc.SelectSingleNode("//TabControl")
    if ($tabControl) {
        Write-Host "    [OK] TabControl found" -ForegroundColor Green
        $diagnosticResults.Passed++
        
        $tabs = $tabControl.SelectNodes("TabItem")
        Write-Host "    [INFO] Found $($tabs.Count) tabs in TabControl" -ForegroundColor Cyan
    }
    
    # Check for unbound bindings
    $bindings = $xmlDoc.SelectNodes("//*[@*[contains(., '{Binding')]]")
    Write-Host "    [INFO] Found $($bindings.Count) data bindings" -ForegroundColor Cyan
    
} catch {
    Write-Host "  [ERROR] XAML validation failed: $($_.Exception.Message)" -ForegroundColor Red
    $diagnosticResults.Failed++
    $diagnosticResults.Errors += $_.Exception.Message
}

Write-Host ""

# ============================================================================
# DIAGNOSTIC 4: RUNTIME ERROR SIMULATION
# ============================================================================

Write-Host "[DIAGNOSTIC 4] Runtime Error Detection..." -ForegroundColor Yellow

$errorTests = @(
    @{ 
        Name = "Null Reference Check"
        Test = { if ($null -eq $XAML) { throw "XAML is null" } }
    },
    @{
        Name = "Function Call Validation"
        Test = { if (-not (Get-Command Start-GUI -ErrorAction SilentlyContinue)) { throw "Start-GUI not available" } }
    },
    @{
        Name = "Assembly Load Check"
        Test = { 
            try { [System.Reflection.Assembly]::LoadWithPartialName("PresentationFramework") | Out-Null } 
            catch { throw "PresentationFramework load failed" }
        }
    }
)

foreach ($test in $errorTests) {
    try {
        & $test.Test
        Write-Host "  [OK] $($test.Name)" -ForegroundColor Green
        $diagnosticResults.Passed++
    } catch {
        Write-Host "  [ERROR] $($test.Name): $($_.Exception.Message)" -ForegroundColor Red
        $diagnosticResults.Failed++
        $diagnosticResults.Errors += "$($test.Name): $($_.Exception.Message)"
    }
}

Write-Host ""

# ============================================================================
# DIAGNOSTIC 5: FILE INTEGRITY CHECK
# ============================================================================

Write-Host "[DIAGNOSTIC 5] File Integrity and Resource Check..." -ForegroundColor Yellow

$resources = @(
    @{ Type = "Script"; Path = ".\HELPER SCRIPTS\WinRepairCore.ps1" },
    @{ Type = "Script"; Path = ".\HELPER SCRIPTS\WinRepairGUI.ps1" },
    @{ Type = "Script"; Path = ".\HELPER SCRIPTS\WinRepairTUI.ps1" },
    @{ Type = "Directory"; Path = ".\DOCUMENTATION" },
    @{ Type = "Directory"; Path = ".\VALIDATION" },
    @{ Type = "File"; Path = ".\DOCUMENTATION\RECOMMENDED_TOOLS_FEATURE.md" }
)

foreach ($resource in $resources) {
    if (Test-Path $resource.Path) {
        $item = Get-Item $resource.Path
        if ($resource.Type -eq "File" -or $resource.Type -eq "Script") {
            $size = $item.Length / 1024
            Write-Host "  [OK] $($resource.Path) ($([math]::Round($size, 2))KB)" -ForegroundColor Green
        } else {
            Write-Host "  [OK] $($resource.Path) (Directory)" -ForegroundColor Green
        }
        $diagnosticResults.Passed++
    } else {
        Write-Host "  [ERROR] Missing: $($resource.Path)" -ForegroundColor Red
        $diagnosticResults.Failed++
        $diagnosticResults.Errors += "Missing resource: $($resource.Path)"
    }
}

Write-Host ""

# ============================================================================
# DIAGNOSTIC 6: PERFORMANCE ANALYSIS
# ============================================================================

if ($PerformanceTest) {
    Write-Host "[DIAGNOSTIC 6] Performance Analysis..." -ForegroundColor Yellow
    
    $perfTests = @(
        @{ Name = "XAML Parse Time"; Script = { [xml]$test = (Get-Content ".\HELPER SCRIPTS\WinRepairGUI.ps1" -Raw).Substring(0, 5000) } },
        @{ Name = "Module Load Time"; Script = { . ".\HELPER SCRIPTS\WinRepairCore.ps1" -ErrorAction Stop } }
    )
    
    foreach ($test in $perfTests) {
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            & $test.Script
            $timer.Stop()
            Write-Host "  [OK] $($test.Name): $($timer.ElapsedMilliseconds)ms" -ForegroundColor Green
            $diagnosticResults.Passed++
        } catch {
            $timer.Stop()
            Write-Host "  [ERROR] $($test.Name) failed after $($timer.ElapsedMilliseconds)ms" -ForegroundColor Red
            $diagnosticResults.Failed++
        }
    }
    
    Write-Host ""
}

# ============================================================================
# DIAGNOSTIC SUMMARY
# ============================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTIC SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Checks Passed: $($diagnosticResults.Passed)" -ForegroundColor Green
Write-Host "Checks Failed: $($diagnosticResults.Failed)" -ForegroundColor Red
Write-Host "Warnings: $($diagnosticResults.Warnings)" -ForegroundColor Yellow
Write-Host ""

if ($diagnosticResults.Errors.Count -gt 0) {
    Write-Host "ERRORS DETECTED:" -ForegroundColor Red
    foreach ($error in $diagnosticResults.Errors) {
        Write-Host "  • $error" -ForegroundColor Red
    }
    Write-Host ""
}

$totalTests = $diagnosticResults.Passed + $diagnosticResults.Failed
if ($totalTests -gt 0) {
    $passRate = [math]::Round(($diagnosticResults.Passed / $totalTests) * 100, 2)
    Write-Host "Pass Rate: $passRate%" -ForegroundColor Cyan
}

Write-Host ""
if ($diagnosticResults.Failed -eq 0) {
    Write-Host "RESULT: ALL DIAGNOSTICS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "RESULT: DIAGNOSTICS FAILED - REVIEW ERRORS" -ForegroundColor Red
    exit 1
}
