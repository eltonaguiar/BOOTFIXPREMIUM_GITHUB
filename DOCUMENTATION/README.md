# 🛠️ MiracleBoot v7.2.0 - Windows Recovery & Boot Repair Toolkit

**Version:** 7.2.0 (STABLE)  
**Last Updated:** January 7, 2026  
**Status:** ✅ Production Ready - All Critical Fixes Applied

**MiracleBoot** is a comprehensive Windows system recovery and boot repair solution designed for **IT professionals**, **system administrators**, and **advanced users**. It works in multiple environments—from emergency recovery consoles to fully booted Windows systems—providing powerful diagnostic, repair, and backup tools when you need them most.

---

## 📋 Recent Updates (January 7, 2026)

### ✅ Critical GUI Fixes
- **Resolved:** "You cannot call a method on a null-valued expression" error that prevented GUI launch on Windows 11
- **Solution:** Fixed function structure, added defensive null checks for all event handlers
- **Result:** GUI now launches without errors and is fully functional

### 🎨 Project Structure Reorganization
- Moved helper scripts to dedicated `HELPER SCRIPTS/` folder
- Moved validation scripts to dedicated `VALIDATION/` folder
- Moved test logs to `TEST_LOGS/` and test modules to `TEST/`
- Kept only 2 main launchers in root: `MiracleBoot.ps1` & `RunMiracleBoot.cmd`
- **See:** [INDEX.md](../INDEX.md) for new structure details

### 📊 Research-Based Enhancement Roadmap
- Comprehensive industry analysis (WinRE, WinPE, Microsoft DaRT, commercial tools)
- Identified capability gaps and improvement opportunities
- Created phased implementation plan (v7.3-7.6 over 2026)
- **See:** [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md) for details

### 📦 Version Control System
- Implemented `LAST_KNOWN_WORKING_<timestamp>` backup system
- Automatically maintains up to 5 confirmed working versions
- Enables quick rollback if future changes introduce issues
- **See:** [BACKUP_SYSTEM.md](BACKUP_SYSTEM.md) for details

---

## 🎯 Purpose

MiracleBoot solves critical Windows boot and system recovery problems:

- ✅ **Boot Failures** - Repair corrupted BCD (Boot Configuration Data), missing boot files, UEFI/BIOS issues
- ✅ **Driver Problems** - Detect and inject missing storage drivers (NVMe, RAID, Intel VMD) causing 0x7B BSOD
- ✅ **Installation Failures** - Diagnose why Windows Setup failed with detailed log analysis
- ✅ **System Diagnostics** - Analyze boot logs, event logs, BSOD stop codes, and hardware compatibility
- ✅ **Offline Repairs** - Perform registry edits, driver injection, and system analysis from WinPE/WinRE
- ✅ **Educational Content** - Learn about recovery tools, backup strategies, and unofficial repair methods

---

## 🖥️ Supported Environments

MiracleBoot adapts to your environment with **two interfaces**:

### 1. 💻 **Graphical User Interface (GUI)** - Windows 10/11 Full OS

**Best for:** Desktop users, visual learners, comprehensive diagnostics

**Requirements:**
- Windows 10/11 with desktop environment
- .NET Framework 4.5+ (for WPF)
- Administrator privileges

**Features:**
- 8-tab interface with visual BCD editor
- Boot menu simulator (WYSIWYG preview)
- Driver diagnostics with export capabilities
- One-click repair operations with test mode
- System diagnostics & log analysis
- Recommended tools guide with backup wizard

**Launch:** Double-click `MiracleBoot.ps1` or run from PowerShell with admin rights

---

### 2. ⌨️ **Text User Interface (TUI)** - WinPE/WinRE/Shift+F10

**Best for:** Recovery environments, Shift+F10 command prompts, minimal installations

**Requirements:**
- Windows Recovery Environment (WinRE)
- Windows Preinstallation Environment (WinPE)
- Command Prompt in recovery mode (Shift+F10 at Windows Setup)
- PowerShell 5.0+ (available in modern WinRE/WinPE)

**Features:**
- MS-DOS style menu for keyboard navigation
- Volume listing & driver scanning
- BCD viewing & editing
- Offline driver injection
- Recommended tools guide
- Utility launcher (Notepad, Registry Editor, etc.)

**Launch:** From recovery command prompt, run `RunMiracleBoot.cmd` or directly `powershell -ExecutionPolicy Bypass -File MiracleBoot.ps1`

---

## 🚀 Quick Start

### For Windows 10/11 Users (GUI Mode):

1. **Download** the repository as ZIP or clone: `git clone https://github.com/eltonaguiar/BOOTFIXPREMIUM_GITHUB.git`
2. **Extract** to a convenient location (e.g., `C:\MiracleBoot`)
3. **Right-click** `MiracleBoot.ps1` → **Run with PowerShell** (as Administrator)
4. If execution policy error appears, run:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
   .\MiracleBoot.ps1
   ```

### For Recovery Environment (TUI Mode):

1. **Copy** the entire folder to a USB drive or accessible drive from WinRE/WinPE
2. Boot into **Windows Recovery Environment** (Advanced Startup → Troubleshoot → Command Prompt)
   - Or press **Shift+F10** during Windows Setup
3. Navigate to the folder (e.g., `D:\MiracleBoot`)
4. Run: `RunMiracleBoot.cmd`
5. If batch file fails, manually run:
   ```cmd
   powershell -ExecutionPolicy Bypass -File MiracleBoot.ps1
   ```

---

## 🔧 Environment Compatibility Matrix

| Environment | GUI Available | TUI Available | PowerShell Required | Internet Access | Typical Use Case |
|-------------|---------------|---------------|---------------------|-----------------|------------------|
| **Windows 10/11 Full OS** | ✅ Yes | ✅ Yes | ✅ Yes (built-in) | ✅ Usually | Pre-boot diagnostics, BCD management |
| **WinRE (Recovery)** | ❌ No* | ✅ Yes | ✅ Yes | ⚠️ Maybe** | Boot repair, driver injection, offline diagnostics |
| **WinPE (Bootable USB)** | ❌ No* | ✅ Yes | ✅ Yes | ⚠️ Maybe** | System rescue, clean installs, driver loading |
| **Shift+F10 (Setup)** | ❌ No | ✅ Yes | ✅ Yes | ❌ Usually not | Emergency repairs during failed installation |
| **Safe Mode** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Usually | Diagnose boot loops, malware recovery |

\* *WPF GUI requires desktop environment; WinRE/WinPE typically lack this. TUI mode activates automatically.*  
\** *Network drivers may need manual enablement. See Network Connectivity section below.*

---

## 📦 What's Included

### Core Files:

- **`MiracleBoot.ps1`** - Main launcher (auto-detects environment)
- **`WinRepairCore.ps1`** - Function library (2000+ lines of diagnostic/repair logic)
- **`WinRepairGUI.ps1`** - Graphical interface (for Full OS)
- **`WinRepairTUI.ps1`** - Text interface (for WinRE/WinPE)
- **`RunMiracleBoot.cmd`** - Batch launcher for recovery environments
- **`FixWinRepairCore.ps1`** - Maintenance script (auto-fixes syntax errors)

### Documentation:

- **`README.md`** - This file
- **`FUTURE_ENHANCEMENTS.md`** - Roadmap for v8.0+
- **`TOOLS_USER_GUIDE.md`** - Comprehensive recovery tools guide
- **`RECOMMENDED_TOOLS_FEATURE.md`** - Feature implementation details

---

## 🛡️ Key Features

### 1️⃣ BCD Management & Boot Repair

- **Comprehensive BCD Parsing** - View all boot entries with ALL properties
- **Visual Boot Menu Simulator** - Preview how boot menu will appear
- **Duplicate Entry Detection** - Auto-detect and rename duplicate boot entries
- **Multi-EFI Partition Sync** - Sync BCD across all EFI partitions (multi-disk setups)
- **Automated Boot Diagnosis** - One-click comprehensive boot issue detection
- **Backup Before Modify** - Automatic timestamped BCD backups before changes

**Common Tasks:**
- Rebuild BCD from Windows installation (`bcdboot`)
- Fix boot files (`bootrec /fixboot`, `/fixmbr`)
- Scan for Windows installations (`bootrec /scanos`)
- Set default boot entry and timeout

---

### 2️⃣ Driver Diagnostics & Management

- **Missing Driver Detection** - Identify devices with driver errors (Code 28, 1, 3)
- **Hardware ID Forensics** - Match missing drivers to INF files (Intel VMD, NVMe, RAID)
- **Driver Export** - Export in-use drivers to file for offline installation
- **Driver Extraction** - Extract actual driver files from DriverStore
- **Offline Driver Injection** - Inject drivers into offline Windows using DISM
- **Live Driver Loading** - Load harvested drivers in WinPE/WinRE

**Supported Driver Types:**
- Intel VMD (Volume Management Device)
- Intel RST (Rapid Storage Technology)
- NVMe storage controllers
- AMD RAID
- USB 3.x controllers

---

### 3️⃣ Advanced Diagnostics

- **Boot Log Analysis** - Parse `ntbtlog.txt` for driver load failures
- **Event Log Analysis** - Scan `System.evtx` for BSOD, shutdown events
- **BSOD Stop Code Explanations** - Human-readable causes for blue screens
- **Setup Log Analysis** - Parse Panther logs to diagnose installation failures
- **Filter Driver Forensics** - Detect problematic third-party storage filters (Acronis, Symantec)
- **Hardware Support Info** - Get manufacturer support URLs for drivers

---

### 4️⃣ System Recovery Tools

- **System Restore Detection** - Check for available restore points (offline/online)
- **WinRE Health Check** - Validate Windows Recovery Environment configuration
- **Offline OS Information** - Extract version/edition/build from offline registry
- **Registry Override Scripts** - Generate EditionID override scripts for ISO compatibility
- **One-Click Registry Fixes** - Apply all compatibility overrides with backups

---

### 5️⃣ Experimental Features

⚠️ **Use with caution - advanced/hacky methods**

- **Repair Install Forcing (Online)** - Force in-place upgrade from inside Windows
- **Repair Install Forcing (Offline)** - Trick Setup into repairing offline OS from WinPE
- **Cloud Repair Integration** - Instructions for Windows 11 hidden cloud repair feature

---

### 6️⃣ Educational Content

- **Recommended Tools Guide** - Curated list of free/paid recovery tools
- **Backup Strategy Wizard** - Interactive 3-2-1 backup planning
- **Unofficial Repair Tips** - Community-sourced workarounds from MDL forums
- **Command Explanations** - Learn what each command does and why

---

## 🌐 Network Connectivity in Recovery Environments

### Default Network Status:

| Environment | Network Adapters | Internet Access | Browser Available |
|-------------|------------------|-----------------|-------------------|
| **Full OS** | ✅ Enabled | ✅ Yes | ✅ Yes (Edge/Chrome) |
| **WinRE** | ⚠️ Usually disabled | ❌ No | ❌ No |
| **WinPE** | ⚠️ Depends on build | ⚠️ Maybe | ⚠️ Custom only |
| **Shift+F10** | ❌ Disabled | ❌ No | ❌ No |

### Enabling Network in Recovery:

**Option 1: Manual Network Adapter Enablement**
```cmd
wpeinit
```
*(WinPE only - initializes network stack)*

**Option 2: PowerShell Network Configuration**
```powershell
Get-NetAdapter | Where-Object {$_.Status -eq 'Disabled'} | Enable-NetAdapter
```

**Option 3: Use MiracleBoot's Built-in Network Tools** *(Coming in v7.3)*
- Auto-detect and enable network adapters
- Test internet connectivity
- Configure DNS (8.8.8.8, 1.1.1.1)
- Launch text-based browser for help resources

---

## 🌍 Browser Access in Recovery Environments

### Full OS:
- Use built-in Edge, Chrome, Firefox normally

### WinRE/WinPE:
**Browsers typically don't work due to:**
- Missing GUI subsystem (WPF/GDI+)
- No display drivers
- Limited DLL dependencies

**Workarounds:**
1. **Text-based Browser** *(planned v7.3)* - `Invoke-WebRequest` with HTML parsing
2. **Portable Browser on USB** - Include Firefox Portable/Chrome Portable in WinPE build
3. **Custom WinPE with Browser** - Use Hiren's BootCD PE (includes browsers)

### Shift+F10:
❌ **Not possible** - No GUI framework, command-line only

**Alternative:** Use `curl` or `Invoke-WebRequest` to fetch text-based help:
```powershell
Invoke-WebRequest -Uri "https://example.com/help" | Select-Object -ExpandProperty Content
```

---

## ⚠️ Safety Features

MiracleBoot includes multiple safety mechanisms:

- ✅ **Test Mode** - Preview commands before execution (Boot Fixer tab)
- ✅ **Automatic Backups** - BCD backed up before modifications
- ✅ **BitLocker Warnings** - Alerts before operations that may lock encrypted drives
- ✅ **Confirmation Dialogs** - Required for all destructive operations
- ✅ **Registry Backups** - Created before registry overrides
- ✅ **Operation Logging** - All actions logged for audit trail

---

## 📋 System Requirements

### Minimum:
- Windows 10 1809+ or Windows 11
- PowerShell 5.0+
- 2GB RAM
- Administrator privileges

### Recommended:
- Windows 11 22H2+
- PowerShell 7.x
- 4GB+ RAM
- SSD for faster diagnostics

### For WinRE/WinPE:
- Modern WinRE (Windows 10 1809+)
- PowerShell support in WinPE (included in modern builds)

---

## 🤝 Contributing

Contributions welcome! Areas for improvement:
- Network connectivity automation
- Browser integration for WinPE
- Multi-language support
- Additional driver database
- Cloud repair feature integration

---

## 📜 License

This project is provided as-is for educational and recovery purposes. Always create backups before using system repair tools.

---

## 🆘 Support & Resources

- **GitHub Issues**: Report bugs or request features
- **Unofficial Repair Tips**: See "Diagnostics & Logs" tab → "Unofficial Repair Tips"
- **Community Forums**: Win-Raid, MDL Forum (for advanced discussions)

---

## 🔄 Version History

### v7.2.0 (Current)
- ✅ Added Recommended Tools feature
- ✅ Backup Strategy Wizard
- ✅ Environment detection display
- ✅ Enhanced TUI with tools menu

### v7.1.1
- Initial GitHub release
- Comprehensive BCD management
- Driver forensics & diagnostics
- Setup log analysis

---

## 🚧 Roadmap (v7.3+)

See [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md) for detailed roadmap.

**Coming Soon:**
- 🌐 Network connectivity auto-detection & enablement
- 🌍 Text-based browser for ChatGPT/help access
- ⚠️ Enhanced safety warnings before destructive operations
- 📊 Windows installation failure reason checker
- 🔧 PowerShell-free fallback mode for legacy systems

---

**Made with ❤️ for Windows recovery professionals**

*"When Windows won't boot, MiracleBoot will."*