<#
.SYNOPSIS
WinRepairGUI.ps1 - MiracleBoot v7.2.0 GUI Interface Module
Provides a graphical user interface for Windows recovery operations.

.DESCRIPTION
This module implements the GUI interface for MiracleBoot, offering:
- Visual repair tool selection and execution
- Real-time progress monitoring
- Comprehensive error handling and logging
- Integration with core repair functions

.NOTES
Requires: Windows PowerShell 3.0+, WPF, Administrator privileges
Environment: FullOS only
#>

# ============================================================================
# GUI LOGGING INTEGRATION
# ============================================================================

function Log-GUIEvent {
    <#
    .SYNOPSIS
    Logs GUI-specific events for traceability.
    #>
    param(
        [string]$EventType,
        [string]$Message,
        [string]$Details = ''
    )
    
    if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
        $logMsg = "[GUI] $EventType - $Message"
        Write-ToLog $logMsg "INFO"
        
        if ($Details) {
            Write-ToLog "[GUI] Details: $Details" "DEBUG"
        }
    } else {
        Write-Host "[GUI] $EventType - $Message" -ForegroundColor Cyan
    }
}

function Log-GUISkip {
    <#
    .SYNOPSIS
    Logs reasons for skipping or exiting GUI mode.
    #>
    param(
        [string]$Reason,
        [string]$Details = '',
        [string]$FallbackMode = ''
    )
    
    if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
        Write-ToLog "GUI SKIP: $Reason" "WARNING"
        if ($Details) {
            Write-ToLog "  Reason Detail: $Details" "WARNING"
        }
        if ($FallbackMode) {
            Write-ToLog "  Fallback: Switching to $FallbackMode mode" "WARNING"
        }
    } else {
        Write-Host "[GUI SKIP] $Reason - $Details" -ForegroundColor Yellow
    }
}

# ============================================================================
# DRIVE SELECTION + SETTINGS INTEGRATION
# ============================================================================

function Initialize-DriveSelectionModules {
    <#
    .SYNOPSIS
    Loads drive selection and global settings modules if available.
    #>
    param([string]$ScriptRoot)
    
    $loaded = $false
    try {
        $dsmPath = Join-Path $ScriptRoot "HELPER SCRIPTS\DriveSelectionManager.ps1"
        if (Test-Path -LiteralPath $dsmPath) {
            . $dsmPath
            $loaded = $true
            Log-GUIEvent "INIT" "DriveSelectionManager loaded" $dsmPath
        } else {
            Log-GUIEvent "INIT" "DriveSelectionManager not found" $dsmPath
        }
        
        $gsmPath = Join-Path $ScriptRoot "HELPER SCRIPTS\GlobalSettingsManager.ps1"
        if (Test-Path -LiteralPath $gsmPath) {
            . $gsmPath
            $loaded = $true
            Log-GUIEvent "INIT" "GlobalSettingsManager loaded" $gsmPath
        } else {
            Log-GUIEvent "INIT" "GlobalSettingsManager not found" $gsmPath
        }
    } catch {
        Log-GUIEvent "INIT" "Drive selection module load failed" $_.Exception.Message
    }
    
    if (Get-Command Load-Settings -ErrorAction SilentlyContinue) {
        Load-Settings | Out-Null
    }
    
    return $loaded
}

function Show-SettingsWindow {
    <#
    .SYNOPSIS
    Displays settings dialog for default drive and warnings.
    #>
    if (-not (Get-Command Get-AvailableSystemDrives -ErrorAction SilentlyContinue)) {
        [System.Windows.MessageBox]::Show(
            "Drive selection components are not available.",
            "Settings Unavailable",
            "OK",
            "Warning"
        ) | Out-Null
        return
    }
    
    Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
    
    $settingsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MiracleBoot Settings" Width="520" Height="420"
        WindowStartupLocation="CenterScreen" Background="#F0F0F0">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TabControl Grid.Row="0">
            <TabItem Header="Default Drive">
                <StackPanel Margin="10">
                    <TextBlock Text="Default Drive Settings" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                    <TextBlock Text="Select a default drive for operations:" Margin="0,0,0,5" Foreground="Gray"/>
                    <ComboBox Name="DefaultDriveCombo" Height="28" Margin="0,0,0,10"/>
                    <TextBlock Text="If no default drive is set, you will be prompted for each operation."
                              Foreground="Gray" TextWrapping="Wrap" FontSize="11" Margin="0,0,0,10"/>
                    <CheckBox Name="RememberLastDrive" Content="Remember last used drive" Margin="0,10,0,0"/>
                </StackPanel>
            </TabItem>
            
            <TabItem Header="Warnings">
                <StackPanel Margin="10">
                    <TextBlock Text="Warning Preferences" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                    <CheckBox Name="WarnOnDefaultDrive" Content="Warn me before using default drive" Margin="0,0,0,10"/>
                    <TextBlock Text="Shows a confirmation dialog before using the default drive."
                              Foreground="Gray" TextWrapping="Wrap" FontSize="11" Margin="20,0,0,20"/>
                    <CheckBox Name="AllowDriveOverride" Content="Allow me to select a different drive" Margin="0,0,0,10"/>
                    <TextBlock Text="Allows choosing another drive or changing the default at runtime."
                              Foreground="Gray" TextWrapping="Wrap" FontSize="11" Margin="20,0,0,20"/>
                </StackPanel>
            </TabItem>
        </TabControl>
        
        <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="BtnSave" Content="Save" Width="90" Height="32" Background="#5CB85C" Foreground="White" Margin="0,0,8,0"/>
            <Button Name="BtnCancel" Content="Cancel" Width="90" Height="32" Margin="0,0,8,0"/>
            <Button Name="BtnReset" Content="Reset" Width="90" Height="32" Background="#D9534F" Foreground="White"/>
        </StackPanel>
    </Grid>
</Window>
"@
    
    $window = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$settingsXaml)))
    
    $defaultDriveCombo = $window.FindName("DefaultDriveCombo")
    $warnOnDefaultCheck = $window.FindName("WarnOnDefaultDrive")
    $allowOverrideCheck = $window.FindName("AllowDriveOverride")
    $rememberLastCheck = $window.FindName("RememberLastDrive")
    $saveButton = $window.FindName("BtnSave")
    $cancelButton = $window.FindName("BtnCancel")
    $resetButton = $window.FindName("BtnReset")
    
    $defaultDriveCombo.Items.Add("Always ask (no default)") | Out-Null
    $drives = Get-AvailableSystemDrives
    foreach ($drive in $drives) {
        $label = if ($drive.Label) { $drive.Label } else { "Unlabeled" }
        $defaultDriveCombo.Items.Add("$($drive.Letter): - $label ($($drive.FileSystem)) [$($drive.SizeGB) GB total, $($drive.FreeGB) GB free]") | Out-Null
    }
    
    $currentDefault = if (Get-Command Get-DefaultDrive -ErrorAction SilentlyContinue) { Get-DefaultDrive } else { $null }
    if ($currentDefault) {
        foreach ($item in $defaultDriveCombo.Items) {
            if ($item -match "^${currentDefault}:") {
                $defaultDriveCombo.SelectedItem = $item
                break
            }
        }
    } else {
        $defaultDriveCombo.SelectedIndex = 0
    }
    
    $warnOnDefaultCheck.IsChecked = if (Get-Command Get-SuppressWarnings -ErrorAction SilentlyContinue) { -not (Get-SuppressWarnings) } else { $true }
    $allowOverrideCheck.IsChecked = if (Get-Command Get-AllowDriveOverride -ErrorAction SilentlyContinue) { Get-AllowDriveOverride } else { $true }
    $rememberLastCheck.IsChecked = if (Get-Command Get-Setting -ErrorAction SilentlyContinue) { (Get-Setting -Name "RememberLastDrive" -Default $true) } else { $true }
    
    $saveButton.Add_Click({
        $selectedDrive = $defaultDriveCombo.SelectedItem
        if (Get-Command Set-DefaultDrive -ErrorAction SilentlyContinue -and Get-Command Clear-DefaultDrive -ErrorAction SilentlyContinue) {
            if ($selectedDrive -and $selectedDrive -match '^([A-Z]):') {
                Set-DefaultDrive $matches[1] | Out-Null
            } else {
                Clear-DefaultDrive | Out-Null
            }
        }
        
        if (Get-Command Set-SuppressWarnings -ErrorAction SilentlyContinue) {
            Set-SuppressWarnings (-not $warnOnDefaultCheck.IsChecked) | Out-Null
        }
        if (Get-Command Set-AllowDriveOverride -ErrorAction SilentlyContinue) {
            Set-AllowDriveOverride ($allowOverrideCheck.IsChecked -eq $true) | Out-Null
        }
        if (Get-Command Set-Setting -ErrorAction SilentlyContinue) {
            Set-Setting -Name "RememberLastDrive" -Value ($rememberLastCheck.IsChecked -eq $true) | Out-Null
        }
        
        [System.Windows.MessageBox]::Show("Settings saved.", "Saved", "OK", "Information") | Out-Null
        $window.Close()
    })
    
    $cancelButton.Add_Click({ $window.Close() })
    $resetButton.Add_Click({
        $confirm = [System.Windows.MessageBox]::Show("Reset settings to defaults?", "Confirm Reset", "YesNo", "Question")
        if ($confirm -eq "Yes") {
            if (Get-Command Reset-ToDefaults -ErrorAction SilentlyContinue) {
                Reset-ToDefaults | Out-Null
            }
            [System.Windows.MessageBox]::Show("Settings reset to defaults.", "Reset", "OK", "Information") | Out-Null
            $window.Close()
        }
    })
    
    $window.ShowDialog() | Out-Null
}

# ============================================================================
# GUI PREFLIGHT VALIDATION
# ============================================================================

function Test-GUIPrerequisites {
    <#
    .SYNOPSIS
    Validates that all GUI prerequisites are available.
    
    .OUTPUTS
    PSCustomObject with validation results
    #>
    
    Log-GUIEvent "PREFLIGHT" "Starting GUI prerequisites validation"
    
    $results = @{
        WPFAvailable = $false
        WinFormsAvailable = $false
        AdminPrivileges = $false
        ValidEnvironment = $false
        AllChecksPassed = $false
        Issues = @()
    }
    
    # Check 1: Admin privileges
    try {
        $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        $results.AdminPrivileges = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $results.AdminPrivileges) {
            $results.Issues += "Not running as Administrator"
            Log-GUISkip "Missing admin privileges" "GUI requires administrator rights"
        } else {
            Log-GUIEvent "VALIDATION" "✓ Administrator privileges confirmed"
        }
    } catch {
        $results.Issues += "Failed to check admin privileges: $_"
        Log-GUISkip "Admin check failed" $_.Exception.Message
    }
    
    # Check 2: FullOS environment
    if (Get-Command Get-EnvironmentType -ErrorAction SilentlyContinue) {
        $envType = Get-EnvironmentType
        if ($envType -ne 'FullOS') {
            $results.Issues += "Not in FullOS environment (currently: $envType)"
            Log-GUISkip "Wrong environment" "GUI only works in FullOS, detected: $envType"
        } else {
            $results.ValidEnvironment = $true
            Log-GUIEvent "VALIDATION" "✓ FullOS environment confirmed"
        }
    } else {
        # Fallback check
        if ($env:SystemDrive -ne 'X:' -and (Test-Path "$env:SystemDrive\Windows")) {
            $results.ValidEnvironment = $true
            Log-GUIEvent "VALIDATION" "✓ FullOS environment detected"
        } else {
            $results.Issues += "Invalid environment for GUI (X: drive or no Windows detected)"
            Log-GUISkip "Invalid environment" "SystemDrive=$env:SystemDrive"
        }
    }
    
    # Check 3: WPF Assembly
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        $results.WPFAvailable = $true
        Log-GUIEvent "VALIDATION" "✓ WPF (PresentationFramework) loaded successfully"
    } catch {
        $results.Issues += "WPF (PresentationFramework) not available: $_"
        Log-GUISkip "WPF unavailable" $_.Exception.Message
    }
    
    # Check 4: WinForms Assembly
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $results.WinFormsAvailable = $true
        Log-GUIEvent "VALIDATION" "✓ WinForms (System.Windows.Forms) loaded successfully"
    } catch {
        $results.Issues += "WinForms not available: $_"
        Log-GUISkip "WinForms unavailable" $_.Exception.Message
    }
    
    # Overall result
    $results.AllChecksPassed = ($results.WPFAvailable -and $results.AdminPrivileges -and $results.ValidEnvironment)
    
    if ($results.AllChecksPassed) {
        Log-GUIEvent "VALIDATION" "✓ All GUI prerequisites met - ready to launch"
    } else {
        Log-GUISkip "Prerequisites failed" "Failed checks: $($results.Issues.Count)" "TUI"
    }
    
    return $results
}

# ============================================================================
# GUI MAIN WINDOW
# ============================================================================

function Start-GUI {
    <#
    .SYNOPSIS
    Launches the MiracleBoot GUI interface.
    
    .DESCRIPTION
    Initializes and displays the main GUI window for MiracleBoot recovery tools.
    All operations are logged for diagnostic purposes.
    #>
    
    Log-GUIEvent "STARTUP" "GUI initialization beginning"
    
    try {
        # Validate prerequisites
        $prereqs = Test-GUIPrerequisites
        if (-not $prereqs.AllChecksPassed) {
            Log-GUISkip "Prerequisites validation failed" "Issues: $($prereqs.Issues -join '; ')" "TUI"
            throw "GUI prerequisites not met: $($prereqs.Issues -join '; ')"
        }
        
        Initialize-DriveSelectionModules -ScriptRoot $PSScriptRoot | Out-Null
        
        Log-GUIEvent "STARTUP" "Creating main window..."
        
        # Define XAML for the main window
        [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MiracleBoot v7.2.0 - Windows Recovery Toolkit - VisualStudio - github"
        Height="650"
        Width="900"
        WindowStartupLocation="CenterScreen"
        Background="#F0F0F0"
        FontFamily="Segoe UI"
        FontSize="11">
    <Grid>
        <StackPanel Margin="20">
            <!-- Header -->
            <TextBlock Text="MiracleBoot v7.2.0 - Windows Recovery Toolkit - VisualStudio - github" 
                       FontSize="24" 
                       FontWeight="Bold" 
                       Foreground="#0078D4" 
                       Margin="0,0,0,10"/>
            
            <TextBlock Text="Professional Windows repair, diagnostics, and recovery tools" 
                       FontSize="12" 
                       Foreground="#666666" 
                       Margin="0,0,0,20"/>
            
            <!-- Main content area -->
            <TabControl Margin="0,0,0,20">
                <!-- Tab 1: Quick Actions -->
                <TabItem Header="Quick Actions" Padding="15,5">
                    <StackPanel Margin="10" VerticalAlignment="Top">
                        <TextBlock Text="Common Recovery Tasks" FontSize="14" FontWeight="Bold" Margin="0,0,0,10"/>
                        
                        <Button Content="Repair Windows Installation" 
                                Height="40" 
                                Margin="0,0,0,10" 
                                Background="#0078D4" 
                                Foreground="White"
                                Name="RepairWindowsButton"/>
                        
                        <Button Content="Run System File Checker (SFC)" 
                                Height="40" 
                                Margin="0,0,0,10" 
                                Background="#0078D4" 
                                Foreground="White"
                                Name="RunSFCButton"/>
                        
                        <Button Content="Check Disk (CHKDSK)" 
                                Height="40" 
                                Margin="0,0,0,10" 
                                Background="#0078D4" 
                                Foreground="White"
                                Name="CheckDiskButton"/>
                        
                        <Button Content="Repair-Install Readiness Check" 
                                Height="40" 
                                Margin="0,0,0,10" 
                                Background="#107C10" 
                                Foreground="White"
                                Name="RepairInstallButton"/>

                        <Button Content="Local Remediation (No MDM)" 
                                Height="40" 
                                Margin="0,0,0,10" 
                                Background="#6B69D6" 
                                Foreground="White"
                                Name="LocalRemediationButton"/>
                    </StackPanel>
                </TabItem>
                
                <!-- Tab 2: Advanced Tools -->
                <TabItem Header="Advanced Tools" Padding="15,5">
                    <StackPanel Margin="10" VerticalAlignment="Top">
                        <TextBlock Text="Advanced Recovery Operations" FontSize="14" FontWeight="Bold" Margin="0,0,0,10"/>
                        
                        <Button Content="List Windows Volumes" 
                                Height="40" 
                                Margin="0,0,0,10" 
                                Background="#DA3B01" 
                                Foreground="White"
                                Name="ListVolumesButton"/>
                        
                        <Button Content="Scan Storage Drivers" 
                                Height="40" 
                                Margin="0,0,0,10" 
                                Background="#DA3B01" 
                                Foreground="White"
                                Name="ScanDriversButton"/>
                        
                        <Button Content="View BCD Configuration" 
                                Height="40" 
                                Margin="0,0,0,10" 
                                Background="#DA3B01" 
                                Foreground="White"
                                Name="ViewBCDButton"/>
                        
                        <Button Content="Inject Drivers (Offline)" 
                                Height="40" 
                                Margin="0,0,0,10" 
                                Background="#DA3B01" 
                                Foreground="White"
                                Name="InjectDriversButton"/>

                        <Button Content="Open Windows Backup (File Backup Only)" 
                                Height="40" 
                                Margin="0,0,0,6" 
                                Background="#DA3B01" 
                                Foreground="White"
                                Name="WindowsBackupButton"/>

                        <TextBlock Text="Windows Backup saves files and folders only. It is NOT a full system image; use imaging tools (e.g., Macrium) for bare-metal restore."
                                   TextWrapping="Wrap"
                                   Foreground="#555555"
                                   Margin="0,0,0,10"/>
                    </StackPanel>
                </TabItem>
                
                <!-- Tab 3: Information -->
                <TabItem Header="Information" Padding="15,5">
                    <StackPanel Margin="10" VerticalAlignment="Top">
                        <TextBlock Text="System Information" FontSize="14" FontWeight="Bold" Margin="0,0,0,10"/>
                        
                        <TextBlock Name="SystemInfoText" 
                                   TextWrapping="Wrap" 
                                   Foreground="#333333"
                                   Margin="0,0,0,15"/>
                        
                        <TextBlock Text="Diagnostic Logs" FontSize="12" FontWeight="Bold" Margin="0,0,0,10"/>
                        
                        <Button Content="View Diagnostic Log" 
                                Height="35" 
                                Background="#6B69D6" 
                                Foreground="White"
                                Name="ViewLogButton"/>

                        <Button Content="Boot Issue Mapping" 
                                Height="35" 
                                Margin="0,10,0,0"
                                Background="#6B69D6" 
                                Foreground="White"
                                Name="BootIssueMappingButton"/>

                        <Button Content="Open Local Remediation Guide" 
                                Height="35" 
                                Margin="0,10,0,0"
                                Background="#6B69D6" 
                                Foreground="White"
                                Name="OpenRemediationGuideButton"/>
                    </StackPanel>
                </TabItem>
            </TabControl>
            
            <!-- Status bar -->
            <Border Background="#E7E7E7" Padding="10" CornerRadius="3" Margin="0,10,0,0">
                <TextBlock Name="StatusText" 
                           Text="Ready" 
                           Foreground="#333333"
                           FontSize="11"/>
            </Border>
            
            <!-- Bottom buttons -->
            <StackPanel Orientation="Horizontal" Margin="0,15,0,0" HorizontalAlignment="Right">
                <Button Content="Settings"
                        Height="35"
                        Width="90"
                        Margin="0,0,10,0"
                        Background="#E1E1E1"
                        Foreground="Black"
                        Name="SettingsButton"/>
                
                <Button Content="Switch to Text Mode (MS-DOS)" 
                        Height="35" 
                        Width="180" 
                        Margin="0,0,10,0" 
                        Background="#FFB900" 
                        Foreground="Black"
                        Name="SwitchToTUIButton"/>
                
                <Button Content="Exit" 
                        Height="35" 
                        Width="80" 
                        Background="#A4373A" 
                        Foreground="White"
                        Name="ExitButton"/>
            </StackPanel>
        </StackPanel>
    </Grid>
</Window>
'@
        
        Log-GUIEvent "WINDOW" "Parsing XAML..."
        
        # Create the window
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        $window = [Windows.Markup.XamlReader]::Load($reader)
        
        Log-GUIEvent "WINDOW" "✓ Window created successfully"
        
        # Get control references
        $statusText = $window.FindName("StatusText")
        $sysInfoText = $window.FindName("SystemInfoText")
        $exitButton = $window.FindName("ExitButton")
        $switchToTUIButton = $window.FindName("SwitchToTUIButton")
        $repairWindowsButton = $window.FindName("RepairWindowsButton")
        $runSFCButton = $window.FindName("RunSFCButton")
        $checkDiskButton = $window.FindName("CheckDiskButton")
        $repairInstallButton = $window.FindName("RepairInstallButton")
        $localRemediationButton = $window.FindName("LocalRemediationButton")
        $listVolumesButton = $window.FindName("ListVolumesButton")
        $scanDriversButton = $window.FindName("ScanDriversButton")
        $viewBCDButton = $window.FindName("ViewBCDButton")
        $injectDriversButton = $window.FindName("InjectDriversButton")
        $windowsBackupButton = $window.FindName("WindowsBackupButton")
        $viewLogButton = $window.FindName("ViewLogButton")
        $bootIssueMappingButton = $window.FindName("BootIssueMappingButton")
        $openRemediationGuideButton = $window.FindName("OpenRemediationGuideButton")
        $settingsButton = $window.FindName("SettingsButton")

        # Heartbeat status updates for long-running operations
        $heartbeatTimer = New-Object System.Windows.Threading.DispatcherTimer
        $heartbeatTimer.Interval = [TimeSpan]::FromSeconds(5)
        $heartbeatMessage = $null
        $heartbeatStart = $null
        $heartbeatTimer.Add_Tick({
            if ($statusText -and $heartbeatStart -and $heartbeatMessage) {
                $elapsed = New-TimeSpan -Start $heartbeatStart -End (Get-Date)
                $statusText.Text = "$heartbeatMessage (elapsed: $($elapsed.ToString('hh\:mm\:ss')))"
            }
        })

        function Start-Heartbeat {
            param([string]$Message)
            $script:heartbeatMessage = $Message
            $script:heartbeatStart = Get-Date
            if ($statusText) {
                $statusText.Text = "$Message (elapsed: 00:00:00)"
            }
            if (-not $heartbeatTimer.IsEnabled) {
                $heartbeatTimer.Start()
            }
        }

        function Stop-Heartbeat {
            if ($heartbeatTimer.IsEnabled) {
                $heartbeatTimer.Stop()
            }
            $script:heartbeatMessage = $null
            $script:heartbeatStart = $null
        }

        function Set-StatusSafe {
            param([string]$Message)
            if ($statusText) {
                $statusText.Text = $Message
            }
        }

        function Save-GUIReport {
            param(
                [string]$Prefix,
                [string]$Content
            )
            $reportDir = if ($global:LogPath) { Split-Path $global:LogPath } else { Join-Path $env:TEMP "LOGS_MIRACLEBOOT" }
            if (-not (Test-Path -LiteralPath $reportDir)) {
                $null = New-Item -ItemType Directory -Path $reportDir -Force -ErrorAction SilentlyContinue
            }
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $reportPath = Join-Path $reportDir "${Prefix}_$timestamp.txt"
            $Content | Set-Content -LiteralPath $reportPath -Encoding UTF8 -ErrorAction SilentlyContinue
            return $reportPath
        }

        function Open-ReportInNotepad {
            param([string]$Path)
            if ($Path -and (Test-Path -LiteralPath $Path)) {
                try {
                    & notepad.exe $Path
                } catch {
                    Log-GUIEvent "REPORT" "Failed to open report in Notepad" $_.Exception.Message
                }
            }
        }

        function Open-TextFile {
            param([string]$Path)
            if ($Path -and (Test-Path -LiteralPath $Path)) {
                try {
                    & notepad.exe $Path
                } catch {
                    Log-GUIEvent "DOC" "Failed to open file in Notepad" $_.Exception.Message
                }
            } else {
                Set-StatusSafe "File not found: $Path"
            }
        }

        function Get-SelectedDriveForOperation {
            param(
                [string]$OperationName,
                [string]$FallbackDrive = $env:SystemDrive.TrimEnd(':')
            )
            
            if (Get-Command Select-OperationDrive -ErrorAction SilentlyContinue) {
                $defaultDrive = if (Get-Command Get-DefaultDrive -ErrorAction SilentlyContinue) { Get-DefaultDrive } else { $null }
                $allowOverride = if (Get-Command Get-AllowDriveOverride -ErrorAction SilentlyContinue) { Get-AllowDriveOverride } else { $true }
                $suppressWarnings = if (Get-Command Get-SuppressWarnings -ErrorAction SilentlyContinue) { Get-SuppressWarnings } else { $false }
                
                $selected = Select-OperationDrive -OperationName $OperationName -DefaultDrive $defaultDrive `
                    -AllowOverride $allowOverride -SuppressWarnings $suppressWarnings
                
                if ($selected -and (Get-Command Set-Setting -ErrorAction SilentlyContinue)) {
                    Set-Setting -Name "LastUsedDrive" -Value $selected | Out-Null
                }
                
                return $selected
            }
            
            return $FallbackDrive
        }

        function Show-LocalRemediationDialog {
            $dialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Local Remediation (No MDM)"
        Height="520" Width="620"
        WindowStartupLocation="CenterScreen"
        Background="#F0F0F0"
        FontFamily="Segoe UI"
        FontSize="11">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="Select the steps to run (admin required)." Margin="0,0,0,10" FontWeight="Bold"/>

        <StackPanel Grid.Row="1">
            <CheckBox Name="Step1ResetWU" Content="Step 1 - Reset servicing stack and update plumbing" Margin="0,0,0,6" IsChecked="True"/>
            <CheckBox Name="Step2Dism" Content="Step 2 - DISM RestoreHealth" Margin="0,0,0,6" IsChecked="True"/>
            <CheckBox Name="Step2Source" Content="Use DISM /Source (if Windows Update is broken)" Margin="18,0,0,6"/>
            <StackPanel Orientation="Horizontal" Margin="36,0,0,8">
                <TextBlock Text="WIM path:" VerticalAlignment="Center"/>
                <TextBox Name="SourcePath" Width="320" Margin="6,0,6,0"/>
                <TextBlock Text="Index:" VerticalAlignment="Center"/>
                <TextBox Name="SourceIndex" Width="40" Text="1" Margin="6,0,0,0"/>
            </StackPanel>
            <CheckBox Name="Step3AppX" Content="Step 3 - AppX re-registration (Start/Menu/Settings fixes)" Margin="0,0,0,6" IsChecked="True"/>
            <CheckBox Name="Step4Sfc" Content="Step 4 - SFC /scannow (after DISM)" Margin="0,0,0,6" IsChecked="True"/>
            <CheckBox Name="Step5ClearSetup" Content="Step 5 - Clear setup blockers (panther, $WINDOWS.~BT, $WINDOWS.~WS)" Margin="0,0,0,6"/>
            <CheckBox Name="Step6Setup" Content="Step 6 - Run in-place upgrade (setup.exe)" Margin="0,0,0,6"/>
            <StackPanel Orientation="Horizontal" Margin="18,0,0,0">
                <TextBlock Text="setup.exe path:" VerticalAlignment="Center"/>
                <TextBox Name="SetupPath" Width="320" Margin="6,0,6,0"/>
                <Button Name="BrowseSetup" Content="Browse..." Width="70"/>
            </StackPanel>
        </StackPanel>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="RunSelected" Content="Run Selected" Width="110" Margin="0,0,8,0" Background="#107C10" Foreground="White"/>
            <Button Name="Cancel" Content="Cancel" Width="80"/>
        </StackPanel>
    </Grid>
</Window>
'@
            $reader = New-Object System.Xml.XmlNodeReader ([xml]$dialogXaml)
            $dialog = [Windows.Markup.XamlReader]::Load($reader)

            $step1 = $dialog.FindName("Step1ResetWU")
            $step2 = $dialog.FindName("Step2Dism")
            $step2Source = $dialog.FindName("Step2Source")
            $sourcePath = $dialog.FindName("SourcePath")
            $sourceIndex = $dialog.FindName("SourceIndex")
            $step3 = $dialog.FindName("Step3AppX")
            $step4 = $dialog.FindName("Step4Sfc")
            $step5 = $dialog.FindName("Step5ClearSetup")
            $step6 = $dialog.FindName("Step6Setup")
            $setupPath = $dialog.FindName("SetupPath")
            $browseSetup = $dialog.FindName("BrowseSetup")
            $runSelected = $dialog.FindName("RunSelected")
            $cancel = $dialog.FindName("Cancel")

            if ($browseSetup) {
                $browseSetup.Add_Click({
                    try {
                        $openFile = New-Object System.Windows.Forms.OpenFileDialog
                        $openFile.Filter = "setup.exe (setup.exe)|setup.exe|Executable (*.exe)|*.exe"
                        $openFile.Title = "Select setup.exe from mounted ISO"
                        if ($openFile.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                            $setupPath.Text = $openFile.FileName
                        }
                    } catch {
                        Set-StatusSafe "Failed to open file picker: $_"
                    }
                })
            }

            if ($cancel) {
                $cancel.Add_Click({ $dialog.Close() })
            }

            if ($runSelected) {
                $runSelected.Add_Click({
                    $steps = @()
                    if ($step1 -and $step1.IsChecked) { $steps += "ResetWU" }
                    if ($step2 -and $step2.IsChecked) { $steps += "DismRestore" }
                    if ($step3 -and $step3.IsChecked) { $steps += "AppXRegister" }
                    if ($step4 -and $step4.IsChecked) { $steps += "SfcScan" }
                    if ($step5 -and $step5.IsChecked) { $steps += "ClearSetupBlockers" }
                    if ($step6 -and $step6.IsChecked) { $steps += "RunSetup" }

                    if ($steps.Count -eq 0) {
                        Set-StatusSafe "No steps selected."
                        return
                    }

                    $useSource = $false
                    $wimPath = $null
                    $wimIndex = "1"
                    if ($step2Source -and $step2Source.IsChecked) {
                        $useSource = $true
                        $wimPath = $sourcePath.Text
                        $wimIndex = $sourceIndex.Text
                        if (-not $wimPath) {
                            Set-StatusSafe "DISM source selected but WIM path is empty."
                            return
                        }
                    }

                    $setupExe = $null
                    if ($steps -contains "RunSetup") {
                        $setupExe = $setupPath.Text
                        if (-not $setupExe) {
                            Set-StatusSafe "setup.exe path is required for in-place upgrade."
                            return
                        }
                    }

                    $dialog.Close()
                    Invoke-BackgroundAction "LocalRemoteRemediation" "Running local remediation steps" @{
                        Steps = $steps
                        UseSource = $useSource
                        SourceWim = $wimPath
                        SourceIndex = $wimIndex
                        SetupPath = $setupExe
                    }
                })
            }

            $dialog.ShowDialog() | Out-Null
        }

        function Invoke-BackgroundAction {
            param(
                [string]$Action,
                [string]$Description,
                [hashtable]$Params = @{},
                [scriptblock]$OnComplete = $null
            )

            Start-Heartbeat $Description
            Set-StatusSafe "$Description (this may take a while)"
            Log-GUIEvent "ACTION" "Starting: $Description"

            $job = $null
            try {
                $job = Start-Job -ArgumentList $PSScriptRoot, $Action, $Params -ScriptBlock {
                    param($root, $action, $params)
                    $result = @{
                        Success = $true
                        Output = ""
                        Error = ""
                    }
                    try {
                        $core = Join-Path $root "WinRepairCore.ps1"
                        if (Test-Path -LiteralPath $core) {
                            . $core
                        }
                        switch ($action) {
                        "RepairWindows" {
                            $output = & cmd /c "dism /online /cleanup-image /restorehealth" 2>&1
                            $output += "`r`n"
                            $output += & cmd /c "sfc /scannow" 2>&1
                        }
                        "RunSFC" {
                            $output = & cmd /c "sfc /scannow" 2>&1
                        }
                        "CheckDisk" {
                            $drive = if ($params.Drive) { $params.Drive } else { $env:SystemDrive }
                            $output = & cmd /c "echo Y|chkdsk $drive /f" 2>&1
                        }
                        "ListVolumes" {
                            if (Get-Command Get-WindowsVolumes -ErrorAction SilentlyContinue) {
                                $output = Get-WindowsVolumes | Format-Table -AutoSize | Out-String
                            } elseif (Get-Command Get-Volume -ErrorAction SilentlyContinue) {
                                $output = Get-Volume | Format-Table -AutoSize | Out-String
                            } else {
                                $output = "No volume enumeration cmdlets available."
                            }
                        }
                        "ScanDrivers" {
                            if (Get-Command Get-MissingStorageDevices -ErrorAction SilentlyContinue) {
                                $output = Get-MissingStorageDevices | Out-String
                            } elseif (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) {
                                $output = Get-PnpDevice -Class Storage -Status Error | Format-Table -AutoSize | Out-String
                            } else {
                                $output = "No storage driver scanning cmdlets available."
                            }
                        }
                        "ViewBCD" {
                            $output = bcdedit /enum 2>&1 | Out-String
                        }
                        "InjectDrivers" {
                            $drive = $params.Drive
                            $path = $params.Path
                            if (-not $drive -or -not $path) {
                                throw "Target drive or driver path missing."
                            }
                            if (Get-Command Inject-Drivers-Offline -ErrorAction SilentlyContinue) {
                                $output = Inject-Drivers-Offline $drive $path | Out-String
                            } else {
                                $output = "Inject-Drivers-Offline not available."
                            }
                        }
                        "RepairInstallCheck" {
                            $drive = if ($params.TargetDrive) { $params.TargetDrive } else { "C" }
                            $auto = [bool]$params.AutoRepair
                            if (Get-Command Invoke-RepairInstallReadinessCheck -ErrorAction SilentlyContinue) {
                                $output = Invoke-RepairInstallReadinessCheck -TargetDrive $drive -AutoRepair:$auto | Out-String
                            } else {
                                throw "Repair-Install module not available."
                            }
                        }
                        "LocalRemoteRemediation" {
                            $steps = @()
                            if ($params.Steps) {
                                if ($params.Steps -is [Array]) { $steps = $params.Steps } else { $steps = @($params.Steps) }
                            }
                            $useSource = [bool]$params.UseSource
                            $sourceWim = $params.SourceWim
                            $sourceIndex = if ($params.SourceIndex) { $params.SourceIndex } else { "1" }
                            $setupPath = $params.SetupPath

                            $output = ""
                            function Add-Out { param([string]$Line) $script:output += "$Line`r`n" }

                            Add-Out "=== Local Remote Remediation - Started: $(Get-Date) ==="
                            Add-Out "Steps: $($steps -join ', ')"

                            if ($steps -contains "ResetWU") {
                                Add-Out "[Step 1] Reset servicing stack and update plumbing"
                                Add-Out (& cmd /c "net stop wuauserv" 2>&1)
                                Add-Out (& cmd /c "net stop bits" 2>&1)
                                Add-Out (& cmd /c "net stop cryptsvc" 2>&1)
                                Add-Out (& cmd /c "net stop trustedinstaller" 2>&1)

                                $sd = Join-Path $env:windir "SoftwareDistribution"
                                if (Test-Path $sd) {
                                    $sdNew = "$sd.old_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                                    try { Rename-Item -Path $sd -NewName $sdNew -ErrorAction Stop; Add-Out "Renamed $sd -> $sdNew" } catch { Add-Out "Rename failed: $_"; Remove-Item -Recurse -Force -Path $sd -ErrorAction SilentlyContinue }
                                }
                                $cr = Join-Path $env:windir "System32\catroot2"
                                if (Test-Path $cr) {
                                    $crNew = "$cr.old_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                                    try { Rename-Item -Path $cr -NewName $crNew -ErrorAction Stop; Add-Out "Renamed $cr -> $crNew" } catch { Add-Out "Rename failed: $_"; Remove-Item -Recurse -Force -Path $cr -ErrorAction SilentlyContinue }
                                }

                                Add-Out (& cmd /c "net start trustedinstaller" 2>&1)
                                Add-Out (& cmd /c "net start cryptsvc" 2>&1)
                                Add-Out (& cmd /c "net start bits" 2>&1)
                                Add-Out (& cmd /c "net start wuauserv" 2>&1)
                            }

                            if ($steps -contains "DismRestore") {
                                Add-Out "[Step 2] DISM /RestoreHealth"
                                if ($useSource -and $sourceWim) {
                                    $cmd = "DISM /Online /Cleanup-Image /RestoreHealth /Source:wim:${sourceWim}:$sourceIndex /LimitAccess"
                                    Add-Out (& cmd /c $cmd 2>&1)
                                } else {
                                    Add-Out (& cmd /c "DISM /Online /Cleanup-Image /RestoreHealth" 2>&1)
                                }
                            }

                            if ($steps -contains "AppXRegister") {
                                Add-Out "[Step 3] AppX re-registration"
                                try {
                                    Get-AppxPackage -AllUsers | ForEach-Object {
                                        Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"
                                    }
                                    Add-Out "AppX re-registration complete."
                                } catch {
                                    Add-Out "AppX re-registration failed: $_"
                                }
                            }

                            if ($steps -contains "SfcScan") {
                                Add-Out "[Step 4] SFC /scannow"
                                Add-Out (& cmd /c "sfc /scannow" 2>&1)
                            }

                            if ($steps -contains "ClearSetupBlockers") {
                                Add-Out "[Step 5] Clear setup blockers"
                                $paths = @(
                                    "C:\$WINDOWS.~BT",
                                    "C:\$WINDOWS.~WS",
                                    "C:\Windows\Panther",
                                    "C:\Windows\SoftwareDistribution\Download"
                                )
                                foreach ($p in $paths) {
                                    if (Test-Path $p) {
                                        $newName = "$p.old_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                                        try {
                                            Rename-Item -Path $p -NewName $newName -ErrorAction Stop
                                            Add-Out "Renamed $p -> $newName"
                                        } catch {
                                            Add-Out "Rename failed for ${p}: $_"
                                            Remove-Item -Recurse -Force -Path $p -ErrorAction SilentlyContinue
                                            Add-Out "Removed $p"
                                        }
                                    } else {
                                        Add-Out "Not found: $p"
                                    }
                                }
                            }

                            if ($steps -contains "RunSetup") {
                                Add-Out "[Step 6] Run setup.exe (in-place upgrade)"
                                if ($setupPath -and (Test-Path $setupPath)) {
                                    try {
                                        Start-Process -FilePath $setupPath
                                        Add-Out "setup.exe launched: $setupPath"
                                    } catch {
                                        Add-Out "Failed to launch setup.exe: $_"
                                    }
                                } else {
                                    Add-Out "setup.exe path not found or invalid."
                                }
                            }

                            Add-Out "=== Local Remote Remediation - Completed: $(Get-Date) ==="
                        }
                        default {
                            throw "Unknown action: $action"
                        }
                    }
                        $result.Output = $output
                    } catch {
                        $result.Success = $false
                        $result.Error = $_.Exception.Message
                        $result.Output = ($_ | Out-String)
                    }
                    return $result
                }
            } catch {
                Stop-Heartbeat
                Set-StatusSafe "Failed to start background task: $_"
                Log-GUIEvent "ACTION" "ERROR - Failed to start background task" $_.Exception.Message
                return
            }

            $monitor = New-Object System.Windows.Threading.DispatcherTimer
            $monitor.Interval = [TimeSpan]::FromSeconds(1)
            $monitor.Add_Tick({
                if ($job.State -ne 'Running' -and $job.State -ne 'NotStarted') {
                    $monitor.Stop()
                    Stop-Heartbeat

                    $jobResult = $null
                    try {
                        $jobResult = Receive-Job -Job $job -ErrorAction SilentlyContinue
                    } catch {
                        $jobResult = @{
                            Success = $false
                            Output = ""
                            Error = $_.Exception.Message
                        }
                    }
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

                    $reportPath = $null
                    if ($jobResult -and $jobResult.Output) {
                        $reportPath = Save-GUIReport $Action $jobResult.Output
                    }

                    if ($jobResult -and $jobResult.Success) {
                        if ($reportPath) {
                            Set-StatusSafe "$Description completed. Report saved: $reportPath"
                        } else {
                            Set-StatusSafe "$Description completed."
                        }
                        Log-GUIEvent "ACTION" "Completed: $Description" $reportPath
                    } else {
                        Set-StatusSafe "$Description failed. Check log for details."
                        Log-GUIEvent "ACTION" "FAILED: $Description" $($jobResult.Error)
                    }

                    if ($OnComplete) {
                        & $OnComplete $jobResult $reportPath
                    }
                }
            })
            $monitor.Start()
        }
        
        Log-GUIEvent "WINDOW" "Attaching event handlers..."
        
        # Populate system info
        if ($sysInfoText) {
            $envType = if (Get-Command Get-EnvironmentType -ErrorAction SilentlyContinue) { Get-EnvironmentType } else { "FullOS" }
            $psVersion = $PSVersionTable.PSVersion
            $logFile = if (Get-Variable -Name "LogPath" -Scope Global -ErrorAction SilentlyContinue) { $global:LogPath } else { "Not initialized" }
            
            $infoText = @"
PowerShell Version: $psVersion
Environment: $envType
SystemDrive: $env:SystemDrive
Diagnostic Log: $logFile
Current User: $env:USERNAME
Computer: $env:COMPUTERNAME
"@
            $sysInfoText.Text = $infoText
            Log-GUIEvent "WINDOW" "System info populated"
        }
        
        # Exit button
        if ($exitButton) {
            $exitButton.Add_Click({
                Log-GUIEvent "EXIT" "Exit button clicked by user"
                $window.Close()
            })
        }
        
        # Switch to TUI button
        if ($switchToTUIButton) {
            $switchToTUIButton.Add_Click({
                Log-GUIEvent "FALLBACK" "User switched to TUI mode"
                if (Get-Command Write-ToLog -ErrorAction SilentlyContinue) {
                    Write-ToLog "User manually switched from GUI to TUI mode" "INFO"
                }
                $window.Close()
                # Signal fallback to main script
                $global:GUIFallbackToTUI = $true
            })
        }
        
        # View log button
        if ($viewLogButton) {
            $viewLogButton.Add_Click({
                Log-GUIEvent "LOG_VIEW" "User requested log file view"
                
                if (Get-Variable -Name "LogPath" -Scope Global -ErrorAction SilentlyContinue) {
                    $logPath = $global:LogPath
                    if (Test-Path -LiteralPath $logPath) {
                        try {
                            & notepad.exe $logPath
                            Set-StatusSafe "Log file opened in Notepad"
                        } catch {
                            Set-StatusSafe "Failed to open log file: $_"
                            Log-GUIEvent "LOG_VIEW" "ERROR - Failed to open log" $_.Exception.Message
                        }
                    } else {
                        Set-StatusSafe "Log file not found: $logPath"
                    }
                } else {
                    Set-StatusSafe "Log system not initialized"
                }
            })
        }

        if ($bootIssueMappingButton) {
            $bootIssueMappingButton.Add_Click({
                $docPath = Join-Path $PSScriptRoot "DOCUMENTATION\BOOT_ISSUE_MAPPING.md"
                Open-TextFile $docPath
                Log-GUIEvent "DOC" "Opened boot issue mapping guide" $docPath
            })
        }

        if ($openRemediationGuideButton) {
            $openRemediationGuideButton.Add_Click({
                $docPath = Join-Path $PSScriptRoot "DOCUMENTATION\LOCAL_REMOTE_REMEDIATION_GUIDE.md"
                Open-TextFile $docPath
                Log-GUIEvent "DOC" "Opened local remediation guide" $docPath
            })
        }
        
        if ($settingsButton) {
            $settingsButton.Add_Click({
                Log-GUIEvent "SETTINGS" "Settings button clicked"
                Show-SettingsWindow
            })
        }
        
        # Repair Windows button
        if ($repairWindowsButton) {
            $repairWindowsButton.Add_Click({
                Log-GUIEvent "ACTION" "Repair Windows button clicked"
                Write-Host "`nLaunching Windows repair (DISM + SFC) from GUI..." -ForegroundColor Cyan
                Invoke-BackgroundAction "RepairWindows" "Repairing Windows installation (DISM + SFC)"
            })
        }

        if ($runSFCButton) {
            $runSFCButton.Add_Click({
                Log-GUIEvent "ACTION" "Run SFC button clicked"
                Invoke-BackgroundAction "RunSFC" "Running System File Checker (SFC)"
            })
        }

        if ($checkDiskButton) {
            $checkDiskButton.Add_Click({
                Log-GUIEvent "ACTION" "Check Disk button clicked"
                $drive = Get-SelectedDriveForOperation -OperationName "Check Disk (CHKDSK)"
                if (-not $drive) {
                    Set-StatusSafe "Check Disk cancelled."
                    return
                }
                Invoke-BackgroundAction "CheckDisk" "Running Check Disk on $drive`:" @{ Drive = "$drive`:" }
            })
        }

        if ($repairInstallButton) {
            $repairInstallButton.Add_Click({
                Log-GUIEvent "ACTION" "Repair-Install readiness button clicked"
                $drive = Get-SelectedDriveForOperation -OperationName "Repair-Install Readiness Check"
                if (-not $drive) {
                    Set-StatusSafe "Repair-Install readiness check cancelled."
                    return
                }
                Invoke-BackgroundAction "RepairInstallCheck" "Running Repair-Install readiness check on $drive`:" @{ TargetDrive = $drive; AutoRepair = $false }
            })
        }

        if ($localRemediationButton) {
            $localRemediationButton.Add_Click({
                Log-GUIEvent "ACTION" "Local remediation button clicked"
                Show-LocalRemediationDialog
            })
        }

        if ($listVolumesButton) {
            $listVolumesButton.Add_Click({
                Log-GUIEvent "ACTION" "List Windows Volumes button clicked"
                Invoke-BackgroundAction "ListVolumes" "Listing Windows volumes" @{} {
                    param($result, $reportPath)
                    Open-ReportInNotepad $reportPath
                }
            })
        }

        if ($scanDriversButton) {
            $scanDriversButton.Add_Click({
                Log-GUIEvent "ACTION" "Scan Storage Drivers button clicked"
                Invoke-BackgroundAction "ScanDrivers" "Scanning storage drivers" @{} {
                    param($result, $reportPath)
                    Open-ReportInNotepad $reportPath
                }
            })
        }

        if ($viewBCDButton) {
            $viewBCDButton.Add_Click({
                Log-GUIEvent "ACTION" "View BCD button clicked"
                Invoke-BackgroundAction "ViewBCD" "Collecting BCD configuration" @{} {
                    param($result, $reportPath)
                    Open-ReportInNotepad $reportPath
                }
            })
        }

        if ($injectDriversButton) {
            $injectDriversButton.Add_Click({
                Log-GUIEvent "ACTION" "Inject Drivers button clicked"
                try {
                    $targetDrive = Get-SelectedDriveForOperation -OperationName "Offline Driver Injection"
                    if (-not $targetDrive) {
                        Set-StatusSafe "Driver injection cancelled."
                        return
                    }
                    
                    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
                    $folderDialog.Description = "Select folder containing driver files (.inf)"
                    $folderDialog.ShowNewFolderButton = $false
                    $dialogResult = $folderDialog.ShowDialog()
                    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
                        Set-StatusSafe "Driver injection canceled."
                        return
                    }
                    $driverPath = $folderDialog.SelectedPath
                    Invoke-BackgroundAction "InjectDrivers" "Injecting drivers into $targetDrive`:" @{ Drive = $targetDrive; Path = $driverPath }
                } catch {
                    Set-StatusSafe "Failed to start driver injection: $_"
                    Log-GUIEvent "ACTION" "ERROR - Driver injection setup failed" $_.Exception.Message
                }
            })
        }

        if ($windowsBackupButton) {
            $windowsBackupButton.Add_Click({
                Log-GUIEvent "ACTION" "Windows Backup button clicked"
                try {
                    Start-Process "ms-settings:backup"
                    Set-StatusSafe "Opened Windows Backup (file backup only; not a system image)."
                } catch {
                    try {
                        Start-Process "control.exe" "/name Microsoft.BackupAndRestore"
                        Set-StatusSafe "Opened Backup and Restore (Windows 7) (file backup only; not a system image)."
                    } catch {
                        Set-StatusSafe "Failed to open Windows Backup: $_"
                        Log-GUIEvent "ACTION" "ERROR - Windows Backup launch failed" $_.Exception.Message
                    }
                }
            })
        }
        
        Log-GUIEvent "STARTUP" "✓ Event handlers attached, showing window"
        
        # Show window
        $window.ShowDialog() | Out-Null
        
        Log-GUIEvent "SHUTDOWN" "GUI window closed normally"
        
    } catch {
        $errorMsg = $_.Exception.Message
        Log-GUISkip "GUI execution failed" $errorMsg "TUI"
        
        if (Get-Command Write-ErrorLog -ErrorAction SilentlyContinue) {
            Write-ErrorLog "GUI failed to launch" -Exception $_ -Details "Falling back to TUI"
        }
        
        # Set fallback flag
        $global:GUIFallbackToTUI = $true
        
        throw $_
    }
}

# Export function
if ($MyInvocation.MyCommand.Module) {
    Export-ModuleMember -Function Start-GUI
}
