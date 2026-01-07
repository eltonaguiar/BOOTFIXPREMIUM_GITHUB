<#
.SYNOPSIS
MiracleBoot Diskpart Interactive Wrapper
Provides user-friendly diskpart commands with safety confirmations and education.

.DESCRIPTION
This module wraps diskpart commands to help users:
- Safely identify their disks and volumes
- Execute diskpart operations with confirmation
- Understand what each operation does
- Avoid data loss through careful validation

.AUTHOR
MiracleBoot Team - v7.2.0

.VERSION
1.0 - January 2026
#>

function Get-DiskInformation {
    <#
    .SYNOPSIS
    Safely retrieves and displays disk information in an easy-to-read format.
    
    .OUTPUTS
    Formatted table of all disks with size and status
    #>
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Disk Information" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        $diskInfo = @()
        
        # Use diskpart via script
        $diskpartScript = @"
list disk
"@
        
        $output = $diskpartScript | diskpart
        
        # Parse diskpart output
        $lines = $output -split "`n"
        $inDiskSection = $false
        
        foreach ($line in $lines) {
            if ($line -match '^\s*Disk\s+###') {
                $inDiskSection = $true
                continue
            }
            
            if ($inDiskSection -and $line -match '^\s*Disk\s+(\d+)') {
                Write-Host $line -ForegroundColor Yellow
            } elseif ($inDiskSection -and $line.Trim() -eq '') {
                break
            } elseif ($inDiskSection) {
                Write-Host $line -ForegroundColor Gray
            }
        }
        
        # Alternative: Use Get-Disk for PowerShell
        Write-Host ""
        Write-Host "Alternative view (PowerShell):" -ForegroundColor Cyan
        Get-Disk | Format-Table -Property Number, Size, PartitionStyle, BusType -AutoSize | Out-Host
        
    } catch {
        Write-Host "Error retrieving disk information: $_" -ForegroundColor Red
    }
}

function Get-VolumeInformation {
    <#
    .SYNOPSIS
    Displays detailed volume information for all partitions.
    
    .OUTPUTS
    Formatted table with drive letters, sizes, and file systems
    #>
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Volume Information" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Show volumes from diskpart
        $diskpartScript = @"
list volume
"@
        
        $output = $diskpartScript | diskpart
        $lines = $output -split "`n"
        
        Write-Host "Diskpart Volume View:" -ForegroundColor Yellow
        foreach ($line in $lines) {
            if ($line -match '^\s*Volume|^\s*Ltr|^\s*[0-9]|^\s*─') {
                Write-Host $line -ForegroundColor Gray
            }
        }
        
        # Show volumes from PowerShell for cleaner view
        Write-Host ""
        Write-Host "PowerShell Volume View:" -ForegroundColor Yellow
        Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystem, Size, SizeRemaining | 
            Format-Table @{
                Expression = { $_.DriveLetter + ':' }
                Label = 'Drive'
                Width = 6
            },
            @{
                Expression = { $_.FileSystemLabel }
                Label = 'Label'
                Width = 20
            },
            @{
                Expression = { $_.FileSystem }
                Label = 'Type'
                Width = 8
            },
            @{
                Expression = { "{0:N0} GB" -f ($_.Size / 1GB) }
                Label = 'Size'
                Width = 12
            },
            @{
                Expression = { "{0:N0} GB" -f ($_.SizeRemaining / 1GB) }
                Label = 'Free'
                Width = 12
            } -AutoSize
        
    } catch {
        Write-Host "Error retrieving volume information: $_" -ForegroundColor Red
    }
}

function Find-WindowsBootVolume {
    <#
    .SYNOPSIS
    Identifies which volume contains the Windows boot files.
    
    .OUTPUTS
    Drive letter of boot volume
    #>
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Finding Windows Boot Volume" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Checking each volume for Windows installation..." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        # Check for Windows directory on each drive
        $volumes = Get-Volume | Where-Object { $_.DriveLetter }
        
        foreach ($volume in $volumes) {
            $driveLetter = $volume.DriveLetter
            $windowsPath = "${driveLetter}:\Windows"
            $systemPath = "${driveLetter}:\Windows\System32"
            
            Write-Host "Checking ${driveLetter}:... " -ForegroundColor Cyan -NoNewline
            
            if (Test-Path $windowsPath -ErrorAction SilentlyContinue) {
                $label = if ($volume.FileSystemLabel) { " ($($volume.FileSystemLabel))" } else { "" }
                Write-Host "✓ Windows found!$label" -ForegroundColor Green
                
                # Check if this is boot volume
                if (Test-Path "$systemPath\winload.exe" -ErrorAction SilentlyContinue) {
                    Write-Host "  → This is your BOOT volume (winload.exe found)" -ForegroundColor Green
                    return $driveLetter
                }
            } else {
                Write-Host "No Windows" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        Write-Host "⚠️  Could not find Windows boot volume" -ForegroundColor Yellow
        
    } catch {
        Write-Host "Error searching for Windows: $_" -ForegroundColor Red
    }
}

function Show-DiskpartHelp {
    <#
    .SYNOPSIS
    Displays help information about common diskpart operations.
    #>
    $helpText = @"
╔════════════════════════════════════════════════════════════════════════════════╗
║                       DISKPART SAFETY GUIDE                                    ║
╚════════════════════════════════════════════════════════════════════════════════╝

WHAT IS DISKPART?
  Diskpart is a tool for managing disks and volumes from command line.
  Think of it as "Disk Management" but with text commands.

KEY CONCEPTS:
  • Disk = Physical hard drive (Disk 0, Disk 1, etc.)
  • Volume = A partition with a drive letter (C:, D:, E:, etc.)
  • Partition = A section of a disk

BASIC WORKFLOW:
  1. List disks to find the one you need
  2. Select the disk
  3. List volumes on that disk
  4. Get details about specific volumes

COMMANDS YOU'LL USE:

  list disk              → Shows all physical disks
  select disk X          → Pick which disk to work with (X = number)
  list volume            → Shows all volumes/partitions
  select volume X        → Pick which partition (X = number)
  detail volume          → Show detailed info about selected volume
  clean                  → DESTRUCTIVE: Erase entire disk! (careful!)
  create partition       → DESTRUCTIVE: Create new partition

SAFETY RULES:
  ✓ Always "list disk" first to verify disk numbers
  ✓ Double-check disk size to make sure you have the right one
  ✓ Read all prompts carefully before pressing Enter
  ⚠️  NEVER use "clean" or "create partition" unless you absolutely know what you're doing

NEED HELP?
  Type "help" inside diskpart for more commands
  Type "help COMMAND" for help on specific command

FOR DETAILED TUTORIAL:
  See SAVE_ME.txt section: "Understanding Your Disks (Diskpart Basics)"

"@
    
    Write-Host $helpText
}

function Test-DiskpartSafely {
    <#
    .SYNOPSIS
    Test diskpart with safe read-only operations.
    #>
    Write-Host ""
    Write-Host "Testing diskpart availability..." -ForegroundColor Cyan
    
    try {
        # Test with simple list disk command
        $test = "list disk" | diskpart 2>&1
        
        if ($test -match "Disk ###" -or $test -match "Number|Status|Size") {
            Write-Host "✓ Diskpart is working correctly" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️  Diskpart may not be working properly" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "✗ Diskpart failed: $_" -ForegroundColor Red
        return $false
    }
}

function Start-DiskpartInteractive {
    <#
    .SYNOPSIS
    Launch interactive diskpart menu for safe disk operations.
    #>
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          MiracleBoot - Diskpart Interactive Menu                              ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    # Test diskpart first
    if (-not (Test-DiskpartSafely)) {
        Write-Host "Diskpart is not available or not working." -ForegroundColor Red
        Write-Host "This tool requires Windows Recovery Environment or Command Prompt." -ForegroundColor Yellow
        return
    }
    
    $running = $true
    while ($running) {
        Write-Host ""
        Write-Host "Diskpart Menu:" -ForegroundColor Cyan
        Write-Host "  1) Show all disks (list disk)" -ForegroundColor White
        Write-Host "  2) Show all volumes (list volume)" -ForegroundColor White
        Write-Host "  3) Find Windows boot volume" -ForegroundColor White
        Write-Host "  4) Get detailed volume info" -ForegroundColor White
        Write-Host "  5) View diskpart help" -ForegroundColor White
        Write-Host "  6) Open advanced diskpart" -ForegroundColor White
        Write-Host "  0) Exit" -ForegroundColor White
        Write-Host ""
        
        $choice = Read-Host "Enter choice (0-6)"
        
        switch ($choice) {
            '1' {
                Get-DiskInformation
            }
            '2' {
                Get-VolumeInformation
            }
            '3' {
                $bootVol = Find-WindowsBootVolume
                if ($bootVol) {
                    Write-Host ""
                    Write-Host "Boot volume found: $bootVol" -ForegroundColor Green
                }
            }
            '4' {
                Write-Host ""
                Write-Host "Enter disk number to detail:" -ForegroundColor Cyan
                $diskNum = Read-Host
                
                $script = @"
select disk $diskNum
list volume
exit
"@
                Write-Host ""
                Write-Host $script | diskpart
            }
            '5' {
                Show-DiskpartHelp
            }
            '6' {
                Write-Host ""
                Write-Host "Opening interactive diskpart..." -ForegroundColor Yellow
                Write-Host "Type 'help' for available commands" -ForegroundColor Yellow
                Write-Host "Type 'exit' to return to menu" -ForegroundColor Yellow
                Write-Host ""
                & diskpart.exe
            }
            '0' {
                $running = $false
                Write-Host "Exiting diskpart menu." -ForegroundColor Green
            }
            default {
                Write-Host "Invalid choice" -ForegroundColor Red
            }
        }
    }
}

# Main entry point
Start-DiskpartInteractive
