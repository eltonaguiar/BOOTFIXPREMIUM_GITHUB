# Windows Log Analysis Quick Reference Card

## Quick Start (5 Minutes)

### Step 1: Collect Logs
```powershell
# Run as Administrator
cd "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code"
.\HELPER SCRIPTS\Collect_All_System_Logs.ps1
```

### Step 2: Analyze Logs
```powershell
.\HELPER SCRIPTS\Windows_Log_Analyzer_Interactive.ps1
```

### Step 3: Review Results
- Check ANALYSIS_REPORT.txt for summary
- Open CSV files in Excel for detailed filtering

---

## Tool Overview Matrix

| Tool | Purpose | Speed | Depth | Installation |
|------|---------|-------|-------|--------------|
| **Event Viewer** | System event log | Fast | Medium | Built-in |
| **msconfig** | Boot sequence log | Fast | Low | Built-in |
| **Reliability Monitor** | System health timeline | Fast | Medium | Built-in |
| **Procmon** | Kernel-level tracing | Medium | Very Deep | Download |
| **Autoruns** | Startup items analysis | Fast | High | Download |
| **WPR/WPA** | Performance analysis | Slow | Very Deep | Install ADK |
| **BootRacer** | Boot time measurement | Fast | Medium | Download |

---

## Common Tasks & Tools

### I want to...
**...see what happened at startup** 
→ Event Viewer (Event ID 6005) or msconfig boot log

**...find slow-loading drivers**
→ msconfig boot log + Event Viewer (Event ID 41)

**...see all startup programs**
→ Autoruns or Task Manager > Startup tab

**...trace file/registry access during boot**
→ Procmon with boot logging

**...measure exact boot time**
→ BootRacer or WPA performance trace

**...find crashed applications**
→ Event Viewer (Event ID 1001) or Reliability Monitor

**...identify malware startup items**
→ Autoruns (look for unsigned/unknown publishers)

**...check hardware errors**
→ Event Viewer > System > Event ID 1003 (WHEA)

**...see disk usage during boot**
→ WPA or Performance counters

---

## Event Viewer Quick Guide

### Access
```powershell
# Method 1: GUI
Win + R → eventvwr.msc

# Method 2: PowerShell (Admin)
eventvwr.msc
```

### Key Event IDs
| ID | Meaning | Severity |
|---|---------|----------|
| 6005 | System startup | Info |
| 6006 | System shutdown | Info |
| 41 | Power-Down (Crash) | Critical |
| 1001 | BSOD/Bugcheck | Critical |
| 1003 | Hardware error (WHEA) | Warning |
| 219 | Kernel Power Event | Critical |
| 132 | Driver Load Failure | Error |
| 10005 | COM+ Error | Error |

### Quick Filter
1. Right-click log > Filter Current Log
2. Enter Event IDs: `6005,6006,41,1001`
3. Click OK to show filtered events

### Export Events
```powershell
# Get last 7 days of startup events
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ID = 6005
    StartTime = (Get-Date).AddDays(-7)
} | Export-Csv startup_events.csv -NoTypeInformation
```

---

## Boot Log (ntbtlog.txt) Quick Guide

### Enable Logging
1. `Win + R` → `msconfig`
2. Boot tab → Check "Boot log"
3. Click OK → Restart

### Location
`C:\Windows\ntbtlog.txt`

### Read Entries
```
Loaded: C:\Windows\System32\drivers\ACPI.sys        ← Driver loaded successfully
Did not load: C:\Windows\drivers\problem.sys        ← Failed to load
Loaded: C:\Program Files\Software\app.exe           ← Application loaded
```

### Find Slow Loads
Look for gaps in timestamps - large time jumps indicate slow-loading items

### PowerShell Analysis
```powershell
# Extract failed loads
(Get-Content C:\Windows\ntbtlog.txt) | Select-String "Did not load:" | 
    Out-File failed_loads.txt
```

---

## Startup Items Quick Check

### View Startup Items
```powershell
# All startup items
Get-CimInstance Win32_StartupCommand | 
    Select-Object Name, Location, Command | 
    Format-Table -AutoSize

# Export to CSV for analysis
Get-CimInstance Win32_StartupCommand | 
    Export-Csv startup_items.csv -NoTypeInformation
```

### Disable Programs from Startup
**Windows 11/10:**
1. Settings > Apps > Startup
2. Toggle off unnecessary programs

**Autoruns (advanced):**
1. Launch Autoruns.exe
2. Uncheck startup items to disable
3. Use yellow highlight to find recently changed items

---

## Services Status Quick Check

### View All Services
```powershell
Get-Service | Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize
```

### Find Stopped Automatic Services
```powershell
Get-Service | 
    Where-Object {$_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic'} | 
    Select-Object Name, DisplayName | 
    Format-Table -AutoSize
```

### Export Services
```powershell
Get-Service | 
    Select-Object Name, DisplayName, Status, StartType | 
    Export-Csv services.csv -NoTypeInformation
```

---

## Performance Counter Quick Check

### CPU Performance
```powershell
Get-WmiObject Win32_PerfFormattedData_PerfOS_System | 
    Select-Object ProcessorQueueLength, SystemCallsPerSec, ContextSwitchesPerSec
```

**Interpretation:**
- ProcessorQueueLength > 1 = CPU bottleneck
- High SystemCallsPerSec = High system activity
- High ContextSwitchesPerSec = Task switching overhead

### Disk Performance
```powershell
Get-WmiObject Win32_PerfFormattedData_PerfDisk_LogicalDisk -Filter "Name='C:'" | 
    Select-Object AvgDiskQueueLength, PercentDiskTime, DiskBytesPerSec
```

**Interpretation:**
- AvgDiskQueueLength > 2 = Disk bottleneck
- PercentDiskTime > 80% = Disk heavily utilized
- Low DiskBytesPerSec = Slow I/O

---

## Procmon Boot Logging Quick Guide

### Installation
1. Download from: https://learn.microsoft.com/en-us/sysinternals/downloads/procmon
2. Extract Procmon.exe to desired location

### Enable Boot Logging
```powershell
# Run as Administrator
.\Procmon.exe

# Menu: Options > Enable Boot Logging
# Select destination (default: C:\Windows\Temp\ProcmonBoot.pml)
# Restart computer
# Log automatically saved after reboot
```

### Analyze Boot Log
```powershell
# Open saved log
.\Procmon.exe C:\Windows\Temp\ProcmonBoot.pml

# Useful filters:
# - Filter > Process Name (find specific exe)
# - Filter > Result (show failures only)
# - Sort by Duration (find slow operations)
```

### Find Missing Files
```
Filter > Result > NAME NOT FOUND
```
Shows all failed file/registry lookups during boot

---

## Autoruns Quick Guide

### Installation
1. Download from: https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns
2. Extract Autoruns.exe

### Key Tabs
| Tab | Shows |
|-----|-------|
| Logon | User startup programs |
| Services | System services |
| Drivers | Kernel drivers |
| Scheduled Tasks | Automated tasks |
| Browser Extensions | Add-ons |
| Codecs | Media handlers |
| Image Hijacks | Process modifications |

### Identify Issues
- **Red entries**: Point to missing files (suspicious)
- **Yellow entries**: Recently modified (verify legitimacy)
- **Unsigned entries**: No digital signature (verify)
- **Unknown publishers**: Unverified software (investigate)

### Disable Safely
1. Uncheck item (doesn't delete, just disables)
2. Restart to test
3. Re-enable if issues occur

### Export Results
```powershell
# Command line export
.\Autoruns.exe -accepteula -a * -s autoruns_export.csv -z autoruns_backup.arn
```

---

## Common Issues & Solutions

### "Event Log is full"
```powershell
# Clear old events
Clear-EventLog -LogName System

# Or increase size
Limit-EventLog -LogName System -MaximumSize 2GB
```

### "Boot log shows many failed loads"
- Some failures are normal (legacy drivers, optional features)
- Check Event Viewer for related errors
- Search failed driver name in system logs
- Use Device Manager to check driver status

### "Services show as Stopped but should run"
```powershell
# Get details
Get-Service | Where-Object Name -eq 'ServiceName' | Format-List

# Try starting
Start-Service ServiceName

# Check for errors
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1} | 
    Where-Object Message -Match 'ServiceName'
```

### "Autoruns shows suspicious startup items"
1. Research the executable name online
2. Check company/publisher
3. Look for digital signature
4. Cross-reference with Task Manager
5. Disable if unknown and restart to test

---

## Troubleshooting Checklist

- [ ] Ran scripts as Administrator
- [ ] Closed antivirus software (may interfere with tools)
- [ ] Restarted after enabling boot logging
- [ ] Verified log files exist in output directory
- [ ] Checked for disk space (traces can be large)
- [ ] Reviewed ANALYSIS_REPORT.txt for summary
- [ ] Cross-referenced events across multiple logs
- [ ] Contacted IT for unknown entries

---

## Advanced Analysis

### Correlate Multiple Log Sources
1. Find Event ID in Event Viewer
2. Note timestamp and source
3. Look for matching entry in boot log
4. Check if service/driver in Services list
5. Verify in Autoruns if startup item

### Timeline Analysis
1. Export all logs to CSV
2. Import into Excel
3. Sort by timestamp
4. Look for correlated events
5. Identify patterns/sequences

### Performance Bottleneck Diagnosis
1. Check ProcessorQueueLength (CPU)
2. Check AvgDiskQueueLength (Disk)
3. Review boot log timing
4. Analyze Procmon I/O operations
5. Measure with BootRacer
6. Capture WPA trace for deep dive

---

## Resources

- Event Viewer Help: [MS Docs Event Viewer](https://docs.microsoft.com/en-us/windows/win32/wes/windows-event-log)
- Sysinternals Suite: [Microsoft Learn](https://learn.microsoft.com/en-us/sysinternals/)
- Performance Analysis: [WPA User Guide](https://docs.microsoft.com/en-us/windows-hardware/test/wpt/windows-performance-analyzer)
- Boot Logging: See [BOOT_LOGGING_GUIDE.md](BOOT_LOGGING_GUIDE.md)

---

## One-Liner Collections

```powershell
# Collect and analyze in one command
.\Collect_All_System_Logs.ps1; .\Windows_Log_Analyzer_Interactive.ps1 -QuickAnalysis

# Export all key data to CSVs
Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=(Get-Date).AddDays(-7)} | Export-Csv events.csv; Get-CimInstance Win32_StartupCommand | Export-Csv startup.csv; Get-Service | Export-Csv services.csv

# Find all errors from last 24 hours
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1; StartTime=(Get-Date).AddHours(-24)} | Select-Object TimeCreated, Id, Message | Out-GridView
```

---

**Last Updated:** January 7, 2026  
**Version:** 1.0  
**Part of:** MiracleBoot v7.1.1+ Integration Suite
