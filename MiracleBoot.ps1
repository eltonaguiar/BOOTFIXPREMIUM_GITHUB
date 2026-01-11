<#
.SYNOPSIS
MiracleBoot v7.2.0 - Hardened Windows Recovery Toolkit
Production-grade recovery and diagnostics for Windows 10/11, WinPE, and WinRE

.DESCRIPTION
This script provides medical-grade recovery tooling with:
- Explicit environment detection (FullOS vs WinPE vs Recovery)
- Comprehensive preflight validation before any operations
- Log scanning capability with configurable error patterns
- Structured JSON output for diagnostic clarity
- Fail-safe design: loud failures, never silent degradation
- Zero reliance on modules unavailable in WinPE
- Defensive error handling throughout

.REQUIREMENTS
- Runs as Administrator (verified)
- PowerShell 2.0+ (available in WinPE)
- No external module dependencies
- Relative paths only (respects $PSScriptRoot)

.NOTES
Author: MiracleBoot Team
Version: 7.2.0 (Hardened)
Last Updated: January 2026
#>

param(
    [switch]$SelfTest
)

# Set execution policy with proper error handling
# Note: In some restricted environments, this may fail - we'll handle it gracefully
try {
    $null = Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
} catch {
    # Execution policy may not be available in all environments (e.g., some WinPE)
    # This is not critical if we're already running - continue with warning
    $policyError = $_.Exception.Message
    if ($policyError -notmatch 'CouldNotAutoloadMatchingModule|module could not be loaded') {
        # Only warn if it's not a module loading issue (which is expected in some environments)
        Write-Warning "Could not set execution policy: $policyError (continuing anyway)"
    }
}

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ============================================================================
# SECTION 0: LOGGING SYSTEM (Initialize First)
# ============================================================================

$global:LogPath = $null
$global:ErrorWarningLogPath = $null
$global:LogBuffer = New-Object System.Collections.ArrayList
$global:ErrorCount = 0
$global:WarningCount = 0

function Wait-ForUserContinue {
    <#
    .SYNOPSIS
    Pauses execution so the user can review the console before continuing.
    #>
    param([string]$Message = "Press any key to continue...")

    try {
        Write-Host ""
        Write-Host $Message -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        # If ReadKey is unavailable, fall back to a minimal delay.
        Start-Sleep -Seconds 2
    }
}

function Set-GuiHostForFullOS {
    <#
    .SYNOPSIS
    Ensures the script is running in a GUI-capable host (STA, Windows PowerShell).
    #>
    param([string]$EnvironmentType)

    if ($EnvironmentType -ne 'FullOS') { return }
    if ($env:MIRACLEBOOT_GUI_RELAUNCH -eq '1') { return }

    $isCore = ($PSVersionTable.PSEdition -eq 'Core')
    $isSta = $true
    try { $isSta = ([Threading.Thread]::CurrentThread.ApartmentState -eq 'STA') } catch {}

    if ($isCore -or -not $isSta) {
        Write-WarningLog "GUI host is not STA/Windows PowerShell (PSEdition=$($PSVersionTable.PSEdition), ApartmentState=$([Threading.Thread]::CurrentThread.ApartmentState))"
        Write-Host "[LAUNCH] GUI requires Windows PowerShell (STA). Relaunching with powershell.exe -Sta..." -ForegroundColor Yellow
        Wait-ForUserContinue -Message "Press any key to relaunch in Windows PowerShell (STA) for GUI support..."

        $scriptPath = $PSCommandPath
        if ([string]::IsNullOrEmpty($scriptPath)) { $scriptPath = $MyInvocation.MyCommand.Path }
        if ([string]::IsNullOrEmpty($scriptPath)) {
            Write-ErrorLog "Cannot determine script path for relaunch"
            return
        }

        $env:MIRACLEBOOT_GUI_RELAUNCH = '1'
        try {
            Start-Process -FilePath "powershell.exe" `
                -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Sta", "-File", "`"$scriptPath`"") `
                -WorkingDirectory $script:MiracleBootRoot | Out-Null
            exit 0
        } catch {
            Write-ErrorLog "Failed to relaunch in Windows PowerShell (STA)" -Exception $_
        }
    }
}

function Initialize-LogSystem {
    <#
    .SYNOPSIS
    Initializes the logging system and cleans up old log files.
    #>
    param([string]$ScriptRoot)
    
    # Create logs directory
    $logsDir = Join-Path $ScriptRoot "LOGS_MIRACLEBOOT"
    if (-not (Test-Path -LiteralPath $logsDir)) {
        try {
            $null = New-Item -ItemType Directory -Path $logsDir -Force -ErrorAction Stop
        } catch {
            # Fallback to temp location
            $logsDir = Join-Path $env:TEMP "LOGS_MIRACLEBOOT"
            $null = New-Item -ItemType Directory -Path $logsDir -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Create timestamped log file
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $global:LogPath = Join-Path $logsDir "MiracleBoot_$timestamp.log"
    $global:ErrorWarningLogPath = Join-Path $logsDir "MiracleBoot_ErrorsWarnings_$timestamp.log"
    
    # Clean old log files (older than 7 days)
    try {
        $cutoffDate = (Get-Date).AddDays(-7)
        Get-ChildItem -LiteralPath $logsDir -Filter "MiracleBoot_*.log" -ErrorAction SilentlyContinue | 
            Where-Object { $_.LastWriteTime -lt $cutoffDate } | 
            Remove-Item -Force -ErrorAction SilentlyContinue
    } catch {
        # Silently fail - log cleanup is not critical
    }
    
    # Write initialization header (functions may not be available yet, so use direct file write)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $header = @"
════════════════════════════════════════════════════════════════
MiracleBoot v7.2.0 - Session Started
Timestamp: $timestamp
════════════════════════════════════════════════════════════════
"@
    try {
        Add-Content -LiteralPath $global:LogPath -Value $header -ErrorAction SilentlyContinue
    } catch {
        # If Write-ToLog is available, use it; otherwise just continue
        if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
            Write-ToLog "════════════════════════════════════════════════════════════════" "INFO"
            Write-ToLog "MiracleBoot v7.2.0 - Session Started" "INFO"
            Write-ToLog "Timestamp: $timestamp" "INFO"
            Write-ToLog "════════════════════════════════════════════════════════════════" "INFO"
        }
    }
}

function Get-LogOrigin {
    <#
    .SYNOPSIS
    Attempts to capture the caller origin for error/warning logs.
    #>
    try {
        if (Get-Command Get-PSCallStack -ErrorAction SilentlyContinue) {
            $stack = Get-PSCallStack
            if ($stack.Count -gt 1) {
                $caller = $stack[1]
                if ($caller.ScriptName) {
                    return "$($caller.FunctionName) @ $($caller.ScriptName):$($caller.ScriptLineNumber)"
                }
                return $caller.FunctionName
            }
        }
    } catch {
        # Best-effort only
    }
    return ''
}

function Write-ToLog {
    <#
    .SYNOPSIS
    Writes a message to both console and log file.
    
    .PARAMETER Message
    The message to log
    
    .PARAMETER Level
    Log level: INFO, WARNING, ERROR, DEBUG
    #>
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Add to buffer
    $null = $global:LogBuffer.Add($logEntry)
    
    # Count errors and warnings
    if ($Level -eq 'ERROR') { $global:ErrorCount++ }
    if ($Level -eq 'WARNING') { $global:WarningCount++ }
    
    # Write to file if available
    if ($global:LogPath -and (Test-Path -LiteralPath (Split-Path $global:LogPath))) {
        try {
            Add-Content -LiteralPath $global:LogPath -Value $logEntry -ErrorAction SilentlyContinue
        } catch {
            # Silently fail if can't write to log
        }
    }
    
    # Console output with color
    $color = switch ($Level) {
        'ERROR'   { 'Red' }
        'WARNING' { 'Yellow' }
        'SUCCESS' { 'Green' }
        'DEBUG'   { 'Gray' }
        default   { 'White' }
    }
    
    Write-Host $Message -ForegroundColor $color
}

function Write-ErrorLog {
    <#
    .SYNOPSIS
    Logs an error with context and details.
    #>
    param(
        [string]$Message,
        [object]$Exception = $null,
        [string]$Details = $null
    )
    
    Write-ToLog "ERROR: $Message" "ERROR"
    $origin = Get-LogOrigin
    if ($origin) {
        Write-ToLog "  Origin: $origin" "ERROR"
        if ($global:ErrorWarningLogPath) {
            try { Add-Content -LiteralPath $global:ErrorWarningLogPath -Value "ERROR: $Message | Origin: $origin" -ErrorAction SilentlyContinue } catch {}
        }
    } else {
        if ($global:ErrorWarningLogPath) {
            try { Add-Content -LiteralPath $global:ErrorWarningLogPath -Value "ERROR: $Message" -ErrorAction SilentlyContinue } catch {}
        }
    }
    
    if ($Exception) {
        $exceptionObj = $null
        $errorRecord = $null

        if ($Exception -is [System.Management.Automation.ErrorRecord]) {
            $errorRecord = $Exception
            $exceptionObj = $Exception.Exception
        } elseif ($Exception -is [Exception]) {
            $exceptionObj = $Exception
        } else {
            $exceptionObj = New-Object System.Exception ([string]$Exception)
        }

        if ($exceptionObj) {
            Write-ToLog "  Exception: $($exceptionObj.Message)" "ERROR"
            Write-ToLog "  Category: $($exceptionObj.GetType().Name)" "ERROR"
        }

        if ($errorRecord) {
            if ($errorRecord.FullyQualifiedErrorId) {
                Write-ToLog "  ErrorId: $($errorRecord.FullyQualifiedErrorId)" "ERROR"
            }
            if ($errorRecord.CategoryInfo) {
                Write-ToLog "  CategoryInfo: $($errorRecord.CategoryInfo)" "ERROR"
            }
            if ($errorRecord.InvocationInfo -and $errorRecord.InvocationInfo.PositionMessage) {
                Write-ToLog "  Position: $($errorRecord.InvocationInfo.PositionMessage)" "ERROR"
            }
        }
    }
    
    if ($Details) {
        Write-ToLog "  Details: $Details" "ERROR"
    }
}

function Write-WarningLog {
    <#
    .SYNOPSIS
    Logs a warning message.
    #>
    param([string]$Message)
    
    Write-ToLog "WARNING: $Message" "WARNING"
    $origin = Get-LogOrigin
    if ($origin) {
        Write-ToLog "  Origin: $origin" "WARNING"
        if ($global:ErrorWarningLogPath) {
            try { Add-Content -LiteralPath $global:ErrorWarningLogPath -Value "WARNING: $Message | Origin: $origin" -ErrorAction SilentlyContinue } catch {}
        }
    } else {
        if ($global:ErrorWarningLogPath) {
            try { Add-Content -LiteralPath $global:ErrorWarningLogPath -Value "WARNING: $Message" -ErrorAction SilentlyContinue } catch {}
        }
    }
}

function Export-LogFile {
    <#
    .SYNOPSIS
    Returns the path to the current log file.
    
    .OUTPUTS
    String - Full path to the log file
    #>
    return $global:LogPath
}

function Get-LogSummary {
    <#
    .SYNOPSIS
    Returns a summary of logged errors and warnings.
    
    .OUTPUTS
    PSCustomObject with summary information
    #>
    return @{
        LogFile = $global:LogPath
        ErrorCount = $global:ErrorCount
        WarningCount = $global:WarningCount
        TotalEntries = $global:LogBuffer.Count
        Errors = @($global:LogBuffer | Where-Object { $_ -match '\[ERROR\]' })
        Warnings = @($global:LogBuffer | Where-Object { $_ -match '\[WARNING\]' })
    }
}

function Invoke-SelfTest {
    <#
    .SYNOPSIS
    Runs a non-destructive self-test to validate script health and logging.
    #>
    param([string]$EnvironmentType)

    Write-Host "`n[SELFTEST] Running MiracleBoot self-test..." -ForegroundColor Cyan

    $checks = New-Object System.Collections.ArrayList
    function Add-Check {
        param([string]$Name, [bool]$Passed, [string]$Message, [object]$Details = $null)
        $null = $checks.Add(@{
            Name = $Name
            Passed = $Passed
            Message = $Message
            Details = $Details
        })
    }

    $isAdmin = Test-AdminPrivileges
    Add-Check -Name "Administrator Privileges" -Passed $isAdmin -Message $(if ($isAdmin) { "Running as administrator" } else { "Not running as administrator" })

    $apartmentState = $null
    try { $apartmentState = [Threading.Thread]::CurrentThread.ApartmentState } catch {}
    Add-Check -Name "PowerShell Host" -Passed $true -Message "PSEdition=$($PSVersionTable.PSEdition), ApartmentState=$apartmentState"

    # Required files and syntax checks
    $requiredFiles = @('WinRepairCore.ps1', 'WinRepairTUI.ps1')
    if ($EnvironmentType -eq 'FullOS') {
        $requiredFiles += 'WinRepairGUI.ps1'
    }
    foreach ($file in $requiredFiles) {
        $fileCheck = Test-ScriptFileExists $file
        Add-Check -Name "File exists: $file" -Passed ($fileCheck.Exists -and $fileCheck.Readable) -Message $fileCheck.Error -Details $fileCheck

        $syntaxCheck = Test-ScriptSyntax $file
        Add-Check -Name "Syntax: $file" -Passed $syntaxCheck.Valid -Message $syntaxCheck.Error -Details $syntaxCheck
    }

    # GUI module sanity check (loadable + Start-GUI defined)
    if ($EnvironmentType -eq 'FullOS') {
        try {
            $guiModule = Join-Path $script:MiracleBootRoot "WinRepairGUI.ps1"
            if (Test-Path -LiteralPath $guiModule) {
                . $guiModule
                $hasStartGui = [bool](Get-Command Start-GUI -ErrorAction SilentlyContinue)
                Add-Check -Name "GUI module load" -Passed $hasStartGui -Message $(if ($hasStartGui) { "Start-GUI found" } else { "Start-GUI not found after load" })
            } else {
                Add-Check -Name "GUI module load" -Passed $false -Message "WinRepairGUI.ps1 not found"
            }
        } catch {
            Add-Check -Name "GUI module load" -Passed $false -Message $_.Exception.Message
        }
    }

    # WPF and WinForms availability
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Check -Name "WPF available" -Passed $true -Message "PresentationFramework loaded"
    } catch {
        Add-Check -Name "WPF available" -Passed $false -Message $_.Exception.Message
    }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Check -Name "WinForms available" -Passed $true -Message "System.Windows.Forms loaded"
    } catch {
        Add-Check -Name "WinForms available" -Passed $false -Message $_.Exception.Message
    }

    # Recent log scan
    $logDir = if ($global:LogPath) { Split-Path $global:LogPath } else { Join-Path $env:TEMP "LOGS_MIRACLEBOOT" }
    $recentLogs = @()
    if (Test-Path -LiteralPath $logDir) {
        $recentLogs = Get-ChildItem -LiteralPath $logDir -Filter "MiracleBoot_*.log" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^MiracleBoot_ErrorsWarnings_' } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 3
    }
    $logScan = if ($recentLogs.Count -gt 0) {
        Invoke-LogScanning -LogPaths ($recentLogs | ForEach-Object { $_.FullName })
    } else {
        @{
            LogsScanned = 0
            FindingsCount = 0
            Findings = @()
            Summary = 'No recent log files to scan'
        }
    }

    # Error/Warning log check
    $recentErrorWarning = $null
    if (Test-Path -LiteralPath $logDir) {
        $recentErrorWarning = Get-ChildItem -LiteralPath $logDir -Filter "MiracleBoot_ErrorsWarnings_*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    $errorWarningInfo = @{
        Path = if ($recentErrorWarning) { $recentErrorWarning.FullName } else { '' }
        Exists = [bool]$recentErrorWarning
        Entries = 0
        RecentEntries = @()
    }
    if ($recentErrorWarning) {
        try {
            $lines = Get-Content -LiteralPath $recentErrorWarning.FullName -ErrorAction Stop
            $errorWarningInfo.Entries = $lines.Count
            $errorWarningInfo.RecentEntries = @($lines | Select-Object -Last 15)
        } catch {
            $errorWarningInfo.RecentEntries = @("Failed to read error/warning log: $($_.Exception.Message)")
        }
    }

    $summary = @{
        Total = $checks.Count
        Passed = ($checks | Where-Object { $_.Passed }).Count
        Failed = ($checks | Where-Object { -not $_.Passed }).Count
    }

    $report = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        EnvironmentType = $EnvironmentType
        SystemDrive = $env:SystemDrive
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PSEdition = $PSVersionTable.PSEdition
        ApartmentState = $apartmentState
        Checks = $checks
        Summary = $summary
        LogScan = $logScan
        ErrorWarningLog = $errorWarningInfo
    }

    $reportDir = if ($global:LogPath) { Split-Path $global:LogPath } else { Join-Path $env:TEMP "LOGS_MIRACLEBOOT" }
    if (-not (Test-Path -LiteralPath $reportDir)) {
        $null = New-Item -ItemType Directory -Path $reportDir -Force -ErrorAction SilentlyContinue
    }
    $reportPath = Join-Path $reportDir ("MiracleBoot_SelfTest_{0}.json" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    $json = ConvertTo-SafeJson -InputObject $report -Depth 6
    $json | Out-File -LiteralPath $reportPath -Encoding ASCII

    Write-Host "[SELFTEST] Complete. Passed $($summary.Passed)/$($summary.Total) checks." -ForegroundColor Green
    Write-Host "[SELFTEST] Report: $reportPath" -ForegroundColor Gray
    if ($logScan.FindingsCount -gt 0) {
        Write-Host "[SELFTEST] Log scan found $($logScan.FindingsCount) issue(s)." -ForegroundColor Yellow
    }
    if (-not $errorWarningInfo.Exists) {
        Write-Host "[SELFTEST] Error/Warning log not found. This run will create it as needed." -ForegroundColor Yellow
    }

    return $report
}

# ============================================================================
# SECTION 1: CORE DIAGNOSTICS & VALIDATION FUNCTIONS
# ============================================================================

function ConvertTo-SafeJson {
    <#
    .SYNOPSIS
    Converts a PowerShell object to JSON (compatible with PS 2.0+)
    #>
    param($InputObject, [int]$Depth = 4)
    
    function ConvertToJsonInternal($obj, [int]$d) {
        if ($d -le 0) { return '{}' }
        if ($null -eq $obj) { return 'null' }
        
        $type = $obj.GetType().Name
        
        if ($type -eq 'Hashtable' -or $type -eq 'PSCustomObject') {
            $pairs = @()
            foreach ($key in $obj.Keys) {
                $value = $obj[$key]
                $jsonValue = ConvertToJsonInternal $value ($d - 1)
                $pairs += "`"$key`": $jsonValue"
            }
            return "{$($pairs -join ', ')}"
        }
        elseif ($type -like '*\[\]' -or $type -eq 'Object[]') {
            $items = @()
            foreach ($item in $obj) {
                $items += ConvertToJsonInternal $item ($d - 1)
            }
            return "[$($items -join ', ')]"
        }
        elseif ($obj -is [System.Boolean]) {
            return $obj.ToString().ToLower()
        }
        elseif ($obj -is [System.String]) {
            return "`"$($obj.Replace('"', '\"'))`""
        }
        else {
            return $obj.ToString()
        }
    }
    
    return ConvertToJsonInternal $InputObject $Depth
}

function New-GUIFailureDiagnosticReport {
    param(
        [string]$FailureReason,
        [string]$ErrorMessage,
        [string]$InnerException,
        [string]$StackTrace,
        [string]$Location,
        [string]$WpfAvailable = "Unknown",
        [string]$StaThread = "Unknown",
        [string]$EnvironmentType = "Unknown"
    )
    
    $logDir = Join-Path $script:MiracleBootRoot "LOGS_MIRACLEBOOT"
    if (-not (Test-Path $logDir)) { 
        try { 
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null 
        } catch { 
            $logDir = $env:TEMP
        }
    }
    
    $reportPath = Join-Path $logDir "GUI_FAILURE_DIAGNOSTIC_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $report = @()
    
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "GUI LAUNCH FAILURE - DIAGNOSTIC REPORT"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    $report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $report += "This report contains information to help investigate why the GUI failed to launch."
    $report += ""
    
    # SHORT SUMMARY (for quick typing)
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "SHORT SUMMARY (Quick Copy-Paste)"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    $report += "GUI failed: $FailureReason"
    $report += "Error: $ErrorMessage"
    if ($Location) {
        $report += "Location: $Location"
    }
    $report += "Environment: $EnvironmentType | WPF: $WpfAvailable | STA: $StaThread"
    $report += ""
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    
    # DETAILED INFORMATION
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "DETAILED FAILURE INFORMATION"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    $report += "FAILURE REASON:"
    $report += "  $FailureReason"
    $report += ""
    $report += "ERROR MESSAGE:"
    $report += "  $ErrorMessage"
    $report += ""
    
    if ($InnerException) {
        $report += "INNER EXCEPTION:"
        $report += "  $InnerException"
        $report += ""
    }
    
    if ($Location) {
        $report += "FAILURE LOCATION:"
        $report += "  $Location"
        $report += ""
    }
    
    if ($StackTrace) {
        $report += "STACK TRACE:"
        $report += "  $StackTrace"
        $report += ""
    }
    
    # SYSTEM INFORMATION
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "SYSTEM INFORMATION"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    
    try {
        $report += "Operating System:"
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $report += "  Name: $($os.Caption)"
            $report += "  Version: $($os.Version)"
            $report += "  Build: $($os.BuildNumber)"
            $report += "  Architecture: $($os.OSArchitecture)"
        } else {
            $report += "  (Could not retrieve OS information)"
        }
        $report += ""
    } catch {
        $report += "  (OS information retrieval failed: $($_.Exception.Message))"
        $report += ""
    }
    
    try {
        $report += "PowerShell Version:"
        $report += "  $($PSVersionTable.PSVersion)"
        $report += "  Edition: $($PSVersionTable.PSEdition)"
        $report += "  Execution Policy: $(Get-ExecutionPolicy -ErrorAction SilentlyContinue)"
        $report += ""
    } catch {
        $report += "  (PowerShell version retrieval failed)"
        $report += ""
    }
    
    $report += "Environment Type: $EnvironmentType"
    $report += "WPF Available: $WpfAvailable"
    $report += "STA Thread: $StaThread"
    $report += ""
    
    try {
        $report += "System Drive: $env:SystemDrive"
        $report += "User Profile: $env:USERPROFILE"
        $report += "Temp Directory: $env:TEMP"
        $report += ""
    } catch {
        $report += "  (Environment variable retrieval failed)"
        $report += ""
    }
    
    # FILE SYSTEM CHECKS
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "FILE SYSTEM CHECKS"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    
    $guiFile = Join-Path $script:MiracleBootRoot "WinRepairGUI.ps1"
    $xamlFile = Join-Path $script:MiracleBootRoot "WinRepairGUI.xaml"
    
    $report += "WinRepairGUI.ps1:"
    if (Test-Path $guiFile) {
        $guiInfo = Get-Item $guiFile -ErrorAction SilentlyContinue
        if ($guiInfo) {
            $report += "  ✓ Found at: $guiFile"
            $report += "  Size: $($guiInfo.Length) bytes"
            $report += "  Last Modified: $($guiInfo.LastWriteTime)"
        } else {
            $report += "  ✗ File exists but cannot read properties"
        }
    } else {
        $report += "  ✗ NOT FOUND at: $guiFile"
    }
    $report += ""
    
    $report += "WinRepairGUI.xaml:"
    if (Test-Path $xamlFile) {
        $xamlInfo = Get-Item $xamlFile -ErrorAction SilentlyContinue
        if ($xamlInfo) {
            $report += "  ✓ Found at: $xamlFile"
            $report += "  Size: $($xamlInfo.Length) bytes"
            $report += "  Last Modified: $($xamlInfo.LastWriteTime)"
        } else {
            $report += "  ✗ File exists but cannot read properties"
        }
    } else {
        $report += "  ✗ NOT FOUND at: $xamlFile"
    }
    $report += ""
    
    # WPF ASSEMBLY CHECKS
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "WPF ASSEMBLY CHECKS"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    
    $wpfAssemblies = @(
        "PresentationFramework",
        "PresentationCore",
        "WindowsBase",
        "System.Xaml"
    )
    
    foreach ($assembly in $wpfAssemblies) {
        try {
            $asm = [System.Reflection.Assembly]::LoadWithPartialName($assembly)
            if ($asm) {
                $report += "  ✓ $assembly - Loaded (Version: $($asm.GetName().Version))"
            } else {
                $report += "  ✗ $assembly - NOT LOADED"
            }
        } catch {
            $report += "  ✗ $assembly - ERROR: $($_.Exception.Message)"
        }
    }
    $report += ""
    
    # LOG FILE LOCATION
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "LOG FILES"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    
    if ($global:LogPath -and (Test-Path $global:LogPath)) {
        $report += "Main Log File:"
        $report += "  $global:LogPath"
        $logInfo = Get-Item $global:LogPath -ErrorAction SilentlyContinue
        if ($logInfo) {
            $report += "  Size: $($logInfo.Length) bytes"
            $report += "  Last Modified: $($logInfo.LastWriteTime)"
        }
    } else {
        $report += "Main Log File: Not found or not set"
    }
    $report += ""
    
    $report += "This Diagnostic Report:"
    $report += "  $reportPath"
    $report += ""
    
    # TROUBLESHOOTING SUGGESTIONS
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "TROUBLESHOOTING SUGGESTIONS"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    
    if ($WpfAvailable -eq "No") {
        $report += "WPF is not available. Possible causes:"
        $report += "  • Running PowerShell Core (pwsh) instead of Windows PowerShell"
        $report += "  • Missing .NET Framework 4.x or later"
        $report += "  • Corrupted WPF assemblies"
        $report += ""
        $report += "Solutions:"
        $report += "  1. Try running with: powershell.exe (not pwsh.exe)"
        $report += "  2. Install/repair .NET Framework 4.8 or later"
        $report += "  3. Run: sfc /scannow to repair system files"
        $report += ""
    }
    
    if ($StaThread -eq "No") {
        $report += "STA thread requirement not met. Possible causes:"
        $report += "  • Running PowerShell without -Sta parameter"
        $report += "  • PowerShell Core doesn't support STA mode"
        $report += ""
        $report += "Solutions:"
        $report += "  1. Run with: powershell.exe -Sta -File MiracleBoot.ps1"
        $report += "  2. Use Windows PowerShell (not PowerShell Core)"
        $report += ""
    }
    
    if (-not (Test-Path $guiFile)) {
        $report += "WinRepairGUI.ps1 not found. Possible causes:"
        $report += "  • File was moved or deleted"
        $report += "  • Running from wrong directory"
        $report += ""
        $report += "Solutions:"
        $report += "  1. Verify file exists in: $script:MiracleBootRoot"
        $report += "  2. Re-download MiracleBoot if file is missing"
        $report += ""
    }
    
    if (-not (Test-Path $xamlFile)) {
        $report += "WinRepairGUI.xaml not found. Possible causes:"
        $report += "  • File was moved or deleted"
        $report += "  • Running from wrong directory"
        $report += ""
        $report += "Solutions:"
        $report += "  1. Verify file exists in: $script:MiracleBootRoot"
        $report += "  2. Re-download MiracleBoot if file is missing"
        $report += ""
    }
    
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "HOW TO REPORT THIS ISSUE"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    $report += "Please provide the following information when reporting this issue:"
    $report += ""
    $report += "1. Copy the 'SHORT SUMMARY' section above (for quick reporting)"
    $report += "2. OR attach this entire file: $reportPath"
    $report += "3. Include any additional context about:"
    $report += "   • What you were trying to do when this happened"
    $report += "   • Any recent system changes (updates, software installs, etc.)"
    $report += "   • Whether this is the first time or a recurring issue"
    $report += ""
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "END OF DIAGNOSTIC REPORT"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    
    Set-Content -Path $reportPath -Value ($report -join "`r`n") -Encoding UTF8 -Force
    
    # Open in Notepad
    try {
        Start-Process notepad.exe -ArgumentList "`"$reportPath`""
    } catch {
        # If Notepad fails, at least show the path
        Write-Host "Could not open Notepad. Report saved to: $reportPath" -ForegroundColor Yellow
    }
    
    return $reportPath
}

function New-DiagnosticReport {
    <#
    .SYNOPSIS
    Creates a structured diagnostic report object
    #>
    param(
        [string]$Title,
        [ValidateSet('Pass', 'Warning', 'Fail')]
        [string]$Status = 'Pass',
        [string]$Message = '',
        [array]$Details = @(),
        [hashtable]$Metadata = @{}
    )
    
    return @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Title = $Title
        Status = $Status
        Message = $Message
        Details = $Details
        Metadata = $Metadata
    }
}

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
    Validates that the script is running with administrator privileges.
    
    .OUTPUTS
    Boolean - $true if admin, $false otherwise
    #>
    try {
        $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Get-EnvironmentType {
    <#
    .SYNOPSIS
    Detects current Windows environment with high confidence.
    
    .OUTPUTS
    String: 'FullOS', 'WinPE', or 'WinRE'
    
    .NOTES
    Logic:
    1. SystemDrive = X: → Recovery environment
    2. MiniNT registry present → WinPE
    3. Otherwise → FullOS
    #>
    
    # Check 1: SystemDrive (most reliable)
    if ($env:SystemDrive -eq 'X:') {
        # We're in a recovery environment
        if (Test-Path 'HKLM:\System\CurrentControlSet\Control\MiniNT' -ErrorAction SilentlyContinue) {
            return 'WinPE'
        }
        # Check Setup key for WinRE marker
        if (Test-Path 'HKLM:\System\Setup' -ErrorAction SilentlyContinue) {
            $setupType = (Get-ItemProperty -Path 'HKLM:\System\Setup' -Name 'CmdLine' -ErrorAction SilentlyContinue).CmdLine
            if ($setupType -match 'recovery|WinRE') {
                return 'WinRE'
            }
        }
        return 'WinRE' # Default to WinRE on X: drive
    }
    
    # Check 2: MiniNT in FullOS (edge case)
    if (Test-Path 'HKLM:\System\CurrentControlSet\Control\MiniNT' -ErrorAction SilentlyContinue) {
        if ($env:SystemDrive -eq 'X:') {
            return 'WinPE'
        }
    }
    
    # Check 3: Standard FullOS
    if ($env:SystemDrive -ne 'X:' -and (Test-Path "$env:SystemDrive\Windows" -ErrorAction SilentlyContinue)) {
        return 'FullOS'
    }
    
    # Fallback: assume FullOS (safer)
    return 'FullOS'
}

function Get-FirmwareType {
    <#
    .SYNOPSIS
    Detects firmware type using Windows registry (UEFI vs BIOS).
    #>
    try {
        $fw = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'PEFirmwareType' -ErrorAction Stop).PEFirmwareType
        switch ($fw) {
            2 { return 'UEFI' }
            1 { return 'BIOS' }
            default { return 'Unknown' }
        }
    } catch {
        return 'Unknown'
    }
}

function Get-EfiSystemPartitionInfo {
    <#
    .SYNOPSIS
    Attempts to locate EFI System Partitions (ESP) on GPT disks.
    #>
    $result = @{
        Available = $false
        Count = 0
        Partitions = @()
        Message = ''
    }

    $cmd = Test-CommandExists 'Get-Partition'
    if (-not $cmd.Available) {
        $result.Message = 'Get-Partition not available'
        return $result
    }

    try {
        $espGuid = '{C12A7328-F81F-11D2-BA4B-00A0C93EC93B}'
        $parts = Get-Partition -ErrorAction Stop | Where-Object {
            $_.GptType -eq $espGuid -or $_.Type -eq 'System'
        }
        $result.Available = $true
        $result.Count = $parts.Count
        $result.Partitions = $parts | Select-Object DiskNumber, PartitionNumber, Size, GptType, Type
        $result.Message = if ($result.Count -gt 0) { 'ESP detected' } else { 'ESP not found' }
        return $result
    } catch {
        $result.Message = $_.Exception.Message
        return $result
    }
}

function Test-ScriptFileExists {
    <#
    .SYNOPSIS
    Validates that required script files exist and are readable.
    
    .PARAMETER FilePath
    Path relative to $PSScriptRoot
    
    .OUTPUTS
    Hashtable with Path, Exists, Readable, Size properties
    #>
    param([string]$FilePath)
    
    $fullPath = Join-Path $script:MiracleBootRoot $FilePath
    
    $result = @{
        FileName = $FilePath
        FullPath = $fullPath
        Exists = Test-Path -LiteralPath $fullPath -ErrorAction SilentlyContinue
        Readable = $false
        Size = 0
        Error = ''
    }
    
    if ($result.Exists) {
        try {
            $fileInfo = Get-Item -LiteralPath $fullPath -ErrorAction Stop
            $result.Size = $fileInfo.Length
            # Test readability
            $null = Get-Content -LiteralPath $fullPath -TotalCount 1 -ErrorAction Stop
            $result.Readable = $true
        } catch {
            $result.Error = $_.Exception.Message
        }
    }
    
    return $result
}

function Test-ScriptSyntax {
    <#
    .SYNOPSIS
    Validates that a script file parses without syntax errors.
    
    .PARAMETER FilePath
    Path relative to $PSScriptRoot
    
    .OUTPUTS
    Hashtable with Valid, Error properties
    #>
    param([string]$FilePath)
    
    $fullPath = Join-Path $script:MiracleBootRoot $FilePath
    
    $result = @{
        FileName = $FilePath
        FullPath = $fullPath
        Valid = $false
        Error = ''
    }
    
    if (-not (Test-Path -LiteralPath $fullPath -ErrorAction SilentlyContinue)) {
        $result.Error = 'File not found'
        return $result
    }
    
    try {
        $content = Get-Content -LiteralPath $fullPath -Raw -ErrorAction Stop
        $parseErrors = $null
        [System.Management.Automation.PSParser]::Tokenize($content, [ref]$parseErrors) | Out-Null
        if ($parseErrors -and $parseErrors.Count -gt 0) {
            $result.Error = $parseErrors[0].Message
        } else {
            $result.Valid = $true
        }
    } catch {
        $result.Error = $_.Exception.Message
    }
    
    return $result
}

function Test-CommandExists {
    <#
    .SYNOPSIS
    Validates that a command is available in the current environment.
    
    .OUTPUTS
    Hashtable with Command, Available, Version properties
    #>
    param([string]$CommandName)
    
    $result = @{
        Command = $CommandName
        Available = $false
        Version = ''
        Error = ''
    }
    
    try {
        $cmd = Get-Command -Name $CommandName -ErrorAction Stop
        $result.Available = $true
        if ($cmd.Version) {
            $result.Version = $cmd.Version.ToString()
        }
    } catch {
        $result.Error = $_.Exception.Message
    }
    
    return $result
}

function Get-BitLockerStatus {
    <#
    .SYNOPSIS
    Retrieves BitLocker status for a drive when tools are available.
    #>
    param([string]$DriveLetter = $env:SystemDrive)

    $result = @{
        Available = $false
        Drive = $DriveLetter
        ProtectionStatus = 'Unknown'
        LockStatus = 'Unknown'
        Message = ''
    }

    if (-not $DriveLetter) {
        $result.Message = 'No drive letter provided'
        return $result
    }

    $bitlockerCmd = Test-CommandExists 'Get-BitLockerVolume'
    if ($bitlockerCmd.Available) {
        try {
            $info = Get-BitLockerVolume -MountPoint $DriveLetter -ErrorAction Stop
            $result.Available = $true
            $result.ProtectionStatus = if ($info.ProtectionStatus -eq 'On') { 'On' } else { 'Off' }
            $result.LockStatus = if ($info.LockStatus -eq 'Locked') { 'Locked' } else { 'Unlocked' }
            $result.Message = 'Queried via Get-BitLockerVolume'
            return $result
        } catch {
            $result.Message = $_.Exception.Message
            return $result
        }
    }

    $manageBdeCmd = Test-CommandExists 'manage-bde.exe'
    if ($manageBdeCmd.Available) {
        try {
            $output = & manage-bde.exe -status $DriveLetter 2>$null
            $result.Available = $true
            if ($output -match 'Protection Status:\s+(\w+)') {
                $result.ProtectionStatus = $matches[1]
            }
            if ($output -match 'Lock Status:\s+(\w+)') {
                $result.LockStatus = $matches[1]
            }
            $result.Message = 'Queried via manage-bde'
            return $result
        } catch {
            $result.Message = $_.Exception.Message
            return $result
        }
    }

    $result.Message = 'BitLocker tools not available'
    return $result
}

function Invoke-PreflightCheck {
    <#
    .SYNOPSIS
    Comprehensive preflight validation before launching any UI or repair logic.
    
    .OUTPUTS
    PSCustomObject with AllChecksPassed, Checks array, Summary
    #>
    param([string]$EnvironmentType = 'FullOS')
    
    Write-Host "`n[PREFLIGHT] Starting comprehensive validation..." -ForegroundColor Cyan
    
    $checks = @()
    $allPassed = $true
    
    # Check 1: Administrator Privileges
    Write-Host "[CHECK] Admin privileges..." -ForegroundColor Gray -NoNewline
    $adminStatus = Test-AdminPrivileges
    $adminCheck = @{
        Name = 'Administrator Privileges'
        Category = 'Privileges'
        Required = $true
        Passed = $adminStatus
        Message = $(if ($adminStatus) { "Running as administrator" } else { "NOT running as administrator - CRITICAL" })
    }
    $checks += $adminCheck
    if (-not $adminCheck.Passed) {
        Write-Host " FAIL" -ForegroundColor Red
        $allPassed = $false
    } else {
        Write-Host " OK" -ForegroundColor Green
    }
    
    # Check 2: Required Script Files
    $requiredFiles = @('WinRepairCore.ps1', 'WinRepairTUI.ps1')
    if ($EnvironmentType -eq 'FullOS') {
        $requiredFiles += 'WinRepairGUI.ps1'
    }
    
    foreach ($file in $requiredFiles) {
        Write-Host "[CHECK] Script file: $file..." -ForegroundColor Gray -NoNewline
        $fileCheck = Test-ScriptFileExists $file
        $fileCheckObj = @{
            Name = "File: $file"
            Category = 'Files'
            Required = $true
            Passed = $fileCheck.Exists -and $fileCheck.Readable
            Message = $(if ($fileCheck.Exists) { "Found ($($fileCheck.Size) bytes)" } else { "NOT FOUND" })
            Details = $fileCheck
        }
        $checks += $fileCheckObj
        if (-not $fileCheckObj.Passed) {
            Write-Host " FAIL" -ForegroundColor Red
            $allPassed = $false
        } else {
            Write-Host " OK" -ForegroundColor Green
        }
    }
    
    # Check 3: Core Commands
    $requiredCommands = @('Get-Volume', 'Get-NetAdapter', 'bcdedit', 'bcdboot', 'dism')
    if ($EnvironmentType -eq 'FullOS') {
        $requiredCommands += @('Add-Type')
    }
    
    foreach ($cmd in $requiredCommands) {
        Write-Host "[CHECK] Command available: $cmd..." -ForegroundColor Gray -NoNewline
        $cmdCheck = Test-CommandExists $cmd
        $cmdCheckObj = @{
            Name = "Command: $cmd"
            Category = 'Commands'
            Required = $true
            Passed = $cmdCheck.Available
            Message = $(if ($cmdCheck.Available) { "Available" } else { "NOT AVAILABLE" })
            Details = $cmdCheck
        }
        $checks += $cmdCheckObj
        if (-not $cmdCheckObj.Passed) {
            Write-Host " WARN" -ForegroundColor Yellow
        } else {
            Write-Host " OK" -ForegroundColor Green
        }
    }
    
    # Check 4: SystemDrive Validity
    Write-Host "[CHECK] SystemDrive validity..." -ForegroundColor Gray -NoNewline
    $systemDriveValid = -not [string]::IsNullOrEmpty($env:SystemDrive) -and (Test-Path $env:SystemDrive)
    $systemDriveCheck = @{
        Name = 'SystemDrive Validity'
        Category = 'Environment'
        Required = $true
        Passed = $systemDriveValid
        Message = $env:SystemDrive
    }
    $checks += $systemDriveCheck
    if (-not $systemDriveValid) {
        Write-Host " FAIL" -ForegroundColor Red
        $allPassed = $false
    } else {
        Write-Host " OK" -ForegroundColor Green
    }

    # Check 5: Firmware Type (informational)
    Write-Host "[CHECK] Firmware type..." -ForegroundColor Gray -NoNewline
    $firmwareType = Get-FirmwareType
    $firmwareCheck = @{
        Name = 'Firmware Type'
        Category = 'Environment'
        Required = $false
        Passed = $true
        Message = $firmwareType
    }
    $checks += $firmwareCheck
    Write-Host " OK" -ForegroundColor Green

    # Check 6: EFI System Partition presence (informational for UEFI)
    Write-Host "[CHECK] EFI System Partition..." -ForegroundColor Gray -NoNewline
    $espInfo = Get-EfiSystemPartitionInfo
    $espCheck = @{
        Name = 'EFI System Partition'
        Category = 'Boot'
        Required = $false
        Passed = $true
        Message = $espInfo.Message
        Details = $espInfo
    }
    $checks += $espCheck
    Write-Host " OK" -ForegroundColor Green

    # Check 7: BitLocker status (informational)
    Write-Host "[CHECK] BitLocker status..." -ForegroundColor Gray -NoNewline
    $bitlockerInfo = Get-BitLockerStatus -DriveLetter $env:SystemDrive
    $isLocked = ($bitlockerInfo.ProtectionStatus -eq 'On' -and $bitlockerInfo.LockStatus -eq 'Locked')
    $bitlockerCheck = @{
        Name = 'BitLocker Status'
        Category = 'Security'
        Required = $false
        Passed = -not $isLocked
        Message = "$($bitlockerInfo.ProtectionStatus)/$($bitlockerInfo.LockStatus)"
        Details = $bitlockerInfo
    }
    $checks += $bitlockerCheck
    if ($isLocked) {
        Write-Host " WARN" -ForegroundColor Yellow
    } else {
        Write-Host " OK" -ForegroundColor Green
    }
    
    Write-Host ""
    
    return @{
        AllChecksPassed = $allPassed
        Checks = $checks
        Summary = @{
            Total = $checks.Count
            Passed = ($checks | Where-Object { $_.Passed }).Count
            Failed = ($checks | Where-Object { -not $_.Passed }).Count
        }
    }
}

function Invoke-LogScanning {
    <#
    .SYNOPSIS
    Scans log files for error patterns.
    
    .PARAMETER LogPaths
    One or more log file paths (relative to root or absolute)
    
    .PARAMETER ErrorPatterns
    Array of regex patterns to search for. Defaults to common error indicators.
    
    .OUTPUTS
    PSCustomObject with findings array and summary
    #>
    param(
        [string[]]$LogPaths = @(),
        [string[]]$ErrorPatterns = @(
            '(?i)error',
            '(?i)exception', 
            '(?i)fail(ed)?',
            '(?i)critical',
            '(?i)fatal',
            '(?i)abort'
        )
    )
    
    if ($LogPaths.Count -eq 0) {
        return @{
            LogsScanned = 0
            Findings = @()
            Summary = 'No log paths provided'
        }
    }
    
    Write-Host "`n[LOGGING] Scanning log files for error patterns..." -ForegroundColor Cyan
    
    $findings = @()
    $logsScanned = 0
    
    $regexPattern = '(?i)(' + (($ErrorPatterns | ForEach-Object { $_ -replace '^\(\?i\)', '' }) -join '|') + ')'

    foreach ($logPath in $LogPaths) {
        # Resolve path
        if ([System.IO.Path]::IsPathRooted($logPath)) {
            $resolvedPath = $logPath
        } else {
            $resolvedPath = Join-Path $script:MiracleBootRoot $logPath
        }
        
        if (-not (Test-Path -LiteralPath $resolvedPath -ErrorAction SilentlyContinue)) {
            Write-Host "  [WARN] Log file not found: $resolvedPath" -ForegroundColor Yellow
            continue
        }
        
        Write-Host "  [SCAN] Processing: $resolvedPath" -ForegroundColor Gray
        $logsScanned++
        
        try {
            $scanMatches = Select-String -LiteralPath $resolvedPath -Pattern $regexPattern -AllMatches -ErrorAction Stop
            foreach ($match in $scanMatches) {
                foreach ($m in $match.Matches) {
                    $findings += @{
                        File = $resolvedPath
                        LineNumber = $match.LineNumber
                        Pattern = $m.Value
                        Content = $match.Line.Substring(0, [Math]::Min(200, $match.Line.Length))
                    }
                }
            }
        } catch {
            Write-Host "  [ERROR] Failed to read: $resolvedPath - $_" -ForegroundColor Red
        }
    }

    Write-Host "  [COMPLETE] Scanned $logsScanned logs, found $($findings.Count) error(s)" -ForegroundColor Cyan
    
    return @{
        LogsScanned = $logsScanned
        FindingsCount = $findings.Count
        Findings = $findings
        Summary = $(if ($findings.Count -eq 0) { "No errors detected" } else { "$($findings.Count) error(s) found" })
    }
}

function New-PreflightReport {
    <#
    .SYNOPSIS
    Generates a comprehensive diagnostic report as structured output.
    #>
    param(
        [hashtable]$PreflightResults,
        [hashtable]$LogScanResults,
        [string]$EnvironmentType
    )
    
    $report = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Version = 'MiracleBoot v7.2.0 (Hardened)'
        Environment = @{
            Type = $EnvironmentType
            SystemDrive = $env:SystemDrive
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            OSVersion = (Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue).Version
        }
        Preflight = @{
            AllChecksPassed = $PreflightResults.AllChecksPassed
            Summary = $PreflightResults.Summary
            CriticalFailures = @($PreflightResults.Checks | Where-Object { $_.Required -and -not $_.Passed })
        }
        LogScanning = $LogScanResults
        ReadyToProceed = $PreflightResults.AllChecksPassed -and $LogScanResults.FindingsCount -eq 0
    }
    
    return $report
}

# ============================================================================
# SECTION 2: INITIALIZATION & MAIN EXECUTION FLOW
# ============================================================================

# Initialize script root robustly (works in all contexts)
$script:MiracleBootRoot = if ($PSScriptRoot) { $PSScriptRoot } else { $null }
if ([string]::IsNullOrEmpty($script:MiracleBootRoot)) {
    $script:MiracleBootRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ([string]::IsNullOrEmpty($script:MiracleBootRoot)) {
        $script:MiracleBootRoot = (Get-Location).Path
    }
}

if (-not (Test-Path -LiteralPath $script:MiracleBootRoot)) {
    Write-Host "FATAL: Cannot determine script root directory" -ForegroundColor Red
    Write-Host "ScriptRoot: $script:MiracleBootRoot" -ForegroundColor Yellow
    Write-Host "MyCommand: $($MyInvocation.MyCommand.Path)" -ForegroundColor Yellow
    exit 1
}

# Initialize logging system FIRST (before any other operations)
try {
    Initialize-LogSystem -ScriptRoot $script:MiracleBootRoot
    # Now that logging is initialized, add environment details
    if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
        Write-ToLog "Logging system initialized successfully" "SUCCESS"
    }
} catch {
    Write-Host "WARNING: Could not initialize logging: $_" -ForegroundColor Yellow
}

# Detect environment (after logging is initialized)
$envType = Get-EnvironmentType
$isAdmin = Test-AdminPrivileges
$firmwareType = Get-FirmwareType

# Log environment details now that all functions are available
if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
    Write-ToLog "Environment detected: $envType" "INFO"
    Write-ToLog "Firmware: $firmwareType" "INFO"
    Write-ToLog "Administrator: $(if ($isAdmin) { 'Yes' } else { 'No' })" "INFO"
    Write-ToLog "PowerShell: $($PSVersionTable.PSVersion)" "INFO"
}

if ($SelfTest) {
    $null = Invoke-SelfTest -EnvironmentType $envType
    Write-Host "Press any key to exit self-test..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 0
}

# Ensure GUI-compatible host when running in FullOS
Set-GuiHostForFullOS -EnvironmentType $envType

# Banner
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     MiracleBoot v7.2.0 - Hardened Windows Recovery Toolkit      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Environment: $envType | SystemDrive: $env:SystemDrive | Admin: $(if ($isAdmin) { 'YES' } else { 'NO' })" -ForegroundColor Gray
Write-Host "Log File: $global:LogPath" -ForegroundColor Gray
Write-Host "Error/Warning Log: $global:ErrorWarningLogPath" -ForegroundColor Gray
Write-Host ""

# CRITICAL: Block if not admin
if (-not $isAdmin) {
    # Try to log, but don't fail if logging isn't initialized yet
    try {
        Write-ErrorLog "This script requires administrator privileges"
    } catch {
        # Logging may not be available - continue with console output
    }
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║         FATAL ERROR: Administrator Privileges Required         ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "This script requires administrator privileges to function properly." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To fix this:" -ForegroundColor Cyan
    Write-Host "  1. Right-click on 'MiracleBoot.ps1'" -ForegroundColor White
    Write-Host "  2. Select 'Run with PowerShell' or 'Run as Administrator'" -ForegroundColor White
    Write-Host "  3. If prompted, click 'Yes' to allow the script to run" -ForegroundColor White
    Write-Host ""
    if ($global:LogPath) {
        Write-Host "Log saved to: $global:LogPath" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        # If ReadKey fails, just wait a moment
        Start-Sleep -Seconds 3
    }
    exit 1
}

# Run comprehensive preflight checks
$preflightResults = Invoke-PreflightCheck -EnvironmentType $envType

# Block if critical failures exist
if (-not $preflightResults.AllChecksPassed) {
    Write-Host "`n" -ForegroundColor Red
    Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║         PREFLIGHT VALIDATION FAILED - CANNOT PROCEED               ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "Critical Failures:" -ForegroundColor Red
    foreach ($check in ($preflightResults.Checks | Where-Object { $_.Required -and -not $_.Passed })) {
        Write-Host "  ✗ $($check.Name): $($check.Message)" -ForegroundColor Red
        if ($check.Details.Error) {
            Write-Host "    Error: $($check.Details.Error)" -ForegroundColor DarkRed
        }
    }
    
    Write-Host ""
    Write-Host "Summary: $($preflightResults.Summary.Passed) / $($preflightResults.Summary.Total) checks passed"
    Write-Host ""
    Write-Host "Log saved to: $global:LogPath" -ForegroundColor Yellow
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Load core module
Write-ToLog "Loading WinRepairCore module..." "INFO"
Write-Host "`n[LOADER] Loading WinRepairCore module..." -ForegroundColor Cyan
try {
    $coreModule = Join-Path $script:MiracleBootRoot "WinRepairCore.ps1"
    if (-not (Test-Path -LiteralPath $coreModule)) {
        throw "WinRepairCore.ps1 not found at $coreModule"
    }
    . $coreModule
    Write-ToLog "WinRepairCore loaded successfully" "SUCCESS"
    Write-Host "[LOADER] ✓ WinRepairCore loaded successfully" -ForegroundColor Green
} catch {
    Write-ErrorLog "Failed to load WinRepairCore.ps1" -Exception $_ -Details $coreModule
    Write-Host "[LOADER] ✗ FATAL: Failed to load WinRepairCore.ps1" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Location: $coreModule" -ForegroundColor Yellow
    Write-Host "Log file: $global:LogPath" -ForegroundColor Yellow
    exit 1
}

# Load optional repair-install module (non-critical)
Write-ToLog "Loading optional EnsureRepairInstallReady module..." "INFO"
Write-Host "[LOADER] Loading optional EnsureRepairInstallReady module..." -ForegroundColor Cyan
try {
    $repairReadyModule = Join-Path $script:MiracleBootRoot "EnsureRepairInstallReady.ps1"
    if (Test-Path -LiteralPath $repairReadyModule) {
        . $repairReadyModule
        Write-ToLog "EnsureRepairInstallReady loaded successfully" "SUCCESS"
        Write-Host "[LOADER] ✓ EnsureRepairInstallReady loaded" -ForegroundColor Green
    } else {
        Write-WarningLog "EnsureRepairInstallReady not found (optional, continuing)"
        Write-Host "[LOADER] - EnsureRepairInstallReady not found (optional, continuing)" -ForegroundColor Yellow
    }
} catch {
    Write-WarningLog "Failed to load EnsureRepairInstallReady (optional): $_"
    Write-Host "[LOADER] - Failed to load EnsureRepairInstallReady (optional): $_" -ForegroundColor Yellow
}

Write-Host ""

# Log summary before launching interface
$logSummary = Get-LogSummary
if ($logSummary.ErrorCount -gt 0 -or $logSummary.WarningCount -gt 0) {
    Write-ToLog "Pre-launch summary - Errors: $($logSummary.ErrorCount), Warnings: $($logSummary.WarningCount)" "INFO"
}

# ============================================================================
# SECTION 3: INTERFACE SELECTION & LAUNCH
# ============================================================================

if ($envType -eq 'FullOS' -or $envType -eq 'WinPE') {
    Write-ToLog "$envType detected - attempting GUI mode if WPF is available..." "INFO"
    Write-Host "[LAUNCH] $envType detected - attempting GUI mode..." -ForegroundColor Green
    
    # Validate GUI prerequisites BEFORE attempting to load
    Write-Host "[LAUNCH] Validating GUI prerequisites..." -ForegroundColor Gray
    
    # Check 1: WPF availability
    $wpfAvailable = $false
    $wpfAvailable = $false
    $wpfErrors = @()
    foreach ($asm in @("PresentationFramework","PresentationCore","WindowsBase")) {
        try {
            Add-Type -AssemblyName $asm -ErrorAction Stop
        } catch {
            $wpfErrors += "${asm}: $($_.Exception.Message)"
        }
    }
    if ($wpfErrors.Count -eq 0) {
        $wpfAvailable = $true
        Write-ToLog "WPF assemblies loaded: PresentationFramework, PresentationCore, WindowsBase" "INFO"
        Write-Host "  [CHECK] WPF assemblies: ✓" -ForegroundColor Green
    } else {
        Write-ErrorLog ("WPF assemblies missing: " + ($wpfErrors -join "; "))
        Write-Host "  [CHECK] WPF assemblies: ✗ - $($wpfErrors -join '; ')" -ForegroundColor Red
        # Attempt one-time relaunch into Windows PowerShell STA if currently in pwsh/Core
        if ($envType -eq 'FullOS' -and $env:MIRACLEBOOT_GUI_RELAUNCH -ne '1') {
            Write-Host "  [ACTION] Attempting to relaunch in Windows PowerShell (STA) for WPF support..." -ForegroundColor Yellow
            $env:MIRACLEBOOT_GUI_RELAUNCH = '1'
            $scriptPath = $PSCommandPath
            if ([string]::IsNullOrEmpty($scriptPath)) { $scriptPath = $MyInvocation.MyCommand.Path }
            if (-not [string]::IsNullOrEmpty($scriptPath)) {
                try {
                    Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-Sta","-File","`"$scriptPath`"") -WorkingDirectory $script:MiracleBootRoot | Out-Null
                    exit 0
                } catch {
                    Write-ErrorLog "Relaunch to Windows PowerShell (STA) failed: $($_.Exception.Message)"
                }
            } else {
                Write-ErrorLog "Cannot determine script path for relaunch after WPF failure"
            }
        }
        Write-Host ""
        Write-Host "GUI cannot launch without WPF support." -ForegroundColor Red
        Write-Host "Falling back to TUI mode..." -ForegroundColor Yellow
        Write-Host ""
        
        # Generate diagnostic report for WPF failure
        New-GUIFailureDiagnosticReport -FailureReason "WPF assemblies missing or unavailable" -ErrorMessage ($wpfErrors -join "; ") -InnerException $null -StackTrace $null -Location "MiracleBoot.ps1:WPF Check" -WpfAvailable "No" -StaThread $(if ($isSta) { "Yes" } else { "No" }) -EnvironmentType $envType
        Write-Host "A diagnostic report has been opened in Notepad with full details." -ForegroundColor Cyan
        Write-Host ""
    }
    
    # Check 2: STA thread requirement
    $isSta = $false
    try {
        $isSta = ([System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA')
        if ($isSta) {
            Write-ToLog "Thread apartment state is STA (required for WPF)" "INFO"
            Write-Host "  [CHECK] STA thread: ✓" -ForegroundColor Green
        } else {
            Write-ErrorLog "Thread apartment state is $([System.Threading.Thread]::CurrentThread.ApartmentState) (STA required for WPF)"
            Write-Host "  [CHECK] STA thread: ✗ - Current: $([System.Threading.Thread]::CurrentThread.ApartmentState)" -ForegroundColor Red
            Write-Host ""
            Write-Host "GUI requires STA thread. Attempting to relaunch..." -ForegroundColor Yellow
            Set-GuiHostForFullOS -EnvironmentType $envType
            # If we get here, relaunch didn't happen, so continue
        }
    } catch {
        Write-ErrorLog "Could not check thread apartment state: $($_.Exception.Message)"
        Write-Host "  [CHECK] STA thread: ✗ - Could not verify" -ForegroundColor Red
    }
    
    # Only proceed if prerequisites are met
    if ($wpfAvailable -and $isSta) {
        Write-Host "[LAUNCH] All GUI prerequisites met - proceeding with GUI launch" -ForegroundColor Green
        Write-Host ""
        
        # Try GUI mode
        Write-ToLog "Loading GUI module..." "INFO"
        Write-Host "[LAUNCH] Loading GUI module..." -ForegroundColor Gray
        try {
            # Load network diagnostics module first (required by GUI)
            $networkModule = Join-Path $script:MiracleBootRoot "HELPER SCRIPTS\NetworkDiagnostics.ps1"
            if (Test-Path -LiteralPath $networkModule) {
                . $networkModule
                Write-ToLog "NetworkDiagnostics loaded for GUI" "DEBUG"
            }

            # Check for GUI module in both possible locations
            $guiModule = Join-Path $script:MiracleBootRoot "WinRepairGUI.ps1"
            if (-not (Test-Path -LiteralPath $guiModule)) {
                $guiModule = Join-Path $script:MiracleBootRoot "HELPER SCRIPTS\WinRepairGUI.ps1"
                if (-not (Test-Path -LiteralPath $guiModule)) {
                    throw "WinRepairGUI.ps1 not found in root or HELPER SCRIPTS directory"
                }
            }

            Write-ToLog "GUI module found at: $guiModule" "INFO"
            Write-Host "  [LOAD] GUI module: $guiModule" -ForegroundColor Gray
            
            # Check for XAML file (resolve explicitly from root to avoid cwd issues)
            $xamlFile = Join-Path $script:MiracleBootRoot "WinRepairGUI.xaml"
            if (-not (Test-Path -LiteralPath $xamlFile)) {
                throw "WinRepairGUI.xaml not found at $xamlFile"
            }
            Write-ToLog "XAML file found at: $xamlFile" "INFO"
            Write-Host "  [LOAD] XAML file: $xamlFile" -ForegroundColor Gray
            $global:LastResolvedXamlPath = $xamlFile

            Write-ToLog "Loading GUI module..." "DEBUG"
            . $guiModule
            
            if (-not (Get-Command Start-GUI -ErrorAction SilentlyContinue)) {
                throw "Start-GUI function not found in WinRepairGUI.ps1 - module may not have loaded correctly"
            }
            
            Write-ToLog "GUI module loaded successfully, calling Start-GUI..." "INFO"
            Write-Host "[LAUNCH] ✓ Starting GUI interface..." -ForegroundColor Green
            Write-Host ""
            
            # Initialize GUI fallback flag
            $global:GUIFallbackToTUI = $false
            
            # Set PSScriptRoot for Start-GUI to find XAML
            $originalPSScriptRoot = $PSScriptRoot
            if (-not $PSScriptRoot) {
                $script:PSScriptRoot = $script:MiracleBootRoot
            }
            
            # Verify XAML file exists before calling Start-GUI
            $xamlCheck = Join-Path $script:MiracleBootRoot "WinRepairGUI.xaml"
            if (-not (Test-Path -LiteralPath $xamlCheck)) {
                throw "WinRepairGUI.xaml not found at $xamlCheck"
            }
            Write-ToLog "XAML file verified: $xamlCheck" "DEBUG"
            
            # Launch GUI with proper error handling
            try {
                Start-GUI
                
                # Check if user switched to TUI
                if ($global:GUIFallbackToTUI) {
                    Write-ToLog "User initiated fallback from GUI to TUI mode" "INFO"
                    Write-Host "[LAUNCH] User selected TUI mode, continuing to MS-DOS mode..." -ForegroundColor Yellow
                } else {
                    Write-ToLog "GUI closed normally, exiting application" "INFO"
                    exit 0
                }
            } catch {
                Write-ErrorLog "Start-GUI function failed: $($_.Exception.Message)" -Exception $_
                
                # Generate and open diagnostic report
                $innerExMsg = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
                New-GUIFailureDiagnosticReport -FailureReason "Start-GUI function failed" -ErrorMessage $_.Exception.Message -InnerException $innerExMsg -StackTrace $_.ScriptStackTrace -Location "$($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -WpfAvailable $(if ($wpfAvailable) { "Yes" } else { "No" }) -StaThread $(if ($isSta) { "Yes" } else { "No" }) -EnvironmentType $envType
                
                Write-Host ""
                Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
                Write-Host "║         GUI LAUNCH FAILED - DETAILED ERROR INFORMATION         ║" -ForegroundColor Red
                Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
                Write-Host ""
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                if ($_.Exception.InnerException) {
                    Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor DarkRed
                }
                Write-Host ""
                Write-Host "Stack Trace:" -ForegroundColor Yellow
                Write-Host $_.ScriptStackTrace -ForegroundColor Gray
                Write-Host ""
                Write-Host "A diagnostic report has been opened in Notepad with full details." -ForegroundColor Cyan
                Write-Host "Please review it and provide the information when reporting this issue." -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Falling back to TUI mode..." -ForegroundColor Yellow
                Write-Host ""
                throw  # Re-throw to be caught by outer catch
            } finally {
                # Restore original PSScriptRoot
                if ($originalPSScriptRoot) {
                    $script:PSScriptRoot = $originalPSScriptRoot
                }
            }
        } catch {
            # GUI launch failure - show detailed error
            Write-ErrorLog "GUI launch failed: $($_.Exception.Message)" -Exception $_
            
            # Generate and open diagnostic report
            $innerExMsg = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
            New-GUIFailureDiagnosticReport -FailureReason "GUI module loading failed" -ErrorMessage $_.Exception.Message -InnerException $innerExMsg -StackTrace $_.ScriptStackTrace -Location "$($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -WpfAvailable $(if ($wpfAvailable) { "Yes" } else { "No" }) -StaThread $(if ($isSta) { "Yes" } else { "No" }) -EnvironmentType $envType
            
            Write-Host ""
            Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
            Write-Host "║         GUI LAUNCH FAILED - DETAILED ERROR INFORMATION         ║" -ForegroundColor Red
            Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
            Write-Host ""
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.Exception.InnerException) {
                Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor DarkRed
            }
            Write-Host ""
            Write-Host "Location: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "A diagnostic report has been opened in Notepad with full details." -ForegroundColor Cyan
            Write-Host "Please review it and provide the information when reporting this issue." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Falling back to TUI mode..." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Log file: $global:LogPath" -ForegroundColor Gray
            Write-Host ""
        }
    } else {
        Write-Host ""
        Write-Host "GUI prerequisites not met. Falling back to TUI mode..." -ForegroundColor Yellow
        Write-Host ""
        
        # Generate diagnostic report for prerequisites failure
        $prereqFailure = "GUI prerequisites not met"
        if (-not $wpfAvailable) { $prereqFailure += " - WPF not available" }
        if (-not $isSta) { $prereqFailure += " - STA thread not available" }
        
        New-GUIFailureDiagnosticReport -FailureReason $prereqFailure -ErrorMessage "One or more GUI prerequisites were not met" -InnerException $null -StackTrace $null -Location "MiracleBoot.ps1:Prerequisites Check" -WpfAvailable $(if ($wpfAvailable) { "Yes" } else { "No" }) -StaThread $(if ($isSta) { "Yes" } else { "No" }) -EnvironmentType $envType
        Write-Host "A diagnostic report has been opened in Notepad with full details." -ForegroundColor Cyan
        Write-Host ""
    }
} else {
    Write-ToLog "Non-FullOS environment detected ($envType), skipping GUI" "WARNING"
    Write-Host "[LAUNCH] Non-FullOS environment ($envType), using TUI only..." -ForegroundColor Yellow
    Wait-ForUserContinue -Message "GUI is unavailable in this environment. Review the message above, then press any key to continue to TUI..."
}

# Fallback: TUI mode
Write-ToLog "Loading TUI module..." "INFO"
Write-Host "[LAUNCH] Loading TUI module..." -ForegroundColor Gray
try {
    $tuiModule = Join-Path $script:MiracleBootRoot "WinRepairTUI.ps1"
    if (-not (Test-Path -LiteralPath $tuiModule)) {
        throw "WinRepairTUI.ps1 not found"
    }
    . $tuiModule
    
    if (Get-Command Start-TUI -ErrorAction SilentlyContinue) {
        Write-ToLog "Launching TUI..." "INFO"
        Write-Host "[LAUNCH] ✓ Launching TUI..." -ForegroundColor Green
        Start-TUI
    } else {
        throw "Start-TUI function not found in WinRepairTUI.ps1"
    }
} catch {
    Write-ErrorLog "Could not launch TUI mode" -Exception $_
    Write-Host "[LAUNCH] FATAL: Could not launch TUI mode" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Log file: $global:LogPath" -ForegroundColor Yellow
    
    # Print error summary
    $summary = Get-LogSummary
    if ($summary.ErrorCount -gt 0) {
        Write-Host "`nErrors logged:" -ForegroundColor Red
        $summary.Errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
    
    exit 1
}

# Session cleanup and logging
Write-ToLog "Session completed successfully" "SUCCESS"
Write-ToLog "════════════════════════════════════════════════════════════════" "INFO"
