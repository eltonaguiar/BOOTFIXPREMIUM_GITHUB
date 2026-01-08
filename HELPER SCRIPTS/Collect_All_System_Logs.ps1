#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Unified Windows Log Collection Script for MiracleBoot
    
.DESCRIPTION
    Collects logs from all available Windows diagnostic tools:
    - Event Viewer (System/Application logs)
    - Boot Logs (ntbtlog.txt)
    - Procmon traces (if available)
    - Autoruns startup items (if available)
    - Reliability Monitor data
    - Performance counter snapshots
    
.PARAMETERS
    -Destination : Custom output path (default: MiracleBoot_Logs)
    -IncludePerformanceTrace : Capture WPR performance trace
    -IncludeProcmon : Capture Procmon boot log
    -IncludeAutoruns : Export Autoruns startup items
    -Verbose : Show detailed collection progress

.EXAMPLE
    .\Collect_All_System_Logs.ps1
    .\Collect_All_System_Logs.ps1 -Destination "D:\Diagnostics" -IncludePerformanceTrace
    
.NOTES
    Requires Administrator privileges
    Windows 10/11 compatible
    MiracleBoot v7.1.1+
#>

param(
    [string]$Destination = "C:\MiracleBoot_Logs",
    [switch]$IncludePerformanceTrace,
    [switch]$IncludeProcmon,
    [switch]$IncludeAutoruns,
    [switch]$Verbose
)

# Verify admin privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script requires Administrator privileges" -ForegroundColor Red
    exit 1
}

# Create timestamped output directory
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $Destination $timestamp
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    Write-Host "Created log directory: $logPath" -ForegroundColor Green
}

# Function to write status messages
function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    
    $color = switch ($Type) {
        "Success" { "Green" }
        "Error" { "Red" }
        "Warning" { "Yellow" }
        default { "Cyan" }
    }
    
    $prefix = "[$([datetime]::Now.ToString('HH:mm:ss'))]"
    Write-Host "$prefix $Message" -ForegroundColor $color
}

# ============================================================================
# 1. COLLECT EVENT VIEWER LOGS
# ============================================================================
Write-Status "COLLECTING EVENT VIEWER LOGS..." "Info"

try {
    # System Events (last 7 days)
    $systemEvents = @{
        LogName = 'System'
        StartTime = (Get-Date).AddDays(-7)
    }
    
    $events = Get-WinEvent -FilterHashtable $systemEvents -ErrorAction SilentlyContinue | 
        Select-Object TimeCreated, Id, LevelDisplayName, Source, Message |
        Sort-Object TimeCreated -Descending
    
    $events | Export-Csv -Path "$logPath\EventViewer_System_7Days.csv" -NoTypeInformation -Encoding UTF8
    Write-Status "✓ Exported $(($events | Measure-Object).Count) System events" "Success"
    
    # Application Events
    $appEvents = Get-WinEvent -FilterHashtable @{LogName = 'Application'; StartTime = (Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, LevelDisplayName, Source, Message |
        Sort-Object TimeCreated -Descending
    
    $appEvents | Export-Csv -Path "$logPath\EventViewer_Application_7Days.csv" -NoTypeInformation -Encoding UTF8
    Write-Status "✓ Exported $(($appEvents | Measure-Object).Count) Application events" "Success"
    
    # Critical Events (all time)
    $criticalEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        Level = 1
    } -ErrorAction SilentlyContinue -MaxEvents 500 |
        Select-Object TimeCreated, Id, LevelDisplayName, Source, Message |
        Sort-Object TimeCreated -Descending
    
    $criticalEvents | Export-Csv -Path "$logPath\EventViewer_Critical_All.csv" -NoTypeInformation -Encoding UTF8
    Write-Status "V Exported $(($criticalEvents | Measure-Object).Count) Critical events" "Success"
    
} catch {
    Write-Status "Failed to collect Event Viewer logs: $_" "Error"
}

# ============================================================================
# 2. COLLECT BOOT LOG (ntbtlog.txt)
# ============================================================================
Write-Status "COLLECTING BOOT LOG..." "Info"

try {
    if (Test-Path "C:\Windows\ntbtlog.txt") {
        Copy-Item "C:\Windows\ntbtlog.txt" -Destination "$logPath\ntbtlog.txt" -Force
        Write-Status "V Boot log copied" "Success"
        
        # Parse boot log for analysis
        $bootLog = Get-Content "C:\Windows\ntbtlog.txt"
        $loadedDrivers = $bootLog | Select-String "Loaded:" | Measure-Object
        $notLoadedDrivers = $bootLog | Select-String "Did not load:" | Measure-Object
        
        Write-Status "  - Loaded drivers: $($loadedDrivers.Count)" "Info"
        Write-Status "  - Failed loads: $($notLoadedDrivers.Count)" "Info"
        
        # Export failed loads
        $bootLog | Select-String "Did not load:" | 
            Out-File "$logPath\ntbtlog_FailedLoads.txt"
    } else {
        Write-Status "Boot log not found. Enable boot logging in msconfig to generate." "Warning"
    }
} catch {
    Write-Status "Failed to collect boot log: $_" "Error"
}

# ============================================================================
# 3. COLLECT SYSTEM CONFIGURATION INFO
# ============================================================================
Write-Status "COLLECTING SYSTEM CONFIGURATION..." "Info"

try {
    # Windows version
    $osInfo = Get-WmiObject Win32_OperatingSystem | 
        Select-Object Caption, BuildNumber, OSArchitecture, LastBootUpTime
    $osInfo | Out-File "$logPath\SystemInfo_OS.txt"
    Write-Status "V OS information collected" "Success"
    
    # Computer info
    $computerInfo = Get-WmiObject Win32_ComputerSystem |
        Select-Object Manufacturer, Model, SystemFamily, TotalPhysicalMemory
    $computerInfo | Out-File "$logPath\SystemInfo_Computer.txt"
    
    # Installed drivers (summary)
    $drivers = Get-WmiObject Win32_SystemDriver -ErrorAction SilentlyContinue |
        Select-Object Name, State, StartMode |
        Sort-Object Name
    $drivers | Export-Csv -Path "$logPath\Drivers_Installed.csv" -NoTypeInformation
    Write-Status "✓ Found $($drivers | Measure-Object | Select-Object -ExpandProperty Count) drivers" "Success"
    
} catch {
    Write-Status "Failed to collect system configuration: $_" "Error"
}

# ============================================================================
# 4. COLLECT STARTUP ITEMS
# ============================================================================
Write-Status "COLLECTING STARTUP ITEMS..." "Info"

try {
    $startupItems = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
        Select-Object Name, Command, Location, User |
        Sort-Object Name
    
    $startupItems | Export-Csv -Path "$logPath\StartupItems_Installed.csv" -NoTypeInformation
    Write-Status "✓ Found $($startupItems | Measure-Object | Select-Object -ExpandProperty Count) startup items" "Success"
    
} catch {
    Write-Status "Failed to collect startup items: $_" "Error"
}

# ============================================================================
# 5. COLLECT SERVICES INFORMATION
# ============================================================================
Write-Status "COLLECTING SERVICES..." "Info"

try {
    $services = Get-Service | Select-Object Name, DisplayName, Status, StartType | Sort-Object Name
    $services | Export-Csv -Path "$logPath\Services_All.csv" -NoTypeInformation
    
    $autoServices = $services | Where-Object {$_.StartType -eq 'Automatic'} | Measure-Object
    $stoppedServices = $services | Where-Object {$_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic'} | Measure-Object
    
    Write-Status "V Services: $($services | Measure-Object | Select-Object -ExpandProperty Count) total" "Success"
    Write-Status "  - Automatic: $($autoServices.Count)" "Info"
    Write-Status "  - Stopped (should be running): $($stoppedServices.Count)" "Warning"
    
} catch {
    Write-Status "Failed to collect services: $_" "Error"
}

# ============================================================================
# 6. COLLECT RELIABILITY MONITOR DATA
# ============================================================================
Write-Status "COLLECTING RELIABILITY MONITOR DATA..." "Info"

try {
    $reliabilityEvents = Get-WmiObject Win32_ReliabilityRecords -ErrorAction SilentlyContinue |
        Select-Object TimeGenerated, EventType, SourceName, Message |
        Sort-Object TimeGenerated -Descending |
        Select-Object -First 100
    
    if ($reliabilityEvents) {
        $reliabilityEvents | Export-Csv -Path "$logPath\ReliabilityMonitor_Events.csv" -NoTypeInformation
        Write-Status "V Exported $(($reliabilityEvents | Measure-Object).Count) reliability events" "Success"
    }
} catch {
    Write-Status "Failed to collect reliability monitor data: $_" "Error"
}

# ============================================================================
# 7. COLLECT PERFORMANCE COUNTERS
# ============================================================================
Write-Status "COLLECTING PERFORMANCE COUNTERS..." "Info"

try {
    # CPU Usage
    $cpu = Get-WmiObject Win32_PerfFormattedData_PerfOS_System -ErrorAction SilentlyContinue |
        Select-Object ProcessorQueueLength, SystemCallsPerSec, ContextSwitchesPerSec
    
    $cpu | Out-File "$logPath\PerformanceCounters_CPU.txt"
    
    # Disk Performance
    $disk = Get-WmiObject Win32_PerfFormattedData_PerfDisk_LogicalDisk -Filter "Name='C:'" -ErrorAction SilentlyContinue |
        Select-Object AvgDiskQueueLength, PercentDiskTime, DiskBytesPerSec
    
    $disk | Out-File "$logPath\PerformanceCounters_Disk.txt"
    
    Write-Status "V Performance counters collected" "Success"
} catch {
    Write-Status "Failed to collect performance counters: $_" "Error"
}

# ============================================================================
# 8. COLLECT PROCMON LOG (if requested and available)
# ============================================================================
if ($IncludeProcmon) {
    Write-Status "COLLECTING PROCMON TRACE..." "Info"
    
    try {
        if (Test-Path "C:\Windows\Temp\ProcmonBoot.pml") {
            Copy-Item "C:\Windows\Temp\ProcmonBoot.pml" -Destination "$logPath\ProcmonBoot.pml" -Force
            Write-Status "V Procmon boot log found and copied" "Success"
        } else {
            Write-Status "Procmon boot log not found. Enable boot logging in Procmon and restart." "Warning"
        }
    } catch {
        Write-Status "Failed to collect Procmon trace: $_" "Error"
    }
}

# ============================================================================
# 9. COLLECT AUTORUNS DATA (if requested and available)
# ============================================================================
if ($IncludeAutoruns) {
    Write-Status "COLLECTING AUTORUNS STARTUP ITEMS..." "Info"
    
    try {
        $autorunsPath = $null
        
        # Search for Autoruns in common locations
        $possiblePaths = @(
            "C:\Program Files\Sysinternals\Autoruns.exe",
            "C:\Program Files (x86)\Sysinternals\Autoruns.exe",
            "$env:USERPROFILE\Downloads\Autoruns.exe",
            (Get-Command autoruns -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
        )
        
        foreach ($path in $possiblePaths) {
            if ($path -and (Test-Path $path)) {
                $autorunsPath = $path
                break
            }
        }
        
        if ($autorunsPath) {
            # Run Autoruns and export
            & $autorunsPath -accepteula -a * -s "$logPath\Autoruns_All.csv" -z "$logPath\Autoruns_All.arn" 2>&1 | Out-Null
            Write-Status "V Autoruns data exported" "Success"
        } else {
            Write-Status "Autoruns not found. Download from Microsoft Sysinternals." "Warning"
        }
    } catch {
        Write-Status "Failed to collect Autoruns data: $_" "Error"
    }
}

# ============================================================================
# 10. GENERATE SUMMARY REPORT
# ============================================================================
Write-Status "GENERATING SUMMARY REPORT..." "Info"

try {
    $reportPath = "$logPath\COLLECTION_SUMMARY.txt"
    
    $report = @"
===============================================================================
WINDOWS LOG COLLECTION SUMMARY
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
===============================================================================

COLLECTION PARAMETERS
---------------------
Destination: $logPath
Include Performance Trace: $IncludePerformanceTrace
Include Procmon: $IncludeProcmon
Include Autoruns: $IncludeAutoruns

SYSTEM INFORMATION
------------------
Computer Name: $env:COMPUTERNAME
OS Version: $($osInfo.Caption)
OS Build: $($osInfo.BuildNumber)
Last Boot Time: $($osInfo.LastBootUpTime)
Current User: $env:USERNAME

FILES COLLECTED
---------------
"@
    
    $files = Get-ChildItem $logPath -File
    foreach ($file in $files) {
        if ($file.Name -ne "COLLECTION_SUMMARY.txt") {
            $sizeMB = [math]::Round($file.Length / 1MB, 2)
            $report += "`n- $($file.Name) ($sizeMB MB)"
        }
    }
    
    $report += @"

ANALYSIS RECOMMENDATIONS
-----------------------
1. Review Event Viewer logs for critical errors:
   - EventViewer_System_7Days.csv
   - EventViewer_Critical_All.csv

2. Check boot sequence delays:
   - ntbtlog_FailedLoads.txt (drivers that failed to load)

3. Verify startup items:
   - StartupItems_Installed.csv (programs in startup)
   - Services_All.csv (running services)

4. Analyze performance impact:
   - PerformanceCounters_*.txt

5. For deep diagnostics:
   - Review individual CSV files sorted by issues
   - Use Procmon GUI if trace was captured
   - Check Autoruns for suspicious entries

NEXT STEPS
----------
1. Open logs in your preferred analysis tool
2. Sort and filter for error conditions
3. Cross-reference Event Viewer with boot logs
4. Investigate failed driver loads
5. Review startup items for unnecessary programs

===============================================================================
"@
    
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Status "V Summary report generated" "Success"
    
} catch {
    Write-Status "Failed to generate summary: $_" "Error"
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================
Write-Host "`n" + ("="*80)
Write-Status "LOG COLLECTION COMPLETE" "Success"
Write-Host ("="*80)
Write-Host "Output Directory: $logPath`n" -ForegroundColor Cyan
Write-Host "Files collected: $(($files | Measure-Object).Count)`n" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "1. Review COLLECTION_SUMMARY.txt for analysis recommendations"
Write-Host "2. Open CSV files in Excel for sorting/filtering"
Write-Host "3. Run Windows_Log_Analyzer_Interactive.ps1 for guided analysis"
Write-Host "4. Review WINDOWS_LOG_ANALYSIS_GUIDE.md for detailed interpretation`n"

Write-Host "You can now analyze these logs with:" -ForegroundColor Yellow
Write-Host ".\Windows_Log_Analyzer_Interactive.ps1 -LogPath `"$logPath`""



