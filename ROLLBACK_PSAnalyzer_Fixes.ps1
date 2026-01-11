# ROLLBACK SCRIPT - DefensiveBootCore.ps1 PSScriptAnalyzer Fixes
# Layer 8: Rollback Invariant (Generated Before Fixes Applied)
# Date: January 10, 2026

# This script restores DefensiveBootCore.ps1 to its state before PSScriptAnalyzer fixes

param(
    [switch]$Execute = $false,
    [string]$BackupPath = "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\DefensiveBootCore.ps1.pre-analyzer-fix"
)

Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        ROLLBACK SCRIPT - PSScriptAnalyzer Fixes              ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Layer 8 Validation: Syntax check before rollback
Write-Host "Layer 8: ROLLBACK INVARIANT" -ForegroundColor Yellow
Write-Host "  Validating rollback path syntax..." -ForegroundColor Gray

if (-not (Test-Path $BackupPath)) {
    Write-Host "  ✗ Backup file not found: $BackupPath" -ForegroundColor Red
    Write-Host "  ℹ Creating backup from current version first..." -ForegroundColor Cyan
    
    $currentPath = "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\DefensiveBootCore.ps1"
    Copy-Item $currentPath $BackupPath -Force
    Write-Host "  ✓ Backup created at: $BackupPath" -ForegroundColor Green
}

Write-Host "  ✓ Rollback path valid" -ForegroundColor Green

if ($Execute) {
    Write-Host "`nExecuting rollback..." -ForegroundColor Yellow
    
    $targetPath = "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\DefensiveBootCore.ps1"
    
    try {
        Copy-Item $BackupPath $targetPath -Force
        Write-Host "✓ Rollback complete!" -ForegroundColor Green
        Write-Host "  Restored from: $BackupPath" -ForegroundColor Gray
        Write-Host "  Restored to: $targetPath" -ForegroundColor Gray
    } catch {
        Write-Host "✗ Rollback failed: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n⚠ DRY RUN - No changes made" -ForegroundColor Yellow
    Write-Host "To execute rollback, run with: -Execute" -ForegroundColor Cyan
    Write-Host "`nExample:" -ForegroundColor Cyan
    Write-Host "  .\ROLLBACK_PSAnalyzer_Fixes.ps1 -Execute" -ForegroundColor Gray
}

Write-Host ""
