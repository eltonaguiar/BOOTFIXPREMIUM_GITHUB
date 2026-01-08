# ============================================================================
# MIRACLEBOOT GUI ENHANCEMENT - SLOW PC ANALYZER TAB INTEGRATION
# Version: 7.2.0
# Purpose: Add Slow PC Analysis section to WinRepairGUI.ps1
# ============================================================================
#
# This file contains the XAML and PowerShell code to add a new "Performance"
# tab to the MiracleBoot GUI with Slow PC diagnostics and hardware 
# upgrade recommendations.
#
# HOW TO INTEGRATE:
# 1. Find the line in WinRepairGUI.ps1 that contains all TabItem definitions
#    (Around line 641: <TabItem Header="Recommended Tools">)
# 2. Add a new TabItem BEFORE "Recommended Tools" tab:
#
# 3. Copy the XAML section from "SLOW_PC_ANALYZER_TAB_XAML_START" 
#    to "SLOW_PC_ANALYZER_TAB_XAML_END" below
#
# 4. Add the PowerShell event handlers from the section below to the
#    event handler registration area in WinRepairGUI.ps1
#
# ============================================================================

# ============================================================================
# XAML DEFINITION FOR SLOW PC ANALYZER TAB
# ============================================================================
# Insert this XAML BEFORE the "Recommended Tools" TabItem (around line 641)

<#
SLOW_PC_ANALYZER_TAB_XAML_START

        <TabItem Header="⚡ Performance Analysis">
            <Grid Margin="10">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <StackPanel Grid.Row="0" Margin="0,0,0,15">
                    <TextBlock Text="Slow PC Performance Analyzer" FontWeight="Bold" FontSize="16" Margin="0,0,0,5" Foreground="#0078D7"/>
                    <TextBlock Text="Comprehensive system diagnostics to identify causes of slowness and provide hardware upgrade recommendations" TextWrapping="Wrap" Foreground="Gray" Margin="0,0,0,10"/>
                    
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <Button Content="🔍 Run Full Analysis" Name="BtnRunSlowPCAnalysis" Height="35" Background="#0078D7" Foreground="White" Width="200" Margin="0,0,10,0" FontWeight="Bold"/>
                        <Button Content="📊 Performance Comparison" Name="BtnShowComparison" Height="35" Background="#6f42c1" Foreground="White" Width="180" Margin="0,0,10,0"/>
                        <Button Content="📖 msconfig Guide" Name="BtnMsconfigGuide" Height="35" Background="#17a2b8" Foreground="White" Width="150" Margin="0,0,10,0"/>
                        <Button Content="💾 Export Report" Name="BtnExportPerformanceReport" Height="35" Background="#28a745" Foreground="White" Width="140"/>
                    </StackPanel>
                </StackPanel>
                
                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                    <TextBox Name="PerformanceAnalysisBox" 
                             AcceptsReturn="True" 
                             VerticalScrollBarVisibility="Disabled" 
                             FontFamily="Consolas" 
                             Background="White" 
                             Foreground="Black" 
                             TextWrapping="Wrap" 
                             IsReadOnly="True" 
                             Padding="10"
                             Text="Click 'Run Full Analysis' to diagnose your system performance and identify causes of slowness..."/>
                </ScrollViewer>
                
                <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,10,0,0">
                    <TextBlock Name="AnalysisStatus" Text="Ready" Foreground="Gray" VerticalAlignment="Center" Margin="0,0,20,0"/>
                    <ProgressBar Name="AnalysisProgressBar" Width="100" Height="15" Visibility="Collapsed" IsIndeterminate="True" Margin="0,0,10,0"/>
                </StackPanel>
            </Grid>
        </TabItem>

SLOW_PC_ANALYZER_TAB_XAML_END

#>

# ============================================================================
# POWERSHELL EVENT HANDLERS FOR SLOW PC ANALYZER TAB
# ============================================================================
# Add these event handlers in the event registration section of WinRepairGUI.ps1
# (Around line 3700, after other tab event handlers)

# Note: This is pseudocode showing what needs to be added.
# Adapt to your specific implementation.

<#

# ========================================================================
# SLOW PC ANALYZER TAB HANDLERS
# ========================================================================

$W.FindName("BtnRunSlowPCAnalysis").Add_Click({
    $analysisBox = $W.FindName("PerformanceAnalysisBox")
    $statusText = $W.FindName("AnalysisStatus")
    $progressBar = $W.FindName("AnalysisProgressBar")
    
    # Show progress
    $statusText.Text = "Running analysis... please wait"
    $progressBar.Visibility = "Visible"
    $W.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
    
    try {
        # Import the Slow PC Analyzer module
        $analyzerPath = Join-Path (Split-Path $PSScriptRoot) "HELPER SCRIPTS\MiracleBoot-SlowPCAnalyzer.ps1"
        if (Test-Path $analyzerPath) {
            . $analyzerPath
        } else {
            $analysisBox.Text = "[ERROR] Slow PC Analyzer module not found at: $analyzerPath"
            $statusText.Text = "Error: Module not found"
            $progressBar.Visibility = "Collapsed"
            return
        }
        
        # Run analysis
        $analysis = Get-SlowPCAnalysis
        
        # Format report
        $report = Format-SlowPCAnalysisReport -Analysis $analysis
        
        # Display report
        $analysisBox.Text = $report
        $analysisBox.ScrollToHome()
        
        $statusText.Text = "Analysis complete"
        $progressBar.Visibility = "Collapsed"
        
        # Show summary message
        $issueCount = $analysis.OverallSlownessCauses.Count
        if ($issueCount -eq 0) {
            [System.Windows.MessageBox]::Show(
                "✓ Analysis complete!`n`nNo critical performance issues detected.`n`nYour system appears to be running normally.",
                "Performance Analysis Complete",
                "OK",
                "Information"
            ) | Out-Null
        } else {
            [System.Windows.MessageBox]::Show(
                "Analysis complete!`n`nFound $issueCount performance issue(s).`n`nReview the detailed report in the tab above.",
                "Performance Analysis Complete",
                "OK",
                "Information"
            ) | Out-Null
        }
    } catch {
        $analysisBox.Text = "[ERROR] Failed to run analysis: $_`n`nPlease ensure MiracleBoot-SlowPCAnalyzer.ps1 is in the HELPER SCRIPTS folder."
        $statusText.Text = "Error running analysis"
        $progressBar.Visibility = "Collapsed"
        
        [System.Windows.MessageBox]::Show(
            "Error running performance analysis: $_",
            "Analysis Failed",
            "OK",
            "Error"
        ) | Out-Null
    }
})

$W.FindName("BtnShowComparison").Add_Click({
    $analysisBox = $W.FindName("PerformanceAnalysisBox")
    $statusText = $W.FindName("AnalysisStatus")
    $progressBar = $W.FindName("AnalysisProgressBar")
    
    # Show progress
    $statusText.Text = "Generating performance comparison... please wait"
    $progressBar.Visibility = "Visible"
    $W.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
    
    try {
        # Import the Slow PC Analyzer module
        $analyzerPath = Join-Path (Split-Path $PSScriptRoot) "HELPER SCRIPTS\MiracleBoot-SlowPCAnalyzer.ps1"
        if (Test-Path $analyzerPath) {
            . $analyzerPath
        } else {
            $analysisBox.Text = "[ERROR] Slow PC Analyzer module not found"
            $statusText.Text = "Error: Module not found"
            $progressBar.Visibility = "Collapsed"
            return
        }
        
        # Run analysis
        $analysis = Get-SlowPCAnalysis
        
        # Get comparison
        $comparison = Get-PerformanceComparison -Analysis $analysis
        
        # Display comparison
        $analysisBox.Text = $comparison
        $analysisBox.ScrollToHome()
        
        $statusText.Text = "Comparison generated"
        $progressBar.Visibility = "Collapsed"
        
    } catch {
        $analysisBox.Text = "[ERROR] Failed to generate comparison: $_"
        $statusText.Text = "Error generating comparison"
        $progressBar.Visibility = "Collapsed"
    }
})

$W.FindName("BtnMsconfigGuide").Add_Click({
    # Show msconfig guide in a new window
    try {
        $guidePath = Join-Path (Split-Path (Split-Path $PSScriptRoot)) "DOCUMENTATION\MSCONFIG_BOOT_GUIDE.md"
        
        if (Test-Path $guidePath) {
            $content = Get-Content $guidePath -Raw
            
            # Create window to display guide
            $guideXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="msconfig & Boot Optimization Guide" Width="900" Height="700" 
        WindowStartupLocation="CenterScreen" Background="#F0F0F0">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Grid.Row="0" Text="msconfig & Boot Optimization Guide" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>
        
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
            <TextBox Name="GuideContent" Text="" TextWrapping="Wrap" IsReadOnly="True" 
                     FontFamily="Consolas" Background="White" Foreground="Black" Padding="10"/>
        </ScrollViewer>
        
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="BtnOpenMsconfig" Content="Open msconfig Now" Background="#0078D7" Foreground="White" Width="150" Height="30" Margin="0,0,10,0"/>
            <Button Name="BtnCloseGuide" Content="Close" Width="100" Height="30"/>
        </StackPanel>
    </Grid>
</Window>
"@
            
            $guideWindow = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$guideXaml)))
            $guideWindow.FindName("GuideContent").Text = $content
            
            $guideWindow.FindName("BtnOpenMsconfig").Add_Click({
                try {
                    Start-Process "msconfig.exe"
                } catch {
                    [System.Windows.MessageBox]::Show("Could not open msconfig. Run manually: Press Windows Key + R, type 'msconfig', press Enter.", "Info", "OK", "Information")
                }
            })
            
            $guideWindow.FindName("BtnCloseGuide").Add_Click({
                $guideWindow.Close()
            })
            
            $guideWindow.ShowDialog() | Out-Null
        } else {
            [System.Windows.MessageBox]::Show(
                "Guide file not found at: $guidePath`n`nManual access: Open Windows Start menu, type 'msconfig', press Enter",
                "Guide Not Found",
                "OK",
                "Information"
            ) | Out-Null
        }
    } catch {
        [System.Windows.MessageBox]::Show(
            "Error opening guide: $_",
            "Error",
            "OK",
            "Error"
        ) | Out-Null
    }
})

$W.FindName("BtnExportPerformanceReport").Add_Click({
    $analysisBox = $W.FindName("PerformanceAnalysisBox")
    
    if ([string]::IsNullOrWhiteSpace($analysisBox.Text) -or $analysisBox.Text -match "Click.*Run Full Analysis") {
        [System.Windows.MessageBox]::Show(
            "Please run the analysis first before exporting.`n`nClick 'Run Full Analysis' button.",
            "No Analysis Data",
            "OK",
            "Warning"
        ) | Out-Null
        return
    }
    
    # Open save dialog
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    $saveDialog.FileName = "MiracleBoot_Performance_Analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $saveDialog.InitialDirectory = $env:USERPROFILE + "\Desktop"
    $saveDialog.Title = "Export Performance Analysis Report"
    
    $result = $saveDialog.ShowDialog()
    
    if ($result -eq "OK") {
        try {
            $analysisBox.Text | Out-File -FilePath $saveDialog.FileName -Encoding UTF8 -Force
            
            [System.Windows.MessageBox]::Show(
                "Report exported successfully!`n`nLocation: $($saveDialog.FileName)",
                "Export Complete",
                "OK",
                "Information"
            ) | Out-Null
            
            # Ask if user wants to open file location
            $openResult = [System.Windows.MessageBox]::Show(
                "Would you like to open the file location?",
                "Open File Location",
                "YesNo",
                "Question"
            )
            
            if ($openResult -eq "Yes") {
                try {
                    Start-Process explorer.exe -ArgumentList "/select,`"$($saveDialog.FileName)`""
                } catch {
                    # Silently fail if explorer doesn't work
                }
            }
        } catch {
            [System.Windows.MessageBox]::Show(
                "Error exporting report: $_",
                "Export Failed",
                "OK",
                "Error"
            ) | Out-Null
        }
    }
})

#>

# ============================================================================
# INTEGRATION INSTRUCTIONS FOR GUI DEVELOPERS
# ============================================================================

<#

STEP-BY-STEP INTEGRATION GUIDE:

1. FIND THE TABITEM INSERTION POINT
   - Open: HELPER SCRIPTS\WinRepairGUI.ps1
   - Search for: <TabItem Header="Recommended Tools">
   - This should be around line 641
   - Add the new tab BEFORE this line

2. INSERT THE XAML
   - Copy the XAML code from "SLOW_PC_ANALYZER_TAB_XAML_START" 
     to "SLOW_PC_ANALYZER_TAB_XAML_END" (above this file)
   - Paste it just before "<TabItem Header="Recommended Tools">"

3. ADD EVENT HANDLERS
   - Find the event handler registration section 
     (look for "BtnRefreshSummary.Add_Click" pattern, around line 700+)
   - Find where other tab event handlers end (before Recommended Tools)
   - Add the three event handlers:
     * BtnRunSlowPCAnalysis.Add_Click
     * BtnShowComparison.Add_Click
     * BtnMsconfigGuide.Add_Click
     * BtnExportPerformanceReport.Add_Click

4. VERIFY MODULE IMPORT
   - Ensure MiracleBoot-SlowPCAnalyzer.ps1 is in HELPER SCRIPTS folder
   - Module path: HELPER SCRIPTS\MiracleBoot-SlowPCAnalyzer.ps1

5. TEST THE INTEGRATION
   - Run WinRepairGUI.ps1
   - Look for new "⚡ Performance Analysis" tab
   - Click "Run Full Analysis" button
   - Verify report displays correctly

6. TROUBLESHOOTING
   - If tab doesn't show: Check XAML syntax
   - If buttons don't work: Check event handler names match button names
   - If module doesn't load: Verify file path and module exists
   - Check PowerShell execution policy: Set-ExecutionPolicy Bypass -Scope CurrentUser

EXPECTED RESULT:
After integration, you should see a new tab in WinRepairGUI showing:
- Performance Analysis button
- Hardware comparison
- msconfig guide access
- Export functionality

#>

# ============================================================================
# ADDITIONAL FEATURES TO CONSIDER
# ============================================================================

<#

These features could be added in future versions:

1. REAL-TIME MONITORING
   - Add background task to monitor CPU/RAM/Disk usage
   - Update dashboard with live metrics
   - Alert when thresholds exceeded

2. AUTOMATED OPTIMIZATION
   - Add buttons for automated cleanup
   - One-click optimization for common issues
   - Before/after performance metrics

3. HARDWARE SHOPPING ASSISTANT
   - Links to recommended hardware on Amazon/Newegg
   - Price comparison across retailers
   - Compatibility checker for current system

4. BOOT TIME TRACKING
   - Measure boot times over time
   - Graph performance improvements
   - Historical comparison

5. STARTUP OPTIMIZER
   - Integration with Task Manager startup analysis
   - One-click disable of high-impact programs
   - Impact prediction

6. TEMPERATURE MONITORING
   - CPU and GPU temperature display
   - Thermal throttling detection
   - Cooling solution recommendations

7. DRIVER UPDATE ASSISTANT
   - Check for outdated drivers
   - One-click update links
   - Rollback functionality

#>

# ============================================================================
# FILE LOCATIONS REFERENCE
# ============================================================================

<#

Required Files for Integration:

/HELPER SCRIPTS/
  ├── WinRepairGUI.ps1 (MODIFY: Add tab and event handlers)
  └── MiracleBoot-SlowPCAnalyzer.ps1 (NEW: Already created)

/DOCUMENTATION/
  └── MSCONFIG_BOOT_GUIDE.md (NEW: Already created)

Tab Placement in TabControl:
  - Before: "Recommended Tools"
  - After: "Repair-Install Readiness"
  - Icon: ⚡ (Lightning bolt for performance)

#>
