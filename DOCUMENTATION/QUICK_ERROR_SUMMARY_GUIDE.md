# QuickErrorSummary - Fast Error Extraction for ChatGPT

## Overview

**QuickErrorSummary** is a lightweight error log analysis tool that quickly extracts your latest system errors and formats them for easy analysis in ChatGPT or other external AI tools.

Unlike the comprehensive AutoLogAnalyzer, this tool focuses on **speed and simplicity** - get your errors formatted for ChatGPT analysis in seconds.

---

## 🚀 Quick Start

### Easiest Way (GUI Menu)
```bash
# Run the launcher
.\HELPER SCRIPTS\RUN_QUICK_ERROR_SUMMARY.cmd
```

Then select one of the options:
- **1** = Quick summary (24 hours, compact)
- **2** = Detailed analysis (24 hours, ChatGPT-ready)
- **3** = Extended analysis (48 hours, full report)
- **4** = Custom (set your own parameters)
- **5** = Copy to clipboard (auto-copy for ChatGPT)

### PowerShell (Direct)
```powershell
# Quick summary
.\HELPER SCRIPTS\QuickErrorSummary.ps1

# Last 48 hours, full details
.\HELPER SCRIPTS\QuickErrorSummary.ps1 -HoursBack 48 -DetailLevel Full

# Copy to clipboard automatically
.\HELPER SCRIPTS\QuickErrorSummary.ps1 -CopyToClipboard

# Save to file
.\HELPER SCRIPTS\QuickErrorSummary.ps1 -OutputFile "C:\my_errors.txt"
```

---

## 📋 Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-HoursBack` | 24 | How many hours back to analyze |
| `-DetailLevel` | Summary | Output format: Compact, Summary, or Full |
| `-TopErrors` | 15 | Show this many top error codes |
| `-CopyToClipboard` | false | Auto-copy output to clipboard |
| `-OutputFile` | (none) | Save output to this file path |
| `-IncludeWarnings` | false | Include warnings (not just errors) |

---

## 📊 Detail Levels

### Compact
- ✓ Most concise
- ✓ Top error codes only
- ✓ Best for quick overview
- ✗ Minimal context
```
QuickErrorSummary.ps1 -DetailLevel Compact
```

### Summary (DEFAULT)
- ✓ Balanced format
- ✓ Error codes with sample context
- ✓ Includes frequency and severity
- ✓ ChatGPT-ready format
```
QuickErrorSummary.ps1 -DetailLevel Summary
```

### Full
- ✓ Comprehensive analysis
- ✓ All errors included
- ✓ Detailed context for each
- ✗ Longer output
- ✓ Best for deep analysis
```
QuickErrorSummary.ps1 -DetailLevel Full
```

---

## 💡 Usage Examples

### For ChatGPT Analysis
```powershell
# Get last 24 hours of errors, ChatGPT-ready, auto-copy
.\QuickErrorSummary.ps1 -CopyToClipboard

# Output includes:
# - All error codes found
# - Frequency of each error
# - Severity levels
# - Suggested ChatGPT prompt
# → Ctrl+V into ChatGPT
```

### For Troubleshooting
```powershell
# Get detailed analysis for last 48 hours
.\QuickErrorSummary.ps1 -HoursBack 48 -DetailLevel Full -TopErrors 20
```

### Save for Later Review
```powershell
# Save to file for reference
.\QuickErrorSummary.ps1 -OutputFile "C:\error_report.txt"
```

### Include Warnings
```powershell
# Also show warning-level events
.\QuickErrorSummary.ps1 -IncludeWarnings -DetailLevel Full
```

---

## 📤 Output Format

### What You Get

Each output includes:

1. **Summary Statistics**
   - Total errors found
   - Unique error codes
   - Time range analyzed

2. **Top Error Codes** (ranked by frequency)
   ```
   [1] 0x80004005
       • Occurrences: 47
       • Severity: Error
       • Sources: Windows Update, System
   ```

3. **Sample Context** (for each error)
   - When it occurred
   - Which service/component
   - Related message snippet

4. **ChatGPT-Ready Section**
   - Pre-formatted prompt
   - System info included
   - Copy-paste ready

---

## 🎯 Real-World Scenarios

### Scenario 1: Quick Problem Check
```powershell
# I want to see what went wrong in the last 24 hours
.\QuickErrorSummary.ps1
```

### Scenario 2: Share with Support
```powershell
# Get 72 hours of detailed errors and save for support ticket
.\QuickErrorSummary.ps1 -HoursBack 72 -DetailLevel Full -OutputFile "C:\support_data.txt"

# Then email the file to support team
```

### Scenario 3: Ask ChatGPT for Help
```powershell
# Quick extraction to clipboard, then paste into ChatGPT
.\QuickErrorSummary.ps1 -DetailLevel Summary -CopyToClipboard

# Ctrl+V into ChatGPT chat window
# Type: "What do these errors mean and how can I fix them?"
```

### Scenario 4: Ongoing Monitoring
```powershell
# Create a batch job to run hourly
.\QuickErrorSummary.ps1 -OutputFile "C:\logs\errors_$(Get-Date -Format 'yyyy-MM-dd').txt"
```

---

## 🔍 Error Types Detected

The tool automatically recognizes:

- **Event IDs** (EventID_1000, Event 6005, etc.)
- **HRESULT Codes** (0x80004005, 0xC0000225, etc.)
- **NT Status Codes** (STATUS_FILE_NOT_FOUND, etc.)
- **COM Errors** (E_FAIL, E_NOINTERFACE, etc.)
- **Hex Values** (0x7B, 0xD1, etc.)
- **Error Numbers** (ERRNO 5, etc.)

---

## 📝 Tips & Tricks

### 1. Always Use Admin Mode
```powershell
# Run PowerShell as Administrator first, then:
.\QuickErrorSummary.ps1
```

### 2. For Better ChatGPT Results
Include this context when pasting:
```
System: [your computer name]
OS: [Windows version]
Issue: [brief description]

Error codes found:
[paste summary output here]
```

### 3. Combine with AutoLogAnalyzer
- **QuickErrorSummary**: For fast ChatGPT-ready format
- **AutoLogAnalyzer**: For comprehensive system analysis

### 4. Schedule Regular Checks
```powershell
# Create scheduled task to run daily
$trigger = New-ScheduledTaskTrigger -Daily -At 8am
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `
  'C:\path\to\QuickErrorSummary.ps1' -OutputFile `
  'C:\Logs\daily_errors.txt'"
Register-ScheduledTask -TaskName "Daily Error Summary" `
  -Trigger $trigger -Action $action
```

---

## ✅ Comparison with AutoLogAnalyzer

| Feature | QuickErrorSummary | AutoLogAnalyzer |
|---------|-------------------|-----------------|
| Speed | ⚡ Fast (10-30s) | 🐢 Slower (1-3min) |
| Detail | 📊 Focused | 📚 Comprehensive |
| ChatGPT Ready | ✅ Native | ✅ Yes |
| Error Extraction | ✅ Yes | ✅ Yes + More |
| Log Analysis | ✅ Basic | ✅ Advanced |
| File Analysis | ❌ No | ✅ Yes |
| Best For | Quick analysis | Deep diagnostics |

---

## 🆘 Troubleshooting

### "Access Denied" Error
- Run PowerShell as Administrator
- Right-click PowerShell → "Run as Administrator"

### No Errors Found
- Try increasing `-HoursBack` parameter
- Use `-IncludeWarnings` to include warnings too
- Check if Event Viewer has actual errors

### Output Too Long
- Reduce `-TopErrors` parameter
- Use `-DetailLevel Compact`
- Reduce `-HoursBack` range

### Can't Copy to Clipboard
- May need to install clipboard module:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

---

## 📌 Related Tools

- **AutoLogAnalyzer.ps1** - Comprehensive log analysis
- **AutoLogAnalyzer_Enhanced.ps1** - Enhanced version with KB articles
- **AutoLogAnalyzer_Lite.ps1** - Lightweight alternative
- **MiracleBoot-AdvancedLogAnalyzer.ps1** - Deep boot/crash analysis

---

## 🔄 Workflow

```
1. Run QuickErrorSummary
           ↓
2. Copy output (manual or -CopyToClipboard)
           ↓
3. Open ChatGPT or paste to support ticket
           ↓
4. Paste the error summary
           ↓
5. Get AI-assisted troubleshooting
           ↓
6. Apply recommended fixes
```

---

## ⚙️ Requirements

- Windows 7 or later
- PowerShell 3.0 or later
- Administrator privileges
- Event Viewer enabled (default in Windows)

---

## 📞 Support

If QuickErrorSummary fails:

1. Check that you're running as Administrator
2. Try: `Get-EventLog -List` to verify Event Viewer works
3. Increase `-HoursBack` to see if there are older errors
4. Check your Event Viewer manually: `eventvwr.msc`

---

**Last Updated:** January 7, 2026  
**Part of MiracleBoot v7.1.1 Suite**
