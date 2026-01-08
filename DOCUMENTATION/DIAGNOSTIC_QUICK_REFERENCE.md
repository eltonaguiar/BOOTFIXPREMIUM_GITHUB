# MiracleBoot Diagnostic Suite - Quick Reference

## 🚀 Fastest Start

```powershell
# Launch the GUI (easiest method)
cd "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\HELPER SCRIPTS"
powershell -File MiracleBoot-DiagnosticHub.ps1
```

---

## 📋 Command Reference

### Diagnostic Hub (GUI)
```powershell
powershell -File "HELPER SCRIPTS\MiracleBoot-DiagnosticHub.ps1"
```

### Log Gathering
```powershell
# Collect all diagnostic logs
powershell -File "HELPER SCRIPTS\MiracleBoot-LogGatherer.ps1"

# Offline system analysis (from WinPE)
powershell -File "HELPER SCRIPTS\MiracleBoot-LogGatherer.ps1" -OfflineSystemDrive "C:"

# Also launch Event Viewer
powershell -File "HELPER SCRIPTS\MiracleBoot-LogGatherer.ps1" -OpenEventViewer

# Also launch Crash Analyzer
powershell -File "HELPER SCRIPTS\MiracleBoot-LogGatherer.ps1" -LaunchCrashAnalyzer
```

### Analysis (Deep Dive)
```powershell
# Interactive analysis with menu
powershell -File "HELPER SCRIPTS\MiracleBoot-AdvancedLogAnalyzer.ps1" -Interactive

# Full analysis + generate remediation script
powershell -File "HELPER SCRIPTS\MiracleBoot-AdvancedLogAnalyzer.ps1" -GenerateRemediationScript
```

### CrashAnalyzer Setup
```powershell
# Initial setup (one-time)
powershell -File "HELPER SCRIPTS\Setup-CrashAnalyzer.ps1"

# Force re-setup
powershell -File "HELPER SCRIPTS\Setup-CrashAnalyzer.ps1" -Force
```

---

## 🔥 INACCESSIBLE_BOOT_DEVICE - 3 Step Fix

### Step 1: Gather Evidence
```powershell
powershell -File "HELPER SCRIPTS\MiracleBoot-LogGatherer.ps1"
```
→ Collects MEMORY.DMP, LiveKernelReports, setup logs, boot traces

### Step 2: Analyze Root Cause
```powershell
powershell -File "HELPER SCRIPTS\MiracleBoot-AdvancedLogAnalyzer.ps1" -Interactive
```
→ Choose option 7 "Determine Root Cause"

### Step 3: Fix Based on Root Cause

**If MEMORY.DMP found:**
```powershell
# Launch Crash Analyzer
powershell -File "HELPER SCRIPTS\Setup-CrashAnalyzer.ps1"
cd "HELPER SCRIPTS\CrashAnalyzer"
.\CrashAnalyzer-Launcher.cmd
```

**If Storage driver issue:**
```powershell
# Boot into WinPE and run:
Dism /Image:C: /Add-Driver /Driver:"<path>" /ForceUnsigned
bcdboot C:\Windows /s S: /f UEFI
```

**If BCD corrupted:**
```powershell
# In WinPE:
bcdboot C:\Windows /s S: /f UEFI
bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum all
```

---

## 📊 Log Locations (What Gets Analyzed)

| Priority | Log | Location |
|----------|-----|----------|
| **🔴 CRITICAL** | Kernel Dump | `C:\Windows\MEMORY.DMP` |
| **🔴 CRITICAL** | Live Reports | `C:\Windows\LiveKernelReports\STORAGE` |
| **🟠 HIGH** | Setup Log | `C:\Windows\Panther\setupact.log` |
| **🟠 HIGH** | Boot Trace | `C:\Windows\ntbtlog.txt` |
| **🟡 MEDIUM** | Event Log | `C:\Windows\System32\winevt\Logs\System.evtx` |
| **🟡 MEDIUM** | BCD Store | `ESP:\EFI\Microsoft\Boot\BCD` |

---

## 🎯 Use Cases

### "System won't boot at all"
```
1. Run: MiracleBoot-LogGatherer.ps1
2. Check: MEMORY.DMP or LiveKernelReports/STORAGE
3. If found: Analyze with Crash Analyzer
```

### "Blue screen on boot"
```
1. Gather logs from WinPE
2. Run: MiracleBoot-AdvancedLogAnalyzer.ps1 -Interactive
3. Choose: Option 7 (Determine Root Cause)
4. Choose: Option 1 (Analyze MEMORY.DMP)
```

### "Setup/Windows upgrade fails"
```
1. Run: MiracleBoot-LogGatherer.ps1 -GatherOnly
2. Open: LOGS/LogAnalysis/setupact.log
3. Search: "error", "failed", "mismatch"
```

### "Storage driver not loading"
```
1. Event Viewer → System Log → Look for storage errors
2. Device Manager → Check for yellow exclamation marks
3. Run setup script to inject missing driver in WinPE
```

---

## 🛠️ Remediation Cheat Sheet

### Enable Storage Driver (Offline)
```cmd
# Mount registry (WinPE)
reg load HKLM\OfflineSystem C:\Windows\System32\config\SYSTEM

# Enable driver (change 4 to 0)
reg add HKLM\OfflineSystem\ControlSet001\Services\stornvme /v Start /t REG_DWORD /d 0
reg add HKLM\OfflineSystem\ControlSet001\Services\storahci /v Start /t REG_DWORD /d 0

# Unload
reg unload HKLM\OfflineSystem
```

### Inject Driver in WinPE
```cmd
Dism /Image:C: /Add-Driver /Driver:"E:\Drivers\nvme.inf" /ForceUnsigned
Dism /Image:C: /Add-Driver /Driver:"E:\Drivers\ahci.inf" /ForceUnsigned
```

### Rebuild BCD
```cmd
bcdboot C:\Windows /s S: /f UEFI
bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum all
```

### Check Services (Live System)
```powershell
Get-Service stornvme, storahci, iaStorV, nvme | Select Name, Status
```

---

## 📁 Output Locations

After running **MiracleBoot-LogGatherer.ps1**:

```
LOGS/LogAnalysis/
├── RootCauseAnalysis_<timestamp>.txt    ← Main findings
├── Analysis_<timestamp>.json             ← Detailed report
├── GatherAnalysis_<timestamp>.log        ← Execution log
├── MEMORY.DMP                            ← Kernel dump (if found)
├── LiveKernelReports/                    ← Silent crash reports
├── setupact.log                          ← Setup actions
├── setuperr.log                          ← Setup errors
├── ntbtlog.txt                           ← Boot trace
├── System.evtx                           ← Event log
├── SYSTEM_hive                           ← Registry
└── ... other diagnostic files
```

---

## ⚡ Common Issues & Fixes

| Problem | Check | Fix |
|---------|-------|-----|
| "Script not found" | Full path in `HELPER SCRIPTS` directory | Use absolute path or cd to dir |
| "Access Denied" | Run as Administrator | `Run PowerShell as Admin` |
| "CrashAnalyzer not found" | Run `Setup-CrashAnalyzer.ps1` | Copies from I:\Dart Crash analyzer\v10 |
| "No logs gathered" | Permissions on C:\Windows | Check read access to Windows folder |
| "Logs empty" | System not online | Try offline analysis from WinPE |

---

## 🎓 Learning Path

**Beginner:** Just use the GUI
```powershell
MiracleBoot-DiagnosticHub.ps1
```

**Intermediate:** Use command-line with presets
```powershell
# Gather + Analyze
MiracleBoot-LogGatherer.ps1
MiracleBoot-AdvancedLogAnalyzer.ps1 -Interactive
```

**Advanced:** Custom parameters and automation
```powershell
# Custom paths, offline analysis, remediation
MiracleBoot-LogGatherer.ps1 -OfflineSystemDrive "D:" -OutputDirectory "E:\Diag"
MiracleBoot-AdvancedLogAnalyzer.ps1 -GenerateRemediationScript
```

---

## 🔍 What Each Tool Does

### MiracleBoot-DiagnosticHub.ps1
- **Purpose:** Central GUI for all tools
- **Speed:** Instant access
- **Best for:** Quick navigation, learning, demos

### MiracleBoot-LogGatherer.ps1
- **Purpose:** Collects logs from 5 diagnostic tiers
- **Output:** Organized logs + Root Cause Analysis summary
- **Speed:** 2-5 minutes
- **Best for:** Getting raw evidence

### MiracleBoot-AdvancedLogAnalyzer.ps1
- **Purpose:** Deep analysis with pattern matching
- **Output:** Detailed findings + Remediation scripts
- **Speed:** 1-2 minutes
- **Best for:** Understanding root cause

### Setup-CrashAnalyzer.ps1
- **Purpose:** Configure CrashAnalyzer environment
- **Output:** Ready-to-use crash analyzer
- **Speed:** 1 minute (one-time)
- **Best for:** Setting up crash analysis tool

---

## 🎯 Success Criteria

✅ **Logs gathered successfully if:**
- `LOGS/LogAnalysis/` directory created
- `RootCauseAnalysis_*.txt` file generated
- At least one critical log found

✅ **Analysis successful if:**
- Root cause identified
- Recommendations provided
- Remediation steps outlined

✅ **Boot issue fixed when:**
- System boots without INACCESSIBLE_BOOT_DEVICE
- Storage drivers loaded successfully
- No blue screens on restart

---

## 🔧 Enable Boot Logging (For Boot Issues)

Boot logging creates `ntbtlog.txt` showing which drivers loaded/failed during startup.

**⚠️ CRITICAL:** Boot logs only exist if enabled BEFORE the issue occurs!

### Quick Command
```powershell
# Enable boot logging for next boot
bcdedit /set {current} bootlog yes

# Verify it's enabled
bcdedit /enum | findstr bootlog

# After diagnosis, disable (improves performance)
bcdedit /set {current} bootlog no
```

### Via GUI
1. Press **Windows + R**, type: `msconfig`
2. **Boot** tab → Check **Boot log**
3. Click **Apply** and **OK** → **Restart**

### Analyze Boot Log
```powershell
# View the log
Get-Content C:\Windows\ntbtlog.txt | Out-GridView

# Find failed drivers
Select-String "Did not load" C:\Windows\ntbtlog.txt

# Find storage driver failures (common cause of 0x7B)
Select-String -Pattern "storage|nvme|ahci|raid" C:\Windows\ntbtlog.txt
```

### Full Documentation
See: `DOCUMENTATION/BOOT_LOGGING_GUIDE.md` for complete guide with troubleshooting

---

## 🔬 Process Monitor Boot Logging (Advanced Analysis)

**Process Monitor** captures detailed system activity (file, registry, network) during boot - far more comprehensive than standard boot logs.

### Quick Start

1. **Download** (free from Microsoft):
   ```
   https://docs.microsoft.com/sysinternals/downloads/procmon
   ```

2. **Enable Boot Logging** (one command):
   ```cmd
   C:\Tools\Procmon\Procmon.exe /accepteula /captureboot
   ```
   → Click **Restart Now** when prompted

3. **Analyze Results**:
   ```cmd
   C:\Tools\Procmon\Procmon.exe
   ```
   Boot trace opens automatically after restart

### Key Searches in Process Monitor

| What to Find | Search Filter |
|-------------|---------------|
| Failed operations | `Result is not "SUCCESS"` |
| Driver loads | `Image ends with ".sys"` |
| Registry access failures | `Path contains "Services"` |
| Missing files | `Result is "NOT_FOUND"` |
| Access denied errors | `Result is "ACCESS_DENIED"` |
| Critical driver ops | `Image contains "storahci"` or `"stornvme"` |

### When to Use Each

| Situation | Use |
|-----------|-----|
| Driver shows failed in boot log | Process Monitor to see why |
| Slow boot (not crash) | Process Monitor to find bottleneck |
| Need exact operation sequence | Process Monitor timeline |
| Driver dependency issues | Process Monitor traces dependencies |
| Simple "won't boot" | Standard `ntbtlog.txt` (faster) |

### Comparison: Boot Log vs Process Monitor

| Feature | ntbtlog.txt | Procmon |
|---------|------------|---------|
| Driver load status | ✅ Yes | ✅ Yes |
| Why failed? | ❌ No | ✅ Yes |
| File access trace | ❌ No | ✅ Yes |
| Registry details | ❌ No | ✅ Yes |
| Timing info | ⚠️ Limited | ✅ Precise |
| Size/Speed | Fast (~1 KB) | Large (50-500 MB) |

### Full Documentation
See: `DOCUMENTATION/BOOT_LOGGING_GUIDE.md` → **"Using Process Monitor for Advanced Boot Analysis"** section

---

**Quick Links:**
- Full Guide: `DOCUMENTATION/DIAGNOSTIC_SUITE_GUIDE.md`
- Boot Logging: `DOCUMENTATION/BOOT_LOGGING_GUIDE.md`
- Main Launcher: `HELPER SCRIPTS/MiracleBoot-DiagnosticHub.ps1`
- Emergency Recovery: Boot into WinPE + Run `MiracleBoot-LogGatherer.ps1`
