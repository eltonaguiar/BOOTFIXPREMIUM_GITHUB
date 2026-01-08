<#
.SYNOPSIS
MiracleBoot Boot Recovery FAQ Generator
Creates a comprehensive SAVE_ME.txt guide with troubleshooting commands.

.DESCRIPTION
This module generates SAVE_ME.txt - a detailed FAQ guide covering:
- Diskpart basics and disk management
- BCDedit and boot configuration
- Bootrec recovery commands
- Common boot failure scenarios
- Step-by-step troubleshooting trees
- ChatGPT escalation guidance

.AUTHOR
MiracleBoot Team - v7.2.0

.VERSION
1.0 - January 2026
#>

function New-BootRecoveryGuide {
    <#
    .SYNOPSIS
    Generates comprehensive boot recovery FAQ file.
    
    .PARAMETER OutputPath
    Directory where SAVE_ME.txt will be created
    
    .OUTPUTS
    Path to generated SAVE_ME.txt file
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    $guidePath = Join-Path $OutputPath "SAVE_ME.txt"
    
    $content = @"
╔════════════════════════════════════════════════════════════════════════════════╗
║                   MIRACLE BOOT - BOOT RECOVERY FAQ                            ║
║                      "SAVE ME!" Troubleshooting Guide                          ║
║                              Version 1.0                                       ║
║                     Generated: $(Get-Date -Format 'MMMM d, yyyy HH:mm:ss')                           ║
╚════════════════════════════════════════════════════════════════════════════════╝

TABLE OF CONTENTS
═════════════════════════════════════════════════════════════════════════════════

1. Getting Started with This Guide
2. Understanding Your System Disks and Volumes (Diskpart Basics)
3. Critical Boot Recovery Commands (Bootrec & BCDedit)
4. Step-by-Step Troubleshooting Trees
5. Common Error Messages & Solutions
6. Advanced Techniques
7. When to Ask for Help


═════════════════════════════════════════════════════════════════════════════════
1. GETTING STARTED WITH THIS GUIDE
═════════════════════════════════════════════════════════════════════════════════

IMPORTANT: This guide is designed for users in Windows Recovery (WinRE), Windows
PE (WinPE), or Command Prompt during Windows Installation (Shift+F10).

If you're not comfortable with command-line interfaces, please:
  A) Use MiracleBoot GUI mode (if available)
  B) Refer to ChatGPT or professional support
  C) Contact Microsoft support

SAFE TYPING:
  - All commands are case-insensitive (DISKPART = diskpart)
  - Capitalization is for readability only
  - Follow commands EXACTLY as written
  - Typos can cause data loss!


═════════════════════════════════════════════════════════════════════════════════
2. UNDERSTANDING YOUR DISKS AND VOLUMES (DISKPART BASICS)
═════════════════════════════════════════════════════════════════════════════════

WHAT IS DISKPART?
  Diskpart is MS-DOS command-line tool that manages disks, partitions, and volumes.
  Think of it as "Disk Management" but as text commands instead of clicking buttons.

BASIC CONCEPT: Disks → Partitions/Volumes

  [Physical Disk]
       ↓
   [Partition 1] [Partition 2] [Partition 3]
   (C: drive)     (D: drive)    (Recovery)
   
TERMS YOU'LL SEE:
  • Disk          = Physical hard drive or SSD (Disk 0, Disk 1, etc.)
  • Partition     = Section of a disk with its own file system
  • Volume        = Partition that's been formatted and assigned a letter (C:, D:, etc.)
  • GPT           = Modern partition style (Windows 10/11, usually GPT)
  • MBR           = Legacy partition style (older systems)

THE DISKPART WORKFLOW:
  1. Open diskpart
  2. List all disks to identify which one is broken
  3. Select the disk you want to fix
  4. List volumes to see what's on it
  5. Get details about specific volumes
  6. Perform operations (clean, create partitions, etc.)

STEP-BY-STEP: DISKPART BASICS

  STEP 1: Open Diskpart (type in command prompt):
  ─────────────────────────────────────────────
  diskpart

  You'll see the prompt change to:
  DISKPART> _

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

  IDENTIFY YOUR DISK:
    • Check the SIZE column - it should match your drive size
    • For a 1TB drive, look for ~931 GB (1024 × 0.91 = 931)
    • For a 512GB drive, look for ~465 GB

  ⚠️  DANGER ⚠️
      Write down the correct DISK # before proceeding!
      Selecting the wrong disk can wipe your data!

  STEP 3: Select the disk you want to work with:
  ─────────────────────────────────────────────
  select disk 0

  Confirmation: "Disk 0 is now the selected disk."

  STEP 4: List volumes on this disk:
  ─────────────────────────────────────────────
  list volume

  Example output:
  ┌──────────────────────────────────────────────────────┐
  │ Volume ### Ltr Label        Fs    Type   Size Status │
  │ ──────── ─── ──────────── ───────── ────── ────── │
  │ Volume 0  C   Windows      NTFS   Simple  476 GB Healthy
  │ Volume 1      Recovery     NTFS   Simple   16 GB Healthy
  │ Volume 2  D                NTFS   Simple  100 GB  Healthy
  └──────────────────────────────────────────────────────┘

  WHAT THIS MEANS:
    • Volume 0 = C: drive (Windows installed here)
    • Volume 1 = Recovery partition (hidden, no letter)
    • Volume 2 = D: drive (secondary volume)
    • "Healthy" = working properly
    • "NTFS" = file system type
    • "Simple" = not part of a RAID array

  LABEL HELPS IDENTIFY:
    • "Windows" label usually = OS drive
    • "Recovery" label = Windows Recovery partition
    • Blank label = secondary drives, sometimes corrupted

  STEP 5: Get details about a specific volume:
  ─────────────────────────────────────────────
  select volume 0        (selects C: drive)
  detail volume

  You'll see detailed information:
    Volume Name: Windows
    Volume Number: 0
    Drive Letter: C
    Boot Volume: Yes
    System Volume: Yes
    File System: NTFS
    Size: 476 GB

  "Boot Volume: Yes" means this drive contains the boot files!

  STEP 6: Exit diskpart:
  ─────────────────────────────────────────────
  exit


MOST COMMON DISKPART SCENARIOS:

  Scenario A: Find which drive has Windows
  ─────────────────────────────────────────
  diskpart
  list disk
    [look for appropriate size: 237GB, 476GB, 1TB, etc.]
  select disk X          [replace X with disk number]
  list volume
    [look for "Boot Volume: Yes"]
  detail volume          [confirms this is your Windows drive]
  exit

  Scenario B: See how much free space a volume has
  ──────────────────────────────────────────────────
  diskpart
  list volume
  select volume X        [replace X with volume number]
  detail volume
    [look for "Free Space" line]
  exit

  Scenario C: Check if a drive is GPT or MBR
  ────────────────────────────────────────────
  diskpart
  list disk
  select disk X
  detail disk
    [look for "Partition Style: GUID Partition Table" (GPT)
              or "Partition Style: MBR" (MBR)]
  exit


═════════════════════════════════════════════════════════════════════════════════
3. CRITICAL BOOT RECOVERY COMMANDS
═════════════════════════════════════════════════════════════════════════════════

The following commands are the "nuclear options" for fixing Windows that won't boot.
Use these in Command Prompt in Windows Recovery Environment (WinRE).

WARNING: These commands modify your boot configuration!
         Always back up your BCD first:
         bcdedit /export C:\BCD_Backup

═ COMMAND SET A: AUTOMATIC REPAIR COMMANDS ═════════════════════════════════════

These commands let Windows try to fix itself:

COMMAND: bootrec /scanos
─────────────────────────────────────
WHAT IT DOES: Scans for all Windows installations on connected drives

WHEN TO USE: First step when Windows won't boot
             Finds all Windows copies and shows their locations

EXAMPLE OUTPUT:
  Scanning all drives for Windows installations...
  Found Windows installation: C:\Windows
  Found Windows installation: D:\Windows
  Total: 2 installations found

HOW TO RUN:
  bootrec /scanos

WHAT HAPPENS NEXT:
  If Windows found:
    → Windows attempts automatic repair
  If not found:
    → May indicate drive letter issue or severe corruption


COMMAND: bootrec /fixboot
───────────────────────────────
WHAT IT DOES: Repairs the Volume Boot Record (VBR) - the first sector of your boot
              drive that tells the computer where to find Windows

WHEN TO USE: After scanos fails
             When you get "BOOTMGR is missing" errors
             When boot sector is corrupted

EXAMPLE OUTPUT:
  The operation completed successfully.

HOW TO RUN:
  bootrec /fixboot

WHAT HAPPENS NEXT:
  If successful: "The operation completed successfully"
  Then reboot and test if Windows boots


COMMAND: bootrec /fixmbr
──────────────────────────
WHAT IT DOES: Repairs Master Boot Record (MBR) - old-style boot configuration
              (only for legacy/BIOS systems, not UEFI)

WHEN TO USE: Only if you have BIOS/MBR system (rare in modern computers)
             When you get "Invalid partition table" errors

HOW TO RUN:
  bootrec /fixmbr

WARNING: This only works on MBR (legacy) systems!
         UEFI/GPT systems will ignore this command


COMMAND: bootrec /rebuildbcd
──────────────────────────────
WHAT IT DOES: Scans all drives and rebuilds the entire Boot Configuration Data
              (BCD) store from scratch

WHEN TO USE: Last resort when /scanos and /fixboot fail
             When BCD is severely corrupted
             When Windows can't find any boot entries

HOW TO RUN:
  bootrec /rebuildbcd

WHAT HAPPENS:
  Step 1: Windows scans all drives
  Step 2: It asks for confirmation for each Windows installation found
    Scan found Windows installation:
    Windows 11
    Add installation to boot list? (Y/N) → Type Y
  Step 3: Rebuilds boot menu from scratch

CAUTION: This can take 5+ minutes on large drives!


═ COMMAND SET B: MANUAL BCD EDITING ════════════════════════════════════════════

These commands let you manually inspect and edit boot configuration:

COMMAND: bcdedit
──────────────────
WHAT IT DOES: Shows all your boot menu entries and their settings

WHEN TO USE: To see what Windows thinks should boot
             To diagnose missing or corrupt entries
             First step for BCD investigation

EXAMPLE OUTPUT:
  Windows Boot Manager
  ────────────────────────────────────────────
  identifier             {bootmgr}
  device                 partition=C:
  description            Windows Boot Manager
  locale                 en-US
  inherit                {globalsettings}
  integrityservices      Enable
  default                {current}
  resumeobject           {resumeobject}
  displayorder           {current}
                        {5c03b9db-d8da-11ec-9e2d-c4270fa1c4f9}
  toolsdisplayorder      {memdiag}
  timeout                10

  Windows Boot Loader
  ────────────────────────────────────────────
  identifier             {current}
  device                 partition=C:
  path                   \Windows\system32\winload.exe
  description            Windows 11
  locale                 en-US
  inherit                {bootloadersettings}
  isolatedcontext        Yes
  allowedinmemdump       Yes
  osdevice               partition=C:
  systemroot             \Windows
  resumeobject           {resumeobject}
  nx                     OptIn
  bootmenupolicy         Standard

READING THIS OUTPUT:
  • "identifier" = unique ID for this entry
  • "description" = name shown in boot menu (e.g., "Windows 11")
  • "device" = which partition this boot entry uses
  • "path" = where bootloader is located
  • "timeout" = seconds before auto-selecting default (10 = 10 seconds)

HOW TO RUN:
  bcdedit

WHAT TO LOOK FOR:
  ✓ Do you see "Windows Boot Manager"? (Should be there)
  ✓ Do you see at least one "Windows Boot Loader"? (Should be there)
  ✗ Is device showing "partition=C:" or similar? (If blank = problem!)
  ✗ Is path blank instead of "\Windows\system32\winload.exe"? (Problem!)


COMMAND: bcdedit /set timeout 30
──────────────────────────────────
WHAT IT DOES: Changes boot menu timeout (how long before auto-boot)

WHEN TO USE: If boot menu appears for too short/too long
             Default is 10 seconds (might be too fast to read)

HOW TO RUN:
  bcdedit /set timeout 30     [Sets timeout to 30 seconds]
  bcdedit /set timeout 0      [Disables timeout, waits for user]

EXAMPLE OUTPUT:
  The operation completed successfully.


COMMAND: bcdedit /enum all
────────────────────────────
WHAT IT DOES: Shows ALL boot entries including hidden ones

WHEN TO USE: When you need detailed BCD information
             To see all recovery/safe mode entries

HOW TO RUN:
  bcdedit /enum all


═ COMMAND SET C: EMERGENCY REPAIR COMMANDS ════════════════════════════════════

For severe corruption:

COMMAND: Rebuild Boot Files
───────────────────────────
If Windows files are missing, copy them from another source:

  bcdboot C:\Windows /s C: /f UEFI
  [Rebuilds boot files for UEFI system]

  bcdboot C:\Windows /s C: /f BIOS
  [Rebuilds boot files for legacy BIOS system]

NOTE: BIOS is for MBR/legacy systems (rare)
      UEFI is for modern systems (Windows 10/11)


═════════════════════════════════════════════════════════════════════════════════
4. TROUBLESHOOTING DECISION TREES
═════════════════════════════════════════════════════════════════════════════════

USE THIS SECTION: Start here with your specific problem!

TREE A: "BOOTMGR is missing"
─────────────────────────────────────────────────────────────────────────────────

  ┌─ What is BOOTMGR?
  │  It's the boot manager file that starts Windows.
  │  Location: System Reserved partition or C: drive
  │
  ├─ Step 1: Try automatic repair (SAFE)
  │  bootrec /scanos
  │  bootrec /fixboot
  │  Reboot and test
  │
  ├─ Did it work? ──→ YES → You're done!
  │ │ └─→ NO → Continue
  │ │
  │ └─ Step 2: Rebuild boot files
  │    bcdboot C:\Windows /s C: /f UEFI
  │    Reboot and test
  │
  └─ Still not working?
     • The Windows installation might be corrupt
     • Try in-place upgrade/repair: "FUTURE_ENHANCEMENTS.md"
     • Ask for help (see Section 7)


TREE B: "Windows could not start" / Blue Screen
────────────────────────────────────────────────────────────────────────────────

  ┌─ Possible causes: Missing drivers, corrupt system files, hardware failure
  │
  ├─ Step 1: Check BCD entries
  │  bcdedit
  │  Look for errors in output (blank fields, strange paths)
  │
  ├─ Step 2: Repair boot loader
  │  bootrec /fixboot
  │
  ├─ Step 3: Inject missing drivers (if you have them)
  │  Use MiracleBoot GUI → "Driver Diagnostics" tab
  │  Or TUI → "Inject Drivers Offline"
  │
  └─ If still failing:
     • Likely missing storage drivers (NVMe, RAID, USB)
     • Harvest drivers from working system
     • Inject using DISM: dism /Image:C: /Add-Driver /Driver:path /Recurse


TREE C: "Recovery partition not working"
────────────────────────────────────────────────────────────────────────────────

  ┌─ Check recovery partition health
  │  diskpart
  │  list volume
  │  [Look for "Recovery" or unlabeled small volume]
  │
  ├─ Repair recovery partition boot files
  │  bcdboot C:\Windows /s E: /f UEFI
  │  [Replace E: with recovery partition letter]
  │
  └─ Verify it works:
     Reboot → Advanced Startup → Troubleshoot
     Should no longer show "Recovery Partition Error"


TREE D: "System won't boot, even to recovery"
──────────────────────────────────────────────────────────────────────────────

  ┌─ Boot from external media (USB/DVD)
  │  1. Have working computer create Windows PE USB
  │  2. Boot broken computer from USB
  │  3. Run MiracleBoot from USB
  │
  ├─ MiracleBoot will show you:
  │  • All attached drives
  │  • Windows installations found
  │  • Boot configuration status
  │  • Driver status
  │
  └─ Use MiracleBoot to repair from USB
     [See MiracleBoot documentation]


═════════════════════════════════════════════════════════════════════════════════
5. COMMON ERROR MESSAGES & SOLUTIONS
═════════════════════════════════════════════════════════════════════════════════

ERROR: INACCESSIBLE_BOOT_DEVICE (0x7B)
──────────────────────────────────────
WHAT HAPPENED: Windows can't access the boot drive (usually missing drivers)
ROOT CAUSE: Missing storage drivers (NVMe, RAID, USB 3.x)

FIX STEPS:
  1. Boot into WinRE or WinPE
  2. Determine if you have drivers available
     • From working system: Use Harvest-DriverPackage.ps1
     • From manufacturer website: Download storage drivers
  3. Inject drivers: Use MiracleBoot → "Inject Drivers Offline"
  4. Reboot and test


ERROR: CRITICAL_PROCESS_DIED
───────────────────────────────
WHAT HAPPENED: Critical Windows process crashed or missing
ROOT CAUSE: Usually corrupt system files or bad RAM

FIX STEPS:
  1. Boot into WinRE
  2. Run "Automatic Repair"
     Windows should attempt automatic repair on next boot
  3. If still fails, try in-place upgrade/repair


ERROR: DRIVER_IRQL_NOT_LESS_OR_EQUAL
─────────────────────────────────────
WHAT HAPPENED: Problem with a driver causing system crash
ROOT CAUSE: Usually storage or network driver issues

FIX STEPS:
  1. Boot into Safe Mode (if possible)
  2. Find the problematic driver using WinRepairCore diagnostics
  3. Either update or disable the driver
  4. Reboot


ERROR: UNMOUNTABLE_BOOT_VOLUME
───────────────────────────────
WHAT HAPPENED: Can't read the boot volume (file system corrupt)
ROOT CAUSE: Disk corruption or file system damage

FIX STEPS:
  1. Boot into WinRE
  2. Run automatic repair
  3. If fails, disk may need repair:
     chkdsk C: /F /R
     [/F = fix errors, /R = locate bad sectors]
  4. Reboot


═════════════════════════════════════════════════════════════════════════════════
6. ADVANCED TECHNIQUES
═════════════════════════════════════════════════════════════════════════════════
ADVANCED BOOT TROUBLESHOOTING (PHASED APPROACH)

Use the boot phase to choose the right fix. Identify where the boot process
stops, then apply the matching repair steps.

BOOT PHASES (HIGH-LEVEL)
  1) PreBoot (BIOS/UEFI firmware)
  2) Windows Boot Manager (bootmgr / bootmgfw.efi)
  3) Windows OS Loader (winload.exe / winload.efi)
  4) Windows Kernel (ntoskrnl.exe)

PHASE 1: PREBOOT (BIOS/UEFI)
  Symptoms:
    - No disk activity light, only BIOS logo, stuck at firmware screen
    - NumLock light does not toggle
  Actions:
    - Disconnect external devices (USB, docks, storage)
    - Check firmware diagnostics (if available)
    - Suspect hardware failure if disk is not detected

PHASE 2: BOOT MANAGER / BOOT LOADER
  Symptoms:
    - Black screen + blinking cursor
    - "BOOTMGR is missing", "Operating System not found"
    - BCD missing/corrupt, boot sector errors
  Actions:
    - Run Startup Repair (WinRE)
    - Bootrec sequence:
        bootrec /scanos
        bootrec /fixmbr
        bootrec /fixboot
        bootrec /rebuildbcd
    - If WinRE loops forever:
        bcdedit /set {default} recoveryenabled no
    - If F8 options do not appear:
        bcdedit /set {default} bootmenupolicy legacy
    - Startup Repair log:
        %windir%\System32\LogFiles\Srt\Srttrail.txt

PHASE 3: WINDOWS OS LOADER (WINLOAD)
  Symptoms:
    - Error mentioning winload.exe/winload.efi
    - Boot Manager starts, then fails loading Windows
  Actions:
    - Verify Windows folder exists on target drive
    - Inject missing storage drivers (offline DISM)
    - Run Startup Repair again after driver injection

PHASE 4: KERNEL (NTOSKRNL)
  Symptoms:
    - Stop error (blue screen) after Windows logo
    - Spinning dots forever, black screen after logo
  Actions:
    - Try Safe Mode or Last Known Good Configuration
    - Review Event Viewer (if Safe Mode works)
    - Clean boot (disable third-party services)
    - Offline SFC:
        sfc /scannow /offbootdir=C:\ /offwindir=C:\Windows
    - Check disk:
        chkdsk C: /F /R
    - Remove pending updates (WinRE):
        dism /image:C:\ /get-packages
        dism /image:C:\ /remove-package /packagename:NAME
        dism /image:C:\ /cleanup-image /revertpendingactions
      If pending.xml exists, rename it to pending.xml.old
    - Restore registry hives (use System Restore if RegBack is empty)
CHECKING DISK HEALTH

See if your disk has physical errors:

  chkdsk C: /F /R /X
  
  /F = fix errors found
  /R = locate and repair bad sectors
  /X = force dismount before running (needed for C: drive)

WARNING: Takes hours on large drives (don't interrupt!)

CHECKING SYSTEM FILES

Repair corrupt Windows system files:

  sfc /scannow
  [System File Checker - scans for corrupt files]

REPAIRING DISK CORRUPTION

More thorough scan than chkdsk:

  repair-bde C: -status
  [Check BitLocker recovery status]

For detailed help with any of these, ask ChatGPT:
  "How do I use 'chkdsk' to fix Windows?"
  "What does 'sfc /scannow' do?"


═════════════════════════════════════════════════════════════════════════════════
7. WHEN TO ASK FOR HELP
═════════════════════════════════════════════════════════════════════════════════

You're not alone! Here's where to get help:

OPTION 1: Use ChatGPT (FREE, 24/7)
─────────────────────────────────
Go to: https://chatgpt.com

Copy your error message and ask:
  "My computer shows error [ERROR MESSAGE] when booting.
   Here's what I tried: [WHAT YOU DID]
   What should I do next?"

ChatGPT is amazing at explaining Windows errors and commands!
It won't hurt anything because it's just giving advice.

Example questions ChatGPT can answer:
  • "What does 'BOOTMGR is missing' mean?"
  • "How do I use diskpart safely?"
  • "My computer shows blue screen 0x7B, help?"
  • "I'm getting 'driver not found', what do I do?"


OPTION 2: MiracleBoot Community & Support
───────────────────────────────────────────
Use MiracleBoot's built-in help:
  • GUI: Check "Utilities & Tools" → "Help & Documentation"
  • TUI: Select "Network & Internet Help"


OPTION 3: Professional Support
────────────────────────────────
If you're completely stuck or unsure:
  • Contact Microsoft Support
  • Visit certified computer repair shop
  • Use professional recovery service


OPTION 4: Self-Research (YouTube)
──────────────────────────────────
Search on YouTube:
  "How to fix Windows [YOUR ERROR] diskpart"
  "Windows [YOUR ERROR] step by step fix"


═════════════════════════════════════════════════════════════════════════════════
QUICK REFERENCE: COMMAND CHEAT SHEET
═════════════════════════════════════════════════════════════════════════════════

DISKPART COMMANDS:
  diskpart                    Start diskpart
  list disk                   Show all physical disks
  select disk X               Choose disk to work with
  list volume                 Show all volumes/partitions
  select volume X             Choose specific volume
  detail volume               Show detailed volume info
  exit                        Exit diskpart

BOOTREC COMMANDS:
  bootrec /scanos            Scan for Windows installations
  bootrec /fixboot           Repair volume boot record
  bootrec /fixmbr            Repair master boot record (MBR only)
  bootrec /rebuildbcd        Rebuild entire boot config

BCDEDIT COMMANDS:
  bcdedit                     Show current boot entries
  bcdedit /enum all          Show all boot entries including hidden
  bcdedit /set timeout 30    Change boot timeout to 30 seconds
  bcdedit /export file       Backup BCD to file
  bcdedit /import file       Restore BCD from backup

OTHER CRITICAL COMMANDS:
  bcdboot C:\Windows /s C: /f UEFI    Rebuild UEFI boot files
  chkdsk C: /F /R /X                  Check and repair disk
  sfc /scannow                        Repair system files


═════════════════════════════════════════════════════════════════════════════════

STILL STUCK? DON'T PANIC!

Windows is more resilient than you think. If your computer won't boot:

  1. You can still access your files from another computer
  2. Data can almost always be recovered
  3. Windows can usually be repaired with these tools
  4. If all else fails, reinstalling Windows keeps your data (with in-place upgrade)

The fact that you're reading this means you're already on the right path!
Keep going - you've got this.

═════════════════════════════════════════════════════════════════════════════════

For more information, visit:
  • MiracleBoot Project: (check documentation)
  • Microsoft Support: https://support.microsoft.com
  • ChatGPT Help: https://chatgpt.com

Last updated: $(Get-Date -Format 'MMMM d, yyyy')
MiracleBoot Team
"@
    
    $content | Out-File -FilePath $guidePath -Encoding UTF8 -Force
    
    Write-Host "SAVE_ME.txt created: $guidePath" -ForegroundColor Green
    return $guidePath
}

# Interactive function to open SAVE_ME.txt
function Open-BootRecoveryGuide {
    <#
    .SYNOPSIS
    Opens SAVE_ME.txt in Notepad for user reference.
    #>
    param(
        [string]$FilePath
    )
    
    if (Test-Path $FilePath) {
        try {
            & notepad.exe $FilePath
        } catch {
            Write-Host "Could not open Notepad. File location: $FilePath" -ForegroundColor Yellow
            Write-Host "You can open this file manually in Notepad." -ForegroundColor Yellow
        }
    } else {
        Write-Host "SAVE_ME.txt not found. Please generate it first." -ForegroundColor Red
    }
}


