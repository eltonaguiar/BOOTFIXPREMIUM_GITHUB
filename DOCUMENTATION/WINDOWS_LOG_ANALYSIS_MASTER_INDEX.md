# Windows Log Analysis Tools - Master Index

**Date:** January 7, 2026  
**Status:** ✅ Integration Complete  
**MiracleBoot Version:** v7.1.1+

---

## 🎯 Quick Navigation

### For First-Time Users
1. Start here: [WINDOWS_LOG_ANALYSIS_GUIDE.md](WINDOWS_LOG_ANALYSIS_GUIDE.md)
2. Quick reference: [WINDOWS_LOG_ANALYSIS_QUICKREF.md](WINDOWS_LOG_ANALYSIS_QUICKREF.md)
3. Run setup: `Setup_Advanced_Diagnostics.ps1`

### For Experienced Users
- Quick reference: [WINDOWS_LOG_ANALYSIS_QUICKREF.md](WINDOWS_LOG_ANALYSIS_QUICKREF.md)
- Advanced workflows: See **Common Workflows** section below
- Integration details: [WINDOWS_LOG_ANALYSIS_INTEGRATION.md](WINDOWS_LOG_ANALYSIS_INTEGRATION.md)

### For Developers/Integration
- Integration guide: [WINDOWS_LOG_ANALYSIS_INTEGRATION.md](WINDOWS_LOG_ANALYSIS_INTEGRATION.md)
- Script APIs: See **PowerShell Scripts** section
- Customization: Advanced section in integration guide

---

## 📚 Documentation Files

| File | Purpose | Read Time |
|------|---------|-----------|
| **WINDOWS_LOG_ANALYSIS_GUIDE.md** | Comprehensive reference for all tools, why to use them, how to use them, interpretation guidelines | 20-30 min |
| **WINDOWS_LOG_ANALYSIS_QUICKREF.md** | Quick reference card with commands, workflows, common solutions | 10 min |
| **WINDOWS_LOG_ANALYSIS_INTEGRATION.md** | How tools integrate with MiracleBoot, workflows, structure | 15 min |
| **WINDOWS_LOG_ANALYSIS_MASTER_INDEX.md** | This file - navigation hub | 5 min |

---

## 🛠️ PowerShell Scripts

All scripts located in: `.\HELPER SCRIPTS\`

### 1. **Collect_All_System_Logs.ps1**
**Purpose:** Unified log collection from all available tools

**Basic Usage:**
```powershell
.\Collect_All_System_Logs.ps1
```

**Advanced Usage:**
```powershell
.\Collect_All_System_Logs.ps1 `
    -Destination "D:\Diagnostics" `
    -IncludePerformanceTrace `
    -IncludeProcmon `
    -IncludeAutoruns `
    -Verbose
```

**Parameters:**
- `-Destination` : Custom output directory (default: `C:\MiracleBoot_Logs`)
- `-IncludePerformanceTrace` : Capture WPR trace (requires ADK)
- `-IncludeProcmon` : Capture Procmon boot log (requires Procmon installed)
- `-IncludeAutoruns` : Export Autoruns data (requires Autoruns installed)
- `-Verbose` : Show detailed progress

**Output:**
- CSV files (for Excel analysis)
- TXT files (for manual review)
- COLLECTION_SUMMARY.txt (analysis guide)
- Log structure: `[Destination]\[timestamp]\`

**Runtime:** 5-10 minutes (basic), 20-30 minutes (with advanced tools)

---

### 2. **Windows_Log_Analyzer_Interactive.ps1**
**Purpose:** Interactive guided analysis of collected logs

**Basic Usage:**
```powershell
.\Windows_Log_Analyzer_Interactive.ps1
```

**Quick Analysis:**
```powershell
.\Windows_Log_Analyzer_Interactive.ps1 -QuickAnalysis
```

**With Specific Log Path:**
```powershell
.\Windows_Log_Analyzer_Interactive.ps1 -LogPath "C:\MiracleBoot_Logs\20260107_103045"
```

**Menu Options:**
1. View Event Viewer System Events (7 days)
2. View Critical Events (all time)
3. Analyze Boot Log (driver loads)
4. Review Startup Items
5. Check Services Status
6. Performance Analysis
7. Find Failed Driver Loads
8. Identify Slow Boot Items
9. Generate Full Report
0. Exit

**Output:**
- Interactive display with analysis
- ANALYSIS_REPORT.txt (saved to log directory)
- CSV/TXT files from collection

**Runtime:** 2-5 minutes

---

### 3. **Setup_Advanced_Diagnostics.ps1**
**Purpose:** One-time configuration of diagnostic tools

**Basic Usage:**
```powershell
.\Setup_Advanced_Diagnostics.ps1 -ConfigureAll
```

**Tool-Specific Setup:**
```powershell
.\Setup_Advanced_Diagnostics.ps1 -Tool EventLog
.\Setup_Advanced_Diagnostics.ps1 -Tool Procmon
.\Setup_Advanced_Diagnostics.ps1 -Tool WPR
.\Setup_Advanced_Diagnostics.ps1 -Tool Registry
```

**Configuration Actions:**
- Expands Event Log sizes to 2GB
- Enables kernel event tracing
- Provides Procmon/WPR setup instructions
- Generates setup summary

**Output:**
- Setup configuration applied to Windows
- Setup_Summary_[timestamp].txt (configuration details)

**Runtime:** 2-3 minutes

---

## 🔧 Built-In Windows Tools (No Installation)

| Tool | Purpose | Access | Best For |
|------|---------|--------|----------|
| **Event Viewer** | System event repository | `eventvwr.msc` | Errors, startup/shutdown events |
| **msconfig** | Boot log generation | `msconfig.exe` | Boot sequence analysis |
| **Reliability Monitor** | System health timeline | Start > "Reliability Monitor" | Trend analysis |
| **Task Manager** | Process/startup analysis | `taskmgr.exe` | Startup programs |
| **Device Manager** | Driver status | `devmgmt.msc` | Hardware/driver issues |

---

## 📦 Optional Third-Party Tools

| Tool | Purpose | Download | Setup Time |
|------|---------|----------|------------|
| **Procmon** | File/Registry/Process tracing | [Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon) | 5 min |
| **Autoruns** | Startup items analysis | [Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns) | 5 min |
| **WPR/WPA** | Performance analysis | [Windows ADK](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install) | 20 min |
| **BootRacer** | Boot time measurement | [BootRacer](https://www.wrt.com/en/) | 10 min |

---

## 🚀 Common Workflows

### Workflow 1: Health Check (5 minutes)
```
Goal: Is my system healthy?

Steps:
1. .\Collect_All_System_Logs.ps1
2. .\Windows_Log_Analyzer_Interactive.ps1
3. Select: 1, 3, 4, 9 (Events, Boot, Startup, Report)
4. Review ANALYSIS_REPORT.txt
```

### Workflow 2: Boot Optimization (20 minutes)
```
Goal: Speed up boot time

Steps:
1. Enable boot logging (msconfig)
2. Restart computer
3. .\Collect_All_System_Logs.ps1
4. .\Windows_Log_Analyzer_Interactive.ps1
5. Select: 3, 4, 8 (Boot, Startup, SlowItems)
6. Follow recommendations to disable unnecessary programs
```

### Workflow 3: Deep Troubleshooting (60 minutes)
```
Goal: System crashes/unstable, need deep analysis

Steps:
1. .\Setup_Advanced_Diagnostics.ps1 -ConfigureAll
2. Enable Procmon boot logging (manual)
3. Enable WPR recording (manual)
4. Restart computer
5. .\Collect_All_System_Logs.ps1 -IncludeProcmon -IncludePerformanceTrace
6. .\Windows_Log_Analyzer_Interactive.ps1 (menu 1-9)
7. Analyze with: Procmon GUI, WPA
```

### Workflow 4: Trend Monitoring (10 minutes recurring)
```
Goal: Track system health over time

Steps:
1. Schedule: .\Collect_All_System_Logs.ps1 (weekly)
2. .\Windows_Log_Analyzer_Interactive.ps1 -QuickAnalysis (weekly)
3. Compare reports across weeks
4. Look for trends: increasing errors, slowdowns
```

---

## 📊 Output Files Generated

### Collected Log Files
```
C:\MiracleBoot_Logs\[timestamp]\
├── EventViewer_System_7Days.csv              # System events (7 days)
├── EventViewer_Application_7Days.csv         # Application events (7 days)
├── EventViewer_Critical_All.csv              # Critical events (all time)
├── ntbtlog.txt                               # Boot sequence log
├── ntbtlog_FailedLoads.txt                   # Failed driver loads
├── SystemInfo_OS.txt                         # OS information
├── SystemInfo_Computer.txt                   # Hardware information
├── Drivers_Installed.csv                     # Driver list
├── StartupItems_Installed.csv                # Startup programs
├── Services_All.csv                          # Services list
├── PerformanceCounters_CPU.txt               # CPU metrics
├── PerformanceCounters_Disk.txt              # Disk metrics
├── COLLECTION_SUMMARY.txt                    # Collection metadata
├── Autoruns_All.csv                          # Startup items (if included)
├── ProcmonBoot.pml                           # Procmon trace (if included)
├── ANALYSIS_REPORT.txt                       # Full analysis report
└── Procmon analysis files (if included)
```

### Analysis Output
- **ANALYSIS_REPORT.txt** - Executive summary with recommendations
- **Interactive console output** - Menu-driven analysis results
- **CSV files** - Can be opened in Excel for sorting/filtering

---

## 🎓 Learning Path

### Beginner (Start Here)
1. Read: [WINDOWS_LOG_ANALYSIS_GUIDE.md](WINDOWS_LOG_ANALYSIS_GUIDE.md) - Overview
2. Run: `Setup_Advanced_Diagnostics.ps1`
3. Run: `Collect_All_System_Logs.ps1` (basic)
4. Run: `Windows_Log_Analyzer_Interactive.ps1` (select all options)
5. Review: Generated ANALYSIS_REPORT.txt

### Intermediate
1. Read: [WINDOWS_LOG_ANALYSIS_QUICKREF.md](WINDOWS_LOG_ANALYSIS_QUICKREF.md)
2. Follow Workflow 2 (Boot Optimization)
3. Learn: Event ID meanings and filtering
4. Practice: Exporting and analyzing CSV files in Excel

### Advanced
1. Read: [WINDOWS_LOG_ANALYSIS_INTEGRATION.md](WINDOWS_LOG_ANALYSIS_INTEGRATION.md)
2. Follow Workflow 3 (Deep Troubleshooting)
3. Install: Procmon, Autoruns, WPR
4. Learn: Boot log timing analysis, Procmon filtering
5. Create: Custom analysis scripts

---

## ⚡ Quick Commands Reference

### Essential Commands
```powershell
# Collect logs (built-in tools only)
.\Collect_All_System_Logs.ps1

# Interactive analysis
.\Windows_Log_Analyzer_Interactive.ps1

# Quick analysis (non-interactive)
.\Windows_Log_Analyzer_Interactive.ps1 -QuickAnalysis

# Setup advanced tools
.\Setup_Advanced_Diagnostics.ps1

# View Event Viewer
eventvwr.msc

# View Boot Log
notepad C:\Windows\ntbtlog.txt

# View Startup Items
Get-CimInstance Win32_StartupCommand | Format-Table -AutoSize

# Export Events to CSV
Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=(Get-Date).AddDays(-7)} | 
    Export-Csv events.csv
```

---

## 🔍 Troubleshooting Index

| Issue | Solution | Time |
|-------|----------|------|
| No boot log generated | See QUICKREF.md > Issue: "Boot log shows..." | 5 min |
| Event log full | See GUIDE.md > Common Issues > Event Log | 5 min |
| Tools not found | See INTEGRATION.md > Troubleshooting | 10 min |
| Script permissions error | Run PowerShell as Administrator | 1 min |
| Large output files | Use `-Destination` on external drive | 2 min |

---

## 📞 Support Resources

### Documentation
- 📖 [WINDOWS_LOG_ANALYSIS_GUIDE.md](WINDOWS_LOG_ANALYSIS_GUIDE.md) - Full reference
- ⚡ [WINDOWS_LOG_ANALYSIS_QUICKREF.md](WINDOWS_LOG_ANALYSIS_QUICKREF.md) - Quick reference
- 🔗 [WINDOWS_LOG_ANALYSIS_INTEGRATION.md](WINDOWS_LOG_ANALYSIS_INTEGRATION.md) - Integration details

### Scripts Help
```powershell
# Get script help
Get-Help .\Collect_All_System_Logs.ps1 -Full
Get-Help .\Windows_Log_Analyzer_Interactive.ps1 -Full
Get-Help .\Setup_Advanced_Diagnostics.ps1 -Full

# Run with verbose output
.\Collect_All_System_Logs.ps1 -Verbose
```

### External Resources
- [Microsoft Event Viewer Help](https://docs.microsoft.com/en-us/windows/win32/wes/)
- [Sysinternals Tools](https://learn.microsoft.com/en-us/sysinternals/)
- [Windows Performance Toolkit](https://docs.microsoft.com/en-us/windows-hardware/test/wpt/)

---

## 📋 Checklist for Implementation

- [ ] Read WINDOWS_LOG_ANALYSIS_GUIDE.md
- [ ] Run Setup_Advanced_Diagnostics.ps1
- [ ] Run Collect_All_System_Logs.ps1 (basic)
- [ ] Run Windows_Log_Analyzer_Interactive.ps1
- [ ] Review ANALYSIS_REPORT.txt
- [ ] Bookmark WINDOWS_LOG_ANALYSIS_QUICKREF.md
- [ ] (Optional) Install advanced tools (Procmon, WPR)
- [ ] (Optional) Schedule recurring collections
- [ ] (Optional) Set up trend monitoring

---

## 📈 Version & Status

| Item | Status |
|------|--------|
| Documentation | ✅ Complete |
| Collection Script | ✅ Complete |
| Analysis Script | ✅ Complete |
| Setup Script | ✅ Complete |
| Built-in Tools Integration | ✅ Complete |
| Procmon Support | ✅ Complete |
| WPR Support | ✅ Complete |
| Autoruns Support | ✅ Complete |

---

## 🎯 Next Steps

1. **Right Now (5 min):**
   ```powershell
   .\Setup_Advanced_Diagnostics.ps1 -ConfigureAll
   ```

2. **Today (15 min):**
   ```powershell
   .\Collect_All_System_Logs.ps1
   .\Windows_Log_Analyzer_Interactive.ps1 -QuickAnalysis
   ```

3. **This Week:**
   - Read [WINDOWS_LOG_ANALYSIS_GUIDE.md](WINDOWS_LOG_ANALYSIS_GUIDE.md)
   - Bookmark [WINDOWS_LOG_ANALYSIS_QUICKREF.md](WINDOWS_LOG_ANALYSIS_QUICKREF.md)
   - Follow Workflow 2 (Boot Optimization)

4. **Ongoing:**
   - Schedule weekly collections
   - Review trend reports
   - Optimize system based on findings

---

**Welcome to MiracleBoot's Windows Log Analysis Suite!**

📚 **Start Reading:** [WINDOWS_LOG_ANALYSIS_GUIDE.md](WINDOWS_LOG_ANALYSIS_GUIDE.md)  
🚀 **Start Collecting:** `.\Collect_All_System_Logs.ps1`  
🔍 **Start Analyzing:** `.\Windows_Log_Analyzer_Interactive.ps1`

---

*Integrated: January 7, 2026*  
*MiracleBoot v7.1.1+ Windows Log Analysis Suite*
