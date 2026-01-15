# Simplified GUI launcher

function Start-MiracleBoot-GUI-Safe {
    Write-Host "MiracleBoot GUI Safe Launcher" -ForegroundColor Green
    
    # Step 1: Verify WPF
    Write-Host "[1/4] Verifying WPF assemblies..." -ForegroundColor Cyan
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Write-Host "  V WPF loaded" -ForegroundColor Green
    } catch {
        Write-Host "  ? WPF failed: $_" -ForegroundColor Red
        return $false
    }
    
    # Step 2: Load core
    Write-Host "[2/4] Loading core module..." -ForegroundColor Cyan
    try {
        . (Join-Path $PSScriptRoot "WinRepairCore.ps1")
        Write-Host "  V Core loaded" -ForegroundColor Green
    } catch {
        Write-Host "  ? Core failed: $_" -ForegroundColor Red
        return $false
    }
    
    # Step 3: Load GUI
    Write-Host "[3/4] Loading GUI module..." -ForegroundColor Cyan
    try {
        . (Join-Path $PSScriptRoot "WinRepairGUI.ps1")
        Write-Host "  V GUI loaded" -ForegroundColor Green
    } catch {
        Write-Host "  ? GUI failed: $_" -ForegroundColor Red
        return $false
    }
    
    # Step 4: Launch
    Write-Host "[4/4] Launching GUI..." -ForegroundColor Cyan
    try {
        Start-GUI -ErrorAction Stop
        return $true
    } catch {
        Write-Host "  ? Launch failed: $_" -ForegroundColor Red
        return $false
    }
}

Start-MiracleBoot-GUI-Safe
