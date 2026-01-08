# AutoLogAnalyzer - Quick Reference Card

## 🚀 Three Ways to Start

### 1️⃣ **Easiest - Interactive Menu**
```
Double-click: RUN_LOG_ANALYZER.cmd
OR
.\AUTO_ANALYZE_LOGS.ps1
```
Then select from menu.

### 2️⃣ **Fastest - Direct Analysis**
```
.\AutoLogAnalyzer.ps1
```
Analyzes last 48 hours, generates all reports.

### 3️⃣ **Flexible - Custom Options**
```
.\AutoLogAnalyzer.ps1 -HoursBack 24 -OutputPath "C:\Reports"
```

---

## 📊 Output Files Explained

| File | What It Is | Use For |
|------|-----------|---------|
| `DETAILED_REPORT.txt` | Full analysis with all errors | Reading about issues |
| `CHATGPT_PROMPT.txt` | ⭐ Two copy-paste prompts | ChatGPT troubleshooting |
| `ERROR_CODES.csv` | Spreadsheet format | Excel analysis |
| `ALL_ERRORS_RAW.csv` | Every error instance | Deep debugging |

---

## 💬 Using ChatGPT Prompts

```
1. Run analysis:   .\AUTO_ANALYZE_LOGS.ps1
2. Select [1]:     Quick Log Analysis
3. Wait for done, file explorer opens
4. Open latest folder
5. Open CHATGPT_PROMPT.txt
6. Copy PROMPT 1 section
7. Paste into chat.openai.com
8. Ask: "What do these errors mean?"
```

---

## 🔄 Before/After Comparison

### Pre-Repair
```powershell
.\AUTO_ANALYZE_LOGS.ps1
Select [2]: Pre-Repair Analysis
```

### Run Repairs
```powershell
.\MiracleBoot.ps1
```

### Post-Repair
```powershell
.\AUTO_ANALYZE_LOGS.ps1
Select [3]: Post-Repair Analysis
```

### See Results
```powershell
.\AUTO_ANALYZE_LOGS.ps1
Select [4]: Compare Before/After Reports
```

---

## 🕐 Time Range Options

```powershell
.\AutoLogAnalyzer.ps1 -HoursBack 24      # Last 24 hours
.\AutoLogAnalyzer.ps1 -HoursBack 168     # Last 7 days
.\AutoLogAnalyzer.ps1 -HoursBack 720     # Last 30 days
.\AutoLogAnalyzer.ps1 -HoursBack 8760    # Last year (!)
```

---

## 🔍 Error Code Types You'll See

| Type | Example | Meaning |
|------|---------|---------|
| **Event ID** | `EventID_1000` | Windows event code |
| **HRESULT** | `0x80004005` | API error code |
| **NT Status** | `STATUS_FILE_NOT_FOUND` | Kernel error |

---

## ⚡ Quick Commands

```powershell
# Just do it (48 hours)
.\AutoLogAnalyzer.ps1

# Quick today-only analysis
.\AutoLogAnalyzer.ps1 -HoursBack 24

# Check from 2 weeks ago
.\AutoLogAnalyzer.ps1 -HoursBack 336

# Custom folder
.\AutoLogAnalyzer.ps1 -OutputPath "D:\Analysis"

# Everything together
.\AutoLogAnalyzer.ps1 -HoursBack 72 -OutputPath "$env:TEMP\QuickAnalysis"
```

---

## ❌ If It Doesn't Work

| Issue | Fix |
|-------|-----|
| "Script won't run" | `Set-ExecutionPolicy Bypass -Scope Process -Force` |
| "Access Denied" | Run PowerShell as Administrator |
| "No logs found" | Try `-HoursBack 168` (more time = more logs) |
| "Can't find file" | Make sure you're in: `c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code` |

---

## 📂 Where Files Go

```
LOG_ANALYSIS/
├── ERRORS_2026-01-07_142030/
│   ├── DETAILED_REPORT.txt           ← Read this
│   ├── CHATGPT_PROMPT.txt            ← Copy this to ChatGPT
│   ├── ERROR_CODES.csv
│   └── ALL_ERRORS_RAW.csv
├── PRE_REPAIR_2026-01-07_143000/     ← Baseline before repairs
└── POST_REPAIR_2026-01-07_145000/    ← Comparison after repairs
```

---

## 🎯 Common Tasks

**"What's wrong with my computer?"**
```
1. .\AUTO_ANALYZE_LOGS.ps1
2. Select [1]
3. Copy PROMPT 1 to ChatGPT
```

**"Did my repairs help?"**
```
1. .\AUTO_ANALYZE_LOGS.ps1
2. Select [2] (before repairs)
3. Run repairs
4. .\AUTO_ANALYZE_LOGS.ps1
5. Select [3] (after repairs)
6. .\AUTO_ANALYZE_LOGS.ps1
7. Select [4] (compare)
```

**"Check errors from 3 days ago"**
```
.\AutoLogAnalyzer.ps1 -HoursBack 72
```

**"Save analysis to specific folder"**
```
.\AutoLogAnalyzer.ps1 -OutputPath "C:\MyReports"
```

---

## 🔔 Remember

✅ Run as Administrator for full log access  
✅ First run takes longer (collects logs)  
✅ Subsequent runs are faster  
✅ ChatGPT prompts are your best friend  
✅ Compare before/after to prove repairs worked  

---

## 📖 Full Guides

- **Complete Guide**: `DOCUMENTATION/AUTOANALYZER_GUIDE.md`
- **Main README**: `AUTOANALYZER_README.md`
- **This Card**: You're reading it! 📍

---

**Pro Tip**: Save this card to your desktop for quick reference!

```powershell
# Copy to desktop
Copy-Item "AUTOANALYZER_QUICKREF.md" "$env:USERPROFILE\Desktop\"
```

---

*Version 1.0 | Created January 7, 2026*
