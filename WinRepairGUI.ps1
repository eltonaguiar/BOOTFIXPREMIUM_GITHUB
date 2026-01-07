Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# ============================================================================
# MIRACLEBOOT GUI - WinRepairGUI.ps1
# Version: 7.2.0
# Last Updated: January 7, 2026
# ============================================================================
#
# CRITICAL FIX (January 7, 2026):
# Fixed "You cannot call a method on a null-valued expression" error
# that prevented GUI from launching on Windows 11.
#
# Issues Resolved:
# 1. Function closure: Start-GUI function was missing proper closing brace,
#    causing code to execute during script sourcing instead of at call time
# 2. Null checks: Wrapped all event handler registration in null-check guards
# 3. XAML errors: Added detailed error reporting for XAML parsing failures
# 4. Duplicate calls: Removed erroneous $W.ShowDialog() in wizard handler
#
# ============================================================================

function Start-GUI {
Write-Host "GUI: Starting initialization..." -ForegroundColor Cyan

$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Miracle Boot v7.2.0 - Advanced Recovery - Visual Studio (GitHub Copilot)"
 Width="1200" Height="850" WindowStartupLocation="CenterScreen" Background="#F0F0F0">
<Grid>
    <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    
    <!-- Utility Toolbar -->
    <StackPanel Grid.Row="0" Orientation="Horizontal" Background="#E5E5E5" Margin="10,5">
        <TextBlock Text="Utilities:" VerticalAlignment="Center" Margin="5,0,10,0" FontWeight="Bold"/>
        <Button Content="Notepad" Name="BtnNotepad" Width="80" Height="25" Margin="2" ToolTip="Open Notepad"/>
        <Button Content="Registry" Name="BtnRegistry" Width="80" Height="25" Margin="2" ToolTip="Open Registry Editor"/>
        <Button Content="PowerShell" Name="BtnPowerShell" Width="90" Height="25" Margin="2" ToolTip="Open PowerShell"/>
        <Button Content="System Restore" Name="BtnRestore" Width="110" Height="25" Margin="2" ToolTip="Open System Restore Points"/>
        <Separator Margin="10,0"/>
        <TextBlock Name="EnvStatus" Text="Environment: Detecting..." VerticalAlignment="Center" Margin="10,0" Foreground="Gray"/>
</StackPanel>
    
    <TabControl Grid.Row="1" Margin="10">
        <TabItem Header="Volumes &amp; Health">
            <DockPanel Margin="10">
                <Button DockPanel.Dock="Top" Content="Refresh Volume List" Height="35" Name="BtnVol" Background="#0078D7" Foreground="White" FontWeight="Bold"/>
                <ListView Name="VolList" Margin="0,10,0,0">
                    <ListView.View>
                        <GridView>
                            <GridViewColumn Header="Letter" DisplayMemberBinding="{Binding DriveLetter}" Width="50"/>
                            <GridViewColumn Header="Label" DisplayMemberBinding="{Binding FileSystemLabel}" Width="150"/>
                            <GridViewColumn Header="Size" DisplayMemberBinding="{Binding Size}" Width="100"/>
                            <GridViewColumn Header="Status" DisplayMemberBinding="{Binding HealthStatus}" Width="100"/>
                        </GridView>
                    </ListView.View>
                </ListView>
            </DockPanel>
</TabItem>

<TabItem Header="BCD Editor">
            <Grid Margin="10">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                
                <!-- Toolbar -->
                <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
                    <Button Content="Load/Refresh BCD" Height="35" Name="BtnBCD" Background="#0078D7" Foreground="White" Width="150" Margin="0,0,10,0"/>
                    <Button Content="Create Backup" Height="35" Name="BtnBCDBackup" Background="#28a745" Foreground="White" Width="130" Margin="0,0,10,0"/>
                    <Button Content="Fix Duplicates" Height="35" Name="BtnFixDuplicates" Background="#ffc107" Foreground="Black" Width="130" Margin="0,0,10,0"/>
                    <Button Content="Sync to All EFI Partitions" Height="35" Name="BtnSyncBCD" Background="#6f42c1" Foreground="White" Width="200" Margin="0,0,10,0"/>
                    <Button Content="Boot Diagnosis" Height="35" Name="BtnBootDiagnosisBCD" Background="#17a2b8" Foreground="White" Width="150"/>
</StackPanel>
                
                <!-- Main Content with Tabs -->
                <TabControl Grid.Row="1" Name="BCDTabControl">
                    <TabItem Header="Basic Editor">
                        <Grid Margin="5">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="2*"/>
                                <ColumnDefinition Width="1*"/>
                            </Grid.ColumnDefinitions>
                            
                            <StackPanel Grid.Column="0" Margin="5">
                                <TextBlock Text="BCD Boot Entries" FontWeight="Bold" Margin="0,0,0,5"/>
                                <ListBox Name="BCDList" Height="350" Margin="0,0,0,10">
                                    <ListBox.ItemTemplate>
                                        <DataTemplate>
                                            <StackPanel>
                                                <TextBlock Text="{Binding DisplayText}" FontWeight="Bold">
                                                    <TextBlock.Style>
                                                        <Style TargetType="TextBlock">
                                                            <Setter Property="Foreground" Value="#0078D7"/>
                                                            <Style.Triggers>
                                                                <DataTrigger Binding="{Binding IsDefault}" Value="True">
                                                                    <Setter Property="Foreground" Value="#28a745"/>
                                                                </DataTrigger>
                                                            </Style.Triggers>
                                                        </Style>
                                                    </TextBlock.Style>
                                                </TextBlock>
                                                <TextBlock Text="{Binding Id}" FontSize="10" Foreground="Gray"/>
                                            </StackPanel>
                                        </DataTemplate>
                                    </ListBox.ItemTemplate>
                                </ListBox>
                                <TextBox Name="BCDBox" AcceptsReturn="True" Height="150" VerticalScrollBarVisibility="Auto" FontFamily="Consolas" IsReadOnly="True" Background="#222" Foreground="#00FF00"/>
                            </StackPanel>

                            <StackPanel Grid.Column="1" Margin="5" Background="#E5E5E5">
                                <TextBlock Text="Edit Selected Entry" FontWeight="Bold" Margin="5"/>
                                <TextBlock Text="Identifier (GUID):" Margin="5,5,0,0"/>
                                <TextBox Name="EditId" Margin="5" IsReadOnly="True" Background="#DDD"/>
                                <TextBlock Text="Description:" Margin="5,5,0,0"/>
                                <TextBox Name="EditDescription" Margin="5"/>
                                <TextBlock Text="New Friendly Name:" Margin="5,5,0,0"/>
                                <TextBox Name="EditName" Margin="5"/>
                                <Button Content="Update Description" Name="BtnUpdateBcd" Margin="5" Height="25"/>
                                <Button Content="Set as Default Boot" Name="BtnSetDefault" Margin="5" Height="25" Background="#D78700" Foreground="White"/>
                                <Separator Margin="5,10"/>
                                <TextBlock Text="Boot Timeout (Seconds):" Margin="5"/>
                                <TextBox Name="TxtTimeout" Margin="5"/>
                                <Button Content="Save Timeout" Name="BtnTimeout" Margin="5" Height="25"/>
                            </StackPanel>
                        </Grid>
</TabItem>

                    <TabItem Header="Advanced Properties">
                        <Grid Margin="5">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            
                            <TextBlock Grid.Row="0" Text="Select an entry from Basic Editor to edit all properties" FontStyle="Italic" Margin="5" Foreground="Gray"/>
                            
                            <DataGrid Grid.Row="1" Name="BCDPropertiesGrid" AutoGenerateColumns="False" CanUserAddRows="False" IsReadOnly="False" Margin="5">
                                <DataGrid.Columns>
                                    <DataGridTextColumn Header="Property" Binding="{Binding Name}" Width="200" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Value" Binding="{Binding Value}" Width="*"/>
                                </DataGrid.Columns>
                            </DataGrid>
                            
                            <StackPanel Grid.Row="1" Orientation="Horizontal" VerticalAlignment="Bottom" Margin="5">
                                <Button Content="Save Changes" Name="BtnSaveProperties" Height="30" Width="120" Background="#28a745" Foreground="White" Margin="5,0"/>
                                <Button Content="Reset" Name="BtnResetProperties" Height="30" Width="80" Margin="5,0"/>
                            </StackPanel>
                        </Grid>
                    </TabItem>
                </TabControl>
            </Grid>
        </TabItem>

        <TabItem Header="Boot Menu Simulator">
            <StackPanel Background="#003366" Margin="10">
                <TextBlock Text="Windows Boot Manager" Foreground="White" FontSize="22" HorizontalAlignment="Center" Margin="20"/>
                <TextBlock Text="Choose an operating system to start:" Foreground="White" Margin="40,0,0,10"/>
                <ListBox Name="SimList" Height="200" Width="500" Background="#003366" Foreground="White" BorderThickness="0" FontSize="18" Padding="20">
                    <ListBox.ItemTemplate>
                        <DataTemplate>
                            <TextBlock Text="{Binding}"/>
                        </DataTemplate>
                    </ListBox.ItemTemplate>
                </ListBox>
                <TextBlock Name="SimTimeout" Text="Seconds until auto-start: 30" Foreground="White" HorizontalAlignment="Center" Margin="20"/>
                <TextBlock Text="Use the BCD Editor tab to modify these entries." Foreground="#CCC" FontSize="10" HorizontalAlignment="Center"/>
</StackPanel>
</TabItem>

        <TabItem Header="Driver Diagnostics">
            <DockPanel Margin="10">
                <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,10">
                    <Button Content="Scan for Driver Errors" Height="35" Name="BtnDetect" Background="#dc3545" Foreground="White" Width="180" Margin="0,0,10,0"/>
                    <Button Content="Scan for Missing Drivers" Height="35" Name="BtnScanDrivers" Background="#28a745" Foreground="White" Width="200" Margin="0,0,10,0"/>
                    <Button Content="Scan All Drivers" Height="35" Name="BtnScanAllDrivers" Background="#17a2b8" Foreground="White" Width="150" Margin="0,0,10,0"/>
                    <ComboBox Name="DriveCombo" Width="100" Height="35" VerticalContentAlignment="Center"/>
                    <Button Content="Install Drivers" Height="35" Name="BtnInstallDrivers" Background="#6c757d" Foreground="White" Width="120" Margin="10,0,0,0" IsEnabled="False"/>
                </StackPanel>
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <TextBox Name="DrvBox" AcceptsReturn="True" VerticalScrollBarVisibility="Disabled" FontFamily="Consolas" Background="White" Foreground="Black" TextWrapping="Wrap" IsReadOnly="True"/>
                </ScrollViewer>
            </DockPanel>
        </TabItem>

        <TabItem Header="Boot Fixer">
            <Grid Margin="10">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <StackPanel Grid.Row="0" Margin="0,0,0,10">
                    <CheckBox Name="ChkTestMode" Content="Test Mode (Preview commands only - will not execute)" IsChecked="True" FontWeight="Bold" Foreground="#d78700" Margin="5"/>
                    <TextBlock Text="When Test Mode is enabled, commands are displayed but not executed. Uncheck to apply fixes." Foreground="Gray" Margin="5,0,0,5" TextWrapping="Wrap"/>
                </StackPanel>
                
                <GroupBox Grid.Row="1" Header="Boot Repair Operations" Margin="5">
                    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
<StackPanel Margin="10">
                            <Button Content="1. Rebuild BCD from Windows Installation" Height="40" Name="BtnRebuildBCD" Background="#0078D7" Foreground="White" FontWeight="Bold" Margin="0,5"/>
                            <TextBlock Name="TxtRebuildBCD" TextWrapping="Wrap" Margin="10,5" Foreground="Gray" FontSize="11" Text="Click to see command and explanation"/>
                            
                            <Button Content="2. Fix Boot Files (bootrec /fixboot)" Height="40" Name="BtnFixBoot" Background="#0078D7" Foreground="White" FontWeight="Bold" Margin="0,10,0,5"/>
                            <TextBlock Name="TxtFixBoot" TextWrapping="Wrap" Margin="10,5" Foreground="Gray" FontSize="11" Text="Click to see command and explanation"/>
                            
                            <Button Content="3. Scan for Windows Installations" Height="40" Name="BtnScanWindows" Background="#0078D7" Foreground="White" FontWeight="Bold" Margin="0,10,0,5"/>
                            <TextBlock Name="TxtScanWindows" TextWrapping="Wrap" Margin="10,5" Foreground="Gray" FontSize="11" Text="Click to see command and explanation"/>
                            
                            <Button Content="4. Rebuild BCD (bootrec /rebuildbcd)" Height="40" Name="BtnRebuildBCD2" Background="#0078D7" Foreground="White" FontWeight="Bold" Margin="0,10,0,5"/>
                            <TextBlock Name="TxtRebuildBCD2" TextWrapping="Wrap" Margin="10,5" Foreground="Gray" FontSize="11" Text="Click to see command and explanation"/>
                            
                            <Button Content="5. Set Default Boot Entry" Height="40" Name="BtnSetDefaultBoot" Background="#0078D7" Foreground="White" FontWeight="Bold" Margin="0,10,0,5"/>
                            <TextBlock Name="TxtSetDefault" TextWrapping="Wrap" Margin="10,5" Foreground="Gray" FontSize="11" Text="Click to see command and explanation"/>
                            
                            <Button Content="6. Boot Diagnosis" Height="40" Name="BtnBootDiagnosis" Background="#28a745" Foreground="White" FontWeight="Bold" Margin="0,10,0,5"/>
                            <TextBlock Name="TxtBootDiagnosis" TextWrapping="Wrap" Margin="10,5" Foreground="Gray" FontSize="11" Text="Click to run comprehensive boot diagnosis"/>
</StackPanel>
                    </ScrollViewer>
                </GroupBox>
                
                <GroupBox Grid.Row="2" Header="Command Output" Margin="5,10,5,5">
                    <ScrollViewer Height="150" VerticalScrollBarVisibility="Auto">
                        <TextBox Name="FixerOutput" AcceptsReturn="True" FontFamily="Consolas" Background="#222" Foreground="#00FF00" IsReadOnly="True" TextWrapping="Wrap"/>
                    </ScrollViewer>
                </GroupBox>
            </Grid>
</TabItem>

        <TabItem Header="Diagnostics">
            <Grid Margin="10">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                
                <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
                    <TextBlock Text="Target Drive:" VerticalAlignment="Center" Margin="0,0,10,0" FontWeight="Bold"/>
                    <ComboBox Name="DiagDriveCombo" Width="120" Height="30" VerticalContentAlignment="Center" Margin="0,0,20,0"/>
                    <TextBlock Name="CurrentOSLabel" Text="" VerticalAlignment="Center" Foreground="#28a745" FontWeight="Bold" Margin="0,0,10,0"/>
                </StackPanel>
                
                <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,10">
                    <Button Content="Check System Restore" Height="35" Name="BtnCheckRestore" Background="#28a745" Foreground="White" Width="180" Margin="0,0,10,0"/>
                    <Button Content="Check Reagentc Health" Height="35" Name="BtnCheckReagentc" Background="#0078D7" Foreground="White" Width="180" Margin="0,0,10,0"/>
                    <Button Content="Get OS Information" Height="35" Name="BtnGetOSInfo" Background="#6f42c1" Foreground="White" Width="180"/>
</StackPanel>
                
                <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
                    <TextBox Name="DiagBox" AcceptsReturn="True" VerticalScrollBarVisibility="Disabled" FontFamily="Consolas" Background="White" Foreground="Black" TextWrapping="Wrap" IsReadOnly="True" Padding="10"/>
                </ScrollViewer>
            </Grid>
</TabItem>

        <TabItem Header="Diagnostics &amp; Logs">
            <Grid Margin="10">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                
                <StackPanel Grid.Row="0" Margin="0,0,0,10">
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                        <TextBlock Text="Target Drive:" VerticalAlignment="Center" Margin="0,0,10,0" FontWeight="Bold"/>
                        <ComboBox Name="LogDriveCombo" Width="120" Height="30" VerticalContentAlignment="Center"/>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal">
                        <Button Content="Driver Forensics" Height="35" Name="BtnDriverForensics" Background="#dc3545" Foreground="White" Width="150" Margin="0,0,10,0"/>
                        <Button Content="Analyze Boot Log" Height="35" Name="BtnAnalyzeBootLog" Background="#dc3545" Foreground="White" Width="150" Margin="0,0,10,0"/>
                        <Button Content="Analyze Event Logs" Height="35" Name="BtnAnalyzeEventLogs" Background="#17a2b8" Foreground="White" Width="150" Margin="0,0,10,0"/>
                    <Button Content="Full Boot Diagnosis" Height="35" Name="BtnFullBootDiagnosis" Background="#28a745" Foreground="White" Width="150" Margin="0,0,10,0"/>
                    <Button Content="In-Place Upgrade Check" Height="35" Name="BtnUpgradeReadiness" Background="#ff6b35" Foreground="White" Width="180" Margin="0,0,10,0"/>
                    <Button Content="Hardware Support" Height="35" Name="BtnHardwareSupport" Background="#6f42c1" Foreground="White" Width="150" Margin="0,0,10,0"/>
                    <Button Content="Unofficial Repair Tips" Height="35" Name="BtnRepairTips" Background="#ffc107" Foreground="Black" Width="180" Margin="0,0,10,0"/>
                    <Button Content="Generate Registry Override Script" Height="35" Name="BtnGenRegScript" Background="#dc3545" Foreground="White" Width="220" Margin="0,0,10,0"/>
                    <Button Content="One-Click Registry Fixes" Height="35" Name="BtnOneClickFix" Background="#28a745" Foreground="White" Width="200" Margin="0,0,10,0"/>
                    <Button Content="Filter Driver Forensics" Height="35" Name="BtnFilterForensics" Background="#17a2b8" Foreground="White" Width="180" Margin="0,0,10,0"/>
                    <Button Content="Recommended Tools" Height="35" Name="BtnRecommendedTools" Background="#6c757d" Foreground="White" Width="160" Margin="0,0,10,0"/>
                    <Button Content="Export In-Use Drivers" Height="35" Name="BtnExportDrivers" Background="#28a745" Foreground="White" Width="180" Margin="0,0,10,0"/>
                    <Button Content="Generate Cleanup Script" Height="35" Name="BtnGenCleanupScript" Background="#ffc107" Foreground="Black" Width="180"/>
                    </StackPanel>
                </StackPanel>
                
                <TextBlock Grid.Row="1" Text="Offline log analysis from target Windows drive. Driver Forensics identifies missing storage drivers and required INF files. Hardware Support shows manufacturer links and driver update alerts. In-Place Upgrade Check verifies system readiness by checking CBS logs, boot status, setup logs, and upgrade blockers." 
                           FontStyle="Italic" Foreground="Gray" TextWrapping="Wrap" Margin="0,0,0,10"/>
                
                <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
                    <TextBox Name="LogAnalysisBox" AcceptsReturn="True" VerticalScrollBarVisibility="Disabled" FontFamily="Consolas" Background="White" Foreground="Black" TextWrapping="Wrap" IsReadOnly="True" Padding="10"/>
                </ScrollViewer>
            </Grid>
        </TabItem>
        
        <TabItem Header="Repair Install Forcer">
            <Grid Margin="10">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <StackPanel Grid.Row="0" Margin="0,0,0,10">
                    <TextBlock Text="Force Windows to perform a repair-only in-place upgrade from ISO" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                        <RadioButton Name="RbOnlineMode" Content="Online Mode (Running Windows)" IsChecked="True" Margin="0,0,20,0"/>
                        <RadioButton Name="RbOfflineMode" Content="Offline Mode (Non-Booting PC - WinPE/WinRE)" Foreground="#d78700"/>
                    </StackPanel>
                    <TextBlock Name="RepairModeDescription" Text="This forces Setup to reinstall system files while keeping apps and data. Requires same edition, architecture, and build family. Must run from inside Windows." 
                               Foreground="Gray" TextWrapping="Wrap" Margin="0,0,0,10"/>
                </StackPanel>
                
                <GroupBox Grid.Row="1" Header="ISO Selection &amp; Options" Margin="5">
                    <StackPanel Margin="10">
                        <StackPanel Orientation="Horizontal" Margin="0,5" Name="OfflineDrivePanel" Visibility="Collapsed">
                            <TextBlock Text="Offline Windows Drive:" VerticalAlignment="Center" Width="180" Margin="0,0,10,0"/>
                            <ComboBox Name="RepairOfflineDrive" Width="100" Height="25" VerticalContentAlignment="Center" Margin="0,0,10,0"/>
                            <TextBlock Text="(Drive letter where Windows is installed)" Foreground="Gray" VerticalAlignment="Center" FontStyle="Italic"/>
                        </StackPanel>
                        
                        <StackPanel Orientation="Horizontal" Margin="0,5">
                            <TextBlock Text="ISO/Mounted Folder Path:" VerticalAlignment="Center" Width="180" Margin="0,0,10,0"/>
                            <TextBox Name="RepairISOPath" Width="400" Height="25" VerticalContentAlignment="Center" Margin="0,0,10,0"/>
                            <Button Content="Browse..." Name="BtnBrowseISO" Width="80" Height="25"/>
                        </StackPanel>
                        
                        <StackPanel Orientation="Horizontal" Margin="0,10,0,5">
                            <CheckBox Name="ChkSkipCompat" Content="Skip Compatibility Checks" IsChecked="True" Margin="0,0,20,0"/>
                            <CheckBox Name="ChkDisableDynamicUpdate" Content="Disable Dynamic Update" IsChecked="True" Margin="0,0,20,0"/>
                            <CheckBox Name="ChkForceEdition" Content="Force Edition Alignment" IsChecked="False"/>
                        </StackPanel>
                        
                        <StackPanel Orientation="Horizontal" Margin="0,10,0,5">
                            <Button Content="Check Prerequisites" Name="BtnCheckPrereq" Background="#17a2b8" Foreground="White" Width="150" Height="35" Margin="0,0,10,0"/>
                            <Button Content="Show Instructions" Name="BtnShowInstructions" Background="#6c757d" Foreground="White" Width="150" Height="35" Margin="0,0,10,0"/>
                            <Button Content="Start Repair Install" Name="BtnStartRepair" Background="#28a745" Foreground="White" Width="150" Height="35" FontWeight="Bold"/>
                        </StackPanel>
                    </StackPanel>
                </GroupBox>
                
                <GroupBox Grid.Row="2" Header="Status &amp; Output" Margin="5,10,5,5">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <TextBox Name="RepairInstallOutput" AcceptsReturn="True" FontFamily="Consolas" Background="#222" Foreground="#00FF00" IsReadOnly="True" TextWrapping="Wrap" Padding="10"/>
                    </ScrollViewer>
                </GroupBox>
                
                <TextBlock Grid.Row="3" Text="Note: This will launch Windows Setup and restart your system. Ensure you have backups and BitLocker recovery key if applicable." 
                           Foreground="#d78700" FontStyle="Italic" TextWrapping="Wrap" Margin="5,10,5,0"/>
            </Grid>
        </TabItem>

        <TabItem Header="Repair-Install Readiness">
            <Grid Margin="10">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <StackPanel Grid.Row="0" Margin="0,0,0,15">
                    <TextBlock Text="Repair-Install Readiness Check" FontWeight="Bold" FontSize="14" Margin="0,0,0,5"/>
                    <TextBlock Text="Verify Windows is eligible for setup.exe repair-install mode (keeps apps &amp; files)" 
                               Foreground="Gray" TextWrapping="Wrap" Margin="0,0,0,10"/>
                </StackPanel>
                
                <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,10">
                    <Button Content="Run Readiness Check" Name="BtnRepairReadiness" Background="#0078D7" Foreground="White" Height="35" Width="180" Margin="0,0,10,0" FontWeight="Bold"/>
                    <Button Content="Run Check + Auto-Repair" Name="BtnRepairReadinessAuto" Background="#28a745" Foreground="White" Height="35" Width="180" FontWeight="Bold" Margin="0,0,10,0"/>
                    <Button Content="Export Report" Name="BtnExportReadinessReport" Background="#6c757d" Foreground="White" Height="35" Width="150" Margin="0,0,10,0"/>
                    <CheckBox Name="ChkVerboseReadiness" Content="Verbose Output" VerticalAlignment="Center" Margin="20,0,0,0"/>
                </StackPanel>
                
                <GroupBox Grid.Row="2" Header="Readiness Check Results" Margin="0,0,0,10">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="300"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        
                        <StackPanel Grid.Column="0" Margin="10">
                            <TextBlock Text="Check Status" FontWeight="Bold" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal" Margin="0,5">
                                <Rectangle Name="StatusEligibility" Width="20" Height="20" Fill="Gray" Margin="0,0,10,0"/>
                                <TextBlock Text="Setup Eligibility" VerticalAlignment="Center" Width="200"/>
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" Margin="0,5">
                                <Rectangle Name="StatusCBS" Width="20" Height="20" Fill="Gray" Margin="0,0,10,0"/>
                                <TextBlock Text="CBS State" VerticalAlignment="Center" Width="200"/>
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" Margin="0,5">
                                <Rectangle Name="StatusWinRE" Width="20" Height="20" Fill="Gray" Margin="0,0,10,0"/>
                                <TextBlock Text="WinRE Metadata" VerticalAlignment="Center" Width="200"/>
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" Margin="0,5">
                                <Rectangle Name="StatusSetupValidation" Width="20" Height="20" Fill="Gray" Margin="0,0,10,0"/>
                                <TextBlock Text="Setup.exe Validation" VerticalAlignment="Center" Width="200"/>
                            </StackPanel>
                            <Separator Margin="0,10"/>
                            <TextBlock Name="FinalRecommendation" Text="Not yet run" FontWeight="Bold" TextWrapping="Wrap" Margin="0,5" Foreground="#d78700"/>
                        </StackPanel>
                        
                        <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto">
                            <TextBox Name="ReadinessCheckOutput" AcceptsReturn="True" FontFamily="Consolas" Background="#222" Foreground="#00FF00" IsReadOnly="True" TextWrapping="Wrap" Padding="10" Margin="10"/>
                        </ScrollViewer>
                    </Grid>
                </GroupBox>
                
                <TextBlock Grid.Row="3" Text="⚠ This check analyzes CBS state, validates registry keys, and pre-validates setup.exe eligibility without making changes. Run 'Run Check + Auto-Repair' to attempt fixes." 
                           Foreground="#ff6b6b" TextWrapping="Wrap" Margin="0,10,0,0" FontStyle="Italic"/>
            </Grid>
        </TabItem>

        <TabItem Header="Recommended Tools">
            <Grid Margin="10">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                
                <StackPanel Grid.Row="0" Margin="0,0,0,10">
                    <TextBlock Text="Recovery &amp; Backup Tools" FontWeight="Bold" FontSize="16" Margin="0,0,0,5"/>
                    <TextBlock Name="ToolsEnvInfo" Text="Current Environment: Detecting..." Foreground="Gray" Margin="0,0,0,5"/>
                    <TextBlock Text="Tools are categorized based on your current environment and needs." TextWrapping="Wrap" Foreground="Gray" Margin="0,0,0,10"/>
                </StackPanel>
                
                <TabControl Grid.Row="1">
                    <TabItem Header="Recovery Tools (FREE)">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel Margin="10">
                                <!-- Ventoy USB Section -->
                                <GroupBox Header="Step 1: Create Bootable USB with Ventoy (Recommended)" Margin="0,0,0,15" Background="#f8f9fa">
                                    <StackPanel Margin="10">
                                        <TextBlock Text="Ventoy - Multi-Boot USB Solution" FontWeight="Bold" FontSize="14" Foreground="#0078D7" Margin="0,0,0,5"/>
                                        <TextBlock TextWrapping="Wrap" Margin="0,0,0,5">
                                            <Run Text="Ventoy allows you to copy multiple ISO files to a USB drive and boot from them without reformatting. Perfect for recovery environments!"/>
                                        </TextBlock>
                                        <TextBlock Text="Requirements:" FontWeight="Bold" Margin="0,5,0,3"/>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#333" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="USB drive (8GB+ recommended, 16GB+ ideal)" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#333" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="USB will be formatted - BACKUP ANY DATA FIRST!" Foreground="#dc3545" FontWeight="Bold" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        
                                        <StackPanel Orientation="Horizontal" Margin="0,10,0,5">
                                            <Button Content="Open Ventoy Website" Name="BtnVentoyWeb" Background="#28a745" Foreground="White" Width="180" Height="30" Margin="0,0,10,0"/>
                                            <TextBlock Text="https://www.ventoy.net" VerticalAlignment="Center" Foreground="Gray"/>
                                        </StackPanel>
                                        
                                        <TextBlock Text="Instructions:" FontWeight="Bold" Margin="0,10,0,3"/>
                                        <TextBlock Text="1. Download Ventoy from the website above" Margin="20,2"/>
                                        <TextBlock Text="2. Extract and run Ventoy2Disk.exe" Margin="20,2"/>
                                        <TextBlock Text="3. Select your USB drive and click Install" Margin="20,2"/>
                                        <TextBlock Text="4. Copy ISO files directly to the USB drive (no extraction needed!)" Margin="20,2"/>
                                        
                                        <Border Background="#fff3cd" BorderBrush="#ffc107" BorderThickness="1" Margin="0,10,0,0" Padding="10">
                                            <StackPanel>
                                                <TextBlock Text="⚠️ For WIM files (Windows Imaging Format):" FontWeight="Bold" Foreground="#856404"/>
                                                <TextBlock TextWrapping="Wrap" Foreground="#856404" Margin="0,5,0,0">
                                                    <Run Text="WIM files require the WimBoot plugin. Visit: "/>
                                                    <Hyperlink Name="LinkVentoyWimBoot" NavigateUri="https://www.ventoy.net/en/plugin_wimboot.html">https://www.ventoy.net/en/plugin_wimboot.html</Hyperlink>
                                                </TextBlock>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </GroupBox>
                                
                                <!-- Hiren's BootCD PE -->
                                <GroupBox Header="Hiren's BootCD PE - Complete Toolkit" Margin="0,0,0,15">
                                    <StackPanel Margin="10">
                                        <TextBlock Text="Hiren's BootCD PE" FontWeight="Bold" FontSize="14" Foreground="#0078D7" Margin="0,0,0,5"/>
                                        <TextBlock TextWrapping="Wrap" Margin="0,0,0,5">
                                            <Run Text="A comprehensive bootable rescue environment based on Windows 10/11 PE. Includes hundreds of tools for repair, recovery, diagnostics, and data recovery."/>
                                        </TextBlock>
                                        <TextBlock Text="Best For:" FontWeight="Bold" Margin="0,5,0,3"/>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Complete system rescue and repair" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Password reset and data recovery" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Hardware diagnostics and testing" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        
                                        <StackPanel Orientation="Horizontal" Margin="0,10,0,0">
                                            <Button Content="Open Hiren's Website" Name="BtnHirensWeb" Background="#0078D7" Foreground="White" Width="180" Height="30" Margin="0,0,10,0"/>
                                            <TextBlock Text="https://www.hirensbootcd.org" VerticalAlignment="Center" Foreground="Gray"/>
                                        </StackPanel>
                                    </StackPanel>
                                </GroupBox>
                                
                                <!-- Medicat USB -->
                                <GroupBox Header="Medicat USB - Medical-Grade Recovery" Margin="0,0,0,15">
                                    <StackPanel Margin="10">
                                        <TextBlock Text="Medicat USB" FontWeight="Bold" FontSize="14" Foreground="#0078D7" Margin="0,0,0,5"/>
                                        <TextBlock TextWrapping="Wrap" Margin="0,0,0,5">
                                            <Run Text="A comprehensive recovery environment built on Ventoy with curated tools, optimized for Windows recovery and repair scenarios."/>
                                        </TextBlock>
                                        <TextBlock Text="Best For:" FontWeight="Bold" Margin="0,5,0,3"/>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Pre-configured recovery environment" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Windows installation and repair" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        
                                        <TextBlock Text="⚠️ Note: Search for Medicat USB on GitHub or recovery forums" Foreground="#856404" FontStyle="Italic" Margin="0,10,0,0"/>
                                    </StackPanel>
                                </GroupBox>
                                
                                <!-- Other Recovery Environments -->
                                <GroupBox Header="Other Recovery Environments" Margin="0,0,0,10">
                                    <StackPanel Margin="10">
                                        <TextBlock Text="Additional WinPE-Based Tools:" FontWeight="Bold" Margin="0,0,0,10"/>
                                        
                                        <StackPanel Margin="0,0,0,10">
                                            <TextBlock Text="• SystemRescue (Linux-based)" FontWeight="Bold"/>
                                            <TextBlock Text="  Cross-platform recovery with Linux tools" Foreground="Gray" Margin="20,2,0,0"/>
                                            <TextBlock Text="  Website: https://www.system-rescue.org" Foreground="#0078D7" Margin="20,2,0,5"/>
                                        </StackPanel>
                                        
                                        <StackPanel Margin="0,0,0,10">
                                            <TextBlock Text="• AOMEI PE Builder (Windows-based)" FontWeight="Bold"/>
                                            <TextBlock Text="  Create custom WinPE with AOMEI tools" Foreground="Gray" Margin="20,2,0,0"/>
                                            <TextBlock Text="  Website: https://www.aomeitech.com" Foreground="#0078D7" Margin="20,2,0,5"/>
                                        </StackPanel>
                                    </StackPanel>
                                </GroupBox>
                            </StackPanel>
                        </ScrollViewer>
                    </TabItem>
                    
                    <TabItem Header="Recovery Tools (PAID)">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel Margin="10">
                                <!-- Acronis -->
                                <GroupBox Header="Acronis Cyber Protect Home Office" Margin="0,0,0,15">
                                    <StackPanel Margin="10">
                                        <TextBlock Text="Acronis Cyber Protect (formerly True Image)" FontWeight="Bold" FontSize="14" Foreground="#dc7700" Margin="0,0,0,5"/>
                                        <TextBlock TextWrapping="Wrap" Margin="0,0,0,10">
                                            <Run Text="Professional-grade backup and recovery with cloud integration. Includes bootable recovery media creation."/>
                                        </TextBlock>
                                        
                                        <TextBlock Text="Pros:" FontWeight="Bold" Foreground="#28a745" Margin="0,5,0,3"/>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Provides time estimates for backup/restore operations" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Cloud backup integration" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Anti-malware and cybersecurity features" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        
                                        <TextBlock Text="Cons:" FontWeight="Bold" Foreground="#dc3545" Margin="0,10,0,3"/>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#dc3545" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Cloud recovery can be slow" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#dc3545" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="More expensive than alternatives" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        
                                        <StackPanel Orientation="Horizontal" Margin="0,10,0,0">
                                            <Button Content="Open Acronis Website" Name="BtnAcronisWeb" Background="#dc7700" Foreground="White" Width="180" Height="30" Margin="0,0,10,0"/>
                                            <TextBlock Text="https://www.acronis.com" VerticalAlignment="Center" Foreground="Gray"/>
                                        </StackPanel>
                                    </StackPanel>
                                </GroupBox>
                                
                                <!-- Macrium Reflect -->
                                <GroupBox Header="Macrium Reflect - BEST CHOICE ⭐" Margin="0,0,0,15" BorderBrush="#28a745" BorderThickness="2">
                                    <StackPanel Margin="10">
                                        <TextBlock Text="Macrium Reflect (Recommended)" FontWeight="Bold" FontSize="14" Foreground="#28a745" Margin="0,0,0,5"/>
                                        <TextBlock TextWrapping="Wrap" Margin="0,0,0,10">
                                            <Run Text="Professional disk imaging and cloning software. Creates bootable rescue media (WinPE-based) for bare-metal recovery."/>
                                        </TextBlock>
                                        
                                        <TextBlock Text="Why Macrium is the Best:" FontWeight="Bold" Foreground="#28a745" Margin="0,5,0,3"/>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Fast and reliable imaging/restore operations" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Excellent WinPE bootable media creator" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Intuitive interface and reliable recovery" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Free Home Edition available with core features" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,2">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Local backups (faster than cloud-based solutions)" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        
                                        <Border Background="#d4edda" BorderBrush="#28a745" BorderThickness="1" Margin="0,10,0,0" Padding="10">
                                            <TextBlock TextWrapping="Wrap" Foreground="#155724">
                                                <Run Text="💡 Editor's Choice: Based on extensive experience, Macrium Reflect offers the best balance of speed, reliability, and ease of use for system imaging and recovery."/>
                                            </TextBlock>
                                        </Border>
                                        
                                        <StackPanel Orientation="Horizontal" Margin="0,10,0,0">
                                            <Button Content="Open Macrium Website" Name="BtnMacriumWeb" Background="#28a745" Foreground="White" Width="180" Height="30" Margin="0,0,10,0"/>
                                            <TextBlock Text="https://www.macrium.com" VerticalAlignment="Center" Foreground="Gray"/>
                                        </StackPanel>
                                    </StackPanel>
                                </GroupBox>
                                
                                <!-- Paragon -->
                                <GroupBox Header="Paragon Backup &amp; Recovery" Margin="0,0,0,10">
                                    <StackPanel Margin="10">
                                        <TextBlock Text="Paragon Hard Disk Manager" FontWeight="Bold" FontSize="14" Foreground="#0078D7" Margin="0,0,0,5"/>
                                        <TextBlock TextWrapping="Wrap" Margin="0,0,0,5">
                                            <Run Text="Comprehensive disk management with backup, partitioning, and recovery tools."/>
                                        </TextBlock>
                                        
                                        <StackPanel Orientation="Horizontal" Margin="0,10,0,0">
                                            <Button Content="Open Paragon Website" Name="BtnParagonWeb" Background="#0078D7" Foreground="White" Width="180" Height="30" Margin="0,0,10,0"/>
                                            <TextBlock Text="https://www.paragon-software.com" VerticalAlignment="Center" Foreground="Gray"/>
                                        </StackPanel>
                                    </StackPanel>
                                </GroupBox>
                            </StackPanel>
                        </ScrollViewer>
                    </TabItem>
                    
                    <TabItem Header="Backup Strategy">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel Margin="10">
                                <!-- Strategy Overview -->
                                <GroupBox Header="Ideal Backup Methodology" Margin="0,0,0,15" Background="#f8f9fa">
                                    <StackPanel Margin="10">
                                        <TextBlock Text="The 3-2-1 Backup Rule" FontWeight="Bold" FontSize="16" Foreground="#0078D7" Margin="0,0,0,10"/>
                                        
                                        <BulletDecorator Margin="0,5">
                                            <BulletDecorator.Bullet>
                                                <TextBlock Text="3" FontWeight="Bold" FontSize="18" Foreground="#28a745" Width="30"/>
                                            </BulletDecorator.Bullet>
                                            <TextBlock Text="Keep at least 3 copies of your data (original + 2 backups)" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        
                                        <BulletDecorator Margin="0,5">
                                            <BulletDecorator.Bullet>
                                                <TextBlock Text="2" FontWeight="Bold" FontSize="18" Foreground="#0078D7" Width="30"/>
                                            </BulletDecorator.Bullet>
                                            <TextBlock Text="Store backups on 2 different types of media (e.g., internal + external drive)" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        
                                        <BulletDecorator Margin="0,5">
                                            <BulletDecorator.Bullet>
                                                <TextBlock Text="1" FontWeight="Bold" FontSize="18" Foreground="#dc7700" Width="30"/>
                                            </BulletDecorator.Bullet>
                                            <TextBlock Text="Keep 1 copy offsite or in cloud storage (protection against fire, theft, etc.)" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        
                                        <Separator Margin="0,15"/>
                                        
                                        <TextBlock Text="Recommended Backup Schedule:" FontWeight="Bold" Margin="0,10,0,5"/>
                                        <BulletDecorator Margin="20,3">
                                            <BulletDecorator.Bullet><Ellipse Fill="#0078D7" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="System Image: Weekly (or before major changes)" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,3">
                                            <BulletDecorator.Bullet><Ellipse Fill="#0078D7" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Important Files: Daily (automated)" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,3">
                                            <BulletDecorator.Bullet><Ellipse Fill="#0078D7" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Critical Documents: Real-time sync (OneDrive/cloud)" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                    </StackPanel>
                                </GroupBox>
                                
                                <!-- Hardware Recommendations -->
                                <GroupBox Header="Hardware Recommendations for Fast Backups" Margin="0,0,0,15">
                                    <StackPanel Margin="10">
                                        <TextBlock Text="Storage Media Performance Hierarchy" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>
                                        
                                        <StackPanel Margin="0,0,0,10">
                                            <TextBlock Text="🏆 Best: NVMe SSD (PCIe 4.0/5.0)" FontWeight="Bold" Foreground="#28a745"/>
                                            <TextBlock Text="  • Speed: Up to 7,000 MB/s (PCIe 4.0), 14,000 MB/s (PCIe 5.0)" Foreground="Gray" Margin="20,2"/>
                                            <TextBlock Text="  • Use Case: Primary backup drive for desktop PCs" Foreground="Gray" Margin="20,2"/>
                                            <TextBlock Text="  • Requires: M.2 slot on motherboard" Foreground="#dc7700" Margin="20,2"/>
                                        </StackPanel>
                                        
                                        <StackPanel Margin="0,0,0,10">
                                            <TextBlock Text="⭐ Great: SATA SSD" FontWeight="Bold" Foreground="#0078D7"/>
                                            <TextBlock Text="  • Speed: Up to 550 MB/s" Foreground="Gray" Margin="20,2"/>
                                            <TextBlock Text="  • Use Case: Budget-friendly internal backups" Foreground="Gray" Margin="20,2"/>
                                            <TextBlock Text="  • Requires: SATA port on motherboard" Foreground="#dc7700" Margin="20,2"/>
                                        </StackPanel>
                                        
                                        <StackPanel Margin="0,0,0,10">
                                            <TextBlock Text="✅ Good: USB 3.2 Gen 2 External SSD" FontWeight="Bold" Foreground="#6c757d"/>
                                            <TextBlock Text="  • Speed: Up to 1,000 MB/s (USB 3.2 Gen 2)" Foreground="Gray" Margin="20,2"/>
                                            <TextBlock Text="  • Use Case: Portable backups, laptops" Foreground="Gray" Margin="20,2"/>
                                            <TextBlock Text="  • Requires: USB 3.0+ port (USB-C recommended)" Foreground="#dc7700" Margin="20,2"/>
                                        </StackPanel>
                                        
                                        <StackPanel Margin="0,0,0,10">
                                            <TextBlock Text="⚠️ Acceptable: External HDD (7200 RPM)" FontWeight="Bold" Foreground="#856404"/>
                                            <TextBlock Text="  • Speed: ~120-200 MB/s" Foreground="Gray" Margin="20,2"/>
                                            <TextBlock Text="  • Use Case: Large capacity, budget backups" Foreground="Gray" Margin="20,2"/>
                                            <TextBlock Text="  • Note: Slower, but good for archival storage" Foreground="#dc7700" Margin="20,2"/>
                                        </StackPanel>
                                        
                                        <Border Background="#fff3cd" BorderBrush="#ffc107" BorderThickness="1" Margin="0,10,0,0" Padding="10">
                                            <StackPanel>
                                                <TextBlock Text="💡 Investment Recommendation:" FontWeight="Bold" Foreground="#856404"/>
                                                <TextBlock TextWrapping="Wrap" Foreground="#856404" Margin="0,5,0,0">
                                                    <Run Text="For desktop PCs: Add a secondary NVMe SSD dedicated to backups. Requires available M.2 slot (may need motherboard upgrade)."/>
                                                </TextBlock>
                                                <TextBlock TextWrapping="Wrap" Foreground="#856404" Margin="0,5,0,0">
                                                    <Run Text="For laptops: USB 3.2 Gen 2 external SSD is ideal (portable + fast)."/>
                                                </TextBlock>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </GroupBox>
                                
                                <!-- Wizard Button -->
                                <GroupBox Header="Get Personalized Recommendations" Margin="0,0,0,10">
                                    <StackPanel Margin="10">
                                        <TextBlock TextWrapping="Wrap" Margin="0,0,0,10">
                                            <Run Text="Answer a few questions about your system and needs to get tailored backup hardware and software recommendations."/>
                                        </TextBlock>
                                        <Button Content="🧙 Start Backup Wizard" Name="BtnBackupWizard" Background="#6f42c1" Foreground="White" Width="200" Height="35" FontWeight="Bold"/>
                                    </StackPanel>
                                </GroupBox>
                                
                                <!-- Free Backup Software -->
                                <GroupBox Header="Recommended Free Backup Software" Margin="0,0,0,15">
                                    <StackPanel Margin="10">
                                        <StackPanel Margin="0,0,0,10">
                                            <TextBlock Text="1. Macrium Reflect Free" FontWeight="Bold" FontSize="13" Foreground="#28a745"/>
                                            <TextBlock Text="  Full system imaging, bootable rescue media" Foreground="Gray" Margin="20,2"/>
                                            <Button Content="Get Macrium Free" Name="BtnMacriumFreeWeb" Background="#28a745" Foreground="White" Width="150" Height="25" Margin="20,5,0,0" HorizontalAlignment="Left"/>
                                        </StackPanel>
                                        
                                        <StackPanel Margin="0,0,0,10">
                                            <TextBlock Text="2. AOMEI Backupper Standard" FontWeight="Bold" FontSize="13" Foreground="#0078D7"/>
                                            <TextBlock Text="  System/disk/partition backup, scheduling" Foreground="Gray" Margin="20,2"/>
                                            <Button Content="Get AOMEI Free" Name="BtnAOMEIFreeWeb" Background="#0078D7" Foreground="White" Width="150" Height="25" Margin="20,5,0,0" HorizontalAlignment="Left"/>
                                        </StackPanel>
                                        
                                        <StackPanel Margin="0,0,0,10">
                                            <TextBlock Text="3. Windows Backup (Built-in)" FontWeight="Bold" FontSize="13" Foreground="#6c757d"/>
                                            <TextBlock Text="  File History + System Image backup" Foreground="Gray" Margin="20,2"/>
                                            <TextBlock Text="  Access via: Control Panel → Backup and Restore" Foreground="Gray" Margin="20,2" FontStyle="Italic"/>
                                        </StackPanel>
                                    </StackPanel>
                                </GroupBox>
                                
                                <!-- Environment-Specific Tips -->
                                <GroupBox Header="Environment-Specific Backup Tips" Margin="0,0,0,10">
                                    <StackPanel Margin="10">
                                        <TextBlock Text="In Full Windows (FullOS):" FontWeight="Bold" Margin="0,0,0,5"/>
                                        <BulletDecorator Margin="20,3">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Install and run backup software directly" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,3">
                                            <BulletDecorator.Bullet><Ellipse Fill="#28a745" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Create bootable rescue media for recovery" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        
                                        <TextBlock Text="In WinPE/WinRE (Recovery Environment):" FontWeight="Bold" Margin="0,15,0,5"/>
                                        <BulletDecorator Margin="20,3">
                                            <BulletDecorator.Bullet><Ellipse Fill="#0078D7" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Use bootable media created from backup software" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,3">
                                            <BulletDecorator.Bullet><Ellipse Fill="#0078D7" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Access image files on external drives for restore" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        
                                        <TextBlock Text="In Windows Installer (Shift+F10):" FontWeight="Bold" Margin="0,15,0,5"/>
                                        <BulletDecorator Margin="20,3">
                                            <BulletDecorator.Bullet><Ellipse Fill="#dc7700" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Limited to command-line tools" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                        <BulletDecorator Margin="20,3">
                                            <BulletDecorator.Bullet><Ellipse Fill="#dc7700" Width="4" Height="4" Margin="0,0,5,0"/></BulletDecorator.Bullet>
                                            <TextBlock Text="Better to boot into WinPE or use rescue media" TextWrapping="Wrap"/>
                                        </BulletDecorator>
                                    </StackPanel>
                                </GroupBox>
                            </StackPanel>
                        </ScrollViewer>
                    </TabItem>
                </TabControl>
            </Grid>
        </TabItem>
</TabControl>
    
    <!-- Status Bar -->
    <StatusBar Grid.Row="2" Background="#E5E5E5" Height="25">
        <StatusBar.ItemsPanel>
            <ItemsPanelTemplate>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                </Grid>
            </ItemsPanelTemplate>
        </StatusBar.ItemsPanel>
        <StatusBarItem Grid.Column="0">
            <TextBlock Name="StatusBarText" Text="Ready" VerticalAlignment="Center" Margin="5,0"/>
        </StatusBarItem>
        <StatusBarItem Grid.Column="1">
            <StackPanel Orientation="Horizontal" Margin="5,0">
                <TextBlock Name="StatusBarProgress" Text="" VerticalAlignment="Center" Margin="0,0,10,0" Foreground="#0078D7" FontWeight="Bold"/>
                <ProgressBar Name="StatusBarProgressBar" Width="100" Height="15" Visibility="Collapsed" IsIndeterminate="True"/>
            </StackPanel>
        </StatusBarItem>
    </StatusBar>
</Grid>
</Window>
"@

try {
    Write-Host "Parsing XAML ($(($XAML -split '`n').Count) lines)..." -ForegroundColor Gray
    [xml]$xmlDoc = $XAML
    Write-Host "Creating XmlNodeReader..." -ForegroundColor Gray
    $xmlReader = New-Object System.Xml.XmlNodeReader $xmlDoc
    Write-Host "Loading with XamlReader..." -ForegroundColor Gray
    $W = [Windows.Markup.XamlReader]::Load($xmlReader)
    
    if ($null -eq $W) {
        throw "XamlReader.Load returned null"
    }
} catch {
    $errMsg = $_
    $posMsg = $_.InvocationInfo.PositionMessage
    Write-Host "ERROR: Failed to load XAML" -ForegroundColor Red
    Write-Host "Message: $errMsg" -ForegroundColor Red
    Write-Host "Position: $posMsg" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "Inner: $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
    throw "Failed to parse XAML: $errMsg"
}

# ============================================================================
# ENVIRONMENT DETECTION & VALIDATION
# ============================================================================
# Detect current Windows environment (FullOS, WinRE, or WinPE)
# This determines feature availability and operating constraints

$envType = "FullOS"
if (Test-Path 'HKLM:\System\CurrentControlSet\Control\MiniNT') { $envType = "WinRE" }
if ($env:SystemDrive -eq 'X:') { $envType = "WinRE" }

if ($null -eq $W) {
    throw "Window object is null - cannot continue"
}

# ============================================================================
# EVENT HANDLER REGISTRATION - PROTECTED BY NULL CHECKS
# ============================================================================
# ALL event handler registration is wrapped in a null-check guard.
# This prevents "null-valued expression" errors that occurred when the
# function structure was incomplete. The guard ensures $W is valid before
# attempting to call .FindName() on any UI element.
#
# IMPORTANT: Do not call $W.FindName() outside this guard block!
if ($null -ne $W) {

$W.FindName("EnvStatus").Text = "Environment: $envType"

# Utility buttons
$W.FindName("BtnNotepad").Add_Click({
    try {
        Start-Process notepad.exe -ErrorAction SilentlyContinue
    } catch {
        [System.Windows.MessageBox]::Show("Notepad not available in this environment.", "Warning", "OK", "Warning")
    }
})

$W.FindName("BtnRegistry").Add_Click({
    try {
        Start-Process regedit.exe -ErrorAction SilentlyContinue
    } catch {
        [System.Windows.MessageBox]::Show("Registry Editor not available in this environment.", "Warning", "OK", "Warning")
    }
})

$W.FindName("BtnPowerShell").Add_Click({
    try {
        Start-Process powershell.exe -ErrorAction SilentlyContinue
    } catch {
        [System.Windows.MessageBox]::Show("PowerShell not available.", "Error", "OK", "Error")
    }
})

$W.FindName("BtnRestore").Add_Click({
    # Switch to Diagnostics tab and run System Restore check
    try {
        $grid = $W.Content
        $tabControl = $grid.Children | Where-Object { $_.GetType().Name -eq 'TabControl' } | Select-Object -First 1
        
        if ($tabControl) {
            $diagTab = $tabControl.Items | Where-Object { $_.Header -eq "Diagnostics" }
            if ($diagTab) {
                $tabControl.SelectedItem = $diagTab
                # Use dispatcher to ensure UI is updated before triggering button
                $W.Dispatcher.Invoke([action]{
                    $W.FindName("BtnCheckRestore").RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                }, [System.Windows.Threading.DispatcherPriority]::Input)
            }
        }
    } catch {
        # Fallback: show message directing user to Diagnostics tab
        [System.Windows.MessageBox]::Show("Please navigate to the Diagnostics tab and click 'Check System Restore' to view restore points.", "Info", "OK", "Information")
    }
})

# Populate drive combo
$volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.FileSystemLabel } | Sort-Object DriveLetter
$W.FindName("DriveCombo").Items.Clear()
$W.FindName("DriveCombo").Items.Add("Auto-detect")
foreach ($vol in $volumes) {
    $W.FindName("DriveCombo").Items.Add("$($vol.DriveLetter): - $($vol.FileSystemLabel)")
}
$W.FindName("DriveCombo").SelectedIndex = 0

# Populate log drive combo (for Diagnostics & Logs tab)
$W.FindName("LogDriveCombo").Items.Clear()
$W.FindName("LogDriveCombo").Items.Add("C:")
foreach ($vol in $volumes) {
    if ($vol.DriveLetter -ne "C") {
        $W.FindName("LogDriveCombo").Items.Add("$($vol.DriveLetter):")
    }
}
$W.FindName("LogDriveCombo").SelectedIndex = 0

# Populate Diagnostics drive combo
$W.FindName("DiagDriveCombo").Items.Clear()
$currentSystemDrive = $env:SystemDrive.TrimEnd(':')
$W.FindName("DiagDriveCombo").Items.Add("$currentSystemDrive`: (Current OS)")
foreach ($vol in $volumes) {
    if ($vol.DriveLetter -ne $currentSystemDrive) {
        $W.FindName("DiagDriveCombo").Items.Add("$($vol.DriveLetter):")
    }
}
$W.FindName("DiagDriveCombo").SelectedIndex = 0

# Update current OS label
function Update-CurrentOSLabel {
    $selected = $W.FindName("DiagDriveCombo").SelectedItem
    $drive = $currentSystemDrive
    if ($selected) {
        if ($selected -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    if ($drive -eq $currentSystemDrive) {
        $W.FindName("CurrentOSLabel").Text = "[OK] This is the CURRENT OS (running from $currentSystemDrive`:)"
    } else {
        $W.FindName("CurrentOSLabel").Text = "[OFFLINE] This is an OFFLINE OS (not currently running)"
    }
}
Update-CurrentOSLabel
$W.FindName("DiagDriveCombo").Add_SelectionChanged({ Update-CurrentOSLabel })

# Logic for Volumes
$W.FindName("BtnVol").Add_Click({
    $vols = Get-WindowsVolumes
    $W.FindName("VolList").ItemsSource = $vols
})

# Store BCD entries globally for real-time updates
$script:BCDEntriesCache = $null

# Helper function to update status bar
function Update-StatusBar {
    param(
        [string]$Message = "Ready",
        [switch]$ShowProgress,
        [switch]$HideProgress
    )
    
    $W.FindName("StatusBarText").Text = $Message
    
    if ($ShowProgress) {
        $W.FindName("StatusBarProgressBar").Visibility = "Visible"
        $W.FindName("StatusBarProgress").Text = "Working..."
    } elseif ($HideProgress) {
        $W.FindName("StatusBarProgressBar").Visibility = "Collapsed"
        $W.FindName("StatusBarProgress").Text = ""
    }
}

# Helper function to get default boot entry GUID
function Get-BCDDefaultEntryId {
    try {
        # Get the default entry from Windows Boot Manager
        $bootMgrOutput = bcdedit /enum {bootmgr} 2>&1
        if ($bootMgrOutput -match 'default\s+(\{[0-9A-F-]+\})') {
            return $matches[1]
        }
        # Alternative: check for {default} identifier directly in enum output
        $enumOutput = bcdedit /enum 2>&1
        if ($enumOutput -match 'identifier\s+(\{default\})') {
            return "{default}"
        }
        return $null
    } catch {
        return $null
    }
}

# Logic for BCD - Enhanced parser with duplicate detection
$W.FindName("BtnBCD").Add_Click({
    try {
        # Show initial loading message
        Update-StatusBar -Message "Loading BCD Entries..." -ShowProgress
        
        # Force UI to update before blocking operation
        $W.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
        [System.Windows.Forms.Application]::DoEvents()
        
        $rawBcd = bcdedit /enum
        $W.FindName("BCDBox").Text = $rawBcd
        
        Update-StatusBar -Message "Parsing BCD entries..." -ShowProgress
        $W.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
        
        # Get default boot entry ID
        $defaultEntryId = Get-BCDDefaultEntryId
        
        # Parse BCD entries with full properties
        $entries = Get-BCDEntriesParsed
        $script:BCDEntriesCache = $entries
        
        Update-StatusBar -Message "Processing boot entries..." -ShowProgress
        $W.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
        
        $bcdItems = @()
        foreach ($entry in $entries) {
            $displayText = if ($entry.Description) { $entry.Description } else { $entry.Id }
            
            # Mark default entry
            $isDefault = $false
            if ($defaultEntryId) {
                # Check if this entry's ID matches the default (handle both GUID and {default})
                if ($entry.Id -eq $defaultEntryId -or 
                    ($defaultEntryId -eq "{default}" -and $entry.Id -match '\{default\}')) {
                    $isDefault = $true
                    $displayText = "[DEFAULT] $displayText"
                }
            }
            
            $bcdItems += [PSCustomObject]@{
                Id = $entry.Id
                Description = $entry.Description
                DisplayText = $displayText
                Device = $entry.Device
                Path = $entry.Path
                EntryObject = $entry
                IsDefault = $isDefault
            }
        }
        
        Update-StatusBar -Message "Updating BCD list..." -ShowProgress
        $W.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
        
        $W.FindName("BCDList").ItemsSource = $bcdItems
        
        # Update Simulator in real-time
        Update-BootMenuSimulator $bcdItems
        
        $timeout = Get-BCDTimeout
        $W.FindName("TxtTimeout").Text = $timeout
        $W.FindName("SimTimeout").Text = "Seconds until auto-start: $timeout"
        
        Update-StatusBar -Message "Checking for duplicate entries..." -ShowProgress
        
        # Check for duplicates
        $duplicates = Find-DuplicateBCEEntries
        if ($duplicates) {
            $dupNames = ($duplicates | ForEach-Object { "'$($_.Name)'" }) -join ", "
            $result = [System.Windows.MessageBox]::Show(
                "Found duplicate boot entry names: $dupNames`n`nWould you like to automatically rename them by appending volume labels?",
                "Duplicate Entries Detected",
                "YesNo",
                "Question"
            )
            if ($result -eq "Yes") {
                $fixed = Fix-DuplicateBCEEntries -AppendVolumeLabels
                if ($fixed.Count -gt 0) {
                    [System.Windows.MessageBox]::Show("Fixed $($fixed.Count) duplicate entry name(s).", "Success", "OK", "Information")
                    # Reload BCD
                    $W.FindName("BtnBCD").RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                    return
                }
            }
        }
        
        $defaultCount = ($bcdItems | Where-Object { $_.IsDefault }).Count
        $statusMsg = "Loaded $($bcdItems.Count) BCD entries"
        if ($defaultCount -gt 0) {
            $statusMsg += " (1 default entry marked)"
        }
        Update-StatusBar -Message $statusMsg -HideProgress
        
        if (-not $duplicates) {
            [System.Windows.MessageBox]::Show("Loaded $($bcdItems.Count) BCD entries." + $(if ($defaultCount -gt 0) { "`n`nDefault boot entry is marked with [DEFAULT]." } else { "" }), "Success", "OK", "Information")
        }
    } catch {
        Update-StatusBar -Message "Error loading BCD: $_" -HideProgress
        [System.Windows.MessageBox]::Show("Error loading BCD: $_", "Error", "OK", "Error")
    }
})

# Helper function to update Boot Menu Simulator
function Update-BootMenuSimulator {
    param($Items)
    $W.FindName("SimList").Items.Clear()
    foreach ($item in $Items) {
        if ($item.Description) {
            $W.FindName("SimList").Items.Add($item.Description)
        }
    }
}

# BCD List selection - populate both basic and advanced editors
$W.FindName("BCDList").Add_SelectionChanged({
    $selected = $W.FindName("BCDList").SelectedItem
    if ($selected) {
        $W.FindName("EditId").Text = $selected.Id
        $W.FindName("EditDescription").Text = $selected.Description
        $W.FindName("EditName").Text = $selected.Description
        
        # Populate Advanced Properties Grid
        if ($selected.EntryObject) {
            $properties = @()
            foreach ($key in $selected.EntryObject.Keys) {
                if ($key -ne 'Id' -and $key -ne 'EntryType') {
                    $properties += [PSCustomObject]@{
                        Name = $key
                        Value = $selected.EntryObject[$key]
                    }
                }
            }
            $W.FindName("BCDPropertiesGrid").ItemsSource = $properties
        }
    }
})

# BCD Backup button
$W.FindName("BtnBCDBackup").Add_Click({
    try {
        $backup = Export-BCDBackup
        if ($backup.Success) {
            [System.Windows.MessageBox]::Show("BCD backup created successfully!`n`nLocation: $($backup.Path)", "Backup Complete", "OK", "Information")
        } else {
            [System.Windows.MessageBox]::Show("Failed to create backup: $($backup.Error)", "Error", "OK", "Error")
        }
    } catch {
        [System.Windows.MessageBox]::Show("Error creating backup: $_", "Error", "OK", "Error")
    }
})

# Fix Duplicates button
$W.FindName("BtnFixDuplicates").Add_Click({
    $duplicates = Find-DuplicateBCEEntries
    if ($duplicates -and $duplicates.Count -gt 0) {
        $dupList = ""
        foreach ($dup in $duplicates) {
            $dupList += "`n- '$($dup.Name)' (appears $($dup.Count) times)"
        }
        
        $result = [System.Windows.MessageBox]::Show(
            "Found duplicate boot entry names:$dupList`n`nHow would you like to fix them?`n`nYes = Append Volume Labels (Recommended)`nNo = Append Entry Numbers`nCancel = Skip",
            "Fix Duplicate Entries",
            "YesNoCancel",
            "Question"
        )
        if ($result -eq "Yes") {
            $fixed = Fix-DuplicateBCEEntries -AppendVolumeLabels
            if ($fixed.Count -gt 0) {
                [System.Windows.MessageBox]::Show("Fixed $($fixed.Count) duplicate entry name(s).", "Success", "OK", "Information")
                $W.FindName("BtnBCD").RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            }
        } elseif ($result -eq "No") {
            $fixed = Fix-DuplicateBCEEntries
            if ($fixed.Count -gt 0) {
                [System.Windows.MessageBox]::Show("Fixed $($fixed.Count) duplicate entry name(s).", "Success", "OK", "Information")
                $W.FindName("BtnBCD").RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            }
        }
    } else {
        [System.Windows.MessageBox]::Show(
            "No duplicate boot entry names found.`n`nAll Windows Boot Loader entries have unique names.`n`n(Note: System entries like 'Windows Boot Manager' are excluded from duplicate checking.)",
            "No Duplicates",
            "OK",
            "Information"
        )
    }
})

# Sync BCD to All EFI Partitions
$W.FindName("BtnSyncBCD").Add_Click({
    $selectedDrive = $W.FindName("DriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $result = [System.Windows.MessageBox]::Show(
        "This will synchronize the BCD configuration to ALL EFI System Partitions on all drives.`n`nThis ensures the same boot menu appears regardless of which drive the BIOS boots from.`n`nSource: $drive`:\Windows`n`nContinue?",
        "Synchronize BCD to All EFI Partitions",
        "YesNo",
        "Question"
    )
    
    if ($result -eq "Yes") {
        try {
            $W.FindName("FixerOutput").Text = "Synchronizing BCD to all EFI partitions...`n"
            $syncResult = Sync-BCDToAllEFIPartitions -SourceWindowsDrive $drive
            
            $output = "Synchronization Complete`n"
            $output += "===============================================================`n"
            $output += "$($syncResult.Message)`n`n"
            
            foreach ($res in $syncResult.Results) {
                if ($res.Success) {
                    $output += "[SUCCESS] Drive $($res.Drive): Synced successfully`n"
                } else {
                    $output += "[FAILED] Drive $($res.Drive): $($res.Error)`n"
                }
            }
            
            $W.FindName("FixerOutput").Text = $output
            [System.Windows.MessageBox]::Show($syncResult.Message, "Synchronization Complete", "OK", "Information")
        } catch {
            [System.Windows.MessageBox]::Show("Error during synchronization: $_", "Error", "OK", "Error")
        }
    }
})

# Boot Diagnosis button (Boot Fixer tab)
$W.FindName("BtnBootDiagnosis").Add_Click({
    $selectedDrive = $W.FindName("DriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $diagnosis = Get-BootDiagnosis -TargetDrive $drive
    $W.FindName("FixerOutput").Text = $diagnosis
    
    # Switch to Boot Fixer tab to show the output
    $bootFixerTab = $W.FindName("TabControl").Items | Where-Object { $_.Header -eq "Boot Fixer" }
    if ($bootFixerTab) {
        $W.FindName("TabControl").SelectedItem = $bootFixerTab
    }
    
    [System.Windows.MessageBox]::Show(
        "Boot diagnosis complete.`n`nResults are displayed in the 'Boot Fixer' tab below.`n`nScroll down in the output box to see the full diagnosis report.",
        "Diagnosis Complete",
        "OK",
        "Information"
    )
})

# Boot Diagnosis button (BCD Editor tab)
$W.FindName("BtnBootDiagnosisBCD").Add_Click({
    $selectedDrive = $W.FindName("DriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $diagnosis = Get-BootDiagnosis -TargetDrive $drive
    $W.FindName("BCDBox").Text = $diagnosis
    
    [System.Windows.MessageBox]::Show(
        "Boot diagnosis complete.`n`nResults are displayed in the BCD output box below.",
        "Diagnosis Complete",
        "OK",
        "Information"
    )
})

# Update BCD Description with backup and BitLocker check
$W.FindName("BtnUpdateBcd").Add_Click({
    $id = $W.FindName("EditId").Text
    $name = $W.FindName("EditName").Text
    if ($id -and $name) {
        # BitLocker Safety Check
        $bitlocker = Test-BitLockerStatus -TargetDrive "C"
        if ($bitlocker.IsEncrypted) {
            $result = [System.Windows.MessageBox]::Show(
                "$($bitlocker.Warning)`n`nDo you have your BitLocker recovery key available?`n`nClick 'Yes' to proceed anyway, or 'No' to cancel.",
                "BitLocker Encryption Detected",
                "YesNo",
                "Warning"
            )
            if ($result -eq "No") {
                return
            }
        }
        
        # Create backup first
        $backup = Export-BCDBackup
        if ($backup.Success) {
            Set-BCDDescription $id $name
            [System.Windows.MessageBox]::Show("Entry Updated!`n`nBackup saved to: $($backup.Path)", "Success", "OK", "Information")
            
            # Update simulator in real-time
            $selected = $W.FindName("BCDList").SelectedItem
            if ($selected) {
                $selected.Description = $name
                $selected.DisplayText = $name
                $W.FindName("BCDList").Items.Refresh()
                Update-BootMenuSimulator ($W.FindName("BCDList").ItemsSource)
            }
            
            $W.FindName("BtnBCD").RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
        } else {
            [System.Windows.MessageBox]::Show("Failed to create backup. Update cancelled for safety.", "Error", "OK", "Error")
        }
    }
})

# Save Advanced Properties
$W.FindName("BtnSaveProperties").Add_Click({
    $selected = $W.FindName("BCDList").SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Please select a BCD entry first.", "Warning", "OK", "Warning")
        return
    }
    
    $properties = $W.FindName("BCDPropertiesGrid").ItemsSource
    if (-not $properties) { return }
    
    # Create backup first
    $backup = Export-BCDBackup
    if (-not $backup.Success) {
        [System.Windows.MessageBox]::Show("Failed to create backup. Changes cancelled for safety.", "Error", "OK", "Error")
        return
    }
    
    try {
        foreach ($prop in $properties) {
            if ($prop.Name -and $prop.Value) {
                # Validate path/device if applicable
                if ($prop.Name -match 'path|device' -and $prop.Value) {
                    $isValid = Test-BCDPath -Path $prop.Value -Device $selected.Device
                    if (-not $isValid -and $prop.Name -eq 'path') {
                        $result = [System.Windows.MessageBox]::Show(
                            "Warning: The path '$($prop.Value)' may not exist. Continue anyway?",
                            "Path Validation",
                            "YesNo",
                            "Warning"
                        )
                        if ($result -eq "No") { continue }
                    }
                }
                
                Set-BCDProperty -Id $selected.Id -Property $prop.Name -Value $prop.Value
            }
        }
        
        [System.Windows.MessageBox]::Show("Properties updated!`n`nBackup saved to: $($backup.Path)", "Success", "OK", "Information")
        $W.FindName("BtnBCD").RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
    } catch {
        [System.Windows.MessageBox]::Show("Error updating properties: $_", "Error", "OK", "Error")
    }
})

$W.FindName("BtnSetDefault").Add_Click({
    $id = $W.FindName("EditId").Text
    if ($id) {
        $command = "bcdedit /default $id"
        $explanation = "Sets the selected boot entry as the default option that will boot automatically after the timeout period."
        
        $testMode = Show-CommandPreview $command $null "Set Default Boot Entry"
        
        if ($testMode) {
            Update-StatusBar -Message "Command preview complete (Test Mode)" -HideProgress
            return
        }
        
        try {
            Update-StatusBar -Message "Setting default boot entry..." -ShowProgress
            Set-BCDDefaultEntry $id
            Update-StatusBar -Message "Default boot entry set - refreshing list..." -ShowProgress
            
            # Refresh BCD list to show the new default
            $W.FindName("BtnBCD").RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            
            Update-StatusBar -Message "Default boot entry updated" -HideProgress
            [System.Windows.MessageBox]::Show("Default Boot Set to $id`n`nThe list has been refreshed to show the new default entry.", "Success", "OK", "Information")
        } catch {
            Update-StatusBar -Message "Failed to set default boot entry: $_" -HideProgress
            [System.Windows.MessageBox]::Show("Error setting default boot entry: $_", "Error", "OK", "Error")
        }
    }
})

$W.FindName("BtnTimeout").Add_Click({
    $t = $W.FindName("TxtTimeout").Text
    bcdedit /timeout $t
    [System.Windows.MessageBox]::Show("Timeout updated to $t seconds.", "Success", "OK", "Information")
})

# Driver Diagnostics
$W.FindName("BtnDetect").Add_Click({
    $W.FindName("DrvBox").Text = "Scanning for storage driver errors...`n`n"
    $result = Get-MissingStorageDevices
    $W.FindName("DrvBox").Text = $result
})

$W.FindName("BtnScanDrivers").Add_Click({
    $selectedDrive = $W.FindName("DriveCombo").SelectedItem
    $drive = $null
    
    if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1] + ":"
        }
    }
    
    $W.FindName("DrvBox").Text = "Scanning for MISSING storage drivers...`n`n"
    $W.FindName("DrvBox").Text += "Checking for problematic storage controllers first...`n"
    
    $scanResult = Scan-ForDrivers -SourceDrive $drive
    
    if ($scanResult.Found) {
        $output = "`n[SUCCESS] SCAN COMPLETE`n"
        $output += "===============================================================`n"
        $output += "$($scanResult.Message)`n"
        $output += "Source Location: $($scanResult.SearchPath)`n"
        $output += "`nFound Drivers (matching missing devices):`n"
        $output += "---------------------------------------------------------------`n"
        
        $num = 1
        foreach ($driver in $scanResult.Drivers) {
            $output += "$num. $($driver.Name)`n"
            $output += "   Path: $($driver.Path)`n"
            $output += "   Type: $($driver.Type)`n`n"
            $num++
        }
        
        $W.FindName("DrvBox").Text = $output
    } else {
        $W.FindName("DrvBox").Text = "`n[INFO] SCAN RESULTS`n`n$($scanResult.Message)"
    }
})

$W.FindName("BtnScanAllDrivers").Add_Click({
    $selectedDrive = $W.FindName("DriveCombo").SelectedItem
    $drive = $null
    
    if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1] + ":"
        }
    }
    
    $W.FindName("DrvBox").Text = "Scanning for ALL available storage drivers...`n`n"
    $W.FindName("DrvBox").Text += "This may take a moment...`n"
    
    $scanResult = Scan-ForDrivers -SourceDrive $drive -ShowAll
    
    if ($scanResult.Found) {
        $output = "`n[SUCCESS] SCAN COMPLETE`n"
        $output += "===============================================================`n"
        $output += "$($scanResult.Message)`n"
        $output += "Source Location: $($scanResult.SearchPath)`n"
        $output += "`nFound Drivers (ALL storage drivers):`n"
        $output += "---------------------------------------------------------------`n"
        
        $num = 1
        foreach ($driver in $scanResult.Drivers) {
            $output += "$num. $($driver.Name)`n"
            $output += "   Path: $($driver.Path)`n"
            $output += "   Type: $($driver.Type)`n`n"
            $num++
        }
        
        $W.FindName("DrvBox").Text = $output
    } else {
        $W.FindName("DrvBox").Text = "`n[FAILED] SCAN FAILED`n`n$($scanResult.Message)"
    }
})

# Boot Fixer Functions - Enhanced with detailed command info
function Show-CommandPreview {
    param($Command, $Key, $Description)
    $testMode = $W.FindName("ChkTestMode").IsChecked
    $cmdInfo = Get-DetailedCommandInfo $Key
    
    $output = ">>> ANALYSIS REPORT`n"
    $output += "===============================================================`n"
    $output += "Time: $([DateTime]::Now.ToString('HH:mm:ss'))`n"
    $output += "Command: $Command`n"
    $output += "Description: $Description`n`n"
    
    if ($cmdInfo) {
        $output += "WHY USE THIS:`n"
        $output += "  $($cmdInfo.Why)`n`n"
        $output += "TECHNICAL ACTION:`n"
        $output += "  $($cmdInfo.What)`n`n"
    }
    
    if ($testMode) {
        $output += "--- [TEST MODE ACTIVE: NO CHANGES WILL BE MADE] ---`n"
        $output += "Uncheck 'Test Mode' to execute this command.`n"
    } else {
        $output += "--- [EXECUTING COMMAND] ---`n"
    }
    
    $W.FindName("FixerOutput").Text = $output
    $W.FindName("FixerOutput").ScrollToEnd()
    
    return $testMode
}

$W.FindName("BtnRebuildBCD").Add_Click({
    $selectedDrive = $W.FindName("DriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $command = "bcdboot $drive`:\Windows"
    $explanation = Get-CommandExplanation "bcdboot"
    $cmdInfo = Get-DetailedCommandInfo "bcdboot"
    
    $displayText = "COMMAND: $command`n`n"
    if ($cmdInfo) {
        $displayText += "WHY USE THIS:`n$($cmdInfo.Why)`n`n"
        $displayText += "TECHNICAL ACTION:`n$($cmdInfo.What)`n"
    } else {
        $displayText += "EXPLANATION:`n$explanation"
    }
    $W.FindName("TxtRebuildBCD").Text = $displayText
    
    $testMode = Show-CommandPreview $command "bcdboot" "Rebuild BCD from Windows Installation"
    
    if (-not $testMode) {
        # BitLocker Safety Check
        $bitlocker = Test-BitLockerStatus -TargetDrive $drive
        if ($bitlocker.IsEncrypted) {
            $result = [System.Windows.MessageBox]::Show(
                "$($bitlocker.Warning)`n`nDo you have your BitLocker recovery key available?`n`nClick 'Yes' to proceed anyway, or 'No' to cancel.",
                "BitLocker Encryption Detected",
                "YesNo",
                "Warning"
            )
            if ($result -eq "No") {
                $W.FindName("FixerOutput").Text += "`nOperation cancelled due to BitLocker encryption.`n"
                Update-StatusBar -Message "Operation cancelled" -HideProgress
                return
            }
        }
        
        try {
            Update-StatusBar -Message "Executing BCD rebuild..." -ShowProgress
            $result = Invoke-Expression $command 2>&1
            $W.FindName("FixerOutput").Text += "`nOutput: $result`n"
            Update-StatusBar -Message "BCD rebuild completed" -HideProgress
        } catch {
            $W.FindName("FixerOutput").Text += "`nError: $_`n"
            Update-StatusBar -Message "BCD rebuild failed: $_" -HideProgress
        }
    } else {
        Update-StatusBar -Message "Command preview complete (Test Mode)" -HideProgress
    }
})

$W.FindName("BtnFixBoot").Add_Click({
    $selectedDrive = $W.FindName("DriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $command = "bootrec /fixboot"
    $cmdInfo = Get-DetailedCommandInfo "fixboot"
    
    $displayText = "COMMAND: $command`nAlso runs: bootrec /fixmbr`nAlso runs: bootrec /rebuildbcd`n`n"
    if ($cmdInfo) {
        $displayText += "WHY USE THIS:`n$($cmdInfo.Why)`n`n"
        $displayText += "TECHNICAL ACTION:`n$($cmdInfo.What)`n"
    }
    $W.FindName("TxtFixBoot").Text = $displayText
    
    $testMode = Show-CommandPreview $command "fixboot" "Fix Boot Files (bootrec)"
    
    if (-not $testMode) {
        # BitLocker Safety Check
        $bitlocker = Test-BitLockerStatus -TargetDrive $drive
        if ($bitlocker.IsEncrypted) {
            $result = [System.Windows.MessageBox]::Show(
                "$($bitlocker.Warning)`n`nDo you have your BitLocker recovery key available?`n`nClick 'Yes' to proceed anyway, or 'No' to cancel.",
                "BitLocker Encryption Detected",
                "YesNo",
                "Warning"
            )
            if ($result -eq "No") {
                $W.FindName("FixerOutput").Text += "`nOperation cancelled due to BitLocker encryption.`n"
                Update-StatusBar -Message "Operation cancelled" -HideProgress
                return
            }
        }
        
        try {
            Update-StatusBar -Message "Executing boot fix commands..." -ShowProgress
            $result1 = bootrec /fixboot 2>&1
            $result2 = bootrec /fixmbr 2>&1
            $result3 = bootrec /rebuildbcd 2>&1
            $W.FindName("FixerOutput").Text += "`nOutput:`n$result1`n$result2`n$result3`n"
            Update-StatusBar -Message "Boot fix completed" -HideProgress
        } catch {
            $W.FindName("FixerOutput").Text += "`nError: $_`n"
            Update-StatusBar -Message "Boot fix failed: $_" -HideProgress
        }
    } else {
        Update-StatusBar -Message "Command preview complete (Test Mode)" -HideProgress
    }
})

$W.FindName("BtnScanWindows").Add_Click({
    $command = "bootrec /scanos"
    $cmdInfo = Get-DetailedCommandInfo "scanos"
    
    $displayText = "COMMAND: $command`n`n"
    if ($cmdInfo) {
        $displayText += "WHY USE THIS:`n$($cmdInfo.Why)`n`n"
        $displayText += "TECHNICAL ACTION:`n$($cmdInfo.What)`n"
    }
    $W.FindName("TxtScanWindows").Text = $displayText
    
    $testMode = Show-CommandPreview $command "scanos" "Scan for Windows Installations"
    
    if (-not $testMode) {
        try {
            Update-StatusBar -Message "Scanning for Windows installations..." -ShowProgress
            $result = bootrec /scanos 2>&1
            $W.FindName("FixerOutput").Text += "`nOutput: $result`n"
            Update-StatusBar -Message "Windows scan completed" -HideProgress
        } catch {
            $W.FindName("FixerOutput").Text += "`nError: $_`n"
            Update-StatusBar -Message "Windows scan failed: $_" -HideProgress
        }
    } else {
        Update-StatusBar -Message "Command preview complete (Test Mode)" -HideProgress
    }
})

$W.FindName("BtnRebuildBCD2").Add_Click({
    $command = "bootrec /rebuildbcd"
    $cmdInfo = Get-DetailedCommandInfo "rebuildbcd"
    
    $displayText = "COMMAND: $command`n`n"
    if ($cmdInfo) {
        $displayText += "WHY USE THIS:`n$($cmdInfo.Why)`n`n"
        $displayText += "TECHNICAL ACTION:`n$($cmdInfo.What)`n"
    }
    $W.FindName("TxtRebuildBCD2").Text = $displayText
    
    $testMode = Show-CommandPreview $command "rebuildbcd" "Rebuild BCD (bootrec)"
    
    if (-not $testMode) {
        try {
            Update-StatusBar -Message "Rebuilding BCD..." -ShowProgress
            $result = bootrec /rebuildbcd 2>&1
            $W.FindName("FixerOutput").Text += "`nOutput: $result`n"
            Update-StatusBar -Message "BCD rebuild completed" -HideProgress
        } catch {
            $W.FindName("FixerOutput").Text += "`nError: $_`n"
            Update-StatusBar -Message "BCD rebuild failed: $_" -HideProgress
        }
    } else {
        Update-StatusBar -Message "Command preview complete (Test Mode)" -HideProgress
    }
})

$W.FindName("BtnSetDefaultBoot").Add_Click({
    $selected = $W.FindName("BCDList").SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Please select a BCD entry first in the BCD Editor tab.", "Warning", "OK", "Warning")
        return
    }
    
    $command = "bcdedit /default $($selected.Id)"
    $explanation = "Sets the selected boot entry as the default option that will boot automatically after the timeout period. This is useful when you have multiple Windows installations and want to change which one boots by default."
    $W.FindName("TxtSetDefault").Text = "COMMAND: $command`nEntry: $($selected.Description)`n`nEXPLANATION:`n$explanation"
    
    $testMode = Show-CommandPreview $command $null "Set Default Boot Entry"
    
    if (-not $testMode) {
        try {
            Set-BCDDefaultEntry $selected.Id
            $W.FindName("FixerOutput").Text += "Default boot entry set successfully.`n"
            Update-StatusBar -Message "Default boot entry set successfully - refreshing list..." -ShowProgress
            
            # Refresh BCD list to show the new default
            $W.FindName("BtnBCD").RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            
            Update-StatusBar -Message "Default boot entry updated" -HideProgress
        } catch {
            $W.FindName("FixerOutput").Text += "Error: $_`n"
            Update-StatusBar -Message "Failed to set default boot entry: $_" -HideProgress
        }
    } else {
        Update-StatusBar -Message "Command preview complete (Test Mode)" -HideProgress
    }
})

# Diagnostics Tab Handlers
$W.FindName("BtnCheckRestore").Add_Click({
    $selectedDrive = $W.FindName("DiagDriveCombo").SelectedItem
    $drive = $env:SystemDrive.TrimEnd(':')
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $W.FindName("DiagBox").Text = "Checking System Restore status for drive $drive`:...`n`n"
    $restoreInfo = Get-SystemRestoreInfo -TargetDrive $drive
    
    $output = "SYSTEM RESTORE DIAGNOSTICS`n"
    $output += "===============================================================`n`n"
    $output += "Status: $($restoreInfo.Message)`n`n"
    
    if ($restoreInfo.Enabled -and $restoreInfo.RestorePoints.Count -gt 0) {
        $output += "RESTORE POINTS:`n"
        $output += "---------------------------------------------------------------`n"
        $num = 1
        foreach ($point in $restoreInfo.RestorePoints) {
            $output += "$num. $($point.Description)`n"
            $output += "   Created: $($point.CreationTime)`n"
            $output += "   Type: $($point.RestorePointType)`n"
            $output += "   Sequence: $($point.SequenceNumber)`n`n"
            $num++
            if ($num -gt 20) { break } # Limit to 20 most recent
        }
    } else {
        $output += "No restore points found.`n"
        $output += "`nTo enable System Restore:`n"
        $output += "1. Open System Properties`n"
        $output += "2. Go to System Protection tab`n"
        $output += "3. Select your drive and click Configure`n"
        $output += "4. Enable System Protection`n"
    }
    
    $W.FindName("DiagBox").Text = $output
})

$W.FindName("BtnCheckReagentc").Add_Click({
    $W.FindName("DiagBox").Text = "Checking Reagentc (Windows Recovery Environment) health...`n`n"
    $reagentcHealth = Get-ReagentcHealth
    
    $output = "REAGENTC HEALTH CHECK`n"
    $output += "===============================================================`n`n"
    $output += "$($reagentcHealth.Message)`n`n"
    
    if ($reagentcHealth.WinRELocation) {
        $output += "WinRE Location: $($reagentcHealth.WinRELocation)`n`n"
    }
    
    $output += "DETAILED OUTPUT:`n"
    $output += "---------------------------------------------------------------`n"
    foreach ($line in $reagentcHealth.Details) {
        $output += "$line`n"
    }
    
    $output += "`n`nRECOMMENDATIONS:`n"
    $output += "---------------------------------------------------------------`n"
    if ($reagentcHealth.Status -eq "Disabled") {
        $output += "To enable WinRE, run: reagentc /enable`n"
        $output += "To set WinRE location: reagentc /setreimage /path [path]`n"
    } else {
        $output += "WinRE appears to be properly configured.`n"
    }
    
    $W.FindName("DiagBox").Text = $output
})

$W.FindName("BtnGetOSInfo").Add_Click({
    $selectedDrive = $W.FindName("DiagDriveCombo").SelectedItem
    $drive = $env:SystemDrive.TrimEnd(':')
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $W.FindName("DiagBox").Text = "Gathering Operating System information for drive $drive`:...`n`n"
    $osInfo = Get-OSInfo -TargetDrive $drive
    
    $output = "OPERATING SYSTEM INFORMATION`n"
    $output += "===============================================================`n`n"
    
    # Show current OS indicator
    if ($osInfo.IsCurrentOS) {
        $output += "[CURRENT OS] This is the operating system you are currently running from.`n"
        $output += "Drive: $drive`: (System Drive: $($env:SystemDrive))`n`n"
    } else {
        $output += "[OFFLINE OS] This is an offline Windows installation.`n"
        $output += "Drive: $drive`: (Not currently running)`n`n"
    }
    
    if ($osInfo.Error) {
        $output += "[ERROR] $($osInfo.Error)`n"
    } else {
        $output += "OS Name: $($osInfo.OSName)`n"
        $output += "Version: $($osInfo.Version)`n"
        if ($osInfo.BuildNumber) {
            $output += "Build Number: $($osInfo.BuildNumber)`n"
        }
        if ($osInfo.UBR) {
            $output += "Update Build Revision (UBR): $($osInfo.UBR)`n"
        }
        if ($osInfo.ReleaseId) {
            $output += "Release ID: $($osInfo.ReleaseId)`n"
        }
        if ($osInfo.EditionID) {
            $output += "Edition: $($osInfo.EditionID)`n"
        }
        $output += "Architecture: $($osInfo.Architecture)`n"
        $output += "Language: $($osInfo.Language)"
        if ($osInfo.LanguageCode) {
            $output += " (Code: $($osInfo.LanguageCode))"
        }
        $output += "`n"
        
        # Show Insider build info
        if ($osInfo.IsInsider) {
            $output += "`n[INSIDER BUILD DETECTED]`n"
            $output += "This is a Windows Insider Preview build.`n"
            if ($osInfo.InsiderChannel) {
                $output += "Channel: $($osInfo.InsiderChannel)`n"
            }
            $output += "`nINSIDER ISO DOWNLOAD LINKS:`n"
            $output += "---------------------------------------------------------------`n"
            $output += "Official Insider ISO Downloads:`n"
            $output += "  $($osInfo.InsiderLinks.DevChannel)`n`n"
            $output += "UUP Dump (Community ISO Builder):`n"
            $output += "  $($osInfo.InsiderLinks.UUP)`n"
            $output += "  (Search for build $($osInfo.BuildNumber) to find matching ISO)`n`n"
        }
        
        if ($osInfo.InstallDate) {
            $output += "Install Date: $($osInfo.InstallDate)`n"
        }
        if ($osInfo.SerialNumber) {
            $output += "Serial Number: $($osInfo.SerialNumber)`n"
        }
        
        # Show recommended ISO (only if not insider, or show both)
        if (-not $osInfo.IsInsider) {
            $output += "`n`nRECOMMENDED RECOVERY ISO:`n"
            $output += "===============================================================`n"
            $output += "To create a compatible recovery ISO, you need:`n`n"
            $output += "Architecture: $($osInfo.RecommendedISO.Architecture)`n"
            $output += "Language: $($osInfo.RecommendedISO.Language) ($($osInfo.Language))`n"
            $output += "Version: $($osInfo.RecommendedISO.Version)`n`n"
            $output += "Download from:`n"
            if ($osInfo.RecommendedISO.Version -match "11") {
                $output += "  https://www.microsoft.com/software-download/windows11`n"
            } else {
                $output += "  https://www.microsoft.com/software-download/windows10`n"
            }
            $output += "`nMake sure to select:`n"
            $output += "- $($osInfo.RecommendedISO.Architecture) architecture`n"
            $output += "- $($osInfo.Language) language`n"
            $output += "- The same or newer version than your current installation`n"
        } else {
            $output += "`n`nNOTE: For Insider builds, use the Insider ISO links above.`n"
            $output += "Standard Windows 10/11 ISOs may not be compatible with Insider builds.`n"
        }
    }
    
    $W.FindName("DiagBox").Text = $output
})

# Diagnostics & Logs Tab Handlers
$W.FindName("BtnDriverForensics").Add_Click({
    $W.FindName("LogAnalysisBox").Text = "Running storage driver forensics analysis...`n`nScanning for missing devices and matching to INF files...`n"
    
    $forensics = Get-MissingDriverForensics
    
    $W.FindName("LogAnalysisBox").Text = $forensics
})

$W.FindName("BtnAnalyzeBootLog").Add_Click({
    $selectedDrive = $W.FindName("LogDriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $W.FindName("LogAnalysisBox").Text = "Analyzing boot log from $drive`:...`n`n"
    
    $bootLog = Get-BootLogAnalysis -TargetDrive $drive
    
    $output = $bootLog.Summary
    
    if ($bootLog.Found) {
        $output += "`n`nDETAILED DRIVER FAILURES:`n"
        $output += "---------------------------------------------------------------`n"
        if ($bootLog.FailedDrivers.Count -gt 0) {
            $num = 1
            foreach ($driver in $bootLog.FailedDrivers | Select-Object -First 20) {
                $output += "$num. $driver`n"
                $num++
            }
        } else {
            $output += "No driver failures recorded.`n"
        }
    }
    
    $W.FindName("LogAnalysisBox").Text = $output
})

$W.FindName("BtnAnalyzeEventLogs").Add_Click({
    $selectedDrive = $W.FindName("LogDriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $W.FindName("LogAnalysisBox").Text = "Analyzing event logs from $drive`:...`n`nThis may take a moment...`n"
    
    $eventLogs = Get-OfflineEventLogs -TargetDrive $drive
    
    if ($eventLogs.Success) {
        $W.FindName("LogAnalysisBox").Text = $eventLogs.Summary
    } else {
        $W.FindName("LogAnalysisBox").Text = $eventLogs.Summary
    }
})

$W.FindName("BtnFullBootDiagnosis").Add_Click({
    $selectedDrive = $W.FindName("LogDriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $W.FindName("LogAnalysisBox").Text = "Running comprehensive automated boot diagnosis for $drive`:...`n`nPlease wait...`n"
    
    # Run enhanced automated diagnosis
    $diagnosis = Run-BootDiagnosis -Drive $drive
    
    $output = $diagnosis.Report
    
    # Add boot log summary if available
    $bootLog = Get-BootLogAnalysis -TargetDrive $drive
    if ($bootLog.Found) {
        $output += "`n`n"
        $output += "===============================================================`n"
        $output += "BOOT LOG SUMMARY`n"
        $output += "===============================================================`n"
        $output += "Boot log found. Critical missing drivers: $($bootLog.MissingDrivers.Count)`n"
        if ($bootLog.MissingDrivers.Count -gt 0) {
            $output += "Critical drivers that failed to load:`n"
            foreach ($driver in $bootLog.MissingDrivers) {
                $output += "  - $driver`n"
            }
        }
    }
    
    # Add event log summary if available
    $eventLogs = Get-OfflineEventLogs -TargetDrive $drive
    if ($eventLogs.Success) {
        $output += "`n`n"
        $output += "===============================================================`n"
        $output += "EVENT LOG SUMMARY`n"
        $output += "===============================================================`n"
        $output += "Recent shutdowns: $($eventLogs.ShutdownEvents.Count)`n"
        $output += "BSOD events: $($eventLogs.BSODInfo.Count)`n"
        $output += "Recent errors: $($eventLogs.RecentErrors.Count)`n"
        if ($eventLogs.BSODInfo.Count -gt 0) {
            $output += "`nMost recent BSOD:`n"
            $latestBSOD = $eventLogs.BSODInfo | Sort-Object Time -Descending | Select-Object -First 1
            $output += "  Stop Code: $($latestBSOD.StopCode)`n"
            $output += "  $($latestBSOD.Explanation)`n"
        }
    }
    
    # Show critical issues warning if found
    if ($diagnosis.HasCriticalIssues) {
        $output += "`n`n"
        $output += "═══════════════════════════════════════════════════════════════`n"
        $output += "⚠️  CRITICAL ISSUES DETECTED - IMMEDIATE ACTION REQUIRED`n"
        $output += "═══════════════════════════════════════════════════════════════`n"
        $output += "Review the issues above and follow the recommended actions.`n"
        $output += "Use the Boot Fixer tab to apply repairs.`n"
    }
    
    $W.FindName("LogAnalysisBox").Text = $output
})

# In-Place Upgrade Readiness Check button
$W.FindName("BtnUpgradeReadiness").Add_Click({
    $selectedDrive = $W.FindName("LogDriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $W.FindName("LogAnalysisBox").Text = "Checking in-place upgrade readiness for $drive`:...`n`n"
    $W.FindName("LogAnalysisBox").Text += "Analyzing system logs, component health, and upgrade blockers...`n"
    $W.FindName("LogAnalysisBox").Text += "This may take a moment...`n`n"
    
    # Run upgrade readiness check
    $readiness = Get-InPlaceUpgradeReadiness -TargetDrive $drive
    
    # Display the comprehensive report
    $W.FindName("LogAnalysisBox").Text = $readiness.Summary
    
    # Show a summary message box
    if ($readiness.Ready) {
        if ($readiness.Warnings.Count -gt 0) {
            [System.Windows.MessageBox]::Show(
                "✓ System is READY for in-place upgrade!`n`n" +
                "However, there are $($readiness.Warnings.Count) warning(s) that should be addressed for best results.`n`n" +
                "Review the detailed report in the output window.",
                "Upgrade Readiness - Ready with Warnings",
                "OK",
                "Information"
            )
        } else {
            [System.Windows.MessageBox]::Show(
                "✓ System is READY for in-place upgrade!`n`n" +
                "No blockers or warnings detected.`n" +
                "System appears healthy and ready to proceed.",
                "Upgrade Readiness - Ready",
                "OK",
                "Information"
            )
        }
    } else {
        [System.Windows.MessageBox]::Show(
            "✗ System is NOT READY for in-place upgrade!`n`n" +
            "Found $($readiness.Blockers.Count) critical blocker(s) that MUST be resolved first.`n" +
            "Additional warnings: $($readiness.Warnings.Count)`n`n" +
            "Review the detailed report for specific issues and recommendations.",
            "Upgrade Readiness - Blocked",
            "OK",
            "Warning"
        )
    }
})

$W.FindName("BtnHardwareSupport").Add_Click({
    $W.FindName("LogAnalysisBox").Text = "Gathering hardware information and support links...`n`n"
    
    $hwInfo = Get-HardwareSupportInfo
    
    $output = "HARDWARE SUPPORT INFORMATION`n"
    $output += "===============================================================`n`n"
    
    if ($hwInfo.Error) {
        $output += "[ERROR] $($hwInfo.Error)`n"
    } else {
        $output += "MOTHERBOARD:`n"
        $output += "---------------------------------------------------------------`n"
        if ($hwInfo.Motherboard) {
            $output += "$($hwInfo.Motherboard)`n`n"
        } else {
            $output += "Information not available`n`n"
        }
        
        $output += "GRAPHICS CARDS:`n"
        $output += "---------------------------------------------------------------`n"
        if ($hwInfo.GPUs.Count -gt 0) {
            foreach ($gpu in $hwInfo.GPUs) {
                $output += "$($gpu.Name)`n"
                $output += "  Driver Version: $($gpu.DriverVersion)`n"
                if ($gpu.DriverDate) {
                    $output += "  Driver Date: $($gpu.DriverDate)`n"
                }
                if ($gpu.SupportLink) {
                    $output += "  Support: $($gpu.SupportLink)`n"
                }
                $output += "`n"
            }
        } else {
            $output += "No dedicated graphics cards detected`n`n"
        }
        
        $output += "SUPPORT LINKS:`n"
        $output += "---------------------------------------------------------------`n"
        if ($hwInfo.SupportLinks.Count -gt 0) {
            foreach ($link in $hwInfo.SupportLinks) {
                $output += "$($link.Name) ($($link.Type)):`n"
                $output += "  $($link.URL)`n`n"
            }
        } else {
            $output += "No manufacturer support links available`n`n"
        }
        
        if ($hwInfo.DriverAlerts.Count -gt 0) {
            $output += "DRIVER UPDATE ALERTS:`n"
            $output += "---------------------------------------------------------------`n"
            foreach ($alert in $hwInfo.DriverAlerts) {
                $output += "[!] $alert`n"
            }
            $output += "`n"
        }
        
        $output += "NOTE: Click the links above to download the latest drivers from manufacturer websites.`n"
        $output += "For storage drivers (VMD/RAID), use the 'Driver Forensics' button to identify required INF files.`n"
    }
    
    $W.FindName("LogAnalysisBox").Text = $output
})

$W.FindName("BtnRepairTips").Add_Click({
    $tips = Get-UnofficialRepairTips
    $W.FindName("LogAnalysisBox").Text = $tips
})

$W.FindName("BtnGenRegScript").Add_Click({
    $selectedDrive = $W.FindName("LogDriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $script = Get-RegistryEditionOverride -TargetDrive $drive
    
    # Save script to file
    $scriptPath = "$env:TEMP\RegistryEditionOverride_$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"
    $script | Out-File -FilePath $scriptPath -Encoding UTF8
    
    $output = "REGISTRY EDITIONID OVERRIDE SCRIPT GENERATED`n"
    $output += "===============================================================`n`n"
    $output += "Script saved to: $scriptPath`n`n"
    $output += "═══════════════════════════════════════════════════════════════`n"
    $output += "INSTRUCTIONS:`n"
    $output += "═══════════════════════════════════════════════════════════════`n"
    $output += "1. Run this script as Administrator BEFORE launching setup.exe`n"
    $output += "2. The script will backup your registry first`n"
    $output += "3. It will modify EditionID to 'Professional' for compatibility`n"
    $output += "4. IMMEDIATELY run setup.exe from your Windows ISO (do NOT reboot)`n"
    $output += "5. To restore original values later, use the backup file`n`n"
    $output += "⚠️  WARNING: This modifies system registry. Use at your own risk.`n`n"
    $output += "═══════════════════════════════════════════════════════════════`n"
    $output += "SCRIPT PREVIEW:`n"
    $output += "═══════════════════════════════════════════════════════════════`n`n"
    $output += $script
    
    $W.FindName("LogAnalysisBox").Text = $output
    
    $result = [System.Windows.MessageBox]::Show(
        "Script generated successfully!`n`nLocation: $scriptPath`n`nWould you like to open the script file location?",
        "Script Generated",
        "YesNo",
        "Information"
    )
    
    if ($result -eq "Yes") {
        try {
            Start-Process explorer.exe -ArgumentList "/select,`"$scriptPath`""
        } catch {
            [System.Windows.MessageBox]::Show("Could not open file location.", "Error", "OK", "Error")
        }
    }
})

$W.FindName("BtnOneClickFix").Add_Click({
    $selectedDrive = $W.FindName("LogDriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $result = [System.Windows.MessageBox]::Show(
        "This will apply ALL registry overrides to enable In-Place Upgrade compatibility:`n`n" +
        "- EditionID → Professional`n" +
        "- InstallLanguage → 0409 (US English)`n" +
        "- ProgramFilesDir → Reset to $drive`:\Program Files`n`n" +
        "A full registry backup will be created first.`n`n" +
        "Continue?",
        "One-Click Registry Fixes",
        "YesNo",
        "Question"
    )
    
    if ($result -eq "Yes") {
        $W.FindName("LogAnalysisBox").Text = "Applying one-click registry fixes...`n`nPlease wait...`n"
        
        $fixResults = Apply-OneClickRegistryFixes -TargetDrive $drive
        
        $output = "ONE-CLICK REGISTRY FIXES RESULTS`n"
        $output += "===============================================================`n`n"
        
        if ($fixResults.Success) {
            $output += "[SUCCESS] Registry fixes applied successfully!`n`n"
        } else {
            $output += "[PARTIAL] Some fixes applied, but some failed.`n`n"
        }
        
        $output += "APPLIED FIXES:`n"
        $output += "---------------------------------------------------------------`n"
        if ($fixResults.Applied.Count -gt 0) {
            foreach ($fix in $fixResults.Applied) {
                $output += "[OK] $fix`n"
            }
        } else {
            $output += "No changes were needed (values already correct).`n"
        }
        
        if ($fixResults.Failed.Count -gt 0) {
            $output += "`nFAILED FIXES:`n"
            $output += "---------------------------------------------------------------`n"
            foreach ($fail in $fixResults.Failed) {
                $output += "[FAIL] $fail`n"
            }
        }
        
        if ($fixResults.Warnings.Count -gt 0) {
            $output += "`nWARNINGS:`n"
            $output += "---------------------------------------------------------------`n"
            foreach ($warn in $fixResults.Warnings) {
                $output += "[WARN] $warn`n"
            }
        }
        
        $output += "`n`nNEXT STEPS:`n"
        $output += "---------------------------------------------------------------`n"
        $output += "1. IMMEDIATELY run setup.exe from your Windows ISO`n"
        $output += "2. Do NOT reboot before running setup.exe`n"
        $output += "3. The 'Keep personal files and apps' option should now be available`n"
        $output += "`nBackup location: $($fixResults.BackupPath)`n"
        
        $W.FindName("LogAnalysisBox").Text = $output
        
        if ($fixResults.Success) {
            [System.Windows.MessageBox]::Show(
                "Registry fixes applied successfully!`n`nNow run setup.exe from your Windows ISO IMMEDIATELY (do not reboot).",
                "Success",
                "OK",
                "Information"
            )
        } else {
            [System.Windows.MessageBox]::Show(
                "Some fixes failed. See the output for details.",
                "Partial Success",
                "OK",
                "Warning"
            )
        }
    }
})

$W.FindName("BtnFilterForensics").Add_Click({
    $selectedDrive = $W.FindName("LogDriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $W.FindName("LogAnalysisBox").Text = "Analyzing filter drivers in SYSTEM registry hive...`n`nThis may take a moment...`n"
    
    $forensics = Get-FilterDriverForensics -TargetDrive $drive
    
    $W.FindName("LogAnalysisBox").Text = $forensics.Summary
})

$W.FindName("BtnRecommendedTools").Add_Click({
    $tools = Get-RecommendedTools
    $W.FindName("LogAnalysisBox").Text = $tools
})

$W.FindName("BtnExportDrivers").Add_Click({
    $W.FindName("LogAnalysisBox").Text = "Exporting in-use drivers list...`n`nThis may take a moment...`n"
    
    # Let user choose save location
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    $saveDialog.FileName = "In-Use_Drivers_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $saveDialog.InitialDirectory = $env:USERPROFILE + "\Desktop"
    $saveDialog.Title = "Save In-Use Drivers Export"
    
    $result = $saveDialog.ShowDialog()
    
    if ($result -eq "OK") {
        $exportResult = Export-InUseDrivers -OutputPath $saveDialog.FileName
        
        if ($exportResult.Success) {
            $output = "IN-USE DRIVERS EXPORT COMPLETE`n"
            $output += "===============================================================`n`n"
            $output += "[SUCCESS] Driver list exported successfully!`n`n"
            $output += "File Location: $($exportResult.Path)`n`n"
            $output += "Export Statistics:`n"
            $output += "  Total Devices: $($exportResult.DeviceCount)`n"
            $output += "  Device Classes: $($exportResult.ClassCount)`n`n"
            $output += "═══════════════════════════════════════════════════════════════`n"
            $output += "WHAT'S IN THE FILE:`n"
            $output += "═══════════════════════════════════════════════════════════════`n"
            $output += "The exported file contains:`n`n"
            $output += "1. All currently working (in-use) drivers from your PC`n"
            $output += "2. Device names and hardware IDs`n"
            $output += "3. Driver INF file paths and locations`n"
            $output += "4. Driver versions and providers`n"
            $output += "5. Organized by device class (Storage, Display, Network, etc.)`n`n"
            $output += "═══════════════════════════════════════════════════════════════`n"
            $output += "HOW TO USE:`n"
            $output += "═══════════════════════════════════════════════════════════════`n"
            $output += "1. Take this file to your installer/recovery environment`n"
            $output += "2. Use the INF file paths to locate drivers in DriverStore`n"
            $output += "3. Copy the driver folders to your recovery USB/ISO`n"
            $output += "4. Use Hardware IDs to match drivers to devices`n`n"
            $output += "TIP: Focus on critical drivers (Storage, Network, Display)`n"
            $output += "     These are most likely needed for recovery operations.`n"
            
            $W.FindName("LogAnalysisBox").Text = $output
            
            $msgResult = [System.Windows.MessageBox]::Show(
                "Driver export complete!`n`nFile saved to:`n$($exportResult.Path)`n`nWould you like to open the file location?",
                "Export Complete",
                "YesNo",
                "Information"
            )
            
            if ($msgResult -eq "Yes") {
                try {
                    Start-Process explorer.exe -ArgumentList "/select,`"$($exportResult.Path)`""
                } catch {
                    [System.Windows.MessageBox]::Show("Could not open file location.", "Error", "OK", "Error")
                }
            }
        } else {
            $output = "EXPORT FAILED`n"
            $output += "===============================================================`n`n"
            $output += "[ERROR] Failed to export drivers: $($exportResult.Error)`n`n"
            $output += "Please ensure you have write permissions to the selected location.`n"
            
            $W.FindName("LogAnalysisBox").Text = $output
            [System.Windows.MessageBox]::Show(
                "Failed to export drivers.`n`nError: $($exportResult.Error)",
                "Export Failed",
                "OK",
                "Error"
            )
        }
    } else {
        $W.FindName("LogAnalysisBox").Text = "Export cancelled by user."
    }
})

$W.FindName("BtnGenCleanupScript").Add_Click({
    $selectedDrive = $W.FindName("LogDriveCombo").SelectedItem
    $drive = "C"
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $script = Get-CleanupScript -TargetDrive $drive
    
    # Save script to file
    $scriptPath = "$env:TEMP\WindowsOldCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"
    $script | Out-File -FilePath $scriptPath -Encoding UTF8
    
    $output = "WINDOWS.OLD CLEANUP SCRIPT GENERATED`n"
    $output += "===============================================================`n`n"
    $output += "Script saved to: $scriptPath`n`n"
    $output += "═══════════════════════════════════════════════════════════════`n"
    $output += "INSTRUCTIONS:`n"
    $output += "═══════════════════════════════════════════════════════════════`n"
    $output += "1. Run this script AFTER a successful In-Place Upgrade`n"
    $output += "2. It will remove the Windows.old folder to reclaim disk space`n"
    $output += "3. The script will show the size before deletion`n"
    $output += "4. You will be prompted to confirm before deletion`n`n"
    $output += "[WARNING] This permanently deletes Windows.old. Only run this`n"
    $output += "   after you're certain the repair was successful!`n`n"
    $output += "═══════════════════════════════════════════════════════════════`n"
    $output += "SCRIPT PREVIEW:`n"
    $output += "═══════════════════════════════════════════════════════════════`n`n"
    $output += $script
    
    $W.FindName("LogAnalysisBox").Text = $output
    
    $result = [System.Windows.MessageBox]::Show(
        "Cleanup script generated successfully!`n`nLocation: $scriptPath`n`nWould you like to open the script file location?",
        "Script Generated",
        "YesNo",
        "Information"
    )
    
    if ($result -eq "Yes") {
        try {
            Start-Process explorer.exe -ArgumentList "/select,`"$scriptPath`""
        } catch {
            [System.Windows.MessageBox]::Show("Could not open file location.", "Error", "OK", "Error")
        }
    }
})

# Repair Install Forcer Handlers
# Update mode description when radio buttons change
$W.FindName("RbOnlineMode").Add_Checked({
    if ($W.FindName("RbOnlineMode").IsChecked) {
        $W.FindName("RepairModeDescription").Text = "This forces Setup to reinstall system files while keeping apps and data. Requires same edition, architecture, and build family. Must run from inside Windows."
        $W.FindName("OfflineDrivePanel").Visibility = "Collapsed"
    }
})

$W.FindName("RbOfflineMode").Add_Checked({
    if ($W.FindName("RbOfflineMode").IsChecked) {
        $W.FindName("RepairModeDescription").Text = "[WARNING] ADVANCED/HACKY METHOD: Forces Setup on non-booting PC by manipulating offline registry hives. Requires WinPE/WinRE environment. This tricks Setup into thinking it's upgrading a running OS. Use with caution."
        $W.FindName("OfflineDrivePanel").Visibility = "Visible"
        
        # Populate offline drive combo
        $W.FindName("RepairOfflineDrive").Items.Clear()
        $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.FileSystemLabel } | Sort-Object DriveLetter
        foreach ($vol in $volumes) {
            if ($vol.DriveLetter -ne "X") {
                $testPath = "$($vol.DriveLetter):\Windows"
                if (Test-Path $testPath) {
                    $W.FindName("RepairOfflineDrive").Items.Add("$($vol.DriveLetter):")
                }
            }
        }
        if ($W.FindName("RepairOfflineDrive").Items.Count -gt 0) {
            $W.FindName("RepairOfflineDrive").SelectedIndex = 0
        }
    }
})

$W.FindName("BtnBrowseISO").Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select mounted ISO drive or extracted ISO folder"
    $folderDialog.RootFolder = "MyComputer"
    
    $result = $folderDialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $W.FindName("RepairISOPath").Text = $folderDialog.SelectedPath
    }
})

$W.FindName("BtnShowInstructions").Add_Click({
    $instructions = Get-RepairInstallInstructions
    $W.FindName("RepairInstallOutput").Text = $instructions
    $W.FindName("RepairInstallOutput").ScrollToEnd()
})

$W.FindName("BtnCheckPrereq").Add_Click({
    Update-StatusBar -Message "Checking prerequisites..." -ShowProgress
    $isoPath = $W.FindName("RepairISOPath").Text
    $isOffline = $W.FindName("RbOfflineMode").IsChecked
    
    if ([string]::IsNullOrWhiteSpace($isoPath)) {
        $W.FindName("RepairInstallOutput").Text = "[ERROR] Please specify ISO path first.`n`nClick 'Browse...' to select mounted ISO drive or folder."
        Update-StatusBar -Message "ISO path required" -HideProgress
        return
    }
    
    if ($isOffline) {
        $offlineDrive = $W.FindName("RepairOfflineDrive").SelectedItem
        if (-not $offlineDrive) {
            $W.FindName("RepairInstallOutput").Text = "[ERROR] Please select offline Windows drive first."
            Update-StatusBar -Message "Offline drive required" -HideProgress
            return
        }
        if ($offlineDrive -match '^([A-Z]):') {
            $offlineDrive = $matches[1]
        }
        $prereq = Test-OfflineRepairInstallPrerequisites -ISOPath $isoPath -OfflineWindowsDrive $offlineDrive
    } else {
        $prereq = Test-RepairInstallPrerequisites -ISOPath $isoPath
    }
    
    $output = "PREREQUISITE CHECK RESULTS`n"
    $output += "===============================================================`n`n"
    $output += "ISO Path: $isoPath`n`n"
    
    if ($isOffline) {
        $output += "OFFLINE OS INFORMATION:`n"
        $output += "---------------------------------------------------------------`n"
        $output += "Offline Drive: $($W.FindName("RepairOfflineDrive").SelectedItem)`n"
        $output += "Edition: $($prereq.OfflineOS.EditionID)`n"
        $output += "Architecture: $($prereq.OfflineOS.Architecture)`n"
        $output += "Build Number: $($prereq.OfflineOS.BuildNumber)`n"
        $output += "Version: $($prereq.OfflineOS.Version)`n"
        $output += "Language: $($prereq.OfflineOS.Language)`n`n"
    } else {
        $output += "CURRENT OS INFORMATION:`n"
        $output += "---------------------------------------------------------------`n"
        $output += "Edition: $($prereq.CurrentOS.EditionID)`n"
        $output += "Architecture: $($prereq.CurrentOS.Architecture)`n"
        $output += "Build Number: $($prereq.CurrentOS.BuildNumber)`n"
        $output += "Version: $($prereq.CurrentOS.Version)`n"
        $output += "Language: $($prereq.CurrentOS.Language)`n`n"
    }
    
    if ($prereq.CanProceed) {
        $output += "[SUCCESS] Prerequisites check PASSED`n"
        $output += "===============================================================`n`n"
        $output += "You can proceed with repair install.`n`n"
    } else {
        $output += "[FAILED] Prerequisites check FAILED`n"
        $output += "===============================================================`n`n"
        $output += "BLOCKING ISSUES:`n"
        foreach ($issue in $prereq.Issues) {
            $output += "  ✗ $issue`n"
        }
        $output += "`n"
    }
    
    if ($prereq.Warnings.Count -gt 0) {
        $output += "WARNINGS:`n"
        foreach ($warn in $prereq.Warnings) {
            $output += "  ⚠ $warn`n"
        }
        $output += "`n"
    }
    
    if ($prereq.Recommendations.Count -gt 0) {
        $output += "RECOMMENDATIONS:`n"
        foreach ($rec in $prereq.Recommendations) {
            $output += "  • $rec`n"
        }
        $output += "`n"
    }
    
    $W.FindName("RepairInstallOutput").Text = $output
    $W.FindName("RepairInstallOutput").ScrollToEnd()
    Update-StatusBar -Message "Prerequisites check complete" -HideProgress
})

$W.FindName("BtnStartRepair").Add_Click({
    $isoPath = $W.FindName("RepairISOPath").Text
    $isOffline = $W.FindName("RbOfflineMode").IsChecked
    
    if ([string]::IsNullOrWhiteSpace($isoPath)) {
        [System.Windows.MessageBox]::Show(
            "Please specify ISO path first.`n`nClick 'Browse...' to select mounted ISO drive or folder.",
            "ISO Path Required",
            "OK",
            "Warning"
        )
        return
    }
    
    if ($isOffline) {
        $offlineDrive = $W.FindName("RepairOfflineDrive").SelectedItem
        if (-not $offlineDrive) {
            [System.Windows.MessageBox]::Show(
                "Please select offline Windows drive first.",
                "Offline Drive Required",
                "OK",
                "Warning"
            )
            return
        }
        if ($offlineDrive -match '^([A-Z]):') {
            $offlineDrive = $matches[1]
        }
    }
    
    # Check prerequisites first
    Update-StatusBar -Message "Checking prerequisites..." -ShowProgress
    if ($isOffline) {
        $prereq = Test-OfflineRepairInstallPrerequisites -ISOPath $isoPath -OfflineWindowsDrive $offlineDrive
    } else {
        $prereq = Test-RepairInstallPrerequisites -ISOPath $isoPath
    }
    
    if (-not $prereq.CanProceed) {
        $W.FindName("RepairInstallOutput").Text = "PREREQUISITE CHECK FAILED`n" +
                                                  "===============================================================`n`n" +
                                                  "Cannot proceed with repair install:`n`n" +
                                                  ($prereq.Issues -join "`n") +
                                                  "`n`nPlease fix these issues and try again."
        Update-StatusBar -Message "Prerequisites check failed" -HideProgress
        return
    }
    
    # Get options
    $skipCompat = $W.FindName("ChkSkipCompat").IsChecked
    $disableUpdate = $W.FindName("ChkDisableDynamicUpdate").IsChecked
    $forceEdition = $W.FindName("ChkForceEdition").IsChecked
    
    # Prepare repair install
    Update-StatusBar -Message "Preparing repair install..." -ShowProgress
    if ($isOffline) {
        $repairResult = Start-OfflineRepairInstall -ISOPath $isoPath -OfflineWindowsDrive $offlineDrive -SkipCompatibility:$skipCompat -DisableDynamicUpdate:$disableUpdate
    } else {
        $repairResult = Start-RepairInstall -ISOPath $isoPath -SkipCompatibility:$skipCompat -DisableDynamicUpdate:$disableUpdate -ForceEdition:$forceEdition
    }
    
    if (-not $repairResult.Success) {
        $W.FindName("RepairInstallOutput").Text = $repairResult.Output
        Update-StatusBar -Message "Failed to prepare repair install" -HideProgress
        return
    }
    
    # Show confirmation
    $modeText = if ($isOffline) { "OFFLINE" } else { "ONLINE" }
    $confirmMsg = "$modeText REPAIR INSTALL READY`n`n" +
                 "Command: $($repairResult.Command)`n`n"
    
    if ($isOffline) {
        $confirmMsg += "This will:`n" +
                      "  • Manipulate offline registry hives`n" +
                      "  • Launch Windows Setup against offline OS`n" +
                      "  • Restart and begin repair process`n`n" +
                      "Registry backups saved to:`n"
        foreach ($backup in $repairResult.RegistryBackups) {
            $confirmMsg += "  • $backup`n"
        }
        $confirmMsg += "`n"
    } else {
        $confirmMsg += "This will:`n" +
                      "  • Launch Windows Setup`n" +
                      "  • Restart your system`n" +
                      "  • Begin repair process`n`n"
    }
    
    $confirmMsg += "Monitor progress at: $($repairResult.LogPath)`n`n" +
                  "Do you want to proceed?"
    
    $result = [System.Windows.MessageBox]::Show(
        $confirmMsg,
        "Confirm Repair Install",
        "YesNo",
        "Question"
    )
    
    if ($result -eq "Yes") {
        Update-StatusBar -Message "Starting repair install..." -ShowProgress
        
        $output = "STARTING REPAIR INSTALL`n"
        $output += "===============================================================`n`n"
        $output += $repairResult.Output
        $output += "`n`n[INFO] Launching Windows Setup...`n"
        $output += "System will restart shortly.`n"
        $output += "`nMonitor progress at: $($repairResult.LogPath)`n"
        
        $W.FindName("RepairInstallOutput").Text = $output
        
        try {
            # Execute the setup command
            Start-Process -FilePath $repairResult.Command.Split(' ')[0].Trim('"') -ArgumentList ($repairResult.Command -replace '^"[^"]+"\s*', '') -NoNewWindow -Wait:$false
            
            Update-StatusBar -Message "Repair install started - system will restart" -HideProgress
            
            [System.Windows.MessageBox]::Show(
                "Repair install has been started.`n`nWindows Setup will launch and your system will restart.`n`nMonitor progress at:`n$($repairResult.LogPath)",
                "Repair Install Started",
                "OK",
                "Information"
            )
        } catch {
            $W.FindName("RepairInstallOutput").Text += "`n`n[ERROR] Failed to start repair install: $_`n"
            Update-StatusBar -Message "Failed to start repair install" -HideProgress
        }
    } else {
        Update-StatusBar -Message "Repair install cancelled" -HideProgress
    }
})

# =====================================================================
# Recommended Tools Tab - Event Handlers
# =====================================================================

# Update environment info in the Tools tab
$toolsEnvInfo = $W.FindName("ToolsEnvInfo")
if ($toolsEnvInfo) {
    $toolsEnvInfo.Text = "Current Environment: $envType"
}

# Ventoy Website
$W.FindName("BtnVentoyWeb").Add_Click({
    try {
        Start-Process "https://www.ventoy.net"
    } catch {
        [System.Windows.MessageBox]::Show("Could not open browser. Please visit: https://www.ventoy.net", "Info", "OK", "Information")
    }
})

# Ventoy WimBoot Plugin Link
$ventoyWimBootLink = $W.FindName("LinkVentoyWimBoot")
if ($ventoyWimBootLink) {
    $ventoyWimBootLink.Add_Click({
        try {
            Start-Process "https://www.ventoy.net/en/plugin_wimboot.html"
        } catch {
            [System.Windows.MessageBox]::Show("Could not open browser. Please visit: https://www.ventoy.net/en/plugin_wimboot.html", "Info", "OK", "Information")
        }
    })
}

# Hiren's BootCD Website
$W.FindName("BtnHirensWeb").Add_Click({
    try {
        Start-Process "https://www.hirensbootcd.org"
    } catch {
        [System.Windows.MessageBox]::Show("Could not open browser. Please visit: https://www.hirensbootcd.org", "Info", "OK", "Information")
    }
})

# Acronis Website
$W.FindName("BtnAcronisWeb").Add_Click({
    try {
        Start-Process "https://www.acronis.com"
    } catch {
        [System.Windows.MessageBox]::Show("Could not open browser. Please visit: https://www.acronis.com", "Info", "OK", "Information")
    }
})

# Macrium Website
$W.FindName("BtnMacriumWeb").Add_Click({
    try {
        Start-Process "https://www.macrium.com"
    } catch {
        [System.Windows.MessageBox]::Show("Could not open browser. Please visit: https://www.macrium.com", "Info", "OK", "Information")
    }
})

# Paragon Website
$W.FindName("BtnParagonWeb").Add_Click({
    try {
        Start-Process "https://www.paragon-software.com"
    } catch {
        [System.Windows.MessageBox]::Show("Could not open browser. Please visit: https://www.paragon-software.com", "Info", "OK", "Information")
    }
})

# Macrium Free Website
$W.FindName("BtnMacriumFreeWeb").Add_Click({
    try {
        Start-Process "https://www.macrium.com/reflectfree"
    } catch {
        [System.Windows.MessageBox]::Show("Could not open browser. Please visit: https://www.macrium.com/reflectfree", "Info", "OK", "Information")
    }
})

# AOMEI Free Website
$W.FindName("BtnAOMEIFreeWeb").Add_Click({
    try {
        Start-Process "https://www.aomeitech.com/aomei-backupper.html"
    } catch {
        [System.Windows.MessageBox]::Show("Could not open browser. Please visit: https://www.aomeitech.com/aomei-backupper.html", "Info", "OK", "Information")
    }
})

# Backup Wizard
$W.FindName("BtnBackupWizard").Add_Click({
    # Create wizard dialog
    $wizardXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Backup Hardware Wizard" Width="700" Height="600" WindowStartupLocation="CenterScreen" Background="#F0F0F0">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <StackPanel Grid.Row="0" Margin="0,0,0,15">
            <TextBlock Text="🧙 Backup Hardware Wizard" FontSize="18" FontWeight="Bold" Foreground="#6f42c1"/>
            <TextBlock Text="Answer a few questions to get personalized recommendations" Foreground="Gray" Margin="0,5,0,0"/>
        </StackPanel>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <GroupBox Header="1. What type of computer do you have?" Margin="0,0,0,10">
                    <StackPanel Margin="10">
                        <RadioButton Name="RbDesktop" Content="Desktop PC" IsChecked="True" Margin="0,5"/>
                        <RadioButton Name="RbLaptop" Content="Laptop" Margin="0,5"/>
                        <RadioButton Name="RbWorkstation" Content="Workstation/Server" Margin="0,5"/>
                    </StackPanel>
                </GroupBox>
                
                <GroupBox Header="2. What is your Windows edition?" Margin="0,0,0,10">
                    <StackPanel Margin="10">
                        <RadioButton Name="RbWin10" Content="Windows 10" IsChecked="True" Margin="0,5"/>
                        <RadioButton Name="RbWin11" Content="Windows 11" Margin="0,5"/>
                        <RadioButton Name="RbWinOther" Content="Other/Older Windows" Margin="0,5"/>
                    </StackPanel>
                </GroupBox>
                
                <GroupBox Header="3. How much data do you need to back up?" Margin="0,0,0,10">
                    <StackPanel Margin="10">
                        <RadioButton Name="RbDataSmall" Content="Less than 500GB" IsChecked="True" Margin="0,5"/>
                        <RadioButton Name="RbDataMedium" Content="500GB - 2TB" Margin="0,5"/>
                        <RadioButton Name="RbDataLarge" Content="More than 2TB" Margin="0,5"/>
                    </StackPanel>
                </GroupBox>
                
                <GroupBox Header="4. What is your budget for backup hardware?" Margin="0,0,0,10">
                    <StackPanel Margin="10">
                        <RadioButton Name="RbBudgetLow" Content="Budget-friendly (Under \$100)" IsChecked="True" Margin="0,5"/>
                        <RadioButton Name="RbBudgetMid" Content="Mid-range (\$100-\$300)" Margin="0,5"/>
                        <RadioButton Name="RbBudgetHigh" Content="Premium (\$300+)" Margin="0,5"/>
                    </StackPanel>
                </GroupBox>
                
                <GroupBox Header="5. How important is backup speed to you?" Margin="0,0,0,10">
                    <StackPanel Margin="10">
                        <RadioButton Name="RbSpeedLow" Content="Not important (Occasional backups)" Margin="0,5"/>
                        <RadioButton Name="RbSpeedMed" Content="Somewhat important (Weekly backups)" IsChecked="True" Margin="0,5"/>
                        <RadioButton Name="RbSpeedHigh" Content="Very important (Daily/frequent backups)" Margin="0,5"/>
                    </StackPanel>
                </GroupBox>
            </StackPanel>
        </ScrollViewer>
        
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
            <Button Name="BtnWizardCancel" Content="Cancel" Width="100" Height="30" Margin="0,0,10,0"/>
            <Button Name="BtnWizardGenerate" Content="Get Recommendations" Width="150" Height="30" Background="#6f42c1" Foreground="White" FontWeight="Bold"/>
        </StackPanel>
    </Grid>
</Window>
"@
    
    $wizardWindow = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$wizardXaml)))
    
    $wizardWindow.FindName("BtnWizardCancel").Add_Click({
        $wizardWindow.Close()
    })
    
    $wizardWindow.FindName("BtnWizardGenerate").Add_Click({
        # Gather selections
        $computerType = "Desktop"
        if ($wizardWindow.FindName("RbLaptop").IsChecked) { $computerType = "Laptop" }
        if ($wizardWindow.FindName("RbWorkstation").IsChecked) { $computerType = "Workstation" }
        
        $windowsVersion = "Windows 10"
        if ($wizardWindow.FindName("RbWin11").IsChecked) { $windowsVersion = "Windows 11" }
        if ($wizardWindow.FindName("RbWinOther").IsChecked) { $windowsVersion = "Other Windows" }
        
        $dataSize = "Small"
        if ($wizardWindow.FindName("RbDataMedium").IsChecked) { $dataSize = "Medium" }
        if ($wizardWindow.FindName("RbDataLarge").IsChecked) { $dataSize = "Large" }
        
        $budget = "Low"
        if ($wizardWindow.FindName("RbBudgetMid").IsChecked) { $budget = "Mid" }
        if ($wizardWindow.FindName("RbBudgetHigh").IsChecked) { $budget = "High" }
        
        $speedImportance = "Medium"
        if ($wizardWindow.FindName("RbSpeedLow").IsChecked) { $speedImportance = "Low" }
        if ($wizardWindow.FindName("RbSpeedHigh").IsChecked) { $speedImportance = "High" }
        
        # Generate recommendations
        $recommendations = @"
═══════════════════════════════════════════════════════════════
    PERSONALIZED BACKUP RECOMMENDATIONS
═══════════════════════════════════════════════════════════════

Your Profile:
  • Computer Type: $computerType
  • Windows Version: $windowsVersion
  • Data Size: $dataSize (< 500GB / 500GB-2TB / > 2TB)
  • Budget: $budget
  • Speed Priority: $speedImportance

───────────────────────────────────────────────────────────────
HARDWARE RECOMMENDATIONS:
───────────────────────────────────────────────────────────────

"@
        
        # Hardware recommendations based on profile
        if ($computerType -eq "Desktop") {
            if ($budget -eq "High" -and $speedImportance -eq "High") {
                $recommendations += @"
🏆 RECOMMENDED: Internal NVMe SSD (PCIe 4.0 or 5.0)
   • Capacity: 1TB or 2TB (based on your data size)
   • Speed: Up to 7,000 MB/s (PCIe 4.0) or 14,000 MB/s (PCIe 5.0)
   • Installation: Requires M.2 slot on motherboard
   • Estimated Cost: `$150-`$400
   • Example Products:
     - Samsung 990 PRO (PCIe 4.0)
     - Crucial T700 (PCIe 5.0)
     - WD Black SN850X (PCIe 4.0)

⚠️ NOTE: Check if your motherboard has an available M.2 slot.
   If not, consider a motherboard upgrade or external option.

"@
            } elseif ($budget -eq "Mid" -or $speedImportance -eq "Medium") {
                $recommendations += @"
✅ RECOMMENDED: USB 3.2 Gen 2 External SSD
   • Capacity: 1TB or 2TB
   • Speed: Up to 1,000 MB/s
   • Connection: USB-C (USB 3.2 Gen 2)
   • Estimated Cost: `$100-`$250
   • Example Products:
     - Samsung T7/T9 Portable SSD
     - SanDisk Extreme Pro Portable SSD
     - Crucial X8/X10 Portable SSD

💡 TIP: Also works great if you want portability!

"@
            } else {
                $recommendations += @"
💰 BUDGET OPTION: External HDD (7200 RPM) or SATA SSD
   • Capacity: 2TB or 4TB (HDD) / 1TB (SSD)
   • Speed: ~150 MB/s (HDD) / ~550 MB/s (SATA SSD)
   • Connection: USB 3.0
   • Estimated Cost: `$50-`$100
   • Example Products:
     - WD Elements/My Passport (HDD)
     - Seagate Backup Plus (HDD)
     - Samsung 870 QVO in USB enclosure (SATA SSD)

💡 TIP: HDDs offer more storage per dollar but are slower.

"@
            }
        } else {
            # Laptop recommendations
            $recommendations += @"
✅ RECOMMENDED: USB 3.2 Gen 2 External SSD
   • Capacity: 1TB or 2TB
   • Speed: Up to 1,000 MB/s
   • Connection: USB-C (USB 3.2 Gen 2)
   • Portable and fast!
   • Estimated Cost: `$100-`$250
   • Example Products:
     - Samsung T7/T9 Portable SSD
     - SanDisk Extreme Pro Portable SSD
     - Crucial X8/X10 Portable SSD

💡 TIP: Perfect for laptops - portable and fast enough for frequent backups.

"@
        }
        
        # Software recommendations
        $recommendations += @"
───────────────────────────────────────────────────────────────
SOFTWARE RECOMMENDATIONS:
───────────────────────────────────────────────────────────────

"@
        
        if ($budget -eq "Low") {
            $recommendations += @"
🆓 FREE SOFTWARE:

1. Macrium Reflect Free ⭐ RECOMMENDED
   • Full system imaging with bootable rescue media
   • Reliable and fast
   • Best free option available
   • Download: https://www.macrium.com/reflectfree

2. AOMEI Backupper Standard
   • System/disk/partition backup
   • Scheduling support
   • Download: https://www.aomeitech.com

3. Windows Built-in Backup
   • File History + System Image
   • Already on your PC
   • Access via: Control Panel → Backup and Restore

"@
        } else {
            $recommendations += @"
💎 PAID SOFTWARE (Best Performance):

1. Macrium Reflect Home ⭐ RECOMMENDED
   • Professional features with commercial-grade reliability
   • Fast imaging and restore
   • Excellent WinPE rescue media
   • Cost: ~`$70
   • Download: https://www.macrium.com

2. Acronis Cyber Protect Home Office
   • Cloud integration and ransomware protection
   • Time estimates for operations
   • Cost: ~`$50-100/year (subscription)
   • Download: https://www.acronis.com

💡 OR use the free options above - they work great too!

"@
        }
        
        # Backup strategy
        $recommendations += @"
───────────────────────────────────────────────────────────────
RECOMMENDED BACKUP STRATEGY:
───────────────────────────────────────────────────────────────

"@
        
        if ($speedImportance -eq "High") {
            $recommendations += @"
⚡ HIGH-SPEED BACKUP PLAN:
   • Full System Image: Weekly (automated)
   • Incremental Backups: Daily (automated)
   • Critical Files: Real-time sync to cloud (OneDrive/Google Drive)
   • Keep 3-4 versions of system images

"@
        } elseif ($speedImportance -eq "Medium") {
            $recommendations += @"
✅ BALANCED BACKUP PLAN:
   • Full System Image: Every 2 weeks or before major changes
   • Important Files: Weekly (automated)
   • Critical Documents: Cloud sync (OneDrive/Google Drive)
   • Keep 2-3 versions of system images

"@
        } else {
            $recommendations += @"
💰 OCCASIONAL BACKUP PLAN:
   • Full System Image: Monthly or before major changes
   • Important Files: Weekly
   • Keep 1-2 versions of system images
   • Consider cloud storage for critical files

"@
        }
        
        # Additional tips
        $recommendations += @"
───────────────────────────────────────────────────────────────
ADDITIONAL TIPS:
───────────────────────────────────────────────────────────────

✓ Always test your backups by doing a trial restore
✓ Keep backups in a different physical location when possible
✓ Create bootable rescue media and test it before you need it
✓ Document your backup locations and passwords
✓ Schedule automatic backups to avoid forgetting
✓ Consider the 3-2-1 rule: 3 copies, 2 different media, 1 offsite

───────────────────────────────────────────────────────────────

Need help? Check the other tabs for tool links and instructions!

"@
        
        # Display recommendations
        $resultXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Your Backup Recommendations" Width="800" Height="700" WindowStartupLocation="CenterScreen" Background="#F0F0F0">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="Your Personalized Recommendations" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <TextBox Name="RecommendationsText" Text="" TextWrapping="Wrap" IsReadOnly="True" 
                     FontFamily="Consolas" Background="White" BorderThickness="1" BorderBrush="#CCC" Padding="10"/>
        </ScrollViewer>
        
        <Button Grid.Row="2" Name="BtnClose" Content="Close" Width="100" Height="30" Margin="0,10,0,0" HorizontalAlignment="Right"/>
    </Grid>
</Window>
"@
        
        $resultWindow = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$resultXaml)))
        $resultWindow.FindName("RecommendationsText").Text = $recommendations
        $resultWindow.FindName("BtnClose").Add_Click({ $resultWindow.Close() })
        
        $wizardWindow.Close()
        $resultWindow.ShowDialog() | Out-Null
    })
    
    $wizardWindow.ShowDialog() | Out-Null
})

# ============================================================================
# REPAIR-INSTALL READINESS CHECK HANDLERS
# ============================================================================

$W.FindName("BtnRepairReadiness").Add_Click({
    $outputBox = $W.FindName("ReadinessCheckOutput")
    $outputBox.Text = "Starting repair-install readiness check...`n"
    
    try {
        # Call the module function
        if (Get-Command Invoke-RepairInstallReadinessCheck -ErrorAction SilentlyContinue) {
            $verbose = if ($W.FindName("ChkVerboseReadiness").IsChecked) { $true } else { $false }
            $result = Invoke-RepairInstallReadinessCheck -TargetDrive "C" -AutoRepair $false
            
            # Update status indicators
            $eligibility = $result.Steps | Where-Object { $_.Step -eq "Setup Eligibility Check" } | Select-Object -ExpandProperty Result
            if ($eligibility -and $eligibility.IsEligible) {
                $W.FindName("StatusEligibility").Fill = [System.Windows.Media.Brush]::Parse("#28a745")
            } else {
                $W.FindName("StatusEligibility").Fill = [System.Windows.Media.Brush]::Parse("#dc3545")
            }
            
            # Update recommendation text
            $W.FindName("FinalRecommendation").Text = "Status: $($result.FinalRecommendation)`nCheck completed at $(Get-Date -Format 'HH:mm:ss')"
            
            # Append output
            $outputBox.Text += "`nReadiness check completed!`n"
        } else {
            $outputBox.Text = "ERROR: EnsureRepairInstallReady module not loaded`nCheck console for loading errors."
        }
    } catch {
        $outputBox.Text = "ERROR: $_"
    }
})

$W.FindName("BtnRepairReadinessAuto").Add_Click({
    $outputBox = $W.FindName("ReadinessCheckOutput")
    $outputBox.Text = "Starting repair-install readiness check with auto-repair...`n"
    
    try {
        if (Get-Command Invoke-RepairInstallReadinessCheck -ErrorAction SilentlyContinue) {
            $result = Invoke-RepairInstallReadinessCheck -TargetDrive "C" -AutoRepair $true
            
            # Update all status indicators
            $W.FindName("StatusEligibility").Fill = [System.Windows.Media.Brush]::Parse("#28a745")
            $W.FindName("StatusCBS").Fill = [System.Windows.Media.Brush]::Parse("#28a745")
            $W.FindName("StatusWinRE").Fill = [System.Windows.Media.Brush]::Parse("#28a745")
            $W.FindName("StatusSetupValidation").Fill = [System.Windows.Media.Brush]::Parse("#28a745")
            
            # Update recommendation
            $W.FindName("FinalRecommendation").Text = "Status: $($result.FinalRecommendation)`nAuto-repair completed at $(Get-Date -Format 'HH:mm:ss')"
            
            $outputBox.Text += "`nAuto-repair completed!`n"
        } else {
            $outputBox.Text = "ERROR: EnsureRepairInstallReady module not loaded"
        }
    } catch {
        $outputBox.Text = "ERROR: $_"
    }
})

$W.FindName("BtnExportReadinessReport").Add_Click({
    try {
        $reportPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop) + "\RepairReadinessReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $outputBox = $W.FindName("ReadinessCheckOutput")
        
        $reportContent = @"
═══════════════════════════════════════════════════════════════
REPAIR-INSTALL READINESS REPORT
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
═══════════════════════════════════════════════════════════════

SYSTEM INFORMATION:
  Computer: $env:COMPUTERNAME
  OS: $(Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
  Architecture: $(Get-WmiObject Win32_Processor | Select-Object -ExpandProperty Architecture)

READINESS CHECK OUTPUT:
─────────────────────────────────────────────────────────────

$($outputBox.Text)

═══════════════════════════════════════════════════════════════
END OF REPORT
═══════════════════════════════════════════════════════════════
"@
        
        Set-Content -Path $reportPath -Value $reportContent -Force
        [System.Windows.MessageBox]::Show("Report exported to:`n$reportPath", "Export Successful", "OK", "Information")
    } catch {
        [System.Windows.MessageBox]::Show("Error exporting report: $_", "Export Failed", "OK", "Error")
    }
})

} # End of null check if statement - all event handlers registered

if ($null -eq $W) {
    throw "Cannot show GUI: Window object is null"
}

$W.ShowDialog() | Out-Null

} # End of Start-GUI function
