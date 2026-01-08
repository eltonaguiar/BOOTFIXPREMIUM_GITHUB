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
        
        Log-GUIEvent "STARTUP" "Creating main window..."
        
        # Define XAML for the main window
        [xml]$xaml = @"
<Window x:Class="MiracleBoot.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
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
"@
        
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
        $viewLogButton = $window.FindName("ViewLogButton")

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
                            $statusText.Text = "Log file opened in Notepad"
                        } catch {
                            $statusText.Text = "Failed to open log file: $_"
                            Log-GUIEvent "LOG_VIEW" "ERROR - Failed to open log" $_.Exception.Message
                        }
                    } else {
                        $statusText.Text = "Log file not found: $logPath"
                    }
                } else {
                    $statusText.Text = "Log system not initialized"
                }
            })
        }
        
        # Repair Windows button
        if ($repairWindowsButton) {
            $repairWindowsButton.Add_Click({
                Log-GUIEvent "ACTION" "Repair Windows button clicked"
                Start-Heartbeat "Running Repair-Install readiness check"
                Write-Host "`nLaunching Repair-Install Readiness Check from GUI..." -ForegroundColor Cyan
                
                if (Get-Command Invoke-RepairInstallReadinessCheck -ErrorAction SilentlyContinue) {
                    try {
                        $result = Invoke-RepairInstallReadinessCheck -TargetDrive "C" -AutoRepair $false
                        $statusText.Text = "Repair check completed. See log for details."
                        Log-GUIEvent "ACTION" "Repair check completed successfully"
                    } catch {
                        $statusText.Text = "Error during repair check: $_"
                        Log-GUIEvent "ACTION" "ERROR - Repair check failed" $_.Exception.Message
                    } finally {
                        Stop-Heartbeat
                    }
                } else {
                    $statusText.Text = "Repair-Install module not available"
                    Log-GUIEvent "ACTION" "ERROR - Repair-Install module not found"
                    Stop-Heartbeat
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
Export-ModuleMember -Function Start-GUI
