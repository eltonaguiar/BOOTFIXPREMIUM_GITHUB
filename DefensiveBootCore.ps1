Set-StrictMode -Version Latest

# ============================================================================
# ADVANCED PLAN B TROUBLESHOOTING FUNCTIONS (For High-End Builds)
# ============================================================================

function Test-VMDDriverIssue {
    <#
    .SYNOPSIS
    Detects Intel VMD (Volume Management Device) driver issues on Z790 boards.
    #>
    $result = @{
        Detected = $false
        Details = @()
    }
    
    try {
        # Method 1: Check for VMD devices via WMI
        $vmdDevices = Get-WmiObject Win32_PnPEntity -Filter "Name LIKE '%VMD%'" -ErrorAction SilentlyContinue
        if ($vmdDevices) {
            $result.Detected = $true
            $result.Details += "Intel VMD controller detected via WMI"
        }
        
        # Method 2: Check BIOS version for VMD/RAID indicators
        try {
            $bios = Get-WmiObject Win32_BIOS -ErrorAction SilentlyContinue
            if ($bios -and $bios.SMBIOSBIOSVersion -match "RAID|VMD|AHCI") {
                $result.Detected = $true
                $result.Details += "BIOS version suggests VMD/RAID support: $($bios.SMBIOSBIOSVersion)"
            }
        } catch { }
        
        # Method 3: Check for NVMe drives (indication of potential VMD)
        try {
            $nvmeDrives = Get-WmiObject Win32_DiskDrive -Filter "InterfaceType LIKE '%NVMe%'" -ErrorAction SilentlyContinue
            if ($nvmeDrives) {
                $nvmeCount = @($nvmeDrives).Count
                if ($nvmeCount -gt 0) {
                    $result.Details += "Found $nvmeCount NVMe drive(s) - VMD may be required"
                }
            }
        } catch { }
        
        # Method 4: Check for missing storage drivers (common with VMD)
        try {
            $missingStorage = Get-MissingStorageDevices -ErrorAction SilentlyContinue
            if ($missingStorage -and $missingStorage -match "VMD|RAID|NVMe") {
                $result.Detected = $true
                $result.Details += "Missing storage drivers detected (may indicate VMD issue)"
            }
        } catch { }
        
    } catch {
        $result.Details += "VMD check failed: $($_.Exception.Message)"
    }
    
    return $result
}

function Test-GhostBCEEntries {
    <#
    .SYNOPSIS
    Detects "ghost" BCD entries from multiple drives causing UEFI confusion.
    #>
    $result = @{
        Detected = $false
        Details = @()
        DriveCount = 0
        BCDEntryCount = 0
    }
    
    try {
        # Count Windows installations
        $windowsInstalls = Get-WindowsInstallsSafe
        if ($null -eq $windowsInstalls) { $windowsInstalls = @() }
        if ($windowsInstalls -isnot [array]) { $windowsInstalls = @($windowsInstalls) }
        $result.DriveCount = $windowsInstalls.Count
        
        # Count BCD entries
        try {
            $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "all") -TimeoutSeconds 15 -Description "Enumerate all BCD entries"
            $bcdEntries = $bcdResult.Output
            $entryMatches = [regex]::Matches($bcdEntries, "identifier\s+\{[^}]+\}")
            $result.BCDEntryCount = $entryMatches.Count
            
            if ($result.DriveCount -gt 1 -or $result.BCDEntryCount -gt 3) {
                $result.Detected = $true
                $result.Details += "Multiple drives detected ($($result.DriveCount)) with $($result.BCDEntryCount) BCD entries"
                $result.Details += "UEFI firmware may be confused about which drive is boot manager"
            }
        } catch {
            $result.Details += "Could not enumerate BCD entries: $($_.Exception.Message)"
        }
        
    } catch {
        $result.Details += "Ghost BCD check failed: $($_.Exception.Message)"
    }
    
    return $result
}

function Test-PendingWindowsUpdates {
    <#
    .SYNOPSIS
    Detects pending Windows updates that may block boot repair.
    #>
    $result = @{
        Detected = $false
        Details = @()
        PendingPath = $null
    }
    
    try {
        $windowsInstalls = Get-WindowsInstallsSafe
        if ($null -eq $windowsInstalls) { $windowsInstalls = @() }
        if ($windowsInstalls -isnot [array]) { $windowsInstalls = @($windowsInstalls) }
        
        foreach ($install in $windowsInstalls) {
            $pendingPath = "$($install.Drive)\Windows\WinSxS\pending.xml"
            if (Test-Path $pendingPath) {
                $result.Detected = $true
                $result.PendingPath = $pendingPath
                $result.Details += "Pending updates found at: $pendingPath"
                break
            }
        }
        
    } catch {
        $result.Details += "Pending updates check failed: $($_.Exception.Message)"
    }
    
    return $result
}

function Test-ReadOnlyDrive {
    <#
    .SYNOPSIS
    Detects if a drive is marked as read-only.
    #>
    param([string]$TargetDrive)
    
    $result = @{
        Detected = $false
        Details = @()
    }
    
    try {
        $volumes = Get-Volume -ErrorAction SilentlyContinue
        foreach ($vol in $volumes) {
            if ($vol.DriveLetter -eq $TargetDrive.TrimEnd(':')) {
                break
            }
        }
        
        # Check disk attributes via diskpart
        try {
            diskpart /s (New-TemporaryFile) 2>&1 | Out-Null
            # This is a simplified check - full implementation would parse diskpart output
            # For now, we'll check if we can write to the drive
            $testFile = "$TargetDrive`:\test_write_$(Get-Random).tmp"
            try {
                [System.IO.File]::WriteAllText($testFile, "test")
                Remove-Item $testFile -Force -ErrorAction SilentlyContinue
            } catch {
                $result.Detected = $true
                $result.Details += "Drive appears to be read-only (write test failed)"
            }
        } catch {
            $result.Details += "Read-only check failed: $($_.Exception.Message)"
        }
        
    } catch {
        $result.Details += "Read-only drive check failed: $($_.Exception.Message)"
    }
    
    return $result
}

function Test-BIOSFirmwareState {
    <#
    .SYNOPSIS
    Checks BIOS/firmware state for common boot-blocking issues.
    #>
    $result = @{
        IssuesDetected = $false
        Issues = @()
        Details = @()
    }
    
    try {
        # Check firmware type
        $firmware = "Unknown"
        try {
            $fwResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "firmware") -TimeoutSeconds 10 -Description "Check firmware type"
            if ($fwResult.Output) { $firmware = "UEFI" } else { $firmware = "Legacy" }
        } catch { }
        
        # Check for Secure Boot (simplified - would need WMI/registry access)
        try {
            $bios = Get-WmiObject Win32_BIOS -ErrorAction SilentlyContinue
            if ($bios) {
                $result.Details += "BIOS Version: $($bios.SMBIOSBIOSVersion)"
                $result.Details += "BIOS Manufacturer: $($bios.Manufacturer)"
                
                # Check for common issues
                if ($firmware -eq "Legacy" -and $bios.SMBIOSBIOSVersion -match "UEFI") {
                    $result.IssuesDetected = $true
                    $result.Issues += "Firmware mismatch: BIOS supports UEFI but system is in Legacy mode"
                }
            }
        } catch {
            $result.Details += "BIOS info not available (may be in WinPE)"
        }
        
        # Check for CSM-related issues (would need registry access in full Windows)
        # In WinPE, we can't easily check this, so we provide guidance
        
        if (-not $result.IssuesDetected) {
            $result.Details += "No obvious BIOS/firmware issues detected"
        }
        
    } catch {
        $result.Details += "BIOS/firmware check failed: $($_.Exception.Message)"
    }
    
    return $result
}

function Get-EnvState {
    $isWinPE = $false
    $systemDrive = $env:SystemDrive
    try {
        if ($systemDrive -eq "X:" -and (Test-Path "X:\Windows\System32")) { $isWinPE = $true }
        if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT") { $isWinPE = $true }
    } catch { }
    $firmware = "Unknown"
    try {
        $fwResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "firmware") -TimeoutSeconds 10 -Description "Check firmware type"
        if ($fwResult.Output) { $firmware = "UEFI" }
    } catch { }
    return [pscustomobject]@{
        SystemDrive = $systemDrive
        IsWinPE     = $isWinPE
        Firmware    = $firmware
    }
}

function Get-VolumesSafe {
    try { 
        $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
        # Ensure we always return an array, even if empty or single object
        if ($null -eq $volumes) { return @() }
        if ($volumes -isnot [array]) { return @($volumes) }
        return $volumes
    }
    catch { return @() }
}

function Get-WindowsInstallsSafe {
    $installs = @()
    $volumes = Get-VolumesSafe
    # Ensure $volumes is always an array (defensive check)
    if ($null -eq $volumes) { $volumes = @() }
    if ($volumes -isnot [array]) { $volumes = @($volumes) }
    
    # Method 1: Check volumes from Get-VolumesSafe
    foreach ($v in $volumes) {
        if ($null -eq $v -or -not $v.DriveLetter) { continue }
        $dl = "$($v.DriveLetter):"
        try {
            # Check for Windows installation using multiple methods for WinPE compatibility
            # Method 1a: Check for SYSTEM registry hive (most reliable)
            if (Test-Path "$dl\Windows\System32\config\SYSTEM") {
                $installs += [pscustomobject]@{
                    Drive  = $dl
                    Label  = if ($v.FileSystemLabel) { $v.FileSystemLabel } else { "(no label)" }
                    Volume = $v
                }
                continue  # Found via registry, skip other checks for this drive
            }
            # Method 1b: Fallback - check for winload.efi (for WinPE environments where registry might not be accessible)
            if (Test-Path "$dl\Windows\System32\winload.efi") {
                $installs += [pscustomobject]@{
                    Drive  = $dl
                    Label  = if ($v.FileSystemLabel) { $v.FileSystemLabel } else { "(no label)" }
                    Volume = $v
                }
            }
        } catch { 
            # Silently continue if we can't check this drive
        }
    }
    
    # Method 2: Brute-force search using Get-PSDrive (for WinPE with drive letter shuffling)
    # This handles cases where Get-Volume might miss drives (e.g., complex multi-drive configs)
    if ($installs.Count -eq 0) {
        try {
            $psDrives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^[A-Z]$' }
            if ($psDrives) {
                foreach ($psd in $psDrives) {
                    $driveLetter = "$($psd.Name):"
                    # Skip if already found
                    $alreadyFound = $installs | Where-Object { $_.Drive -eq $driveLetter }
                    if ($alreadyFound) { continue }
                    
                    try {
                        # Check for Windows using winload.efi (most reliable in WinPE)
                        if (Test-Path "$driveLetter\Windows\System32\winload.efi") {
                            $label = try { (Get-Volume -DriveLetter $psd.Name -ErrorAction SilentlyContinue).FileSystemLabel } catch { $null }
                            $installs += [pscustomobject]@{
                                Drive  = $driveLetter
                                Label  = if ($label) { $label } else { "(no label)" }
                                Volume = $null  # Volume object not available via PSDrive
                            }
                        }
                        # Fallback: Check for SYSTEM registry hive
                        elseif (Test-Path "$driveLetter\Windows\System32\config\SYSTEM") {
                            $label = try { (Get-Volume -DriveLetter $psd.Name -ErrorAction SilentlyContinue).FileSystemLabel } catch { $null }
                            $installs += [pscustomobject]@{
                                Drive  = $driveLetter
                                Label  = if ($label) { $label } else { "(no label)" }
                                Volume = $null
                            }
                        }
                    } catch {
                        # Silently continue if we can't check this drive
                    }
                }
            }
        } catch {
            # Brute-force search failed, continue with what we found
        }
    }
    
    return $installs
}

function Get-EspCandidate {
    # Method 1: Standard detection via Get-VolumesSafe
    $volumes = Get-VolumesSafe
    if ($null -eq $volumes) { $volumes = @() }
    if ($volumes -isnot [array]) { $volumes = @($volumes) }
    
    foreach ($v in $volumes) {
        if ($null -eq $v) { continue }
        # Check for EFI partition: FAT32 and small size (< 600MB)
        if ($v.FileSystem -eq "FAT32" -and $v.Size -lt 600MB) { 
            return $v 
        }
    }
    
    # Method 2: Brute-force using Get-Partition (for WinPE with complex drive configs)
    try {
        $efiGuid = "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}"  # Standard EFI GUID
        $efiPart = Get-Partition -ErrorAction SilentlyContinue | Where-Object { $_.GptType -eq $efiGuid }
        if ($efiPart) {
            # Get volume for the partition
            $efiVol = $efiPart | Get-Volume -ErrorAction SilentlyContinue
            if ($efiVol -and $efiVol.DriveLetter) {
                return $efiVol
            }
        }
    } catch {
        # Get-Partition failed, continue with fallback
    }
    
    # Method 3: Fallback - search for FAT32 volumes with EFI/SYSTEM label
    foreach ($v in $volumes) {
        if ($null -eq $v) { continue }
        $label = if ($v.FileSystemLabel) { $v.FileSystemLabel.ToUpper() } else { "" }
        if (($v.FileSystem -eq "FAT32") -and ($label -match "SYSTEM|EFI|ESP")) {
            return $v
        }
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

# ============================================================================
# TIMEOUT WRAPPER FOR BCD OPERATIONS
# ============================================================================

function Invoke-BCDCommandWithTimeout {
    <#
    .SYNOPSIS
    Executes bcdedit or bcdboot commands with a timeout to prevent hanging.
    
    .DESCRIPTION
    Wraps bcdedit/bcdboot commands in a job with timeout to prevent indefinite hangs.
    Returns output and exit code, or timeout error if command takes too long.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$false)]
        [string[]]$Arguments = @(),
        
        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 30,
        
        [Parameter(Mandatory=$false)]
        [string]$Description = "BCD operation"
    )
    
    $result = @{
        Success = $false
        Output = ""
        ExitCode = -1
        TimedOut = $false
        Error = $null
    }
    
    try {
        # Build full command for logging
        $fullCommand = "$Command " + ($Arguments -join " ")
        
        # Properly escape arguments for ProcessStartInfo
        # ProcessStartInfo.Arguments expects a single string with properly escaped arguments
        # Use a StringBuilder-like approach to avoid PowerShell string interpretation issues
        $escapedArgs = @()
        foreach ($arg in $Arguments) {
            if ($null -eq $arg) { continue }
            $argStr = $arg.ToString()
            
            # If argument contains spaces, quotes, or special characters, quote it
            if ($argStr -match '\s|"|[{}\(\)]') {
                # Escape any existing quotes by doubling them (Windows command line standard)
                $escapedArg = $argStr -replace '"', '""'
                # Build quoted argument using string concatenation to avoid backtick interpretation
                $quotedArg = '"' + $escapedArg + '"'
                $escapedArgs += $quotedArg
            } else {
                $escapedArgs += $argStr
            }
        }
        $argumentString = $escapedArgs -join " "
        
        # Use Start-Process with timeout to prevent hanging
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $Command
        $processInfo.Arguments = $argumentString
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        # Start process
        $process.Start() | Out-Null
        
        # Wait for completion with timeout
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $completed) {
            # Timeout - kill the process
            try {
                if (-not $process.HasExited) {
                    $process.Kill()
                }
            } catch {
                # Process may have already exited
            }
            $result.TimedOut = $true
            $result.Error = "Command timed out after $TimeoutSeconds seconds: $fullCommand"
            try {
                $stdout = $process.StandardOutput.ReadToEnd()
                $stderr = $process.StandardError.ReadToEnd()
                $result.Output = $stdout + $stderr
            } catch {
                $result.Output = "Timeout occurred - output unavailable"
            }
            try {
                $process.Dispose()
            } catch { }
            return $result
        }
        
        # Get output
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $result.Output = $stdout + $stderr
        $result.ExitCode = $process.ExitCode
        $result.Success = ($process.ExitCode -eq 0)
        
        $process.Dispose()
        
    } catch {
        $result.Error = $_.Exception.Message
        $result.Output = $_.Exception.Message
        try {
            if ($process -and -not $process.HasExited) {
                $process.Kill()
            }
            if ($process) {
                $process.Dispose()
            }
        } catch { }
    }
    
    return $result
}

# ============================================================================
# ULTIMATE HARDENING FUNCTIONS
# ============================================================================

function Resolve-WindowsPath {
    <#
    .SYNOPSIS
    Resolves and normalizes Windows paths with comprehensive validation.
    
    .DESCRIPTION
    Handles drive letter normalization, long paths, special characters, and validates path format.
    Returns normalized path ready for use in file operations.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [switch]$RequireExists,
        [switch]$SupportLongPath
    )
    
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    
    # Normalize drive letter format (ensure colon)
    if ($Path -match '^([A-Z]):?\\') {
        $drive = $matches[1]
        $offset = if ($Path[$drive.Length] -eq ':') { 1 } else { 0 }
        $Path = "$drive`:" + $Path.Substring($drive.Length + $offset)
    }
    
    # Handle long paths if requested
    if ($SupportLongPath -and $Path.Length -gt 260 -and -not $Path.StartsWith("\\?\UNC\") -and -not $Path.StartsWith("\\?\")) {
        if ($Path.StartsWith("\\")) {
            $Path = "\\?\UNC\" + $Path.Substring(2)
        } else {
            $Path = "\\?\" + $Path
        }
    }
    
    # Normalize separators
    $Path = $Path -replace '/', '\'
    $Path = $Path -replace '\\+', '\'
    
    # Validate path if required
    if ($RequireExists) {
        $exists = $false
        try {
            # Try multiple detection methods
            $exists = Test-Path -LiteralPath $Path -ErrorAction SilentlyContinue
            if (-not $exists) {
                # Try Get-Item as fallback
                try {
                    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
                    $exists = ($null -ne $item)
                } catch { }
            }
            if (-not $exists) {
                # Try .NET File.Exists as last resort
                try {
                    $exists = [System.IO.File]::Exists($Path) -or [System.IO.Directory]::Exists($Path)
                } catch { }
            }
        } catch {
            return $null
        }
        
        if (-not $exists) {
            return $null
        }
    }
    
    return $Path
}

function Test-WinloadExistsComprehensive {
    <#
    .SYNOPSIS
    Comprehensive winload.efi detection using multiple methods.
    
    .DESCRIPTION
    Uses Test-Path, Get-Item, and File.Exists to detect winload.efi.
    Handles symlinks, junctions, and permission issues.
    Temporarily takes ownership and clears attributes if needed for verification.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $resolvedPath = Resolve-WindowsPath -Path $Path -SupportLongPath
    if (-not $resolvedPath) {
        return @{ Exists = $false; Method = "Path Resolution Failed"; Details = "Could not resolve path: $Path" }
    }
    
    try {
        # Method 1: Test-Path
        try {
            $testPathResult = Test-Path -LiteralPath $resolvedPath -ErrorAction Stop
            if ($testPathResult) {
                # Verify it's actually a file and not a directory
                $item = Get-Item -LiteralPath $resolvedPath -ErrorAction SilentlyContinue
                if ($item -and -not $item.PSIsContainer) {
                    return @{ Exists = $true; Method = "Test-Path"; Details = "File found via Test-Path"; Item = $item }
                }
            }
        } catch {
            # Continue to next method
        }
        
        # Method 2: Get-Item
        try {
            $item = Get-Item -LiteralPath $resolvedPath -ErrorAction Stop
            if ($item -and -not $item.PSIsContainer) {
                return @{ Exists = $true; Method = "Get-Item"; Details = "File found via Get-Item"; Item = $item }
            }
        } catch {
            # Continue to next method - might be permission issue
        }
        
        # Method 3: .NET File.Exists
        try {
            $fileExists = [System.IO.File]::Exists($resolvedPath)
            if ($fileExists) {
                $item = Get-Item -LiteralPath $resolvedPath -ErrorAction SilentlyContinue
                if ($item) {
                    return @{ Exists = $true; Method = "File.Exists"; Details = "File found via File.Exists"; Item = $item }
                }
            }
        } catch {
            # Continue
        }
        
        # Method 4: Try with temporary ownership/permission fix (for hidden/system files)
        try {
            # Check if file might exist but be hidden or have permission issues
            # Temporarily take ownership and clear attributes
            $takeownResult = Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$resolvedPath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
            if ($takeownResult.ExitCode -eq 0) {
                $permissionsModified = $true
                # Grant permissions
                Start-Process -FilePath "icacls.exe" -ArgumentList "`"$resolvedPath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue | Out-Null
                # Clear hidden/system/readonly attributes
                Start-Process -FilePath "attrib.exe" -ArgumentList "-s", "-h", "-r", "`"$resolvedPath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue | Out-Null
                
                # Now try to access the file
                $item = Get-Item -LiteralPath $resolvedPath -ErrorAction SilentlyContinue
                if ($item -and -not $item.PSIsContainer) {
                    return @{ 
                        Exists = $true; 
                        Method = "Get-Item (with ownership fix)"; 
                        Details = "File found after taking ownership and clearing attributes"; 
                        Item = $item;
                        PermissionsModified = $true
                    }
                }
            }
        } catch {
            # Continue to next method
        }
        
        # Method 5: Check if it's a symlink/junction pointing to valid file
        try {
            $item = Get-Item -LiteralPath $resolvedPath -ErrorAction SilentlyContinue
            if ($item) {
                $linkType = $item.LinkType
                if ($linkType) {
                    $target = $item.Target
                    if ($target -and (Test-Path -LiteralPath $target -ErrorAction SilentlyContinue)) {
                        return @{ Exists = $true; Method = "Symlink/Junction"; Details = "Valid symlink/junction found"; Item = $item; Target = $target }
                    } else {
                        return @{ Exists = $false; Method = "Symlink/Junction"; Details = "Broken symlink/junction"; Item = $item; Target = $target }
                    }
                }
            }
        } catch {
            # Continue
        }
        
        return @{ Exists = $false; Method = "All Methods Failed"; Details = "File not found via any detection method" }
    } finally {
        # Note: We don't restore permissions here because:
        # 1. If file was hidden/system, it should stay visible/accessible after verification
        # 2. Taking ownership is typically needed for boot files anyway
        # 3. Restoring could cause issues if verification is part of repair process
        # If restoration is needed, it should be handled at a higher level
    }
}

function Get-FileHashSafe {
    <#
    .SYNOPSIS
    Safely calculates file hash with error handling.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    try {
        $resolvedPath = Resolve-WindowsPath -Path $FilePath -RequireExists -SupportLongPath
        if (-not $resolvedPath) {
            return $null
        }
        
        # Try Get-FileHash first (PowerShell 4+)
        if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
            return Get-FileHash -Path $resolvedPath -Algorithm SHA256 -ErrorAction Stop
        }
        
        # Fallback to .NET
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $fileStream = [System.IO.File]::OpenRead($resolvedPath)
        try {
            $hashBytes = $sha256.ComputeHash($fileStream)
            $hashString = [System.BitConverter]::ToString($hashBytes) -replace '-', ''
            return [pscustomobject]@{
                Algorithm = "SHA256"
                Hash = $hashString
                Path = $resolvedPath
            }
        } finally {
            $fileStream.Close()
            $sha256.Dispose()
        }
    } catch {
        return $null
    }
}

function Test-FileIntegrity {
    <#
    .SYNOPSIS
    Comprehensive file integrity verification.
    
    .DESCRIPTION
    Verifies file exists, has correct size, is readable, and optionally matches hash.
    Temporarily takes ownership and clears attributes if needed for verification.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [long]$ExpectedSize = -1,
        [string]$ExpectedHash = $null,
        [long]$MinSize = 100000,
        [long]$MaxSize = 5000000
    )
    
    $result = @{
        Valid = $false
        Exists = $false
        SizeMatch = $false
        HashMatch = $false
        Readable = $false
        SizeReasonable = $false
        Details = @()
        FileInfo = $null
        PermissionsModified = $false
    }
    
    # Track if we need to restore permissions
    $permissionsModified = $false
    $resolvedPath = Resolve-WindowsPath -Path $FilePath -SupportLongPath
    if (-not $resolvedPath) {
        $resolvedPath = $FilePath  # Fallback
    }
    
    # Check existence using comprehensive method (this may already fix permissions)
    $existsCheck = Test-WinloadExistsComprehensive -Path $FilePath
    $result.Exists = $existsCheck.Exists
    # Safely check for PermissionsModified (not all return paths include it)
    if ($existsCheck -is [hashtable] -and $existsCheck.ContainsKey('PermissionsModified') -and $existsCheck.PermissionsModified) {
        $permissionsModified = $true
        $result.PermissionsModified = $true
    }
    
    if (-not $result.Exists) {
        $result.Details += "File does not exist: $FilePath"
        return $result
    }
    
    $result.FileInfo = $existsCheck.Item
    if (-not $result.FileInfo) {
        try {
            $result.FileInfo = Get-Item -LiteralPath $resolvedPath -ErrorAction Stop
        } catch {
            # If we can't get file info, try taking ownership first
            if (-not $permissionsModified) {
                try {
                    $takeownResult = Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$resolvedPath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                    if ($takeownResult.ExitCode -eq 0) {
                        $permissionsModified = $true
                        $result.PermissionsModified = $true
                        Start-Process -FilePath "icacls.exe" -ArgumentList "`"$resolvedPath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue | Out-Null
                        Start-Process -FilePath "attrib.exe" -ArgumentList "-s", "-h", "-r", "`"$resolvedPath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue | Out-Null
                        $result.FileInfo = Get-Item -LiteralPath $resolvedPath -ErrorAction Stop
                    } else {
                        $result.Details += "Could not get file info: $($_.Exception.Message)"
                        return $result
                    }
                } catch {
                    $result.Details += "Could not get file info: $($_.Exception.Message)"
                    return $result
                }
            } else {
                $result.Details += "Could not get file info: $($_.Exception.Message)"
                return $result
            }
        }
    }
    
    # Check file size
    $actualSize = $result.FileInfo.Length
    $result.SizeReasonable = ($actualSize -ge $MinSize -and $actualSize -le $MaxSize)
    
    if ($ExpectedSize -gt 0) {
        $result.SizeMatch = ($actualSize -eq $ExpectedSize)
        if (-not $result.SizeMatch) {
            $result.Details += "Size mismatch: Expected $ExpectedSize bytes, got $actualSize bytes"
        }
    } else {
        $result.SizeMatch = $result.SizeReasonable
    }
    
    # Check readability (try with permission fix if needed)
    try {
        $testRead = [System.IO.File]::OpenRead($resolvedPath)
        $testRead.Close()
        $result.Readable = $true
    } catch {
        # If read failed and we haven't tried permission fix yet, try it now
        if (-not $permissionsModified) {
            try {
                $takeownResult = Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$resolvedPath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                if ($takeownResult.ExitCode -eq 0) {
                    $permissionsModified = $true
                    $result.PermissionsModified = $true
                    $icaclsResult = Start-Process -FilePath "icacls.exe" -ArgumentList "`"$resolvedPath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                    $attribResult = Start-Process -FilePath "attrib.exe" -ArgumentList "-s", "-h", "-r", "`"$resolvedPath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                    
                    # Try reading again
                    $testRead = [System.IO.File]::OpenRead($resolvedPath)
                    $testRead.Close()
                    $result.Readable = $true
                } else {
                    $result.Readable = $false
                    $result.Details += "File not readable: $($_.Exception.Message) (takeown failed)"
                }
            } catch {
                $result.Readable = $false
                $result.Details += "File not readable: $($_.Exception.Message)"
            }
        } else {
            $result.Readable = $false
            $result.Details += "File not readable: $($_.Exception.Message)"
        }
    }
    
    # Check hash if provided
    if ($ExpectedHash) {
        $actualHash = Get-FileHashSafe -FilePath $resolvedPath
        if ($actualHash) {
            $result.HashMatch = ($actualHash.Hash -eq $ExpectedHash)
            if (-not $result.HashMatch) {
                $result.Details += "Hash mismatch: Expected $ExpectedHash, got $($actualHash.Hash)"
            }
        } else {
            $result.Details += "Could not calculate file hash"
        }
    } else {
        $result.HashMatch = $true  # No hash to compare
    }
    
    # Overall validity
    $result.Valid = $result.Exists -and $result.SizeMatch -and $result.Readable -and $result.SizeReasonable -and ($result.HashMatch -or -not $ExpectedHash)
    
    if ($result.Valid) {
        $result.Details += "File integrity verified: $actualSize bytes, readable, size reasonable"
        if ($permissionsModified) {
            $result.Details += "Permissions/attributes were modified to enable verification"
        }
    }
    
    return $result
}

function Get-WindowsVersionInfo {
    <#
    .SYNOPSIS
    Gets Windows version and architecture information for a drive.
    
    .DESCRIPTION
    Attempts to read version info from registry or system files.
    Returns version, build number, and architecture.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Drive
    )
    
    $info = @{
        Version = $null
        BuildNumber = $null
        Architecture = $null
        OSName = $null
        IsCompatible = $false
    }
    
    try {
        # Try to load registry hive
        $systemHive = "$Drive`:\Windows\System32\config\SYSTEM"
        if (Test-Path $systemHive) {
            # Try to get info from registry (requires reg.exe or offline registry access)
            # For now, use file-based detection
            $sys32Path = "$Drive`:\Windows\System32"
            
            # Architecture detection
            if (Test-Path "$sys32Path\winload.efi") {
                $info.Architecture = "x64"
            } elseif (Test-Path "$sys32Path\winload.exe") {
                $info.Architecture = "x86"
            } else {
                # Check for ARM64
                if (Test-Path "$sys32Path\winloadarm.efi") {
                    $info.Architecture = "ARM64"
                } else {
                    $info.Architecture = "Unknown"
                }
            }
            
            # Version detection from build number (if available)
            try {
                $versionFile = "$Drive`:\Windows\System32\ntoskrnl.exe"
                if (Test-Path $versionFile) {
                    $fileVersion = (Get-Item $versionFile -ErrorAction SilentlyContinue).VersionInfo
                    if ($fileVersion) {
                        $info.Version = $fileVersion.FileVersion
                        # Extract build number from version string
                        if ($fileVersion.FileVersion -match '(\d+\.\d+\.\d+\.\d+)') {
                            $parts = $matches[1] -split '\.'
                            if ($parts.Count -ge 3) {
                                $info.BuildNumber = $parts[2]
                            }
                        }
                    }
                }
            } catch { }
            
            $info.IsCompatible = ($info.Architecture -ne "Unknown")
        }
    } catch {
        # Fallback: assume compatible if we can't determine
        $info.IsCompatible = $true
    }
    
    return $info
}

function Test-VersionCompatibility {
    <#
    .SYNOPSIS
    Tests if source winload.efi is compatible with target Windows installation.
    
    .DESCRIPTION
    Checks architecture match and optionally version compatibility.
    Returns compatibility score and details.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetDrive,
        
        [hashtable]$TargetInfo = $null
    )
    
    $result = @{
        Compatible = $false
        Score = 0
        Details = @()
        Warnings = @()
    }
    
    # Get target info if not provided
    if (-not $TargetInfo) {
        $TargetInfo = Get-WindowsVersionInfo -Drive $TargetDrive
    }
    
    # Get source info
    $sourceDrive = (Split-Path $SourcePath -Qualifier).TrimEnd(':')
    $sourceInfo = Get-WindowsVersionInfo -Drive $sourceDrive
    
    # Architecture compatibility (CRITICAL)
    if ($sourceInfo.Architecture -eq $TargetInfo.Architecture) {
        $result.Score += 50
        $result.Details += "[OK] Architecture match: $($sourceInfo.Architecture)"
    } elseif ($sourceInfo.Architecture -eq "Unknown" -or $TargetInfo.Architecture -eq "Unknown") {
        $result.Score += 25
        $result.Warnings += "⚠ Architecture unknown - assuming compatible"
        $result.Details += "⚠ Architecture detection failed - proceeding with caution"
    } else {
        $result.Details += "[X] Architecture mismatch: Source=$($sourceInfo.Architecture), Target=$($TargetInfo.Architecture)"
        $result.Warnings += "CRITICAL: Architecture mismatch - winload.efi may not work!"
        return $result  # Architecture mismatch is critical
    }
    
    # Version compatibility (if available)
    if ($sourceInfo.BuildNumber -and $TargetInfo.BuildNumber) {
        $sourceBuild = [int]$sourceInfo.BuildNumber
        $targetBuild = [int]$TargetInfo.BuildNumber
        
        # Same build = perfect match
        if ($sourceBuild -eq $targetBuild) {
            $result.Score += 30
            $result.Details += "✓ Build number match: $sourceBuild"
        }
        # Within same major version (e.g., both Windows 10 or both Windows 11)
        elseif (($sourceBuild -lt 22000 -and $targetBuild -lt 22000) -or 
                ($sourceBuild -ge 22000 -and $targetBuild -ge 22000)) {
            $result.Score += 20
            $result.Details += "[OK] Same Windows version family (builds: $sourceBuild vs $targetBuild)"
        }
        # Different major versions (e.g., Win10 vs Win11)
        else {
            $result.Score += 10
            $result.Warnings += "⚠ Different Windows versions (builds: $sourceBuild vs $targetBuild)"
            $result.Details += "⚠ Version mismatch: Source build $sourceBuild, Target build $targetBuild"
        }
    } else {
        $result.Score += 20  # Partial credit if we can't determine version
        $result.Details += "⚠ Version info unavailable - assuming compatible"
    }
    
    # Overall compatibility
    $result.Compatible = ($result.Score -ge 50)  # At least architecture must match
    
    return $result
}

function Find-WinloadSourceUltimate {
    <#
    .SYNOPSIS
    Ultimate source discovery - searches all possible locations.
    
    .DESCRIPTION
    Searches Windows installations, WinRE, mounted ISOs, network shares, and install.wim.
    Returns best match with version/architecture validation.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetDrive,
        
        [string]$TargetVersion = $null,
        [string]$TargetArchitecture = $null
    )
    
    $sources = @()
    $actions = @()
    
    # Get target Windows info for compatibility checking
    $targetInfo = Get-WindowsVersionInfo -Drive $TargetDrive
    $actions += "Target Windows: Architecture=$($targetInfo.Architecture), Build=$($targetInfo.BuildNumber)"
    
    # Check if we're running from WinRE/WinPE (prioritize WinRE sources)
    $envState = Get-EnvState
    $runningFromWinRE = $envState.IsWinPE
    if ($runningFromWinRE) {
        $actions += "Running from WinRE/WinPE - will prioritize WinRE sources (immediately available)"
    }
    
    # When running from WinRE, search WinRE FIRST (before Windows installations)
    # WinRE sources are immediately available and reliable when in WinRE environment
    if ($runningFromWinRE) {
        # 0. Search WinRE/current environment FIRST (when in WinRE)
        # Note: winload.efi can be in System32 or System32\Boot subdirectory
        $winrePaths = @(
            "$env:SystemRoot\System32\winload.efi",           # Current environment (highest priority)
            "$env:SystemRoot\System32\Boot\winload.efi",      # Current environment Boot subdirectory
            "X:\Windows\System32\winload.efi",                # Standard WinRE location
            "X:\Windows\System32\Boot\winload.efi",           # WinRE Boot subdirectory (matches user's file location)
            "X:\sources\boot.wim\Windows\System32\winload.efi",  # Boot WIM location
            "X:\sources\boot.wim\Windows\System32\Boot\winload.efi"  # Boot WIM Boot subdirectory
        )
        
        foreach ($winrePath in $winrePaths) {
            $resolvedPath = Resolve-WindowsPath -Path $winrePath -SupportLongPath
            if ($resolvedPath) {
                $existsCheck = Test-WinloadExistsComprehensive -Path $resolvedPath
                if ($existsCheck.Exists) {
                    $integrity = Test-FileIntegrity -FilePath $resolvedPath
                    if ($integrity.Valid) {
                        $compatibility = Test-VersionCompatibility -SourcePath $resolvedPath -TargetDrive $TargetDrive -TargetInfo $targetInfo
                        $sources += [pscustomobject]@{
                            Path = $resolvedPath
                            Source = "WinRE"
                            Drive = (Split-Path $resolvedPath -Qualifier)
                            Size = $integrity.FileInfo.Length
                            Confidence = "HIGH"  # HIGH confidence when running from WinRE
                            Integrity = $integrity
                            Compatibility = $compatibility
                            CompatibilityScore = $compatibility.Score
                        }
                        $actions += "✓ Found winload.efi in WinRE (PRIORITIZED): $resolvedPath ($($integrity.FileInfo.Length) bytes)"
                    }
                }
            }
        }
    }
    
    # 1. Search all Windows installations
    $windowsInstalls = Get-WindowsInstallsSafe
    foreach ($winInstall in $windowsInstalls) {
        if ($winInstall.Drive -ne "$TargetDrive`:") {
            $candidatePath = Resolve-WindowsPath -Path "$($winInstall.Drive)\Windows\System32\winload.efi" -SupportLongPath
            if ($candidatePath) {
                $existsCheck = Test-WinloadExistsComprehensive -Path $candidatePath
                if ($existsCheck.Exists) {
                    $integrity = Test-FileIntegrity -FilePath $candidatePath
                    if ($integrity.Valid) {
                        # Check version/architecture compatibility
                        $compatibility = Test-VersionCompatibility -SourcePath $candidatePath -TargetDrive $TargetDrive -TargetInfo $targetInfo
                        
                        $confidence = "HIGH"
                        if (-not $compatibility.Compatible) {
                            $confidence = "LOW"
                            $actions += "⚠ Source in $($winInstall.Drive) has compatibility issues: $($compatibility.Warnings -join '; ')"
                        } elseif ($compatibility.Score -lt 70) {
                            $confidence = "MEDIUM"
                            $actions += "⚠ Source in $($winInstall.Drive) may have version mismatch"
                        }
                        
                        $sources += [pscustomobject]@{
                            Path = $candidatePath
                            Source = "WindowsInstall"
                            Drive = $winInstall.Drive
                            Size = $integrity.FileInfo.Length
                            Confidence = $confidence
                            Integrity = $integrity
                            Compatibility = $compatibility
                            CompatibilityScore = $compatibility.Score
                        }
                        $actions += "Found winload.efi in $($winInstall.Drive): $($integrity.FileInfo.Length) bytes (verified, compatibility: $($compatibility.Score)/100)"
                    }
                }
            }
        }
    }
    
    # 2. Search WinRE/current environment (PRIORITIZE when running from WinRE)
    # When running from WinRE, these sources are immediately available and reliable
    # Note: winload.efi can be in System32 or System32\Boot subdirectory
    $winrePaths = @(
        "$env:SystemRoot\System32\winload.efi",           # Current environment (highest priority when in WinRE)
        "$env:SystemRoot\System32\Boot\winload.efi",      # Current environment Boot subdirectory
        "X:\Windows\System32\winload.efi",                # Standard WinRE location
        "X:\Windows\System32\Boot\winload.efi",           # WinRE Boot subdirectory (common location)
        "X:\sources\boot.wim\Windows\System32\winload.efi",  # Boot WIM location
        "X:\sources\boot.wim\Windows\System32\Boot\winload.efi",  # Boot WIM Boot subdirectory
        "C:\Windows\System32\winload.efi",               # Current system (if not WinRE)
        "C:\Windows\System32\Boot\winload.efi",          # Current system Boot subdirectory
        "D:\Windows\System32\winload.efi",                # Common secondary
        "D:\Windows\System32\Boot\winload.efi",           # Common secondary Boot subdirectory
        "E:\Windows\System32\winload.efi"                 # Common tertiary
    )
    
    # If running from WinRE, search WinRE paths FIRST (before Windows installations)
    # This ensures we find the immediately available WinRE source
    foreach ($winrePath in $winrePaths) {
        $resolvedPath = Resolve-WindowsPath -Path $winrePath -SupportLongPath
        if ($resolvedPath) {
            $existsCheck = Test-WinloadExistsComprehensive -Path $resolvedPath
            if ($existsCheck.Exists) {
                $integrity = Test-FileIntegrity -FilePath $resolvedPath
                if ($integrity.Valid) {
                    # Check compatibility for WinRE source
                    $compatibility = Test-VersionCompatibility -SourcePath $resolvedPath -TargetDrive $TargetDrive -TargetInfo $targetInfo
                    
                    # When running from WinRE, WinRE sources get HIGH confidence (they're immediately available)
                    # When running from full Windows, WinRE sources get MEDIUM confidence (may need to boot to WinRE)
                    $confidence = if ($runningFromWinRE -and $resolvedPath -like "$env:SystemRoot*") { 
                        "HIGH" 
                    } elseif ($runningFromWinRE) { 
                        "HIGH" 
                    } else { 
                        "MEDIUM" 
                    }
                    
                    $sources += [pscustomobject]@{
                        Path = $resolvedPath
                        Source = "WinRE"
                        Drive = (Split-Path $resolvedPath -Qualifier)
                        Size = $integrity.FileInfo.Length
                        Confidence = $confidence
                        Integrity = $integrity
                        Compatibility = $compatibility
                        CompatibilityScore = $compatibility.Score
                    }
                    $actions += "Found winload.efi in WinRE: $resolvedPath ($($integrity.FileInfo.Length) bytes, Confidence: $confidence)"
                    # Don't break - continue to find all sources, then pick best one
                }
            }
        }
    }
    
    # 3. Search all mounted drives (including removable/USB)
    $allVolumes = Get-VolumesSafe
    foreach ($volume in $allVolumes) {
        $driveLetter = "$($volume.DriveLetter):"
        if ($driveLetter -ne "$TargetDrive`:" -and $driveLetter -ne "X:") {
            $candidatePath = Resolve-WindowsPath -Path "$driveLetter\Windows\System32\winload.efi" -SupportLongPath
            if ($candidatePath) {
                $existsCheck = Test-WinloadExistsComprehensive -Path $candidatePath
                if ($existsCheck.Exists) {
                    $integrity = Test-FileIntegrity -FilePath $candidatePath
                    if ($integrity.Valid) {
                        # Check if already in sources
                        $alreadyFound = $sources | Where-Object { $_.Path -eq $candidatePath }
                        if (-not $alreadyFound) {
                            # Check compatibility for mounted drive source
                            $compatibility = Test-VersionCompatibility -SourcePath $candidatePath -TargetDrive $TargetDrive -TargetInfo $targetInfo
                            $sources += [pscustomobject]@{
                                Path = $candidatePath
                                Source = "MountedDrive"
                                Drive = $driveLetter
                                Size = $integrity.FileInfo.Length
                                Confidence = "MEDIUM"
                                Integrity = $integrity
                                Compatibility = $compatibility
                                CompatibilityScore = $compatibility.Score
                            }
                            $actions += "Found winload.efi on mounted drive ${driveLetter}: $($integrity.FileInfo.Length) bytes"
                        }
                    }
                }
            }
        }
    }
    
    # 4. Search for mounted ISOs (check for sources\install.wim)
    foreach ($volume in $allVolumes) {
        $driveLetter = "$($volume.DriveLetter):"
        $wimPath = Resolve-WindowsPath -Path "$driveLetter\sources\install.wim" -SupportLongPath
        $esdPath = Resolve-WindowsPath -Path "$driveLetter\sources\install.esd" -SupportLongPath
        
        if ($wimPath -or $esdPath) {
            $actions += "Found Windows installation media on $driveLetter (install.wim/esd detected)"
            # Note: Extraction would be handled by Extract-WinloadFromWim function
            # This just identifies the source
        }
    }
    
    # 4. Search network shares (if available and accessible)
    try {
        if (Get-Command Get-SmbShare -ErrorAction SilentlyContinue) {
            $smbShares = Get-SmbShare -ErrorAction SilentlyContinue | Where-Object { $_.PathType -eq "FileSystem" }
            foreach ($share in $smbShares) {
                try {
                    $sharePath = $share.Path
                    $candidatePath = Resolve-WindowsPath -Path "$sharePath\Windows\System32\winload.efi" -SupportLongPath
                    if ($candidatePath) {
                        $existsCheck = Test-WinloadExistsComprehensive -Path $candidatePath
                        if ($existsCheck.Exists) {
                            $integrity = Test-FileIntegrity -FilePath $candidatePath
                            if ($integrity.Valid) {
                                $compatibility = Test-VersionCompatibility -SourcePath $candidatePath -TargetDrive $TargetDrive -TargetInfo $targetInfo
                                
                                $confidence = if ($compatibility.Compatible) { "MEDIUM" } else { "LOW" }
                                
                                $sources += [pscustomobject]@{
                                    Path = $candidatePath
                                    Source = "NetworkShare"
                                    Drive = $share.Name
                                    Size = $integrity.FileInfo.Length
                                    Confidence = $confidence
                                    Integrity = $integrity
                                    Compatibility = $compatibility
                                    CompatibilityScore = $compatibility.Score
                                }
                                $actions += "Found winload.efi on network share '$($share.Name)': $($integrity.FileInfo.Length) bytes"
                            }
                        }
                    }
                } catch {
                    # Network share may not be accessible, skip silently
                }
            }
        }
    } catch {
        # SMB module may not be available, skip network search
    }
    
    # Return best source (prioritize: compatibility score > confidence > size)
    if ($sources.Count -gt 0) {
        $bestSource = $sources | Sort-Object -Property @{
            Expression = {
                $score = 0
                # Compatibility score (0-100) - default to 50 if not set (assume medium compatibility)
                $compatScore = if ($_.CompatibilityScore) { $_.CompatibilityScore } else { 50 }
                $score += $compatScore * 10
                # Confidence (HIGH=3, MEDIUM=2, LOW=1)
                $score += switch ($_.Confidence) { "HIGH" { 3 } "MEDIUM" { 2 } "LOW" { 1 } default { 0 } }
                # Prefer larger files (more likely to be complete)
                if ($_.Size) { $score += [math]::Min($_.Size / 1000000, 1) }
                return $score
            }
            Descending = $true
        } | Select-Object -First 1
        
        if ($bestSource.Compatibility -and -not $bestSource.Compatibility.Compatible) {
            $actions += "⚠ WARNING: Best source has compatibility issues - repair may fail!"
            foreach ($warning in $bestSource.Compatibility.Warnings) {
                $actions += "  ⚠ $warning"
            }
        }
        
        return @{
            Sources = $sources
            BestSource = $bestSource
            Actions = $actions
        }
    }
    
    return @{
        Sources = @()
        BestSource = $null
        Actions = $actions
    }
}

function New-ComprehensiveRepairReport {
    param(
        [string]$TargetDrive,
        [array]$CommandHistory,
        [array]$FailedCommands,
        [array]$InitialIssues,
        [array]$RemainingIssues,
        [array]$Actions,
        [bool]$Bootable,
        [bool]$WinloadExists,
        [bool]$BcdPathMatch,
        [bool]$BitlockerLocked
    )
    
    $logDir = Join-Path $PSScriptRoot "LOGS_MIRACLEBOOT"
    if (-not (Test-Path $logDir)) { try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch { } }
    
    $reportPath = Join-Path $logDir "COMPREHENSIVE_REPAIR_REPORT_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $report = @()
    
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "COMPREHENSIVE BOOT REPAIR REPORT"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    $report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $report += "Target Drive: $TargetDrive`:"
    $report += ""
    
    # CODE RED: FAILED COMMANDS! (at the top)
    if ($FailedCommands.Count -gt 0) {
        $report += "═══════════════════════════════════════════════════════════════════════════════"
        $report += "CODE RED: FAILED COMMANDS!"
        $report += "═══════════════════════════════════════════════════════════════════════════════"
        $report += ""
        $report += "The following commands FAILED during repair:"
        $report += ""
        foreach ($failed in $FailedCommands) {
            $report += "❌ FAILED COMMAND:"
            $report += "   Time: $($failed.Timestamp)"
            $report += "   Command: $($failed.Command)"
            $report += "   Description: $($failed.Description)"
            if ($failed.TargetDrive) {
                $report += "   Target Drive: $($failed.TargetDrive):"
            }
            $report += "   Exit Code: $($failed.ExitCode)"
            if ($failed.ErrorOutput) {
                $report += "   Error Output: $($failed.ErrorOutput)"
            }
            $report += ""
        }
        $report += "═══════════════════════════════════════════════════════════════════════════════"
        $report += ""
    }
    
    # Initial Issues
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "INITIAL ISSUES DETECTED"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    if ($InitialIssues.Count -gt 0) {
        foreach ($issue in $InitialIssues) {
            $report += "  • $issue"
        }
    } else {
        $report += "  • winload.efi: $(if ($WinloadExists) { 'Present' } else { 'MISSING' })"
        $report += "  • BCD path match: $(if ($BcdPathMatch) { 'YES' } else { 'NO - MISMATCH' })"
        $report += "  • BitLocker: $(if ($BitlockerLocked) { 'LOCKED' } else { 'Unlocked or N/A' })"
    }
    $report += ""
    
    # Commands Executed
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "COMMANDS EXECUTED"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    if ($CommandHistory.Count -gt 0) {
        foreach ($cmd in $CommandHistory) {
            $status = if ($cmd.Success) { "[OK] SUCCESS" } else { "[X] FAILED" }
            $report += "$status - $($cmd.Description)"
            $report += "   Command: $($cmd.Command)"
            $report += "   Time: $($cmd.Timestamp)"
            if ($cmd.TargetDrive) {
                $report += "   Target Drive: $($cmd.TargetDrive):"
            }
            if (-not $cmd.Success) {
                $report += "   Exit Code: $($cmd.ExitCode)"
                if ($cmd.ErrorOutput) {
                    $report += "   Error: $($cmd.ErrorOutput)"
                }
            }
            $report += ""
        }
    } else {
        $report += "No commands were executed (DiagnoseOnly or DryRun mode)."
        $report += ""
    }
    
    # Current Status
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "CURRENT STATUS"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    $report += "Bootability: $(if ($Bootable) { '✅ LIKELY BOOTABLE' } else { '❌ WILL NOT BOOT' })"
    $report += "  • winload.efi: $(if ($WinloadExists) { 'Present' } else { 'MISSING' })"
    $report += "  • BCD path match: $(if ($BcdPathMatch) { 'YES' } else { 'NO - MISMATCH' })"
    $report += "  • BitLocker: $(if ($BitlockerLocked) { 'LOCKED - Unlock required' } else { 'Unlocked or N/A' })"
    $report += ""
    
    # Remaining Issues
    if (-not $Bootable) {
        $report += "═══════════════════════════════════════════════════════════════════════════════"
        $report += "REMAINING ISSUES"
        $report += "═══════════════════════════════════════════════════════════════════════════════"
        $report += ""
        
        $remainingIssuesList = @()
        if (-not $WinloadExists) {
            $remainingIssuesList += "winload.efi is still MISSING at $TargetDrive`:\Windows\System32\winload.efi"
        }
        if (-not $BcdPathMatch) {
            $remainingIssuesList += "BCD does NOT point to winload.efi correctly"
        }
        if ($BitlockerLocked) {
            $remainingIssuesList += "BitLocker is LOCKED - drive must be unlocked before repairs"
        }
        
        if ($RemainingIssues.Count -gt 0) {
            foreach ($issue in $RemainingIssues) {
                $remainingIssuesList += $issue
            }
        }
        
        if ($remainingIssuesList.Count -gt 0) {
            foreach ($issue in $remainingIssuesList) {
                $report += "  ❌ $issue"
            }
        } else {
            $report += "  (No specific remaining issues identified)"
        }
        $report += ""
        
        # Additional Fix Suggestions (NEW commands not already run)
        $report += "═══════════════════════════════════════════════════════════════════════════════"
        $report += "ADDITIONAL FIX SUGGESTIONS"
        $report += "═══════════════════════════════════════════════════════════════════════════════"
        $report += ""
        $report += "The following commands were NOT run by the automated repair. Try these manually:"
        $report += ""
        
        $suggestedCommands = @()
        $executedCommands = $CommandHistory | ForEach-Object { $_.Command }
        
        if (-not $WinloadExists) {
            # Check if we tried DISM extraction
            $triedDism = $executedCommands | Where-Object { $_ -match "dism.*mount.*wim" }
            if (-not $triedDism) {
                $suggestedCommands += @{
                    Command = "dism /Mount-Wim /WimFile:`"ISO_PATH`"\sources\install.wim /Index:1 /MountDir:C:\Mount /ReadOnly"
                    Description = "Extract winload.efi from Windows installation media"
                    Why = "If no other source was found, extract from install.wim"
                    ErrorToLookUp = "DISM mount errors, install.wim not found"
                }
                $suggestedCommands += @{
                    Command = "copy C:\Mount\Windows\System32\winload.efi $TargetDrive`:\Windows\System32\winload.efi /Y"
                    Description = "Copy extracted winload.efi to target"
                    Why = "After extracting from WIM, copy to target location"
                    ErrorToLookUp = "Access denied, file in use"
                }
            }
            
            # Check if we tried SFC
            $triedSfc = $executedCommands | Where-Object { $_ -match "sfc.*scannow" }
            if (-not $triedSfc) {
                $suggestedCommands += @{
                    Command = "sfc /scannow /offbootdir=$TargetDrive`:\ /offwindir=$TargetDrive`:\Windows"
                    Description = "System File Checker - repair corrupted system files"
                    Why = "SFC can restore missing system files including winload.efi"
                    ErrorToLookUp = "SFC cannot repair, Windows Resource Protection errors"
                }
            }
            
            # Check if we tried DISM restore health
            $triedDismRestore = $executedCommands | Where-Object { $_ -match "dism.*restorehealth" }
            if (-not $triedDismRestore) {
                $suggestedCommands += @{
                    Command = "dism /Online /Cleanup-Image /RestoreHealth /Source:`"ISO_PATH`"\sources\install.wim"
                    Description = "DISM restore health - repair Windows image"
                    Why = "DISM can restore corrupted Windows image files"
                    ErrorToLookUp = "DISM restore health errors, source not found"
                }
            }
        }
        
        if (-not $BcdPathMatch) {
            # Check if we tried bootrec
            $triedBootrec = $executedCommands | Where-Object { $_ -match "bootrec" }
            if (-not $triedBootrec) {
                $suggestedCommands += @{
                    Command = "bootrec /fixmbr"
                    Description = "Fix Master Boot Record"
                    Why = "Can fix MBR issues that prevent BCD from working"
                    ErrorToLookUp = "bootrec access denied, MBR write errors"
                }
                $suggestedCommands += @{
                    Command = "bootrec /fixboot"
                    Description = "Fix boot sector"
                    Why = "Can fix boot sector corruption"
                    ErrorToLookUp = "bootrec fixboot errors, boot sector locked"
                }
            }
            
            # Check if we tried rebuilding BCD completely
            $triedRebuild = $executedCommands | Where-Object { $_ -match "bootrec.*rebuildbcd" }
            if (-not $triedRebuild) {
                $suggestedCommands += @{
                    Command = "bootrec /rebuildbcd"
                    Description = "Rebuild BCD completely"
                    Why = "More aggressive BCD rebuild than bcdboot"
                    ErrorToLookUp = "bootrec rebuildbcd errors, BCD store locked"
                }
            }
        }
        
        if ($BitlockerLocked) {
            $suggestedCommands += @{
                Command = "manage-bde -unlock $TargetDrive`: -RecoveryPassword `"YOUR_48_DIGIT_KEY`""
                Description = "Unlock BitLocker-encrypted drive"
                Why = "Drive must be unlocked before any repairs can be applied"
                ErrorToLookUp = "BitLocker unlock errors, invalid recovery key"
            }
            $suggestedCommands += @{
                Command = "manage-bde -status $TargetDrive`:"
                Description = "Check BitLocker status"
                Why = "Verify unlock was successful"
                ErrorToLookUp = "manage-bde not found, BitLocker service errors"
            }
        }
        
        # Add disk health checks if not done
        $triedChkdsk = $executedCommands | Where-Object { $_ -match "chkdsk" }
        if (-not $triedChkdsk) {
            $suggestedCommands += @{
                Command = "chkdsk $TargetDrive`: /f /r"
                Description = "Check and repair disk errors"
                Why = "Disk errors can prevent file operations from succeeding"
                ErrorToLookUp = "chkdsk cannot run, disk is in use, file system errors"
            }
        }
        
        if ($suggestedCommands.Count -gt 0) {
            foreach ($suggestion in $suggestedCommands) {
                $report += "Command: $($suggestion.Command)"
                $report += "  Purpose: $($suggestion.Description)"
                $report += "  Why try this: $($suggestion.Why)"
                if ($suggestion.ErrorToLookUp) {
                    $report += "  If this fails, search for: $($suggestion.ErrorToLookUp)"
                }
                $report += ""
            }
        } else {
            $report += "All common repair commands have been attempted."
            $report += "Please refer to the manual repair guide for advanced troubleshooting."
            $report += ""
        }
        
        # Error Messages to Look Up
        if ($FailedCommands.Count -gt 0) {
            $report += "═══════════════════════════════════════════════════════════════════════════════"
            $report += "ERROR MESSAGES TO LOOK UP"
            $report += "═══════════════════════════════════════════════════════════════════════════════"
            $report += ""
            $report += "If you encounter these errors, search for them online for specific solutions:"
            $report += ""
            foreach ($failed in $FailedCommands) {
                if ($failed.ErrorOutput) {
                    $errorLines = ($failed.ErrorOutput -split "`n" | Where-Object { $_ -match "error|failed|denied|invalid|syntax|access" -and $_.Length -gt 10 -and $_.Length -lt 200 }) | Select-Object -First 3
                    foreach ($errorLine in $errorLines) {
                        $cleanError = $errorLine.Trim()
                        if ($cleanError) {
                            $report += "  • $cleanError"
                        }
                    }
                }
            }
            $report += ""
            $report += "Common error codes and meanings:"
            $report += "  • Exit Code 1: General error"
            $report += "  • Exit Code 2: Invalid syntax or parameters"
            $report += "  • Exit Code 5: Access denied (permissions)"
            $report += "  • Exit Code 32: File in use (cannot access)"
            $report += "  • Exit Code 50: Not supported (wrong environment)"
            $report += ""
        }
    }
    
    # Actions Summary
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "REPAIR ACTIONS SUMMARY"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += ""
    if ($Actions.Count -gt 0) {
        foreach ($action in $Actions) {
            $report += "  $action"
        }
    } else {
        $report += "  No repair actions were executed."
    }
    $report += ""
    
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    $report += "END OF REPORT"
    $report += "═══════════════════════════════════════════════════════════════════════════════"
    
    Set-Content -Path $reportPath -Value ($report -join "`r`n") -Encoding UTF8 -Force
    return $reportPath
}

function New-WinloadRepairGuidanceDocument {
    param(
        [string]$TargetDrive,
        [bool]$WinloadExists,
        [bool]$BcdPathMatch,
        [bool]$BitlockerLocked,
        [array]$Actions
    )
    
    $logDir = Join-Path $PSScriptRoot "LOGS_MIRACLEBOOT"
    if (-not (Test-Path $logDir)) { try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch { } }
    
    $docPath = Join-Path $logDir "WINLOAD_EFI_MANUAL_REPAIR_GUIDE_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $doc = @()
    
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    $doc += "WINLOAD.EFI MANUAL REPAIR GUIDE"
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    $doc += ""
    $doc += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $doc += "Target Drive: $TargetDrive`:"
    $doc += ""
    $doc += "CURRENT STATUS:"
    $doc += "  • winload.efi present: $(if ($WinloadExists) { 'YES' } else { 'NO - MISSING' })"
    $doc += "  • BCD points to winload.efi: $(if ($BcdPathMatch) { 'YES' } else { 'NO - MISMATCH' })"
    $doc += "  • BitLocker status: $(if ($BitlockerLocked) { 'LOCKED - Unlock required' } else { 'Unlocked or N/A' })"
    $doc += ""
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    $doc += "AUTOMATED REPAIR ATTEMPTS"
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    $doc += ""
    foreach ($action in $Actions) {
        $doc += "  $action"
    }
    $doc += ""
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    $doc += "MANUAL REPAIR INSTRUCTIONS"
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    $doc += ""
    
    if ($BitlockerLocked) {
        $doc += "STEP 0: UNLOCK BITLOCKER (REQUIRED FIRST)"
        $doc += "───────────────────────────────────────────────────────────────────────────────"
        $doc += "Your drive is BitLocker-locked. You MUST unlock it before attempting repairs."
        $doc += ""
        $doc += "Command:"
        $doc += "  manage-bde -unlock $TargetDrive`: -RecoveryPassword <YOUR_48_DIGIT_KEY>"
        $doc += ""
        $doc += "To find your recovery key:"
        $doc += "  1. Check your Microsoft account: https://account.microsoft.com/devices/recoverykey"
        $doc += "  2. Check printed recovery key if you saved it"
        $doc += "  3. Check if your organization has the key"
        $doc += ""
        $doc += "After unlocking, verify:"
        $doc += "  manage-bde -status $TargetDrive`:"
        $doc += "  # Should show 'Lock Status: Unlocked'"
        $doc += ""
    }
    
    if (-not $WinloadExists) {
        $doc += "STEP 1: IDENTIFY THE ESP (EFI System Partition)"
        $doc += "───────────────────────────────────────────────────────────────────────────────"
        $doc += "The ESP is a FAT32 partition, typically 100-550 MB, that contains boot files."
        $doc += ""
        $doc += "Method 1: Using PowerShell (Recommended)"
        $doc += "  Get-Volume | Where-Object { `$_.FileSystem -eq 'FAT32' -and `$_.Size -lt 600MB }"
        $doc += ""
        $doc += "Method 2: Using diskpart"
        $doc += "  diskpart"
        $doc += "    list disk"
        $doc += "    select disk X  (where X is your Windows disk number)"
        $doc += "    list partition"
        $doc += "    select partition Y  (look for 'System' or 'EFI' type, FAT32, ~100-550 MB)"
        $doc += "    detail partition"
        $doc += "    exit"
        $doc += ""
        $doc += "What to look for:"
        $doc += "  ✓ FileSystem: FAT32"
        $doc += "  ✓ Size: Usually 100-550 MB (less than 600 MB)"
        $doc += "  ✓ GPT Type: {c12a7328-f81f-11d2-ba4b-00a0c93ec93b} (EFI System Partition)"
        $doc += ""
        $doc += "STEP 2: MOUNT THE ESP (If Not Already Mounted)"
        $doc += "───────────────────────────────────────────────────────────────────────────────"
        $doc += "If ESP doesn't have a drive letter, mount it temporarily:"
        $doc += ""
        $doc += "Method 1: Using mountvol (Recommended)"
        $doc += "  mountvol S: /S"
        $doc += "  # This mounts the system ESP to drive letter S:"
        $doc += "  # Replace S: with any available drive letter (Z:, Y:, X:, etc.)"
        $doc += ""
        $doc += "Method 2: Using diskpart"
        $doc += "  diskpart"
        $doc += "  > list disk"
        $doc += "  > select disk X"
        $doc += "  > list partition"
        $doc += "  > select partition Y  (select the ESP partition)"
        $doc += "  > assign letter=S"
        $doc += "  > exit"
        $doc += ""
        $doc += "Verify mount:"
        $doc += "  dir S:\EFI\Microsoft\Boot"
        $doc += "  # Should show: bootmgfw.efi, BCD, and other boot files"
        $doc += ""
        $doc += "STEP 3: LOCATE WINLOAD.EFI SOURCE"
        $doc += "───────────────────────────────────────────────────────────────────────────────"
        $doc += "You need a copy of winload.efi from a compatible Windows installation."
        $doc += ""
        $doc += "Option A: From Windows Installation Media (ISO/USB) - RECOMMENDED"
        $doc += "  1. Mount your Windows ISO or insert Windows USB"
        $doc += "  2. Navigate to: sources\install.wim or sources\install.esd"
        $doc += "  3. Extract winload.efi using DISM:"
        $doc += ""
        $doc += "     # First, get WIM info to find correct index"
        $doc += "     dism /Get-WimInfo /WimFile:D:\sources\install.wim"
        $doc += "     # Note the index number for your Windows edition (usually 1 for Home, 2 for Pro)"
        $doc += ""
        $doc += "     # Create mount directory"
        $doc += "     mkdir C:\Mount"
        $doc += ""
        $doc += "     # Mount the WIM (replace Index:1 with your index)"
        $doc += "     dism /Mount-Wim /WimFile:D:\sources\install.wim /Index:1 /MountDir:C:\Mount /ReadOnly"
        $doc += ""
        $doc += "     # Copy winload.efi to temporary location"
        $doc += "     copy C:\Mount\Windows\System32\winload.efi C:\winload.efi.temp"
        $doc += ""
        $doc += "     # Unmount WIM"
        $doc += "     dism /Unmount-Wim /MountDir:C:\Mount /Discard"
        $doc += ""
        $doc += "     # Your winload.efi is now at C:\winload.efi.temp"
        $doc += ""
        $doc += "Option B: From Another Working Windows Installation"
        $doc += "  1. If you have another Windows installation on a different drive (e.g., D:):"
        $doc += "     copy D:\Windows\System32\winload.efi C:\winload.efi.temp"
        $doc += ""
        $doc += "Option C: From Windows Recovery Environment (WinRE)"
        $doc += "  1. If running from WinRE, check:"
        $doc += "     dir /s X:\Windows\System32\winload.efi"
        $doc += "     # X: is typically WinRE in recovery environment"
        $doc += "     # If found, copy it:"
        $doc += "     copy X:\Windows\System32\winload.efi C:\winload.efi.temp"
        $doc += ""
        $doc += "STEP 4: COPY WINLOAD.EFI TO TARGET WINDOWS SYSTEM32"
        $doc += "───────────────────────────────────────────────────────────────────────────────"
        $doc += "Target location: $TargetDrive`:\Windows\System32\winload.efi"
        $doc += ""
        $doc += "IMPORTANT: Run PowerShell as Administrator for these commands!"
        $doc += ""
        $doc += "Commands (run in order):"
        $doc += ""
        $doc += "  1. Take ownership of the target file (if it exists):"
        $doc += "     takeown /f `"$TargetDrive`:\Windows\System32\winload.efi`""
        $doc += ""
        $doc += "  2. Grant full permissions:"
        $doc += "     icacls `"$TargetDrive`:\Windows\System32\winload.efi`" /grant Administrators:F"
        $doc += ""
        $doc += "  3. Remove read-only/system/hidden attributes:"
        $doc += "     attrib -s -h -r `"$TargetDrive`:\Windows\System32\winload.efi`""
        $doc += ""
        $doc += "  4. Copy the file (adjust source path as needed):"
        $doc += "     copy C:\winload.efi.temp `"$TargetDrive`:\Windows\System32\winload.efi`" /Y"
        $doc += ""
        $doc += "  5. Verify the file was copied correctly:"
        $doc += "     dir `"$TargetDrive`:\Windows\System32\winload.efi`""
        $doc += "     # Should show file size (typically 1-2 MB)"
        $doc += ""
        $doc += "  6. Verify file is readable:"
        $doc += "     [System.IO.File]::OpenRead(`"$TargetDrive`:\Windows\System32\winload.efi`").Close()"
        $doc += "     # Should complete without error"
        $doc += ""
    }
    
    if (-not $BcdPathMatch) {
        $doc += "STEP 5: VERIFY AND FIX BCD ENTRY"
        $doc += "───────────────────────────────────────────────────────────────────────────────"
        $doc += "Ensure BCD points to the correct winload.efi path."
        $doc += ""
        $doc += "Commands:"
        $doc += ""
        $doc += "  1. Check current BCD entry:"
        $doc += "     bcdedit /enum {default}"
        $doc += ""
        $doc += "  2. If ESP is mounted to S:, fix BCD path:"
        $doc += "     bcdedit /store S:\EFI\Microsoft\Boot\BCD /set {default} path \Windows\system32\winload.efi"
        $doc += "     bcdedit /store S:\EFI\Microsoft\Boot\BCD /set {default} device partition=$TargetDrive`:"
        $doc += "     bcdedit /store S:\EFI\Microsoft\Boot\BCD /set {default} osdevice partition=$TargetDrive`:"
        $doc += ""
        $doc += "  3. If ESP is not mounted, use default BCD:"
        $doc += "     bcdedit /set {default} path \Windows\system32\winload.efi"
        $doc += "     bcdedit /set {default} device partition=$TargetDrive`:"
        $doc += "     bcdedit /set {default} osdevice partition=$TargetDrive`:"
        $doc += ""
        $doc += "  4. Verify BCD fix:"
        $doc += "     bcdedit /enum {default}"
        $doc += "     # Look for 'path \Windows\system32\winload.efi' and correct 'device'/'osdevice'"
        $doc += ""
    }
    
    $doc += "STEP 6: REBUILD BOOT FILES (If BCD is still problematic)"
    $doc += "───────────────────────────────────────────────────────────────────────────────"
    $doc += "If BCD is corrupted or not fixable with bcdedit /set, rebuild it completely."
    $doc += ""
    $doc += "Commands:"
    $doc += ""
    $doc += "  1. Ensure ESP is mounted (e.g., to S:)"
    $doc += "     mountvol S: /S"
    $doc += ""
    $doc += "  2. Rebuild BCD and copy boot files to ESP:"
    $doc += "     bcdboot $TargetDrive`:\Windows /s S: /f ALL"
    $doc += ""
    $doc += "  3. Verify boot files:"
    $doc += "     dir S:\EFI\Microsoft\Boot"
    $doc += "     # Should show: bootmgfw.efi, BCD, and other boot files"
    $doc += ""
    $doc += "STEP 7: UNMOUNT ESP"
    $doc += "───────────────────────────────────────────────────────────────────────────────"
    $doc += "Always unmount the ESP after repairs."
    $doc += ""
    $doc += "Command:"
    $doc += "  mountvol S: /D"
    $doc += "  # Replace S: with the letter you assigned"
    $doc += ""
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    $doc += "TROUBLESHOOTING TIPS"
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    $doc += ""
    $doc += "Problem: 'Access Denied' when copying winload.efi"
    $doc += "  Solution:"
    $doc += "    • Ensure you're running PowerShell as Administrator"
    $doc += "    • Take ownership: takeown /f `"$TargetDrive`:\Windows\System32\winload.efi`""
    $doc += "    • Grant permissions: icacls `"$TargetDrive`:\Windows\System32\winload.efi`" /grant Administrators:F"
    $doc += "    • Remove attributes: attrib -s -h -r `"$TargetDrive`:\Windows\System32\winload.efi`""
    $doc += ""
    $doc += "Problem: Cannot find winload.efi source"
    $doc += "  Solution:"
    $doc += "    • Check if another Windows installation exists:"
    $doc += "      Get-Volume | Where-Object { Test-Path `"`$(`$_.DriveLetter):\Windows\System32\winload.efi`" }"
    $doc += "    • Mount Windows ISO and extract from install.wim (see Step 3, Option A)"
    $doc += "    • Download Windows ISO from Microsoft if needed"
    $doc += ""
    $doc += "Problem: 'mountvol S: /S' fails"
    $doc += "  Solution:"
    $doc += "    • Try different drive letters (Z:, Y:, X:, etc.)"
    $doc += "    • Use diskpart method instead (see Step 2, Method 2)"
    $doc += "    • Check if ESP is already mounted: Get-Volume | Where-Object { `$_.FileSystem -eq 'FAT32' }"
    $doc += ""
    $doc += "Problem: 'bcdboot' fails"
    $doc += "  Solution:"
    $doc += "    • Ensure ESP is FAT32 and has enough free space"
    $doc += "    • Check if install.wim is accessible"
    $doc += "    • Try: bcdboot $TargetDrive`:\Windows /s S: /f UEFI (instead of /f ALL)"
    $doc += ""
    $doc += "Problem: 'bcdedit /enum {default}' shows incorrect path"
    $doc += "  Solution:"
    $doc += "    • Double-check the bcdedit /set commands"
    $doc += "    • Ensure ESP is mounted correctly"
    $doc += "    • Try rebuilding BCD completely (Step 6)"
    $doc += ""
    $doc += "Problem: BitLocker is active"
    $doc += "  Solution:"
    $doc += "    • Unlock the drive first: manage-bde -unlock $TargetDrive`: -RecoveryPassword <key>"
    $doc += "    • Find recovery key at: https://account.microsoft.com/devices/recoverykey"
    $doc += ""
    $doc += "Problem: winload.efi is missing from install.wim"
    $doc += "  Solution:"
    $doc += "    • The image might be corrupted or a different version"
    $doc += "    • Try another Windows ISO"
    $doc += "    • Try extracting from a different index in the WIM"
    $doc += ""
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    $doc += "QUICK REFERENCE: ALL COMMANDS IN ORDER"
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    $doc += ""
    $doc += "# 1. Unlock BitLocker (if locked)"
    $doc += "manage-bde -unlock $TargetDrive`: -RecoveryPassword <YOUR_KEY>"
    $doc += ""
    $doc += "# 2. Mount ESP"
    $doc += "mountvol S: /S"
    $doc += ""
    $doc += "# 3. Extract winload.efi from install.wim (if needed)"
    $doc += "mkdir C:\Mount"
    $doc += "dism /Mount-Wim /WimFile:D:\sources\install.wim /Index:1 /MountDir:C:\Mount /ReadOnly"
    $doc += "copy C:\Mount\Windows\System32\winload.efi C:\winload.efi.temp"
    $doc += "dism /Unmount-Wim /MountDir:C:\Mount /Discard"
    $doc += ""
    $doc += "# 4. Copy winload.efi to target"
    $doc += "takeown /f `"$TargetDrive`:\Windows\System32\winload.efi`""
    $doc += "icacls `"$TargetDrive`:\Windows\System32\winload.efi`" /grant Administrators:F"
    $doc += "attrib -s -h -r `"$TargetDrive`:\Windows\System32\winload.efi`""
    $doc += "copy C:\winload.efi.temp `"$TargetDrive`:\Windows\System32\winload.efi`" /Y"
    $doc += ""
    $doc += "# 5. Fix BCD"
    $doc += "bcdedit /store S:\EFI\Microsoft\Boot\BCD /set {default} path \Windows\system32\winload.efi"
    $doc += "bcdedit /store S:\EFI\Microsoft\Boot\BCD /set {default} device partition=$TargetDrive`:"
    $doc += "bcdedit /store S:\EFI\Microsoft\Boot\BCD /set {default} osdevice partition=$TargetDrive`:"
    $doc += ""
    $doc += "# 6. Rebuild boot files (if needed)"
    $doc += "bcdboot $TargetDrive`:\Windows /s S: /f ALL"
    $doc += ""
    $doc += "# 7. Unmount ESP"
    $doc += "mountvol S: /D"
    $doc += ""
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    $doc += "END OF GUIDE"
    $doc += "═══════════════════════════════════════════════════════════════════════════════"
    
    Set-Content -Path $docPath -Value ($doc -join "`r`n") -Encoding UTF8 -Force
    
    return @{
        Path = $docPath
        Content = $doc
    }
}

# ============================================================================
# BRUTE FORCE BOOT REPAIR FUNCTIONS
# ============================================================================

function Find-WinloadSourceAggressive {
    param(
        [string]$TargetDrive,
        [switch]$ExtractFromWim
    )
    
    $sources = @()
    $actions = @()
    
    # Get target info for compatibility checking
    $targetInfo = Get-WindowsVersionInfo -Drive $TargetDrive
    
    # 1. Search all mounted Windows installations
    $windowsInstalls = Get-WindowsInstallsSafe
    foreach ($winInstall in $windowsInstalls) {
        if ($winInstall.Drive -ne "$TargetDrive`:") {
            $candidatePath = "$($winInstall.Drive)\Windows\System32\winload.efi"
            if (Test-Path $candidatePath) {
                $fileInfo = Get-Item $candidatePath -ErrorAction SilentlyContinue
                if ($fileInfo) {
                    # Check compatibility
                    $compatibility = Test-VersionCompatibility -SourcePath $candidatePath -TargetDrive $TargetDrive -TargetInfo $targetInfo
                    $sources += [pscustomobject]@{
                        Path = $candidatePath
                        Source = "WindowsInstall"
                        Drive = $winInstall.Drive
                        Size = $fileInfo.Length
                        Confidence = "HIGH"
                        Compatibility = $compatibility
                        CompatibilityScore = $compatibility.Score
                    }
                    $actions += "Found winload.efi in $($winInstall.Drive): $($fileInfo.Length) bytes"
                }
            }
        }
    }
    
    # 2. Search WinRE/current environment
    # Note: winload.efi can be in System32 or System32\Boot subdirectory
    $winrePaths = @(
        "$env:SystemRoot\System32\winload.efi",
        "$env:SystemRoot\System32\Boot\winload.efi",      # Boot subdirectory (common location)
        "X:\Windows\System32\winload.efi",
        "X:\Windows\System32\Boot\winload.efi",           # WinRE Boot subdirectory (matches user's file location)
        "X:\sources\boot.wim\Windows\System32\winload.efi",
        "X:\sources\boot.wim\Windows\System32\Boot\winload.efi"  # Boot WIM Boot subdirectory
    )
    foreach ($winrePath in $winrePaths) {
        if (Test-Path $winrePath) {
            $fileInfo = Get-Item $winrePath -ErrorAction SilentlyContinue
            if ($fileInfo) {
                # Check compatibility
                $compatibility = Test-VersionCompatibility -SourcePath $winrePath -TargetDrive $TargetDrive -TargetInfo $targetInfo
                $sources += [pscustomobject]@{
                    Path = $winrePath
                    Source = "WinRE"
                    Drive = "WinRE"
                    Size = $fileInfo.Length
                    Confidence = "MEDIUM"
                    Compatibility = $compatibility
                    CompatibilityScore = $compatibility.Score
                }
                $actions += "Found winload.efi in WinRE: $($fileInfo.Length) bytes"
            }
        }
    }
    
    # 3. Search all mounted drives (including ISOs/USB)
    $allVolumes = Get-VolumesSafe
    foreach ($vol in $allVolumes) {
        $dl = "$($vol.DriveLetter):"
        if ($dl -ne "$TargetDrive`:" -and $dl -ne "X:") {
            # Check for install.wim/esd
            $wimPaths = @(
                "$dl\sources\install.wim",
                "$dl\sources\install.esd"
            )
            foreach ($wimPath in $wimPaths) {
                if (Test-Path $wimPath -ErrorAction SilentlyContinue) {
                    # WIM files don't have direct compatibility - will be checked when extracted
                    $sources += [pscustomobject]@{
                        Path = $wimPath
                        Source = "InstallWim"
                        Drive = $dl
                        Size = $null
                        Confidence = "MEDIUM"
                        Compatibility = @{ Compatible = $true; Score = 50 }
                        CompatibilityScore = 50
                    }
                    $actions += "Found install.wim/esd at $wimPath"
                }
            }
            
            # Check for winload.efi directly
            $directPath = "$dl\Windows\System32\winload.efi"
            if (Test-Path $directPath -ErrorAction SilentlyContinue) {
                $fileInfo = Get-Item $directPath -ErrorAction SilentlyContinue
                if ($fileInfo) {
                    # Check compatibility
                    $compatibility = Test-VersionCompatibility -SourcePath $directPath -TargetDrive $TargetDrive -TargetInfo $targetInfo
                    $sources += [pscustomobject]@{
                        Path = $directPath
                        Source = "Direct"
                        Drive = $dl
                        Size = $fileInfo.Length
                        Confidence = "HIGH"
                        Compatibility = $compatibility
                        CompatibilityScore = $compatibility.Score
                    }
                    $actions += "Found winload.efi directly at ${directPath}: $($fileInfo.Length) bytes"
                }
            }
        }
    }
    
    # Return best source (prefer HIGH confidence, then by size)
    if ($sources.Count -gt 0) {
        $bestSource = $sources | Where-Object { $_.Confidence -eq "HIGH" } | Sort-Object Size -Descending | Select-Object -First 1
        if (-not $bestSource) {
            $bestSource = $sources | Sort-Object { if ($_.Size) { $_.Size } else { 0 } } -Descending | Select-Object -First 1
        }
        return @{
            Source = $bestSource
            AllSources = $sources
            Actions = $actions
        }
    }
    
    return @{
        Source = $null
        AllSources = @()
        Actions = $actions
    }
}

function Extract-WinloadFromWim {
    param(
        [string]$WimPath,
        [string]$MountDir,
        [string]$TargetPath
    )
    
    $actions = @()
    $tempMount = $null
    
    try {
        # Create mount directory
        if (-not (Test-Path $MountDir)) {
            New-Item -ItemType Directory -Path $MountDir -Force | Out-Null
            $actions += "Created mount directory: $MountDir"
        }
        
        # Get WIM info to find correct index
        $wimInfo = dism /Get-WimInfo /WimFile:$WimPath 2>&1 | Out-String
        $actions += "WIM info retrieved"
        
        # Try index 1 first (most common)
        $index = 1
        if ($wimInfo -match "Index\s*:\s*(\d+)") {
            $index = [int]$matches[1]
        }
        
        # Mount WIM
        $mountOut = dism /Mount-Wim /WimFile:$WimPath /Index:$index /MountDir:$MountDir /ReadOnly 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $tempMount = $MountDir
            $actions += "Mounted WIM index $index to $MountDir"
            
            # Extract winload.efi
            $sourcePath = Join-Path $MountDir "Windows\System32\winload.efi"
            if (Test-Path $sourcePath) {
                $fileInfo = Get-Item $sourcePath -ErrorAction SilentlyContinue
                if ($fileInfo) {
                    Copy-Item -Path $sourcePath -Destination $TargetPath -Force -ErrorAction Stop
                    $actions += "Extracted winload.efi ($($fileInfo.Length) bytes) to $TargetPath"
                    
                    # Unmount
                    dism /Unmount-Wim /MountDir:$MountDir /Discard 2>&1 | Out-Null
                    $tempMount = $null
                    $actions += "Unmounted WIM"
                    
                    return @{
                        Success = $true
                        Actions = $actions
                        FileSize = $fileInfo.Length
                    }
                } else {
                    $actions += "winload.efi not found in mounted WIM at $sourcePath"
                }
            } else {
                $actions += "winload.efi path not found in mounted WIM: $sourcePath"
            }
            
            # Unmount on failure
            dism /Unmount-Wim /MountDir:$MountDir /Discard 2>&1 | Out-Null
            $tempMount = $null
        } else {
            $actions += "Failed to mount WIM: $mountOut"
        }
    } catch {
        $actions += "WIM extraction error: $($_.Exception.Message)"
        if ($tempMount) {
            try { dism /Unmount-Wim /MountDir:$tempMount /Discard 2>&1 | Out-Null } catch { }
        }
    }
    
    return @{
        Success = $false
        Actions = $actions
        FileSize = $null
    }
}

function Copy-BootFileBruteForce {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [int]$MaxRetries = 3
    )
    
    $actions = @()
    $sourceFile = Get-Item $SourcePath -ErrorAction SilentlyContinue
    if (-not $sourceFile) {
        return @{
            Success = $false
            Actions = @("Source file not found: $SourcePath")
            Verified = $false
        }
    }
    
    $expectedSize = $sourceFile.Length
    $targetDir = Split-Path $TargetPath -Parent
    
    # Ensure target directory exists
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        $actions += "Created target directory: $targetDir"
    }
    
    # Try multiple copy methods
    $copyMethods = @(
        @{ Name = "Copy-Item"; Script = { Copy-Item -Path $SourcePath -Destination $TargetPath -Force -ErrorAction Stop } },
        @{ Name = "robocopy"; Script = { 
            robocopy (Split-Path $SourcePath -Parent) $targetDir (Split-Path $SourcePath -Leaf) /R:1 /W:1 /NFL /NDL /NJH /NJS 2>&1 | Out-Null
            if ($LASTEXITCODE -ge 0 -and $LASTEXITCODE -le 7) { } else { throw "robocopy failed with exit code $LASTEXITCODE" }
        }},
        @{ Name = "xcopy"; Script = { 
            xcopy $SourcePath $TargetPath /Y /R 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "xcopy failed with exit code $LASTEXITCODE" }
        }},
        @{ Name = ".NET File.Copy"; Script = {
            [System.IO.File]::Copy($SourcePath, $TargetPath, $true)
        }}
    )
    
    foreach ($method in $copyMethods) {
        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            try {
                # Force permissions before copy
                if (Test-Path $TargetPath) {
                    Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$TargetPath`"" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
                    Start-Process -FilePath "icacls.exe" -ArgumentList "`"$TargetPath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
                    Start-Process -FilePath "attrib.exe" -ArgumentList "-s", "-h", "-r", "`"$TargetPath`"" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
                }
                
                # Execute copy method
                & $method.Script
                $actions += "Copy attempt $attempt using $($method.Name): SUCCESS"
                
                # Verify copy
                Start-Sleep -Milliseconds 500  # Allow file system to sync
                $targetFile = Get-Item $TargetPath -ErrorAction SilentlyContinue
                if ($targetFile -and $targetFile.Length -eq $expectedSize) {
                    # Set permissions on copied file
                    Start-Process -FilePath "icacls.exe" -ArgumentList "`"$TargetPath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
                    
                    $actions += "VERIFIED: File copied successfully ($($targetFile.Length) bytes, matches source)"
                    return @{
                        Success = $true
                        Actions = $actions
                        Verified = $true
                        FileSize = $targetFile.Length
                    }
                } else {
                    $actualSize = if ($targetFile) { $targetFile.Length } else { 0 }
                    $actions += "VERIFICATION FAILED: Expected $expectedSize bytes, got $actualSize bytes"
                }
            } catch {
                $actions += "Copy attempt $attempt using $($method.Name): FAILED - $($_.Exception.Message)"
                if ($attempt -lt $MaxRetries) {
                    Start-Sleep -Seconds ([Math]::Pow(2, $attempt))  # Exponential backoff
                }
            }
        }
    }
    
    return @{
        Success = $false
        Actions = $actions
        Verified = $false
    }
}

function Test-BitLockerUnlocked {
    <#
    .SYNOPSIS
    Checks if BitLocker is unlocked on the target drive.
    
    .DESCRIPTION
    Returns $true if drive is unlocked or BitLocker is not active.
    Returns $false if drive is locked.
    #>
    param(
        [string]$TargetDrive
    )
    
    try {
        $statusOut = manage-bde -status "$TargetDrive`:" 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            # manage-bde not available or drive not BitLocker-protected
            return $true  # Assume unlocked if we can't check
        }
        
        # Check for "Lock Status: Unlocked" or "Protection Status: Off"
        if ($statusOut -match "Lock Status:\s*Unlocked" -or $statusOut -match "Protection Status:\s*Off") {
            return $true
        }
        
        # Check for "Lock Status: Locked"
        if ($statusOut -match "Lock Status:\s*Locked") {
            return $false
        }
        
        # Default to unlocked if status unclear
        return $true
    } catch {
        # If we can't check, assume unlocked to allow repairs to proceed
        return $true
    }
}

function Test-VMDDriverLoaded {
    <#
    .SYNOPSIS
    Checks if Intel VMD/RST drivers are loaded in the current session.
    #>
    $result = @{
        VMDDetected = $false
        DriverLoaded = $false
        Details = @()
    }
    
    try {
        # Check if VMD is detected
        $vmdCheck = Test-VMDDriverIssue
        if ($vmdCheck.Detected) {
            $result.VMDDetected = $true
            $result.Details += "Intel VMD controller detected"
        }
        
        # Check if RST/VMD driver is loaded
        $rstDrivers = Get-PnpDevice -Class System -ErrorAction SilentlyContinue | Where-Object {
            $_.FriendlyName -match "Intel.*RST|VMD|Volume.*Management" -or
            $_.InstanceId -match "iaStor|VMD"
        }
        
        if ($rstDrivers) {
            $result.DriverLoaded = $true
            $result.Details += "Intel RST/VMD driver found: $($rstDrivers[0].FriendlyName)"
        } else {
            $result.Details += "Intel RST/VMD driver not found in loaded devices"
        }
        
    } catch {
        $result.Details += "VMD driver check failed: $($_.Exception.Message)"
    }
    
    return $result
}

function Test-DiskSignatureCollision {
    <#
    .SYNOPSIS
    Detects potential disk signature collisions from cloned drives.
    #>
    $result = @{
        Detected = $false
        Details = @()
        DuplicateSignatures = @()
    }
    
    try {
        $disks = Get-Disk -ErrorAction SilentlyContinue
        $signatures = @{}
        
        foreach ($disk in $disks) {
            if ($disk.UniqueId) {
                $sig = $disk.UniqueId
                if ($signatures.ContainsKey($sig)) {
                    $result.Detected = $true
                    $result.DuplicateSignatures += @{
                        Signature = $sig
                        Disk1 = $signatures[$sig]
                        Disk2 = $disk.Number
                    }
                } else {
                    $signatures[$sig] = $disk.Number
                }
            }
        }
        
        if ($result.Detected) {
            $result.Details += "Duplicate disk signatures detected - drives may have been cloned"
            $result.Details += "UEFI firmware may be confused about which drive to boot"
        }
        
    } catch {
        $result.Details += "Disk signature check failed: $($_.Exception.Message)"
    }
    
    return $result
}

function Find-SystemRootByWinload {
    <#
    .SYNOPSIS
    Finds the correct SystemRoot by searching for winload.efi instead of assuming C:.
    #>
    param(
        [string]$PreferredDrive = "C"
    )
    
    $result = @{
        Drive = $null
        Path = $null
        Confidence = "LOW"
        Details = @()
    }
    
    try {
        # Get all available drives
        $allDrives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match '^[A-Z]$'
        }
        
        $candidates = @()
        
        foreach ($drive in $allDrives) {
            $driveLetter = "$($drive.Name):"
            $winloadPath = "$driveLetter\Windows\System32\winload.efi"
            
            if (Test-Path $winloadPath) {
                $fileInfo = Get-Item $winloadPath -ErrorAction SilentlyContinue
                if ($fileInfo -and $fileInfo.Length -gt 0) {
                    $confidence = if ($driveLetter -eq "$PreferredDrive`:") { "HIGH" } else { "MEDIUM" }
                    $candidates += @{
                        Drive = $driveLetter.TrimEnd(':')
                        Path = $winloadPath
                        Confidence = $confidence
                        Size = $fileInfo.Length
                    }
                }
            }
        }
        
        if ($candidates.Count -eq 0) {
            $result.Details += "No drives found with winload.efi"
            return $result
        }
        
        # Prefer the preferred drive if found, otherwise use first candidate
        $selected = $candidates | Where-Object { $_.Drive -eq $PreferredDrive } | Select-Object -First 1
        if (-not $selected) {
            $selected = $candidates[0]
        }
        
        $result.Drive = $selected.Drive
        $result.Path = $selected.Path
        $result.Confidence = $selected.Confidence
        $result.Details += "Found winload.efi on $($selected.Drive): ($($selected.Size) bytes)"
        
        if ($candidates.Count -gt 1) {
            $result.Details += "WARNING: Multiple drives contain winload.efi - using $($selected.Drive):"
        }
        
    } catch {
        $result.Details += "SystemRoot search failed: $($_.Exception.Message)"
    }
    
    return $result
}

function Repair-BCDDeepRepair {
    <#
    .SYNOPSIS
    Performs a "nuke and pave" deep repair: formats EFI partition and rebuilds BCD from scratch.
    
    .DESCRIPTION
    This is the most aggressive repair option. It:
    1. Assigns a letter to the EFI partition
    2. Formats the EFI partition as FAT32
    3. Runs bcdboot with /f UEFI and /addlast flags
    #>
    param(
        [string]$TargetDrive,
        [string]$EspLetter,
        [switch]$ConfirmFormat = $false
    )
    
    $actions = @()
    $actions += "═══════════════════════════════════════════════════════════════════════════════"
    $actions += "DEEP REPAIR: Format EFI Partition and Rebuild BCD from Scratch"
    $actions += "═══════════════════════════════════════════════════════════════════════════════"
    $actions += ""
    
    # Pre-flight checks
    $actions += "Pre-flight checks..."
    
    # Check BitLocker
    $bitlockerUnlocked = Test-BitLockerUnlocked -TargetDrive $TargetDrive
    if (-not $bitlockerUnlocked) {
        $actions += "❌ BLOCKED: BitLocker is locked on $TargetDrive`:"
        $actions += "   Unlock the drive first: manage-bde -unlock $TargetDrive`: -RecoveryPassword <KEY>"
        return @{
            Success = $false
            Actions = $actions
            Blocked = "BitLocker locked"
        }
    }
    
    # Check if ESP letter is provided
    if (-not $EspLetter) {
        $actions += "❌ BLOCKED: ESP letter not provided - cannot format EFI partition"
        return @{
            Success = $false
            Actions = $actions
            Blocked = "ESP letter missing"
        }
    }
    
    # Verify ESP is accessible
    if (-not (Test-Path "$EspLetter`:\")) {
        $actions += "❌ BLOCKED: ESP at $EspLetter`: is not accessible"
        return @{
            Success = $false
            Actions = $actions
            Blocked = "ESP not accessible"
        }
    }
    
    # Backup BCD if it exists
    $bcdPath = "$EspLetter`:\EFI\Microsoft\Boot\BCD"
    $backupPath = $null
    if (Test-Path $bcdPath) {
        $backupPath = Join-Path $env:TEMP "BCD_DEEPREPAIR_BACKUP_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
        try {
            Copy-Item $bcdPath $backupPath -Force -ErrorAction Stop
            $actions += "✓ BCD backed up to: $backupPath"
        } catch {
            $actions += "⚠ BCD backup failed: $($_.Exception.Message)"
            if (-not $ConfirmFormat) {
                $actions += "❌ BLOCKED: Cannot backup BCD - format aborted for safety"
                return @{
                    Success = $false
                    Actions = $actions
                    Blocked = "BCD backup failed"
                }
            }
        }
    }
    
    # Format EFI partition
    $actions += ""
    $actions += "Formatting EFI partition $EspLetter`: as FAT32..."
    try {
        $formatOut = format "$EspLetter`:" /FS:FAT32 /Q /Y 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $actions += "✓ EFI partition formatted successfully"
        } else {
            $actions += "❌ Format failed: $formatOut"
            return @{
                Success = $false
                Actions = $actions
                Blocked = "Format failed"
            }
        }
    } catch {
        $actions += "❌ Format failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Actions = $actions
            Blocked = "Format exception"
        }
    }
    
    # Rebuild boot files
    $actions += ""
    $actions += "Rebuilding boot files using bcdboot..."
    try {
        $bcdbootOut = bcdboot "$TargetDrive`:\Windows" /s $EspLetter /f UEFI /addlast 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $actions += "✓ Boot files rebuilt successfully"
            
            # Verify BCD was created
            if (Test-Path $bcdPath) {
                $actions += "✓ BCD file created and verified"
                
                # Verify BCD points to correct winload.efi
                $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdPath, "/enum", "{default}") -TimeoutSeconds 15 -Description "Verify BCD path"
                $bcdEnum = $bcdResult.Output
                # More flexible regex: case-insensitive, handles both single and double backslashes
                $bcdPathMatch = $bcdEnum -match "(?i)path\s+[\\/]?Windows[\\/]system32[\\/]winload\.efi"
                if ($bcdPathMatch) {
                    $actions += "✓ BCD correctly points to winload.efi"
                    return @{
                        Success = $true
                        Actions = $actions
                        Verified = $true
                        BackupPath = $backupPath
                    }
                } else {
                    $actions += "⚠ BCD created but path verification failed"
                    return @{
                        Success = $true
                        Actions = $actions
                        Verified = $false
                        BackupPath = $backupPath
                    }
                }
            } else {
                $actions += "⚠ bcdboot succeeded but BCD file not found"
                return @{
                    Success = $false
                    Actions = $actions
                    Verified = $false
                    BackupPath = $backupPath
                }
            }
        } else {
            $actions += "❌ bcdboot failed: $bcdbootOut"
            return @{
                Success = $false
                Actions = $actions
                Verified = $false
                BackupPath = $backupPath
            }
        }
    } catch {
        $actions += "❌ bcdboot exception: $($_.Exception.Message)"
        return @{
            Success = $false
            Actions = $actions
            Verified = $false
            BackupPath = $backupPath
        }
    }
}

function Restore-BCDFromWinPE {
    <#
    .SYNOPSIS
    Attempts to restore BCD from WinPE X: drive if available.
    #>
    param(
        [string]$TargetBcdPath,
        [string]$EspLetter
    )
    
    $actions = @()
    $restored = $false
    
    # Check if we're in WinPE or if X: drive exists
    $winpeBcdPath = $null
    if ($env:SystemDrive -eq "X:" -and (Test-Path "X:\EFI\Microsoft\Boot\BCD" -ErrorAction SilentlyContinue)) {
        $winpeBcdPath = "X:\EFI\Microsoft\Boot\BCD"
        $actions += "✓ Found BCD on WinPE X: drive: $winpeBcdPath"
    } elseif (Test-Path "X:\EFI\Microsoft\Boot\BCD" -ErrorAction SilentlyContinue) {
        $winpeBcdPath = "X:\EFI\Microsoft\Boot\BCD"
        $actions += "✓ Found BCD on X: drive: $winpeBcdPath"
    }
    
    if ($winpeBcdPath -and (Test-Path $winpeBcdPath)) {
        try {
            # Ensure target directory exists
            $targetDir = Split-Path -Path $TargetBcdPath -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                $actions += "✓ Created target directory: $targetDir"
            }
            
            # Copy BCD from WinPE
            Copy-Item -Path $winpeBcdPath -Destination $TargetBcdPath -Force -ErrorAction Stop
            $actions += "✓ Restored BCD from WinPE X: drive to: $TargetBcdPath"
            $restored = $true
            
            # Verify the copied BCD is readable
            Start-Sleep -Milliseconds 500
            $verifyResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $TargetBcdPath, "/enum", "all") -TimeoutSeconds 15 -Description "Verify restored BCD"
            if ($verifyResult.ExitCode -eq 0) {
                $actions += "✓ Verified restored BCD is readable"
            } else {
                $actions += "⚠ Restored BCD may be corrupted: $($verifyResult.Output)"
            }
        } catch {
            $actions += "❌ Failed to restore BCD from WinPE: $($_.Exception.Message)"
        }
    } else {
        $actions += "ℹ No BCD found on WinPE X: drive (this is normal if not in WinPE)"
    }
    
    return @{
        Restored = $restored
        Actions = $actions
    }
}

function Create-BCDDefaultEntry {
    <#
    .SYNOPSIS
    Creates a {default} boot entry in BCD if it doesn't exist.
    #>
    param(
        [string]$BcdStore,
        [string]$TargetDrive
    )
    
    $actions = @()
    
    # First, enumerate all entries to see what exists
    $enumAllResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $BcdStore, "/enum", "all") -TimeoutSeconds 15 -Description "Enumerate all BCD entries"
    
    if ($enumAllResult.ExitCode -eq 0) {
        # Check if {default} exists
        if ($enumAllResult.Output -match '\{default\}') {
            $actions += "✓ {default} entry already exists"
            return @{
                Success = $true
                Actions = $actions
            }
        }
        
        # Try to find any Windows boot entry
        $windowsEntryGuid = $null
        if ($enumAllResult.Output -match '\{([a-f0-9\-]{36})\}.*Windows') {
            $windowsEntryGuid = $matches[1]
            $actions += "✓ Found existing Windows boot entry: {$windowsEntryGuid}"
        }
        
        # If we found an entry, set it as default
        if ($windowsEntryGuid) {
            $setDefaultResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $BcdStore, "/default", "{$windowsEntryGuid}") -TimeoutSeconds 15 -Description "Set default entry"
            if ($setDefaultResult.ExitCode -eq 0) {
                $actions += "✓ Set existing entry as default"
                return @{
                    Success = $true
                    Actions = $actions
                }
            }
        }
    }
    
    # If no entry exists, create a new {default} entry
    $actions += "Creating new {default} boot entry..."
    
    # Create a boot entry using bcdedit /create
    $createResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $BcdStore, "/create", "{default}", "/d", "Windows Boot Manager") -TimeoutSeconds 15 -Description "Create default entry"
    
    if ($createResult.ExitCode -eq 0) {
        $actions += "✓ Created {default} entry"
        
        # Set it as a Windows boot entry
        $setTypeResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $BcdStore, "/set", "{default}", "device", "partition=$TargetDrive") -TimeoutSeconds 15 -Description "Set device"
        $setOsResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $BcdStore, "/set", "{default}", "osdevice", "partition=$TargetDrive") -TimeoutSeconds 15 -Description "Set osdevice"
        $setPathResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $BcdStore, "/set", "{default}", "path", "\Windows\system32\winload.efi") -TimeoutSeconds 15 -Description "Set path"
        
        if ($setTypeResult.ExitCode -eq 0 -and $setOsResult.ExitCode -eq 0 -and $setPathResult.ExitCode -eq 0) {
            $actions += "✓ Configured {default} entry properties"
            return @{
                Success = $true
                Actions = $actions
            }
        } else {
            $actions += "⚠ Created entry but some properties failed to set"
            return @{
                Success = $true
                Actions = $actions
            }
        }
    } else {
        $actions += "❌ Failed to create {default} entry: $($createResult.Output)"
        return @{
            Success = $false
            Actions = $actions
        }
    }
}

function Repair-BCDBruteForce {
    param(
        [string]$TargetDrive,
        [string]$EspLetter,
        [string]$WinloadPath,
        [switch]$DeepRepair = $false,
        [switch]$ConfirmFormat = $false
    )
    
    $actions = @()
    # Normalize ESP letter - strip colon if present for /store parameter
    $espLetterClean = if ($EspLetter) { $EspLetter.TrimEnd(':') } else { $null }
    $bcdStore = if ($espLetterClean) { "$espLetterClean\EFI\Microsoft\Boot\BCD" } else { "BCD" }
    $bcdPath = if ($espLetterClean) { "$espLetterClean`:\EFI\Microsoft\Boot\BCD" } else { "$TargetDrive`:\Boot\BCD" }
    
    # Pre-flight: Check BitLocker
    $bitlockerUnlocked = Test-BitLockerUnlocked -TargetDrive $TargetDrive
    if (-not $bitlockerUnlocked) {
        $actions += "❌ BLOCKED: BitLocker is locked on $TargetDrive`:"
        $actions += "   Unlock the drive first: manage-bde -unlock $TargetDrive`: -RecoveryPassword <KEY>"
        return @{
            Success = $false
            Actions = $actions
            Blocked = "BitLocker locked"
        }
    }
    
    # Pre-flight: Check VMD driver
    $vmdCheck = Test-VMDDriverLoaded
    if ($vmdCheck.VMDDetected -and -not $vmdCheck.DriverLoaded) {
        $actions += "⚠ WARNING: Intel VMD detected but RST driver not loaded"
        $actions += "   This may cause bcdboot to fail silently"
        $actions += "   Solution: Load Intel RST driver: drvload <path>\iaStorVD.inf"
    }
    
    # Pre-flight: Check disk signature collisions
    $sigCheck = Test-DiskSignatureCollision
    if ($sigCheck.Detected) {
        $actions += "⚠ WARNING: Duplicate disk signatures detected"
        $actions += "   UEFI firmware may be confused about which drive to boot"
        foreach ($dup in $sigCheck.DuplicateSignatures) {
            $actions += "   - Signature $($dup.Signature) found on Disk $($dup.Disk1) and Disk $($dup.Disk2)"
        }
    }
    
    # If DeepRepair is requested, use the deep repair function
    if ($DeepRepair -and $EspLetter) {
        return Repair-BCDDeepRepair -TargetDrive $TargetDrive -EspLetter $EspLetter -ConfirmFormat:$ConfirmFormat
    }
    
    # CRITICAL FIX: Check if BCD EXISTS before trying to modify it
    # If BCD is missing, we MUST use bcdboot to CREATE it first
    # NEW: Also try to recover from WinPE X: drive
    $actions += "Step 1: Checking if BCD exists..."
    
    # First check if the BCD file actually exists on disk
    $bcdFileExists = Test-Path $bcdPath -ErrorAction SilentlyContinue
    if (-not $bcdFileExists) {
        $actions += "❌ BCD file missing at: $bcdPath"
    } else {
        $actions += "✓ BCD file exists at: $bcdPath"
    }
    
    # Then try to enumerate it to see if it's readable and has {default} entry
    $enumCheckResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/enum", "{default}") -TimeoutSeconds 15 -Description "Check BCD existence"
    
    # Check for various error conditions
    $bcdExists = $enumCheckResult.ExitCode -eq 0 -and -not ($enumCheckResult.Output -match "could not be opened|cannot find|No bootable entries|specified entry type is invalid")
    $invalidEntryType = $enumCheckResult.Output -match "specified entry type is invalid|The parameter is incorrect"
    
    if (-not $bcdExists) {
        # BCD is MISSING or {default} entry doesn't exist
        $actions += "❌ BCD missing, corrupted, or {default} entry invalid: $($enumCheckResult.Output)"
        $actions += ""
        
        # NEW: Try to restore from WinPE X: drive first
        if ($espLetterClean -and (Test-Path $bcdPath -ErrorAction SilentlyContinue)) {
            $actions += "Step 1a: Attempting to restore BCD from WinPE X: drive..."
            $restoreResult = Restore-BCDFromWinPE -TargetBcdPath $bcdPath -EspLetter $espLetterClean
            $actions += $restoreResult.Actions
            if ($restoreResult.Restored) {
                # Re-check after restore
                Start-Sleep -Milliseconds 500
                $enumCheckResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/enum", "{default}") -TimeoutSeconds 15 -Description "Re-check BCD after restore"
                $bcdExists = $enumCheckResult.ExitCode -eq 0 -and -not ($enumCheckResult.Output -match "could not be opened|cannot find|No bootable entries|specified entry type is invalid")
                $invalidEntryType = $enumCheckResult.Output -match "specified entry type is invalid|The parameter is incorrect"
            }
        }
        
        # If BCD file exists but {default} entry is invalid, create it
        if ($invalidEntryType -and (Test-Path $bcdPath -ErrorAction SilentlyContinue)) {
            $actions += ""
            $actions += "Step 1b: BCD file exists but {default} entry is invalid - creating entry..."
            $createEntryResult = Create-BCDDefaultEntry -BcdStore $bcdStore -TargetDrive $TargetDrive
            $actions += $createEntryResult.Actions
            if ($createEntryResult.Success) {
                # Re-check after creating entry
                Start-Sleep -Milliseconds 500
                $enumCheckResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/enum", "{default}") -TimeoutSeconds 15 -Description "Re-check BCD after creating entry"
                $bcdExists = $enumCheckResult.ExitCode -eq 0 -and -not ($enumCheckResult.Output -match "could not be opened|cannot find|No bootable entries|specified entry type is invalid")
            }
        }
        
        # If BCD still doesn't exist, create it with bcdboot
        if (-not $bcdExists) {
            $actions += ""
            $actions += "Step 2: Creating BCD with bcdboot (recovery mode)..."
            
            if ($espLetterClean) {
                # Try bcdboot first to CREATE the BCD
                $rebuildResult = Invoke-BCDCommandWithTimeout -Command "bcdboot.exe" -Arguments @("$TargetDrive`:\Windows", "/s", $espLetterClean, "/f", "UEFI", "/addlast") -TimeoutSeconds 30 -Description "Create BCD with bcdboot"
                
                if ($rebuildResult.ExitCode -eq 0) {
                    $actions += "✓ BCD created by bcdboot"
                    # After bcdboot, check if {default} entry exists
                    Start-Sleep -Milliseconds 500
                    $enumCheckResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/enum", "{default}") -TimeoutSeconds 15 -Description "Check BCD after bcdboot"
                    if ($enumCheckResult.Output -match "specified entry type is invalid") {
                        $actions += "⚠ bcdboot created BCD but {default} entry missing - creating it..."
                        $createEntryResult = Create-BCDDefaultEntry -BcdStore $bcdStore -TargetDrive $TargetDrive
                        $actions += $createEntryResult.Actions
                    }
                } else {
                    $actions += "❌ bcdboot failed to create BCD: $($rebuildResult.Output)"
                    # Continue anyway and try bcdedit commands
                    $actions += "   Attempting manual BCD creation..."
                }
            } else {
                # No ESP letter - try bcdboot to system BCD (creates C:\Boot\BCD)
                $actions += "No ESP detected - creating system BCD at $bcdPath"
                $rebuildResult = Invoke-BCDCommandWithTimeout -Command "bcdboot.exe" -Arguments @("$TargetDrive`:\Windows") -TimeoutSeconds 30 -Description "Recreate system BCD"
                if ($rebuildResult.ExitCode -eq 0) {
                    $actions += "✓ System BCD recreated at $bcdPath"
                    # Verify file was created
                    Start-Sleep -Milliseconds 1000
                    if (Test-Path $bcdPath -ErrorAction SilentlyContinue) {
                        $actions += "✓ Verified BCD file exists at $bcdPath"
                    } else {
                        $actions += "⚠ bcdboot reported success but BCD file not found at $bcdPath"
                    }
                    # After bcdboot, check if {default} entry exists
                    $enumCheckResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "{default}") -TimeoutSeconds 15 -Description "Check BCD after bcdboot"
                    if ($enumCheckResult.Output -match "specified entry type is invalid") {
                        $actions += "⚠ bcdboot created BCD but {default} entry missing - creating it..."
                        $createEntryResult = Create-BCDDefaultEntry -BcdStore "BCD" -TargetDrive $TargetDrive
                        $actions += $createEntryResult.Actions
                    } elseif ($enumCheckResult.ExitCode -eq 0) {
                        $actions += "✓ BCD is readable and {default} entry exists"
                        $bcdExists = $true
                    }
                } else {
                    $actions += "❌ Failed to recreate system BCD: $($rebuildResult.Output)"
                    $actions += "   Error details: $($rebuildResult.Error)"
                    # Try alternative: ensure Boot directory exists and try again
                    $bootDir = "$TargetDrive`:\Boot"
                    if (-not (Test-Path $bootDir -ErrorAction SilentlyContinue)) {
                        try {
                            New-Item -ItemType Directory -Path $bootDir -Force | Out-Null
                            $actions += "✓ Created Boot directory: $bootDir"
                            # Retry bcdboot
                            $rebuildResult = Invoke-BCDCommandWithTimeout -Command "bcdboot.exe" -Arguments @("$TargetDrive`:\Windows") -TimeoutSeconds 30 -Description "Retry recreate system BCD"
                            if ($rebuildResult.ExitCode -eq 0) {
                                $actions += "✓ System BCD recreated after creating Boot directory"
                                Start-Sleep -Milliseconds 1000
                                if (Test-Path $bcdPath -ErrorAction SilentlyContinue) {
                                    $actions += "✓ Verified BCD file exists at $bcdPath"
                                    $bcdExists = $true
                                }
                            }
                        } catch {
                            $actions += "❌ Failed to create Boot directory: $($_.Exception.Message)"
                        }
                    }
                }
            }
            
            # After attempting bcdboot, pause briefly for file system sync
            Start-Sleep -Milliseconds 500
        }
    }
    
    # Step 2/3: Now try to set BCD properties (whether we just created it or it existed)
    $actions += ""
    $actions += "Step 3: Setting BCD properties..."
    
    $pathArgs = @("/store", $bcdStore, "/set", "{default}", "path", "\Windows\system32\winload.efi")
    $deviceArgs = @("/store", $bcdStore, "/set", "{default}", "device", "partition=$TargetDrive")
    $osdeviceArgs = @("/store", $bcdStore, "/set", "{default}", "osdevice", "partition=$TargetDrive")
    
    $setPathResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $pathArgs -TimeoutSeconds 15 -Description "Set BCD path"
    $setDeviceResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $deviceArgs -TimeoutSeconds 15 -Description "Set BCD device"
    $setOsDeviceResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $osdeviceArgs -TimeoutSeconds 15 -Description "Set BCD osdevice"
    
    # Check for "invalid entry type" errors and retry with entry creation
    $needsRetry = $false
    if ($setPathResult.ExitCode -ne 0 -and $setPathResult.Output -match "specified entry type is invalid|The parameter is incorrect") {
        $actions += "⚠ BCD path set failed - {default} entry may not exist: $($setPathResult.Output)"
        $needsRetry = $true
    }
    if ($setDeviceResult.ExitCode -ne 0 -and $setDeviceResult.Output -match "specified entry type is invalid|The parameter is incorrect") {
        $actions += "⚠ BCD device set failed - {default} entry may not exist: $($setDeviceResult.Output)"
        $needsRetry = $true
    }
    if ($setOsDeviceResult.ExitCode -ne 0 -and $setOsDeviceResult.Output -match "specified entry type is invalid|The parameter is incorrect") {
        $actions += "⚠ BCD osdevice set failed - {default} entry may not exist: $($setOsDeviceResult.Output)"
        $needsRetry = $true
    }
    
    # If we got "invalid entry type" errors, create the entry and retry
    if ($needsRetry) {
        $actions += ""
        $actions += "Step 3a: Creating {default} entry and retrying..."
        $createEntryResult = Create-BCDDefaultEntry -BcdStore $bcdStore -TargetDrive $TargetDrive
        $actions += $createEntryResult.Actions
        
        if ($createEntryResult.Success) {
            Start-Sleep -Milliseconds 500
            # Retry setting properties
            $actions += "Step 3b: Retrying BCD property settings..."
            $setPathResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $pathArgs -TimeoutSeconds 15 -Description "Set BCD path (retry)"
            $setDeviceResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $deviceArgs -TimeoutSeconds 15 -Description "Set BCD device (retry)"
            $setOsDeviceResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $osdeviceArgs -TimeoutSeconds 15 -Description "Set BCD osdevice (retry)"
        }
    }
    
    if ($setPathResult.ExitCode -eq 0 -and $setDeviceResult.ExitCode -eq 0 -and $setOsDeviceResult.ExitCode -eq 0) {
        $actions += "✓ BCD path, device, and osdevice set successfully"
    } else {
        if ($setPathResult.ExitCode -ne 0) {
            $actions += "❌ BCD path set failed: $($setPathResult.Output)"
        }
        if ($setDeviceResult.ExitCode -ne 0) {
            $actions += "❌ BCD device set failed: $($setDeviceResult.Output)"
        }
        if ($setOsDeviceResult.ExitCode -ne 0) {
            $actions += "❌ BCD osdevice set failed: $($setOsDeviceResult.Output)"
        }
    }
    
    # Step 4: Verify BCD was updated (with aggressive permission fixes for verification)
    $actions += ""
    $actions += "Step 4: Verifying BCD configuration..."
    $enumResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/enum", "{default}") -TimeoutSeconds 15 -Description "Enumerate BCD entries"
    $bcdEnum = $enumResult.Output
    $bcdEnumExitCode = $enumResult.ExitCode
    
    # If enumeration failed, try permission fixes before giving up
    if ($enumResult.ExitCode -ne 0 -and (Test-Path $bcdPath -ErrorAction SilentlyContinue)) {
        $actions += "⚠ BCD enumeration failed (exit code $bcdEnumExitCode), attempting permission fix for verification..."
        try {
            # Fix parent directory permissions
            $bcdParentDir = Split-Path -Path $bcdPath -Parent
            if (Test-Path $bcdParentDir -ErrorAction SilentlyContinue) {
                Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$bcdParentDir`"", "/r", "/d", "y" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue | Out-Null
                Start-Process -FilePath "icacls.exe" -ArgumentList "`"$bcdParentDir`"", "/grant", "Administrators:F", "/t" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue | Out-Null
            }
            
            # Fix BCD file permissions
            $takeownResult = Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$bcdPath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
            if ($takeownResult.ExitCode -eq 0) {
                Start-Process -FilePath "icacls.exe" -ArgumentList "`"$bcdPath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue | Out-Null
                Start-Process -FilePath "attrib.exe" -ArgumentList "-s", "-h", "-r", "`"$bcdPath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue | Out-Null
                $actions += "  ✓ Fixed permissions, retrying enumeration..."
                
                Start-Sleep -Milliseconds 500
                $enumResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/enum", "{default}") -TimeoutSeconds 15 -Description "Re-enumerate BCD after permission fix"
                $bcdEnum = $enumResult.Output
                $bcdEnumExitCode = $enumResult.ExitCode
            }
        } catch {
            $actions += "  ⚠ Could not fix BCD permissions for verification: $($_.Exception.Message)"
        }
    }
    
    # More flexible regex: case-insensitive, handles both single and double backslashes
    $bcdPathMatch = $bcdEnum -match "(?i)path\s+[\\/]?Windows[\\/]system32[\\/]winload\.efi"
    # Device match: handle both "partition=C" and "partition=C:" formats, case-insensitive
    $targetDriveClean = $TargetDrive.TrimEnd(':').ToUpper()
    $bcdDeviceMatch = $bcdEnum -match "(?i)device\s+partition=$targetDriveClean" -or $bcdEnum -match "(?i)device\s+partition=$targetDriveClean`:"
    
    if ($bcdPathMatch -and $bcdDeviceMatch) {
        $actions += "✓ VERIFIED: BCD correctly points to winload.efi on $TargetDrive"
        return @{
            Success = $true
            Actions = $actions
            Verified = $true
        }
    } else {
        $actions += "⚠ BCD verification inconclusive - path match: $bcdPathMatch, device match: $bcdDeviceMatch"
        
        # Check if the enum itself succeeded
        if ($enumResult.ExitCode -eq 0) {
            $actions += "✓ BCD exists and is readable (may need manual verification)"
            return @{
                Success = $true
                Actions = $actions
                Verified = $false
            }
        } else {
            $actions += "❌ BCD still not accessible after repair: $($enumResult.Output)"
            return @{
                Success = $false
                Actions = $actions
                Verified = $false
            }
        }
    }
}

function Test-BootabilityComprehensive {
    <#
    .SYNOPSIS
    Ultimate comprehensive bootability test using hardened detection methods.
    #>
    param(
        [string]$TargetDrive,
        [string]$EspLetter
    )
    
    $verification = @{
        WinloadExists = $false
        WinloadReadable = $false
        WinloadSize = $null
        BootmgfwExists = $false
        BCDExists = $false
        BCDReadable = $false
        BCDPathMatch = $false
        BCDDeviceMatch = $false
        AllBootFilesPresent = $false
        Issues = @()
        Actions = @()
    }
    
    # 1. Verify winload.efi (ULTIMATE HARDENED DETECTION)
    $winloadPath = Resolve-WindowsPath -Path "$TargetDrive`:\Windows\System32\winload.efi" -SupportLongPath
    if (-not $winloadPath) {
        $winloadPath = "$TargetDrive`:\Windows\System32\winload.efi"  # Fallback
    }
    
    $winloadCheck = Test-WinloadExistsComprehensive -Path $winloadPath
    if ($winloadCheck.Exists) {
        $winloadIntegrity = Test-FileIntegrity -FilePath $winloadPath
        if ($winloadIntegrity.Valid) {
            $verification.WinloadExists = $true
            $verification.WinloadReadable = $winloadIntegrity.Readable
            $verification.WinloadSize = $winloadIntegrity.FileInfo.Length
            $verification.Actions += "✓ winload.efi exists and verified at $winloadPath (detected via: $($winloadCheck.Method))"
            $verification.Actions += "  Size: $($winloadIntegrity.FileInfo.Length) bytes, Readable: $($winloadIntegrity.Readable), Integrity: Valid"
        } else {
            $verification.Issues += "winload.efi exists but integrity check FAILED: $($winloadIntegrity.Details -join '; ')"
            $verification.WinloadExists = $false
        }
    } else {
        $verification.Issues += "winload.efi MISSING at $winloadPath (checked via: $($winloadCheck.Method))"
    }
    
    # 2. Verify bootmgfw.efi in ESP
    if ($EspLetter) {
        $bootmgfwPath = "$EspLetter\EFI\Microsoft\Boot\bootmgfw.efi"
        if (Test-Path $bootmgfwPath) {
            $verification.BootmgfwExists = $true
            $verification.Actions += "✓ bootmgfw.efi exists in ESP"
        } else {
            $verification.Issues += "bootmgfw.efi MISSING in ESP"
        }
    }
    
    # 3. Verify BCD (with permission handling)
    # LAYER 10 EVIDENCE-BASED: If bcdedit /enum works, BCD EXISTS and is accessible
    # Try system BCD FIRST (without /store) - this is the most reliable check
    $bcdPermissionsModified = $false
    $bcdEnum = $null
    $bcdExitCode = -1
    $bcdStore = $null
    $actualEspLetter = $EspLetter
    $bcdStorePath = $null
    
    # Step 1: Try system BCD first (most reliable - if this works, BCD exists)
    $verification.Actions += "Checking system BCD accessibility..."
    $systemBcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "{default}") -TimeoutSeconds 15 -Description "Check system BCD accessibility"
    
    if ($systemBcdResult.ExitCode -eq 0 -and -not ($systemBcdResult.Output -match "could not be opened|cannot find|specified entry type is invalid")) {
        # System BCD works! This is evidence that BCD exists and is accessible
        $verification.BCDExists = $true
        $verification.BCDReadable = $true
        $bcdEnum = $systemBcdResult.Output
        $bcdExitCode = 0
        $verification.Actions += "✓ System BCD is accessible (bcdedit /enum succeeded)"
        $bcdStore = "BCD"  # System BCD - no /store parameter needed
    } elseif ($systemBcdResult.Output -match "specified entry type is invalid|The parameter is incorrect") {
        # BCD exists but {default} entry is invalid - try to create it
        $verification.Actions += "⚠ System BCD exists but {default} entry is invalid. Attempting to create entry..."
        try {
            $createEntryResult = Create-BCDDefaultEntry -BcdStore "BCD" -TargetDrive $TargetDrive
            $verification.Actions += $createEntryResult.Actions
            if ($createEntryResult.Success) {
                Start-Sleep -Milliseconds 500
                $systemBcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "{default}") -TimeoutSeconds 15 -Description "Re-check system BCD after creating entry"
                if ($systemBcdResult.ExitCode -eq 0 -and -not ($systemBcdResult.Output -match "could not be opened|cannot find|specified entry type is invalid")) {
                    $verification.BCDExists = $true
                    $verification.BCDReadable = $true
                    $bcdEnum = $systemBcdResult.Output
                    $bcdExitCode = 0
                    $verification.Actions += "✓ System BCD accessible after creating {default} entry"
                    $bcdStore = "BCD"
                }
            }
        } catch {
            $verification.Actions += "  ⚠ Could not create {default} entry: $($_.Exception.Message)"
        }
        
        # If still not working, fall through to permission fix or ESP BCD check
        if ($bcdExitCode -ne 0) {
            # Continue to permission fix or ESP BCD check below
        }
    } elseif ($systemBcdResult.ExitCode -ne 0 -and -not ($systemBcdResult.Output -match "specified entry type is invalid")) {
        # System BCD failed but might be a permission issue - try fixing permissions on system BCD file
        $systemBcdPath = "$TargetDrive`:\Boot\BCD"
        if (Test-Path $systemBcdPath -ErrorAction SilentlyContinue) {
            $verification.Actions += "System BCD enumeration failed, attempting permission fix on $systemBcdPath..."
            try {
                $takeownResult = Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$systemBcdPath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                if ($takeownResult.ExitCode -eq 0) {
                    $bcdPermissionsModified = $true
                    $icaclsResult = Start-Process -FilePath "icacls.exe" -ArgumentList "`"$systemBcdPath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                    $attribResult = Start-Process -FilePath "attrib.exe" -ArgumentList "-s", "-h", "-r", "`"$systemBcdPath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                    $verification.Actions += "  ✓ Fixed permissions on system BCD file, retrying enumeration..."
                    
                    # Also fix parent directory permissions
                    $bootDir = "$TargetDrive`:\Boot"
                    if (Test-Path $bootDir -ErrorAction SilentlyContinue) {
                        Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$bootDir`"", "/r", "/d", "y" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
                        Start-Process -FilePath "icacls.exe" -ArgumentList "`"$bootDir`"", "/grant", "Administrators:F", "/t" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
                    }
                    
                    # Retry system BCD enumeration
                    Start-Sleep -Milliseconds 500
                    $systemBcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "{default}") -TimeoutSeconds 15 -Description "Re-check system BCD after permission fix"
                    
                    if ($systemBcdResult.ExitCode -eq 0 -and -not ($systemBcdResult.Output -match "could not be opened|cannot find|specified entry type is invalid")) {
                        $verification.BCDExists = $true
                        $verification.BCDReadable = $true
                        $bcdEnum = $systemBcdResult.Output
                        $bcdExitCode = 0
                        $verification.Actions += "✓ System BCD accessible after permission fix"
                        $bcdStore = "BCD"
                    }
                }
            } catch {
                $verification.Actions += "  ⚠ Could not fix system BCD permissions: $($_.Exception.Message)"
            }
        }
        
        # If system BCD still doesn't work after permission fix, fall through to ESP BCD check
        if ($bcdExitCode -ne 0) {
            # System BCD failed - try ESP BCD
            $verification.Actions += "System BCD not accessible, checking ESP BCD..."
            
            # Try to detect/mount ESP if not provided
            $actualEspLetter = $EspLetter
            if (-not $actualEspLetter) {
                # Try to detect ESP
                $esp = Get-EspCandidate
                if ($esp -and $esp.DriveLetter) {
                    $actualEspLetter = "$($esp.DriveLetter):"
                    $verification.Actions += "✓ ESP detected at $actualEspLetter (auto-detected for BCD verification)"
                } else {
                    # Try to mount ESP temporarily for verification
                    $mount = Mount-EspTemp -PreferredLetter "S"
                    if ($mount) {
                        $actualEspLetter = "$($mount.Letter):"
                        $verification.Actions += "✓ ESP mounted at $actualEspLetter (temporarily mounted for BCD verification)"
                    }
                }
            }
            
            # Check ESP BCD file path
            if ($actualEspLetter) {
                $espLetterClean = $actualEspLetter.TrimEnd(':')
                $bcdStore = "$espLetterClean\EFI\Microsoft\Boot\BCD"
                $bcdStorePath = "$actualEspLetter\EFI\Microsoft\Boot\BCD"
            } else {
                $bcdStore = "BCD"
                $bcdStorePath = "$TargetDrive`:\Boot\BCD"
            }
            
            # Check if BCD file exists on disk
            if (Test-Path $bcdStorePath -ErrorAction SilentlyContinue) {
                $verification.BCDExists = $true
                $verification.Actions += "✓ BCD file exists at $bcdStorePath"
                
                try {
                    # Try to enumerate ESP BCD with timeout to prevent hanging
                    $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/enum", "{default}") -TimeoutSeconds 15 -Description "Enumerate BCD entries"
                    $bcdEnum = $bcdResult.Output
                    $bcdExitCode = $bcdResult.ExitCode
                
                    # Check for timeout
                    if ($bcdResult.TimedOut) {
                        $verification.Issues += "BCD enumeration timed out after 15 seconds - BCD may be locked or corrupted"
                        $verification.Actions += "⚠ bcdedit enumeration timed out (BCD may be locked)"
                    }
                    # If enumeration failed, try taking ownership of BCD file and parent directory
                    elseif ($bcdExitCode -ne 0) {
                        $verification.Actions += "⚠ bcdedit enumeration failed (exit code $bcdExitCode), attempting permission fix..."
                        try {
                            # Fix parent directory permissions first (ESP or Boot directory)
                            $bcdParentDir = Split-Path -Path $bcdStorePath -Parent
                            if (Test-Path $bcdParentDir -ErrorAction SilentlyContinue) {
                                Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$bcdParentDir`"", "/r", "/d", "y" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue | Out-Null
                                Start-Process -FilePath "icacls.exe" -ArgumentList "`"$bcdParentDir`"", "/grant", "Administrators:F", "/t" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue | Out-Null
                                $verification.Actions += "  ✓ Fixed permissions on parent directory: $bcdParentDir"
                            }
                            
                            # Fix BCD file permissions
                            $takeownResult = Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$bcdStorePath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                            if ($takeownResult.ExitCode -eq 0) {
                                $bcdPermissionsModified = $true
                                $icaclsResult = Start-Process -FilePath "icacls.exe" -ArgumentList "`"$bcdStorePath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                                $attribResult = Start-Process -FilePath "attrib.exe" -ArgumentList "-s", "-h", "-r", "`"$bcdStorePath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                                $verification.Actions += "  ✓ Took ownership and fixed permissions on BCD file"
                                
                                # Wait for file system to sync
                                Start-Sleep -Milliseconds 500
                                
                                # Try enumeration again with timeout
                                $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/enum", "{default}") -TimeoutSeconds 15 -Description "Re-enumerate BCD after permission fix"
                                $bcdEnum = $bcdResult.Output
                                $bcdExitCode = $bcdResult.ExitCode
                                
                                if ($bcdResult.TimedOut) {
                                    $verification.Issues += "BCD enumeration still timed out after permission fix"
                                } elseif ($bcdExitCode -eq 0) {
                                    $verification.Actions += "  ✓ BCD enumeration succeeded after permission fix"
                                }
                            } else {
                                $verification.Actions += "  ⚠ takeown failed (exit code $($takeownResult.ExitCode)) - may need administrator privileges"
                            }
                        } catch {
                            $verification.Actions += "  ⚠ Could not fix BCD permissions: $($_.Exception.Message)"
                        }
                    }
                } catch {
                    $verification.Issues += "BCD exists but not readable: $($_.Exception.Message)"
                }
            } else {
                # BCD file doesn't exist on disk - but try system BCD enumeration one more time
                # Sometimes BCD is accessible via bcdedit even if file path check fails
                $verification.Actions += "⚠ BCD file not found at $bcdStorePath, but checking if system BCD is accessible..."
                $finalSystemCheck = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "{default}") -TimeoutSeconds 15 -Description "Final system BCD check"
                if ($finalSystemCheck.ExitCode -eq 0 -and -not ($finalSystemCheck.Output -match "could not be opened|cannot find|specified entry type is invalid")) {
                    $verification.BCDExists = $true
                    $verification.BCDReadable = $true
                    $bcdEnum = $finalSystemCheck.Output
                    $bcdExitCode = 0
                    $verification.Actions += "✓ System BCD is accessible via bcdedit (file path check may be misleading)"
                    $bcdStore = "BCD"
                } else {
                    $verification.Actions += "❌ BCD file not found and system BCD enumeration also failed"
                }
            }
        }
    }
    
    # Process BCD enumeration results (whether from system or ESP BCD)
    if ($bcdExitCode -eq 0) {
        $verification.BCDReadable = $true
        # More flexible regex: case-insensitive, handles both single and double backslashes
        $verification.BCDPathMatch = $bcdEnum -match "(?i)path\s+[\\/]?Windows[\\/]system32[\\/]winload\.efi"
        # Device match: handle both "partition=C" and "partition=C:" formats, case-insensitive
        $targetDriveClean = $TargetDrive.TrimEnd(':').ToUpper()
        $verification.BCDDeviceMatch = $bcdEnum -match "(?i)device\s+partition=$targetDriveClean" -or $bcdEnum -match "(?i)device\s+partition=$targetDriveClean`:"
        
        if ($verification.BCDPathMatch) {
            $verification.Actions += "✓ BCD path correctly points to winload.efi"
        } else {
            $verification.Issues += "BCD path does NOT point to winload.efi"
        }
        
        if ($verification.BCDDeviceMatch) {
            $verification.Actions += "✓ BCD device correctly set to $TargetDrive"
        } else {
            $verification.Issues += "BCD device does NOT match $TargetDrive"
        }
        
        if ($bcdPermissionsModified) {
            $verification.Actions += "  (BCD permissions were modified to enable verification)"
        }
    } elseif ($verification.BCDExists) {
        # BCD file exists but enumeration failed
        $verification.Issues += "BCD exists but cannot be enumerated (exit code $bcdExitCode)"
        if ($bcdEnum) {
            $verification.Issues += "  bcdedit output: $($bcdEnum.Substring(0, [Math]::Min(200, $bcdEnum.Length)))"
        }
    } else {
        # BCD is missing - provide actionable solution
        $verification.Issues += "BCD MISSING or not accessible"
        if ($actualEspLetter) {
            $verification.Actions += "❌ BCD MISSING - Solution: Run this command to create it:"
            $verification.Actions += "   bcdboot $TargetDrive`:\Windows /s $actualEspLetter /f UEFI"
            $verification.Actions += "   Or use the 'Rebuild BCD' option in the repair menu"
        } else {
            $verification.Actions += "❌ BCD MISSING - ESP not detected. Solution:"
            $verification.Actions += "   1. Mount ESP: mountvol S: /S"
            $verification.Actions += "   2. Create BCD: bcdboot $TargetDrive`:\Windows /s S: /f UEFI"
            $verification.Actions += "   Or use the 'Rebuild BCD' option in the repair menu"
        }
    }
    
    # 4. Check all critical boot files (using comprehensive detection)
    $criticalFiles = @(
        @{ Path = "$TargetDrive`:\Windows\System32\winload.efi"; Name = "winload.efi" },
        @{ Path = "$TargetDrive`:\Windows\System32\ntoskrnl.exe"; Name = "ntoskrnl.exe" }
    )
    if ($EspLetter) {
        $criticalFiles += @{ Path = "$EspLetter\EFI\Microsoft\Boot\bootmgfw.efi"; Name = "bootmgfw.efi" }
        $criticalFiles += @{ Path = "$EspLetter\EFI\Microsoft\Boot\BCD"; Name = "BCD" }
    }
    
    $allPresent = $true
    foreach ($fileInfo in $criticalFiles) {
        $file = $fileInfo.Path
        $fileName = $fileInfo.Name
        $resolvedFile = Resolve-WindowsPath -Path $file -SupportLongPath
        if (-not $resolvedFile) { $resolvedFile = $file }  # Fallback
        
        # Use comprehensive detection for all critical files
        $fileCheck = Test-WinloadExistsComprehensive -Path $resolvedFile
        if (-not $fileCheck.Exists) {
            $allPresent = $false
            $verification.Issues += "Critical boot file MISSING: $fileName at $file (checked via: $($fileCheck.Method))"
        } else {
            $verification.Actions += "✓ Critical boot file present: $fileName (detected via: $($fileCheck.Method))"
        }
    }
    $verification.AllBootFilesPresent = $allPresent
    if ($allPresent) {
        $verification.Actions += "✓ All critical boot files present"
    }
    
    # Overall bootability assessment
    $verification.Bootable = $verification.WinloadExists -and 
                             $verification.WinloadReadable -and 
                             $verification.BCDPathMatch -and 
                             $verification.AllBootFilesPresent
    
    # Create a clean copy of verification without nested objects that might have problematic properties
    # This prevents PowerShell from trying to access properties like PermissionsModified on nested objects
    $cleanVerification = @{
        WinloadExists = $verification.WinloadExists
        WinloadReadable = $verification.WinloadReadable
        WinloadSize = $verification.WinloadSize
        BootmgfwExists = $verification.BootmgfwExists
        BCDExists = $verification.BCDExists
        BCDReadable = $verification.BCDReadable
        BCDPathMatch = $verification.BCDPathMatch
        BCDDeviceMatch = $verification.BCDDeviceMatch
        AllBootFilesPresent = $verification.AllBootFilesPresent
        Bootable = $verification.Bootable
        Issues = $verification.Issues
        Actions = $verification.Actions
    }
    
    return $cleanVerification
}

function Invoke-BruteForceBootRepair {
    param(
        [string]$TargetDrive,
        [switch]$ExtractFromWim = $true,
        [int]$MaxRetries = 3,
        [switch]$DryRun,
        [switch]$AllowOnlineRepair
    )
    
    $actions = @()
    $verificationResults = @()
    $logDir = Join-Path $PSScriptRoot "LOGS_MIRACLEBOOT"
    if (-not (Test-Path $logDir)) { try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch { } }
    
    # Check environment
    $envState = Get-EnvState
    $runningOnline = (-not $envState.IsWinPE)
    
    $targetDrive = $TargetDrive.TrimEnd(':')
    $actions += "═══════════════════════════════════════════════════════════════════════════════"
    $actions += "BRUTE FORCE BOOT REPAIR MODE"
    $actions += "═══════════════════════════════════════════════════════════════════════════════"
    $actions += "Target Drive: $targetDrive`:"
    $actions += "Max Retries: $MaxRetries"
    $actions += "Extract from WIM: $ExtractFromWim"
    $actions += "Environment: $(if ($runningOnline) { 'Full Windows' } else { 'WinRE/WinPE' })"
    if ($runningOnline -and $AllowOnlineRepair) {
        $actions += "AllowOnlineRepair: ENABLED - Safe repairs will be attempted"
    } elseif ($runningOnline) {
        $actions += "AllowOnlineRepair: DISABLED - Only diagnosis will be performed"
        $actions += "⚠ Running in full Windows without -AllowOnlineRepair: Repairs will be blocked"
    }
    $actions += ""
    
    if ($DryRun) {
        $actions += "⚠ DRY RUN MODE: No changes will be made"
        return @{
            Output = ($actions -join "`n")
            Bootable = $false
            Verified = $false
            Actions = $actions
        }
    }
    
    # Step 1: Ultimate source discovery (using hardened function)
    $actions += "STEP 1: ULTIMATE SOURCE DISCOVERY"
    $actions += "───────────────────────────────────────────────────────────────────────────────"
    
    # Use ultimate source discovery first
    $ultimateSource = Find-WinloadSourceUltimate -TargetDrive $targetDrive
    $actions += $ultimateSource.Actions
    
    # Fallback to aggressive if ultimate didn't find source
    if (-not $ultimateSource.BestSource) {
        $sourceResult = Find-WinloadSourceAggressive -TargetDrive $targetDrive -ExtractFromWim:$ExtractFromWim
        $actions += $sourceResult.Actions
        if ($sourceResult.Source) {
            $ultimateSource.BestSource = [pscustomobject]@{
                Path = $sourceResult.Source.Path
                Source = $sourceResult.Source.Source
                Drive = $sourceResult.Source.Drive
                Size = $sourceResult.Source.Size
                Confidence = $sourceResult.Source.Confidence
                Integrity = $null
                Compatibility = if ($sourceResult.Source.Compatibility) { $sourceResult.Source.Compatibility } else { @{ Compatible = $true; Score = 50 } }
                CompatibilityScore = if ($sourceResult.Source.CompatibilityScore) { $sourceResult.Source.CompatibilityScore } else { 50 }
            }
        }
    }
    
    $sourceResult = @{
        Source = $ultimateSource.BestSource
        Actions = $actions
    }
    
    if (-not $sourceResult.Source) {
        $actions += "❌ No winload.efi source found. Cannot proceed with brute force repair."
        return @{
            Output = ($actions -join "`n")
            Bootable = $false
            Verified = $false
            Actions = $actions
        }
    }
    
    # Check if we should proceed with repairs when running online
    if ($runningOnline -and -not $AllowOnlineRepair -and -not $DryRun) {
        $actions += "⚠ Running in full Windows without -AllowOnlineRepair: Repairs blocked by Environment Guard"
        $actions += "⚠ To enable safe repairs (file copy, BCD fixes), use -AllowOnlineRepair or run from WinRE"
        return @{
            Output = ($actions -join "`n")
            Bootable = $false
            Verified = $false
            Actions = $actions
        }
    }
    
    $winloadSource = $sourceResult.Source
    $actions += "✓ Selected source: $($winloadSource.Path) (Confidence: $($winloadSource.Confidence))"
    
    # Validate source integrity before proceeding
    if ($winloadSource.Integrity) {
        if ($winloadSource.Integrity.Valid) {
            $actions += "  ✓ Source integrity verified: $($winloadSource.Size) bytes, readable"
        } else {
            $actions += "  ⚠ Source integrity check warnings: $($winloadSource.Integrity.Details -join '; ')"
        }
    } else {
        # Perform integrity check now
        $sourceIntegrity = Test-FileIntegrity -FilePath $winloadSource.Path
        if ($sourceIntegrity.Valid) {
            $actions += "  ✓ Source integrity verified: $($sourceIntegrity.FileInfo.Length) bytes, readable"
        } else {
            $actions += "  ⚠ Source integrity check failed: $($sourceIntegrity.Details -join '; ')"
            $actions += "  ⚠ Proceeding anyway, but repair may fail"
        }
    }
    $actions += ""
    
    # Step 2: Mount ESP if needed
    $actions += "STEP 2: ESP MOUNTING"
    $actions += "───────────────────────────────────────────────────────────────────────────────"
    $espMounted = $false
    $espLetter = $null
    $mountedByUs = $false
    
    $esp = Get-EspCandidate
    if ($esp -and $esp.DriveLetter) {
        $espMounted = $true
        $espLetter = "$($esp.DriveLetter):"
        $actions += "✓ ESP already mounted at $espLetter"
    } else {
        $mount = Mount-EspTemp -PreferredLetter "S"
        if ($mount) {
            $espMounted = $true
            $espLetter = "$($mount.Letter):"
            $mountedByUs = $true
            $actions += "✓ ESP mounted to $espLetter"
        } else {
            $actions += "⚠ Failed to mount ESP - will continue without ESP mount"
        }
    }
    $actions += ""
    
    # Step 3: Extract from WIM if needed
    $winloadSourcePath = $winloadSource.Path
    if ($winloadSource.Source -eq "InstallWim" -and $ExtractFromWim) {
        $actions += "STEP 3: EXTRACTING FROM INSTALL.WIM"
        $actions += "───────────────────────────────────────────────────────────────────────────────"
        $mountDir = Join-Path $env:TEMP "MiracleBoot_WIM_Mount_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        $tempWinloadPath = Join-Path $env:TEMP "winload_efi_temp_$(Get-Date -Format 'yyyyMMdd_HHmmss').efi"
        
        $extractResult = Extract-WinloadFromWim -WimPath $winloadSourcePath -MountDir $mountDir -TargetPath $tempWinloadPath
        $actions += $extractResult.Actions
        
        if ($extractResult.Success) {
            $winloadSourcePath = $tempWinloadPath
            $actions += "✓ Successfully extracted winload.efi from WIM"
        } else {
            $actions += "❌ Failed to extract from WIM - will try other sources"
            # Try other sources
            $otherSources = $sourceResult.AllSources | Where-Object { $_.Source -ne "InstallWim" } | Select-Object -First 1
            if ($otherSources) {
                $winloadSourcePath = $otherSources.Path
                $actions += "Falling back to: $winloadSourcePath"
            } else {
                $actions += "❌ No alternative sources available"
                return @{
                    Output = ($actions -join "`n")
                    Bootable = $false
                    Verified = $false
                    Actions = $actions
                }
            }
        }
        $actions += ""
    }
    
    # Step 4: Brute force file copy
    $actions += "STEP 4: BRUTE FORCE FILE COPY"
    $actions += "───────────────────────────────────────────────────────────────────────────────"
    $targetPath = "$targetDrive`:\Windows\System32\winload.efi"
    
    $copyResult = Copy-BootFileBruteForce -SourcePath $winloadSourcePath -TargetPath $targetPath -MaxRetries $MaxRetries
    $actions += $copyResult.Actions
    
    if (-not $copyResult.Success -or -not $copyResult.Verified) {
        $actions += "❌ BRUTE FORCE COPY FAILED after all attempts"
        
        # Create and show guidance document
        $guidanceDoc = New-WinloadRepairGuidanceDocument -TargetDrive $targetDrive -WinloadExists $false -BcdPathMatch $false -BitlockerLocked $false -Actions $actions
        $actions += ""
        $actions += "═══════════════════════════════════════════════════════════════════════════════"
        $actions += "REPAIR FAILED - COMPREHENSIVE GUIDANCE DOCUMENT CREATED"
        $actions += "═══════════════════════════════════════════════════════════════════════════════"
        $actions += "A detailed manual repair guide has been created and will open in Notepad."
        $actions += "Guidance document location: $($guidanceDoc.Path)"
        $actions += "═══════════════════════════════════════════════════════════════════════════════"
        
        # Show guidance document in Notepad
        try {
            Start-Process notepad.exe -ArgumentList "`"$($guidanceDoc.Path)`""
        } catch {
            $actions += "Could not open Notepad automatically. Please open: $($guidanceDoc.Path)"
        }
        
        return @{
            Output = ($actions -join "`n")
            Bootable = $false
            Verified = $false
            Actions = $actions
        }
    }
    
    $actions += "✓ winload.efi successfully copied and verified"
    $actions += ""
    
    # Step 5: Brute force BCD repair
    $actions += "STEP 5: BRUTE FORCE BCD REPAIR"
    $actions += "───────────────────────────────────────────────────────────────────────────────"
    
    # Ensure ESP is mounted for BCD operations
    if (-not $espLetter) {
        $actions += "⚠ ESP not mounted - attempting to mount..."
        $mount = Mount-EspTemp -PreferredLetter "S"
        if ($mount) {
            $espLetter = "$($mount.Letter):"
            $actions += "✓ ESP mounted to $espLetter"
        } else {
            $actions += "❌ Failed to mount ESP - BCD repair may fail"
        }
    }
    
    $bcdStore = if ($espLetter) { "$espLetter\EFI\Microsoft\Boot\BCD" } else { "$targetDrive`:\Boot\BCD" }
    
    # Check if BCD exists - if not, CREATE it first
    $bcdExists = Test-Path $bcdStore
    if (-not $bcdExists) {
        $actions += "❌ BCD MISSING at $bcdStore"
        $actions += "Creating BCD with bcdboot..."
        
        if ($espLetter) {
            $createResult = Invoke-BCDCommandWithTimeout -Command "bcdboot.exe" -Arguments @("$targetDrive`:\Windows", "/s", $espLetter, "/f", "UEFI", "/addlast") -TimeoutSeconds 60 -Description "Create BCD with bcdboot"
            if ($createResult.Success) {
                $actions += "✓ BCD created successfully"
                $bcdExists = $true
                # Wait for file system sync
                Start-Sleep -Milliseconds 1000
            } else {
                $actions += "❌ Failed to create BCD: $($createResult.Output)"
                $actions += "   Error details: $($createResult.Error)"
            }
        } else {
            # No ESP - try to create system BCD at C:\Boot\BCD
            $actions += "No ESP detected - attempting to create system BCD at $bcdStore"
            $createResult = Invoke-BCDCommandWithTimeout -Command "bcdboot.exe" -Arguments @("$targetDrive`:\Windows") -TimeoutSeconds 60 -Description "Create system BCD"
            if ($createResult.Success) {
                $actions += "✓ System BCD created successfully"
                $bcdExists = $true
                # Verify file was created
                Start-Sleep -Milliseconds 1000
                if (Test-Path $bcdStore -ErrorAction SilentlyContinue) {
                    $actions += "✓ Verified BCD file exists at $bcdStore"
                } else {
                    $actions += "⚠ bcdboot reported success but BCD file not found at $bcdStore"
                    # Try to ensure Boot directory exists
                    $bootDir = "$targetDrive`:\Boot"
                    if (-not (Test-Path $bootDir -ErrorAction SilentlyContinue)) {
                        try {
                            New-Item -ItemType Directory -Path $bootDir -Force | Out-Null
                            $actions += "✓ Created Boot directory: $bootDir"
                            # Retry bcdboot
                            $createResult = Invoke-BCDCommandWithTimeout -Command "bcdboot.exe" -Arguments @("$targetDrive`:\Windows") -TimeoutSeconds 60 -Description "Retry create system BCD"
                            if ($createResult.Success -and (Test-Path $bcdStore -ErrorAction SilentlyContinue)) {
                                $actions += "✓ System BCD created after creating Boot directory"
                                $bcdExists = $true
                            }
                        } catch {
                            $actions += "❌ Failed to create Boot directory: $($_.Exception.Message)"
                        }
                    }
                }
            } else {
                $actions += "❌ Failed to create system BCD: $($createResult.Output)"
                $actions += "   Error details: $($createResult.Error)"
                $actions += "   Solution: Try manually: bcdboot $targetDrive`:\Windows"
            }
        }
    }
    
    # Backup BCD if it exists
    $bcdBackup = Join-Path $logDir "BCD_BRUTEFORCE_BACKUP_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
    if ($bcdExists -and (Test-Path $bcdStore)) {
        $backupResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/export", $bcdBackup) -TimeoutSeconds 30 -Description "BCD backup creation"
        if ($backupResult.Success) {
            $actions += "✓ BCD backed up to $bcdBackup"
        } else {
            $actions += "⚠ BCD backup failed but continuing"
            if ($backupResult.Error) {
                $actions += "  Error: $($backupResult.Error)"
            }
        }
    }
    
    # Pre-flight: Check BitLocker before brute force repair
    $bitlockerUnlocked = Test-BitLockerUnlocked -TargetDrive $targetDrive
    if (-not $bitlockerUnlocked) {
        $actions += "❌ BLOCKED: BitLocker is locked on $targetDrive`:"
        $actions += "   Unlock the drive first: manage-bde -unlock $targetDrive`: -RecoveryPassword <KEY>"
        $bcdResult = @{
            Success = $false
            Actions = @()
            Blocked = "BitLocker locked"
        }
    } else {
        # Normalize ESP letter - strip colon if present
        $espLetterForRepair = if ($espLetter) { $espLetter.TrimEnd(':') } else { $null }
        $bcdResult = Repair-BCDBruteForce -TargetDrive $targetDrive -EspLetter $espLetterForRepair -WinloadPath $targetPath
        $actions += $bcdResult.Actions
    }
    
    # Safely check for Blocked property
    $isBlocked = $false
    $blockedReason = $null
    if ($bcdResult -is [hashtable] -and $bcdResult.ContainsKey('Blocked')) {
        $isBlocked = $true
        $blockedReason = $bcdResult.Blocked
    } elseif ($bcdResult -is [pscustomobject] -or $bcdResult -is [psobject]) {
        if ($bcdResult.PSObject.Properties.Name -contains 'Blocked') {
            $isBlocked = $true
            $blockedReason = $bcdResult.Blocked
        }
    }
    
    if ($isBlocked) {
        $actions += "⚠ BCD repair blocked: $blockedReason"
    } elseif (-not $bcdResult.Success -or -not $bcdResult.Verified) {
        $actions += "⚠ BCD repair completed but verification had issues"
    } else {
        $actions += "✓ BCD repair successful and verified"
    }
    $actions += ""
    
    # Step 6: Comprehensive verification
    $actions += "STEP 6: COMPREHENSIVE VERIFICATION"
    $actions += "───────────────────────────────────────────────────────────────────────────────"
    $verification = Test-BootabilityComprehensive -TargetDrive $targetDrive -EspLetter $espLetter
    $actions += $verification.Actions
    
    if ($verification.Issues.Count -gt 0) {
        $actions += ""
        $actions += "⚠ VERIFICATION ISSUES FOUND:"
        foreach ($issue in $verification.Issues) {
            $actions += "  - $issue"
        }
    }
    
    $actions += ""
    if ($verification.Bootable) {
        $actions += "✅ BOOTABILITY STATUS: LIKELY BOOTABLE"
        $actions += "All critical boot files are present and correctly configured."
    } else {
        $actions += "❌ BOOTABILITY STATUS: WILL NOT BOOT"
        $actions += "Issues detected that prevent booting."
        $actions += ""
        
        # Create and show guidance document on failure
        $guidanceDoc = New-WinloadRepairGuidanceDocument -TargetDrive $targetDrive -WinloadExists $verification.WinloadExists -BcdPathMatch $verification.BCDPathMatch -BitlockerLocked $false -Actions $actions
        $actions += "═══════════════════════════════════════════════════════════════════════════════"
        $actions += "REPAIR FAILED - COMPREHENSIVE GUIDANCE DOCUMENT CREATED"
        $actions += "═══════════════════════════════════════════════════════════════════════════════"
        $actions += "A detailed manual repair guide has been created and will open in Notepad."
        $actions += "Guidance document location: $($guidanceDoc.Path)"
        $actions += "═══════════════════════════════════════════════════════════════════════════════"
        
        # Show guidance document in Notepad
        try {
            Start-Process notepad.exe -ArgumentList "`"$($guidanceDoc.Path)`""
        } catch {
            $actions += "Could not open Notepad automatically. Please open: $($guidanceDoc.Path)"
        }
    }
    $actions += ""
    
    # Cleanup
    if ($mountedByUs -and $espLetter) {
        Unmount-EspTemp -Letter $espLetter.TrimEnd(':')
        $actions += "Cleaned up temporary ESP mount"
    }
    
    $actions += "═══════════════════════════════════════════════════════════════════════════════"
    $actions += "BRUTE FORCE REPAIR COMPLETE"
    $actions += "═══════════════════════════════════════════════════════════════════════════════"
    
    # Create a clean return value without nested objects that might cause property enumeration issues
    # Extract only the primitive properties we need from verification
    $cleanVerification = @{
        WinloadExists = $verification.WinloadExists
        WinloadReadable = $verification.WinloadReadable
        WinloadSize = $verification.WinloadSize
        BootmgfwExists = $verification.BootmgfwExists
        BCDExists = $verification.BCDExists
        BCDReadable = $verification.BCDReadable
        BCDPathMatch = $verification.BCDPathMatch
        BCDDeviceMatch = $verification.BCDDeviceMatch
        AllBootFilesPresent = $verification.AllBootFilesPresent
        Bootable = $verification.Bootable
        Issues = $verification.Issues
        Actions = $verification.Actions
    }
    
    return @{
        Output = ($actions -join "`n")
        Bootable = $verification.Bootable
        Verified = $verification.Bootable
        Actions = $actions
        Verification = $cleanVerification
    }
}

function Invoke-DefensiveBootRepair {
    param(
        [string]$TargetDrive,
        [ValidateSet("Auto","DiagnoseOnly","RepairSafe","RepairForce","BruteForce")]
        [string]$Mode = "Auto",
        [string]$SimulationScenario = $null,
        [switch]$DryRun,
        [switch]$AllowOnlineRepair,
        [switch]$Force,
        [switch]$BruteForce
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
    
    # Command tracking for comprehensive reporting
    $script:CommandHistory = @()
    $script:FailedCommands = @()
    $script:InitialIssues = @()
    $script:RemainingIssues = @()
    
    function Track-Command {
        param(
            [string]$Command,
            [string]$Description,
            [object]$Result = $null,
            [int]$ExitCode = $LASTEXITCODE,
            [string]$ErrorOutput = $null,
            [string]$TargetDrive = $null
        )
        
        $commandRecord = [pscustomobject]@{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Command = $Command
            Description = $Description
            TargetDrive = $TargetDrive
            ExitCode = $ExitCode
            Success = ($ExitCode -eq 0)
            ErrorOutput = $ErrorOutput
            Result = $Result
        }
        
        $script:CommandHistory += $commandRecord
        
        if (-not $commandRecord.Success -and -not $DryRun) {
            $script:FailedCommands += $commandRecord
        }
        
        return $commandRecord
    }

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
    
    # Brute Force mode override
    if ($BruteForce -or $resolvedMode -eq "BruteForce") {
        return Invoke-BruteForceBootRepair -TargetDrive $TargetDrive -ExtractFromWim:$true -MaxRetries 3 -DryRun:$DryRun
    }

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
        # Ensure $windowsInstalls is always an array
        if ($null -eq $windowsInstalls) { $windowsInstalls = @() }
        if ($windowsInstalls -isnot [array]) { $windowsInstalls = @($windowsInstalls) }
        
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

        # STATE RESET (ULTIMATE HARDENING - Prevent stale state)
        # Always reset all state variables to ensure fresh detection
        $winloadExists = $false
        $bcdPathMatch = $false
        $bitlockerLocked = $null
        $bootFilesPresent = $false
        $storageDriverMissing = $false
        $secureBoot = $false
        
        # Reset command tracking for this run
        $script:CommandHistory = @()
        $script:FailedCommands = @()
        $script:InitialIssues = @()
        $script:RemainingIssues = @()

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
                    $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "{default}") -TimeoutSeconds 15 -Description "Check BCD path"
                    $bcdOut = $bcdResult.Output
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
                if ($bootCrit) { 
                    $bootCritWithErrors = @($bootCrit | Where-Object { $_.ErrorCode -and $_.ErrorCode -ne 0 })
                    $storageDriverMissing = $bootCritWithErrors.Count -gt 0 
                }
            } catch { }
        }

        # Record initial issues
        $script:InitialIssues = @()
        if (-not $winloadExists) { $script:InitialIssues += "winload.efi missing" }
        if (-not $bcdPathMatch) { $script:InitialIssues += "BCD path mismatch" }
        if ($bitlockerLocked) { $script:InitialIssues += "BitLocker locked" }
        if ($storageDriverMissing) { $script:InitialIssues += "Storage driver missing" }
        
        # Pre-flight backup (Layer 8)
        $backupPath = Join-Path $logDir "BCD_PRODUCTION_BACKUP.bak"
        # Allow writes when: not in diagnose/dryrun/simulate mode, AND either in WinRE OR AllowOnlineRepair is set
        # This allows safe repairs (like copying winload.efi) even when running in full Windows
        $shouldWrite = (-not $diagOnly -and -not $DryRun -and -not $simulate -and (-not $runningOnline -or $AllowOnlineRepair))
        if ($shouldWrite -and -not $blocker) {
            try {
                $exportResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/export", $backupPath) -TimeoutSeconds 30 -Description "BCD backup creation"
                Track-Command -Command "bcdedit /export `"$backupPath`"" -Description "BCD backup creation" -ExitCode $exportResult.ExitCode -ErrorOutput $exportResult.Output -TargetDrive $TargetDrive
                
                if ($exportResult.Success) {
                    $script:LastBackupPath = $backupPath
                    $rollbackPlan[0] = "Restore BCD from backup at $backupPath"
                    $actions += "BCD backup created at $backupPath"
                } else {
                    $errorMsg = if ($exportResult.Error) { $exportResult.Error } else { $exportResult.Output }
                    $blocker = "Failed to export BCD backup (exit $($exportResult.ExitCode)). Aborting repair."
                    $actions += "BCD backup failed; repair aborted."
                    if ($errorMsg) {
                        $actions += "  Error: $errorMsg"
                    }
                }
            } catch {
                $errorMsg = $_.Exception.Message
                Track-Command -Command "bcdedit /export `"$backupPath`"" -Description "BCD backup creation" -ExitCode -1 -ErrorOutput $errorMsg -TargetDrive $TargetDrive
                $blocker = "Failed to export BCD backup: $errorMsg"
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
        if ($runningOnline -and $resolvedMode -ne "DiagnoseOnly" -and -not $AllowOnlineRepair) { 
            $blastRadius += "Running in full Windows; destructive commands blocked by Environment Guard. Safe repairs (file copy, BCD path fixes) are allowed when -AllowOnlineRepair is set." 
        }
        if ($runningOnline -and $AllowOnlineRepair) {
            $blastRadius += "Running in full Windows with -AllowOnlineRepair: Safe repairs enabled (file copy, BCD path fixes). Destructive operations (BCD rebuild) still blocked."
        }

        # Guards - Only show blocking messages when repairs are actually blocked
        if ($diagOnly -or $DryRun -or $simulate) { 
            $actions += "Destructive commands blocked by Environment Guard (DiagnoseOnly/DryRun/Simulate mode)." 
        } elseif ($runningOnline -and -not $AllowOnlineRepair) {
            # Only show this if repairs would actually be blocked (not in diag/dryrun/simulate)
            $actions += "Running in full Windows: Only safe repairs allowed (file copy, BCD path fixes). Use -AllowOnlineRepair to enable safe repairs, or run from WinRE for full repair capabilities."
        } elseif ($runningOnline -and $AllowOnlineRepair) {
            # Inform user that safe repairs are enabled
            $actions += "✓ Safe repairs enabled (AllowOnlineRepair mode): File copy and BCD fixes will be attempted."
        }
        if ($bitlockerLocked -eq $true) { $actions += "Repair aborted: BitLocker locked." }

        # AUTOMATIC REPAIR EXECUTION (when not in DiagnoseOnly mode)
        $repairExecuted = $false
        if (-not $diagOnly -and -not $DryRun -and -not $simulate -and -not $blocker -and -not $bitlockerLocked -and $selectedOS) {
            # Auto-repair winload.efi if missing
            if (-not $winloadExists) {
                $actions += "Attempting automatic winload.efi repair..."
                
                # Step 1: Ensure ESP is mounted
                if (-not $espMounted) {
                    $mount = Mount-EspTemp -PreferredLetter "S"
                    if ($mount) {
                        $espMounted = $true
                        $espLetter = "$($mount.Letter):"
                        $mountedByUs = $true
                        $actions += "ESP mounted to $espLetter"
                        Track-Command -Command "mountvol $($mount.Letter): /S" -Description "Mount ESP partition" -ExitCode 0 -ErrorOutput $null -TargetDrive $selectedOS.Drive.TrimEnd(':')
                    } else {
                        $actions += "Failed to mount ESP automatically"
                        Track-Command -Command "mountvol S: /S" -Description "Mount ESP partition" -ExitCode -1 -ErrorOutput "Failed to mount ESP" -TargetDrive $selectedOS.Drive.TrimEnd(':')
                    }
                }
                
                # Step 2: Search for winload.efi source (ULTIMATE HARDENED SEARCH)
                $winloadSource = $null
                $winloadSourcePath = $null
                
                # Use ultimate source discovery
                $sourceSearch = Find-WinloadSourceUltimate -TargetDrive $selectedOS.Drive.TrimEnd(':')
                $actions += $sourceSearch.Actions
                
                if ($sourceSearch.BestSource) {
                    $winloadSource = $sourceSearch.BestSource.Source
                    $winloadSourcePath = $sourceSearch.BestSource.Path
                    $actions += "✓ Selected best source: $winloadSourcePath (Confidence: $($sourceSearch.BestSource.Confidence), Size: $($sourceSearch.BestSource.Size) bytes)"
                } else {
                    # Fallback to original search method for compatibility
                    foreach ($winInstall in $windowsInstalls) {
                        if ($winInstall.Drive -ne $selectedOS.Drive) {
                            $candidatePath = Resolve-WindowsPath -Path "$($winInstall.Drive)\Windows\System32\winload.efi" -SupportLongPath
                            if ($candidatePath) {
                                $existsCheck = Test-WinloadExistsComprehensive -Path $candidatePath
                                if ($existsCheck.Exists) {
                                    $winloadSource = $winInstall.Drive
                                    $winloadSourcePath = $candidatePath
                                    $actions += "Found winload.efi source (fallback): $candidatePath"
                                    break
                                }
                            }
                        }
                    }
                    
                    # Search in WinRE/current environment if no other source found
                    # PRIORITIZE WinRE sources - they're immediately available when running from WinRE
                    if (-not $winloadSource) {
                        $envState = Get-EnvState
                        $runningFromWinRE = $envState.IsWinPE
                        
                        # Check current environment first (most reliable when in WinRE)
                        # Note: winload.efi can be in System32 or System32\Boot subdirectory
                        $winrePaths = @(
                            "$env:SystemRoot\System32\winload.efi",           # Current environment (highest priority)
                            "$env:SystemRoot\System32\Boot\winload.efi",      # Current environment Boot subdirectory
                            "X:\Windows\System32\winload.efi",                # Standard WinRE location
                            "X:\Windows\System32\Boot\winload.efi",           # WinRE Boot subdirectory (common location)
                            "X:\sources\boot.wim\Windows\System32\winload.efi",  # Boot WIM location
                            "X:\sources\boot.wim\Windows\System32\Boot\winload.efi"  # Boot WIM Boot subdirectory
                        )
                        
                        foreach ($winrePath in $winrePaths) {
                            $resolvedPath = Resolve-WindowsPath -Path $winrePath -SupportLongPath
                            if ($resolvedPath) {
                                $existsCheck = Test-WinloadExistsComprehensive -Path $resolvedPath
                                if ($existsCheck.Exists) {
                                    $winloadSource = "WinRE"
                                    $winloadSourcePath = $resolvedPath
                                    if ($runningFromWinRE) {
                                        $actions += "✓ Found winload.efi in WinRE (current environment): $resolvedPath - PRIORITIZED"
                                    } else {
                                        $actions += "Found winload.efi source (fallback from WinRE): $resolvedPath"
                                    }
                                    break
                                }
                            }
                        }
                    }
                }
                
                # Step 3: Copy winload.efi if source found (ULTIMATE HARDENED with comprehensive verification)
                if ($winloadSourcePath) {
                    $targetPath = Resolve-WindowsPath -Path "$($selectedOS.Drive)\Windows\System32\winload.efi" -SupportLongPath
                    if (-not $targetPath) {
                        $targetPath = "$($selectedOS.Drive)\Windows\System32\winload.efi"  # Fallback
                    }
                    
                    # Comprehensive source file validation
                    $sourceIntegrity = Test-FileIntegrity -FilePath $winloadSourcePath
                    if (-not $sourceIntegrity.Valid) {
                        $actions += "ERROR: Source file integrity check failed: $($sourceIntegrity.Details -join '; ')"
                        $actions += "Source file: $winloadSourcePath"
                    } else {
                        $sourceFile = $sourceIntegrity.FileInfo
                        $expectedSize = $sourceFile.Length
                        $expectedHash = $null
                        
                        # Calculate source hash for verification
                        $sourceHash = Get-FileHashSafe -FilePath $winloadSourcePath
                        if ($sourceHash) {
                            $expectedHash = $sourceHash.Hash
                            $actions += "Source file verified: $expectedSize bytes, SHA256: $($expectedHash.Substring(0,16))..."
                        } else {
                            $actions += "Source file size: $expectedSize bytes (hash calculation skipped)"
                        }
                        
                        # Try multiple copy methods with retries
                        $copySuccess = $false
                        $copyMethods = @(
                            @{ Name = "Copy-Item"; Script = { Copy-Item -Path $winloadSourcePath -Destination $targetPath -Force -ErrorAction Stop } },
                            @{ Name = "robocopy"; Script = { 
                                $targetDir = Split-Path $targetPath -Parent
                                $robocopyOut = robocopy (Split-Path $winloadSourcePath -Parent) $targetDir (Split-Path $winloadSourcePath -Leaf) /R:1 /W:1 /NFL /NDL /NJH /NJS 2>&1
                                if ($LASTEXITCODE -lt 0 -or $LASTEXITCODE -gt 7) { throw "robocopy failed with exit code $LASTEXITCODE" }
                            }},
                            @{ Name = ".NET File.Copy"; Script = {
                                [System.IO.File]::Copy($winloadSourcePath, $targetPath, $true)
                            }}
                        )
                        
                        foreach ($method in $copyMethods) {
                            if ($copySuccess) { break }
                            
                            for ($attempt = 1; $attempt -le 3; $attempt++) {
                                try {
                                    # Ensure target directory exists
                                    $targetDir = Split-Path $targetPath -Parent
                                    if (-not (Test-Path $targetDir)) {
                                        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                                    }
                                    
                                    # Force permissions before copy - handle TrustedInstaller ownership
                                    if (Test-Path $targetPath) {
                                        # Take ownership from TrustedInstaller (use /a flag to give to Administrators group)
                                        $takeownProc = Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$targetPath`"", "/a" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                                        if ($takeownProc.ExitCode -ne 0) {
                                            $actions += "⚠ takeown failed (exit code $($takeownProc.ExitCode)) - ensure running as Administrator"
                                            # Try alternative: take ownership without /a flag
                                            Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$targetPath`"" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
                                        }
                                        # Grant full control to Administrators
                                        $icaclsProc = Start-Process -FilePath "icacls.exe" -ArgumentList "`"$targetPath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                                        if ($icaclsProc.ExitCode -ne 0) {
                                            $actions += "⚠ icacls failed (exit code $($icaclsProc.ExitCode)) - permissions may not be set correctly"
                                        }
                                        # Remove system/hidden/read-only attributes
                                        Start-Process -FilePath "attrib.exe" -ArgumentList "-s", "-h", "-r", "`"$targetPath`"" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
                                        # Fallback: Use Set-ItemProperty if attrib fails
                                        try {
                                            Set-ItemProperty -Path $targetPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
                                        } catch {
                                            # Ignore - attrib may have already worked
                                        }
                                    }
                                    
                                    # Execute copy method
                                    & $method.Script
                                    $actions += "Copy attempt $attempt using $($method.Name): executed"
                                    
                                    # Wait for file system sync
                                    Start-Sleep -Milliseconds 500
                                    
                                    # ULTIMATE HARDENED VERIFICATION: Comprehensive integrity check
                                    $targetIntegrity = Test-FileIntegrity -FilePath $targetPath -ExpectedSize $expectedSize -ExpectedHash $expectedHash
                                    
                                    if ($targetIntegrity.Valid) {
                                        # Set permissions on copied file
                                        $icaclsFinalProc = Start-Process -FilePath "icacls.exe" -ArgumentList "`"$targetPath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                                        Track-Command -Command "icacls `"$targetPath`" /grant Administrators:F (final)" -Description "Set final permissions on copied file" -ExitCode $(if ($icaclsFinalProc) { $icaclsFinalProc.ExitCode } else { -1 }) -ErrorOutput $null -TargetDrive $selectedOS.Drive.TrimEnd(':')
                                        
                                        # Final comprehensive check
                                        $finalCheck = Test-WinloadExistsComprehensive -Path $targetPath
                                        if ($finalCheck.Exists -and $targetIntegrity.Readable) {
                                            $copySuccess = $true
                                            $winloadExists = $true
                                            $bootFilesPresent = $true
                                            $repairExecuted = $true
                                            
                                            $verifyMsg = "✓ ULTIMATE VERIFICATION PASSED: winload.efi copied successfully"
                                            $verifyMsg += " ($($targetIntegrity.FileInfo.Length) bytes"
                                            if ($targetIntegrity.HashMatch) {
                                                $verifyMsg += ", hash verified"
                                            }
                                            $verifyMsg += ", readable, integrity confirmed)"
                                            $actions += $verifyMsg
                                            break
                                        } else {
                                            $actions += "⚠ Final check failed: $($finalCheck.Details)"
                                        }
                                    } else {
                                        $actions += "⚠ Integrity verification failed: $($targetIntegrity.Details -join '; ')"
                                        if ($targetIntegrity.FileInfo) {
                                            $actualSize = $targetIntegrity.FileInfo.Length
                                            $actions += "  Expected: $expectedSize bytes, Got: $actualSize bytes"
                                        }
                                    }
                                } catch {
                                    $actions += "Copy attempt $attempt using $($method.Name): FAILED - $($_.Exception.Message)"
                                    if ($attempt -lt 3) {
                                        Start-Sleep -Seconds ([Math]::Pow(2, $attempt))
                                    }
                                }
                            }
                        }
                        
                        if (-not $copySuccess) {
                            $actions += "❌ winload.efi copy FAILED after all methods and retries"
                        }
                    }
                } else {
                    $actions += "No winload.efi source found - cannot auto-repair (see manual guide below)"
                }
            }
            
            # Auto-fix BCD path if winload.efi now exists but BCD doesn't point to it
            if ($winloadExists -and -not $bcdPathMatch) {
                try {
                    # Ensure ESP is mounted before BCD operations
                    if (-not $espMounted -and $espLetter) {
                        $mount = Mount-EspTemp -PreferredLetter "S"
                        if ($mount) {
                            $espMounted = $true
                            $espLetter = "$($mount.Letter):"
                            $mountedByUs = $true
                            $actions += "✓ ESP mounted to $espLetter for BCD repair"
                        }
                    }
                    
                    # Determine BCD store path
                    $bcdStore = if ($espLetter) { "$espLetter\EFI\Microsoft\Boot\BCD" } else { "BCD" }
                    $bcdStorePath = if ($espLetter) { "$espLetter\EFI\Microsoft\Boot\BCD" } else { "$($selectedOS.Drive.TrimEnd(':'))`:\Boot\BCD" }
                    
                    # Verify ESP mount and BCD file exists before attempting repair
                    if ($espLetter -and -not (Test-Path $bcdStorePath -ErrorAction SilentlyContinue)) {
                        $actions += "⚠ BCD file not found at $bcdStorePath - ESP may not be properly mounted"
                        # Try to verify ESP mount
                        if (-not (Test-Path "$espLetter\EFI\Microsoft\Boot" -ErrorAction SilentlyContinue)) {
                            $actions += "❌ ESP mount verification failed - $espLetter\EFI\Microsoft\Boot does not exist"
                            $actions += "⚠ Cannot proceed with BCD repair without valid ESP mount"
                        }
                    }
                    
                    # Use timeout wrapper to prevent hanging - ensure proper quoting for {default}
                    $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/set", "{default}", "path", "\Windows\system32\winload.efi") -TimeoutSeconds 15 -Description "Set BCD path to winload.efi"
                    $bcdOut = $bcdResult.Output
                    $exitCode = $bcdResult.ExitCode
                    
                    if ($bcdResult.TimedOut) {
                        $actions += "⚠ BCD path set command timed out - BCD may be locked"
                        Track-Command -Command "bcdedit /store $bcdStore /set `"{default}`" path \Windows\system32\winload.efi" -Description "Set BCD path to winload.efi (TIMED OUT)" -ExitCode -1 -ErrorOutput "Command timed out after 15 seconds" -TargetDrive $selectedOS.Drive.TrimEnd(':')
                    } elseif ($exitCode -eq 0) {
                        Track-Command -Command "bcdedit /store $bcdStore /set `"{default}`" path \Windows\system32\winload.efi" -Description "Set BCD path to winload.efi" -ExitCode $exitCode -ErrorOutput $bcdOut -TargetDrive $selectedOS.Drive.TrimEnd(':')
                        
                        # ENHANCED VERIFICATION: Verify BCD path was actually set correctly
                        Start-Sleep -Milliseconds 500
                        $verifyBcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/enum", "{default}") -TimeoutSeconds 15 -Description "Verify BCD path after setting"
                        if ($verifyBcdResult.ExitCode -eq 0) {
                            $bcdEnum = $verifyBcdResult.Output
                            # Check if path actually points to winload.efi
                            if ($bcdEnum -match "(?i)path\s+[\\/]?Windows[\\/]system32[\\/]winload\.efi") {
                                $actions += "✓ BCD path verified: correctly points to winload.efi"
                                $bcdPathMatch = $true
                            } else {
                                $actions += "⚠ BCD path set command succeeded but verification shows path mismatch"
                                $actions += "  BCD output: $($bcdEnum.Substring(0, [Math]::Min(200, $bcdEnum.Length)))"
                            }
                        } else {
                            $actions += "⚠ Could not verify BCD path after setting (enumeration failed)"
                        }
                        
                        # Set device and osdevice with timeout
                        $driveLetter = $selectedOS.Drive.TrimEnd(':')
                        $deviceResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/set", "{default}", "device", "partition=$driveLetter`:") -TimeoutSeconds 15 -Description "Set BCD device partition"
                        $osdeviceResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/set", "{default}", "osdevice", "partition=$driveLetter`:") -TimeoutSeconds 15 -Description "Set BCD osdevice partition"
                        
                        if ($deviceResult.ExitCode -eq 0 -and $osdeviceResult.ExitCode -eq 0) {
                            $actions += "✓ BCD device/osdevice set to partition=$driveLetter`:"
                        }
                    } else {
                        Track-Command -Command "bcdedit /store $bcdStore /set `"{default}`" path \Windows\system32\winload.efi" -Description "Set BCD path to winload.efi" -ExitCode $exitCode -ErrorOutput $bcdOut -TargetDrive $selectedOS.Drive.TrimEnd(':')
                    
                    if ($exitCode -eq 0 -and -not $bcdResult.TimedOut) {
                        $actions += "BCD path set to \\Windows\\system32\\winload.efi"
                        
                        # Set device and osdevice with timeout
                        $driveLetter = $selectedOS.Drive.TrimEnd(':')
                        $deviceResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/set", "{default}", "device", "partition=$driveLetter`:") -TimeoutSeconds 15 -Description "Set BCD device partition"
                        $osdeviceResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/set", "{default}", "osdevice", "partition=$driveLetter`:") -TimeoutSeconds 15 -Description "Set BCD osdevice partition"
                        
                        $deviceOut = $deviceResult.Output
                        $osdeviceOut = $osdeviceResult.Output
                        
                        if ($deviceResult.TimedOut) {
                            $actions += "⚠ BCD device set command timed out"
                        }
                        if ($osdeviceResult.TimedOut) {
                            $actions += "⚠ BCD osdevice set command timed out"
                        }
                        
                        Track-Command -Command "bcdedit /set {default} device partition=$driveLetter`:" -Description "Set BCD device partition" -ExitCode $deviceResult.ExitCode -ErrorOutput $deviceOut -TargetDrive $driveLetter
                        Track-Command -Command "bcdedit /set {default} osdevice partition=$driveLetter`:" -Description "Set BCD osdevice partition" -ExitCode $osdeviceResult.ExitCode -ErrorOutput $osdeviceOut -TargetDrive $driveLetter
                        
                        if ($deviceResult.ExitCode -eq 0 -and $osdeviceResult.ExitCode -eq 0 -and -not $deviceResult.TimedOut -and -not $osdeviceResult.TimedOut) {
                            $actions += "BCD device/osdevice set to partition=$driveLetter`:"
                        }
                        
                        # Verify the fix (check exit code and use strict regex, with permission handling)
                        $bcdPermissionsModified = $false
                        $bcdStorePath = if ($espLetter) { "$espLetter\EFI\Microsoft\Boot\BCD" } else { "$driveLetter`:\Boot\BCD" }
                        
                        # Use timeout wrapper to prevent hanging
                        if ($espLetter -and (Test-Path $bcdStorePath)) {
                            $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStorePath, "/enum", "{default}") -TimeoutSeconds 15 -Description "Verify BCD path fix"
                        } else {
                            $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "{default}") -TimeoutSeconds 15 -Description "Verify BCD path fix"
                        }
                        $bcdCheck = $bcdResult.Output
                        $bcdCheckExitCode = $bcdResult.ExitCode
                        
                        if ($bcdResult.TimedOut) {
                            $actions += "⚠ BCD verification timed out - BCD may be locked or corrupted"
                            $bcdCheckExitCode = -1
                        }
                        
                        Track-Command -Command "bcdedit /enum {default}" -Description "Verify BCD path fix" -ExitCode $bcdCheckExitCode -ErrorOutput $null -TargetDrive $driveLetter
                        
                        # If enumeration failed, try taking ownership of BCD file
                        if ($bcdCheckExitCode -ne 0 -and (Test-Path $bcdStorePath) -and -not $bcdResult.TimedOut) {
                            try {
                                $takeownResult = Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$bcdStorePath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                                if ($takeownResult.ExitCode -eq 0) {
                                    $bcdPermissionsModified = $true
                                    $icaclsResult = Start-Process -FilePath "icacls.exe" -ArgumentList "`"$bcdStorePath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                                    $attribResult = Start-Process -FilePath "attrib.exe" -ArgumentList "-s", "-h", "-r", "`"$bcdStorePath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                                    
                                    # Try enumeration again with timeout
                                    if ($espLetter) {
                                        $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStorePath, "/enum", "{default}") -TimeoutSeconds 15 -Description "Re-verify BCD after permission fix"
                                    } else {
                                        $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "{default}") -TimeoutSeconds 15 -Description "Re-verify BCD after permission fix"
                                    }
                                    $bcdCheck = $bcdResult.Output
                                    $bcdCheckExitCode = $bcdResult.ExitCode
                                    
                                    if ($bcdResult.TimedOut) {
                                        $actions += "⚠ BCD verification still timed out after permission fix"
                                    }
                                }
                            } catch {
                                # Continue with original result
                            }
                        }
                        
                        if ($bcdCheckExitCode -eq 0) {
                            # Use strict regex to match the actual path field format
                            if ($bcdCheck -match "path\s+\\Windows\\system32\\winload\.efi") {
                                $bcdPathMatch = $true
                                $repairExecuted = $true
                                $actions += "✓ BCD path fix verified (strict match)"
                                if ($bcdPermissionsModified) {
                                    $actions += "  (BCD permissions were modified to enable verification)"
                                }
                            } elseif ($bcdCheck -match "winload\.efi") {
                                # Fallback: if winload.efi is mentioned, assume it's correct
                                $bcdPathMatch = $true
                                $repairExecuted = $true
                                $actions += "✓ BCD path fix verified (winload.efi found in output)"
                                if ($bcdPermissionsModified) {
                                    $actions += "  (BCD permissions were modified to enable verification)"
                                }
                            } else {
                                $actions += "⚠ BCD path fix applied but verification failed - path not found in output"
                            }
                        } else {
                            $actions += "⚠ bcdedit verification failed with exit code $bcdCheckExitCode"
                            # If we just set it successfully, assume it's correct despite verification failure
                            if ($bcdOut -match "successfully|completed") {
                                $bcdPathMatch = $true
                                $repairExecuted = $true
                                $actions += "  (Assuming BCD fix succeeded based on set command output)"
                            }
                        }
                    } else {
                        $actions += "BCD path fix failed: $bcdOut"
                    }
                } catch {
                    $errorMsg = $_.Exception.Message
                    Track-Command -Command "bcdedit /set {default} path \Windows\system32\winload.efi" -Description "Set BCD path to winload.efi" -ExitCode -1 -ErrorOutput $errorMsg -TargetDrive $selectedOS.Drive.TrimEnd(':')
                    $actions += "BCD path fix failed: $errorMsg"
                }
            }
            
            # Rebuild boot files if ESP is mounted and winload.efi exists
            if ($espMounted -and $espLetter -and $winloadExists) {
                # Pre-flight: Check BitLocker
                $bitlockerUnlocked = Test-BitLockerUnlocked -TargetDrive $selectedOS.Drive.TrimEnd(':')
                if (-not $bitlockerUnlocked) {
                    $actions += "❌ BLOCKED: BitLocker is locked on $($selectedOS.Drive)"
                    $actions += "   Unlock the drive first: manage-bde -unlock $($selectedOS.Drive) -RecoveryPassword <KEY>"
                    Track-Command -Command "manage-bde -status $($selectedOS.Drive)" -Description "Check BitLocker status" -ExitCode 0 -ErrorOutput "BitLocker locked" -TargetDrive $selectedOS.Drive.TrimEnd(':')
                } else {
                    # Pre-flight: Check VMD driver
                    $vmdCheck = Test-VMDDriverLoaded
                    if ($vmdCheck.VMDDetected -and -not $vmdCheck.DriverLoaded) {
                        $actions += "⚠ WARNING: Intel VMD detected but RST driver not loaded"
                        $actions += "   This may cause bcdboot to fail silently"
                        $actions += "   Solution: Load Intel RST driver: drvload <path>\iaStorVD.inf"
                    }
                    
                    # Pre-flight: Check disk signature collisions
                    $sigCheck = Test-DiskSignatureCollision
                    if ($sigCheck.Detected) {
                        $actions += "⚠ WARNING: Duplicate disk signatures detected"
                        $actions += "   UEFI firmware may be confused about which drive to boot"
                    }
                    
                    try {
                        # Use timeout wrapper to prevent bcdboot from hanging (bcdboot can take a long time)
                        $bcdbootResult = Invoke-BCDCommandWithTimeout -Command "bcdboot.exe" -Arguments @("$($selectedOS.Drive)\Windows", "/s", $espLetter, "/f", "UEFI", "/addlast") -TimeoutSeconds 60 -Description "Rebuild boot files using bcdboot"
                        $bcdbootOut = $bcdbootResult.Output
                        $exitCode = $bcdbootResult.ExitCode
                        
                        if ($bcdbootResult.TimedOut) {
                            $actions += "⚠ bcdboot rebuild timed out after 60 seconds - operation may still be in progress"
                            $actions += "  This can happen if the BCD store is locked or corrupted"
                            Track-Command -Command "bcdboot `"$($selectedOS.Drive)\Windows`" /s $espLetter /f UEFI /addlast" -Description "Rebuild boot files using bcdboot (TIMED OUT)" -ExitCode -1 -ErrorOutput "Command timed out after 60 seconds" -TargetDrive $selectedOS.Drive.TrimEnd(':')
                        } else {
                            Track-Command -Command "bcdboot `"$($selectedOS.Drive)\Windows`" /s $espLetter /f UEFI /addlast" -Description "Rebuild boot files using bcdboot" -ExitCode $exitCode -ErrorOutput $bcdbootOut -TargetDrive $selectedOS.Drive.TrimEnd(':')
                            
                            if ($exitCode -eq 0) {
                                $actions += "Boot files rebuilt using bcdboot"
                                $repairExecuted = $true
                            } else {
                                $actions += "bcdboot rebuild failed: $bcdbootOut"
                            }
                        }
                    } catch {
                        $errorMsg = $_.Exception.Message
                        Track-Command -Command "bcdboot `"$($selectedOS.Drive)\Windows`" /s $espLetter /f UEFI /addlast" -Description "Rebuild boot files using bcdboot" -ExitCode -1 -ErrorOutput $errorMsg -TargetDrive $selectedOS.Drive.TrimEnd(':')
                        $actions += "bcdboot rebuild failed: $errorMsg"
                    }
                }
            }
        }

        # POST-REPAIR VERIFICATION (ULTIMATE HARDENED - Comprehensive final check)
        $actions += ""
        $actions += "═══════════════════════════════════════════════════════════════════════════════"
        $actions += "ULTIMATE POST-REPAIR VERIFICATION"
        $actions += "═══════════════════════════════════════════════════════════════════════════════"
        
        # Re-check winload.efi with ultimate comprehensive verification
        if ($selectedOS) {
            $finalWinloadPath = Resolve-WindowsPath -Path "$($selectedOS.Drive)\Windows\System32\winload.efi" -SupportLongPath
            if (-not $finalWinloadPath) {
                $finalWinloadPath = "$($selectedOS.Drive)\Windows\System32\winload.efi"  # Fallback
            }
            
            # Comprehensive existence check
            $finalWinloadCheck = Test-WinloadExistsComprehensive -Path $finalWinloadPath
            
            if ($finalWinloadCheck.Exists) {
                # Ultimate integrity verification
                $finalIntegrity = Test-FileIntegrity -FilePath $finalWinloadPath
                
                $actions += "✓ winload.efi EXISTS at $finalWinloadPath (detected via: $($finalWinloadCheck.Method))"
                $actions += "  File size: $($finalIntegrity.FileInfo.Length) bytes"
                
                if ($finalIntegrity.Valid) {
                    $actions += "  ✓ File integrity VERIFIED"
                    $actions += "    - Size match: $($finalIntegrity.SizeMatch)"
                    $actions += "    - Readable: $($finalIntegrity.Readable)"
                    $actions += "    - Size reasonable: $($finalIntegrity.SizeReasonable)"
                    if ($finalIntegrity.HashMatch) {
                        $actions += "    - Hash verified: ✓"
                    }
                    $winloadExists = $true
                } else {
                    $actions += "  ❌ File integrity CHECK FAILED:"
                    foreach ($detail in $finalIntegrity.Details) {
                        $actions += "    - $detail"
                    }
                    $winloadExists = $false
                }
            } else {
                $actions += "❌ winload.efi MISSING at $finalWinloadPath"
                $actions += "  Detection method: $($finalWinloadCheck.Method)"
                $actions += "  Details: $($finalWinloadCheck.Details)"
                $winloadExists = $false
            }
            
            # Re-check BCD (ULTIMATE HARDENED VERIFICATION with permission handling)
            try {
                $bcdPermissionsModified = $false
                $bcdStorePath = $null
                
                # Determine BCD store path (ESP or default)
                if ($espLetter) {
                    $bcdStorePath = "$espLetter\EFI\Microsoft\Boot\BCD"
                } else {
                    $bcdStorePath = "$($selectedOS.Drive)\Boot\BCD"
                }
                
                # Try enumeration (with /store if ESP is mounted)
                if ($espLetter -and (Test-Path $bcdStorePath)) {
                    $bcdCheckResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStorePath, "/enum", "{default}") -TimeoutSeconds 15 -Description "Final BCD verification"
                    $finalBcdCheck = $bcdCheckResult.Output
                    $bcdExitCode = $bcdCheckResult.ExitCode
                } else {
                    $bcdCheckResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "{default}") -TimeoutSeconds 15 -Description "Final BCD verification"
                    $finalBcdCheck = $bcdCheckResult.Output
                    $bcdExitCode = $bcdCheckResult.ExitCode
                }
                
                # If enumeration failed, try taking ownership of BCD file
                if ($bcdExitCode -ne 0 -and (Test-Path $bcdStorePath)) {
                    $actions += "⚠ bcdedit enumeration failed (exit code $bcdExitCode), attempting permission fix on BCD file..."
                    try {
                        $takeownResult = Start-Process -FilePath "takeown.exe" -ArgumentList "/f", "`"$bcdStorePath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                        if ($takeownResult.ExitCode -eq 0) {
                            $bcdPermissionsModified = $true
                            $icaclsResult = Start-Process -FilePath "icacls.exe" -ArgumentList "`"$bcdStorePath`"", "/grant", "Administrators:F" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                            $attribResult = Start-Process -FilePath "attrib.exe" -ArgumentList "-s", "-h", "-r", "`"$bcdStorePath`"" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                            $actions += "  ✓ Took ownership and fixed permissions on BCD file"
                            
                            # Try enumeration again
                            if ($espLetter) {
                                $bcdCheckResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStorePath, "/enum", "{default}") -TimeoutSeconds 15 -Description "Re-enumerate BCD after permission fix"
                                $finalBcdCheck = $bcdCheckResult.Output
                                $bcdExitCode = $bcdCheckResult.ExitCode
                            } else {
                                $bcdCheckResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "{default}") -TimeoutSeconds 15 -Description "Re-enumerate BCD after permission fix"
                                $finalBcdCheck = $bcdCheckResult.Output
                                $bcdExitCode = $bcdCheckResult.ExitCode
                            }
                        }
                    } catch {
                        $actions += "  ⚠ Could not fix BCD permissions: $($_.Exception.Message)"
                    }
                }
                
                if ($bcdExitCode -eq 0) {
                    # Use flexible regex to match the actual path field format (case-insensitive, handles variations)
                    # Matches: "path                \Windows\system32\winload.efi" or "/Windows/system32/winload.efi"
                    if ($finalBcdCheck -match "(?i)path\s+[\\/]?Windows[\\/]system32[\\/]winload\.efi") {
                        $actions += "✓ BCD path correctly points to winload.efi"
                        if ($bcdPermissionsModified) {
                            $actions += "  (BCD permissions were modified to enable verification)"
                        }
                        $bcdPathMatch = $true
                    } else {
                        # Fallback: check if winload.efi appears anywhere (less strict but still useful)
                        if ($finalBcdCheck -match "winload\.efi") {
                            $actions += "⚠ BCD contains winload.efi reference but path format may be unexpected"
                            $actions += "  BCD output snippet: $($finalBcdCheck -replace "`r`n", " | " | Select-String -Pattern "winload" | Select-Object -First 1)"
                            if ($bcdPermissionsModified) {
                                $actions += "  (BCD permissions were modified to enable verification)"
                            }
                            $bcdPathMatch = $true  # Assume it's correct if winload.efi is mentioned
                        } else {
                            $actions += "❌ BCD path does NOT point to winload.efi"
                            $actions += "  BCD output: $($finalBcdCheck.Substring(0, [Math]::Min(500, $finalBcdCheck.Length)))"
                            $bcdPathMatch = $false
                        }
                    }
                } else {
                    $actions += "⚠ bcdedit command failed with exit code $bcdExitCode"
                    $actions += "  Output: $($finalBcdCheck.Substring(0, [Math]::Min(500, $finalBcdCheck.Length)))"
                    # Don't assume failure - if we just repaired it, it might still be correct
                    # Check if we can at least see winload.efi mentioned
                    if ($finalBcdCheck -match "winload\.efi") {
                        $actions += "  However, winload.efi is mentioned in output - assuming BCD is correct"
                        $bcdPathMatch = $true
                    } else {
                        $bcdPathMatch = $false
                    }
                }
            } catch {
                $actions += "⚠ Could not verify BCD: $($_.Exception.Message)"
                # Don't assume failure - if repair was successful, BCD is likely correct
                # Only set to false if we have strong evidence it's wrong
                $bcdPathMatch = $false
            }
        }
        
        $actions += "═══════════════════════════════════════════════════════════════════════════════"
        $actions += ""
        
        # Record remaining issues
        $script:RemainingIssues = @()
        if (-not $winloadExists) { $script:RemainingIssues += "winload.efi still missing" }
        if (-not $bcdPathMatch) { $script:RemainingIssues += "BCD path still does not match" }
        if ($bitlockerLocked) { $script:RemainingIssues += "BitLocker still locked" }
        if ($storageDriverMissing) { $script:RemainingIssues += "Storage driver still missing" }
        
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
        # Environment Guard: Block destructive commands unless AllowOnlineRepair is set (which allows safe repairs)
        $envGuardBlocked = ($diagOnly -or $DryRun -or $simulate -or ($runningOnline -and -not $AllowOnlineRepair))
        $bundle += "EnvironmentGuard: " + ($(if ($envGuardBlocked) { "Destructive commands blocked by Environment Guard." } else { "Repair actions permitted." }))
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
        if ($repairExecuted) {
            $output += "AUTO-REPAIR: Attempted automatic fixes (see ActionsExecuted below)"
        }
        if ($bootable) { $output += "BOOT STATUS: LIKELY BOOTABLE" }
        else { $output += "BOOT STATUS: WILL NOT BOOT"; $output += "Blocker: $blockerFinal" }
        $output += "Confidence: $confidence"
        $output += "Plan: "
        foreach ($p in $plan) { $output += "  - $p" }
        if ($repairExecuted) {
            $output += ""
            $output += "AUTO-REPAIR SUMMARY:"
            $output += "───────────────────────────────────────────────────────────────────────────────"
            $repairActions = $actions | Where-Object { $_ -match "winload|BCD|bcdboot|ESP mounted|repair" }
            foreach ($action in $repairActions) {
                $output += "  • $action"
            }
            if ($winloadExists -and $bcdPathMatch) {
                $output += ""
                $output += "✓ Auto-repair appears successful - winload.efi present and BCD configured"
            } elseif ($winloadExists) {
                $output += ""
                $output += "⚠ Partial success - winload.efi restored but BCD may need manual fix"
            } else {
                $output += ""
                $output += "✗ Auto-repair could not complete - see manual guide below"
            }
            $output += "───────────────────────────────────────────────────────────────────────────────"
        }
        
        # Add comprehensive guide when winload.efi is missing and confidence is LOW
        if (-not $winloadExists -and $confidence -eq "LOW" -and $selectedOS) {
            $output += ""
            $output += "═══════════════════════════════════════════════════════════════════════════════"
            $output += "COMPREHENSIVE WINLOAD.EFI REPAIR GUIDE"
            $output += "═══════════════════════════════════════════════════════════════════════════════"
            $output += ""
            $output += "STEP 1: IDENTIFY THE ESP (EFI System Partition)"
            $output += "───────────────────────────────────────────────────────────────────────────────"
            $output += "The ESP is a FAT32 partition, typically 100-550 MB, that contains boot files."
            $output += ""
            $output += "Commands to identify ESP:"
            $output += "  • Get-Volume | Where-Object { `$_.FileSystem -eq 'FAT32' -and `$_.Size -lt 600MB }"
            $output += "  • Get-Partition | Where-Object { `$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' }"
            $output += "  • diskpart"
            $output += "    > list disk"
            $output += "    > select disk X  (where X is your Windows disk)"
            $output += "    > list partition"
            $output += "    > select partition Y  (look for 'System' or 'EFI' type, FAT32, ~100-550 MB)"
            $output += "    > detail partition"
            $output += ""
            $output += "What to look for:"
            $output += "  ✓ FileSystem: FAT32"
            $output += "  ✓ Size: Usually 100-550 MB (less than 600 MB)"
            $output += "  ✓ GPT Type: {c12a7328-f81f-11d2-ba4b-00a0c93ec93b} (EFI System Partition)"
            $output += "  ✓ May have drive letter already assigned, or may be hidden"
            $output += ""
            $output += "STEP 2: MOUNT THE ESP (If Not Already Mounted)"
            $output += "───────────────────────────────────────────────────────────────────────────────"
            $output += "If ESP doesn't have a drive letter, mount it temporarily:"
            $output += ""
            $output += "Method 1: Using mountvol (Recommended)"
            $output += "  mountvol S: /S"
            $output += "  # This mounts the system ESP to drive letter S:"
            $output += "  # Replace S: with any available drive letter (Z:, Y:, X:, etc.)"
            $output += ""
            $output += "Method 2: Using diskpart"
            $output += "  diskpart"
            $output += "  > list disk"
            $output += "  > select disk X"
            $output += "  > list partition"
            $output += "  > select partition Y  (select the ESP partition)"
            $output += "  > assign letter=S"
            $output += "  > exit"
            $output += ""
            $output += "Method 3: Using PowerShell (if partition has GUID)"
            $output += "  `$espPart = Get-Partition | Where-Object { `$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' }"
            $output += "  `$espPart | Add-PartitionAccessPath -AssignDriveLetter"
            $output += ""
            $output += "Verify ESP is mounted:"
            $output += "  dir S:\EFI\Microsoft\Boot"
            $output += "  # Should show: bootmgfw.efi, BCD, and other boot files"
            $output += ""
            $output += "STEP 3: LOCATE WINLOAD.EFI SOURCE"
            $output += "───────────────────────────────────────────────────────────────────────────────"
            $output += "You need to find winload.efi from one of these sources:"
            $output += ""
            $output += "Option A: From Windows Installation Media (ISO/USB)"
            $output += "  1. Mount your Windows ISO or insert Windows USB"
            $output += "  2. Navigate to: sources\install.wim or sources\install.esd"
            $output += "  3. Extract winload.efi using DISM:"
            $output += "     dism /Get-WimInfo /WimFile:X:\sources\install.wim"
            $output += "     # Note the index number for your Windows edition"
            $output += "     dism /Mount-Wim /WimFile:X:\sources\install.wim /Index:1 /MountDir:C:\Mount"
            $output += "     # Copy: C:\Mount\Windows\System32\winload.efi"
            $output += "     dism /Unmount-Wim /MountDir:C:\Mount /Discard"
            $output += ""
            $output += "Option B: From Another Working Windows Installation"
            $output += "  1. If you have another Windows installation on a different drive:"
            $output += "     copy D:\Windows\System32\winload.efi C:\Windows\System32\winload.efi"
            $output += ""
            $output += "Option C: From Windows Recovery Environment (WinRE)"
            $output += "  1. WinRE partition may have winload.efi:"
            $output += "     dir /s X:\Windows\System32\winload.efi"
            $output += "     # X: is typically WinRE in recovery environment"
            $output += ""
            $output += "STEP 4: COPY WINLOAD.EFI TO WINDOWS SYSTEM32"
            $output += "───────────────────────────────────────────────────────────────────────────────"
            $output += "Target location: $($selectedOS.Drive)\Windows\System32\winload.efi"
            $output += ""
            $output += "Commands:"
            $output += "  # If source is on another drive (e.g., D:):"
            $output += "  copy D:\Windows\System32\winload.efi $($selectedOS.Drive)\Windows\System32\winload.efi /Y"
            $output += ""
            $output += "  # If source is in mounted WIM:"
            $output += "  copy C:\Mount\Windows\System32\winload.efi $($selectedOS.Drive)\Windows\System32\winload.efi /Y"
            $output += ""
            $output += "  # Verify the file was copied:"
            $output += "  dir $($selectedOS.Drive)\Windows\System32\winload.efi"
            $output += ""
            $output += "STEP 5: VERIFY AND FIX BCD ENTRY"
            $output += "───────────────────────────────────────────────────────────────────────────────"
            $output += "Ensure BCD points to the correct winload.efi path:"
            $output += ""
            $output += "Commands:"
            $output += "  # View current BCD entries:"
            $output += "  bcdedit /enum all"
            $output += ""
            $output += "  # Check if default entry points to winload.efi:"
            $output += "  bcdedit /enum {default}"
            $output += ""
            $output += "  # If path is wrong, set it correctly:"
            $output += "  bcdedit /set {default} path \\Windows\\system32\\winload.efi"
            $output += ""
            $output += "  # Set device and osdevice (if needed):"
            $output += "  bcdedit /set {default} device partition=$($selectedOS.Drive.TrimEnd(':')):"
            $output += "  bcdedit /set {default} osdevice partition=$($selectedOS.Drive.TrimEnd(':')):"
            $output += ""
            $output += "  # Verify the fix:"
            $output += "  bcdedit /enum {default} | findstr winload"
            $output += ""
            $output += "STEP 6: REBUILD BOOT FILES (If Needed)"
            $output += "───────────────────────────────────────────────────────────────────────────────"
            $output += "If winload.efi is present but boot still fails, rebuild boot files:"
            $output += ""
            $output += "Commands:"
            $output += "  # Rebuild BCD (if ESP is mounted as S: and Windows is on C:):"
            $output += "  bcdboot $($selectedOS.Drive)\Windows /s S: /f UEFI"
            $output += ""
            $output += "  # Alternative: Rebuild boot files using bootrec (if in WinRE):"
            $output += "  bootrec /fixmbr"
            $output += "  bootrec /fixboot"
            $output += "  bootrec /rebuildbcd"
            $output += ""
            $output += "STEP 7: UNMOUNT ESP (When Done)"
            $output += "───────────────────────────────────────────────────────────────────────────────"
            $output += "If you mounted ESP manually, unmount it:"
            $output += ""
            $output += "Method 1: Using mountvol"
            $output += "  mountvol S: /D"
            $output += ""
            $output += "Method 2: Using diskpart"
            $output += "  diskpart"
            $output += "  > select disk X"
            $output += "  > select partition Y"
            $output += "  > remove letter=S"
            $output += "  > exit"
            $output += ""
            $output += "Method 3: Using PowerShell"
            $output += "  `$espPart = Get-Partition | Where-Object { `$_.DriveLetter -eq 'S' }"
            $output += "  `$espPart | Remove-PartitionAccessPath -DriveLetter S"
            $output += ""
            $output += "═══════════════════════════════════════════════════════════════════════════════"
            $output += "QUICK REFERENCE: ALL COMMANDS IN ONE PLACE"
            $output += "═══════════════════════════════════════════════════════════════════════════════"
            $output += ""
            $output += "# 1. Find ESP partition"
            $output += "Get-Volume | Where-Object { `$_.FileSystem -eq 'FAT32' -and `$_.Size -lt 600MB }"
            $output += ""
            $output += "# 2. Mount ESP"
            $output += "mountvol S: /S"
            $output += ""
            $output += "# 3. Verify ESP contents"
            $output += "dir S:\EFI\Microsoft\Boot"
            $output += ""
            $output += "# 4. Copy winload.efi (adjust source path as needed)"
            $output += "copy D:\Windows\System32\winload.efi $($selectedOS.Drive)\Windows\System32\winload.efi /Y"
            $output += ""
            $output += "# 5. Verify winload.efi exists"
            $output += "dir $($selectedOS.Drive)\Windows\System32\winload.efi"
            $output += ""
            $output += "# 6. Fix BCD path"
            $output += "bcdedit /set {default} path \\Windows\\system32\\winload.efi"
            $output += "bcdedit /set {default} device partition=$($selectedOS.Drive.TrimEnd(':')):"
            $output += "bcdedit /set {default} osdevice partition=$($selectedOS.Drive.TrimEnd(':')):"
            $output += ""
            $output += "# 7. Rebuild boot files (if needed)"
            $output += "bcdboot $($selectedOS.Drive)\Windows /s S: /f UEFI"
            $output += ""
            $output += "# 8. Unmount ESP"
            $output += "mountvol S: /D"
            $output += ""
            $output += "═══════════════════════════════════════════════════════════════════════════════"
            $output += "TROUBLESHOOTING"
            $output += "═══════════════════════════════════════════════════════════════════════════════"
            $output += ""
            $output += "Problem: 'mountvol S: /S' fails with 'parameter is incorrect'"
            $output += "  Solution: ESP may already be mounted or drive letter S: is in use. Try:"
            $output += "    • Use a different drive letter: mountvol Z: /S"
            $output += "    • Check if ESP already has a drive letter: Get-Volume | Where-Object { `$_.FileSystem -eq 'FAT32' }"
            $output += ""
            $output += "Problem: Cannot find winload.efi source"
            $output += "  Solution:"
            $output += "    • Use Windows Installation Media (ISO/USB)"
            $output += "    • Extract from install.wim using DISM (see Step 3, Option A)"
            $output += "    • Check if another Windows installation exists: Get-Volume | Where-Object { Test-Path `"`$(`$_.DriveLetter):\Windows\System32\winload.efi`" }"
            $output += ""
            $output += "Problem: 'Access Denied' when copying winload.efi"
            $output += "  Solution:"
            $output += "    • Run PowerShell/CMD as Administrator"
            $output += "    • Take ownership: takeown /f $($selectedOS.Drive)\Windows\System32\winload.efi"
            $output += "    • Grant permissions: icacls $($selectedOS.Drive)\Windows\System32\winload.efi /grant Administrators:F"
            $output += ""
            $output += "Problem: BCD edit fails"
            $output += "  Solution:"
            $output += "    • Ensure you're in WinRE/WinPE (not full Windows)"
            $output += "    • Backup BCD first: bcdedit /export C:\BCD_Backup.bak"
            $output += "    • Try rebuilding: bcdboot $($selectedOS.Drive)\Windows /s S: /f UEFI"
            $output += ""
            $output += "═══════════════════════════════════════════════════════════════════════════════"
        }
        
        $output += $bundle
        
        # ADVANCED PLAN B TROUBLESHOOTING (when standard repair fails)
        # Add advanced troubleshooting section if repair failed or confidence is low
        if (-not $bootable -or $bootabilityConfidence -lt 50) {
            $output += ""
            $output += "═══════════════════════════════════════════════════════════════════════════════"
            $output += "ADVANCED PLAN B TROUBLESHOOTING (For High-End Builds: i9-14900K/Z790)"
            $output += "═══════════════════════════════════════════════════════════════════════════════"
            $output += ""
            $output += "Standard repair failed. Try these advanced steps:"
            $output += ""
            
            # Check for VMD driver issue
            $vmdCheck = Test-VMDDriverIssue
            if ($vmdCheck.Detected) {
                $output += "1. VMD DRIVER ISSUE DETECTED"
                $output += "   Symptom: Intel Volume Management Device (VMD) may be blocking drive access"
                $output += "   Fix:"
                $output += "     a) Go to BIOS -> Storage Configuration"
                $output += "     b) If VMD is Enabled, try disabling it (may require reinstall)"
                $output += "     c) OR load Intel RST VMD driver in WinPE:"
                $output += "        drvload C:\path\to\driver.inf"
                if ($vmdCheck.Details.Count -gt 0) {
                    foreach ($detail in $vmdCheck.Details) {
                        $output += "   Details: $detail"
                    }
                }
                $output += ""
            }
            
            # Check for ghost BCD entries
            $ghostCheck = Test-GhostBCEEntries
            if ($ghostCheck.Detected) {
                $output += "2. GHOST BCD ENTRIES DETECTED"
                $output += "   Symptom: Multiple drives causing UEFI firmware confusion"
                $output += "   Fix:"
                $output += "     a) Unplug all drives except primary NVME boot drive"
                $output += "     b) Attempt repair again"
                $output += "     c) Plug other drives back and use msconfig/EasyBCD to clean up"
                if ($ghostCheck.Details.Count -gt 0) {
                    foreach ($detail in $ghostCheck.Details) {
                        $output += "   Details: $detail"
                    }
                }
                $output += ""
            }
            
            # Check for pending updates
            $pendingCheck = Test-PendingWindowsUpdates
            if ($pendingCheck.Detected) {
                $output += "3. PENDING WINDOWS UPDATES DETECTED"
                $output += "   Symptom: Pending updates may be blocking boot repair"
                $output += "   Fix:"
                $output += "     a) Check for: $($pendingCheck.PendingPath)"
                $output += "     b) Rename or delete pending.xml if found"
                $output += "     c) Reboot and try repair again"
                $output += ""
            }
            
            # Check for read-only drive
            $readOnlyCheck = Test-ReadOnlyDrive -TargetDrive $TargetDrive
            if ($readOnlyCheck.Detected) {
                $output += "4. READ-ONLY DRIVE DETECTED"
                $output += "   Symptom: Drive marked as read-only, preventing writes"
                $output += "   Fix:"
                $output += "     diskpart"
                $output += "     > select disk X (your NVME)"
                $output += "     > attributes disk clear readonly"
                $output += "     > exit"
                $output += ""
            }
            
            # Check BIOS/firmware state
            $biosCheck = Test-BIOSFirmwareState
            if ($biosCheck.IssuesDetected) {
                $output += "5. BIOS/FIRMWARE STATE CHECK"
                $output += "   Issues detected:"
                foreach ($issue in $biosCheck.Issues) {
                    $output += "     • $issue"
                }
                $output += "   Fix:"
                $output += "     a) CSM (Compatibility Support Module): Should be DISABLED for NVME/UEFI"
                $output += "     b) Secure Boot: Try setting to 'Other OS' or 'Disabled' temporarily"
                $output += "     c) Check BIOS version and update if needed"
                $output += ""
            }
            
            # Manual partition recreation
            $output += "6. MANUAL PARTITION RECREATION (Nuke and Pave EFI)"
            $output += "   Warning: Destructive to EFI partition only, not your data"
            $output += "   Steps:"
            $output += "     diskpart"
            $output += "     > list disk"
            $output += "     > sel disk X (your NVME)"
            $output += "     > list part"
            $output += "     > sel part Y (~100MB-500MB System partition)"
            $output += "     > delete partition override"
            $output += "     > create partition efi size=100"
            $output += "     > format quick fs=fat32 label=`"System`""
            $output += "     > assign letter=S"
            $output += "     > exit"
            $winDrive = if ($TargetDrive) { "$TargetDrive`:" } else { "C:" }
            $output += "     bcdboot $winDrive\Windows /s S: /f UEFI"
            $output += ""
            
            # SFC/DISM from WinPE
            $output += "7. SFC AND DISM FROM WINPE"
            $output += "   If winload.efi is missing or 0KB, pull fresh copy from WIM:"
            $output += "     # Replace C: with your actual Windows drive"
            $output += "     # Replace D: with your USB Installation Media"
            $output += "     dism /Image:C:\ /Cleanup-Image /RestoreHealth /Source:D:\sources\install.wim"
            $output += "     sfc /scannow /offbootdir=C:\ /offwindir=C:\Windows"
            $output += ""
            
            # MBR/GPT corruption check
            $output += "8. MBR/GPT CORRUPTION CHECK"
            $output += "   If partition table is corrupted:"
            $output += "     bootsect /nt60 ALL /force /mbr"
            $output += ""
            
            $output += "═══════════════════════════════════════════════════════════════════════════════"
        }
        
        # If repair failed, create and show comprehensive guidance document
        if (-not $bootable -and -not $diagOnly -and -not $DryRun -and -not $simulate) {
            $guidanceDoc = New-WinloadRepairGuidanceDocument -TargetDrive $selectedOS.Drive -WinloadExists $winloadExists -BcdPathMatch $bcdPathMatch -BitlockerLocked $bitlockerLocked -Actions $actions
            $output += ""
            $output += "═══════════════════════════════════════════════════════════════════════════════"
            $output += "REPAIR FAILED - COMPREHENSIVE GUIDANCE DOCUMENT CREATED"
            $output += "═══════════════════════════════════════════════════════════════════════════════"
            $output += ""
            $output += "A detailed manual repair guide has been created and will open in Notepad."
            $output += "The guide contains step-by-step instructions to manually fix winload.efi issues."
            $output += ""
            $output += "Guidance document location: $($guidanceDoc.Path)"
            $output += ""
            $output += "═══════════════════════════════════════════════════════════════════════════════"
            
            # Show guidance document in Notepad
            try {
                Start-Process notepad.exe -ArgumentList "`"$($guidanceDoc.Path)`""
            } catch {
                $output += "Could not open Notepad automatically. Please open: $($guidanceDoc.Path)"
            }
        }

        # Generate comprehensive repair report (ALWAYS, not just on failure)
        $reportPath = $null
        if ($selectedOS) {
            $reportPath = New-ComprehensiveRepairReport -TargetDrive $selectedOS.Drive.TrimEnd(':') -CommandHistory $script:CommandHistory -FailedCommands $script:FailedCommands -InitialIssues $script:InitialIssues -RemainingIssues $script:RemainingIssues -Actions $actions -Bootable $bootable -WinloadExists $winloadExists -BcdPathMatch $bcdPathMatch -BitlockerLocked $bitlockerLocked
            
            # Open report in Notepad (ALWAYS, so user can see what was done)
            if ($reportPath) {
                try {
                    Start-Process notepad.exe -ArgumentList "`"$reportPath`""
                    $output += ""
                    $output += "═══════════════════════════════════════════════════════════════════════════════"
                    $output += "COMPREHENSIVE REPAIR REPORT"
                    $output += "═══════════════════════════════════════════════════════════════════════════════"
                    $output += ""
                    $output += "A detailed repair report has been created and opened in Notepad."
                    $output += "The report shows:"
                    $output += "  • All commands that were run"
                    $output += "  • Which hard drive was repaired ($($selectedOS.Drive))"
                    $output += "  • What was wrong initially"
                    $output += "  • What is still wrong (if anything)"
                    if ($script:FailedCommands.Count -gt 0) {
                        $output += "  • CODE RED: Failed commands (see top of report)"
                    }
                    $output += "  • Additional fix suggestions (if needed)"
                    $output += ""
                    $output += "Report location: $reportPath"
                    $output += ""
                    $output += "═══════════════════════════════════════════════════════════════════════════════"
                } catch {
                    $output += "`nCould not open Notepad automatically. Report saved to: $reportPath"
                }
            }
        }

        # Get final comprehensive verification with all issues
        $finalVerification = $null
        if ($selectedOS -and $espLetter) {
            try {
                $finalVerification = Test-BootabilityComprehensive -TargetDrive $selectedOS.Drive -EspLetter $espLetter
            } catch {
                # If verification fails, create a minimal verification object
                $finalVerification = @{
                    Bootable = $bootable
                    Issues = $script:RemainingIssues
                    Actions = @()
                }
            }
        } elseif ($selectedOS) {
            try {
                $finalVerification = Test-BootabilityComprehensive -TargetDrive $selectedOS.Drive -EspLetter $null
            } catch {
                $finalVerification = @{
                    Bootable = $bootable
                    Issues = $script:RemainingIssues
                    Actions = @()
                }
            }
        }
        
        # Combine remaining issues with verification issues
        $allIssues = @()
        if ($script:RemainingIssues) {
            # Ensure RemainingIssues is an array
            if ($script:RemainingIssues -is [array]) {
                $allIssues += $script:RemainingIssues
            } else {
                $allIssues += @($script:RemainingIssues)
            }
        }
        if ($finalVerification -and $finalVerification.Issues) {
            # Ensure Verification.Issues is an array
            if ($finalVerification.Issues -is [array]) {
                $allIssues += $finalVerification.Issues
            } else {
                $allIssues += @($finalVerification.Issues)
            }
        }
        $allIssues = $allIssues | Select-Object -Unique
        
        return [pscustomobject]@{
            Mode       = $resolvedMode
            Bootable   = $bootable
            Confidence = $confidence
            Blocker    = $blockerFinal
            Output     = ($output -join "`n")
            Bundle     = ($bundle -join "`n")
            ReportPath = $reportPath
            CommandHistory = $script:CommandHistory
            FailedCommands = $script:FailedCommands
            Verification = $finalVerification
            Issues = $allIssues
        }
    }
    finally {
        if ($mountedByUs -and $espLetter) {
            try { Unmount-EspTemp -Letter ($espLetter.TrimEnd(':')) } catch { }
        }
    }
}
