# AutoLogAnalyzer - System Log Analysis & ChatGPT Integration

## 🎯 What is AutoLogAnalyzer?

AutoLogAnalyzer is an intelligent system log analysis tool that automatically:

1. **Collects** system logs from Event Viewer and local applications
2. **Analyzes** logs for error codes and critical issues  
3. **Deduplicates** repetitive errors to find the most important ones
4. **Generates** ChatGPT-friendly prompts for AI-assisted troubleshooting
5. **Creates** detailed reports with error frequency and context

Perfect for users who want to:
- ✅ Understand what's wrong with their system
- ✅ Get quick summaries of critical errors
- ✅ Get AI assistance from ChatGPT without manual log parsing
- ✅ Track system health before and after repairs

---

## 📁 Files Included

| File | Purpose |
|------|---------|
| `AutoLogAnalyzer.ps1` | Core analysis engine (run this) |
| `AUTO_ANALYZE_LOGS.ps1` | Interactive menu wrapper |
| `DOCUMENTATION/AUTOANALYZER_GUIDE.md` | Complete usage guide |
| `README.md` | This file |

---

## 🚀 Quick Start

### Option 1: Interactive Menu (Easiest)
```powershell
cd "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code"
.\AUTO_ANALYZE_LOGS.ps1
```

This launches an interactive menu where you can:
- Run quick analysis
- Create pre-repair baseline
- Create post-repair comparison
- View previous reports

### Option 2: Direct Analysis (Fastest)
```powershell
.\AutoLogAnalyzer.ps1
```

Analyzes logs from the last 48 hours and generates reports immediately.

### Option 3: Command Line (Flexible)
```powershell
# Last 24 hours
.\AutoLogAnalyzer.ps1 -HoursBack 24

# Last 7 days
.\AutoLogAnalyzer.ps1 -HoursBack 168

# Custom output location
.\AutoLogAnalyzer.ps1 -OutputPath "C:\MyReports"
```

---

## 📊 What You Get

After running the analysis, you'll get these files in `LOG_ANALYSIS` folder:

### 1. DETAILED_REPORT.txt
Comprehensive analysis with:
- All error codes found
- Frequency (how many times each appeared)
- Severity levels
- Which components were affected
- First and last occurrence times

**Use for**: Understanding all issues on the system

### 2. CHATGPT_PROMPT.txt ⭐ (Most Useful)
Two pre-formatted prompts ready to copy-paste:

**PROMPT 1**: "What do these error codes mean?"
- Lists top 10 errors
- Shows occurrence count
- Includes error type and severity

**PROMPT 2**: "How do I fix these errors?"
- Groups errors by type
- Provides context for each group
- Ideal for root cause analysis

**Use for**: Getting AI-assisted troubleshooting from ChatGPT

### 3. ERROR_CODES.csv
Spreadsheet-friendly format with:
- Error code
- Number of occurrences
- Type and severity
- Affected components

**Use for**: Importing into Excel or other tools

### 4. ALL_ERRORS_RAW.csv
Complete error data:
- Every error instance (not deduplicated)
- Full context and messages
- Exact timestamps

**Use for**: Deep investigation of specific errors

---

## 💡 How to Use ChatGPT Prompts

### Step 1: Run Analysis
```powershell
.\AUTO_ANALYZE_LOGS.ps1
# Select option [1] Quick Log Analysis
```

### Step 2: Copy Prompt
1. Wait for analysis to complete
2. File explorer opens at `LOG_ANALYSIS\` folder
3. Open the latest folder (newest date)
4. Open `CHATGPT_PROMPT.txt`
5. Copy **PROMPT 1** section

### Step 3: Paste into ChatGPT
1. Go to https://chat.openai.com/
2. Paste the entire PROMPT 1 section
3. Ask: "What do these error codes mean and how serious are they?"

### Step 4: Get Details
1. Go back to `CHATGPT_PROMPT.txt`
2. Copy **PROMPT 2** section
3. Paste into ChatGPT
4. Ask: "Based on these error patterns, what are the most likely root causes?"

---

## 🔍 Understanding Error Codes

### Event Viewer Event IDs
- **Format**: `EventID_XXXX` (e.g., `EventID_1000`)
- **Source**: Windows Event Viewer
- **Meaning**: System or application event number
- **Example**: `EventID_1000` = Application crashed

### HRESULT Codes
- **Format**: `0xXXXXXXXX` (e.g., `0x80004005`)
- **Source**: Windows COM/API errors
- **Meaning**: Specific error return value
- **Example**: `0x80004005` = Unspecified error

### NT Status Codes
- **Format**: `STATUS_XXXXX` (e.g., `STATUS_FILE_NOT_FOUND`)
- **Source**: Windows kernel/driver level
- **Meaning**: Kernel operation result
- **Example**: `STATUS_FILE_NOT_FOUND` = File doesn't exist

---

## 📈 Before/After Comparison

Track system improvements:

### Step 1: Pre-Repair Baseline
```powershell
.\AUTO_ANALYZE_LOGS.ps1
# Select option [2] Pre-Repair Analysis
# This creates a snapshot labeled "PRE_REPAIR_..."
```

### Step 2: Run MiracleBoot Repairs
```powershell
.\MiracleBoot.ps1
# Run your repairs
```

### Step 3: Post-Repair Analysis
```powershell
.\AUTO_ANALYZE_LOGS.ps1
# Select option [3] Post-Repair Analysis
# This creates a snapshot labeled "POST_REPAIR_..."
```

### Step 4: Compare
```powershell
.\AUTO_ANALYZE_LOGS.ps1
# Select option [4] Compare Before/After Reports
```

**Shows**:
- ✅ Errors that were fixed
- ⚠️ New errors introduced
- 📊 Overall improvement percentage

---

## 🎓 Common Use Cases

### Case 1: "I keep getting error messages"
1. Run: `.\AUTO_ANALYZE_LOGS.ps1`
2. Select: [1] Quick Log Analysis
3. Open the ChatGPT prompt file
4. Copy PROMPT 1 into ChatGPT
5. Ask: "What do these mean?"

### Case 2: "My system is crashing, what's wrong?"
1. Run: `.\AUTO_ANALYZE_LOGS.ps1`
2. Select: [5] Custom Analysis
3. Choose: [3] Last 30 days
4. Open the ChatGPT prompt file
5. Copy PROMPT 2 into ChatGPT
6. Ask: "What's causing these crashes?"

### Case 3: "Did my repairs actually help?"
1. Pre-repair: Select [2]
2. After repairs: Select [3]
3. Then: Select [4] to see comparison
4. Shows fixed vs new errors

### Case 4: "Specific application is having issues"
1. Run: `.\AutoLogAnalyzer.ps1 -HoursBack 24`
2. Look in ERROR_CODES.csv for app name
3. Check DETAILED_REPORT.txt for context
4. Copy relevant errors to ChatGPT

---

## ⚙️ Advanced Options

### Schedule Daily Analysis
```powershell
# Create a scheduled task for 3 AM daily
$action = New-ScheduledTaskAction -Execute powershell.exe `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File AutoLogAnalyzer.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 3:00AM
Register-ScheduledTask -Action $action -Trigger $trigger `
  -TaskName "AutoLogAnalyzer" -RunLevel Highest
```

### Run in Background
```powershell
# Start analysis without blocking
$job = Start-Job -FilePath ".\AutoLogAnalyzer.ps1"
Get-Job
Receive-Job -Id 1  # Check when done
```

### Custom Time Range
```powershell
# Last 3 days
.\AutoLogAnalyzer.ps1 -HoursBack 72

# Last 1 week
.\AutoLogAnalyzer.ps1 -HoursBack 168

# Last 30 days
.\AutoLogAnalyzer.ps1 -HoursBack 720
```

---

## 🛠️ Troubleshooting

| Problem | Solution |
|---------|----------|
| "No logs found" | Try `-HoursBack 168` (1 week) instead of default 48 hours |
| "Access Denied" | Run PowerShell as Administrator |
| "Files not generating" | Check that output folder is writable |
| "ChatGPT prompt too long" | Use PROMPT 1 and PROMPT 2 separately in different conversations |
| "Script won't run" | Set execution policy: `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force` |

---

## 📚 Integration with MiracleBoot

AutoLogAnalyzer complements MiracleBoot's repair capabilities:

```
WORKFLOW:
┌─────────────────────────────────────────────────┐
│ 1. Run AutoLogAnalyzer (PRE-REPAIR)            │
│    └─ Create baseline of current errors         │
├─────────────────────────────────────────────────┤
│ 2. Run MiracleBoot Repairs                      │
│    └─ Fix identified issues                     │
├─────────────────────────────────────────────────┤
│ 3. Run AutoLogAnalyzer (POST-REPAIR)           │
│    └─ Verify improvements                       │
├─────────────────────────────────────────────────┤
│ 4. Compare Reports                              │
│    └─ Show errors fixed vs new issues           │
└─────────────────────────────────────────────────┘
```

---

## 📝 Example Output

```
╔════════════════════════════════════════════════════════════════╗
║          COMPREHENSIVE SYSTEM LOG ANALYSIS REPORT             ║
╚════════════════════════════════════════════════════════════════╝

SUMMARY STATISTICS
Total Unique Error Codes: 47
Total Error Occurrences: 1,243
Most Frequent Error: EventID_1000 (156 times)

TOP 5 ERROR CODES
[1] EventID_1000 - 156 occurrences
    Type: Event Viewer
    Severity: Error
    Sources: Application
    
[2] 0x80070002 - 89 occurrences
    Type: HRESULT
    Severity: Error
    Sources: System
    
[3] STATUS_FILE_NOT_FOUND - 67 occurrences
    Type: NT Status
    Severity: Warning
    Sources: Application
```

---

## 🔐 Requirements

- Windows 10/11 with PowerShell 5.0+
- Administrator privileges (for Security log access)
- ~10MB disk space for reports

---

## ❓ FAQ

**Q: Will this find viruses?**  
A: No, it shows Windows errors. Use Windows Defender for security scanning.

**Q: Can I share the ChatGPT prompt online?**  
A: Yes! The prompts are generic error codes, no personal info is exposed.

**Q: How long does analysis take?**  
A: Usually 2-5 minutes depending on log size.

**Q: Can I run this on other computers?**  
A: Yes, copy the script and run on any Windows machine.

**Q: What if I have errors from months ago?**  
A: Event logs typically keep 7-30 days. Use `-HoursBack 720` for maximum history.

---

## 📞 Support

For help:
1. Check `DOCUMENTATION/AUTOANALYZER_GUIDE.md` for detailed guide
2. Review error output carefully - usually explains what went wrong
3. Check DETAILED_REPORT.txt for full context
4. Search error codes on Microsoft KB (knowledge.microsoft.com)

---

## 🎉 Next Steps

1. Run: `.\AUTO_ANALYZE_LOGS.ps1`
2. Select option [1] for quick analysis
3. Wait for completion
4. Copy ChatGPT prompt into chat.openai.com
5. Get AI-assisted troubleshooting!

---

**Version**: 1.0  
**Created**: January 7, 2026  
**Compatible**: Windows 10/11 with PowerShell 5.0+  
**Integration**: Part of MiracleBoot v7.2 suite
