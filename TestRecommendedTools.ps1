# Quick test script to verify Recommended Tools tab was added correctly

Write-Host "Testing MiracleBoot v7.2.0 - Recommended Tools Feature" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if GUI file contains the new tab
Write-Host "Test 1: Checking GUI for Recommended Tools tab..." -ForegroundColor Yellow
$guiContent = Get-Content "WinRepairGUI.ps1" -Raw
if ($guiContent -match 'TabItem Header="Recommended Tools"') {
    Write-Host "  ✓ Recommended Tools tab found in GUI" -ForegroundColor Green
} else {
    Write-Host "  ✗ Recommended Tools tab NOT found in GUI" -ForegroundColor Red
}

# Test 2: Check for button handlers
Write-Host ""
Write-Host "Test 2: Checking for button event handlers..." -ForegroundColor Yellow
$buttons = @(
    "BtnVentoyWeb",
    "BtnHirensWeb",
    "BtnAcronisWeb",
    "BtnMacriumWeb",
    "BtnParagonWeb",
    "BtnMacriumFreeWeb",
    "BtnAOMEIFreeWeb",
    "BtnBackupWizard"
)

foreach ($btn in $buttons) {
    if ($guiContent -match "`$$btn.*Add_Click") {
        Write-Host "  ✓ $btn handler found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $btn handler NOT found" -ForegroundColor Red
    }
}

# Test 3: Check TUI for new menu option
Write-Host ""
Write-Host "Test 3: Checking TUI for Recommended Tools menu..." -ForegroundColor Yellow
$tuiContent = Get-Content "WinRepairTUI.ps1" -Raw
if ($tuiContent -match "6\) Recommended Recovery Tools") {
    Write-Host "  ✓ Menu option found in TUI" -ForegroundColor Green
} else {
    Write-Host "  ✗ Menu option NOT found in TUI" -ForegroundColor Red
}

# Test 4: Check for key features
Write-Host ""
Write-Host "Test 4: Checking for key features..." -ForegroundColor Yellow

$features = @{
    "Ventoy section" = "Ventoy - Multi-Boot USB Solution"
    "Hiren's section" = "Hiren's BootCD PE"
    "Medicat section" = "Medicat USB"
    "Macrium section" = "Macrium Reflect"
    "Acronis section" = "Acronis"
    "3-2-1 Backup Rule" = "3-2-1 Backup Rule"
    "Backup Wizard" = "Backup Hardware Wizard"
    "Hardware recommendations" = "Hardware Recommendations for Fast Backups"
}

foreach ($feature in $features.GetEnumerator()) {
    if ($guiContent -match [regex]::Escape($feature.Value)) {
        Write-Host "  ✓ $($feature.Key) found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($feature.Key) NOT found" -ForegroundColor Red
    }
}

# Test 5: Check XAML syntax
Write-Host ""
Write-Host "Test 5: Validating XAML syntax..." -ForegroundColor Yellow
try {
    # Extract XAML from the GUI file
    if ($guiContent -match '(?s)\$XAML\s*=\s*@"(.*?)"@') {
        $xaml = $matches[1]
        [xml]$xmlTest = $xaml
        Write-Host "  ✓ XAML is valid XML" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Could not extract XAML for validation" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ✗ XAML validation failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Testing complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "To see the new features in action:" -ForegroundColor White
Write-Host "  • Run MiracleBoot.ps1 in Full Windows to see the GUI tab" -ForegroundColor Gray
Write-Host "  • Run in WinPE/WinRE to see the TUI menu option" -ForegroundColor Gray
Write-Host ""
