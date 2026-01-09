# Test script to simulate Missing Driver Helper without user interaction
# This simulates the button click handler flow

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Missing Driver Helper Simulation Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 0: Load WinRepairCore.ps1
Write-Host "[0/6] Loading WinRepairCore.ps1..." -ForegroundColor Yellow
$corePath = $null

# Try multiple locations
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$possiblePaths = @(
    ".\WinRepairCore.ps1",
    ".\HELPER SCRIPTS\WinRepairCore.ps1",
    ".\Helper\WinRepairCore.ps1",
    (Join-Path $scriptRoot "WinRepairCore.ps1"),
    (Join-Path (Join-Path $scriptRoot "HELPER SCRIPTS") "WinRepairCore.ps1")
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $corePath = $path
        Write-Host "  Found at: $path" -ForegroundColor Gray
        break
    }
}

if (-not $corePath) {
    Write-Host "  [ERROR] WinRepairCore.ps1 not found in any expected location" -ForegroundColor Red
    Write-Host "  Searched:" -ForegroundColor Yellow
    foreach ($path in $possiblePaths) {
        Write-Host "    - $path" -ForegroundColor Gray
    }
    exit 1
}

try {
    . $corePath
    Write-Host "  [OK] WinRepairCore.ps1 loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Failed to load WinRepairCore.ps1: $_" -ForegroundColor Red
    Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 1: Check if required functions exist
Write-Host "[1/6] Checking for required functions..." -ForegroundColor Yellow
$functionsNeeded = @("Get-AdvancedStorageControllerInfo", "Find-MatchingDrivers")
$missingFunctions = @()

foreach ($func in $functionsNeeded) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $func found" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $func not found" -ForegroundColor Red
        $missingFunctions += $func
    }
}

if ($missingFunctions.Count -gt 0) {
    Write-Host ""
    Write-Host "[ERROR] Missing required functions: $($missingFunctions -join ', ')" -ForegroundColor Red
    Write-Host "Please ensure WinRepairCore.ps1 is loaded." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 2: Simulate Get-AdvancedStorageControllerInfo call
Write-Host "[2/6] Calling Get-AdvancedStorageControllerInfo -IncludeNonCritical..." -ForegroundColor Yellow
try {
    $controllers = Get-AdvancedStorageControllerInfo -IncludeNonCritical
    Write-Host "  [OK] Function call succeeded" -ForegroundColor Green
    Write-Host "  Controllers returned: $($controllers.Count)" -ForegroundColor Gray
    
    if ($controllers -and $controllers.Count -gt 0) {
        Write-Host "  Sample controller:" -ForegroundColor Gray
        $sample = $controllers[0]
        Write-Host "    Name: $($sample.Name)" -ForegroundColor Gray
        Write-Host "    NeedsDriver: $($sample.NeedsDriver)" -ForegroundColor Gray
        Write-Host "    HasDriver: $($sample.HasDriver)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  [ERROR] Get-AdvancedStorageControllerInfo failed: $_" -ForegroundColor Red
    Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Check if controllers were returned
Write-Host "[3/6] Validating controller data..." -ForegroundColor Yellow
if (-not $controllers -or $controllers.Count -eq 0) {
    Write-Host "  [INFO] No controllers detected (this is OK for testing)" -ForegroundColor Yellow
    Write-Host "  Simulating scenario: No controllers found" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[TEST COMPLETE] Flow reached end - No controllers scenario" -ForegroundColor Green
    exit 0
}

# Step 4: Check for controllers needing drivers
Write-Host "[4/6] Filtering controllers that need drivers..." -ForegroundColor Yellow
$needsDriver = $controllers | Where-Object { $_.NeedsDriver }
Write-Host "  Controllers needing drivers: $($needsDriver.Count)" -ForegroundColor Gray

# Continue even if no missing drivers - test the full flow
if (-not $needsDriver -or $needsDriver.Count -eq 0) {
    Write-Host "  [INFO] No missing drivers detected - continuing test with all controllers" -ForegroundColor Yellow
    Write-Host "  Using all controllers for testing purposes" -ForegroundColor Gray
    $needsDriver = $controllers | Select-Object -First 5  # Use first 5 for testing
}

# Step 5: Simulate folder dialog (use temp folder for testing)
Write-Host "[5/6] Simulating folder selection..." -ForegroundColor Yellow
$testDriverPath = Join-Path $env:TEMP "TestDriverFolder"
if (-not (Test-Path $testDriverPath)) {
    New-Item -ItemType Directory -Path $testDriverPath -Force | Out-Null
    Write-Host "  Created test folder: $testDriverPath" -ForegroundColor Gray
} else {
    Write-Host "  Using existing test folder: $testDriverPath" -ForegroundColor Gray
}

# Create a dummy INF file for testing
$dummyInf = Join-Path $testDriverPath "test.inf"
if (-not (Test-Path $dummyInf)) {
    @"
[Version]
Signature="$Windows NT$"
Class=System
"@ | Out-File -FilePath $dummyInf -Encoding ASCII
    Write-Host "  Created dummy INF file for testing" -ForegroundColor Gray
}

Write-Host "  [OK] Folder simulation complete" -ForegroundColor Green
Write-Host ""

# Step 6: Call Find-MatchingDrivers
Write-Host "[6/6] Calling Find-MatchingDrivers..." -ForegroundColor Yellow
try {
    Write-Host "  Controller count: $($controllers.Count)" -ForegroundColor Gray
    Write-Host "  Driver path: $testDriverPath" -ForegroundColor Gray
    
    $matchResult = Find-MatchingDrivers -ControllerInfo $controllers -DriverPath $testDriverPath
    Write-Host "  [OK] Find-MatchingDrivers call succeeded" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "  Results:" -ForegroundColor Cyan
    Write-Host "    Matches found: $($matchResult.Matches.Count)" -ForegroundColor Gray
    Write-Host "    Errors: $($matchResult.Errors.Count)" -ForegroundColor Gray
    
    if ($matchResult.Report) {
        Write-Host "    Report length: $($matchResult.Report.Length) characters" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Report preview (first 500 chars):" -ForegroundColor Cyan
        Write-Host "  $($matchResult.Report.Substring(0, [Math]::Min(500, $matchResult.Report.Length)))..." -ForegroundColor White
    } else {
        Write-Host "    [WARNING] Report is empty" -ForegroundColor Yellow
    }
    
    if ($matchResult.Errors.Count -gt 0) {
        Write-Host ""
        Write-Host "  Errors encountered:" -ForegroundColor Yellow
        foreach ($err in $matchResult.Errors) {
            Write-Host "    - $err" -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Host "  [ERROR] Find-MatchingDrivers failed: $_" -ForegroundColor Red
    Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[TEST COMPLETE] Flow reached the very end!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  - All function calls succeeded" -ForegroundColor Green
Write-Host "  - No exceptions thrown" -ForegroundColor Green
Write-Host "  - Output generated successfully" -ForegroundColor Green
Write-Host ""

