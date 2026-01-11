function Start-TUI {
    # Log TUI startup
    if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
        Write-ToLog "═════════════════════════════════════════════════════════════" "INFO"
        Write-ToLog "TUI Mode Starting - User Interface: MS-DOS STYLE" "INFO"
        Write-ToLog "═════════════════════════════════════════════════════════════" "INFO"
    }
    
    # Load DefensiveBootCore.ps1 (required for One-Click Repair)
    try {
        $corePath = Join-Path $PSScriptRoot "DefensiveBootCore.ps1"
        if (Test-Path $corePath) {
            # Load with explicit UTF-8 encoding to prevent character corruption
            $coreContent = Get-Content $corePath -Raw -Encoding UTF8
            Invoke-Expression $coreContent -ErrorAction Stop
            if (-not (Get-Command Invoke-DefensiveBootRepair -ErrorAction SilentlyContinue)) {
                Write-Warning "DefensiveBootCore.ps1 loaded but Invoke-DefensiveBootRepair function not found"
            }
            if (-not (Get-Command Invoke-BruteForceBootRepair -ErrorAction SilentlyContinue)) {
                Write-Warning "DefensiveBootCore.ps1 loaded but Invoke-BruteForceBootRepair function not found"
            }
        } else {
            Write-Warning "DefensiveBootCore.ps1 not found at $corePath - One-Click Repair may not work"
        }
    } catch {
        Write-Warning "Failed to load DefensiveBootCore.ps1: $_ - One-Click Repair may not work"
        Write-Warning "Error details: $($_.Exception.Message)"
        Write-Warning "Stack trace: $($_.ScriptStackTrace)"
    }
    
    # Load global settings for read-only mode if available
    try {
        $gsmPath = Join-Path $PSScriptRoot "HELPER SCRIPTS\GlobalSettingsManager.ps1"
        if (Test-Path -LiteralPath $gsmPath) {
            . $gsmPath
            if (Get-Command Load-Settings -ErrorAction SilentlyContinue) {
                Load-Settings | Out-Null
            }
        }
    } catch {
        # Non-fatal; continue without settings
    }
    
    function Get-ReadOnlyModeEnabled {
        if (Get-Command Get-ReadOnlyMode -ErrorAction SilentlyContinue) {
            return (Get-ReadOnlyMode -eq $true)
        }
        return $false
    }
    
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
    
    if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
        Write-ToLog "Environment: $envDisplay" "INFO"
    }

    function Invoke-OneClickRepairTUI {
        param(
            [string]$TargetDrive = $env:SystemDrive.TrimEnd(':'),
            [switch]$DryRun,
            [string]$SimulationScenario = $null
        )

        # Verify function is available before calling
        if (-not (Get-Command Invoke-DefensiveBootRepair -ErrorAction SilentlyContinue)) {
            throw "Invoke-DefensiveBootRepair function not found. Please ensure DefensiveBootCore.ps1 is loaded."
        }

        $result = Invoke-DefensiveBootRepair -TargetDrive $TargetDrive -Mode "Auto" -DryRun:$DryRun -SimulationScenario $SimulationScenario
        
        # Defensive checks for result properties
        $outputText = ""
        $bundleText = ""
        $reportPath = $null
        $bootable = $false
        
        if ($result) {
            if ($result.PSObject.Properties.Name -contains 'Output') {
                $outputText = $result.Output
            }
            if ($result.PSObject.Properties.Name -contains 'Bundle') {
                $bundleText = $result.Bundle
            }
            if ($result.PSObject.Properties.Name -contains 'ReportPath') {
                $reportPath = $result.ReportPath
            }
            if ($result.PSObject.Properties.Name -contains 'Bootable') {
                $bootable = $result.Bootable
            }
        } else {
            Write-Host "Error: Repair function returned no result" -ForegroundColor Red
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
        
        $summaryDir = Join-Path $PSScriptRoot "LOGS_MIRACLEBOOT"
        if (-not (Test-Path $summaryDir)) { New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null }
        $summaryPath = Join-Path $summaryDir ("OneClick_TUI_{0:yyyyMMdd_HHmmss}.txt" -f (Get-Date))
        Set-Content -Path $summaryPath -Value ($outputText + "`n`n" + $bundleText) -Encoding UTF8 -Force

        Clear-Host
        Write-Host $outputText -ForegroundColor Cyan
        Write-Host "`n--- PASTE-BACK BUNDLE ---`n" -ForegroundColor Yellow
        Write-Host $bundleText -ForegroundColor Gray
        
        # Open comprehensive report in Notepad (if available)
        if ($reportPath -and (Test-Path $reportPath)) {
            Write-Host "`nOpening comprehensive repair report in Notepad..." -ForegroundColor Green
            try {
                Start-Process notepad.exe -ArgumentList "`"$reportPath`""
            } catch {
                Write-Host "Could not open Notepad. Report saved to: $reportPath" -ForegroundColor Yellow
            }
        }
        
        Write-Host "`nSummary saved to: $summaryPath" -ForegroundColor Yellow
        if ($reportPath) {
            Write-Host "Comprehensive report: $reportPath" -ForegroundColor Yellow
        }
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
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
        Write-Host "5) Edit BCD Entry / Quick Fixes" -ForegroundColor White
        Write-Host "6) Repair-Install Readiness Check" -ForegroundColor Yellow
        Write-Host "H) WinRE Health Check" -ForegroundColor Yellow
        Write-Host "7) Recommended Recovery Tools" -ForegroundColor Green
        Write-Host "8) Utilities & Tools" -ForegroundColor Magenta
        Write-Host "9) Network & Internet Help" -ForegroundColor Cyan
        Write-Host "B) Boot Issue Mapping" -ForegroundColor Cyan
        Write-Host "A) One-Click Repair (TUI - defaults to Test Mode)" -ForegroundColor Green
        Write-Host "S) Simulation & Diagnostics" -ForegroundColor Yellow
        Write-Host "Q) Quit" -ForegroundColor Yellow
        Write-Host ""

        $c = Read-Host "Select"
        
        # Log menu selection
        if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
            Write-ToLog "TUI Menu selection: [$c]" "DEBUG"
        }
        
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
                    if (Get-ReadOnlyModeEnabled) {
                        Write-Host "`nRead-only mode enabled. Preview only:" -ForegroundColor Yellow
                        Write-Host "  Inject-Drivers-Offline $win $path" -ForegroundColor Gray
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        break
                    }
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
                Clear-Host
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "  BCD EDIT + QUICK FIXES" -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                if (Get-ReadOnlyModeEnabled) {
                    Write-Host "Read-only mode enabled. BCD modifications are disabled." -ForegroundColor Yellow
                    Write-Host "Preview commands:" -ForegroundColor Gray
                    Write-Host "  bcdedit /set {default} recoveryenabled no" -ForegroundColor Gray
                    Write-Host "  bcdedit /set {default} bootmenupolicy legacy" -ForegroundColor Gray
                    Write-Host "Press any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    break
                }
                Write-Host "1) Edit BCD Entry Description" -ForegroundColor White
                Write-Host "2) Break Recovery Loop (recoveryenabled no)" -ForegroundColor Yellow
                Write-Host "3) Enable Legacy F8 Menu (bootmenupolicy legacy)" -ForegroundColor Yellow
                Write-Host "R) Return to Menu" -ForegroundColor Gray
                Write-Host ""

                $bcdChoice = Read-Host "Select"
                switch ($bcdChoice.ToUpper()) {
                    "1" {
                        Write-Host "`nCurrent BCD Entries:" -ForegroundColor Cyan
                        bcdedit /enum | Select-String "identifier" | ForEach-Object { Write-Host $_.Line -ForegroundColor Gray }
                        Write-Host ""
                        $id = Read-Host "Enter BCD Identifier (GUID)"
                        $name = Read-Host "Enter new description"
                        if ($id -and $name) {
                            Set-BCDDescription $id $name
                            Write-Host "BCD entry updated successfully!" -ForegroundColor Green
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "2" {
                        try {
                            if (Get-Command Disable-BCDRecoveryEnabledDefault -ErrorAction SilentlyContinue) {
                                Disable-BCDRecoveryEnabledDefault
                            } else {
                                bcdedit /set {default} recoveryenabled no | Out-Null
                            }
                            Write-Host "Recovery loop disabled for default entry." -ForegroundColor Green
                        } catch {
                            Write-Host "Failed to disable recovery loop: $_" -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "3" {
                        try {
                            if (Get-Command Set-BCDBootMenuPolicyLegacyDefault -ErrorAction SilentlyContinue) {
                                Set-BCDBootMenuPolicyLegacyDefault
                            } else {
                                bcdedit /set {default} bootmenupolicy legacy | Out-Null
                            }
                            Write-Host "Legacy F8 boot menu enabled for default entry." -ForegroundColor Green
                        } catch {
                            Write-Host "Failed to enable legacy boot menu: $_" -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    default { }
                }
            }
            "A" {
                $target = Read-Host "Target Windows drive letter (default: $($env:SystemDrive))"
                if (-not $target) { $target = $env:SystemDrive.TrimEnd(':') }
                $dr = Read-Host "Dry-run only? (Y/N, default Y)"
                $isDry = if (-not $dr -or $dr -match '^[Yy]') { $true } else { $false }
                Invoke-OneClickRepairTUI -TargetDrive $target -DryRun:$isDry
            }
            "S" {
                Write-Host "`nSIMULATION & DIAGNOSTICS" -ForegroundColor Cyan
                Write-Host "1) winload_missing" -ForegroundColor White
                Write-Host "2) bcd_missing" -ForegroundColor White
                Write-Host "3) storage_driver_missing" -ForegroundColor White
                Write-Host "R) Return" -ForegroundColor Gray
                $simChoice = Read-Host "Select simulation"
                $scenario = $null
                switch ($simChoice) {
                    "1" { $scenario = "winload_missing" }
                    "2" { $scenario = "bcd_missing" }
                    "3" { $scenario = "storage_driver_missing" }
                    default { $scenario = $null }
                }
                if ($scenario) {
                    Invoke-OneClickRepairTUI -TargetDrive $env:SystemDrive.TrimEnd(':') -DryRun -SimulationScenario $scenario
                }
            }
            "6" {
                Clear-Host
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
                Write-Host "  REPAIR-INSTALL READINESS CHECK" -ForegroundColor Yellow
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "This checks if Windows is eligible for setup.exe repair-install" -ForegroundColor White
                Write-Host "mode, which preserves apps and files." -ForegroundColor White
                Write-Host ""
                
                $readinessChoice = Read-Host "Select option: (1) Check Only, (2) Check + Auto-Repair, (Q) Return to Menu"
                switch ($readinessChoice.ToUpper()) {
                    "1" {
                        Write-Host "`nRunning repair-install readiness check..." -ForegroundColor Cyan
                        Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
                        
                        try {
                            if (Get-Command Invoke-RepairInstallReadinessCheck -ErrorAction SilentlyContinue) {
                                $result = Invoke-RepairInstallReadinessCheck -TargetDrive "C" -AutoRepair:$false
                                
                                Write-Host "`n" -ForegroundColor Gray
                                Write-Host "FINAL RECOMMENDATION: $($result.FinalRecommendation)" -ForegroundColor Cyan
                                Write-Host ""
                            } else {
                                Write-Host "ERROR: EnsureRepairInstallReady module not available" -ForegroundColor Red
                            }
                        } catch {
                            Write-Host "ERROR: $_" -ForegroundColor Red
                        }
                        
                        Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "2" {
                        Write-Host "`nRunning repair-install readiness check with auto-repair..." -ForegroundColor Cyan
                        Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
                        Write-Host "⚠ This will attempt to normalize Windows state for setup.exe" -ForegroundColor Yellow
                        Write-Host ""
                        
                        $confirm = Read-Host "Proceed? (Y/N)"
                        if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                            try {
                                if (Get-Command Invoke-RepairInstallReadinessCheck -ErrorAction SilentlyContinue) {
                                    $result = Invoke-RepairInstallReadinessCheck -TargetDrive "C" -AutoRepair:$true
                                    
                                    Write-Host "`n" -ForegroundColor Gray
                                    Write-Host "FINAL RECOMMENDATION: $($result.FinalRecommendation)" -ForegroundColor Cyan
                                    Write-Host ""
                                } else {
                                    Write-Host "ERROR: EnsureRepairInstallReady module not available" -ForegroundColor Red
                                }
                            } catch {
                                Write-Host "ERROR: $_" -ForegroundColor Red
                            }
                            
                            Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        } else {
                            Write-Host "Operation cancelled." -ForegroundColor Yellow
                        }
                    }
                }
            }
            "H" {
                Clear-Host
                Write-Host "ЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭ" -ForegroundColor Yellow
                Write-Host "  WINRE HEALTH CHECK" -ForegroundColor Yellow
                Write-Host "ЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭ" -ForegroundColor Yellow
                Write-Host ""
                
                $defaultDrive = $env:SystemDrive.TrimEnd(':')
                $driveInput = Read-Host "Target Windows drive letter (e.g. C) [default: $defaultDrive]"
                if ([string]::IsNullOrWhiteSpace($driveInput)) {
                    $driveInput = $defaultDrive
                }
                
                if (Get-Command Get-WinREHealth -ErrorAction SilentlyContinue) {
                    $health = Get-WinREHealth -TargetDrive $driveInput
                    Write-Host ""
                    Write-Host $health.Report -ForegroundColor White
                } else {
                    Write-Host "ERROR: WinRE health check function not available." -ForegroundColor Red
                }
                
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "h" {
                Clear-Host
                Write-Host "ЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭ" -ForegroundColor Yellow
                Write-Host "  WINRE HEALTH CHECK" -ForegroundColor Yellow
                Write-Host "ЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭ" -ForegroundColor Yellow
                Write-Host ""
                
                $defaultDrive = $env:SystemDrive.TrimEnd(':')
                $driveInput = Read-Host "Target Windows drive letter (e.g. C) [default: $defaultDrive]"
                if ([string]::IsNullOrWhiteSpace($driveInput)) {
                    $driveInput = $defaultDrive
                }
                
                if (Get-Command Get-WinREHealth -ErrorAction SilentlyContinue) {
                    $health = Get-WinREHealth -TargetDrive $driveInput
                    Write-Host ""
                    Write-Host $health.Report -ForegroundColor White
                } else {
                    Write-Host "ERROR: WinRE health check function not available." -ForegroundColor Red
                }
                
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "8" {
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
            "7" {
                Clear-Host
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
                Write-Host "  UTILITIES & TOOLS" -ForegroundColor Magenta
                Write-Host "  Environment: $envDisplay" -ForegroundColor Gray
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
                Write-Host ""
                Write-Host "A) Open Notepad" -ForegroundColor White
                Write-Host "B) Open Registry Editor (regedit)" -ForegroundColor White
                Write-Host "C) Open Disk Management (diskpart)" -ForegroundColor White
                Write-Host "D) Open Task Manager" -ForegroundColor White
                Write-Host "E) Open Command Prompt" -ForegroundColor White
                Write-Host "F) Open PowerShell" -ForegroundColor White
                Write-Host "G) Open File Explorer" -ForegroundColor White
                Write-Host "H) System Information (systeminfo)" -ForegroundColor White
                Write-Host "I) Check Disk (chkdsk)" -ForegroundColor Yellow
                Write-Host "J) Network Configuration (ipconfig)" -ForegroundColor Cyan
                Write-Host "K) Restart Windows Explorer" -ForegroundColor Yellow
                Write-Host "R) Return to Main Menu" -ForegroundColor Gray
                Write-Host ""
                
                $utilChoice = Read-Host "Select"
                switch ($utilChoice.ToUpper()) {
                    "A" {
                        Write-Host "`nLaunching Notepad..." -ForegroundColor Green
                        try {
                            Start-Process "notepad.exe" -ErrorAction Stop
                            Write-Host "Notepad opened successfully." -ForegroundColor Green
                        } catch {
                            Write-Host "Failed to open Notepad: $_" -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "B" {
                        Write-Host "`nLaunching Registry Editor..." -ForegroundColor Green
                        Write-Host "WARNING: Be careful when editing the registry!" -ForegroundColor Yellow
                        try {
                            Start-Process "regedit.exe" -ErrorAction Stop
                            Write-Host "Registry Editor opened successfully." -ForegroundColor Green
                        } catch {
                            Write-Host "Failed to open Registry Editor: $_" -ForegroundColor Red
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "C" {
                        Write-Host "`nLaunching DiskPart (interactive mode)..." -ForegroundColor Green
                        Write-Host "Type 'help' for commands, 'exit' to return." -ForegroundColor Yellow
                        Write-Host ""
                        diskpart
                        Write-Host "`nReturning to utilities menu..." -ForegroundColor Gray
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "D" {
                        Write-Host "`nLaunching Task Manager..." -ForegroundColor Green
                        try {
                            Start-Process "taskmgr.exe" -ErrorAction Stop
                            Write-Host "Task Manager opened successfully." -ForegroundColor Green
                        } catch {
                            Write-Host "Failed to open Task Manager: $_" -ForegroundColor Red
                            Write-Host "Task Manager may not be available in $envDisplay" -ForegroundColor Yellow
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "E" {
                        Write-Host "`nLaunching Command Prompt..." -ForegroundColor Green
                        Write-Host "Type 'exit' to return to this menu." -ForegroundColor Yellow
                        Write-Host ""
                        cmd.exe
                        Write-Host "`nReturning to utilities menu..." -ForegroundColor Gray
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "F" {
                        Write-Host "`nLaunching PowerShell..." -ForegroundColor Green
                        Write-Host "Type 'exit' to return to this menu." -ForegroundColor Yellow
                        Write-Host ""
                        powershell.exe
                        Write-Host "`nReturning to utilities menu..." -ForegroundColor Gray
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "G" {
                        Write-Host "`nLaunching File Explorer..." -ForegroundColor Green
                        try {
                            Start-Process "explorer.exe" -ErrorAction Stop
                            Write-Host "File Explorer opened successfully." -ForegroundColor Green
                        } catch {
                            Write-Host "Failed to open File Explorer: $_" -ForegroundColor Red
                            Write-Host "File Explorer may not be available in $envDisplay" -ForegroundColor Yellow
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "H" {
                        Write-Host "`nGathering system information..." -ForegroundColor Green
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                        systeminfo | more
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "I" {
                        Write-Host "`nCheck Disk Utility" -ForegroundColor Yellow
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                        Write-Host ""
                        $driveLetter = Read-Host "Enter drive letter to check (e.g., C)"
                        if ($driveLetter) {
                            $driveNormalized = $driveLetter.TrimEnd(':').ToUpper()
                            if (Get-ReadOnlyModeEnabled) {
                                Write-Host "`nRead-only mode enabled. Preview only:" -ForegroundColor Yellow
                                Write-Host "  chkdsk ${driveNormalized}: /F /R" -ForegroundColor Gray
                                Write-Host "Press any key to continue..." -ForegroundColor Gray
                                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                                break
                            }
                            Write-Host "`nRunning chkdsk on ${driveNormalized}:..." -ForegroundColor Green
                            Write-Host "This may take several minutes..." -ForegroundColor Yellow
                            chkdsk "${driveNormalized}:" /F /R
                            Write-Host "`nCheck disk operation completed." -ForegroundColor Green
                        }
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "J" {
                        Write-Host "`nNetwork Configuration" -ForegroundColor Cyan
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                        Write-Host ""
                        ipconfig /all | more
                        Write-Host ""
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "K" {
                        Write-Host "`nRestarting Windows Explorer..." -ForegroundColor Yellow
                        Write-Host ""
                        $result = Restart-WindowsExplorer
                        
                        Write-Host "Status: $($result.Status)" -ForegroundColor $(if ($result.Success) { "Green" } else { "Red" })
                        Write-Host "Message: $($result.Message)" -ForegroundColor $(if ($result.Success) { "Green" } else { "Red" })
                        
                        if ($result.ActionTaken -eq "Restarted") {
                            Write-Host "`n✓ Windows Explorer has been successfully restarted." -ForegroundColor Green
                        } elseif ($result.ExplorerRunning) {
                            Write-Host "`n✓ Windows Explorer is running normally - no restart needed." -ForegroundColor Green
                        } else {
                            Write-Host "`n✗ An error occurred while restarting Windows Explorer." -ForegroundColor Red
                        }
                        
                        Write-Host "`nPress any key to continue..." -ForegroundColor Gray
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
            }
            "9" {
                Clear-Host
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "  NETWORK & INTERNET HELP" -ForegroundColor Cyan
                Write-Host "  Environment: $envDisplay" -ForegroundColor Gray
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "A) Check Network Status" -ForegroundColor White
                Write-Host "B) Enable Network Adapters (WinPE)" -ForegroundColor Green
                Write-Host "C) Test Internet Connectivity" -ForegroundColor White
                Write-Host "D) Get Windows Help (Text Browser)" -ForegroundColor Yellow
                Write-Host "E) Install Portable Browser (WinPE Only)" -ForegroundColor Magenta
                Write-Host "F) Launch Browser (if available)" -ForegroundColor Cyan
                Write-Host "R) Return to Main Menu" -ForegroundColor Gray
                Write-Host ""
                
                $netChoice = Read-Host "Select"
                switch ($netChoice.ToUpper()) {
                    "A" {
                        Write-Host "`nChecking network adapters..." -ForegroundColor Green
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                        Write-Host ""
                        
                        try {
                            $adapters = Get-NetAdapter -ErrorAction Stop
                            Write-Host "Network Adapters Found:" -ForegroundColor Cyan
                            Write-Host ""
                            foreach ($adapter in $adapters) {
                                $statusColor = if ($adapter.Status -eq "Up") { "Green" } else { "Yellow" }
                                Write-Host "  Name: $($adapter.Name)" -ForegroundColor White
                                Write-Host "  Status: $($adapter.Status)" -ForegroundColor $statusColor
                                Write-Host "  Interface: $($adapter.InterfaceDescription)" -ForegroundColor Gray
                                Write-Host ""
                            }
                        } catch {
                            Write-Host "Get-NetAdapter not available. Using netsh..." -ForegroundColor Yellow
                            netsh interface show interface
                        }
                        
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "B" {
                        Write-Host "`nEnabling network adapters in WinPE..." -ForegroundColor Green
                        Write-Host ""
                        
                        if ($envDisplay -eq "WinPE" -or $envDisplay -eq "WinRE") {
                            Write-Host "Method 1: Running wpeinit (WinPE Network Initialization)..." -ForegroundColor Cyan
                            try {
                                wpeinit
                                Write-Host "Network stack initialized successfully!" -ForegroundColor Green
                            } catch {
                                Write-Host "wpeinit not available or failed." -ForegroundColor Yellow
                            }
                            
                            Write-Host ""
                            Write-Host "Method 2: Enabling disabled network adapters..." -ForegroundColor Cyan
                            try {
                                $disabledAdapters = Get-NetAdapter | Where-Object {$_.Status -eq 'Disabled'}
                                if ($disabledAdapters) {
                                    foreach ($adapter in $disabledAdapters) {
                                        Write-Host "  Enabling: $($adapter.Name)..." -ForegroundColor Gray
                                        Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
                                    }
                                    Write-Host "All disabled adapters enabled!" -ForegroundColor Green
                                } else {
                                    Write-Host "No disabled adapters found." -ForegroundColor Yellow
                                }
                            } catch {
                                Write-Host "Failed to enable adapters: $_" -ForegroundColor Red
                                Write-Host "Try manually: netsh interface set interface 'Ethernet' enable" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "This option is primarily for WinPE/WinRE environments." -ForegroundColor Yellow
                            Write-Host "Current environment: $envDisplay" -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "In Full OS, network adapters are typically already enabled." -ForegroundColor White
                        }
                        
                        Write-Host ""
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "C" {
                        Write-Host "`nTesting internet connectivity..." -ForegroundColor Green
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                        Write-Host ""
                        
                        Write-Host "Test 1: Ping Google DNS (8.8.8.8)..." -ForegroundColor Cyan
                        $pingResult = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet
                        if ($pingResult) {
                            Write-Host "  ✓ Internet connectivity: OK" -ForegroundColor Green
                        } else {
                            Write-Host "  ✗ No internet connection" -ForegroundColor Red
                        }
                        
                        Write-Host ""
                        Write-Host "Test 2: DNS Resolution (google.com)..." -ForegroundColor Cyan
                        try {
                            $dnsResult = Resolve-DnsName "google.com" -ErrorAction Stop
                            Write-Host "  ✓ DNS resolution: OK" -ForegroundColor Green
                        } catch {
                            Write-Host "  ✗ DNS resolution failed" -ForegroundColor Red
                        }
                        
                        Write-Host ""
                        Write-Host "Test 3: HTTP Connectivity (microsoft.com)..." -ForegroundColor Cyan
                        try {
                            $webResult = Invoke-WebRequest -Uri "https://www.microsoft.com" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
                            Write-Host "  ✓ Web access: OK (Status $($webResult.StatusCode))" -ForegroundColor Green
                        } catch {
                            Write-Host "  ✗ Web access failed: $_" -ForegroundColor Red
                        }
                        
                        Write-Host ""
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "D" {
                        Write-Host "`nText-Based Web Browser" -ForegroundColor Yellow
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "This feature fetches web content as text (no images/CSS)." -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "1) Microsoft Support - Windows Boot Issues" -ForegroundColor White
                        Write-Host "2) Microsoft Support - Windows Startup Settings" -ForegroundColor White
                        Write-Host "3) Custom URL" -ForegroundColor Cyan
                        Write-Host "R) Return" -ForegroundColor Gray
                        Write-Host ""
                        
                        $browserChoice = Read-Host "Select"
                        $url = ""
                        
                        switch ($browserChoice) {
                            "1" { $url = "https://support.microsoft.com/en-us/windows/advanced-startup-options-including-safe-mode-b90e7808-80b5-a291-d4b8-1a1af602b617" }
                            "2" { $url = "https://support.microsoft.com/en-us/windows/start-your-pc-in-safe-mode-in-windows-92c27cff-db89-8644-1ce4-b3e5e56fe234" }
                            "3" { $url = Read-Host "Enter URL (must start with http:// or https://)" }
                            "R" { break }
                        }
                        
                        if ($url -and $url -ne "") {
                            Write-Host "`nFetching content from: $url" -ForegroundColor Green
                            Write-Host "Please wait..." -ForegroundColor Yellow
                            Write-Host ""
                            
                            try {
                                $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                                
                                # Extract plain text from HTML (basic parsing)
                                $content = $response.Content
                                $content = $content -replace '<script[^>]*>.*?</script>', ''  # Remove scripts
                                $content = $content -replace '<style[^>]*>.*?</style>', ''    # Remove styles
                                $content = $content -replace '<[^>]+>', "`n"                  # Remove HTML tags
                                $content = $content -replace '&nbsp;', ' '                    # Replace nbsp
                                $content = $content -replace '&quot;', '"'                    # Replace quotes
                                $content = $content -replace '&amp;', '&'                     # Replace ampersand
                                $content = $content -replace '&#39;', "'"                     # Replace apostrophe
                                $content = $content -replace '\s+', ' '                       # Normalize whitespace
                                $content = ($content -split "`n") | Where-Object { $_.Trim() -ne "" } | Select-Object -First 100
                                
                                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
                                Write-Host "Content Preview (first 100 lines):" -ForegroundColor Cyan
                                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                                Write-Host ""
                                $content | ForEach-Object { Write-Host $_.Trim() }
                                Write-Host ""
                                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                                
                                # Offer to save to file
                                $saveChoice = Read-Host "`nSave full content to file? (Y/N)"
                                if ($saveChoice -eq 'Y' -or $saveChoice -eq 'y') {
                                    $savePath = Read-Host "Enter file path (e.g., C:\help.txt)"
                                    if ($savePath) {
                                        $response.Content | Out-File -FilePath $savePath -Encoding UTF8
                                        Write-Host "Content saved to: $savePath" -ForegroundColor Green
                                    }
                                }
                                
                            } catch {
                                Write-Host "Failed to fetch web content: $_" -ForegroundColor Red
                                Write-Host ""
                                Write-Host "Possible reasons:" -ForegroundColor Yellow
                                Write-Host "  • No internet connection" -ForegroundColor White
                                Write-Host "  • Network adapters not enabled" -ForegroundColor White
                                Write-Host "  • Firewall blocking connection" -ForegroundColor White
                                Write-Host "  • DNS not configured" -ForegroundColor White
                            }
                        }
                        
                        Write-Host ""
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "E" {
                        Write-Host "`nPortable Browser Installation for WinPE" -ForegroundColor Magenta
                        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "IMPORTANT NOTES:" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "Shift+F10 Environment:" -ForegroundColor Cyan
                        Write-Host "  • No graphical browsers will work (no GUI framework)" -ForegroundColor Red
                        Write-Host "  • Limited to command-line tools only" -ForegroundColor White
                        Write-Host "  • Use text-based browser (Option D) instead" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "WinPE/WinRE with GUI:" -ForegroundColor Cyan
                        Write-Host "  • Some portable browsers may work if GUI available" -ForegroundColor Green
                        Write-Host "  • Requires display drivers loaded" -ForegroundColor Yellow
                        Write-Host "  • Best option: Include browser in custom WinPE build" -ForegroundColor White
                        Write-Host ""
                        Write-Host "RECOMMENDED APPROACH:" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "1. Download Portable Browser:" -ForegroundColor White
                        Write-Host "   • Firefox Portable: https://portableapps.com/apps/internet/firefox_portable" -ForegroundColor Gray
                        Write-Host "   • Chrome Portable: https://portableapps.com/apps/internet/google_chrome_portable" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "2. Copy to USB Drive:" -ForegroundColor White
                        Write-Host "   • Extract portable browser to USB" -ForegroundColor Gray
                        Write-Host "   • Access from WinPE if GUI available" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "3. For Shift+F10:" -ForegroundColor White
                        Write-Host "   • Browsers will NOT work (no GUI)" -ForegroundColor Red
                        Write-Host "   • Use Option D (Text Browser) for help content" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "4. Better Alternative:" -ForegroundColor White
                        Write-Host "   • Use Hiren's BootCD PE (includes browsers pre-installed)" -ForegroundColor Green
                        Write-Host "   • Download: https://www.hirensbootcd.org" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "Current Environment: $envDisplay" -ForegroundColor Cyan
                        if ($envDisplay -eq "FullOS") {
                            Write-Host "  → Browsers already available on your system!" -ForegroundColor Green
                        } elseif ($envDisplay -eq "WinPE" -or $envDisplay -eq "WinRE") {
                            Write-Host "  → Check if GUI is available (explorer.exe)" -ForegroundColor Yellow
                            Write-Host "  → If no GUI, use text-based browser (Option D)" -ForegroundColor White
                        }
                        
                        Write-Host ""
                        Write-Host "Press any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "F" {
                        Write-Host "`nLaunching Browser..." -ForegroundColor Cyan
                        Write-Host ""
                        
                        $browsers = @(
                            @{Name="Microsoft Edge"; Path="msedge.exe"; Args="https://chatgpt.com"},
                            @{Name="Google Chrome"; Path="chrome.exe"; Args="https://chatgpt.com"},
                            @{Name="Firefox"; Path="firefox.exe"; Args="https://chatgpt.com"},
                            @{Name="Internet Explorer"; Path="iexplore.exe"; Args="https://chatgpt.com"}
                        )
                        
                        $launched = $false
                        foreach ($browser in $browsers) {
                            try {
                                Write-Host "Trying $($browser.Name)..." -ForegroundColor Gray
                                Start-Process $browser.Path -ArgumentList $browser.Args -ErrorAction Stop
                                Write-Host "✓ $($browser.Name) launched successfully!" -ForegroundColor Green
                                Write-Host "Opening ChatGPT for Windows boot assistance..." -ForegroundColor Cyan
                                $launched = $true
                                break
                            } catch {
                                Write-Host "  $($browser.Name) not available" -ForegroundColor DarkGray
                            }
                        }
                        
                        if (-not $launched) {
                            Write-Host ""
                            Write-Host "No graphical browser found." -ForegroundColor Red
                            Write-Host ""
                            Write-Host "Environment: $envDisplay" -ForegroundColor Yellow
                            if ($envDisplay -ne "FullOS") {
                                Write-Host "Graphical browsers typically don't work in $envDisplay" -ForegroundColor Yellow
                                Write-Host ""
                                Write-Host "Alternative options:" -ForegroundColor Cyan
                                Write-Host "  • Use Option D (Text-Based Browser) for help content" -ForegroundColor White
                                Write-Host "  • Boot into Full Windows to access browsers" -ForegroundColor White
                                Write-Host "  • Use Hiren's BootCD PE (includes browsers)" -ForegroundColor White
                            }
                        }
                        
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
            }
            "B" {
                Clear-Host
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "  BOOT ISSUE MAPPING" -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Describe the boot symptoms (stop codes, recovery loop, missing Start menu, etc.):" -ForegroundColor Gray
                $description = Read-Host -Prompt "Enter description (required)"
                if ([string]::IsNullOrWhiteSpace($description)) {
                    Write-Host "No description entered. Returning to menu." -ForegroundColor Yellow
                } else {
                    $suggestions = Suggest-BootIssueFromDescription $description
                    if (-not $suggestions -or $suggestions.Count -eq 0) {
                        Write-Host "`nNo direct mapping found. Consider reviewing the Boot Issue Mapping guide." -ForegroundColor Yellow
                    } else {
                        foreach ($suggestion in $suggestions) {
                            Write-Host "`n$($suggestion.Name)" -ForegroundColor Green
                            Write-Host "  Symptom: $($suggestion.Symptom)" -ForegroundColor Gray
                            Write-Host "  Description: $($suggestion.Description)" -ForegroundColor Gray
                            Write-Host "  Commands:" -ForegroundColor Gray
                            foreach ($cmd in $suggestion.Commands) {
                                Write-Host "    - $cmd" -ForegroundColor Gray
                            }
                            Write-Host "  Reference: $($suggestion.References -join ', ')" -ForegroundColor Cyan
                        }
                    }
                    Write-Host "`nFull mapping guide: DOCUMENTATION/BOOT_ISSUE_MAPPING.md" -ForegroundColor Gray
                    Write-Host "Official Microsoft troubleshooting reference (0x7B): https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/stop-error-7b-or-inaccessible-boot-device-troubleshooting" -ForegroundColor Gray
                    Write-Host "Virtual agent reference: https://chatgpt.com/s/t_695f6243fe9481919a76f51b7510aeb9" -ForegroundColor Gray
                }
                Write-Host "`nPress any key to return..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "Q" {
                Write-Host "`nExiting..." -ForegroundColor Yellow
                if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
                    Write-ToLog "TUI Mode: User pressed Q to quit" "INFO"
                }
                break
            }
            "q" { 
                Write-Host "`nExiting..." -ForegroundColor Yellow
                if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
                    Write-ToLog "TUI Mode: User pressed q to quit" "INFO"
                }
                break
            }
            default {
                Write-Host "`nInvalid selection. Press any key to continue..." -ForegroundColor Red
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
    } while ($c -ne "Q" -and $c -ne "q")
    
    # Log TUI shutdown
    if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
        Write-ToLog "TUI Mode ended - User exited application" "INFO"
        Write-ToLog "═════════════════════════════════════════════════════════════" "INFO"
    }
}

