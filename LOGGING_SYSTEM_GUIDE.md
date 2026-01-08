# MiracleBoot v7.2.0 - Logging System Documentation

## Overview

MiracleBoot now includes a **comprehensive logging system** that captures all errors, warnings, and operational events. This makes troubleshooting much simpler - users can just say "fix the errors" and provide the log file.

---

## ✨ Key Features

### 1. **Automatic Log File Creation**
- Logs created in: `LOGS_MIRACLEBOOT\` subdirectory
- Filename format: `MiracleBoot_YYYYMMDD_HHMMSS.log`
- Example: `MiracleBoot_20260108_010512.log`

### 2. **Automatic Log Cleanup**
- Old logs (>7 days) automatically deleted
- Prevents disk space issues
- Only logs from current run kept

### 3. **Comprehensive Logging Coverage**
- ✓ Script initialization
- ✓ Environment detection
- ✓ Admin privilege verification
- ✓ Preflight checks
- ✓ Module loading
- ✓ Error details
- ✓ Warnings
- ✓ Session summary

### 4. **Structured Log Format**
```
[HH:MM:SS] [LEVEL] Message
[01:05:12] [INFO] Environment detected: FullOS
[01:05:12] [ERROR] ERROR: This script requires administrator privileges
[01:05:12] [SUCCESS] Logging system initialized successfully
```

---

## Log Levels

| Level | Use Case | Color |
|-------|----------|-------|
| **INFO** | General operational information | White |
| **SUCCESS** | Successful operations | Green |
| **WARNING** | Non-critical issues | Yellow |
| **ERROR** | Critical issues | Red |
| **DEBUG** | Detailed debugging info | Gray |

---

## Finding Logs

### Location
```
c:\Users\<YourUsername>\Downloads\MiracleBoot_v7_1_1 - Github code\LOGS_MIRACLEBOOT\
```

### List All Logs
```powershell
Get-ChildItem 'LOGS_MIRACLEBOOT' -Filter '*.log' | Sort-Object LastWriteTime -Descending
```

### View Latest Log
```powershell
Get-Content -Tail 50 (Get-ChildItem 'LOGS_MIRACLEBOOT' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
```

### Search for Errors
```powershell
Get-Content 'LOGS_MIRACLEBOOT\MiracleBoot_*.log' | Select-String '\[ERROR\]|\[WARNING\]'
```

---

## Log File Information

### Displayed During Execution
The log file path is displayed in the console output:
```
Log File: C:\Users\...\LOGS_MIRACLEBOOT\MiracleBoot_20260108_010512.log
```

### Contents

#### Header (Session Start)
```
════════════════════════════════════════════════════════════════
MiracleBoot v7.2.0 - Session Started
Timestamp: 2026-01-08 01:05:12
Environment: FullOS
Administrator: No
PowerShell: 5.1.26100.7462
════════════════════════════════════════════════════════════════
```

#### Main Content
```
[01:05:12] [INFO] Logging system initialized successfully
[01:05:12] [INFO] Environment detected: FullOS
[01:05:12] [INFO] Starting preflight validation checks
[01:05:12] [ERROR] ERROR: This script requires administrator privileges
```

---

## Logging Functions

### Write-ToLog
Logs a message to both console and file.

```powershell
Write-ToLog -Message "Script started" -Level "INFO"
Write-ToLog -Message "Operation succeeded" -Level "SUCCESS"
Write-ToLog -Message "Warning: Low disk space" -Level "WARNING"
Write-ToLog -Message "Failed to load module" -Level "ERROR"
```

### Write-ErrorLog
Logs an error with full exception details.

```powershell
Write-ErrorLog -Message "Module failed" -Exception $_ -Details $modulePath
```

### Write-WarningLog
Logs a warning message.

```powershell
Write-WarningLog -Message "WPF not available, using TUI"
```

### Export-LogFile
Returns the full path to the current log file.

```powershell
$logPath = Export-LogFile
Write-Host "Log saved to: $logPath"
```

### Get-LogSummary
Returns a summary of all logged errors and warnings.

```powershell
$summary = Get-LogSummary
Write-Host "Total Errors: $($summary.ErrorCount)"
Write-Host "Total Warnings: $($summary.WarningCount)"
```

---

## Troubleshooting Guide

### Problem: Script Fails, Need Logs

**Step 1**: Run the script
```powershell
.\MiracleBoot.ps1
```

**Step 2**: Note the log file path from console output
```
Log File: C:\Users\...\LOGS_MIRACLEBOOT\MiracleBoot_20260108_010512.log
```

**Step 3**: Share the log file contents
```powershell
Get-Content 'LOGS_MIRACLEBOOT\MiracleBoot_20260108_010512.log' | Out-File error_log.txt
# Share error_log.txt
```

### Problem: Many Log Files Accumulated

**Automatic Cleanup**: Logs older than 7 days are automatically deleted on script startup.

**Manual Cleanup**:
```powershell
# Delete logs older than 7 days
$cutoff = (Get-Date).AddDays(-7)
Get-ChildItem 'LOGS_MIRACLEBOOT' -Filter '*.log' | 
    Where-Object { $_.LastWriteTime -lt $cutoff } | 
    Remove-Item
```

### Problem: Log File Path Truncated in Console

The full path is still valid - Windows just displays it wrapped. Use:
```powershell
# Get the latest log file directly
$latestLog = Get-ChildItem 'LOGS_MIRACLEBOOT' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content $latestLog.FullName
```

---

## Viewing Logs

### In PowerShell
```powershell
# View latest log
Get-Content (Get-ChildItem 'LOGS_MIRACLEBOOT' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

# Follow log in real-time
Get-Content -Path 'LOGS_MIRACLEBOOT\MiracleBoot_*.log' -Wait

# Search for errors
Get-Content 'LOGS_MIRACLEBOOT\*.log' | Select-String 'ERROR'
```

### In Notepad
```powershell
# Open latest log in Notepad
notepad (Get-ChildItem 'LOGS_MIRACLEBOOT' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
```

### In Text Editor
1. Navigate to: `LOGS_MIRACLEBOOT` folder
2. Open latest `.log` file with any text editor

---

## Log Analysis

### Count Errors
```powershell
(Get-Content 'LOGS_MIRACLEBOOT\MiracleBoot_20260108_010512.log' | Select-String '\[ERROR\]').Count
```

### Count Warnings
```powershell
(Get-Content 'LOGS_MIRACLEBOOT\MiracleBoot_20260108_010512.log' | Select-String '\[WARNING\]').Count
```

### Extract Only Errors
```powershell
Get-Content 'LOGS_MIRACLEBOOT\MiracleBoot_20260108_010512.log' | Select-String '\[ERROR\]'
```

### Get Session Duration
```powershell
$log = Get-Content 'LOGS_MIRACLEBOOT\MiracleBoot_20260108_010512.log'
$first = $log[0] -match '\[(.*?)\]' | % { $Matches[1] }
$last = $log[-1] -match '\[(.*?)\]' | % { $Matches[1] }
Write-Host "Started: $first, Ended: $last"
```

---

## Global Variables

You can access logging information in the script:

```powershell
# Current log file path
$global:LogPath

# Error count
$global:ErrorCount

# Warning count
$global:WarningCount

# All log entries as array
$global:LogBuffer
```

---

## Integration with Support

### For Support Requests
When reporting issues:

1. Run the script
2. Note the log file path
3. Copy the entire log file
4. Send to support with error description

### Troubleshooting Workflow
```
1. User reports: "Script is failing"
2. Request: "Please share the log file"
3. User: "Log file: C:\...\MiracleBoot_20260108_010512.log"
4. Support: Reads log, identifies [ERROR] entries, provides fix
```

---

## Log File Examples

### Example 1: Admin Check Failure
```
[01:05:12] [INFO] ════════════════════════════════════════════════════════════════
[01:05:12] [INFO] MiracleBoot v7.2.0 - Session Started
[01:05:12] [INFO] Timestamp: 2026-01-08 01:05:12
[01:05:12] [INFO] Environment: FullOS
[01:05:12] [INFO] Administrator: No
[01:05:12] [INFO] PowerShell: 5.1.26100.7462
[01:05:12] [INFO] ════════════════════════════════════════════════════════════════
[01:05:12] [SUCCESS] Logging system initialized successfully
[01:05:12] [INFO] Environment detected: FullOS
[01:05:12] [ERROR] ERROR: This script requires administrator privileges
```

### Example 2: Module Loading Success
```
[01:06:23] [INFO] Logging system initialized successfully
[01:06:23] [INFO] Environment detected: FullOS
[01:06:23] [INFO] Starting preflight validation checks
[01:06:24] [SUCCESS] Preflight checks completed
[01:06:24] [INFO] Loading WinRepairCore module...
[01:06:24] [SUCCESS] WinRepairCore loaded successfully
[01:06:24] [INFO] Loading optional EnsureRepairInstallReady module...
[01:06:24] [SUCCESS] EnsureRepairInstallReady loaded successfully
```

---

## Configuration

### Log Retention
Currently set to 7 days - old logs automatically deleted.

To modify (edit MiracleBoot.ps1):
```powershell
# In Initialize-LogSystem function
$cutoffDate = (Get-Date).AddDays(-7)  # Change -7 to desired days
```

### Log Location
Currently: `LOGS_MIRACLEBOOT` subdirectory in script folder.

Falls back to `%TEMP%\LOGS_MIRACLEBOOT` if subdirectory can't be created.

---

## Best Practices

### 1. **Check Logs After Failures**
Always check the log file when something goes wrong.

### 2. **Archive Important Logs**
Keep logs from failed repairs for future reference:
```powershell
Copy-Item 'LOGS_MIRACLEBOOT\MiracleBoot_*.log' 'C:\Archive\'
```

### 3. **Automate Log Analysis**
Create a script to analyze logs:
```powershell
$logs = Get-ChildItem 'LOGS_MIRACLEBOOT'
foreach ($log in $logs) {
    $errors = (Get-Content $log | Select-String '\[ERROR\]').Count
    Write-Host "$($log.Name): $errors errors"
}
```

### 4. **Share Full Context**
When reporting issues, share the entire log file, not just error lines.

---

## Frequently Asked Questions

### Q: Where are the logs stored?
**A**: In the `LOGS_MIRACLEBOOT` subdirectory next to MiracleBoot.ps1

### Q: Are old logs automatically cleaned up?
**A**: Yes, logs older than 7 days are automatically deleted

### Q: Can I disable logging?
**A**: Not recommended, but you can comment out the Initialize-LogSystem line

### Q: What if the log file gets corrupted?
**A**: A new one is created on the next script run

### Q: Can I export logs to a different format?
**A**: Yes, read the log and pipe to your desired format:
```powershell
Get-Content log.log | ConvertFrom-Csv | Export-Excel log.xlsx
```

### Q: Are logs encrypted?
**A**: No, logs are plain text for easy reading

### Q: Can multiple instances write to the same log?
**A**: No, each instance gets its own timestamped log file

---

## Summary

The logging system ensures that:

✅ All errors and warnings are captured  
✅ Session details are recorded  
✅ Old logs don't accumulate  
✅ Log paths are visible to users  
✅ Troubleshooting is straightforward  
✅ Support can diagnose issues quickly  

**Result**: When users say "fix the errors," you have all the context needed!

---

**MiracleBoot v7.2.0 - Logging System**  
*Professional-grade diagnostics for easy troubleshooting*  
*Last Updated: January 8, 2026*
