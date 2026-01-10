Set-StrictMode -Version Latest

function Get-EnvState {
    $isWinPE = $false
    $systemDrive = $env:SystemDrive
    try {
        if ($systemDrive -eq "X:" -and (Test-Path "X:\Windows\System32")) { $isWinPE = $true }
        if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT") { $isWinPE = $true }
    } catch { }
    $firmware = "Unknown"
    try {
        $fw = bcdedit /enum firmware 2>$null
        if ($fw) { $firmware = "UEFI" }
    } catch { }
    return [pscustomobject]@{
        SystemDrive = $systemDrive
        IsWinPE     = $isWinPE
        Firmware    = $firmware
    }
}

function Get-VolumesSafe {
    try { return Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } }
    catch { return @() }
}

function Get-WindowsInstallsSafe {
    $installs = @()
    foreach ($v in Get-VolumesSafe) {
        $dl = "$($v.DriveLetter):"
        try {
            if (Test-Path "$dl\Windows\System32\config\SYSTEM") {
                $installs += [pscustomobject]@{
                    Drive  = $dl
                    Label  = $v.FileSystemLabel
                    Volume = $v
                }
            }
        } catch { }
    }
    return $installs
}

function Get-EspCandidate {
    foreach ($v in Get-VolumesSafe) {
        if ($v.FileSystem -eq "FAT32" -and $v.Size -lt 600MB) { return $v }
    }
    return $null
}

function Mount-EspTemp {
    param($PreferredLetter = "S")
    $letters = @($PreferredLetter,"Z","Y","X","W","V","U")
    foreach ($l in $letters) {
        if (-not (Get-PSDrive -Name $l -ErrorAction SilentlyContinue)) {
            try {
                $out = mountvol "$l`:\" /S 2>&1
                if ($LASTEXITCODE -eq 0 -and ($out -notmatch "parameter is incorrect")) {
                    return [pscustomobject]@{ Letter = $l; Output = $out }
                }
            } catch { }
        }
    }
    return $null
}

function Unmount-EspTemp {
    param($Letter)
    if (-not $Letter) { return }
    try { mountvol "$Letter`:\" /D 2>$null } catch { }
}

function Invoke-DefensiveBootRepair {
    param(
        [string]$TargetDrive,
        [ValidateSet("Auto","DiagnoseOnly","RepairSafe","RepairForce")]
        [string]$Mode = "Auto",
        [string]$SimulationScenario = $null,
        [switch]$DryRun,
        [switch]$AllowOnlineRepair,
        [switch]$Force
    )

    $actions = @()
    $rollbackPlan = @(
        "Restore original BCD from backup if taken",
        "Unmount any temporary ESP mounts",
        "Revert file attributes on boot files if modified"
    )
    $blastRadius = @()
    $script:LastBackupPath = $null
    $logDir = Join-Path $PSScriptRoot "LOGS_MIRACLEBOOT"
    if (-not (Test-Path $logDir)) { try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch { } }
    $envState = Get-EnvState
    $runningOnline = (-not $envState.IsWinPE)

    # Mode resolution
    $resolvedMode = $Mode
    if ($Mode -eq "Auto") {
        if ($runningOnline) {
            $resolvedMode = "DiagnoseOnly"
            if ($AllowOnlineRepair) { $resolvedMode = "RepairSafe" }
        } else {
            $resolvedMode = "RepairSafe"
            if ($Force) { $resolvedMode = "RepairForce" }
        }
    }
    if ($resolvedMode -eq "RepairForce" -and $runningOnline) { $resolvedMode = "DiagnoseOnly" }

    $diagOnly = ($resolvedMode -eq "DiagnoseOnly")
    $simulate = [bool]$SimulationScenario
    $simulationState = $null

    if ($simulate) {
        $simulationState = @{
            winload_missing = @{
                OSDrive = if ($TargetDrive) { $TargetDrive } else { "C:" }
                WinloadExists = $false
                BcdPointsWinload = $true
                BitLockerLocked = $false
                ESPPresent = $true
                ESPMounted = $true
                BootFiles = $true
            }
            winload_missing_bitlocker = @{
                OSDrive = if ($TargetDrive) { $TargetDrive } else { "C:" }
                WinloadExists = $false
                BcdPointsWinload = $true
                BitLockerLocked = $true
                ESPPresent = $true
                ESPMounted = $true
                BootFiles = $true
                StorageDriverMissing = $false
                SecureBoot = $false
            }
            bcd_points_wrong_partition = @{
                OSDrive = if ($TargetDrive) { $TargetDrive } else { "C:" }
                WinloadExists = $true
                BcdPointsWinload = $false
                BitLockerLocked = $false
                ESPPresent = $true
                ESPMounted = $true
                BootFiles = $true
            }
            esp_missing = @{
                OSDrive = if ($TargetDrive) { $TargetDrive } else { "C:" }
                WinloadExists = $true
                BcdPointsWinload = $true
                BitLockerLocked = $false
                ESPPresent = $false
                ESPMounted = $false
                BootFiles = $false
            }
            bcd_missing = @{
                OSDrive = if ($TargetDrive) { $TargetDrive } else { "C:" }
                WinloadExists = $true
                BcdPointsWinload = $false
                BitLockerLocked = $false
                ESPPresent = $true
                ESPMounted = $true
                BootFiles = $false
            }
            secure_boot_blocks_loader = @{
                OSDrive = if ($TargetDrive) { $TargetDrive } else { "C:" }
                WinloadExists = $true
                BcdPointsWinload = $true
                BitLockerLocked = $false
                ESPPresent = $true
                ESPMounted = $true
                BootFiles = $true
                SecureBoot = $true
            }
            storage_driver_missing = @{
                OSDrive = if ($TargetDrive) { $TargetDrive } else { "C:" }
                WinloadExists = $true
                BcdPointsWinload = $true
                BitLockerLocked = $false
                ESPPresent = $true
                ESPMounted = $true
                BootFiles = $true
                StorageDriverMissing = $true
            }
        }[$SimulationScenario]
    }

    $mountedByUs = $false
    $espLetter = $null
    $espMounted = $false
    $esp = $null
    $windowsInstalls = @()
    $selectedOS = $null
    $blocker = $null

    try {
        # Detection
        $windowsInstalls = Get-WindowsInstallsSafe
        if ($TargetDrive) {
            $selectedOS = $windowsInstalls | Where-Object { $_.Drive.TrimEnd(':') -ieq $TargetDrive.TrimEnd(':') } | Select-Object -First 1
        } elseif ($windowsInstalls.Count -eq 1) {
            $selectedOS = $windowsInstalls[0]
        }
        if (-not $selectedOS) {
            if ($windowsInstalls.Count -gt 1) { $blocker = "Multiple Windows installs; cannot safely choose target automatically." }
            elseif ($windowsInstalls.Count -eq 0) { $blocker = "No Windows install detected." }
        }

        # ESP detection / mount
        $esp = Get-EspCandidate
        if ($esp -and $esp.DriveLetter) {
            $espMounted = $true
            $espLetter = "$($esp.DriveLetter):"
        } elseif (-not $simulate -and -not $diagOnly -and -not $DryRun) {
            $mount = Mount-EspTemp -PreferredLetter "S"
            if ($mount) { $espMounted = $true; $espLetter = "$($mount.Letter):"; $mountedByUs = $true }
        }

        # If simulation, override states
        $winloadExists = $false
        $bcdPathMatch = $false
        $bitlockerLocked = $null
        $bootFilesPresent = $false
        $storageDriverMissing = $false
        $secureBoot = $false

        if ($simulate -and $simulationState) {
        $winloadExists = $simulationState.WinloadExists
        $bcdPathMatch = $simulationState.BcdPointsWinload
        $bitlockerLocked = $simulationState.BitLockerLocked
        $bootFilesPresent = $simulationState.BootFiles
        $storageDriverMissing = $(if ($simulationState.PSObject.Properties.Name -contains 'StorageDriverMissing') { $simulationState.StorageDriverMissing } else { $false })
        $secureBoot = $(if ($simulationState.PSObject.Properties.Name -contains 'SecureBoot') { $simulationState.SecureBoot } else { $false })
            if ($simulationState.ESPPresent -and -not $espMounted) { $espMounted = $true; $espLetter = "S:"; $mountedByUs = $false }
            if (-not $selectedOS -and $simulationState.OSDrive) {
                $selectedOS = [pscustomobject]@{ Drive = $simulationState.OSDrive; Label = "(sim)"; Volume = $null }
                $blocker = $null
            }
        } else {
            if ($selectedOS) {
                $winloadPath = "$($selectedOS.Drive)\Windows\System32\winload.efi"
                $winloadExists = Test-Path $winloadPath
                $bootFilesPresent = $winloadExists
                try {
                    $bcdOut = bcdedit /enum {default} 2>&1 | Out-String
                    if ($bcdOut -match "winload\.efi") { $bcdPathMatch = $true }
                } catch { }
                try {
                    $blOut = manage-bde -status "$($selectedOS.Drive)" 2>&1 | Out-String
                    if ($blOut -match "Lock Status:\s*Locked") { $bitlockerLocked = $true } else { $bitlockerLocked = $false }
                } catch { $bitlockerLocked = $null }
                try { $secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue } catch { $secureBoot = $false }
            }
            try {
                $controllers = Get-StorageControllerCandidates
                $bootCrit = $controllers | Where-Object { $_.Class -match 'VMD|RAID|NVMe|SATA|AHCI|SAS' }
                if ($bootCrit) { $storageDriverMissing = ($bootCrit | Where-Object { $_.ErrorCode -and $_.ErrorCode -ne 0 }).Count -gt 0 }
            } catch { }
        }

        # Pre-flight backup (Layer 8)
        $backupPath = Join-Path $logDir "BCD_PRODUCTION_BACKUP.bak"
        $shouldWrite = (-not $diagOnly -and -not $DryRun -and -not $simulate -and -not $runningOnline)
        if ($shouldWrite -and -not $blocker) {
            try {
                $exportOut = bcdedit /export "$backupPath" 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0) {
                    $script:LastBackupPath = $backupPath
                    $rollbackPlan[0] = "Restore BCD from backup at $backupPath"
                    $actions += "BCD backup created at $backupPath"
                } else {
                    $blocker = "Failed to export BCD backup (exit $LASTEXITCODE). Aborting repair."
                    $actions += "BCD backup failed; repair aborted."
                }
            } catch {
                $blocker = "Failed to export BCD backup: $($_.Exception.Message)"
                $actions += "BCD backup failed; repair aborted."
            }
        }

        # Build plan
        $plan = @()
        if ($blocker) {
            $plan += "Blocker: $blocker"
        } else {
            if (-not $espMounted) { $plan += "Mount ESP (mountvol S: /S)" }
            if (-not $winloadExists) { $plan += "Extract winload.efi from install media and copy to $($selectedOS.Drive)\Windows\System32" }
            if (-not $bcdPathMatch) { $plan += "Set BCD path to \\Windows\\system32\\winload.efi" }
            if ($bitlockerLocked) { $plan += "Unlock BitLocker: manage-bde -unlock $($selectedOS.Drive) -RecoveryPassword [KEY]" }
        }

        # Blast radius
        if ($bitlockerLocked) { $blastRadius += "BitLocker locked: will not attempt writes; risk of triggering recovery prompts avoided." }
        if ($runningOnline -and $resolvedMode -ne "DiagnoseOnly") { $blastRadius += "Running in full Windows; destructive commands blocked by Environment Guard." }

        # Guards
        if ($diagOnly -or $DryRun -or $simulate) { $actions += "Destructive commands blocked by Environment Guard." }
        if ($bitlockerLocked -eq $true) { $actions += "Repair aborted: BitLocker locked." }

        # Truth engine
        $bootable = $winloadExists -and $bcdPathMatch -and (-not $bitlockerLocked)
        $confidence = "LOW"
        if ($bootable -and $espMounted -and $bootFilesPresent -and -not $storageDriverMissing) { $confidence = "HIGH" }
        elseif ($bootable) { $confidence = "MEDIUM" }
        elseif (-not $bootable -and (-not $winloadExists -or $bitlockerLocked -or -not $bcdPathMatch)) { $confidence = "HIGH" }
        $blockerFinal = $null
        if (-not $bootable) {
            if (-not $winloadExists) { $blockerFinal = "winload.efi missing" }
            elseif (-not $bcdPathMatch) { $blockerFinal = "BCD mismatch" }
            elseif ($bitlockerLocked) { $blockerFinal = "BitLocker locked" }
            else { $blockerFinal = "Unknown blocker" }
        }

        # Bundle
        $bundle = @()
        $bundle += "========== BOOTFIX PASTE-BACK BUNDLE BEGIN =========="
        $bundle += "Mode: $resolvedMode"
        $bundle += "Environment: " + ($(if ($envState.IsWinPE) { "WinRE/WinPE" } else { "FullWindows" }))
        $bundle += "Firmware: $($envState.Firmware)"
        $bundle += "DiskLayout: Unknown"
        $bundle += "EnvironmentGuard: " + ($(if ($diagOnly -or $DryRun -or $simulate -or $runningOnline) { "Destructive commands blocked by Environment Guard." } else { "Repair actions permitted." }))
        $bundle += "DetectedWindows:"
        foreach ($w in $windowsInstalls) { $bundle += "  - $($w.Drive) $($w.Label)" }
        $bundle += "SelectedWindows: " + $(if ($selectedOS) { $selectedOS.Drive } else { "(none)" })
        $bundle += "ESP:"
        $bundle += "  present: " + $(if ($esp) { "true" } else { "false" })
        $bundle += "  mounted: " + $(if ($espMounted) { "true" } else { "false" })
        $bundle += "  letter: " + $(if ($espLetter) { $espLetter } else { "(none)" })
        $bundle += "BCDBackupPath: " + $(if ($script:LastBackupPath) { $script:LastBackupPath } else { "(not created; guard or failure)" })
        $bundle += "BootFiles:"
        $bundle += "  bootmgfw.efi: unknown"
        $bundle += "  BCD: unknown"
        $bundle += "WindowsFiles:"
        $bundle += "  winload.efi: " + $(if ($winloadExists) { "present" } else { "missing" })
        $bundle += "  ntoskrnl.exe: unknown"
        $bundle += "BCDCheck:"
        $bundle += "  path_matches: " + $(if ($bcdPathMatch) { "true" } else { "false" })
        $bundle += "SecureBoot: " + $(if ($secureBoot) { "true" } else { "false" })
        $bundle += "BitLocker: " + $(if ($bitlockerLocked -eq $true) { "locked" } elseif ($bitlockerLocked -eq $false) { "unlocked" } else { "unknown" })
        $bundle += "StorageModeHints: " + $(if ($storageDriverMissing) { "boot-critical driver missing" } else { "unknown/ok" })
        $bundle += "RollbackPlan:"
        foreach ($r in $rollbackPlan) { $bundle += "  - $r" }
        $bundle += "BlastRadius:"
        if ($blastRadius.Count -gt 0) { foreach ($b in $blastRadius) { $bundle += "  - $b" } } else { $bundle += "  - minimal (simulation/diagnose mode)" }
        $bundle += "ActionsExecuted:"
        foreach ($a in $actions) { $bundle += "  - $a" }
        $bundle += "Final:"
        $bundle += "  BootVerdict: " + $(if ($bootable) { "YES" } else { "NO" })
        $bundle += "  Confidence: $confidence"
        $bundle += "  Blocker: " + $(if ($blockerFinal) { $blockerFinal } else { "none" })
        $bundle += "  NextStep: " + $(if ($plan.Count -gt 0) { $plan -join "; " } else { "none" })
        $bundle += "========== BOOTFIX PASTE-BACK BUNDLE END =========="

        $output = @()
        $output += "--- FINAL REPAIR REPORT ---"
        if ($bootable) { $output += "BOOT STATUS: LIKELY BOOTABLE" }
        else { $output += "BOOT STATUS: WILL NOT BOOT"; $output += "Blocker: $blockerFinal" }
        $output += "Confidence: $confidence"
        $output += "Plan: "
        foreach ($p in $plan) { $output += "  - $p" }
        $output += $bundle

        return [pscustomobject]@{
            Mode       = $resolvedMode
            Bootable   = $bootable
            Confidence = $confidence
            Blocker    = $blockerFinal
            Output     = ($output -join "`n")
            Bundle     = ($bundle -join "`n")
        }
    }
    finally {
        if ($mountedByUs -and $espLetter) {
            try { Unmount-EspTemp -Letter ($espLetter.TrimEnd(':')) } catch { }
        }
    }
}
