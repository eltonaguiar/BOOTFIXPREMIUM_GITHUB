# Process Monitor Boot Logging - Complete Guide

## Overview

**Process Monitor** (Procmon) is a free, powerful real-time system monitoring tool from Microsoft Sysinternals that provides forensic-level detail about system activity during boot. Unlike standard boot logs (`ntbtlog.txt`) that only report driver load success/failure, Process Monitor reveals **why** failures occur by capturing every file, registry, and network operation.

---

## When to Use Process Monitor

### Use Process Monitor When:
- ✅ Driver fails in boot log but cause is unclear
- ✅ Troubleshooting slow boot performance
- ✅ Need exact sequence of operations
- ✅ Investigating driver dependency failures
- ✅ Debugging registry access issues
- ✅ Storage controller initialization problems
- ✅ Need forensic-level analysis

### Use Standard Boot Logging When:
- ✅ Just need to know which drivers failed
- ✅ Quick diagnosis needed
- ✅ Limited disk space (ntbtlog.txt is ~1 KB)
- ✅ Performance testing (Procmon captures consume resources)

---

## Installation & Setup

### Step 1: Download Process Monitor

```
Official Source: https://docs.microsoft.com/sysinternals/downloads/procmon
```

**File:** `Procmon.exe` (~3 MB executable)

### Step 2: Extract to Known Location

Recommended: `C:\Tools\Procmon\`

```powershell
# Example extraction
$url = "https://download.sysinternals.com/files/ProcessMonitor.zip"
Invoke-WebRequest -Uri $url -OutFile "C:\Temp\Procmon.zip"
Expand-Archive "C:\Temp\Procmon.zip" -DestinationPath "C:\Tools\Procmon"
```

### Step 3: Verify Installation

```cmd
C:\Tools\Procmon\Procmon.exe -?
```

Should display help with command-line options.

---

## How to Enable Boot Logging

### Method 1: Command-Line (Recommended)

```cmd
C:\Tools\Procmon\Procmon.exe /accepteula /captureboot
```

**What happens:**
1. Procmon initializes boot capture configuration
2. Prompts: `"Restart now to begin capturing at boot?"`
3. Click **"Yes"** to restart
4. System reboots and **immediately** begins capturing
5. All kernel-level activity is recorded
6. After full system boot, trace file is automatically saved

**Trace location:** 
```
C:\Users\<username>\AppData\Local\Temp\Procmon-Boot-XXXX.pmd
```

### Method 2: GUI Configuration

1. Open **Procmon.exe**
2. Click **File** → **Capture Events** (toggle ON)
3. Click **File** → **Capture Boot Log**
4. Click **"Restart"** button
5. System reboots with capture enabled

### Method 3: Registry Configuration (Advanced)

```powershell
# Set boot capture (must restart to take effect)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Procmon" /v "BootCapture" /t REG_DWORD /d 1

# Then run Procmon
C:\Tools\Procmon\Procmon.exe /accepteula
```

---

## Reproducing the Boot Issue

### Important: Follow This Workflow

1. **Run the capture command** (Step 1 above)
2. **Restart immediately** when prompted
3. **Let the system attempt to boot** with any issues active
4. **Allow full boot completion** before stopping capture
5. **Don't force restart or power off** - let it naturally complete

### If Issue Prevents Full Boot:

1. **Boot into WinPE** from USB
2. **Mount the Windows partition** offline
3. **Open Procmon trace** from offline system
4. Analyze the trace up to the point where it stopped

---

## Opening & Analyzing the Boot Trace

### Auto-Opening After Boot

The boot trace is **automatically opened** when you run Procmon after the reboot:

```cmd
C:\Tools\Procmon\Procmon.exe
```

### Manual Opening

```cmd
# Open last boot capture
C:\Tools\Procmon\Procmon.exe C:\Users\<username>\AppData\Local\Temp\Procmon-Boot-*.pmd

# Or use File → Open Recent
```

### Initial View

The trace will show **thousands of operations** in reverse chronological order (newest first). This requires filtering.

---

## Filtering & Searching

### Essential Filters

#### 1. Find Failed Operations
```
Result is not "SUCCESS"
```
Shows every operation that failed - most important for boot issues.

#### 2. Find Driver Operations
```
Image ends with ".sys"
```
Isolates driver-related activity.

#### 3. Find Storage Driver Issues
```
Image contains "stornvme" OR Image contains "storahci" OR Image contains "iaStorV"
```
Focuses on most common 0x7B INACCESSIBLE_BOOT_DEVICE causes.

#### 4. Find Registry Access Failures
```
Operation is "RegOpenKey" AND Result is not "SUCCESS"
```
Shows registry access problems (drivers can't find service registry keys).

#### 5. Find Missing Files
```
Result is "NOT_FOUND"
```
Identifies missing driver files or system files.

#### 6. Find Access Denied
```
Result is "ACCESS_DENIED"
```
Indicates permissions issues or file integrity problems.

### How to Apply Filters

1. Click **Filter** menu → **Filter** (or press Ctrl+L)
2. Click **New** to add a filter
3. Set field, condition, value
4. Click **Add**
5. Click **Apply**

### Quick Filter Examples

**Find why stornvme.sys failed to load:**
```
Image ends with "stornvme.sys" AND Result is not "SUCCESS"
```

**Find storage controller initialization:**
```
Path contains "storahci" OR Path contains "nvme" OR Path contains "raid"
```

**Find registry problems:**
```
Path contains "Services\stornvme" AND Result is not "SUCCESS"
```

---

## Interpreting Results

### Understanding Process Monitor Output

Each line represents one system operation:

| Column | Meaning | Example |
|--------|---------|---------|
| **Time** | Exact timestamp (millisecond precision) | 12:34:56.123456 |
| **Process** | Which process/driver performed operation | System, svchost.exe, kernel |
| **Process ID** | Process identifier | 4 (System), 128 (services) |
| **Operation** | Type of system operation | CreateFile, WriteFile, RegOpenKey |
| **Path** | What was accessed | C:\Windows\drivers\storage\stornvme.sys |
| **Result** | Success or error code | SUCCESS, NOT_FOUND, ACCESS_DENIED |
| **Details** | Additional context | Desired Access: Read, Allocation Size: 4096 |

### Common Boot Failure Patterns

#### Pattern 1: Missing Driver File

```
Operation: CreateFile
Path: C:\Windows\System32\drivers\stornvme.sys
Result: NOT_FOUND
→ CAUSE: Driver file doesn't exist
→ FIX: Inject driver from WinPE or restore from backup
```

#### Pattern 2: Driver Not Registered

```
Operation: RegOpenKey
Path: HKLM\System\CurrentControlSet\Services\stornvme
Result: NOT_FOUND or PATH_NOT_FOUND
→ CAUSE: Driver not registered in system registry
→ FIX: Re-enable in registry or reinstall driver
```

#### Pattern 3: Corrupted Driver Signature

```
Operation: SignFile or VerifyFile
Path: C:\Windows\System32\drivers\stornvme.sys
Result: SIGNATURE_VERIFICATION_FAILED
→ CAUSE: Driver file is corrupted or has invalid signature
→ FIX: Extract from Windows media or reinstall driver
```

#### Pattern 4: Registry Corruption

```
Operation: RegQueryValue or RegOpenKey
Path: HKLM\System\CurrentControlSet\Services\stornvme
Result: UNSUCCESSFUL_OPERATION or INVALID_REGISTRY_PATH
→ CAUSE: Registry hive is corrupted
→ FIX: Repair registry from backup or Windows repair
```

#### Pattern 5: Timeout/Hang

```
Operation: <any> repeated 100+ times
Time: 12:34:56.123 → 12:34:59.456 (3+ seconds for same op)
Result: TIMEOUT or repeated UNSUCCESSFUL_OPERATION
→ CAUSE: Driver/hardware not responding
→ FIX: Check hardware compatibility or update BIOS
```

#### Pattern 6: Deadlock

```
Operation: WriteFile (by driver A) → WAITING
Operation: ReadFile (by driver B) → WAITING
→ CAUSE: Two drivers waiting for each other
→ FIX: Check driver load order or dependency
```

---

## Advanced Analysis Techniques

### Technique 1: Timeline Reconstruction

To understand exact boot sequence:

1. **Apply filter:** `Operation is "CreateFile" AND Path ends with ".sys"`
2. **Sort by Time** (ascending for earliest first)
3. **Review in order** to see which drivers load first
4. **Note any gaps** (large time jumps indicate hangs)

### Technique 2: Dependency Tracing

To find why a driver failed to load:

1. Find the driver operation: `Image ends with "stornvme.sys"`
2. Look at **immediately preceding operations** for file access
3. Look for `Result is not "SUCCESS"` before the driver loads
4. That failed operation is likely the cause

### Technique 3: Comparing Boot Attempts

To find what changed between successful and failed boots:

1. **Capture two boot traces** (one working, one failing)
2. Save both as `.csv` files
3. **Use diff tool** to compare operations:
   ```powershell
   # PowerShell comparison
   $successful = Import-Csv "boot-working.csv"
   $failed = Import-Csv "boot-failed.csv"
   
   Compare-Object -ReferenceObject $successful -DifferenceObject $failed |
     Where-Object { $_.Result -ne "SUCCESS" }
   ```
4. Focus on operations that appear in failed but not successful

### Technique 4: Process Filtering

To trace activity by one process:

Filter: `Process Name is "svchost.exe"` OR specific driver name

This reveals all operations initiated by that specific process/driver.

---

## Exporting & Sharing Results

### Export Options

**Method 1: Via GUI**
1. **File** → **Save As**
2. Choose format:
   - `.pmd` - Native format (best for re-analysis)
   - `.csv` - For spreadsheet analysis
   - `.xml` - For programmatic analysis

**Method 2: Via Command-Line**
```cmd
C:\Tools\Procmon\Procmon.exe /capture /export:"C:\Diagnostics\boot-trace.csv"
```

### File Size Estimates

| Format | Typical Size | Compression |
|--------|-------------|-------------|
| `.pmd` | 50-200 MB | Excellent (~5-20 MB) |
| `.csv` | 100-500 MB | Poor (~80-400 MB) |
| `.xml` | 80-300 MB | Poor (~70-250 MB) |

**Recommendation:** Save as `.pmd` for sharing (smaller, preserves all details).

### Sharing with Support

1. Save trace as `.pmd`
2. Compress: `7-Zip` or `WinRAR` (better compression than ZIP)
3. Upload or share file
4. Include context:
   - Boot error message (if visible)
   - Relevant Event Log errors
   - Hardware configuration
   - Steps to reproduce

---

## Troubleshooting Common Issues

### "Boot trace not created"

**Causes & Solutions:**
- System fully shut down: Ensure clean restart, not forced power-off
- Procmon path incorrect: Verify file exists at `C:\Tools\Procmon\Procmon.exe`
- Insufficient permissions: Run command as Administrator
- Conflicting software: Disable third-party monitoring tools

**Fix:**
```cmd
# Verify Procmon is executable
C:\Tools\Procmon\Procmon.exe -?

# Try manual startup
C:\Tools\Procmon\Procmon.exe /accepteula /captureboot
```

### "Trace file is too large"

Boot traces can grow to 500+ MB. If disk space is limited:

**Solution 1: Compress .pmd file**
```powershell
Compress-Archive "Procmon-Boot-*.pmd" "Procmon-Boot.7z"
# Results in 5-20 MB file
```

**Solution 2: Export to filtered CSV**
1. Open trace in Procmon
2. Apply filters to reduce noise
3. File → Export → CSV
4. Use CSV for analysis

**Solution 3: Analyze offline**
```powershell
# Copy trace to another machine with more space
Copy-Item "Procmon-Boot-*.pmd" "E:\Diagnostics\"
# Analyze from external drive
```

### "Can't open boot trace"

**Causes:**
- File is locked by Procmon process
- Trace file corrupted
- 32-bit Procmon trying to open 64-bit trace

**Solution:**
```cmd
# Ensure Procmon is closed
taskkill /IM Procmon.exe

# Verify trace file
dir "C:\Users\<username>\AppData\Local\Temp\Procmon-Boot-*.pmd"

# Try opening directly
C:\Tools\Procmon\Procmon.exe "C:\Users\<username>\AppData\Local\Temp\Procmon-Boot-*.pmd"
```

### "Trace is incomplete or empty"

**Causes:**
- System crashed before trace completed
- Boot logging not fully enabled
- System shut down during capture

**Solution:**
```powershell
# Check file size
(Get-Item "Procmon-Boot-*.pmd").Length

# If very small (<1 MB), likely incomplete
# Try again with Clean Boot sequence

# Check last modified time
Get-Item "Procmon-Boot-*.pmd" | Select-Object LastWriteTime
```

---

## Process Monitor vs Other Tools

### Comparison with Standard Boot Logging

| Feature | ntbtlog.txt | Process Monitor | Event Viewer |
|---------|-------------|-----------------|--------------|
| **Driver Load Status** | ✅ Shows success/fail | ✅ Yes | ⚠️ Indirect |
| **Why It Failed** | ❌ No | ✅ Full details | ⚠️ Limited |
| **File Operations** | ❌ No | ✅ Every operation | ❌ No |
| **Registry Details** | ❌ No | ✅ Every access | ❌ No |
| **Exact Timing** | ⚠️ Seconds | ✅ Milliseconds | ⚠️ Seconds |
| **Operation Sequence** | ❌ No | ✅ Complete | ❌ No |
| **File Size** | ~1 KB | 100-300 MB | ~100 MB |
| **Analysis Speed** | 1 minute | 5-10 minutes | 2-5 minutes |
| **Best For** | Quick diagnosis | Root cause forensics | Error trends |

### Decision Tree

```
Boot Issue Occurs
    │
    ├─→ Quick Answer Needed?
    │   └─→ YES: Use ntbtlog.txt
    │
    ├─→ Driver Shows Failed Loading?
    │   └─→ YES: Use Process Monitor (why did it fail?)
    │
    ├─→ Boot Hangs/Slows?
    │   └─→ YES: Use Process Monitor (timing analysis)
    │
    ├─→ Investigating Storage?
    │   └─→ YES: Use Process Monitor (detailed trace)
    │
    └─→ Blue Screen With Dump?
        └─→ YES: Use WinDbg + Crash Analyzer
```

---

## Integration with MiracleBoot Diagnostic Suite

### Using Process Monitor With MiracleBoot

1. **Gather logs with MiracleBoot:**
   ```powershell
   powershell -File "MiracleBoot-LogGatherer.ps1"
   ```

2. **If ntbtlog.txt shows failures**, enable Process Monitor boot logging:
   ```cmd
   C:\Tools\Procmon\Procmon.exe /accepteula /captureboot
   ```

3. **Analyze both:**
   - ntbtlog.txt: Which drivers failed
   - Procmon trace: Why they failed

4. **Use MiracleBoot remediation:**
   ```powershell
   powershell -File "MiracleBoot-AdvancedLogAnalyzer.ps1" -GenerateRemediationScript
   ```

---

## Performance Impact & Considerations

### During Boot Capture

- **CPU Usage:** Minimal (1-3%)
- **Memory Usage:** 50-100 MB (usually)
- **Disk I/O:** Moderate increase (data being written)
- **Boot Time:** +5-15 seconds typically

### During Analysis

- **CPU Usage:** Moderate (30-50%)
- **Memory Usage:** 500 MB - 2 GB (depends on trace size)
- **Disk Space:** Need 3x trace size for working space
- **Analysis Time:** 1-10 minutes on modern hardware

### Recommendations

- Capture on **real hardware** when possible (performance accurate)
- **Disable antivirus** during capture (reduces noise)
- Close unnecessary **applications** before capture
- Ensure **adequate disk space** (500+ MB available)
- Use **fast disk** for trace storage (SSD preferred)

---

## Command-Line Reference

### Common Commands

```cmd
# Basic boot capture
Procmon.exe /accepteula /captureboot

# Capture and auto-restart
Procmon.exe /accepteula /captureboot /restart

# Open specific trace
Procmon.exe "path\to\trace.pmd"

# Apply filter
Procmon.exe /filter "Image contains stornvme" "path\to\trace.pmd"

# Export filtered results
Procmon.exe /export:"output.csv" /filter "Result is not SUCCESS" "trace.pmd"

# Close GUI (stop capturing)
Procmon.exe /terminate

# Help/Options
Procmon.exe /?
```

---

## Best Practices

1. ✅ **Enable standard boot logging first** (`bcdedit /set {current} bootlog yes`)
2. ✅ **Use Process Monitor for complex issues** (standard boot log insufficient)
3. ✅ **Capture both logs** when investigating (complementary information)
4. ✅ **Save traces for later analysis** (patterns not always obvious immediately)
5. ✅ **Compare multiple boots** (identify what changed)
6. ✅ **Document findings** (trace + ntbtlog + Event Log together tell complete story)
7. ✅ **Disable unnecessary monitoring** (reduces trace noise)
8. ✅ **Use filters aggressively** (thousands of operations can be overwhelming)

---

## References

- **Official Process Monitor:** https://docs.microsoft.com/sysinternals/downloads/procmon
- **Sysinternals Documentation:** https://docs.microsoft.com/sysinternals/
- **MiracleBoot Integration:** See [BOOT_LOGGING_GUIDE.md](BOOT_LOGGING_GUIDE.md)
- **Standard Boot Logging:** [BOOT_LOGGING_GUIDE.md](BOOT_LOGGING_GUIDE.md) → "How to Enable Boot Logging"

---

**Last Updated:** January 7, 2026  
**Document Version:** 1.0  
**MiracleBoot Integration:** v7.2+
