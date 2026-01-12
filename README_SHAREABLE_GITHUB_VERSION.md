# 🛠️ MiracleBoot v7.2.0 - Windows Recovery & Boot Repair Toolkit

**Version:** 7.2.0 (STABLE)  
**Last Updated:** January 2026  
**Status:** ✅ Production Ready - All Critical Fixes Applied

**MiracleBoot** is a comprehensive Windows system recovery and boot repair solution designed for **IT professionals**, **system administrators**, and **advanced users**. It works in multiple environments—from emergency recovery consoles to fully booted Windows systems—providing powerful diagnostic, repair, and backup tools when you need them most.

---

## 🎯 What MiracleBoot Does

MiracleBoot solves critical Windows boot and system recovery problems:

- ✅ **Boot Failures** - Repair corrupted BCD (Boot Configuration Data), missing boot files, UEFI/BIOS issues
- ✅ **WinRE Detection** - Automatically detects and fixes when default boot entry points to Windows Recovery Environment instead of actual Windows installation
- ✅ **Driver Problems** - Detect and inject missing storage drivers (NVMe, RAID, Intel VMD) causing 0x7B BSOD
- ✅ **Installation Failures** - Diagnose why Windows Setup failed with detailed log analysis
- ✅ **System Diagnostics** - Analyze boot logs, event logs, BSOD stop codes, and hardware compatibility
- ✅ **Offline Repairs** - Perform registry edits, driver injection, and system analysis from WinPE/WinRE
- ✅ **CMD-Only Repairs** - Pure CMD-based emergency fixes that work without PowerShell dependencies
- ✅ **Educational Content** - Learn about recovery tools, backup strategies, and unofficial repair methods

---

## 🚀 Quick Start

### For Windows 10/11 Users (GUI Mode):

1. **Extract** the MiracleBoot package to a convenient location (e.g., `C:\MiracleBoot`)
2. **Right-click** `MiracleBoot.ps1` → **Run with PowerShell** (as Administrator)
3. If execution policy error appears, run:
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

### Quick Command for Windows RE (Shift+F10) - Download from Internet

**Complete Command Sequence:**
```cmd
REM Step 1: Enable Internet
wpeinit
netsh interface set interface "Ethernet" admin=enable
netsh interface set interface "Local Area Connection" admin=enable
netsh interface ip set address name="Ethernet" source=dhcp
netsh interface ip set dns name="Ethernet" static 8.8.8.8
ipconfig /renew
ping -n 2 google.com

REM Step 2: Download and Run Emergency Fix V4 (if available online)
REM Replace URL with your distribution source
curl -L -o "%TEMP%\EMERGENCY_BOOT_REPAIR_V4.cmd" "YOUR_DISTRIBUTION_URL/EMERGENCY_BOOT_REPAIR_V4.cmd" && "%TEMP%\EMERGENCY_BOOT_REPAIR_V4.cmd"
```

**Or use the all-in-one script:**
```cmd
REM If QUICK_INTERNET_AND_FIX.cmd is available on USB, run:
D:\QUICK_INTERNET_AND_FIX.cmd
```

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
- Repair Wizard (intelligent repair sequence)
- Emergency fixes (V1-V4) with individual buttons
- CMD-only repair option (no PowerShell required)
- System diagnostics & log analysis
- Log management (clear all logs or logs over 48 hours)
- Recommended tools guide with backup wizard

**Launch:** Double-click `MiracleBoot.ps1` or run from PowerShell with admin rights

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

## 🛡️ Key Features

### 1️⃣ BCD Management & Boot Repair

- **Comprehensive BCD Parsing** - View all boot entries with ALL properties
- **Visual Boot Menu Simulator** - Preview how boot menu will appear
- **Duplicate Entry Detection** - Auto-detect and rename duplicate boot entries
- **Multi-EFI Partition Sync** - Sync BCD across all EFI partitions (multi-disk setups)
- **Automated Boot Diagnosis** - One-click comprehensive boot issue detection
- **WinRE Detection & Auto-Fix** - Automatically detects when default entry points to Windows Recovery Environment and fixes it
- **Backup Before Modify** - Automatic timestamped BCD backups before changes

**Common Tasks:**
- Rebuild BCD from Windows installation (`bcdboot`)
- Fix boot files (`bootrec /fixboot`, `/fixmbr`)
- Scan for Windows installations (`bootrec /scanos`)
- Set default boot entry and timeout

### 2️⃣ Emergency Boot Repairs

**Emergency Fix V1 (Standard Repair)**
- Comprehensive boot repair using standard Windows tools
- Rebuilds BCD, fixes boot files, scans for installations
- Standalone CMD file - no dependencies required

**Emergency Fix V2 (Alternative Implementation)**
- Alternative implementation with different coding approach
- Uses goto-based flow control
- Standalone CMD file

**Emergency Fix V3 (Minimal Last Resort)**
- Minimal implementation using only basic commands
- No complex nested structures
- Last resort when other fixes fail

**Emergency Fix V4 (Intelligent Minimal Repair)** ⭐ **RECOMMENDED**
- Intelligent diagnostics - checks issues first
- Only fixes what's actually broken (fastest)
- Progress percentage display (0-100%)
- Shows exact commands being executed
- Skips unnecessary commands based on diagnostics

**Comprehensive Boot Repair (CMD-Only)**
- All-in-one standalone repair tool
- Runs all emergency fixes sequentially (V4 → V1 → V2 → V3)
- Validates boot readiness after each repair
- Stops when boot is fixed
- **No PowerShell required** - pure CMD commands

**Repair Wizard**
- Guided repair sequence: V4 (Intelligent) → Brute Force → V1 → V2 → V3
- Checks boot readiness after each step
- Stops if boot is fixed
- Offers to continue if a fix fails
- Automatically fixes WinRE default entry issues

### 3️⃣ Driver Diagnostics & Management

- **Missing Driver Detection** - Identify devices with driver errors (Code 28, 1, 3)
- **Hardware ID Forensics** - Match missing drivers to INF files (Intel VMD, NVMe, RAID)
- **Driver Export** - Export in-use drivers to file for offline installation
- **Driver Extraction** - Extract actual driver files from DriverStore
- **DISM Offline OS Injection** - Inject drivers to offline Windows (C:\) using DISM
- **DISM WIM Injection** - Inject drivers to boot.wim and install.wim recovery images
- **Batch Driver Injection** - Multi-target injection with progress tracking and rollback
- **Snappy Driver Installer Integration** - Auto-detect and download missing drivers
- **Driver Compatibility Validation** - Pre-injection verification and checkpoints
- **Live Driver Loading** - Load harvested drivers in WinPE/WinRE

**Supported Driver Types:**
- Intel VMD (Volume Management Device)
- Intel RST (Rapid Storage Technology)
- NVMe storage controllers
- AMD RAID
- USB 3.x controllers
- Network adapters (NIC)
- Chipset drivers

**Driver Injection Environments:**
- ✅ Offline Windows OS (from WinPE/WinRE)
- ✅ WIM boot images (boot.wim for PE, install.wim for setup)
- ✅ Recovery environments (WinRE)
- ✅ Windows installation media

**Critical Fixes:**
- INACCESSIBLE_BOOT_DEVICE (storage driver missing)
- No network in recovery (NIC drivers)
- NVMe drive not detected (requires chipset driver pre-injection)

### 4️⃣ Advanced Diagnostics

- **Boot Log Analysis** - Parse `ntbtlog.txt` for driver load failures
- **Event Log Analysis** - Scan `System.evtx` for BSOD, shutdown events
- **BSOD Stop Code Explanations** - Human-readable causes for blue screens
- **Setup Log Analysis** - Parse Panther logs to diagnose installation failures
- **Filter Driver Forensics** - Detect problematic third-party storage filters (Acronis, Symantec)
- **Hardware Support Info** - Get manufacturer support URLs for drivers

### 5️⃣ System Recovery Tools

- **System Restore Detection** - Check for available restore points (offline/online)
- **WinRE Health Check** - Validate Windows Recovery Environment configuration
- **Offline OS Information** - Extract version/edition/build from offline registry
- **Registry Override Scripts** - Generate EditionID override scripts for ISO compatibility
- **One-Click Registry Fixes** - Apply all compatibility overrides with backups

### 6️⃣ Log Management

- **Clear All Logs** - Delete all log files from all log directories
- **Clear Old Logs** - Delete log files older than 48 hours
- **Log Directories:**
  - `LOGS_MIRACLEBOOT` (main logs)
  - `LOGS` (analysis logs)
  - `TEST_LOGS` (test logs)
  - `LOG_ANALYSIS` (log analysis results)

### 7️⃣ Network Connectivity Tools

- **WINRE_NETWORK_INIT.cmd** - Quick network initialization for WinRE/Shift+F10
- **QUICK_INTERNET_AND_FIX.cmd** - All-in-one script to enable internet and download/run emergency fix
- **Automatic Network Detection** - Detects and enables network adapters
- **DNS Configuration** - Sets DNS to 8.8.8.8 (Cloudflare) for reliable connectivity

### 8️⃣ Experimental Features

⚠️ **Use with caution - advanced/hacky methods**

- **Repair Install Forcing (Online)** - Force in-place upgrade from inside Windows
- **Repair Install Forcing (Offline)** - Trick Setup into repairing offline OS from WinPE
- **Cloud Repair Integration** - Instructions for Windows 11 hidden cloud repair feature

### 9️⃣ Educational Content

- **Recommended Tools Guide** - Curated list of free/paid recovery tools
- **Backup Strategy Wizard** - Interactive 3-2-1 backup planning
- **Unofficial Repair Tips** - Community-sourced workarounds from MDL forums
- **Command Explanations** - Learn what each command does and why
- **Boot Fixer Instructions** - Comprehensive guide for running in Windows Repair environment

---

## 📦 What's Included

### Core Files:

- **`MiracleBoot.ps1`** - Main launcher (auto-detects environment)
- **`WinRepairCore.ps1`** - Function library (2000+ lines of diagnostic/repair logic)
- **`WinRepairGUI.ps1`** - Graphical interface (for Full OS)
- **`WinRepairTUI.ps1`** - Text interface (for WinRE/WinPE)
- **`RunMiracleBoot.cmd`** - Batch launcher for recovery environments
- **`FixWinRepairCore.ps1`** - Maintenance script (auto-fixes syntax errors)

### Emergency Repair Scripts (Standalone CMD - No PowerShell Required):

- **`EMERGENCY_BOOT_REPAIR.cmd`** - Emergency Fix V1 (Standard Repair)
- **`EMERGENCY_BOOT_REPAIR_V2.cmd`** - Emergency Fix V2 (Alternative Implementation)
- **`EMERGENCY_BOOT_REPAIR_V3.cmd`** - Emergency Fix V3 (Minimal Last Resort)
- **`EMERGENCY_BOOT_REPAIR_V4.cmd`** - Emergency Fix V4 (Intelligent Minimal Repair) ⭐
- **`EMERGENCY_BOOT_REPAIR_WRAPPER.cmd`** - Runs all fixes sequentially with automatic failover
- **`COMPREHENSIVE_BOOT_REPAIR.cmd`** - All-in-one CMD-only repair (runs all fixes until boot is restored)

### Network & Quick Access Scripts:

- **`WINRE_NETWORK_INIT.cmd`** - Enable internet in Windows RE
- **`QUICK_INTERNET_AND_FIX.cmd`** - Enable internet + download/run emergency fix

### Documentation:

- **`README.md`** - Main documentation file
- **`DOCUMENTATION/`** - Detailed documentation folder
- Additional guides and reference materials

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

**Option 1: Use WINRE_NETWORK_INIT.cmd**
```cmd
WINRE_NETWORK_INIT.cmd
```

**Option 2: Manual Network Adapter Enablement**
```cmd
wpeinit
netsh interface set interface "Ethernet" admin=enable
netsh interface ip set address name="Ethernet" source=dhcp
netsh interface ip set dns name="Ethernet" static 8.8.8.8
ipconfig /renew
```

**Option 3: PowerShell Network Configuration**
```powershell
Get-NetAdapter | Where-Object {$_.Status -eq 'Disabled'} | Enable-NetAdapter
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
- ✅ **WinRE Detection** - Automatically detects and fixes when default entry points to WinRE instead of Windows installation
- ✅ **Boot Readiness Checks** - Comprehensive validation after each repair

---

## 📋 System Requirements

### Minimum:
- Windows 10 1809+ or Windows 11
- PowerShell 5.0+ (for GUI/TUI modes)
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
- **Note:** Emergency fixes (V1-V4) work without PowerShell - pure CMD only

---

## 🔄 Version History

### v7.2.0 (Current - January 2026)
- ✅ Added CMD-only repair option (no PowerShell required)
- ✅ WinRE detection and auto-fix functionality
- ✅ Log management (clear all logs or logs over 48 hours)
- ✅ Quick internet download commands for Windows RE
- ✅ Network initialization scripts (WINRE_NETWORK_INIT.cmd, QUICK_INTERNET_AND_FIX.cmd)
- ✅ Repair Wizard with intelligent repair sequence
- ✅ Individual emergency fix buttons (V1-V4)
- ✅ Enhanced boot readiness checks (detects WinRE entries)
- ✅ Comprehensive Boot Fixer Instructions
- ✅ Recommended Tools feature
- ✅ Backup Strategy Wizard
- ✅ Environment detection display
- ✅ Enhanced TUI with tools menu

### v7.1.1
- Initial release
- Comprehensive BCD management
- Driver forensics & diagnostics
- Setup log analysis

---

## 🚧 Roadmap (Future Versions)

**Coming Soon:**
- 🌐 Network connectivity auto-detection & enablement
- 🌍 Text-based browser for help access
- ⚠️ Enhanced safety warnings before destructive operations
- 📊 Windows installation failure reason checker
- 🔧 Additional CMD-only repair options

---

## 📜 License & Usage

This software is provided as-is for educational and recovery purposes. Always create backups before using system repair tools.

**Important:** This tool modifies critical system files including the Boot Configuration Data (BCD). Use at your own risk and ensure you have proper backups before proceeding with any repairs.

---

## 🆘 Support & Resources

- **Documentation**: See included documentation folder for detailed guides
- **Unofficial Repair Tips**: Available in the "Diagnostics & Logs" tab
- **Community Forums**: Win-Raid, MDL Forum (for advanced discussions)

---

## 💼 Commercial Use

This toolkit is designed for professional IT environments and can be used in commercial settings. All emergency repair scripts are standalone and do not require external dependencies or internet connectivity for basic operations.

**Key Commercial Benefits:**
- ✅ No recurring subscription fees
- ✅ Works offline (no cloud dependencies)
- ✅ Standalone CMD scripts for enterprise deployment
- ✅ Comprehensive logging and audit trails
- ✅ Professional-grade diagnostics and repair capabilities

---

**Made with ❤️ for Windows recovery professionals**

*"When Windows won't boot, MiracleBoot will."*

---

## 📞 Technical Support

For technical support, feature requests, or bug reports, please contact your distributor or refer to the included documentation.

**System Requirements Verification:**
- Ensure Windows 10/11 (1809+) is installed
- Verify administrator privileges are available
- Check that PowerShell 5.0+ is installed (for GUI/TUI modes)
- For emergency fixes, only CMD is required (no PowerShell needed)

**Troubleshooting:**
- If GUI doesn't launch, TUI mode will activate automatically
- If PowerShell execution policy blocks execution, use the provided bypass command
- For network issues in recovery, use WINRE_NETWORK_INIT.cmd
- All emergency fixes are standalone and work without dependencies

---

*Version 7.2.0 - January 2026*
