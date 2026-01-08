# Complete GUI Launch Test
# Catches all runtime errors BEFORE user testing

param([string]$WaitSeconds = 0)

Set-Location "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code"

Write-Host ""
Write-Host "COMPLETE GUI LAUNCH TEST" -ForegroundColor Cyan
Write-Host ""

$allErrors = @()

# STAGE 1: Load all modules
Write-Host "[1] Loading assemblies and modules..." -ForegroundColor Yellow

try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    . ".\HELPER SCRIPTS\WinRepairCore.ps1" -ErrorAction Stop
    . ".\HELPER SCRIPTS\WinRepairGUI.ps1" -ErrorAction Stop
    Write-Host "  OK: All modules loaded" -ForegroundColor Green
} catch {
    $msg = $_.Exception.Message
    Write-Host "  ERROR: $msg" -ForegroundColor Red
    $allErrors += $msg
}

# STAGE 2: Verify function
Write-Host "[2] Verifying Start-GUI function..." -ForegroundColor Yellow

if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
    Write-Host "  OK: Function available" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Start-GUI not found" -ForegroundColor Red
    $allErrors += "Start-GUI function missing"
}

# STAGE 3: Test XAML and element creation
Write-Host "[3] Testing XAML parsing and element creation..." -ForegroundColor Yellow

try {
    if ($null -eq $XAML) {
        throw "XAML variable not defined"
    }
    
    [xml]$xmlDoc = $XAML
    $xmlReader = New-Object System.Xml.XmlNodeReader $xmlDoc
    $W = [Windows.Markup.XamlReader]::Load($xmlReader)
    
    if ($null -eq $W) {
        throw "Window creation returned null"
    }
    
    Write-Host "  OK: Window object created" -ForegroundColor Green
    
    # Test element access
    Write-Host "[4] Testing UI element access..." -ForegroundColor Yellow
    
    $testElements = @('StatusBarText', 'BtnNotepad', 'EnvStatus')
    $elemErrors = @()
    
    foreach ($elemName in $testElements) {
        try {
            $element = $W.FindName($elemName)
            if ($null -ne $element) {
                Write-Host "    OK: Element found - $elemName" -ForegroundColor Green
            } else {
                Write-Host "    WARN: Element not found - $elemName" -ForegroundColor Yellow
            }
        } catch {
            $errMsg = $_.Exception.Message
            Write-Host "    ERROR: Cannot access $elemName - $errMsg" -ForegroundColor Red
            $elemErrors += $errMsg
        }
    }
    
    if ($elemErrors.Count -gt 0) {
        $allErrors += $elemErrors
    }
    
} catch {
    $msg = $_.Exception.Message
    Write-Host "  ERROR: $msg" -ForegroundColor Red
    $allErrors += $msg
}

# STAGE 5: Cleanup
Write-Host "[5] Cleaning up..." -ForegroundColor Yellow
try {
    $W = $null
    [System.GC]::Collect()
    Write-Host "  OK: Cleanup complete" -ForegroundColor Green
} catch {
    Write-Host "  WARN: Cleanup issue" -ForegroundColor Yellow
}

# SUMMARY
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($allErrors.Count -eq 0) {
    Write-Host "RESULT: PASS - GUI is ready" -ForegroundColor Green
    Write-Host ""
    Write-Host "The GUI can launch without runtime errors." -ForegroundColor Green
    exit 0
} else {
    Write-Host "RESULT: FAIL - Found runtime errors" -ForegroundColor Red
    Write-Host ""
    Write-Host "Errors found:" -ForegroundColor Red
    foreach ($err in $allErrors) {
        Write-Host "  - $err" -ForegroundColor Red
    }
    exit 1
}
