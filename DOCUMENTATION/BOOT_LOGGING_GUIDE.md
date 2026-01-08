# Boot Logging Guide - MiracleBoot v7.2

## Overview

When a Windows 11 system experiences boot issues, **boot logging** is essential for diagnosing the problem. Boot logging creates a detailed log file (`ntbtlog.txt`) that records which drivers loaded successfully and which ones failed during the startup process.

---

## When to Enable Boot Logging

Enable boot logging when you encounter:
- **Blue Screen of Death (BSOD)** during startup
- **System hangs** during boot
- **Device initialization failures**
- **Unexpected restarts** during startup
- **Storage driver issues** (especially with NVMe, RAID, or AHCI controllers)
- **Uncertain boot failures** where the root cause isn't obvious

---

## 🔴 CRITICAL: Enable Boot Logging FIRST

**The ntbtlog.txt file ONLY exists if boot logging was enabled BEFORE the system issue occurred.** If your system won't boot, you need to enable boot logging on the NEXT boot attempt.

---

## How to Enable Boot Logging

### Method 1: PowerShell Command (Recommended)

Run this command as **Administrator** to enable boot logging on the next boot:

```powershell
# Enable boot logging for next boot
bcdedit /set {current} bootlog yes

# Verify it's enabled
bcdedit /enum
```

**Expected output:**
```
bootlog                 Yes
```

### Method 2: Windows 11 GUI (System Configuration)

1. Press **Windows Key + R** to open Run dialog
2. Type `msconfig` and press **Enter**
3. Go to the **Boot** tab
4. Check the box labeled **"Boot log"**
5. Click **Apply** and **OK**
6. **Restart** when prompted

### Method 3: Command Prompt (Legacy Method)

Run as **Administrator**:

```cmd
bcdedit /set {current} bootlog yes
```

---

## How to Disable Boot Logging (After Diagnosis)

Once you've gathered the logs, disable boot logging to improve boot performance:

```powershell
# Disable boot logging
bcdedit /set {current} bootlog no

# Verify it's disabled
bcdedit /enum
```

---

## Locating the Boot Log File

After enabling boot logging and experiencing the issue, the boot log is located at:

### For Current Operating System
```
C:\Windows\ntbtlog.txt
```

### For Offline/Repair Analysis (from WinPE or external drive)
```
<DriveLetterOrPath>:\Windows\ntbtlog.txt
```

**Example:** If Windows is installed on drive D:
```
D:\Windows\ntbtlog.txt
```

---

## Interpreting the Boot Log

The `ntbtlog.txt` file contains lines like these:

### Successfully Loaded Drivers
```
Loaded driver \SystemRoot\System32\drivers\disk.sys
Loaded driver \SystemRoot\System32\drivers\partmgr.sys
Loaded driver \SystemRoot\System32\drivers\ntfs.sys
```
✅ These are **good** - the drivers initialized successfully.

### Failed Driver Loads
```
Did not load driver \SystemRoot\System32\drivers\stornvme.sys
Did not load driver \SystemRoot\System32\drivers\storahci.sys
```
❌ These are **problems** - the driver failed to initialize. This is likely the cause of your boot failure.

### Critical Drivers That Must Load
These drivers **MUST** load successfully for Windows to boot:
- `disk.sys` - Disk driver
- `partmgr.sys` - Partition manager
- `volmgr.sys` - Volume manager
- `storahci.sys` - AHCI storage controller
- `stornvme.sys` - NVMe storage controller
- `ntfs.sys` - NTFS file system
- `mountmgr.sys` - Mount manager
- `classpnp.sys` - Class driver

If any of these fail to load, Windows will not boot.

---

## 📊 Quick Analysis Guide

### Step 1: Enable Boot Logging
```powershell
bcdedit /set {current} bootlog yes
```

### Step 2: Restart and Reproduce the Issue
Allow the system to attempt to boot with the issue active. Don't force restart immediately.

### Step 3: Locate the Log (If System Boots Normally)
```powershell
Get-Content C:\Windows\ntbtlog.txt | Out-GridView
```

### Step 4: Search for Failed Drivers
Look for lines starting with **"Did not load driver"**:
```powershell
Get-Content C:\Windows\ntbtlog.txt | Select-String "Did not load"
```

### Step 5: Analyze Storage Drivers Specifically
Storage driver failures are the #1 cause of INACCESSIBLE_BOOT_DEVICE (0x7B):
```powershell
Get-Content C:\Windows\ntbtlog.txt | Select-String -Pattern "storage|nvme|ahci|raid|vmbus" -IgnoreCase
```

---

## 🔍 Understanding Common Boot Log Failures

### Non-Critical Load Failures (Often Harmless)

The following failures appear in boot logs but **do NOT necessarily indicate a problem**. These drivers are optional and may fail depending on your system configuration:

| Failed Driver | What It Is | When It's OK to Fail |
|---------------|-----------|-------------------|
| `dsound.vxd` | DirectSound audio | System doesn't have DirectSound support |
| `ebios` | Extended BIOS | Older systems, not needed on modern hardware |
| `ndis2sup.vxd` | NDIS 2.0 Support | Deprecated networking protocol |
| `vpowerd` | Power Management | System manages power independently |
| `vserver.vxd` | Network Server Support | Optional networking component |
| `vshare.vxd` | File Sharing | Optional component, not always needed |
| `MTRR` (Windows 98) | Memory Type Range Register | Modern systems use different memory management |
| `JAVASUP` (Windows 98) | Java Support | Java not installed or not needed |

**Key Point:** If you see failures for these drivers and **your system boots normally**, you can safely ignore them. They are expected failures on most modern Windows installations.

### Critical Load Failures (Must Be Fixed)

These drivers **MUST load successfully** for Windows to boot:

| Failed Driver | What It Does | Impact if Failed |
|---------------|--------------|-----------------|
| `disk.sys` | Disk driver | Cannot access any drives → BSOD 0x7B |
| `partmgr.sys` | Partition manager | Cannot access partitions → BSOD 0x7B |
| `volmgr.sys` | Volume manager | Cannot manage volumes → BSOD 0x7B |
| `storahci.sys` | AHCI storage controller | Cannot access AHCI drives → BSOD 0x7B |
| `stornvme.sys` | NVMe storage controller | Cannot access NVMe drives → BSOD 0x7B |
| `ntfs.sys` | NTFS file system | Cannot read NTFS volumes → BSOD 0x7B |
| `mountmgr.sys` | Mount manager | Cannot mount volumes → System hangs |
| `classpnp.sys` | Class driver | Devices won't load → Cascading failures |

### How to Distinguish Between Critical and Non-Critical

**All failed drivers appear the same in the log:**
```
Did not load driver \SystemRoot\System32\drivers\<drivername>.sys
```

Use this PowerShell script to identify which failures are critical:

```powershell
$CriticalDrivers = @(
    "disk", "partmgr", "volmgr", "storahci", "stornvme",
    "ntfs", "mountmgr", "classpnp", "acpi", "pci"
)

$BootLog = Get-Content C:\Windows\ntbtlog.txt
$FailedLines = $BootLog | Select-String "Did not load"

Write-Host "CRITICAL FAILURES:" -ForegroundColor Red
foreach ($line in $FailedLines) {
    foreach ($critical in $CriticalDrivers) {
        if ($line -match $critical) {
            Write-Host "❌ $line" -ForegroundColor Red
            break
        }
    }
}

Write-Host "`nNON-CRITICAL (Safe to Ignore):" -ForegroundColor Yellow
$SafeToIgnore = @("dsound", "ebios", "ndis2sup", "vpowerd", "vserver", "vshare", "MTRR", "JAVASUP")
foreach ($line in $FailedLines) {
    $isSafe = $false
    foreach ($safe in $SafeToIgnore) {
        if ($line -match $safe) {
            Write-Host "ℹ️  $line" -ForegroundColor Yellow
            $isSafe = $true
            break
        }
    }
}
```

### When Non-Critical Failures Become a Problem

Although these drivers are optional, some situations require investigation:

1. **Performance Issues**: If `dsound.vxd` or `JAVASUP` fails and you need that functionality
2. **Network Issues**: If `ndis2sup.vxd` fails and you need legacy networking
3. **Functionality**: Verify the feature you expect to work actually works

**Example Fix:** If audio doesn't work and `dsound.vxd` failed:
```powershell
# Update audio drivers
# Check if audio device is in Device Manager (devmgmt.msc)
# Reinstall audio drivers from manufacturer
```

### Common Load Failure Scenarios

**Scenario 1: Single Non-Critical Driver Fails**
```
Did not load driver \SystemRoot\System32\drivers\dsound.vxd
```
✅ **Result**: System boots normally, audio may not work. Check audio settings.

**Scenario 2: Storage Driver Fails**
```
Did not load driver \SystemRoot\System32\drivers\stornvme.sys
```
❌ **Result**: BSOD 0x7B on next boot. This is a critical failure requiring repair.

**Scenario 3: Multiple Non-Critical Drivers Fail**
```
Did not load driver \SystemRoot\System32\drivers\vpowerd
Did not load driver \SystemRoot\System32\drivers\vserver.vxd
Did not load driver \SystemRoot\System32\drivers\ebios
```
✅ **Result**: System likely boots fine. These are optional.

### How to Fix Critical Driver Load Failures

If a critical driver failed to load, you need to fix it:

```powershell
# 1. Check if the driver file exists
Test-Path "C:\Windows\System32\drivers\stornvme.sys"

# 2. If missing, you need to inject it from media or recovery
# Boot into WinPE/Recovery Environment

# 3. Use MiracleBoot to analyze and suggest fixes
# See: DIAGNOSTIC_SUITE_GUIDE.md
```

---

## Using Process Monitor for Advanced Boot Analysis

**Process Monitor** is a powerful real-time monitoring tool that captures detailed information about system activity during boot, including file system, registry, and network operations that aren't visible in standard boot logs.

### What is Process Monitor?

Process Monitor (Procmon) is a free advanced monitoring tool from Microsoft Sysinternals that logs:
- **File System Operations** - All file reads/writes/deletes
- **Registry Operations** - All registry access
- **Network Activity** - TCP/UDP connections
- **Process Events** - Process creation/termination
- **Thread Activity** - Thread operations
- **DLL Loading** - All dynamic library loads

### When to Use Process Monitor Boot Logging

Use Process Monitor when:
- Standard boot logs show failed driver but you need more context
- Troubleshooting slow boot times (which driver is causing delays)
- Investigating file system or registry errors
- Analyzing deadlocks between drivers
- Verifying driver initialization sequences
- Tracking access to system files and drivers

### Prerequisites

1. **Download Process Monitor** (free from Microsoft):
   ```
   https://docs.microsoft.com/sysinternals/downloads/procmon
   ```

2. **Extract to a Known Location**:
   ```
   C:\Tools\Procmon\Procmon.exe
   ```

3. **Run with Administrator Privileges**

---

### Method: Enable Process Monitor Boot Logging

#### Step 1: Set Up Boot Logging (One-Time Configuration)

Run this command in **Administrator** PowerShell or Command Prompt:

```cmd
Procmon.exe /accepteula /captureboot
```

Or use PowerShell:

```powershell
C:\Tools\Procmon\Procmon.exe /accepteula /captureboot
```

**What this does:**
- Configures Procmon to automatically capture the next boot
- Prompts you to **restart immediately**
- Boot data is captured to a .PMD file

#### Step 2: Restart the Computer

After running the command, click **"Restart Now"** when prompted. Process Monitor will automatically:
- Begin capturing at the very start of boot
- Record all system activity through Windows startup
- Save the trace to a `.pmd` file in the Procmon directory

#### Step 3: Reproduce the Issue

Let the system boot normally with the issue active. Don't force restart or power off.

#### Step 4: Analyze the Boot Trace

When the system has fully booted, run:

```cmd
Procmon.exe
```

The boot trace will automatically open. You can now:
- 🔍 **Search** for specific drivers or files
- 🔗 **Track sequences** showing which operations failed
- ⏱️ **View timestamps** to identify timing issues
- 💾 **Export results** to CSV or XML for detailed analysis

---

### Process Monitor Boot Logging - GUI Alternative

If you prefer a graphical interface:

1. Open **Process Monitor**
2. Click **File** → **Capture Events** (toggle ON)
3. Click **File** → **Capture Boot Log** (requires restart)
4. Click **Restart** when prompted
5. After reboot, the boot trace opens automatically

---

### Analyzing Process Monitor Boot Trace

#### Common Searches

**Find failed operations:**
```
Result is not "SUCCESS"
```

**Find driver loads:**
```
Image contains ".sys"
```

**Find registry access to driver configuration:**
```
Path contains "Services" and Path contains ".sys"
```

**Find file access to critical boot files:**
```
Path contains "Windows\System32" and (Path contains "driver" or Path contains "config")
```

**Find operations by a specific process:**
```
Process Name is "explorer.exe"
```

---

#### Interpreting Results

Each line in the Process Monitor trace shows:

| Column | Meaning | Example |
|--------|---------|---------|
| **Time** | When the operation occurred | 12:34:56.123 |
| **Process** | Which process performed it | svchost.exe |
| **Operation** | Type of operation | WriteFile, RegQueryValue |
| **Path** | What was accessed | C:\Windows\ntbtlog.txt |
| **Result** | Success or failure code | SUCCESS, STATUS_NOT_FOUND |
| **Details** | Additional information | Length: 4096 |

---

#### Finding Boot Issues

**Look for patterns:**

1. **Access Denied to Driver Files**
   ```
   Operation: CreateFile or ReadFile
   Path: ...drivers\*.sys
   Result: ACCESS_DENIED or NOT_FOUND
   ```
   → Missing or corrupted driver

2. **Registry Key Not Found**
   ```
   Operation: RegOpenKey
   Path: HKLM\System\CurrentControlSet\Services\<drivername>
   Result: NOT_FOUND or PATH_NOT_FOUND
   ```
   → Driver not properly registered

3. **Timeout Operations**
   - Same operation repeated for several seconds
   - Indicates driver waiting for hardware response
   - Often causes boot hangs

4. **Initialization Order Issues**
   - Driver trying to access file before file system driver loads
   - Shown as operations with PATH_NOT_FOUND errors early in trace

---

### Comparing Standard Boot Log with Process Monitor

| Feature | ntbtlog.txt | Process Monitor |
|---------|-------------|-----------------|
| Driver Load Status | ✅ Yes | ✅ Yes |
| Failed Operations | ✅ Limited | ✅ Detailed |
| File Access Details | ❌ No | ✅ Yes |
| Registry Access | ❌ No | ✅ Yes |
| Timing Information | ⚠️ Limited | ✅ Precise |
| Operation Sequences | ❌ No | ✅ Complete |
| Driver Dependencies | ❌ No | ✅ Traceable |
| Performance Analysis | ❌ No | ✅ Yes |

---

### Process Monitor Filtering Tips

To reduce noise from thousands of operations:

**Exclude non-critical processes:**
```
Exclude: Process Name is "SearchIndexer.exe"
Exclude: Process Name is "RuntimeBroker.exe"
Exclude: Process Name is "svchost.exe" (optional - may filter important data)
```

**Focus on system drivers:**
```
Include: Image ends with ".sys"
Include: Path contains "drivers"
```

**Find initialization failures:**
```
Filter: Result is not "SUCCESS"
```

---

### Exporting Results for Analysis

Save the trace for sharing with support:

1. **Menu** → **File** → **Save As**
2. Choose format:
   - **`.pmd`** - Procmon native format (best for re-analysis)
   - **`.csv`** - For spreadsheet analysis
   - **`.xml`** - For programmatic analysis

---

### Comparing Boot Logs

To compare multiple boot attempts:

```powershell
# Open two traces side-by-side
Procmon.exe <trace1.pmd> &
Procmon.exe <trace2.pmd> &
```

Then use **Find** to search the same operation in both traces to see where they diverge.

---

### Process Monitor Performance Notes

⚠️ **Important Considerations:**

- **Disk Space**: Boot traces can be 50-500 MB depending on system activity
- **Performance**: Capture has minimal impact during boot
- **Memory**: Large traces require 2+ GB RAM for analysis
- **File Format**: `.pmd` files compress better than `.csv`

---

## Using MiracleBoot to Analyze Boot Logs

MiracleBoot automates the analysis of boot logs:

### Via GUI (Recommended)
```powershell
cd "HELPER SCRIPTS"
powershell -File MiracleBoot-DiagnosticHub.ps1
```
Then click **"Analyze Boot Log"**

### Via Command Line
```powershell
powershell -File "HELPER SCRIPTS\MiracleBoot-AdvancedLogAnalyzer.ps1" -Interactive
```

---

## 🔧 Troubleshooting Boot Logging Issues

### "Boot log file not found after enabling"

**Causes:**
1. System didn't boot at all (can't create the file)
2. Boot logging wasn't actually enabled
3. The system automatically disabled it after analysis

**Solution:**
```powershell
# Verify boot logging is enabled
bcdedit /enum | findstr bootlog

# If it shows "No" or is missing, re-enable
bcdedit /set {current} bootlog yes

# Check if the log exists on the current system
Test-Path C:\Windows\ntbtlog.txt
```

### "Boot log exists but is empty"

The system may have booted too quickly or logging failed. Try:

```powershell
# Force verbose driver loading
bcdedit /set {current} bootoptimization off

# Keep boot logging enabled
bcdedit /set {current} bootlog yes

# Restart and check again
Restart-Computer
```

### "Only seeing partial logs"

This is normal. Boot logs are created **as drivers load**, so if the system crashes during boot, only the logs up to that point are recorded.

---

## 📋 Driver Load Order (Boot Priority)

Understanding the order helps identify when the failure occurred:

```
1. System Firmware (BIOS/UEFI) - Not in ntbtlog.txt
2. Boot Loader (bootmgr/BCD) - Not in ntbtlog.txt
3. Kernel (ntoskrnl.exe) + HAL
4. Core Drivers (acpi, pci, msisadrv)
5. Storage Controllers (storahci, stornvme, nvraid)
6. Disk Management (classpnp, disk, partmgr, volmgr)
7. File Systems (ntfs)
8. Other Drivers
```

If a driver at level 5-7 fails, you'll see **INACCESSIBLE_BOOT_DEVICE** (0x7B).

---

## 🛠️ Common Fixes Based on Boot Log

### Storage Driver Not Loading

**Symptom:** `Did not load driver \SystemRoot\System32\drivers\stornvme.sys`

**Fix (requires WinPE):**
```powershell
# Mount the offline Windows registry
reg load HKLM\OfflineSystem C:\Windows\System32\config\SYSTEM

# Enable the driver (0 = auto-start)
reg add HKLM\OfflineSystem\ControlSet001\Services\stornvme /v Start /t REG_DWORD /d 0 /f

# Unload the registry
reg unload HKLM\OfflineSystem
```

### AHCI Storage Not Loading

**Symptom:** `Did not load driver \SystemRoot\System32\drivers\storahci.sys`

**Fix (requires WinPE):**
```powershell
# Same as above, but for AHCI
reg load HKLM\OfflineSystem C:\Windows\System32\config\SYSTEM
reg add HKLM\OfflineSystem\ControlSet001\Services\storahci /v Start /t REG_DWORD /d 0 /f
reg unload HKLM\OfflineSystem
```

### Missing Disk Driver

**Symptom:** `Did not load driver \SystemRoot\System32\drivers\disk.sys`

**Fix:** Inject driver from WinPE:
```powershell
# Boot into WinPE first
Dism /Image:C: /Add-Driver /Driver:"<path-to-driver>" /ForceUnsigned

# Rebuild BCD
bcdboot C:\Windows /s S: /f UEFI
```

---

## ✅ Best Practices

1. **Enable boot logging BEFORE troubleshooting** - Especially if the system is unstable
2. **Disable after diagnosis** - Boot logging adds minimal overhead, but disabling improves performance
3. **Keep logs for reference** - Save `ntbtlog.txt` to a USB drive for analysis
4. **Use MiracleBoot for automated analysis** - It identifies critical failures instantly
5. **Cross-reference with Event Logs** - Check `System.evtx` for additional context

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Enable boot logging | `bcdedit /set {current} bootlog yes` |
| Disable boot logging | `bcdedit /set {current} bootlog no` |
| Check if enabled | `bcdedit /enum \| findstr bootlog` |
| View boot log | `Get-Content C:\Windows\ntbtlog.txt` |
| Find failed drivers | `Select-String "Did not load" C:\Windows\ntbtlog.txt` |
| Find storage issues | `Select-String -Pattern "storage\|nvme\|ahci" C:\Windows\ntbtlog.txt` |

---

## Integration with MiracleBoot Diagnostic Suite

MiracleBoot automatically:
- ✅ Detects if boot logging is enabled
- ✅ Analyzes all failed driver loads
- ✅ Identifies critical driver failures
- ✅ Suggests remediation based on failures
- ✅ Provides automated root cause analysis

**See:** [DIAGNOSTIC_SUITE_GUIDE.md](DIAGNOSTIC_SUITE_GUIDE.md) for full diagnostic workflow.

---

## References

- Windows Boot Log: https://docs.microsoft.com/en-us/windows/client-management/
- BCD Edit Documentation: https://docs.microsoft.com/windows-server/administration/windows-commands/bcdedit
- Driver Load Order: https://support.microsoft.com/en-us/help/102122/

