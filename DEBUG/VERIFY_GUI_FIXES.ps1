# Simple GUI Verification
Write-Host "MiracleBoot GUI Verification" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
Write-Host "Admin: $(if ($isAdmin) { 'YES' } else { 'NO' })"
Write-Host ""

if (-not $isAdmin) {
    Write-Host "ERROR: Must run as administrator" -ForegroundColor Red
    exit 1
}

# Test 1
Write-Host "Test 1: Syntax Check" -ForegroundColor Yellow
try {
    $content = Get-Content .\WinRepairGUI.ps1 -Raw
    [scriptblock]::Create($content) | Out-Null
    Write-Host "  PASS" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: $_" -ForegroundColor Red
    exit 1
}

# Test 2
Write-Host "Test 2: Module Load" -ForegroundColor Yellow
try {
    . .\WinRepairGUI.ps1
    Write-Host "  PASS" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: $_" -ForegroundColor Red
    exit 1
}

# Test 3
Write-Host "Test 3: Start-GUI Exists" -ForegroundColor Yellow
if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
    Write-Host "  PASS" -ForegroundColor Green
} else {
    Write-Host "  FAIL" -ForegroundColor Red
    exit 1
}

# Test 4
Write-Host "Test 4: Add-MiracleBootLog Exists" -ForegroundColor Yellow
if (Get-Command Add-MiracleBootLog -ErrorAction SilentlyContinue) {
    Write-Host "  PASS" -ForegroundColor Green
} else {
    Write-Host "  FAIL" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All tests passed!" -ForegroundColor Green
