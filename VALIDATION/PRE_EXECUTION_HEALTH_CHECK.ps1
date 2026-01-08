#!/usr/bin/env powershell
<#
.SYNOPSIS
    Pre-Execution Verification and Health Check
    
.DESCRIPTION
    Comprehensive checks before running MiracleBoot to ensure environment
    is ready and all dependencies are available.
#>

param(
    [switch]$Quick,
    [switch]$Verbose
)

$ErrorActionPreference = 'Continue'

# Color scheme
$colors = @{
    Title = "Cyan"
    Pass = "Green"
    Fail = "Red"
    Warning = "Yellow"
    Info = "Gray"
    Debug = "DarkGray"
}

# Get paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host "`n=======================================================================" -ForegroundColor $colors.Title
Write-Host "PRE-EXECUTION VERIFICATION AND HEALTH CHECK" -ForegroundColor $colors.Title
Write-Host "=======================================================================" -ForegroundColor $colors.Title
Write-Host ""

$checks = @()
$checksPassed = 0
$checksFailed = 0

# Helper function for checks
function Add-Check {
    param(
        [string]$Name,
        [bool]$Result,
        [string]$Message,
        [bool]$Critical = $false
    )
    
    $check = @{
        Name = $Name
        Result = $Result
        Message = $Message
        Critical = $Critical
    }
    
    $global:checks += $check
    
    if ($Result) {
        $global:checksPassed++
    } else {
        $global:checksFailed++
    }
    
    if ($Result) {
        $status = "[OK]"
        $color = $colors.Pass
    } else {
        $status = "[FAIL]"
        $color = $colors.Fail
    }
    Write-Host "$status $Name" -ForegroundColor $color -NoNewline
    if ($Message) {
        Write-Host ": $Message" -ForegroundColor $colors.Info
    } else {
        Write-Host ""
    }
}

# ==== 1. ENVIRONMENT CHECKS ====
Write-Host "`n1. ENVIRONMENT CHECKS" -ForegroundColor $colors.Title
Write-Host "---------------------------------------------------------------------" -ForegroundColor $colors.Info

# Check administrator privileges
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) { $adminMsg = 'administrator' } else { $adminMsg = 'user' }
Add-Check -Name "Administrator Privileges" -Result $isAdmin -Message "Running as $adminMsg" -Critical $true

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
$ps5Plus = $psVersion.Major -ge 5
Add-Check -Name "PowerShell Version" -Result $ps5Plus -Message "v$($psVersion.Major).$($psVersion.Minor)" -Critical $true

# Check operating system
$osInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($osInfo) {
    $isWindows = $osInfo.Caption -match 'Windows'
    Add-Check -Name "Windows Operating System" -Result $isWindows -Message $osInfo.Caption -Critical $true
}

# Check system drive accessibility
$systemDriveOk = Test-Path $env:SystemDrive
Add-Check -Name "System Drive Access" -Result $systemDriveOk -Message "$env:SystemDrive"

# ==== 2. PROJECT STRUCTURE CHECKS ====
Write-Host "`n2. PROJECT STRUCTURE CHECKS" -ForegroundColor $colors.Title
Write-Host "---------------------------------------------------------------------" -ForegroundColor $colors.Info

# Check main entry points
$mainScriptExists = Test-Path (Join-Path $projectRoot "MiracleBoot.ps1")
Add-Check -Name "Main Script (MiracleBoot.ps1)" -Result $mainScriptExists

$launcherExists = Test-Path (Join-Path $projectRoot "RunMiracleBoot.cmd")
Add-Check -Name "CMD Launcher (RunMiracleBoot.cmd)" -Result $launcherExists

# Check helper scripts folder
$helperFolderExists = Test-Path (Join-Path $projectRoot "HELPER SCRIPTS")
Add-Check -Name "HELPER SCRIPTS folder" -Result $helperFolderExists

# Check core modules
$coreScripts = @(
    "WinRepairCore.ps1",
    "WinRepairGUI.ps1",
    "WinRepairTUI.ps1"
)

$coreScriptsOk = $true
foreach ($script in $coreScripts) {
    $path = Join-Path (Join-Path $projectRoot "HELPER SCRIPTS") $script
    $exists = Test-Path $path
    if (-not $exists) {
        $coreScriptsOk = $false
        Write-Host "  [FAIL] Missing: $script" -ForegroundColor $colors.Fail
    }
}
Add-Check -Name "Core Helper Scripts" -Result $coreScriptsOk -Message "$($coreScripts.Count) scripts" -Critical $true

# Check documentation
$docFolderExists = Test-Path (Join-Path $projectRoot "DOCUMENTATION")
Add-Check -Name "DOCUMENTATION folder" -Result $docFolderExists

# Check test suite
$testFolderExists = Test-Path (Join-Path $projectRoot "TEST")
Add-Check -Name "TEST folder" -Result $testFolderExists

# ==== 3. DEPENDENCY CHECKS ====
Write-Host "`n3. DEPENDENCY CHECKS" -ForegroundColor $colors.Title
Write-Host "---------------------------------------------------------------------" -ForegroundColor $colors.Info

# Check WPF availability (needed for GUI)
$wpfAvailable = $true
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop | Out-Null
} catch {
    $wpfAvailable = $false
}
if ($wpfAvailable) { $wpfMsg = 'Available' } else { $wpfMsg = 'Not available - GUI mode disabled' }
Add-Check -Name "WPF Framework" -Result $wpfAvailable -Message $wpfMsg

# Check Windows Forms
$winFormsAvailable = $true
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop | Out-Null
} catch {
    $winFormsAvailable = $false
}
if ($winFormsAvailable) { $winFormsMsg = 'Available' } else { $winFormsMsg = 'Not available' }
Add-Check -Name "Windows Forms" -Result $winFormsAvailable -Message $winFormsMsg

# Check bcdedit availability
$bcdeditAvailable = $null -ne (Get-Command bcdedit -ErrorAction SilentlyContinue)
if ($bcdeditAvailable) { $bcdeditMsg = 'Available' } else { $bcdeditMsg = 'Not found' }
Add-Check -Name "bcdedit Command" -Result $bcdeditAvailable -Message $bcdeditMsg -Critical $true

# Check diskpart availability
$diskpartAvailable = $null -ne (Get-Command diskpart -ErrorAction SilentlyContinue)
if ($diskpartAvailable) { $diskpartMsg = 'Available' } else { $diskpartMsg = 'Not found' }
Add-Check -Name "diskpart Command" -Result $diskpartAvailable -Message $diskpartMsg -Critical $false

# ==== 4. FILE INTEGRITY CHECKS ====
if (-not $Quick) {
    Write-Host "`n4. FILE INTEGRITY CHECKS" -ForegroundColor $colors.Title
    Write-Host "---------------------------------------------------------------------" -ForegroundColor $colors.Info
    
    # Check main script file size
    $mainScript = Get-Item (Join-Path $projectRoot "MiracleBoot.ps1") -ErrorAction SilentlyContinue
    $fileSizeOk = $mainScript -and $mainScript.Length -gt 5KB
    if ($mainScript) { 
        $fileSizeMsg = "$([math]::Round($mainScript.Length/1KB, 2)) KB" 
    } else { 
        $fileSizeMsg = 'N/A' 
    }
    Add-Check -Name "Main Script File Size" -Result $fileSizeOk -Message $fileSizeMsg
    
    # Check for script readability
    $mainScriptReadable = $true
    try {
        $content = Get-Content (Join-Path $projectRoot "MiracleBoot.ps1") -Raw -ErrorAction Stop
        $mainScriptReadable = -not [string]::IsNullOrEmpty($content)
    } catch {
        $mainScriptReadable = $false
    }
    Add-Check -Name "Main Script Readable" -Result $mainScriptReadable
}

# ==== 5. SYSTEM REGISTRY CHECKS ====
Write-Host "`n5. SYSTEM REGISTRY CHECKS" -ForegroundColor $colors.Title
Write-Host "---------------------------------------------------------------------" -ForegroundColor $colors.Info

# Check BCD store accessibility
$bcdAccessible = $true
try {
    $bcdOutput = bcdedit /enum 2>&1
    if ($bcdOutput -match "Access is denied") {
        $bcdAccessible = $false
    }
} catch {
    $bcdAccessible = $false
}
if ($bcdAccessible) { $bcdMsg = 'Accessible' } else { $bcdMsg = 'Access denied - admin may be needed' }
Add-Check -Name "BCD Store Access" -Result $bcdAccessible -Message $bcdMsg -Critical $true

# Check Windows installation
$windowsInstallOk = Test-Path "$env:SystemDrive\Windows\System32"
Add-Check -Name "Windows Installation" -Result $windowsInstallOk -Message "$env:SystemDrive\Windows"

# ==== RESULTS ====
Write-Host "`n=======================================================================" -ForegroundColor $colors.Title
Write-Host "VERIFICATION SUMMARY" -ForegroundColor $colors.Title
Write-Host "=======================================================================" -ForegroundColor $colors.Title
Write-Host ""

Write-Host "Checks Passed: " -NoNewline
Write-Host $checksPassed -ForegroundColor $colors.Pass
Write-Host "Checks Failed: " -NoNewline
if ($checksFailed -eq 0) { 
    Write-Host $checksFailed -ForegroundColor $colors.Pass 
} else { 
    Write-Host $checksFailed -ForegroundColor $colors.Fail 
}
Write-Host "Total Checks: " -NoNewline
Write-Host $checks.Count -ForegroundColor $colors.Info
Write-Host ""

# Check for critical failures
$criticalFailures = $checks | Where-Object { $_.Critical -and -not $_.Result }
if ($criticalFailures.Count -gt 0) {
    Write-Host "[CRITICAL] FAILURES DETECTED:" -ForegroundColor $colors.Fail
    foreach ($failure in $criticalFailures) {
        Write-Host "  - $($failure.Name)" -ForegroundColor $colors.Fail
    }
    Write-Host ""
    Write-Host "These must be resolved before running MiracleBoot." -ForegroundColor $colors.Fail
    Write-Host ""
    exit 1
} else {
    Write-Host "[OK] ALL CRITICAL CHECKS PASSED" -ForegroundColor $colors.Pass
    Write-Host ""
    Write-Host "Environment is ready for MiracleBoot execution." -ForegroundColor $colors.Pass
    Write-Host ""
    exit 0
}

