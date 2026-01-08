# Boot Log Failure Reference Guide

## What is ntbtlog.txt?

The boot log (`C:\Windows\ntbtlog.txt`) records every driver the system attempts to load during startup. It shows which drivers succeeded and which failed.

---

## ✅ Lines in the Boot Log - What They Mean

### Successful Load
```
Loaded driver \SystemRoot\System32\drivers\disk.sys
```
✅ **Good** - The driver initialized successfully.

### Failed Load
```
Did not load driver \SystemRoot\System32\drivers\stornvme.sys
```
❌ **Could be a problem** - Depends on whether it's critical.

---

## 🎯 Quick Classification

### ⚠️ CRITICAL (Will Stop Boot)
**If ANY of these fail to load, you'll get BSOD 0x7B:**
- `disk.sys` - Disk controller
- `partmgr.sys` - Partition manager
- `volmgr.sys` - Volume manager
- `storahci.sys` - AHCI storage
- `stornvme.sys` - NVMe storage
- `ntfs.sys` - NTFS filesystem
- `mountmgr.sys` - Mount manager

**Action:** Boot into WinPE and repair the driver.

---

### ℹ️ NON-CRITICAL (Safe to Ignore)
**These commonly fail but don't stop boot:**

| Driver | What It Is | Why It Fails |
|--------|-----------|------------|
| `dsound.vxd` | DirectSound audio | Not on modern systems |
| `ebios` | Extended BIOS | Deprecated, not needed |
| `ndis2sup.vxd` | NDIS 2.0 networking | Legacy protocol |
| `vpowerd` | Virtual power device | Modern power management works differently |
| `vserver.vxd` | Network server support | Not needed on workstations |
| `vshare.vxd` | File sharing | Not always enabled |
| `MTRR` | Memory management (Windows 98) | Expected to fail |
| `JAVASUP` | Java support (Windows 98) | Java not installed |

**Action:** None required. System will boot fine.

---

## 🔍 How to Check Your Boot Log

### Enable Boot Logging First
```powershell
bcdedit /set {current} bootlog yes
# Restart system
```

### View the Log
```powershell
Get-Content C:\Windows\ntbtlog.txt | Out-GridView
```

### Find Failed Drivers
```powershell
Get-Content C:\Windows\ntbtlog.txt | Select-String "Did not load"
```

### Find Storage Drivers
```powershell
Get-Content C:\Windows\ntbtlog.txt | Select-String -Pattern "storage|nvme|ahci|raid"
```

---

## ⚡ Decision Tree

**Question 1:** Does your system boot normally?
- **YES** → Any failures are non-critical. See table above.
- **NO** → You have a critical driver failure (see below)

**Question 2 (If not booting):** Are ANY of these in the failed list?
- `disk.sys`, `partmgr.sys`, `volmgr.sys`, `storahci.sys`, `stornvme.sys`, `ntfs.sys`, `mountmgr.sys`
- **YES** → CRITICAL: Boot into WinPE for recovery
- **NO** → Other driver issue, see "Other Failed Drivers" section

**Question 3 (If failing):** Is it:
- `stornvme.sys` or `storahci.sys`? → Storage driver (most common 0x7B)
- `disk.sys`? → Disk driver missing
- `ntfs.sys`? → File system issue
- Other? → Check driver-specific fixes

---

## 🛠️ Common Scenarios & Fixes

### Scenario 1: "System boots but I see dsound.vxd failed"
```
Did not load driver \SystemRoot\System32\drivers\dsound.vxd
```
✅ **This is NORMAL.** DirectSound is deprecated.
- Audio should work fine through modern drivers
- No action needed
- If audio doesn't work: Update audio drivers from device manufacturer

---

### Scenario 2: "BSOD 0x7B - stornvme.sys failed"
```
Did not load driver \SystemRoot\System32\drivers\stornvme.sys
```
❌ **CRITICAL.** You cannot access the NVMe drive.

**Fixes (requires WinPE):**
```powershell
# 1. Boot into WinPE
# 2. Mount offline Windows registry
reg load HKLM\OfflineSystem C:\Windows\System32\config\SYSTEM

# 3. Enable the driver (Start type 0 = Boot)
reg add HKLM\OfflineSystem\ControlSet001\Services\stornvme /v Start /t REG_DWORD /d 0 /f

# 4. Unload registry
reg unload HKLM\OfflineSystem

# 5. Rebuild BCD
bcdboot C:\Windows /s E: /f UEFI

# 6. Reboot
```

---

### Scenario 3: "Multiple drivers failed - ndis2sup, ebios, vpowerd, vserver, vshare"
✅ **This is NORMAL.** These are all optional/deprecated.
- System will boot fine
- No action needed
- See table above for details

---

### Scenario 4: "BSOD 0x7B - storahci.sys failed"
❌ **CRITICAL.** You cannot access the AHCI drive.

**Fix (similar to NVMe):**
```powershell
# Same process as stornvme.sys above, but for storahci
reg add HKLM\OfflineSystem\ControlSet001\Services\storahci /v Start /t REG_DWORD /d 0 /f
```

---

### Scenario 5: "System boots but some feature doesn't work"
✅ **Likely a non-critical driver.**

**Investigation:**
```powershell
# Check what's failing
Get-Content C:\Windows\ntbtlog.txt | Select-String "Did not load" | Out-GridView

# Identify the feature and update its driver
# Example: If audio driver fails, update audio in Device Manager
Start-Process devmgmt.msc
```

---

## 📊 Error Code Database Integration

MiracleBoot recognizes these boot log failures:

- `BOOTLOG_DSOUND_FAILED` - DirectSound
- `BOOTLOG_EBIOS_FAILED` - Extended BIOS
- `BOOTLOG_NDIS2SUP_FAILED` - NDIS 2.0
- `BOOTLOG_VPOWERD_FAILED` - Virtual Power
- `BOOTLOG_VSERVER_FAILED` - Network Server
- `BOOTLOG_VSHARE_FAILED` - File Sharing
- `BOOTLOG_SDVXD_FAILED` - SD Card Support
- `BOOTLOG_MTRR_FAILED` - Memory (Windows 98)
- `BOOTLOG_JAVASUP_FAILED` - Java (Windows 98)
- `BOOTLOG_CRITICAL_DRIVER_FAILED` - Critical (Any critical driver)

---

## ✅ Complete Example

**You see this boot log:**
```
Loaded driver \SystemRoot\System32\drivers\disk.sys
Loaded driver \SystemRoot\System32\drivers\ntfs.sys
Did not load driver \SystemRoot\System32\drivers\dsound.vxd
Did not load driver \SystemRoot\System32\drivers\vpowerd
Loaded driver \SystemRoot\System32\drivers\stornvme.sys
```

**Analysis:**
| Driver | Status | Meaning |
|--------|--------|---------|
| `disk.sys` | ✅ Loaded | Good - disk access works |
| `ntfs.sys` | ✅ Loaded | Good - can read NTFS |
| `dsound.vxd` | ❌ Failed | Non-critical - expected |
| `vpowerd` | ❌ Failed | Non-critical - expected |
| `stornvme.sys` | ✅ Loaded | Good - NVMe access works |

**Conclusion:** ✅ System will boot fine. The failures are normal.

---

## 🚀 Using MiracleBoot

MiracleBoot automatically:
1. Reads your boot log
2. Identifies critical vs non-critical failures
3. Explains what each failure means
4. Suggests fixes where needed

```powershell
# Run MiracleBoot analysis
cd "HELPER SCRIPTS"
powershell -ExecutionPolicy Bypass -File "WinRepairGUI.ps1"
# Click: Logs & Diagnostics → Analyze Boot Log
```

---

## 📖 See Also

- **Full Guide:** `BOOT_LOGGING_GUIDE.md` - Complete boot logging procedures
- **Diagnostics:** `DIAGNOSTIC_START_HERE.md` - Full diagnostic workflow
- **Error Codes:** `ErrorCodeDatabase.ps1` - All error codes with fixes
- **Event Logs:** `WINDOWS_LOG_ANALYSIS_GUIDE.md` - Analyzing event logs

---

## Quick Command Reference

| Task | Command |
|------|---------|
| Enable boot logging | `bcdedit /set {current} bootlog yes` |
| Verify enabled | `bcdedit /enum \| findstr bootlog` |
| View boot log | `Get-Content C:\Windows\ntbtlog.txt` |
| Search failures | `Select-String "Did not load" C:\Windows\ntbtlog.txt` |
| Search storage | `Select-String -Pattern "nvme\|ahci\|storage" C:\Windows\ntbtlog.txt` |
| Disable after done | `bcdedit /set {current} bootlog no` |

---

**Last Updated:** January 2026  
**MiracleBoot Version:** 7.2
