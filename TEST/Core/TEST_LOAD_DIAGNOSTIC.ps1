# Test script to diagnose MiracleBoot loading issues
# This script tests the loading of MiracleBoot.ps1 up to the UI initialization stage

Write-Host "" -ForegroundColor Cyan
Write-Host "MiracleBoot Load Diagnostic Test" -ForegroundColor Cyan
Write-Host "" -ForegroundColor Cyan
Write-Host ""

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Test started at: $timestamp" -ForegroundColor Gray

# Check if running as admin
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Admin privileges: $(if ($isAdmin) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($isAdmin) { "Green" } else { "Red" })
Write-Host ""

if (-not $isAdmin) {
    Write-Host "ERROR: This test requires Administrator privileges!" -ForegroundColor Red
    exit 1
}

$scriptRoot = "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code"
Set-Location $scriptRoot
Write-Host "Working directory: $(Get-Location)" -ForegroundColor Gray
Write-Host ""

# Test 1: Check if MiracleBoot.ps1 exists
Write-Host "Test 1: File Existence Check" -ForegroundColor Yellow
$mainScript = "$scriptRoot\MiracleBoot.ps1"
if (Test-Path $mainScript) {
    Write-Host " MiracleBoot.ps1 found" -ForegroundColor Green
} else {
    Write-Host " MiracleBoot.ps1 NOT FOUND" -ForegroundColor Red
    exit 1
}

# Test 2: Check helper scripts
Write-Host ""
Write-Host "Test 2: Helper Scripts Check" -ForegroundColor Yellow
$helperScripts = @(
    "HELPER SCRIPTS\WinRepairCore.ps1",
    "HELPER SCRIPTS\WinRepairGUI.ps1",
    "HELPER SCRIPTS\WinRepairTUI.ps1"
)

foreach ($script in $helperScripts) {
    $path = Join-Path $scriptRoot $script
    if (Test-Path $path) {
        Write-Host " $script found" -ForegroundColor Green
    } else {
        Write-Host " $script NOT FOUND" -ForegroundColor Red
    }
}

# Test 3: Load WinRepairCore.ps1
Write-Host ""
Write-Host "Test 3: Loading WinRepairCore.ps1" -ForegroundColor Yellow
try {
    $coreScriptPath = Join-Path $scriptRoot "HELPER SCRIPTS" "WinRepairCore.ps1"
    . $coreScriptPath
    Write-Host " WinRepairCore.ps1 loaded successfully" -ForegroundColor Green
} catch {
    Write-Host " ERROR loading WinRepairCore.ps1:" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

# Test 4: Load WinRepairGUI.ps1
Write-Host ""
Write-Host "Test 4: Loading WinRepairGUI.ps1" -ForegroundColor Yellow
try {
    $guiPath = Join-Path $scriptRoot "HELPER SCRIPTS" "WinRepairGUI.ps1"
    . $guiPath
    Write-Host " WinRepairGUI.ps1 loaded successfully" -ForegroundColor Green
} catch {
    Write-Host " ERROR loading WinRepairGUI.ps1:" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

# Test 5: Check if Start-GUI function exists
Write-Host ""
Write-Host "Test 5: Function Availability Check" -ForegroundColor Yellow
if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
    Write-Host " Start-GUI function found" -ForegroundColor Green
} else {
    Write-Host " Start-GUI function NOT FOUND" -ForegroundColor Red
}

# Test 6: Test PowerShell and WPF availability
Write-Host ""
Write-Host "Test 6: System Capabilities Check" -ForegroundColor Yellow
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Write-Host " PresentationFramework (WPF) loaded" -ForegroundColor Green
} catch {
    Write-Host " PresentationFramework (WPF) NOT available: $_" -ForegroundColor Yellow
}

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Write-Host " System.Windows.Forms loaded" -ForegroundColor Green
} catch {
    Write-Host " System.Windows.Forms NOT available: $_" -ForegroundColor Yellow
}

# Final summary
Write-Host ""
Write-Host "" -ForegroundColor Cyan
Write-Host "Diagnostic Test Complete" -ForegroundColor Cyan
Write-Host "" -ForegroundColor Cyan
Write-Host ""
Write-Host "All critical components have been tested." -ForegroundColor Green
Write-Host "You can now attempt to run MiracleBoot.ps1" -ForegroundColor Green
Write-Host ""
