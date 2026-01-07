# 🔧 Driver Injection Workflow Guide

**Version:** v7.2.1  
**Last Updated:** January 7, 2026  
**Status:** Production Ready

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [DISM Driver Injection (Offline OS)](#dism-driver-injection-offline-os)
3. [WIM File Injection (boot.wim, install.wim)](#wim-file-injection)
4. [Snappy Driver Installer Integration](#snappy-driver-installer-integration)
5. [Batch Processing](#batch-processing)
6. [Troubleshooting](#troubleshooting)
7. [Quick Reference](#quick-reference)

---

## 🎯 Overview

MiracleBoot now has comprehensive driver injection capabilities for both **offline OS** and **recovery environments**:

| Target | Environment | Command | Use Case |
|--------|-------------|---------|----------|
| **Offline OS (C:\)** | WinPE/WinRE | `dism /image:C:\ /add-driver` | When Windows won't boot - inject drivers before reboot |
| **boot.wim** | Recovery media | `dism /mount-image` → inject → `/unmount-image /commit` | Inject drivers into WinPE recovery environment |
| **install.wim** | Setup media | Same WIM injection | Add drivers to Windows installation media |
| **Snappy SDI** | Full Windows | GUI-based scanner | Auto-detect and download missing drivers |

---

## 🖥️ DISM Driver Injection (Offline OS)

### When to Use
- System won't boot with **INACCESSIBLE_BOOT_DEVICE** error
- Missing storage drivers (NVMe, SATA, RAID)
- In WinPE/WinRE environment with C:\ accessible
- Preparing recovery media with essential drivers pre-loaded

### Prerequisites
- ✅ Windows disk accessible (from WinPE/WinRE or recovery partition)
- ✅ Driver files with .inf files (not just .sys files)
- ✅ Administrator privileges
- ✅ DISM available (Windows built-in)

### Usage

```powershell
# Basic usage
Invoke-DISMOfflineOSDriverInjection -DriverPath "E:\Drivers"

# With recursive search (recommended)
Invoke-DISMOfflineOSDriverInjection -DriverPath "E:\Drivers" -Recursive
```

### What It Does

1. **Validates driver path** - Checks if drivers exist
2. **Validates offline image** - Ensures C:\ is accessible
3. **Executes DISM** - Runs: `dism /image:C:\ /add-driver /driver:E:\Drivers /recurse`
4. **Logs output** - Records operation in driver-injection-YYYY-MM-DD.log
5. **Reports result** - Returns success/failure with exit code

### Example Workflow

```powershell
# 1. Boot into WinPE/WinRE
# 2. Attach USB drive with drivers (E:\ drive)
# 3. Run injection
$result = Invoke-DISMOfflineOSDriverInjection -DriverPath "E:\Drivers"

# 4. Check result
if ($result.Success) {
    Write-Host "Drivers injected successfully! Reboot Windows."
} else {
    Write-Host "Failed: $($result.Message)"
    Write-Host "Output: $($result.Output)"
}
```

### DISM Command Breakdown

```
dism /image:C:\ 
  - Target: Offline Windows installation at C:\

/add-driver 
  - Operation: Add drivers

/driver:E:\Drivers 
  - Source: Driver folder on USB (E:\ drive)

/recurse 
  - Search: All subfolders for .inf files
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "Cannot find path C:\" | C:\ not accessible from WinPE/WinRE |
| "No .inf files found" | Drivers not in proper format |
| "DISM exit code: 1" | Check logs for specific DISM error |
| "Permission denied" | Run PowerShell as Administrator |

---

## 💾 WIM File Injection

### When to Use
- Adding drivers to boot.wim (WinPE recovery environment)
- Pre-loading drivers in install.wim (Windows setup media)
- Creating custom WinPE images with drivers
- Preparing offline installation media

### Prerequisites
- ✅ WIM file path (boot.wim or install.wim)
- ✅ Image index (usually 1 for boot.wim)
- ✅ Driver files with .inf files
- ✅ Sufficient disk space (min 2x WIM size for mount/operation)
- ✅ Administrator privileges

### Usage

```powershell
# Inject to boot.wim
Invoke-DISMWIMDriverInjection `
    -WIMPath "E:\boot.wim" `
    -ImageIndex 1 `
    -DriverPath "E:\Drivers"

# Inject to install.wim (may have multiple indexes)
Invoke-DISMWIMDriverInjection `
    -WIMPath "E:\install.wim" `
    -ImageIndex 4 `
    -DriverPath "E:\Drivers"
```

### What It Does

1. **Validates files** - Checks WIM and drivers exist
2. **Creates checkpoint** - Backs up original WIM
3. **Mounts WIM** - Extracts image to mount directory
4. **Injects drivers** - Adds drivers via DISM
5. **Unmounts with commit** - Saves changes to WIM
6. **Logs operation** - Records with checkpoint reference

### Example Workflow

```powershell
# 1. Prepare WIM file from Windows ISO
# Copy boot.wim from ISO to E:\ drive

# 2. Inject drivers
$result = Invoke-DISMWIMDriverInjection `
    -WIMPath "E:\boot.wim" `
    -ImageIndex 1 `
    -DriverPath "E:\Drivers"

# 3. Check checkpoint (for rollback if needed)
if (-not $result.Success) {
    Restore-DriverCheckpoint `
        -CheckpointPath $result.Checkpoint `
        -TargetPath "E:\boot.wim"
}

# 4. Use modified WIM for recovery media
# Re-create USB with modified boot.wim
```

### DISM WIM Commands

```
dism /mount-image 
  /imagefile:E:\boot.wim 
  /index:1 
  /mountdir:C:\MiracleBoot-Drivers\Mount
  - Mounts WIM to temporary folder

dism /image:C:\MiracleBoot-Drivers\Mount 
  /add-driver 
  /driver:E:\Drivers 
  /recurse
  - Injects drivers into mounted image

dism /unmount-image 
  /mountdir:C:\MiracleBoot-Drivers\Mount 
  /commit
  - Saves changes back to WIM file
```

### Finding Image Indexes

```powershell
# List all images in WIM
dism /get-wiminfo /wimfile:E:\install.wim

# Output:
# Index : 1
# Name  : Windows 11 Home
# Index : 2
# Name  : Windows 11 Pro
# etc.
```

---

## 🚀 Snappy Driver Installer Integration

### When to Use
- Running full Windows (not WinPE/WinRE)
- Need to auto-detect ALL missing drivers
- Want downloadable driver packages before injection
- Prefer GUI-based driver management

### Installation
1. Download from: **https://www.snappy-driver-installer.org/**
2. Extract to: `C:\Program Files\Snappy Driver Installer`
3. No installation needed (portable)

### Usage

```powershell
# Scan for missing drivers
Invoke-SnappyDriverInstaller -Mode Scan

# Download missing drivers automatically
Invoke-SnappyDriverInstaller -Mode Download

# Auto-prepare for DISM injection (recommended)
Invoke-SnappyDriverInstaller -Mode Inject
```

### What It Does

1. **Launches Snappy Driver Installer** GUI
2. **Scans system** - Detects missing drivers
3. **Downloads drivers** - From free official sources (no malware!)
4. **Organizes by category** - Network, Storage, Chipset, etc.
5. **Installs or exports** - Can install directly or save for offline use

### Complete Workflow

```powershell
# STEP 1: Scan current system
Write-Host "Scanning for missing drivers..."
Invoke-SnappyDriverInstaller -Mode Scan

# STEP 2: Download driver packages
Write-Host "Downloading driver packages..."
Invoke-SnappyDriverInstaller -Mode Download
# (Snappy downloads to its cache folder)

# STEP 3: Copy drivers to USB
Copy-Item -Path "C:\ProgramData\SnappyDriver\Drivers" `
    -Destination "E:\Drivers" -Recurse

# STEP 4: Boot to WinPE/WinRE
# Insert USB drive with drivers

# STEP 5: Inject via DISM
Invoke-DISMOfflineOSDriverInjection -DriverPath "E:\Drivers"

# STEP 6: Reboot Windows
# Drivers are now pre-loaded before Windows starts
```

### Advantages
- ✅ Completely free
- ✅ Portable (no installation)
- ✅ No adware/malware (from trusted source)
- ✅ Huge driver database
- ✅ Auto-categorizes drivers
- ✅ GUI is intuitive

---

## 🔄 Batch Processing

### When to Use
- Injecting to multiple targets at once
- Recovery media with multiple WIM files
- Creating comprehensive recovery environment

### Usage

```powershell
# Define multiple injection targets
$targets = @(
    @{
        Type  = 'OS'
        Path  = 'C:\'
    },
    @{
        Type  = 'WIM'
        Path  = 'E:\boot.wim'
        Index = 1
    },
    @{
        Type  = 'WIM'
        Path  = 'E:\install.wim'
        Index = 4
    }
)

# Execute batch injection
$batchResult = Invoke-BatchDriverInjection `
    -DriverPath "E:\Drivers" `
    -Targets $targets

# Check summary
$batchResult.Summary
# Output: TotalTargets=3, SuccessCount=3, FailureCount=0, SuccessRate=100%

# Check detailed results
$batchResult.DetailedResults | ForEach-Object {
    if ($_.Result.Success) {
        Write-Host "✅ $($_.Target.Type) - Success"
    } else {
        Write-Host "❌ $($_.Target.Type) - Failed: $($_.Result.Message)"
    }
}
```

### Progress Tracking
- Real-time logging to driver-injection-YYYY-MM-DD.log
- Progress percentage displayed
- Detailed output for each target
- Success/failure summary at end

---

## 🧪 Compatibility Validation

### Before Injecting

```powershell
# Validate driver .inf files
$validation = Test-DriverCompatibility -DriverPath "E:\Drivers"

if ($validation.Compatible) {
    Write-Host "✅ $($validation.ValidDrivers) valid drivers found"
    Invoke-DISMOfflineOSDriverInjection -DriverPath "E:\Drivers"
} else {
    Write-Host "❌ Driver validation failed"
    Write-Host "Found: $($validation.TotalInfFiles) .inf files"
    Write-Host "Valid: $($validation.ValidDrivers) drivers"
}
```

### What Gets Validated
- ✅ .inf file syntax (required sections)
- ✅ Driver structure (SourceDisksFiles section)
- ✅ File integrity
- ✅ Architecture compatibility (x86/x64)

---

## 🚨 Troubleshooting

### DISM Fails with Exit Code 1

```powershell
# Check logs
Get-Content 'C:\MiracleBoot-Drivers\driver-injection-*.log'

# Common causes:
# 1. Invalid WIM file
# 2. Insufficient disk space
# 3. Corrupted driver .inf files
# 4. Wrong image index
# 5. WIM locked by another process
```

### No Drivers Found

```powershell
# Verify driver structure
Get-ChildItem -Path "E:\Drivers" -Filter "*.inf" -Recurse | 
    Select-Object FullName, Name

# If empty: Check if drivers are in subdirectories
# DISM requires actual .inf files, not just driver executables
```

### WIM Mount Fails

```powershell
# Manually clean up mounts
$mountPath = 'C:\MiracleBoot-Drivers\Mount'
if (Test-Path $mountPath) {
    dism /unmount-image /mountdir:$mountPath /discard
    Remove-Item -Path $mountPath -Force
}

# Retry injection
```

### Snappy Installer Won't Launch

```powershell
# Check if installed
Test-Path 'C:\Program Files\Snappy Driver Installer\SDI.exe'

# If false, download from:
# https://www.snappy-driver-installer.org/

# Ensure it's in correct location before using integration
```

---

## 💾 Rollback & Checkpoints

### Automatic Checkpoints

WIM injections automatically create backups:
```
C:\MiracleBoot-Drivers\Checkpoints\
├── wim-checkpoint-20260107-143022.bak
├── wim-checkpoint-20260107-150315.bak
└── wim-checkpoint-20260107-152844.bak
```

### Manual Rollback

```powershell
# If injection failed, restore from checkpoint
Restore-DriverCheckpoint `
    -CheckpointPath 'C:\MiracleBoot-Drivers\Checkpoints\wim-checkpoint-*.bak' `
    -TargetPath 'E:\boot.wim'
```

### OS Injection (No Rollback Needed)
- Offline OS injection adds drivers directly
- Doesn't modify Windows system files
- Safe to run multiple times
- Drivers accumulate (idempotent)

---

## 📊 Quick Reference

### Command Cheat Sheet

```powershell
# Inject to offline OS (C:\)
Invoke-DISMOfflineOSDriverInjection -DriverPath "E:\Drivers" -Recursive

# Inject to WIM file
Invoke-DISMWIMDriverInjection -WIMPath "E:\boot.wim" -ImageIndex 1 -DriverPath "E:\Drivers"

# Batch injection
$targets = @(
    @{ Type = 'OS'; Path = 'C:\' },
    @{ Type = 'WIM'; Path = 'E:\boot.wim'; Index = 1 }
)
Invoke-BatchDriverInjection -DriverPath "E:\Drivers" -Targets $targets

# Snappy Driver Installer
Invoke-SnappyDriverInstaller -Mode Download

# Validate drivers
Test-DriverCompatibility -DriverPath "E:\Drivers"

# Restore from checkpoint
Restore-DriverCheckpoint -CheckpointPath "path/to/backup.bak" -TargetPath "E:\boot.wim"
```

### Typical Workflows

**Scenario 1: Boot Failure with INACCESSIBLE_BOOT_DEVICE**
```powershell
# 1. Boot to WinPE/WinRE from USB
# 2. Attach USB with drivers
# 3. Run:
Invoke-DISMOfflineOSDriverInjection -DriverPath "E:\Drivers"
# 4. Reboot - Windows will load with drivers pre-injected
```

**Scenario 2: Create Custom Recovery Media**
```powershell
# 1. Extract boot.wim from Windows ISO
# 2. Run Snappy to get driver packages
# 3. Inject:
Invoke-DISMWIMDriverInjection -WIMPath "E:\boot.wim" `
    -ImageIndex 1 -DriverPath "E:\Drivers"
# 4. Re-create recovery USB with modified boot.wim
```

**Scenario 3: Comprehensive Driver Update**
```powershell
# 1. Scan with Snappy
Invoke-SnappyDriverInstaller -Mode Scan
# 2. Download all drivers
Invoke-SnappyDriverInstaller -Mode Download
# 3. Copy to USB
# 4. Boot to WinPE and inject:
Invoke-DISMOfflineOSDriverInjection -DriverPath "E:\Drivers"
```

---

## 📖 See Also

- [MiracleBoot-DriverInjectionDISM.ps1](../HELPER%20SCRIPTS/MiracleBoot-DriverInjectionDISM.ps1) - Complete module with all functions
- [MiracleBoot-DriverInjection.ps1](../HELPER%20SCRIPTS/MiracleBoot-DriverInjection.ps1) - Detection and risk assessment
- [FUTURE_ENHANCEMENTS.md](./FUTURE_ENHANCEMENTS.md) - Planned driver improvements
- [RECOMMENDED_TOOLS_FEATURE.md](./RECOMMENDED_TOOLS_FEATURE.md) - Snappy Driver Installer details

---

**Status:** ✅ Complete and tested  
**Last Validation:** January 7, 2026  
**Compatibility:** Windows 10/11, WinPE/WinRE
