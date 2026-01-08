# MiracleBoot v7.2.0 - GUI & Logging Quick Reference

## 🎯 What Was Fixed

| Issue | Before | After |
|-------|--------|-------|
| **GUI Launch** | ❌ Skipped immediately to MS-DOS mode | ✅ Loads GUI interface properly |
| **Logging** | ❌ Minimal, couldn't trace issues | ✅ Comprehensive logging at all points |
| **Error Messages** | ❌ Silent failures | ✅ Clear reasons for any fallbacks |
| **User Experience** | ❌ No visibility into decisions | ✅ Full transparency via logs |

---

## 🚀 Running MiracleBoot Now

### Standard Usage (FullOS)
```powershell
# Run as Administrator
.\MiracleBoot.ps1

# Expected: Professional GUI window opens
# All operations logged to: LOGS_MIRACLEBOOT/MiracleBoot_[timestamp].log
```

### What You'll See

**On FullOS with GUI available:**
```
╔══════════════════════════════════════════════════════════════════╗
║     MiracleBoot v7.2.0 - Hardened Windows Recovery Toolkit      ║
╚══════════════════════════════════════════════════════════════════╝

Environment: FullOS | SystemDrive: C: | Admin: YES
Log File: C:\...\LOGS_MIRACLEBOOT\MiracleBoot_20260108_142345.log

[LAUNCH] FullOS detected - attempting GUI mode...
[LOADER] Loading WinRepairCore module...
[LOADER] ✓ WinRepairCore loaded successfully
[LAUNCH] Loading GUI module...
[LAUNCH] ✓ Starting GUI interface...

→ GUI WINDOW OPENS ←
```

---

## 📊 Understanding the Log File

### Where to Find Logs
```
Location: C:\Users\[YourName]\Downloads\MiracleBoot_v7_1_1\LOGS_MIRACLEBOOT\
Filename: MiracleBoot_YYYYMMDD_HHMMSS.log

Example: MiracleBoot_20260108_142345.log (Jan 8, 2026 at 2:23:45 PM)
```

### Reading Log Entries
```
[HH:MM:SS] [LEVEL] [COMPONENT] Message

[14:23:45] [INFO] MiracleBoot v7.2.0 - Session Started
                  ↑                      ↑
                  Timestamp              Message content
```

### Color-Coded Log Levels
| Level | Meaning | Example |
|-------|---------|---------|
| **INFO** | Normal operation | Session start, mode selection |
| **SUCCESS** | Operation succeeded | ✓ GUI launched successfully |
| **WARNING** | Non-critical issue | ⚠ Fallback to TUI mode |
| **ERROR** | Operation failed | ✗ WPF not available |
| **DEBUG** | Detailed diagnostic | Menu selection #3 chosen |

---

## 🔍 Troubleshooting: What the Logs Tell You

### ✅ Success Scenario
```log
[14:23:45] [SUCCESS] Logging system initialized successfully
[14:23:46] [INFO] FullOS detected - attempting GUI mode...
[14:23:46] [SUCCESS] ✓ All GUI prerequisites met - ready to launch
[14:23:46] [INFO] ✓ Launching GUI...
[14:23:47] [INFO] GUI window closed normally
```
→ **Your system**: ✓ Working perfectly

---

### ⚠️ Fallback to TUI (Expected on some systems)
```log
[14:23:46] [WARNING] GUI SKIP: WPF assemblies not available
[14:23:46] [WARNING] Reason Detail: PresentationFramework not found
[14:23:46] [WARNING] Fallback: Switching to TUI mode
[14:23:47] [INFO] Loading TUI module...
[14:23:47] [INFO] ✓ Launching TUI...
[14:23:47] [INFO] TUI Mode Starting - User Interface: MS-DOS STYLE
```
→ **Your system**: ⚠️ No GUI framework, using text mode (normal for some environments)

---

### ❌ Actual Problem (Needs Attention)
```log
[14:23:46] [ERROR] GUI launch failed, falling back to TUI mode
[14:23:46] [ERROR] Exception: Start-GUI function not found
[14:23:46] [ERROR] Category: ParentContainsErrorRecordException
[14:23:46] [ERROR] GUI fallback reason: Module file incomplete or corrupt
```
→ **Your system**: ✗ File issue - WinRepairGUI.ps1 may be corrupted

**Solution:**
1. Re-download MiracleBoot
2. Verify all .ps1 files are complete
3. Check file permissions
4. Try again with clean installation

---

## 🎛️ GUI Features (When Available)

### Tab 1: Quick Actions
- **Repair Windows Installation** - Automatic repair attempt
- **Run System File Checker (SFC)** - Scan and fix corrupted system files
- **Check Disk (CHKDSK)** - Scan and repair hard drive errors
- **Repair-Install Readiness** - Check if setup.exe repair mode is viable

### Tab 2: Advanced Tools
- **List Windows Volumes** - View all drives and partitions
- **Scan Storage Drivers** - Identify missing or problematic drivers
- **View BCD Configuration** - See Windows boot settings
- **Inject Drivers (Offline)** - Add drivers to Windows installation

### Tab 3: Information
- **System Information** - Current environment and settings
- **View Diagnostic Log** - Opens log file in Notepad

### Bottom Options
- **Switch to Text Mode** - Falls back to MS-DOS style menu
- **Exit** - Close application

---

## 📋 Text Mode (MS-DOS) Menu

If GUI isn't available or you choose text mode:

```
═══════════════════════════════════════════════════════════
  MIRACLE BOOT v7.2.0 - MS-DOS STYLE MODE
  Environment: FullOS
═══════════════════════════════════════════════════════════

1) List Windows Volumes (Sorted)
2) Scan Storage Drivers (Detailed)
3) Inject Drivers Offline (DISM)
4) Quick View BCD
5) Edit BCD Entry
6) Repair-Install Readiness Check
7) Recommended Recovery Tools
8) Utilities & Tools
9) Network & Internet Help
Q) Quit

Select:
```

---

## 🔧 Common Scenarios & What to Expect

### Scenario 1: Running on Windows 10/11 (Normal)
```
Expected GUI: ✓ YES (if WPF installed)
Log entry: [SUCCESS] All GUI prerequisites met
Experience: Professional GUI opens immediately
```

### Scenario 2: Running from Windows Installer (Shift+F10)
```
Expected GUI: ❌ NO (not in FullOS)
Log entry: [WARNING] Non-FullOS environment detected (WinRE)
Experience: Text mode menu appears
```

### Scenario 3: Running from WinPE Recovery Boot
```
Expected GUI: ❌ NO (not in FullOS)
Log entry: [WARNING] Non-FullOS environment detected (WinPE)
Experience: Text mode menu appears
```

### Scenario 4: Older Windows Version (Pre-WPF)
```
Expected GUI: ❌ NO (WPF not available)
Log entry: [WARNING] WPF unavailable, using TUI mode
Experience: Text mode menu appears
```

---

## 📝 Log Interpretation Cheat Sheet

### Look for these to understand what happened:

**When opening LOGS_MIRACLEBOOT log file:**

| Search For | Means | Action |
|-----------|-------|--------|
| `GUI SKIP` | GUI didn't launch (expected) | Check reason - likely environment |
| `ERROR: GUI launch failed` | GUI crash (check details) | Look for exception message |
| `All GUI prerequisites met` | GUI worked (check why it isn't) | GUI loaded successfully |
| `User initiated fallback` | User clicked "Switch to Text" | Normal - user chose TUI |
| `TUI Mode Starting` | Text mode began | TUI running normally |
| `ExitCode: 0` | Clean exit | Application finished successfully |
| `ExitCode: 1` | Error exit | Check logs for ERROR entries |

---

## 🎓 Log Analysis Examples

### Example 1: Check if GUI was attempted
```powershell
# Open PowerShell as Administrator
$logFile = Get-ChildItem "C:\Users\$env:USERNAME\Downloads\MiracleBoot_v7_1_1\LOGS_MIRACLEBOOT" `
    -Filter "*.log" | Sort LastWriteTime -Desc | Select -First 1

# Look for GUI attempts
Select-String "GUI|FullOS|WPF" $logFile.FullName | Select -First 20
```

### Example 2: Find what made it fall back to TUI
```powershell
# Search for skip reasons
Select-String "SKIP|fallback|Fallback" $logFile.FullName
```

### Example 3: Check for errors
```powershell
# Find all errors
Select-String "\[ERROR\]" $logFile.FullName

# Count errors and warnings
$errorCount = @(Select-String "\[ERROR\]" $logFile.FullName).Count
$warnCount = @(Select-String "\[WARNING\]" $logFile.FullName).Count
Write-Host "Errors: $errorCount, Warnings: $warnCount"
```

---

## 🛠️ If GUI Doesn't Work

### Step 1: Check Admin Privileges
```log
Look for: [ERROR] Not running as Administrator
Solution: Run PowerShell as Administrator → Rerun script
```

### Step 2: Check Environment
```log
Look for: [WARNING] Non-FullOS environment
Solution: This is expected on WinPE/WinRE - text mode is correct
```

### Step 3: Check WPF Availability
```log
Look for: [WARNING] WPF (PresentationFramework) not available
Solution: Your system doesn't have GUI framework - text mode is normal
```

### Step 4: Check File Integrity
```log
Look for: [ERROR] WinRepairGUI.ps1 not found
Solution: Reinstall MiracleBoot or check file permissions
```

---

## ✨ What's Logged (Comprehensive List)

### Session Events
- ✓ Script startup with version
- ✓ PowerShell version and environment type
- ✓ Administrator privilege status
- ✓ All modules loaded (success/failure)
- ✓ Preflight checks results
- ✓ Interface selection decision
- ✓ Session end timestamp

### GUI Events (if attempted)
- ✓ GUI module loading
- ✓ Prerequisites validation (each check)
- ✓ WPF assembly loading
- ✓ XAML window creation
- ✓ Event handler attachment
- ✓ User button clicks
- ✓ Any errors with details
- ✓ GUI window close reason

### TUI Events
- ✓ TUI startup
- ✓ Each menu selection
- ✓ Operation start/end
- ✓ User quit/exit
- ✓ Session end

### Error Tracking
- ✓ Exception types
- ✓ Error messages
- ✓ Error categories
- ✓ Stack context
- ✓ Fallback decisions

---

## 🎯 Next Steps If You Encounter Issues

1. **Open log file**: `LOGS_MIRACLEBOOT/[latest].log`
2. **Search for errors**: Look for `[ERROR]` entries
3. **Check warnings**: Look for `[WARNING]` entries
4. **Identify root cause**: First major issue found is usually the problem
5. **Take action**: See solutions in "Troubleshooting" section above
6. **Verify fix**: Run again and check new log for success

---

## 📞 Support Information

**To report issues effectively:**
1. Attach the relevant log file (from LOGS_MIRACLEBOOT folder)
2. Include your Windows version
3. Mention any error messages from GUI or log
4. Describe what action you were attempting

**Log contains complete diagnostic info for troubleshooting:**
- ✓ Environment details
- ✓ System capabilities
- ✓ Exact failure points
- ✓ Error details with context
- ✓ Timing and sequence of events

---

## Version Info
- **MiracleBoot**: v7.2.0 (Hardened)
- **Fix Date**: January 8, 2026
- **GUI Status**: ✅ Fully Implemented with Comprehensive Logging
- **Logging System**: Enhanced with GUI skip tracking
- **Compatibility**: Windows 10/11, WinPE, WinRE

**Your MiracleBoot is now production-ready with full diagnostic visibility!**
