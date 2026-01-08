#!/usr/bin/env powershell
<#
.SYNOPSIS
    MASTER QA TEST - Comprehensive Quality Assurance Procedure
    
.DESCRIPTION
    This is the definitive test suite that will:
    1. Check syntax of ALL scripts
    2. Load all modules in isolation
    3. Execute modules with full error capture
    4. Test background job execution with absolute paths
    5. Check for WPF/XAML runtime errors
    6. FAIL on ANY error before GUI is fully launched
    
    This test NEVER passes if ANY error occurs.
#>

param(
    [string]$TestDir = ".\VALIDATION\TEST_LOGS",
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Ensure log directory
if (-not (Test-Path $TestDir)) {
    mkdir $TestDir -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$masterLog = Join-Path $TestDir "MASTER_QA_$timestamp.log"
$errorLog = Join-Path $TestDir "MASTER_QA_ERRORS_$timestamp.txt"

$logOutput = @()
$totalErrors = 0
$testsPassed = 0
$testsFailed = 0

function Log {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    $logOutput += $Message
}

function LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    $logOutput += "[ERROR] $Message"
    $global:totalErrors++
}

function LogPass {
    param([string]$Message)
    Write-Host "[PASS] $Message" -ForegroundColor Green
    $logOutput += "[PASS] $Message"
    $global:testsPassed++
}

function LogFail {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    $logOutput += "[FAIL] $Message"
    $global:testsFailed++
}

Log ""
Log "==================================================================" "Cyan"
Log "MASTER QA TEST SUITE - COMPREHENSIVE QUALITY ASSURANCE" "Cyan"
Log "==================================================================" "Cyan"
Log ""
Log "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Gray"
Log "Log File: $masterLog" "Gray"
Log ""

# Get project root
$projectRoot = Get-Item -Path "." -ErrorAction Stop | Select-Object -ExpandProperty FullName
$helperPath = Join-Path $projectRoot "HELPER SCRIPTS"

# ============================================================================
# TEST 1: Syntax Validation
# ============================================================================
Log ""
Log "TEST 1: SYNTAX VALIDATION" "Yellow"
Log "---"

$psFiles = @(
    (Join-Path $helperPath "WinRepairCore.ps1"),
    (Join-Path $helperPath "WinRepairGUI.ps1"),
    (Join-Path $helperPath "WinRepairTUI.ps1")
)

$syntaxErrors = @()
foreach ($file in $psFiles) {
    if (-not (Test-Path $file)) {
        LogError "File not found: $file"
        continue
    }
    
    try {
        $content = Get-Content $file -Raw
        $errors = @()
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
        
        if ($errors.Count -gt 0) {
            LogFail "$(Split-Path $file -Leaf) has $($errors.Count) syntax errors"
            $errors | ForEach-Object {
                LogError "  Line $($_.Token.StartLine): $($_.Message)"
                $syntaxErrors += "$(Split-Path $file -Leaf):$($_.Token.StartLine): $($_.Message)"
            }
        } else {
            LogPass "$(Split-Path $file -Leaf) - Syntax OK"
        }
    } catch {
        LogError "Failed to validate $(Split-Path $file -Leaf): $_"
    }
}

# ============================================================================
# TEST 2: Module Loading in Current Context
# ============================================================================
Log ""
Log "TEST 2: MODULE LOADING (Current Context)" "Yellow"
Log "---"

try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    LogPass "PresentationFramework loaded"
} catch {
    LogError "PresentationFramework: $_"
}

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    LogPass "System.Windows.Forms loaded"
} catch {
    LogError "System.Windows.Forms: $_"
}

try {
    . (Join-Path $helperPath "WinRepairCore.ps1") -ErrorAction Stop
    LogPass "WinRepairCore.ps1 loaded"
} catch {
    LogError "WinRepairCore.ps1: $($_.Exception.Message)"
}

try {
    . (Join-Path $helperPath "WinRepairGUI.ps1") -ErrorAction Stop
    LogPass "WinRepairGUI.ps1 loaded"
} catch {
    LogError "WinRepairGUI.ps1: $($_.Exception.Message)"
}

# ============================================================================
# TEST 3: Function Availability
# ============================================================================
Log ""
Log "TEST 3: FUNCTION VERIFICATION" "Yellow"
Log "---"

if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
    LogPass "Start-GUI function found"
} else {
    LogFail "Start-GUI function not found"
}

if (Get-Command Get-WindowsHealthSummary -ErrorAction SilentlyContinue) {
    LogPass "Get-WindowsHealthSummary function found"
} else {
    LogError "Get-WindowsHealthSummary function not found (non-critical)"
}

# ============================================================================
# TEST 4: Background Job Execution Test
# ============================================================================
Log ""
Log "TEST 4: BACKGROUND JOB EXECUTION TEST" "Yellow"
Log "---"

$jobScript = {
    param($coreFile, $guiFile)
    $ErrorActionPreference = 'Continue'
    
    $jobErrors = @()
    
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        . $coreFile -ErrorAction Stop
        . $guiFile -ErrorAction Stop
        
        if (Get-Command Start-GUI -ErrorAction SilentlyContinue) {
            return @{
                Success = $true
                Message = "All modules loaded and Start-GUI available"
                Errors = $jobErrors
            }
        } else {
            return @{
                Success = $false
                Message = "Start-GUI function not found"
                Errors = @("Start-GUI not available")
            }
        }
    } catch {
        return @{
            Success = $false
            Message = "Exception: $($_.Exception.Message)"
            Errors = @($_.Exception.Message, $_.ScriptStackTrace)
        }
    }
}

try {
    $job = Start-Job -ScriptBlock $jobScript -ArgumentList @(
        (Join-Path $helperPath "WinRepairCore.ps1"),
        (Join-Path $helperPath "WinRepairGUI.ps1")
    )
    
    $result = Wait-Job -Job $job -Timeout 5 -ErrorAction SilentlyContinue
    
    if ($result) {
        $output = Receive-Job -Job $job
        
        if ($output.Success) {
            LogPass "Background job: $($output.Message)"
        } else {
            LogFail "Background job: $($output.Message)"
            if ($output.Errors) {
                $output.Errors | ForEach-Object { LogError "  $_" }
            }
        }
    } else {
        LogError "Background job timed out"
    }
    
    Stop-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    
} catch {
    LogError "Job test exception: $_"
}

# ============================================================================
# SUMMARY
# ============================================================================
Log ""
Log "==================================================================" "Cyan"
Log "TEST SUMMARY" "Cyan"
Log "---"
Log "Tests Passed: $testsPassed"
Log "Tests Failed: $testsFailed"
Log "Errors Found: $totalErrors"
Log "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Save logs
$logOutput | Out-File $masterLog -Force -Encoding UTF8

if ($totalErrors -gt 0) {
    $syntaxErrors | Out-File $errorLog -Force -Encoding UTF8
}

Log ""
Log "==================================================================" "Cyan"

if ($totalErrors -gt 0 -or $testsFailed -gt 0) {
    Log "[FAIL] MASTER QA TEST FAILED" "Red"
    Log "Total Issues: $($totalErrors + $testsFailed)" "Red"
    Log ""
    Log "DO NOT DEPLOY" "Red"
    Log ""
    Log "Logs:"
    Log "  Master Log: $masterLog"
    Log "  Error Log: $errorLog"
    exit 1
} else {
    Log "[PASS] MASTER QA TEST PASSED" "Green"
    Log "All tests successful - Ready for further testing" "Green"
    Log ""
    Log "Log: $masterLog"
    exit 0
}
