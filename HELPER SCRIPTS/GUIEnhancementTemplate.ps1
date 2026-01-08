# ============================================================================
# DRIVE-AWARE GUI INTEGRATION EXAMPLE - GUIEnhancementTemplate.ps1
# Version: 7.3.0
# Last Updated: January 7, 2026
# ============================================================================
#
# This template shows how to integrate the DriveSelectionManager and 
# GlobalSettingsManager modules into the existing WinRepairGUI.ps1
#
# Copy patterns from this file into your GUI event handlers
#
# ============================================================================

# --- INITIALIZATION (Add to Start-GUI function before creating window) ---

function Initialize-DriveSelectionSystem {
    Write-Host "Initializing Drive Selection and Settings Manager..." -ForegroundColor Cyan
    
    try {
        # Load Drive Selection Manager
        $dsmPath = Join-Path $PSScriptRoot "DriveSelectionManager.ps1"
        if (Test-Path $dsmPath) {
            . $dsmPath
            Write-Host "[OK] DriveSelectionManager loaded" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] DriveSelectionManager not found at $dsmPath" -ForegroundColor Yellow
        }
        
        # Load Global Settings Manager
        $gsmPath = Join-Path $PSScriptRoot "GlobalSettingsManager.ps1"
        if (Test-Path $gsmPath) {
            . $gsmPath
            Write-Host "[OK] GlobalSettingsManager loaded" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] GlobalSettingsManager not found at $gsmPath" -ForegroundColor Yellow
        }
        
        return $true
    } catch {
        Write-Host "[ERROR] Failed to initialize drive selection system: $_" -ForegroundColor Red
        return $false
    }
}

# --- SETTINGS WINDOW IMPLEMENTATION ---

function Show-SettingsWindow {
    Add-Type -AssemblyName PresentationFramework
    
    $settingsXAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MiracleBoot Settings" Width="500" Height="600" 
        WindowStartupLocation="CenterOwner" Background="#F0F0F0">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TabControl Grid.Row="0" Margin="10">
            <!-- Default Drive Tab -->
            <TabItem Header="Default Drive">
                <StackPanel Margin="10">
                    <TextBlock Text="Default Drive Settings" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                    <TextBlock Text="Select a default drive for operations:" Margin="0,0,0,5" Foreground="Gray"/>
                    
                    <ComboBox Name="DefaultDriveCombo" Height="30" Margin="0,0,0,10"/>
                    
                    <TextBlock Text="If no default drive is set, you will be prompted for each operation." 
                              Foreground="Gray" TextWrapping="Wrap" Margin="0,0,0,10" FontSize="11"/>
                    
                    <CheckBox Name="RememberLastDrive" Content="Remember last used drive" Margin="0,10,0,0"/>
                </StackPanel>
            </TabItem>
            
            <!-- Warning Preferences Tab -->
            <TabItem Header="Warnings">
                <StackPanel Margin="10">
                    <TextBlock Text="Warning Preferences" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                    
                    <CheckBox Name="WarnOnDefaultDrive" Content="Warn me before using default drive" Margin="0,0,0,10"/>
                    <TextBlock Text="When checked, shows confirmation dialog before using default drive for operations." 
                              Foreground="Gray" TextWrapping="Wrap" Margin="20,0,0,20" FontSize="11"/>
                    
                    <CheckBox Name="AllowDriveOverride" Content="Allow me to select different drive" Margin="0,0,0,10"/>
                    <TextBlock Text="When checked, displays option to select different drive instead of using default." 
                              Foreground="Gray" TextWrapping="Wrap" Margin="20,0,0,20" FontSize="11"/>
                    
                    <Button Content="Reset Warning Messages" Height="30" Background="#D9534F" Foreground="White"/>
                </StackPanel>
            </TabItem>
            
            <!-- Advanced Tab -->
            <TabItem Header="Advanced">
                <StackPanel Margin="10">
                    <TextBlock Text="Advanced Settings" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                    
                    <CheckBox Name="VerboseLogging" Content="Enable verbose logging" Margin="0,0,0,10"/>
                    <TextBlock Text="Logs detailed information about all operations including drive selection." 
                              Foreground="Gray" TextWrapping="Wrap" Margin="20,0,0,20" FontSize="11"/>
                    
                    <CheckBox Name="AutoBackupBeforeRepair" Content="Backup BCD before repairs" Margin="0,0,0,10"/>
                    <TextBlock Text="Automatically creates backup of boot configuration before repair operations." 
                              Foreground="Gray" TextWrapping="Wrap" Margin="20,0,0,20" FontSize="11"/>
                    
                    <CheckBox Name="ConfirmDestructive" Content="Confirm destructive operations" Margin="0,0,0,10"/>
                    <TextBlock Text="Requires manual confirmation before running destructive repair operations." 
                              Foreground="Gray" TextWrapping="Wrap" Margin="20,0,0,20" FontSize="11"/>
                </StackPanel>
            </TabItem>
        </TabControl>
        
        <!-- Buttons -->
        <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="10">
            <Button Name="BtnSave" Content="Save Settings" Width="100" Height="35" 
                   Background="#5CB85C" Foreground="White" FontWeight="Bold" Margin="5"/>
            <Button Name="BtnCancel" Content="Cancel" Width="100" Height="35" Margin="5"/>
            <Button Name="BtnReset" Content="Reset to Defaults" Width="150" Height="35" 
                   Background="#D9534F" Foreground="White" Margin="5"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $settingsWindow = [xml]$settingsXAML
    $window = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $settingsWindow))
    
    # Get controls
    $defaultDriveCombo = $window.FindName("DefaultDriveCombo")
    $warnOnDefaultCheck = $window.FindName("WarnOnDefaultDrive")
    $allowOverrideCheck = $window.FindName("AllowDriveOverride")
    $verboseLoggingCheck = $window.FindName("VerboseLogging")
    $autoBackupCheck = $window.FindName("AutoBackupBeforeRepair")
    $confirmDestructiveCheck = $window.FindName("ConfirmDestructive")
    $rememberLastCheck = $window.FindName("RememberLastDrive")
    $saveButton = $window.FindName("BtnSave")
    $cancelButton = $window.FindName("BtnCancel")
    $resetButton = $window.FindName("BtnReset")
    
    # Populate drive combo
    $drives = Get-AvailableSystemDrives
    foreach ($drive in $drives) {
        $defaultDriveCombo.Items.Add("$($drive.Letter): ($($drive.Label))") | Out-Null
    }
    
    # Load current settings
    $currentDefault = Get-DefaultDrive
    if ($currentDefault) {
        $defaultDriveCombo.SelectedItem = "$($currentDefault): (System)"
    }
    
    $warnOnDefaultCheck.IsChecked = -not (Get-SuppressWarnings)
    $allowOverrideCheck.IsChecked = Get-AllowDriveOverride
    $verboseLoggingCheck.IsChecked = Get-VerboseLogging
    $autoBackupCheck.IsChecked = Get-AutoBackupBeforeRepair
    $confirmDestructiveCheck.IsChecked = Get-Setting -Name "ConfirmDestructiveOperations" -Default $true
    $rememberLastCheck.IsChecked = Get-Setting -Name "RememberLastDrive" -Default $true
    
    # Event handlers
    $saveButton.Add_Click({
        # Save settings
        $selectedDrive = $defaultDriveCombo.SelectedItem
        if ($selectedDrive -match '^([A-Z]):') {
            Set-DefaultDrive $matches[1]
        } else {
            Clear-DefaultDrive
        }
        
        Set-SuppressWarnings (-not $warnOnDefaultCheck.IsChecked)
        Set-AllowDriveOverride $allowOverrideCheck.IsChecked
        Set-VerboseLogging $verboseLoggingCheck.IsChecked
        Set-AutoBackupBeforeRepair $autoBackupCheck.IsChecked
        Set-Setting -Name "ConfirmDestructiveOperations" -Value $confirmDestructiveCheck.IsChecked
        Set-Setting -Name "RememberLastDrive" -Value $rememberLastCheck.IsChecked
        
        [System.Windows.MessageBox]::Show("Settings saved successfully.", "Success", "OK", "Information")
        $window.Close()
    })
    
    $cancelButton.Add_Click({
        $window.Close()
    })
    
    $resetButton.Add_Click({
        $result = [System.Windows.MessageBox]::Show("Reset all settings to defaults?", "Confirm Reset", "YesNo", "Question")
        if ($result -eq "Yes") {
            Reset-ToDefaults
            [System.Windows.MessageBox]::Show("Settings reset to defaults.", "Success", "OK", "Information")
            $window.Close()
        }
    })
    
    $window.ShowDialog() | Out-Null
}

# --- EXAMPLE: BUTTON CLICK HANDLER WITH DRIVE SELECTION ---

function Initialize-BootRepairButton {
    param($Button, $OutputTextBox)
    
    $Button.Add_Click({
        # Step 1: Select drive
        $selectedDrive = Select-OperationDrive `
            -OperationName "Boot Repair" `
            -DefaultDrive (Get-DefaultDrive) `
            -AllowOverride (Get-AllowDriveOverride) `
            -SuppressWarnings (Get-SuppressWarnings)
        
        if ($null -eq $selectedDrive) {
            $OutputTextBox.AppendText("Operation cancelled by user.`n")
            return
        }
        
        # Step 2: Format status message with drive context
        $statusMsg = Format-DriveStatusMessage `
            -Message "Starting boot repair analysis..." `
            -DriveLetter $selectedDrive `
            -OperationType "Boot Repair"
        
        $OutputTextBox.AppendText("$statusMsg`n")
        
        # Step 3: Run operation with drive parameter
        try {
            $result = Run-BootDiagnosis -Drive $selectedDrive
            
            # Step 4: Format output with drive info
            if ($result.HasCriticalIssues) {
                $OutputTextBox.AppendText("$(Format-DriveStatusMessage -Message 'CRITICAL ISSUES DETECTED' -DriveLetter $selectedDrive -OperationType 'Boot Repair')`n")
            } else {
                $OutputTextBox.AppendText("$(Format-DriveStatusMessage -Message 'Boot diagnosis completed successfully' -DriveLetter $selectedDrive -OperationType 'Boot Repair')`n")
            }
            
            $OutputTextBox.AppendText($result.Report)
            
        } catch {
            $errorMsg = Format-DriveStatusMessage `
                -Message "Error: $_" `
                -DriveLetter $selectedDrive `
                -OperationType "Boot Repair"
            $OutputTextBox.AppendText("$errorMsg`n")
        }
        
        $OutputTextBox.ScrollToEnd()
    })
}

# --- EXAMPLE: DIAGNOSTIC OPERATION WITH DRIVE SELECTION ---

function Initialize-DiagnosticsButton {
    param($Button, $DriveCombo, $OutputTextBox)
    
    # Populate drive combo
    $drives = Get-AvailableSystemDrives
    foreach ($drive in $drives) {
        $DriveCombo.Items.Add("$($drive.Letter):") | Out-Null
    }
    
    # Set default selection
    $defaultDrive = Get-DefaultDrive
    if ($defaultDrive) {
        $DriveCombo.SelectedItem = "$defaultDrive`:"
    } else {
        $DriveCombo.SelectedIndex = 0
    }
    
    $Button.Add_Click({
        $selectedDrive = $DriveCombo.SelectedItem -replace ':$', ''
        
        if ($null -eq $selectedDrive) {
            [System.Windows.MessageBox]::Show("Please select a drive.", "Error", "OK", "Error")
            return
        }
        
        $statusMsg = Format-DriveStatusMessage `
            -Message "Running diagnostics..." `
            -DriveLetter $selectedDrive `
            -OperationType "Diagnostics"
        
        $OutputTextBox.AppendText("$statusMsg`n")
        
        try {
            $health = Get-WindowsHealthSummary -TargetDrive $selectedDrive
            $OutputTextBox.AppendText("Overall Health: $($health.OverallHealth)`n")
            $OutputTextBox.AppendText("Status: $($health.Status)`n")
            
            # Display boot stack order for this drive
            foreach ($component in $health.BootStackOrder) {
                $OutputTextBox.AppendText("  $($component.Component): $($component.Status)`n")
            }
        } catch {
            $OutputTextBox.AppendText("Error: $_`n")
        }
        
        $OutputTextBox.ScrollToEnd()
    })
}

# --- EXAMPLE: STATUS MESSAGE HELPER ---

function Write-DriveDependentStatus {
    param(
        [string]$Message,
        [string]$DriveLetter,
        [string]$OperationType = "Operation",
        [System.Windows.Controls.TextBox]$OutputBox
    )
    
    $formattedMsg = Format-DriveStatusMessage `
        -Message $Message `
        -DriveLetter $DriveLetter `
        -OperationType $OperationType
    
    if ($OutputBox) {
        $OutputBox.AppendText("$formattedMsg`n")
        $OutputBox.ScrollToEnd()
    } else {
        Write-Host $formattedMsg
    }
}

# --- SETTINGS MENU INTEGRATION ---

function Initialize-SettingsMenu {
    param($SettingsButton)
    
    $SettingsButton.Add_Click({
        Show-SettingsWindow
    })
}

# --- EXAMPLE: COMPLETE FUNCTION WITH ALL INTEGRATIONS ---

function Invoke-DriveSelectorRepairOperation {
    param(
        [string]$OperationName,
        [scriptblock]$OperationScript,
        [System.Windows.Controls.TextBox]$OutputBox
    )
    
    # Step 1: Get drive selection with all features
    $drive = Select-OperationDrive `
        -OperationName $OperationName `
        -DefaultDrive (Get-DefaultDrive) `
        -AllowOverride (Get-AllowDriveOverride) `
        -SuppressWarnings (Get-SuppressWarnings)
    
    if ($null -eq $drive) {
        Write-DriveDependentStatus "Operation cancelled." -DriveLetter "" -OperationType $OperationName -OutputBox $OutputBox
        return
    }
    
    # Step 2: Check if verbose logging is enabled
    $verboseMode = Get-VerboseLogging
    
    # Step 3: Show start status
    Write-DriveDependentStatus "Starting $OperationName..." -DriveLetter $drive -OperationType $OperationName -OutputBox $OutputBox
    
    if ($verboseMode) {
        $driveHealth = Get-DriveHealthStatus -DriveLetter $drive
        Write-DriveDependentStatus "Drive Health: $($driveHealth.HealthStatus), Free: $($driveHealth.FreeSpaceGB) GB" `
            -DriveLetter $drive -OperationType "$OperationName (Verbose)" -OutputBox $OutputBox
    }
    
    # Step 4: Check for auto-backup requirement
    if ((Get-AutoBackupBeforeRepair) -and $OperationName -like "*Repair*") {
        Write-DriveDependentStatus "Creating backup before operation..." -DriveLetter $drive -OperationType $OperationName -OutputBox $OutputBox
        $backupResult = Export-BCDBackup
        if ($backupResult.Success) {
            Write-DriveDependentStatus "Backup created: $($backupResult.Path)" -DriveLetter $drive -OperationType "$OperationName (Backup)" -OutputBox $OutputBox
        }
    }
    
    # Step 5: Check for confirmation requirement
    if ((Get-Setting -Name "ConfirmDestructiveOperations" -Default $true) -and $OperationName -like "*Delete*") {
        $confirm = [System.Windows.MessageBox]::Show(
            "This operation will make changes to drive $($drive):. Proceed?",
            "Confirm $OperationName",
            "YesNo",
            "Warning"
        )
        if ($confirm -ne "Yes") {
            Write-DriveDependentStatus "Operation cancelled by user." -DriveLetter $drive -OperationType $OperationName -OutputBox $OutputBox
            return
        }
    }
    
    # Step 6: Execute the operation script with drive parameter
    try {
        Write-DriveDependentStatus "Executing operation..." -DriveLetter $drive -OperationType $OperationName -OutputBox $OutputBox
        
        & $OperationScript -DriveLetter $drive | ForEach-Object {
            $OutputBox.AppendText("$_`n")
        }
        
        Write-DriveDependentStatus "$OperationName completed successfully." -DriveLetter $drive -OperationType $OperationName -OutputBox $OutputBox
    } catch {
        Write-DriveDependentStatus "Error: $_" -DriveLetter $drive -OperationType "$OperationName (ERROR)" -OutputBox $OutputBox
    }
    
    $OutputBox.ScrollToEnd()
}

# --- INITIALIZATION CALL ---

if (-not (Initialize-DriveSelectionSystem)) {
    Write-Host "Warning: Drive selection system failed to initialize. Some features may not work." -ForegroundColor Yellow
}
