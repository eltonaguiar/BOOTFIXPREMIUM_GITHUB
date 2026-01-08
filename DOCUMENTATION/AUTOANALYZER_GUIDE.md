# AutoLogAnalyzer - Quick Start Guide

## Overview
**AutoLogAnalyzer** is a comprehensive system log analysis tool that automatically:
- Collects Event Viewer logs (System, Application, Security)
- Analyzes local application log files
- Extracts and deduplicates error codes
- Generates ChatGPT-friendly summaries for troubleshooting

## Features

### ✓ Automatic Log Collection
- Windows Event Viewer (System, Application, Security logs)
- Local application logs from common paths
- Filters by time range (default: last 48 hours)

### ✓ Smart Error Extraction
Recognizes multiple error code formats:
- Event Viewer Event IDs
- HRESULT codes (0xXXXXXXXX format)
- NT Status codes (STATUS_* format)
- HTTP status codes
- Process/application errors

### ✓ Intelligent Deduplication
- Groups identical error codes
- Tracks frequency of occurrence
- Identifies most critical issues
- Shows first and last occurrence time

### ✓ ChatGPT-Ready Output
Two prompt templates pre-formatted for AI assistance:
1. **Prompt 1**: Summary of top error codes with context
2. **Prompt 2**: Detailed error patterns for root cause analysis

## Installation

1. Copy `AutoLogAnalyzer.ps1` to your MiracleBoot directory
2. Ensure PowerShell execution policy allows script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
   ```

## Usage

### Basic Usage (Last 48 hours)
```powershell
.\AutoLogAnalyzer.ps1
```

### Last 24 Hours
```powershell
.\AutoLogAnalyzer.ps1 -HoursBack 24
```

### Last 7 Days
```powershell
.\AutoLogAnalyzer.ps1 -HoursBack 168
```

### Custom Output Location
```powershell
.\AutoLogAnalyzer.ps1 -OutputPath "C:\MyLogs"
```

### All Options Combined
```powershell
.\AutoLogAnalyzer.ps1 -HoursBack 24 -OutputPath "C:\Reports"
```

## Output Files

When analysis completes, you'll receive:

### 1. **DETAILED_REPORT.txt**
- Comprehensive analysis with all error codes
- Top 20 most frequent errors
- Error distribution by type and severity
- Timestamps and sources for each error

### 2. **CHATGPT_PROMPT.txt**
- **PROMPT 1**: Copy-paste ready for ChatGPT
  - Lists top 10 error codes with occurrences
  - Includes types, severity, and context
  - Ask ChatGPT: "What do these errors mean?"

- **PROMPT 2**: Detailed error context prompt
  - Groups errors by type
  - Provides detailed context for each
  - Ask ChatGPT: "What causes these and how do I fix them?"

### 3. **ERROR_CODES.csv**
- Deduplicated error codes
- Count, type, severity for each
- Importable into Excel or other tools
- Sources and log files affected

### 4. **ALL_ERRORS_RAW.csv**
- Every error instance (not deduplicated)
- Full context for each occurrence
- Timestamps
- Complete message text

## How to Use ChatGPT Prompts

### Method 1: Two-Part Analysis (Recommended)

**Step 1 - Understanding Errors:**
1. Open `CHATGPT_PROMPT.txt`
2. Copy **PROMPT 1** section
3. Paste into ChatGPT with this intro: "I'm experiencing these Windows system errors"
4. Ask follow-up questions about specific codes

**Step 2 - Detailed Troubleshooting:**
1. Go back to `CHATGPT_PROMPT.txt`
2. Copy **PROMPT 2** section
3. Ask: "Based on these error patterns, what are the most likely root causes and how do I fix them?"

### Method 2: Full Context Analysis

1. Copy entire `CHATGPT_PROMPT.txt`
2. Ask ChatGPT: "Here's a system log analysis - help me troubleshoot"
3. ChatGPT will prioritize errors and suggest fixes

## Understanding Error Types

### Event Viewer Error Codes
- Format: `EventID_XXXX`
- Source: Windows Event Viewer
- Meaning: System or application event
- Example: `EventID_1000` (Application Error)

### HRESULT Codes
- Format: `0xXXXXXXXX`
- Source: COM/Windows APIs
- Meaning: Specific error return value
- Example: `0x80004005` (E_FAIL - Unspecified error)

### NT Status Codes
- Format: `STATUS_XXXXX`
- Source: Windows kernel/driver level
- Meaning: Kernel operation result
- Example: `STATUS_FILE_NOT_FOUND`

## Example Report

```
╔════════════════════════════════════════════════════════════════╗
║          COMPREHENSIVE SYSTEM LOG ANALYSIS REPORT             ║
╚════════════════════════════════════════════════════════════════╝

Report Generated: 2026-01-07 14:30:22
Analysis Scope: Last 48 hours
System: MYCOMPUTER (DOMAIN\USER)

───────────────────────────────────────────────────────────────
SUMMARY STATISTICS
───────────────────────────────────────────────────────────────
Total Unique Error Codes: 47
Total Error Occurrences: 1,243
Most Frequent Error: EventID_1000 (156 times)

───────────────────────────────────────────────────────────────
TOP 5 ERROR CODES
───────────────────────────────────────────────────────────────

[1] EventID_1000
    Type:              Event Viewer
    Occurrences:       156
    Severity:          Error
    Sources:           Application
    Log Files:         Application
    First Seen:        2026-01-05 14:22:11
    Last Seen:         2026-01-07 13:45:09
    Sample Context:    Faulting application name: explorer.exe
```

## Troubleshooting

### No logs found?
- Ensure at least 48 hours have passed since system issues
- Try: `.\AutoLogAnalyzer.ps1 -HoursBack 168` (1 week)
- Check that you're running as Administrator

### Files not generating?
- Check output directory exists and is writable
- Verify: `Test-Path "C:\path\to\output"`
- Try different path: `.\AutoLogAnalyzer.ps1 -OutputPath "$env:TEMP"`

### ChatGPT prompts not working?
- Copy the entire **PROMPT 1** or **PROMPT 2** section
- Use exact formatting - don't modify error codes
- If too long, split into two separate ChatGPT conversations

## Integration with MiracleBoot

AutoLogAnalyzer complements MiracleBoot by:
1. **Diagnostic Phase**: Collect baseline logs before repairs
2. **Problem Identification**: Understand root causes
3. **Validation Phase**: Check logs after repairs
4. **Documentation**: Create evidence of issues and fixes

Suggested workflow:
```powershell
# 1. Run analyzer to understand problems
.\AutoLogAnalyzer.ps1

# 2. Get AI assistance with prompts
# (Copy prompts to ChatGPT)

# 3. Run MiracleBoot repairs
.\MiracleBoot.ps1

# 4. Run analyzer again to validate fixes
.\AutoLogAnalyzer.ps1

# 5. Compare reports to show improvement
```

## Advanced Options

### Run in Background
```powershell
Start-Job -ScriptBlock { & ".\AutoLogAnalyzer.ps1" }
Get-Job
Receive-Job -Id 1  # Check results
```

### Schedule Daily Analysis
```powershell
# Create scheduled task
$action = New-ScheduledTaskAction -Execute powershell.exe `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File AutoLogAnalyzer.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 3:00AM
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "AutoLogAnalyzer"
```

## Notes

- Requires Administrator privileges to access Security logs
- Some application logs may require elevated permissions
- First run takes longer due to log collection
- Subsequent runs are faster due to time-based filtering

## Support

For issues or enhancements:
1. Review the error output carefully
2. Check DETAILED_REPORT.txt for full context
3. Validate error codes against Microsoft KB articles
4. Share ERROR_CODES.csv with technical support

---

**Version**: 1.0
**Last Updated**: January 7, 2026
**Compatibility**: Windows 10/11, PowerShell 5.0+
