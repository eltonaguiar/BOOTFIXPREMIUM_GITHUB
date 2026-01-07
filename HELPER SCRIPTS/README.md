# 🔧 HELPER SCRIPTS - Core Modules & Utilities

**Location:** Root-level `HELPER SCRIPTS/` folder  
**Purpose:** Contains all core PowerShell modules imported and used by MiracleBoot  
**Status:** Production Ready (v7.2.0+)

---

## 📋 What's Inside

This folder contains 20+ PowerShell scripts that provide the core functionality for MiracleBoot. These scripts are:

- ✅ Imported by main launchers (`MiracleBoot.ps1`, `RunMiracleBoot.cmd`)
- ✅ Organized by feature/function
- ✅ Documented with inline help
- ✅ Tested as part of the validation system
- ⚠️ **NOT** meant to be run directly (use main launchers instead)

---

## 📁 Folder Contents

### Core Repair Modules

| Script | Purpose | Environment |
|--------|---------|-------------|
| **MiracleBoot-BootRecovery.ps1** | Boot configuration and BCD editing | GUI + TUI |
| **MiracleBoot-Diagnostics.ps1** | System diagnostics and log analysis | GUI + TUI |
| **MiracleBoot-DriverInjection.ps1** | Driver detection and risk assessment | GUI + TUI |
| **MiracleBoot-DriverInjectionDISM.ps1** | **NEW** DISM-based driver injection to OS/WIM | Recovery |
| **MiracleBoot-NetworkRepair.ps1** | Network connectivity fixes | GUI + TUI |
| **MiracleBoot-Automation.ps1** | Automated repair workflows | GUI + TUI |

### UI Implementations

| Script | Purpose | Environment |
|--------|---------|-------------|
| **WinRepairGUI.ps1** | Graphical User Interface (WPF) | Full Windows only |
| **WinRepairTUI.ps1** | Text User Interface | WinRE/WinPE/CMD |
| **WinRepairCore.ps1** | Core repair logic (shared) | GUI + TUI |

### Utility & Support Scripts

| Script | Purpose | Used By |
|--------|---------|---------|
| **Backup-WorkingVersion.ps1** | Creates timestamped backups | Automation system |
| **Generate-BootRecoveryGuide.ps1** | Creates recovery guides | GUI |
| **Harvest-DriverPackage.ps1** | Exports drivers from running system | Driver injection |
| **KeyboardSymbols.ps1** | Keyboard input helpers | TUI |
| **EnsureRepairInstallReady.ps1** | Validates repair install environment | Automation |
| **Diskpart-Interactive.ps1** | Disk partitioning helper | Advanced users |

---

## 🚀 Usage

### ✅ Correct Way (Use These)

**For Windows 10/11 users:**
```powershell
# Run the GUI directly
.\MiracleBoot.ps1
```

**For Recovery/WinPE users:**
```cmd
# Run the launcher
RunMiracleBoot.cmd
```

### ❌ Incorrect Way (Don't Do This)

```powershell
# DON'T run helper scripts directly
.\MiracleBoot-BootRecovery.ps1    # ❌ Wrong - missing dependencies
.\WinRepairGUI.ps1                # ❌ Wrong - missing configuration
.\MiracleBoot-Diagnostics.ps1     # ❌ Wrong - needs initialization
```

---

## 🔧 For Developers Only

If you're developing/debugging MiracleBoot:

### Testing Individual Modules

```powershell
# 1. Set up the environment
. .\MiracleBoot.ps1 -Initialize

# 2. Import the specific module
. .\HELPER SCRIPTS\MiracleBoot-Diagnostics.ps1

# 3. Call functions directly
Get-SystemDiagnostics
Get-BootConfiguration
```

### Running Validation Tests

```powershell
# Test the entire module
cd .\VALIDATION
.\SUPER_TEST_MANDATORY.ps1
```

### Individual Module Tests

```powershell
# Test a specific module
cd .\TEST
.\Test-MiracleBoot-Diagnostics.ps1
.\Test-MiracleBoot-BootRecovery.ps1
.\Test-MiracleBoot-DriverInjection.ps1
```

---

## 📚 Function Reference

### Quick Examples (for developers)

**Get System Information:**
```powershell
Get-SystemDiagnostics -Verbose
```

**Analyze Boot Configuration:**
```powershell
Get-BootConfiguration
Set-BootConfiguration -EntryName "Windows 10" -IsDefault $true
```

**Inject Drivers (Detection & Risk Assessment):**
```powershell
Get-NetworkDriverInfo
Get-StorageDriverInfo
Get-DriverComprehensiveReport
```

**Inject Drivers (DISM - OS & WIM):**
```powershell
# Inject to offline Windows (C:\)
Invoke-DISMOfflineOSDriverInjection -DriverPath "E:\Drivers" -Recursive

# Inject to WIM boot image
Invoke-DISMWIMDriverInjection -WIMPath "E:\boot.wim" -ImageIndex 1 -DriverPath "E:\Drivers"

# Batch injection to multiple targets
$targets = @(
    @{ Type = 'OS'; Path = 'C:\' },
    @{ Type = 'WIM'; Path = 'E:\boot.wim'; Index = 1 }
)
Invoke-BatchDriverInjection -DriverPath "E:\Drivers" -Targets $targets

# Launch Snappy Driver Installer for offline package creation
Invoke-SnappyDriverInstaller -Mode Download

# Validate driver compatibility before injection
Test-DriverCompatibility -DriverPath "E:\Drivers"
```

**Network Diagnostics:**
```powershell
Test-NetworkConnectivity
Repair-NetworkAdapter -AdapterName "Ethernet"
```

See individual script files for complete documentation.

---

## ✅ Validation & Quality

All scripts in this folder are:

- ✅ Syntax validated (no parse errors)
- ✅ Module tested (all dependencies work)
- ✅ Integration tested (work with main launchers)
- ✅ Error keyword scanned (no obvious bugs)
- ✅ Documented (inline help available)
- ✅ Version controlled (Git tracked)

**Validation Status:** PASS  
**Last Validation:** January 7, 2026  
**Validation Tool:** `SUPER_TEST_MANDATORY.ps1`

---

## 📦 Dependencies

### Required PowerShell Version
- Minimum: PowerShell 3.0
- Recommended: PowerShell 5.0+
- Best: PowerShell 5.1 (Windows 10 included)

### Required Modules
- PresentationFramework (GUI only)
- Hyper-V (some diagnostics)

### Required Permissions
- Administrator privileges (for most operations)
- System drive access (for offline operations)

---

## 🔐 Security Notes

These scripts:
- ✅ Do NOT collect personal data
- ✅ Do NOT phone home or send telemetry
- ✅ Do NOT modify system files unnecessarily
- ✅ Do NOT install external software
- ✅ Create backups before modifications
- ✅ Can be audited (open source)

All modifications are logged to `TEST_LOGS/` when validation is run.

---

## 🆘 Troubleshooting

### "Module not found" error
**Issue:** Script can't find a helper module  
**Solution:** Run from root directory (not from HELPER SCRIPTS folder)

### "Function not recognized" error
**Issue:** Trying to call a function from main script  
**Solution:** Use main launcher (`MiracleBoot.ps1`) instead

### "Permission denied" error
**Issue:** Not running as Administrator  
**Solution:** Right-click → "Run with PowerShell as Administrator"

### "Invalid registry operation" error
**Issue:** Registry operation failed  
**Solution:** Check `TEST_LOGS/` for details; may need Safe Mode

---

## 📞 Support

For issues with helper scripts:

1. **Check documentation:** Read the script's inline help
   ```powershell
   Get-Help .\MiracleBoot-Diagnostics.ps1 -Full
   ```

2. **Review test logs:** Check `TEST_LOGS/` for error details

3. **Run validation:** Execute `SUPER_TEST_MANDATORY.ps1` to verify integrity

4. **Report issues:** GitHub Issues with script name and error message

---

## 📝 File Listing (v7.2.0)

```
HELPER SCRIPTS/
├── MiracleBoot-Automation.ps1          (Automated workflows)
├── MiracleBoot-Backup.ps1              (Backup operations)
├── MiracleBoot-BootRecovery.ps1        (BCD/Boot fixes)
├── MiracleBoot-Diagnostics.ps1         (System analysis)
├── MiracleBoot-DriverInjection.ps1     (Driver injection)
├── MiracleBoot-NetworkDiagnostics.ps1  (Network tools)
├── MiracleBoot-NetworkRepair.ps1       (Network fixes)
├── WinRepairCore.ps1                   (Core logic)
├── WinRepairGUI.ps1                    (GUI interface)
├── WinRepairTUI.ps1                    (TUI interface)
├── Backup-WorkingVersion.ps1           (Version backup)
├── Completion-Summary.ps1              (Status reporting)
├── Diskpart-Interactive.ps1            (Disk tools)
├── EnsureRepairInstallReady.ps1        (Repair validation)
├── ERROR-KEYWORD-SCANNER.ps1           (Error detection)
├── FixWinRepairCore.ps1                (Core repairs)
├── Generate-BootRecoveryGuide.ps1      (Guide generation)
├── Harvest-DriverPackage.ps1           (Driver export)
├── KeyboardSymbols.ps1                 (Input helpers)
└── NetworkDiagnostics.ps1              (Net diagnostics)
```

---

## 🎯 Next Steps

- **Users:** Don't interact with this folder - use main launchers
- **Developers:** See individual script files for function documentation
- **Contributors:** Follow coding standards in CONTRIBUTING.md

---

**Last Updated:** January 7, 2026  
**Version:** 7.2.0  
**Status:** Production Ready  
**Maintenance:** Actively maintained
