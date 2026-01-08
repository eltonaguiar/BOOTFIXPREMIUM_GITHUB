# MiracleBoot Diagnostic Suite v7.2

## Overview

The Diagnostic Suite provides a comprehensive framework for gathering, analyzing, and resolving system boot failures and critical issues, with particular focus on `INACCESSIBLE_BOOT_DEVICE` and storage-related problems.

## Components

### 1. **MiracleBoot-DiagnosticHub.ps1** - Central Launcher
GUI-based central hub for all diagnostic tools and workflows.

**Features:**
- Visual interface for easy navigation
- One-click access to all tools
- Quick actions for common scenarios
- Integration with Event Viewer and Crash Analyzer

**Launch:**
```powershell
powershell -File "MiracleBoot-DiagnosticHub.ps1"
```

### 2. **MiracleBoot-LogGatherer.ps1** - Log Collection
Systematically gathers logs from the file system organized by diagnostic priority.

**Collects:**

#### TIER 1: Boot-Critical Crash Dumps (Highest Priority)
- **MEMORY.DMP** (`C:\Windows\MEMORY.DMP`)
  - Full kernel crash dump
  - Highest signal for boot failures
  - Captures entire kernel + storage stack
  
- **LiveKernelReports** (`C:\Windows\LiveKernelReports\`)
  - Silent driver hangs before full BSOD
  - Subfolders: STORAGE, WATCHDOG, NDIS, USB
  - Common with INACCESSIBLE_BOOT_DEVICE

- **Minidumps** (`C:\Windows\Minidump\`)
  - Lower priority for boot failures
  - Boot crashes often skip this

#### TIER 2: Boot Pipeline Logs
- **Setup Logs** (Panther directory)
  - `setupact.log` - Setup actions (MOST IMPORTANT)
  - `setuperr.log` - Setup errors
  - Location: `C:\$WINDOWS.~BT\Sources\Panther\` or `C:\Windows\Panther\`
  
- **Boot Trace Log** (`C:\Windows\ntbtlog.txt`)
  - Shows which drivers loaded/failed
  - Only if boot logging enabled
  
- **Diagnostics** (`C:\Windows\System32\LogFiles\`)
  - `SrtTrail.txt` - BCD and boot issues
  - `BootCKCL.etl` - Boot checklist logs

#### TIER 3: Event Logs
- **System.evtx** (`C:\Windows\System32\winevt\Logs\System.evtx`)
  - Look for Event 1001 (BugCheck)
  - Look for Event 41 (Kernel-Power)
  - Storage driver errors

#### TIER 4: Boot Structure
- **BCD Store** - Boot Configuration Database
  - Requires mounting ESP in WinPE
  - Check for missing {default}, wrong paths
  
- **Registry** - Boot-critical services
  - SYSTEM hive analysis
  - Storage driver Start values

#### TIER 5: Hardware Context
- Image restoration history
- BIOS configuration changes
- Hardware compatibility markers

**Usage:**
```powershell
# Basic gathering
powershell -File "MiracleBoot-LogGatherer.ps1"

# With specific system drive
powershell -File "MiracleBoot-LogGatherer.ps1" -OfflineSystemDrive "E:"

# Gather only (skip analysis)
powershell -File "MiracleBoot-LogGatherer.ps1" -GatherOnly

# Launch Event Viewer after gathering
powershell -File "MiracleBoot-LogGatherer.ps1" -OpenEventViewer

# Launch Crash Analyzer after gathering
powershell -File "MiracleBoot-LogGatherer.ps1" -LaunchCrashAnalyzer
```

**Output:**
- Organized in: `LOGS\LogAnalysis\`
- Text report: `RootCauseAnalysis_[timestamp].txt`
- JSON report: `Analysis_[timestamp].json`
- Execution log: `GatherAnalysis_[timestamp].log`

### 3. **MiracleBoot-AdvancedLogAnalyzer.ps1** - Deep Analysis
Performs pattern matching, signature detection, and root cause determination.

**Analyzes:**
- MEMORY.DMP signature validation
- Setup log error pattern matching
- Boot trace driver failure detection
- Event log interpretation
- LiveKernelReport correlation
- Registry corruption detection

**Decision Tree:**
1. MEMORY.DMP exists? → Analyze with Crash Analyzer
2. LiveKernelReports\STORAGE? → Storage controller hang
3. Setup logs with errors? → Boot environment mismatch
4. System event log crashes? → Review Event 1001, 41
5. ntbtlog shows driver failed? → Enable or inject driver
6. BCD missing/corrupt? → Rebuild BCD
7. Storage driver disabled? → Enable in Registry

**Usage:**
```powershell
# Full analysis with interactive menu
powershell -File "MiracleBoot-AdvancedLogAnalyzer.ps1" -Interactive

# Non-interactive analysis
powershell -File "MiracleBoot-AdvancedLogAnalyzer.ps1"

# Generate remediation script
powershell -File "MiracleBoot-AdvancedLogAnalyzer.ps1" -GenerateRemediationScript

# Custom log directory
powershell -File "MiracleBoot-AdvancedLogAnalyzer.ps1" -LogDirectory "E:\DiagLogs"
```

**Interactive Menu Options:**
1. Analyze MEMORY.DMP
2. Analyze Setup Logs
3. Analyze Boot Trace
4. Analyze Event Logs
5. Analyze LiveKernelReports
6. Analyze Registry Hive
7. Determine Root Cause
8. Generate Remediation Script
9. Open Event Viewer
0. Exit

### 4. **Setup-CrashAnalyzer.ps1** - CrashAnalyzer Configuration
Sets up Crash Dump Analyzer environment and creates launcher wrapper.

**Features:**
- Copies crashanalyze.exe from source
- Copies all DLL dependencies
- Creates PATH-aware launcher
- Resolves missing dependency issues

**Usage:**
```powershell
# Standard setup
powershell -File "Setup-CrashAnalyzer.ps1"

# With custom source path
powershell -File "Setup-CrashAnalyzer.ps1" -SourcePath "I:\Dart Crash analyzer\v10"

# Force overwrite existing
powershell -File "Setup-CrashAnalyzer.ps1" -Force
```

**Output:**
- Location: `HELPER SCRIPTS\CrashAnalyzer\`
- Executable: `crashanalyze.exe`
- Dependencies: `CrashAnalyzer\Dependencies\*.dll`
- Launcher: `CrashAnalyzer-Launcher.cmd`

---

## Quick Start Workflows

### Workflow 1: Complete Diagnostics (5-10 min)

```powershell
# Step 1: Launch Diagnostic Hub
powershell -File "MiracleBoot-DiagnosticHub.ps1"

# Step 2: Click "▶ Gather Logs Now"
# (Collects all diagnostic logs)

# Step 3: Click "📈 Analyze Logs"
# (Performs root cause analysis)

# Step 4: Review findings and recommendations
```

### Workflow 2: Emergency Boot Recovery

**Prerequisites:** Windows Recovery Environment (WinPE) access

```powershell
# Step 1: Boot into WinPE and open PowerShell
# Step 2: Run diagnostics from USB/network share
powershell -File "MiracleBoot-LogGatherer.ps1" -OfflineSystemDrive "C:"

# Step 3: Review findings
# Step 4: If storage driver issue detected:
Dism /Image:C: /Add-Driver /Driver:"<path-to-driver>" /ForceUnsigned

# Step 5: Rebuild BCD
bcdboot C:\Windows /s S: /f UEFI

# Step 6: Verify
bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum all

# Step 7: Reboot and test
```

### Workflow 3: Crash Dump Analysis

```powershell
# Step 1: Gather logs
powershell -File "MiracleBoot-LogGatherer.ps1"

# Step 2: Setup Crash Analyzer
powershell -File "Setup-CrashAnalyzer.ps1"

# Step 3: Launch and load MEMORY.DMP
powershell -File "MiracleBoot-AdvancedLogAnalyzer.ps1" -Interactive

# Step 4: In menu, select option 1 (Analyze MEMORY.DMP)
# Step 5: Crash Analyzer opens with dump loaded
```

---

## INACCESSIBLE_BOOT_DEVICE - Root Cause Decision Tree

```
INACCESSIBLE_BOOT_DEVICE (Error 0x7B)
│
├─ [YES] MEMORY.DMP exists?
│  └─► ANALYZE WITH CRASH ANALYZER (Highest Priority)
│      Command: crashanalyze.exe MEMORY.DMP
│      Or: WinDbg !analyze -v
│      Look for: Faulting driver, bug check parameters
│
├─ [NO] LiveKernelReports\STORAGE found?
│  └─► STORAGE CONTROLLER HANG (Silent Failure)
│      Action: Inject correct storage driver
│      Or: Enable driver in offline registry
│
├─ [NO] setupact.log with errors?
│  └─► PARSE FOR:
│      - Boot environment mismatch
│      - Edition/build family mismatch
│      - CBS state invalid
│      - Boot device not accessible
│
├─ [NO] System.evtx has crashes?
│  └─► REVIEW:
│      - Event 1001 (BugCheck) - Check exception code
│      - Event 41 (Kernel-Power) - Unexpected shutdown
│      - Storage error events
│
├─ [NO] ntbtlog.txt shows driver failed?
│  └─► IF STORAGE DRIVER FAILED:
│      1. Inject driver: DISM /Add-Driver
│      2. Enable in Registry
│      3. Rebuild BCD
│
├─ [NO] BCD missing/corrupted?
│  └─► REBUILD:
│      bcdboot C:\Windows /s S: /f UEFI
│
└─ [NO] Storage driver disabled in Registry?
   └─► CHECK: HKLM\SYSTEM\ControlSet001\Services\stornvme
       If Start=4 → Enable (set to 0)
       Or: Inject driver for new hardware
```

---

## File Organization

```
MiracleBoot_v7_1_1 - Github code/
│
├── HELPER SCRIPTS/
│   ├── MiracleBoot-DiagnosticHub.ps1         ← Main GUI launcher
│   ├── MiracleBoot-LogGatherer.ps1           ← Log collection
│   ├── MiracleBoot-AdvancedLogAnalyzer.ps1   ← Analysis engine
│   ├── Setup-CrashAnalyzer.ps1               ← Setup CrashAnalyzer
│   │
│   └── CrashAnalyzer/                        ← Created by Setup script
│       ├── crashanalyze.exe                  ← Copied from I:\Dart...
│       ├── CrashAnalyzer-Launcher.cmd
│       └── Dependencies/
│           ├── *.dll files
│
├── LOGS/
│   └── LogAnalysis/                          ← Created by LogGatherer
│       ├── RootCauseAnalysis_[timestamp].txt
│       ├── Analysis_[timestamp].json
│       ├── GatherAnalysis_[timestamp].log
│       ├── MEMORY.DMP
│       ├── LiveKernelReports/
│       ├── setupact.log
│       ├── setuperr.log
│       ├── ntbtlog.txt
│       ├── System.evtx
│       └── ... (other logs)
│
├── DOCUMENTATION/
│   └── DIAGNOSTIC_SUITE_GUIDE.md             ← This file
```

---

## Advanced Diagnostic Tools

### Process Monitor Boot Logging (Supplementary Tool)

**Process Monitor** (Procmon) is a free real-time system monitoring tool from Microsoft Sysinternals that provides **far more detailed** analysis than standard boot logs. Use it when standard diagnostics don't reveal the root cause.

#### What It Captures

Unlike `ntbtlog.txt` which only shows driver load status, Process Monitor captures:
- ✅ **File System Operations** - Every file read/write/delete
- ✅ **Registry Operations** - All registry access attempts
- ✅ **Network Activity** - TCP/UDP connections
- ✅ **Process Details** - Which process initiated each operation
- ✅ **Exact Timing** - Precise timestamps for sequencing
- ✅ **Operation Results** - Success/failure codes with details

#### When to Use Process Monitor

| Scenario | Use Procmon? |
|----------|-----------|
| Driver failed in boot log | ✅ YES - See why it failed |
| Slow boot performance | ✅ YES - Find bottleneck |
| Need exact operation sequence | ✅ YES - Full timeline |
| Driver dependency issues | ✅ YES - Trace dependencies |
| Simple "won't boot" diagnosis | ❌ NO - ntbtlog.txt sufficient |

#### Quick Start

1. **Download** (Free):
   ```
   https://docs.microsoft.com/sysinternals/downloads/procmon
   Extract to: C:\Tools\Procmon\
   ```

2. **Enable Boot Logging** (one command):
   ```cmd
   C:\Tools\Procmon\Procmon.exe /accepteula /captureboot
   ```
   → System immediately prompts to restart
   → Boot trace captures from very first driver load

3. **Analyze** (after automatic reboot):
   ```cmd
   C:\Tools\Procmon\Procmon.exe
   ```
   → Boot trace file opens automatically

#### Key Search Filters

```
Failed operations:        Result is not "SUCCESS"
Driver loads:             Image ends with ".sys"
Driver initialization:    Path contains "drivers" AND Operation is "RegOpenKey"
Missing files:            Result is "NOT_FOUND"
Access denied:            Result is "ACCESS_DENIED"
Storage driver problems:  Image contains "stornvme" or "storahci" or "iaStorV"
Registry service access:  Path contains "CurrentControlSet\Services"
```

#### Comparison Matrix

| Feature | ntbtlog.txt | Event Viewer | Process Monitor |
|---------|-------------|--------------|-----------------|
| Driver load status | ✅ Yes | ⚠️ Indirect | ✅ Yes |
| Why it failed | ❌ No | ⚠️ Limited | ✅ Yes |
| File access trace | ❌ No | ❌ No | ✅ Yes |
| Registry details | ❌ No | ❌ No | ✅ Yes |
| Exact sequence | ❌ No | ❌ No | ✅ Yes |
| Timing accuracy | ⚠️ Seconds | ⚠️ Seconds | ✅ Milliseconds |
| Analysis speed | Fast | Fast | Medium |
| Disk space | ~1 KB | ~100 MB | 50-500 MB |

#### Workflow Integration

```
Standard Diagnosis → Process Monitor
   ↓                        ↓
ntbtlog.txt        Boot trace .pmd file
   ↓                        ↓
Shows driver        Detailed forensics:
failed loading      - Failed file access
   ↓                - Registry errors
Run Procmon         - Timing analysis
to debug            - Dependency issues
```

#### Example: Investigating Storage Driver Failure

**In Process Monitor trace, search for:**
```
Image contains "stornvme" AND Result is not "SUCCESS"
```

**Results might show:**
```
Operation: CreateFile
Path: C:\Windows\System32\drivers\stornvme.sys
Result: PATH_NOT_FOUND
→ Driver file is missing!

Operation: RegOpenKey
Path: HKLM\System\CurrentControlSet\Services\stornvme
Result: NOT_FOUND
→ Driver not registered in registry!

Operation: SignFile
Path: C:\Windows\System32\drivers\stornvme.sys
Result: SIGNATURE_VERIFICATION_FAILED
→ Driver signature check failed!
```

#### Saving & Sharing Results

```powershell
# In Process Monitor, use File → Save As

# Format Options:
#  .pmd  - Native format (best for re-analysis)
#  .csv  - For spreadsheet analysis
#  .xml  - For programmatic processing

# File sizes:
#  Typical boot trace: 100-300 MB (.pmd compressed to 5-20 MB)
```

---

## Advanced Usage

### Custom Log Directory
```powershell
$LogDir = "E:\MiracleBoot_Diagnostics"
powershell -File "MiracleBoot-LogGatherer.ps1" -OutputDirectory $LogDir
powershell -File "MiracleBoot-AdvancedLogAnalyzer.ps1" -LogDirectory $LogDir
```

### Automation / Scripting
```powershell
# Run full diagnostics silently
$params = @{
    GatherOnly = $false
    Verbose = $true
    OutputDirectory = "\\server\diagnostics\$(Get-Date -Format 'yyyyMMdd')"
}
& "MiracleBoot-LogGatherer.ps1" @params
```

### Integration with WinPE
```
1. Copy entire HELPER SCRIPTS directory to WinPE USB
2. Boot into WinPE
3. Mount offline Windows drive as C:
4. Run: powershell -File "MiracleBoot-LogGatherer.ps1" -OfflineSystemDrive "C:"
5. Copy logs to USB for analysis on another machine
```

---

## Remediation Commands Reference

### Enable Storage Driver (Offline Registry)
```powershell
# In WinPE
reg load HKLM\OfflineSystem C:\Windows\System32\config\SYSTEM
reg add HKLM\OfflineSystem\ControlSet001\Services\stornvme /v Start /t REG_DWORD /d 0
reg unload HKLM\OfflineSystem
```

### Inject Storage Driver
```powershell
# In WinPE
Dism /Image:C: /Add-Driver /Driver:"E:\nvme_driver.inf" /ForceUnsigned
```

### Rebuild BCD
```powershell
# In WinPE
bcdboot C:\Windows /s S: /f UEFI

# Verify
bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum all
```

### List Installed Drivers
```powershell
Get-WindowsDriver -Online | Where-Object { $_.ProviderName -match 'storage' }
```

### Check Service Status
```powershell
Get-Service stornvme, storahci, iaStorV -ErrorAction SilentlyContinue
```

---

## Troubleshooting

### "CrashAnalyzer not found"
- Run Setup-CrashAnalyzer.ps1
- Verify source path: `I:\Dart Crash analyzer\v10`

### "Logs directory empty"
- Ensure script has admin privileges
- Check if paths exist on target system
- For offline analysis, mount Windows partition first

### "MEMORY.DMP exists but can't open"
- Use 64-bit Crash Analyzer or WinDbg
- Ensure sufficient disk space for analysis
- Try: `!analyze -v` command in WinDbg

### "System.evtx analysis fails"
- Copy evtx to live Windows system
- Open with Event Viewer locally
- Don't try analyzing offline system files

---

## Performance Notes

- **Log Gathering:** 2-5 minutes (depends on log file sizes)
- **Analysis:** 1-2 minutes
- **Memory Requirements:** ~500 MB for tools
- **Disk Space:** 1-5 GB for full crash dumps + logs

---

## Support & Best Practices

### When to Use Each Tool

| Issue | Tool | Priority |
|-------|------|----------|
| System won't boot | LogGatherer + AdvancedAnalyzer | Critical |
| BSOD visible | MEMORY.DMP analysis | High |
| Boot hangs silently | LiveKernelReports analysis | High |
| Setup/upgrade fails | setupact.log parsing | Medium |
| Driver issues | Event Viewer + Device Manager | Medium |

### Safe Practices

1. **Always backup** registry and boot files before remediation
2. **Boot from WinPE** when making offline changes
3. **Verify BCD** after rebuilds with: `bcdedit /enum all`
4. **Keep logs** for troubleshooting and support escalation
5. **Test incrementally** - one fix at a time

---

## Version History

- **v7.2** - Added Diagnostic Suite
  - MiracleBoot-DiagnosticHub.ps1
  - MiracleBoot-LogGatherer.ps1
  - MiracleBoot-AdvancedLogAnalyzer.ps1
  - Setup-CrashAnalyzer.ps1
  - CrashAnalyzer integration
  - Event Viewer integration
  - Tiered log collection (TIER 1-5)
  - Root cause decision tree
  - Interactive analysis menu
  - Remediation script generation

---

**Last Updated:** January 7, 2026  
**Status:** Production Ready  
**License:** MiracleBoot v7.2

