# BOOTFIX PREMIUM

🔧 **Professional Boot Repair & Recovery Utility**

BOOTFIX PREMIUM is a comprehensive boot repair and recovery tool designed to fix common boot-related issues on Windows and Linux systems. This premium utility provides automated diagnostics and repair functions for bootloader problems, partition issues, and boot sector corruption.

## 🌟 Features

- **Automatic Boot Diagnostics** - Detects and analyzes boot configuration issues
- **MBR/GPT Repair** - Fixes corrupted Master Boot Record and GUID Partition Table
- **Bootloader Repair** - Repairs GRUB, GRUB2, and Windows Boot Manager
- **Boot Sector Recovery** - Restores damaged boot sectors
- **Partition Table Repair** - Fixes partition table errors
- **UEFI/Legacy Support** - Compatible with both UEFI and Legacy BIOS systems
- **Backup & Restore** - Creates backups before making changes
- **Multi-OS Support** - Works with Windows, Linux, and dual-boot configurations

## 📋 Requirements

- Root/Administrator privileges
- Python 3.6 or higher
- Supported OS: Windows 7+, Linux (Ubuntu, Debian, Fedora, etc.)
- At least 100MB free disk space

## 🚀 Installation

### Linux
```bash
git clone https://github.com/eltonaguiar/BOOTFIXPREMIUM_GITHUB.git
cd BOOTFIXPREMIUM_GITHUB
sudo python3 bootfix.py --install
```

### Windows (Run as Administrator)
```cmd
git clone https://github.com/eltonaguiar/BOOTFIXPREMIUM_GITHUB.git
cd BOOTFIXPREMIUM_GITHUB
python bootfix.py --install
```

## 💻 Usage

### Basic Diagnostics
```bash
sudo python3 bootfix.py --diagnose
```

### Repair MBR
```bash
sudo python3 bootfix.py --repair-mbr
```

### Repair GRUB Bootloader
```bash
sudo python3 bootfix.py --repair-grub
```

### Repair Windows Bootloader
```bash
python bootfix.py --repair-windows-boot
```

### Full System Scan and Auto-Repair
```bash
sudo python3 bootfix.py --auto-fix
```

### Create Backup
```bash
sudo python3 bootfix.py --backup
```

## 🔧 Advanced Options

- `--target-disk` - Specify target disk (e.g., /dev/sda, C:)
- `--boot-mode` - Force UEFI or Legacy mode
- `--skip-backup` - Skip backup creation (not recommended)
- `--verbose` - Enable detailed logging
- `--dry-run` - Show what would be done without making changes

## 📊 Supported Issues

- Boot device not found
- GRUB rescue mode
- Windows Boot Manager errors
- Missing operating system
- Invalid partition table
- Boot sector corruption
- UEFI boot problems
- Dual-boot configuration issues

## ⚠️ Safety Features

- **Automatic Backups** - All operations create backups before proceeding
- **Dry-Run Mode** - Preview changes before applying them
- **Rollback Support** - Undo changes if something goes wrong
- **Verification** - Post-repair integrity checks

## 📝 License

MIT License - See LICENSE file for details

## 🤝 Contributing

Contributions are welcome! Please read CONTRIBUTING.md for guidelines.

## 📞 Support

- Report issues: https://github.com/eltonaguiar/BOOTFIXPREMIUM_GITHUB/issues
- Documentation: https://github.com/eltonaguiar/BOOTFIXPREMIUM_GITHUB/wiki

## ⚡ Quick Fix Examples

### "GRUB Rescue" Error
```bash
sudo python3 bootfix.py --repair-grub --target-disk /dev/sda
```

### "Missing Operating System"
```bash
sudo python3 bootfix.py --repair-mbr --verify
```

### Windows Won't Boot
```bash
python bootfix.py --repair-windows-boot --fix-bcd
```

## 🔐 Security Notice

This tool requires administrative privileges to modify boot sectors and system files. Always create backups and use caution when running boot repair utilities.

---

**Version:** 1.0.0  
**Author:** Elton Aguiar  
**Status:** Active Development
