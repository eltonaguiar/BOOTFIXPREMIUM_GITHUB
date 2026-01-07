#!/usr/bin/env powershell
<#
.SYNOPSIS
    Comprehensive Test Orchestrator - Runs all validation layers
    
.DESCRIPTION
    Master test coordinator that runs:
    1. SUPER_TEST_MANDATORY - Primary validation (REQUIRED)
    2. All individual test modules (comprehensive)
    3. Generates consolidated report
    
.PARAMETER TestLevel
    1 = Quick (syntax only)
    2 = Standard (syntax + modules)
    3 = Full (syntax + modules + UI)
    Default: 3
    
.PARAMETER GenerateHTML
    If $true, generates HTML report. Default: $true
#>

param(
    [ValidateSet(1, 2, 3)]
    [int]$TestLevel = 3,
    [bool]$GenerateHTML = $true
)

$ErrorActionPreference = 'Continue'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$logDir = Join-Path $scriptDir "TEST_LOGS"
$orchestratorLog = Join-Path $logDir "ORCHESTRATOR_$timestamp.log"

if (-not (Test-Path $logDir)) {
    $null = New-Item -ItemType Directory -Path $logDir -Force
}

# Logging function
function Write-OrchestratorLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [System.ConsoleColor]$Color = "White"
    )
    
    $logEntry = "$(Get-Date -Format 'HH:mm:ss') [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $Color
    Add-Content -Path $orchestratorLog -Value $logEntry
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  MIRACLEBOOT TEST ORCHESTRATOR v1.0" -ForegroundColor Cyan
Write-Host "  Comprehensive Multi-Layer Validation System" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host ""

Write-OrchestratorLog "Test Orchestration Starting" "START" "Cyan"
Write-OrchestratorLog "Test Level: $TestLevel" "INFO" "White"
Write-OrchestratorLog "Log Directory: $logDir" "INFO" "White"

$orchestratorResults = @{
    StartTime = Get-Date
    EndTime = $null
    SuperTestPassed = $false
    SuperTestExitCode = -1
    IndividualTests = @()
    OverallStatus = "PENDING"
    TotalErrors = 0
}

# ============================================================================
# LAYER 1: SUPER TEST (MANDATORY)
# ============================================================================
Write-Host ""
Write-OrchestratorLog "==============================" "LAYER" "Yellow"
Write-OrchestratorLog "LAYER 1: MANDATORY SUPER TEST" "LAYER" "Yellow"
Write-OrchestratorLog "==============================" "LAYER" "Yellow"

$superTestPath = Join-Path $scriptDir "SUPER_TEST_MANDATORY.ps1"

if (Test-Path $superTestPath) {
    Write-OrchestratorLog "Running: SUPER_TEST_MANDATORY.ps1" "RUN" "Cyan"
    Write-Host ""
    
    try {
        # Run super test and capture exit code
        & $superTestPath -UITest ($TestLevel -ge 3)
        $orchestratorResults.SuperTestExitCode = $LASTEXITCODE
        $orchestratorResults.SuperTestPassed = ($LASTEXITCODE -eq 0)
        
        if ($orchestratorResults.SuperTestPassed) {
            Write-OrchestratorLog "SUPER_TEST: PASSED [OK]" "PASS" "Green"
        } else {
            Write-OrchestratorLog "SUPER_TEST: FAILED [ERROR]" "FAIL" "Red"
            $orchestratorResults.TotalErrors++
        }
    } catch {
        Write-OrchestratorLog "SUPER_TEST: EXCEPTION - $($_.Exception.Message)" "ERROR" "Red"
        $orchestratorResults.SuperTestPassed = $false
        $orchestratorResults.TotalErrors++
    }
} else {
    Write-OrchestratorLog "CRITICAL: SUPER_TEST_MANDATORY.ps1 not found!" "CRITICAL" "Red"
    $orchestratorResults.TotalErrors++
}

# ============================================================================
# LAYER 2: INDIVIDUAL TEST MODULES
# ============================================================================
Write-Host ""
Write-OrchestratorLog "==============================" "LAYER" "Yellow"
Write-OrchestratorLog "LAYER 2: INDIVIDUAL TEST MODULES" "LAYER" "Yellow"
Write-OrchestratorLog "==============================" "LAYER" "Yellow"

$testDir = Join-Path $scriptDir "TEST"
if (Test-Path $testDir) {
    $testModules = Get-ChildItem -Path $testDir -Filter "Test-*.ps1" -File -ErrorAction SilentlyContinue
    
    Write-OrchestratorLog "Found $($testModules.Count) individual test modules" "INFO" "White"
    
    foreach ($testModule in $testModules) {
        Write-Host ""
        Write-OrchestratorLog "Running: $($testModule.Name)" "RUN" "Cyan"
        
        try {
            & $testModule.FullName
            $exitCode = $LASTEXITCODE
            
            $testResult = @{
                Name = $testModule.Name
                ExitCode = $exitCode
                Passed = ($exitCode -eq 0)
            }
            
            $orchestratorResults.IndividualTests += $testResult
            
            if ($exitCode -eq 0) {
                Write-OrchestratorLog "$($testModule.Name): PASSED" "PASS" "Green"
            } else {
                Write-OrchestratorLog "$($testModule.Name): FAILED (exit: $exitCode)" "WARN" "Yellow"
            }
        } catch {
            Write-OrchestratorLog "$($testModule.Name): EXCEPTION - $($_.Exception.Message)" "ERROR" "Red"
            $orchestratorResults.IndividualTests += @{
                Name = $testModule.Name
                ExitCode = -1
                Passed = $false
                Exception = $_.Exception.Message
            }
        }
    }
} else {
    Write-OrchestratorLog "TEST directory not found at: $testDir" "WARN" "Yellow"
}

# ============================================================================
# LAYER 3: CONSOLIDATED REPORT
# ============================================================================
Write-Host ""
Write-OrchestratorLog "==============================" "LAYER" "Yellow"
Write-OrchestratorLog "LAYER 3: CONSOLIDATED REPORT" "LAYER" "Yellow"
Write-OrchestratorLog "==============================" "LAYER" "Yellow"

$orchestratorResults.EndTime = Get-Date
$duration = $orchestratorResults.EndTime - $orchestratorResults.StartTime

Write-Host ""
Write-OrchestratorLog "Test Duration: $([Math]::Round($duration.TotalSeconds, 2)) seconds" "TIME" "Cyan"
Write-OrchestratorLog "" "INFO"

Write-OrchestratorLog "SUPER TEST:        $(if ($orchestratorResults.SuperTestPassed) { "PASSED" } else { "FAILED" })" "RESULT" $(if ($orchestratorResults.SuperTestPassed) { "Green" } else { "Red" })
Write-OrchestratorLog "Individual Tests:  $($orchestratorResults.IndividualTests.Count) found" "RESULT" "Cyan"

$passedIndividual = @($orchestratorResults.IndividualTests | Where-Object { $_.Passed }).Count
Write-OrchestratorLog "                   $passedIndividual passed, $(($orchestratorResults.IndividualTests.Count) - $passedIndividual) issues" "RESULT" "Cyan"

# Determine overall status
if ($orchestratorResults.SuperTestPassed -and $orchestratorResults.TotalErrors -eq 0) {
    $orchestratorResults.OverallStatus = "READY FOR RELEASE"
    $statusColor = "Green"
} else {
    $orchestratorResults.OverallStatus = "FIX REQUIRED"
    $statusColor = "Red"
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  FINAL STATUS: $($orchestratorResults.OverallStatus)" -ForegroundColor $statusColor
Write-Host "======================================================" -ForegroundColor Cyan

Write-OrchestratorLog "" "INFO"
Write-OrchestratorLog "FINAL STATUS: $($orchestratorResults.OverallStatus)" "FINAL" $statusColor
Write-OrchestratorLog "Orchestrator log: $orchestratorLog" "INFO" "Cyan"

Write-Host ""

# Generate HTML report if requested
if ($GenerateHTML) {
    $htmlPath = Join-Path $logDir "REPORT_$timestamp.html"
    
    # Create HTML content
    $htmlContent = "<!DOCTYPE html>`r`n<html lang=`"en`">`r`n"
    $htmlContent += "<head>`r`n"
    $htmlContent += "<meta charset=`"UTF-8`">`r`n"
    $htmlContent += "<title>MiracleBoot Test Report - $timestamp</title>`r`n"
    $htmlContent += "<style>`r`n"
    $htmlContent += "body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }`r`n"
    $htmlContent += ".container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }`r`n"
    $htmlContent += "h1 { color: #0078d4; border-bottom: 3px solid #0078d4; }`r`n"
    $htmlContent += "table { width: 100%; border-collapse: collapse; margin: 20px 0; }`r`n"
    $htmlContent += "th { background: #f5f5f5; font-weight: bold; padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }`r`n"
    $htmlContent += "td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }`r`n"
    $htmlContent += ".pass-cell { color: #34a853; font-weight: bold; }`r`n"
    $htmlContent += ".fail-cell { color: #d33b27; font-weight: bold; }`r`n"
    $htmlContent += "</style>`r`n</head>`r`n"
    $htmlContent += "<body><div class=`"container`">`r`n"
    $htmlContent += "<h1>MiracleBoot Test Report</h1>`r`n"
    $htmlContent += "<p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>`r`n"
    $htmlContent += "<h2>Summary</h2>`r`n"
    $htmlContent += "<p><strong>Super Test:</strong> <span class='$(if ($orchestratorResults.SuperTestPassed) { 'pass-cell' } else { 'fail-cell' })'>$(if ($orchestratorResults.SuperTestPassed) { 'PASSED' } else { 'FAILED' })</span></p>`r`n"
    $htmlContent += "<table>`r`n<tr><th>Test</th><th>Status</th><th>Exit Code</th></tr>`r`n"
    $htmlContent += "<tr><td>SUPER_TEST_MANDATORY</td><td><span class='$(if ($orchestratorResults.SuperTestPassed) { 'pass-cell' } else { 'fail-cell' })'>$(if ($orchestratorResults.SuperTestPassed) { 'PASSED' } else { 'FAILED' })</span></td><td>$($orchestratorResults.SuperTestExitCode)</td></tr>`r`n"
    
    foreach ($test in $orchestratorResults.IndividualTests) {
        $statusSpan = if ($test.Passed) { "<span class='pass-cell'>PASSED</span>" } else { "<span class='fail-cell'>FAILED</span>" }
        $htmlContent += "<tr><td>$($test.Name)</td><td>$statusSpan</td><td>$($test.ExitCode)</td></tr>`r`n"
    }
    
    $htmlContent += "</table>`r`n</div></body>`r`n</html>`r`n"
    
    Set-Content -Path $htmlPath -Value $htmlContent
    Write-OrchestratorLog "HTML Report generated: $htmlPath" "REPORT" "Cyan"
}

Write-OrchestratorLog "Orchestration Complete" "END" "Cyan"

# Exit with appropriate code
if ($orchestratorResults.SuperTestPassed -and $orchestratorResults.TotalErrors -eq 0) {
    exit 0
} else {
    exit 1
}
