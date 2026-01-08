# AutoLogAnalyzer - Complete Documentation Index

## 📍 You Are Here

Welcome to the AutoLogAnalyzer suite! This is your index to all available resources.

---

## 🚀 Getting Started (Pick One)

### **New Users - Start Here**
📄 [AUTOANALYZER_README.md](AUTOANALYZER_README.md)
- Overview of what AutoLogAnalyzer does
- Simple 3-step quick start
- Common use cases
- FAQ section

### **Quick Reference Card**
📋 [AUTOANALYZER_QUICKREF.md](AUTOANALYZER_QUICKREF.md)
- One-page cheat sheet
- Common commands
- Error type reference
- Troubleshooting table

### **Complete User Guide**
📚 [DOCUMENTATION/AUTOANALYZER_GUIDE.md](DOCUMENTATION/AUTOANALYZER_GUIDE.md)
- Detailed feature explanations
- Advanced options
- Integration with MiracleBoot
- Scheduled task setup

---

## 🎯 Main Scripts

### **AUTO_ANALYZE_LOGS.ps1** (Recommended)
**Interactive menu-driven wrapper**
```powershell
.\AUTO_ANALYZE_LOGS.ps1
```
Best for: Users who like visual menus and step-by-step guidance

Features:
- ✅ Interactive menu
- ✅ Pre/Post repair comparison
- ✅ Report browser
- ✅ View previous analyses

### **AutoLogAnalyzer.ps1** (Core Engine)
**Direct analysis script**
```powershell
.\AutoLogAnalyzer.ps1
```
Best for: Power users and automation

Features:
- ✅ Direct analysis
- ✅ Custom time ranges
- ✅ Flexible output paths
- ✅ Scriptable

### **RUN_LOG_ANALYZER.cmd** (Easiest)
**One-click launcher**
```
Double-click: RUN_LOG_ANALYZER.cmd
```
Best for: Users who want no learning curve

Features:
- ✅ No PowerShell knowledge needed
- ✅ Launches interactive menu
- ✅ Error checking

---

## 📊 Report Types

### After Running Analysis

Your reports will be in: `LOG_ANALYSIS/ANALYSIS_DATE_TIME/`

#### **DETAILED_REPORT.txt**
- Summary statistics
- Top 20 error codes
- Error distribution by type
- Error distribution by severity
- Full context for each error

**Use when**: You want a complete overview of all issues

#### **CHATGPT_PROMPT.txt** ⭐ Most Useful
- PROMPT 1: "What do these error codes mean?"
- PROMPT 2: "How do I fix these errors?"
- Pre-formatted for ChatGPT
- Copy and paste ready

**Use when**: You want AI-assisted troubleshooting

#### **ERROR_CODES.csv**
- Spreadsheet-compatible format
- Deduped error codes
- Count, type, severity
- Sources and affected log files

**Use when**: You want to analyze in Excel

#### **ALL_ERRORS_RAW.csv**
- Every error instance (not deduplicated)
- Full message text
- Exact timestamps
- Complete context

**Use when**: You need deep details on specific errors

---

## 💡 Common Workflows

### Workflow 1: Quick Troubleshooting
```
1. .\AUTO_ANALYZE_LOGS.ps1
   Select [1] Quick Log Analysis
   
2. Wait for completion
   File explorer opens with reports
   
3. Open CHATGPT_PROMPT.txt
   Copy PROMPT 1
   
4. Paste into ChatGPT
   Ask: "What do these mean and how serious are they?"
```

### Workflow 2: Repair Validation
```
1. .\AUTO_ANALYZE_LOGS.ps1
   Select [2] Pre-Repair Analysis
   
2. .\MiracleBoot.ps1
   Run your repairs
   
3. .\AUTO_ANALYZE_LOGS.ps1
   Select [3] Post-Repair Analysis
   
4. .\AUTO_ANALYZE_LOGS.ps1
   Select [4] Compare Before/After
   Shows: Fixed errors ✅ vs New issues ⚠️
```

### Workflow 3: Deep Investigation
```
1. .\AutoLogAnalyzer.ps1 -HoursBack 168
   (Analyze last 7 days)
   
2. Open ERROR_CODES.csv in Excel
   Sort by Count (descending)
   
3. Open CHATGPT_PROMPT.txt
   Copy PROMPT 2
   
4. Paste into ChatGPT
   Ask: "What causes these patterns?"
```

### Workflow 4: Remote Analysis
```
1. Copy AutoLogAnalyzer.ps1 to another computer
   
2. Run: .\AutoLogAnalyzer.ps1
   
3. Transfer CSV files
   
4. Analyze remotely
   Open CHATGPT_PROMPT.txt files
```

---

## 🔧 Command Reference

### Basic Usage
```powershell
# Last 48 hours (default)
.\AutoLogAnalyzer.ps1

# Last 24 hours
.\AutoLogAnalyzer.ps1 -HoursBack 24

# Last week
.\AutoLogAnalyzer.ps1 -HoursBack 168

# Last 30 days
.\AutoLogAnalyzer.ps1 -HoursBack 720
```

### Custom Output
```powershell
# Save to custom location
.\AutoLogAnalyzer.ps1 -OutputPath "C:\Reports"

# Combine options
.\AutoLogAnalyzer.ps1 -HoursBack 72 -OutputPath "$env:TEMP\Analysis"
```

### Interactive Menu
```powershell
# Launch menu
.\AUTO_ANALYZE_LOGS.ps1

# Specific mode
.\AUTO_ANALYZE_LOGS.ps1 -Mode "Quick"
.\AUTO_ANALYZE_LOGS.ps1 -Mode "PreRepair"
.\AUTO_ANALYZE_LOGS.ps1 -Mode "PostRepair"
```

---

## 📖 Documentation Map

```
📦 AutoLogAnalyzer Suite
│
├─ 📍 This File (You are here)
│
├─ 🚀 Getting Started
│  ├─ AUTOANALYZER_README.md (Big picture)
│  ├─ AUTOANALYZER_QUICKREF.md (One page)
│  └─ DOCUMENTATION/AUTOANALYZER_GUIDE.md (Deep dive)
│
├─ 🎯 Main Scripts
│  ├─ AUTO_ANALYZE_LOGS.ps1 (Menu wrapper)
│  ├─ AutoLogAnalyzer.ps1 (Core engine)
│  └─ RUN_LOG_ANALYZER.cmd (One-click)
│
├─ 📊 Reports (Generated)
│  ├─ DETAILED_REPORT.txt
│  ├─ CHATGPT_PROMPT.txt ⭐
│  ├─ ERROR_CODES.csv
│  └─ ALL_ERRORS_RAW.csv
│
└─ 🗂️ Output Directory Structure
   LOG_ANALYSIS/
   ├─ ANALYSIS_2026-01-07_140000/
   │  ├─ DETAILED_REPORT.txt
   │  ├─ CHATGPT_PROMPT.txt
   │  ├─ ERROR_CODES.csv
   │  └─ ALL_ERRORS_RAW.csv
   │
   ├─ PRE_REPAIR_2026-01-07_141000/
   ├─ POST_REPAIR_2026-01-07_150000/
   └─ ... (more analyses)
```

---

## ❓ Which File Should I Use?

### "I want to start now"
→ [AUTOANALYZER_README.md](AUTOANALYZER_README.md)

### "I need a quick reference"
→ [AUTOANALYZER_QUICKREF.md](AUTOANALYZER_QUICKREF.md)

### "I want to learn everything"
→ [DOCUMENTATION/AUTOANALYZER_GUIDE.md](DOCUMENTATION/AUTOANALYZER_GUIDE.md)

### "I just want to analyze logs"
→ Run: `.\AutoLogAnalyzer.ps1`

### "I like menus"
→ Run: `.\AUTO_ANALYZE_LOGS.ps1` or double-click `RUN_LOG_ANALYZER.cmd`

### "I want to use ChatGPT"
→ [AUTOANALYZER_README.md](AUTOANALYZER_README.md#-how-to-use-chatgpt-prompts)

### "I want before/after comparison"
→ [AUTOANALYZER_GUIDE.md - Workflow Section](DOCUMENTATION/AUTOANALYZER_GUIDE.md)

---

## 🔄 Integration Points

### With MiracleBoot
AutoLogAnalyzer complements MiracleBoot by:
1. Identifying issues before repairs
2. Creating repair validation snapshots
3. Proving repairs worked
4. Providing ChatGPT-ready analysis

Suggested workflow:
```
1. .\AutoLogAnalyzer.ps1 -HoursBack 168   (Last week baseline)
2. .\MiracleBoot.ps1                       (Run repairs)
3. .\AutoLogAnalyzer.ps1                   (Check after repair)
4. Compare reports to show improvement
```

### With Other Tools
- **CSV output** → Excel pivot tables
- **ChatGPT prompts** → AI troubleshooting
- **Error codes** → Microsoft KB article searches
- **Scheduled tasks** → Continuous monitoring

---

## ✅ Checklist

Getting ready to analyze?

- [ ] Running PowerShell as Administrator
- [ ] In correct directory: `c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code`
- [ ] Have 5-10 minutes available for first run
- [ ] Decided on analysis method:
  - [ ] Menu (AUTO_ANALYZE_LOGS.ps1)
  - [ ] Direct (AutoLogAnalyzer.ps1)
  - [ ] One-click (RUN_LOG_ANALYZER.cmd)
- [ ] Ready to copy prompts to ChatGPT?

---

## 🎓 Learning Path

### Beginner (5 minutes)
1. Read: [AUTOANALYZER_README.md](AUTOANALYZER_README.md) - "Quick Start" section
2. Run: `.\AutoLogAnalyzer.ps1`
3. Copy ChatGPT prompt to chat.openai.com

### Intermediate (30 minutes)
1. Read: [AUTOANALYZER_QUICKREF.md](AUTOANALYZER_QUICKREF.md)
2. Try all menu options in `AUTO_ANALYZE_LOGS.ps1`
3. Do pre/post repair comparison
4. Review CSV reports in Excel

### Advanced (1-2 hours)
1. Read: [DOCUMENTATION/AUTOANALYZER_GUIDE.md](DOCUMENTATION/AUTOANALYZER_GUIDE.md)
2. Create scheduled task
3. Integrate with custom PowerShell scripts
4. Analyze reports programmatically

---

## 📞 Help & Support

### Quick Issues
- **Script won't run**: Check [AUTOANALYZER_QUICKREF.md](AUTOANALYZER_QUICKREF.md) - Troubleshooting section
- **No logs found**: Try `-HoursBack 168` instead
- **Can't find files**: Verify you're in correct directory

### Detailed Help
- **How do I use ChatGPT prompts?** → See [AUTOANALYZER_README.md](AUTOANALYZER_README.md)
- **How do I compare reports?** → See [AUTOANALYZER_GUIDE.md](DOCUMENTATION/AUTOANALYZER_GUIDE.md)
- **What do these error codes mean?** → Open CHATGPT_PROMPT.txt and copy to ChatGPT

### Need More?
1. Review DETAILED_REPORT.txt from your analysis
2. Search error codes on microsoft.com/en-us/support
3. Copy CSV data to ChatGPT for detailed analysis

---

## 🎉 Ready to Start?

### Option 1: Menu-Driven (Easiest)
```powershell
cd "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code"
.\AUTO_ANALYZE_LOGS.ps1
```

### Option 2: One-Click (Simplest)
```
Double-click: RUN_LOG_ANALYZER.cmd
```

### Option 3: Direct Analysis (Fastest)
```powershell
.\AutoLogAnalyzer.ps1
```

---

## 📝 Version Info

- **AutoLogAnalyzer Version**: 1.0
- **Created**: January 7, 2026
- **Compatible With**: Windows 10/11, PowerShell 5.0+
- **Part Of**: MiracleBoot v7.2 Suite

---

## 🗺️ Site Map

All Documentation Files:
- 📍 **INDEX.md** ← You are here
- [README.md](AUTOANALYZER_README.md) - Main guide
- [QUICKREF.md](AUTOANALYZER_QUICKREF.md) - One-page card
- [DOCUMENTATION/GUIDE.md](DOCUMENTATION/AUTOANALYZER_GUIDE.md) - Deep dive
- [AutoLogAnalyzer.ps1](AutoLogAnalyzer.ps1) - Core engine
- [AUTO_ANALYZE_LOGS.ps1](AUTO_ANALYZE_LOGS.ps1) - Menu wrapper
- [RUN_LOG_ANALYZER.cmd](RUN_LOG_ANALYZER.cmd) - Launcher

---

**Start your first analysis now!** ✨

Choose your style:
- 🎯 Menu lover? → `.\AUTO_ANALYZE_LOGS.ps1`
- ⚡ Power user? → `.\AutoLogAnalyzer.ps1`
- 🖱️ One-clicker? → `RUN_LOG_ANALYZER.cmd`

Happy analyzing! 🔍
