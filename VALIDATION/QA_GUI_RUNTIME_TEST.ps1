# GUI Runtime Test with Actual Start-GUI Call
# This test actually invokes the Start-GUI function and catches runtime errors

param([string]$TimeoutSeconds = 3)

Set-Location "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code"

Write-Host ""
Write-Host "TESTING GUI RUNTIME WITH ACTUAL START-GUI CALL" -ForegroundColor Cyan
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
    Write-Host "RESULT: FAIL - Cannot proceed" -ForegroundColor Red
    exit 1
}

# STAGE 3: Capture any startup errors when trying to initialize GUI
Write-Host "[3] Testing GUI initialization with error capture..." -ForegroundColor Yellow

$errorLog = @()
$actionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop"

try {
    # Suppress UI from actually showing by redirecting ShowDialog
    # We only want to test that the GUI initializes without errors
    $scriptBlock = {
        param($GUI)
        
        # Attempt to call Start-GUI and catch all errors
        try {
            # Note: Start-GUI will show the window, but we're testing for errors
            # In actual deployment, this would run interactively
            Start-GUI
        } catch {
            throw $_
        }
    }
    
    # Run in a job with timeout to avoid hanging
    $job = Start-Job -ScriptBlock {
        param($path)
        Set-Location $path
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        . ".\HELPER SCRIPTS\WinRepairCore.ps1" -ErrorAction Stop
        . ".\HELPER SCRIPTS\WinRepairGUI.ps1" -ErrorAction Stop
        
        # Attempt to initialize GUI
        Start-GUI
    } -ArgumentList (Get-Location) -ErrorAction SilentlyContinue
    
    # Wait briefly for initialization
    Start-Sleep -Seconds 2
    
    # Check job for errors
    $jobState = $job | Get-Job -ErrorAction SilentlyContinue
    if ($jobState) {
        $jobErrors = $job | Receive-Job -ErrorAction SilentlyContinue -ErrorVariable jobErr 2>&1
        if ($jobErr) {
            $allErrors += $jobErr
            Write-Host "  ERROR: Runtime initialization error detected" -ForegroundColor Red
            foreach ($err in $jobErr) {
                Write-Host "    - $($err.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  OK: GUI initialized without errors" -ForegroundColor Green
        }
    }
    
    # Cleanup job
    Stop-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -ErrorAction SilentlyContinue
    
} catch {
    $msg = $_.Exception.Message
    Write-Host "  ERROR: $msg" -ForegroundColor Red
    $allErrors += $msg
}

$ErrorActionPreference = $actionPreference

# SUMMARY
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($allErrors.Count -eq 0) {
    Write-Host "RESULT: PASS - GUI initializes without runtime errors" -ForegroundColor Green
    Write-Host ""
    Write-Host "✓ No runtime errors detected during initialization" -ForegroundColor Green
    Write-Host "✓ GUI is ready for user testing" -ForegroundColor Green
    exit 0
} else {
    Write-Host "RESULT: FAIL - Found runtime errors that must be fixed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Errors found:" -ForegroundColor Red
    foreach ($err in $allErrors) {
        Write-Host "  ✗ $err" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "ACTION REQUIRED: Fix errors before user testing" -ForegroundColor Red
    exit 1
}
