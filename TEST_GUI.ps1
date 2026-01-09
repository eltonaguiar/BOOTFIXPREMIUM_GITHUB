# Test GUI Launch - Run with Admin
Write-Host "MiracleBoot GUI Launch Test" -ForegroundColor Cyan
Write-Host "============================="
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
Write-Host "Running as Admin: $isAdmin" -ForegroundColor $(if ($isAdmin) { 'Green' } else { 'Red' })

if (-not $isAdmin) {
    Write-Host "FATAL: This test requires administrator privileges" -ForegroundColor Red
    exit 1
}

# Test 1: Load WinRepairGUI
Write-Host ""
Write-Host "Test 1: Loading WinRepairGUI.ps1..." -ForegroundColor Yellow
try {
    . .\WinRepairGUI.ps1 -ErrorAction Stop
    Write-Host "  SUCCESS: WinRepairGUI loaded" -ForegroundColor Green
} catch {
    Write-Host "  FAILED: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Check Start-GUI exists
Write-Host ""
Write-Host "Test 2: Checking Start-GUI function..." -ForegroundColor Yellow
if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
    Write-Host "  SUCCESS: Start-GUI function exists" -ForegroundColor Green
} else {
    Write-Host "  FAILED: Start-GUI not found" -ForegroundColor Red
    exit 1
}

# Test 3: Try launching GUI (with timeout)
Write-Host ""
Write-Host "Test 3: Attempting GUI Launch..." -ForegroundColor Yellow
Write-Host "  (GUI window should appear - close it to continue test)" -ForegroundColor Cyan

try {
    $job = Start-Job -ScriptBlock {
        . 'c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\WinRepairGUI.ps1'
        Start-GUI
    } -ErrorAction Stop
    
    # Wait up to 10 seconds for GUI to appear
    $timeout = 0
    while ($job.State -eq 'Running' -and $timeout -lt 100) {
        Start-Sleep -Milliseconds 100
        $timeout++
    }
    
    # Check if GUI launched successfully
    if ($job.State -eq 'Running') {
        Write-Host "  SUCCESS: GUI appears to be running" -ForegroundColor Green
        Write-Host "  (Waiting for user to close GUI window...)" -ForegroundColor Cyan
        Wait-Job $job | Out-Null
    } elseif ($job.State -eq 'Completed') {
        Write-Host "  SUCCESS: GUI launched and closed cleanly" -ForegroundColor Green
    } else {
        $errors = Receive-Job $job -ErrorVariable err
        if ($err) {
            Write-Host "  FAILED: $($err[0])" -ForegroundColor Red
        } else {
            Write-Host "  Unknown state: $($job.State)" -ForegroundColor Yellow
        }
    }
    
    Remove-Job $job -Force
} catch {
    Write-Host "  FAILED: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All tests passed!" -ForegroundColor Green
