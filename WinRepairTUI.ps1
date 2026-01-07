function Start-TUI {
    # Detect environment for display (matching main script logic)
    $envDisplay = "FullOS"
    
    if ($env:SystemDrive -eq 'X:') {
        # X: drive indicates WinPE/WinRE
        if (Test-Path 'HKLM:\System\Setup') {
            $setupType = (Get-ItemProperty -Path 'HKLM:\System\Setup' -Name 'CmdLine' -ErrorAction SilentlyContinue).CmdLine
            if ($setupType -match 'recovery|WinRE') {
                $envDisplay = "WinRE"
            } else {
                $envDisplay = "WinPE"
            }
        } elseif (Test-Path 'HKLM:\System\CurrentControlSet\Control\MiniNT') {
            $envDisplay = "WinPE"
        } else {
            $envDisplay = "WinRE"
        }
    } elseif ($env:SystemDrive -ne 'X:' -and (Test-Path "$env:SystemDrive\Windows")) {
        $envDisplay = "FullOS"
    }
    
    do {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  MIRACLE BOOT v7.2.0 - MS-DOS STYLE MODE" -ForegroundColor Cyan
        Write-Host "  Environment: $envDisplay" -ForegroundColor Gray
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1) List Windows Volumes (Sorted)" -ForegroundColor White
        Write-Host "2) Scan Storage Drivers (Detailed)" -ForegroundColor White
        Write-Host "3) Inject Drivers Offline (DISM)" -ForegroundColor White
        Write-Host "4) Quick View BCD" -ForegroundColor White
        Write-Host "5) Edit BCD Entry" -ForegroundColor White
        Write-Host "6) Recommended Recovery Tools" -ForegroundColor Green
        Write-Host "Q) Quit" -ForegroundColor Yellow
        Write-Host ""

        $c = Read-Host "Select"
        switch ($c) {
            "1" { 
                Write-Host "`nScanning volumes..." -ForegroundColor Gray
                Get-WindowsVolumes | Format-Table -AutoSize
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Write-Host "`nScanning for storage driver issues..." -ForegroundColor Gray
                Write-Host ""
                Write-Host (Get-MissingStorageDevices) -ForegroundColor Yellow
                $ans = Read-Host "`nAttempt to harvest drivers from a Windows drive? (Y/N)"
                if ($ans -eq 'Y' -or $ans -eq 'y') {
                    $src = Read-Host "Source drive (e.g. C)"
                    if ($src) {
                        Write-Host "Harvesting drivers from ${src}:..." -ForegroundColor Gray
                        Harvest-StorageDrivers "$($src):"
                        Write-Host "Loading drivers..." -ForegroundColor Gray
                        Load-Drivers-Live "X:\Harvested"
                        Write-Host "Drivers loaded. Press any key to continue..." -ForegroundColor Green
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                }
            }
            "3" {
                $win = Read-Host "Target Windows drive letter (e.g. C)"
                $path = Read-Host "Path to driver folder"
                if ($win -and $path) {
                    Write-Host "Injecting drivers into ${win}: using DISM..." -ForegroundColor Gray
                    Inject-Drivers-Offline $win $path
                    Write-Host "Driver injection complete. Press any key to continue..." -ForegroundColor Green
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            }
            "4" { 
                Write-Host "`nBCD Entries:" -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                bcdedit /enum
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "5" {
                Write-Host "`nCurrent BCD Entries:" -ForegroundColor Cyan
                bcdedit /enum | Select-String "identifier" | ForEach-Object { Write-Host $_.Line -ForegroundColor Gray }
                Write-Host ""
                $id = Read-Host "Enter BCD Identifier (GUID)"
                $name = Read-Host "Enter new description"
                if ($id -and $name) {
                    Set-BCDDescription $id $name
                    Write-Host "BCD entry updated successfully!" -ForegroundColor Green
                    Write-Host "Press any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            }
            "6" {
                Clear-Host
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "  RECOMMENDED RECOVERY & BACKUP TOOLS" -ForegroundColor Cyan
                Write-Host "  Current Environment: $envDisplay" -ForegroundColor Gray
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "A) Free Recovery Tools" -ForegroundColor Green
                Write-Host "B) Paid Recovery Tools" -ForegroundColor Yellow
                Write-Host "C) Backup Strategy Guide" -ForegroundColor Cyan
                Write-Host "D) Hardware Recommendations" -ForegroundColor Magenta
                Write-Host "R) Return to Main Menu" -ForegroundColor White
                Write-Host ""
                
                $toolChoice = Read-Host "Select"
                switch ($toolChoice.ToUpper()) {
                    "A" {
                        Clear-Host
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
                        Write-Host "  FREE RECOVERY TOOLS" -ForegroundColor Green
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
                        Write-Host ""
                        
                        Write-Host "1. VENTOY - Multi-Boot USB Solution" -ForegroundColor Cyan
                        Write-Host "   Website: https://www.ventoy.net" -ForegroundColor Gray
                        Write-Host "   • Create bootable USB with multiple ISOs" -ForegroundColor White
                        Write-Host "   • No need to reformat for each ISO" -ForegroundColor White
                        Write-Host "   • Supports Windows/Linux ISO files" -ForegroundColor White
                        Write-Host "   • Requirements: USB drive 8GB+ (will be formatted!)" -ForegroundColor Yellow
                        Write-Host "   • For WIM files, install WimBoot plugin:" -ForegroundColor Yellow
                        Write-Host "     https://www.ventoy.net/en/plugin_wimboot.html" -ForegroundColor Gray
                        Write-Host ""
                        
                        Write-Host "2. HIREN'S BOOTCD PE - Complete Toolkit" -ForegroundColor Cyan
                        Write-Host "   Website: https://www.hirensbootcd.org" -ForegroundColor Gray
                        Write-Host "   • Comprehensive Windows PE environment" -ForegroundColor White
                        Write-Host "   • Hundreds of recovery and diagnostic tools" -ForegroundColor White
                        Write-Host "   • Password reset, data recovery, diagnostics" -ForegroundColor White
                        Write-Host "   • Best for: Complete system rescue" -ForegroundColor Green
                        Write-Host ""
                        
                        Write-Host "3. MEDICAT USB - Medical-Grade Recovery" -ForegroundColor Cyan
                        Write-Host "   • Pre-configured Ventoy with curated tools" -ForegroundColor White
                        Write-Host "   • Optimized for Windows recovery" -ForegroundColor White
                        Write-Host "   • Search on GitHub or recovery forums" -ForegroundColor Gray
                        Write-Host ""
                        
                        Write-Host "4. SYSTEM RESCUE (Linux-based)" -ForegroundColor Cyan
                        Write-Host "   Website: https://www.system-rescue.org" -ForegroundColor Gray
                        Write-Host "   • Cross-platform recovery with Linux tools" -ForegroundColor White
                        Write-Host "   • Good for Linux/Windows dual-boot systems" -ForegroundColor White
                        Write-Host ""
                        
                        Write-Host "5. AOMEI PE BUILDER" -ForegroundColor Cyan
                        Write-Host "   Website: https://www.aomeitech.com" -ForegroundColor Gray
                        Write-Host "   • Create custom WinPE with AOMEI tools" -ForegroundColor White
                        Write-Host "   • Includes backup and partitioning tools" -ForegroundColor White
                        Write-Host ""
                        
                        Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor Gray
                        Write-Host "TIP: Use Ventoy to create one USB with multiple tools!" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "B" {
                        Clear-Host
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
                        Write-Host "  PAID RECOVERY TOOLS" -ForegroundColor Yellow
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
                        Write-Host ""
                        
                        Write-Host "1. MACRIUM REFLECT ⭐ RECOMMENDED" -ForegroundColor Green
                        Write-Host "   Website: https://www.macrium.com" -ForegroundColor Gray
                        Write-Host "   Free Edition: https://www.macrium.com/reflectfree" -ForegroundColor Cyan
                        Write-Host "   • Professional disk imaging and cloning" -ForegroundColor White
                        Write-Host "   • Best-in-class WinPE rescue media" -ForegroundColor White
                        Write-Host "   • Fast and reliable recovery" -ForegroundColor White
                        Write-Host "   • FREE Home Edition available!" -ForegroundColor Green
                        Write-Host "   • Paid Home: ~`$70 (one-time)" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "   Why Macrium is Best:" -ForegroundColor Cyan
                        Write-Host "   ✓ Fastest imaging/restore speeds" -ForegroundColor White
                        Write-Host "   ✓ Most reliable recovery" -ForegroundColor White
                        Write-Host "   ✓ Excellent bootable media creator" -ForegroundColor White
                        Write-Host "   ✓ Intuitive interface" -ForegroundColor White
                        Write-Host ""
                        
                        Write-Host "2. ACRONIS CYBER PROTECT HOME OFFICE" -ForegroundColor Cyan
                        Write-Host "   Website: https://www.acronis.com" -ForegroundColor Gray
                        Write-Host "   • Cloud-integrated backup solution" -ForegroundColor White
                        Write-Host "   • Provides time estimates (sometimes)" -ForegroundColor White
                        Write-Host "   • Anti-malware and cybersecurity features" -ForegroundColor White
                        Write-Host "   • Cost: ~`$50-100/year (subscription)" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "   Pros: Cloud backup, time estimates, security" -ForegroundColor Green
                        Write-Host "   Cons: Cloud recovery can be slow, expensive" -ForegroundColor Red
                        Write-Host ""
                        
                        Write-Host "3. PARAGON BACKUP & RECOVERY" -ForegroundColor Cyan
                        Write-Host "   Website: https://www.paragon-software.com" -ForegroundColor Gray
                        Write-Host "   • Comprehensive disk management" -ForegroundColor White
                        Write-Host "   • Backup, partitioning, and recovery" -ForegroundColor White
                        Write-Host "   • Cost: Varies by edition" -ForegroundColor Gray
                        Write-Host ""
                        
                        Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor Gray
                        Write-Host "EDITOR'S CHOICE: Macrium Reflect (Free or Paid)" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "C" {
                        Clear-Host
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
                        Write-Host "  IDEAL BACKUP STRATEGY" -ForegroundColor Cyan
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
                        Write-Host ""
                        
                        Write-Host "THE 3-2-1 BACKUP RULE:" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "  3 - Keep at least 3 copies of your data" -ForegroundColor Green
                        Write-Host "      (Original + 2 backups)" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "  2 - Store on 2 different types of media" -ForegroundColor Green
                        Write-Host "      (e.g., Internal SSD + External HDD)" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "  1 - Keep 1 copy offsite or in cloud" -ForegroundColor Green
                        Write-Host "      (Protection against fire/theft)" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "RECOMMENDED BACKUP SCHEDULE:" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "  • System Image: Weekly (or before major changes)" -ForegroundColor White
                        Write-Host "  • Important Files: Daily (automated)" -ForegroundColor White
                        Write-Host "  • Critical Documents: Real-time sync (OneDrive)" -ForegroundColor White
                        Write-Host ""
                        Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "FREE BACKUP SOFTWARE:" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "  1. Macrium Reflect Free ⭐" -ForegroundColor Green
                        Write-Host "     Full system imaging + bootable rescue media" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "  2. AOMEI Backupper Standard" -ForegroundColor Green
                        Write-Host "     System/disk backup with scheduling" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "  3. Windows Built-in Backup" -ForegroundColor Green
                        Write-Host "     File History + System Image (already on your PC)" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "ENVIRONMENT-SPECIFIC TIPS:" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "In Full Windows (FullOS):" -ForegroundColor Cyan
                        Write-Host "  • Install backup software directly" -ForegroundColor White
                        Write-Host "  • Create bootable rescue media" -ForegroundColor White
                        Write-Host "  • Schedule automatic backups" -ForegroundColor White
                        Write-Host ""
                        Write-Host "In WinPE/WinRE (Recovery):" -ForegroundColor Cyan
                        Write-Host "  • Use bootable media from backup software" -ForegroundColor White
                        Write-Host "  • Access image files on external drives" -ForegroundColor White
                        Write-Host "  • Restore system from backup images" -ForegroundColor White
                        Write-Host ""
                        Write-Host "In Windows Installer (Shift+F10):" -ForegroundColor Cyan
                        Write-Host "  • Limited to command-line tools" -ForegroundColor White
                        Write-Host "  • Better to use WinPE or rescue media" -ForegroundColor White
                        Write-Host ""
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "D" {
                        Clear-Host
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
                        Write-Host "  HARDWARE RECOMMENDATIONS FOR FAST BACKUPS" -ForegroundColor Magenta
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
                        Write-Host ""
                        
                        Write-Host "STORAGE PERFORMANCE HIERARCHY:" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "🏆 BEST: NVMe SSD (PCIe 4.0/5.0)" -ForegroundColor Green
                        Write-Host "   Speed: Up to 7,000 MB/s (PCIe 4.0)" -ForegroundColor Gray
                        Write-Host "   Speed: Up to 14,000 MB/s (PCIe 5.0)" -ForegroundColor Gray
                        Write-Host "   Use Case: Primary backup for desktop PCs" -ForegroundColor White
                        Write-Host "   Requires: M.2 slot on motherboard" -ForegroundColor Yellow
                        Write-Host "   Cost: `$150-`$400 (1-2TB)" -ForegroundColor Gray
                        Write-Host ""
                        
                        Write-Host "⭐ GREAT: SATA SSD" -ForegroundColor Cyan
                        Write-Host "   Speed: Up to 550 MB/s" -ForegroundColor Gray
                        Write-Host "   Use Case: Budget internal backups" -ForegroundColor White
                        Write-Host "   Requires: SATA port on motherboard" -ForegroundColor Yellow
                        Write-Host "   Cost: `$50-`$150 (1TB)" -ForegroundColor Gray
                        Write-Host ""
                        
                        Write-Host "✅ GOOD: USB 3.2 Gen 2 External SSD" -ForegroundColor White
                        Write-Host "   Speed: Up to 1,000 MB/s" -ForegroundColor Gray
                        Write-Host "   Use Case: Portable backups, laptops" -ForegroundColor White
                        Write-Host "   Requires: USB 3.0+ port (USB-C recommended)" -ForegroundColor Yellow
                        Write-Host "   Cost: `$100-`$250 (1-2TB)" -ForegroundColor Gray
                        Write-Host ""
                        
                        Write-Host "⚠️ ACCEPTABLE: External HDD (7200 RPM)" -ForegroundColor DarkYellow
                        Write-Host "   Speed: ~120-200 MB/s" -ForegroundColor Gray
                        Write-Host "   Use Case: Large capacity, budget backups" -ForegroundColor White
                        Write-Host "   Note: Slower but good for archival storage" -ForegroundColor Yellow
                        Write-Host "   Cost: `$50-`$100 (2-4TB)" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "INVESTMENT RECOMMENDATIONS:" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "For Desktop PCs:" -ForegroundColor Cyan
                        Write-Host "  • Add secondary NVMe SSD for backups" -ForegroundColor White
                        Write-Host "  • Check motherboard for M.2 slot availability" -ForegroundColor White
                        Write-Host "  • May require motherboard upgrade" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "For Laptops:" -ForegroundColor Cyan
                        Write-Host "  • USB 3.2 Gen 2 external SSD (portable + fast)" -ForegroundColor White
                        Write-Host "  • Look for USB-C connection" -ForegroundColor White
                        Write-Host ""
                        Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "EXAMPLE PRODUCTS:" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "NVMe SSDs:" -ForegroundColor Cyan
                        Write-Host "  • Samsung 990 PRO (PCIe 4.0)" -ForegroundColor White
                        Write-Host "  • Crucial T700 (PCIe 5.0)" -ForegroundColor White
                        Write-Host "  • WD Black SN850X (PCIe 4.0)" -ForegroundColor White
                        Write-Host ""
                        Write-Host "External SSDs:" -ForegroundColor Cyan
                        Write-Host "  • Samsung T7/T9 Portable SSD" -ForegroundColor White
                        Write-Host "  • SanDisk Extreme Pro Portable SSD" -ForegroundColor White
                        Write-Host "  • Crucial X8/X10 Portable SSD" -ForegroundColor White
                        Write-Host ""
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "R" {
                        # Return to main menu
                        break
                    }
                    default {
                        Write-Host "`nInvalid selection. Press any key to continue..." -ForegroundColor Red
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                }
                
                # Loop back to tools submenu unless user chose to return
                if ($toolChoice.ToUpper() -ne "R") {
                    # Recursive call to show tools menu again
                    continue
                }
            }
            "Q" { 
                Write-Host "`nExiting..." -ForegroundColor Yellow
                break 
            }
            "q" { 
                Write-Host "`nExiting..." -ForegroundColor Yellow
                break 
            }
            default {
                Write-Host "`nInvalid selection. Press any key to continue..." -ForegroundColor Red
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
    } while ($c -ne "Q" -and $c -ne "q")
}
