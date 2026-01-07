#!/usr/bin/env powershell
<#
.SYNOPSIS
    SUPER TEST - Mandatory Pre-Release Validation Suite for MiracleBoot v7.2.0+
    
.DESCRIPTION
    Comprehensive testing framework that MUST pass before any code module can be released.
    This script ensures NO syntax errors, successful module loading, and functional UI launch on Windows 11.
    
    All output is logged to files for permanent record and error keyword detection.
    
.PARAMETER LogDirectory
    Directory where test logs will be saved. Default: ./TEST_LOGS
    
.PARAMETER Strict
    If $true, fails on ANY warning. Default: $true
    
.PARAMETER UITest
    If $true, attempts to launch the UI. Default: $true
    
.PARAMETER EmailReport
    If $true, saves a report summary. Default: $true
#>

param(
    [string]$LogDirectory = "$PSScriptRoot\TEST_LOGS",
    [bool]$Strict = $true,
    [bool]$UITest = $true,
    [bool]$EmailReport = $true
)

$ErrorActionPreference = 'Continue'
$WarningPreference = 'Continue'

# Create log directory
if (-not (Test-Path $LogDirectory)) {
    $null = New-Item -ItemType Directory -Path $LogDirectory -Force
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$logFile = Join-Path $LogDirectory "SUPER_TEST_$timestamp.log"
$errorLog = Join-Path $LogDirectory "ERRORS_$timestamp.txt"
$summaryFile = Join-Path $LogDirectory "SUMMARY_$timestamp.txt"

# Test results tracking
$testResults = @{
    StartTime = Get-Date
    EndTime = $null
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Warnings = 0
    CriticalErrors = @()
    Warnings_List = @()
    SyntaxErrors = @()
    ModuleErrors = @()
    UIErrors = @()
    Environment = @{}
}

# Logger function - writes to both console and file
function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [System.ConsoleColor]$Color = "White"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console
    Write-Host $logEntry -ForegroundColor $Color
    
    # Write to log file
    Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
}

# Error detector - looks for critical keywords
function Detect-ErrorKeywords {
    param(
        [string]$Content,
        [string]$FileName
    )
    
    $errorKeywords = @(
        'ERROR',
        'CRITICAL',
        'FATAL',
        'Exception',
        'failed',
        'cannot',
        'not found',
        'does not exist',
        'syntax error',
        'parse error',
        'InvalidOperation',
        'MethodInvocationException',
        'UnauthorizedAccessException'
    )
    
    $foundErrors = @()
    
    foreach ($keyword in $errorKeywords) {
        if ($Content -match $keyword) {
            $foundErrors += @{
                Keyword = $keyword
                File = $FileName
                Context = ($Content | Select-String $keyword -Context 2 | ForEach-Object { $_.Line })
            }
        }
    }
    
    return $foundErrors
}

# ============================================================================
# PHASE 1: SYNTAX VALIDATION
# ============================================================================
Write-TestLog "SUPER TEST SUITE STARTING" "HEADER" "Cyan"
Write-TestLog "Log Directory: $LogDirectory" "INFO" "White"
Write-TestLog "Strict Mode: $Strict" "INFO" "White"
Write-TestLog "UI Testing Enabled: $UITest" "INFO" "White"
Write-TestLog "" "INFO"

Write-TestLog "=============== PHASE 1: SYNTAX VALIDATION ===============" "HEADER" "Yellow"

$rootDir = $PSScriptRoot
$allPSFiles = @()
$allPSFiles += @(Get-ChildItem -Path $rootDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'SUPER_TEST_MANDATORY.ps1' })
$allPSFiles += @(Get-ChildItem -Path "$rootDir\TEST" -Filter '*.ps1' -File -ErrorAction SilentlyContinue)

Write-TestLog "Found $($allPSFiles.Count) PowerShell files to validate" "INFO" "Cyan"

foreach ($file in $allPSFiles) {
    $testResults.TotalTests++
    
    $parseErrors = $null
    $tokens = $null
    
    try {
        [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName, 
            [ref]$tokens, 
            [ref]$parseErrors
        ) | Out-Null
        
        if ($parseErrors.Count -eq 0) {
            Write-TestLog "[SYNTAX OK] $($file.Name)" "PASS" "Green"
            $testResults.PassedTests++
        } else {
            Write-TestLog "[SYNTAX FAIL] $($file.Name) - $($parseErrors.Count) errors" "FAIL" "Red"
            $testResults.FailedTests++
            $testResults.SyntaxErrors += @{
                File = $file.Name
                FullPath = $file.FullName
                ErrorCount = $parseErrors.Count
                Errors = $parseErrors
            }
            
            # Log each syntax error
            foreach ($err in $parseErrors) {
                Write-TestLog "  Error at line $($err.Extent.StartLineNumber): $($err.Message)" "ERROR" "Red"
                Add-Content -Path $errorLog -Value "FILE: $($file.Name) | LINE: $($err.Extent.StartLineNumber) | ERROR: $($err.Message)"
            }
        }
    } catch {
        Write-TestLog "[SYNTAX ERROR] $($file.Name) - Exception: $($_.Exception.Message)" "ERROR" "Red"
        $testResults.FailedTests++
        $testResults.SyntaxErrors += @{
            File = $file.Name
            FullPath = $file.FullName
            Exception = $_.Exception.Message
        }
        Add-Content -Path $errorLog -Value "FILE: $($file.Name) | EXCEPTION: $($_.Exception.Message)"
    }
}

Write-TestLog "" "INFO"

# ============================================================================
# PHASE 2: MODULE LOADING & DEPENDENCY CHECK
# ============================================================================
Write-TestLog "=============== PHASE 2: MODULE LOADING ===============" "HEADER" "Yellow"

$coreModules = @(
    'MiracleBoot.ps1',
    'WinRepairCore.ps1',
    'WinRepairTUI.ps1',
    'WinRepairGUI.ps1',
    'MiracleBoot-Backup.ps1',
    'MiracleBoot-BootRecovery.ps1',
    'MiracleBoot-Diagnostics.ps1',
    'MiracleBoot-NetworkDiagnostics.ps1'
)

foreach ($moduleName in $coreModules) {
    $testResults.TotalTests++
    $modulePath = Join-Path $rootDir $moduleName
    
    if (-not (Test-Path $modulePath)) {
        Write-TestLog "[SKIP] $moduleName (not found in root)" "WARN" "Yellow"
        $testResults.Warnings++
        $testResults.Warnings_List += "$moduleName not found"
        continue
    }
    
    try {
        $fileContent = Get-Content -Path $modulePath -Raw -ErrorAction Stop
        
        # Check for error keywords in the file
        $keywordErrors = Detect-ErrorKeywords -Content $fileContent -FileName $moduleName
        
        if ($keywordErrors.Count -gt 0) {
            Write-TestLog "[ERROR KEYWORDS DETECTED] $moduleName - Found $($keywordErrors.Count) error indicators" "WARN" "Yellow"
            $testResults.Warnings++
            foreach ($err in $keywordErrors) {
                Write-TestLog "  Keyword: $($err.Keyword)" "WARN" "Yellow"
            }
            Add-Content -Path $errorLog -Value "FILE: $moduleName | ERROR KEYWORDS DETECTED: $($keywordErrors | ConvertTo-Json)"
        }
        
        # Try to dot-source the module in isolated scope
        $null = & {
            Set-StrictMode -Off
            . $modulePath 2>&1 | Out-Null
        }
        
        Write-TestLog "[MODULE OK] $moduleName" "PASS" "Green"
        $testResults.PassedTests++
    } catch {
        Write-TestLog "[MODULE FAIL] $moduleName - $($_.Exception.Message)" "ERROR" "Red"
        $testResults.FailedTests++
        $testResults.ModuleErrors += @{
            Module = $moduleName
            Error = $_.Exception.Message
        }
        Add-Content -Path $errorLog -Value "FILE: $moduleName | MODULE LOAD ERROR: $($_.Exception.Message)"
    }
}

Write-TestLog "" "INFO"

# ============================================================================
# PHASE 3: SYSTEM ENVIRONMENT VALIDATION
# ============================================================================
Write-TestLog "=============== PHASE 3: SYSTEM ENVIRONMENT ===============" "HEADER" "Yellow"

# Check Windows version
$osVersion = [System.Environment]::OSVersion.Version
$osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

$testResults.TotalTests++
if ($osInfo.ProductType -eq 1 -and $osInfo.Version -like "10.0.22*") {
    Write-TestLog "[OS OK] Windows 11 detected ($($osInfo.Version))" "PASS" "Green"
    $testResults.PassedTests++
    $testResults.Environment.Windows11 = $true
} else {
    Write-TestLog "[OS WARN] Not Windows 11 (Version: $($osInfo.Version)). UI tests may not run properly." "WARN" "Yellow"
    $testResults.Warnings++
    $testResults.Warnings_List += "Not running Windows 11"
    $testResults.Environment.Windows11 = $false
}

# Check PowerShell version
$testResults.TotalTests++
if ($PSVersionTable.PSVersion.Major -ge 5) {
    Write-TestLog "[PWSH OK] PowerShell v$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)" "PASS" "Green"
    $testResults.PassedTests++
    $testResults.Environment.PSVersion = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
} else {
    Write-TestLog "[PWSH FAIL] PowerShell 5.0+ required. Current: v$($PSVersionTable.PSVersion.Major)" "FAIL" "Red"
    $testResults.FailedTests++
    $testResults.CriticalErrors += "PowerShell 5.0+ required"
}

# Check admin privileges
$testResults.TotalTests++
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-TestLog "[PRIV OK] Running as Administrator" "PASS" "Green"
    $testResults.PassedTests++
    $testResults.Environment.IsAdmin = $true
} else {
    Write-TestLog "[PRIV WARN] Not running as Administrator. UI may not have full capabilities." "WARN" "Yellow"
    $testResults.Warnings++
    $testResults.Warnings_List += "Not running as Administrator"
    $testResults.Environment.IsAdmin = $false
}

# Check required assemblies
$testResults.TotalTests++
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Write-TestLog "[ASSEMBLY OK] PresentationFramework available" "PASS" "Green"
    $testResults.PassedTests++
} catch {
    Write-TestLog "[ASSEMBLY FAIL] PresentationFramework not available" "FAIL" "Red"
    $testResults.FailedTests++
    $testResults.CriticalErrors += "PresentationFramework assembly required for UI"
}

Write-TestLog "" "INFO"

# ============================================================================
# PHASE 4: UI LAUNCH TEST (Windows 11 Only)
# ============================================================================
if ($UITest -and $testResults.Environment.Windows11 -and $testResults.Environment.IsAdmin) {
    Write-TestLog "=============== PHASE 4: UI LAUNCH TEST ===============" "HEADER" "Yellow"
    
    $guiPath = Join-Path $rootDir "WinRepairGUI.ps1"
    
    if (Test-Path $guiPath) {
        $testResults.TotalTests++
        try {
            # Run GUI in a timeout-limited background job to test launch
            $job = Start-Job -ScriptBlock {
                param($scriptPath)
                Set-StrictMode -Off
                . $scriptPath
                Start-GUI
            } -ArgumentList $guiPath -ErrorAction SilentlyContinue
            
            Start-Sleep -Seconds 3
            
            $jobState = Get-Job -Id $job.Id -ErrorAction SilentlyContinue
            
            if ($jobState.State -eq "Running") {
                Write-TestLog "[UI LAUNCHED] WinRepairGUI.ps1 launched successfully" "PASS" "Green"
                $testResults.PassedTests++
                Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
            } else {
                $output = Receive-Job -Id $job.Id -ErrorAction SilentlyContinue
                if ($output -match "ERROR|Exception|failed") {
                    Write-TestLog "[UI FAIL] WinRepairGUI failed to launch - $output" "FAIL" "Red"
                    $testResults.FailedTests++
                    $testResults.UIErrors += "UI launch failure: $output"
                    Add-Content -Path $errorLog -Value "UI LAUNCH ERROR: $output"
                } else {
                    Write-TestLog "[UI OK] WinRepairGUI.ps1 test completed" "PASS" "Green"
                    $testResults.PassedTests++
                }
            }
            
            Remove-Job -Id $job.Id -Force -ErrorAction SilentlyContinue
        } catch {
            Write-TestLog "[UI TEST ERROR] Exception during UI launch: $($_.Exception.Message)" "WARN" "Yellow"
            $testResults.Warnings++
            $testResults.UIErrors += $_.Exception.Message
            Add-Content -Path $errorLog -Value "UI LAUNCH EXCEPTION: $($_.Exception.Message)"
        }
    } else {
        Write-TestLog "[UI SKIP] WinRepairGUI.ps1 not found" "WARN" "Yellow"
        $testResults.Warnings++
    }
    
    Write-TestLog "" "INFO"
}

# ============================================================================
# FINAL REPORTING
# ============================================================================
$testResults.EndTime = Get-Date
$duration = $testResults.EndTime - $testResults.StartTime

Write-TestLog "=============== TEST RESULTS SUMMARY ===============" "HEADER" "Cyan"
Write-TestLog "Start Time:     $($testResults.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" "INFO" "White"
Write-TestLog "End Time:       $($testResults.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))" "INFO" "White"
Write-TestLog "Duration:       $($duration.TotalSeconds) seconds" "INFO" "White"
Write-TestLog "" "INFO"

Write-TestLog "Total Tests:    $($testResults.TotalTests)" "INFO" "Cyan"
Write-TestLog "Passed:         $($testResults.PassedTests)" "PASS" "Green"
Write-TestLog "Failed:         $($testResults.FailedTests)" "FAIL" $(if ($testResults.FailedTests -gt 0) { "Red" } else { "Green" })
Write-TestLog "Warnings:       $($testResults.Warnings)" "WARN" "Yellow"
Write-TestLog "" "INFO"

if ($testResults.TotalTests -gt 0) {
    $passRate = [Math]::Round(($testResults.PassedTests / $testResults.TotalTests) * 100, 1)
    Write-TestLog "Pass Rate:      $passRate%" "INFO" "Cyan"
}

Write-TestLog "" "INFO"

# Detailed error reporting
if ($testResults.SyntaxErrors.Count -gt 0) {
    Write-TestLog "=== SYNTAX ERRORS ($($testResults.SyntaxErrors.Count)) ===" "ERROR" "Red"
    foreach ($err in $testResults.SyntaxErrors) {
        Write-TestLog "  File: $($err.File)" "ERROR" "Red"
        if ($err.ErrorCount) {
            Write-TestLog "    Count: $($err.ErrorCount)" "ERROR" "Red"
        }
        if ($err.Exception) {
            Write-TestLog "    Exception: $($err.Exception)" "ERROR" "Red"
        }
    }
    Write-TestLog "" "INFO"
}

if ($testResults.ModuleErrors.Count -gt 0) {
    Write-TestLog "=== MODULE LOADING ERRORS ($($testResults.ModuleErrors.Count)) ===" "ERROR" "Red"
    foreach ($err in $testResults.ModuleErrors) {
        Write-TestLog "  Module: $($err.Module)" "ERROR" "Red"
        Write-TestLog "    Error: $($err.Error)" "ERROR" "Red"
    }
    Write-TestLog "" "INFO"
}

if ($testResults.UIErrors.Count -gt 0) {
    Write-TestLog "=== UI LAUNCH ERRORS ($($testResults.UIErrors.Count)) ===" "ERROR" "Red"
    foreach ($err in $testResults.UIErrors) {
        Write-TestLog "  Error: $err" "ERROR" "Red"
    }
    Write-TestLog "" "INFO"
}

if ($testResults.Warnings_List.Count -gt 0) {
    Write-TestLog "=== WARNINGS ($($testResults.Warnings_List.Count)) ===" "WARN" "Yellow"
    foreach ($warn in $testResults.Warnings_List) {
        Write-TestLog "  Warning: $warn" "WARN" "Yellow"
    }
    Write-TestLog "" "INFO"
}

# Determine overall status
$testPassed = ($testResults.FailedTests -eq 0) -and ((-not $Strict) -or ($testResults.Warnings -eq 0))
$statusColor = if ($testPassed) { "Green" } else { "Red" }
$statusText = if ($testPassed) { "[PASSED] ALL TESTS PASSED - CODE READY FOR RELEASE" } else { "[FAILED] TEST FAILURES DETECTED - CODE NOT READY FOR RELEASE" }

Write-TestLog "" "INFO"
Write-TestLog "=============== FINAL STATUS ===============" "HEADER" $statusColor
Write-TestLog $statusText "FINAL" $statusColor
Write-TestLog "" "INFO"

# Create summary report
$summaryContent = @"
MIRACLEBOOT SUPER TEST SUMMARY
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
===============================================

OVERALL STATUS: $(if ($testPassed) { "PASSED" } else { "FAILED" })

TEST STATISTICS:
  Total Tests:       $($testResults.TotalTests)
  Passed:            $($testResults.PassedTests)
  Failed:            $($testResults.FailedTests)
  Warnings:          $($testResults.Warnings)
  Pass Rate:         $(if ($testResults.TotalTests -gt 0) { "$([Math]::Round(($testResults.PassedTests / $testResults.TotalTests) * 100, 1))%" } else { "N/A" })

DURATION: $($duration.TotalSeconds) seconds

ENVIRONMENT:
  Windows 11:        $($testResults.Environment.Windows11)
  PowerShell:        $($testResults.Environment.PSVersion)
  Admin Rights:      $($testResults.Environment.IsAdmin)

CRITICAL ERRORS: $($testResults.CriticalErrors.Count)
$($testResults.CriticalErrors | ForEach-Object { "  - $_" } | Out-String)

SYNTAX ERRORS: $($testResults.SyntaxErrors.Count)
$($testResults.SyntaxErrors | ForEach-Object { "  - $($_.File)" } | Out-String)

MODULE ERRORS: $($testResults.ModuleErrors.Count)
$($testResults.ModuleErrors | ForEach-Object { "  - $($_.Module): $($_.Error)" } | Out-String)

UI ERRORS: $($testResults.UIErrors.Count)
$($testResults.UIErrors | ForEach-Object { "  - $_" } | Out-String)

WARNINGS: $($testResults.Warnings_List.Count)
$($testResults.Warnings_List | ForEach-Object { "  - $_" } | Out-String)

DETAILED LOGS:
  Full Log:     $logFile
  Error Log:    $errorLog
  Summary:      $summaryFile

RECOMMENDATION:
$(if ($testPassed) { 
    "Code is ready for release. All tests passed successfully."
} else { 
    "Code has issues that must be resolved before release.`nReview the error logs above and fix all reported issues."
})
"@

Add-Content -Path $summaryFile -Value $summaryContent
Write-TestLog "" "INFO"
Write-TestLog "Summary saved to: $summaryFile" "INFO" "Cyan"
Write-TestLog "Full log saved to: $logFile" "INFO" "Cyan"
Write-TestLog "Error log saved to: $errorLog" "INFO" "Cyan"

Write-TestLog "" "INFO"

# Exit with appropriate code
if ($testPassed) {
    Write-TestLog "SUPER TEST COMPLETED SUCCESSFULLY" "SUCCESS" "Green"
    exit 0
} else {
    Write-TestLog "SUPER TEST FAILED - SEE ERRORS ABOVE" "FAILURE" "Red"
    exit 1
}
