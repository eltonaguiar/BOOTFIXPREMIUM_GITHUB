<#
.SYNOPSIS
HARDENED PRE-FLIGHT VERIFICATION SYSTEM
Prevents false-positive test results before code is marked ready for testing

.DESCRIPTION
This system ensures that:
1. ALL pre-UI execution stages pass (imports, admin check, environment detect)
2. ANY error before UI launch is flagged as CRITICAL
3. Script CANNOT be marked ready if pre-UI checks fail
4. Detailed logging for debugging
5. Return exit code 0 = ALL CLEAR, exit code 1 = CRITICAL FAILURE

.NOTES
CRITICAL RULE: If this returns exit code 1, the code is NOT ready for testing!
This is a BLOCKER. Fix ALL errors before proceeding.

Author: QA Automation System
Date: 2026-01-07
#>

param(
    [switch]$Verbose,
    [string]$LogFile = (Join-Path (Split-Path $PSScriptRoot) "LOGS\PREFLIGHT_$(Get-Date -Format 'yyyyMMdd_HHmmss').log")
)

$logDir = Split-Path $LogFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$script:failures = @()
$script:passes = @()

function Write-PreFlightLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Add-Content -Path $LogFile -Value $logEntry
    
    if ($Verbose -or $Level -in @("ERROR", "CRITICAL", "WARNING")) {
        Write-Host $logEntry -ForegroundColor $(
            switch($Level) {
                "ERROR" { "Red" }
                "CRITICAL" { "Magenta" }
                "WARNING" { "Yellow" }
                "PASS" { "Green" }
                default { "Gray" }
            }
        )
    }
}

function Test-PreFlightCheck {
    param([string]$CheckName, [scriptblock]$TestBlock, [string]$FailureMessage)
    
    try {
        $result = & $TestBlock
        if ($result -eq $true) {
            Write-PreFlightLog "[PASS] $CheckName" "PASS"
            $script:passes += $CheckName
            return $true
        } else {
            Write-PreFlightLog "[FAIL] $CheckName - $FailureMessage" "ERROR"
            $script:failures += $CheckName
            return $false
        }
    } catch {
        Write-PreFlightLog "[CRITICAL] $CheckName - $($_.Exception.Message)" "CRITICAL"
        $script:failures += $CheckName
        return $false
    }
}

Write-PreFlightLog "==============================================================" "INFO"
Write-PreFlightLog "HARDENED PRE-FLIGHT VERIFICATION STARTING" "INFO"
Write-PreFlightLog "==============================================================" "INFO"
Write-PreFlightLog "PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"
Write-PreFlightLog "Log File: $LogFile" "INFO"

Write-PreFlightLog "" "INFO"
Write-PreFlightLog "PHASE 1: ENVIRONMENT AND PRIVILEGES" "INFO"
Write-PreFlightLog "------------------------------------" "INFO"

Test-PreFlightCheck "Administrator Privileges" {
    $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} "Script must run as Administrator" | Out-Null

Test-PreFlightCheck "PowerShell 5.0 or higher" {
    $PSVersionTable.PSVersion.Major -ge 5
} "PowerShell 5.0 or higher required" | Out-Null

Test-PreFlightCheck "Windows OS Detected" {
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem
    $osInfo.Caption -match "Windows"
} "Must run on Windows OS" | Out-Null

Test-PreFlightCheck "64-bit Architecture" {
    [System.Environment]::Is64BitOperatingSystem
} "64-bit Windows required for WPF" | Out-Null

Write-PreFlightLog "" "INFO"
Write-PreFlightLog "PHASE 2: FILE AND PATH VALIDATION" "INFO"
Write-PreFlightLog "------------------------------------" "INFO"

Test-PreFlightCheck "MiracleBoot.ps1 Exists" {
    Test-Path (Join-Path $PSScriptRoot "MiracleBoot.ps1")
} "MiracleBoot.ps1 not found in root" | Out-Null

$helperScripts = @(
    "HELPER SCRIPTS\WinRepairCore.ps1",
    "HELPER SCRIPTS\WinRepairGUI.ps1",
    "HELPER SCRIPTS\WinRepairTUI.ps1"
)

foreach ($script in $helperScripts) {
    $scriptPath = Join-Path $PSScriptRoot $script
    Test-PreFlightCheck "Helper: $(Split-Path $script -Leaf)" {
        Test-Path $scriptPath
    } "Required helper script not found" | Out-Null
}

$requiredFolders = @("HELPER SCRIPTS", "TEST", "LOGS")
foreach ($folder in $requiredFolders) {
    $folderPath = Join-Path $PSScriptRoot $folder
    Test-PreFlightCheck "Folder: $folder" {
        Test-Path -PathType Container $folderPath
    } "Required folder missing" | Out-Null
}

Write-PreFlightLog "" "INFO"
Write-PreFlightLog "PHASE 3: SYNTAX AND IMPORT VALIDATION" "INFO"
Write-PreFlightLog "--------------------------------------" "INFO"

Test-PreFlightCheck "MiracleBoot.ps1 Syntax Valid" {
    $mbPath = Join-Path $PSScriptRoot "MiracleBoot.ps1"
    $errors = $null
    [void][System.Management.Automation.PSParser]::Tokenize((Get-Content $mbPath -Raw), [ref]$errors)
    $errors.Count -eq 0
} "Syntax errors in MiracleBoot.ps1" | Out-Null

foreach ($script in $helperScripts) {
    $scriptPath = Join-Path $PSScriptRoot $script
    Test-PreFlightCheck "Syntax: $(Split-Path $script -Leaf)" {
        $errors = $null
        [void][System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)
        $errors.Count -eq 0
    } "Syntax errors detected" | Out-Null
}

Test-PreFlightCheck "System.Windows.Forms Available" {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    $true
} "System.Windows.Forms not available" | Out-Null

Test-PreFlightCheck "PresentationFramework Available" {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    $true
} "PresentationFramework not available" | Out-Null

Write-PreFlightLog "" "INFO"
Write-PreFlightLog "PHASE 4: WPF AND THREADING VALIDATION" "INFO"
Write-PreFlightLog "--------------------------------------" "INFO"

Test-PreFlightCheck "XamlReader Type Available" {
    $null = [System.Windows.Markup.XamlReader]
    $true
} "XamlReader type not available" | Out-Null

Test-PreFlightCheck "WPF Window Can Be Created" {
    try {
        $window = New-Object System.Windows.Window
        $window.Title = "Test"
        $null = $window
        $true
    } catch {
        $false
    }
} "Cannot create WPF Window object" | Out-Null

Write-PreFlightLog "" "INFO"
Write-PreFlightLog "==============================================================" "INFO"
Write-PreFlightLog "VERIFICATION SUMMARY" "INFO"
Write-PreFlightLog "==============================================================" "INFO"

$totalTests = $script:passes.Count + $script:failures.Count
$passRate = if ($totalTests -gt 0) { [math]::Round(($script:passes.Count / $totalTests) * 100, 1) } else { 0 }

Write-PreFlightLog "Total Tests: $totalTests" "INFO"
Write-PreFlightLog "Passed: $($script:passes.Count)" "PASS"
Write-PreFlightLog "Failed: $($script:failures.Count)" $(if ($script:failures.Count -gt 0) { "CRITICAL" } else { "INFO" })
Write-PreFlightLog "Pass Rate: $passRate percent" "INFO"
Write-PreFlightLog "" "INFO"

if ($script:failures.Count -eq 0) {
    Write-PreFlightLog "ALL PRE-FLIGHT CHECKS PASSED" "PASS"
    Write-PreFlightLog "STATUS: CODE IS READY FOR TESTING" "PASS"
    Write-PreFlightLog "==============================================================" "PASS"
    exit 0
} else {
    Write-PreFlightLog "CRITICAL FAILURES DETECTED" "CRITICAL"
    Write-PreFlightLog "STATUS: CODE IS NOT READY FOR TESTING" "CRITICAL"
    Write-PreFlightLog "" "CRITICAL"
    Write-PreFlightLog "Failed Checks:" "CRITICAL"
    foreach ($failure in $script:failures) {
        Write-PreFlightLog "  - $failure" "CRITICAL"
    }
    Write-PreFlightLog "==============================================================" "CRITICAL"
    exit 1
}
