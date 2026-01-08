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
        [string]$PreselectedDrive = $null,
        [bool]$AllowSetDefault = $true,
        [bool]$ForceSetDefault = $false
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
        
        $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="420" Width="720"
        WindowStartupLocation="CenterScreen" Background="#F7F7F7">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Select a drive from the list below:" 
                   FontWeight="Bold" Margin="0,0,0,8"/>
        
        <ListView Grid.Row="1" Name="DriveList" Margin="0,0,0,8" SelectionMode="Single">
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="Drive" DisplayMemberBinding="{Binding Letter}" Width="60"/>
                    <GridViewColumn Header="Label" DisplayMemberBinding="{Binding Label}" Width="160"/>
                    <GridViewColumn Header="FileSystem" DisplayMemberBinding="{Binding FileSystem}" Width="90"/>
                    <GridViewColumn Header="Size (GB)" DisplayMemberBinding="{Binding SizeGB}" Width="90"/>
                    <GridViewColumn Header="Free (GB)" DisplayMemberBinding="{Binding FreeGB}" Width="90"/>
                    <GridViewColumn Header="Health" DisplayMemberBinding="{Binding Health}" Width="90"/>
                </GridView>
            </ListView.View>
        </ListView>
        
        <CheckBox Grid.Row="2" Name="SetDefaultCheck" Content="Set as default drive for future operations"
                  Margin="0,0,0,8"/>
        
        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="OkButton" Content="OK" Width="90" Height="30" Margin="0,0,8,0"/>
            <Button Name="CancelButton" Content="Cancel" Width="90" Height="30"/>
        </StackPanel>
    </Grid>
</Window>
"@
        
        $window = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
        $list = $window.FindName("DriveList")
        $setDefaultCheck = $window.FindName("SetDefaultCheck")
        $okButton = $window.FindName("OkButton")
        $cancelButton = $window.FindName("CancelButton")
        
        $list.ItemsSource = $drives
        
        if ($PreselectedDrive) {
            $target = $PreselectedDrive.TrimEnd(':').ToUpper()
            foreach ($item in $list.Items) {
                if ($item.Letter -eq $target) {
                    $list.SelectedItem = $item
                    $list.ScrollIntoView($item)
                    break
                }
            }
        }
        
        if (-not $AllowSetDefault) {
            $setDefaultCheck.Visibility = "Collapsed"
        } elseif ($ForceSetDefault) {
            $setDefaultCheck.IsChecked = $true
            $setDefaultCheck.IsEnabled = $false
        }
        
        if (-not $AllowCancel) {
            $cancelButton.Visibility = "Collapsed"
        }
        
        $script:driveSelection = $null
        $okButton.Add_Click({
            if (-not $list.SelectedItem) {
                [System.Windows.MessageBox]::Show(
                    "Please select a drive to continue.",
                    "No Drive Selected",
                    "OK",
                    "Warning"
                ) | Out-Null
                return
            }
            $script:driveSelection = $list.SelectedItem
            $window.DialogResult = $true
            $window.Close()
        })
        
        $cancelButton.Add_Click({
            $window.DialogResult = $false
            $window.Close()
        })
        
        $result = $window.ShowDialog()
        if (-not $result -or -not $script:driveSelection) {
            return $null
        }
        
        $selectedDrive = $script:driveSelection.Letter
        $setDefault = ($setDefaultCheck.IsChecked -eq $true)
        if ($setDefault -and (Get-Command Set-DefaultDrive -ErrorAction SilentlyContinue)) {
            Set-DefaultDrive $selectedDrive | Out-Null
        }
        
        return $selectedDrive
        
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
        $label = if ($driveInfo -and $driveInfo.FileSystemLabel) { $driveInfo.FileSystemLabel -replace '^\s+|\s+$' } else { "" }
        
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

function Show-DefaultDriveChoiceDialog {
    <#
    .SYNOPSIS
    Presents a clear choice when a default drive is configured.
    
    .PARAMETER DefaultDrive
    The default drive letter
    
    .PARAMETER Operation
    Operation name for context
    
    .PARAMETER AllowOverride
    Whether to allow choosing a different drive
    
    .OUTPUTS
    String - UseDefault, ChooseDifferent, ChangeDefault, or Cancel
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DefaultDrive,
        [string]$Operation = "operation",
        [bool]$AllowOverride = $true
    )
    
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        
        $drive = $DefaultDrive.TrimEnd(':').ToUpper()
        $driveInfo = Get-Volume -DriveLetter $drive -ErrorAction SilentlyContinue
        $label = if ($driveInfo -and $driveInfo.FileSystemLabel) { $driveInfo.FileSystemLabel } else { "[Unlabeled]" }
        $size = if ($driveInfo) { [math]::Round($driveInfo.Size / 1GB, 2) } else { "N/A" }
        $free = if ($driveInfo) { [math]::Round($driveInfo.SizeRemaining / 1GB, 2) } else { "N/A" }
        
        $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Default Drive Confirmation" Height="240" Width="520"
        WindowStartupLocation="CenterScreen" Background="#F7F7F7">
    <Grid Margin="12">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Default drive detected for this operation." 
                   FontWeight="Bold" Margin="0,0,0,8"/>
        
        <StackPanel Grid.Row="1" Margin="0,0,0,10">
            <TextBlock Text="Operation: $Operation" Margin="0,0,0,4"/>
            <TextBlock Text="Default Drive: ${drive}:`nLabel: $label`nSize: $size GB  Free: $free GB" />
        </StackPanel>
        
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="UseDefaultBtn" Content="Use Default" Width="110" Height="30" Margin="0,0,8,0"/>
            <Button Name="ChooseBtn" Content="Choose Different" Width="130" Height="30" Margin="0,0,8,0"/>
            <Button Name="ChangeDefaultBtn" Content="Change Default" Width="130" Height="30" Margin="0,0,8,0"/>
            <Button Name="CancelBtn" Content="Cancel" Width="90" Height="30"/>
        </StackPanel>
    </Grid>
</Window>
"@
        
        $window = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
        $useDefaultBtn = $window.FindName("UseDefaultBtn")
        $chooseBtn = $window.FindName("ChooseBtn")
        $changeDefaultBtn = $window.FindName("ChangeDefaultBtn")
        $cancelBtn = $window.FindName("CancelBtn")
        
        if (-not $AllowOverride) {
            $chooseBtn.Visibility = "Collapsed"
            $changeDefaultBtn.Visibility = "Collapsed"
        }
        
        $script:choice = "Cancel"
        $useDefaultBtn.Add_Click({ $script:choice = "UseDefault"; $window.Close() })
        $chooseBtn.Add_Click({ $script:choice = "ChooseDifferent"; $window.Close() })
        $changeDefaultBtn.Add_Click({ $script:choice = "ChangeDefault"; $window.Close() })
        $cancelBtn.Add_Click({ $script:choice = "Cancel"; $window.Close() })
        
        $window.ShowDialog() | Out-Null
        return $script:choice
        
    } catch {
        Write-Warning "Error showing default drive choice dialog: $_"
        return "Cancel"
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
        }
        
        if ($DefaultDrive) {
            if ($AllowOverride) {
                $choice = Show-DefaultDriveChoiceDialog -DefaultDrive $DefaultDrive `
                    -Operation $OperationName -AllowOverride $AllowOverride
                
                switch ($choice) {
                    "UseDefault" { return $DefaultDrive }
                    "ChooseDifferent" { return Show-DriveSelectionDialog -Title "Select Drive for $OperationName" -PreselectedDrive $DefaultDrive -AllowSetDefault $false }
                    "ChangeDefault" { return Show-DriveSelectionDialog -Title "Select New Default Drive" -PreselectedDrive $DefaultDrive -AllowSetDefault $true -ForceSetDefault $true }
                    default { return $null }
                }
            }
            
            return $DefaultDrive
        }
        
        # No default - show selection dialog
        return Show-DriveSelectionDialog -Title "Select Drive for $OperationName" -AllowSetDefault $true
        
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
