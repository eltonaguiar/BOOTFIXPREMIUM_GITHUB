# ============================================================================
# GLOBAL SETTINGS MANAGER - GlobalSettingsManager.ps1
# Version: 7.3.0
# Last Updated: January 7, 2026
# ============================================================================
#
# PURPOSE:
# Centralized settings management for MiracleBoot application
# Stores and retrieves user preferences for drive selection and operations
#
# FEATURES:
# - Persistent settings storage
# - Default drive management
# - Warning preferences
# - Operation preferences
# - Settings file management and validation
#
# ============================================================================

# Settings file location
$global:MiracleBoot_SettingsPath = Join-Path $env:APPDATA "MiracleBoot\Settings.xml"
$global:MiracleBoot_SettingsDir = Split-Path $global:MiracleBoot_SettingsPath

# Default settings structure
$global:MiracleBoot_DefaultSettings = @{
    DefaultDrive = $null
    SuppressWarnings = $false
    AllowDriveOverride = $true
    VerboseLogging = $false
    AutoBackupBeforeRepair = $true
    ConfirmDestructiveOperations = $true
    ReadOnlyMode = $false
    LastUsedDrive = $null
    LastUsedOperation = $null
    RememberLastDrive = $true
    Theme = "Dark"
    WindowWidth = 1200
    WindowHeight = 850
}

# Current settings in memory
$global:MiracleBoot_Settings = $global:MiracleBoot_DefaultSettings.Clone()

function Initialize-SettingsDirectory {
    <#
    .SYNOPSIS
    Ensures the settings directory exists.
    
    .OUTPUTS
    Boolean - $true if successful, $false otherwise
    #>
    try {
        if (-not (Test-Path $global:MiracleBoot_SettingsDir)) {
            $null = New-Item -ItemType Directory -Path $global:MiracleBoot_SettingsDir -Force -ErrorAction Stop
            return $true
        }
        return $true
    } catch {
        Write-Warning "Error creating settings directory: $_"
        return $false
    }
}

function Save-Settings {
    <#
    .SYNOPSIS
    Saves current settings to XML file.
    
    .OUTPUTS
    Boolean - $true if successful, $false otherwise
    #>
    try {
        Initialize-SettingsDirectory | Out-Null
        
        $xml = [xml]::new()
        $xmlDeclaration = $xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
        $xml.AppendChild($xmlDeclaration) | Out-Null
        
        $rootNode = $xml.CreateElement("MiracleBoot_Settings")
        $rootNode.SetAttribute("Version", "7.3.0")
        $rootNode.SetAttribute("SaveTime", (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
        $xml.AppendChild($rootNode) | Out-Null
        
        foreach ($key in $global:MiracleBoot_Settings.Keys) {
            $element = $xml.CreateElement($key)
            $element.InnerText = [string]($global:MiracleBoot_Settings[$key])
            $rootNode.AppendChild($element) | Out-Null
        }
        
        $xml.Save($global:MiracleBoot_SettingsPath)
        return $true
    } catch {
        Write-Warning "Error saving settings: $_"
        return $false
    }
}

function Load-Settings {
    <#
    .SYNOPSIS
    Loads settings from XML file.
    
    .OUTPUTS
    Boolean - $true if successful, $false otherwise
    #>
    try {
        if (-not (Test-Path $global:MiracleBoot_SettingsPath)) {
            # Settings don't exist yet, use defaults
            return $true
        }
        
        $xml = [xml]::new()
        $xml.Load($global:MiracleBoot_SettingsPath)
        
        $rootNode = $xml.SelectSingleNode("MiracleBoot_Settings")
        if ($null -eq $rootNode) {
            return $false
        }
        
        foreach ($element in $rootNode.ChildNodes) {
            if ($element.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                $value = $element.InnerText
                
                # Convert string values to appropriate types
                if ($value -eq "True" -or $value -eq "False") {
                    $value = [bool]::Parse($value)
                } elseif ($value -match '^\d+$') {
                    $value = [int]::Parse($value)
                } elseif ($value -eq "$null" -or $value -eq "") {
                    $value = $null
                }
                
                $global:MiracleBoot_Settings[$element.Name] = $value
            }
        }
        
        return $true
    } catch {
        Write-Warning "Error loading settings: $_"
        return $false
    }
}

function Get-Setting {
    <#
    .SYNOPSIS
    Retrieves a specific setting value.
    
    .PARAMETER Name
    The setting name
    
    .PARAMETER Default
    Default value if setting not found
    
    .OUTPUTS
    The setting value or default
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Default = $null
    )
    
    if ($global:MiracleBoot_Settings.ContainsKey($Name)) {
        return $global:MiracleBoot_Settings[$Name]
    }
    
    return $Default
}

function Set-Setting {
    <#
    .SYNOPSIS
    Sets a specific setting value.
    
    .PARAMETER Name
    The setting name
    
    .PARAMETER Value
    The setting value
    
    .PARAMETER AutoSave
    Whether to save to file immediately
    
    .OUTPUTS
    Boolean - $true if successful
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Value,
        [bool]$AutoSave = $true
    )
    
    try {
        $global:MiracleBoot_Settings[$Name] = $Value
        
        if ($AutoSave) {
            return Save-Settings
        }
        
        return $true
    } catch {
        Write-Warning "Error setting $Name : $_"
        return $false
    }
}

function Get-DefaultDrive {
    <#
    .SYNOPSIS
    Gets the configured default drive.
    
    .OUTPUTS
    String - drive letter or $null if not set
    #>
    return Get-Setting -Name "DefaultDrive"
}

function Set-DefaultDrive {
    <#
    .SYNOPSIS
    Sets the default drive for operations.
    
    .PARAMETER DriveLetter
    The drive letter to set as default (e.g., "C", "D")
    
    .OUTPUTS
    Boolean - $true if successful
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )
    
    try {
        $drive = $DriveLetter.ToUpper()
        if ($drive.Length -gt 1) { $drive = $drive[0] }
        
        return Set-Setting -Name "DefaultDrive" -Value $drive
    } catch {
        Write-Warning "Error setting default drive: $_"
        return $false
    }
}

function Clear-DefaultDrive {
    <#
    .SYNOPSIS
    Clears the default drive setting.
    
    .OUTPUTS
    Boolean - $true if successful
    #>
    return Set-Setting -Name "DefaultDrive" -Value $null
}

function Get-SuppressWarnings {
    <#
    .SYNOPSIS
    Gets the warning suppression setting.
    
    .OUTPUTS
    Boolean - $true if warnings are suppressed
    #>
    return Get-Setting -Name "SuppressWarnings" -Default $false
}

function Set-SuppressWarnings {
    <#
    .SYNOPSIS
    Sets whether to suppress default drive warnings.
    
    .PARAMETER Suppress
    $true to suppress warnings, $false to show them
    
    .OUTPUTS
    Boolean - $true if successful
    #>
    param(
        [Parameter(Mandatory=$true)]
        [bool]$Suppress
    )
    
    return Set-Setting -Name "SuppressWarnings" -Value $Suppress
}

function Get-AllowDriveOverride {
    <#
    .SYNOPSIS
    Gets whether drive override is allowed.
    
    .OUTPUTS
    Boolean - $true if override is allowed
    #>
    return Get-Setting -Name "AllowDriveOverride" -Default $true
}

function Set-AllowDriveOverride {
    <#
    .SYNOPSIS
    Sets whether to allow overriding the default drive.
    
    .PARAMETER Allow
    $true to allow override, $false to enforce default
    
    .OUTPUTS
    Boolean - $true if successful
    #>
    param(
        [Parameter(Mandatory=$true)]
        [bool]$Allow
    )
    
    return Set-Setting -Name "AllowDriveOverride" -Value $Allow
}

function Get-VerboseLogging {
    <#
    .SYNOPSIS
    Gets the verbose logging setting.
    
    .OUTPUTS
    Boolean - $true if verbose logging is enabled
    #>
    return Get-Setting -Name "VerboseLogging" -Default $false
}

function Set-VerboseLogging {
    <#
    .SYNOPSIS
    Sets whether to enable verbose logging.
    
    .PARAMETER Enable
    $true to enable verbose logging
    
    .OUTPUTS
    Boolean - $true if successful
    #>
    param(
        [Parameter(Mandatory=$true)]
        [bool]$Enable
    )
    
    return Set-Setting -Name "VerboseLogging" -Value $Enable
}

function Get-AutoBackupBeforeRepair {
    <#
    .SYNOPSIS
    Gets the auto-backup setting.
    
    .OUTPUTS
    Boolean - $true if auto-backup is enabled
    #>
    return Get-Setting -Name "AutoBackupBeforeRepair" -Default $true
}

function Set-AutoBackupBeforeRepair {
    <#
    .SYNOPSIS
    Sets whether to automatically backup before repair.
    
    .PARAMETER Enable
    $true to enable auto-backup
    
    .OUTPUTS
    Boolean - $true if successful
    #>
    param(
        [Parameter(Mandatory=$true)]
        [bool]$Enable
    )
    
    return Set-Setting -Name "AutoBackupBeforeRepair" -Value $Enable
}

function Get-ReadOnlyMode {
    <#
    .SYNOPSIS
    Gets the read-only mode setting.
    
    .OUTPUTS
    Boolean - $true if read-only mode is enabled
    #>
    return Get-Setting -Name "ReadOnlyMode" -Default $false
}

function Set-ReadOnlyMode {
    <#
    .SYNOPSIS
    Sets read-only mode for potentially destructive operations.
    
    .PARAMETER Enable
    $true to enable read-only mode, $false to disable
    
    .OUTPUTS
    Boolean - $true if successful
    #>
    param(
        [Parameter(Mandatory=$true)]
        [bool]$Enable
    )
    
    return Set-Setting -Name "ReadOnlyMode" -Value $Enable
}

function Reset-ToDefaults {
    <#
    .SYNOPSIS
    Resets all settings to defaults.
    
    .OUTPUTS
    Boolean - $true if successful
    #>
    try {
        $global:MiracleBoot_Settings = $global:MiracleBoot_DefaultSettings.Clone()
        return Save-Settings
    } catch {
        Write-Warning "Error resetting settings to defaults: $_"
        return $false
    }
}

function Export-Settings {
    <#
    .SYNOPSIS
    Exports all current settings to a backup file.
    
    .PARAMETER OutputPath
    Path to save the backup file
    
    .OUTPUTS
    Boolean - $true if successful
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    try {
        $xml = [xml]::new()
        $xmlDeclaration = $xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
        $xml.AppendChild($xmlDeclaration) | Out-Null
        
        $rootNode = $xml.CreateElement("MiracleBoot_SettingsBackup")
        $rootNode.SetAttribute("Version", "7.3.0")
        $rootNode.SetAttribute("ExportTime", (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
        $xml.AppendChild($rootNode) | Out-Null
        
        foreach ($key in $global:MiracleBoot_Settings.Keys) {
            $element = $xml.CreateElement($key)
            $element.InnerText = [string]($global:MiracleBoot_Settings[$key])
            $rootNode.AppendChild($element) | Out-Null
        }
        
        $xml.Save($OutputPath)
        return $true
    } catch {
        Write-Warning "Error exporting settings: $_"
        return $false
    }
}

function Import-Settings {
    <#
    .SYNOPSIS
    Imports settings from a backup file.
    
    .PARAMETER InputPath
    Path to the backup file
    
    .OUTPUTS
    Boolean - $true if successful
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputPath
    )
    
    try {
        if (-not (Test-Path $InputPath)) {
            Write-Warning "Settings backup file not found: $InputPath"
            return $false
        }
        
        $xml = [xml]::new()
        $xml.Load($InputPath)
        
        $rootNode = $xml.SelectSingleNode("MiracleBoot_SettingsBackup")
        if ($null -eq $rootNode) {
            return $false
        }
        
        foreach ($element in $rootNode.ChildNodes) {
            if ($element.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                $value = $element.InnerText
                
                if ($value -eq "True" -or $value -eq "False") {
                    $value = [bool]::Parse($value)
                } elseif ($value -match '^\d+$') {
                    $value = [int]::Parse($value)
                } elseif ($value -eq "$null" -or $value -eq "") {
                    $value = $null
                }
                
                $global:MiracleBoot_Settings[$element.Name] = $value
            }
        }
        
        return Save-Settings
    } catch {
        Write-Warning "Error importing settings: $_"
        return $false
    }
}

function Get-SettingsSummary {
    <#
    .SYNOPSIS
    Gets a summary of all current settings.
    
    .OUTPUTS
    PSObject with all settings
    #>
    try {
        $summary = New-Object PSObject
        
        foreach ($key in $global:MiracleBoot_Settings.Keys) {
            $summary | Add-Member -MemberType NoteProperty -Name $key -Value $global:MiracleBoot_Settings[$key]
        }
        
        return $summary
    } catch {
        return $null
    }
}

# Initialize on module load
Initialize-SettingsDirectory | Out-Null
Load-Settings | Out-Null

Export-ModuleMember -Function @(
    'Get-Setting',
    'Set-Setting',
    'Get-DefaultDrive',
    'Set-DefaultDrive',
    'Clear-DefaultDrive',
    'Get-SuppressWarnings',
    'Set-SuppressWarnings',
    'Get-AllowDriveOverride',
    'Set-AllowDriveOverride',
    'Get-VerboseLogging',
    'Set-VerboseLogging',
    'Get-AutoBackupBeforeRepair',
    'Set-AutoBackupBeforeRepair',
    'Get-ReadOnlyMode',
    'Set-ReadOnlyMode',
    'Reset-ToDefaults',
    'Export-Settings',
    'Import-Settings',
    'Get-SettingsSummary',
    'Save-Settings',
    'Load-Settings',
    'Initialize-SettingsDirectory'
)
