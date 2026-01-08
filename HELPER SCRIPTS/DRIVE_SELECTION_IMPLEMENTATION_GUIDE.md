# DRIVE SELECTION & GLOBAL SETTINGS ENHANCEMENT - Implementation Guide
# Version: 7.3.0
# Last Updated: January 7, 2026
# 
# OVERVIEW:
# This enhancement adds comprehensive drive selection, global settings management,
# and drive-specific status messages throughout the MiracleBoot application.
#
# ============================================================================

## FEATURES IMPLEMENTED

### 1. DriveSelectionManager.ps1
- **Get-AvailableSystemDrives**: Lists all accessible drives with details
- **Test-DriveAccessibility**: Checks if a drive is accessible
- **Show-DriveSelectionDialog**: Displays drive selection GUI
- **Show-DriveWarningDialog**: Shows warning before operation on default drive
- **Select-OperationDrive**: Comprehensive drive selection with all features
- **Format-DriveStatusMessage**: Adds drive context to all status messages
- **Get-DriveHealthStatus**: Gets health info for specific drive
- **Get-DriveSelectionSummary**: Shows current selection state

### 2. GlobalSettingsManager.ps1
- **Get-Setting / Set-Setting**: Generic setting getters/setters
- **Get-DefaultDrive / Set-DefaultDrive**: Default drive management
- **Get-SuppressWarnings / Set-SuppressWarnings**: Warning preferences
- **Get-AllowDriveOverride / Set-AllowDriveOverride**: Override permissions
- **Get-VerboseLogging / Set-VerboseLogging**: Logging preferences
- **Get-AutoBackupBeforeRepair / Set-AutoBackupBeforeRepair**: Backup options
- **Save-Settings / Load-Settings**: Persistent storage
- **Export-Settings / Import-Settings**: Backup/restore settings
- **Reset-ToDefaults**: Factory reset

### 3. Integration Points

#### In WinRepairGUI.ps1:
1. Load modules on startup
2. Add Settings gear icon to toolbar
3. Create Settings submenu with:
   - Default Drive settings
   - Warning preferences
   - Drive override settings
   - Logging options
   - Reset to defaults
4. Add drive selector to each operation
5. Update status messages with drive context

#### In WinRepairCore.ps1:
1. Add $DriveLetter parameter to all functions
2. Update status outputs with Format-DriveStatusMessage
3. Add drive selection prompts before operations

#### In WinRepairTUI.ps1:
1. Add drive selection prompt to start
2. Show selected drive in header
3. Allow drive change at any menu

## USAGE EXAMPLES

### For GUI Operations:
```powershell
# In button click handler:
$selectedDrive = Select-OperationDrive -OperationName "Boot Repair" `
    -DefaultDrive (Get-DefaultDrive) `
    -AllowOverride (Get-AllowDriveOverride) `
    -SuppressWarnings (Get-SuppressWarnings)

if ($selectedDrive) {
    $statusMsg = Format-DriveStatusMessage -Message "Starting boot repair..." `
        -DriveLetter $selectedDrive -OperationType "Boot Repair"
    $statusBox.Text = $statusMsg
    
    Run-BootDiagnosis -Drive $selectedDrive | Add-OutputBox
}
```

### For Settings Management:
```powershell
# Set default drive
Set-DefaultDrive "C"

# Suppress warnings
Set-SuppressWarnings $true

# Allow override
Set-AllowDriveOverride $true

# Check current settings
Get-SettingsSummary
```

### For Drive-Specific Status Messages:
```powershell
$message = Format-DriveStatusMessage `
    -Message "Analyzing system integrity..." `
    -DriveLetter "C" `
    -OperationType "Diagnostics"

# Output: [14:32:15 | Drive: C: | Diagnostics] Analyzing system integrity...
```

## SETTINGS FILE LOCATION

Windows: `%APPDATA%\MiracleBoot\Settings.xml`
Example: `C:\Users\YourUsername\AppData\Roaming\MiracleBoot\Settings.xml`

## DEFAULT SETTINGS

```xml
<MiracleBoot_Settings Version="7.3.0" SaveTime="2026-01-07 14:30:00">
    <DefaultDrive/>
    <SuppressWarnings>false</SuppressWarnings>
    <AllowDriveOverride>true</AllowDriveOverride>
    <VerboseLogging>false</VerboseLogging>
    <AutoBackupBeforeRepair>true</AutoBackupBeforeRepair>
    <ConfirmDestructiveOperations>true</ConfirmDestructiveOperations>
    <RememberLastDrive>true</RememberLastDrive>
    <Theme>Dark</Theme>
    <WindowWidth>1200</WindowWidth>
    <WindowHeight>850</WindowHeight>
</MiracleBoot_Settings>
```

## HOW TO INTEGRATE INTO GUI

### Step 1: Load Modules in Start-GUI
Add to the beginning of Start-GUI function:
```powershell
# Load settings and drive selection managers
. (Join-Path $PSScriptRoot "DriveSelectionManager.ps1")
. (Join-Path $PSScriptRoot "GlobalSettingsManager.ps1")
```

### Step 2: Add Settings Gear Icon to Toolbar
Add to XAML toolbar (after existing buttons):
```xml
<Separator Margin="10,0"/>
<Button Content="⚙️ Settings" Name="BtnSettings" Width="100" Height="25" 
    Margin="2" ToolTip="Global Settings and Preferences"/>
```

### Step 3: Create Settings Menu Handler
```powershell
$BtnSettings.Add_Click({
    Show-SettingsWindow
})
```

### Step 4: Add Drive Selection to Every Operation
For each repair function button, wrap with drive selector:
```powershell
$BtnFixBoot.Add_Click({
    $drive = Select-OperationDrive -OperationName "Fix Boot Sector" `
        -DefaultDrive (Get-DefaultDrive) `
        -AllowOverride (Get-AllowDriveOverride) `
        -SuppressWarnings (Get-SuppressWarnings)
    
    if ($drive) {
        $statusMsg = Format-DriveStatusMessage -Message "Starting fix..." `
            -DriveLetter $drive -OperationType "Boot Repair"
        $FixerOutput.Text += $statusMsg + "`n"
        # ... perform operation with $drive parameter
    }
})
```

### Step 5: Update Status Messages
Before any output, format with drive context:
```powershell
$output = Format-DriveStatusMessage -Message $baseMessage `
    -DriveLetter $selectedDrive `
    -OperationType "Boot Diagnostics"
```

## CONFIGURATION OPTIONS

### Via Settings Menu (GUI):
1. ⚙️ Settings → Default Drive Selection
   - Set default drive to C, D, E, etc.
   - Leave empty for always prompt

2. ⚙️ Settings → Warning Preferences
   - ☑️ Warn about default drive usage
   - ☑️ Allow drive override
   - ☑️ Remember last used drive

3. ⚙️ Settings → Logging
   - ☑️ Enable verbose logging
   - ☑️ Log to file
   - Select log location

4. ⚙️ Settings → Advanced
   - ☑️ Auto-backup before repairs
   - ☑️ Require confirmation on destructive ops
   - Reset to defaults button

### Via PowerShell (Programmatic):
```powershell
Set-DefaultDrive "C"
Set-SuppressWarnings $false
Set-AllowDriveOverride $true
Set-AutoBackupBeforeRepair $true
Set-VerboseLogging $false
```

## WORKFLOW EXAMPLE: Boot Repair with Drive Selection

1. User clicks "Rebuild BCD from Windows Installation"
2. System checks if default drive is set
3. If default set and warnings NOT suppressed:
   - Shows dialog: "Using default drive C: for BCD rebuild. Proceed?"
   - Offers option to select different drive
4. User selects or confirms drive
5. Status message shows: "[14:35:22 | Drive: C: | Boot Repair] Rebuilding BCD..."
6. All subsequent status messages include drive context
7. Upon completion: "[14:36:45 | Drive: C: | Boot Repair] BCD rebuild completed successfully"

## BACKWARD COMPATIBILITY

All changes are backward compatible:
- Existing functions work without drive parameter
- Default to current system drive if not specified
- Legacy code continues to work unchanged
- New parameters are optional

## TESTING CHECKLIST

- [ ] Module loading completes without errors
- [ ] Settings file created in %APPDATA%\MiracleBoot\
- [ ] Default drive can be set and persists after restart
- [ ] Warnings show for default drive operations
- [ ] Drive override works correctly
- [ ] Drive selector dialog displays all available drives
- [ ] Status messages include drive letter and operation type
- [ ] Settings can be exported/imported
- [ ] Reset to defaults works
- [ ] Logging shows detailed drive information
- [ ] All repairs work with new drive parameter
- [ ] Diagnostics show drive-specific results

## FUTURE ENHANCEMENTS

1. **Multi-Drive Operations**: Queue operations for multiple drives
2. **Drive Profiles**: Save/load operation sets for specific drives
3. **Drive Health Dashboard**: Real-time monitoring of all drives
4. **Scheduled Repairs**: Schedule repairs for specific drives
5. **Cloud Sync Settings**: Sync settings across multiple machines
6. **Drive Blacklist**: Mark drives to skip in operations
7. **Operation History**: Log all operations per drive
8. **Smart Drive Detection**: Auto-detect optimal repair method per drive

## SUPPORT & TROUBLESHOOTING

### Settings File Won't Save
- Check %APPDATA%\MiracleBoot\ folder exists
- Verify write permissions
- Check disk space available

### Drive Selection Dialog Not Showing
- Verify WPF assemblies are loaded
- Check for MessageBox errors in console
- Try manual drive entry as fallback

### Default Drive Not Persisting
- Ensure Save-Settings is called after Set-Setting
- Check if AppData folder is accessible
- Verify settings XML file is created

### Status Messages Not Including Drive
- Ensure Format-DriveStatusMessage is called
- Check drive letter format (single letter without colon)
- Verify OperationType parameter is provided

## VERSION HISTORY

v7.3.0 (January 7, 2026)
- Initial release of drive selection and global settings system
- Added DriveSelectionManager.ps1
- Added GlobalSettingsManager.ps1
- Created comprehensive integration guide

## CONTACT & CREDITS

Created as part of MiracleBoot v7.3.0
Advanced Windows Recovery Toolkit
GitHub: MiracleBoot (GitHub Copilot - Visual Studio Integration)
