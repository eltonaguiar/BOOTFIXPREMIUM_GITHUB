# FINAL QA VERIFICATION - MiracleBoot v7.2.0 GUI Ready ness
# Comprehensive test that verifies GUI launches successfully

Write-Host ""
Write-Host "TEST: FINAL QA VERIFICATION" -ForegroundColor Green
Write-Host ""

$testResults = @()
$rootPath = Split-Path -Parent -Path $PSScriptRoot
$coreFile = Join-Path $rootPath "HELPER SCRIPTS\WinRepairCore.ps1"
$guiFile = Join-Path $rootPath "HELPER SCRIPTS\WinRepairGUI.ps1"

# TEST 1: File existence
Write-Host "[TEST 1] Core Files Exist..." -ForegroundColor Cyan
$filesExist = $true
if (Test-Path $coreFile) {
    Write-Host "  [OK] WinRepairCore.ps1" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] WinRepairCore.ps1" -ForegroundColor Red
    $filesExist = $false
}
if (Test-Path $guiFile) {
    Write-Host "  [OK] WinRepairGUI.ps1" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] WinRepairGUI.ps1" -ForegroundColor Red
    $filesExist = $false
}
$testResults += @{Name="Files Exist"; Result=$filesExist}

# TEST 2: Load assemblies
Write-Host ""
Write-Host "[TEST 2] Load Assemblies..." -ForegroundColor Cyan
$assembliesLoaded = $true
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Write-Host "  [OK] PresentationFramework" -ForegroundColor Green
    Write-Host "  [OK] System.Windows.Forms" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Assembly load failed" -ForegroundColor Red
    $assembliesLoaded = $false
}
$testResults += @{Name="Assemblies Load"; Result=$assembliesLoaded}

# TEST 3: Load GUI module
Write-Host ""
Write-Host "[TEST 3] Load GUI Module..." -ForegroundColor Cyan
$guiLoaded = $true
$global:Error.Clear()
try {
    . $coreFile -ErrorAction Stop
    . $guiFile -ErrorAction Stop
    Write-Host "  [OK] Modules loaded" -ForegroundColor Green
    
    if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] Start-GUI function available" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Start-GUI function not found" -ForegroundColor Red
        $guiLoaded = $false
    }
} catch {
    Write-Host "  [FAIL] Module load failed" -ForegroundColor Red
    $guiLoaded = $false
}
$testResults += @{Name="GUI Module Load"; Result=$guiLoaded}

# TEST 4: Invoke Start-GUI
Write-Host ""
Write-Host "[TEST 4] Invoke Start-GUI Function..." -ForegroundColor Cyan
$guiInvoked = $true
$errorsBefore = $global:Error.Count

Write-Host "  [INFO] Calling Start-GUI..." -ForegroundColor Yellow

try {
    Start-GUI
    Write-Host "  [OK] Start-GUI completed" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Exception during Start-GUI" -ForegroundColor Red
    $guiInvoked = $false
}

$errorsAfter = $global:Error.Count
$errorsAdded = $errorsAfter - $errorsBefore

if ($errorsAdded -eq 0) {
    Write-Host "  [OK] No errors during invocation" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] $errorsAdded error(s) detected" -ForegroundColor Red
    $guiInvoked = $false
}
$testResults += @{Name="GUI Invocation"; Result=$guiInvoked}

# SUMMARY
Write-Host ""
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host ""

$totalTests = $testResults.Count
$passedTests = ($testResults | Where-Object {$_.Result -eq $true}).Count
$failedTests = $totalTests - $passedTests

foreach ($test in $testResults) {
    $icon = if ($test.Result) { "[PASS]" } else { "[FAIL]" }
    $color = if ($test.Result) { "Green" } else { "Red" }
    Write-Host "  $icon $($test.Name)" -ForegroundColor $color
}

Write-Host ""
Write-Host "Total: $totalTests  |  Passed: $passedTests  |  Failed: $failedTests" -ForegroundColor Cyan
Write-Host ""

if ($failedTests -eq 0) {
    Write-Host "SUCCESS: ALL TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILURE: TESTS FAILED" -ForegroundColor Red
    exit 1
}
