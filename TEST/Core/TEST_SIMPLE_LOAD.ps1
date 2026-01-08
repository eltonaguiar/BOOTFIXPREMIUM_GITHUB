# Simple test to load scripts and catch errors
$scriptRoot = "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code"
Set-Location $scriptRoot

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "MiracleBoot Script Load Test (Non-Admin)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Try to load WinRepairCore.ps1 without admin
Write-Host "Test 1: Loading WinRepairCore.ps1..." -ForegroundColor Yellow
try {
    $coreScriptPath = Join-Path $scriptRoot "HELPER SCRIPTS\WinRepairCore.ps1"
    . $coreScriptPath
    Write-Host "[OK] WinRepairCore loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Error loading WinRepairCore:" -ForegroundColor Red
    Write-Host "  $($_)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

# Test 2: Try to load WinRepairGUI.ps1
Write-Host ""
Write-Host "Test 2: Loading WinRepairGUI.ps1..." -ForegroundColor Yellow
try {
    $guiPath = Join-Path $scriptRoot "HELPER SCRIPTS\WinRepairGUI.ps1"
    . $guiPath
    Write-Host "[OK] WinRepairGUI loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Error loading WinRepairGUI:" -ForegroundColor Red
    Write-Host "  $($_)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

# Test 3: Check for Start-GUI function
Write-Host ""
Write-Host "Test 3: Checking for Start-GUI function..." -ForegroundColor Yellow
if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Start-GUI function found" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Start-GUI function NOT FOUND" -ForegroundColor Red
    exit 1
}

# Test 4: Check available functions from WinRepairCore
Write-Host ""
Write-Host "Test 4: Checking WinRepairCore functions..." -ForegroundColor Yellow
$coreFunctions = @(
    "Test-AdminPrivileges",
    "Get-WindowsVolumes",
    "Get-BCDEntries"
)

foreach ($func in $coreFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "[OK] Function '$func' found" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Function '$func' not found (might not be exported)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "All scripts loaded successfully!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now run MiracleBoot.ps1 with administrator privileges." -ForegroundColor Green
Write-Host ""
