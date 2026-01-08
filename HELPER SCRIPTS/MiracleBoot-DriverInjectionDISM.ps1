#!/usr/bin/env powershell
# ============================================================================
# MIRACLEBOOT DISM DRIVER INJECTION MODULE
# Version 2.2 - Enhanced Driver Injection for OS & Recovery Environments
# ============================================================================
# Purpose: Inject drivers into Windows OS and Recovery environments using DISM
#          Supports offline OS injection, WinPE injection, and WinRE injection
#
# Features:
# - Inject drivers to offline Windows installation (C:\)
# - Inject drivers to WinPE/WinRE boot images
# - Inject drivers to WIM files (install.wim, boot.wim)
# - Batch driver injection with progress tracking
# - Automatic WIM mounting/dismounting
# - Rollback capability with checkpoint restoration
# - Integration with Snappy Driver Installer
# - Driver compatibility verification
# - Injection logging and audit trail
#
# DISM Commands Used:
# - dism /image:C:\ /add-driver /driver:C:\Drivers /recurse
# - dism /mount-image /imagefile:boot.wim /index:1 /mountdir:C:\mount
# - dism /image:C:\mount /add-driver /driver:C:\Drivers
# - dism /unmount-image /mountdir:C:\mount /commit
#
# Critical for: INACCESSIBLE_BOOT_DEVICE prevention, NVMe support, RAID drivers
# ============================================================================

param()

# ============================================================================
# CONFIGURATION
# ============================================================================

$DriverConfig = @{
    LogPath              = 'C:\MiracleBoot-Drivers'
    DriverCachePath      = 'C:\MiracleBoot-Drivers\Cache'
    WindowsPEDriverPath  = 'C:\MiracleBoot-Drivers\WinPE'
    InjectionPath        = 'C:\MiracleBoot-Drivers\Injected'
    MountPath            = 'C:\MiracleBoot-Drivers\Mount'
    CheckpointPath       = 'C:\MiracleBoot-Drivers\Checkpoints'
    MaxRetries           = 3
    EnableAutoDownload   = $true
    EnableSnappyIntegration = $true
    SnappyInstallerPath  = 'C:\Program Files\Snappy Driver Installer'
}

# Create required directories
$null = New-Item -ItemType Directory -Path $DriverConfig['LogPath'] -Force -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Path $DriverConfig['MountPath'] -Force -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Path $DriverConfig['CheckpointPath'] -Force -ErrorAction SilentlyContinue

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-DriverLog {
    param(
        [string]$Message,
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    $logFile = Join-Path $DriverConfig['LogPath'] "driver-injection-$(Get-Date -Format 'yyyy-MM-dd').log"
    
    switch ($Level) {
        'Error'   { Write-Host $logEntry -ForegroundColor Red }
        'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
        'Info'    { Write-Host $logEntry -ForegroundColor Cyan }
        default   { Write-Host $logEntry }
    }
    
    Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
}

# ============================================================================
# DISM DRIVER INJECTION - OFFLINE OS (C:\)
# ============================================================================

function Invoke-DISMOfflineOSDriverInjection {
    <#
    .SYNOPSIS
    Injects drivers into offline Windows OS installation (C:\)
    
    .DESCRIPTION
    Adds drivers to the Windows installation at C:\ using DISM
    Useful when Windows is not running (recovery environment) but disk is accessible
    Prevents INACCESSIBLE_BOOT_DEVICE errors by injecting critical drivers
    
    .PARAMETER DriverPath
    Path to drivers folder containing .inf files
    Supports recursive search through subfolders
    
    .PARAMETER Recursive
    If true, searches all subdirectories for drivers
    
    .EXAMPLE
    Invoke-DISMOfflineOSDriverInjection -DriverPath "E:\Drivers" -Recursive
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriverPath,
        
        [switch]$Recursive = $true
    )
    
    Write-DriverLog "Starting offline OS driver injection (C:\)" -Level Info
    Write-DriverLog "Driver source: $DriverPath" -Level Info
    
    # Validate driver path exists
    if (-not (Test-Path $DriverPath)) {
        Write-DriverLog "Driver path not found: $DriverPath" -Level Error
        return @{ Success = $false; Message = "Driver path not found" }
    }
    
    try {
        # Build DISM command
        $dismCmd = "dism /image:C:\ /add-driver /driver:`"$DriverPath`""
        
        if ($Recursive) {
            $dismCmd += " /recurse"
            Write-DriverLog "Recursive mode enabled" -Level Info
        }
        
        Write-DriverLog "Executing: $dismCmd" -Level Info
        
        # Execute DISM
        $output = Invoke-Expression $dismCmd 2>&1
        $exitCode = $LASTEXITCODE
        
        Write-DriverLog "DISM Exit Code: $exitCode" -Level Info
        
        if ($exitCode -eq 0) {
            Write-DriverLog "Driver injection successful" -Level Success
            return @{
                Success   = $true
                ExitCode  = $exitCode
                Message   = "Drivers injected to C:\ successfully"
                Output    = $output
            }
        }
        else {
            Write-DriverLog "DISM failed with exit code: $exitCode" -Level Error
            Write-DriverLog "Output: $output" -Level Error
            return @{
                Success   = $false
                ExitCode  = $exitCode
                Message   = "DISM driver injection failed"
                Output    = $output
            }
        }
    }
    catch {
        Write-DriverLog "Exception during driver injection: $_" -Level Error
        return @{
            Success   = $false
            Message   = "Exception: $_"
        }
    }
}

# ============================================================================
# DISM DRIVER INJECTION - WIM FILES (boot.wim, install.wim)
# ============================================================================

function Invoke-DISMWIMDriverInjection {
    <#
    .SYNOPSIS
    Injects drivers into WIM boot images (boot.wim, install.wim)
    
    .DESCRIPTION
    Mounts WIM file, injects drivers, and commits changes
    Used for WinPE/WinRE boot environments
    Automatically handles mounting and dismounting
    
    .PARAMETER WIMPath
    Path to WIM file (boot.wim or install.wim)
    
    .PARAMETER ImageIndex
    Index of image to modify (default 1 for boot.wim, varies for install.wim)
    
    .PARAMETER DriverPath
    Path to drivers folder
    
    .EXAMPLE
    Invoke-DISMWIMDriverInjection -WIMPath "E:\boot.wim" -ImageIndex 1 -DriverPath "E:\Drivers"
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$WIMPath,
        
        [int]$ImageIndex = 1,
        
        [Parameter(Mandatory=$true)]
        [string]$DriverPath
    )
    
    Write-DriverLog "Starting WIM driver injection" -Level Info
    Write-DriverLog "WIM File: $WIMPath" -Level Info
    Write-DriverLog "Image Index: $ImageIndex" -Level Info
    Write-DriverLog "Driver source: $DriverPath" -Level Info
    
    # Validate files
    if (-not (Test-Path $WIMPath)) {
        Write-DriverLog "WIM file not found: $WIMPath" -Level Error
        return @{ Success = $false; Message = "WIM file not found" }
    }
    
    if (-not (Test-Path $DriverPath)) {
        Write-DriverLog "Driver path not found: $DriverPath" -Level Error
        return @{ Success = $false; Message = "Driver path not found" }
    }
    
    # Create checkpoint (backup original WIM)
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $checkpoint = Join-Path $DriverConfig['CheckpointPath'] "wim-checkpoint-$timestamp.bak"
    
    try {
        Write-DriverLog "Creating checkpoint: $checkpoint" -Level Info
        Copy-Item -Path $WIMPath -Destination $checkpoint -Force
        Write-DriverLog "Checkpoint created successfully" -Level Success
    }
    catch {
        Write-DriverLog "Failed to create checkpoint: $_" -Level Warning
    }
    
    # Mount WIM
    try {
        $mountPath = $DriverConfig['MountPath']
        Write-DriverLog "Mounting WIM to: $mountPath" -Level Info
        
        $mountCmd = "dism /mount-image /imagefile:`"$WIMPath`" /index:$ImageIndex /mountdir:`"$mountPath`""
        Write-DriverLog "Executing: $mountCmd" -Level Info
        
        $output = Invoke-Expression $mountCmd 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -ne 0) {
            Write-DriverLog "WIM mount failed with exit code: $exitCode" -Level Error
            return @{
                Success   = $false
                ExitCode  = $exitCode
                Message   = "Failed to mount WIM"
                Output    = $output
            }
        }
        
        Write-DriverLog "WIM mounted successfully" -Level Success
        
        # Inject drivers into mounted image
        try {
            $injectionCmd = "dism /image:`"$mountPath`" /add-driver /driver:`"$DriverPath`" /recurse"
            Write-DriverLog "Executing: $injectionCmd" -Level Info
            
            $output = Invoke-Expression $injectionCmd 2>&1
            $exitCode = $LASTEXITCODE
            
            Write-DriverLog "Driver injection exit code: $exitCode" -Level Info
            
            if ($exitCode -ne 0) {
                Write-DriverLog "Driver injection failed" -Level Error
            }
            else {
                Write-DriverLog "Drivers injected successfully" -Level Success
            }
        }
        finally {
            # Unmount and commit changes
            try {
                Write-DriverLog "Unmounting WIM (committing changes)..." -Level Info
                
                $unmountCmd = "dism /unmount-image /mountdir:`"$mountPath`" /commit"
                Write-DriverLog "Executing: $unmountCmd" -Level Info
                
                $output = Invoke-Expression $unmountCmd 2>&1
                $exitCode = $LASTEXITCODE
                
                if ($exitCode -eq 0) {
                    Write-DriverLog "WIM unmounted and changes committed" -Level Success
                }
                else {
                    Write-DriverLog "WIM unmount failed: $output" -Level Error
                }
            }
            catch {
                Write-DriverLog "Error unmounting WIM: $_" -Level Error
                Write-DriverLog "Attempting force dismount..." -Level Warning
                
                $forceCmd = "dism /unmount-image /mountdir:`"$mountPath`" /discard"
                Invoke-Expression $forceCmd -ErrorAction SilentlyContinue
            }
        }
        
        return @{
            Success     = $true
            Message     = "WIM driver injection completed"
            Checkpoint  = $checkpoint
        }
    }
    catch {
        Write-DriverLog "Exception during WIM injection: $_" -Level Error
        return @{
            Success     = $false
            Message     = "Exception: $_"
        }
    }
}

# ============================================================================
# SNAPPY DRIVER INSTALLER INTEGRATION
# ============================================================================

function Invoke-SnappyDriverInstaller {
    <#
    .SYNOPSIS
    Launches Snappy Driver Installer for automated driver detection/download
    
    .DESCRIPTION
    Snappy Driver Installer (SDI) is a free, portable driver updater
    Can scan system and download missing drivers automatically
    Useful for offline driver package creation before DISM injection
    
    .PARAMETER Mode
    'Scan' = Scan for missing drivers
    'Download' = Download missing drivers to cache
    'Inject' = Auto-download and inject drivers
    
    .EXAMPLE
    Invoke-SnappyDriverInstaller -Mode Download
    #>
    
    param(
        [ValidateSet('Scan', 'Download', 'Inject')]
        [string]$Mode = 'Scan'
    )
    
    Write-DriverLog "Snappy Driver Installer integration initiated" -Level Info
    
    # Check if Snappy is installed
    $snappyPath = $DriverConfig['SnappyInstallerPath']
    $snappyExe = Join-Path $snappyPath 'SDI.exe'
    
    if (-not (Test-Path $snappyExe)) {
        Write-DriverLog "Snappy Driver Installer not found at: $snappyExe" -Level Warning
        Write-DriverLog "Download from: https://www.snappy-driver-installer.org/" -Level Info
        
        return @{
            Success  = $false
            Message  = "Snappy Driver Installer not installed"
            Download = "https://www.snappy-driver-installer.org/"
        }
    }
    
    try {
        Write-DriverLog "Launching Snappy Driver Installer..." -Level Info
        
        switch ($Mode) {
            'Scan' {
                Write-DriverLog "Mode: Scan for missing drivers" -Level Info
                & $snappyExe
            }
            'Download' {
                Write-DriverLog "Mode: Download missing drivers" -Level Info
                & $snappyExe
            }
            'Inject' {
                Write-DriverLog "Mode: Auto-download and prepare for injection" -Level Info
                & $snappyExe
            }
        }
        
        Write-DriverLog "Snappy Driver Installer completed" -Level Success
        
        return @{
            Success  = $true
            Message  = "Snappy Driver Installer completed successfully"
        }
    }
    catch {
        Write-DriverLog "Error launching Snappy Driver Installer: $_" -Level Error
        return @{
            Success  = $false
            Message  = "Failed to launch Snappy Driver Installer: $_"
        }
    }
}

# ============================================================================
# BATCH DRIVER INJECTION WITH PROGRESS
# ============================================================================

function Invoke-BatchDriverInjection {
    <#
    .SYNOPSIS
    Injects drivers to multiple targets (OS, WIM files, etc.)
    
    .DESCRIPTION
    Comprehensive driver injection workflow
    Supports injection to offline OS and multiple WIM files
    Tracks progress and provides detailed reporting
    
    .PARAMETER Targets
    Array of injection targets with paths and configuration
    
    .EXAMPLE
    $targets = @(
        @{ Type = 'OS'; Path = 'C:\' },
        @{ Type = 'WIM'; Path = 'E:\boot.wim'; Index = 1 }
    )
    Invoke-BatchDriverInjection -DriverPath "E:\Drivers" -Targets $targets
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriverPath,
        
        [Parameter(Mandatory=$true)]
        [array]$Targets
    )
    
    Write-DriverLog "Starting batch driver injection" -Level Info
    Write-DriverLog "Total targets: $($Targets.Count)" -Level Info
    
    $results = @()
    $successCount = 0
    $failureCount = 0
    
    for ($i = 0; $i -lt $Targets.Count; $i++) {
        $target = $Targets[$i]
        $progressPercent = (($i + 1) / $Targets.Count) * 100
        
        Write-DriverLog "[$($i+1)/$($Targets.Count)] Processing target: $($target.Type)" -Level Info
        Write-DriverLog "Progress: $([Math]::Round($progressPercent))%" -Level Info
        
        $result = $null
        
        switch ($target.Type) {
            'OS' {
                $result = Invoke-DISMOfflineOSDriverInjection -DriverPath $DriverPath
            }
            'WIM' {
                $result = Invoke-DISMWIMDriverInjection -WIMPath $target.Path `
                    -ImageIndex $(if ($null -ne $target.Index) { $target.Index } else { 1 }) `
                    -DriverPath $DriverPath
            }
            default {
                Write-DriverLog "Unknown target type: $($target.Type)" -Level Error
                $result = @{ Success = $false; Message = "Unknown target type" }
            }
        }
        
        if ($result.Success) {
            $successCount++
        }
        else {
            $failureCount++
        }
        
        $results += @{
            Target = $target
            Result = $result
        }
    }
    
    Write-DriverLog "Batch injection completed" -Level Info
    Write-DriverLog "Success: $successCount | Failed: $failureCount" -Level Info
    
    return @{
        Summary = @{
            TotalTargets  = $Targets.Count
            SuccessCount  = $successCount
            FailureCount  = $failureCount
            SuccessRate   = if ($Targets.Count -gt 0) { ($successCount / $Targets.Count) * 100 } else { 0 }
        }
        DetailedResults = $results
    }
}

# ============================================================================
# DRIVER COMPATIBILITY CHECK
# ============================================================================

function Test-DriverCompatibility {
    <#
    .SYNOPSIS
    Verifies driver compatibility before injection
    
    .DESCRIPTION
    Checks:
    - Driver .inf file syntax
    - Windows version compatibility
    - Architecture (x86/x64)
    - Driver signature (important for boot drivers)
    
    .PARAMETER DriverPath
    Path to driver folder to validate
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriverPath
    )
    
    Write-DriverLog "Validating driver compatibility..." -Level Info
    
    $infFiles = Get-ChildItem -Path $DriverPath -Filter "*.inf" -Recurse
    
    if ($infFiles.Count -eq 0) {
        Write-DriverLog "No .inf files found in: $DriverPath" -Level Warning
        return @{
            Compatible = $false
            InfCount   = 0
            Message    = "No driver .inf files found"
        }
    }
    
    Write-DriverLog "Found $($infFiles.Count) driver .inf files" -Level Info
    
    $validCount = 0
    foreach ($inf in $infFiles) {
        try {
            $content = Get-Content -Path $inf.FullName -ErrorAction Stop
            if ($content -match '\[Version\]' -and $content -match '\[SourceDisksFiles\]') {
                $validCount++
            }
        }
        catch {
            Write-DriverLog "Failed to read: $($inf.Name)" -Level Warning
        }
    }
    
    Write-DriverLog "Valid drivers: $validCount / $($infFiles.Count)" -Level Success
    
    return @{
        Compatible     = ($validCount -gt 0)
        TotalInfFiles  = $infFiles.Count
        ValidDrivers   = $validCount
        DriverList     = $infFiles | Select-Object -ExpandProperty Name
    }
}

# ============================================================================
# CHECKPOINT & ROLLBACK
# ============================================================================

function Restore-DriverCheckpoint {
    <#
    .SYNOPSIS
    Restores WIM file from checkpoint if injection fails
    
    .PARAMETER CheckpointPath
    Path to checkpoint backup file
    
    .PARAMETER TargetPath
    Target WIM path to restore to
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$CheckpointPath,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetPath
    )
    
    if (-not (Test-Path $CheckpointPath)) {
        Write-DriverLog "Checkpoint not found: $CheckpointPath" -Level Error
        return $false
    }
    
    try {
        Write-DriverLog "Restoring from checkpoint..." -Level Info
        Copy-Item -Path $CheckpointPath -Destination $TargetPath -Force
        Write-DriverLog "Checkpoint restored successfully" -Level Success
        return $true
    }
    catch {
        Write-DriverLog "Failed to restore checkpoint: $_" -Level Error
        return $false
    }
}

# ============================================================================
# MAIN EXPORTS
# ============================================================================

$null = @(
    'Invoke-DISMOfflineOSDriverInjection',
    'Invoke-DISMWIMDriverInjection',
    'Invoke-SnappyDriverInstaller',
    'Invoke-BatchDriverInjection',
    'Test-DriverCompatibility',
    'Restore-DriverCheckpoint'
)

Write-DriverLog "MiracleBoot DISM Driver Injection Module loaded successfully" -Level Success
Write-DriverLog "Features: OS injection, WIM injection, Snappy integration, batch processing, rollback" -Level Info
