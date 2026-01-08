# ============================================================================
# DRIVE SELECTION MANAGER - DriveSelectionManager.ps1
# Version: 7.3.0
# Last Updated: January 7, 2026
# ============================================================================
#
# PURPOSE:
# Centralized drive selection and management system for MiracleBoot
# Provides consistent drive selection prompts, warnings, and override options
#
# FEATURES:
# - Global drive settings management
# - Drive selection dialogs with warnings
# - Default drive handling with consent
# - Drive validation and availability checking
# - Status message generation with drive context
#
# ============================================================================

# Global state for current selected drive
$global:MiracleBoot_SelectedDrive = $null
$global:MiracleBoot_DriveWarningShown = $false
$global:MiracleBoot_DriveSuppressWarnings = $false

function Get-AvailableSystemDrives {
    <#
    .SYNOPSIS
    Retrieves all available system drives with complete information.
    
    .OUTPUTS
    Array of PSObjects with drive information
    #>
    try {
        $drives = Get-Volume -ErrorAction SilentlyContinue | 
            Where-Object { $_.DriveLetter -and $_.DriveLetter -ne '' } |
            Sort-Object DriveLetter |
            Select-Object @{
                Name = 'Letter'
                Expression = { $_.DriveLetter }
            }, @{
                Name = 'Label'
                Expression = { $_.FileSystemLabel }
            }, @{
                Name = 'FileSystem'
                Expression = { $_.FileSystem }
            }, @{
                Name = 'SizeGB'
                Expression = { [math]::Round($_.Size / 1GB, 2) }
            }, @{
                Name = 'FreeGB'
                Expression = { [math]::Round($_.SizeRemaining / 1GB, 2) }
            }, @{
                Name = 'Health'
                Expression = { $_.HealthStatus }
            }
        
        return $drives
    } catch {
        Write-Warning "Error retrieving available drives: $_"
        return @()
    }
}

function Test-DriveAccessibility {
    <#
    .SYNOPSIS
    Tests if a specific drive letter is accessible and readable.
    
    .PARAMETER DriveLetter
    The drive letter to test (e.g., "C", "D")
    
    .OUTPUTS
    Boolean - $true if drive is accessible, $false otherwise
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )
    
    try {
        $drive = $DriveLetter.ToUpper()
        if ($drive.Length -gt 1) { $drive = $drive[0] }
        
        $path = "${drive}:\"
        return (Test-Path $path -ErrorAction SilentlyContinue)
    } catch {
        return $false
    }
}

function Show-DriveSelectionDialog {
    <#
    .SYNOPSIS
    Displays a visual dialog for drive selection.
    
    .PARAMETER Title
    Title of the dialog
    
    .PARAMETER AllowCancel
    Whether to allow cancellation
    
    .PARAMETER PreselectedDrive
    Optional pre-selected drive letter
    
    .OUTPUTS
    String - selected drive letter or $null if cancelled
    #>
    param(
        [string]$Title = "Select Target Drive",
        [bool]$AllowCancel = $true,
        [string]$PreselectedDrive = $null
    )
    
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        
        $drives = Get-AvailableSystemDrives
        
        if ($drives.Count -eq 0) {
            [System.Windows.MessageBox]::Show(
                "No drives available on this system.",
                "No Drives Found",
                "OK",
                "Warning"
            ) | Out-Null
            return $null
        }
        
        # Build drive list display
        $driveList = @()
        foreach ($drive in $drives) {
            $display = "$($drive.Letter): - $($drive.Label) ($($drive.FileSystem)) [$($drive.SizeGB)GB Total, $($drive.FreeGB)GB Free]"
            $driveList += $display
        }
        
        # Create simple selection window (using MessageBox as fallback)
        $message = "Available Drives:`n`n"
        for ($i = 0; $i -lt $driveList.Count; $i++) {
            $message += "$($i+1). $($driveList[$i])`n"
        }
        $message += "`nSelect a drive by number (or press Cancel to exit):"
        
        [System.Windows.MessageBox]::Show(
            $message,
            $Title,
            "OKCancel",
            "Information"
        ) | Out-Null
        
        # For now, return $null - will be enhanced with better selection dialog
        return $null
        
    } catch {
        Write-Warning "Error showing drive selection dialog: $_"
        return $null
    }
}

function Show-DriveWarningDialog {
    <#
    .SYNOPSIS
    Shows a warning about the selected drive before operation.
    
    .PARAMETER DriveLetter
    The drive letter being used
    
    .PARAMETER Operation
    Description of the operation to be performed
    
    .PARAMETER IsDefault
    Whether this is a default drive
    
    .OUTPUTS
    Boolean - $true if user consents, $false to cancel
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter,
        [string]$Operation = "system repair operation",
        [bool]$IsDefault = $false
    )
    
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        
        $drive = $DriveLetter.ToUpper()
        if ($drive.Length -gt 1) { $drive = $drive[0] }
        
        $driveInfo = Get-Volume -DriveLetter $drive -ErrorAction SilentlyContinue
        $label = $driveInfo.FileSystemLabel -replace '^\s+|\s+$'
        
        $message = "OPERATION TARGET CONFIRMATION`n`n"
        
        if ($IsDefault) {
            $message += "⚠ DEFAULT DRIVE IN USE ⚠`n`n"
        }
        
        $message += "Drive Letter: $drive`:`n"
        $message += "Volume Label: $(if ($label) { $label } else { '[Unlabeled]' })`n"
        if ($driveInfo) {
            $message += "Total Size: $([math]::Round($driveInfo.Size / 1GB, 2)) GB`n"
            $message += "Free Space: $([math]::Round($driveInfo.SizeRemaining / 1GB, 2)) GB`n"
        }
        $message += "`nOperation: $Operation`n`n"
        $message += "Do you want to proceed with this operation on $($drive): ?`n"
        
        $result = [System.Windows.MessageBox]::Show(
            $message,
            "Drive Selection Confirmation",
            "YesNo",
            "Warning"
        )
        
        return ($result -eq [System.Windows.MessageBoxResult]::Yes)
    } catch {
        Write-Warning "Error showing drive warning dialog: $_"
        return $false
    }
}

function Select-OperationDrive {
    <#
    .SYNOPSIS
    Comprehensive drive selection function with all features.
    Handles default drive, warnings, and user selection.
    
    .PARAMETER OperationName
    Name of the operation (for messages)
    
    .PARAMETER DefaultDrive
    Optional default drive letter
    
    .PARAMETER AllowOverride
    Whether to allow overriding the default drive
    
    .PARAMETER SuppressWarnings
    Whether to suppress default drive warnings
    
    .OUTPUTS
    String - selected drive letter or $null if cancelled
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OperationName,
        [string]$DefaultDrive = $null,
        [bool]$AllowOverride = $true,
        [bool]$SuppressWarnings = $false
    )
    
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        
        # If default drive is specified and warning not suppressed, show warning
        if ($DefaultDrive -and -not $SuppressWarnings) {
            $proceed = Show-DriveWarningDialog -DriveLetter $DefaultDrive `
                -Operation $OperationName -IsDefault $true
            
            if (-not $proceed) {
                return $null
            }
            
            # Ask if user wants to override
            if ($AllowOverride) {
                $override = [System.Windows.MessageBox]::Show(
                    "Do you want to select a different drive instead?",
                    "Override Default Drive",
                    "YesNo",
                    "Question"
                )
                
                if ($override -eq [System.Windows.MessageBoxResult]::Yes) {
                    return Show-DriveSelectionDialog -Title "Select Alternative Drive"
                }
            }
            
            return $DefaultDrive
        }
        
        # No default or warnings suppressed - show selection dialog
        return Show-DriveSelectionDialog -Title "Select Drive for $OperationName"
        
    } catch {
        Write-Warning "Error in drive selection: $_"
        return $null
    }
}

function Format-DriveStatusMessage {
    <#
    .SYNOPSIS
    Formats status messages to include specific drive information.
    
    .PARAMETER Message
    Base message text
    
    .PARAMETER DriveLetter
    The drive letter being referenced
    
    .PARAMETER OperationType
    Type of operation for context
    
    .OUTPUTS
    String - formatted message with drive context
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter,
        [string]$OperationType = "Operation"
    )
    
    try {
        $drive = $DriveLetter.ToUpper()
        if ($drive.Length -gt 1) { $drive = $drive[0] }
        
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        return "[$timestamp | Drive: $($drive): | $OperationType] $Message"
    } catch {
        return $Message
    }
}

function Get-DriveHealthStatus {
    <#
    .SYNOPSIS
    Retrieves health and status information for a specific drive.
    
    .PARAMETER DriveLetter
    The drive letter to check
    
    .OUTPUTS
    PSObject with health information
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )
    
    try {
        $drive = $DriveLetter.ToUpper()
        if ($drive.Length -gt 1) { $drive = $drive[0] }
        
        $driveInfo = Get-Volume -DriveLetter $drive -ErrorAction SilentlyContinue
        
        $status = [PSObject]@{
            DriveLetter = $drive
            Label = $driveInfo.FileSystemLabel
            FileSystem = $driveInfo.FileSystem
            TotalSize = $driveInfo.Size
            FreeSpace = $driveInfo.SizeRemaining
            HealthStatus = $driveInfo.HealthStatus
            IsAccessible = Test-DriveAccessibility -DriveLetter $drive
            TotalSizeGB = [math]::Round($driveInfo.Size / 1GB, 2)
            FreeSpaceGB = [math]::Round($driveInfo.SizeRemaining / 1GB, 2)
            UsagePercent = [math]::Round((($driveInfo.Size - $driveInfo.SizeRemaining) / $driveInfo.Size) * 100, 2)
        }
        
        return $status
    } catch {
        Write-Warning "Error retrieving drive health status: $_"
        return $null
    }
}

function Get-DriveSelectionSummary {
    <#
    .SYNOPSIS
    Provides a summary of current drive selection state.
    
    .OUTPUTS
    PSObject with drive selection information
    #>
    try {
        $summary = [PSObject]@{
            CurrentDrive = $global:MiracleBoot_SelectedDrive
            WarningShown = $global:MiracleBoot_DriveWarningShown
            WarningsSuppressed = $global:MiracleBoot_DriveSuppressWarnings
            AvailableDrives = (Get-AvailableSystemDrives).Letter -join ', '
            Timestamp = Get-Date
        }
        
        return $summary
    } catch {
        return $null
    }
}

Export-ModuleMember -Function @(
    'Get-AvailableSystemDrives',
    'Test-DriveAccessibility',
    'Show-DriveSelectionDialog',
    'Show-DriveWarningDialog',
    'Select-OperationDrive',
    'Format-DriveStatusMessage',
    'Get-DriveHealthStatus',
    'Get-DriveSelectionSummary'
)
