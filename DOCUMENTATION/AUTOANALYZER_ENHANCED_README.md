# AutoLogAnalyzer Enhanced - Phase 2 Implementation

## Overview

**AutoLogAnalyzer Enhanced** extends the original analyzer with a built-in error code database, automatic error matching, and specific suggested fixes for each identified issue.

**Key Differences from Phase 1:**
- Phase 1: Extracted error codes + generated ChatGPT prompts
- Phase 2: Error codes + database matching + specific fixes + severity ranking

## What's New

### 1. Built-in Error Code Database
- **37 Error Codes** with full context
- Each entry includes:
  - Error name and description
  - 2-5 common causes
  - 5-7 specific suggested fixes
  - Severity level (1-10)
  - Component category (Services, Security, API, Kernel, etc.)

**Codes Included:**
- EventID codes: 1000, 7000, 7009, 7034, 10016, 36871, 219, 4096, etc.
- HRESULT codes: 0x80004005, 0x80070005, 0x80070002, etc.
- NT Status codes: STATUS_ACCESS_DENIED, STATUS_INSUFFICIENT_RESOURCES, etc.

### 2. Automatic Error Matching
- Extracts Event IDs from log entries
- Searches for HRESULT codes in messages
- Looks up each code in database
- Enriches errors with causes and fixes

### 3. Enhanced Reports

**ANALYSIS_WITH_FIXES.txt**
- Structured list of all identified errors
- Sorted by severity (critical first)
- For each error:
  - Error code and name
  - Number of occurrences
  - Why it matters (description)
  - Common causes (bullet list)
  - Suggested fixes (numbered steps)
  - Affected components

**FIXES_FOR_CHATGPT.txt**
- ChatGPT-friendly format
- Ready to paste into AI assistant
- Includes all context and fixes
- Good for discussion/brainstorming

**ERROR_ANALYSIS.csv**
- Excel-compatible
- Contains: Error code, name, count, severity, category, sources
- Easy to sort/filter in spreadsheet

### 4. Severity Ranking
Each error has a severity level (1-10):
- 10: Immediate action required (SSL/TLS failures, critical services)
- 8-9: High priority (service crashes, application errors)
- 5-7: Medium priority (permission issues, warnings)
- 1-4: Low priority (deprecation notices, informational)

Critical issues (9-10) are prioritized first in reports.

## Usage

### Quick Start
```powershell
# Run the enhanced launcher
RUN_ANALYZER_ENHANCED.cmd

# Or run directly with PowerShell
.\AutoLogAnalyzer_Enhanced.ps1 -HoursBack 48
```

### Command Line Options
```powershell
# Analyze last 48 hours (default)
.\AutoLogAnalyzer_Enhanced.ps1

# Analyze last 7 days
.\AutoLogAnalyzer_Enhanced.ps1 -HoursBack 168

# Analyze custom period (24 hours)
.\AutoLogAnalyzer_Enhanced.ps1 -HoursBack 24

# Specify custom output location
.\AutoLogAnalyzer_Enhanced.ps1 -OutputPath "C:\MyReports"

# Generate detailed report
.\AutoLogAnalyzer_Enhanced.ps1 -GenerateDetailedReport
```

## Example Output

### Console Output
```
==== AutoLogAnalyzer Enhanced ====
Analysis Period: Last 48 hours

[1/4] Collecting Event Viewer Logs...
  Collected 523 from System
  Collected 347 from Application

[2/4] Extracting and Matching Errors...
  Found 18 unique error codes with database matches

[3/4] Generating Reports...
  Generated: ANALYSIS_WITH_FIXES.txt
  Generated: FIXES_FOR_CHATGPT.txt
  Generated: ERROR_ANALYSIS.csv

[4/4] Summary

Total Errors Found: 18
Critical Issues: 3
Warnings: 8

TOP CRITICAL ISSUES:
  [10/10] EventID_36871 - SSL/TLS Certificate Error (104x)
  [9/10] EventID_7034 - Service Crashed (12x)
  [9/10] EventID_1000 - Application Error / Crash (8x)

Report Location: C:\Users\zerou\Downloads\...\LOG_ANALYSIS_ENHANCED\Analysis_2026-01-15_143022
```

### Sample Report Entry

```
==== SYSTEM LOG ANALYSIS WITH ERROR DATABASE ====

CRITICAL ISSUES (Priority First)
============================================================

ERROR: EventID_36871 - SSL/TLS Certificate Error
  Occurrences: 104
  Severity: CRITICAL
  Description: Secure channel SSL/TLS certificate validation or handshake failed.
  Affected: System

  Common Causes:
    • System clock incorrect
    • Expired certificate
    • Untrusted root CA
    • SSL policy mismatch

  Suggested Fixes (In Order):
    1. IMMEDIATE: Fix system date/time (Settings > Time & Language)
    2. Run Windows Update
    3. Clear SSL cache: certutil -setreg chain\\ChainCacheResync 1
    4. Update root certificates: certutil -generateSSTFromWU root.sst
    5. Run: sfc /scannow
    6. Disable antivirus SSL inspection temporarily
```

## Understanding the Reports

### Priority Order
1. **Critical Issues (Severity 9-10)** - Fix FIRST
2. **High Priority (Severity 7-8)** - Fix SECOND
3. **Medium Priority (Severity 5-6)** - Fix THIRD
4. **Low Priority (Severity 1-4)** - Fix when convenient

### How to Use Suggested Fixes
1. Read the fixes in order
2. Follow each step sequentially
3. After each fix, monitor Event Log for changes
4. Re-run analyzer to verify improvement

### Escalation
If you don't understand a fix:
1. Copy the error entry to ChatGPT
2. Paste FIXES_FOR_CHATGPT.txt into AI
3. Ask for step-by-step explanation
4. Get help with specific commands

## Common Critical Errors

### EventID_36871 - SSL/TLS Certificate Error
**Severity:** 10/10 (CRITICAL)
- **Cause:** Usually system time is wrong or certificate expired
- **Impact:** HTTPS fails, Windows Update broken, secure connections fail
- **Quick Fix:** Set correct system date/time immediately

### EventID_7034 - Service Crashed
**Severity:** 9/10 (CRITICAL)
- **Cause:** Service crashed unexpectedly during operation
- **Impact:** System service not working, may affect multiple components
- **Quick Fix:** Restart service: `net stop SERVICE && net start SERVICE`

### EventID_1000 - Application Error
**Severity:** 9/10 (CRITICAL)
- **Cause:** Application crashed, usually driver or resource issue
- **Impact:** Application unusable, may affect system stability
- **Quick Fix:** Update drivers and run `sfc /scannow`

### EventID_7000 - Service Failed to Start
**Severity:** 8/10 (HIGH)
- **Cause:** Service won't start during boot
- **Impact:** System feature unavailable, may affect dependent services
- **Quick Fix:** Check services.msc, verify dependencies

## Reports Generated

| File | Purpose | Best For |
|------|---------|----------|
| ANALYSIS_WITH_FIXES.txt | Complete analysis with all fixes | Reading, understanding |
| FIXES_FOR_CHATGPT.txt | AI-ready format | Sharing with ChatGPT |
| ERROR_ANALYSIS.csv | Data format | Excel, sorting/filtering |

## Workflow

### Typical Usage Flow
```
1. Run: RUN_ANALYZER_ENHANCED.cmd
   ↓
2. Select "Quick Scan (48 hours)"
   ↓
3. Wait for analysis to complete
   ↓
4. View ANALYSIS_WITH_FIXES.txt
   ↓
5. Prioritize critical issues (severity 9-10)
   ↓
6. Follow suggested fixes in order
   ↓
7. Re-run scan after implementing fixes
   ↓
8. Verify improvement in error counts
```

## Database Structure

Each error entry contains:
```
'EventID_36871' = @{
    Name = 'SSL/TLS Certificate Error'
    Severity = 'CRITICAL'
    Category = 'Security'
    Description = '...'
    CommonCauses = @('Cause1', 'Cause2', ...)
    SuggestedFixes = @('Fix1', 'Fix2', ...)
    Severity_Level = 10
}
```

This ensures:
- Fast lookups (hashtable)
- No external dependencies (all data embedded)
- Easy updates (add new codes as needed)
- Structured retrieval (can extract specific fields)

## Adding New Error Codes

To add a new error to the database, edit `AutoLogAnalyzer_Enhanced.ps1` and add an entry to the `$ErrorDatabase` hashtable:

```powershell
'EventID_XXXX' = @{
    Name = 'Error Name'
    Severity = 'CRITICAL|ERROR|WARNING'
    Category = 'Category'
    Description = 'What this error means'
    CommonCauses = @('Cause1', 'Cause2', 'Cause3')
    SuggestedFixes = @('Fix1', 'Fix2', 'Fix3', 'Fix4')
    Severity_Level = 10  # 1-10, higher = more critical
}
```

## Performance

- **Collection Time:** 30-60 seconds (collects 1000+ events)
- **Analysis Time:** 30-60 seconds (matches against database)
- **Report Generation:** 10-20 seconds (creates 3 reports)
- **Total:** Typically 2-3 minutes

## System Requirements

- Windows 10 or later
- PowerShell 5.0 or later (built-in)
- Administrator access (recommended, for Security log)
- No internet required (database is embedded)

## Troubleshooting

### No errors found
- Run longer scan (use -HoursBack 168 for 7 days)
- Check Event Viewer directly: eventvwr.msc
- Some errors may have been cleared

### Access Denied errors
- Run as Administrator
- Try scanning just Application + System logs
- Security log may need elevated privileges

### Script won't run
- Run as Administrator
- Check execution policy: `Get-ExecutionPolicy`
- Fix with: `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process`

## Next Steps After Fixing

1. **Verify Fixes:**
   - Restart and monitor for 24 hours
   - Re-run analyzer
   - Compare before/after error counts

2. **If Issues Remain:**
   - Review logs for related errors
   - Search online for specific error code + component
   - Share FIXES_FOR_CHATGPT.txt with support

3. **For Complex Issues:**
   - Use FIXES_FOR_CHATGPT.txt with ChatGPT
   - Include system specifications
   - Provide before/after screenshots
   - Ask for step-by-step guidance

## Related Files

- `AutoLogAnalyzer_Enhanced.ps1` - Main analyzer script
- `RUN_ANALYZER_ENHANCED.cmd` - Interactive launcher
- `AutoLogAnalyzer_Lite.ps1` - Previous lightweight version
- `ErrorCodeDatabase.ps1` - Standalone error database (for reference)

## Support

For issues or to add error codes:
1. Check existing error in database
2. Review suggested fixes
3. Try fixes in order
4. If stuck, share FIXES_FOR_CHATGPT.txt with AI assistance
