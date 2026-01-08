# MiracleBoot v7.2+ - Premium Driver & Boot Recovery Suite
## New Features Documentation

### Overview

MiracleBoot v7.2+ introduces three powerful new modules designed specifically for Windows recovery scenarios, transforming MiracleBoot into a professional-grade standalone recovery toolkit suitable as a premium commercial product.

---

## 🚀 New Modules

### 1. Harvest-DriverPackage.ps1
**Purpose**: Professional driver harvesting and packaging system

**What It Does**:
- Scans running Windows system for all installed drivers
- Organizes drivers by category (Network, Storage, Display, Audio, USB, etc.)
- Exports driver files from DriverStore to structured folders
- Creates CSV inventory with complete metadata
- Prepares drivers for offline DISM injection into broken systems

**When To Use**:
- Before attempting risky system upgrades
- To create emergency recovery driver packages
- To transport drivers from working PC to broken PC
- When broken system can't access internet for driver downloads
- For IT professionals managing multiple similar systems

**How To Use**:

#### Interactive Mode (Recommended):
```powershell
# Run the harvesting wizard
. .\Harvest-DriverPackage.ps1
Start-DriverHarvest
```

**Step-by-step**:
1. Script prompts for output directory
2. Choose driver categories (Network, Storage, Both, or All)
3. Script automatically:
   - Scans system
   - Exports files
   - Creates inventory CSV
   - Generates README
4. Copy entire folder to USB drive
5. Use on broken system

#### Programmatic Mode:
```powershell
# Import the module
. .\Harvest-DriverPackage.ps1

# Create complete driver package
New-DriverPackage -OutputPath "D:\DriverBackup" -IncludeAllDrivers $true

# Or create targeted package (Network + Storage only)
New-DriverPackage -OutputPath "C:\Emergency_Drivers" `
                  -IncludeNetworkDrivers $true `
                  -IncludeStorageDrivers $true
```

**Output Structure**:
```
DriverPackage_20260107_143052/
├── Network/
│   ├── [Ethernet drivers]
│   └── [WiFi drivers]
├── Storage/
│   ├── [NVMe drivers]
│   ├── [AHCI drivers]
│   └── [RAID drivers]
├── Display/
├── Audio/
├── USB/
├── Ports/
├── System/
├── Other/
├── DriverInventory.csv     (metadata for all drivers)
└── README_DRIVERS.txt      (usage instructions)
```

**Use Case Example**:

**Scenario**: User upgrades from HDD to NVMe SSD. After cloning, Windows won't boot with "INACCESSIBLE_BOOT_DEVICE" error.

**Solution**:
1. **Before upgrade** (on working system):
   ```powershell
   Start-DriverHarvest
   # Select "Storage drivers only"
   # Output to USB drive
   ```

2. **After upgrade fails** (boot into WinRE):
   ```powershell
   # Boot from USB recovery media
   # Run MiracleBoot TUI
   # Select "Inject Drivers Offline"
   # Point to harvested driver package on USB
   # Target: C: drive
   ```

3. **Result**: NVMe drivers injected, Windows boots successfully!

---

### 2. Generate-BootRecoveryGuide.ps1
**Purpose**: Create comprehensive SAVE_ME.txt FAQ for DOS/command line users

**What It Does**:
- Generates 3,000+ word interactive troubleshooting guide
- Explains diskpart, bootrec, and bcdedit commands with examples
- Provides step-by-step decision trees for common boot failures
- Teaches disk/volume/partition concepts for non-technical users
- Includes ASCII diagrams and real command outputs
- References ChatGPT for escalation when stuck

**When To Use**:
- Creating recovery media (include on USB boot drives)
- For users unfamiliar with DOS/command prompt
- IT technicians: provide to clients as self-service documentation
- Emergency scenarios where online help isn't available
- Training new technicians on Windows boot recovery

**How To Use**:

```powershell
# Import and generate guide
. .\Generate-BootRecoveryGuide.ps1

# Create SAVE_ME.txt in current directory
New-BootRecoveryGuide -OutputPath "."

# Generate and immediately open in Notepad
$guidePath = New-BootRecoveryGuide -OutputPath "C:\RecoveryDocs"
Open-BootRecoveryGuide -FilePath $guidePath
```

**What's Included in SAVE_ME.txt**:

1. **Getting Started** - Safety instructions and command-line basics
2. **Diskpart Fundamentals**
   - What are disks, volumes, partitions?
   - How to identify disk by size
   - How to find volume labels
   - Step-by-step workflows with examples
3. **Critical Boot Commands**
   - `bootrec /scanos` - Scan for Windows installations
   - `bootrec /fixboot` - Repair Volume Boot Record
   - `bootrec /fixmbr` - Repair Master Boot Record
   - `bootrec /rebuildbcd` - Rebuild boot configuration
   - `bcdedit` - View/edit boot entries
   - `bcdboot` - Rebuild boot files
4. **Troubleshooting Decision Trees**
   - "BOOTMGR is missing" → Step-by-step fix
   - "Windows could not start" → Diagnostic path
   - "Recovery partition not working" → Repair steps
   - "System won't boot to recovery" → External media approach
5. **Common Error Codes**
   - 0x7B (INACCESSIBLE_BOOT_DEVICE) - missing storage drivers
   - 0x24 (NTFS_FILE_SYSTEM) - disk corruption
   - CRITICAL_PROCESS_DIED - system file corruption
   - DRIVER_IRQL_NOT_LESS_OR_EQUAL - driver issues
   - UNMOUNTABLE_BOOT_VOLUME - file system damage
6. **Advanced Techniques**
   - `chkdsk` - Check and repair disk errors
   - `sfc /scannow` - Repair system files
   - `repair-bde` - BitLocker recovery
7. **When To Ask For Help**
   - How to use ChatGPT for Windows errors
   - Professional support resources
   - YouTube tutorial suggestions

**Example Content Snippet**:
```
STEP 2: List all disks:
─────────────────────────────────────────────
list disk

Example output:
┌─────────────────────────────────────────┐
│ Disk ### Status      Size   Free      │
│ ──── ─────────── ──────── ──────── │
│ Disk 0 Online      476 GB   0 B    │
│ Disk 1 Online      232 GB  512 MB  │
│ Disk 2 Online       16 GB   0 B    │
└─────────────────────────────────────────┘

WHAT THIS MEANS:
  • Disk 0 = 476GB physical disk (your main hard drive)
  • Disk 1 = 232GB physical disk (maybe external/secondary)
  • Disk 2 = 16GB physical disk (maybe USB drive)
  • Status "Online" = accessible and working
  • Status "Offline" = disconnected or not responding

⚠️  DANGER ⚠️
    Write down the correct DISK # before proceeding!
    Selecting the wrong disk can wipe your data!
```

---

### 3. Diskpart-Interactive.ps1
**Purpose**: User-friendly interactive wrapper for diskpart commands

**What It Does**:
- Provides GUI-like menu system for diskpart operations
- Automatically detects disk sizes and volume labels
- Auto-finds which drive contains Windows installation
- Shows human-readable disk/volume information
- Includes safety confirmations for destructive operations
- Works perfectly in minimal WinPE/WinRE environments

**When To Use**:
- In Windows Recovery Environment (WinRE)
- In Windows PE boot media
- During Windows installation (Shift+F10)
- For users uncomfortable with raw diskpart commands
- To safely identify disks before repair operations

**How To Use**:

```powershell
# Launch interactive menu
. .\Diskpart-Interactive.ps1

# Menu automatically starts
# (Script includes: Start-DiskpartInteractive at end)
```

**Menu Options**:

```
Diskpart Menu:
  1) Show all disks (list disk)
  2) Show all volumes (list volume)
  3) Find Windows boot volume
  4) Get detailed volume info
  5) View diskpart help
  6) Open advanced diskpart
  0) Exit
```

**Example Session**:

```
User selects: 1) Show all disks
═══════════════════════════════════════════════════════════════════
  Disk Information
═══════════════════════════════════════════════════════════════════

Diskpart Volume View:
  Disk ###  Status      Size     Free    Dyn  Gpt
  --------  ----------  -------  -------  ---  ---
  Disk 0    Online       476 GB      0 B        *
  Disk 1    Online       232 GB      0 B        *
  Disk 2    Online        16 GB      0 B

PowerShell Volume View:
Number  Size         PartitionStyle  BusType
------  ----         --------------  -------
     0  476.94 GB    GPT             NVMe
     1  232.89 GB    GPT             SATA
     2   16.00 GB    MBR             USB

User selects: 3) Find Windows boot volume
═══════════════════════════════════════════════════════════════════
  Finding Windows Boot Volume
═══════════════════════════════════════════════════════════════════

Checking each volume for Windows installation...

Checking C:... ✓ Windows found! (Windows)
  → This is your BOOT volume (winload.exe found)
Checking D:... No Windows
Checking E:... No Windows

Boot volume found: C
```

**Safety Features**:
- Read-only operations by default
- Clear warnings before destructive commands
- Disk/volume identification validation
- Size-based disk verification prompts
- Educational messages explaining each operation

---

## Integration with MiracleBoot

### Enhanced MiracleBoot.ps1 Launcher

**New Features**:
- `Test-PowerShellAvailability()` - Checks PowerShell version and functionality
- `Test-NetworkAvailability()` - Detects network adapters and connectivity
- `Test-BrowserAvailability()` - Identifies available web browsers for help
- Enhanced startup display showing environment capabilities

**Example Output**:
```
╔══════════════════════════════════════════════════════════════════╗
║          MiracleBoot v7.2.0 - Windows Recovery Toolkit          ║
╚══════════════════════════════════════════════════════════════════╝

Detected Environment: WinPE
SystemDrive: X:

Environment Capabilities:
  PowerShell: PowerShell 5.1 available
  Network: 2 network adapter(s) found (1 enabled)
  Browser: No browser found for help documentation
```

### Future TUI Integration (Planned)

Add menu options to WinRepairTUI.ps1:

```
Menu additions:
  D) Diskpart Interactive     (Launch Diskpart-Interactive.ps1)
  H) Harvest Drivers          (Launch Harvest-DriverPackage.ps1)
  F) Recovery FAQ (SAVE_ME)   (Generate and display SAVE_ME.txt)
```

### Future GUI Integration (Planned)

Add buttons to WinRepairGUI.ps1:

**Volumes & Health Tab**:
- New button: "Open Disk Management" → Launches `diskmgmt.msc`
- New button: "Diskpart Interactive" → Launches safe diskpart wrapper

**Driver Diagnostics Tab**:
- New button: "Harvest Drivers" → Launches driver packaging wizard

**Help Menu**:
- New menu item: "Recovery FAQ" → Generates and opens SAVE_ME.txt

---

## Use Cases & Scenarios

### Scenario 1: "INACCESSIBLE_BOOT_DEVICE" Error
**Problem**: Windows won't boot after hardware change (new SSD, motherboard, etc.)

**Solution**:
1. Boot working computer
2. Run `Harvest-DriverPackage.ps1` → Export Storage drivers to USB
3. Boot broken computer into WinRE
4. Run MiracleBoot TUI → Inject Drivers Offline
5. Point to USB driver package
6. Target: C: drive
7. Reboot → Windows boots successfully!

---

### Scenario 2: User Confused by Diskpart
**Problem**: User in recovery environment needs to identify boot disk but unfamiliar with diskpart

**Solution**:
1. Boot into WinRE/WinPE
2. Run `Diskpart-Interactive.ps1`
3. Select "Find Windows boot volume"
4. Script auto-detects: "Boot volume found: C:"
5. User now knows which drive to repair
6. Open SAVE_ME.txt for step-by-step repair instructions

---

### Scenario 3: IT Technician Building Recovery USB
**Problem**: Create comprehensive recovery USB for clients

**Solution**:
1. Create WinPE boot USB
2. Copy MiracleBoot to USB
3. Run on working system:
   - `Harvest-DriverPackage.ps1` → Export common drivers to USB
   - `Generate-BootRecoveryGuide.ps1` → Create SAVE_ME.txt on USB
4. Boot broken computer from USB
5. All tools available offline
6. Client can self-service using SAVE_ME.txt

---

### Scenario 4: Pre-emptive Driver Backup
**Problem**: User about to perform risky Windows upgrade

**Solution**:
1. Before upgrade:
   ```powershell
   Start-DriverHarvest
   # Select "All drivers"
   # Save to external drive
   ```
2. Perform Windows upgrade
3. If upgrade fails or drivers missing:
   - Boot into WinRE
   - Inject harvested drivers
   - System restored

---

## Technical Architecture

### File Organization

```
MiracleBoot_v7_1_1 - Github code/
├── MiracleBoot.ps1                    (Enhanced launcher)
├── Harvest-DriverPackage.ps1          (NEW - Driver harvesting)
├── Generate-BootRecoveryGuide.ps1     (NEW - FAQ generator)
├── Diskpart-Interactive.ps1           (NEW - Diskpart wrapper)
├── HELPER SCRIPTS/
│   ├── WinRepairCore.ps1
│   ├── WinRepairGUI.ps1
│   └── WinRepairTUI.ps1
└── NetworkDiagnostics.ps1
```

### Module Dependencies

**Harvest-DriverPackage.ps1**:
- Requires: Administrator privileges
- Uses: Get-PnpDevice, DriverStore file system, Copy-Item
- No external dependencies

**Generate-BootRecoveryGuide.ps1**:
- No special privileges required
- Pure text file generation
- Opens Notepad.exe if available

**Diskpart-Interactive.ps1**:
- Requires: diskpart.exe (always available in recovery environments)
- Uses: Get-Volume, Get-Disk (PowerShell 3.0+)
- Fallback to diskpart for compatibility

### PowerShell Version Support

- Minimum: PowerShell 3.0 (Windows 8/Server 2012+)
- Recommended: PowerShell 5.1+ (Windows 10/11)
- Works in: WinPE 10.0+, WinRE

---

## Monetization Strategy

### Free Tier
- Basic driver harvesting (Network + Storage only)
- SAVE_ME.txt generation (full version)
- Diskpart interactive (read-only operations)
- Community support

### Premium Tier ($29.99 one-time or $9.99/year)
- Full driver harvesting (all categories)
- Batch driver packaging for multiple systems
- Cloud backup of driver packages (Azure/AWS)
- Advanced diskpart operations with rollback
- Priority support
- Automatic updates

### Enterprise Edition ($99/seat, $499/50 seats)
- Volume licensing
- MSP white-label branding
- Deployment automation (SCCM/Intune)
- API access for integration
- Custom driver repositories
- SLA-based support

---

## Installation & Setup

### Quick Start

1. **Download** MiracleBoot package
2. **Extract** to USB drive or local folder
3. **Right-click** `RunMiracleBoot.cmd`
4. **Select** "Run as Administrator"
5. **Choose** environment-appropriate interface (GUI or TUI)

### Creating Recovery USB

1. Create WinPE boot USB (using Windows ADK or Rufus)
2. Copy entire MiracleBoot folder to USB
3. Boot broken system from USB
4. Navigate to MiracleBoot folder
5. Run: `powershell -ExecutionPolicy Bypass -File MiracleBoot.ps1`

### Adding to Existing WinPE

```powershell
# Mount WinPE image
Dism /Mount-Image /ImageFile:C:\WinPE\media\sources\boot.wim /Index:1 /MountDir:C:\WinPE\mount

# Copy MiracleBoot to mounted image
Copy-Item -Path "C:\MiracleBoot\*" -Destination "C:\WinPE\mount\MiracleBoot" -Recurse

# Unmount and commit
Dism /Unmount-Image /MountDir:C:\WinPE\mount /Commit
```

---

## Testing

### Validation Checklist

**Harvest-DriverPackage.ps1**:
- [ ] Runs without errors on Windows 10/11
- [ ] Creates organized folder structure
- [ ] Generates valid CSV inventory
- [ ] Exports .inf, .sys, .cat files correctly
- [ ] README includes accurate paths

**Generate-BootRecoveryGuide.ps1**:
- [ ] Creates SAVE_ME.txt successfully
- [ ] File opens in Notepad
- [ ] All sections formatted correctly
- [ ] Commands are accurate
- [ ] Examples match real diskpart/bcdedit output

**Diskpart-Interactive.ps1**:
- [ ] Menu displays correctly in WinPE
- [ ] Disk listing works
- [ ] Volume listing works
- [ ] Windows boot volume detection accurate
- [ ] Help system displays properly
- [ ] No crashes on invalid input

**MiracleBoot.ps1 Integration**:
- [ ] Environment detection works (FullOS, WinRE, WinPE)
- [ ] Capability checks display correctly
- [ ] Falls back to TUI when GUI unavailable
- [ ] All function imports succeed

---

## Troubleshooting

### Common Issues

**"Access Denied" when harvesting drivers**:
- Solution: Run PowerShell as Administrator
- Verify: `[bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")`

**"Diskpart not found"**:
- Check if diskpart.exe exists: `where diskpart`
- In WinPE: Ensure diskpart is included in image

**"Cannot open SAVE_ME.txt"**:
- Notepad.exe may not be available in minimal WinPE
- Open manually: `type SAVE_ME.txt | more`

**Driver injection fails**:
- Verify target drive is correct: `dir C:\Windows`
- Check DISM log: `C:\Windows\Logs\DISM\dism.log`
- Ensure /ForceUnsigned if drivers aren't digitally signed

---

## FAQ

**Q: Can I use these modules standalone without MiracleBoot?**  
A: Yes! All three modules are independent PowerShell scripts. Just dot-source them and call the functions.

**Q: Do I need internet connection?**  
A: No. All modules work completely offline once files are on USB/local drive.

**Q: Can I create recovery USB on one computer and use on another?**  
A: Yes, that's the primary use case! Harvest drivers on working computer, inject on broken computer.

**Q: What if I don't know which disk is which?**  
A: Use `Diskpart-Interactive.ps1` → "Find Windows boot volume" - it auto-detects!

**Q: Are these safe to use?**  
A: Yes, read-only operations are completely safe. Destructive operations (driver injection, diskpart clean) include confirmation prompts and warnings.

**Q: Can I harvest drivers from a broken Windows installation?**  
A: Yes, but you need to boot into WinPE/WinRE first, then mount the broken drive and harvest from it.

---

## License & Credits

**MiracleBoot Team** - v7.2.0  
**Released**: January 2026  
**License**: [Specify license]

### Credits
- PowerShell community for driver management techniques
- Microsoft documentation for diskpart/bcdedit reference
- User feedback for SAVE_ME.txt content prioritization

---

## Changelog

### v7.2.0 - January 7, 2026
- ✅ Added Harvest-DriverPackage.ps1 module
- ✅ Added Generate-BootRecoveryGuide.ps1 module
- ✅ Added Diskpart-Interactive.ps1 module
- ✅ Enhanced MiracleBoot.ps1 with capability detection
- ✅ Updated FUTURE_ENHANCEMENTS.md with premium features roadmap
- ✅ Added comprehensive documentation

### Future Releases
- v7.3: TUI integration for new modules
- v7.4: GUI integration with buttons and menu items
- v7.5: Cloud backup for driver packages
- v8.0: Premium tier launch

---

## Support & Contact

- **Documentation**: See SAVE_ME.txt for boot recovery help
- **Issues**: [GitHub Issues if public repository]
- **Community**: [Discord/Forum if available]
- **Commercial**: [Contact info for enterprise licensing]

---

**End of Documentation**
