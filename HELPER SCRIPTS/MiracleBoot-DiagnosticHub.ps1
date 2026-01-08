<#
.SYNOPSIS
    MiracleBoot Diagnostic Hub
    
    Central launcher for all diagnostics and log analysis tools.
    Provides GUI-based access to:
    - Log gathering
    - Log analysis
    - Event Viewer
    - Crash Analyzer
    - Remediation scripts

#>

param(
    [Switch]$NoGUI
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

#region Variables
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogGathererScript = Join-Path $ScriptRoot "MiracleBoot-LogGatherer.ps1"
$AnalyzerScript = Join-Path $ScriptRoot "MiracleBoot-AdvancedLogAnalyzer.ps1"
$CrashAnalyzerPath = Join-Path $ScriptRoot "..\CrashAnalyzer\crashanalyze.exe"
$LogDirectory = "$ScriptRoot\..\LOGS\LogAnalysis"

#endregion

#region Helper Functions
function Show-Message {
    param([String]$Message, [String]$Title = "MiracleBoot", [String]$Type = "Info")
    
    $MessageType = switch ($Type) {
        "Error" { [System.Windows.Forms.MessageBoxIcon]::Error }
        "Warning" { [System.Windows.Forms.MessageBoxIcon]::Warning }
        "Question" { [System.Windows.Forms.MessageBoxIcon]::Question }
        default { [System.Windows.Forms.MessageBoxIcon]::Information }
    }
    
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, $MessageType) | Out-Null
}

function Run-Script {
    param([String]$ScriptPath, [String]$Arguments)
    
    if (-not (Test-Path $ScriptPath)) {
        Show-Message "Script not found: $ScriptPath" "Error" "Error"
        return
    }
    
    $PowerShellPath = (Get-Command powershell).Source
    $Command = "-NoExit -File `"$ScriptPath`""
    
    if ($Arguments) {
        $Command += " $Arguments"
    }
    
    Start-Process $PowerShellPath -ArgumentList $Command
}

function Open-Folder {
    param([String]$FolderPath)
    
    if (Test-Path $FolderPath) {
        Invoke-Item $FolderPath
    } else {
        Show-Message "Folder not found: $FolderPath" "Warning" "Warning"
    }
}

#endregion

#region GUI Creation
function Create-DiagnosticGUI {
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "MiracleBoot Diagnostic Hub v7.2"
    $Form.Size = New-Object System.Drawing.Size(800, 700)
    $Form.StartPosition = "CenterScreen"
    $Form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $Form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    
    #region Title Panel
    $TitlePanel = New-Object System.Windows.Forms.Panel
    $TitlePanel.Dock = "Top"
    $TitlePanel.Height = 80
    $TitlePanel.BackColor = [System.Drawing.Color]::FromArgb(0, 102, 204)
    
    $TitleLabel = New-Object System.Windows.Forms.Label
    $TitleLabel.Text = "🔧 MiracleBoot Diagnostic Hub"
    $TitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $TitleLabel.ForeColor = [System.Drawing.Color]::White
    $TitleLabel.Location = New-Object System.Drawing.Point(20, 15)
    $TitleLabel.Size = New-Object System.Drawing.Size(600, 40)
    $TitlePanel.Controls.Add($TitleLabel)
    
    $SubtitleLabel = New-Object System.Windows.Forms.Label
    $SubtitleLabel.Text = "Centralized Diagnostics, Log Analysis & Remediation"
    $SubtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $SubtitleLabel.ForeColor = [System.Drawing.Color]::White
    $SubtitleLabel.Location = New-Object System.Drawing.Point(20, 50)
    $SubtitleLabel.Size = New-Object System.Drawing.Size(600, 20)
    $TitlePanel.Controls.Add($SubtitleLabel)
    
    $Form.Controls.Add($TitlePanel)
    #endregion
    
    #region Tab Control
    $TabControl = New-Object System.Windows.Forms.TabControl
    $TabControl.Location = New-Object System.Drawing.Point(10, 90)
    $TabControl.Size = New-Object System.Drawing.Size(770, 590)
    $TabControl.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    
    #region Tab 1: Log Gathering
    $Tab1 = New-Object System.Windows.Forms.TabPage
    $Tab1.Text = "📊 Log Gathering"
    $Tab1.BackColor = [System.Drawing.Color]::White
    
    $GroupBox1 = New-Object System.Windows.Forms.GroupBox
    $GroupBox1.Text = "Gather Diagnostic Logs"
    $GroupBox1.Location = New-Object System.Drawing.Point(10, 10)
    $GroupBox1.Size = New-Object System.Drawing.Size(740, 350)
    $GroupBox1.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    
    $TextBox1 = New-Object System.Windows.Forms.TextBox
    $TextBox1.Location = New-Object System.Drawing.Point(15, 30)
    $TextBox1.Size = New-Object System.Drawing.Size(710, 200)
    $TextBox1.Multiline = $true
    $TextBox1.ReadOnly = $true
    $TextBox1.ScrollBars = "Vertical"
    $TextBox1.Text = @"
This tool gathers critical logs from multiple sources:

TIER 1: Boot-Critical Crash Dumps
  • C:\Windows\MEMORY.DMP
  • C:\Windows\LiveKernelReports\

TIER 2: Boot Pipeline Logs
  • C:\Windows\Panther\setupact.log & setuperr.log
  • C:\Windows\ntbtlog.txt

TIER 3: Event Logs
  • C:\Windows\System32\winevt\Logs\System.evtx

TIER 4: Boot Structure
  • BCD Store, Registry hives

TIER 5: Image/Hardware Context

Logs will be organized and analyzed systematically.
"@
    $GroupBox1.Controls.Add($TextBox1)
    
    $GatherButton = New-Object System.Windows.Forms.Button
    $GatherButton.Text = "▶ Gather Logs Now"
    $GatherButton.Location = New-Object System.Drawing.Point(15, 240)
    $GatherButton.Size = New-Object System.Drawing.Size(150, 40)
    $GatherButton.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
    $GatherButton.ForeColor = [System.Drawing.Color]::White
    $GatherButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $GatherButton.Add_Click({ 
        Run-Script $LogGathererScript
    })
    $GroupBox1.Controls.Add($GatherButton)
    
    $AnalyzeButton = New-Object System.Windows.Forms.Button
    $AnalyzeButton.Text = "📈 Analyze Logs"
    $AnalyzeButton.Location = New-Object System.Drawing.Point(175, 240)
    $AnalyzeButton.Size = New-Object System.Drawing.Size(150, 40)
    $AnalyzeButton.BackColor = [System.Drawing.Color]::FromArgb(0, 102, 204)
    $AnalyzeButton.ForeColor = [System.Drawing.Color]::White
    $AnalyzeButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $AnalyzeButton.Add_Click({ 
        Run-Script $AnalyzerScript "-Interactive"
    })
    $GroupBox1.Controls.Add($AnalyzeButton)
    
    $OpenLogsButton = New-Object System.Windows.Forms.Button
    $OpenLogsButton.Text = "📁 Open Logs Folder"
    $OpenLogsButton.Location = New-Object System.Drawing.Point(335, 240)
    $AnalyzeButton.Size = New-Object System.Drawing.Size(150, 40)
    $OpenLogsButton.BackColor = [System.Drawing.Color]::FromArgb(200, 100, 0)
    $OpenLogsButton.ForeColor = [System.Drawing.Color]::White
    $OpenLogsButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $OpenLogsButton.Add_Click({ 
        Open-Folder $LogDirectory
    })
    $GroupBox1.Controls.Add($OpenLogsButton)
    
    $GatherAdvancedCheckbox = New-Object System.Windows.Forms.CheckBox
    $GatherAdvancedCheckbox.Text = "Use Advanced Options"
    $GatherAdvancedCheckbox.Location = New-Object System.Drawing.Point(15, 290)
    $GatherAdvancedCheckbox.Size = New-Object System.Drawing.Size(200, 30)
    $GroupBox1.Controls.Add($GatherAdvancedCheckbox)
    
    $Tab1.Controls.Add($GroupBox1)
    $TabControl.TabPages.Add($Tab1)
    #endregion
    
    #region Tab 2: Analysis Tools
    $Tab2 = New-Object System.Windows.Forms.TabPage
    $Tab2.Text = "🔍 Analysis Tools"
    $Tab2.BackColor = [System.Drawing.Color]::White
    
    $GroupBox2a = New-Object System.Windows.Forms.GroupBox
    $GroupBox2a.Text = "System Tools"
    $GroupBox2a.Location = New-Object System.Drawing.Point(10, 10)
    $GroupBox2a.Size = New-Object System.Drawing.Size(740, 150)
    
    $EventViewerButton = New-Object System.Windows.Forms.Button
    $EventViewerButton.Text = "📋 Open Event Viewer"
    $EventViewerButton.Location = New-Object System.Drawing.Point(15, 30)
    $EventViewerButton.Size = New-Object System.Drawing.Size(200, 40)
    $EventViewerButton.BackColor = [System.Drawing.Color]::FromArgb(0, 102, 204)
    $EventViewerButton.ForeColor = [System.Drawing.Color]::White
    $EventViewerButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $EventViewerButton.Add_Click({ 
        Start-Process "eventvwr.exe" -ErrorAction SilentlyContinue
        Show-Message "Event Viewer opened. Check System Event Log for:" + "`nEvent 1001 (BugCheck), Event 41 (Kernel-Power)" "Event Viewer"
    })
    $GroupBox2a.Controls.Add($EventViewerButton)
    
    $CrashAnalyzerButton = New-Object System.Windows.Forms.Button
    $CrashAnalyzerButton.Text = "💥 Crash Dump Analyzer"
    $CrashAnalyzerButton.Location = New-Object System.Drawing.Point(225, 30)
    $CrashAnalyzerButton.Size = New-Object System.Drawing.Size(200, 40)
    $CrashAnalyzerButton.BackColor = [System.Drawing.Color]::FromArgb(150, 0, 0)
    $CrashAnalyzerButton.ForeColor = [System.Drawing.Color]::White
    $CrashAnalyzerButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $CrashAnalyzerButton.Add_Click({ 
        if (Test-Path $CrashAnalyzerPath) {
            Start-Process $CrashAnalyzerPath
        } else {
            Show-Message "Crash Analyzer not found. Run Setup-CrashAnalyzer.ps1 first." "Not Found" "Warning"
        }
    })
    $GroupBox2a.Controls.Add($CrashAnalyzerButton)
    
    $DeviceManagerButton = New-Object System.Windows.Forms.Button
    $DeviceManagerButton.Text = "⚙️ Device Manager"
    $DeviceManagerButton.Location = New-Object System.Drawing.Point(435, 30)
    $DeviceManagerButton.Size = New-Object System.Drawing.Size(200, 40)
    $DeviceManagerButton.BackColor = [System.Drawing.Color]::FromArgb(200, 100, 0)
    $DeviceManagerButton.ForeColor = [System.Drawing.Color]::White
    $DeviceManagerButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $DeviceManagerButton.Add_Click({ 
        Start-Process "devmgmt.msc" -ErrorAction SilentlyContinue
    })
    $GroupBox2a.Controls.Add($DeviceManagerButton)
    
    $DiskMgmtButton = New-Object System.Windows.Forms.Button
    $DiskMgmtButton.Text = "💾 Disk Management"
    $DiskMgmtButton.Location = New-Object System.Drawing.Point(15, 80)
    $DiskMgmtButton.Size = New-Object System.Drawing.Size(200, 40)
    $DiskMgmtButton.BackColor = [System.Drawing.Color]::FromArgb(0, 102, 204)
    $DiskMgmtButton.ForeColor = [System.Drawing.Color]::White
    $DiskMgmtButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $DiskMgmtButton.Add_Click({ 
        Start-Process "diskmgmt.msc" -ErrorAction SilentlyContinue
    })
    $GroupBox2a.Controls.Add($DiskMgmtButton)
    
    $Tab2.Controls.Add($GroupBox2a)
    
    $GroupBox2b = New-Object System.Windows.Forms.GroupBox
    $GroupBox2b.Text = "Storage Diagnostics"
    $GroupBox2b.Location = New-Object System.Drawing.Point(10, 170)
    $GroupBox2b.Size = New-Object System.Drawing.Size(740, 380)
    
    $TextBox2 = New-Object System.Windows.Forms.TextBox
    $TextBox2.Location = New-Object System.Drawing.Point(15, 30)
    $TextBox2.Size = New-Object System.Drawing.Size(710, 320)
    $TextBox2.Multiline = $true
    $TextBox2.ReadOnly = $true
    $TextBox2.ScrollBars = "Vertical"
    $TextBox2.Text = @"
QUICK DIAGNOSTIC CHECKLIST:

1. STORAGE DRIVERS
   □ Check if storage drivers are loaded (Device Manager)
   □ Verify no yellow exclamation marks on storage devices
   □ Check driver version against hardware manufacturer

2. INACCESSIBLE_BOOT_DEVICE Root Causes
   □ NVMe/SATA compatibility (check BIOS RAID/AHCI mode)
   □ VMD (Virtual Machine Device) toggle
   □ Image restored to new hardware
   □ Missing or corrupted BCD
   □ Disabled storage driver in Registry

3. BOOT CONFIGURATION
   □ Review MEMORY.DMP if present
   □ Check LiveKernelReports\STORAGE for hangs
   □ Verify setupact.log for environment mismatches
   □ Check System event log for crash codes

4. REMEDIATION STEPS
   □ Boot into WinPE
   □ Inject correct storage driver (DISM)
   □ Enable driver in offline registry
   □ Rebuild BCD with bcdboot
   □ Verify boot configuration
"@
    $GroupBox2b.Controls.Add($TextBox2)
    
    $Tab2.Controls.Add($GroupBox2b)
    $TabControl.TabPages.Add($Tab2)
    #endregion
    
    #region Tab 3: Quick Actions
    $Tab3 = New-Object System.Windows.Forms.TabPage
    $Tab3.Text = "⚡ Quick Actions"
    $Tab3.BackColor = [System.Drawing.Color]::White
    
    $GroupBox3 = New-Object System.Windows.Forms.GroupBox
    $GroupBox3.Text = "Automated Workflows"
    $GroupBox3.Location = New-Object System.Drawing.Point(10, 10)
    $GroupBox3.Size = New-Object System.Drawing.Size(740, 520)
    
    $QuickAction1Button = New-Object System.Windows.Forms.Button
    $QuickAction1Button.Text = "1. Full Diagnostics (Gather + Analyze)"
    $QuickAction1Button.Location = New-Object System.Drawing.Point(15, 30)
    $QuickAction1Button.Size = New-Object System.Drawing.Size(710, 40)
    $QuickAction1Button.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
    $QuickAction1Button.ForeColor = [System.Drawing.Color]::White
    $QuickAction1Button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $QuickAction1Button.Add_Click({ 
        Run-Script $LogGathererScript
        Start-Sleep -Seconds 2
        Run-Script $AnalyzerScript "-Interactive"
    })
    $GroupBox3.Controls.Add($QuickAction1Button)
    
    $QuickAction2Button = New-Object System.Windows.Forms.Button
    $QuickAction2Button.Text = "2. Emergency Boot Recovery (BCD + Storage)"
    $QuickAction2Button.Location = New-Object System.Drawing.Point(15, 80)
    $QuickAction2Button.Size = New-Object System.Drawing.Size(710, 40)
    $QuickAction2Button.BackColor = [System.Drawing.Color]::FromArgb(150, 0, 0)
    $QuickAction2Button.ForeColor = [System.Drawing.Color]::White
    $QuickAction2Button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $QuickAction2Button.Add_Click({ 
        Show-Message "EMERGENCY RECOVERY STEPS:`n`n1. Boot into Windows Recovery Environment (WinRE)`n`n2. Open Command Prompt`n`n3. Run:`nbcdboot C:\Windows /s S: /f UEFI`n`n4. Then inject storage driver:`nDism /Image:C: /Add-Driver /Driver:<path> /ForceUnsigned`n`n5. Rebuild BCD again and reboot" "Emergency Recovery" "Info"
    })
    $GroupBox3.Controls.Add($QuickAction2Button)
    
    $QuickAction3Button = New-Object System.Windows.Forms.Button
    $QuickAction3Button.Text = "3. Analyze MEMORY.DMP (if exists)"
    $QuickAction3Button.Location = New-Object System.Drawing.Point(15, 130)
    $QuickAction3Button.Size = New-Object System.Drawing.Size(710, 40)
    $QuickAction3Button.BackColor = [System.Drawing.Color]::FromArgb(0, 102, 204)
    $QuickAction3Button.ForeColor = [System.Drawing.Color]::White
    $QuickAction3Button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $QuickAction3Button.Add_Click({ 
        $MemoryDmp = "$LogDirectory\MEMORY.DMP"
        if (Test-Path $MemoryDmp) {
            if (Test-Path $CrashAnalyzerPath) {
                Start-Process $CrashAnalyzerPath -ArgumentList "`"$MemoryDmp`""
            } else {
                Show-Message "Crash Analyzer not found. Would analyze:`n`n$MemoryDmp`n`nIn WinDbg, use: !analyze -v" "Crash Analysis" "Info"
            }
        } else {
            Show-Message "MEMORY.DMP not found in:`n`n$LogDirectory`n`nRun 'Gather Logs Now' first." "Not Found" "Warning"
        }
    })
    $GroupBox3.Controls.Add($QuickAction3Button)
    
    $QuickAction4Button = New-Object System.Windows.Forms.Button
    $QuickAction4Button.Text = "4. Check Storage Driver Status"
    $QuickAction4Button.Location = New-Object System.Drawing.Point(15, 180)
    $QuickAction4Button.Size = New-Object System.Drawing.Size(710, 40)
    $QuickAction4Button.BackColor = [System.Drawing.Color]::FromArgb(200, 100, 0)
    $QuickAction4Button.ForeColor = [System.Drawing.Color]::White
    $QuickAction4Button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $QuickAction4Button.Add_Click({ 
        $StorageDriverStatus = @"
STORAGE DRIVER STATUS:

To check if storage drivers are loaded:
PowerShell (Admin):
  Get-WmiObject Win32_SystemDriver | Where-Object { $_.Name -match 'stor|nvme' }

For specific drivers:
  Get-Service stornvme
  Get-Service storahci
  Get-Service iaStorV

Check status (Running = good):
  Get-WindowsDriver -Online -All | Where-Object { $_.ProviderName -match 'storage' }
"@
        Show-Message $StorageDriverStatus "Storage Driver Check" "Info"
    })
    $GroupBox3.Controls.Add($QuickAction4Button)
    
    $QuickAction5Button = New-Object System.Windows.Forms.Button
    $QuickAction5Button.Text = "5. Setup CrashAnalyzer"
    $QuickAction5Button.Location = New-Object System.Drawing.Point(15, 230)
    $QuickAction5Button.Size = New-Object System.Drawing.Size(710, 40)
    $QuickAction5Button.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 200)
    $QuickAction5Button.ForeColor = [System.Drawing.Color]::White
    $QuickAction5Button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $QuickAction5Button.Add_Click({ 
        $SetupScript = Join-Path $ScriptRoot "Setup-CrashAnalyzer.ps1"
        if (Test-Path $SetupScript) {
            Run-Script $SetupScript
        } else {
            Show-Message "Setup script not found: $SetupScript" "Not Found" "Error"
        }
    })
    $GroupBox3.Controls.Add($QuickAction5Button)
    
    $Tab3.Controls.Add($GroupBox3)
    $TabControl.TabPages.Add($Tab3)
    #endregion
    
    $Form.Controls.Add($TabControl)
    
    #region Footer
    $FooterLabel = New-Object System.Windows.Forms.Label
    $FooterLabel.Text = "MiracleBoot v7.2 | For INACCESSIBLE_BOOT_DEVICE and system diagnostics"
    $FooterLabel.Location = New-Object System.Drawing.Point(10, 690)
    $FooterLabel.Size = New-Object System.Drawing.Size(780, 20)
    $FooterLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $FooterLabel.ForeColor = [System.Drawing.Color]::Gray
    $Form.Controls.Add($FooterLabel)
    #endregion
    
    $Form.ShowDialog() | Out-Null
}

#endregion

# Main
if ($NoGUI) {
    Write-Host "Running in command-line mode" -ForegroundColor Cyan
    Write-Host "Available commands:"
    Write-Host "  powershell -File $LogGathererScript"
    Write-Host "  powershell -File $AnalyzerScript -Interactive"
} else {
    Create-DiagnosticGUI
}
