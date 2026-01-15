# MiracleBoot v7.2.0 (Hardened) - Quick Reference

## Overview
Production-grade Windows recovery toolkit with medical-grade safety standards. Runs on Windows 10/11, WinPE, and WinRE.

## Key Features

### 1. Automatic Environment Detection
- **FullOS**: Normal Windows installation → GUI mode (if available)
- **WinPE**: Windows PE environment → TUI mode
- **WinRE**: Windows Recovery Environment → TUI mode

### 2. Comprehensive Preflight Validation
Automatically verifies:
- ✓ Administrator privileges
- ✓ Required script files (readable, accessible)
- ✓ Required commands (Get-Volume, bcdedit, etc.)
- ✓ System drive validity
- ✓ Blocks execution if critical checks fail

### 3. Log Scanning Capability
```powershell
Invoke-LogScanning -LogPaths @("log1.txt", "log2.txt") -ErrorPatterns @("(?i)error", "(?i)failed")
```

Scans for:
- error
- exception
- failed
- critical
- fatal
- abort

(Customizable patterns)

### 4. Structured Diagnostics
Generate JSON-ready diagnostic reports:
```powershell
$report = New-PreflightReport $preflight $logScan $env
$json = ConvertTo-SafeJson $report
```

### 5. Fail-Safe Design
- Loud failures (never silent)
- Clear error messages
- Blocks unsafe operations
- Graceful degradation (GUI → TUI fallback)

---

## Usage

### Normal Execution (Requires Administrator)
```powershell
.\MiracleBoot.ps1
```

### What Happens
1. Detects environment (FullOS/WinPE/WinRE)
2. Verifies administrator privileges
3. Runs preflight checks
4. Loads core modules
5. Launches GUI (FullOS) or TUI (WinPE/WinRE)

### Non-Admin Context
Script blocks execution with:
```
FATAL ERROR: This script requires administrator privileges.
```

---

## Functions Reference

### Environment Detection
```powershell
$envType = Get-EnvironmentType
# Returns: "FullOS", "WinPE", or "WinRE"
```

### Privilege Verification
```powershell
$isAdmin = Test-AdminPrivileges
# Returns: $true or $false
```

### File Validation
```powershell
$fileCheck = Test-ScriptFileExists "WinRepairCore.ps1"
# Returns: HashTable with Exists, Readable, Size, Error
```

### Command Validation
```powershell
$cmdCheck = Test-CommandExists "bcdedit"
# Returns: HashTable with Available, Version, Error
```

### Preflight Checks
```powershell
$results = Invoke-PreflightCheck -EnvironmentType "FullOS"
# Returns: AllChecksPassed, Checks[], Summary{}
```

### Log Scanning
```powershell
$scanResults = Invoke-LogScanning -LogPaths @("app.log") -ErrorPatterns @("error", "failed")
# Returns: LogsScanned, Findings[], Summary
```

### JSON Export
```powershell
$json = ConvertTo-SafeJson @{ Key = "Value"; Count = 42 }
# Returns: JSON string (PS 2.0 compatible)
```

### Report Generation
```powershell
$report = New-PreflightReport $preflightResults $logScanResults $environmentType
# Returns: Comprehensive diagnostic object
```

---

## Architecture

### Section 1: Core Diagnostics & Validation
- ConvertTo-SafeJson
- New-DiagnosticReport
- Test-AdminPrivileges
- Get-EnvironmentType
- Test-ScriptFileExists
- Test-CommandExists
- Invoke-PreflightCheck
- Invoke-LogScanning
- New-PreflightReport

### Section 2: Initialization & Execution
- PSScriptRoot initialization
- Environment detection
- Admin privilege verification
- Module loading (WinRepairCore, optional modules)
- Interface selection (GUI/TUI)
- Error handling and fallback logic

### Section 3: Interface Launcher
- Priority 1: GUI (FullOS + WPF available)
- Priority 2: TUI (all environments)
- Priority 3: Manual exit (if TUI unavailable)

---

## Files Required

| File | Required | Environment | Purpose |
|------|----------|-------------|---------|
| WinRepairCore.ps1 | YES | All | Core repair functions |
| WinRepairTUI.ps1 | YES | All | Text-based interface |
| WinRepairGUI.ps1 | NO* | FullOS | Graphical interface |
| EnsureRepairInstallReady.ps1 | NO | All | Repair-install checks |

*Optional but recommended for FullOS

---

## Error Handling Strategy

### Fail-Safe Blocks
1. **Non-Admin**: Exit immediately
2. **Missing Core File**: Exit immediately
3. **Preflight Failed**: Exit immediately
4. **Module Load Error**: Fall back to TUI or exit

### Graceful Degradation
1. **GUI Load Error**: Fall back to TUI (non-fatal)
2. **Optional Module Missing**: Continue (non-critical)
3. **Environment Detection Ambiguous**: Default to FullOS (safe)

### Clear Messaging
All errors are prefixed with:
- `[FATAL]` - Critical, must exit
- `[ERROR]` - Error occurred, check details
- `[WARN]` - Warning, but continuing
- `[CHECK]` - Validation check
- `[LOADER]` - Module loading
- `[LAUNCH]` - Interface launching

---

## Troubleshooting

### "FATAL ERROR: This script requires administrator privileges"
**Solution**: Run PowerShell as Administrator
```powershell
Right-click PowerShell → Run as Administrator
```

### "Preflight Validation Failed"
**Solution**: Check log output for which check failed
```
✗ File: WinRepairCore.ps1: NOT FOUND
✗ File: WinRepairTUI.ps1: NOT FOUND
```
**Action**: Ensure all required files are in the same directory as MiracleBoot.ps1

### "GUI mode failed, falling back to TUI"
**Normal**: WPF unavailable or GUI module has issues
**Action**: TUI will continue - this is expected behavior

### "Could not launch TUI mode"
**Critical**: TUI module is missing or corrupted
**Action**: Re-extract MiracleBoot package, check WinRepairTUI.ps1

---

## Integration Examples

### Export Diagnostic Report as JSON
```powershell
$preflight = Invoke-PreflightCheck -EnvironmentType "FullOS"
$logScan = Invoke-LogScanning -LogPaths @("C:\Logs\app.log")
$report = New-PreflightReport $preflight $logScan "FullOS"
$json = ConvertTo-SafeJson $report | Out-File "diagnostics.json"
```

### Custom Error Pattern Scanning
```powershell
$customPatterns = @(
    "(?i)catastrophic",
    "(?i)system failure",
    "(?i)undefined behavior"
)
$results = Invoke-LogScanning -LogPaths @("app.log") -ErrorPatterns $customPatterns
```

### Batch Validation
```powershell
$files = @("WinRepairCore.ps1", "WinRepairTUI.ps1", "WinRepairGUI.ps1")
foreach ($file in $files) {
    $check = Test-ScriptFileExists $file
    Write-Host "$file : $(if ($check.Readable) { 'OK' } else { 'FAILED' })"
}
```

---

## System Requirements

### Minimum
- PowerShell 2.0 (Available in WinPE)
- Administrator privileges
- Windows 10 / 11 / WinPE / WinRE

### Recommended
- PowerShell 5.0+
- Windows 10 / 11 (for GUI)
- WPF assemblies (for GUI mode)

### Not Required
- External PowerShell modules
- .NET Framework 4.0+
- Internet connectivity (for core operation)

---

## Security Notes

- ✓ Script blocks execution if not admin (privilege check)
- ✓ Validates all file paths before sourcing
- ✓ Uses `-LiteralPath` to prevent injection
- ✓ No external network calls in core logic
- ✓ No hardcoded credentials or paths
- ✓ Proper error handling prevents information disclosure
- ✓ Log scanning is non-destructive (read-only)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 7.2.0 | Jan 2026 | Hardened release: Added preflight validation, log scanning, JSON output, fail-safe design |
| 7.1.1 | Dec 2025 | Previous version |

---

## Support

For issues:
1. Run MiracleBoot.ps1 and note any errors in [brackets]
2. Check VALIDATION_REPORT.md for known issues
3. Review HARDENING_SUMMARY.md for technical details
4. Export diagnostic report: ConvertTo-SafeJson (New-PreflightReport)

---

**MiracleBoot v7.2.0 (Hardened)**
*Production-Grade Windows Recovery Toolkit*
*Last Updated: January 8, 2026*
