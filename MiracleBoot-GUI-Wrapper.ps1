# MiracleBoot-GUI-Wrapper.ps1
# Simplified GUI launcher

function Start-MiracleBoot-GUI-Safe {
    Write-Host "MiracleBoot GUI Safe Launcher" -ForegroundColor Green
    
    # Step 1: Verify WPF
    Write-Host "[1/4] Verifying WPF assemblies..." -ForegroundColor Cyan
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Write-Host "  ✓ WPF loaded" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ WPF failed: \" -ForegroundColor Red
        return \False
    }
    
    # Step 2: Load core
    Write-Host "[2/4] Loading core module..." -ForegroundColor Cyan
    try {
        . ".\Helper\WinRepairCore.ps1" -ErrorAction Stop
        Write-Host "  ✓ Core loaded" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Core failed: \" -ForegroundColor Red
        return \False
    }
    
    # Step 3: Load GUI
    Write-Host "[3/4] Loading GUI module..." -ForegroundColor Cyan
    try {
        . ".\Helper\WinRepairGUI.ps1" -ErrorAction Stop
        Write-Host "  ✓ GUI loaded" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ GUI failed: \" -ForegroundColor Red
        return \False
    }
    
    # Step 4: Launch
    Write-Host "[4/4] Launching GUI..." -ForegroundColor Cyan
    try {
        Start-GUI -ErrorAction Stop
        return \True
    } catch {
        Write-Host "  ✗ Launch failed: \" -ForegroundColor Red
        return \False
    }
}

Start-MiracleBoot-GUI-Safe
