# Windows Log Analysis Guide for MiracleBoot

## Overview

This guide integrates built-in Windows tools and Sysinternals utilities to provide comprehensive log analysis capabilities for boot diagnostics and system health monitoring.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Built-in Windows Tools](#built-in-windows-tools)
3. [Third-Party & Sysinternals Tools](#third-party--sysinternals-tools)
4. [Integration with MiracleBoot](#integration-with-miracleboot)
5. [Log Analysis Workflow](#log-analysis-workflow)
6. [Troubleshooting Guide](#troubleshooting-guide)

---

## Quick Start

**For automated log collection:**
```powershell
.\Collect_All_System_Logs.ps1
```

**For interactive log analysis:**
```powershell
.\Windows_Log_Analyzer_Interactive.ps1
```

---

## Built-in Windows Tools

### 1. Event Viewer (eventvwr.msc)

**Purpose:** Central repository for all Windows system events, including startup, shutdown, and hardware failures.

**Why Use It:**
- Provides detailed timestamps and event codes
- Shows error codes specific to system failures
- Integrates with Windows reliability tracking
- No additional installation required

**How to Access:**
```powershell
# Method 1: Via Run dialog
# Press Win + R, type: eventvwr.msc

# Method 2: Via PowerShell
eventvwr.msc
```

**Key Navigation:**
1. Open Event Viewer
2. Navigate to **Windows Logs > System**
3. Click **Filter Current Log** (right pane)
4. Enter Event IDs:
   - **6005**: System startup
   - **6006**: System shutdown
   - **1001**: Bugcheck (crash)
   - **41**: Power failure

**Extracting Events via PowerShell:**
```powershell
# Get startup events from last 7 days
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ID = 6005
    StartTime = (Get-Date).AddDays(-7)
} | Export-Csv -Path "startup_events.csv" -NoTypeInformation

# Get critical errors
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    Level = 1
    StartTime = (Get-Date).AddDays(-1)
} | Export-Csv -Path "critical_errors.csv" -NoTypeInformation
```

---

### 2. System Configuration (msconfig)

**Purpose:** Enables boot logging to capture the sequence of driver and service loads during startup.

**Why Use It:**
- Creates ntbtlog.txt with complete boot sequence
- Useful for identifying slow-loading drivers
- Simple interface suitable for all users
- Lightweight, minimal performance impact

**How to Enable Boot Logging:**

1. Open System Configuration:
   ```powershell
   # Method 1: Via Run
   # Win + R, type: msconfig
   
   # Method 2: Via PowerShell
   msconfig.exe
   ```

2. Go to **Boot** tab
3. Check **Boot log** checkbox
4. Click **Apply** and **OK**
5. Restart your system
6. Log file will be at: `C:\Windows\ntbtlog.txt`

**Reading ntbtlog.txt:**
```
[Boot Session: 01/07/2026 10:30:45 AM]
Loaded: C:\Windows\System32\drivers\ACPI.sys
Loaded: C:\Windows\System32\drivers\CLASSPNP.sys
Did not load: C:\Windows\System32\drivers\slowdriver.sys
```

**Parse Boot Log with PowerShell:**
```powershell
$bootLog = Get-Content C:\Windows\ntbtlog.txt | Select-String "Did not load"
$bootLog | Export-Csv -Path "failed_loads.csv"
```

---

### 3. Windows Performance Recorder (WPR) & Analyzer (WPA)

**Purpose:** Advanced kernel-level tracing for detailed performance diagnostics during boot.

**Why Use It:**
- Captures CPU, disk, network activity at kernel level
- Identifies bottlenecks with precise timing
- Part of official Windows ADK
- Professional-grade analysis capabilities

**Installation:**
1. Download Windows ADK from Microsoft
2. Install "Windows Performance Toolkit" component
3. Tools located at: `C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\`

**How to Use WPR:**

**Starting Recording:**
```powershell
# Launch WPR GUI
wpr.exe -start GeneralProfile
```

Or via command line for automated boot recording:
```powershell
# Start performance recording
wpr.exe -start GeneralProfile
# Restart computer
# After restart, stop recording
wpr.exe -stop "boot_trace.etl"

# Analyze
wpa.exe "boot_trace.etl"
```

**GUI Steps:**
1. Run `wpr.exe`
2. Select **First level triage** or **CPU usage** profile
3. Click **Start**
4. Restart computer
5. After reboot, Windows will prompt to save trace
6. Open trace in WPA for analysis

---

### 4. Reliability Monitor

**Purpose:** High-level visual dashboard of system stability events and trends.

**Why Use It:**
- Easy-to-understand timeline view
- Shows crashes, warnings, and information events
- No configuration required
- Quick overview of system health

**How to Access:**
```powershell
# Method 1: Search Start menu for "Reliability Monitor"

# Method 2: Via PowerShell
Get-WmiObject Win32_OSRecoveryConfiguration
```

**Via GUI:**
1. Press `Win + X`
2. Search for "Reliability Monitor"
3. View events on timeline
4. Click events for details
5. Export report if needed

---

## Third-Party & Sysinternals Tools

### 1. Process Monitor (Procmon)

**Purpose:** Real-time capture of file system, Registry, and process activity at the kernel level.

**Why Use It:**
- Traces exact file and Registry access
- Identifies slow operations during boot
- Pinpoints permission issues
- Captures application launch sequences

**Download & Installation:**
```powershell
# Download from Microsoft
# https://learn.microsoft.com/en-us/sysinternals/downloads/procmon

# Extract and run
.\Procmon.exe
```

**Enable Boot Logging:**

1. Run Procmon as Administrator
2. Go to **Options > Enable Boot Logging**
3. Select destination folder (default: `C:\Windows\Temp\ProcmonBoot.pml`)
4. Restart computer
5. After reboot, boot log is automatically captured

**Analyzing Boot Logs:**
```powershell
# Procmon saves as .pml file
# Open in Procmon GUI to analyze
.\Procmon.exe C:\Windows\Temp\ProcmonBoot.pml

# Filter by:
# - Process name (double-click process)
# - Operation (Registry Read/Write, File Create, etc.)
# - Result (Success/Failure)
```

**Common Boot Filters:**
- Filter **Result** to "NAME NOT FOUND" to find missing files/Registry keys
- Filter by specific executable to trace its operations
- Sort by **Duration** to find slow operations

---

### 2. Autoruns

**Purpose:** Comprehensive view of all startup items and autorun locations.

**Why Use It:**
- Shows all programs configured to run at startup
- Identifies malicious startup entries
- Verifies digital signatures
- Disables suspicious items safely

**Download & Installation:**
```powershell
# Download from Microsoft
# https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns

# Extract and run
.\Autoruns.exe
```

**Key Features:**

1. **Tabs Available:**
   - **Logon**: Programs running at user login
   - **Services**: System services
   - **Drivers**: Kernel drivers
   - **Scheduled Tasks**: Recurring tasks
   - **Browser Extensions**: Browser plugins
   - **Image Hijacks**: System process modifications

2. **Identifying Issues:**
   - Yellow highlighted entries: Recently modified
   - Unchecked items: Disabled
   - Red: Entry points to non-existent files

3. **Exporting Results:**
```powershell
# Right-click > Select All
# File > Export as CSV
```

**Integration with MiracleBoot:**
```powershell
# PowerShell to get startup items
Get-CimInstance Win32_StartupCommand | 
    Select-Object Name, Command, Location, User |
    Export-Csv -Path "startup_analysis.csv" -NoTypeInformation
```

---

### 3. BootRacer & Startup Timer

**Purpose:** Measure exact boot time and identify startup bottlenecks.

**Why Use It:**
- Simple visual display of boot duration
- Shows which applications are slowest to load
- Tracks boot time changes over time
- User-friendly interface

**Installation:**
- Download from: https://www.wrt.com/en/
- Install on target system

**Using BootRacer:**

1. Run BootRacer
2. Click **Start** to begin boot sequence measurement
3. Computer restarts and measures boot time
4. Report shows:
   - Total boot time
   - Individual application load times
   - Slowest applications
   - System configuration details

**PowerShell Alternative:**
```powershell
# Measure boot time from Event Log
$startEvent = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ID = 6005
} | Select-Object -First 1

$endEvent = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ID = 6006
} | Select-Object -First 1

$bootTime = ($endEvent.TimeCreated - $startEvent.TimeCreated).TotalSeconds
Write-Host "Boot Duration: $bootTime seconds"
```

---

## Integration with MiracleBoot

### Unified Log Collection Script

The `Collect_All_System_Logs.ps1` script automatically collects logs from all tools:

```powershell
# Runs all log collection methods
# Output: C:\MiracleBoot_Logs\[timestamp]\

.\Collect_All_System_Logs.ps1 -IncludePerformanceTrace -Destination "D:\Diagnostics"
```

**Parameters:**
- `-IncludePerformanceTrace`: Captures WPR trace (requires ADK)
- `-IncludeProcmon`: Captures Procmon boot log (requires Procmon installed)
- `-IncludeAutoruns`: Exports startup items (requires Autoruns installed)
- `-Destination`: Custom output path

### Interactive Analysis Tool

```powershell
# Launch interactive log analyzer
.\Windows_Log_Analyzer_Interactive.ps1
```

**Menu Options:**
1. View Event Viewer Events
2. Parse Boot Log (ntbtlog.txt)
3. Analyze Procmon Trace
4. Review Autoruns Startup Items
5. Check System Reliability
6. Generate Combined Report

---

## Log Analysis Workflow

### Quick 5-Minute Analysis

```powershell
# 1. Enable boot logging
msconfig.exe
# Check "Boot log" and restart

# 2. Collect logs after restart
.\Collect_All_System_Logs.ps1

# 3. Generate report
.\Windows_Log_Analyzer_Interactive.ps1
# Select option 6 for combined report
```

### Deep Diagnostics (30 minutes)

```powershell
# 1. Enable Procmon boot logging
.\Enable_Procmon_BootLogging.ps1
# Restart system

# 2. Enable WPR tracing
wpr.exe -start GeneralProfile
# Restart

# After restart:
wpr.exe -stop "boot_trace.etl"

# 3. Collect everything
.\Collect_All_System_Logs.ps1 -IncludePerformanceTrace -IncludeProcmon

# 4. Analyze
.\Windows_Log_Analyzer_Interactive.ps1
```

### Continuous Monitoring

```powershell
# Monitor for issues over time
.\Setup_Continuous_Boot_Monitoring.ps1 -IntervalDays 7
```

---

## Troubleshooting Guide

### Issue: No Boot Log Generated

**Solutions:**
1. Verify msconfig boot log is checked
2. Restart system after enabling
3. Check permissions on C:\Windows
4. Disable Secure Boot temporarily
5. Try command-line approach:
```powershell
# Enable boot logging via Registry
reg add "HKLM\System\CurrentControlSet\Services\EventLog\System" /v MaxSize /t REG_DWORD /d 524288 /f
```

### Issue: Event Viewer Shows Limited Events

**Solutions:**
1. Increase Event Log size:
```powershell
# PowerShell (Admin)
Limit-EventLog -LogName System -MaximumSize 2GB
Limit-EventLog -LogName Application -MaximumSize 2GB
```

2. Configure advanced audit policies
3. Check logging is enabled:
```powershell
Get-EventLog -List | Select-Object Log, MaximumKilobytes
```

### Issue: Procmon Boot Log Not Created

**Solutions:**
1. Run Procmon as Administrator
2. Verify write permissions to temp folder
3. Check disk space available
4. Try alternate path in Options:
```powershell
# Set custom path
reg add "HKLM\System\CurrentControlSet\Control\Session Manager" /v BootLogDirectory /t REG_SZ /d "D:\BootLogs" /f
```

### Issue: WPR Not Available

**Solutions:**
1. Install Windows ADK (Assessment and Deployment Kit)
2. Ensure Windows Performance Toolkit component selected
3. Verify tools path: `C:\Program Files (x86)\Windows Kits\10\`
4. Alternative: Use simpler tools (msconfig, Procmon)

---

## Performance Impact Summary

| Tool | Boot Impact | Log Size | Collection Time | Resource Use |
|------|-------------|----------|-----------------|--------------|
| Event Viewer | None | Low | Real-time | Minimal |
| msconfig Boot Log | Minimal | 1-2MB | 1 restart | Minimal |
| WPR | Moderate | 50-500MB | 1 restart | High during capture |
| Procmon | Moderate | 10-100MB | 1 restart | Moderate |
| Autoruns | None | <1MB | Instant | Minimal |
| Reliability Monitor | None | N/A | Real-time | Minimal |

---

## Key Event IDs Reference

| Event ID | Description | Severity |
|----------|-------------|----------|
| 6005 | System startup | Info |
| 6006 | System shutdown | Info |
| 41 | Power-Down Without Shutdown (Crash) | Critical |
| 1001 | Bugcheck (BSOD) | Critical |
| 1003 | WHEA (Hardware error) | Warning |
| 10005 | COM+ Initialization Failure | Error |
| 219 | Kernel Power Event | Critical |
| 132 | Driver Load Failure | Error |

---

## Integration Checklist

- [ ] Event Viewer configured for system events
- [ ] Boot logging enabled in msconfig
- [ ] Procmon downloaded (optional)
- [ ] Autoruns downloaded (optional)
- [ ] WPR/WPA installed (optional)
- [ ] MiracleBoot log collection scripts verified
- [ ] Custom output paths configured
- [ ] Baseline boot time measured
- [ ] Automated collection scheduled (optional)
- [ ] Team trained on log analysis procedures

---

## Next Steps

1. Run `Collect_All_System_Logs.ps1` to collect baseline
2. Open `Windows_Log_Analyzer_Interactive.ps1` for guided analysis
3. Review [DIAGNOSTIC_QUICK_REFERENCE.md](DIAGNOSTIC_QUICK_REFERENCE.md) for common issues
4. Consult [BOOT_LOGGING_GUIDE.md](BOOT_LOGGING_GUIDE.md) for advanced boot diagnostics

---

**Last Updated:** January 7, 2026  
**Version:** 1.0  
**Compatibility:** Windows 10/11, MiracleBoot v7.1.1+
