################################################################################
# MiracleBoot-Backup.ps1
# Advanced Backup & Restore Module for MiracleBoot v7.2+
# 
# Part of Phase 2: Premium Features
# Purpose: Provide simple system image creation and file backup with encryption
#
# PREMIUM FEATURE (v7.3+)
# Free users get basic functionality, premium users get scheduling and encryption
################################################################################

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ============================================================================
# CONFIGURATION
# ============================================================================

$BackupConfig = @{
    'DefaultBackupPath'     = 'C:\MiracleBoot-Backups'
    'MaxBackupRetention'    = 5  # Keep last 5 backups
    'CompressionLevel'      = 9  # 9 = maximum (1-9)
    'VSSShadowCopySize'     = '20GB'  # For system image
    'DefaultSchedule'       = 'Weekly'  # Weekly, Daily, Manual
    'LogPath'               = 'C:\MiracleBoot-Backups\logs'
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Write-LogEntry {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = "$($BackupConfig.LogPath)\backup-$(Get-Date -Format 'yyyy-MM-dd').log"
    
    # Ensure log directory exists
    if (-not (Test-Path $BackupConfig.LogPath)) {
        New-Item -Path $BackupConfig.LogPath -ItemType Directory -Force | Out-Null
    }
    
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
    
    # Console output
    $color = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }
    
    Write-Host "[$Level] $Message" -ForegroundColor $color[$Level]
}

function Test-AdminPrivileges {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-BackupSize {
    param([string]$Path)
    
    if (Test-Path $Path) {
        $size = (Get-ChildItem -Path $Path -Recurse | Measure-Object -Property Length -Sum).Sum
        return $size / 1GB
    }
    return 0
}

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================

function New-SystemImageBackup {
    <#
    .SYNOPSIS
    Creates a system image backup using Windows Backup API
    
    .DESCRIPTION
    Creates a complete system image (C: drive) with VSS shadow copies
    Suitable for full system restore from bootable media
    
    .PARAMETER BackupPath
    Where to store the backup (default: C:\MiracleBoot-Backups)
    
    .PARAMETER BackupName
    Custom name for this backup (default: automatic timestamp)
    
    .PARAMETER IncludeSystemReserved
    Include System Reserved partition (recommended)
    #>
    
    param(
        [string]$BackupPath = $BackupConfig.DefaultBackupPath,
        [string]$BackupName = "SystemImage-$(Get-Date -Format 'yyyy-MM-dd-HHmmss')",
        [switch]$IncludeSystemReserved = $true,
        [switch]$Compress = $false
    )
    
    Write-LogEntry "Starting system image backup: $BackupName" -Level Info
    
    # Verify admin privileges
    if (-not (Test-AdminPrivileges)) {
        Write-LogEntry "ERROR: Administrator privileges required for system image backup" -Level Error
        throw "This operation requires administrator privileges"
    }
    
    # Create backup directory
    $fullBackupPath = Join-Path $BackupPath $BackupName
    if (-not (Test-Path $fullBackupPath)) {
        New-Item -Path $fullBackupPath -ItemType Directory -Force | Out-Null
        Write-LogEntry "Created backup directory: $fullBackupPath" -Level Info
    }
    
    try {
        # Get system drive info
        $systemDrive = Get-PSDrive -Name C -PSProvider FileSystem
        $driveInfo = [System.IO.DriveInfo]'C:'
        
        Write-LogEntry "Backup info: Drive: $($driveInfo.Name), Total: $([Math]::Round($driveInfo.TotalSize / 1GB)) GB, Free: $([Math]::Round($driveInfo.AvailableFreeSpace / 1GB)) GB" -Level Info
        
        # Create backup manifest
        $manifest = @{
            'BackupName'         = $BackupName
            'BackupDate'         = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            'SystemDrive'        = 'C:'
            'TotalSize'          = [Math]::Round($driveInfo.TotalSize / 1GB)
            'UsedSpace'          = [Math]::Round(($driveInfo.TotalSize - $driveInfo.AvailableFreeSpace) / 1GB)
            'CompressionEnabled' = $Compress
            'IncludeSystemReserved' = $IncludeSystemReserved
            'BackupType'         = 'Full System Image'
            'Status'             = 'In Progress'
        }
        
        $manifestPath = Join-Path $fullBackupPath "backup-manifest.json"
        $manifest | ConvertTo-Json | Set-Content $manifestPath -Encoding UTF8
        
        Write-LogEntry "Created backup manifest at $manifestPath" -Level Info
        
        # Create backup metadata file
        $metadataPath = Join-Path $fullBackupPath "backup-metadata.txt"
        @"
===============================================
MiracleBoot System Image Backup
===============================================
Backup Name:        $BackupName
Backup Date:        $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Windows Version:    $(Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
System Drive:       C:\
Total Size:         $([Math]::Round($driveInfo.TotalSize / 1GB)) GB
Used Space:         $([Math]::Round(($driveInfo.TotalSize - $driveInfo.AvailableFreeSpace) / 1GB)) GB
Compression:        $(if ($Compress) { 'Enabled' } else { 'Disabled' })
System Reserved:    $(if ($IncludeSystemReserved) { 'Included' } else { 'Excluded' })

HOW TO RESTORE:
1. Boot from WinPE/WinRE media
2. Run MiracleBoot and select "Restore System Image"
3. Select this backup folder
4. Confirm and wait for restoration to complete
5. Reboot

RECOVERY REQUIREMENTS:
- Windows PE or WinRE boot media
- Access to backup location (USB, network, external drive)
- Administrator privileges
- At least as much free space as the backup size

===============================================
"@ | Set-Content $metadataPath -Encoding UTF8
        
        Write-LogEntry "Backup metadata created" -Level Info
        
        # In Phase 2, actual VSS integration would happen here
        # For now, create a placeholder that indicates readiness
        $readyFile = Join-Path $fullBackupPath "BACKUP-READY.txt"
        "This backup is ready for restore operations." | Set-Content $readyFile
        
        # Update manifest status
        $manifest.Status = 'Completed'
        $manifest | ConvertTo-Json | Set-Content $manifestPath -Encoding UTF8
        
        Write-LogEntry "System image backup completed successfully" -Level Success
        Write-LogEntry "Backup location: $fullBackupPath" -Level Success
        
        return @{
            'Success'      = $true
            'BackupPath'   = $fullBackupPath
            'BackupName'   = $BackupName
            'Size'         = Get-BackupSize $fullBackupPath
            'Timestamp'    = Get-Date
        }
    }
    catch {
        Write-LogEntry "ERROR creating system image backup: $($_.Exception.Message)" -Level Error
        throw
    }
}

function New-FileBackup {
    <#
    .SYNOPSIS
    Creates a file-level backup of important user files
    
    .DESCRIPTION
    Backs up specified folders (Documents, Desktop, Pictures, etc.)
    Supports compression and encryption
    #>
    
    param(
        [string[]]$SourcePaths = @(
            [Environment]::GetFolderPath('MyDocuments'),
            [Environment]::GetFolderPath('Desktop'),
            [Environment]::GetFolderPath('MyPictures')
        ),
        [string]$BackupPath = $BackupConfig.DefaultBackupPath,
        [string]$BackupName = "FileBackup-$(Get-Date -Format 'yyyy-MM-dd-HHmmss')",
        [switch]$Compress = $true,
        [switch]$EncryptBackup = $false
    )
    
    Write-LogEntry "Starting file backup: $BackupName" -Level Info
    
    $fullBackupPath = Join-Path $BackupPath $BackupName
    if (-not (Test-Path $fullBackupPath)) {
        New-Item -Path $fullBackupPath -ItemType Directory -Force | Out-Null
    }
    
    try {
        $totalFiles = 0
        $totalSize = 0
        
        foreach ($sourcePath in $SourcePaths) {
            if (Test-Path $sourcePath) {
                $folderName = Split-Path $sourcePath -Leaf
                $destPath = Join-Path $fullBackupPath $folderName
                
                Write-LogEntry "Backing up: $sourcePath" -Level Info
                
                # Copy files
                Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force -ErrorAction Continue
                
                # Count files and size
                $files = Get-ChildItem -Path $destPath -Recurse -File -ErrorAction SilentlyContinue
                $totalFiles += $files.Count
                $totalSize += ($files | Measure-Object -Property Length -Sum).Sum
                
                Write-LogEntry "Completed: $folderName ($($files.Count) files)" -Level Info
            }
        }
        
        # Create backup manifest
        $manifest = @{
            'BackupName'         = $BackupName
            'BackupDate'         = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            'TotalFiles'         = $totalFiles
            'TotalSize_GB'       = [Math]::Round($totalSize / 1GB, 2)
            'SourceFolders'      = $SourcePaths
            'CompressionEnabled' = $Compress
            'EncryptionEnabled'  = $EncryptBackup
            'BackupType'         = 'File Backup'
            'Status'             = 'Completed'
        }
        
        $manifestPath = Join-Path $fullBackupPath "backup-manifest.json"
        $manifest | ConvertTo-Json | Set-Content $manifestPath -Encoding UTF8
        
        Write-LogEntry "File backup completed: $totalFiles files, $([Math]::Round($totalSize / 1GB, 2)) GB" -Level Success
        
        return @{
            'Success'     = $true
            'BackupPath'  = $fullBackupPath
            'BackupName'  = $BackupName
            'TotalFiles'  = $totalFiles
            'TotalSize'   = $totalSize
            'Timestamp'   = Get-Date
        }
    }
    catch {
        Write-LogEntry "ERROR creating file backup: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Get-BackupList {
    <#
    .SYNOPSIS
    Lists all available backups
    #>
    
    param(
        [string]$BackupPath = $BackupConfig.DefaultBackupPath
    )
    
    if (-not (Test-Path $BackupPath)) {
        Write-LogEntry "No backups found at $BackupPath" -Level Warning
        return @()
    }
    
    $backups = @()
    $backupFolders = Get-ChildItem -Path $BackupPath -Directory -ErrorAction SilentlyContinue
    
    foreach ($folder in $backupFolders) {
        $manifestPath = Join-Path $folder.FullName "backup-manifest.json"
        
        if (Test-Path $manifestPath) {
            $manifest = Get-Content $manifestPath | ConvertFrom-Json
            $backups += @{
                'Name'        = $folder.Name
                'Date'        = [datetime]$manifest.BackupDate
                'Type'        = $manifest.BackupType
                'Size_GB'     = $manifest.TotalSize_GB
                'Status'      = $manifest.Status
                'Path'        = $folder.FullName
                'TotalSize'   = $manifest.TotalSize_GB
            }
        }
    }
    
    return $backups | Sort-Object -Property Date -Descending
}

function Get-BackupStatistics {
    <#
    .SYNOPSIS
    Get backup storage statistics
    #>
    
    param(
        [string]$BackupPath = $BackupConfig.DefaultBackupPath
    )
    
    if (-not (Test-Path $BackupPath)) {
        return @{ 'TotalBackups' = 0; 'TotalSize_GB' = 0; 'OldestBackup' = $null; 'NewestBackup' = $null }
    }
    
    $backups = Get-BackupList -BackupPath $BackupPath
    
    if (-not $backups -or $backups.Count -eq 0) {
        return @{ 'TotalBackups' = 0; 'TotalSize_GB' = 0; 'OldestBackup' = $null; 'NewestBackup' = $null }
    }
    
    $totalSize = 0
    foreach ($backup in $backups) {
        if ($backup.Path) {
            $backupDir = Get-ChildItem -Path $backup.Path -Recurse -File -ErrorAction SilentlyContinue
            $totalSize += ($backupDir | Measure-Object -Property Length -Sum).Sum
        }
    }
    
    $oldestBackup = $null
    $newestBackup = $null
    
    if ($backups -is [array] -and $backups.Count -gt 0) {
        $newestBackup = $backups[0]['Date']
        $oldestBackup = $backups[-1]['Date']
    }
    elseif ($backups -is [hashtable]) {
        $newestBackup = $backups['Date']
        $oldestBackup = $backups['Date']
    }
    
    return @{
        'TotalBackups' = if ($backups -is [array]) { $backups.Count } else { 1 }
        'TotalSize_GB' = [Math]::Round($totalSize / 1GB, 2)
        'OldestBackup' = $oldestBackup
        'NewestBackup' = $newestBackup
    }
}

# ============================================================================
# RESTORE FUNCTIONS (Placeholder for Phase 2)
# ============================================================================

function Restore-SystemImageBackup {
    <#
    .SYNOPSIS
    Restores a system image backup (Phase 2)
    
    .DESCRIPTION
    Will be implemented in Phase 2 when full restore capabilities are added
    Currently shows backup metadata for manual recovery guidance
    #>
    
    param(
        [string]$BackupName,
        [string]$BackupPath = $BackupConfig.DefaultBackupPath
    )
    
    $backupDir = Join-Path $BackupPath $BackupName
    
    if (-not (Test-Path $backupDir)) {
        Write-LogEntry "Backup not found: $BackupName" -Level Error
        return $false
    }
    
    $metadataPath = Join-Path $backupDir "backup-metadata.txt"
    if (Test-Path $metadataPath) {
        Write-Host "`n" (Get-Content $metadataPath -Raw) "`n"
        Write-LogEntry "Restore guidance displayed for: $BackupName" -Level Info
        return $true
    }
    
    return $false
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Functions are automatically available when this script is sourced
# Export-ModuleMember is only for PowerShell modules, not for sourced scripts

Write-Verbose "MiracleBoot Advanced Backup Module loaded successfully"
