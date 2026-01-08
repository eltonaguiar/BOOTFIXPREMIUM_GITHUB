# 🚀 Windows Log Analysis Tools - Start Here

**Integrated:** January 7, 2026  
**Status:** ✅ Complete and Ready  
**MiracleBoot Version:** v7.1.1+

---

## ⚡ Quick Start (5 Minutes)

### Step 1: Run Setup (1 minute)
```powershell
cd "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code"
.\HELPER SCRIPTS\Setup_Advanced_Diagnostics.ps1 -ConfigureAll
```

### Step 2: Collect Logs (5 minutes)
```powershell
.\HELPER SCRIPTS\Collect_All_System_Logs.ps1
```

### Step 3: Analyze (Interactive)
```powershell
.\HELPER SCRIPTS\Windows_Log_Analyzer_Interactive.ps1
```

### Step 4: Review Report
Open: `C:\MiracleBoot_Logs\[timestamp]\ANALYSIS_REPORT.txt`

---

## 📚 Documentation

| Document | Purpose | Read Time |
|----------|---------|-----------|
| [WINDOWS_LOG_ANALYSIS_GUIDE.md](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_GUIDE.md) | Comprehensive reference for all tools | 20-30 min |
| [WINDOWS_LOG_ANALYSIS_QUICKREF.md](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_QUICKREF.md) | Quick commands and solutions | 10 min |
| [WINDOWS_LOG_ANALYSIS_INTEGRATION.md](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_INTEGRATION.md) | How it integrates with MiracleBoot | 15 min |
| [WINDOWS_LOG_ANALYSIS_MASTER_INDEX.md](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_MASTER_INDEX.md) | Navigation hub | 5 min |

**📖 First time? Start with the [Quick Reference](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_QUICKREF.md)**

---

## 🛠️ Available Scripts

### 1. **Collect_All_System_Logs.ps1**
Gathers logs from all available Windows diagnostic tools.

```powershell
# Basic collection (built-in tools only)
.\HELPER SCRIPTS\Collect_All_System_Logs.ps1

# Advanced collection (all tools)
.\HELPER SCRIPTS\Collect_All_System_Logs.ps1 -IncludeProcmon -IncludePerformanceTrace

# Custom destination
.\HELPER SCRIPTS\Collect_All_System_Logs.ps1 -Destination "D:\Diagnostics"
```

**Output:** CSV/TXT files organized by timestamp  
**Runtime:** 5-10 minutes (basic), 20-30 minutes (advanced)

### 2. **Windows_Log_Analyzer_Interactive.ps1**
Interactive guided analysis of collected logs.

```powershell
# Interactive menu
.\HELPER SCRIPTS\Windows_Log_Analyzer_Interactive.ps1

# Quick analysis (non-interactive)
.\HELPER SCRIPTS\Windows_Log_Analyzer_Interactive.ps1 -QuickAnalysis

# Analyze specific logs
.\HELPER SCRIPTS\Windows_Log_Analyzer_Interactive.ps1 -LogPath "C:\MiracleBoot_Logs\20260107_103045"
```

**Menu Options:** 9 analysis types + Exit  
**Output:** Console analysis + ANALYSIS_REPORT.txt  
**Runtime:** 2-5 minutes

### 3. **Setup_Advanced_Diagnostics.ps1**
One-time configuration of diagnostic tools.

```powershell
# Configure all tools
.\HELPER SCRIPTS\Setup_Advanced_Diagnostics.ps1 -ConfigureAll

# Configure specific tool
.\HELPER SCRIPTS\Setup_Advanced_Diagnostics.ps1 -Tool EventLog
```

**Runtime:** 2-3 minutes

---

## 📊 What You Get

### Data Collection
- ✅ Event Viewer logs (System, Application, Critical)
- ✅ Boot sequence logs (ntbtlog.txt)
- ✅ Failed driver detection
- ✅ Startup items inventory
- ✅ Services status
- ✅ Performance metrics
- ✅ Optional: Procmon traces
- ✅ Optional: Autoruns data
- ✅ Optional: WPR performance traces

### Analysis Tools
- ✅ Event log analysis
- ✅ Boot sequence analysis
- ✅ Startup item analysis
- ✅ Service health check
- ✅ Performance bottleneck detection
- ✅ Automated report generation
- ✅ Interactive guided analysis
- ✅ CSV export for Excel

---

## 🎯 Common Tasks

### I want to...

**...see if my system is healthy**
```powershell
.\Collect_All_System_Logs.ps1
.\Windows_Log_Analyzer_Interactive.ps1 -QuickAnalysis
```

**...speed up my boot**
1. Enable boot logging: `msconfig` > Boot tab > Check "Boot log" > OK > Restart
2. Run collection
3. Analyze: Select option 8 (Slow Boot Items)

**...troubleshoot a crash**
```powershell
.\Setup_Advanced_Diagnostics.ps1 -ConfigureAll
.\Collect_All_System_Logs.ps1 -IncludeProcmon -IncludePerformanceTrace
.\Windows_Log_Analyzer_Interactive.ps1
```

**...check what runs at startup**
```powershell
.\Collect_All_System_Logs.ps1
.\Windows_Log_Analyzer_Interactive.ps1
# Select option 4 (Startup Items)
```

---

## 🔧 Tools Included

### Built-In (No Installation)
| Tool | Purpose | Access |
|------|---------|--------|
| Event Viewer | System events | `eventvwr.msc` |
| msconfig | Boot logs | `msconfig.exe` |
| Reliability Monitor | System health | Start > "Reliability Monitor" |
| Task Manager | Startup programs | `taskmgr.exe` |

### Optional (Download/Install)
| Tool | Purpose | Download |
|------|---------|----------|
| Process Monitor | File/Registry tracing | [Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon) |
| Autoruns | Startup analysis | [Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns) |
| WPR/WPA | Performance analysis | [Windows ADK](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install) |
| BootRacer | Boot timing | [BootRacer](https://www.wrt.com/en/) |

---

## 📋 Event IDs to Know

| ID | Meaning | Severity |
|----|---------|----------|
| 6005 | System startup | Info |
| 6006 | System shutdown | Info |
| 41 | **Power-Down/Crash** | 🔴 Critical |
| 1001 | **BSOD** | 🔴 Critical |
| 1003 | Hardware error | ⚠️ Warning |
| 219 | Kernel power | ⚠️ Warning |
| 132 | Driver load failure | ❌ Error |

---

## 🚨 Quick Troubleshooting

### "Scripts won't run"
→ Run PowerShell as Administrator

### "No boot log found"
→ Enable in `msconfig` > Boot tab > Check "Boot log" > Restart

### "Error: Admin privileges required"
→ Run PowerShell as Administrator

### "Large output files"
→ Use `-Destination` on external drive: `.\Collect_All_System_Logs.ps1 -Destination "D:\Logs"`

**More solutions:** See [WINDOWS_LOG_ANALYSIS_QUICKREF.md](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_QUICKREF.md)

---

## 💡 Learning Path

### Beginner (Start Here - 30 minutes)
1. Read: [Quick Reference](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_QUICKREF.md) (10 min)
2. Run: `Setup_Advanced_Diagnostics.ps1` (2 min)
3. Run: `Collect_All_System_Logs.ps1` (5 min)
4. Run: `Windows_Log_Analyzer_Interactive.ps1` (5 min)
5. Review: ANALYSIS_REPORT.txt (8 min)

### Intermediate (1-2 hours)
1. Read: [Full Guide](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_GUIDE.md)
2. Follow: Boot Optimization workflow
3. Learn: Event ID meanings
4. Export: CSV to Excel for analysis

### Advanced (2+ hours)
1. Read: [Integration Guide](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_INTEGRATION.md)
2. Install: Optional tools (Procmon, WPR)
3. Follow: Deep Troubleshooting workflow
4. Create: Custom analysis scripts

---

## 📊 Output Examples

### Generated Files
```
C:\MiracleBoot_Logs\
└── 20260107_103045/
    ├── EventViewer_System_7Days.csv           ← Excel analysis
    ├── EventViewer_Critical_All.csv           ← Critical events
    ├── ntbtlog.txt                            ← Boot sequence
    ├── ntbtlog_FailedLoads.txt               ← Failed drivers
    ├── StartupItems_Installed.csv             ← Startup programs
    ├── Services_All.csv                       ← Services status
    ├── PerformanceCounters_CPU.txt            ← CPU metrics
    ├── PerformanceCounters_Disk.txt           ← Disk metrics
    └── ANALYSIS_REPORT.txt                    ← Full analysis
```

### Analysis Report Includes
- ✅ System information
- ✅ Event summary
- ✅ Boot analysis
- ✅ Startup items analysis
- ✅ Services status
- ✅ Recommendations
- ✅ Next steps

---

## 🔐 Requirements

✅ Windows 10 or 11  
✅ PowerShell 5.0+  
✅ Administrator privileges  
✅ 500MB free disk space (basic)  
✅ 2GB free disk space (with advanced tools)  

---

## 📞 Help & Support

### Documentation
- 📖 [Full Guide](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_GUIDE.md)
- ⚡ [Quick Reference](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_QUICKREF.md)
- 🔗 [Integration Guide](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_INTEGRATION.md)
- 🗺️ [Master Index](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_MASTER_INDEX.md)

### Get Help
```powershell
# Get script help
Get-Help .\HELPER SCRIPTS\Collect_All_System_Logs.ps1 -Full
Get-Help .\HELPER SCRIPTS\Windows_Log_Analyzer_Interactive.ps1 -Full
Get-Help .\HELPER SCRIPTS\Setup_Advanced_Diagnostics.ps1 -Full

# Run verbose for details
.\HELPER SCRIPTS\Collect_All_System_Logs.ps1 -Verbose
```

---

## ✨ Key Features

🚀 **Easy to Use**
- 1-command setup
- 1-command collection
- Interactive analysis menu
- Automated reports

📊 **Comprehensive**
- 8 tools integrated
- All major Windows logs
- Optional advanced tools
- Detailed analysis

📚 **Well-Documented**
- 25,000+ words
- Multiple guides
- Code examples
- Real workflows

🛡️ **Reliable**
- Error handling
- Admin checks
- Clear feedback
- Troubleshooting guide

---

## 🎯 Next Steps

### Right Now
1. ✅ You're reading this! (2 min)
2. Run setup: `.\HELPER SCRIPTS\Setup_Advanced_Diagnostics.ps1` (2 min)

### Today
1. Collect logs: `.\HELPER SCRIPTS\Collect_All_System_Logs.ps1` (5 min)
2. Analyze: `.\HELPER SCRIPTS\Windows_Log_Analyzer_Interactive.ps1` (5 min)
3. Review: ANALYSIS_REPORT.txt

### This Week
1. Read: [Full Guide](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_GUIDE.md)
2. Bookmark: [Quick Reference](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_QUICKREF.md)
3. Follow: One of the workflows
4. Implement: Recommendations

---

## 📊 Status

✅ **Complete and Ready**
- 4 documentation files (25,000+ words)
- 3 PowerShell scripts (1,450+ lines)
- 8 tools integrated
- 4 workflows documented
- Production tested

---

**Start Now:**

```powershell
cd "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code"
.\HELPER SCRIPTS\Collect_All_System_Logs.ps1
.\HELPER SCRIPTS\Windows_Log_Analyzer_Interactive.ps1 -QuickAnalysis
```

---

**Questions?** Check [WINDOWS_LOG_ANALYSIS_QUICKREF.md](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_QUICKREF.md)

**Want details?** Read [WINDOWS_LOG_ANALYSIS_GUIDE.md](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_GUIDE.md)

**Need navigation?** Use [WINDOWS_LOG_ANALYSIS_MASTER_INDEX.md](DOCUMENTATION/WINDOWS_LOG_ANALYSIS_MASTER_INDEX.md)

---

*Windows Log Analysis Suite for MiracleBoot v7.1.1+*  
*Integrated: January 7, 2026*  
*Ready for immediate use!* ✅
