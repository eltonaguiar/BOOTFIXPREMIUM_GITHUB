#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Interactive Windows Log Analyzer for MiracleBoot
    
.DESCRIPTION
    Provides guided analysis of collected Windows logs with interactive menu
    and filtering capabilities. Analyzes:
    - Event Viewer events
    - Boot logs
    - Startup items
    - Services status
    - Performance data
    
.PARAMETERS
    -LogPath : Directory containing previously collected logs
    -QuickAnalysis : Skip interactive menu and run standard analysis
    
.EXAMPLE
    .\Windows_Log_Analyzer_Interactive.ps1
    .\Windows_Log_Analyzer_Interactive.ps1 -LogPath "C:\MiracleBoot_Logs\20260107_103045"
    .\Windows_Log_Analyzer_Interactive.ps1 -QuickAnalysis
    
.NOTES
    Requires Administrator privileges
    Works with logs collected by Collect_All_System_Logs.ps1
#>

param(
    [string]$LogPath,
    [switch]$QuickAnalysis
)

# Color scheme
$colors = @{
    "Header"  = "Cyan"
    "Success" = "Green"
    "Error"   = "Red"
    "Warning" = "Yellow"
    "Info"    = "Gray"
}

function Write-Header {
    param([string]$Text)
    Write-Host "`n" + ("="*80) -ForegroundColor $colors.Header
    Write-Host $Text -ForegroundColor $colors.Header
    Write-Host ("="*80) -ForegroundColor $colors.Header
}

function Write-Section {
    param([string]$Text)
    Write-Host "`n--- $Text ---" -ForegroundColor $colors.Info
}

function Show-Menu {
    Write-Header "WINDOWS LOG ANALYZER - MAIN MENU"
    Write-Host @"
1. View Event Viewer System Events (last 7 days)
2. View Critical Events (all time)
3. Analyze Boot Log (driver/service loads)
4. Review Startup Items
5. Check Services Status
6. Performance Analysis
7. Find Failed Driver Loads
8. Identify Slow Boot Items
9. Generate Full Report
0. Exit

"@ -ForegroundColor Cyan
}

function Analyze-EventViewerEvents {
    Write-Section "EVENT VIEWER SYSTEM EVENTS (Last 7 Days)"
    
    if (Test-Path "$LogPath\EventViewer_System_7Days.csv") {
        $events = Import-Csv "$LogPath\EventViewer_System_7Days.csv"
        
        $counts = $events | Group-Object -Property LevelDisplayName | Select-Object Name, Count
        Write-Host "Event Distribution:" -ForegroundColor $colors.Info
        $counts | Format-Table -AutoSize
        
        Write-Host "`nMost Common Event Sources:" -ForegroundColor $colors.Info
        $events | Group-Object -Property Source | Select-Object -First 10 Name, Count | Format-Table -AutoSize
        
        Write-Host "`nRecent Critical Events:" -ForegroundColor $colors.Warning
        $critical = $events | Where-Object {$_.LevelDisplayName -eq "Error" -or $_.LevelDisplayName -eq "Warning"} | 
            Select-Object -First 10 TimeCreated, Id, Source, Message
        $critical | Format-Table -AutoSize -Wrap
        
        Write-Host "`nFull log saved to: EventViewer_System_7Days.csv" -ForegroundColor $colors.Success
    } else {
        Write-Host "Event Viewer log not found. Run Collect_All_System_Logs.ps1 first." -ForegroundColor $colors.Error
    }
}

function Analyze-CriticalEvents {
    Write-Section "CRITICAL EVENTS (All Time)"
    
    if (Test-Path "$LogPath\EventViewer_Critical_All.csv") {
        $events = Import-Csv "$LogPath\EventViewer_Critical_All.csv"
        
        if ($events.Count -gt 0) {
            Write-Host "Total Critical Events Found: $($events.Count)" -ForegroundColor $colors.Warning
            
            Write-Host "`nTop Event Sources:" -ForegroundColor $colors.Info
            $events | Group-Object -Property Source | Select-Object -First 10 Name, Count | Format-Table -AutoSize
            
            Write-Host "`nCritical Events Summary:" -ForegroundColor $colors.Info
            $events | Select-Object -First 15 TimeCreated, Id, Source, Message | Format-Table -AutoSize -Wrap
            
            Write-Host "`nRecommendation: Review these events for system stability issues" -ForegroundColor $colors.Warning
        } else {
            Write-Host "No critical events found. System appears healthy!" -ForegroundColor $colors.Success
        }
    } else {
        Write-Host "Critical events log not found." -ForegroundColor $colors.Error
    }
}

function Analyze-BootLog {
    Write-Section "BOOT LOG ANALYSIS"
    
    if (Test-Path "$LogPath\ntbtlog.txt") {
        $bootLog = Get-Content "$LogPath\ntbtlog.txt"
        
        $loaded = $bootLog | Select-String "Loaded:" | Measure-Object | Select-Object -ExpandProperty Count
        $notLoaded = $bootLog | Select-String "Did not load:" | Measure-Object | Select-Object -ExpandProperty Count
        
        Write-Host "Boot Sequence Summary:" -ForegroundColor $colors.Info
        Write-Host "  - Drivers/Services Loaded: $loaded" -ForegroundColor $colors.Success
        Write-Host "  - Failed to Load: $notLoaded" -ForegroundColor $(if ($notLoaded -gt 0) { $colors.Warning } else { $colors.Success })
        
        if ($notLoaded -gt 0) {
            Write-Host "`nDrivers/Services That Failed to Load:" -ForegroundColor $colors.Warning
            $bootLog | Select-String "Did not load:" | Select-Object -First 20
            Write-Host "`n(Showing first 20. See ntbtlog_FailedLoads.txt for complete list)"
        }
        
        # Try to extract timing info
        Write-Host "`nBoot Session Details:" -ForegroundColor $colors.Info
        $bootLog | Select-Object -First 3
        
    } else {
        Write-Host "Boot log not found. Enable boot logging in msconfig and restart to generate." -ForegroundColor $colors.Error
        Write-Host "`nTo enable: Run 'msconfig.exe', go to Boot tab, check 'Boot log', restart." -ForegroundColor $colors.Info
    }
}

function Analyze-StartupItems {
    Write-Section "STARTUP ITEMS ANALYSIS"
    
    if (Test-Path "$LogPath\StartupItems_Installed.csv") {
        $items = Import-Csv "$LogPath\StartupItems_Installed.csv"
        
        Write-Host "Total Startup Items: $($items.Count)" -ForegroundColor $colors.Info
        
        $byLocation = $items | Group-Object -Property Location | Select-Object Name, Count | Sort-Object Count -Descending
        Write-Host "`nStartup Items by Location:" -ForegroundColor $colors.Info
        $byLocation | Format-Table -AutoSize
        
        Write-Host "`nStartup Items by User:" -ForegroundColor $colors.Info
        $items | Group-Object -Property User | Select-Object Name, Count | Format-Table -AutoSize
        
        Write-Host "`nAll Startup Items:" -ForegroundColor $colors.Info
        $items | Select-Object Name, Location, Command | Format-Table -AutoSize -Wrap
        
        Write-Host "`nTip: Review 'Command' column for suspicious or unnecessary programs" -ForegroundColor $colors.Warning
    } else {
        Write-Host "Startup items log not found." -ForegroundColor $colors.Error
    }
}

function Analyze-Services {
    Write-Section "SERVICES ANALYSIS"
    
    if (Test-Path "$LogPath\Services_All.csv") {
        $services = Import-Csv "$LogPath\Services_All.csv"
        
        $automatic = $services | Where-Object {$_.StartType -eq 'Automatic'} | Measure-Object | Select-Object -ExpandProperty Count
        $running = $services | Where-Object {$_.Status -eq 'Running'} | Measure-Object | Select-Object -ExpandProperty Count
        $stopped = $services | Where-Object {$_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic'} | Measure-Object | Select-Object -ExpandProperty Count
        
        Write-Host "Services Summary:" -ForegroundColor $colors.Info
        Write-Host "  - Total Services: $($services.Count)" -ForegroundColor $colors.Info
        Write-Host "  - Automatic Start: $automatic" -ForegroundColor $colors.Info
        Write-Host "  - Currently Running: $running" -ForegroundColor $colors.Success
        
        if ($stopped -gt 0) {
            Write-Host "  - Automatic but Stopped: $stopped" -ForegroundColor $colors.Warning
            Write-Host "`nServices that should be running but are stopped:" -ForegroundColor $colors.Warning
            $services | Where-Object {$_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic'} | 
                Select-Object Name, DisplayName, StartType, Status | Format-Table -AutoSize -Wrap
        }
        
    } else {
        Write-Host "Services log not found." -ForegroundColor $colors.Error
    }
}

function Analyze-Performance {
    Write-Section "PERFORMANCE ANALYSIS"
    
    if (Test-Path "$LogPath\PerformanceCounters_CPU.txt") {
        Write-Host "CPU Performance:" -ForegroundColor $colors.Info
        Get-Content "$LogPath\PerformanceCounters_CPU.txt"
    }
    
    if (Test-Path "$LogPath\PerformanceCounters_Disk.txt") {
        Write-Host "`nDisk Performance:" -ForegroundColor $colors.Info
        Get-Content "$LogPath\PerformanceCounters_Disk.txt"
    }
    
    Write-Host "`nInterpretation:" -ForegroundColor $colors.Info
    Write-Host "  - High ProcessorQueueLength: CPU bottleneck" -ForegroundColor $colors.Info
    Write-Host "  - High AvgDiskQueueLength: Disk bottleneck" -ForegroundColor $colors.Info
    Write-Host "  - High PercentDiskTime: Disk heavily utilized" -ForegroundColor $colors.Info
}

function Find-FailedLoads {
    Write-Section "FAILED DRIVER/SERVICE LOADS"
    
    if (Test-Path "$LogPath\ntbtlog_FailedLoads.txt") {
        $failedLoads = Get-Content "$LogPath\ntbtlog_FailedLoads.txt"
        
        if ($failedLoads) {
            $failedCount = @($failedLoads).Count
            Write-Host "Failed Load Attempts: $failedCount" -ForegroundColor $colors.Warning
            Write-Host "`nFailed Items:" -ForegroundColor $colors.Info
            $failedLoads | Format-List
            
            Write-Host "`nRecommendation:" -ForegroundColor $colors.Warning
            Write-Host "- Some failed loads are normal (legacy drivers, conditional loads)"
            Write-Host "- Investigate if they're critical to system functionality"
            Write-Host "- Check Event Viewer for related error codes"
        }
    } else {
        Write-Host "Boot log not available. Failed loads info cannot be generated." -ForegroundColor $colors.Error
    }
}

function Find-SlowBootItems {
    Write-Section "IDENTIFYING SLOW BOOT ITEMS"
    
    Write-Host "To identify slow boot items:" -ForegroundColor $colors.Info
    Write-Host "`n1. Using Boot Log Analysis:" -ForegroundColor $colors.Header
    Write-Host "   - Look for items with timestamps far apart in ntbtlog.txt"
    Write-Host "   - Drivers/services that take several seconds to load"
    
    Write-Host "`n2. Using Startup Items List:" -ForegroundColor $colors.Header
    if (Test-Path "$LogPath\StartupItems_Installed.csv") {
        $items = Import-Csv "$LogPath\StartupItems_Installed.csv"
        Write-Host "   - Found $($items.Count) startup items"
        Write-Host "   - Disable unnecessary programs: System Settings > Apps > Startup"
        Write-Host "`n   Top startup items by category:" -ForegroundColor $colors.Info
        $items | Group-Object -Property Location | Select-Object Name, Count | Sort-Object Count -Descending | Format-Table -AutoSize
    }
    
    Write-Host "`n3. Using Performance Counters:" -ForegroundColor $colors.Header
    Write-Host "   - High CPU/Disk activity during boot indicates slow items"
    
    Write-Host "`n4. Advanced Tools:" -ForegroundColor $colors.Header
    Write-Host "   - BootRacer: Measures individual app load times"
    Write-Host "   - Process Monitor: Traces file/registry activity"
    Write-Host "   - Windows Performance Analyzer: Detailed kernel tracing"
}

function Generate-FullReport {
    Write-Header "GENERATING COMPREHENSIVE REPORT"
    
    $reportPath = "$LogPath\ANALYSIS_REPORT.txt"
    
    $report = @"
================================================================================
COMPREHENSIVE WINDOWS LOG ANALYSIS REPORT
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Report Location: $LogPath
================================================================================

EXECUTIVE SUMMARY
-----------------
This report summarizes the system diagnostic logs collected and analyzed on this date.

"@
    
    # System Info
    if (Test-Path "$LogPath\SystemInfo_OS.txt") {
        $osInfo = Get-Content "$LogPath\SystemInfo_OS.txt"
        $report += "`n1. SYSTEM INFORMATION`n" + ("-"*40) + "`n"
        $report += $osInfo | Out-String
    }
    
    # Event Summary
    if (Test-Path "$LogPath\EventViewer_System_7Days.csv") {
        $events = Import-Csv "$LogPath\EventViewer_System_7Days.csv"
        $report += "`n2. EVENT VIEWER SUMMARY (Last 7 Days)`n" + ("-"*40) + "`n"
        $report += "Total Events: $($events.Count)`n"
        $events | Group-Object -Property LevelDisplayName | ForEach-Object { $report += "$($_.Name): $($_.Count)`n" }
    }
    
    # Critical Events
    if (Test-Path "$LogPath\EventViewer_Critical_All.csv") {
        $critical = Import-Csv "$LogPath\EventViewer_Critical_All.csv"
        if ($critical.Count -gt 0) {
            $report += "`n3. CRITICAL EVENTS (All Time)`n" + ("-"*40) + "`n"
            $report += "Critical Events Found: $($critical.Count)`n"
            $report += "Top Sources: `n"
            $critical | Group-Object -Property Source | Select-Object -First 5 | ForEach-Object { $report += "  - $($_.Name): $($_.Count)`n" }
        }
    }
    
    # Boot Analysis
    if (Test-Path "$LogPath\ntbtlog.txt") {
        $bootLog = Get-Content "$LogPath\ntbtlog.txt"
        $loaded = $bootLog | Select-String "Loaded:" | Measure-Object | Select-Object -ExpandProperty Count
        $notLoaded = $bootLog | Select-String "Did not load:" | Measure-Object | Select-Object -ExpandProperty Count
        
        $report += "`n4. BOOT SEQUENCE ANALYSIS`n" + ("-"*40) + "`n"
        $report += "Drivers/Services Loaded: $loaded`n"
        $report += "Failed to Load: $notLoaded`n"
        
        if ($notLoaded -gt 0) {
            $report += "`nFailed Load Details:`n"
            $bootLog | Select-String "Did not load:" | Select-Object -First 10 | ForEach-Object { $report += "$_`n" }
        }
    }
    
    # Startup Items
    if (Test-Path "$LogPath\StartupItems_Installed.csv") {
        $items = Import-Csv "$LogPath\StartupItems_Installed.csv"
        $report += "`n5. STARTUP ITEMS ANALYSIS`n" + ("-"*40) + "`n"
        $report += "Total Startup Items: $($items.Count)`n"
        $report += "`nItems by Location:`n"
        $items | Group-Object -Property Location | ForEach-Object { $report += "  - $($_.Name): $($_.Count)`n" }
    }
    
    # Services
    if (Test-Path "$LogPath\Services_All.csv") {
        $services = Import-Csv "$LogPath\Services_All.csv"
        $automatic = $services | Where-Object {$_.StartType -eq 'Automatic'} | Measure-Object | Select-Object -ExpandProperty Count
        $stopped = $services | Where-Object {$_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic'} | Measure-Object | Select-Object -ExpandProperty Count
        
        $report += "`n6. SERVICES STATUS`n" + ("-"*40) + "`n"
        $report += "Total Services: $($services.Count)`n"
        $report += "Automatic Start Services: $automatic`n"
        
        if ($stopped -gt 0) {
            $report += "Stopped (should run): $stopped`n`n"
            $report += "Services to Investigate:`n"
            $services | Where-Object {$_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic'} | 
                Select-Object -First 10 | ForEach-Object { $report += "  - $($_.DisplayName) ($($_.Name))`n" }
        }
    }
    
    # Recommendations
    $report += @"
`n7. RECOMMENDATIONS
-------------------
1. IMMEDIATE ACTIONS:
   - Review critical events in Event Viewer
   - Investigate any failed driver loads
   - Check for stopped automatic services
   
2. PERFORMANCE OPTIMIZATION:
   - Disable unnecessary startup programs
   - Review services running at startup
   - Check for malware using Autoruns
   
3. FOLLOW-UP DIAGNOSTICS:
   - Use Procmon to trace slow operations
   - Use Windows Performance Analyzer for deep analysis
   - Consider using BootRacer for boot time measurement
   
4. ONGOING MONITORING:
   - Schedule periodic log collection
   - Trend analysis over time
   - Monitor for recurring issues

===============================================================================
Report End
Detailed CSV files available in: $LogPath
===============================================================================
"@
    
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "Full report generated: $reportPath" -ForegroundColor $colors.Success
    
    # Also display key findings
    Write-Host "`n" + $report | Out-Host
}

# Main execution
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script requires Administrator privileges" -ForegroundColor $colors.Error
    exit 1
}

# Find log path if not provided
if (-not $LogPath) {
    $recentLogs = Get-ChildItem "C:\MiracleBoot_Logs" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($recentLogs) {
        $LogPath = $recentLogs.FullName
        Write-Host "Using most recent log directory: $LogPath" -ForegroundColor $colors.Success
    } else {
        Write-Host "ERROR: No log directory found. Run Collect_All_System_Logs.ps1 first." -ForegroundColor $colors.Error
        exit 1
    }
}

Write-Header "WINDOWS LOG ANALYZER - MiracleBoot"
Write-Host "Log Directory: $LogPath`n" -ForegroundColor $colors.Success

# Quick analysis mode
if ($QuickAnalysis) {
    Write-Host "Running quick analysis..." -ForegroundColor $colors.Info
    Analyze-EventViewerEvents
    Analyze-BootLog
    Analyze-StartupItems
    Analyze-Services
    Generate-FullReport
    exit 0
}

# Interactive menu
do {
    Show-Menu
    $choice = Read-Host "Enter selection (0-9)"
    
    switch ($choice) {
        "1" { Analyze-EventViewerEvents }
        "2" { Analyze-CriticalEvents }
        "3" { Analyze-BootLog }
        "4" { Analyze-StartupItems }
        "5" { Analyze-Services }
        "6" { Analyze-Performance }
        "7" { Find-FailedLoads }
        "8" { Find-SlowBootItems }
        "9" { Generate-FullReport }
        "0" { break }
        default { Write-Host "Invalid selection" -ForegroundColor $colors.Error }
    }
} while ($true)

Write-Host "`nExiting analyzer. Thank you!" -ForegroundColor $colors.Success

