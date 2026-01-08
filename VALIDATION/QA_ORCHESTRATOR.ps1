#!/usr/bin/env powershell
<#
.SYNOPSIS
    MiracleBoot QA Orchestrator - Master Test Coordinator
    
.DESCRIPTION
    Coordinates all QA activities in the proper sequence:
    1. Syntax validation
    2. Pre-execution health check
    3. Runtime functional tests
    4. Generates comprehensive report
    
.PARAMETER Stage
    Run specific stage: 'syntax', 'health', 'runtime', 'all' (default: all)
    
.PARAMETER StrictMode
    If $true, any failure stops execution. Default: $false
#>

param(
    [ValidateSet('syntax', 'health', 'runtime', 'all')]
    [string]$Stage = 'all',
    [bool]$StrictMode = $false
)

$ErrorActionPreference = 'Continue'

# Color scheme
$colors = @{
    Title = "Cyan"
    Pass = "Green"
    Fail = "Red"
    Warning = "Yellow"
    Info = "Gray"
    Section = "Magenta"
    Arrow = "White"
}

# Get paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# Timestamp for logs
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logDir = Join-Path $projectRoot "TEST_LOGS"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$qaLogFile = Join-Path $logDir "QA_ORCHESTRATOR_$timestamp.log"

# Initialize log
@"
================================================================================
MiracleBoot QA Orchestrator Report
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Stage: $Stage
Strict Mode: $StrictMode
================================================================================
Project Root: $projectRoot
Log File: $qaLogFile
================================================================================

"@ | Out-File -FilePath $qaLogFile -Encoding UTF8

function Log-Message {
    param([string]$Message)
    Add-Content -Path $qaLogFile -Value $Message
}

function Write-Header {
    param(
        [string]$Text,
        [int]$Width = 76
    )
    
    Write-Host ""
    Write-Host "╔" + ("═" * ($Width - 2)) + "╗" -ForegroundColor $colors.Title
    Write-Host "║ $($Text.PadRight($Width - 4)) ║" -ForegroundColor $colors.Title
    Write-Host "╚" + ("═" * ($Width - 2)) + "╝" -ForegroundColor $colors.Title
    Write-Host ""
    
    Log-Message ""
    Log-Message "╔" + ("═" * ($Width - 2)) + "╗"
    Log-Message "║ $($Text.PadRight($Width - 4)) ║"
    Log-Message "╚" + ("═" * ($Width - 2)) + "╝"
    Log-Message ""
}

function Write-Section {
    param([string]$Text)
    
    Write-Host "► $Text" -ForegroundColor $colors.Section
    Log-Message "► $Text"
}

function Invoke-QAStage {
    param(
        [string]$StageName,
        [string]$ScriptPath,
        [string]$DisplayName
    )
    
    Write-Section "Running: $DisplayName"
    Write-Host "Script: $ScriptPath" -ForegroundColor $colors.Info
    Log-Message "Script: $ScriptPath"
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "ERROR: Script not found at $ScriptPath" -ForegroundColor $colors.Fail
        Log-Message "ERROR: Script not found at $ScriptPath"
        return $false
    }
    
    try {
        # Run script and capture output
        $output = & $ScriptPath 2>&1
        $exitCode = $LASTEXITCODE
        
        # Log all output
        $output | ForEach-Object {
            Log-Message $_
            Write-Host $_
        }
        
        if ($exitCode -eq 0) {
            Write-Host ""
            Write-Host "✓ $DisplayName PASSED" -ForegroundColor $colors.Pass
            Log-Message ""
            Log-Message "✓ $DisplayName PASSED"
            Log-Message ""
            return $true
        } else {
            Write-Host ""
            Write-Host "✗ $DisplayName FAILED (Exit Code: $exitCode)" -ForegroundColor $colors.Fail
            Log-Message ""
            Log-Message "✗ $DisplayName FAILED (Exit Code: $exitCode)"
            Log-Message ""
            return $false
        }
    } catch {
        Write-Host "ERROR executing stage: $_" -ForegroundColor $colors.Fail
        Log-Message "ERROR executing stage: $_"
        return $false
    }
}

# Main execution
Write-Header "MIRACLEBOOT QA ORCHESTRATOR - MASTER TEST COORDINATOR"
Log-Message "MIRACLEBOOT QA ORCHESTRATOR - MASTER TEST COORDINATOR"

Write-Host "Orchestrating QA stages..." -ForegroundColor $colors.Info
Write-Host "Stage Filter: $Stage" -ForegroundColor $colors.Info
Write-Host "Strict Mode: $(if ($StrictMode) { 'ON' } else { 'OFF' })" -ForegroundColor $colors.Info
Write-Host ""

Log-Message "Stage Filter: $Stage"
Log-Message "Strict Mode: $(if ($StrictMode) { 'ON' } else { 'OFF' })"
Log-Message ""

$stageResults = @()
$allPassed = $true

# Stage 1: Syntax Validation
if ($Stage -eq 'all' -or $Stage -eq 'syntax') {
    Write-Header "STAGE 1: SYNTAX VALIDATION"
    Log-Message "════════════════════════════════════════════════════════════════════════"
    Log-Message "STAGE 1: SYNTAX VALIDATION"
    Log-Message "════════════════════════════════════════════════════════════════════════"
    
    $scriptPath = Join-Path $scriptDir "QA_SYNTAX_CHECKER.ps1"
    $passed = Invoke-QAStage -StageName "syntax" -ScriptPath $scriptPath -DisplayName "Syntax Validation"
    $stageResults += @{ Stage = "Syntax Validation"; Passed = $passed }
    
    if (-not $passed -and $StrictMode) {
        $allPassed = $false
        Write-Host ""
        Write-Host "STOPPING: Syntax validation failed in strict mode" -ForegroundColor $colors.Fail
        Log-Message ""
        Log-Message "STOPPING: Syntax validation failed in strict mode"
        Log-Message ""
    }
} else {
    Write-Host "⊘ Syntax Validation: SKIPPED" -ForegroundColor $colors.Warning
    Log-Message "⊘ Syntax Validation: SKIPPED"
}

# Stage 2: Pre-Execution Health Check
if ($Stage -eq 'all' -or $Stage -eq 'health') {
    Write-Header "STAGE 2: PRE-EXECUTION HEALTH CHECK"
    Log-Message "════════════════════════════════════════════════════════════════════════"
    Log-Message "STAGE 2: PRE-EXECUTION HEALTH CHECK"
    Log-Message "════════════════════════════════════════════════════════════════════════"
    
    $scriptPath = Join-Path $scriptDir "PRE_EXECUTION_HEALTH_CHECK.ps1"
    $passed = Invoke-QAStage -StageName "health" -ScriptPath $scriptPath -DisplayName "Pre-Execution Health Check"
    $stageResults += @{ Stage = "Health Check"; Passed = $passed }
    
    if (-not $passed -and $StrictMode) {
        $allPassed = $false
        Write-Host ""
        Write-Host "STOPPING: Health check failed in strict mode" -ForegroundColor $colors.Fail
        Log-Message ""
        Log-Message "STOPPING: Health check failed in strict mode"
        Log-Message ""
    }
} else {
    Write-Host "⊘ Health Check: SKIPPED" -ForegroundColor $colors.Warning
    Log-Message "⊘ Health Check: SKIPPED"
}

# Stage 3: Runtime Functional Tests
if ($Stage -eq 'all' -or $Stage -eq 'runtime') {
    Write-Header "STAGE 3: RUNTIME FUNCTIONAL TESTS"
    Log-Message "════════════════════════════════════════════════════════════════════════"
    Log-Message "STAGE 3: RUNTIME FUNCTIONAL TESTS"
    Log-Message "════════════════════════════════════════════════════════════════════════"
    
    $scriptPath = Join-Path $scriptDir "QA_RUNTIME_TESTS.ps1"
    $passed = Invoke-QAStage -StageName "runtime" -ScriptPath $scriptPath -DisplayName "Runtime Functional Tests"
    $stageResults += @{ Stage = "Runtime Tests"; Passed = $passed }
} else {
    Write-Host "⊘ Runtime Tests: SKIPPED" -ForegroundColor $colors.Warning
    Log-Message "⊘ Runtime Tests: SKIPPED"
}

# Final Report
Write-Header "QA ORCHESTRATOR FINAL REPORT"
Log-Message "════════════════════════════════════════════════════════════════════════"
Log-Message "QA ORCHESTRATOR FINAL REPORT"
Log-Message "════════════════════════════════════════════════════════════════════════"

Write-Host ""
Write-Host "Stage Results:" -ForegroundColor $colors.Section
Log-Message ""
Log-Message "Stage Results:"

foreach ($result in $stageResults) {
    if ($result.Passed) {
        $status = "[PASS]"
        $color = $colors.Pass
    } else {
        $status = "[FAIL]"
        $color = $colors.Fail
    }
    Write-Host "  $status - $($result.Stage)" -ForegroundColor $color
    Log-Message "  $status - $($result.Stage)"
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor $colors.Section
Log-Message ""
Log-Message "Summary:"

$passedCount = ($stageResults | Where-Object { $_.Passed }).Count
$totalStages = $stageResults.Count

Write-Host "  Stages Passed: $passedCount / $totalStages" -ForegroundColor $colors.Info
Write-Host "  Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor $colors.Info
Write-Host "  Log File: $qaLogFile" -ForegroundColor $colors.Info
Log-Message "  Stages Passed: $passedCount / $totalStages"
Log-Message "  Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Log-Message "  Log File: $qaLogFile"

Write-Host ""

if ($passedCount -eq $totalStages) {
    Write-Host "═════════════════════════════════════════════════════════════════════════" -ForegroundColor $colors.Pass
    Write-Host "✓ ALL QA STAGES PASSED - CODE IS PRODUCTION READY" -ForegroundColor $colors.Pass
    Write-Host "═════════════════════════════════════════════════════════════════════════" -ForegroundColor $colors.Pass
    Log-Message ""
    Log-Message "═════════════════════════════════════════════════════════════════════════"
    Log-Message "✓ ALL QA STAGES PASSED - CODE IS PRODUCTION READY"
    Log-Message "═════════════════════════════════════════════════════════════════════════"
    Write-Host ""
    Write-Host "You may safely proceed to testing with users." -ForegroundColor $colors.Pass
    Write-Host ""
    exit 0
} else {
    Write-Host "═════════════════════════════════════════════════════════════════════════" -ForegroundColor $colors.Fail
    Write-Host "✗ QA STAGES FAILED - FIX ERRORS BEFORE PROCEEDING" -ForegroundColor $colors.Fail
    Write-Host "═════════════════════════════════════════════════════════════════════════" -ForegroundColor $colors.Fail
    Log-Message ""
    Log-Message "═════════════════════════════════════════════════════════════════════════"
    Log-Message "✗ QA STAGES FAILED - FIX ERRORS BEFORE PROCEEDING"
    Log-Message "═════════════════════════════════════════════════════════════════════════"
    Write-Host ""
    $logMessage = "Review the log file for details: $qaLogFile"
    Write-Host $logMessage -ForegroundColor $colors.Fail
    Write-Host ""
    exit 1
}
