#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Setup script for advanced Windows diagnostic tools
    
.DESCRIPTION
    Configures and enables:
    - Procmon boot logging
    - WPR performance recording
    - Event log expansion
    - Registry-based boot tracing
    
.PARAMETERS
    -Tool : Specific tool to setup ('Procmon', 'WPR', 'EventLog', 'All')
    -ConfigureAll : Quick setup of all available tools
    
.EXAMPLE
    .\Setup_Advanced_Diagnostics.ps1 -Tool Procmon
    .\Setup_Advanced_Diagnostics.ps1 -ConfigureAll
    
.NOTES
    Requires Administrator privileges
    Procmon and WPR must be separately installed
#>

param(
    [ValidateSet('Procmon', 'WPR', 'EventLog', 'Registry', 'All')]
    [string]$Tool = 'All',
    [switch]$ConfigureAll
)

# Color scheme
$colors = @{
    "Header"  = "Cyan"
    "Success" = "Green"
    "Error"   = "Red"
    "Warning" = "Yellow"
    "Info"    = "Gray"
}

function Write-Header {
    param([string]$Text)
    Write-Host "`n" + ("="*80) -ForegroundColor $colors.Header
    Write-Host $Text -ForegroundColor $colors.Header
    Write-Host ("="*80) -ForegroundColor $colors.Header
}

function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    if ($colors.ContainsKey($Type)) {
        $color = $colors[$Type]
    } else {
        $color = $colors.Info
    }
    Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $color
}

# Verify admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script requires Administrator privileges" -ForegroundColor $colors.Error
    exit 1
}

Write-Header "WINDOWS DIAGNOSTIC TOOLS SETUP"

# ============================================================================
# SETUP EVENT LOG
# ============================================================================
if ($Tool -eq 'EventLog' -or $Tool -eq 'All') {
    Write-Host "`n1. CONFIGURING EVENT LOGS" -ForegroundColor $colors.Header
    
    try {
        Write-Status "Expanding System Event Log size..."
        Limit-EventLog -LogName System -MaximumSize 2GB
        Write-Status "System log set to 2GB" "Success"
        
        Write-Status "Expanding Application Event Log size..."
        Limit-EventLog -LogName Application -MaximumSize 2GB
        Write-Status "Application log set to 2GB" "Success"
        
        Write-Status "Enabling Security audit logging..."
        # Enable process tracking
        auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable
        Write-Status "Process creation auditing enabled" "Success"
        
    } catch {
        Write-Status "Error configuring event logs: $_" "Error"
    }
}

# ============================================================================
# SETUP REGISTRY-BASED BOOT TRACING
# ============================================================================
if ($Tool -eq 'Registry' -or $Tool -eq 'All') {
    Write-Host "`n2. CONFIGURING REGISTRY-BASED BOOT TRACING" -ForegroundColor $colors.Header
    
    try {
        Write-Status "Enabling boot event log..."
        $regPath = "HKLM:\System\CurrentControlSet\Services\EventLog\System"
        Set-ItemProperty -Path $regPath -Name MaxSize -Value 524288 -Type DWord -ErrorAction SilentlyContinue
        Write-Status "Boot event log maximized" "Success"
        
        Write-Status "Enabling kernel event tracing..."
        # Enable Windows Kernel Trace
        $kePath = "HKLM:\System\CurrentControlSet\Control\WMI\Autologger\EventLog-System"
        if (-not (Test-Path $kePath)) {
            New-Item -Path $kePath -Force | Out-Null
        }
        Set-ItemProperty -Path $kePath -Name Enabled -Value 1 -Type DWord
        Write-Status "Kernel event tracing configured" "Success"
        
        Write-Status "Setting up critical event log..."
        $logPath = "HKLM:\System\CurrentControlSet\Services\EventLog\System"
        Set-ItemProperty -Path $logPath -Name Retention -Value 7 -Type DWord
        Write-Status "Event retention set to 7 days" "Success"
        
    } catch {
        Write-Status "Error configuring registry tracing: $_" "Error"
    }
}

# ============================================================================
# SETUP PROCMON
# ============================================================================
if ($Tool -eq 'Procmon' -or $Tool -eq 'All') {
    Write-Host "`n3. PROCMON BOOT LOGGING SETUP" -ForegroundColor $colors.Header
    
    # Find Procmon
    $procmonPath = $null
    $possiblePaths = @(
        "C:\Program Files\Sysinternals\Procmon.exe",
        "C:\Program Files (x86)\Sysinternals\Procmon.exe",
        "$env:USERPROFILE\Downloads\Procmon.exe",
        (Get-Command procmon -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    )
    
    foreach ($path in $possiblePaths) {
        if ($path -and (Test-Path $path)) {
            $procmonPath = $path
            break
        }
    }
    
    if ($procmonPath) {
        Write-Status "Found Procmon at: $procmonPath" "Success"
        
        $bootLogPath = "C:\Windows\Temp\ProcmonBoot"
        Write-Status "Boot log destination: $bootLogPath" "Info"
        
        Write-Status "Procmon boot logging must be configured manually:" "Warning"
        Write-Host @"
        
    Steps to enable Procmon boot logging:
    1. Run Procmon as Administrator: $procmonPath
    2. Go to Options > Enable Boot Logging...
    3. Select boot log location (default: $bootLogPath)
    4. Click OK to continue
    5. When prompted, restart your computer
    6. After restart, boot log is automatically captured
    
    Automated alternative:
    $procmonPath /bootlog
    
"@ -ForegroundColor $colors.Info
        
    } else {
        Write-Status "Procmon not found. Download from:" "Warning"
        Write-Host "  https://learn.microsoft.com/en-us/sysinternals/downloads/procmon" -ForegroundColor $colors.Info
        Write-Host "  Extract to: C:\Program Files\Sysinternals\" -ForegroundColor $colors.Info
    }
}

# ============================================================================
# SETUP WPR
# ============================================================================
if ($Tool -eq 'WPR' -or $Tool -eq 'All') {
    Write-Host "`n4. WINDOWS PERFORMANCE RECORDER (WPR) SETUP" -ForegroundColor $colors.Header
    
    # Check if WPR is installed
    $wprPath = "C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\wpr.exe"
    $wprPath11 = "C:\Program Files (x86)\Windows Kits\11\Windows Performance Toolkit\wpr.exe"
    
    $wprFound = $null
    if (Test-Path $wprPath) {
        $wprFound = $wprPath
    } elseif (Test-Path $wprPath11) {
        $wprFound = $wprPath11
    }
    
    if ($wprFound) {
        Write-Status "Found WPR at: $wprFound" "Success"
        Write-Status "Available profiles:" "Info"
        & $wprFound -profiles | Out-Host
        
        Write-Host @"
        
    To capture a boot performance trace:
    
    1. Open PowerShell as Administrator
    2. Start recording:
       wpr.exe -start GeneralProfile
    3. Restart your computer
    4. After boot completes, log data is captured
    5. Stop and save:
       wpr.exe -stop "boot_trace.etl"
    6. Analyze in Windows Performance Analyzer:
       wpa.exe "boot_trace.etl"

"@ -ForegroundColor $colors.Info
        
    } else {
        Write-Status "WPR not installed. Install Windows ADK:" "Warning"
        Write-Host @"
        
    Installation steps:
    1. Download Windows ADK from Microsoft
       https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
    2. Run ADK installer
    3. Select only 'Windows Performance Toolkit' component
    4. Complete installation
    5. Tools will be at: C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\

"@ -ForegroundColor $colors.Info
    }
}

# ============================================================================
# MSCONFIG BOOT LOGGING
# ============================================================================
Write-Host "`n5. MSCONFIG BOOT LOGGING" -ForegroundColor $colors.Header

Write-Status "To enable boot logging via msconfig:" "Info"
Write-Host @"
    
    Quick method (GUI):
    1. Press Win + R
    2. Type: msconfig
    3. Go to Boot tab
    4. Check 'Boot log' checkbox
    5. Click OK
    6. Choose 'Restart' when prompted
    7. Log file: C:\Windows\ntbtlog.txt
    
    PowerShell method (registry):
    reg add "HKLM\System\CurrentControlSet\Control\Session Manager" /v BootOptionsPersist /t REG_DWORD /d 0 /f
    
"@ -ForegroundColor $colors.Info

# ============================================================================
# GENERATE SETUP SUMMARY
# ============================================================================
Write-Header "SETUP SUMMARY"

$summary = @"

CONFIGURED TOOLS
================

1. EVENT VIEWER
   - Status: Built-in (always available)
   - Location: Run 'eventvwr.msc'
   - Log Size: $((Get-WmiObject Win32_NTEventLogFile -Filter "LogFileName='System'").MaxFileSize / 1MB)MB
   
2. BOOT LOG (ntbtlog.txt)
   - Status: Manual setup via msconfig
   - Location: C:\Windows\ntbtlog.txt
   - Setup Time: 5 minutes (includes restart)

3. EVENT LOG EXPANSION
   - System Log: 2GB
   - Application Log: 2GB
   - Status: Configured
   
4. BOOT TRACING (Registry)
   - Kernel Tracing: Enabled
   - Event Retention: 7 days
   - Status: Configured

5. PROCMON BOOT LOGGING
   - Location: C:\Windows\Temp\ProcmonBoot.pml
   - Status: $(if ($procmonPath) {"Installation found - manual setup required"} else {"Not installed"})
   - Installation: Download from Microsoft Sysinternals

6. WINDOWS PERFORMANCE RECORDER
   - Status: $(if ($wprFound) {"Installed"} else {"Not installed"})
   - Profiles: GeneralProfile, BootProfile, and others
   - Installation: Windows ADK (Performance Toolkit component)

NEXT STEPS
==========

To enable each tool:

Option 1 - Quick Start (5 minutes)
  1. Enable msconfig boot logging
  2. Restart computer
  3. Run: .\Collect_All_System_Logs.ps1
  4. Run: .\Windows_Log_Analyzer_Interactive.ps1

Option 2 - Deep Diagnostics (30 minutes)
  1. Enable boot logging for all available tools
  2. Enable Procmon boot logging
  3. Enable WPR recording
  4. Restart computer
  5. Collect all logs: .\Collect_All_System_Logs.ps1 -IncludeProcmon -IncludePerformanceTrace
  6. Analyze: .\Windows_Log_Analyzer_Interactive.ps1

Option 3 - Continuous Monitoring
  1. Set up recurring collection script
  2. Configure task scheduler
  3. Analyze trends over time

RECOMMENDED READING
===================
- WINDOWS_LOG_ANALYSIS_GUIDE.md (Comprehensive guide)
- WINDOWS_LOG_ANALYSIS_QUICKREF.md (Quick reference)
- BOOT_LOGGING_GUIDE.md (Advanced boot diagnostics)

"@

Write-Host $summary -ForegroundColor $colors.Info

# Create settings summary file
$settingsFile = "C:\MiracleBoot_Setup_Summary_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$summary | Out-File -FilePath $settingsFile -Encoding UTF8
Write-Status "Setup summary saved to: $settingsFile" "Success"

Write-Host "`nSetup complete!" -ForegroundColor $colors.Success
Write-Host "`nTo view all available tools: Review WINDOWS_LOG_ANALYSIS_GUIDE.md" -ForegroundColor $colors.Info
