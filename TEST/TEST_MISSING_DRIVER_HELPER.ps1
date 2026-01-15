# Test script to simulate Missing Driver Helper without user interaction
# This simulates the full flow to check if it reaches the end

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Missing Driver Helper Simulation Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"
$script:TestOutput = @()
$script:TestErrors = @()

function Write-TestLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"
    $script:TestOutput += $logEntry
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        default { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
}

function Write-TestError {
    param([string]$Message, [Exception]$Exception = $null)
    $script:TestErrors += $Message
    if ($Exception) {
        $script:TestErrors += "Exception: $($Exception.Message)"
        $script:TestErrors += "Stack: $($Exception.StackTrace)"
    }
    Write-TestLog $Message "ERROR"
}

# Step 1: Load WinRepairCore
Write-TestLog "Step 1: Loading WinRepairCore.ps1..."
try {
    $corePath = Join-Path $PSScriptRoot "WinRepairCore.ps1"
    if (-not (Test-Path $corePath)) {
        $corePath = Join-Path $PSScriptRoot "HELPER SCRIPTS" "WinRepairCore.ps1"
    }
    if (-not (Test-Path $corePath)) {
        throw "WinRepairCore.ps1 not found in root or HELPER SCRIPTS directory"
    }
    . $corePath -ErrorAction Stop
    Write-TestLog "WinRepairCore.ps1 loaded successfully" "SUCCESS"
} catch {
    Write-TestError "Failed to load WinRepairCore.ps1" $_
    exit 1
}

# Step 2: Check if required functions exist
Write-TestLog "Step 2: Checking for required functions..."
$requiredFunctions = @("Get-AdvancedStorageControllerInfo", "Find-MatchingDrivers")
$missingFunctions = @()

foreach ($funcName in $requiredFunctions) {
    if (Get-Command $funcName -ErrorAction SilentlyContinue) {
        Write-TestLog "  ✓ $funcName found" "SUCCESS"
    } else {
        Write-TestLog "  ✗ $funcName NOT FOUND" "ERROR"
        $missingFunctions += $funcName
    }
}

if ($missingFunctions.Count -gt 0) {
    Write-TestError "Missing required functions: $($missingFunctions -join ', ')"
    exit 1
}

# Step 3: Simulate the missing driver helper flow
Write-TestLog "Step 3: Starting Missing Driver Helper simulation..."
Write-TestLog "  (Simulating: Analyzing storage/network controllers...)"

try {
    # Step 3a: Get controllers
    Write-TestLog "Step 3a: Calling Get-AdvancedStorageControllerInfo -IncludeNonCritical..."
    $controllers = Get-AdvancedStorageControllerInfo -IncludeNonCritical
    Write-TestLog "  Controllers found: $($controllers.Count)" "SUCCESS"
    
    if (-not $controllers -or $controllers.Count -eq 0) {
        Write-TestLog "  No controllers detected - this is expected in some environments" "WARNING"
        Write-TestLog "  Test will continue with empty controller list"
    } else {
        Write-TestLog "  Controller details:"
        foreach ($controller in $controllers | Select-Object -First 5) {
            Write-TestLog "    - $($controller.Name) | NeedsDriver: $($controller.NeedsDriver) | Status: $($controller.Status)"
        }
    }
    
    # Step 3b: Check for missing drivers
    Write-TestLog "Step 3b: Filtering controllers that need drivers..."
    $needsDriver = $controllers | Where-Object { $_.NeedsDriver }
    Write-TestLog "  Controllers needing drivers: $($needsDriver.Count)"
    
    if (-not $needsDriver -or $needsDriver.Count -eq 0) {
        Write-TestLog "  No missing drivers detected - this is a valid end state" "SUCCESS"
        Write-TestLog "  Simulation would stop here (user would see message)" "INFO"
        Write-TestLog "  ✓ Test completed successfully - reached end without errors" "SUCCESS"
        exit 0
    }
    
    # Step 3c: Simulate folder selection (skip dialog, use temp path)
    Write-TestLog "Step 3c: Simulating driver folder selection..."
    $testDriverPath = Join-Path $env:TEMP "TestDriverFolder"
    if (-not (Test-Path $testDriverPath)) {
        New-Item -ItemType Directory -Path $testDriverPath -Force | Out-Null
        Write-TestLog "  Created test driver folder: $testDriverPath"
    } else {
        Write-TestLog "  Using existing test driver folder: $testDriverPath"
    }
    
    # Step 3d: Call Find-MatchingDrivers
    Write-TestLog "Step 3d: Calling Find-MatchingDrivers..."
    Write-TestLog "  Controller count: $($controllers.Count)"
    Write-TestLog "  Driver path: $testDriverPath"
    
    $matchResult = Find-MatchingDrivers -ControllerInfo $controllers -DriverPath $testDriverPath
    Write-TestLog "  Find-MatchingDrivers completed" "SUCCESS"
    
    # Step 3e: Check result
    Write-TestLog "Step 3e: Analyzing results..."
    Write-TestLog "  Matches found: $($matchResult.Matches.Count)"
    Write-TestLog "  Errors: $($matchResult.Errors.Count)"
    Write-TestLog "  Report length: $($matchResult.Report.Length) characters"
    
    if ($matchResult.Report) {
        Write-TestLog "  Report generated successfully" "SUCCESS"
        # Show first few lines of report
        $reportLines = $matchResult.Report -split "`n" | Select-Object -First 10
        Write-TestLog "  Report preview (first 10 lines):"
        foreach ($line in $reportLines) {
            Write-TestLog "    $line"
        }
    } else {
        Write-TestLog "  No report generated (this may be normal if no matches)" "WARNING"
    }
    
    Write-TestLog "  ✓ Test completed successfully - reached the very end" "SUCCESS"
    
} catch {
    Write-TestError "Missing Driver Helper simulation failed" $_
    Write-TestLog "  Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}

# Final summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total log entries: $($script:TestOutput.Count)" -ForegroundColor White
Write-Host "Errors encountered: $($script:TestErrors.Count)" -ForegroundColor $(if ($script:TestErrors.Count -eq 0) { "Green" } else { "Red" })

if ($script:TestErrors.Count -gt 0) {
    Write-Host ""
    Write-Host "Errors:" -ForegroundColor Red
    foreach ($error in $script:TestErrors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host ""
    Write-Host "✓ All steps completed successfully!" -ForegroundColor Green
    Write-Host "✓ Missing Driver Helper reached the end without errors" -ForegroundColor Green
    exit 0
}

