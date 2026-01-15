# Independent GUI Launch Test Script
# This script tests if the GUI can actually launch without errors

Write-Host "=== GUI Launch Test ===" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "[1/4] Checking prerequisites..." -ForegroundColor Yellow

# Check WPF availability
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop | Out-Null
    Write-Host "  [OK] WPF available" -ForegroundColor Green
    $wpfAvailable = $true
} catch {
    Write-Host "  [FAIL] WPF not available: $_" -ForegroundColor Red
    $wpfAvailable = $false
}

# Check STA thread
$isSta = ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA')
if ($isSta) {
    Write-Host "  [OK] Running in STA thread" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Not running in STA thread" -ForegroundColor Red
}

if (-not $wpfAvailable -or -not $isSta) {
    Write-Host ""
    Write-Host "Prerequisites not met. Cannot test GUI launch." -ForegroundColor Red
    exit 1
}

# Check if files exist
Write-Host ""
Write-Host "[2/4] Checking required files..." -ForegroundColor Yellow

$scriptPath = $PSScriptRoot
if (-not $scriptPath) {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$guiScript = Join-Path $scriptPath "WinRepairGUI.ps1"
$xamlFile = Join-Path $scriptPath "WinRepairGUI.xaml"

if (Test-Path $guiScript) {
    Write-Host "  [OK] WinRepairGUI.ps1 found" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] WinRepairGUI.ps1 not found at: $guiScript" -ForegroundColor Red
    exit 1
}

if (Test-Path $xamlFile) {
    Write-Host "  [OK] WinRepairGUI.xaml found" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] WinRepairGUI.xaml not found at: $xamlFile" -ForegroundColor Red
    exit 1
}

# Test script syntax
Write-Host ""
Write-Host "[3/4] Testing script syntax..." -ForegroundColor Yellow

$syntaxErrors = $null
try {
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $guiScript -Raw), [ref]$syntaxErrors)
    if ($syntaxErrors.Count -eq 0) {
        Write-Host "  [OK] No syntax errors detected" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Syntax errors found:" -ForegroundColor Red
        foreach ($error in $syntaxErrors) {
            Write-Host "    Line $($error.Token.StartLine): $($error.Message)" -ForegroundColor Red
        }
        exit 1
    }
} catch {
    Write-Host "  [FAIL] Syntax check failed: $_" -ForegroundColor Red
    exit 1
}

# Test loading the module
Write-Host ""
Write-Host "[4/4] Testing module loading..." -ForegroundColor Yellow

try {
    # Dot-source the GUI script
    . $guiScript -ErrorAction Stop
    
    # Check if Start-GUI function exists
    if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] Start-GUI function loaded" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Start-GUI function not found after loading" -ForegroundColor Red
        exit 1
    }
    
    # Check if Get-Control function exists
    if (Get-Command Get-Control -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] Get-Control function loaded" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Get-Control function not found after loading" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "=== All Checks Passed ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "The GUI module loaded successfully!" -ForegroundColor Cyan
    Write-Host "You can now try launching the GUI with:" -ForegroundColor Yellow
    Write-Host "  Start-GUI" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: This test does not actually display the GUI window." -ForegroundColor Gray
    Write-Host "      It only verifies that the module can be loaded without errors." -ForegroundColor Gray
    
} catch {
    Write-Host "  [FAIL] Module loading failed: $_" -ForegroundColor Red
    $stackTrace = $_.ScriptStackTrace
    Write-Host "  Stack Trace: $stackTrace" -ForegroundColor Red
    exit 1
}
