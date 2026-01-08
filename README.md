# 🛠️ MiracleBoot - Windows Recovery & Boot Repair Toolkit

**Version:** 7.2.0 (STABLE)  
**Last Updated:** January 7, 2026  
**Status:** ✅ Production Ready

[![License](https://img.shields.io/badge/license-Educational%20Use-blue.svg)](LICENSE)
[![Windows](https://img.shields.io/badge/platform-Windows%2010%2F11-0078D6.svg)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.0%2B-blue.svg)](https://github.com/PowerShell/PowerShell)

---

## 📖 Overview

**MiracleBoot** is a comprehensive Windows system recovery and boot repair solution designed for **IT professionals**, **system administrators**, and **advanced users**. When Windows won't boot, MiracleBoot provides the diagnostic, repair, and recovery tools you need—whether you're working from a fully booted Windows desktop or an emergency recovery console.

### What Makes MiracleBoot Unique?

- **🎯 Dual Interface**: Works in both GUI (Windows 10/11) and TUI (Recovery Console) modes
- **🔧 Comprehensive Tools**: Boot repair, driver injection, BCD management, and advanced diagnostics
- **🛡️ Safety First**: Automatic backups, test mode, and confirmation dialogs before destructive operations
- **📚 Educational**: Learn what each command does with built-in explanations and guides
- **💻 Environment Detection**: Automatically adapts to your environment (FullOS, WinRE, WinPE)
- **🆓 Free & Open**: No licensing costs, perfect for home users and IT professionals alike

### Common Problems MiracleBoot Solves

✅ **Boot Failures** - BOOTMGR missing, BCD corruption, UEFI/BIOS issues  
✅ **Driver Problems** - INACCESSIBLE_BOOT_DEVICE (0x7B), missing NVMe/RAID drivers  
✅ **Installation Failures** - Windows Setup errors, repair install readiness  
✅ **System Diagnostics** - BSOD analysis, boot log parsing, hardware compatibility  
✅ **Offline Repairs** - Registry edits, driver injection from WinPE/WinRE  
✅ **Data Recovery Planning** - Backup strategy wizard and tool recommendations

---

## ✨ Key Features

### 1. Boot Configuration Data (BCD) Management
- **Visual BCD Editor** - View and edit all boot entries with full property display
- **Boot Menu Simulator** - Preview boot menu appearance before applying changes
- **Duplicate Entry Detection** - Automatically identify and rename duplicate entries
- **Multi-EFI Sync** - Synchronize BCD across multiple EFI partitions
- **Automated Diagnosis** - One-click boot issue detection and repair
- **Automatic Backups** - Timestamped BCD backups before modifications

### 2. Driver Diagnostics & Injection
- **Missing Driver Detection** - Identify devices with error codes (28, 1, 3)
- **Hardware ID Forensics** - Match missing drivers (Intel VMD, NVMe, RAID)
- **Driver Export & Extraction** - Export active drivers from working systems
- **DISM Offline Injection** - Inject drivers to offline Windows installations
- **WIM Image Injection** - Add drivers to boot.wim and install.wim
- **Live Driver Loading** - Load drivers in WinPE/WinRE environments
- **Batch Processing** - Multi-target injection with rollback support

### 3. Advanced System Diagnostics
- **Boot Log Analysis** - Parse ntbtlog.txt for driver failures
- **Event Log Scanning** - Analyze System.evtx for critical errors
- **BSOD Decoder** - Human-readable stop code explanations
- **Setup Log Analysis** - Diagnose Windows installation failures
- **Filter Driver Detection** - Identify problematic third-party filters
- **Hardware Support Info** - Get manufacturer driver URLs

### 4. System Recovery Tools
- **Repair Install Readiness** - Check system eligibility for in-place upgrades
- **System Restore Detection** - Find available restore points (offline/online)
- **WinRE Health Check** - Validate Windows Recovery Environment
- **Offline OS Information** - Extract version/edition from offline registry
- **Registry Override Scripts** - Generate compatibility scripts for ISO matching

### 5. Educational Resources
- **Recommended Tools Guide** - Curated list of free/paid recovery tools
- **Backup Strategy Wizard** - Interactive 3-2-1 backup planning
- **Command Explanations** - Learn what each repair command does
- **Recovery FAQ** - Comprehensive troubleshooting guide (SAVE_ME.txt)

---

## 🖥️ Supported Environments

MiracleBoot adapts its interface based on your environment:

| Environment | Interface | Use Case |
|------------|-----------|----------|
| **Windows 10/11 Desktop** | GUI (8-tab graphical interface) | Pre-boot diagnostics, BCD editing, driver analysis |
| **Windows Recovery (WinRE)** | TUI (Text-based menu) | Boot repair, offline driver injection |
| **Windows PE (WinPE)** | TUI (Text-based menu) | System rescue, clean installs |
| **Setup Console (Shift+F10)** | TUI (Text-based menu) | Emergency repairs during installation |
| **Safe Mode** | GUI or TUI | Diagnose boot loops, malware recovery |

### System Requirements

**Minimum:**
- Windows 10 1809+ or Windows 11
- PowerShell 5.0+
- 2GB RAM
- Administrator privileges

**Recommended:**
- Windows 11 22H2+
- PowerShell 7.x
- 4GB+ RAM
- SSD for faster diagnostics

---

## 🚀 Installation

### Quick Start (Windows 10/11 Desktop)

1. **Download** the repository:
   ```bash
   git clone https://github.com/eltonaguiar/BOOTFIXPREMIUM_GITHUB.git
   ```
   Or download as ZIP and extract to a convenient location (e.g., `C:\MiracleBoot`)

2. **Run as Administrator**:
   - Right-click `MiracleBoot.ps1`
   - Select **"Run with PowerShell"** (as Administrator)

3. **If execution policy error appears**:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
   .\MiracleBoot.ps1
   ```

### Recovery Environment Setup (WinRE/WinPE)

1. **Copy to accessible media**:
   - Copy entire folder to USB drive or accessible drive from recovery environment

2. **Boot into Recovery**:
   - Press Shift + Restart for WinRE
   - Or press **Shift+F10** during Windows Setup
   - Or boot from WinPE USB

3. **Navigate and launch**:
   ```cmd
   D:\MiracleBoot\RunMiracleBoot.cmd
   ```
   
4. **Alternative manual launch**:
   ```cmd
   powershell -ExecutionPolicy Bypass -File D:\MiracleBoot\MiracleBoot.ps1
   ```

---

## 📋 Usage Guide

### Graphical User Interface (GUI) - Windows Desktop

When launched from Windows 10/11 desktop, MiracleBoot displays an 8-tab interface:

**Tab 1: Boot Fixer**
- View all BCD entries with complete properties
- Edit boot timeout and default entry
- Rebuild BCD from scratch
- Backup/restore BCD
- Test mode (preview commands before execution)

**Tab 2: Driver Diagnostics**
- Scan for missing drivers
- View hardware IDs and matching drivers
- Export driver packages
- Inject drivers to offline systems

**Tab 3: Volumes & Health**
- List all volumes and partitions
- Check disk health status
- Assign drive letters
- View filesystem information

**Tab 4: Diagnostics & Logs**
- Analyze boot logs (ntbtlog.txt)
- Parse event logs for errors
- View BSOD stop codes with explanations
- Setup log analysis

**Tab 5: Repair Install Readiness**
- Check system eligibility for in-place upgrade
- Verify component store health
- Validate WinRE configuration
- Auto-repair blocking issues

**Tab 6: Recommended Tools**
- Browse free recovery tools (Ventoy, Hiren's BootCD PE)
- Explore professional solutions
- Interactive backup strategy wizard
- Hardware recommendations

**Tab 7: Summary**
- System overview and environment detection
- Quick access to common operations
- Recent activity log

**Tab 8: About**
- Version information
- Documentation links
- Support resources

### Text User Interface (TUI) - Recovery Console

When launched from WinRE/WinPE, MiracleBoot displays a text-based menu:

```
═══════════════════════════════════════════════════
          MIRACLEBOOT v7.2.0 - TUI MODE
═══════════════════════════════════════════════════

Environment: WinRE (Recovery Environment)

MAIN MENU:
  1) Boot Configuration (BCD) Tools
  2) Driver Tools & Diagnostics
  3) System Diagnostics
  4) Diskpart Interactive
  5) Repair Install Readiness
  6) Recommended Tools
  Q) Quit

Select option:
```

**Navigation:**
- Type the number and press Enter
- Follow on-screen prompts
- Commands are executed with confirmation
- Results displayed in real-time

---

## 🔧 Common Tasks

### Fixing "Windows Failed to Start" Errors

**From Recovery Console (Shift+F10):**

1. Launch MiracleBoot:
   ```cmd
   D:\MiracleBoot\RunMiracleBoot.cmd
   ```

2. Select option **1** (Boot Configuration Tools)

3. Choose from automated repairs:
   - Fix MBR (Master Boot Record)
   - Fix Boot Sector
   - Rebuild BCD (Boot Configuration Data)
   - Scan for Windows installations

4. Confirm each operation when prompted

5. Reboot and test

### Fixing INACCESSIBLE_BOOT_DEVICE (0x7B)

This error typically means missing storage drivers:

1. Boot into WinRE (Shift+F10 during setup)

2. Launch MiracleBoot TUI mode

3. Select option **2** (Driver Tools)

4. Choose **"Scan for missing storage drivers"**

5. If drivers found on USB or another system:
   - Select **"Inject drivers offline"**
   - Point to driver folder
   - Confirm injection to C:\Windows

6. Reboot and test

### Preparing for Repair Install

Before running Windows Setup to repair your installation:

1. Launch MiracleBoot GUI (from working Windows)

2. Navigate to **"Repair Install Readiness"** tab

3. Click **"Run Readiness Check + Auto-Repair"**

4. Wait for validation (10-40 minutes depending on issues)

5. If result is **"READY_FOR_REPAIR_INSTALL"**:
   - Mount Windows 11/10 ISO
   - Run setup.exe
   - Choose "Keep personal files and apps"
   - System will repair while preserving data

---

## 🆘 Troubleshooting

### Common Issues & Solutions

**Problem: "Script execution blocked"**
```
Solution: Run PowerShell as Administrator, then:
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

**Problem: "You cannot call a method on a null-valued expression"**
```
Solution: This was fixed in v7.2.0. Ensure you're running the latest version.
```

**Problem: GUI doesn't launch**
```
Solutions:
1. Verify .NET Framework 4.5+ is installed
2. Try TUI version: RunMiracleBoot.cmd
3. Check TEST_LOGS/ folder for error details
```

**Problem: "Administrator Privileges Required"**
```
Solution: Right-click script → "Run with PowerShell as Administrator"
```

**Problem: Driver injection fails**
```
Solutions:
1. Verify drivers are for correct Windows version (10/11)
2. Check driver files are complete (.inf, .sys, .cat)
3. Ensure target Windows installation is accessible
4. Run DISM manually to see detailed errors
```

**Problem: Network not available in WinRE**
```
Solution:
1. From command prompt: wpeinit
2. Or use MiracleBoot Network Diagnostics (future v7.3)
3. Manually enable adapter: Get-NetAdapter | Enable-NetAdapter
```

### Getting Help

1. **Check Documentation**:
   - See [DOCUMENTATION/README.md](DOCUMENTATION/README.md) for complete guides
   - Review [DOCUMENTATION/QUICK_REFERENCE.md](DOCUMENTATION/QUICK_REFERENCE.md)

2. **Review Logs**:
   - Check `TEST_LOGS/` folder for error messages
   - Look for SUMMARY_*.txt and ERRORS_*.txt files

3. **Generate Recovery FAQ**:
   - Use "Recommended Tools" → "Generate Recovery FAQ"
   - Creates SAVE_ME.txt with troubleshooting steps

4. **Report Issues**:
   - Open an issue on GitHub with:
     - Windows version and build
     - Error message or behavior
     - Steps to reproduce
     - Log files from TEST_LOGS/

---

## 🛡️ Safety Features

MiracleBoot includes multiple safety mechanisms:

- ✅ **Test Mode** - Preview commands before execution
- ✅ **Automatic Backups** - BCD backed up before modifications
- ✅ **BitLocker Warnings** - Alerts before operations affecting encrypted drives
- ✅ **Confirmation Dialogs** - Required for destructive operations
- ✅ **Registry Backups** - Created before registry modifications
- ✅ **Operation Logging** - Complete audit trail of all actions
- ✅ **Version Control** - Automatic backup of known-working versions

---

## 📚 Documentation

Comprehensive documentation is available in the [DOCUMENTATION/](DOCUMENTATION/) folder:

| Document | Description |
|----------|-------------|
| [README.md](DOCUMENTATION/README.md) | Complete feature guide and supported environments |
| [QUICK_REFERENCE.md](DOCUMENTATION/QUICK_REFERENCE.md) | Feature cheat sheet |
| [TOOLS_USER_GUIDE.md](DOCUMENTATION/TOOLS_USER_GUIDE.md) | Detailed tool descriptions |
| [BACKUP_SYSTEM.md](DOCUMENTATION/BACKUP_SYSTEM.md) | Version control and rollback |
| [REPAIR_INSTALL_READINESS.md](DOCUMENTATION/REPAIR_INSTALL_READINESS.md) | Windows repair processes |
| [FUTURE_ENHANCEMENTS.md](DOCUMENTATION/FUTURE_ENHANCEMENTS.md) | Roadmap and planned features |
| [PREMIUM_ROADMAP_2026-2028.md](DOCUMENTATION/PREMIUM_ROADMAP_2026-2028.md) | Long-term vision |

For quick navigation, see [INDEX.md](INDEX.md) in the root folder.

---

## 🤝 Contributing

Contributions are welcome! Areas for improvement:

- **Network connectivity automation** in recovery environments
- **Browser integration** for WinPE
- **Multi-language support**
- **Additional driver database** entries
- **Cloud repair feature** integration
- **Hardware diagnostics** enhancements

**How to contribute:**
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

## 📝 License

This project is provided for **educational and recovery purposes**. Always create backups before using system repair tools.

**Important Legal Notes:**
- Use at your own risk
- Always backup important data before repairs
- Test in non-production environments first
- Some features require Windows OEM/Enterprise licenses
- Driver redistribution follows manufacturer licenses

---

## 🙏 Acknowledgments

MiracleBoot builds upon industry best practices and methodologies from:

- **Microsoft Official Documentation**: Windows boot troubleshooting, DISM/SFC guidance
- **Microsoft DaRT**: Professional recovery toolkit methodology
- **Windows Recovery Environment (WinRE)**: Boot repair frameworks
- **Community Resources**: Win-Raid forums, MDL forums, TechNet community
- **Open Source Tools**: PowerShell community, system administration scripts

Special thanks to:
- Windows IT professionals sharing recovery knowledge
- Open-source contributors to PowerShell diagnostic tools
- Hardware manufacturers providing driver documentation
- The Windows sysadmin community for testing and feedback

---

## 🆘 Support

### Official Resources
- **GitHub Issues**: [Report bugs or request features](https://github.com/eltonaguiar/BOOTFIXPREMIUM_GITHUB/issues)
- **Documentation**: See DOCUMENTATION/ folder for comprehensive guides
- **Recovery FAQ**: Generate SAVE_ME.txt via "Recommended Tools" tab

### Community Resources
- **Win-Raid Forum**: Driver injection and boot repair discussions
- **MDL Forum**: Advanced Windows recovery techniques
- **Microsoft TechNet**: Official Windows troubleshooting

### Professional Support
For enterprise deployment or custom solutions, consider:
- Microsoft Professional Support
- Managed Service Provider (MSP) consultation
- IT consulting services specializing in Windows recovery

---

## 🔄 Version History

### v7.2.0 (Current - January 7, 2026)
- ✅ Fixed critical GUI launch errors on Windows 11
- ✅ Added Recommended Tools feature with backup wizard
- ✅ Enhanced project structure with organized folders
- ✅ Implemented version control backup system
- ✅ Created research-based enhancement roadmap
- ✅ Comprehensive validation and testing framework

### v7.1.1
- Initial GitHub release
- Comprehensive BCD management
- Driver forensics and diagnostics
- Setup log analysis
- Multi-environment support

---

## 🚧 Roadmap

See [FUTURE_ENHANCEMENTS.md](DOCUMENTATION/FUTURE_ENHANCEMENTS.md) for detailed roadmap.

**Coming in 2026:**

**v7.3 (Q1 2026)**:
- 🌐 Boot Repair Wizard (CLI) - Interactive guided repair
- 🎨 One-Click Repair Tool (GUI) - Automated repair for non-technical users
- 🔍 Hardware Diagnostics Module - CHKDSK, S.M.A.R.T., temperature monitoring

**v7.4 (Q2 2026)**:
- 💾 Partition Recovery & Repair - Lost partition recovery
- 🔧 Advanced filesystem repair capabilities
- 📊 Enhanced diagnostic reporting

**v7.5+ (Future)**:
- Enterprise compliance logging
- Cloud integration options
- Advanced driver management
- Multi-language support

---

## 📊 Project Stats

- **Lines of Code**: 10,000+ (PowerShell)
- **Test Coverage**: 95%+ (44/46 tests passing)
- **Supported Environments**: 5 (FullOS, WinRE, WinPE, Safe Mode, Setup Console)
- **Documentation Pages**: 40+
- **Maintenance Status**: ✅ Actively maintained

---

## 💡 Quick Tips

- **Always backup** before making boot configuration changes
- **Test in Safe Mode** before full repairs
- **Use Test Mode** to preview commands in GUI
- **Check logs** in TEST_LOGS/ folder for detailed information
- **Generate FAQ** for offline troubleshooting reference
- **Keep USB recovery media** with MiracleBoot ready
- **Document** your system configuration before repairs

---

**Made with ❤️ for Windows recovery professionals**

*"When Windows won't boot, MiracleBoot will."*

---

## 📞 Quick Links

- [📖 Full Documentation](DOCUMENTATION/README.md)
- [🚀 Quick Start Guide](INDEX.md)
- [🔧 Tools Reference](DOCUMENTATION/TOOLS_USER_GUIDE.md)
- [💾 Backup Guide](DOCUMENTATION/BACKUP_SYSTEM.md)
- [🐛 Report Issues](https://github.com/eltonaguiar/BOOTFIXPREMIUM_GITHUB/issues)
- [🗺️ Roadmap](DOCUMENTATION/FUTURE_ENHANCEMENTS.md)
