$ErrorActionPreference = 'Stop'

function Write-Result {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Details = ""
    )
    $line = "{0,-40} {1}" -f $Name, $Status
    if ($Details) {
        $line += " - $Details"
    }
    Write-Host $line
}

function Invoke-Check {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    try {
        & $Action | Out-Null
        Write-Result -Name $Name -Status "PASS"
        return $true
    } catch {
        Write-Result -Name $Name -Status "FAIL" -Details $_.Exception.Message
        return $false
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot

$corePath = Join-Path $repoRoot "WinRepairCore.ps1"
if (Test-Path -LiteralPath $corePath) {
    . $corePath
} else {
    Write-Result -Name "Load WinRepairCore.ps1" -Status "FAIL" -Details "File not found"
    exit 1
}

$readinessPath = Join-Path $repoRoot "EnsureRepairInstallReady.ps1"
if (Test-Path -LiteralPath $readinessPath) {
    . $readinessPath
}

Write-Host "Non-write task smoke tests"
Write-Host "------------------------------------------------------------"

$allPassed = $true
$allPassed = (Invoke-Check -Name "List Windows Volumes" -Action { Get-WindowsVolumes | Out-String }) -and $allPassed
$allPassed = (Invoke-Check -Name "Scan Storage Drivers" -Action { Get-MissingStorageDevices | Out-String }) -and $allPassed
$allPassed = (Invoke-Check -Name "Boot Issue Mappings" -Action { Get-BootIssueMappings | Out-String }) -and $allPassed

if (Get-Command Test-AdminPrivileges -ErrorAction SilentlyContinue) {
    if (Test-AdminPrivileges) {
        $allPassed = (Invoke-Check -Name "View BCD Entries" -Action { Get-BCDEntries | Out-String }) -and $allPassed
    } else {
        Write-Result -Name "View BCD Entries" -Status "SKIP" -Details "Admin required"
    }
} else {
    Write-Result -Name "View BCD Entries" -Status "SKIP" -Details "Test-AdminPrivileges missing"
}

if (Get-Command Invoke-RepairInstallReadinessCheck -ErrorAction SilentlyContinue) {
    $allPassed = (Invoke-Check -Name "Repair-Install Readiness (Check Only)" -Action { Invoke-RepairInstallReadinessCheck -TargetDrive $env:SystemDrive.TrimEnd(':') -AutoRepair:$false | Out-String }) -and $allPassed
} else {
    Write-Result -Name "Repair-Install Readiness (Check Only)" -Status "SKIP" -Details "Module not available"
}

Write-Host "------------------------------------------------------------"
if ($allPassed) {
    Write-Host "RESULT: PASS"
    exit 0
}

Write-Host "RESULT: FAIL"
exit 2
