# Windows Log Analysis Tools - MiracleBoot Integration Index

**Integration Date:** January 7, 2026  
**Version:** 1.0  
**Compatibility:** Windows 10/11, PowerShell 5.0+, MiracleBoot v7.1.1+

---

## Overview

This integration adds comprehensive Windows log analysis capabilities to MiracleBoot by combining built-in Windows tools, Sysinternals utilities, and custom PowerShell automation scripts.

### What's Included

✅ **Comprehensive Documentation**
- WINDOWS_LOG_ANALYSIS_GUIDE.md - Full reference guide
- WINDOWS_LOG_ANALYSIS_QUICKREF.md - Quick reference card

✅ **Automation Scripts**
- Collect_All_System_Logs.ps1 - Unified log collection
- Windows_Log_Analyzer_Interactive.ps1 - Interactive analysis tool
- Setup_Advanced_Diagnostics.ps1 - Tool configuration

✅ **Tool Integration**
- Event Viewer (built-in)
- Boot logging via msconfig
- Procmon boot tracing support
- Autoruns integration
- Windows Performance Analyzer support
- Reliability Monitor data collection

---

## Quick Start Guide

### 1. Initial Setup (One-time, 5 minutes)

```powershell
# Run as Administrator
cd "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code"
.\HELPER SCRIPTS\Setup_Advanced_Diagnostics.ps1 -ConfigureAll
```

This will:
- Expand Event Log sizes to 2GB each
- Enable kernel event tracing
- Show instructions for Procmon/WPR setup

### 2. Collect Logs (5-30 minutes depending on options)

```powershell
# Basic collection (built-in tools only)
.\HELPER SCRIPTS\Collect_All_System_Logs.ps1

# With advanced tools
.\HELPER SCRIPTS\Collect_All_System_Logs.ps1 `
    -IncludeProcmon `
    -IncludePerformanceTrace `
    -Destination "D:\DiagnosticData"
```

### 3. Analyze Results (Interactive)

```powershell
# Launch interactive analyzer
.\HELPER SCRIPTS\Windows_Log_Analyzer_Interactive.ps1

# Or quick analysis
.\HELPER SCRIPTS\Windows_Log_Analyzer_Interactive.ps1 -QuickAnalysis
```

---

## Tools Included in Integration

### Built-In Windows Tools (No Installation Required)

#### 1. **Event Viewer (eventvwr.msc)**
- **Purpose:** Central Windows event repository
- **Key Events:** 6005 (startup), 6006 (shutdown), 41 (crash), 1001 (BSOD)
- **Access:** `Win + R` → `eventvwr.msc`
- **Automated Export:**
```powershell
Get-WinEvent -FilterHashtable @{LogName='System'; ID=6005; StartTime=(Get-Date).AddDays(-7)} | 
    Export-Csv startup_events.csv
```

#### 2. **System Configuration (msconfig)**
- **Purpose:** Generate boot sequence logs (ntbtlog.txt)
- **Setup:** `Win + R` → `msconfig` → Boot tab → Check "Boot log" → Restart
- **Output:** `C:\Windows\ntbtlog.txt`
- **Shows:** Sequence of driver and service loads with timing

#### 3. **Reliability Monitor**
- **Purpose:** High-level system health timeline
- **Access:** Search "Reliability Monitor" in Start menu
- **Shows:** Crashes, warnings, and system changes over time
- **Best For:** Quick overview, trend analysis

### Third-Party Tools (Optional, Requires Installation)

#### 4. **Process Monitor (Procmon) - Microsoft Sysinternals**
- **Purpose:** Kernel-level tracing of file/registry/process activity
- **Download:** https://learn.microsoft.com/en-us/sysinternals/downloads/procmon
- **Boot Logging:** Options > Enable Boot Logging (requires restart)
- **Output:** PML files analyzable in Procmon GUI
- **Best For:** Deep troubleshooting, finding missing files

#### 5. **Autoruns - Microsoft Sysinternals**
- **Purpose:** Comprehensive startup item analysis
- **Download:** https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns
- **Identifies:** Malware, unnecessary startup programs
- **Features:** Digital signature verification, safe disable/enable
- **Best For:** Startup optimization, security auditing

#### 6. **Windows Performance Recorder/Analyzer (WPR/WPA)**
- **Purpose:** Professional-grade performance analysis
- **Installation:** Windows ADK (Assessment and Deployment Kit)
- **Component:** Select "Windows Performance Toolkit"
- **Use:** Boot time measurement, bottleneck identification
- **Best For:** Professional diagnostics, performance tuning

#### 7. **BootRacer / Startup Timer**
- **Purpose:** Simple boot time measurement and application tracking
- **Download:** https://www.wrt.com/en/
- **Shows:** Individual app load times during boot
- **Best For:** Quick boot time checks, historical trending

---

## Directory Structure

```
MiracleBoot_v7_1_1 - Github code/
├── DOCUMENTATION/
│   ├── WINDOWS_LOG_ANALYSIS_GUIDE.md          ← Full reference
│   ├── WINDOWS_LOG_ANALYSIS_QUICKREF.md       ← Quick reference
│   └── WINDOWS_LOG_ANALYSIS_INTEGRATION.md    ← This file
├── HELPER SCRIPTS/
│   ├── Collect_All_System_Logs.ps1            ← Log collection
│   ├── Windows_Log_Analyzer_Interactive.ps1   ← Interactive analyzer
│   └── Setup_Advanced_Diagnostics.ps1         ← Tool setup
└── MiracleBoot_Logs/
    └── [timestamp]/
        ├── EventViewer_System_7Days.csv
        ├── EventViewer_Critical_All.csv
        ├── ntbtlog.txt
        ├── StartupItems_Installed.csv
        ├── Services_All.csv
        ├── COLLECTION_SUMMARY.txt
        └── ANALYSIS_REPORT.txt
```

---

## Common Workflows

### Workflow 1: Quick 5-Minute Health Check

**Scenario:** "Is my system healthy?"

```powershell
# 1. Collect logs (automatic via built-in tools)
.\Collect_All_System_Logs.ps1

# 2. Analyze (interactive)
.\Windows_Log_Analyzer_Interactive.ps1
# Select: 1 (Event Viewer), 3 (Boot Log), 4 (Startup), 9 (Report)

# 3. Review ANALYSIS_REPORT.txt
```

**Time:** ~5 minutes  
**Tools Used:** Event Viewer, Boot Log, Autoruns data

---

### Workflow 2: Boot Optimization (15 minutes)

**Scenario:** "How can I speed up my boot?"

```powershell
# 1. Enable boot logging
# msconfig.exe > Boot tab > Check "Boot log" > OK > Restart

# 2. After restart, collect logs
.\Collect_All_System_Logs.ps1

# 3. Analyze
.\Windows_Log_Analyzer_Interactive.ps1
# Select: 3 (Boot Log), 4 (Startup), 8 (Slow Items), 9 (Report)

# 4. Review recommendations
# - Disable unnecessary startup programs
# - Investigate failed driver loads
# - Check services that auto-start
```

**Time:** ~15 minutes + 1 restart  
**Tools Used:** Boot log, Startup items, Services analysis

---

### Workflow 3: Deep Diagnostics (30-60 minutes)

**Scenario:** "System is crashing or unstable, need deep analysis"

```powershell
# 1. Setup and enable all tools
.\Setup_Advanced_Diagnostics.ps1 -ConfigureAll

# 2. Enable Procmon boot logging
# Procmon.exe > Options > Enable Boot Logging > Restart

# 3. Enable WPR recording
# wpr.exe -start GeneralProfile > Restart

# 4. After restart, collect everything
.\Collect_All_System_Logs.ps1 `
    -IncludeProcmon `
    -IncludePerformanceTrace

# 5. Analyze with interactive tool
.\Windows_Log_Analyzer_Interactive.ps1
# Go through all options: 1-9

# 6. Open Procmon trace
# Procmon.exe C:\Windows\Temp\ProcmonBoot.pml
# Filter for failures: Result = NAME NOT FOUND

# 7. Analyze WPA trace
# wpa.exe boot_trace.etl
```

**Time:** ~60 minutes + restarts  
**Tools Used:** All tools (Event Viewer, Boot Log, Procmon, WPR, etc.)

---

### Workflow 4: Trending & Monitoring

**Scenario:** "Track system health over time"

```powershell
# 1. Setup task to run weekly
# Create scheduled task or PowerShell job:

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "02:00AM"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\MiracleBoot_Logs\collect_logs.ps1"
Register-ScheduledTask -TaskName "Weekly_System_Diagnostics" `
    -Trigger $trigger -Action $action -RunLevel Highest

# 2. Review logs weekly
cd "C:\MiracleBoot_Logs"
Get-ChildItem | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# 3. Compare reports across weeks
# Look for trends: increasing errors, slowdowns, etc.
```

---

## Integration with MiracleBoot

The Windows Log Analysis tools integrate seamlessly with MiracleBoot's existing ecosystem:

### Connected Components

1. **Diagnostic Suite**
   - Complements existing MiracleBoot diagnostics
   - Uses same logging infrastructure
   - Shared output format (CSV/TXT/PS objects)

2. **Automated Analysis**
   - Integrates with MiracleBoot's AUTO_ANALYZE_LOGS.ps1
   - Compatible with existing report generation
   - Cross-references Event Viewer with MiracleBoot logs

3. **Testing Framework**
   - Can be triggered from RUN_ALL_TESTS.ps1
   - Generates test artifacts for QA
   - Produces trackable metrics

### Calling from Existing Scripts

```powershell
# From MiracleBoot test suite
& ".\HELPER SCRIPTS\Collect_All_System_Logs.ps1" `
    -Destination ".\TEST_LOGS\Windows_Diagnostics" `
    -Verbose

# From AUTO_ANALYZE_LOGS.ps1
& ".\HELPER SCRIPTS\Windows_Log_Analyzer_Interactive.ps1" `
    -LogPath ".\TEST_LOGS\Windows_Diagnostics\[latest]" `
    -QuickAnalysis
```

---

## Event ID Reference

### Critical Events to Monitor

| ID | Meaning | Severity | Action |
|----|---------|----------|--------|
| 6005 | System Startup | Info | Baseline event |
| 6006 | System Shutdown | Info | Normal shutdown |
| 41 | Power-Down Without Shutdown (Crash) | **Critical** | Investigate immediately |
| 1001 | Bugcheck/BSOD | **Critical** | Check dump file, error code |
| 1003 | WHEA Hardware Error | Warning | Check hardware |
| 219 | Kernel Power Event | Warning | Power supply or hardware |
| 132 | Driver Load Failure | Error | Verify driver installation |
| 10005 | COM+ Initialization | Error | May indicate startup issues |

### How to Find These in Event Viewer

```powershell
# Get critical events programmatically
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    Level = 1  # Critical and Error
    StartTime = (Get-Date).AddDays(-7)
} | Select-Object TimeCreated, Id, LevelDisplayName, Source, Message | Out-GridView
```

---

## Troubleshooting

### Issue: "No boot log generated"

**Solution:**
```powershell
# Verify msconfig setting
reg query "HKLM\System\CurrentControlSet\Control\Session Manager" /v BootOptionsPersist

# Manually enable
reg add "HKLM\System\CurrentControlSet\Control\Session Manager" `
    /v BootOptionsPersist /t REG_DWORD /d 0 /f

# Restart and check C:\Windows\ntbtlog.txt
```

### Issue: "Event log keeps filling up"

**Solution:**
```powershell
# Increase log size
Limit-EventLog -LogName System -MaximumSize 4GB
Limit-EventLog -LogName Application -MaximumSize 4GB

# Configure retention
wevtutil sl System /maxsize:4194304
wevtutil sl Application /maxsize:4194304
```

### Issue: "Procmon boot log not found"

**Solution:**
```powershell
# Verify Procmon has write permissions
icacls "C:\Windows\Temp" /grant:r "$env:USERNAME:(F)" /T

# Run Procmon and manually enable boot logging
# Procmon.exe > Options > Enable Boot Logging > OK > Restart
```

### Issue: "WPR not installed"

**Solution:**
```powershell
# Download Windows ADK from:
# https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
# Install and select "Windows Performance Toolkit" component only
```

---

## Performance Impact

| Operation | Boot Time | Memory | Disk | Notes |
|-----------|-----------|--------|------|-------|
| Event Viewer only | None | Minimal | Minimal | Safest option |
| Boot log (msconfig) | <5% | Minimal | <5MB | Recommended |
| Procmon boot trace | 10-15% | High during capture | 10-100MB | Data analysis only |
| WPR recording | 20-30% | Very high | 50-500MB | Performance impact visible |
| Full analysis (all) | ~30% | High | ~200MB | Total collection only |

**Recommendation:** Use boot log (msconfig) for regular monitoring. Use Procmon/WPR only when deep diagnostics needed.

---

## Advanced Customization

### Create Custom Analysis Reports

```powershell
# Example: Find all drivers that failed to load
$bootLog = Get-Content "C:\Windows\ntbtlog.txt"
$failedLoads = $bootLog | Select-String "Did not load:" | 
    ForEach-Object { $_.Line -replace ".*: ", "" }

$failedLoads | ForEach-Object {
    $driver = $_
    Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        Message = "*$driver*"
    } | Select-Object TimeCreated, Id, Message
}
```

### Schedule Automated Collections

```powershell
# Create PowerShell profile entry for auto-collection on every boot
Add-Content $PROFILE -Value @"
if ((whoami /groups | Select-String S-1-5-32-544) -eq $null) { return }
& "C:\MiracleBoot_v7_1_1 - Github code\HELPER SCRIPTS\Collect_All_System_Logs.ps1" `
    -Destination "C:\MiracleBoot_Logs" | Out-Null
"@
```

---

## Resources & References

### Microsoft Documentation
- [Event Viewer Help](https://docs.microsoft.com/en-us/windows/win32/wes/windows-event-log)
- [Windows Performance Toolkit](https://docs.microsoft.com/en-us/windows-hardware/test/wpt/)
- [Sysinternals Suite](https://learn.microsoft.com/en-us/sysinternals/)

### MiracleBoot Documentation
- [BOOT_LOGGING_GUIDE.md](BOOT_LOGGING_GUIDE.md) - Advanced boot logging
- [DIAGNOSTIC_SUITE_GUIDE.md](DIAGNOSTIC_SUITE_GUIDE.md) - Diagnostic integration
- [WINDOWS_LOG_ANALYSIS_GUIDE.md](WINDOWS_LOG_ANALYSIS_GUIDE.md) - Full reference

### External Tools
- [Sysinternals Download Page](https://learn.microsoft.com/en-us/sysinternals/downloads/)
- [Windows ADK Download](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install)
- [BootRacer](https://www.wrt.com/en/)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-07 | Initial integration of Windows log analysis tools |

---

## Support & Feedback

For issues or suggestions:
1. Check [WINDOWS_LOG_ANALYSIS_QUICKREF.md](WINDOWS_LOG_ANALYSIS_QUICKREF.md) for quick solutions
2. Review [WINDOWS_LOG_ANALYSIS_GUIDE.md](WINDOWS_LOG_ANALYSIS_GUIDE.md) for comprehensive help
3. Run with `-Verbose` flag for detailed output
4. Check generated ANALYSIS_REPORT.txt for recommendations

---

**Next Steps:**
1. Read [WINDOWS_LOG_ANALYSIS_GUIDE.md](WINDOWS_LOG_ANALYSIS_GUIDE.md)
2. Run `Setup_Advanced_Diagnostics.ps1`
3. Execute `Collect_All_System_Logs.ps1`
4. Launch `Windows_Log_Analyzer_Interactive.ps1`

---

*Integration completed: January 7, 2026*  
*MiracleBoot v7.1.1+ Windows Log Analysis Suite*
