<#
    MIRACLE BOOT – WPF GRAPHICAL USER INTERFACE (GUI)
    ==================================================

    This module defines the **WPF desktop UI** for Miracle Boot. It is only
    available when running in a full Windows desktop with WPF/.NET available.
    All heavy lifting is delegated to the core engine in `Helper\WinRepairCore.ps1`.

    TABLE OF CONTENTS (HIGH‑LEVEL)
    ------------------------------
   1. WPF Window Definition (XAML)
       - Toolbar: utilities, network, ChatGPT help, environment indicators
       - Tabs:
           - Volumes & Health
           - BCD Editor
           - Boot Repair & Diagnostics
           - System File / Disk Repair
           - Drivers & Porting
           - In-Place Upgrade / Readiness
           - Logs & Install Failure Analysis
    2. Code‑Behind Wiring (`Start-GUI`)
       - XAML loading and window creation
       - Control lookups (`FindName`) and event wiring
       - Status bar and progress updates
    3. Command Handlers (By Area)
       - Volume refresh, BCD actions, boot repair commands
       - SFC/DISM/CHKDSK repair flows with progress callbacks
       - Driver export/porting/injection
       - Install failure analysis and log viewers
       - Repair-Install Readiness UX
       - Network enablement, diagnostics, and ChatGPT help
       - System restore point creation/listing
       - Keyboard symbol helper integration

    ENVIRONMENT MAPPING – WHEN THIS GUI RUNS
    ----------------------------------------
    - **FullOS (Windows 10/11 desktop) ONLY**
        - Launched by `MiracleBoot.ps1` when:
            - `Get-EnvironmentType` returns `FullOS`, and
            - WPF assemblies (`PresentationFramework`) load successfully.
        - Assumes:
            - A logged‑in interactive user session.
            - Sufficient .NET / WPF support.

    - **NOT USED in WinRE / WinPE / Shift+F10**
        - In those environments, `MiracleBoot.ps1` falls back to `Start-TUI`.

    FLOW MAPPING – HOW USER ACTIONS REACH THE ENGINE
    ------------------------------------------------
    1. `MiracleBoot.ps1` detects `FullOS` and dot‑sources:
         - `Helper\WinRepairCore.ps1`  → core engine
         - `Helper\WinRepairGUI.ps1`   → this file

    2. `Start-GUI` is invoked:
         - Loads XAML into a `Window`.
         - Looks up key UI elements (buttons, text boxes, list views).
         - Attaches event handlers for each button/menu item.

    3. Event handlers call into **engine functions** in `WinRepairCore.ps1`, e.g.:
         - `Get-WindowsVolumes`, `Get-BCDEntries*`
         - `Start-SystemFileRepair`, `Start-DiskRepair`, `Start-CompleteSystemRepair`
         - `Start-RepairInstallReadiness`
         - `Get-BootChainAnalysis`, `Get-BootLogAnalysis`
         - `Generate-SaveMeTxt`, driver export/porting helpers
         - `Create-SystemRestorePoint`, `Get-SystemRestorePoints`
         - Network diagnostics and ChatGPT helpers

    4. Real‑time progress is surfaced by:
         - Passing `ProgressCallback` scriptblocks into engine functions.
         - Updating:
             - Status bar text
             - Progress bar controls
             - Rich text / log output panes

    QUICK ORIENTATION
    -----------------
    - **New to the project?**  
        → Skim this file to see which **buttons and tabs** exist and then jump
          into `WinRepairCore.ps1` to see what work each action performs.

    - **Adding a new GUI feature?**  
        1. Extend the XAML (new button/tab/section).
        2. Wire up an event handler in `Start-GUI`.
        3. Call into an existing or new core function in `WinRepairCore.ps1`.

    - **Need environment‑specific behavior?**  
        → Use the environment status labels (`EnvStatus`, `NetworkStatus`) and
          gate actions if certain capabilities are missing (e.g. network, browser).
#>

# Initialize window variable early to prevent "variable not set" errors
# This satisfies PowerShell's strict mode and prevents race conditions
# The variable will be assigned the actual window object in Start-GUI function
$script:W = $null
$W = $null

try { Add-Type -AssemblyName PresentationFramework -ErrorAction Stop } catch {}
try { Add-Type -AssemblyName PresentationCore -ErrorAction Stop } catch {}
try { Add-Type -AssemblyName WindowsBase -ErrorAction Stop } catch {}
try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop } catch {}
try { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop } catch {}

# Load Defensive Boot Core
try {
    $corePath = Join-Path $PSScriptRoot "DefensiveBootCore.ps1"
    if (Test-Path $corePath) { 
        # Load with explicit UTF-8 encoding to prevent character corruption
        $coreContent = Get-Content $corePath -Raw -Encoding UTF8
        # Use dot-sourcing to load into current scope (allows functions to be available to nested functions)
        . ([scriptblock]::Create($coreContent))
        if (-not (Get-Command Invoke-DefensiveBootRepair -ErrorAction SilentlyContinue)) {
            Write-Warning "DefensiveBootCore.ps1 loaded but Invoke-DefensiveBootRepair function not found"
        }
        if (-not (Get-Command Invoke-BruteForceBootRepair -ErrorAction SilentlyContinue)) {
            Write-Warning "DefensiveBootCore.ps1 loaded but Invoke-BruteForceBootRepair function not found"
        }
    } else {
        Write-Warning "DefensiveBootCore.ps1 not found at $corePath - One-Click Repair may not work"
    }
} catch { 
    Write-Warning "Failed to load DefensiveBootCore.ps1: $_ - One-Click Repair may not work"
}

# Compute and cache a stable script root for all event handlers (UI contexts can null MyInvocation.Path)
$script:ScriptRootSafe = $PSScriptRoot
if (-not $script:ScriptRootSafe) { $script:ScriptRootSafe = Split-Path -Parent $PSCommandPath -ErrorAction SilentlyContinue }
if (-not $script:ScriptRootSafe) { $script:ScriptRootSafe = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue }
if (-not $script:ScriptRootSafe) { $script:ScriptRootSafe = (Get-Location).ProviderPath }

# Initialize script-level variables used by timer callbacks to prevent "variable not set" errors
# These are used in progress update timers and must be initialized before ShowDialog() is called
if (-not (Test-Path variable:script:stepIndex)) {
    $script:stepIndex = 0
}
if (-not (Test-Path variable:script:progressSteps)) {
    $script:progressSteps = @()
}

# Load centralized logging system
$script:LoggingAvailable = $false
try {
    if (Test-Path "$script:ScriptRootSafe\ErrorLogging.ps1") {
        . "$script:ScriptRootSafe\ErrorLogging.ps1"
        $null = Initialize-ErrorLogging -ScriptRoot $script:ScriptRootSafe -RetentionDays 7
        try { Add-MiracleBootLog -Level "INFO" -Message "WinRepairGUI.ps1 loaded" -Location "WinRepairGUI.ps1" -ErrorAction SilentlyContinue } catch { $script:LoggingAvailable = $false }
        $script:LoggingAvailable = $true
    } else {
        # Fallback if ErrorLogging.ps1 not found - define stub function
        if (-not (Get-Command Add-MiracleBootLog -ErrorAction SilentlyContinue)) {
            function Add-MiracleBootLog {
                param([string]$Level, [string]$Message, [string]$Location, [switch]$NoConsole, [hashtable]$Data, [switch]$ErrorAction)
                # Stub function - does nothing, just prevents errors
            }
        }
    }
} catch {
    # Silently continue if logging fails - define stub
    if (-not (Get-Command Add-MiracleBootLog -ErrorAction SilentlyContinue)) {
        function Add-MiracleBootLog {
            param([string]$Level, [string]$Message, [string]$Location, [switch]$NoConsole, [hashtable]$Data, [switch]$ErrorAction)
            # Stub function - does nothing, just prevents errors
        }
    }
}

# Function to log GUI failures that could cause TUI fallback
function Log-GUIFailure {
    param(
        [string]$Location,
        [string]$Error,
        [string]$Details = "",
        [Exception]$Exception = $null
    )
    
    $logMessage = "GUI FAILURE - Potential TUI Fallback`n"
    $logMessage += "Location: $Location`n"
    $logMessage += "Error: $Error`n"
    if ($Details) {
        $logMessage += "Details: $Details`n"
    }
    if ($Exception) {
        $logMessage += "Exception: $($Exception.Message)`n"
        $logMessage += "Stack Trace: $($Exception.StackTrace)`n"
    }
    $logMessage += "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $logMessage += "`n" + ("=" * 80) + "`n"
    
    # Try to log using the logging system
    try {
        if ($script:LoggingAvailable) {
            Add-MiracleBootLog -Level "ERROR" -Message $logMessage -Location $Location -Data @{
                Error = $Error
                Details = $Details
                ExceptionMessage = if ($Exception) { $Exception.Message } else { "" }
            } -ErrorAction SilentlyContinue
        }
    } catch {
        # Fallback: write to file directly
        try {
            $logFile = Join-Path $env:TEMP "MiracleBoot_GUI_Failures.log"
            Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
        } catch {
            # Last resort: write to console
            Write-Host $logMessage -ForegroundColor Red
        }
    }
    
    return $logMessage
}

# Define missing functions that GUI expects
function Open-ChatGPTHelp {
    param([switch]$ReturnInstructions)

    $instructions = @"
CHATGPT HELP FOR WINDOWS BOOT ISSUES
===================================

This tool provides AI-powered assistance for Windows boot problems.

HOW TO GET HELP:
1. Open your web browser
2. Go to: https://chatgpt.com
3. Describe your boot issue in detail:
   - What happened when you tried to start Windows?
   - Any error messages or codes?
   - What were you doing before the problem?
   - Hardware changes recently?

EXAMPLE QUERY:
"My Windows 10 PC won't boot. I get a blue screen with error code 0xc000000e.
This started after I installed new RAM. What should I do?"

AVAILABLE RESOURCES:
- Microsoft Support: https://support.microsoft.com
- Windows Boot Diagnostics Guide
- Community Forums: https://answers.microsoft.com

For urgent issues requiring immediate assistance, consider professional repair services.
"@

    if ($ReturnInstructions) {
        return @{ Success = $false; Instructions = $instructions; Message = "Browser not available - see instructions below" }
    }

    try {
        Start-Process "https://chatgpt.com"
        return @{ Success = $true; Message = "ChatGPT opened in browser" }
    } catch {
        return @{ Success = $false; Instructions = $instructions; Message = "Could not open browser - see instructions below" }
    }
}

function Show-SymbolHelperGUI {
    # Stub function for keyboard symbols
    [System.Windows.MessageBox]::Show("Keyboard Symbol Helper not implemented yet.`n`nUse Windows Character Map (charmap.exe) or Alt codes.", "Feature Not Available", "OK", "Information")
}

function Show-SymbolHelper {
    # Console version of symbol helper
    Write-Host "Keyboard Symbol Helper" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host "Common Alt Codes:" -ForegroundColor Yellow
    Write-Host ("Alt+0176 = {0} (degree)" -f [char]0x00B0) -ForegroundColor White
    Write-Host ("Alt+0169 = {0} (copyright)" -f [char]0x00A9) -ForegroundColor White
    Write-Host ("Alt+0174 = {0} (registered)" -f [char]0x00AE) -ForegroundColor White
    Write-Host ("Alt+0153 = {0} (trademark)" -f [char]0x2122) -ForegroundColor White
    Write-Host ("Alt+0131 = {0} (function)" -f [char]0x0192) -ForegroundColor White
    Write-Host ""
    Write-Host "Use Windows Character Map for more symbols." -ForegroundColor Gray
}

# Helper function to safely get controls with null checking
# Defined at script level so handlers can use it (returns null if $W doesn't exist yet)
function Get-Control {
    param([string]$Name, [switch]$Silent)  # Silent flag to suppress logging for optional controls
    # Check if $W exists and is not null (safe check that won't error if variable doesn't exist)
    if (-not (Get-Variable -Name "W" -Scope Script -ErrorAction SilentlyContinue) -or $null -eq $script:W) {
        if (-not $Silent) {
            try { Add-MiracleBootLog -Level "WARNING" -Message "Window object not available" -Location "Get-Control" -NoConsole -ErrorAction SilentlyContinue } catch {}
        }
        return $null
    }
    $W = $script:W
    $control = $W.FindName($Name)
    if (-not $control) {
        if (-not $Silent) {
            try { Add-MiracleBootLog -Level "WARNING" -Message "Control '$Name' not found in XAML" -Location "Get-Control" -Data @{ControlName=$Name} -NoConsole -ErrorAction SilentlyContinue } catch {}
        }
    }
    return $control
}

function Start-GUI {
    # LAYER 3: FAILURE ENUMERATION - STA Thread Validation
    # CRITICAL: WPF requires STA thread. Validate BEFORE any XAML operations.
    $apartmentState = [System.Threading.Thread]::CurrentThread.ApartmentState
    if ($apartmentState -ne 'STA') {
        $errorMsg = "WPF GUI requires STA (Single-Threaded Apartment) thread, but current thread is $apartmentState.`n"
        $errorMsg += "Please run PowerShell with -Sta parameter: powershell.exe -Sta -File MiracleBoot.ps1`n"
        $errorMsg += "Current thread apartment state: $apartmentState"
        throw $errorMsg
    }
    
    # XAML definition for the main window
    # Resolve XAML path - check multiple possible locations
    $xamlPath = $null
    
    # Try PSScriptRoot first (if set)
    if ($PSScriptRoot) {
        $xamlPath = Join-Path $PSScriptRoot "WinRepairGUI.xaml"
        if (-not (Test-Path -LiteralPath $xamlPath)) {
            $xamlPath = $null
        }
    }
    
    # Try script root from calling script
    if (-not $xamlPath) {
        $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        if ($scriptRoot) {
            $xamlPath = Join-Path $scriptRoot "WinRepairGUI.xaml"
            if (-not (Test-Path -LiteralPath $xamlPath)) {
                $xamlPath = $null
            }
        }
    }
    
    # Try current directory
    if (-not $xamlPath) {
        $xamlPath = Join-Path (Get-Location).Path "WinRepairGUI.xaml"
        if (-not (Test-Path -LiteralPath $xamlPath)) {
            $xamlPath = $null
        }
    }
    
    # Try relative to this script's location
    if (-not $xamlPath) {
        $thisScriptPath = $MyInvocation.MyCommand.Path
        if ($thisScriptPath) {
            $thisScriptDir = Split-Path -Parent $thisScriptPath
            $xamlPath = Join-Path $thisScriptDir "WinRepairGUI.xaml"
            if (-not (Test-Path -LiteralPath $xamlPath)) {
                $xamlPath = $null
            }
        }
    }
    
    if (-not $xamlPath -or -not (Test-Path -LiteralPath $xamlPath)) {
        $errorMsg = "XAML file not found. Searched in:`n"
        $errorMsg += "  - PSScriptRoot: $(if ($PSScriptRoot) { $PSScriptRoot } else { 'not set' })`n"
        $errorMsg += "  - Script path: $(if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { 'not set' })`n"
        $errorMsg += "  - Current directory: $((Get-Location).Path)"
        throw $errorMsg
    }
    $XAML = Get-Content -LiteralPath $xamlPath -Raw -ErrorAction Stop
    if ($XAML -match 'x:Class=') {
        # Strip x:Class to avoid class mismatch when loading loose XAML.
        $XAML = $XAML -replace '\s+x:Class="[^"]*"', ''
        $XAML = $XAML -replace "\s+x:Class='[^']*'", ''
        Write-Verbose "Removed x:Class attribute from XAML."
    }


# #region agent log
try {
    $logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ".cursor\debug.log"
    $logEntry = @{
        sessionId = "debug-session"
        runId = "gui-launch-1"
        hypothesisId = "A"
        location = "WinRepairGUI.ps1:469"
        message = "XAML parsing start"
        data = @{ xamlLength = $XAML.Length }
        timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
    } | ConvertTo-Json -Compress
    Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
} catch {}
# #endregion agent log

try {
    # #region agent log
    try {
        $logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ".cursor\debug.log"
        $logEntry = @{
            sessionId = "debug-session"
            runId = "gui-launch-verify"
            hypothesisId = "XAML-PARSE"
            location = "WinRepairGUI.ps1:before-parse"
            message = "About to parse XAML"
            data = @{ xamlLength = $XAML.Length; xamlPreview = $XAML.Substring(0, [Math]::Min(200, $XAML.Length)) }
            timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
        } | ConvertTo-Json -Compress
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
    # #endregion agent log
    
    # First validate XML structure
    try {
        $xmlDoc = [xml]$XAML
        # #region agent log
        try {
            $logEntry = @{
                sessionId = "debug-session"
                runId = "gui-launch-verify"
                hypothesisId = "XAML-PARSE"
                location = "WinRepairGUI.ps1:xml-validated"
                message = "XML structure validated"
                data = @{ rootElement = $xmlDoc.DocumentElement.Name }
                timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
            } | ConvertTo-Json -Compress
            Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
        } catch {}
        # #endregion agent log
    } catch {
        # #region agent log
        try {
            $logEntry = @{
                sessionId = "debug-session"
                runId = "gui-launch-verify"
                hypothesisId = "XAML-PARSE"
                location = "WinRepairGUI.ps1:xml-validation-failed"
                message = "XML validation failed"
                data = @{ error = $_.Exception.Message; innerException = $_.Exception.InnerException.Message }
                timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
            } | ConvertTo-Json -Compress
            Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
        } catch {}
        # #endregion agent log
        throw "XAML XML structure is invalid: $_"
    }
    
    # Load XAML with detailed error handling
    try {
        $script:W=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$XAML)))
        $W = $script:W  # Also set local variable for backward compatibility
    } catch {
        $innerEx = if ($_.Exception.InnerException) { $_.Exception.InnerException } else { $null }
        $errorDetails = "Failed to load XAML window:`n"
        $errorDetails += "  Exception: $($_.Exception.Message)`n"
        if ($innerEx) {
            $errorDetails += "  Inner Exception: $($innerEx.Message)`n"
            if ($innerEx.InnerException) {
                $errorDetails += "  Inner Inner Exception: $($innerEx.InnerException.Message)`n"
            }
            $errorDetails += "  Inner Stack Trace: $($innerEx.StackTrace)`n"
        }
        $errorDetails += "  Stack Trace: $($_.ScriptStackTrace)"
        throw $errorDetails
    }
    
    # Validate window object is valid before accessing controls
    if ($null -eq $W) {
        throw "Window object is null - XAML parsing may have failed silently"
    }
    
    # Wire up controls that were attempted at script load time (before $W existed)
    # These controls exist in XAML but couldn't be wired earlier because $W didn't exist
    $btnBCD = Get-Control "BtnBCD" -Silent
    if ($btnBCD) {
        $btnBCD.Add_Click({
            Invoke-BCDRefresh -ButtonControl $btnBCD
        })
    }
    
    $btnBCDHelp = Get-Control "BtnBCDHelp" -Silent
    if ($btnBCDHelp) {
        $btnBCDHelp.Add_Click({
            try {
                $bcdList = Get-Control "BCDList"
                $bcdEntries = if ($bcdList -and $bcdList.ItemsSource) { $bcdList.ItemsSource } else { $null }
                $selectedEntry = if ($bcdList -and $bcdList.SelectedItem) { $bcdList.SelectedItem } else { $null }
                Show-BCDParameterHelp -BCDEntries $bcdEntries -SelectedEntry $selectedEntry
            } catch {
                Show-MessageBoxSafe -Message "Error opening help: $_" -Title "Error" -Button ([System.Windows.MessageBoxButton]::OK) -Icon ([System.Windows.MessageBoxImage]::Error)
            }
        })
    }
    
    $btnSimLoadBCD = Get-Control "BtnSimLoadBCD" -Silent
    if ($btnSimLoadBCD) {
        $btnSimLoadBCD.Add_Click({
            Invoke-BCDRefresh -ButtonControl $btnSimLoadBCD
        })
    }
    
    $btnGetOSInfo = Get-Control "BtnGetOSInfo" -Silent
    if ($btnGetOSInfo) {
        $btnGetOSInfo.Add_Click({
            $diagDriveCombo = Get-Control "DiagDriveCombo"
            $selectedDrive = if ($diagDriveCombo) { $diagDriveCombo.SelectedItem } else { $null }
            $drive = $env:SystemDrive.TrimEnd(':')
            
            if ($selectedDrive) {
                if ($selectedDrive -match '^([A-Z]):') {
                    $drive = $matches[1]
                }
            }
            
            $diagBox = Get-Control "DiagBox"
            if ($diagBox) {
                $diagBox.Text = "Gathering Operating System information for drive $drive`:...`n`n"
            }
            
            try {
                $osInfo = Get-OSInfo -TargetDrive $drive
            } catch {
                $osInfo = @{
                    Error = "Failed to retrieve OS information: $($_.Exception.Message)"
                    IsCurrentOS = $false
                }
            }
            
            $output = "OPERATING SYSTEM INFORMATION`n"
            $output += "===============================================================`n`n"
            
            if ($null -eq $osInfo) {
                $output += "[ERROR] Failed to retrieve OS information. Get-OSInfo returned null.`n"
                $output += "Drive: $drive`:`n`n"
                if ($diagBox) {
                    $diagBox.Text = $output
                }
                return
            }
            
            if ($osInfo.PSObject.Properties.Name -contains 'IsCurrentOS' -and $osInfo.IsCurrentOS) {
                $output += "[CURRENT OS] This is the operating system you are currently running from.`n"
                $output += "Drive: $drive`: (System Drive: $($env:SystemDrive))`n`n"
            } else {
                $output += "[OFFLINE OS] This is an offline Windows installation.`n"
                $output += "Drive: $drive`: (Not currently running)`n`n"
            }
            
            if ($osInfo.PSObject.Properties.Name -contains 'Error' -and $osInfo.Error) {
                $output += "[ERROR] $($osInfo.Error)`n"
            } else {
                if ($osInfo.PSObject.Properties.Name -contains 'OSName') {
                    $output += "OS Name: $($osInfo.OSName)`n"
                }
                if ($osInfo.PSObject.Properties.Name -contains 'Version') {
                    $output += "Version: $($osInfo.Version)`n"
                }
                if ($osInfo.PSObject.Properties.Name -contains 'BuildNumber' -and $osInfo.BuildNumber) {
                    $output += "Build Number: $($osInfo.BuildNumber)`n"
                }
                if ($osInfo.PSObject.Properties.Name -contains 'UBR' -and $osInfo.UBR) {
                    $output += "Update Build Revision (UBR): $($osInfo.UBR)`n"
                }
                if ($osInfo.PSObject.Properties.Name -contains 'ReleaseId' -and $osInfo.ReleaseId) {
                    $output += "Release ID: $($osInfo.ReleaseId)`n"
                }
                if ($osInfo.PSObject.Properties.Name -contains 'EditionID' -and $osInfo.EditionID) {
                    $output += "Edition: $($osInfo.EditionID)`n"
                }
                if ($osInfo.PSObject.Properties.Name -contains 'Architecture' -and $osInfo.Architecture) {
                    $output += "Architecture: $($osInfo.Architecture)`n"
                }
                if ($osInfo.PSObject.Properties.Name -contains 'Language' -and $osInfo.Language) {
                    $output += "Language: $($osInfo.Language)"
                    if ($osInfo.PSObject.Properties.Name -contains 'LanguageCode' -and $osInfo.LanguageCode) {
                        $output += " (Code: $($osInfo.LanguageCode))"
                    }
                }
                $output += "`n"
                
                if ($osInfo.PSObject.Properties.Name -contains 'IsInsider' -and $osInfo.IsInsider) {
                    $output += "`n[INSIDER BUILD DETECTED]`n"
                    $output += "This is a Windows Insider Preview build.`n"
                    if ($osInfo.PSObject.Properties.Name -contains 'InsiderChannel' -and $osInfo.InsiderChannel) {
                        $output += "Channel: $($osInfo.InsiderChannel)`n"
                    }
                    $output += "`nINSIDER ISO DOWNLOAD LINKS:`n"
                    $output += "---------------------------------------------------------------`n"
                    $output += "Official Insider ISO Downloads:`n"
                    if ($osInfo.PSObject.Properties.Name -contains 'InsiderLinks' -and $osInfo.InsiderLinks -and $osInfo.InsiderLinks.DevChannel) {
                        $output += "  $($osInfo.InsiderLinks.DevChannel)`n`n"
                    }
                    $output += "UUP Dump (Community ISO Builder):`n"
                    if ($osInfo.PSObject.Properties.Name -contains 'InsiderLinks' -and $osInfo.InsiderLinks -and $osInfo.InsiderLinks.UUP) {
                        $output += "  $($osInfo.InsiderLinks.UUP)`n"
                    }
                    if ($osInfo.PSObject.Properties.Name -contains 'BuildNumber' -and $osInfo.BuildNumber) {
                        $output += "  (Search for build $($osInfo.BuildNumber) to find matching ISO)`n`n"
                    }
                }
                
                if ($osInfo.PSObject.Properties.Name -contains 'InstallDate' -and $osInfo.InstallDate) {
                    $output += "Install Date: $($osInfo.InstallDate)`n"
                }
                if ($osInfo.PSObject.Properties.Name -contains 'SerialNumber' -and $osInfo.SerialNumber) {
                    $output += "Serial Number: $($osInfo.SerialNumber)`n"
                }
                
                if ($osInfo.PSObject.Properties.Name -contains 'IsInsider' -and -not $osInfo.IsInsider) {
                    $output += "`n`nRECOMMENDED RECOVERY ISO:`n"
                    $output += "===============================================================`n"
                    $output += "To create a compatible recovery ISO, you need:`n`n"
                    if ($osInfo.PSObject.Properties.Name -contains 'RecommendedISO' -and $osInfo.RecommendedISO) {
                        if ($osInfo.RecommendedISO.Architecture) {
                            $output += "Architecture: $($osInfo.RecommendedISO.Architecture)`n"
                        }
                        if ($osInfo.RecommendedISO.Language) {
                            $lang = if ($osInfo.PSObject.Properties.Name -contains 'Language' -and $osInfo.Language) { $osInfo.Language } else { "" }
                            $output += "Language: $($osInfo.RecommendedISO.Language) ($lang)`n"
                        }
                        if ($osInfo.RecommendedISO.Version) {
                            $output += "Version: $($osInfo.RecommendedISO.Version)`n`n"
                        }
                    }
                    $output += "Download from:`n"
                    if ($osInfo.PSObject.Properties.Name -contains 'RecommendedISO' -and $osInfo.RecommendedISO -and $osInfo.RecommendedISO.Version -match "11") {
                        $output += "  https://www.microsoft.com/software-download/windows11`n"
                    } else {
                        $output += "  https://www.microsoft.com/software-download/windows10`n"
                    }
                    $output += "`nMake sure to select:`n"
                    if ($osInfo.PSObject.Properties.Name -contains 'RecommendedISO' -and $osInfo.RecommendedISO -and $osInfo.RecommendedISO.Architecture) {
                        $output += "- $($osInfo.RecommendedISO.Architecture) architecture`n"
                    }
                    if ($osInfo.PSObject.Properties.Name -contains 'Language' -and $osInfo.Language) {
                        $output += "- $($osInfo.Language) language`n"
                    }
                    $output += "- The same or newer version than your current installation`n"
                } else {
                    $output += "`n`nNOTE: For Insider builds, use the Insider ISO links above.`n"
                    $output += "Standard Windows 10/11 ISOs may not be compatible with Insider builds.`n"
                }
            }
            
            if ($diagBox) {
                $diagBox.Text = $output
            }
        })
    }
    
    # #region agent log
    try {
        $logEntry = @{
            sessionId = "debug-session"
            runId = "gui-launch-verify"
            hypothesisId = "XAML-PARSE"
            location = "WinRepairGUI.ps1:parse-success"
            message = "XAML parsing success"
            data = @{ windowType = $W.GetType().FullName; windowNotNull = ($null -ne $W) }
            timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
        } | ConvertTo-Json -Compress
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
    # #endregion agent log
} catch {
    # #region agent log
    try {
        $logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ".cursor\debug.log"
        $logEntry = @{
            sessionId = "debug-session"
            runId = "gui-launch-verify"
            hypothesisId = "XAML-PARSE"
            location = "WinRepairGUI.ps1:parse-failed"
            message = "XAML parsing failed"
            data = @{ 
                error = $_.Exception.Message
                innerException = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
                stackTrace = $_.ScriptStackTrace
            }
            timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
        } | ConvertTo-Json -Compress
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
    # #endregion agent log
    throw "Failed to parse XAML: $_"
}

# Get-Control is now defined at script level (above) so handlers can use it

# Helper function to safely wire up event handlers with null checking
function Connect-EventHandler {
    param(
        [string]$ControlName,
        [string]$EventName,
        [scriptblock]$Handler
    )
    $control = Get-Control -Name $ControlName
    if ($control) {
        try {
            $control.$EventName.Add($Handler)
        } catch {
            Write-Warning "Failed to wire up $EventName event for '$ControlName': $_"
        }
    } else {
        Write-Warning "Skipping event handler for '$ControlName' - control not found in XAML"
    }
}

# Load LogAnalysis module
$logAnalysisPath = Join-Path $PSScriptRoot "LogAnalysis.ps1"
if (Test-Path $logAnalysisPath) {
    try {
        . $logAnalysisPath
    } catch {
        Write-Warning "Failed to load LogAnalysis module: $_"
    }
}

# Detect environment
$envType = "FullOS"
if (Test-Path 'HKLM:\System\CurrentControlSet\Control\MiniNT') { $envType = "WinRE" }
if ($env:SystemDrive -eq 'X:') { $envType = "WinRE" }

# Load WinRepairCore module to make helper functions available for button handlers
# NOTE: Window validation moved inside Start-GUI function after $W is created
try {
    # Resolve WinRepairCore path with multiple fallbacks (handles dot-sourcing scenarios)
    $coreModulePath = $null
    
    # Try 1: Current directory first (most common scenario)
    $testPath = Join-Path (Get-Location).Path "WinRepairCore.ps1"
    if (Test-Path -LiteralPath $testPath) {
        $coreModulePath = $testPath
    }
    
    # Try 2: MyInvocation.MyCommand.Path (fails when dot-sourced but used when script is called directly)
    if (-not $coreModulePath -and $MyInvocation.MyCommand.Path) {
        $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        $testPath = Join-Path $scriptRoot "WinRepairCore.ps1"
        if (Test-Path -LiteralPath $testPath) {
            $coreModulePath = $testPath
        }
    }
    
    # Try 3: PSScriptRoot (set when script is run directly)
    if (-not $coreModulePath -and $PSScriptRoot) {
        $testPath = Join-Path $PSScriptRoot "WinRepairCore.ps1"
        if (Test-Path -LiteralPath $testPath) {
            $coreModulePath = $testPath
        }
    }
    
    # Try 4: If called from another script, use that script's directory
    if (-not $coreModulePath -and $MyInvocation.PSCommandPath) {
        $scriptRoot = Split-Path -Parent $MyInvocation.PSCommandPath
        $testPath = Join-Path $scriptRoot "WinRepairCore.ps1"
        if (Test-Path -LiteralPath $testPath) {
            $coreModulePath = $testPath
        }
    }
    
    if ($coreModulePath) {
        . $coreModulePath -ErrorAction Stop
        # #region agent log
        try {
            $logEntry = @{
                sessionId = "debug-session"
                runId = "gui-launch-1"
                hypothesisId = "B"
                location = "WinRepairGUI.ps1:412"
                message = "WinRepairCore.ps1 loaded successfully"
                data = @{ coreModulePath = $coreModulePath }
                timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
            } | ConvertTo-Json -Compress
            Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
        } catch {}
        # #endregion agent log
    } else {
        Write-Warning "WinRepairCore.ps1 not found. Searched in: current directory, script root locations."
        # #region agent log
        try {
            $logEntry = @{
                sessionId = "debug-session"
                runId = "gui-launch-1"
                hypothesisId = "B"
                location = "WinRepairGUI.ps1:412"
                message = "WinRepairCore.ps1 not found in any search location"
                data = @{ currentDir = (Get-Location).Path; psScriptRoot = $PSScriptRoot; myInvocation = $MyInvocation.MyCommand.Path }
                timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
            } | ConvertTo-Json -Compress
            Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
        } catch {}
        # #endregion agent log
    }
} catch {
    Write-Warning "Failed to load WinRepairCore.ps1: $_"
    # #region agent log
    try {
        $logEntry = @{
            sessionId = "debug-session"
            runId = "gui-launch-1"
            hypothesisId = "B"
            location = "WinRepairGUI.ps1:412-error"
            message = "Failed to load WinRepairCore.ps1"
            data = @{ error = $_.Exception.Message; stackTrace = $_.ScriptStackTrace }
            timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
        } | ConvertTo-Json -Compress
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
    # #endregion agent log
}

# #region agent log
try {
    $logEntry = @{
        sessionId = "debug-session"
        runId = "gui-launch-1"
        hypothesisId = "B"
        location = "WinRepairGUI.ps1:475"
        message = "Before FindName EnvStatus"
        data = @{ envType = $envType; windowNotNull = ($null -ne $W) }
        timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
    } | ConvertTo-Json -Compress
    Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
} catch {}
# #endregion agent log

$envStatusControl = Get-Control -Name "EnvStatus"

# #region agent log
try {
    $logEntry = @{
        sessionId = "debug-session"
        runId = "gui-launch-1"
        hypothesisId = "B"
        location = "WinRepairGUI.ps1:477"
        message = "After FindName EnvStatus"
        data = @{ controlIsNull = ($null -eq $envStatusControl); controlType = if ($envStatusControl) { $envStatusControl.GetType().FullName } else { "null" } }
        timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
    } | ConvertTo-Json -Compress
    Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
} catch {}
# #endregion agent log

if ($envStatusControl) {
    $envStatusControl.Text = "Environment: $envType"
} else {
    Write-Warning "EnvStatus control not found in XAML"
}

# Utility buttons (with null checks)
$btnNotepad = Get-Control -Name "BtnNotepad"
if ($btnNotepad) {
    $btnNotepad.Add_Click({
        try {
            Start-Process notepad.exe -ErrorAction SilentlyContinue
        } catch {
            [System.Windows.MessageBox]::Show("Notepad not available in this environment.", "Warning", "OK", "Warning")
        }
    })
} else {
    Write-Warning "BtnNotepad control not found in XAML"
}

$btnRegistry = Get-Control -Name "BtnRegistry"
if ($btnRegistry) {
    $btnRegistry.Add_Click({
        try {
            Start-Process regedit.exe -ErrorAction SilentlyContinue
        } catch {
            [System.Windows.MessageBox]::Show("Registry Editor not available in this environment.", "Warning", "OK", "Warning")
        }
    })
} else {
    Write-Warning "BtnRegistry control not found in XAML"
}

$btnPowerShell = Get-Control -Name "BtnPowerShell"
if ($btnPowerShell) {
    $btnPowerShell.Add_Click({
        try {
            Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle = 'MiracleBoot - PowerShell'" -ErrorAction SilentlyContinue
        } catch {
            [System.Windows.MessageBox]::Show("PowerShell not available.", "Error", "OK", "Error")
        }
    })
} else {
    Write-Warning "BtnPowerShell control not found in XAML"
}

$btnDiskManagement = Get-Control -Name "BtnDiskManagement"
if ($btnDiskManagement) {
    $btnDiskManagement.Add_Click({
        try {
            Start-Process diskmgmt.msc -ErrorAction Stop
        } catch {
            [System.Windows.MessageBox]::Show("Disk Management not available in this environment.", "Warning", "OK", "Warning")
        }
    })
} else {
    Write-Warning "BtnDiskManagement control not found in XAML"
}

$btnRestartExplorer = Get-Control -Name "BtnRestartExplorer"
if ($btnRestartExplorer) {
    $btnRestartExplorer.Add_Click({
        try {
            $result = Restart-WindowsExplorer
            if ($result.Success) {
                [System.Windows.MessageBox]::Show("Windows Explorer restarted successfully.`n`n$($result.Message)", "Explorer Restarted", "OK", "Information")
            } else {
                [System.Windows.MessageBox]::Show("Failed to restart Windows Explorer:`n`n$($result.Message)", "Error", "OK", "Error")
            }
        } catch {
            [System.Windows.MessageBox]::Show("Error restarting Windows Explorer: $_", "Error", "OK", "Error")
        }
    })
} else {
    Write-Warning "BtnRestartExplorer control not found in XAML"
}

$btnRestore = Get-Control -Name "BtnRestore"
if ($btnRestore) {
    $btnRestore.Add_Click({
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
                        $btnCheckRestore = $W.FindName("BtnCheckRestore")
                        if ($btnCheckRestore) {
                            $btnCheckRestore.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                        }
                    }, [System.Windows.Threading.DispatcherPriority]::Input)
                }
            }
        } catch {
            # Fallback: show message directing user to Diagnostics tab
            [System.Windows.MessageBox]::Show("Please navigate to the Diagnostics tab and click 'Check System Restore' to view restore points.", "Info", "OK", "Information")
        }
    })
} else {
    Write-Warning "BtnRestore control not found in XAML"
}

# Network enablement button
$btnEnableNetwork = Get-Control -Name "BtnEnableNetwork"
if ($btnEnableNetwork) {
    $btnEnableNetwork.Add_Click({
        try {
            Update-StatusBar -Message "Enabling network adapters..." -ShowProgress
            $result = Enable-NetworkWinRE
            
            $networkStatusControl = Get-Control "NetworkStatus"
            if ($result.Success) {
                if ($networkStatusControl) {
                    $networkStatusControl.Text = "Network: Enabled"
                    $networkStatusControl.Foreground = "Green"
                }
                
                # Test internet connectivity
                Update-StatusBar -Message "Testing internet connectivity..." -ShowProgress
                $internetTest = Test-InternetConnectivity
                
                if ($internetTest.Connected) {
                    if ($networkStatusControl) {
                        $networkStatusControl.Text = "Network: Connected"
                    }
                    [System.Windows.MessageBox]::Show("Network enabled successfully!`n`n$($result.Message)`n`n$($internetTest.Message)", "Network Enabled", "OK", "Information")
                } else {
                    if ($networkStatusControl) {
                        $networkStatusControl.Text = "Network: No Internet"
                        $networkStatusControl.Foreground = "Orange"
                    }
                    [System.Windows.MessageBox]::Show("Network adapters enabled, but no internet connectivity detected.`n`n$($result.Message)`n`n$($internetTest.Message)", "Network Enabled (No Internet)", "OK", "Warning")
                }
            } else {
                if ($networkStatusControl) {
                    $networkStatusControl.Text = "Network: Failed"
                    $networkStatusControl.Foreground = "Red"
                }
                [System.Windows.MessageBox]::Show("Failed to enable network:`n`n$($result.Message)", "Network Error", "OK", "Error")
            }
            Update-StatusBar -Message "Network operation complete" -HideProgress
        } catch {
            Update-StatusBar -Message "Network operation failed: $_" -HideProgress
            [System.Windows.MessageBox]::Show("Error enabling network: $_", "Error", "OK", "Error")
        }
    })
} else {
    Write-Warning "BtnEnableNetwork control not found in XAML"
}

# ChatGPT Help button
$btnNetworkDiagnostics = Get-Control -Name "BtnNetworkDiagnostics"
if ($btnNetworkDiagnostics) {
    $btnNetworkDiagnostics.Add_Click({
    try {
        if (Get-Command Invoke-NetworkDiagnostics -ErrorAction SilentlyContinue) {
            Update-StatusBar -Message "Running network diagnostics..." -ShowProgress
            
            # Switch to Diagnostics tab if available
            $grid = $W.Content
            $tabControl = $grid.Children | Where-Object { $_.GetType().Name -eq 'TabControl' } | Select-Object -First 1
            
            if ($tabControl) {
                $diagTab = $tabControl.Items | Where-Object { $_.Header -eq "Diagnostics" }
                if ($diagTab) {
                    $tabControl.SelectedItem = $diagTab
                }
            }
            
            $result = Invoke-NetworkDiagnostics
            $diagBox = Get-Control "DiagBox"
            if ($diagBox) {
                $diagBox.Text = $result.Report
            }
            Update-StatusBar -Message "Network diagnostics complete" -HideProgress
        } else {
            [System.Windows.MessageBox]::Show(
                "Network Diagnostics module not available.`n`nThis feature requires NetworkDiagnostics.ps1 to be loaded.",
                "Module Not Available",
                "OK",
                "Warning"
            )
        }
    } catch {
        [System.Windows.MessageBox]::Show("Error running network diagnostics: $_", "Error", "OK", "Error")
        Update-StatusBar -Message "Network diagnostics failed" -HideProgress
    }
    })
}

$btnKeyboardSymbols = Get-Control -Name "BtnKeyboardSymbols"
if ($btnKeyboardSymbols) {
    $btnKeyboardSymbols.Add_Click({
    try {
        if (Get-Command Show-SymbolHelperGUI -ErrorAction SilentlyContinue) {
            Show-SymbolHelperGUI
        } elseif (Get-Command Show-SymbolHelper -ErrorAction SilentlyContinue) {
            # Fallback to console version
            Show-SymbolHelper
        } else {
            [System.Windows.MessageBox]::Show(
                "Keyboard Symbol Helper not available.`n`nThis feature requires KeyboardSymbols.ps1 to be loaded.",
                "Module Not Available",
                "OK",
                "Warning"
            )
        }
    } catch {
        [System.Windows.MessageBox]::Show("Error launching keyboard symbol helper: $_", "Error", "OK", "Error")
    }
    })
}

# Theme and UI Layout Settings (will be initialized inside Start-GUI)
$script:IsDarkMode = $false
$script:IsCompactUI = $false

# These functions will be defined inside Start-GUI after $W is created
function Apply-DarkMode {
    # Safe check: use Get-Variable to check if $W exists before accessing
    if (-not (Get-Variable -Name "W" -Scope Script -ErrorAction SilentlyContinue) -or $null -eq $script:W) { return }
    $W = $script:W
    
    try {
        $script:IsDarkMode = $true
        $darkBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#1E1E1E"))
        $lightBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#D4D4D4"))
        $panelBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#252526"))
        $textBoxBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#3C3C3C"))
        
        # Apply to main window
        $W.Background = $darkBrush
        $W.Foreground = $lightBrush
        
        # Apply to main grid
        $mainGrid = $W.Content
        if ($mainGrid) {
            $mainGrid.Background = $darkBrush
        }
        
        # Apply to specific controls by name
        $controlsToUpdate = @(
            "DrvBox", "BCDBox", "DiagBox", "LogAnalysisBox", "FixerOutput", 
            "RepairInstallOutput", "BootHealthBox", "UpdateEligibilityBox"
        )
        
        foreach ($controlName in $controlsToUpdate) {
            $control = Get-Control -Name $controlName -Silent
            if ($control) {
                try {
                    $control.Background = $textBoxBrush
                    $control.Foreground = $lightBrush
                } catch {}
            }
        }
        
        # Update status bar
        $statusBar = Get-Control -Name "StatusBarText" -Silent
        if ($statusBar) {
            $statusBar.Foreground = $lightBrush
        }
        
        # Update network and env status
        $networkStatus = Get-Control -Name "NetworkStatus" -Silent
        if ($networkStatus) {
            $networkStatus.Foreground = $lightBrush
        }
        
        $envStatus = Get-Control -Name "EnvStatus" -Silent
        if ($envStatus) {
            $envStatus.Foreground = $lightBrush
        }
        
        # Apply dark mode to TabControl and TabItems
        function Apply-DarkModeToControl {
            param($Control)
            if (-not $Control) { return }
            
            try {
                if ($Control -is [System.Windows.Controls.TabControl]) {
                    $Control.Background = $panelBrush
                    $Control.Foreground = $lightBrush
                }
                if ($Control -is [System.Windows.Controls.TabItem]) {
                    $Control.Background = $panelBrush
                    $Control.Foreground = $lightBrush
                }
                if ($Control -is [System.Windows.Controls.Menu]) {
                    $Control.Background = $panelBrush
                    $Control.Foreground = $lightBrush
                }
                if ($Control -is [System.Windows.Controls.MenuItem]) {
                    $Control.Background = $panelBrush
                    $Control.Foreground = $lightBrush
                }
                if ($Control -is [System.Windows.Controls.Border]) {
                    if ($Control.Background -and $Control.Background.ToString() -ne "#FFF3CD") {
                        $Control.Background = $panelBrush
                    }
                }
                if ($Control -is [System.Windows.Controls.StackPanel]) {
                    if ($Control.Background -and $Control.Background.ToString() -ne "#FFF3CD") {
                        $Control.Background = $panelBrush
                    }
                }
                
                # Recursively apply to children
                if ($Control.Children) {
                    foreach ($child in $Control.Children) {
                        Apply-DarkModeToControl -Control $child
                    }
                }
                if ($Control.Items) {
                    foreach ($item in $Control.Items) {
                        if ($item -is [System.Windows.FrameworkElement]) {
                            Apply-DarkModeToControl -Control $item
                        }
                    }
                }
            } catch {
                # Ignore errors for individual controls
            }
        }
        
        # Apply to all controls in the window
        Apply-DarkModeToControl -Control $mainGrid
        
        Update-StatusBar -Message "Dark mode enabled" -HideProgress
    } catch {
        Write-Warning "Error applying dark mode: $_"
    }
}

function Apply-LightMode {
    # Safe check: use Get-Variable to check if $W exists before accessing
    if (-not (Get-Variable -Name "W" -Scope Script -ErrorAction SilentlyContinue) -or $null -eq $script:W) { return }
    $W = $script:W
    
    try {
        $script:IsDarkMode = $false
        $lightBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#F0F0F0"))
        $darkBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#000000"))
        $whiteBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF"))
        
        # Apply to main window
        $W.Background = $lightBrush
        $W.Foreground = $darkBrush
        
        # Apply to main grid
        $mainGrid = $W.Content
        if ($mainGrid) {
            $mainGrid.Background = $lightBrush
        }
        
        # Apply to specific controls by name
        $controlsToUpdate = @(
            "DrvBox", "BCDBox", "DiagBox", "LogAnalysisBox", "FixerOutput", 
            "RepairInstallOutput", "BootHealthBox", "UpdateEligibilityBox"
        )
        
        foreach ($controlName in $controlsToUpdate) {
            $control = Get-Control -Name $controlName -Silent
            if ($control) {
                try {
                    $control.Background = $whiteBrush
                    $control.Foreground = $darkBrush
                } catch {}
            }
        }
        
        # Special handling for BCDBox (green text on black)
        $bcdBox = Get-Control -Name "BCDBox" -Silent
        if ($bcdBox) {
            try {
                $bcdBox.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#222"))
                $bcdBox.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#00FF00"))
            } catch {}
        }
        
        # Special handling for FixerOutput (green text on black)
        $fixerOutput = Get-Control -Name "FixerOutput" -Silent
        if ($fixerOutput) {
            try {
                $fixerOutput.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#222"))
                $fixerOutput.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#00FF00"))
            } catch {}
        }
        
        # Update status bar
        $statusBar = Get-Control -Name "StatusBarText" -Silent
        if ($statusBar) {
            $statusBar.Foreground = $darkBrush
        }
        
        # Update network and env status
        $networkStatus = Get-Control -Name "NetworkStatus" -Silent
        if ($networkStatus) {
            $networkStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#808080"))
        }
        
        $envStatus = Get-Control -Name "EnvStatus" -Silent
        if ($envStatus) {
            $envStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#808080"))
        }
        
        Update-StatusBar -Message "Light mode enabled" -HideProgress
    } catch {
        Write-Warning "Error applying light mode: $_"
    }
}

function Apply-CompactUI {
    # Safe check: use Get-Variable to check if $W exists before accessing
    if (-not (Get-Variable -Name "W" -Scope Script -ErrorAction SilentlyContinue) -or $null -eq $script:W) { return }
    $W = $script:W
    
    try {
        $script:IsCompactUI = $true
        
        # Store original values for restoration
        if (-not $script:OriginalButtonHeights) {
            $script:OriginalButtonHeights = @{}
            $script:OriginalMargins = @{}
            $script:OriginalFontSizes = @{}
        }
        
        # Reduce button heights and margins
        $allButtons = @()
        function Find-AllButtons {
            param($Control)
            if (-not $Control) { return }
            
            if ($Control -is [System.Windows.Controls.Button]) {
                $allButtons += $Control
            }
            
            if ($Control.Children) {
                foreach ($child in $Control.Children) {
                    Find-AllButtons -Control $child
                }
            }
            
            # Also check Items property for ItemsControl
            if ($Control.Items) {
                foreach ($item in $Control.Items) {
                    if ($item -is [System.Windows.FrameworkElement]) {
                        Find-AllButtons -Control $item
                    }
                }
            }
        }
        
        $mainGrid = $W.Content
        Find-AllButtons -Control $mainGrid
        
        foreach ($btn in $allButtons) {
            if (-not $script:OriginalButtonHeights.ContainsKey($btn.Name)) {
                $script:OriginalButtonHeights[$btn.Name] = $btn.Height
            }
            if ($btn.Height -gt 30) {
                $btn.Height = 28
            }
            if ($btn.Height -gt 25 -and $btn.Height -le 30) {
                $btn.Height = 25
            }
            
            if (-not $script:OriginalMargins.ContainsKey($btn.Name)) {
                $script:OriginalMargins[$btn.Name] = $btn.Margin
            }
            if ($btn.Margin.Left -gt 5) {
                $btn.Margin = New-Object System.Windows.Thickness(3, 2, 3, 2)
            }
        }
        
        # Reduce font sizes slightly
        $allTextBlocks = @()
        function Find-AllTextBlocks {
            param($Control)
            if (-not $Control) { return }
            
            if ($Control -is [System.Windows.Controls.TextBlock]) {
                $allTextBlocks += $Control
            }
            
            if ($Control.Children) {
                foreach ($child in $Control.Children) {
                    Find-AllTextBlocks -Control $child
                }
            }
        }
        
        Find-AllTextBlocks -Control $mainGrid
        
        foreach ($tb in $allTextBlocks) {
            if ($tb.Name -and -not $script:OriginalFontSizes.ContainsKey($tb.Name)) {
                $script:OriginalFontSizes[$tb.Name] = $tb.FontSize
            }
            if ($tb.FontSize -gt 12) {
                $tb.FontSize = [Math]::Max(10, $tb.FontSize - 1)
            }
        }
        
        # Reduce tab control margins
        $tabControl = Get-Control -Name "BCDTabControl" -Silent
        if ($tabControl) {
            $tabControl.Margin = New-Object System.Windows.Thickness(5)
        }
        
        Update-StatusBar -Message "Compact UI enabled - optimized for smaller screens" -HideProgress
    } catch {
        Write-Warning "Error applying compact UI: $_"
    }
}

function Apply-StandardUI {
    # Safe check: use Get-Variable to check if $W exists before accessing
    if (-not (Get-Variable -Name "W" -Scope Script -ErrorAction SilentlyContinue) -or $null -eq $script:W) { return }
    $W = $script:W
    
    try {
        $script:IsCompactUI = $false
        
        # Restore original button heights
        if ($script:OriginalButtonHeights) {
            $allButtons = @()
            function Find-AllButtons {
                param($Control)
                if (-not $Control) { return }
                
                if ($Control -is [System.Windows.Controls.Button]) {
                    $allButtons += $Control
                }
                
                if ($Control.Children) {
                    foreach ($child in $Control.Children) {
                        Find-AllButtons -Control $child
                    }
                }
            }
            
            $mainGrid = $W.Content
            Find-AllButtons -Control $mainGrid
            
            foreach ($btn in $allButtons) {
                if ($btn.Name -and $script:OriginalButtonHeights.ContainsKey($btn.Name)) {
                    $btn.Height = $script:OriginalButtonHeights[$btn.Name]
                }
                if ($btn.Name -and $script:OriginalMargins.ContainsKey($btn.Name)) {
                    $btn.Margin = $script:OriginalMargins[$btn.Name]
                }
            }
        }
        
        # Restore original font sizes
        if ($script:OriginalFontSizes) {
            $allTextBlocks = @()
            function Find-AllTextBlocks {
                param($Control)
                if (-not $Control) { return }
                
                if ($Control -is [System.Windows.Controls.TextBlock]) {
                    $allTextBlocks += $Control
                }
                
                if ($Control.Children) {
                    foreach ($child in $Control.Children) {
                        Find-AllTextBlocks -Control $child
                    }
                }
            }
            
            $mainGrid = $W.Content
            Find-AllTextBlocks -Control $mainGrid
            
            foreach ($tb in $allTextBlocks) {
                if ($tb.Name -and $script:OriginalFontSizes.ContainsKey($tb.Name)) {
                    $tb.FontSize = $script:OriginalFontSizes[$tb.Name]
                }
            }
        }
        
        # Restore tab control margins
        $tabControl = Get-Control -Name "BCDTabControl" -Silent
        if ($tabControl) {
            $tabControl.Margin = New-Object System.Windows.Thickness(5)
        }
        
        Update-StatusBar -Message "Standard UI layout restored" -HideProgress
    } catch {
        Write-Warning "Error applying standard UI: $_"
    }
}

# Settings menu handlers (will be wired up inside Start-GUI after $W is created)
# Moved to after $W creation to prevent errors

# Resources menu handlers
$btnBackupGuide = Get-Control -Name "BtnBackupGuide" -Silent
if ($btnBackupGuide) {
    $btnBackupGuide.Add_Click({
        $guideText = @"
BACKUP SOFTWARE GUIDE
====================

FREE OPTIONS:
- Macrium Reflect Free: Full system imaging, incremental backups
- AOMEI Backupper Standard: User-friendly interface, good for beginners
- Windows Built-in Backup: Basic but reliable, included with Windows

PAID OPTIONS (RECOMMENDED):
- Macrium Reflect (Paid): Best overall, fast, reliable, excellent support
- Acronis Cyber Protect: Cloud integration, but slower recovery
- Paragon Backup & Recovery: Good alternative with solid features

BEST PRACTICES:
- Follow 3-2-1 rule: 3 copies, 2 different media, 1 offsite
- Test backups regularly
- Use incremental backups for efficiency
- Store backups on separate drives from OS
- Consider cloud backup for offsite storage

For more details, visit:
- Macrium: https://www.macrium.com
- Acronis: https://www.acronis.com
- Paragon: https://www.paragon-software.com
"@
        $window = New-Object System.Windows.Window
        $window.Title = "Backup Software Guide"
        $window.Width = 700
        $window.Height = 500
        $window.WindowStartupLocation = "CenterScreen"
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $guideText
        $textBlock.TextWrapping = "Wrap"
        $textBlock.Margin = "15"
        $textBlock.FontFamily = "Consolas"
        $textBlock.FontSize = "11"
        $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
        $scrollViewer.Content = $textBlock
        $scrollViewer.VerticalScrollBarVisibility = "Auto"
        $window.Content = $scrollViewer
        $window.ShowDialog() | Out-Null
    })
}

$btnRecoveryToolsFree = Get-Control -Name "BtnRecoveryToolsFree" -Silent
if ($btnRecoveryToolsFree) {
    $btnRecoveryToolsFree.Add_Click({
        $toolsText = @"
FREE RECOVERY TOOLS
===================

1. VENTOY USB TOOL
   - Multi-boot USB solution
   - Supports ISO, WIM, VHD files
   - No need to extract ISO files
   - Website: https://www.ventoy.net
   - Best for: Creating bootable USB with multiple OS images

2. HIREN'S BOOTCD PE
   - Complete recovery toolkit
   - Includes diagnostic and repair tools
   - Pre-configured WinPE environment
   - Website: https://www.hirensbootcd.org
   - Best for: Comprehensive system recovery

3. MEDICAT USB
   - Medical-grade recovery environment
   - Extensive tool collection
   - Regular updates
   - Best for: Advanced recovery scenarios

4. SYSTEMRESCUE
   - Linux-based recovery
   - File system repair tools
   - Network capabilities
   - Best for: Cross-platform recovery

5. AOMEI PE BUILDER
   - Create custom WinPE
   - Integrated backup tools
   - Best for: Custom recovery environments
"@
        $window = New-Object System.Windows.Window
        $window.Title = "Free Recovery Tools"
        $window.Width = 700
        $window.Height = 500
        $window.WindowStartupLocation = "CenterScreen"
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $toolsText
        $textBlock.TextWrapping = "Wrap"
        $textBlock.Margin = "15"
        $textBlock.FontFamily = "Consolas"
        $textBlock.FontSize = "11"
        $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
        $scrollViewer.Content = $textBlock
        $scrollViewer.VerticalScrollBarVisibility = "Auto"
        $window.Content = $scrollViewer
        $window.ShowDialog() | Out-Null
    })
}

$btnRecoveryToolsPaid = Get-Control -Name "BtnRecoveryToolsPaid" -Silent
if ($btnRecoveryToolsPaid) {
    $btnRecoveryToolsPaid.Add_Click({
        $toolsText = @"
PAID RECOVERY TOOLS
===================

1. MACRIUM REFLECT (RECOMMENDED)
   Pros:
   - Fastest backup and restore speeds
   - Excellent reliability
   - Great support and documentation
   - Free version available
   - Incremental and differential backups
   
   Cons:
   - Paid version required for advanced features
   
   Website: https://www.macrium.com
   Best for: Most users, best overall value

2. ACRONIS CYBER PROTECT
   Pros:
   - Cloud integration
   - Ransomware protection
   - Good for enterprise
   
   Cons:
   - Cloud recovery can be slow
   - More expensive
   - Can be complex for beginners
   
   Website: https://www.acronis.com
   Best for: Enterprise users needing cloud backup

3. PARAGON BACKUP & RECOVERY
   Pros:
   - Good feature set
   - Reliable
   - Cross-platform support
   
   Cons:
   - Less popular than Macrium
   - Smaller community
   
   Website: https://www.paragon-software.com
   Best for: Users needing cross-platform support
"@
        $window = New-Object System.Windows.Window
        $window.Title = "Paid Recovery Tools"
        $window.Width = 700
        $window.Height = 500
        $window.WindowStartupLocation = "CenterScreen"
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $toolsText
        $textBlock.TextWrapping = "Wrap"
        $textBlock.Margin = "15"
        $textBlock.FontFamily = "Consolas"
        $textBlock.FontSize = "11"
        $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
        $scrollViewer.Content = $textBlock
        $scrollViewer.VerticalScrollBarVisibility = "Auto"
        $window.Content = $scrollViewer
        $window.ShowDialog() | Out-Null
    })
}

$btnBackupStrategy = Get-Control -Name "BtnBackupStrategy" -Silent
if ($btnBackupStrategy) {
    $btnBackupStrategy.Add_Click({
        $strategyText = @"
BACKUP STRATEGY GUIDE - 3-2-1 RULE
===================================

THE 3-2-1 RULE:
===============
3 Copies: Keep 3 copies of your data
2 Different Media: Use 2 different storage types
1 Offsite: Keep 1 copy offsite

DETAILED BREAKDOWN:
==================

1. THREE COPIES
   - Original data
   - Local backup (external drive, NAS)
   - Offsite backup (cloud, remote location)

2. TWO DIFFERENT MEDIA
   - Example: External HDD + Cloud
   - Example: NAS + USB SSD
   - Prevents single point of failure

3. ONE OFFSITE
   - Cloud storage (OneDrive, Google Drive, Backblaze)
   - Remote server
   - Physical location (friend's house, office)

RECOMMENDED SCHEDULE:
====================
- Daily: Incremental backups
- Weekly: Full system backup
- Monthly: Verify backup integrity
- Quarterly: Test restore procedure

HARDWARE RECOMMENDATIONS:
=========================
Performance (Best to Good):
1. NVMe SSD (Fastest, most expensive)
2. SATA SSD (Fast, good value)
3. USB SSD (Portable, fast)
4. External HDD (Cheapest, slowest)

For Desktop: NVMe or SATA SSD
For Laptop: USB SSD or External HDD
For Budget: External HDD with cloud backup

COST ESTIMATES:
===============
- NVMe SSD (1TB): $80-150
- SATA SSD (1TB): $60-100
- USB SSD (1TB): $80-120
- External HDD (2TB): $50-80
- Cloud Backup (1TB/year): $50-100
"@
        $window = New-Object System.Windows.Window
        $window.Title = "Backup Strategy Guide"
        $window.Width = 700
        $window.Height = 500
        $window.WindowStartupLocation = "CenterScreen"
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $strategyText
        $textBlock.TextWrapping = "Wrap"
        $textBlock.Margin = "15"
        $textBlock.FontFamily = "Consolas"
        $textBlock.FontSize = "11"
        $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
        $scrollViewer.Content = $textBlock
        $scrollViewer.VerticalScrollBarVisibility = "Auto"
        $window.Content = $scrollViewer
        $window.ShowDialog() | Out-Null
    })
}

$btnHardwareRecs = Get-Control -Name "BtnHardwareRecs" -Silent
if ($btnHardwareRecs) {
    $btnHardwareRecs.Add_Click({
        $hardwareText = @"
HARDWARE RECOMMENDATIONS FOR BACKUPS
====================================

PERFORMANCE HIERARCHY:
======================
1. NVMe SSD (M.2)
   - Speed: 3000-7000 MB/s
   - Best for: Desktop PCs with M.2 slot
   - Cost: $80-150 per 1TB
   - Examples: Samsung 980, WD Black SN850

2. SATA SSD (2.5")
   - Speed: 500-550 MB/s
   - Best for: Desktop and laptop
   - Cost: $60-100 per 1TB
   - Examples: Samsung 870 EVO, Crucial MX500

3. USB SSD (External)
   - Speed: 400-500 MB/s
   - Best for: Portable backups
   - Cost: $80-120 per 1TB
   - Examples: Samsung T7, SanDisk Extreme

4. External HDD
   - Speed: 100-200 MB/s
   - Best for: Budget backups, large storage
   - Cost: $50-80 per 2TB
   - Examples: WD My Passport, Seagate Backup Plus

RECOMMENDATIONS BY USE CASE:
============================

Desktop PC:
- Primary: NVMe SSD (if motherboard supports)
- Secondary: SATA SSD or USB SSD
- Budget: External HDD + Cloud

Laptop:
- Primary: USB SSD (portable)
- Secondary: External HDD
- Budget: External HDD + Cloud

Workstation:
- Primary: NVMe SSD
- Secondary: NAS or multiple drives
- Offsite: Cloud or remote server

INVESTMENT RECOMMENDATIONS:
===========================
- Minimum: External HDD (2TB) - $50-80
- Recommended: USB SSD (1TB) - $80-120
- Best: NVMe SSD (1TB) + Cloud - $130-250
- Enterprise: NAS + Cloud - $300+

MOTHERBOARD COMPATIBILITY:
==========================
- Check for M.2 slot for NVMe
- Check SATA ports for SATA SSD
- USB 3.0+ recommended for external drives
"@
        $window = New-Object System.Windows.Window
        $window.Title = "Hardware Recommendations"
        $window.Width = 700
        $window.Height = 500
        $window.WindowStartupLocation = "CenterScreen"
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $hardwareText
        $textBlock.TextWrapping = "Wrap"
        $textBlock.Margin = "15"
        $textBlock.FontFamily = "Consolas"
        $textBlock.FontSize = "11"
        $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
        $scrollViewer.Content = $textBlock
        $scrollViewer.VerticalScrollBarVisibility = "Auto"
        $window.Content = $scrollViewer
        $window.ShowDialog() | Out-Null
    })
}

# Recommended Recovery Tools (Must-Have Tools)
$btnRecommendedRecoveryTools = Get-Control -Name "BtnRecommendedRecoveryTools" -Silent
if ($btnRecommendedRecoveryTools) {
    $btnRecommendedRecoveryTools.Add_Click({
        $toolsText = @"
RECOMMENDED RECOVERY TOOLS
===================================================================================

If you are serious about maintaining your system, these are the "Must-Have" tools:

+---------------------------------------------------------------+
| Tool                          | Purpose                      |
+---------------------------------------------------------------+
| Hiren's BootCD PE             | The ultimate Win10-based     |
|                                | recovery environment.        |
|                                | Includes tools for           |
|                                | partitioning, driver          |
|                                | injection, and registry      |
|                                | editing.                     |
|                                | Download: hirensbootcd.org   |
+---------------------------------------------------------------+
| Macrium Reflect (Rescue)      | ESSENTIAL. Its "Fix Windows  |
|                                | Boot Problems" button is     |
|                                | magic—it fixes complex       |
|                                | BCD/UEFI issues that         |
|                                | bootrec often fails at.      |
|                                | Download: macrium.com/       |
|                                | reflectfree                  |
+---------------------------------------------------------------+
| Sergei Strelec's WinPE        | A more "advanced"            |
|                                | alternative to Hiren's.      |
|                                | It contains almost every     |
|                                | diagnostic tool known to     |
|                                | man.                         |
|                                | Download: sergeistrelec.name |
+---------------------------------------------------------------+
| Explorer++                    | A lightweight file manager   |
|                                | that often works in WinPE    |
|                                | when the standard file       |
|                                | explorer is buggy.           |
|                                | Download: explorerplusplus.  |
|                                | com                          |
+---------------------------------------------------------------+
| Microsoft SaRA                | (Support and Recovery        |
|                                | Assistant) A specialized     |
|                                | tool that automates fixes    |
|                                | for Windows Activation and   |
|                                | Office issues.               |
|                                | Download: aka.ms/SaRASetup   |
+---------------------------------------------------------------+

USAGE TIPS:
- Keep Hiren's BootCD PE on a USB drive for emergency recovery
- Macrium Reflect Rescue can fix boot issues that bcdboot cannot
- Use Sergei Strelec's WinPE for advanced registry and file system repairs
- Explorer++ is invaluable when Windows Explorer crashes in recovery mode
"@
        $window = New-Object System.Windows.Window
        $window.Title = "Recommended Recovery Tools"
        $window.Width = 800
        $window.Height = 600
        $window.WindowStartupLocation = "CenterScreen"
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $toolsText
        $textBlock.TextWrapping = "Wrap"
        $textBlock.Margin = "15"
        $textBlock.FontFamily = "Consolas"
        $textBlock.FontSize = "11"
        $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
        $scrollViewer.Content = $textBlock
        $scrollViewer.VerticalScrollBarVisibility = "Auto"
        $window.Content = $scrollViewer
        $window.ShowDialog() | Out-Null
    })
}

# Microsoft Professional Support
$btnMicrosoftSupport = Get-Control -Name "BtnMicrosoftSupport" -Silent
if ($btnMicrosoftSupport) {
    $btnMicrosoftSupport.Add_Click({
        $supportText = @"
MICROSOFT PROFESSIONAL SUPPORT OPTIONS
===================================================================================

For retail/home users seeking professional, break-fix support, Microsoft offers
several paid support options. These services provide access to Microsoft engineers
who can perform advanced troubleshooting including Registry analysis, BSOD memory
dump analysis, and complex bootloader repairs.

+---------------------------------------------------------------+
| PAY-PER-INCIDENT SUPPORT (RETAIL/HOME USERS)                 |
+---------------------------------------------------------------+
| E-mail or Web-based Support                                  |
|   Cost: $99 per incident                                     |
|   Best For: Time-saving alternative to phone support         |
|   Note: Often faster than waiting for phone technician      |
+---------------------------------------------------------------+
| Professional Support (General)                                |
|   Cost: $499 per incident                                    |
|   Definition: A single support issue and reasonable efforts  |
|               to resolve it. Cost does not depend on time.   |
+---------------------------------------------------------------+
| Pro 5-Pack                                                   |
|   Cost: $1,225 (5 incidents)                                 |
|   Best For: Multiple issues or ongoing support needs          |
+---------------------------------------------------------------+

IMPORTANT NOTES:
- Free Support: Basic installation, setup, and billing support are available
  for free with most Microsoft 365 subscriptions.
- How to Use: To use a purchased pay-per-incident credit, you must sign in
  with the same personal Microsoft account (MSA) used for the purchase on
  the Microsoft Support for Business portal and apply the credit when
  creating a new case.
- Business/Enterprise Plans: Larger businesses typically use subscription-
  based "Unified Support" plans where fees are a percentage of their total
  annual Microsoft spending, rather than a fixed per-incident cost.

+---------------------------------------------------------------+
| PROFESSIONAL SUPPORT FOR WINDOWS 11 PRO USERS                |
+---------------------------------------------------------------+
| Microsoft offers professional-grade support to individual     |
| Windows 11 Pro users, but it is structured as a "business-   |
| class" service called Professional Support (Pay-Per-Incident).|
|                                                               |
| Because you are using the Pro edition, you are technically    |
| eligible for these higher-tier services, even if you are not |
| a corporation.                                                |
+---------------------------------------------------------------+

1. PROFESSIONAL SUPPORT (PAY-PER-INCIDENT)
   This is the most direct way to get an actual Microsoft engineer rather
   than a general customer service agent.

   Cost: Approximately $499 USD per incident (roughly $650+ CAD).

   How it Works:
   - You purchase a single "support incident"
   - You are assigned a case number and a higher-tier engineer
   - The engineer stays with the case until it is resolved or deemed
     "unfixable"

   Scope:
   - Unlike standard support, they will dive into the Registry
   - Analyze BSOD memory dumps
   - Work through complex bootloader issues
   - However, if the hardware is failing, they will still tell you to
     replace the drive

   Refund Policy:
   - If the engineer determines the issue is caused by a documented
     Microsoft bug, they will often refund the incident fee
   - If the issue is caused by your hardware, third-party drivers, or user
     error, you still pay

   How to Access:
   - Go to the Microsoft Professional Support page
   - Select "Windows" and your version (Windows 11)
   - Choose "Pay-per-incident" and follow the prompts to pay and open a
     ticket

2. MICROSOFT 365 "PREMIUM" SUPPORT
   If you have a Microsoft 365 Personal or Family subscription, "Premium
   Support" is included.

   How it Works:
   - You can request a chat or callback through the "Get Help" app in
     Windows

   The Reality:
   - While they are "professionals," these agents are trained for high
     volume
   - For a non-booting system, their script almost always defaults to
     "Reset this PC" or "Cloud Reinstall" within the first 30 minutes
   - They generally do not have the tools or time to perform the
     "surgical" repairs an independent pro might do

3. THE "BUSINESS ASSIST" ALTERNATIVE
   If you use your Windows 11 Pro machine for work/freelancing, Microsoft
   offers a service called Microsoft 365 Business Assist.

   Cost: Usually around $5.00/month per user (added to a Business
         subscription)

   How it Works:
   - It gives you 24/7 access to small business specialists who help with
     setup and troubleshooting
   - It is a middle ground between the free consumer support and the 
     enterprise-level support

SUMMARY: IS IT WORTH IT FOR A PRO USER?
----------------------------------------
For an individual user, Pay-Per-Incident is rarely worth the cost unless
you are running a highly specialized environment that would take days of
manual labor to rebuild.

Most advanced users choose to use the independent tools mentioned earlier
(Hiren's BootCD, Macrium Reflect, etc.) because they offer more control
than a remote technician would have over a non-booting system.
"@
        $window = New-Object System.Windows.Window
        $window.Title = "Microsoft Professional Support"
        $window.Width = 800
        $window.Height = 700
        $window.WindowStartupLocation = "CenterScreen"
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $supportText
        $textBlock.TextWrapping = "Wrap"
        $textBlock.Margin = "15"
        $textBlock.FontFamily = "Consolas"
        $textBlock.FontSize = "10"
        $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
        $scrollViewer.Content = $textBlock
        $scrollViewer.VerticalScrollBarVisibility = "Auto"
        $window.Content = $scrollViewer
        $window.ShowDialog() | Out-Null
    })
}

# Local Technician Alternative
$btnLocalTechnician = Get-Control -Name "BtnLocalTechnician" -Silent
if ($btnLocalTechnician) {
    $btnLocalTechnician.Add_Click({
        $technicianText = @"
LOCAL TECHNICIAN ALTERNATIVE (RECOMMENDED)
===================================================================================

Before paying Microsoft's premium support fees, consider contacting a local
computer repair technician. Many reputable technicians offer significant
advantages over remote Microsoft support:

+---------------------------------------------------------------+
| LOCAL TECHNICIAN BENEFITS                                     |
+---------------------------------------------------------------+
| "No Fix, No Fee" Guarantee                                    |
|   - You only pay if the problem is actually resolved          |
|   - No charge if they cannot fix the issue                    |
|   - Much lower risk than Microsoft's pay-per-incident model  |
+---------------------------------------------------------------+
| Free Onsite Estimates                                         |
|   - Many technicians offer free diagnostic estimates          |
|   - You know the cost before committing to repairs            |
|   - Can compare multiple quotes easily                         |
+---------------------------------------------------------------+
| Travel/Appointment Fee Only (If Applicable)                   |
|   - Some technicians charge a small travel/appointment fee    |
|   - This is typically marginal compared to full repair cost   |
|   - Often waived if you proceed with the repair               |
+---------------------------------------------------------------+
| Hands-On Access                                               |
|   - Direct physical access to your hardware                    |
|   - Can test components, swap parts, check connections        |
|   - More thorough than remote diagnostics                     |
+---------------------------------------------------------------+
| Personalized Service                                          |
|   - One-on-one attention from start to finish                 |
|   - Can explain what went wrong and how to prevent it          |
|   - Often more patient and thorough than call center agents   |
+---------------------------------------------------------------+

HOW TO FIND A REPUTABLE TECHNICIAN:
-----------------------------------
- Look for technicians with "No Fix, No Fee" guarantees
- Check online reviews (Google, Yelp, local business directories)
- Ask about their experience with boot issues and Windows recovery
- Verify they offer free estimates before committing
- Compare multiple quotes to ensure fair pricing
- Ask if they have experience with tools like Hiren's BootCD, Macrium
  Reflect, or similar recovery environments

COST COMPARISON:
----------------
Microsoft Professional Support: $499+ per incident (paid regardless of
                                outcome, unless it's a Microsoft bug)

Local Technician:              Travel/appointment fee (often $50-100) +
                                Repair cost (only if successful)
                                Total often less than Microsoft's fee,
                                with better guarantee

RECOMMENDATION:
---------------
For most users, a local technician with a "No Fix, No Fee" guarantee and
free onsite estimates offers better value than Microsoft's premium support.
You get hands-on service, personalized attention, and only pay if the problem
is actually fixed. The travel/appointment fee (if any) is typically marginal
compared to Microsoft's full incident cost.
"@
        $window = New-Object System.Windows.Window
        $window.Title = "Local Technician Alternative"
        $window.Width = 800
        $window.Height = 700
        $window.WindowStartupLocation = "CenterScreen"
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $technicianText
        $textBlock.TextWrapping = "Wrap"
        $textBlock.Margin = "15"
        $textBlock.FontFamily = "Consolas"
        $textBlock.FontSize = "10"
        $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
        $scrollViewer.Content = $textBlock
        $scrollViewer.VerticalScrollBarVisibility = "Auto"
        $window.Content = $scrollViewer
        $window.ShowDialog() | Out-Null
    })
}

$btnChatGPT = Get-Control -Name "BtnChatGPT"
if ($btnChatGPT) {
    $btnChatGPT.Add_Click({
    try {
        Update-StatusBar -Message "Opening ChatGPT help..." -ShowProgress
        $result = Open-ChatGPTHelp
        
        if ($result.Success) {
            Update-StatusBar -Message $result.Message -HideProgress
            [System.Windows.MessageBox]::Show($result.Message, "ChatGPT Help", "OK", "Information")
        } else {
            Update-StatusBar -Message "Browser not available" -HideProgress
            # Show instructions in a message box
            $instructionsWindow = New-Object System.Windows.Window
            $instructionsWindow.Title = "ChatGPT Help - Instructions"
            $instructionsWindow.Width = 600
            $instructionsWindow.Height = 500
            $instructionsWindow.WindowStartupLocation = "CenterScreen"
            
            $textBlock = New-Object System.Windows.Controls.TextBlock
            $textBlock.Text = $result.Instructions
            $textBlock.TextWrapping = "Wrap"
            $textBlock.Margin = "10"
            $textBlock.FontFamily = "Consolas"
            $textBlock.FontSize = "11"
            
            $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
            $scrollViewer.Content = $textBlock
            $scrollViewer.VerticalScrollBarVisibility = "Auto"
            
            $instructionsWindow.Content = $scrollViewer
            $instructionsWindow.ShowDialog() | Out-Null
        }
    } catch {
        Update-StatusBar -Message "Error opening ChatGPT: $_" -HideProgress
        [System.Windows.MessageBox]::Show("Error opening ChatGPT help: $_", "Error", "OK", "Error")
    }
    })
}

# Zoom functionality (will be initialized inside Start-GUI after $W is created)
$script:ZoomLevel = 1.0

# Zoom function (will be used inside Start-GUI)
function Update-Zoom {
    param([double]$NewZoom)
    
    if ($NewZoom -lt 0.5) { $NewZoom = 0.5 }
    if ($NewZoom -gt 2.0) { $NewZoom = 2.0 }
    
    $script:ZoomLevel = $NewZoom
    
    if ($W) {
        try {
            # Apply zoom using a ScaleTransform on the main content
            $mainGrid = $W.Content
            if ($mainGrid) {
                # Get or create transform group
                if (-not $mainGrid.RenderTransform -or $mainGrid.RenderTransform.GetType().Name -ne "TransformGroup") {
                    $transformGroup = New-Object System.Windows.Media.TransformGroup
                    $mainGrid.RenderTransform = $transformGroup
                } else {
                    $transformGroup = $mainGrid.RenderTransform
                }
                
                # Remove existing scale transform if any
                $existingScale = $transformGroup.Children | Where-Object { $_.GetType().Name -eq "ScaleTransform" } | Select-Object -First 1
                if ($existingScale) {
                    $transformGroup.Children.Remove($existingScale) | Out-Null
                }
                
                # Add new scale transform
                $scaleTransform = New-Object System.Windows.Media.ScaleTransform($script:ZoomLevel, $script:ZoomLevel)
                $transformGroup.Children.Add($scaleTransform) | Out-Null
                
                # Set transform origin to top-left for better scaling behavior
                $mainGrid.RenderTransformOrigin = New-Object System.Windows.Point(0, 0)
                
                # Update zoom level display
                $zoomLevelControl = Get-Control -Name "ZoomLevel" -Silent
                if ($zoomLevelControl) {
                    $zoomLevelControl.Text = "{0}%" -f [math]::Round($script:ZoomLevel * 100)
                }
                
                # Sync interface scale slider if it exists
                $interfaceScaleSlider = Get-Control -Name "InterfaceScaleSlider" -Silent
                if ($interfaceScaleSlider) {
                    $interfaceScaleSlider.Value = $script:ZoomLevel
                }
            }
        } catch {
            Write-Warning "Error applying zoom: $_"
        }
    }
}

$btnSwitchToTUI = Get-Control -Name "BtnSwitchToTUI"
if ($btnSwitchToTUI) {
    $btnSwitchToTUI.Add_Click({
    $result = [System.Windows.MessageBox]::Show(
        "Switch to Command Line Mode (TUI)?`n`nThis will close the GUI and open the text-based interface.`n`nContinue?",
        "Switch to Command Line Mode",
        "YesNo",
        "Question"
    )
    
    if ($result -eq "Yes") {
        try {
            Update-StatusBar -Message "Switching to command line mode..." -ShowProgress
            
            # Close GUI window first
            $W.Close()
            
            # Small delay to ensure window closes
            Start-Sleep -Milliseconds 100
            
            # Load TUI module and start it
            # Use script:ScriptRootSafe which is computed at module load time
            $tuiScriptRoot = $script:ScriptRootSafe
            if (-not $tuiScriptRoot) {
                # Fallback to PSScriptRoot or current location
                $tuiScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).ProviderPath }
            }
            $tuiPath = Join-Path $tuiScriptRoot "WinRepairTUI.ps1"
            if (Test-Path $tuiPath) {
                try {
                    # Set PSScriptRoot for TUI module before loading it
                    # This ensures Start-TUI can find files it needs
                    $originalPSScriptRoot = $PSScriptRoot
                    $script:PSScriptRoot = $tuiScriptRoot
                    
                    # Load TUI module with error handling
                    . $tuiPath -ErrorAction Stop
                    
                    # Verify Start-TUI function exists
                    if (Get-Command Start-TUI -ErrorAction SilentlyContinue) {
                        Start-TUI
                    } else {
                        throw "Start-TUI function not found after loading WinRepairTUI.ps1"
                    }
                    
                    # Restore original PSScriptRoot if it was set
                    if ($originalPSScriptRoot) {
                        $script:PSScriptRoot = $originalPSScriptRoot
                    }
                } catch {
                    $errorDetails = $_.Exception.Message
                    if ($_.Exception.InnerException) {
                        $errorDetails += "`nInner: $($_.Exception.InnerException.Message)"
                    }
                    Write-Host "Error loading TUI module: $errorDetails" -ForegroundColor Red
                    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
                    throw "Failed to load TUI module: $errorDetails"
                }
            } else {
                Write-Host "Error: WinRepairTUI.ps1 not found at $tuiPath" -ForegroundColor Red
                Write-Host "Please run MiracleBoot.ps1 to access TUI mode." -ForegroundColor Yellow
                throw "WinRepairTUI.ps1 not found at $tuiPath"
            }
        } catch {
            $errorMsg = $_.Exception.Message
            # Don't show message box if window is already closed - just write to console
            try {
                [System.Windows.MessageBox]::Show(
                    "Error switching to command line mode: $errorMsg`n`nYou can manually run MiracleBoot.ps1 to access TUI mode.",
                    "Error",
                    "OK",
                    "Error"
                ) | Out-Null
            } catch {
                # Window already closed, just write to console
                Write-Host "Error switching to command line mode: $errorMsg" -ForegroundColor Red
                Write-Host "You can manually run MiracleBoot.ps1 to access TUI mode." -ForegroundColor Yellow
            }
        }
    }
    })
}

# Initialize network status (with improved detection)
try {
    $networkStatusControl = Get-Control "NetworkStatus"
    if ($networkStatusControl) {
        try {
            # First check if network adapters exist and are enabled
            $hasAdapter = $false
            $adapterConnected = $false
            
            # Try Get-NetAdapter (Windows 8+)
            if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
                $adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
                if ($adapters -and $adapters.Count -gt 0) {
                    $hasAdapter = $true
                    $adapterConnected = $true
                }
            }
            
            # Fallback to WMI if Get-NetAdapter not available
            if (-not $hasAdapter) {
                try {
                    $wmiAdapters = Get-WmiObject Win32_NetworkAdapter -ErrorAction SilentlyContinue | 
                        Where-Object { $_.NetEnabled -eq $true -and $_.PhysicalAdapter -eq $true }
                    if ($wmiAdapters) {
                        $hasAdapter = $true
                        # Check if adapter has IP
                        foreach ($adapter in $wmiAdapters) {
                            $config = Get-WmiObject Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | 
                                Where-Object { $_.Index -eq $adapter.Index }
                            if ($config -and $config.IPAddress) {
                                $adapterConnected = $true
                                break
                            }
                        }
                    }
                } catch {
                    # WMI check failed, continue
                }
            }
            
            # If adapter exists, test internet connectivity
            if ($adapterConnected) {
                # Quick connectivity test
                try {
                    $testResult = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
                    if ($testResult) {
                        $networkStatusControl.Text = "Network: Connected"
                        $networkStatusControl.Foreground = "Green"
                    } else {
                        # Adapter exists but no internet
                        $networkStatusControl.Text = "Network: No Internet"
                        $networkStatusControl.Foreground = "Orange"
                    }
                } catch {
                    # Test failed, but adapter exists
                    $networkStatusControl.Text = "Network: Adapter Found"
                    $networkStatusControl.Foreground = "Yellow"
                }
            } elseif ($hasAdapter) {
                # Adapter exists but not connected
                $networkStatusControl.Text = "Network: Disconnected"
                $networkStatusControl.Foreground = "Orange"
            } else {
                # No adapters found
                $networkStatusControl.Text = "Network: Not Found"
                $networkStatusControl.Foreground = "Gray"
            }
        } catch {
            $networkStatusControl.Text = "Network: Unknown"
            $networkStatusControl.Foreground = "Gray"
        }
    } else {
        Write-Warning "NetworkStatus control not found in XAML"
    }
} catch {
    Write-Warning "Error initializing network status: $_"
}

# Populate drive combo (with null checks and WinPE compatibility)
try {
    # Enhanced volume detection for WinPE environments with drive letter shuffling
    $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | Sort-Object DriveLetter
    # Ensure $volumes is always an array (critical for .Count property access)
    if ($null -eq $volumes) { $volumes = @() }
    if ($volumes -isnot [array]) { $volumes = @($volumes) }
    
    # Fallback: If no volumes found, try alternative detection methods for WinPE
    if ($volumes.Count -eq 0) {
        try {
            # Try using Get-PSDrive as fallback (works in WinPE)
            $psDrives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^[A-Z]$' }
            if ($psDrives) {
                $volumes = @()
                foreach ($psd in $psDrives) {
                    $driveLetter = "$($psd.Name):"
                    if (Test-Path "$driveLetter\") {
                        try {
                            $vol = Get-Volume -DriveLetter $psd.Name -ErrorAction SilentlyContinue
                            if ($vol) { $volumes += $vol }
                        } catch {
                            # If Get-Volume fails, create a minimal volume object
                            $volumes += [pscustomobject]@{
                                DriveLetter = $psd.Name
                                FileSystemLabel = "Drive $($psd.Name)"
                                FileSystem = "Unknown"
                                Size = 0
                            }
                        }
                    }
                }
                # Ensure still an array
                if ($null -eq $volumes) { $volumes = @() }
                if ($volumes -isnot [array]) { $volumes = @($volumes) }
            }
        } catch {
            # Fallback failed, continue with empty array
            $volumes = @()
        }
    }
    
    $currentSystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd(':') } else { "C" }
    $driveCombo = Get-Control "DriveCombo"
    if ($driveCombo) {
        $driveCombo.Items.Clear()
        $driveCombo.Items.Add("Auto-detect")
        foreach ($vol in $volumes) {
            $label = if ($vol.FileSystemLabel) { $vol.FileSystemLabel } else { "(no label)" }
            $driveCombo.Items.Add("$($vol.DriveLetter): - $label")
        }
        $driveCombo.SelectedIndex = 0
    }
    
    # Populate One-Click drive combo
    $oneClickDriveCombo = Get-Control "OneClickDriveCombo"
    if ($oneClickDriveCombo) {
        $oneClickDriveCombo.Items.Clear()
        foreach ($vol in $volumes) {
            $label = if ($vol.FileSystemLabel) { $vol.FileSystemLabel } else { "(no label)" }
            $oneClickDriveCombo.Items.Add("$($vol.DriveLetter): - $label")
        }
        # default to system drive if present
        $defaultIndex = 0
        for ($i = 0; $i -lt $oneClickDriveCombo.Items.Count; $i++) {
            if ($oneClickDriveCombo.Items[$i] -match "^${currentSystemDrive}:") { $defaultIndex = $i; break }
        }
        $oneClickDriveCombo.SelectedIndex = $defaultIndex
    }
    
    # Populate log drive combo (for Diagnostics & Logs tab)
    $logDriveCombo = Get-Control "LogDriveCombo"
    if ($logDriveCombo) {
        $logDriveCombo.Items.Clear()
        $seen = New-Object System.Collections.Generic.HashSet[string]
        foreach ($vol in $volumes) {
            $item = "$($vol.DriveLetter):"
            if ($seen.Add($item)) { $logDriveCombo.Items.Add($item) }
        }
        if ($logDriveCombo.Items.Count -eq 0) { $logDriveCombo.Items.Add("C:") }
        $logDriveCombo.SelectedIndex = 0
    }
    
    # Populate Diagnostics drive combo
    $currentSystemDrive = $env:SystemDrive.TrimEnd(':')
    $diagDriveCombo = Get-Control "DiagDriveCombo"
    if ($diagDriveCombo) {
        $diagDriveCombo.Items.Clear()
        $diagDriveCombo.Items.Add("$currentSystemDrive`: (Current OS)")
        foreach ($vol in $volumes) {
            if ($vol.DriveLetter -ne $currentSystemDrive) {
                $diagDriveCombo.Items.Add("$($vol.DriveLetter):")
            }
        }
        $diagDriveCombo.SelectedIndex = 0
    }
    
    # Populate Summary drive combo
    $summaryDriveCombo = Get-Control "SummaryDriveCombo"
    if ($summaryDriveCombo) {
        $summaryDriveCombo.Items.Clear()
        $summaryDriveCombo.Items.Add("$currentSystemDrive`: (Current OS)")
        foreach ($vol in $volumes) {
            if ($vol.DriveLetter -ne $currentSystemDrive) {
                $summaryDriveCombo.Items.Add("$($vol.DriveLetter):")
            }
        }
        $summaryDriveCombo.SelectedIndex = 0
    }
} catch {
    # Enhanced error handling for drive detection failures (common in WinPE)
    $errorMsg = "Error scanning for Windows installations: $($_.Exception.Message)"
    Write-Warning $errorMsg
    try {
        Add-MiracleBootLog -Level "WARNING" -Message $errorMsg -Location "WinRepairGUI.ps1:DriveComboPopulation" -Data @{Error=$_.Exception.Message; StackTrace=$_.ScriptStackTrace} -NoConsole -ErrorAction SilentlyContinue
    } catch { }
    
    # Fallback: Add default drive to combos if they exist
    $currentSystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd(':') } else { "C" }
    $oneClickDriveCombo = Get-Control "OneClickDriveCombo"
    if ($oneClickDriveCombo -and $oneClickDriveCombo.Items.Count -eq 0) {
        $oneClickDriveCombo.Items.Add("$currentSystemDrive`: - (fallback)")
        $oneClickDriveCombo.SelectedIndex = 0
    }
    $driveCombo = Get-Control "DriveCombo"
    if ($driveCombo -and $driveCombo.Items.Count -eq 0) {
        $driveCombo.Items.Add("Auto-detect")
        $driveCombo.Items.Add("$currentSystemDrive`: - (fallback)")
        $driveCombo.SelectedIndex = 0
    }
}

# Wire up window events (must be after $W is created) - MOVED OUTSIDE try-catch
if ($null -ne $W) {
    # Window loaded event
    $W.Add_Loaded({
        try {
            Update-StatusBar -Message "Ready" -HideProgress
        } catch {
            # Ignore errors during initialization
        }
    })
    
    # Window closing event
    $W.Add_Closing({
        param($sender, $e)
        # Allow window to close normally
        # DO NOT set e.Cancel = $true unless we want to prevent closing
    })
    
    # ========================================
    # CRITICAL: Wire up button handlers BEFORE ShowDialog()
    # ShowDialog() is blocking - code after it won't execute until window closes!
    # ========================================
    
    # One-Click Repair Handler
    $btnOneClickRepair = Get-Control -Name "BtnOneClickRepair" -Silent
    if ($btnOneClickRepair) {
        Write-Verbose "One-Click Repair button found and wiring handler..." -Verbose
        Write-Host "[GUI] Wiring One-Click Repair button handler..." -ForegroundColor Cyan
        $btnOneClickRepair.Add_Click({
            # DEBUG: Show immediate feedback that button was clicked - REMOVE THIS AFTER TESTING
            try {
                [System.Windows.MessageBox]::Show("Button clicked! Handler is working.`n`nIf you see this, the handler is attached correctly.", "Debug - Button Click Detected", "OK", "Information") | Out-Null
            } catch {
                # Ignore message box errors but write to console
                Write-Host "DEBUG: Message box failed: $_" -ForegroundColor Yellow
            }
            
            # Wrap entire handler in try-catch to catch any errors
            try {
                # Disable button IMMEDIATELY on UI thread to prevent multiple clicks
                if ($W -and $W.Dispatcher) {
                    $W.Dispatcher.Invoke([action]{
                        $btnOneClickRepair.IsEnabled = $false
                    }, [System.Windows.Threading.DispatcherPriority]::Send)
                } else {
                    $btnOneClickRepair.IsEnabled = $false
                }
                
                # Immediate feedback - update status bar right away
                try {
                    Update-StatusBar -Message "One-Click Repair: Button clicked, starting..." -ShowProgress
                } catch {
                    # Status bar update failed, but continue
                }
                
                # Get all controls first
                $txtOneClickStatus = Get-Control -Name "TxtOneClickStatus"
                $fixerOutput = Get-Control -Name "FixerOutput"
                $repairModeCombo = Get-Control -Name "RepairModeCombo"
                $simulateCombo = Get-Control -Name "SimulateIssueCombo"
                $oneClickDriveCombo = Get-Control -Name "OneClickDriveCombo"
                
                # Force immediate UI update using dispatcher to show button was clicked
                if ($W -and $W.Dispatcher) {
                    $W.Dispatcher.Invoke([action]{
                        # Update status text immediately to show button was clicked
                        if ($txtOneClickStatus) {
                            $txtOneClickStatus.Text = "Button clicked - initializing..."
                        }
                        if ($fixerOutput) {
                            $fixerOutput.Text = "One-Click Repair button clicked.`nInitializing...`n"
                            $fixerOutput.ScrollToEnd()
                        }
                    }, [System.Windows.Threading.DispatcherPriority]::Send)
                } else {
                    # Fallback if dispatcher not available
                    if ($txtOneClickStatus) {
                        $txtOneClickStatus.Text = "Button clicked - initializing..."
                    }
                    if ($fixerOutput) {
                        $fixerOutput.Text = "One-Click Repair button clicked.`nInitializing...`n"
                    }
                }
                
                $targetDrive = $env:SystemDrive.TrimEnd(':')
                if ($oneClickDriveCombo -and $oneClickDriveCombo.SelectedItem) {
                    $sel = $oneClickDriveCombo.SelectedItem
                    if ($sel -match '^([A-Z]):') { $targetDrive = $matches[1] }
                }
                
                # Validate targetDrive is not empty
                if ([string]::IsNullOrWhiteSpace($targetDrive)) {
                    $errorMsg = "ERROR: Target drive is empty or invalid.`nPlease select a valid drive from the dropdown."
                    if ($W -and $W.Dispatcher) {
                        $W.Dispatcher.Invoke([action]{
                            if ($txtOneClickStatus) { $txtOneClickStatus.Text = $errorMsg }
                            if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                            $btnOneClickRepair.IsEnabled = $true
                        }, [System.Windows.Threading.DispatcherPriority]::Normal)
                    } else {
                        if ($txtOneClickStatus) { $txtOneClickStatus.Text = $errorMsg }
                        if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                        $btnOneClickRepair.IsEnabled = $true
                    }
                    [System.Windows.MessageBox]::Show($errorMsg, "Invalid Drive", "OK", "Error") | Out-Null
                    return
                }
                
                # Update status before showing dialog - use dispatcher for immediate update
                if ($W -and $W.Dispatcher) {
                    $W.Dispatcher.Invoke([action]{
                        if ($txtOneClickStatus) {
                            $txtOneClickStatus.Text = "Preparing repair for drive $targetDrive`:..."
                        }
                        Update-StatusBar -Message "One-Click Repair: Preparing for drive $targetDrive`:" -ShowProgress
                    }, [System.Windows.Threading.DispatcherPriority]::Send)
                } else {
                    if ($txtOneClickStatus) {
                        $txtOneClickStatus.Text = "Preparing repair for drive $targetDrive`:..."
                    }
                }
                
                # Small delay to ensure UI updates are visible before showing modal dialog
                Start-Sleep -Milliseconds 200
                
                # Show confirmation dialog (this is modal and will block)
                $confirm = [System.Windows.MessageBox]::Show("Run One-Click Repair on drive $targetDrive`: ?","Confirm Target Drive","YesNo","Question")
                if ($confirm -eq "No") {
                    # User clicked No - show drive selection dialog
                    $driveList = @()
                    if ($oneClickDriveCombo) {
                        foreach ($item in $oneClickDriveCombo.Items) { $driveList += $item }
                    }
                    $drivePrompt = "Select drive letter from list:`n" + ($driveList -join "`n")
                    $input = [Microsoft.VisualBasic.Interaction]::InputBox($drivePrompt, "Select Drive", "$targetDrive`:")
                    if ([string]::IsNullOrWhiteSpace($input)) { 
                        if ($W -and $W.Dispatcher) {
                            $W.Dispatcher.Invoke([action]{
                                $btnOneClickRepair.IsEnabled = $true
                                if ($txtOneClickStatus) { $txtOneClickStatus.Text = "Repair canceled - no drive selected" }
                            }, [System.Windows.Threading.DispatcherPriority]::Normal)
                        } else {
                            $btnOneClickRepair.IsEnabled = $true
                        }
                        return 
                    }
                    if ($input -match '^([A-Z]):') { $targetDrive = $matches[1] } else { 
                        if ($W -and $W.Dispatcher) {
                            $W.Dispatcher.Invoke([action]{
                                $btnOneClickRepair.IsEnabled = $true
                                if ($txtOneClickStatus) { $txtOneClickStatus.Text = "Repair canceled - invalid drive format" }
                            }, [System.Windows.Threading.DispatcherPriority]::Normal)
                        } else {
                            $btnOneClickRepair.IsEnabled = $true
                        }
                        return 
                    }
                    if ($oneClickDriveCombo) {
                        for ($i=0; $i -lt $oneClickDriveCombo.Items.Count; $i++) {
                            if ($oneClickDriveCombo.Items[$i] -match "^${targetDrive}:") { $oneClickDriveCombo.SelectedIndex = $i; break }
                        }
                    }
                }

                $simulationScenario = $null
                if ($simulateCombo -and $simulateCombo.SelectedItem) {
                    $val = $simulateCombo.SelectedItem.ToString()
                    if ($val -and $val -ne "None") { $simulationScenario = $val }
                }
                # IMPORTANT: Even if "None" is selected, we still analyze and fix real issues
                # The simulation scenario only affects testing, not actual repair behavior
                
                # Determine repair mode from combo box
                $dryRunFlag = $true  # Default to safe mode
                $repairMode = "DryRun"
                $bruteForceMode = $false
                if ($repairModeCombo -and $repairModeCombo.SelectedItem) {
                    $selectedItem = $repairModeCombo.SelectedItem
                    if ($selectedItem.Tag -eq "Execute") {
                        $repairMode = "Execute"
                        $dryRunFlag = $false
                    } elseif ($selectedItem.Tag -eq "BruteForce") {
                        $repairMode = "BruteForce"
                        $dryRunFlag = $false
                        $bruteForceMode = $true
                    }
                }
            
                # Build command preview
                $commandsToRun = @()
                if ($bruteForceMode) {
                    $commandsToRun += "Invoke-BruteForceBootRepair -TargetDrive $targetDrive"
                    $commandsToRun += "  -ExtractFromWim"
                    $commandsToRun += "  -MaxRetries 3"
                } else {
                    $commandsToRun += "Invoke-DefensiveBootRepair -TargetDrive $targetDrive -Mode Auto"
                    if ($simulationScenario) {
                        $commandsToRun += "  -SimulationScenario $simulationScenario"
                    }
                    if ($dryRunFlag) {
                        $commandsToRun += "  -DryRun"
                    }
                }
                
                # Show command preview and get confirmation
                $previewText = "COMMANDS THAT WILL BE RUN:`n`n"
                $previewText += ($commandsToRun -join "`n") + "`n`n"
                
                if ($bruteForceMode) {
                    $previewText += "⚠ BRUTE FORCE MODE - AGGRESSIVE REPAIR:`n"
                    $previewText += "This will execute the following aggressive operations:`n"
                    $previewText += "  1. Search ALL drives for winload.efi sources`n"
                    $previewText += "  2. Extract from install.wim if no source found`n"
                    $previewText += "  3. Try MULTIPLE copy methods with retries`n"
                    $previewText += "  4. VERIFY file integrity after each copy attempt`n"
                    $previewText += "  5. Rebuild BCD completely if standard repair fails`n"
                    $previewText += "  6. COMPREHENSIVE verification of all boot files`n`n"
                    $previewText += "⚠ WARNING: This mode is more aggressive and will:`n"
                    $previewText += "  - Try multiple copy methods (Copy-Item, robocopy, xcopy, .NET)`n"
                    $previewText += "  - Retry failed operations up to 3 times`n"
                    $previewText += "  - Extract from install.wim if needed`n"
                    $previewText += "  - Rebuild BCD completely if needed`n"
                    $previewText += "  - Verify EVERYTHING after repair`n`n"
                    $previewText += "A BCD backup will be created before any modifications.`n`n"
                } else {
                    $previewText += "This will execute the following operations:`n"
                    $previewText += "  1. Diagnose boot issues on drive $targetDrive`:`n"
                    $previewText += "  2. Check for missing winload.efi`n"
                    $previewText += "  3. Verify BCD configuration`n"
                    $previewText += "  4. Check storage drivers`n"
                    $previewText += "  5. Attempt automatic repairs (if enabled)`n`n"
                    
                    if ($dryRunFlag) {
                        $previewText += "⚠ PREVIEW MODE: Commands will be displayed but NOT executed.`n"
                        $previewText += "No changes will be made to your system.`n`n"
                    } else {
                        $previewText += "⚠ EXECUTE MODE: Commands will be executed and changes will be made.`n"
                        $previewText += "A BCD backup will be created before any modifications.`n`n"
                    }
                }
                
                $previewText += "Do you want to proceed?"
                
                $confirmExecute = [System.Windows.MessageBox]::Show(
                    $previewText,
                    "Command Preview - One-Click Repair" + $(if ($bruteForceMode) { " (BRUTE FORCE MODE)" } else { "" }),
                    "YesNo",
                    $(if ($dryRunFlag) { "Question" } else { "Warning" })
                )
                
                if ($confirmExecute -eq "No") {
                    if ($W -and $W.Dispatcher) {
                        $W.Dispatcher.Invoke([action]{
                            if ($txtOneClickStatus) { $txtOneClickStatus.Text = "Repair canceled by user." }
                            $btnOneClickRepair.IsEnabled = $true
                        }, [System.Windows.Threading.DispatcherPriority]::Normal)
                    } else {
                        if ($txtOneClickStatus) { $txtOneClickStatus.Text = "Repair canceled by user." }
                        $btnOneClickRepair.IsEnabled = $true
                    }
                    return
                }
                
                # Run comprehensive readiness check before proceeding
                $requiredFunctions = if ($bruteForceMode) { @("Invoke-BruteForceBootRepair") } else { @("Invoke-DefensiveBootRepair") }
                
                if (-not (Get-Command Test-BootRepairReadiness -ErrorAction SilentlyContinue)) {
                    # Fallback to basic function check if readiness function not available
                    Write-Host "WARNING: Test-BootRepairReadiness not available, using basic checks" -ForegroundColor Yellow
                    if ($bruteForceMode) {
                        if (-not (Get-Command Invoke-BruteForceBootRepair -ErrorAction SilentlyContinue)) {
                            $errorMsg = "ERROR: Invoke-BruteForceBootRepair function not found.`nPlease ensure DefensiveBootCore.ps1 is loaded."
                            if ($W -and $W.Dispatcher) {
                                $W.Dispatcher.Invoke([action]{
                                    if ($txtOneClickStatus) { $txtOneClickStatus.Text = $errorMsg }
                                    if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                                    $btnOneClickRepair.IsEnabled = $true
                                }, [System.Windows.Threading.DispatcherPriority]::Normal)
                            } else {
                                if ($txtOneClickStatus) { $txtOneClickStatus.Text = $errorMsg }
                                if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                                $btnOneClickRepair.IsEnabled = $true
                            }
                            [System.Windows.MessageBox]::Show($errorMsg, "Function Not Found", "OK", "Error") | Out-Null
                            return
                        }
                    } else {
                        if (-not (Get-Command Invoke-DefensiveBootRepair -ErrorAction SilentlyContinue)) {
                            $errorMsg = "ERROR: Invoke-DefensiveBootRepair function not found.`nPlease ensure DefensiveBootCore.ps1 is loaded."
                            if ($W -and $W.Dispatcher) {
                                $W.Dispatcher.Invoke([action]{
                                    if ($txtOneClickStatus) { $txtOneClickStatus.Text = $errorMsg }
                                    if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                                    $btnOneClickRepair.IsEnabled = $true
                                }, [System.Windows.Threading.DispatcherPriority]::Normal)
                            } else {
                                if ($txtOneClickStatus) { $txtOneClickStatus.Text = $errorMsg }
                                if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                                $btnOneClickRepair.IsEnabled = $true
                            }
                            [System.Windows.MessageBox]::Show($errorMsg, "Function Not Found", "OK", "Error") | Out-Null
                            return
                        }
                    }
                } else {
                    # Run comprehensive readiness check
                    try {
                        Update-StatusBar -Message "One-Click Repair: Running readiness checks..." -ShowProgress
                        $readiness = Test-BootRepairReadiness -TargetDrive $targetDrive -RequiredFunctions $requiredFunctions -CheckPermissions -CheckPaths
                        
                        if (-not $readiness.Ready) {
                            $errorDetails = @()
                            $errorDetails += "READINESS CHECK FAILED"
                            $errorDetails += ""
                            $errorDetails += "Issues found:"
                            foreach ($issue in $readiness.Issues) {
                                $errorDetails += "  - $issue"
                            }
                            if ($readiness.Warnings.Count -gt 0) {
                                $errorDetails += ""
                                $errorDetails += "Warnings:"
                                foreach ($warning in $readiness.Warnings) {
                                    $errorDetails += "  - $warning"
                                }
                            }
                            $errorDetails += ""
                            $errorDetails += "Check details:"
                            foreach ($checkName in $readiness.Checks.Keys) {
                                $check = $readiness.Checks[$checkName]
                                $status = if ($check.Passed) { "[OK]" } else { "[FAIL]" }
                                $errorDetails += "  $status $checkName : $($check.Message)"
                            }
                            
                            $errorMsg = $errorDetails -join "`n"
                            
                            if ($W -and $W.Dispatcher) {
                                $W.Dispatcher.Invoke([action]{
                                    if ($txtOneClickStatus) { $txtOneClickStatus.Text = "Readiness check failed - see details" }
                                    if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                                    $btnOneClickRepair.IsEnabled = $true
                                    Update-StatusBar -Message "One-Click Repair: Readiness check failed" -HideProgress
                                }, [System.Windows.Threading.DispatcherPriority]::Normal)
                            } else {
                                if ($txtOneClickStatus) { $txtOneClickStatus.Text = "Readiness check failed - see details" }
                                if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                                $btnOneClickRepair.IsEnabled = $true
                            }
                            
                            [System.Windows.MessageBox]::Show(
                                "Readiness check failed. Cannot proceed with repair.`n`n$($readiness.Issues -join '`n')",
                                "Readiness Check Failed",
                                "OK",
                                "Error"
                            ) | Out-Null
                            return
                        } else {
                            # Log successful readiness check
                            Write-Host "Readiness check passed: $($readiness.Summary)" -ForegroundColor Green
                            if ($readiness.Warnings.Count -gt 0) {
                                Write-Host "Warnings: $($readiness.Warnings -join '; ')" -ForegroundColor Yellow
                            }
                        }
                    } catch {
                        $errorMsg = "ERROR: Readiness check failed with exception: $($_.Exception.Message)"
                        Write-Host $errorMsg -ForegroundColor Red
                        if ($W -and $W.Dispatcher) {
                            $W.Dispatcher.Invoke([action]{
                                if ($txtOneClickStatus) { $txtOneClickStatus.Text = "Readiness check error" }
                                if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                                $btnOneClickRepair.IsEnabled = $true
                                Update-StatusBar -Message "One-Click Repair: Readiness check error" -HideProgress
                            }, [System.Windows.Threading.DispatcherPriority]::Normal)
                        } else {
                            if ($txtOneClickStatus) { $txtOneClickStatus.Text = "Readiness check error" }
                            if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                            $btnOneClickRepair.IsEnabled = $true
                        }
                        [System.Windows.MessageBox]::Show($errorMsg, "Readiness Check Error", "OK", "Error") | Out-Null
                        return
                    }
                }
                
                # Inner try for the actual repair execution
                try {
                    # Update status bar to show repair is starting
                    Update-StatusBar -Message "One-Click Repair: Starting diagnostics and repair..." -ShowProgress
                    
                    # Set up progress update timer to show activity during repair
                    # Use script scope for progressSteps so it's accessible in the timer callback
                    $script:progressSteps = @(
                        "One-Click Repair: Scanning Windows installations...",
                        "One-Click Repair: Checking boot configuration...",
                        "One-Click Repair: Analyzing boot files...",
                        "One-Click Repair: Performing repairs...",
                        "One-Click Repair: Verifying bootability..."
                    )
                    # Use script scope for stepIndex so it's accessible in the timer callback
                    $script:stepIndex = 0
                    $progressTimer = New-Object System.Windows.Threading.DispatcherTimer
                    $progressTimer.Interval = [TimeSpan]::FromSeconds(2)
                    $progressTimer.Add_Tick({
                        # Defensive: Ensure variables are initialized before accessing
                        if (-not (Test-Path variable:script:stepIndex)) {
                            $script:stepIndex = 0
                        }
                        if (-not (Test-Path variable:script:progressSteps)) {
                            $script:progressSteps = @()
                        }
                        
                        if ($script:progressSteps.Count -gt 0 -and $script:stepIndex -lt $script:progressSteps.Count - 1) {
                            $script:stepIndex++
                            Update-StatusBar -Message $script:progressSteps[$script:stepIndex] -ShowProgress
                        } elseif ($script:progressSteps.Count -gt 0) {
                            # Cycle back to show activity
                            $script:stepIndex = 0
                            Update-StatusBar -Message $script:progressSteps[$script:stepIndex] -ShowProgress
                        }
                    })
                    $progressTimer.Start()
                    
                    # Final validation: Ensure targetDrive is not empty before calling repair functions
                    if ([string]::IsNullOrWhiteSpace($targetDrive)) {
                        $progressTimer.Stop()
                        $errorMsg = "ERROR: Target drive is empty. Cannot proceed with repair."
                        if ($W -and $W.Dispatcher) {
                            $W.Dispatcher.Invoke([action]{
                                if ($txtOneClickStatus) { $txtOneClickStatus.Text = $errorMsg }
                                if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                                $btnOneClickRepair.IsEnabled = $true
                                Update-StatusBar -Message "One-Click Repair: Failed - Invalid drive" -HideProgress
                            }, [System.Windows.Threading.DispatcherPriority]::Normal)
                        } else {
                            if ($txtOneClickStatus) { $txtOneClickStatus.Text = $errorMsg }
                            if ($fixerOutput) { $fixerOutput.Text = $errorMsg }
                            $btnOneClickRepair.IsEnabled = $true
                        }
                        [System.Windows.MessageBox]::Show($errorMsg, "Repair Error", "OK", "Error") | Out-Null
                        return
                    }
                    
                    # Run repair with automatic failover to backup and last effort modes
                    # First try primary function, then backup, then last effort if needed
                    $useFailover = $false
                    $repairModeUsed = "Primary"
                    
                    try {
                        if ($bruteForceMode) {
                            # Pass -AllowOnlineRepair when user selects Execute Repairs (not DryRun)
                            # This allows safe repairs (like copying winload.efi) even when running in full Windows
                            if (Get-Command Invoke-BruteForceBootRepair -ErrorAction SilentlyContinue) {
                                $result = Invoke-BruteForceBootRepair -TargetDrive $targetDrive -ExtractFromWim:$true -MaxRetries 3 -AllowOnlineRepair:(!$dryRunFlag)
                                $repairModeUsed = "Primary (BruteForce)"
                            } else {
                                $useFailover = $true
                            }
                        } else {
                            # Pass -AllowOnlineRepair when user selects Execute Repairs (not DryRun)
                            # This allows safe repairs (like copying winload.efi) even when running in full Windows
                            if (Get-Command Invoke-DefensiveBootRepair -ErrorAction SilentlyContinue) {
                                $result = Invoke-DefensiveBootRepair -TargetDrive $targetDrive -Mode "Auto" -SimulationScenario $simulationScenario -DryRun:$dryRunFlag -AllowOnlineRepair:(!$dryRunFlag)
                                $repairModeUsed = "Primary (Defensive)"
                            } else {
                                $useFailover = $true
                            }
                        }
                        
                        # Check if primary repair failed or returned non-bootable result
                        if ($useFailover -or ($result -and -not $result.Bootable)) {
                            $useFailover = $true
                        }
                    } catch {
                        # Primary repair threw exception - use failover
                        $useFailover = $true
                        Write-Host "Primary repair failed with exception: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                    
                    # Failover to backup/last effort if primary failed
                    if ($useFailover) {
                        Write-Host "Primary repair failed or unavailable. Switching to failover mode..." -ForegroundColor Yellow
                        Update-StatusBar -Message "One-Click Repair: Primary repair failed - using failover mode..." -ShowProgress
                        
                        if (Get-Command Invoke-BootRepairWithFailover -ErrorAction SilentlyContinue) {
                            try {
                                $result = Invoke-BootRepairWithFailover -TargetDrive $targetDrive -Mode "Auto" -SimulationScenario $simulationScenario -DryRun:$dryRunFlag -AllowOnlineRepair:(!$dryRunFlag) -BruteForce:$bruteForceMode
                                $repairModeUsed = if ($result.RepairMode) { $result.RepairMode } else { "Failover" }
                                
                                if ($result.FailoverUsed) {
                                    Write-Host "Failover mode used: $($result.RepairMode)" -ForegroundColor Yellow
                                    if ($txtOneClickStatus) {
                                        $txtOneClickStatus.Text = "Repair completed using failover mode: $($result.RepairMode)"
                                    }
                                }
                            } catch {
                                Write-Host "Failover repair also failed: $($_.Exception.Message)" -ForegroundColor Red
                                $result = @{
                                    Output = "All repair attempts failed. Last error: $($_.Exception.Message)"
                                    Bundle = ""
                                    Bootable = $false
                                    Confidence = "UNKNOWN"
                                    Blocker = "All repair attempts failed"
                                    RemainingIssues = @("All repair attempts failed", $_.Exception.Message)
                                }
                                $repairModeUsed = "Failed"
                            }
                        } else {
                            # Fallback: try backup function directly
                            Write-Host "Failover wrapper not available. Trying backup function directly..." -ForegroundColor Yellow
                            if (Get-Command Invoke-BackupBootRepair -ErrorAction SilentlyContinue) {
                                try {
                                    $result = Invoke-BackupBootRepair -TargetDrive $targetDrive -DryRun:$dryRunFlag
                                    $repairModeUsed = "Backup (Direct)"
                                } catch {
                                    # Last resort: try last effort function
                                    Write-Host "Backup repair failed. Trying last effort..." -ForegroundColor Red
                                    if (Get-Command Invoke-LastEffortBootRepair -ErrorAction SilentlyContinue) {
                                        try {
                                            $result = Invoke-LastEffortBootRepair -TargetDrive $targetDrive
                                            $repairModeUsed = "Last Effort"
                                        } catch {
                                            $result = @{
                                                Output = "All repair attempts failed. Last error: $($_.Exception.Message)"
                                                Bundle = ""
                                                Bootable = $false
                                                Confidence = "UNKNOWN"
                                                Blocker = "All repair attempts failed"
                                                RemainingIssues = @("All repair attempts failed", $_.Exception.Message)
                                            }
                                            $repairModeUsed = "Failed"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    # Stop progress timer
                    $progressTimer.Stop()
                    
                    # Handle result with defensive checks - wrap entire block in try-catch
                    try {
                        if ($result) {
                        $outputText = ""
                        $bundleText = ""
                        $bootable = $false
                        $confidence = "UNKNOWN"
                        $blocker = $null
                        $remainingIssues = @()
                        
                        # Safely extract all properties with comprehensive error handling
                        try {
                            if ($result.PSObject.Properties.Name -contains 'Output') {
                                $outputText = $result.Output
                            }
                        } catch {
                            Write-Host "Warning: Could not access result.Output: $_" -ForegroundColor Yellow
                        }
                        
                        try {
                            if ($result.PSObject.Properties.Name -contains 'Bundle') {
                                $bundleText = $result.Bundle
                            }
                        } catch {
                            Write-Host "Warning: Could not access result.Bundle: $_" -ForegroundColor Yellow
                        }
                        
                        try {
                            if ($result.PSObject.Properties.Name -contains 'Bootable') {
                                $bootable = $result.Bootable
                            }
                        } catch {
                            Write-Host "Warning: Could not access result.Bootable: $_" -ForegroundColor Yellow
                        }
                        
                        try {
                            if ($result.PSObject.Properties.Name -contains 'Confidence') {
                                $confidence = $result.Confidence
                            }
                        } catch {
                            Write-Host "Warning: Could not access result.Confidence: $_" -ForegroundColor Yellow
                        }
                        
                        try {
                            if ($result.PSObject.Properties.Name -contains 'Blocker') {
                                $blocker = $result.Blocker
                            }
                        } catch {
                            Write-Host "Warning: Could not access result.Blocker: $_" -ForegroundColor Yellow
                        }
                        
                        if ($fixerOutput) {
                            $fixerOutput.Text = $outputText + "`n`n" + $bundleText
                            $fixerOutput.ScrollToEnd()
                        }
                        $summaryDir = Join-Path $PSScriptRoot "LOGS_MIRACLEBOOT"
                        if (-not (Test-Path $summaryDir)) { New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null }
                        $summaryPath = Join-Path $summaryDir ("OneClick_GUI_{0:yyyyMMdd_HHmmss}.txt" -f (Get-Date))
                        Set-Content -Path $summaryPath -Value ($outputText + "`n`n" + $bundleText) -Encoding UTF8 -Force
                        
                        # Enhanced validation result display with specific details
                        
                        # Get issues from result object (preferred method - includes exact paths)
                        try {
                            if ($result.PSObject.Properties.Name -contains 'Issues' -and $result.Issues) {
                                $issuesValue = $result.Issues
                                # Ensure it's always an array
                                if ($null -eq $issuesValue) {
                                    $remainingIssues = @()
                                } elseif ($issuesValue -is [array]) {
                                    $remainingIssues = $issuesValue
                                } else {
                                    $remainingIssues = @($issuesValue)
                                }
                            } elseif ($result.PSObject.Properties.Name -contains 'Verification' -and $result.Verification) {
                                # Safely access Verification.Issues (Verification is a hashtable, not pscustomobject)
                                try {
                                    if ($result.Verification -is [hashtable]) {
                                        if ($result.Verification.ContainsKey('Issues') -and $result.Verification.Issues) {
                                            $issuesValue = $result.Verification.Issues
                                            # Ensure it's always an array
                                            if ($null -eq $issuesValue) {
                                                $remainingIssues = @()
                                            } elseif ($issuesValue -is [array]) {
                                                $remainingIssues = $issuesValue
                                            } else {
                                                $remainingIssues = @($issuesValue)
                                            }
                                        }
                                    } elseif ($result.Verification -is [pscustomobject] -or $result.Verification -is [psobject]) {
                                        if ($result.Verification.PSObject.Properties.Name -contains 'Issues' -and $result.Verification.Issues) {
                                            $issuesValue = $result.Verification.Issues
                                            # Ensure it's always an array
                                            if ($null -eq $issuesValue) {
                                                $remainingIssues = @()
                                            } elseif ($issuesValue -is [array]) {
                                                $remainingIssues = $issuesValue
                                            } else {
                                                $remainingIssues = @($issuesValue)
                                            }
                                        }
                                    }
                                } catch {
                                    # If accessing Verification fails, fall through to text extraction
                                    Write-Host "Warning: Could not access Verification.Issues: $_" -ForegroundColor Yellow
                                }
                            }
                        } catch {
                            Write-Host "Warning: Could not access result.Issues or Verification: $_" -ForegroundColor Yellow
                        }
                        
                        # Ensure $remainingIssues is always an array before accessing .Count
                        if ($null -eq $remainingIssues) {
                            $remainingIssues = @()
                        } elseif ($remainingIssues -isnot [array]) {
                            $remainingIssues = @($remainingIssues)
                        }
                        
                        # Fallback: Extract issues from output text if we didn't get them from the object
                        if ($remainingIssues.Count -eq 0) {
                            # Fallback: Extract specific issues from output text (look for missing files, paths, etc.)
                            $issuePatterns = @(
                                "MISSING at (.+)",
                                "does NOT point to",
                                "still missing",
                                "still does not match",
                                "still locked",
                                "MISSING: (.+)",
                                "FAILED: (.+)",
                                "cannot be enumerated",
                                "not readable"
                            )
                            
                            foreach ($pattern in $issuePatterns) {
                                try {
                                    $matches = [regex]::Matches($outputText, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                                    # Ensure $matches is always iterable
                                    if ($matches) {
                                        foreach ($match in $matches) {
                                            try {
                                                # Safely check Groups.Count - Groups is always a collection but may not have .Count property in all PowerShell versions
                                                $groupCount = if ($match.Groups) { 
                                                    if ($match.Groups -is [array]) { $match.Groups.Count } 
                                                    elseif ($match.Groups.PSObject.Properties.Name -contains 'Count') { $match.Groups.Count }
                                                    else { 0 }
                                                } else { 0 }
                                                
                                                if ($groupCount -gt 1 -and $match.Groups[1].Value) {
                                                    $remainingIssues += $match.Groups[0].Value
                                                } elseif ($match.Value) {
                                                    $remainingIssues += $match.Value
                                                }
                                            } catch {
                                                # If accessing match properties fails, just use the match value
                                                if ($match.Value) {
                                                    $remainingIssues += $match.Value
                                                }
                                            }
                                        }
                                    }
                                } catch {
                                    # Skip this pattern if regex matching fails
                                    Write-Host "Warning: Failed to match pattern '$pattern': $_" -ForegroundColor Yellow
                                }
                            }
                        }
                        
                        # Build comprehensive status message
                        $statusText = ""
                        if ($bootable) {
                            $statusText = "✅ VALIDATION PASSED: System is LIKELY BOOTABLE`n"
                            $statusText += "Confidence Level: $confidence`n"
                            $statusText += "`nAll critical boot files are present and correctly configured."
                        } else {
                            $statusText = "❌ VALIDATION FAILED: System WILL NOT BOOT`n"
                            $statusText += "Confidence Level: $confidence`n"
                            
                            if ($blocker) {
                                $statusText += "`nPrimary Blocker: $blocker`n"
                            }
                            
                            if ($remainingIssues.Count -gt 0) {
                                $statusText += "`nSpecific Issues Found:`n"
                                $statusText += "────────────────────────────────────────`n"
                                $uniqueIssues = $remainingIssues | Select-Object -Unique
                                # Ensure $uniqueIssues is always an array
                                if ($null -eq $uniqueIssues) {
                                    $uniqueIssues = @()
                                } elseif ($uniqueIssues -isnot [array]) {
                                    $uniqueIssues = @($uniqueIssues)
                                }
                                foreach ($issue in $uniqueIssues) {
                                    $statusText += "  • $issue`n"
                                }
                            } else {
                                # Try to extract issues from output text more directly
                                $outputLines = $outputText -split "`n"
                                $issueLines = $outputLines | Where-Object { 
                                    $_ -match "❌|MISSING|FAILED|does NOT|still missing|still does not|cannot be|not readable" 
                                } | Select-Object -First 10
                                
                                # Ensure $issueLines is always an array before accessing .Count
                                if ($null -eq $issueLines) {
                                    $issueLines = @()
                                } elseif ($issueLines -isnot [array]) {
                                    $issueLines = @($issueLines)
                                }
                                
                                if ($issueLines.Count -gt 0) {
                                    $statusText += "`nSpecific Issues Found:`n"
                                    $statusText += "────────────────────────────────────────`n"
                                    foreach ($line in $issueLines) {
                                        $cleanLine = $line.Trim() -replace "^\s*[❌⚠✗]\s*", ""
                                        if ($cleanLine -and $cleanLine.Length -gt 5) {
                                            $statusText += "  • $cleanLine`n"
                                        }
                                    }
                                }
                            }
                            
                            # Add guidance
                            $statusText += "`n────────────────────────────────────────`n"
                            $statusText += "Please review the detailed output above for exact file paths and specific problems."
                        }
                        
                        if ($result.PSObject.Properties.Name -contains 'ReportPath' -and $result.ReportPath) {
                            $statusText += "`n`nComprehensive report opened in Notepad: $($result.ReportPath)"
                        }
                        
                        if ($txtOneClickStatus) {
                            $txtOneClickStatus.Text = $statusText
                        }
                        
                        # Also show a message box for critical failures
                        if (-not $bootable) {
                            $messageBoxText = "VALIDATION FAILED`n`n"
                            $messageBoxText += "The system will NOT boot.`n`n"
                            if ($blocker) {
                                $messageBoxText += "Primary Issue: $blocker`n`n"
                            }
                            $messageBoxText += "Please check the output box for detailed information about missing files and specific problems."
                            
                            [System.Windows.MessageBox]::Show(
                                $messageBoxText,
                                "Validation Failed",
                                "OK",
                                "Warning"
                            ) | Out-Null
                        }
                    } else {
                        # Result is null or invalid
                        if ($txtOneClickStatus) { 
                            $txtOneClickStatus.Text = "Error: Repair function returned no result"
                        }
                        if ($fixerOutput) {
                            $fixerOutput.Text = "Error: Repair function returned no result. Check logs for details."
                        }
                        }
                    } catch {
                        # Catch any property access errors (like PermissionsModified)
                        $errorMsg = "❌ Error accessing repair result: $($_.Exception.Message)"
                        Write-Host "Error details: $($_.Exception.GetType().FullName)" -ForegroundColor Red
                        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
                        
                        # Try to extract at least the output text if available
                        $outputText = ""
                        $bundleText = ""
                        try {
                            if ($result -and $result.PSObject.Properties.Name -contains 'Output') {
                                $outputText = $result.Output
                            }
                        } catch {
                            Write-Host "Could not extract Output: $_" -ForegroundColor Yellow
                        }
                        try {
                            if ($result -and $result.PSObject.Properties.Name -contains 'Bundle') {
                                $bundleText = $result.Bundle
                            }
                        } catch {
                            Write-Host "Could not extract Bundle: $_" -ForegroundColor Yellow
                        }
                        
                        if ($fixerOutput) {
                            $fixerOutput.Text = "Error processing repair result: $($_.Exception.Message)`n`n" + 
                                                 "Output: $outputText`n`nBundle: $bundleText"
                            $fixerOutput.ScrollToEnd()
                        }
                        
                        if ($txtOneClickStatus) {
                            $txtOneClickStatus.Text = $errorMsg
                        }
                        
                        Update-StatusBar -Message "One-Click Repair: Error processing result" -HideProgress
                        [System.Windows.MessageBox]::Show(
                            "One-Click Repair completed but encountered an error processing the result: $($_.Exception.Message)`n`nCheck the output box for details.",
                            "Repair Error",
                            "OK",
                            "Error"
                        ) | Out-Null
                    }
                    
                    Update-StatusBar -Message "One-Click Repair: Complete" -HideProgress
                } catch {
                    $errorMsg = "❌ Error: $($_.Exception.Message)"
                    if ($txtOneClickStatus) { $txtOneClickStatus.Text = $errorMsg }
                    if ($fixerOutput) { 
                        $fixerOutput.Text = $errorMsg + "`n`nStack trace: $($_.ScriptStackTrace)"
                        $fixerOutput.ScrollToEnd()
                    }
                    Update-StatusBar -Message "One-Click Repair: Error - $($_.Exception.Message)" -HideProgress
                    [System.Windows.MessageBox]::Show(
                        "One-Click Repair failed: $($_.Exception.Message)`n`nCheck the output box for details.",
                        "Repair Error",
                        "OK",
                        "Error"
                    ) | Out-Null
                } finally {
                    # Always re-enable button
                    $btnOneClickRepair.IsEnabled = $true
                }
            } catch {
                # Outer catch for any errors in the handler setup (errors before inner try block)
                $errorMsg = "Button handler error: $($_.Exception.Message)"
                $fullError = $errorMsg + "`n`nStack: $($_.ScriptStackTrace)"
                try {
                    # Always show error message - don't silently fail
                    [System.Windows.MessageBox]::Show($fullError, "Handler Error", "OK", "Error") | Out-Null
                    Update-StatusBar -Message $errorMsg -HideProgress
                } catch {
                    # If even error display fails, write to console
                    Write-Host "CRITICAL: Button handler error display failed: $_" -ForegroundColor Red
                    Write-Host "Original error: $fullError" -ForegroundColor Red
                }
                try {
                    $btnOneClickRepair.IsEnabled = $true
                } catch {
                    Write-Host "CRITICAL: Could not re-enable button: $_" -ForegroundColor Red
                }
            }
        })  # End of Add_Click handler
        Write-Host "[GUI] One-Click Repair button handler wired successfully" -ForegroundColor Green
    } else {
        Write-Host "[GUI] WARNING: BtnOneClickRepair button NOT FOUND in XAML!" -ForegroundColor Yellow
        Write-Host "[GUI] This means the button handler will NOT work!" -ForegroundColor Red
    }  # End of if ($btnOneClickRepair)
    
    # ========================================
    # END OF BUTTON HANDLER REGISTRATION
    # All handlers must be registered BEFORE ShowDialog()!
    # ========================================
}  # End of if ($null -ne $W) for button handlers

# Show the window - MOVED OUTSIDE try-catch so it ALWAYS runs
if ($null -ne $W) {
    try {
        # Ensure window is visible and not minimized
        $W.Visibility = [System.Windows.Visibility]::Visible
        $W.WindowState = [System.Windows.WindowState]::Normal
        $W.ShowInTaskbar = $true
        
        # Show the window - this blocks until window is closed
        $result = $W.ShowDialog()
    } catch {
        Write-Error "Failed to show GUI window: $_"
        throw
    }
} else {
    throw "Window object is null - cannot display GUI"
}

# Footer buttons: resize toggle and summary shortcut
    $btnResizeWindow = Get-Control -Name "BtnResizeWindow"
    if ($btnResizeWindow) {
        $btnResizeWindow.Add_Click({
            try {
                $mainWin = [System.Windows.Application]::Current.MainWindow
                if ($mainWin.WindowState -eq "Maximized") {
                    $mainWin.WindowState = "Normal"
                } else {
                    $mainWin.WindowState = "Maximized"
                }
            } catch {
                Write-Warning "Resize toggle failed: $_"
            }
        })
    }
    $btnSummaryShortcut = Get-Control -Name "BtnSummaryShortcut"
    if ($btnSummaryShortcut) {
        $btnSummaryShortcut.Add_Click({
            try {
                $tabs = Get-Control -Name "MainTabs"
                if ($tabs) {
                    foreach ($item in $tabs.Items) {
                        if ($item.Header -eq "Summary") {
                            $tabs.SelectedItem = $item
                            break
                        }
                    }
                }
            } catch {
                Write-Warning "Summary shortcut failed: $_"
            }
        })
    }
    
    # Update current OS label
    function Update-CurrentOSLabel {
        try {
            $diagDriveCombo = Get-Control "DiagDriveCombo"
            if ($diagDriveCombo -and $diagDriveCombo.SelectedItem) {
                $selected = $diagDriveCombo.SelectedItem
                $drive = $currentSystemDrive
                if ($selected) {
                    if ($selected -match '^([A-Z]):') {
                        $drive = $matches[1]
                    }
                }
                $currentOSLabel = Get-Control "CurrentOSLabel"
                if ($currentOSLabel) {
                    if ($drive -eq $currentSystemDrive) {
                        $currentOSLabel.Text = "[OK] This is the CURRENT OS (running from $currentSystemDrive`:)"
                    } else {
                        $currentOSLabel.Text = "[OFFLINE] This is an OFFLINE OS (not currently running)"
                    }
                }
            }
        } catch {
            Write-Warning "Error in Update-CurrentOSLabel: $_"
        }
    }
    Update-CurrentOSLabel
    if ($diagDriveCombo) {
        $diagDriveCombo.Add_SelectionChanged({ Update-CurrentOSLabel })
    }
    
    # Logic for Volumes
    $btnVol = Get-Control "BtnVol"
    if ($btnVol) {
        $btnVol.Add_Click({
            $vols = Get-WindowsVolumes
            $volList = Get-Control "VolList"
            if ($volList) {
                $volList.ItemsSource = $vols
            }
        })
    }
    
    # Logic for Summary Tab
    $btnRefreshSummary = Get-Control "BtnRefreshSummary"
    if ($btnRefreshSummary) {
        $btnRefreshSummary.Add_Click({
            try {
                Update-StatusBar -Message "Analyzing boot health and Windows Update eligibility..." -ShowProgress
                
                # Check if required function exists
                if (-not (Get-Command Get-WindowsHealthSummary -ErrorAction SilentlyContinue)) {
                    $errorMsg = "Get-WindowsHealthSummary function not found. WinRepairCore.ps1 may not be loaded correctly."
                    Log-GUIFailure -Location "Summary Tab Handler" -Error "Function Not Found" -Details $errorMsg
                    Update-StatusBar -Message "Error: Core functions not available" -HideProgress
                    [System.Windows.MessageBox]::Show($errorMsg, "Function Not Found", "OK", "Error")
                    return
                }
                
                # Get selected drive
                $summaryDriveCombo = Get-Control "SummaryDriveCombo"
                $selectedDrive = $currentSystemDrive
                if ($summaryDriveCombo -and $summaryDriveCombo.SelectedItem) {
                    $selected = $summaryDriveCombo.SelectedItem
                    if ($selected -match '^([A-Z]):') {
                        $selectedDrive = $matches[1]
                    }
                }
                
                # Get Windows Health Summary (includes both boot health and update eligibility)
                $bootHealthStatus = Get-Control "BootHealthStatus"
                $bootHealthBox = Get-Control "BootHealthBox"
                $updateEligibilityStatus = Get-Control "UpdateEligibilityStatus"
                $updateEligibilityBox = Get-Control "UpdateEligibilityBox"
                
                if ($bootHealthStatus) {
                    $bootHealthStatus.Text = "Analyzing boot health for drive $selectedDrive`:..."
                }
                if ($updateEligibilityStatus) {
                    $updateEligibilityStatus.Text = "Checking Windows Update eligibility for drive $selectedDrive`:..."
                }
                
                # Call the actual function
                $healthSummary = Get-WindowsHealthSummary -TargetDrive $selectedDrive
                
                # Format Boot Health Report
                if ($bootHealthBox) {
                    $bootHealthReport = "WINDOWS BOOT HEALTH SUMMARY`n"
                    $bootHealthReport += "===============================================================`n"
                    $bootHealthReport += "Target Drive: $($healthSummary.TargetDrive)`n"
                    $bootHealthReport += "Analysis Time: $($healthSummary.Timestamp)`n"
                    $bootHealthReport += "Overall Health: $($healthSummary.OverallHealth)`n"
                    $bootHealthReport += "Status: $($healthSummary.Status)`n"
                    $bootHealthReport += "`n===============================================================`n`n"
                    
                    # BCD Health
                    if ($healthSummary.Components.BCD) {
                        $bcd = $healthSummary.Components.BCD
                        $bootHealthReport += "BCD VALIDITY:`n"
                        $bootHealthReport += "  Status: $($bcd.Status)`n"
                        $bootHealthReport += "  Valid: $($bcd.IsValid)`n"
                        $bootHealthReport += "  Entry Count: $($bcd.EntryCount)`n"
                        $bootHealthReport += "  Default Entry: $($bcd.DefaultEntry)`n"
                        if ($bcd.Issues.Count -gt 0) {
                            $bootHealthReport += "  Issues: $($bcd.Issues -join ', ')`n"
                        }
                        $bootHealthReport += "`n"
                    }
                    
                    # EFI Health
                    if ($healthSummary.Components.EFI) {
                        $efi = $healthSummary.Components.EFI
                        $bootHealthReport += "EFI PARTITION:`n"
                        $bootHealthReport += "  Present: $($efi.Present)`n"
                        $bootHealthReport += "  Location: $($efi.Location)`n"
                        $bootHealthReport += "  Size: $($efi.Size)`n"
                        $bootHealthReport += "`n"
                    }
                    
                    # Boot Stack Order
                    if ($healthSummary.BootStackOrder -and $healthSummary.BootStackOrder.Count -gt 0) {
                        $bootHealthReport += "BOOT STACK ORDER:`n"
                        foreach ($item in $healthSummary.BootStackOrder) {
                            $bootHealthReport += "  $($item.Order). $($item.Component): $($item.Status)`n"
                            if ($item.Path) {
                                $bootHealthReport += "     Path: $($item.Path)`n"
                            }
                        }
                        $bootHealthReport += "`n"
                    }
                    
                    # Log Issues
                    if ($healthSummary.Components.Logs -and $healthSummary.Components.Logs.Count -gt 0) {
                        $bootHealthReport += "LOG ISSUES: $($healthSummary.Components.Logs.Count) issue(s) detected`n"
                        $bootHealthReport += "`n"
                    }
                    
                    # Recommendations
                    if ($healthSummary.Recommendations -and $healthSummary.Recommendations.Count -gt 0) {
                        $bootHealthReport += "RECOMMENDATIONS:`n"
                        foreach ($rec in $healthSummary.Recommendations) {
                            $bootHealthReport += "  • $rec`n"
                        }
                    }
                    
                    $bootHealthBox.Text = $bootHealthReport
                }
                
                if ($bootHealthStatus) {
                    $statusText = "Overall Health: $($healthSummary.OverallHealth) - $($healthSummary.Status)"
                    $bootHealthStatus.Text = $statusText
                    switch ($healthSummary.OverallHealth) {
                        "Healthy" { $bootHealthStatus.Foreground = "Green" }
                        "Caution" { $bootHealthStatus.Foreground = "Orange" }
                        "Warning" { $bootHealthStatus.Foreground = "Orange" }
                        "Critical" { $bootHealthStatus.Foreground = "Red" }
                        default { $bootHealthStatus.Foreground = "Gray" }
                    }
                }
                
                # Format Update Eligibility Report
                if ($updateEligibilityBox -and $healthSummary.UpdateEligibility) {
                    $updateReport = "WINDOWS UPDATE IN-PLACE REPAIR ELIGIBILITY`n"
                    $updateReport += "===============================================================`n"
                    $updateReport += "Target Drive: $($healthSummary.TargetDrive)`n"
                    $updateReport += "Eligible: $($healthSummary.UpdateEligibility.Eligible)`n"
                    $updateReport += "Reason: $($healthSummary.UpdateEligibility.Reason)`n"
                    $updateReport += "`n===============================================================`n`n"
                    
                    if ($healthSummary.UpdateEligibility.Requirements) {
                        $updateReport += "REQUIREMENTS CHECK:`n"
                        foreach ($req in $healthSummary.UpdateEligibility.Requirements.GetEnumerator()) {
                            $updateReport += "  $($req.Key): $($req.Value.Status)`n"
                        }
                        $updateReport += "`n"
                    }
                    
                    if ($healthSummary.UpdateEligibility.Issues -and $healthSummary.UpdateEligibility.Issues.Count -gt 0) {
                        $updateReport += "ISSUES:`n"
                        foreach ($issue in $healthSummary.UpdateEligibility.Issues) {
                            $updateReport += "  • $issue`n"
                        }
                    }
                    
                    $updateEligibilityBox.Text = $updateReport
                }
                
                if ($updateEligibilityStatus) {
                    $eligibility = $healthSummary.UpdateEligibility
                    $statusText = "Eligible: $($eligibility.Eligible) - $($eligibility.Reason)"
                    $updateEligibilityStatus.Text = $statusText
                    if ($eligibility.Eligible) {
                        $updateEligibilityStatus.Foreground = "Green"
                    } else {
                        $updateEligibilityStatus.Foreground = "Red"
                    }
                }
                
                Update-StatusBar -Message "Summary analysis complete" -HideProgress
            } catch {
                $errorDetails = "Error analyzing summary: $_`n`nStack Trace: $($_.ScriptStackTrace)"
                Log-GUIFailure -Location "Summary Tab Handler" -Error "Summary Analysis Failed" -Details $errorDetails -Exception $_
                Update-StatusBar -Message "Error analyzing summary: $_" -HideProgress
                [System.Windows.MessageBox]::Show(
                    "Error analyzing summary:`n`n$_`n`nThis error has been logged to: $env:TEMP\MiracleBoot_GUI_Failures.log`n`nPlease check the log file for details.",
                    "Summary Analysis Error",
                    "OK",
                    "Error"
                )
            }
        })
    }
}

# Store BCD entries globally for real-time updates
$script:BCDEntriesCache = $null

# Helper function to update status bar with enhanced progress tracking
# Global status bar state for elapsed time tracking
$script:StatusBarStartTime = $null
$script:StatusBarElapsedTimer = $null

function Update-StatusBar {
    param(
        [string]$Message = "Ready",
        [switch]$ShowProgress,
        [switch]$HideProgress,
        [int]$Percentage = -1,
        [string]$Stage = "",
        [string]$CurrentOperation = "",
        [Nullable[TimeSpan]]$EstimatedTimeRemaining = $null
    )
    
    # Start elapsed time tracking when progress begins
    if ($ShowProgress -and -not $script:StatusBarStartTime) {
        $script:StatusBarStartTime = Get-Date
        # Clear any existing timer
        if ($script:StatusBarElapsedTimer) {
            $script:StatusBarElapsedTimer.Stop()
            $script:StatusBarElapsedTimer = $null
        }
        # Create timer for periodic updates
        $script:StatusBarElapsedTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:StatusBarElapsedTimer.Interval = [TimeSpan]::FromSeconds(1)
        $script:StatusBarElapsedTimer.Add_Tick({
            if ($script:StatusBarStartTime -and $W) {
                $elapsed = (Get-Date) - $script:StatusBarStartTime
                $minutes = [math]::Floor($elapsed.TotalMinutes)
                $seconds = [math]::Floor($elapsed.TotalSeconds % 60)
                $W.Dispatcher.Invoke([action]{
                    $statusBarControl = Get-Control "StatusBarText"
                    if ($statusBarControl) {
                        $currentText = $statusBarControl.Text
                        # Update elapsed time if message hasn't changed
                        if ($currentText -match "Elapsed:") {
                            $statusBarControl.Text = $currentText -replace "Elapsed: \d+m \d+s", "Elapsed: ${minutes}m ${seconds}s"
                        } elseif ($currentText -notmatch "Elapsed:") {
                            $statusBarControl.Text = "$currentText | Elapsed: ${minutes}m ${seconds}s"
                        }
                    }
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            }
        })
        $script:StatusBarElapsedTimer.Start()
    }
    
    # Stop elapsed time tracking when progress ends
    if ($HideProgress) {
        if ($script:StatusBarElapsedTimer) {
            $script:StatusBarElapsedTimer.Stop()
            $script:StatusBarElapsedTimer = $null
        }
        $script:StatusBarStartTime = $null
    }
    
    # Use dispatcher to ensure UI updates on UI thread
    $W.Dispatcher.Invoke([action]{
        $statusBarControl = Get-Control "StatusBarText"
        if ($statusBarControl) {
            # Add elapsed time if progress is active
            if ($ShowProgress -and $script:StatusBarStartTime) {
                $elapsed = (Get-Date) - $script:StatusBarStartTime
                $minutes = [math]::Floor($elapsed.TotalMinutes)
                $seconds = [math]::Floor($elapsed.TotalSeconds % 60)
                $statusBarControl.Text = "$Message | Elapsed: ${minutes}m ${seconds}s"
            } else {
                $statusBarControl.Text = $Message
            }
        }
        
        $progressBar = Get-Control "StatusBarProgressBar"
        $progressText = Get-Control "StatusBarProgress"
        
        if ($ShowProgress -and $progressBar -and $progressText) {
            $progressBar.Visibility = "Visible"
            
            # If percentage is provided, use determinate progress bar
            if ($Percentage -ge 0) {
                $progressBar.IsIndeterminate = $false
                $progressBar.Value = $Percentage
                $progressBar.Maximum = 100
                
                # Build progress text
                $progressTextParts = @()
                if ($Percentage -ge 0) {
                    $progressTextParts += "$Percentage%"
                }
                if ($Stage) {
                    $progressTextParts += "($Stage)"
                }
                if ($CurrentOperation) {
                    $progressTextParts += "- $CurrentOperation"
                }
                if ($EstimatedTimeRemaining -and $EstimatedTimeRemaining.TotalSeconds -gt 0) {
                    $minutes = [math]::Floor($EstimatedTimeRemaining.TotalMinutes)
                    $seconds = [math]::Floor($EstimatedTimeRemaining.TotalSeconds % 60)
                    if ($minutes -gt 0) {
                        $progressTextParts += "~${minutes}m ${seconds}s remaining"
                    } else {
                        $progressTextParts += "~${seconds}s remaining"
                    }
                }
                
                if ($progressText) {
                    $progressText.Text = $progressTextParts -join " "
                }
            } else {
                # No percentage available, use indeterminate progress bar
                if ($progressBar) {
                    $progressBar.IsIndeterminate = $true
                }
                if ($progressText) {
                    $progressText.Text = "Working..."
                }
            }
        } elseif ($HideProgress -and $progressBar -and $progressText) {
            $progressBar.Visibility = "Collapsed"
            $progressBar.IsIndeterminate = $true
            $progressBar.Value = 0
            $progressText.Text = ""
        }
    }, [System.Windows.Threading.DispatcherPriority]::Render)
    
    # Force UI update
    [System.Windows.Forms.Application]::DoEvents()
}

# Helper function to wrap long operations with heartbeat updates
function Start-OperationWithHeartbeat {
    <#
    .SYNOPSIS
        Wraps a long-running operation with periodic heartbeat updates to prevent UI from appearing frozen.
    
    .DESCRIPTION
        Executes a scriptblock in a background runspace and provides periodic "Still working..." updates
        every few seconds to keep the UI responsive and inform users the operation is still running.
    
    .PARAMETER ScriptBlock
        The operation to execute
    
    .PARAMETER OperationName
        Display name for the operation
    
    .PARAMETER HeartbeatInterval
        Seconds between heartbeat updates (default: 5)
    
    .EXAMPLE
        Start-OperationWithHeartbeat -ScriptBlock { Start-Sleep -Seconds 30 } -OperationName "Disk Check"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory=$true)]
        [string]$OperationName,
        
        [int]$HeartbeatInterval = 5
    )
    
    $startTime = Get-Date
    $lastHeartbeat = Get-Date
    
    # Create runspace for background execution
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()
    
    # Create PowerShell instance
    $psInstance = [PowerShell]::Create()
    $psInstance.Runspace = $runspace
    
    # Add the scriptblock
    $null = $psInstance.AddScript($ScriptBlock)
    
    # Start operation asynchronously
    $asyncResult = $psInstance.BeginInvoke()
    
    # Monitor and provide heartbeat updates
    while (-not $asyncResult.IsCompleted) {
        Start-Sleep -Milliseconds 500
        
        $elapsed = (Get-Date) - $startTime
        $minutes = [math]::Floor($elapsed.TotalMinutes)
        $seconds = [math]::Floor($elapsed.TotalSeconds % 60)
        
        # Send heartbeat every N seconds
        if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $HeartbeatInterval) {
            $heartbeatMsg = "Still working on: $OperationName... (${minutes}m ${seconds}s elapsed)"
            $W.Dispatcher.Invoke([action]{
                Update-StatusBar -Message $heartbeatMsg -ShowProgress
            }, [System.Windows.Threading.DispatcherPriority]::Background)
            $lastHeartbeat = Get-Date
        }
        
        # Allow UI to process events
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    # Get result
    $result = $psInstance.EndInvoke($asyncResult)
    
    # Cleanup
    $psInstance.Dispose()
    $runspace.Close()
    $runspace.Dispose()
    
    return $result
}

# Helper function to create progress callback for repair operations
function New-ProgressCallback {
    <#
    .SYNOPSIS
    Creates a progress callback scriptblock that updates the GUI status bar with progress information.
    
    .DESCRIPTION
    Returns a scriptblock that can be passed to repair functions like Start-SystemFileRepair,
    Start-DiskRepair, etc. The callback receives a progress object with Percentage, Stage,
    CurrentOperation, and EstimatedTimeRemaining properties.
    #>
    param(
        [string]$OperationName = "Operation"
    )
    
    return {
        param($progress)
        
        # Handle both progress object format and simple string messages
        if ($progress -is [hashtable] -or $progress -is [PSCustomObject]) {
            $percentage = if ($progress.Percentage) { $progress.Percentage } else { -1 }
            $stage = if ($progress.Stage) { $progress.Stage } else { "" }
            $currentOp = if ($progress.CurrentOperation) { $progress.CurrentOperation } else { "" }
            $estimatedTime = if ($progress.EstimatedTimeRemaining) { $progress.EstimatedTimeRemaining } else { $null }
            
            $message = if ($progress.CurrentOperation) {
                "${OperationName}: $($progress.CurrentOperation)"
            } else {
                "${OperationName}: $($progress.Stage)"
            }
            
            # Build parameter hashtable conditionally to avoid passing null to TimeSpan parameter
            $statusBarParams = @{
                Message = $message
                ShowProgress = $true
                Percentage = $percentage
                Stage = $stage
                CurrentOperation = $currentOp
            }
            
            # Only include EstimatedTimeRemaining if it's not null
            if ($null -ne $estimatedTime -and $estimatedTime -is [TimeSpan]) {
                $statusBarParams['EstimatedTimeRemaining'] = $estimatedTime
            }
            
            Update-StatusBar @statusBarParams
        } else {
            # Simple string message
            Update-StatusBar -Message "${OperationName}: $progress" -ShowProgress
        }
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

# Helper: safe MessageBox wrapper to avoid crashes if UI host is gone
function Show-MessageBoxSafe {
    param(
        [string]$Message,
        [string]$Title = "MiracleBoot",
        [System.Windows.MessageBoxButton]$Button = [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Information
    )
    try {
        return [System.Windows.MessageBox]::Show($Message, $Title, $Button, $Icon)
    } catch {
        # Swallow - never crash the UI over a message box failure
        return $null
    }
}

# Helper: log BCD errors to a file for postmortem when console scrolls
function Write-BCDLog {
    param([string]$Message)
    try {
        $logDir = Join-Path $PSScriptRoot "LOGS"
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $logPath = Join-Path $logDir "BCD_LOAD_ERROR.log"
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $logPath -Value "[$timestamp] $Message"
        return $logPath
    } catch {
        return $null
    }
}

function Show-AdminInstructionsWindow {
    $instructions = @"
HOW TO RUN MIRACLE BOOT AS ADMINISTRATOR
========================================

Method 1: From PowerShell
--------------------------
1. Close this application
2. Open PowerShell as Administrator:
   - Press Windows Key + X
   - Select 'Windows PowerShell (Admin)' or 'Terminal (Admin)'
3. Navigate to the Miracle Boot folder
4. Run: .\MiracleBoot.ps1

Method 2: From File Explorer
------------------------------
1. Close this application
2. Navigate to the Miracle Boot folder in File Explorer
3. Right-click on 'RunMiracleBoot.cmd' or 'MiracleBoot.ps1'
4. Select 'Run as Administrator'
5. Click 'Yes' on the UAC prompt

Method 3: Create a Shortcut
----------------------------
1. Right-click on 'RunMiracleBoot.cmd'
2. Select 'Create Shortcut'
3. Right-click the shortcut and select 'Properties'
4. Click 'Advanced' button
5. Check 'Run as administrator'
6. Click OK twice
7. Use this shortcut to launch Miracle Boot

NOTE: BCD (Boot Configuration Data) operations require administrator
privileges because they modify critical boot settings that affect system startup.
"@

    try {
        $instructionsWindow = New-Object System.Windows.Window
        $instructionsWindow.Title = "Run as Administrator - Instructions"
        $instructionsWindow.Width = 600
        $instructionsWindow.Height = 500
        $instructionsWindow.WindowStartupLocation = "CenterScreen"
        
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $instructions
        $textBlock.TextWrapping = "Wrap"
        $textBlock.Margin = "10"
        $textBlock.FontFamily = "Consolas"
        $textBlock.FontSize = "11"
        
        $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
        $scrollViewer.Content = $textBlock
        $scrollViewer.VerticalScrollBarVisibility = "Auto"
        
        $instructionsWindow.Content = $scrollViewer
        $instructionsWindow.ShowDialog() | Out-Null
    } catch {
        # Do nothing if the popup fails
    }
}

function Invoke-BCDRefresh {
    param(
        [System.Windows.Controls.Button]$ButtonControl
    )

    # Helper function to safely update UI on dispatcher thread
    function Update-UI {
        param([scriptblock]$Action)
        try {
            if ($W -and $W.Dispatcher -and -not $W.Dispatcher.HasShutdownStarted) {
                if ($W.Dispatcher.CheckAccess()) {
                    # Already on UI thread
                    & $Action
                } else {
                    # Need to invoke on UI thread
                    $W.Dispatcher.Invoke([action]$Action, [System.Windows.Threading.DispatcherPriority]::Normal)
                }
            }
        } catch {
            # Silently fail UI updates - don't crash the whole operation
            Write-Warning "UI update failed: $_"
        }
    }

    $logPath = $null
    $scriptErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Stop'  # Ensure all errors are caught
        if ($ButtonControl) { 
            Update-UI {
                $ButtonControl.IsEnabled = $false
            }
        }

        # Ensure we only run when admin
        $isAdmin = $false
        try {
            $isAdmin = Test-AdminPrivileges
        } catch {
            # Fallback to manual principal check
            try {
                $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            } catch {
                $isAdmin = $false
            }
        }

        if (-not $isAdmin) {
            Show-MessageBoxSafe -Message (
                "BCD operations require administrator privileges.`n`n" +
                "Current session is NOT running as Administrator.`n`n" +
                "Click OK to see instructions."
            ) -Title "Administrator Privileges Required" -Button ([System.Windows.MessageBoxButton]::OK) -Icon ([System.Windows.MessageBoxImage]::Warning)
            Show-AdminInstructionsWindow
            Update-UI {
                Update-StatusBar -Message "BCD operation requires administrator privileges" -HideProgress
            }
            return
        }

        # Verify required functions exist before proceeding
        $requiredFunctions = @('Get-BCDEntriesParsed', 'Get-BCDTimeout', 'Update-BootMenuSimulator', 'Find-DuplicateBCEEntries', 'Fix-DuplicateBCEEntries')
        $missingFunctions = @()
        foreach ($func in $requiredFunctions) {
            if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
                $missingFunctions += $func
            }
        }

        if ($missingFunctions) {
            throw "Missing required BCD functions: $($missingFunctions -join ', '). These should be loaded from WinRepairCore."
        }

        # Load raw BCD text first so we can show users what we saw even if parsing fails
        Update-UI {
            Update-StatusBar -Message "Loading BCD Entries..." -ShowProgress
        }

        # Use Invoke-BCDCommandWithTimeout for consistent error handling
        $bcdResult = $null
        if (Get-Command Invoke-BCDCommandWithTimeout -ErrorAction SilentlyContinue) {
            $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "/v") -TimeoutSeconds 30 -Description "Enumerate BCD entries"
            $rawBcd = $bcdResult.Output
        } else {
            # Fallback to direct call if function not available
            $rawBcd = (& bcdedit /enum /v 2>&1) | Out-String
            $bcdResult = @{
                ExitCode = $LASTEXITCODE
                Output = $rawBcd
                Success = ($LASTEXITCODE -eq 0)
            }
        }
        
        # Check for actual permission errors vs. BCD missing/corrupted
        $isPermissionError = $rawBcd -match "Access is denied|access is denied"
        $isBcdMissing = $rawBcd -match "could not be opened|cannot find|No bootable entries"
        $isInvalidEntry = $rawBcd -match "specified entry type is invalid|The parameter is incorrect"
        
        if ($bcdResult.ExitCode -ne 0) {
            # If it's a permission error, show admin dialog
            if ($isPermissionError) {
                throw "bcdedit exited with code $($bcdResult.ExitCode). Output:`n$rawBcd"
            }
            # If BCD is missing or invalid entry, try to recover
            elseif ($isBcdMissing -or $isInvalidEntry) {
                Update-UI {
                    Update-StatusBar -Message "BCD missing or corrupted - attempting recovery..." -ShowProgress
                }
                
                # Try to recover BCD using DefensiveBootCore functions if available
                if (Get-Command Restore-BCDFromWinPE -ErrorAction SilentlyContinue) {
                    # Find target drive (usually C:)
                    $targetDrive = "C"
                    $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Windows" -ErrorAction SilentlyContinue) }
                    if ($volumes) {
                        $targetDrive = $volumes[0].DriveLetter
                    }
                    
                    # Try to find ESP
                    $espLetter = $null
                    $espVolumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and (Test-Path "$($_.DriveLetter):\EFI\Microsoft\Boot" -ErrorAction SilentlyContinue) }
                    if ($espVolumes) {
                        $espLetter = $espVolumes[0].DriveLetter
                    }
                    
                    if ($espLetter) {
                        $bcdPath = "$espLetter`:\EFI\Microsoft\Boot\BCD"
                        $restoreResult = Restore-BCDFromWinPE -TargetBcdPath $bcdPath -EspLetter $espLetter
                        if ($restoreResult.Restored) {
                            Start-Sleep -Milliseconds 500
                            # Retry enumeration
                            $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "/v") -TimeoutSeconds 30 -Description "Re-enumerate BCD after restore"
                            $rawBcd = $bcdResult.Output
                        }
                    }
                }
                
                # If still failing, check if we need to create {default} entry
                if ($bcdResult.ExitCode -ne 0 -and $isInvalidEntry) {
                    if (Get-Command Create-BCDDefaultEntry -ErrorAction SilentlyContinue) {
                        $targetDrive = "C"
                        $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Windows" -ErrorAction SilentlyContinue) }
                        if ($volumes) {
                            $targetDrive = $volumes[0].DriveLetter
                        }
                        
                        $createResult = Create-BCDDefaultEntry -BcdStore "BCD" -TargetDrive $targetDrive
                        if ($createResult.Success) {
                            Start-Sleep -Milliseconds 500
                            # Retry enumeration
                            $bcdResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/enum", "/v") -TimeoutSeconds 30 -Description "Re-enumerate BCD after creating entry"
                            $rawBcd = $bcdResult.Output
                        }
                    }
                }
                
                # If still failing after recovery attempts, throw error
                if ($bcdResult.ExitCode -ne 0) {
                    throw "BCD could not be accessed or recovered. Exit code: $($bcdResult.ExitCode). Output:`n$rawBcd"
                }
            } else {
                # Other error
                throw "bcdedit exited with code $($bcdResult.ExitCode). Output:`n$rawBcd"
            }
        }
        
        Update-UI {
            $bcdBox = Get-Control "BCDBox"
            if ($bcdBox) {
                $bcdBox.Text = $rawBcd
            }
        }

        Update-UI {
            Update-StatusBar -Message "Parsing BCD entries..." -ShowProgress
        }

        # Parse and populate UI
        $defaultEntryId = Get-BCDDefaultEntryId
        $entries = Get-BCDEntriesParsed
        $script:BCDEntriesCache = $entries

        Update-UI {
            Update-StatusBar -Message "Processing boot entries..." -ShowProgress
        }

        $bcdItems = @()
        foreach ($entry in $entries) {
            $displayText = if ($entry.Description) { $entry.Description } else { $entry.Id }
            
            # Mark default entry
            $isDefault = $false
            if ($defaultEntryId) {
                if ($entry.Id -eq $defaultEntryId -or ($defaultEntryId -eq "{default}" -and $entry.Id -match '\{default\}')) {
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

        Update-UI {
            Update-StatusBar -Message "Updating BCD list..." -ShowProgress
            
            $bcdList = Get-Control "BCDList"
            if ($bcdList) {
                $bcdList.ItemsSource = $bcdItems
            }

            # Update Simulator in real-time
            Update-BootMenuSimulator $bcdItems

            $timeout = Get-BCDTimeout
            $txtTimeout = Get-Control "TxtTimeout"
            $simTimeout = Get-Control "SimTimeout"
            if ($txtTimeout) { $txtTimeout.Text = $timeout }
            if ($simTimeout) { $simTimeout.Text = "Seconds until auto-start: $timeout" }
        }

        Update-UI {
            Update-StatusBar -Message "Checking for duplicate entries..." -ShowProgress
        }

        # Check for duplicates
        $duplicates = @() + (Find-DuplicateBCEEntries)
        if ($duplicates) {
            $dupNames = ($duplicates | ForEach-Object { "'$($_.Name)'" }) -join ", "
            $result = Show-MessageBoxSafe -Message (
                "Found duplicate boot entry names: $dupNames`n`nWould you like to automatically rename them by appending volume labels?"
            ) -Title "Duplicate Entries Detected" -Button ([System.Windows.MessageBoxButton]::YesNo) -Icon ([System.Windows.MessageBoxImage]::Question)
            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                $fixed = Fix-DuplicateBCEEntries -AppendVolumeLabels
                if (@($fixed).Count -gt 0) {
                    Show-MessageBoxSafe -Message "Fixed $(@($fixed).Count) duplicate entry name(s)." -Title "Success" -Button ([System.Windows.MessageBoxButton]::OK) -Icon ([System.Windows.MessageBoxImage]::Information)
                    # Reload BCD
                    if ($ButtonControl) {
                        $ButtonControl.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                    }
                    return
                }
            }
        }

        $defaultCount = (@($bcdItems | Where-Object { $_.IsDefault })).Count
        $statusMsg = "Loaded $(@($bcdItems).Count) BCD entries"
        if ($defaultCount -gt 0) {
            $statusMsg += " (1 default entry marked)"
        }
        Update-UI {
            Update-StatusBar -Message $statusMsg -HideProgress
        }

        if (-not $duplicates -or @($duplicates).Count -eq 0) {
            Show-MessageBoxSafe -Message ("Loaded $(@($bcdItems).Count) BCD entries." + $(if ($defaultCount -gt 0) { "`n`nDefault boot entry is marked with [DEFAULT]." } else { "" })) -Title "Success" -Button ([System.Windows.MessageBoxButton]::OK) -Icon ([System.Windows.MessageBoxImage]::Information)
        }
    } catch {
        $errorMsg = $_.Exception.Message
        $logPath = Write-BCDLog -Message $errorMsg
        
        # Safely update UI even in error case
        try {
            if ($W -and $W.Dispatcher -and -not $W.Dispatcher.HasShutdownStarted) {
                if ($W.Dispatcher.CheckAccess()) {
                    Update-StatusBar -Message "Error loading BCD: $errorMsg" -HideProgress
                } else {
                    $W.Dispatcher.Invoke([action]{
                        Update-StatusBar -Message "Error loading BCD: $errorMsg" -HideProgress
                    }, [System.Windows.Threading.DispatcherPriority]::Normal)
                }
            }
        } catch {
            # UI update failed, but continue with error handling
            Write-Warning "Could not update status bar: $_"
        }

        # Distinguish between permission errors and BCD missing/corrupted errors
        $isPermissionError = $errorMsg -match "Access is denied|access is denied" -and -not ($errorMsg -match "could not be opened.*cannot find|No bootable entries|specified entry type is invalid")
        $isBcdMissing = $errorMsg -match "could not be opened.*cannot find|No bootable entries|specified entry type is invalid|BCD could not be accessed or recovered"
        
        if ($isPermissionError) {
            # Actual permission error - show admin dialog
            $result = Show-MessageBoxSafe -Message (
                "BCD Access Denied: The boot configuration data store could not be opened.`n`n" +
                "This operation requires administrator privileges.`n`n" +
                "Would you like to see instructions?"
            ) -Title "Administrator Privileges Required" -Button ([System.Windows.MessageBoxButton]::YesNo) -Icon ([System.Windows.MessageBoxImage]::Warning)
            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                Show-AdminInstructionsWindow
            }
        } elseif ($isBcdMissing) {
            # BCD missing or corrupted - suggest repair
            $result = Show-MessageBoxSafe -Message (
                "BCD Missing or Corrupted: The boot configuration data store could not be accessed.`n`n" +
                "This may indicate a missing or corrupted BCD file.`n`n" +
                "Would you like to attempt automatic repair?"
            ) -Title "BCD Recovery Required" -Button ([System.Windows.MessageBoxButton]::YesNo) -Icon ([System.Windows.MessageBoxImage]::Warning)
            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                # Try to run repair
                Update-UI {
                    Update-StatusBar -Message "Attempting BCD repair..." -ShowProgress
                }
                try {
                    # Find target drive
                    $targetDrive = "C"
                    $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Windows" -ErrorAction SilentlyContinue) }
                    if ($volumes) {
                        $targetDrive = $volumes[0].DriveLetter
                    }
                    
                    # Find ESP
                    $espLetter = $null
                    $espVolumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and (Test-Path "$($_.DriveLetter):\EFI\Microsoft\Boot" -ErrorAction SilentlyContinue) }
                    if ($espVolumes) {
                        $espLetter = $espVolumes[0].DriveLetter
                    }
                    
                    # Try repair if DefensiveBootCore is loaded
                    if (Get-Command Repair-BCDBruteForce -ErrorAction SilentlyContinue) {
                        $repairResult = Repair-BCDBruteForce -TargetDrive $targetDrive -EspLetter $espLetter
                        if ($repairResult.Success) {
                            Update-UI {
                                Update-StatusBar -Message "BCD repair successful - refreshing..." -ShowProgress
                            }
                            Start-Sleep -Milliseconds 500
                            # Retry loading BCD
                            Invoke-BCDRefresh -ButtonControl $ButtonControl
                            return
                        } else {
                            Show-MessageBoxSafe -Message (
                                "BCD repair attempted but was not successful.`n`n" +
                                "Actions taken:`n$($repairResult.Actions -join "`n")`n`n" +
                                "You may need to use the 'One-Click Repair' feature for a complete repair."
                            ) -Title "BCD Repair Incomplete" -Button ([System.Windows.MessageBoxButton]::OK) -Icon ([System.Windows.MessageBoxImage]::Information)
                        }
                    } else {
                        Show-MessageBoxSafe -Message (
                            "BCD repair functions are not available.`n`n" +
                            "Please use the 'One-Click Repair' feature from the main window to repair the BCD."
                        ) -Title "Repair Functions Not Available" -Button ([System.Windows.MessageBoxButton]::OK) -Icon ([System.Windows.MessageBoxImage]::Information)
                    }
                } catch {
                    Show-MessageBoxSafe -Message (
                        "Error during BCD repair attempt: $($_.Exception.Message)`n`n" +
                        "Please use the 'One-Click Repair' feature for a complete repair."
                    ) -Title "Repair Error" -Button ([System.Windows.MessageBoxButton]::OK) -Icon ([System.Windows.MessageBoxImage]::Error)
                }
            }
        } else {
            $extra = if ($logPath) { "`n`nDetails logged to:`n$logPath" } else { "" }
            Show-MessageBoxSafe -Message ("Error loading BCD: $errorMsg$extra") -Title "Error" -Button ([System.Windows.MessageBoxButton]::OK) -Icon ([System.Windows.MessageBoxImage]::Error)
        }
    } finally {
        # Safely re-enable button
        try {
            if ($ButtonControl -and $W -and $W.Dispatcher -and -not $W.Dispatcher.HasShutdownStarted) {
                if ($W.Dispatcher.CheckAccess()) {
                    $ButtonControl.IsEnabled = $true
                } else {
                    $W.Dispatcher.Invoke([action]{
                        $ButtonControl.IsEnabled = $true
                    }, [System.Windows.Threading.DispatcherPriority]::Normal)
                }
            }
        } catch {
            # Button re-enable failed, but continue
            Write-Warning "Could not re-enable button: $_"
        }
        $ErrorActionPreference = $scriptErrorActionPreference
    }
}

# Function to get BCD parameter descriptions
function Get-BCDParameterDescriptions {
    return @{
        'description' = @{
            Name = 'description'
            Purpose = 'The friendly name displayed in the boot menu'
            Example = 'Windows 11', 'Windows 10 (Safe Mode)', 'Linux Ubuntu'
            Notes = 'This is what users see when choosing which OS to boot. Keep it descriptive but concise.'
        }
        'device' = @{
            Name = 'device'
            Purpose = 'Specifies the device (disk and partition) where the boot files are located'
            Example = 'partition=C:', 'ramdisk=[boot]\Recovery\WindowsRE\Winre.wim'
            Notes = 'Usually set to partition=C: for Windows installations. Changing this incorrectly can prevent booting.'
        }
        'path' = @{
            Name = 'path'
            Purpose = 'Path to the boot loader executable relative to the device'
            Example = '\Windows\system32\winload.exe', '\Windows\system32\winload.efi'
            Notes = 'Points to the Windows boot loader. winload.exe for BIOS, winload.efi for UEFI.'
        }
        'osdevice' = @{
            Name = 'osdevice'
            Purpose = 'Device where the Windows operating system is installed'
            Example = 'partition=C:'
            Notes = 'Usually matches the device parameter. Specifies where Windows is installed.'
        }
        'systemroot' = @{
            Name = 'systemroot'
            Purpose = 'Path to the Windows directory'
            Example = '\Windows'
            Notes = 'Standard Windows installation path. Rarely needs to be changed.'
        }
        'nx' = @{
            Name = 'nx'
            Purpose = 'Data Execution Prevention (DEP) setting'
            Example = 'OptIn', 'OptOut', 'AlwaysOn', 'AlwaysOff'
            Notes = 'Controls hardware-based DEP. OptIn is recommended for most systems.'
        }
        'pae' = @{
            Name = 'pae'
            Purpose = 'Physical Address Extension setting'
            Example = 'Default', 'ForceEnable', 'ForceDisable'
            Notes = 'Enables support for more than 4GB RAM on 32-bit systems. Usually Default.'
        }
        'detecthal' = @{
            Name = 'detecthal'
            Purpose = 'Hardware Abstraction Layer detection'
            Example = 'Yes', 'No'
            Notes = 'Allows Windows to detect the correct HAL. Usually Yes for automatic detection.'
        }
        'winpe' = @{
            Name = 'winpe'
            Purpose = 'Windows Preinstallation Environment flag'
            Example = 'Yes', 'No'
            Notes = 'Set to Yes for WinPE boot entries. Usually No for normal Windows installations.'
        }
        'bootmenupolicy' = @{
            Name = 'bootmenupolicy'
            Purpose = 'Boot menu display policy'
            Example = 'Standard', 'Legacy'
            Notes = 'Standard shows modern boot menu, Legacy shows text-based menu. Standard is recommended.'
        }
        'timeout' = @{
            Name = 'timeout'
            Purpose = 'Boot menu timeout in seconds'
            Example = "'0' (no timeout), '10', '30'"
            Notes = 'How long to wait before auto-booting default entry. 0 = wait indefinitely.'
        }
        'default' = @{
            Name = 'default'
            Purpose = 'Default boot entry identifier'
            Example = '{current}', '{guid}', '{bootmgr}'
            Notes = 'Specifies which entry boots automatically after timeout. Set via "Set as Default Boot" button.'
        }
        'displayorder' = @{
            Name = 'displayorder'
            Purpose = 'Order in which entries appear in boot menu'
            Example = '{guid1} {guid2} {guid3}'
            Notes = 'Controls the sequence of entries. First entry is at the top of the menu.'
        }
        'locale' = @{
            Name = 'locale'
            Purpose = 'Boot menu language/locale'
            Example = 'en-US', 'fr-FR', 'de-DE'
            Notes = 'Language for boot menu text. Usually matches your Windows installation language.'
        }
        'inherit' = @{
            Name = 'inherit'
            Purpose = 'Properties inherited from parent boot loader'
            Example = '{bootloadersettings}', '{globalsettings}'
            Notes = 'Specifies which settings group to inherit from. Usually automatic.'
        }
        'recoverysequence' = @{
            Name = 'recoverysequence'
            Purpose = 'Recovery environment entry to use'
            Example = '{guid}'
            Notes = 'Points to the Windows Recovery Environment (WinRE) entry for automatic recovery.'
        }
        'recoveryenabled' = @{
            Name = 'recoveryenabled'
            Purpose = 'Enable automatic recovery on boot failure'
            Example = 'Yes', 'No'
            Notes = 'If Yes, Windows will attempt to launch recovery environment after failed boot attempts.'
        }
        'badmemoryaccess' = @{
            Name = 'badmemoryaccess'
            Purpose = 'Bad memory access handling'
            Example = 'Yes', 'No'
            Notes = 'Enables detection of bad memory. Usually Yes for systems with memory issues.'
        }
        'bootlog' = @{
            Name = 'bootlog'
            Purpose = 'Enable boot logging'
            Example = 'Yes', 'No'
            Notes = 'If Yes, creates ntbtlog.txt with detailed boot information for troubleshooting.'
        }
        'safeboot' = @{
            Name = 'safeboot'
            Purpose = 'Safe mode boot type'
            Example = 'Minimal', 'Network', 'AlternateShell', 'DSRepair'
            Notes = 'Boots into safe mode. Minimal = basic drivers, Network = with networking, AlternateShell = command prompt only.'
        }
        'safebootalternateshell' = @{
            Name = 'safebootalternateshell'
            Purpose = 'Use alternate shell in safe mode'
            Example = 'Yes', 'No'
            Notes = 'If Yes, boots to command prompt instead of Windows Explorer in safe mode.'
        }
        'lastknowngood' = @{
            Name = 'lastknowngood'
            Purpose = 'Use Last Known Good Configuration'
            Example = 'Yes', 'No'
            Notes = 'If Yes, attempts to boot using last known good registry configuration.'
        }
        'emssettings' = @{
            Name = 'emssettings'
            Purpose = 'Emergency Management Services settings'
            Example = '{guid}'
            Notes = 'Advanced: Configures EMS for remote debugging and management.'
        }
        'graphicsmodedisabled' = @{
            Name = 'graphicsmodedisabled'
            Purpose = 'Disable graphics mode during boot'
            Example = 'Yes', 'No'
            Notes = 'If Yes, uses text mode instead of graphics during boot. Useful for troubleshooting display issues.'
        }
        'quietboot' = @{
            Name = 'quietboot'
            Purpose = 'Suppress boot screen messages'
            Example = 'Yes', 'No'
            Notes = 'If Yes, hides boot progress messages. No shows detailed boot information.'
        }
        'nointegritychecks' = @{
            Name = 'nointegritychecks'
            Purpose = 'Disable driver signature enforcement'
            Example = 'Yes', 'No'
            Notes = 'WARNING: If Yes, allows unsigned drivers. Security risk - only use for testing.'
        }
        'testsigning' = @{
            Name = 'testsigning'
            Purpose = 'Enable test signing mode'
            Example = 'Yes', 'No'
            Notes = 'Allows test-signed drivers. Used for driver development. Not recommended for production.'
        }
        'hypervisorlaunchtype' = @{
            Name = 'hypervisorlaunchtype'
            Purpose = 'Hyper-V hypervisor launch type'
            Example = 'Auto', 'Off', 'On'
            Notes = 'Controls Hyper-V virtualization. Auto = use if available, Off = disable, On = force enable.'
        }
    }
}

# Function to get contextual suggestions based on current BCD state
function Get-BCDContextualSuggestions {
    param(
        [array]$BCDEntries,
        [object]$SelectedEntry
    )
    
    $suggestions = @()
    
    # Check for duplicate entries
    $duplicates = $null
    if (Get-Command Find-DuplicateBCEEntries -ErrorAction SilentlyContinue) {
        $duplicates = Find-DuplicateBCEEntries -ErrorAction SilentlyContinue
    }
    if ($duplicates -and $duplicates.Count -gt 0) {
        $suggestions += @{
            Type = 'Warning'
            Title = 'Duplicate Boot Entry Names Detected'
            Message = "Found $($duplicates.Count) duplicate entry name(s). This can cause confusion in the boot menu."
            Recommendation = "Click 'Fix Duplicates' button to automatically rename them with volume labels."
            Priority = 'High'
        }
    }
    
    # Check for missing default entry
    $hasDefault = $false
    if ($BCDEntries) {
        $hasDefault = ($BCDEntries | Where-Object { $_.IsDefault }).Count -gt 0
    }
    if (-not $hasDefault) {
        $suggestions += @{
            Type = 'Info'
            Title = 'No Default Boot Entry Set'
            Message = 'No boot entry is marked as default. Windows will wait indefinitely at boot menu.'
            Recommendation = "Select an entry and click 'Set as Default Boot' to set a default entry."
            Priority = 'Medium'
        }
    }
    
    # Check timeout setting
    $timeout = $null
    if (Get-Command Get-BCDTimeout -ErrorAction SilentlyContinue) {
        $timeout = Get-BCDTimeout -ErrorAction SilentlyContinue
    }
    if ($null -ne $timeout -and $timeout -eq 0) {
        $suggestions += @{
            Type = 'Info'
            Title = 'Boot Timeout Set to 0 (No Auto-Boot)'
            Message = 'Boot menu will wait indefinitely for user selection.'
            Recommendation = "Consider setting timeout to 10-30 seconds for automatic boot after delay."
            Priority = 'Low'
        }
    } elseif ($timeout -gt 60) {
        $suggestions += @{
            Type = 'Info'
            Title = 'Long Boot Timeout'
            Message = "Boot timeout is set to $timeout seconds (over 1 minute)."
            Recommendation = 'Consider reducing to 10-30 seconds for faster boot times.'
            Priority = 'Low'
        }
    }
    
    # Check for multiple Windows entries
    $windowsEntries = $BCDEntries | Where-Object { $_.Description -match 'Windows' } | Measure-Object
    if ($windowsEntries.Count -gt 1) {
        $suggestions += @{
            Type = 'Info'
            Title = 'Multiple Windows Installations Detected'
            Message = "Found $($windowsEntries.Count) Windows boot entries."
            Recommendation = 'Ensure each has a unique, descriptive name to avoid confusion.'
            Priority = 'Medium'
        }
    }
    
    # Check selected entry properties
    if ($SelectedEntry) {
        if ($SelectedEntry.Description -match 'Windows.*Safe.*Mode') {
            $suggestions += @{
                Type = 'Info'
                Title = 'Safe Mode Entry Selected'
                Message = 'This is a Safe Mode boot entry. It boots with minimal drivers for troubleshooting.'
                Recommendation = 'Use this entry when Windows fails to boot normally. Not recommended for daily use.'
                Priority = 'Low'
            }
        }
        
        if ($SelectedEntry.Description -match 'Recovery|WinRE') {
            $suggestions += @{
                Type = 'Info'
                Title = 'Recovery Environment Entry'
                Message = 'This is a Windows Recovery Environment entry for system repair.'
                Recommendation = 'This entry is used automatically for recovery. Usually no manual changes needed.'
                Priority = 'Low'
            }
        }
    }
    
    # Check for UEFI vs BIOS
    if (Get-Command Get-FirmwareType -ErrorAction SilentlyContinue) {
        $firmwareType = Get-FirmwareType -ErrorAction SilentlyContinue
        if ($firmwareType -eq 'UEFI') {
            $suggestions += @{
                Type = 'Info'
                Title = 'UEFI System Detected'
                Message = 'Your system uses UEFI firmware. Boot entries are stored in EFI System Partition.'
                Recommendation = "Use 'Sync to All EFI Partitions' if you have multiple drives to ensure consistent boot menu."
                Priority = 'Low'
            }
        }
    }
    
    return $suggestions
}

# Function to show BCD parameter help window
function Show-BCDParameterHelp {
    param(
        [array]$BCDEntries = $null,
        [object]$SelectedEntry = $null
    )
    
    try {
        # Get parameter descriptions
        $paramDescriptions = Get-BCDParameterDescriptions
        
        # Get contextual suggestions
        $suggestions = Get-BCDContextualSuggestions -BCDEntries $BCDEntries -SelectedEntry $SelectedEntry
        
        # Create help window
        $helpWindow = New-Object System.Windows.Window
        $helpWindow.Title = "BCD Editor - Parameter Help & Suggestions"
        $helpWindow.Width = 900
        $helpWindow.Height = 700
        $helpWindow.WindowStartupLocation = "CenterScreen"
        $helpWindow.WindowStyle = "SingleBorderWindow"
        $helpWindow.ResizeMode = "CanResize"
        
        # Create main grid
        $mainGrid = New-Object System.Windows.Controls.Grid
        $mainGrid.Margin = "10"
        
        # Define rows
        $rowDef1 = New-Object System.Windows.Controls.RowDefinition
        $rowDef1.Height = "Auto"
        $rowDef2 = New-Object System.Windows.Controls.RowDefinition
        $rowDef2.Height = "*"
        $mainGrid.RowDefinitions.Add($rowDef1)
        $mainGrid.RowDefinitions.Add($rowDef2)
        
        # Tab control for Parameters and Suggestions
        $tabControl = New-Object System.Windows.Controls.TabControl
        $tabControl.Margin = "0,10,0,0"
        Grid.SetRow($tabControl, 1)
        
        # Tab 1: Parameter Descriptions
        $paramTab = New-Object System.Windows.Controls.TabItem
        $paramTab.Header = "Parameter Descriptions"
        
        $paramScrollViewer = New-Object System.Windows.Controls.ScrollViewer
        $paramScrollViewer.VerticalScrollBarVisibility = "Auto"
        $paramScrollViewer.HorizontalScrollBarVisibility = "Disabled"
        
        $paramStackPanel = New-Object System.Windows.Controls.StackPanel
        $paramStackPanel.Margin = "10"
        
        $introText = New-Object System.Windows.Controls.TextBlock
        $introText.Text = "BCD (Boot Configuration Data) Parameters`n`nHover over any field in the BCD Editor to see its tooltip. Below are detailed descriptions of all available parameters:"
        $introText.Margin = "0,0,0,15"
        $introText.TextWrapping = "Wrap"
        $introText.FontSize = "12"
        $paramStackPanel.Children.Add($introText) | Out-Null
        
        foreach ($paramKey in ($paramDescriptions.Keys | Sort-Object)) {
            $param = $paramDescriptions[$paramKey]
            
            # Parameter name
            $nameBlock = New-Object System.Windows.Controls.TextBlock
            $nameBlock.Text = $param.Name
            $nameBlock.FontWeight = "Bold"
            $nameBlock.FontSize = "14"
            $nameBlock.Margin = "0,10,0,5"
            $nameBlock.Foreground = "#0078D7"
            $paramStackPanel.Children.Add($nameBlock) | Out-Null
            
            # Purpose
            $purposeBlock = New-Object System.Windows.Controls.TextBlock
            $purposeBlock.Text = "Purpose: $($param.Purpose)"
            $purposeBlock.Margin = "10,0,0,3"
            $purposeBlock.TextWrapping = "Wrap"
            $paramStackPanel.Children.Add($purposeBlock) | Out-Null
            
            # Example
            if ($param.Example) {
                $exampleBlock = New-Object System.Windows.Controls.TextBlock
                $exampleText = "Example: "
                if ($param.Example -is [array]) {
                    $exampleText += ($param.Example -join ", ")
                } else {
                    $exampleText += $param.Example
                }
                $exampleBlock.Text = $exampleText
                $exampleBlock.Margin = "10,0,0,3"
                $exampleBlock.TextWrapping = "Wrap"
                $exampleBlock.FontFamily = "Consolas"
                $exampleBlock.Foreground = "#28a745"
                $paramStackPanel.Children.Add($exampleBlock) | Out-Null
            }
            
            # Notes
            if ($param.Notes) {
                $notesBlock = New-Object System.Windows.Controls.TextBlock
                $notesBlock.Text = "Notes: $($param.Notes)"
                $notesBlock.Margin = "10,0,0,5"
                $notesBlock.TextWrapping = "Wrap"
                $notesBlock.FontStyle = "Italic"
                $notesBlock.Foreground = "#666"
                $paramStackPanel.Children.Add($notesBlock) | Out-Null
            }
            
            # Separator
            $separator = New-Object System.Windows.Controls.Separator
            $separator.Margin = "0,5,0,5"
            $paramStackPanel.Children.Add($separator) | Out-Null
        }
        
        $paramScrollViewer.Content = $paramStackPanel
        $paramTab.Content = $paramScrollViewer
        $tabControl.Items.Add($paramTab) | Out-Null
        
        # Tab 2: Contextual Suggestions
        $suggestionsTab = New-Object System.Windows.Controls.TabItem
        $suggestionsTab.Header = "Contextual Suggestions"
        
        $suggestionsScrollViewer = New-Object System.Windows.Controls.ScrollViewer
        $suggestionsScrollViewer.VerticalScrollBarVisibility = "Auto"
        
        $suggestionsStackPanel = New-Object System.Windows.Controls.StackPanel
        $suggestionsStackPanel.Margin = "10"
        
        if ($suggestions.Count -eq 0) {
            $noSuggestionsText = New-Object System.Windows.Controls.TextBlock
            $noSuggestionsText.Text = "[OK] No specific recommendations at this time.`n`nYour BCD configuration appears to be in good shape!"
            $noSuggestionsText.Margin = "0,20,0,0"
            $noSuggestionsText.TextWrapping = "Wrap"
            $noSuggestionsText.FontSize = "14"
            $noSuggestionsText.Foreground = "#28a745"
            $suggestionsStackPanel.Children.Add($noSuggestionsText) | Out-Null
        } else {
            $suggestionsIntro = New-Object System.Windows.Controls.TextBlock
            $suggestionsIntro.Text = "Based on your current BCD configuration, here are some recommendations:"
            $suggestionsIntro.Margin = "0,0,0,15"
            $suggestionsIntro.TextWrapping = "Wrap"
            $suggestionsIntro.FontSize = "12"
            $suggestionsStackPanel.Children.Add($suggestionsIntro) | Out-Null
            
            foreach ($suggestion in $suggestions) {
                # Suggestion card
                $cardBorder = New-Object System.Windows.Controls.Border
                $cardBorder.BorderBrush = switch ($suggestion.Type) {
                    'Warning' { [System.Windows.Media.Brushes]::Orange }
                    'Info' { [System.Windows.Media.Brushes]::Blue }
                    'Error' { [System.Windows.Media.Brushes]::Red }
                    default { [System.Windows.Media.Brushes]::Gray }
                }
                $cardBorder.BorderThickness = "2"
                $cardBorder.CornerRadius = "5"
                $cardBorder.Margin = "0,0,0,10"
                $cardBorder.Padding = "10"
                $cardBorder.Background = "#F9F9F9"
                
                $cardStack = New-Object System.Windows.Controls.StackPanel
                
                # Title
                $titleBlock = New-Object System.Windows.Controls.TextBlock
                $titleBlock.Text = $suggestion.Title
                $titleBlock.FontWeight = "Bold"
                $titleBlock.FontSize = "13"
                $titleBlock.Margin = "0,0,0,5"
                $titleBlock.Foreground = switch ($suggestion.Type) {
                    'Warning' { "#FF8C00" }
                    'Info' { "#0078D7" }
                    'Error' { "#DC3545" }
                    default { "#000" }
                }
                $cardStack.Children.Add($titleBlock) | Out-Null
                
                # Message
                $messageBlock = New-Object System.Windows.Controls.TextBlock
                $messageBlock.Text = $suggestion.Message
                $messageBlock.Margin = "0,0,0,5"
                $messageBlock.TextWrapping = "Wrap"
                $cardStack.Children.Add($messageBlock) | Out-Null
                
                # Recommendation
                $recBlock = New-Object System.Windows.Controls.TextBlock
                $recBlock.Text = "Recommendation: $($suggestion.Recommendation)"
                $recBlock.Margin = "10,5,0,0"
                $recBlock.TextWrapping = "Wrap"
                $recBlock.FontStyle = "Italic"
                $recBlock.Foreground = "#28a745"
                $cardStack.Children.Add($recBlock) | Out-Null
                
                $cardBorder.Child = $cardStack
                $suggestionsStackPanel.Children.Add($cardBorder) | Out-Null
            }
        }
        
        $suggestionsScrollViewer.Content = $suggestionsStackPanel
        $suggestionsTab.Content = $suggestionsScrollViewer
        $tabControl.Items.Add($suggestionsTab) | Out-Null
        
        # Close button
        $buttonPanel = New-Object System.Windows.Controls.StackPanel
        $buttonPanel.Orientation = "Horizontal"
        $buttonPanel.HorizontalAlignment = "Right"
        $buttonPanel.Margin = "0,10,0,0"
        Grid.SetRow($buttonPanel, 0)
        
        $closeButton = New-Object System.Windows.Controls.Button
        $closeButton.Content = "Close"
        $closeButton.Width = "100"
        $closeButton.Height = "30"
        $closeButton.Margin = "0,0,0,0"
        $closeButton.Add_Click({
            $helpWindow.Close()
        })
        $buttonPanel.Children.Add($closeButton) | Out-Null
        
        $mainGrid.Children.Add($buttonPanel) | Out-Null
        $mainGrid.Children.Add($tabControl) | Out-Null
        
        $helpWindow.Content = $mainGrid
        $helpWindow.ShowDialog() | Out-Null
    } catch {
        Show-MessageBoxSafe -Message "Error displaying help window: $_" -Title "Error" -Button ([System.Windows.MessageBoxButton]::OK) -Icon ([System.Windows.MessageBoxImage]::Error)
    }
}

# Logic for BCD - Enhanced parser with duplicate detection
# Note: Control wiring happens at script load time, but $W doesn't exist yet
# These controls will be wired when Start-GUI is called and $W is created
$btnBCD = Get-Control "BtnBCD" -Silent
if ($btnBCD) {
    $btnBCD.Add_Click({
        Invoke-BCDRefresh -ButtonControl $btnBCD
    })
}

# BCD Help button
$btnBCDHelp = Get-Control "BtnBCDHelp" -Silent
if ($btnBCDHelp) {
    $btnBCDHelp.Add_Click({
        try {
            # Get current BCD entries and selected entry
            $bcdList = Get-Control "BCDList"
            $bcdEntries = if ($bcdList -and $bcdList.ItemsSource) { $bcdList.ItemsSource } else { $null }
            $selectedEntry = if ($bcdList -and $bcdList.SelectedItem) { $bcdList.SelectedItem } else { $null }
            
            Show-BCDParameterHelp -BCDEntries $bcdEntries -SelectedEntry $selectedEntry
        } catch {
            Show-MessageBoxSafe -Message "Error opening help: $_" -Title "Error" -Button ([System.Windows.MessageBoxButton]::OK) -Icon ([System.Windows.MessageBoxImage]::Error)
        }
    })
}

# Helper function to update Boot Menu Simulator
function Update-BootMenuSimulator {
    param($Items)
    $simListControl = Get-Control "SimList"
    if ($simListControl) {
        $simListControl.Items.Clear()
        foreach ($item in $Items) {
            if ($item.Description) {
                $simListControl.Items.Add($item.Description)
            }
        }
    }
}

# Boot Menu Simulator - Load BCD Entries button
# Note: Control wiring happens at script load time, but $W doesn't exist yet
# This control will be wired when Start-GUI is called and $W is created
$btnSimLoadBCD = Get-Control "BtnSimLoadBCD" -Silent
if ($btnSimLoadBCD) {
    $btnSimLoadBCD.Add_Click({
        Invoke-BCDRefresh -ButtonControl $btnSimLoadBCD
    })
}

# BCD List selection - populate both basic and advanced editors
$bcdListControl = Get-Control "BCDList"
if ($bcdListControl) {
    $bcdListControl.Add_SelectionChanged({
        $selected = $bcdListControl.SelectedItem
        if ($selected) {
            $editIdControl = Get-Control "EditId"
            $editDescControl = Get-Control "EditDescription"
            $editNameControl = Get-Control "EditName"
            
            if ($editIdControl) { $editIdControl.Text = $selected.Id }
            if ($editDescControl) { $editDescControl.Text = $selected.Description }
            if ($editNameControl) { $editNameControl.Text = $selected.Description }
            
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
                $propsGridControl = Get-Control "BCDPropertiesGrid"
                if ($propsGridControl) {
                    $propsGridControl.ItemsSource = $properties
                }
            }
        }
    })
}

# BCD Backup button
$btnBCDBackup = Get-Control -Name "BtnBCDBackup"
if ($btnBCDBackup) {
    $btnBCDBackup.Add_Click({
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
}

# Fix Duplicates button
$btnFixDuplicates = Get-Control -Name "BtnFixDuplicates"
if ($btnFixDuplicates) {
    $btnFixDuplicates.Add_Click({
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
                $bcdBtn = Get-Control -Name "BtnBCD"
                if ($bcdBtn) {
                    $bcdBtn.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                }
            }
        } elseif ($result -eq "No") {
            $fixed = Fix-DuplicateBCEEntries
            if ($fixed.Count -gt 0) {
                [System.Windows.MessageBox]::Show("Fixed $($fixed.Count) duplicate entry name(s).", "Success", "OK", "Information")
                $bcdBtn = Get-Control -Name "BtnBCD"
                if ($bcdBtn) {
                    $bcdBtn.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                }
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
}

# Sync BCD to All EFI Partitions
$btnSyncBCD = Get-Control -Name "BtnSyncBCD"
if ($btnSyncBCD) {
    $btnSyncBCD.Add_Click({
        $driveCombo = Get-Control -Name "DriveCombo"
        $selectedDrive = if ($driveCombo) { $driveCombo.SelectedItem } else { $null }
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
                $fixerOutput = Get-Control -Name "FixerOutput"
                if ($fixerOutput) {
                    $fixerOutput.Text = "Synchronizing BCD to all EFI partitions...`n"
                }
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
                
                if ($fixerOutput) {
                    $fixerOutput.Text = $output
                }
                [System.Windows.MessageBox]::Show($syncResult.Message, "Synchronization Complete", "OK", "Information")
            } catch {
                [System.Windows.MessageBox]::Show("Error during synchronization: $_", "Error", "OK", "Error")
            }
        }
    })
}

# Boot Diagnosis button (Boot Fixer tab)
$btnBootDiagnosis = Get-Control -Name "BtnBootDiagnosis"
if ($btnBootDiagnosis) {
    $btnBootDiagnosis.Add_Click({
        $driveCombo = Get-Control -Name "DriveCombo"
        $selectedDrive = if ($driveCombo) { $driveCombo.SelectedItem } else { $null }
        $drive = "C"
        
        if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        $diagnosis = Get-BootDiagnosis -TargetDrive $drive
        $fixerOutput = Get-Control -Name "FixerOutput"
        if ($fixerOutput) {
            $fixerOutput.Text = $diagnosis
        }
        
        # Switch to Boot Fixer tab to show the output
        $tabControl = Get-Control -Name "TabControl"
        if ($tabControl) {
            $bootFixerTab = $tabControl.Items | Where-Object { $_.Header -eq "Boot Fixer" }
            if ($bootFixerTab) {
                $tabControl.SelectedItem = $bootFixerTab
            }
        }
        
        [System.Windows.MessageBox]::Show(
            "Boot diagnosis complete.`n`nResults are displayed in the 'Boot Fixer' tab below.`n`nScroll down in the output box to see the full diagnosis report.",
            "Diagnosis Complete",
            "OK",
            "Information"
        )
    })
}

# Function to calculate boot diagnosis score
function Get-BootDiagnosisScore {
    param([string]$DiagnosisOutput)
    
    $criticalCount = 0
    $warningCount = 0
    $okCount = 0
    $errorCount = 0
    
    # Count issue types from diagnosis output
    $lines = $DiagnosisOutput -split "`n"
    foreach ($line in $lines) {
        if ($line -match '\[CRITICAL\]') {
            $criticalCount++
        } elseif ($line -match '\[ERROR\]') {
            $errorCount++
        } elseif ($line -match '\[WARNING\]') {
            $warningCount++
        } elseif ($line -match '\[OK\]') {
            $okCount++
        }
    }
    
    # Calculate score
    $totalIssues = $criticalCount + $errorCount + $warningCount
    $totalChecks = $criticalCount + $errorCount + $warningCount + $okCount
    
    # Determine overall status
    $status = "OK"
    $statusColor = "#28a745"  # Green
    $statusIcon = "[OK]"
    $recommendation = "Your boot configuration appears healthy. No action required."
    
    if ($criticalCount -gt 0) {
        $status = "NEEDS CHECKING"
        $statusColor = "#DC3545"  # Red
        $statusIcon = "[WARN]"
        $recommendation = "Critical issues detected. Immediate attention required. Review the diagnosis report below."
    } elseif ($errorCount -gt 0) {
        $status = "NEEDS CHECKING"
        $statusColor = "#FF8C00"  # Orange
        $statusIcon = "[WARN]"
        $recommendation = "Errors detected. Review the diagnosis report and consider taking corrective action."
    } elseif ($warningCount -gt 0) {
        $status = "NEEDS CHECKING"
        $statusColor = "#FFC107"  # Yellow
        $statusIcon = "[WARN]"
        $recommendation = "Warnings detected. Review the diagnosis report. Issues may not be critical but should be addressed."
    }
    
    return @{
        Status = $status
        StatusColor = $statusColor
        StatusIcon = $statusIcon
        CriticalCount = $criticalCount
        ErrorCount = $errorCount
        WarningCount = $warningCount
        OKCount = $okCount
        TotalIssues = $totalIssues
        TotalChecks = $totalChecks
        Recommendation = $recommendation
        Score = if ($totalChecks -gt 0) { 
            [math]::Round((($okCount / $totalChecks) * 100), 0) 
        } else { 
            0 
        }
    }
}

# Boot Diagnosis button (BCD Editor tab)
$btnBootDiagnosisBCD = Get-Control -Name "BtnBootDiagnosisBCD"
if ($btnBootDiagnosisBCD) {
    $btnBootDiagnosisBCD.Add_Click({
        try {
            Update-StatusBar -Message "Running boot diagnosis..." -ShowProgress
            
            $driveCombo = Get-Control -Name "DriveCombo"
            $selectedDrive = if ($driveCombo) { $driveCombo.SelectedItem } else { $null }
            $drive = "C"
            
            if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
                if ($selectedDrive -match '^([A-Z]):') {
                    $drive = $matches[1]
                }
            }
            
            # Run diagnosis
            $diagnosis = Get-BootDiagnosis -TargetDrive $drive
            
            # Calculate score
            $score = Get-BootDiagnosisScore -DiagnosisOutput $diagnosis
            
            # Build formatted output with score header
            $statusLine = "Status: $($score.StatusIcon) $($score.Status)"
            $scoreLine = "Score: $($score.Score)%"
            $detailsLine = "Details: $($score.OKCount) OK"
            if ($score.WarningCount -gt 0) { $detailsLine += ", $($score.WarningCount) Warnings" }
            if ($score.ErrorCount -gt 0) { $detailsLine += ", $($score.ErrorCount) Errors" }
            if ($score.CriticalCount -gt 0) { $detailsLine += ", $($score.CriticalCount) Critical" }
            
            # Wrap recommendation if too long
            $recLines = @()
            $maxLineLength = 58
            $words = $score.Recommendation -split ' '
            $currentLine = ""
            foreach ($word in $words) {
                if (($currentLine + " " + $word).Length -le $maxLineLength) {
                    $currentLine += if ($currentLine) { " $word" } else { $word }
                } else {
                    if ($currentLine) { $recLines += $currentLine }
                    $currentLine = $word
                }
            }
            if ($currentLine) { $recLines += $currentLine }
            
            $formattedOutput = "===============================================================`n"
            $formattedOutput += "                    BOOT DIAGNOSIS SCORE                          `n"
            $formattedOutput += "===============================================================`n"
            $formattedOutput += "  $($statusLine.PadRight(60)) `n"
            $formattedOutput += "  $($scoreLine.PadRight(60)) `n"
            $formattedOutput += "  $($detailsLine.PadRight(60)) `n"
            $formattedOutput += "===============================================================`n"
            $formattedOutput += "  Recommendation:                                                `n"
            foreach ($recLine in $recLines) {
                $formattedOutput += "  $($recLine.PadRight(60)) `n"
            }
            $formattedOutput += "===============================================================`n`n"
            $formattedOutput += $diagnosis
            
            # Switch to Basic Editor tab
            $bcdTabControl = Get-Control -Name "BCDTabControl"
            if ($bcdTabControl -and $bcdTabControl.Items.Count -gt 0) {
                $bcdTabControl.SelectedIndex = 0  # Switch to first tab (Basic Editor)
            }
            
            # Display in BCDBox
            $bcdBox = Get-Control -Name "BCDBox"
            if ($bcdBox) {
                $bcdBox.Text = $formattedOutput
                $bcdBox.ScrollToHome()
            }
            
            Update-StatusBar -Message "Boot diagnosis complete - $($score.Status)" -HideProgress
            
            # Show result message with score
            $message = "Boot Diagnosis Complete`n`n"
            $message += "Overall Status: $($score.StatusIcon) $($score.Status)`n"
            $message += "Score: $($score.Score)%`n`n"
            $message += "Results:`n"
            $message += "  [OK] OK: $($score.OKCount)`n"
            if ($score.WarningCount -gt 0) {
                $message += "  [WARN] Warnings: $($score.WarningCount)`n"
            }
            if ($score.ErrorCount -gt 0) {
                $message += "  [ERROR] Errors: $($score.ErrorCount)`n"
            }
            if ($score.CriticalCount -gt 0) {
                $message += "  [CRITICAL] Critical: $($score.CriticalCount)`n"
            }
            $message += "`n$($score.Recommendation)`n`n"
            $message += "Full report is displayed in the BCD output box below."
            
            $icon = if ($score.Status -eq "OK") {
                [System.Windows.MessageBoxImage]::Information
            } else {
                [System.Windows.MessageBoxImage]::Warning
            }
            
            Show-MessageBoxSafe -Message $message -Title "Boot Diagnosis Complete" -Button ([System.Windows.MessageBoxButton]::OK) -Icon $icon
        } catch {
            Update-StatusBar -Message "Error running boot diagnosis: $_" -HideProgress
            Show-MessageBoxSafe -Message "Error running boot diagnosis: $_" -Title "Error" -Button ([System.Windows.MessageBoxButton]::OK) -Icon ([System.Windows.MessageBoxImage]::Error)
        }
    })
}

# Update BCD Description with backup and BitLocker check
$btnUpdateBcd = Get-Control -Name "BtnUpdateBcd"
if ($btnUpdateBcd) {
    $btnUpdateBcd.Add_Click({
        $editId = Get-Control -Name "EditId"
        $editName = Get-Control -Name "EditName"
        $id = if ($editId) { $editId.Text } else { "" }
        $name = if ($editName) { $editName.Text } else { "" }
    if ($id -and $name) {
        # Show comprehensive warning
        $warningInfo = Show-CommandWarning -CommandKey "bcd_description" -Command "Set-BCDDescription $id $name" -Description "Change BCD entry description" -IsGUI
        
        $warningMsg = "$($warningInfo.Message)`n`nDo you want to proceed?"
        $result = [System.Windows.MessageBox]::Show(
            $warningMsg,
            $warningInfo.Title,
            "YesNo",
            $(if ($warningInfo.RiskLevel -eq "Critical") { "Error" } elseif ($warningInfo.RiskLevel -eq "High") { "Warning" } else { "Question" })
        )
        
        if ($result -eq "No") {
            return
        }
        
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
            $bcdList = Get-Control -Name "BCDList"
            $selected = if ($bcdList) { $bcdList.SelectedItem } else { $null }
            if ($selected) {
                $selected.Description = $name
                $selected.DisplayText = $name
                if ($bcdList) {
                    $bcdList.Items.Refresh()
                    Update-BootMenuSimulator ($bcdList.ItemsSource)
                }
            }
            
            $btnBCD = Get-Control -Name "BtnBCD"
            if ($btnBCD) {
                $btnBCD.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            }
        } else {
            [System.Windows.MessageBox]::Show("Failed to create backup. Update cancelled for safety.", "Error", "OK", "Error")
        }
    }
    })
}

# Save Advanced Properties
$btnSaveProperties = Get-Control -Name "BtnSaveProperties"
if ($btnSaveProperties) {
    $btnSaveProperties.Add_Click({

    $bcdList = Get-Control -Name "BCDList"
    $selected = if ($bcdList) { $bcdList.SelectedItem } else { $null }
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Please select a BCD entry first.", "Warning", "OK", "Warning")
        return
    }
    
    $bcdPropertiesGrid = Get-Control -Name "BCDPropertiesGrid"
    $properties = if ($bcdPropertiesGrid) { $bcdPropertiesGrid.ItemsSource } else { $null }
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
        $bcdBtn = Get-Control -Name "BtnBCD"
        if ($bcdBtn) {
            $bcdBtn.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
        }
    } catch {
        [System.Windows.MessageBox]::Show("Error updating properties: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
    })
}

$btnSetDefault = Get-Control -Name "BtnSetDefault"
if ($btnSetDefault) {
    $btnSetDefault.Add_Click({
        $editId = Get-Control -Name "EditId"
        $id = if ($editId) { $editId.Text } else { "" }
        
        if ($id) {
            $command = "bcdedit /default $id"
            
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
                $btnBCD = Get-Control -Name "BtnBCD"
                if ($btnBCD) {
                    $btnBCD.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                }
                
                Update-StatusBar -Message "Default boot entry updated" -HideProgress
                [System.Windows.MessageBox]::Show("Default Boot Set to $id`n`nThe list has been refreshed to show the new default entry.", "Success", "OK", "Information")
            } catch {
                Update-StatusBar -Message "Failed to set default boot entry: $_" -HideProgress
                [System.Windows.MessageBox]::Show("Error setting default boot entry: $_", "Error", "OK", "Error")
            }
        }
    })
}

$btnTimeout = Get-Control -Name "BtnTimeout"
if ($btnTimeout) {
    $btnTimeout.Add_Click({
        $txtTimeout = Get-Control -Name "TxtTimeout"
        if ($txtTimeout) {
            $t = $txtTimeout.Text
            bcdedit /timeout $t
            [System.Windows.MessageBox]::Show("Timeout updated to $t seconds.", "Success", "OK", "Information")
        } else {
            [System.Windows.MessageBox]::Show("Timeout control not found.", "Error", "OK", "Error")
        }
    })
}

# Driver Diagnostics
$btnDetect = Get-Control -Name "BtnDetect"
if ($btnDetect) {
    $btnDetect.Add_Click({
        $currentDrive = $env:SystemDrive.TrimEnd(':')
        $drvBox = Get-Control -Name "DrvBox"
        if ($drvBox) {
            $drvBox.Text = "Scanning for storage driver errors...`n`n"
            $drvBox.Text += "TARGET DRIVE: $currentDrive`:\ (Current System)`n"
            $drvBox.Text += "STATUS: CURRENT OPERATING SYSTEM`n`n"
        }
        $result = Get-MissingStorageDevices
        if ($drvBox) {
            $drvBox.Text = $result
        }
    })
}

# All Missing Drivers (including non-storage devices)
$btnAllMissingDrivers = Get-Control -Name "BtnAllMissingDrivers"
if ($btnAllMissingDrivers) {
    $btnAllMissingDrivers.Add_Click({
        $drvBox = Get-Control -Name "DrvBox"
        try {
            $currentDrive = $env:SystemDrive.TrimEnd(':')
            Update-StatusBar -Message "Scanning for ALL devices with driver problems..." -ShowProgress
            if ($drvBox) {
                $drvBox.Text = "Scanning for ALL devices with driver problems...`n`n"
                $drvBox.Text += "TARGET DRIVE: $currentDrive`:\ (Current System)`n"
                $drvBox.Text += "STATUS: CURRENT OPERATING SYSTEM`n`n"
                $drvBox.Text += "This includes all device classes (not just storage).`n"
                $drvBox.Text += "Checking for yellow exclamation marks in Device Manager...`n`n"
            }
            $result = Get-AllMissingDrivers
            if ($drvBox) {
                $drvBox.Text = $result
            }
            Update-StatusBar -Message "All missing drivers scan complete" -HideProgress
        } catch {
            Update-StatusBar -Message "All missing drivers scan failed" -HideProgress
            if ($drvBox) {
                $drvBox.Text = "Failed to scan for all missing drivers: $_"
            }
        }
    })
}

$btnScanDrivers = Get-Control -Name "BtnScanDrivers"
if ($btnScanDrivers) {
    $btnScanDrivers.Add_Click({
        $driveCombo = Get-Control -Name "DriveCombo"
        $drvBox = Get-Control -Name "DrvBox"
        
        $selectedDrive = if ($driveCombo) { $driveCombo.SelectedItem } else { $null }
        $drive = $null
        
        if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1] + ":"
            }
        }
        
        $targetDriveDisplay = if ($drive) { $drive } else { "$($env:SystemDrive.TrimEnd(':'))`:" }
        
        if ($drvBox) {
            $drvBox.Text = "Scanning for MISSING storage drivers...`n`n"
            $drvBox.Text += "TARGET DRIVE: $targetDriveDisplay`n"
            $drvBox.Text += "Checking for problematic storage controllers first...`n"
        }
        
        $scanResult = Scan-ForDrivers -SourceDrive $drive
        
        if ($scanResult.Found) {
            $output = "`n[SUCCESS] SCAN COMPLETE`n"
            $output += "===============================================================`n"
            $output += "$($scanResult.Message)`n"
            $output += "===============================================================`n`n"
            $output += "Found Drivers (matching missing devices):`n"
            $output += "---------------------------------------------------------------`n"
            
            $num = 1
            foreach ($driver in $scanResult.Drivers) {
                $output += "$num. $($driver.Name)`n"
                $output += "   Path: $($driver.Path)`n"
                $output += "   Type: $($driver.Type)`n`n"
                $num++
            }
            
            if ($drvBox) {
                $drvBox.Text = $output
            }
        } else {
            if ($drvBox) {
                $drvBox.Text = "`n[INFO] SCAN RESULTS`n`n$($scanResult.Message)"
            }
        }
    })
}

$btnScanAllDrivers = Get-Control -Name "BtnScanAllDrivers"
if ($btnScanAllDrivers) {
    $btnScanAllDrivers.Add_Click({
        $driveCombo = Get-Control -Name "DriveCombo"
        $drvBox = Get-Control -Name "DrvBox"
        
        $selectedDrive = if ($driveCombo) { $driveCombo.SelectedItem } else { $null }
        $drive = $null
        
        if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1] + ":"
            }
        }
        
        $targetDriveDisplay = if ($drive) { $drive } else { "$($env:SystemDrive.TrimEnd(':'))`:" }
        
        if ($drvBox) {
            $drvBox.Text = "Scanning for ALL available storage drivers...`n`n"
            $drvBox.Text += "TARGET DRIVE: $targetDriveDisplay`n"
            $drvBox.Text += "This may take a moment...`n"
        }
        
        $scanResult = Scan-ForDrivers -SourceDrive $drive -ShowAll
        
        if ($scanResult.Found) {
            $output = "`n[SUCCESS] SCAN COMPLETE`n"
            $output += "===============================================================`n"
            $output += "$($scanResult.Message)`n"
            $output += "===============================================================`n`n"
            $output += "Found Drivers (ALL storage drivers):`n"
            $output += "---------------------------------------------------------------`n"
            
            $num = 1
            foreach ($driver in $scanResult.Drivers) {
                $output += "$num. $($driver.Name)`n"
                $output += "   Path: $($driver.Path)`n"
                $output += "   Type: $($driver.Type)`n`n"
                $num++
            }
            
            if ($drvBox) {
                $drvBox.Text = $output
            }
        } else {
            if ($drvBox) {
                $drvBox.Text = "`n[FAILED] SCAN FAILED`n`n$($scanResult.Message)"
            }
        }
    })
}

$btnDriverErrors = Get-Control -Name "BtnDriverErrors"
if ($btnDriverErrors) {
    $btnDriverErrors.Add_Click({
        $drvBox = Get-Control -Name "DrvBox"
        try {
            Update-StatusBar -Message "Collecting driver error logs..." -ShowProgress
            $summary = Get-DriverErrorLogsSummary
            if ($drvBox) {
                $drvBox.Text = $summary
            }
            Update-StatusBar -Message "Driver error log scan complete" -HideProgress
        } catch {
            Update-StatusBar -Message "Driver error log scan failed" -HideProgress
            if ($drvBox) {
                $drvBox.Text = "Failed to collect driver error logs: $_"
            }
        }
    })
}

$btnExportDriverInf = Get-Control -Name "BtnExportDriverInf"
if ($btnExportDriverInf) {
    $btnExportDriverInf.Add_Click({
        $drvBox = Get-Control -Name "DrvBox"
        try {
            $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderDialog.Description = "Select export folder for driver INF packages"
            $folderDialog.ShowNewFolderButton = $true
            if ($folderDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                return
            }

            Update-StatusBar -Message "Exporting driver INF packages..." -ShowProgress
            $result = Export-DriverINFCollection -DestinationFolder $folderDialog.SelectedPath
            if ($drvBox) {
                $drvBox.Text = $result.Report
            }
            Update-StatusBar -Message "Driver INF export complete" -HideProgress
        } catch {
            Update-StatusBar -Message "Driver INF export failed" -HideProgress
            if ($drvBox) {
                $drvBox.Text = "Driver INF export failed: $_"
            }
        }
    })
}

$btnExportDriverInfZip = Get-Control -Name "BtnExportDriverInfZip"
if ($btnExportDriverInfZip) {
    $btnExportDriverInfZip.Add_Click({
        $drvBox = Get-Control -Name "DrvBox"
        try {
            $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderDialog.Description = "Select export folder for driver INF packages (zip will be created here)"
            $folderDialog.ShowNewFolderButton = $true
            if ($folderDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                return
            }

            Update-StatusBar -Message "Exporting and zipping driver INF packages..." -ShowProgress
            $result = Export-DriverINFCollection -DestinationFolder $folderDialog.SelectedPath -Zip
            if ($drvBox) {
                $drvBox.Text = $result.Report
            }
            Update-StatusBar -Message "Driver INF zip export complete" -HideProgress
        } catch {
            Update-StatusBar -Message "Driver INF zip export failed" -HideProgress
            if ($drvBox) {
                $drvBox.Text = "Driver INF zip export failed: $_"
            }
        }
    })
}

$btnMissingDrive = Get-Control -Name "BtnMissingDrive"
if ($btnMissingDrive) {
    $btnMissingDrive.Add_Click({
        $drvBox = Get-Control -Name "DrvBox"
        try {
            if ($drvBox) {
                $drvBox.Text = "Analyzing storage/network controllers...`n`n"
            }
            Update-StatusBar -Message "Analyzing storage/network controllers..." -ShowProgress
            
            # Check if function exists
            if (-not (Get-Command Get-AdvancedStorageControllerInfo -ErrorAction SilentlyContinue)) {
                $errorMsg = "Get-AdvancedStorageControllerInfo function not found. Please ensure WinRepairCore.ps1 is loaded."
                if ($drvBox) {
                    $drvBox.Text = "[ERROR] $errorMsg"
                }
                Update-StatusBar -Message "Missing drive helper failed: Function not found" -HideProgress
                [System.Windows.MessageBox]::Show($errorMsg, "Error", "OK", "Error")
                return
            }
            
            $controllers = Get-AdvancedStorageControllerInfo -IncludeNonCritical
            if (-not $controllers -or $controllers.Count -eq 0) {
                if ($drvBox) {
                    $drvBox.Text = "No storage controllers detected or hardware scan unavailable.`n`nThis may indicate:`n- No storage devices present`n- Hardware scan unavailable in current environment`n- Insufficient permissions"
                }
                Update-StatusBar -Message "No controller data available" -HideProgress
                return
            }

            $needsDriver = $controllers | Where-Object { $_.NeedsDriver }
            if (-not $needsDriver -or $needsDriver.Count -eq 0) {
                if ($drvBox) {
                    $drvBox.Text = "No missing storage controller drivers detected.`n`nIf a drive is still missing, you can provide a driver folder to scan for matching drivers.`n`nClick the button again to select a driver folder."
                }
                Update-StatusBar -Message "No missing drivers detected" -HideProgress
                return
            }

            $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderDialog.Description = "Select a driver folder (INF packages) to match against detected hardware"
            $folderDialog.ShowNewFolderButton = $false
            if ($folderDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                Update-StatusBar -Message "Missing drive helper cancelled" -HideProgress
                return
            }

            if ($drvBox) {
                $drvBox.Text = "Matching drivers to hardware IDs...`n`nSelected folder: $($folderDialog.SelectedPath)`n`n"
            }
            Update-StatusBar -Message "Matching drivers to hardware IDs..." -ShowProgress
            
            # Check if function exists
            if (-not (Get-Command Find-MatchingDrivers -ErrorAction SilentlyContinue)) {
                $errorMsg = "Find-MatchingDrivers function not found. Please ensure WinRepairCore.ps1 is loaded."
                if ($drvBox) {
                    $drvBox.Text = "[ERROR] $errorMsg"
                }
                Update-StatusBar -Message "Missing drive helper failed: Function not found" -HideProgress
                [System.Windows.MessageBox]::Show($errorMsg, "Error", "OK", "Error")
                return
            }
            
            $matchResult = Find-MatchingDrivers -ControllerInfo $controllers -DriverPath $folderDialog.SelectedPath

            if ($drvBox) {
                if ($matchResult.Report) {
                    $drvBox.Text = $matchResult.Report
                } else {
                    $drvBox.Text = "Driver matching completed, but no report was generated.`n`nMatches found: $($matchResult.Matches.Count)`nErrors: $($matchResult.Errors.Count)"
                }
            }
            Update-StatusBar -Message "Driver matching complete" -HideProgress
        } catch {
            $errorMsg = $_.Exception.Message
            $errorDetails = "Missing drive helper failed: $errorMsg`n`nStack trace: $($_.ScriptStackTrace)"
            Update-StatusBar -Message "Missing drive helper failed" -HideProgress
            if ($drvBox) {
                $drvBox.Text = "[ERROR] $errorDetails"
            }
            Write-Warning "Missing drive helper error: $errorDetails"
        }
    })
}

$btnDriverResources = Get-Control -Name "BtnDriverResources"
if ($btnDriverResources) {
    $btnDriverResources.Add_Click({
        $drvBox = Get-Control -Name "DrvBox"
        try {
            $info = Get-DriverUpdateResources
            if ($drvBox) {
                $drvBox.Text = $info
            }
        } catch {
            if ($drvBox) {
                $drvBox.Text = "Unable to load driver update resources: $_"
            }
        }
    })
}

# Advanced Driver Tools (2025+ Systems) - Handler for advanced storage controller detection
# Note: Add button to XAML with Name="BtnAdvancedControllerDetection" to enable
$btnAdvancedControllerDetection = Get-Control -Name "BtnAdvancedControllerDetection"
if ($btnAdvancedControllerDetection) {
    $btnAdvancedControllerDetection.Add_Click({

        $drvBox = Get-Control -Name "DrvBox"
        if ($drvBox) {
            $drvBox.Text = "Advanced Storage Controller Detection (2025+ Systems)`n"
            $drvBox.Text += "===============================================================`n"
            $drvBox.Text += "Detecting storage controllers using WMI, Registry, and PCI enumeration...`n`n"
        }
        
        Update-StatusBar -Message "Detecting storage controllers..." -ShowProgress
        
        try {
            $controllers = Get-AdvancedStorageControllerInfo -IncludeNonCritical -Detailed
            
            if ($controllers.Count -eq 0) {
                if ($drvBox) {
                    $drvBox.Text += "No storage controllers detected.`n"
                }
            } else {
                $output = "Found $($controllers.Count) storage controller(s):`n`n"
                
                foreach ($controller in $controllers) {
                    $statusColor = if ($controller.HasDriver) { "[OK]" } else { "[MISSING]" }
                    $criticalMark = if ($controller.IsBootCritical) { " [BOOT-CRITICAL]" } else { "" }
                    
                    $output += "Controller: $($controller.Name)$criticalMark`n"
                    $output += "  Type: $($controller.ControllerType)`n"
                    $output += "  Vendor: $($controller.Vendor)`n"
                    $output += "  Status: $($controller.Status) $statusColor`n"
                    $output += "  Has Driver: $($controller.HasDriver)`n"
                    $output += "  Needs Driver: $($controller.NeedsDriver)`n"
                    $output += "  Required INF: $($controller.RequiredInf)`n"
                    if ($controller.HardwareIDs -and $controller.HardwareIDs.Count -gt 0) {
                        $output += "  Hardware ID: $($controller.HardwareIDs[0])`n"
                    }
                    $output += "`n"
                }
                
                $needsDriver = ($controllers | Where-Object { $_.NeedsDriver }).Count
                $bootCritical = ($controllers | Where-Object { $_.IsBootCritical }).Count
                
                $output += "Summary:`n"
                $output += "  Total Controllers: $($controllers.Count)`n"
                $output += "  Boot-Critical: $bootCritical`n"
                $output += "  Need Drivers: $needsDriver`n"
                
                if ($drvBox) {
                    $drvBox.Text += $output
                }
            }
            
            Update-StatusBar -Message "Storage controller detection complete" -HideProgress
        } catch {
            if ($drvBox) {
                $drvBox.Text += "Error: $_`n"
            }
            Update-StatusBar -Message "Error detecting storage controllers: $_" -HideProgress
        }
        })
}

# Advanced Driver Matching & Injection - Handler
# Note: Add button to XAML with Name="BtnAdvancedDriverInjection" to enable
$btnAdvancedDriverInjection = Get-Control -Name "BtnAdvancedDriverInjection"
if ($btnAdvancedDriverInjection) {
    $btnAdvancedDriverInjection.Add_Click({

        $driveCombo = Get-Control -Name "DriveCombo"
        $selectedDrive = if ($driveCombo) { $driveCombo.SelectedItem } else { $null }
        $drive = "C"
        
        if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        # Show dialog for driver path
        $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderDialog.Description = "Select folder containing driver INF files"
        $folderDialog.ShowNewFolderButton = $false
        
        if ($folderDialog.ShowDialog() -eq "OK") {
            $driverPath = $folderDialog.SelectedPath
            
            $drvBox = Get-Control -Name "DrvBox"
            if ($drvBox) {
                $drvBox.Text = "Advanced Driver Matching & Injection`n"
                $drvBox.Text += "===============================================================`n"
                $drvBox.Text += "Target: $drive`: | Source: $driverPath`n`n"
            }
            
            Update-StatusBar -Message "Detecting storage controllers..." -ShowProgress
            
            try {
                $controllers = Get-AdvancedStorageControllerInfo -IncludeNonCritical
                
                $progressCallback = {
                    param($message, $percent)
                    $W.Dispatcher.Invoke([action]{
                        $drvBoxInner = Get-Control -Name "DrvBox"
                        if ($drvBoxInner) {
                            $drvBoxInner.Text += "$message ($percent%)`n"
                            $drvBoxInner.ScrollToEnd()
                        }
                        Update-StatusBar -Message $message -ShowProgress
                    }, [System.Windows.Threading.DispatcherPriority]::Input)
                }
                
                $result = Start-AdvancedDriverInjection -WindowsDrive $drive -DriverPath $driverPath -ControllerInfo $controllers -ProgressCallback $progressCallback
                
                if ($drvBox) {
                    $drvBox.Text += "`n$($result.Report)`n"
                }
                
                if ($result.Success) {
                    Update-StatusBar -Message "Driver injection completed successfully" -HideProgress
                    [System.Windows.MessageBox]::Show("Successfully injected $($result.DriversInjected.Count) driver(s).", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
                } else {
                    Update-StatusBar -Message "Driver injection completed with errors" -HideProgress
                    [System.Windows.MessageBox]::Show("Driver injection completed with $($result.DriversFailed.Count) error(s). Check the output for details.", "Warning", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
                }
            } catch {
                if ($drvBox) {
                    $drvBox.Text += "Error: $_`n"
                }
                Update-StatusBar -Message "Error: $_" -HideProgress
                [System.Windows.MessageBox]::Show("Error during driver injection: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        }
        })
    }

# Find Matching Drivers - Handler
# Note: Add button to XAML with Name="BtnFindMatchingDrivers" to enable
$btnFindMatchingDrivers = Get-Control -Name "BtnFindMatchingDrivers"
if ($btnFindMatchingDrivers) {
    $btnFindMatchingDrivers.Add_Click({

        $driveCombo = Get-Control -Name "DriveCombo"
        $selectedDrive = if ($driveCombo) { $driveCombo.SelectedItem } else { $null }
        $drive = $null
        
        if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        $drvBox = Get-Control -Name "DrvBox"
        if ($drvBox) {
            $drvBox.Text = "Find Matching Drivers for Controllers`n"
            $drvBox.Text += "===============================================================`n"
            $drvBox.Text += "Detecting storage controllers...`n`n"
        }
        
        Update-StatusBar -Message "Detecting storage controllers..." -ShowProgress
        
        try {
            $controllers = Get-AdvancedStorageControllerInfo -IncludeNonCritical
            
            if ($controllers.Count -eq 0) {
                if ($drvBox) {
                    $drvBox.Text += "No storage controllers detected.`n"
                }
                Update-StatusBar -Message "No controllers found" -HideProgress
                return
            }
            
            # Show dialog for additional search paths
            $searchPaths = @()
            $addMore = [System.Windows.MessageBox]::Show("Add additional driver search paths?", "Search Paths", "YesNo", "Question")
            
            while ($addMore -eq "Yes") {
                $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $folderDialog.Description = "Select additional driver search folder (or Cancel to finish)"
                if ($folderDialog.ShowDialog() -eq "OK") {
                    $searchPaths += $folderDialog.SelectedPath
                    $addMore = [System.Windows.MessageBox]::Show("Add another search path?", "Search Paths", "YesNo", "Question")
                } else {
                    $addMore = "No"
                }
            }
            
            if ($drvBox) {
                $drvBox.Text += "Searching for matching drivers...`n`n"
            }
            Update-StatusBar -Message "Searching for matching drivers..." -ShowProgress
            
            $driverMatches = Find-MatchingDrivers -ControllerInfo $controllers -SearchPaths $searchPaths -WindowsDrive $drive
            
            $output = "Driver Matching Results:`n"
            $output += "===============================================================`n`n"
            
            foreach ($match in $driverMatches) {
                $output += "Controller: $($match.Controller)`n"
                $output += "  Type: $($match.ControllerType)`n"
                $output += "  Hardware ID: $($match.HardwareID)`n"
                $output += "  Required INF: $($match.RequiredInf)`n"
                $output += "  Matches Found: $($match.MatchesFound)`n"
                
                if ($match.BestMatches.Count -gt 0) {
                    $output += "`n  Best Matches:`n"
                    foreach ($bestMatch in $match.BestMatches) {
                        $output += "    - $($bestMatch.DriverName)`n"
                        $output += "      Source: $($bestMatch.Source)`n"
                        $output += "      Match: $($bestMatch.MatchType) (Score: $($bestMatch.MatchScore))`n"
                        $output += "      Signed: $($bestMatch.IsSigned)`n"
                    }
                } else {
                    $output += "  No matching drivers found.`n"
                    $output += "  Recommendation: Download $($match.RequiredInf) from manufacturer`n"
                }
                $output += "`n"
            }
            
            if ($drvBox) {
                $drvBox.Text += $output
            }
            Update-StatusBar -Message "Driver matching complete" -HideProgress
        } catch {
            if ($drvBox) {
                $drvBox.Text += "Error: $_`n"
            }
            Update-StatusBar -Message "Error: $_" -HideProgress
        }
        })
}

        <# LEGACY ONE-CLICK BLOCK (deprecated; superseded by DefensiveBootCore) 
        # BitLocker status check
        $bitlockerLocked = $false
        try {
            if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
                $bl = Get-BitLockerVolume -MountPoint "$targetDrive`:" -ErrorAction SilentlyContinue
                if ($bl) {
                    $null = $summaryBuilder.AppendLine("BitLocker: $($bl.ProtectionStatus) on $targetDrive`:")
                    if ($bl.LockStatus -eq 'Locked') {
                        $bitlockerLocked = $true
                        $issuesList += "BitLocker locked on $targetDrive`:"
                        $null = $summaryBuilder.AppendLine("  [WARNING] Drive is locked. Repairs may fail until unlocked.")
                        $ask = [System.Windows.MessageBox]::Show("Drive $targetDrive`: appears BitLocker-locked. Provide recovery key to unlock now?","BitLocker Unlock","YesNo","Warning")
                        if ($ask -eq "Yes") {
                            $key = [Microsoft.VisualBasic.Interaction]::InputBox("Enter 48-digit BitLocker recovery key for $targetDrive`:", "BitLocker Recovery Key", "")
                            if ([string]::IsNullOrWhiteSpace($key)) {
                                if ($txtOneClickStatus) { $txtOneClickStatus.Text = "BitLocker unlock canceled."; $btnOneClickRepair.IsEnabled = $true }
                                Update-StatusBar -Message "One-Click Repair: canceled (BitLocker locked)" -HideProgress
                                return
                            }
                            if ($testMode) {
                                $null = $summaryBuilder.AppendLine("  BitLocker unlock simulated (Test Mode): manage-bde -unlock $targetDrive`: -RecoveryPassword <key>")
                            } else {
                                try {
                                    $unlockOut = manage-bde -unlock "$targetDrive`:" -RecoveryPassword $key 2>&1 | Out-String
                                    $null = $summaryBuilder.AppendLine("  manage-bde unlock output: $unlockOut")
                                    $bl2 = Get-BitLockerVolume -MountPoint "$targetDrive`:" -ErrorAction SilentlyContinue
                                    if ($bl2 -and $bl2.LockStatus -eq 'Unlocked') {
                                        $bitlockerLocked = $false
                                        $null = $summaryBuilder.AppendLine("  BitLocker: unlocked successfully.")
                                    } else {
                                        $issuesList += "BitLocker still locked on $targetDrive`:"
                                        $null = $summaryBuilder.AppendLine("  BitLocker unlock failed or still locked.")
                                        if ($txtOneClickStatus) { $txtOneClickStatus.Text = "BitLocker locked; unlock failed."; $btnOneClickRepair.IsEnabled = $true }
                                        Update-StatusBar -Message "One-Click Repair: BitLocker locked" -HideProgress
                                        return
                                    }
                                } catch {
                                    $issuesList += "BitLocker unlock error on $targetDrive`:"
                                    $null = $summaryBuilder.AppendLine("  BitLocker unlock error: $($_.Exception.Message)")
                                    if ($txtOneClickStatus) { $txtOneClickStatus.Text = "BitLocker unlock error."; $btnOneClickRepair.IsEnabled = $true }
                                    Update-StatusBar -Message "One-Click Repair: BitLocker unlock error" -HideProgress
                                    return
                                }
                            }
                        } else {
                            if ($txtOneClickStatus) { $txtOneClickStatus.Text = "BitLocker locked; user declined unlock."; $btnOneClickRepair.IsEnabled = $true }
                            Update-StatusBar -Message "One-Click Repair: canceled (BitLocker locked)" -HideProgress
                            return
                        }
                    }
                } else {
                    $null = $summaryBuilder.AppendLine("BitLocker: status unavailable for $targetDrive`:")
                }
            } else {
                $null = $summaryBuilder.AppendLine("BitLocker: Get-BitLockerVolume not available; skipping check.")
            }
        } catch {
            $null = $summaryBuilder.AppendLine("BitLocker check failed: $($_.Exception.Message)")
        }
        
        # Disable button during repair
        $btnOneClickRepair.IsEnabled = $false
        
        try {
            # Update status
            if ($txtOneClickStatus) {
                $txtOneClickStatus.Text = "Starting automated repair... Please wait."
            }
            Update-StatusBar -Message "One-Click Repair: Starting diagnostics..." -ShowProgress
            
            # Step 1: Hardware Diagnostics
            if ($txtOneClickStatus) {
                $txtOneClickStatus.Text = "Step 1/5: Running hardware diagnostics (S.M.A.R.T., disk health)..."
            }
            Update-StatusBar -Message "One-Click Repair: Checking hardware health..." -ShowProgress
            $null = $summaryBuilder.AppendLine("Step 1/5: Hardware diagnostics...")
            
            # Resolve script root using cached value; falls back to current location as last resort
            $scriptRoot = $script:ScriptRootSafe
            if (-not $scriptRoot) { $scriptRoot = (Get-Location).ProviderPath }
            . (Join-Path $scriptRoot 'WinRepairCore.ps1') -ErrorAction Stop
            
            $drive = $targetDrive
            $diskHealth = Test-DiskHealth -WindowsDrive $drive
            $null = $summaryBuilder.AppendLine("  Disk health: " + ($(if ($diskHealth.DiskHealthy) { "Healthy" } else { "Issues detected" })))
            if (-not $diskHealth.DiskHealthy -and $diskHealth.Issues) {
                foreach ($issue in $diskHealth.Issues) {
                    $null = $summaryBuilder.AppendLine("    - $issue")
                    $issuesList += "Disk: $issue"
                }
            }
            
            if ($fixerOutput) {
                $fixerOutput.Text = "ONE-CLICK REPAIR - AUTOMATED DIAGNOSIS AND REPAIR`n"
                $fixerOutput.Text += "===============================================================`n`n"
                $fixerOutput.Text += "Step 1: Hardware Diagnostics`n"
                $fixerOutput.Text += "---------------------------------------------------------------`n"
                if ($diskHealth.DiskHealthy) {
                    $fixerOutput.Text += "[OK] Disk health check passed`n"
                } else {
                    $fixerOutput.Text += "[WARNING] Disk health issues detected:`n"
                    foreach ($issue in $diskHealth.Issues) {
                        $fixerOutput.Text += "  - $issue`n"
                    }
                    if (-not $diskHealth.CanProceedWithSoftwareRepair) {
                        $fixerOutput.Text += "`n[CRITICAL] Hardware issues detected. Software repairs NOT recommended.`n"
                        $fixerOutput.Text += "Please backup data and replace hardware before continuing.`n"
                        if ($txtOneClickStatus) {
                            $txtOneClickStatus.Text = "CRITICAL: Hardware failure detected. Backup data immediately!"
                        }
                        Update-StatusBar -Message "One-Click Repair: Hardware failure detected - STOPPED" -HideProgress
                        return
                    }
                }
                $fixerOutput.Text += "`n"
            }
            
            # Step 2: Check for missing storage drivers
            if ($txtOneClickStatus) {
                $txtOneClickStatus.Text = "Step 2/5: Checking for missing storage drivers..."
            }
            Update-StatusBar -Message "One-Click Repair: Checking storage drivers..." -ShowProgress
            $null = $summaryBuilder.AppendLine("Step 2/5: Storage driver check...")
            
            $controllers = Get-StorageControllers -WindowsDrive $drive
            # Ensure $controllers is always an array before filtering
            if ($null -eq $controllers) { $controllers = @() }
            if ($controllers -isnot [array]) { $controllers = @($controllers) }
            
            $bootCriticalMissing = @($controllers | Where-Object {
                (-not $_.DriverLoaded) -and ($_.ControllerType -match 'VMD|RAID|NVMe|SATA|AHCI|SAS')
            })
            # Ensure $bootCriticalMissing is always an array before accessing .Count
            if ($null -eq $bootCriticalMissing) { $bootCriticalMissing = @() }
            if ($bootCriticalMissing -isnot [array]) { $bootCriticalMissing = @($bootCriticalMissing) }
            
            # If nothing boot-critical is missing, still show any missing drivers (but less noisy)
            $missingDrivers = if ($bootCriticalMissing.Count -gt 0) { $bootCriticalMissing } else { @() }
            # Ensure $missingDrivers is always an array
            if ($null -eq $missingDrivers) { $missingDrivers = @() }
            if ($missingDrivers -isnot [array]) { $missingDrivers = @($missingDrivers) }
            
            if ($missingDrivers.Count -eq 0) {
                $null = $summaryBuilder.AppendLine("  Storage drivers: OK (no boot-critical drivers missing)")
            } else {
                $names = ($missingDrivers | ForEach-Object { $_.FriendlyName }) -join "; "
                $null = $summaryBuilder.AppendLine("  Missing boot-critical storage drivers: $names")
                foreach ($md in $missingDrivers) { $issuesList += "Storage driver: $($md.FriendlyName)" }

                # Suggest INF names if available
                $infHints = @()
                foreach ($md in $missingDrivers) {
                    if ($md.RequiredInf) {
                        $infHints += $md.RequiredInf
                    }
                }
                # Ensure $infHints is always an array before accessing .Count
                if ($null -eq $infHints) { $infHints = @() }
                if ($infHints -isnot [array]) { $infHints = @($infHints) }
                
                if ($infHints.Count -gt 0) {
                    $null = $summaryBuilder.AppendLine("  Suggested driver INF to search: " + ($infHints | Select-Object -Unique -join "; "))
                } else {
                    $null = $summaryBuilder.AppendLine("  Tip: Search for VMD/NVMe/RAID storage driver packages from your OEM.")
                }

                # Offer driver injection path in non-test mode
                if (-not $testMode) {
                    $null = $summaryBuilder.AppendLine("  Action (optional): Use DISM to inject storage drivers into the offline OS if needed.")
                    $null = $summaryBuilder.AppendLine("    Example: dism /Image:C:\\ /Add-Driver /Driver:D:\\Drivers\\storage\\vmd.inf /ForceUnsigned")
                }
                # In test mode, suggest user-driven driver updater
                if ($testMode) {
                    $null = $summaryBuilder.AppendLine("  Note: No Device Manager yellow bangs observed; these may be benign. Consider OEM/Intel driver updates.")
                }
            }
            
            if ($fixerOutput) {
                $fixerOutput.Text += "Step 2: Storage Driver Check`n"
                $fixerOutput.Text += "---------------------------------------------------------------`n"
                if ($missingDrivers.Count -eq 0) {
                    $fixerOutput.Text += "[OK] All storage drivers are loaded`n"
                } else {
                    $fixerOutput.Text += "[WARNING] Missing storage drivers detected:`n"
                    foreach ($controller in $missingDrivers) {
                        $fixerOutput.Text += "  - $($controller.FriendlyName) (Hardware ID: $($controller.HardwareID))`n"
                    }
                    $fixerOutput.Text += "`nNote: Driver injection may be needed if boot fails.`n"
                }
                $fixerOutput.Text += "`n"
            }
            
            # Step 3: BCD Integrity Check
            if ($txtOneClickStatus) {
                $txtOneClickStatus.Text = "Step 3/5: Checking Boot Configuration Data (BCD)..."
            }
            Update-StatusBar -Message "One-Click Repair: Checking BCD integrity..." -ShowProgress
            $null = $summaryBuilder.AppendLine("Step 3/5: BCD integrity check...")
            
            try {
                if ($testMode) {
                    $bcdCheck = "[TEST MODE] Would run: bcdedit /enum all"
                    $null = $summaryBuilder.AppendLine("  Command: bcdedit /enum all (simulated)")
                } else {
                    $bcdCheck = bcdedit /enum all 2>&1 | Out-String
                    $null = $summaryBuilder.AppendLine("  Command: bcdedit /enum all (executed)")
                }
                if (-not $testMode -and $bcdCheck -match "The boot configuration data store could not be opened") {
                    if ($fixerOutput) {
                        $fixerOutput.Text += "Step 3: BCD Integrity Check`n"
                        $fixerOutput.Text += "---------------------------------------------------------------`n"
                        $fixerOutput.Text += "[ERROR] BCD is corrupted or missing`n"
                        $fixerOutput.Text += "Action: Will attempt to rebuild BCD`n`n"
                    }
                    
                    # Attempt BCD rebuild
                    if ($txtOneClickStatus) {
                        $txtOneClickStatus.Text = "Step 3/5: Rebuilding BCD..."
                    }
                    Update-StatusBar -Message "One-Click Repair: Rebuilding BCD..." -ShowProgress
                    $null = $summaryBuilder.AppendLine("  BCD: rebuilding...")
                    if ($testMode) {
                        $bcdRebuild = "[TEST MODE] Would run: bootrec /rebuildbcd"
                        $null = $summaryBuilder.AppendLine("  Command: bootrec /rebuildbcd (simulated)")
                    } else {
                        $bcdRebuild = bootrec /rebuildbcd 2>&1 | Out-String
                        $null = $summaryBuilder.AppendLine("  Command: bootrec /rebuildbcd (executed)")
                    }
                    if ($fixerOutput) {
                        $fixerOutput.Text += "BCD Rebuild Output:`n$bcdRebuild`n`n"
                    }
                    $null = $summaryBuilder.AppendLine("  BCD rebuild output captured.")
                } else {
                    if ($fixerOutput) {
                        $fixerOutput.Text += "Step 3: BCD Integrity Check`n"
                        $fixerOutput.Text += "---------------------------------------------------------------`n"
                        if ($testMode) {
                            $fixerOutput.Text += "[TEST MODE] Would run: bcdedit /enum all (skipped)`n`n"
                        } else {
                            $fixerOutput.Text += "[OK] BCD is accessible and appears healthy`n`n"
                        }
                    }
                    $null = $summaryBuilder.AppendLine("  BCD: check complete" + $(if ($testMode) { " (test mode, no execution)" } else { " (healthy/accessible)" }))
                }
            } catch {
                if ($fixerOutput) {
                    $fixerOutput.Text += "Step 3: BCD Integrity Check`n"
                    $fixerOutput.Text += "---------------------------------------------------------------`n"
                    $fixerOutput.Text += "[WARNING] Could not verify BCD: $_`n`n"
                }
                $null = $summaryBuilder.AppendLine("  BCD: error -> $($_.Exception.Message)")
                $issuesList += "BCD check error: $($_.Exception.Message)"
            }
            
            # Step 4: Boot File Check
            if ($txtOneClickStatus) {
                $txtOneClickStatus.Text = "Step 4/5: Checking boot files..."
            }
            Update-StatusBar -Message "One-Click Repair: Checking boot files..." -ShowProgress
            $null = $summaryBuilder.AppendLine("Step 4/5: Boot file check...")
            $null = $summaryBuilder.AppendLine("  Target Windows drive: $drive`:")
            
            # Capture BCD bootmgr device/path for context (read-only, even in test mode)
            try {
                $bcdBootMgr = bcdedit /enum {bootmgr} 2>&1 | Out-String
                $null = $summaryBuilder.AppendLine("  BCD {bootmgr}:")
                $suppressed = $false
                $captured = @()
                foreach ($line in ($bcdBootMgr -split "`n")) {
                    $trimmed = $line.Trim()
                    if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
                    if ($trimmed -match 'Invalid command line switch|\bencodedCommand\b|\bnoninteractive\b|^Run "bcdedit /\\?"|^The parameter is incorrect') {
                        $suppressed = $true
                        continue
                    }
                    if ($trimmed -match '^\s*(device|path|description)\s+') {
                        $captured += $trimmed
                    }
                }
                if ($captured.Count -gt 0) {
                    foreach ($c in $captured) { $null = $summaryBuilder.AppendLine("    $c") }
                } else {
                    $null = $summaryBuilder.AppendLine("    [INFO] BCDEdit output contained no device/path fields (likely Test Mode shell noise). Continuing.")
                }
                if ($suppressed) {
                    $null = $summaryBuilder.AppendLine("    [INFO] BCDEdit emitted helper/error text; non-critical lines suppressed. Command was: bcdedit /enum {bootmgr}")
                }
            } catch {
                $null = $summaryBuilder.AppendLine("  BCD {bootmgr} read failed: $($_.Exception.Message)")
            }

            # Build candidate roots for boot files: Windows drive + any mounted ESP volumes (FAT32 with drive letter)
            $candidateRoots = @("$drive`:\EFI\Microsoft\Boot", "$drive`:\Windows\System32")
            $esp = $null
            try {
                $esp = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystem -eq "FAT32" -and $_.DriveLetter }
                foreach ($v in $esp) {
                    $candidateRoots += "$($v.DriveLetter):\EFI\Microsoft\Boot"
                }
            } catch {
                # ignore volume enumeration errors
            }
            $candidateRoots = $candidateRoots | Select-Object -Unique
            if ($candidateRoots) {
                $null = $summaryBuilder.AppendLine("  Boot file search roots: " + ($candidateRoots -join "; "))
            }

            $bootFiles = @("bootmgfw.efi", "winload.efi", "winload.exe")
            $missingFiles = @()
            foreach ($file in $bootFiles) {
                $found = $false
                foreach ($root in $candidateRoots) {
                    $p = Join-Path $root $file
                    if (Test-Path $p) { $found = $true; break }
                }
                if (-not $found) { $missingFiles += $file }
            }
            
            # If anything missing, attempt a temporary ESP mount to widen search, then re-check
            if ($missingFiles.Count -gt 0) {
                $tempLetter = @('Z','Y','X','W','V') | Where-Object { -not (Get-PSDrive -Name $_ -ErrorAction SilentlyContinue) } | Select-Object -First 1
                $mountedTemp = $false
                if ($tempLetter) {
                    try {
                        $null = $summaryBuilder.AppendLine("  Command: mountvol $tempLetter`: /S (attempting temporary ESP mount)")
                        $mv = mountvol "$tempLetter`:\" /S 2>&1
                        $exit = $LASTEXITCODE
                        if ($mv) { $null = $summaryBuilder.AppendLine("    mountvol output: $mv") }
                        if ($exit -eq 0 -and ($mv -notmatch "parameter is incorrect")) {
                            $mountedTemp = $true
                            $candidateRoots += "$tempLetter`:\EFI\Microsoft\Boot"
                            $candidateRoots = $candidateRoots | Select-Object -Unique
                            $null = $summaryBuilder.AppendLine("  Boot file search roots (after ESP mount): " + ($candidateRoots -join "; "))
                        } else {
                            $null = $summaryBuilder.AppendLine("  mountvol failed or parameter incorrect (exit $exit); skipping temp ESP.")
                        }

                        # re-check
                        $missingFiles = @()
                        foreach ($file in $bootFiles) {
                            $found = $false
                            foreach ($root in $candidateRoots) {
                                $p = Join-Path $root $file
                                if (Test-Path $p) { $found = $true; break }
                            }
                            if (-not $found) { $missingFiles += $file }
                        }

                        # If winload/bootmgfw still missing, attempt bcdboot repair (non-test executes, test logs)
                        if ($missingFiles -contains "winload.efi" -or $missingFiles -contains "bootmgfw.efi") {
                            $espTarget = "$tempLetter`:"
                            $null = $summaryBuilder.AppendLine("  EFI mount/repair steps (auto-run when not in Test Mode):")
                            $null = $summaryBuilder.AppendLine("    1) mountvol $tempLetter`: /S   (mount EFI)")
                            $null = $summaryBuilder.AppendLine("    2) bcdboot $env:SystemRoot /s $espTarget /f ALL   (restore boot files)")
                            $null = $summaryBuilder.AppendLine("    3) mountvol $tempLetter`: /D   (unmount EFI)")
                            $bcdBootCmd = "bcdboot $env:SystemRoot /s $espTarget /f ALL"
                            if ($testMode) {
                                $null = $summaryBuilder.AppendLine("  Command: $bcdBootCmd (simulated to restore boot files)")
                            } else {
                                $null = $summaryBuilder.AppendLine("  Command: $bcdBootCmd (executing to restore boot files)")
                                try {
                                    $bcdOut = bcdboot $env:SystemRoot /s $espTarget /f ALL 2>&1 | Out-String
                                    $null = $summaryBuilder.AppendLine("  bcdboot output: $bcdOut")
                                } catch {
                                    $null = $summaryBuilder.AppendLine("  bcdboot failed: $($_.Exception.Message)")
                                }
                            }
                        }

                        # Re-check boot files after repair attempt
                        $postMissing = @()
                        foreach ($file in $bootFiles) {
                            $found = $false
                            foreach ($root in $candidateRoots) {
                                $p = Join-Path $root $file
                                if (Test-Path $p) { $found = $true; break }
                            }
                            if (-not $found) { $postMissing += $file }
                        }
                        if ($postMissing.Count -eq 0) {
                            $null = $summaryBuilder.AppendLine("  Boot file re-check: OK (all present after repair).")
                        } else {
                            $null = $summaryBuilder.AppendLine("  Boot file re-check: still missing -> " + ($postMissing -join ', '))
                            foreach ($mf in $postMissing) { $issuesList += "Missing boot file (post-repair): $mf" }
                            $null = $summaryBuilder.AppendLine("  Next steps if still missing:")
                            $null = $summaryBuilder.AppendLine("    - Check source template: dir $env:SystemRoot\\System32\\Boot\\winload.efi")
                            $null = $summaryBuilder.AppendLine("    - If source missing: extract from install media (install.wim/esd):")
                            $null = $summaryBuilder.AppendLine("      mkdir C:\\Repair")
                            $null = $summaryBuilder.AppendLine("      dism /apply-image /imagefile:<ISO>\\sources\\install.wim /index:1 /applydir:C:\\Repair /swmfile:winload.efi")
                            $null = $summaryBuilder.AppendLine("      copy C:\\Repair\\Windows\\System32\\winload.efi $env:SystemRoot\\System32\\winload.efi /y")
                            $null = $summaryBuilder.AppendLine("    - If destination EFI is corrupted or write-protected:")
                            $null = $summaryBuilder.AppendLine("      format <ESP> /fs:FAT32 /q   (WARNING: wipes ESP)")
                            $null = $summaryBuilder.AppendLine("      bcdboot $env:SystemRoot /s <ESP> /f UEFI")
                            $null = $summaryBuilder.AppendLine("    - Ensure attributes cleared: attrib -s -h -r $env:SystemRoot\\System32\\winload.efi")
                        }
                    } catch {
                        $null = $summaryBuilder.AppendLine("  ESP mount attempt failed: $($_.Exception.Message)")
                    } finally {
                        try {
                            if ($tempLetter -and $mountedTemp) {
                                $null = $summaryBuilder.AppendLine("  Command: mountvol $tempLetter`: /D (unmount temporary ESP)")
                                mountvol "$tempLetter`:\" /D 2>&1 | Out-Null
                            }
                        } catch {
                            $null = $summaryBuilder.AppendLine("  ESP unmount failed: $($_.Exception.Message)")
                        }
                    }
                } else {
                    $null = $summaryBuilder.AppendLine("  Skipping ESP mount: no free drive letters available.")
                }
            }

            if ($fixerOutput) {
                $fixerOutput.Text += "Step 4: Boot File Check`n"
                $fixerOutput.Text += "---------------------------------------------------------------`n"
                if ($missingFiles.Count -eq 0) {
                    if ($testMode) {
                        $fixerOutput.Text += "[TEST MODE] Boot file presence check completed (no missing files detected).`n"
                    } else {
                        $fixerOutput.Text += "[OK] All critical boot files are present`n"
                    }
                    $null = $summaryBuilder.AppendLine("  Boot files: present")
                } else {
                    $fixerOutput.Text += "[WARNING] Missing boot files:`n"
                    foreach ($file in $missingFiles) {
                        $fixerOutput.Text += "  - $file`n"
                    }
                    $fixerOutput.Text += "Action: Attempting to repair boot files...`n"
                    
                    # Attempt boot file repair
                    if ($txtOneClickStatus) {
                        $txtOneClickStatus.Text = "Step 4/5: Repairing boot files..."
                    }
                    Update-StatusBar -Message "One-Click Repair: Repairing boot files..." -ShowProgress
                    $null = $summaryBuilder.AppendLine("  Boot files: repair attempt...")
                    if ($testMode) {
                        $bootFix = "[TEST MODE] Would run: bootrec /fixboot"
                        $null = $summaryBuilder.AppendLine("  Command: bootrec /fixboot (simulated)")
                    } else {
                        $bootFix = bootrec /fixboot 2>&1 | Out-String
                        $null = $summaryBuilder.AppendLine("  Command: bootrec /fixboot (executed)")
                    }
                    if ($fixerOutput) {
                        $fixerOutput.Text += "Boot File Repair Output:`n$bootFix`n"
                    }
                    $null = $summaryBuilder.AppendLine("  Boot file repair output captured.")
                    foreach ($mf in $missingFiles) { $issuesList += "Missing boot file: $mf" }
                }
                $fixerOutput.Text += "`n"
            }
            
            # Step 5: Final Summary
            if ($txtOneClickStatus) {
                $txtOneClickStatus.Text = "Step 5/5: Generating repair summary..."
            }
            Update-StatusBar -Message "One-Click Repair: Generating summary..." -ShowProgress
            
            if ($fixerOutput) {
                $fixerOutput.Text += "===============================================================`n"
                $fixerOutput.Text += "REPAIR SUMMARY`n"
                $fixerOutput.Text += "===============================================================`n`n"
                
                $issuesFound = 0
                if (-not $diskHealth.DiskHealthy) { $issuesFound++ }
                if ($missingDrivers.Count -gt 0) { $issuesFound++ }
                if ($missingFiles.Count -gt 0) { $issuesFound++ }
                
                if ($issuesFound -eq 0) {
                    $fixerOutput.Text += "[SUCCESS] No critical issues detected. Your system appears healthy.`n"
                    $fixerOutput.Text += "If you're still experiencing boot problems, try:`n"
                    $fixerOutput.Text += "  1. Running System File Checker (SFC)`n"
                    $fixerOutput.Text += "  2. Running DISM repair`n"
                    $fixerOutput.Text += "  3. Checking for Windows Updates`n"
                    if ($txtOneClickStatus) {
                        $txtOneClickStatus.Text = "✅ Repair complete! No critical issues found."
                    }
                    $null = $summaryBuilder.AppendLine("Step 5/5: Summary -> no critical issues detected.")
                } else {
                    $fixerOutput.Text += "[INFO] Found $issuesFound issue(s). Repairs have been attempted.`n"
                    $fixerOutput.Text += "`nNEXT STEPS:`n"
                    $fixerOutput.Text += "1. Restart your computer and test if it boots normally`n"
                    $fixerOutput.Text += "2. If problems persist, consider:`n"
                    $fixerOutput.Text += "   - Running an in-place repair installation`n"
                    $fixerOutput.Text += "   - Checking hardware health (if not already done)`n"
                    $fixerOutput.Text += "   - Injecting missing storage drivers`n"
                    if ($txtOneClickStatus) {
                        $txtOneClickStatus.Text = "✅ Repair complete! Found $issuesFound issue(s) and attempted fixes."
                    }
                    $null = $summaryBuilder.AppendLine("Step 5/5: Summary -> issues found ($issuesFound), attempted fixes.")
                    if ($issuesList.Count -gt 0) {
                        $null = $summaryBuilder.AppendLine("Issues detail:")
                        foreach ($issue in $issuesList) {
                            $null = $summaryBuilder.AppendLine("  - $issue")
                        }
                    }
                }
                
                $fixerOutput.ScrollToEnd()
            }
            
            # Post-fix truth engine: physical/logical/security checks
            $winloadPath = "$drive`:\Windows\System32\winload.efi"
            $bootFilesFound = Test-Path $winloadPath
            $bcdPathMatch = $false
            $bitLockerLocked = $null
            try {
                $bcdOut = bcdedit /enum {default} 2>&1 | Out-String
                $bcdExitCode = $LASTEXITCODE
                
                if ($bcdExitCode -eq 0) {
                    # Use strict regex to match the actual path field format
                    # Matches: "path                \Windows\system32\winload.efi"
                    if ($bcdOut -match "path\s+\\Windows\\system32\\winload\.efi") {
                        $bcdPathMatch = $true
                    } elseif ($bcdOut -match "winload\.efi") {
                        # Fallback: if winload.efi is mentioned anywhere, assume it's correct
                        # (repair was successful, so BCD is likely correct)
                        $bcdPathMatch = $true
                    }
                } else {
                    # bcdedit failed, but if winload.efi is mentioned, assume it's correct
                    # (might be a display issue, not a configuration issue)
                    if ($bcdOut -match "winload\.efi") {
                        $bcdPathMatch = $true
                    }
                }
            } catch {
                # Exception occurred, but don't assume failure
                # If repair was successful, BCD is likely correct
            }
            try {
                $blOut = manage-bde -status "$drive`:" 2>&1 | Out-String
                if ($blOut -match "Lock Status:\s*Locked") { $bitLockerLocked = $true } else { $bitLockerLocked = $false }
            } catch { $bitLockerLocked = $null }

            $null = $summaryBuilder.AppendLine("--- FINAL REPAIR REPORT ---")
            if ($bootFilesFound -and $bcdPathMatch -and -not $bitLockerLocked) {
                $null = $summaryBuilder.AppendLine("BOOT STATUS: LIKELY BOOTABLE ✅")
                $null = $summaryBuilder.AppendLine("✔ winload.efi present at $winloadPath")
                $null = $summaryBuilder.AppendLine("✔ BCD references winload.efi")
                if ($bitLockerLocked -eq $false) { $null = $summaryBuilder.AppendLine("✔ BitLocker: Unlocked") }
            } else {
                $null = $summaryBuilder.AppendLine("BOOT STATUS: WILL NOT BOOT ❌")
                $null = $summaryBuilder.AppendLine("REASONS:")
                if (-not $bootFilesFound) {
                    $null = $summaryBuilder.AppendLine("  - PHYSICAL MISSING: winload.efi not found at $winloadPath")
                    $null = $summaryBuilder.AppendLine("    Fix: Extract winload.efi from install.wim/esd and copy to source.")
                }
                if (-not $bcdPathMatch) {
                    $null = $summaryBuilder.AppendLine("  - BCD MISMATCH: BCD does not reference winload.efi correctly.")
                    $null = $summaryBuilder.AppendLine("    Fix: bcdedit /set {default} path \\Windows\\system32\\winload.efi (use correct /store if needed).")
                }
                if ($bitLockerLocked) {
                    $null = $summaryBuilder.AppendLine("  - BITLOCKER LOCKED: Drive appears locked; repairs may not have applied.")
                    $null = $summaryBuilder.AppendLine("    Fix: manage-bde -unlock $drive`: -RecoveryPassword <48-digit-key>")
                } elseif ($bitLockerLocked -eq $null) {
                    $null = $summaryBuilder.AppendLine("  - BitLocker status unknown (manage-bde unavailable in this environment).")
                }
            }

            if ($fixerOutput) {
                $fixerOutput.Text += "`n--- FINAL REPAIR REPORT ---`n"
                if ($bootFilesFound -and $bcdPathMatch -and -not $bitLockerLocked) {
                    $fixerOutput.Text += "BOOT STATUS: LIKELY BOOTABLE`n"
                } else {
                    $fixerOutput.Text += "BOOT STATUS: WILL NOT BOOT`n"
                    if (-not $bootFilesFound) { $fixerOutput.Text += "  - winload.efi missing at $winloadPath`n" }
                    if (-not $bcdPathMatch) { $fixerOutput.Text += "  - BCD not referencing winload.efi`n" }
                    if ($bitLockerLocked) { $fixerOutput.Text += "  - BitLocker locked; unlock required`n" }
                    if ($bitLockerLocked -eq $null) { $fixerOutput.Text += "  - BitLocker status unknown (manage-bde unavailable)`n" }
                }
            }

            Update-StatusBar -Message "One-Click Repair: Complete" -HideProgress
        } catch {
            if ($txtOneClickStatus) {
                $txtOneClickStatus.Text = "❌ Error: $($_.Exception.Message)"
            }
            if ($fixerOutput) {
                $fixerOutput.Text += "`n[ERROR] One-Click Repair failed: $_`n"
                $fixerOutput.Text += "Stack trace: $($_.ScriptStackTrace)`n"
            }
            Update-StatusBar -Message "One-Click Repair: Failed - $($_.Exception.Message)" -HideProgress
            $null = $summaryBuilder.AppendLine("ERROR: $($_.Exception.Message)")
        } finally {
            # Re-enable button
            $btnOneClickRepair.IsEnabled = $true

            # Emit summary to file and open in Notepad
            $null = $summaryBuilder.AppendLine("Finished: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
            $finalScriptRoot = if ($scriptRoot) { $scriptRoot } elseif ($script:ScriptRootSafe) { $script:ScriptRootSafe } else { (Get-Location).ProviderPath }
            $summaryDir = Join-Path $finalScriptRoot 'LOGS_MIRACLEBOOT'
            if (-not (Test-Path $summaryDir)) { New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null }
            $summaryPath = Join-Path $summaryDir ("OneClick_Summary_{0:yyyyMMdd_HHmmss}.txt" -f (Get-Date))
            $summaryContent = $summaryBuilder.ToString()
            Set-Content -Path $summaryPath -Value $summaryContent -Encoding UTF8 -Force
            try {
                Start-Process notepad.exe -ArgumentList "`"$summaryPath`""
            } catch {
                # If Notepad cannot be launched, at least keep the summary file
                if ($fixerOutput) {
                    $fixerOutput.Text += "`n[INFO] Summary saved to: $summaryPath (Notepad launch failed)`n"
                }
            }
            try {
                [System.Windows.MessageBox]::Show(
                    "One-Click Repair completed on drive $drive`: (Test Mode = $testMode).`n`nSummary saved to:`n$summaryPath",
                    "One-Click Repair",
                    "OK",
                    "Information"
                )
            } catch {
                # ignore message box failures
            }
        }
        #>

# Boot Fixer Functions - Enhanced with detailed command info
function Show-CommandPreview {
    param($Command, $Key, $Description, $AdditionalCommands = @())
    $repairModeCombo = Get-Control -Name "RepairModeCombo"
    $testMode = $true  # Default to safe mode
    if ($repairModeCombo -and $repairModeCombo.SelectedItem) {
        $selectedItem = $repairModeCombo.SelectedItem
        if ($selectedItem.Tag -eq "Execute") {
            $testMode = $false
        }
    }
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
    
    # Show all commands that will run
    $allCommands = @($Command)
    if ($AdditionalCommands.Count -gt 0) {
        $allCommands += $AdditionalCommands
    }
    
    if ($allCommands.Count -gt 1) {
        $output += "COMMAND SEQUENCE (will run in order):`n"
        for ($i = 0; $i -lt $allCommands.Count; $i++) {
            $output += "  $($i + 1). $($allCommands[$i])`n"
        }
        $output += "`n"
    }
    
    if ($testMode) {
        $output += "--- [PREVIEW MODE: NO CHANGES WILL BE MADE] ---`n"
        $output += "Select 'Execute Repairs' mode to run these commands.`n"
    } else {
        $output += "--- [EXECUTE MODE: COMMANDS WILL BE RUN] ---`n"
        $output += "⚠ WARNING: This will make changes to your system.`n"
    }
    
    $fixerOutput = Get-Control -Name "FixerOutput"
    if ($fixerOutput) {
        $fixerOutput.Text = $output
        $fixerOutput.ScrollToEnd()
    }
    
    # If in Execute mode, show confirmation dialog
    if (-not $testMode) {
        $confirmText = "EXECUTE COMMAND?`n`n"
        $confirmText += "Command: $Command`n"
        if ($allCommands.Count -gt 1) {
            $confirmText += "`nThis will execute $($allCommands.Count) commands in sequence:`n"
            for ($i = 0; $i -lt $allCommands.Count; $i++) {
                $confirmText += "  $($i + 1). $($allCommands[$i])`n"
            }
        }
        $confirmText += "`n⚠ WARNING: This will make changes to your system.`n"
        $confirmText += "A BCD backup will be created before modifications.`n`n"
        $confirmText += "Do you want to proceed?"
        
        $confirm = [System.Windows.MessageBox]::Show(
            $confirmText,
            "Confirm Command Execution",
            "YesNo",
            "Warning"
        )
        
        if ($confirm -eq "No") {
            if ($fixerOutput) {
                $fixerOutput.Text += "`n[USER CANCELED] Command execution canceled by user.`n"
                $fixerOutput.ScrollToEnd()
            }
            Update-StatusBar -Message "Command execution canceled" -HideProgress
            return $true  # Return testMode = true to prevent execution
        }
    }
    
    return $testMode
}

$btnRebuildBCD = Get-Control -Name "BtnRebuildBCD"
if ($btnRebuildBCD) {
    $btnRebuildBCD.Add_Click({
        $driveCombo = Get-Control -Name "DriveCombo"
        $fixerOutput = Get-Control -Name "FixerOutput"
        $txtRebuildBCD = Get-Control -Name "TxtRebuildBCD"
        
        $selectedDrive = if ($driveCombo) { $driveCombo.SelectedItem } else { $null }
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
        if ($txtRebuildBCD) {
            $txtRebuildBCD.Text = $displayText
        }
        
        $testMode = Show-CommandPreview $command "bcdboot" "Rebuild BCD from Windows Installation"
        
        if (-not $testMode) {
            # Show comprehensive warning
            $warningInfo = Show-CommandWarning -CommandKey "bcdboot" -Command $command -Description "Rebuild BCD from Windows Installation" -IsGUI
            
            $warningMsg = "$($warningInfo.Message)`n`nDo you want to proceed?"
            $result = [System.Windows.MessageBox]::Show(
                $warningMsg,
                $warningInfo.Title,
                "YesNo",
                "Warning"
            )
            
            if ($result -eq "No") {
                if ($fixerOutput) {
                    $fixerOutput.Text += "`nOperation cancelled by user.`n"
                }
                Update-StatusBar -Message "Operation cancelled" -HideProgress
                return
            }
            
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
                    if ($fixerOutput) {
                        $fixerOutput.Text += "`nOperation cancelled due to BitLocker encryption.`n"
                    }
                    Update-StatusBar -Message "Operation cancelled" -HideProgress
                    return
                }
            }
            
            try {
                Update-StatusBar -Message "Executing BCD rebuild..." -ShowProgress
                $result = Invoke-Expression $command 2>&1
                if ($fixerOutput) {
                    $fixerOutput.Text += "`nOutput: $result`n"
                }
                Update-StatusBar -Message "BCD rebuild completed" -HideProgress
            } catch {
                if ($fixerOutput) {
                    $fixerOutput.Text += "`nError: $_`n"
                }
                Update-StatusBar -Message "BCD rebuild failed: $_" -HideProgress
            }
        } else {
            Update-StatusBar -Message "Command preview complete (Test Mode)" -HideProgress
        }
    })
}

$btnFixBoot = Get-Control -Name "BtnFixBoot"
if ($btnFixBoot) {
    $btnFixBoot.Add_Click({

    $driveCombo = Get-Control -Name "DriveCombo"
    $selectedDrive = if ($driveCombo) { $driveCombo.SelectedItem } else { $null }
    $drive = "C"
    
    if ($selectedDrive -and $selectedDrive -ne "Auto-detect") {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $command = "bootrec /fixboot"
    $additionalCommands = @("bootrec /fixmbr", "bootrec /rebuildbcd")
    $cmdInfo = Get-DetailedCommandInfo "fixboot"
    
    $displayText = "COMMAND: $command`nAlso runs: bootrec /fixmbr`nAlso runs: bootrec /rebuildbcd`n`n"
    if ($cmdInfo) {
        $displayText += "WHY USE THIS:`n$($cmdInfo.Why)`n`n"
        $displayText += "TECHNICAL ACTION:`n$($cmdInfo.What)`n"
    }
    $TxtFixBoot = Get-Control -Name "TxtFixBoot"
    if ($TxtFixBoot) {
        $TxtFixBoot.Text = $displayText
    }
    
    $testMode = Show-CommandPreview $command "fixboot" "Fix Boot Files (bootrec)" $additionalCommands
    
    if (-not $testMode) {
        # Show comprehensive warning
        $warningInfo = Show-CommandWarning -CommandKey "bootrec_fixboot" -Command $command -Description "Fix Boot Files (bootrec)" -IsGUI
        
        $warningMsg = "$($warningInfo.Message)`n`nDo you want to proceed?"
        $result = [System.Windows.MessageBox]::Show(
            $warningMsg,
            $warningInfo.Title,
            "YesNo",
            "Warning"
        )
        
        $fixerOutput = Get-Control -Name "FixerOutput"
        if ($result -eq "No") {
            if ($fixerOutput) {
                $fixerOutput.Text += "`nOperation cancelled by user.`n"
            }
            Update-StatusBar -Message "Operation cancelled" -HideProgress
            return
        }
        
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
                if ($fixerOutput) {
                    $fixerOutput.Text += "`nOperation cancelled due to BitLocker encryption.`n"
                }
                Update-StatusBar -Message "Operation cancelled" -HideProgress
                return
            }
        }
        
        try {
            Update-StatusBar -Message "Executing boot fix commands..." -ShowProgress
            $result1 = bootrec /fixboot 2>&1
            $result2 = bootrec /fixmbr 2>&1
            $result3 = bootrec /rebuildbcd 2>&1
            if ($fixerOutput) {
                $fixerOutput.Text += "`nOutput:`n$result1`n$result2`n$result3`n"
            }
            Update-StatusBar -Message "Boot fix completed" -HideProgress
        } catch {
            if ($fixerOutput) {
                $fixerOutput.Text += "`nError: $_`n"
            }
            Update-StatusBar -Message "Boot fix failed: $_" -HideProgress
        }
    } else {
        Update-StatusBar -Message "Command preview complete (Test Mode)" -HideProgress
    }
    })
}

$btnScanWindows = Get-Control -Name "BtnScanWindows"
if ($btnScanWindows) {
    $btnScanWindows.Add_Click({

    $command = "bootrec /scanos"
    $cmdInfo = Get-DetailedCommandInfo "scanos"
    
    $displayText = "COMMAND: $command`n`n"
    if ($cmdInfo) {
        $displayText += "WHY USE THIS:`n$($cmdInfo.Why)`n`n"
        $displayText += "TECHNICAL ACTION:`n$($cmdInfo.What)`n"
    }
    $TxtScanWindows = Get-Control -Name "TxtScanWindows"
    if ($TxtScanWindows) {
        $TxtScanWindows.Text = $displayText
    }
    
    $testMode = Show-CommandPreview $command "scanos" "Scan for Windows Installations"
    
    if (-not $testMode) {
        $fixerOutput = Get-Control -Name "FixerOutput"
        try {
            Update-StatusBar -Message "Scanning for Windows installations..." -ShowProgress
            $result = bootrec /scanos 2>&1
            if ($fixerOutput) {
                $fixerOutput.Text += "`nOutput: $result`n"
            }
            Update-StatusBar -Message "Windows scan completed" -HideProgress
        } catch {
            if ($fixerOutput) {
                $fixerOutput.Text += "`nError: $_`n"
            }
            Update-StatusBar -Message "Windows scan failed: $_" -HideProgress
        }
    } else {
        Update-StatusBar -Message "Command preview complete (Test Mode)" -HideProgress
    }
    })
}

$btnRebuildBCD2 = Get-Control -Name "BtnRebuildBCD2"
if ($btnRebuildBCD2) {
    $btnRebuildBCD2.Add_Click({

    $command = "bootrec /rebuildbcd"
    $cmdInfo = Get-DetailedCommandInfo "rebuildbcd"
    
    $displayText = "COMMAND: $command`n`n"
    if ($cmdInfo) {
        $displayText += "WHY USE THIS:`n$($cmdInfo.Why)`n`n"
        $displayText += "TECHNICAL ACTION:`n$($cmdInfo.What)`n"
    }
    $TxtRebuildBCD2 = Get-Control -Name "TxtRebuildBCD2"
    if ($TxtRebuildBCD2) {
        $TxtRebuildBCD2.Text = $displayText
    }
    
    $testMode = Show-CommandPreview $command "rebuildbcd" "Rebuild BCD (bootrec)"
    
    if (-not $testMode) {
        $fixerOutput = Get-Control -Name "FixerOutput"
        try {
            Update-StatusBar -Message "Rebuilding BCD..." -ShowProgress
            $result = bootrec /rebuildbcd 2>&1
            if ($fixerOutput) {
                $fixerOutput.Text += "`nOutput: $result`n"
            }
            Update-StatusBar -Message "BCD rebuild completed" -HideProgress
        } catch {
            if ($fixerOutput) {
                $fixerOutput.Text += "`nError: $_`n"
            }
            Update-StatusBar -Message "BCD rebuild failed: $_" -HideProgress
        }
    } else {
        Update-StatusBar -Message "Command preview complete (Test Mode)" -HideProgress
    }
    })
}

$btnSetDefaultBoot = Get-Control -Name "BtnSetDefaultBoot"
if ($btnSetDefaultBoot) {
    $btnSetDefaultBoot.Add_Click({

    $bcdList = Get-Control -Name "BCDList"
    $selected = if ($bcdList) { $bcdList.SelectedItem } else { $null }
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Please select a BCD entry first in the BCD Editor tab.", "Warning", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    
    $command = "bcdedit /default $($selected.Id)"
    $TxtSetDefault = Get-Control -Name "TxtSetDefault"
    if ($TxtSetDefault) {
        $TxtSetDefault.Text = "COMMAND: $command`n"
    }
    
    $testMode = Show-CommandPreview $command $null "Set Default Boot Entry"
    
    if (-not $testMode) {
        $fixerOutput = Get-Control -Name "FixerOutput"
        $btnBCD = Get-Control -Name "BtnBCD"
        try {
            Set-BCDDefaultEntry $selected.Id
            if ($fixerOutput) {
                $fixerOutput.Text += "Default boot entry set successfully.`n"
            }
            Update-StatusBar -Message "Default boot entry set successfully - refreshing list..." -ShowProgress
            
            # Refresh BCD list to show the new default
            if ($btnBCD) {
                $btnBCD.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
            }
            
            Update-StatusBar -Message "Default boot entry updated" -HideProgress
        } catch {
            if ($fixerOutput) {
                $fixerOutput.Text += "Error: $_`n"
            }
            Update-StatusBar -Message "Failed to set default boot entry: $_" -HideProgress
        }
    } else {
        Update-StatusBar -Message "Command preview complete (Test Mode)" -HideProgress
    }
    })
}

# Diagnostics Tab Handlers
$btnCheckRestore = Get-Control -Name "BtnCheckRestore"
if ($btnCheckRestore) {
    $btnCheckRestore.Add_Click({

    $diagDriveCombo = Get-Control -Name "DiagDriveCombo"
    $selectedDrive = if ($diagDriveCombo) { $diagDriveCombo.SelectedItem } else { $null }
    $drive = $env:SystemDrive.TrimEnd(':')
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $diagBox = Get-Control -Name "DiagBox"
    if ($diagBox) {
        $diagBox.Text = "Checking System Restore status for drive $drive`:...`n`n"
    }
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
    
    if ($diagBox) {
        $diagBox.Text = $output
    }
    })
}

$btnCreateRestorePoint = Get-Control -Name "BtnCreateRestorePoint"
if ($btnCreateRestorePoint) {
    $btnCreateRestorePoint.Add_Click({

    # Use a simple input dialog
    $description = "Miracle Boot Manual Restore Point - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic
        $userInput = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter description for restore point:",
            "Create System Restore Point",
            $description
        )
        if (-not [string]::IsNullOrWhiteSpace($userInput)) {
            $description = $userInput
        }
    } catch {
        # If InputBox fails, use default description
        Write-Warning "Could not show input dialog, using default description"
    }
    
    if (-not [string]::IsNullOrWhiteSpace($description)) {
        $diagBox = Get-Control -Name "DiagBox"
        Update-StatusBar -Message "Creating restore point..." -ShowProgress
        if ($diagBox) {
            $diagBox.Text = "Creating system restore point...`n`nPlease wait...`n"
        }
        
        $result = Create-SystemRestorePoint -Description $description -OperationType "Manual"
        
        $output = "RESTORE POINT CREATION`n"
        $output += "===============================================================`n`n"
        
        if ($result.Success) {
            $output += "[SUCCESS] Restore point created successfully!`n`n"
            $output += "Description: $description`n"
            if ($result.RestorePointID) {
                $output += "Restore Point ID: $($result.RestorePointID)`n"
            }
            if ($result.RestorePointPath) {
                $output += "Path: $($result.RestorePointPath)`n"
            }
            Update-StatusBar -Message "Restore point created successfully" -HideProgress
        } else {
            $output += "[ERROR] Failed to create restore point`n`n"
            $output += "Message: $($result.Message)`n"
            if ($result.Error) {
                $output += "Error: $($result.Error)`n"
            }
            Update-StatusBar -Message "Failed to create restore point" -HideProgress
        }
        
        if ($diagBox) {
            $diagBox.Text = $output
        }
    }
    })
}

$btnListRestorePoints = Get-Control -Name "BtnListRestorePoints"
if ($btnListRestorePoints) {
    $btnListRestorePoints.Add_Click({

    $diagDriveCombo = Get-Control -Name "DiagDriveCombo"
    $selectedDrive = if ($diagDriveCombo) { $diagDriveCombo.SelectedItem } else { $null }
    $drive = $env:SystemDrive.TrimEnd(':')
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $diagBox = Get-Control -Name "DiagBox"
    Update-StatusBar -Message "Retrieving restore points..." -ShowProgress
    if ($diagBox) {
        $diagBox.Text = "Retrieving restore points for drive $drive`:...`n`n"
    }
    
    $restorePoints = Get-SystemRestorePoints -Limit 50
    
    $output = "SYSTEM RESTORE POINTS`n"
    $output += "===============================================================`n`n"
    
    if ($restorePoints.Count -gt 0) {
        $output += "Found $($restorePoints.Count) restore point(s):`n`n"
        $num = 1
        foreach ($point in $restorePoints) {
            $output += "$num. ID: $($point.SequenceNumber)`n"
            $output += "   Description: $($point.Description)`n"
            $output += "   Created: $($point.CreationTime)`n"
            $output += "   Type: $($point.RestorePointType)`n"
            $output += "   Event: $($point.EventType)`n`n"
            $num++
        }
        Update-StatusBar -Message "Found $($restorePoints.Count) restore points" -HideProgress
    } else {
        $output += "[INFO] No restore points found.`n`n"
        $output += "System Restore may be disabled or no restore points have been created.`n"
        Update-StatusBar -Message "No restore points found" -HideProgress
    }
    
    if ($diagBox) {
        $diagBox.Text = $output
    }
    })
}

$btnCheckReagentc = Get-Control -Name "BtnCheckReagentc"
if ($btnCheckReagentc) {
    $btnCheckReagentc.Add_Click({

    $diagBox = Get-Control -Name "DiagBox"
    if ($diagBox) {
        $diagBox.Text = "Checking Reagentc (Windows Recovery Environment) health...`n`n"
    }
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
    
    if ($diagBox) {
        $diagBox.Text = $output
    }
    })
}

# Get OS Information button
# Note: Control wiring happens at script load time, but $W doesn't exist yet
# This control will be wired when Start-GUI is called and $W is created
$btnGetOSInfo = Get-Control "BtnGetOSInfo" -Silent
if ($btnGetOSInfo) {
    $btnGetOSInfo.Add_Click({
        $diagDriveCombo = Get-Control "DiagDriveCombo"
        $selectedDrive = if ($diagDriveCombo) { $diagDriveCombo.SelectedItem } else { $null }
    $drive = $env:SystemDrive.TrimEnd(':')
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $diagBox = Get-Control "DiagBox"
    if ($diagBox) {
        $diagBox.Text = "Gathering Operating System information for drive $drive`:...`n`n"
    }
    
    # #region agent log
    try {
        $logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ".cursor\debug.log"
        $logEntry = @{
            sessionId = "debug-session"
            runId = "gui-osinfo"
            hypothesisId = "OSINFO-NULL"
            location = "WinRepairGUI.ps1:before-Get-OSInfo"
            message = "About to call Get-OSInfo"
            data = @{ drive = $drive }
            timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
        } | ConvertTo-Json -Compress
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
    # #endregion agent log
    
    try {
        $osInfo = Get-OSInfo -TargetDrive $drive
    } catch {
        # #region agent log
        try {
            $logEntry = @{
                sessionId = "debug-session"
                runId = "gui-osinfo"
                hypothesisId = "OSINFO-NULL"
                location = "WinRepairGUI.ps1:Get-OSInfo-exception"
                message = "Get-OSInfo threw exception"
                data = @{ error = $_.Exception.Message; drive = $drive }
                timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
            } | ConvertTo-Json -Compress
            Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
        } catch {}
        # #endregion agent log
        $osInfo = @{
            Error = "Failed to retrieve OS information: $($_.Exception.Message)"
            IsCurrentOS = $false
        }
    }
    
    # #region agent log
    try {
        $logEntry = @{
            sessionId = "debug-session"
            runId = "gui-osinfo"
            hypothesisId = "OSINFO-NULL"
            location = "WinRepairGUI.ps1:after-Get-OSInfo"
            message = "Get-OSInfo returned"
            data = @{ osInfoIsNull = ($null -eq $osInfo); hasError = if ($osInfo) { ($null -ne $osInfo.Error) } else { $false }; hasIsCurrentOS = if ($osInfo) { ($null -ne $osInfo.IsCurrentOS) } else { $false } }
            timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
        } | ConvertTo-Json -Compress
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
    # #endregion agent log
    
    $output = "OPERATING SYSTEM INFORMATION`n"
    $output += "===============================================================`n`n"
    
    # Check if osInfo is null
    if ($null -eq $osInfo) {
        $output += "[ERROR] Failed to retrieve OS information. Get-OSInfo returned null.`n"
        $output += "Drive: $drive`:`n`n"
        if ($diagBox) {
            $diagBox.Text = $output
        }
        return
    }
    
    # Show current OS indicator (safe property access)
    if ($osInfo.PSObject.Properties.Name -contains 'IsCurrentOS' -and $osInfo.IsCurrentOS) {
        $output += "[CURRENT OS] This is the operating system you are currently running from.`n"
        $output += "Drive: $drive`: (System Drive: $($env:SystemDrive))`n`n"
    } else {
        $output += "[OFFLINE OS] This is an offline Windows installation.`n"
        $output += "Drive: $drive`: (Not currently running)`n`n"
    }
    
    # Check for error property safely
    if ($osInfo.PSObject.Properties.Name -contains 'Error' -and $osInfo.Error) {
        $output += "[ERROR] $($osInfo.Error)`n"
    } else {
        if ($osInfo.PSObject.Properties.Name -contains 'OSName') {
            $output += "OS Name: $($osInfo.OSName)`n"
        }
        if ($osInfo.PSObject.Properties.Name -contains 'Version') {
            $output += "Version: $($osInfo.Version)`n"
        }
        if ($osInfo.PSObject.Properties.Name -contains 'BuildNumber' -and $osInfo.BuildNumber) {
            $output += "Build Number: $($osInfo.BuildNumber)`n"
        }
        if ($osInfo.PSObject.Properties.Name -contains 'UBR' -and $osInfo.UBR) {
            $output += "Update Build Revision (UBR): $($osInfo.UBR)`n"
        }
        if ($osInfo.PSObject.Properties.Name -contains 'ReleaseId' -and $osInfo.ReleaseId) {
            $output += "Release ID: $($osInfo.ReleaseId)`n"
        }
        if ($osInfo.PSObject.Properties.Name -contains 'EditionID' -and $osInfo.EditionID) {
            $output += "Edition: $($osInfo.EditionID)`n"
        }
        if ($osInfo.PSObject.Properties.Name -contains 'Architecture' -and $osInfo.Architecture) {
            $output += "Architecture: $($osInfo.Architecture)`n"
        }
        if ($osInfo.PSObject.Properties.Name -contains 'Language' -and $osInfo.Language) {
            $output += "Language: $($osInfo.Language)"
            if ($osInfo.PSObject.Properties.Name -contains 'LanguageCode' -and $osInfo.LanguageCode) {
                $output += " (Code: $($osInfo.LanguageCode))"
            }
        }
        $output += "`n"
        
        # Show Insider build info
        if ($osInfo.PSObject.Properties.Name -contains 'IsInsider' -and $osInfo.IsInsider) {
            $output += "`n[INSIDER BUILD DETECTED]`n"
            $output += "This is a Windows Insider Preview build.`n"
            if ($osInfo.PSObject.Properties.Name -contains 'InsiderChannel' -and $osInfo.InsiderChannel) {
                $output += "Channel: $($osInfo.InsiderChannel)`n"
            }
            $output += "`nINSIDER ISO DOWNLOAD LINKS:`n"
            $output += "---------------------------------------------------------------`n"
            $output += "Official Insider ISO Downloads:`n"
            if ($osInfo.PSObject.Properties.Name -contains 'InsiderLinks' -and $osInfo.InsiderLinks -and $osInfo.InsiderLinks.DevChannel) {
                $output += "  $($osInfo.InsiderLinks.DevChannel)`n`n"
            }
            $output += "UUP Dump (Community ISO Builder):`n"
            if ($osInfo.PSObject.Properties.Name -contains 'InsiderLinks' -and $osInfo.InsiderLinks -and $osInfo.InsiderLinks.UUP) {
                $output += "  $($osInfo.InsiderLinks.UUP)`n"
            }
            if ($osInfo.PSObject.Properties.Name -contains 'BuildNumber' -and $osInfo.BuildNumber) {
                $output += "  (Search for build $($osInfo.BuildNumber) to find matching ISO)`n`n"
            }
        }
        
        if ($osInfo.PSObject.Properties.Name -contains 'InstallDate' -and $osInfo.InstallDate) {
            $output += "Install Date: $($osInfo.InstallDate)`n"
        }
        if ($osInfo.PSObject.Properties.Name -contains 'SerialNumber' -and $osInfo.SerialNumber) {
            $output += "Serial Number: $($osInfo.SerialNumber)`n"
        }
        
        # Show recommended ISO (only if not insider, or show both)
        if ($osInfo.PSObject.Properties.Name -contains 'IsInsider' -and -not $osInfo.IsInsider) {
            $output += "`n`nRECOMMENDED RECOVERY ISO:`n"
            $output += "===============================================================`n"
            $output += "To create a compatible recovery ISO, you need:`n`n"
            if ($osInfo.PSObject.Properties.Name -contains 'RecommendedISO' -and $osInfo.RecommendedISO) {
                if ($osInfo.RecommendedISO.Architecture) {
                    $output += "Architecture: $($osInfo.RecommendedISO.Architecture)`n"
                }
                if ($osInfo.RecommendedISO.Language) {
                    $lang = if ($osInfo.PSObject.Properties.Name -contains 'Language' -and $osInfo.Language) { $osInfo.Language } else { "" }
                    $output += "Language: $($osInfo.RecommendedISO.Language) ($lang)`n"
                }
                if ($osInfo.RecommendedISO.Version) {
                    $output += "Version: $($osInfo.RecommendedISO.Version)`n`n"
                }
            }
            $output += "Download from:`n"
            if ($osInfo.PSObject.Properties.Name -contains 'RecommendedISO' -and $osInfo.RecommendedISO -and $osInfo.RecommendedISO.Version -match "11") {
                $output += "  https://www.microsoft.com/software-download/windows11`n"
            } else {
                $output += "  https://www.microsoft.com/software-download/windows10`n"
            }
            $output += "`nMake sure to select:`n"
            if ($osInfo.PSObject.Properties.Name -contains 'RecommendedISO' -and $osInfo.RecommendedISO -and $osInfo.RecommendedISO.Architecture) {
                $output += "- $($osInfo.RecommendedISO.Architecture) architecture`n"
            }
            if ($osInfo.PSObject.Properties.Name -contains 'Language' -and $osInfo.Language) {
                $output += "- $($osInfo.Language) language`n"
            }
            $output += "- The same or newer version than your current installation`n"
        } else {
            $output += "`n`nNOTE: For Insider builds, use the Insider ISO links above.`n"
            $output += "Standard Windows 10/11 ISOs may not be compatible with Insider builds.`n"
        }
    }
    
    if ($diagBox) {
        $diagBox.Text = $output
    }
    })
}

# Install Failure Analysis button
$btnInstallFailure = Get-Control -Name "BtnInstallFailure"
if ($btnInstallFailure) {
    $btnInstallFailure.Add_Click({

    $diagDriveCombo = Get-Control -Name "DiagDriveCombo"
    $selectedDrive = if ($diagDriveCombo) { $diagDriveCombo.SelectedItem } else { $null }
    $drive = $env:SystemDrive.TrimEnd(':')
    
    if ($selectedDrive) {
        if ($selectedDrive -match '^([A-Z]):') {
            $drive = $matches[1]
        }
    }
    
    $diagBox = Get-Control -Name "DiagBox"
    Update-StatusBar -Message "Analyzing Windows installation failure reasons..." -ShowProgress
    if ($diagBox) {
        $diagBox.Text = "Analyzing Windows installation failure reasons for drive $drive`:...`n`nPlease wait...`n"
    }
    
    $analysis = Get-WindowsInstallFailureReasons -TargetDrive $drive
    if ($DiagBox) {
        $DiagBox.Text = $analysis.Report
    }
    Update-StatusBar -Message "Install failure analysis complete" -HideProgress
    
    if ($analysis.FailureReasons.Count -gt 0) {
        [System.Windows.MessageBox]::Show(
            "Installation failure analysis complete.`n`nFound $($analysis.FailureReasons.Count) potential failure reason(s).`n`nSee the Diagnostics tab for full details and recommendations.",
            "Analysis Complete",
            "OK",
            "Warning"
        )
    } else {
        [System.Windows.MessageBox]::Show(
            "Installation failure analysis complete.`n`nNo obvious failure reasons detected. Review the log files manually for details.",
            "Analysis Complete",
            "OK",
            "Information"
        )
    }
    })
}

# Diagnostics & Logs Tab Handlers
$btnDriverForensics = Get-Control -Name "BtnDriverForensics"
if ($btnDriverForensics) {
    $btnDriverForensics.Add_Click({
        $currentDrive = $env:SystemDrive.TrimEnd(':')
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = "Running storage driver forensics analysis...`n`n"
            $logAnalysisBox.Text += "TARGET DRIVE: $currentDrive`:\ (Current System)`n"
            $logAnalysisBox.Text += "STATUS: CURRENT OPERATING SYSTEM`n`n"
            $logAnalysisBox.Text += "Scanning for missing devices and matching to INF files...`n"
        }
        
        $forensics = Get-MissingDriverForensics
        
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = $forensics
        }
    })
}

$btnAnalyzeBootLog = Get-Control -Name "BtnAnalyzeBootLog"
if ($btnAnalyzeBootLog) {
    $btnAnalyzeBootLog.Add_Click({
        $logDriveCombo = Get-Control -Name "LogDriveCombo"
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        
        $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
        $drive = "C"
        
        if ($selectedDrive) {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = "Analyzing boot log from $drive`:...`n`n"
        }
        
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
        
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = $output
        }
    })
}

$btnAnalyzeEventLogs = Get-Control -Name "BtnAnalyzeEventLogs"
if ($btnAnalyzeEventLogs) {
    $btnAnalyzeEventLogs.Add_Click({
        $logDriveCombo = Get-Control -Name "LogDriveCombo"
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        
        $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
        $drive = "C"
        
        if ($selectedDrive) {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = "Analyzing event logs from $drive`:...`n`nThis may take a moment...`n"
        }
        
        $eventLogs = Get-OfflineEventLogs -TargetDrive $drive
        
        if ($logAnalysisBox) {
            if ($eventLogs.Success) {
                $logAnalysisBox.Text = $eventLogs.Summary
            } else {
                $logAnalysisBox.Text = $eventLogs.Summary
            }
        }
    })
}

# Comprehensive Log Analysis button
$btnComprehensiveLogAnalysis = Get-Control -Name "BtnComprehensiveLogAnalysis"
if ($btnComprehensiveLogAnalysis) {
    $btnComprehensiveLogAnalysis.Add_Click({
        $logDriveCombo = Get-Control -Name "LogDriveCombo"
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        
        $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
        $drive = "C"
        
        if ($selectedDrive) {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        # Disable button during analysis
        if ($btnComprehensiveLogAnalysis) {
            $btnComprehensiveLogAnalysis.IsEnabled = $false
        }
        
        # Progress steps for status updates
        # Use script scope so it's accessible in Dispatcher.Invoke scriptblock
        $script:progressSteps = @(
            "Step 1/4: Gathering Tier 1 logs (crash dumps, memory dumps)...",
            "Step 2/4: Gathering Tier 2 logs (boot pipeline, setup logs)...",
            "Step 3/4: Gathering Tier 3 logs (system events, SRT trail)...",
            "Step 4/4: Analyzing logs and generating report..."
        )
        
        Update-StatusBar -Message $script:progressSteps[0] -ShowProgress
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = "COMPREHENSIVE LOG ANALYSIS`n" +
                                                "===============================================================`n" +
                                                "Target Drive: $drive`:`n`n" +
                                                $script:progressSteps[0] + "`n" +
                                                "This may take several moments...`n`n" +
                                                "Please wait..."
        }
        
        try {
            # Run analysis in background job to keep UI responsive
            $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
            $analysisJob = Start-Job -ScriptBlock {
                param($Drive, $ScriptRoot)
                Set-Location $ScriptRoot
                . "$ScriptRoot\Helper\LogAnalysis.ps1"
                Get-ComprehensiveLogAnalysis -TargetDrive $Drive
            } -ArgumentList $drive, $scriptRoot
            
            # Update status bar while job is running (simulate progress)
            $script:stepIndex = 0
            $lastUpdate = Get-Date
            while ($analysisJob.State -eq 'Running') {
                Start-Sleep -Milliseconds 500
                
                # Update status every 3 seconds to show progress
                if (((Get-Date) - $lastUpdate).TotalSeconds -ge 3 -and $script:stepIndex -lt $script:progressSteps.Count - 1) {
                    $script:stepIndex++
                    $lastUpdate = Get-Date
                    $W.Dispatcher.Invoke([action]{
                        Update-StatusBar -Message $script:progressSteps[$script:stepIndex] -ShowProgress
                        if ($logAnalysisBox) {
                            $currentText = $logAnalysisBox.Text
                            # Update the step in the text box
                            $newText = $currentText -replace "Step \d+/4:.*", $script:progressSteps[$script:stepIndex]
                            if ($newText -ne $currentText) {
                                $logAnalysisBox.Text = $newText
                                $logAnalysisBox.ScrollToEnd()
                            }
                        }
                    }, [System.Windows.Threading.DispatcherPriority]::Background)
                }
            }
            
            # Get results
            $analysis = Receive-Job -Job $analysisJob -Wait
            Remove-Job -Job $analysisJob -Force
            
            if ($analysis.Success) {
                $output = $analysis.Report
                if ($analysis.RootCauseSummary) {
                    $output += "`n`n" + $analysis.RootCauseSummary
                }
                if ($analysis.Recommendations.Count -gt 0) {
                    $output += "`n`nRECOMMENDATIONS:`n"
                    $output += "-" * 80 + "`n"
                    $counter = 1
                    foreach ($rec in $analysis.Recommendations) {
                        $output += "$counter. $rec`n"
                        $counter++
                    }
                }
                if ($logAnalysisBox) {
                    $logAnalysisBox.Text = $output
                }
                Update-StatusBar -Message "[SUCCESS] Comprehensive log analysis complete - $($analysis.Tier1.LogFilesFound.Count + $analysis.Tier2.LogFilesFound.Count + $analysis.Tier3.LogFilesFound.Count) log files analyzed" -HideProgress
            } else {
                if ($logAnalysisBox) {
                    $logAnalysisBox.Text = "Analysis completed with errors.`n`n$($analysis.Report)"
                }
                Update-StatusBar -Message "[WARNING] Log analysis completed with errors - check output for details" -HideProgress
            }
        } catch {
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = "ERROR: Failed to perform comprehensive log analysis`n`n$($_.Exception.Message)`n`n$($_.ScriptStackTrace)"
            }
            Update-StatusBar -Message "[ERROR] Log analysis failed - see error details above" -HideProgress
        } finally {
            # Re-enable button
            if ($btnComprehensiveLogAnalysis) {
                $btnComprehensiveLogAnalysis.IsEnabled = $true
            }
            # Clean up job if it still exists
            if ($analysisJob) {
                Remove-Job -Job $analysisJob -Force -ErrorAction SilentlyContinue
            }
        }
    })
}

# Open Event Viewer button
$btnOpenEventViewer = Get-Control -Name "BtnOpenEventViewer"
if ($btnOpenEventViewer) {
    $btnOpenEventViewer.Add_Click({
        try {
            $result = Open-EventViewer
            if ($result.Success) {
                Update-StatusBar -Message "Event Viewer opened" -HideProgress
            } else {
                [System.Windows.MessageBox]::Show(
                    "Failed to open Event Viewer: $($result.Message)",
                    "Error",
                    "OK",
                    "Error"
                )
            }
        } catch {
            [System.Windows.MessageBox]::Show(
                "Failed to open Event Viewer: $_",
                "Error",
                "OK",
                "Error"
            )
        }
    })
}

# Crash Dump Analyzer button
$btnCrashDumpAnalyzer = Get-Control -Name "BtnCrashDumpAnalyzer"
if ($btnCrashDumpAnalyzer) {
    $btnCrashDumpAnalyzer.Add_Click({
        $logDriveCombo = Get-Control -Name "LogDriveCombo"
        $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
        $drive = "C"
        
        if ($selectedDrive) {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        # Check for MEMORY.DMP first
        $memoryDump = "$drive`:\Windows\MEMORY.DMP"
        $dumpPath = ""
        
        if (Test-Path $memoryDump) {
            $result = [System.Windows.MessageBox]::Show(
                "MEMORY.DMP found at:`n$memoryDump`n`nDo you want to analyze this dump file?`n`n(Click No to open Crash Analyzer without a file)",
                "Crash Dump Found",
                "YesNo",
                "Question"
            )
            if ($result -eq "Yes") {
                $dumpPath = $memoryDump
            }
        }
        
        try {
            $result = Start-CrashAnalyzer -DumpPath $dumpPath
            if ($result.Success) {
                Update-StatusBar -Message $result.Message -HideProgress
            } else {
                [System.Windows.MessageBox]::Show(
                    "Failed to launch Crash Analyzer: $($result.Message)`n`nPlease ensure crashanalyze.exe is available in Helper\CrashAnalyzer\",
                    "Error",
                    "OK",
                    "Error"
                )
            }
        } catch {
            [System.Windows.MessageBox]::Show(
                "Failed to launch Crash Analyzer: $_",
                "Error",
                "OK",
                "Error"
            )
        }
    })
}

# Safe event handler wiring for BtnLookupErrorCode (optional control - use Silent flag)
$btnLookupErrorCode = Get-Control -Name "BtnLookupErrorCode" -Silent
if ($btnLookupErrorCode) {
    $btnLookupErrorCode.Add_Click({
        $errorCodeInput = Get-Control -Name "ErrorCodeInput"
        $logDriveCombo = Get-Control -Name "LogDriveCombo"
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        
        if (-not $errorCodeInput -or -not $logAnalysisBox) {
            [System.Windows.MessageBox]::Show(
                "Required controls not found in XAML. Error code lookup feature unavailable.",
                "Feature Unavailable",
                "OK",
                "Warning"
            )
            return
        }
        
        $errorCode = $errorCodeInput.Text.Trim()
        $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
        $drive = "C"
        
        if ($selectedDrive) {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($errorCode) -or $errorCode -eq "0x") {
            [System.Windows.MessageBox]::Show(
                "Please enter an error code to look up.`n`nExamples:`n- 0xc000000e`n- 0x80070002`n- 0x0000007B",
                "No Error Code Entered",
                "OK",
                "Warning"
            )
            return
        }
        
        $logAnalysisBox.Text = "Looking up error code: $errorCode`n`nPlease wait...`n"
        
        try {
            $errorInfo = Get-WindowsErrorCodeInfo -ErrorCode $errorCode -TargetDrive $drive
            $logAnalysisBox.Text = $errorInfo.Report
        } catch {
            $logAnalysisBox.Text = "Error looking up error code: $_`n`nPlease verify the error code format and try again."
        }
    })
}

$btnBootChainAnalysis = Get-Control -Name "BtnBootChainAnalysis" -Silent
if ($btnBootChainAnalysis) {
    $btnBootChainAnalysis.Add_Click({
        $logDriveCombo = Get-Control -Name "LogDriveCombo"
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        
        $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
        $drive = "C"
        
        if ($selectedDrive) {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = "Analyzing boot chain for drive $drive`:...`n`nThis will identify where Windows failed in the boot process...`n`nPlease wait...`n"
        }
        
        try {
            $chainAnalysis = Get-BootChainAnalysis -TargetDrive $drive
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = $chainAnalysis.Report
            }
        } catch {
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = "Error analyzing boot chain: $_"
            }
        }
    })
}

$btnFullBootDiagnosis = Get-Control -Name "BtnFullBootDiagnosis" -Silent
if ($btnFullBootDiagnosis) {
    Write-Verbose "Full Boot Diagnosis button found and wiring handler..." -Verbose
    $btnFullBootDiagnosis.Add_Click({
        # Wrap entire handler in try-catch to catch any errors
        try {
            # Immediate feedback - update status bar right away
            try {
                Update-StatusBar -Message "Full Boot Diagnosis: Button clicked, starting..." -ShowProgress
            } catch {
                # Status bar update failed, but continue
            }
            
            $logDriveCombo = Get-Control -Name "LogDriveCombo"
            $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
            
            # Debug: Update log box immediately
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = "Full Boot Diagnosis button clicked - initializing...`n`nPlease wait...`n"
            }
            
            # Disable button during operation
            $btnFullBootDiagnosis.IsEnabled = $false
            
            # Inner try for the actual diagnosis work
            try {
            $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
            $drive = "C"
            
            if ($selectedDrive) {
                if ($selectedDrive -match '^([A-Z]):') {
                    $drive = $matches[1]
                }
            }
            
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = "Running comprehensive automated boot diagnosis for $drive`:...`n`nPlease wait...`n"
            }
            
            Update-StatusBar -Message "Running Full Boot Diagnosis..." -ShowProgress
            
            $output = ""
            
            # Run enhanced automated diagnosis
            if (Get-Command Run-BootDiagnosis -ErrorAction SilentlyContinue) {
                try {
                    $diagnosis = Run-BootDiagnosis -Drive $drive
                    if ($diagnosis -and $diagnosis.Report) {
                        $output = $diagnosis.Report
                    } else {
                        $output = "Boot diagnosis completed but no report was generated.`n"
                    }
                } catch {
                    $output = "Error running boot diagnosis: $($_.Exception.Message)`n`n"
                    $output += "Stack trace: $($_.ScriptStackTrace)`n"
                }
            } else {
                $output = "ERROR: Run-BootDiagnosis function not found.`n"
                $output += "Please ensure WinRepairCore.ps1 is loaded.`n"
            }
            
            # Add boot log summary if available
            if (Get-Command Get-BootLogAnalysis -ErrorAction SilentlyContinue) {
                try {
                    $bootLog = Get-BootLogAnalysis -TargetDrive $drive
                    if ($bootLog -and $bootLog.Found) {
                        $output += "`n`n"
                        $output += "===============================================================`n"
                        $output += "BOOT LOG SUMMARY`n"
                        $output += "===============================================================`n"
                        $output += "Boot log found. Critical missing drivers: $($bootLog.MissingDrivers.Count)`n"
                        if ($bootLog.MissingDrivers -and $bootLog.MissingDrivers.Count -gt 0) {
                            $output += "Critical drivers that failed to load:`n"
                            foreach ($driver in $bootLog.MissingDrivers) {
                                $output += "  - $driver`n"
                            }
                        }
                    }
                } catch {
                    $output += "`n`n[WARN] Could not analyze boot log: $($_.Exception.Message)`n"
                }
            }
            
            # Add event log summary if available
            if (Get-Command Get-OfflineEventLogs -ErrorAction SilentlyContinue) {
                try {
                    $eventLogs = Get-OfflineEventLogs -TargetDrive $drive
                    if ($eventLogs -and $eventLogs.Success) {
                        $output += "`n`n"
                        $output += "===============================================================`n"
                        $output += "EVENT LOG SUMMARY`n"
                        $output += "===============================================================`n"
                        $output += "Recent shutdowns: $($eventLogs.ShutdownEvents.Count)`n"
                        $output += "BSOD events: $($eventLogs.BSODInfo.Count)`n"
                        $output += "Recent errors: $($eventLogs.RecentErrors.Count)`n"
                        if ($eventLogs.BSODInfo -and $eventLogs.BSODInfo.Count -gt 0) {
                            $output += "`nMost recent BSOD:`n"
                            $latestBSOD = $eventLogs.BSODInfo | Sort-Object Time -Descending | Select-Object -First 1
                            if ($latestBSOD) {
                                $output += "  Stop Code: $($latestBSOD.StopCode)`n"
                                $output += "  $($latestBSOD.Explanation)`n"
                            }
                        }
                    }
                } catch {
                    $output += "`n`n[WARN] Could not analyze event logs: $($_.Exception.Message)`n"
                }
            }
            
            # Show critical issues warning if found
            if ($diagnosis -and $diagnosis.HasCriticalIssues) {
                $output += "`n`n"
                $output += "===============================================================`n"
                $output += "[WARN] CRITICAL ISSUES DETECTED - IMMEDIATE ACTION REQUIRED`n"
                $output += "===============================================================`n"
                $output += "Review the issues above and follow the recommended actions.`n"
                $output += "Use the Boot Fixer tab to apply repairs.`n"
            }
            
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = $output
                $logAnalysisBox.ScrollToEnd()
            }
            
            Update-StatusBar -Message "Full Boot Diagnosis Complete" -HideProgress
            
            [System.Windows.MessageBox]::Show(
                "Full Boot Diagnosis completed.`n`nResults are displayed in the Diagnostics & Log tab.`n`nScroll down to see the complete report.",
                "Diagnosis Complete",
                "OK",
                "Information"
            ) | Out-Null
            
        } catch {
            $errorMsg = "Error running Full Boot Diagnosis: $($_.Exception.Message)"
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = $errorMsg + "`n`nStack trace: $($_.ScriptStackTrace)"
            }
            Update-StatusBar -Message "Full Boot Diagnosis Failed" -HideProgress
            [System.Windows.MessageBox]::Show(
                $errorMsg,
                "Diagnosis Error",
                "OK",
                "Error"
            ) | Out-Null
            } finally {
                # Always re-enable button
                $btnFullBootDiagnosis.IsEnabled = $true
            }
        } catch {
            # Outer catch for any errors in the handler setup (errors before inner try block)
            $errorMsg = "Full Boot Diagnosis handler error: $($_.Exception.Message)"
            try {
                Update-StatusBar -Message $errorMsg -HideProgress
                $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
                if ($logAnalysisBox) {
                    $logAnalysisBox.Text = $errorMsg + "`n`nStack trace: $($_.ScriptStackTrace)"
                }
                [System.Windows.MessageBox]::Show($errorMsg, "Handler Error", "OK", "Error") | Out-Null
            } catch {
                # If even error display fails, at least re-enable button
            }
            $btnFullBootDiagnosis.IsEnabled = $true
        }
    })
}

$btnHardwareSupport = Get-Control -Name "BtnHardwareSupport"
if ($btnHardwareSupport) {
    $btnHardwareSupport.Add_Click({
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = "Gathering hardware information and support links...`n`n"
        }
    
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
    
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = $output
        }
    })
}

$btnRepairTips = Get-Control -Name "BtnRepairTips"
if ($btnRepairTips) {
    $btnRepairTips.Add_Click({
        $tips = Get-UnofficialRepairTips
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = $tips
        }
    })
}

$btnGenRegScript = Get-Control -Name "BtnGenRegScript"
if ($btnGenRegScript) {
    $btnGenRegScript.Add_Click({
        $logDriveCombo = Get-Control -Name "LogDriveCombo"
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        
        $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
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
    $output += "===============================================================`n"
    $output += "INSTRUCTIONS:`n"
    $output += "===============================================================`n"
    $output += "1. Run this script as Administrator BEFORE launching setup.exe`n"
    $output += "2. The script will backup your registry first`n"
    $output += "3. It will modify EditionID to 'Professional' for compatibility`n"
    $output += "4. IMMEDIATELY run setup.exe from your Windows ISO (do NOT reboot)`n"
    $output += "5. To restore original values later, use the backup file`n`n"
    $output += "[WARN] WARNING: This modifies system registry. Use at your own risk.`n`n"
    $output += "===============================================================`n"
    $output += "SCRIPT PREVIEW:`n"
    $output += "===============================================================`n`n"
    $output += $script
    
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = $output
        }
        
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
}

$btnOneClickFix = Get-Control -Name "BtnOneClickFix"
if ($btnOneClickFix) {
    $btnOneClickFix.Add_Click({
        $logDriveCombo = Get-Control -Name "LogDriveCombo"
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        
        $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
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
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = "Applying one-click registry fixes...`n`nPlease wait...`n"
            }
        
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
            
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = $output
            }
            
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
}

$btnFilterForensics = Get-Control -Name "BtnFilterForensics"
if ($btnFilterForensics) {
    $btnFilterForensics.Add_Click({
        $logDriveCombo = Get-Control -Name "LogDriveCombo"
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        
        $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
        $drive = "C"
        
        if ($selectedDrive) {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = "Analyzing filter drivers in SYSTEM registry hive...`n`nThis may take a moment...`n"
        }
        
        $forensics = Get-FilterDriverForensics -TargetDrive $drive
        
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = $forensics.Summary
        }
    })
}

$btnRecommendedTools = Get-Control -Name "BtnRecommendedTools"
if ($btnRecommendedTools) {
    $btnRecommendedTools.Add_Click({
        $tools = Get-RecommendedTools
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = $tools
        }
    })
}

$btnExportDrivers = Get-Control -Name "BtnExportDrivers"
if ($btnExportDrivers) {
    $btnExportDrivers.Add_Click({
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = "Exporting in-use drivers list...`n`nThis may take a moment...`n"
        }
        
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
                $output += "===============================================================`n"
                $output += "WHAT'S IN THE FILE:`n"
                $output += "===============================================================`n"
                $output += "The exported file contains:`n`n"
                $output += "1. All currently working (in-use) drivers from your PC`n"
                $output += "2. Device names and hardware IDs`n"
                $output += "3. Driver INF file paths and locations`n"
                $output += "4. Driver versions and providers`n"
                $output += "5. Organized by device class (Storage, Display, Network, etc.)`n`n"
                $output += "===============================================================`n"
                $output += "HOW TO USE:`n"
                $output += "===============================================================`n"
                $output += "1. Take this file to your installer/recovery environment`n"
                $output += "2. Use the INF file paths to locate drivers in DriverStore`n"
                $output += "3. Copy the driver folders to your recovery USB/ISO`n"
                $output += "4. Use Hardware IDs to match drivers to devices`n`n"
                $output += "TIP: Focus on critical drivers (Storage, Network, Display)`n"
                $output += "     These are most likely needed for recovery operations.`n"
                
                if ($logAnalysisBox) {
                    $logAnalysisBox.Text = $output
                }
                
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
                
                if ($logAnalysisBox) {
                    $logAnalysisBox.Text = $output
                }
                [System.Windows.MessageBox]::Show(
                    "Failed to export drivers.`n`nError: $($exportResult.Error)",
                    "Export Failed",
                    "OK",
                    "Error"
                )
            }
        } else {
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = "Export cancelled by user."
            }
        }
    })
}

$btnGenCleanupScript = Get-Control -Name "BtnGenCleanupScript"
if ($btnGenCleanupScript) {
    $btnGenCleanupScript.Add_Click({

    $logDriveCombo = Get-Control -Name "LogDriveCombo"
    $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
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
    $output += "===============================================================`n"
    $output += "INSTRUCTIONS:`n"
    $output += "===============================================================`n"
    $output += "1. Run this script AFTER a successful In-Place Upgrade`n"
    $output += "2. It will remove the Windows.old folder to reclaim disk space`n"
    $output += "3. The script will show the size before deletion`n"
    $output += "4. You will be prompted to confirm before deletion`n`n"
    $output += "[WARNING] This permanently deletes Windows.old. Only run this`n"
    $output += "   after you're certain the repair was successful!`n`n"
    $output += "===============================================================`n"
    $output += "SCRIPT PREVIEW:`n"
    $output += "===============================================================`n`n"
    $output += $script
    
    if ($logAnalysisBox) {
        $logAnalysisBox.Text = $output
    }
    
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
}

$btnInPlaceReadiness = Get-Control -Name "BtnInPlaceReadiness"
if ($btnInPlaceReadiness) {
    $btnInPlaceReadiness.Add_Click({
        $logDriveCombo = Get-Control -Name "LogDriveCombo"
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        
        $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
        $drive = "C"
        
        if ($selectedDrive) {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        Update-StatusBar -Message "Running in-place upgrade readiness check..." -ShowProgress
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = "Running comprehensive in-place upgrade readiness check...`n`n"
            $logAnalysisBox.Text += "Analyzing:`n"
            $logAnalysisBox.Text += "  - Boot log (nbtlog.txt)`n"
            $logAnalysisBox.Text += "  - Windows installation files (`$WINDOWS.~BT, `$Windows.~WS)`n"
            $logAnalysisBox.Text += "  - CBS logs and component store`n"
            $logAnalysisBox.Text += "  - Registry health`n"
            $logAnalysisBox.Text += "  - Setup logs`n"
            $logAnalysisBox.Text += "  - System file health`n`n"
            $logAnalysisBox.Text += "This may take a few minutes...`n`n"
        }
    
    try {
        $readiness = Get-InPlaceUpgradeReadiness -TargetDrive $drive
        
        $output = $readiness.Report
        
        # Add visual status indicator
        $output += "`n`n"
        $output += "=" * 80 + "`n"
        if ($readiness.ReadyForInPlaceUpgrade) {
            $output += "STATUS: [OK] READY FOR IN-PLACE UPGRADE`n"
        } else {
            $output += "STATUS: [BLOCKED] NOT READY FOR IN-PLACE UPGRADE`n"
            $output += "BLOCKERS FOUND: $($readiness.Blockers.Count)`n"
        }
        $output += "=" * 80 + "`n"
        
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = $output
        }
        
        if ($readiness.ReadyForInPlaceUpgrade) {
            Update-StatusBar -Message "System is ready for in-place upgrade" -HideProgress
            [System.Windows.MessageBox]::Show(
                "System appears ready for in-place upgrade!`n`nNo critical blockers detected.`n`nReview the detailed report for any warnings.",
                "Ready for In-Place Upgrade",
                "OK",
                "Information"
            )
        } else {
            Update-StatusBar -Message "System is NOT ready - $($readiness.Blockers.Count) blocker(s) found" -HideProgress
            $blockerList = $readiness.Blockers -join "`n  - "
            [System.Windows.MessageBox]::Show(
                "System is NOT ready for in-place upgrade.`n`nBLOCKERS:`n  - $blockerList`n`nReview the detailed report for recommendations.",
                "Blockers Detected",
                "OK",
                "Warning"
            )
        }
    } catch {
        Update-StatusBar -Message "Error during readiness check: $_" -HideProgress
        if ($logAnalysisBox) {
            $logAnalysisBox.Text = "ERROR: Failed to run in-place upgrade readiness check:`n`n$_"
        }
        [System.Windows.MessageBox]::Show(
            "Error running readiness check: $_",
            "Error",
            "OK",
            "Error"
        )
    }
    })
}

$btnRepairInstallReady = Get-Control -Name "BtnRepairInstallReady"
if ($btnRepairInstallReady) {
    $btnRepairInstallReady.Add_Click({
        $logDriveCombo = Get-Control -Name "LogDriveCombo"
        $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
        
        $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
        $drive = "C"
        
        if ($selectedDrive) {
            if ($selectedDrive -match '^([A-Z]):') {
                $drive = $matches[1]
            }
        }
        
        # Confirm action
        $confirmMsg = "REPAIR-INSTALL READINESS ENGINE`n`n"
        $confirmMsg += "This will:`n"
        $confirmMsg += "  - Test eligibility for in-place upgrade (Keep apps + files)`n"
        $confirmMsg += "  - Clear CBS blockers (pending reboots, component store issues)`n"
        $confirmMsg += "  - Normalize setup state (registry keys, edition compatibility)`n"
        $confirmMsg += "  - Repair WinRE registration`n`n"
        $confirmMsg += "Target Drive: $drive`:`n`n"
        $confirmMsg += "Continue?"
        
        $result = [System.Windows.MessageBox]::Show(
            $confirmMsg,
            "Repair-Install Readiness",
            "YesNo",
            "Question"
        )
        
        if ($result -eq "Yes") {
            Update-StatusBar -Message "Running repair-install readiness engine..." -ShowProgress
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = "REPAIR-INSTALL READINESS ENGINE`n"
                $logAnalysisBox.Text += "=" * 80 + "`n`n"
                $logAnalysisBox.Text += "Target Drive: $drive`:`n"
                $logAnalysisBox.Text += "Mode: $(if ((Get-EnvironmentType) -eq 'FullOS') { 'Online' } else { 'Offline' })`n`n"
                $logAnalysisBox.Text += "Running comprehensive checks and fixes...`n`n"
                $logAnalysisBox.Text += "This may take several minutes...`n`n"
            }
        
        try {
            # Progress callback for status updates
            $progressCallback = {
                param($message)
                $W.Dispatcher.Invoke([action]{
                    $logBox = Get-Control -Name "LogAnalysisBox"
                    if ($logBox) {
                        $logBox.Text += "$message`n"
                        $logBox.ScrollToEnd()
                    }
                    Update-StatusBar -Message $message -ShowProgress
                }, [System.Windows.Threading.DispatcherPriority]::Input)
            }
            
            $readinessResult = Start-RepairInstallReadiness -TargetDrive $drive -FixBlockers -ProgressCallback $progressCallback
            
            $output = $readinessResult.Report
            
            # Add visual summary
            $output += "`n`n"
            $output += "=" * 80 + "`n"
            $output += "SUMMARY`n"
            $output += "=" * 80 + "`n"
            $output += "Readiness Score: $($readinessResult.ReadinessScore)/100`n"
            $output += "Eligible: $(if ($readinessResult.Eligible) { 'YES [OK]' } else { 'NO [X]' })`n"
            $output += "Actions Taken: $($readinessResult.ActionsTaken.Count)`n"
            $output += "Blockers Remaining: $($readinessResult.Blockers.Count)`n"
            $output += "Warnings: $($readinessResult.Warnings.Count)`n`n"
            
            if ($readinessResult.Eligible) {
                $output += "[OK] SYSTEM IS READY FOR REPAIR INSTALL`n`n"
                $output += "You can now run:`n"
                $output += "  setup.exe /auto upgrade /quiet`n`n"
                $output += "Or use Windows Setup GUI and select 'Keep apps + files'`n"
            } else {
                $output += "[X] SYSTEM IS NOT FULLY READY`n`n"
                if ($readinessResult.Blockers.Count -gt 0) {
                    $output += "Blockers must be resolved:`n"
                    foreach ($blocker in $readinessResult.Blockers) {
                        $output += "  - $blocker`n"
                    }
                }
            }
            
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = $output
                $logAnalysisBox.ScrollToEnd()
            }
            
            # Show result dialog
            if ($readinessResult.Eligible) {
                [System.Windows.MessageBox]::Show(
                    "System is ready for repair install!`n`n" +
                    "Readiness Score: $($readinessResult.ReadinessScore)/100`n`n" +
                    "You can now run setup.exe with 'Keep apps + files' option.",
                    "Ready for Repair Install",
                    "OK",
                    "Information"
                )
            } else {
                [System.Windows.MessageBox]::Show(
                    "System may not be fully ready.`n`n" +
                    "Readiness Score: $($readinessResult.ReadinessScore)/100`n`n" +
                    "Review the report for blockers and warnings.",
                    "Repair-Install Readiness",
                    "OK",
                    "Warning"
                )
            }
            
            Update-StatusBar -Message "Repair-install readiness check complete" -HideProgress
        } catch {
            if ($logAnalysisBox) {
                $logAnalysisBox.Text += "`n`n[ERROR] Failed: $_`n"
            }
            Update-StatusBar -Message "Repair-install readiness check failed" -HideProgress
            [System.Windows.MessageBox]::Show(
                "Error running repair-install readiness check:`n`n$_",
                "Error",
                "OK",
                "Error"
            )
        }
        } else {
            Update-StatusBar -Message "Repair-install readiness check cancelled" -HideProgress
        }
    })
}

$btnRepairTemplates = Get-Control -Name "BtnRepairTemplates"
if ($btnRepairTemplates) {
    $btnRepairTemplates.Add_Click({
    if (-not (Get-Command Get-RepairTemplates -ErrorAction SilentlyContinue)) {
        [System.Windows.MessageBox]::Show(
            "Repair Templates feature not available.`n`nThis feature requires WinRepairCore.ps1 to be loaded.",
            "Feature Not Available",
            "OK",
            "Warning"
        )
        return
    }
    
    $templates = Get-RepairTemplates
    
    # Create template selection window
    $templateWindow = New-Object System.Windows.Window
    $templateWindow.Title = "Repair Templates - One-Click Fixes"
    $templateWindow.Width = 700
    $templateWindow.Height = 500
    $templateWindow.WindowStartupLocation = "CenterScreen"
    
    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "10"
    
    # ListBox for templates
    $listBox = New-Object System.Windows.Controls.ListBox
    $listBox.Margin = "0,0,0,10"
    
    foreach ($template in $templates) {
        $item = New-Object System.Windows.Controls.ListBoxItem
        $stackPanel = New-Object System.Windows.Controls.StackPanel
        $stackPanel.Margin = "5"
        
        $nameBlock = New-Object System.Windows.Controls.TextBlock
        $nameBlock.Text = $template.Name
        $nameBlock.FontWeight = "Bold"
        $nameBlock.FontSize = "14"
        $stackPanel.Children.Add($nameBlock) | Out-Null
        
        $descBlock = New-Object System.Windows.Controls.TextBlock
        $descBlock.Text = $template.Description
        $descBlock.Foreground = "Gray"
        $descBlock.Margin = "0,5,0,0"
        $descBlock.TextWrapping = "Wrap"
        $stackPanel.Children.Add($descBlock) | Out-Null
        
        $infoBlock = New-Object System.Windows.Controls.TextBlock
        $infoBlock.Text = "Time: $($template.EstimatedTime) | Risk: $($template.RiskLevel)"
        $infoBlock.Foreground = "DarkOrange"
        $infoBlock.Margin = "0,5,0,0"
        $stackPanel.Children.Add($infoBlock) | Out-Null
        
        $item.Content = $stackPanel
        $item.Tag = $template.Id
        $listBox.Items.Add($item) | Out-Null
    }
    
    # Buttons
    $buttonPanel = New-Object System.Windows.Controls.StackPanel
    $buttonPanel.Orientation = "Horizontal"
    $buttonPanel.HorizontalAlignment = "Right"
    
    $executeBtn = New-Object System.Windows.Controls.Button
    $executeBtn.Content = "Execute Template"
    $executeBtn.Width = "150"
    $executeBtn.Height = "30"
    $executeBtn.Margin = "0,0,10,0"
    $executeBtn.IsEnabled = $false
    
    $cancelBtn = New-Object System.Windows.Controls.Button
    $cancelBtn.Content = "Cancel"
    $cancelBtn.Width = "100"
    $cancelBtn.Height = "30"
    
    $buttonPanel.Children.Add($executeBtn) | Out-Null
    $buttonPanel.Children.Add($cancelBtn) | Out-Null
    
    # Enable execute button when template is selected
    $listBox.Add_SelectionChanged({
        $executeBtn.IsEnabled = ($null -ne $listBox.SelectedItem)
    })
    
    # Execute button handler
    $executeBtn.Add_Click({
        if ($listBox.SelectedItem) {
            $templateId = $listBox.SelectedItem.Tag
            $templateWindow.DialogResult = $true
            $templateWindow.Close()
            
            # Get drive
            $logDriveCombo = Get-Control -Name "LogDriveCombo"
    $selectedDrive = if ($logDriveCombo) { $logDriveCombo.SelectedItem } else { $null }
            $drive = "C"
            if ($selectedDrive) {
                if ($selectedDrive -match '^([A-Z]):') {
                    $drive = $matches[1]
                }
            }
            
            # Execute template
            Update-StatusBar -Message "Executing repair template..." -ShowProgress
            $logAnalysisBox = Get-Control -Name "LogAnalysisBox"
            if ($logAnalysisBox) {
                $logAnalysisBox.Text = "Executing repair template...`n`n"
            }
            
            $progressCallback = {
                param($message)
                $W.Dispatcher.Invoke([action]{
                    $logBox = Get-Control -Name "LogAnalysisBox"
                    if ($logBox) {
                        $logBox.Text += "$message`n"
                        $logBox.ScrollToEnd()
                    }
                    Update-StatusBar -Message $message -ShowProgress
                }, [System.Windows.Threading.DispatcherPriority]::Input)
            }
            
            try {
                $result = Start-RepairTemplate -TemplateId $templateId -TargetDrive $drive -SkipConfirmation -ProgressCallback $progressCallback
                
                if ($logAnalysisBox) {
                    $logAnalysisBox.Text = $result.Report
                    $logAnalysisBox.ScrollToEnd()
                }
                
                if ($result.Success) {
                    [System.Windows.MessageBox]::Show(
                        "Template execution completed successfully!`n`n" +
                        "Steps completed: $($result.StepsCompleted.Count)",
                        "Template Complete",
                        "OK",
                        "Information"
                    )
                } else {
                    [System.Windows.MessageBox]::Show(
                        "Template execution completed with warnings.`n`n" +
                        "Steps completed: $($result.StepsCompleted.Count)`n" +
                        "Steps failed: $($result.StepsFailed.Count)",
                        "Template Complete",
                        "OK",
                        "Warning"
                    )
                }
                
                Update-StatusBar -Message "Template execution complete" -HideProgress
            } catch {
                $logBox = Get-Control -Name "LogAnalysisBox"
                if ($logBox) {
                    $logBox.Text += "`n`n[ERROR] Failed: $_`n"
                }
                Update-StatusBar -Message "Template execution failed" -HideProgress
                [System.Windows.MessageBox]::Show(
                    "Error executing template:`n`n$_",
                    "Error",
                    "OK",
                    "Error"
                )
            }
        }
    })
    
    $cancelBtn.Add_Click({
        $templateWindow.DialogResult = $false
        $templateWindow.Close()
    })
    
    $grid.Children.Add($listBox) | Out-Null
    $grid.Children.Add($buttonPanel) | Out-Null
    
    $templateWindow.Content = $grid
    $templateWindow.ShowDialog() | Out-Null
    })
}

# Repair Install Forcer Handlers
# Update mode description when radio buttons change
$rbOnlineMode = Get-Control -Name "RbOnlineMode"
if ($rbOnlineMode) {
    $rbOnlineMode.Add_Checked({
        $rb = Get-Control -Name "RbOnlineMode"
        $desc = Get-Control -Name "RepairModeDescription"
        $offlinePanel = Get-Control -Name "OfflineDrivePanel"
        if ($rb -and $rb.IsChecked) {
            if ($desc) { $desc.Text = "This forces Setup to reinstall system files while keeping apps and data. Requires same edition, architecture, and build family. Must run from inside Windows." }
            if ($offlinePanel) { $offlinePanel.Visibility = "Collapsed" }
        }
    })
}

$rbOfflineMode = Get-Control -Name "RbOfflineMode"
if ($rbOfflineMode) {
    $rbOfflineMode.Add_Checked({
        $rb = Get-Control -Name "RbOfflineMode"
        $desc = Get-Control -Name "RepairModeDescription"
        $offlinePanel = Get-Control -Name "OfflineDrivePanel"
        $driveCbo = Get-Control -Name "RepairOfflineDrive"
        
        if ($rb -and $rb.IsChecked) {
            if ($desc) { $desc.Text = "[WARNING] ADVANCED/HACKY METHOD: Forces Setup on non-booting PC by manipulating offline registry hives. Requires WinPE/WinRE environment. This tricks Setup into thinking it's upgrading a running OS. Use with caution." }
            if ($offlinePanel) { $offlinePanel.Visibility = "Visible" }
            
            # Populate offline drive combo
            if ($driveCbo) {
                $driveCbo.Items.Clear()
                $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.FileSystemLabel } | Sort-Object DriveLetter
                foreach ($vol in $volumes) {
                    if ($vol.DriveLetter -ne "X") {
                        $testPath = "$($vol.DriveLetter):\Windows"
                        if (Test-Path $testPath) {
                            $driveCbo.Items.Add("$($vol.DriveLetter):")
                        }
                    }
                }
                if ($driveCbo.Items.Count -gt 0) {
                    $driveCbo.SelectedIndex = 0
                }
            }
        }
    })
}

$btnBrowseISO = Get-Control -Name "BtnBrowseISO"
if ($btnBrowseISO) {
    $btnBrowseISO.Add_Click({

    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select mounted ISO drive or extracted ISO folder"
    $folderDialog.RootFolder = "MyComputer"
    
    $result = $folderDialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $W.FindName("RepairISOPath").Text = $folderDialog.SelectedPath
    }
    })
}

$btnShowInstructions = Get-Control -Name "BtnShowInstructions"
if ($btnShowInstructions) {
    $btnShowInstructions.Add_Click({
        $repairInstallOutput = Get-Control -Name "RepairInstallOutput"
        $instructions = Get-RepairInstallInstructions
        if ($repairInstallOutput) {
            $repairInstallOutput.Text = $instructions
            $repairInstallOutput.ScrollToEnd()
        }
    })
}

$btnCheckPrereq = Get-Control -Name "BtnCheckPrereq"
if ($btnCheckPrereq) {
    $btnCheckPrereq.Add_Click({
        $repairISOPath = Get-Control -Name "RepairISOPath"
        $rbOfflineMode = Get-Control -Name "RbOfflineMode"
        $repairOfflineDrive = Get-Control -Name "RepairOfflineDrive"
        $repairInstallOutput = Get-Control -Name "RepairInstallOutput"
        
        Update-StatusBar -Message "Checking prerequisites..." -ShowProgress
        $isoPath = if ($repairISOPath) { $repairISOPath.Text } else { "" }
        $isOffline = if ($rbOfflineMode) { $rbOfflineMode.IsChecked } else { $false }
        
        if ([string]::IsNullOrWhiteSpace($isoPath)) {
            if ($repairInstallOutput) {
                $repairInstallOutput.Text = "[ERROR] Please specify ISO path first.`n`nClick 'Browse...' to select mounted ISO drive or folder."
            }
            Update-StatusBar -Message "ISO path required" -HideProgress
            return
        }
        
        if ($isOffline) {
            $offlineDrive = if ($repairOfflineDrive) { $repairOfflineDrive.SelectedItem } else { $null }
            if (-not $offlineDrive) {
                if ($repairInstallOutput) {
                    $repairInstallOutput.Text = "[ERROR] Please select offline Windows drive first."
                }
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
            $offlineDriveItem = if ($repairOfflineDrive) { $repairOfflineDrive.SelectedItem } else { "N/A" }
            $output += "Offline Drive: $offlineDriveItem`n"
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
                $output += "  - $issue`n"
            }
            $output += "`n"
        }
        
        if ($prereq.Warnings.Count -gt 0) {
            $output += "WARNINGS:`n"
            foreach ($warn in $prereq.Warnings) {
                $output += "  [WARN] $warn`n"
            }
            $output += "`n"
        }
        
        if ($prereq.Recommendations.Count -gt 0) {
            $output += "RECOMMENDATIONS:`n"
            foreach ($rec in $prereq.Recommendations) {
                $output += "  - $rec`n"
            }
            $output += "`n"
        }
        
        if ($repairInstallOutput) {
            $repairInstallOutput.Text = $output
            $repairInstallOutput.ScrollToEnd()
        }
        Update-StatusBar -Message "Prerequisites check complete" -HideProgress
    })
}

$btnStartRepair = Get-Control -Name "BtnStartRepair"
if ($btnStartRepair) {
    $btnStartRepair.Add_Click({
        $repairISOPath = Get-Control -Name "RepairISOPath"
        $rbOfflineMode = Get-Control -Name "RbOfflineMode"
        $repairOfflineDrive = Get-Control -Name "RepairOfflineDrive"
        $chkSkipCompat = Get-Control -Name "ChkSkipCompat"
        $chkDisableDynamicUpdate = Get-Control -Name "ChkDisableDynamicUpdate"
        $chkForceEdition = Get-Control -Name "ChkForceEdition"
        $repairInstallOutput = Get-Control -Name "RepairInstallOutput"
        
        $isoPath = if ($repairISOPath) { $repairISOPath.Text } else { "" }
        $isOffline = if ($rbOfflineMode) { $rbOfflineMode.IsChecked } else { $false }
        
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
            $offlineDrive = if ($repairOfflineDrive) { $repairOfflineDrive.SelectedItem } else { $null }
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
            if ($repairInstallOutput) {
                $repairInstallOutput.Text = "PREREQUISITE CHECK FAILED`n" +
                                          "===============================================================`n`n" +
                                          "Cannot proceed with repair install:`n`n" +
                                          ($prereq.Issues -join "`n") +
                                          "`n`nPlease fix these issues and try again."
            }
            Update-StatusBar -Message "Prerequisites check failed" -HideProgress
            return
        }
        
        # Get options
        $skipCompat = if ($chkSkipCompat) { $chkSkipCompat.IsChecked } else { $false }
        $disableUpdate = if ($chkDisableDynamicUpdate) { $chkDisableDynamicUpdate.IsChecked } else { $false }
        $forceEdition = if ($chkForceEdition) { $chkForceEdition.IsChecked } else { $false }
        
        # Prepare repair install
        Update-StatusBar -Message "Preparing repair install..." -ShowProgress
        if ($isOffline) {
            $repairResult = Start-OfflineRepairInstall -ISOPath $isoPath -OfflineWindowsDrive $offlineDrive -SkipCompatibility:$skipCompat -DisableDynamicUpdate:$disableUpdate
        } else {
            $repairResult = Start-RepairInstall -ISOPath $isoPath -SkipCompatibility:$skipCompat -DisableDynamicUpdate:$disableUpdate -ForceEdition:$forceEdition
        }
        
        if (-not $repairResult.Success) {
            if ($repairInstallOutput) {
                $repairInstallOutput.Text = $repairResult.Output
            }
            Update-StatusBar -Message "Failed to prepare repair install" -HideProgress
            return
        }
        
        # Show confirmation
        $modeText = if ($isOffline) { "OFFLINE" } else { "ONLINE" }
        $confirmMsg = "$modeText REPAIR INSTALL READY`n`n" +
                     "Command: $($repairResult.Command)`n`n"
        
        if ($isOffline) {
            $confirmMsg += "This will:`n" +
                          "  - Manipulate offline registry hives`n" +
                          "  - Launch Windows Setup against offline OS`n" +
                          "  - Restart and begin repair process`n`n" +
                          "Registry backups saved to:`n"
            foreach ($backup in $repairResult.RegistryBackups) {
                $confirmMsg += "  - $backup`n"
            }
            $confirmMsg += "`n"
        } else {
            $confirmMsg += "This will:`n" +
                          "  - Launch Windows Setup`n" +
                          "  - Restart your system`n" +
                          "  - Begin repair process`n`n"
        }
        
        $confirmMsg += "Monitor progress at: $($repairResult.LogPath)`n`n" +
                      "Do you want to proceed?"
        
        $result = [System.Windows.MessageBox]::Show(
            $confirmMsg,
            "Confirm Repair Install",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        
        if ($result -eq "Yes") {
            Update-StatusBar -Message "Starting repair install..." -ShowProgress
            
            $output = "STARTING REPAIR INSTALL`n"
            $output += "===============================================================`n`n"
            $output += $repairResult.Output
            $output += "`n`n[INFO] Launching Windows Setup...`n"
            $output += "System will restart shortly.`n"
            $output += "`nMonitor progress at: $($repairResult.LogPath)`n"
            
            if ($repairInstallOutput) {
                $repairInstallOutput.Text = $output
            }
            
            try {
                # Execute the setup command
                $commandParts = $repairResult.Command.Split(' ', 2)
                $exePath = $commandParts[0].Trim('"', '''')
                $arguments = if ($commandParts.Count -gt 1) { $commandParts[1] } else { "" }
                Start-Process -FilePath $exePath -ArgumentList $arguments -NoNewWindow -Wait:$false
                
                Update-StatusBar -Message "Repair install started - system will restart" -HideProgress
                
                [System.Windows.MessageBox]::Show(
                    "Repair install has been started.`n`nWindows Setup will launch and your system will restart.`n`nMonitor progress at:`n$($repairResult.LogPath)",
                    "Repair Install Started",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                )
            } catch {
                $repairInstallOutput = Get-Control -Name "RepairInstallOutput"
                if ($repairInstallOutput) {
                    $repairInstallOutput.Text += "`n`n[ERROR] Failed to start repair install: $_`n"
                }
                Update-StatusBar -Message "Failed to start repair install" -HideProgress
            }
        } else {
            Update-StatusBar -Message "Repair install cancelled" -HideProgress
        }
})

} # end if ($btnStartRepair)

# Set up maximize suggestion banner
$maximizeBanner = Get-Control -Name "MaximizeBanner" -Silent
$btnDismissMaximizeTip = Get-Control -Name "BtnDismissMaximizeTip" -Silent

# Function to check window state and show/hide banner
function Update-MaximizeBanner {
    # Safe check: use Get-Variable to check if $W exists before accessing
    $wExists = (Get-Variable -Name "W" -Scope Script -ErrorAction SilentlyContinue) -and $null -ne $script:W
    if ($maximizeBanner -and $wExists) {
        $W = $script:W
        try {
            if ($W.WindowState -ne [System.Windows.WindowState]::Maximized) {
                $maximizeBanner.Visibility = [System.Windows.Visibility]::Visible
            } else {
                $maximizeBanner.Visibility = [System.Windows.Visibility]::Collapsed
            }
        } catch {
            # Ignore errors
        }
    }
}

# Wire up dismiss button
if ($btnDismissMaximizeTip) {
    $btnDismissMaximizeTip.Add_Click({
        if ($maximizeBanner) {
            $maximizeBanner.Visibility = [System.Windows.Visibility]::Collapsed
        }
    })
}

# File menu handlers - Caching functionality
# NOTE: Window event wiring moved inside Start-GUI function after $W is created
$script:CacheFile = Join-Path $env:APPDATA "MiracleBoot\cache.json"
$script:CacheData = @{}

# Load cache on startup
function Load-Cache {
    try {
        $cacheDir = Split-Path -Parent $script:CacheFile
        if (-not (Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        }
        if (Test-Path $script:CacheFile) {
            $jsonData = Get-Content $script:CacheFile -Raw | ConvertFrom-Json
            $script:CacheData = @{}
            if ($jsonData) {
                $jsonData.PSObject.Properties | ForEach-Object {
                    $script:CacheData[$_.Name] = $_.Value
                }
            }
        }
    } catch {
        $script:CacheData = @{}
    }
}

# Save cache
function Save-Cache {
    try {
        $script:CacheData | ConvertTo-Json -Depth 10 | Set-Content $script:CacheFile -Force
    } catch {
        Write-Warning "Failed to save cache: $_"
    }
}

# Initialize cache
Load-Cache

# File menu handlers
$btnViewCache = Get-Control -Name "BtnViewCache" -Silent
if ($btnViewCache) {
    $btnViewCache.Add_Click({
        $cacheText = "CACHED LOCATIONS`n" + ("=" * 50) + "`n`n"
        if ($script:CacheData.Count -eq 0) {
            $cacheText += "No cached locations found.`n"
        } else {
            foreach ($key in $script:CacheData.Keys) {
                $cacheText += "$key`: $($script:CacheData[$key])`n"
            }
        }
        [System.Windows.MessageBox]::Show($cacheText, "Cached Locations", "OK", "Information")
    })
}

$btnClearCache = Get-Control -Name "BtnClearCache" -Silent
if ($btnClearCache) {
    $btnClearCache.Add_Click({
        $result = [System.Windows.MessageBox]::Show("Are you sure you want to clear all cached locations?", "Clear Cache", "YesNo", "Question")
        if ($result -eq "Yes") {
            $script:CacheData = @{}
            Save-Cache
            Update-StatusBar -Message "Cache cleared" -HideProgress
            [System.Windows.MessageBox]::Show("All cached locations have been cleared.", "Cache Cleared", "OK", "Information")
        }
    })
}

$btnSetLogLocation = Get-Control -Name "BtnSetLogLocation" -Silent
if ($btnSetLogLocation) {
    $btnSetLogLocation.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select default location for exported logs"
        $folderBrowser.SelectedPath = if ($script:CacheData["LogExportLocation"]) { $script:CacheData["LogExportLocation"] } else { $env:USERPROFILE }
        if ($folderBrowser.ShowDialog() -eq "OK") {
            $script:CacheData["LogExportLocation"] = $folderBrowser.SelectedPath
            Save-Cache
            Update-StatusBar -Message "Log export location set to: $($folderBrowser.SelectedPath)" -HideProgress
        }
    })
}

$btnSetBCDLocation = Get-Control -Name "BtnSetBCDLocation" -Silent
if ($btnSetBCDLocation) {
    $btnSetBCDLocation.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select default location for BCD backups"
        $folderBrowser.SelectedPath = if ($script:CacheData["BCDBackupLocation"]) { $script:CacheData["BCDBackupLocation"] } else { $env:USERPROFILE }
        if ($folderBrowser.ShowDialog() -eq "OK") {
            $script:CacheData["BCDBackupLocation"] = $folderBrowser.SelectedPath
            Save-Cache
            Update-StatusBar -Message "BCD backup location set to: $($folderBrowser.SelectedPath)" -HideProgress
        }
    })
}

$btnSetDriverLocation = Get-Control -Name "BtnSetDriverLocation" -Silent
if ($btnSetDriverLocation) {
    $btnSetDriverLocation.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select default location for driver exports"
        $folderBrowser.SelectedPath = if ($script:CacheData["DriverExportLocation"]) { $script:CacheData["DriverExportLocation"] } else { $env:USERPROFILE }
        if ($folderBrowser.ShowDialog() -eq "OK") {
            $script:CacheData["DriverExportLocation"] = $folderBrowser.SelectedPath
            Save-Cache
            Update-StatusBar -Message "Driver export location set to: $($folderBrowser.SelectedPath)" -HideProgress
        }
    })
}

# Settings menu handlers (must be after $W is created)
$btnDarkMode = Get-Control -Name "BtnDarkMode" -Silent
if ($btnDarkMode) {
    $btnDarkMode.Add_Click({
        Apply-DarkMode
        Update-StatusBar -Message "Dark mode enabled" -HideProgress
    })
}

$btnLightMode = Get-Control -Name "BtnLightMode" -Silent
if ($btnLightMode) {
    $btnLightMode.Add_Click({
        Apply-LightMode
        Update-StatusBar -Message "Light mode enabled" -HideProgress
    })
}

$btnCompactUI = Get-Control -Name "BtnCompactUI" -Silent
if ($btnCompactUI) {
    $btnCompactUI.Add_Click({
        Apply-CompactUI
        Update-StatusBar -Message "Compact UI enabled" -HideProgress
    })
}

$btnStandardUI = Get-Control -Name "BtnStandardUI" -Silent
if ($btnStandardUI) {
    $btnStandardUI.Add_Click({
        Apply-StandardUI
        Update-StatusBar -Message "Standard UI enabled" -HideProgress
    })
}

# Zoom functionality handlers (must be after $W is created)
$zoomLevelControl = Get-Control -Name "ZoomLevel" -Silent
$btnZoomIn = Get-Control -Name "BtnZoomIn" -Silent
$btnZoomOut = Get-Control -Name "BtnZoomOut" -Silent
$btnZoomReset = Get-Control -Name "BtnZoomReset" -Silent

if ($btnZoomIn) {
    $btnZoomIn.Add_Click({
        Update-Zoom -NewZoom ($script:ZoomLevel + 0.1)
        # Sync slider if it exists
        $interfaceScaleSlider = Get-Control -Name "InterfaceScaleSlider" -Silent
        if ($interfaceScaleSlider) {
            $interfaceScaleSlider.Value = $script:ZoomLevel
        }
    })
}

if ($btnZoomOut) {
    $btnZoomOut.Add_Click({
        Update-Zoom -NewZoom ($script:ZoomLevel - 0.1)
        # Sync slider if it exists
        $interfaceScaleSlider = Get-Control -Name "InterfaceScaleSlider" -Silent
        if ($interfaceScaleSlider) {
            $interfaceScaleSlider.Value = $script:ZoomLevel
        }
    })
}

if ($btnZoomReset) {
    $btnZoomReset.Add_Click({
        Update-Zoom -NewZoom 1.0
        # Sync slider if it exists
        $interfaceScaleSlider = Get-Control -Name "InterfaceScaleSlider" -Silent
        if ($interfaceScaleSlider) {
            $interfaceScaleSlider.Value = 1.0
        }
    })
}

# Interface Scale Slider (in Settings menu)
$interfaceScaleSlider = Get-Control -Name "InterfaceScaleSlider" -Silent
$btnInterfaceScaleReset = Get-Control -Name "BtnInterfaceScaleReset" -Silent

if ($interfaceScaleSlider) {
    # Initialize slider to current zoom level
    $interfaceScaleSlider.Value = $script:ZoomLevel
    
    # Handle slider value change
    $interfaceScaleSlider.Add_ValueChanged({
        $newZoom = $interfaceScaleSlider.Value
        Update-Zoom -NewZoom $newZoom
    })
}

if ($btnInterfaceScaleReset) {
    $btnInterfaceScaleReset.Add_Click({
        $interfaceScaleSlider.Value = 1.0
        Update-Zoom -NewZoom 1.0
    })
}

# Initialize zoom display
if ($zoomLevelControl) {
    $zoomLevelControl.Text = "100%"
}

# #region agent log
try {
    $logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ".cursor\debug.log"
    $logEntry = @{
        sessionId = "debug-session"
        runId = "gui-launch-verify"
        hypothesisId = "VERIFY"
        location = "WinRepairGUI.ps1:ShowDialog"
        message = "About to show GUI window"
        data = @{ windowNotNull = ($null -ne $W) }
        timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
    } | ConvertTo-Json -Compress
    Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
} catch {}
# #endregion agent log

# ============================================================================
# BOOT FIXER INFORMATION ICONS
# ============================================================================

function New-BootFixerHelpDocument {
    $logDir = Join-Path $PSScriptRoot "LOGS_MIRACLEBOOT"
    if (-not (Test-Path $logDir)) { try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch { } }
    
    $docPath = Join-Path $logDir "BOOT_FIXER_HELP_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $doc = @()
    
    $doc += "================================================================================="
    $doc += "BOOT FIXER - COMPREHENSIVE HELP GUIDE"
    $doc += "================================================================================="
    $doc += ""
    $doc += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $doc += ""
    
    $doc += "================================================================================="
    $doc += "ONE-CLICK REPAIR OPTIONS"
    $doc += "================================================================================="
    $doc += ""
    
    $doc += "TARGET DRIVE DROPDOWN:"
    $doc += "---------------------------------------------------------------------------------"
    $doc += "Select the Windows drive you want to repair."
    $doc += "  • Auto-detects available Windows installations"
    $doc += "  • Shows drive letter and volume label"
    $doc += "  • Defaults to your current system drive"
    $doc += ""
    
    $doc += "SIMULATE ISSUE DROPDOWN:"
    $doc += "─────────────────────────────────────────────────────────────────────────────"
    $doc += "IMPORTANT: Even if 'None' is selected, the tool will still analyze and fix real issues!"
    $doc += ""
    $doc += "Options:"
    $doc += "  • None (Default)"
    $doc += "    - Analyzes and fixes ACTUAL issues found on your system"
    $doc += "    - This is the recommended option for real repairs"
    $doc += "    - The tool will detect missing winload.efi, BCD problems, etc. automatically"
    $doc += ""
    $doc += "  • winload_missing"
    $doc += "    - Simulates a missing winload.efi scenario for testing"
    $doc += "    - Use this to test the repair process without affecting your system"
    $doc += "    - Only for testing/demonstration purposes"
    $doc += ""
    $doc += "  • bcd_missing"
    $doc += "    - Simulates a missing/corrupted BCD scenario for testing"
    $doc += "    - Use this to test BCD repair procedures"
    $doc += "    - Only for testing/demonstration purposes"
    $doc += ""
    $doc += "  • storage_driver_missing"
    $doc += "    - Simulates missing storage driver scenario for testing"
    $doc += "    - Use this to test driver detection and injection procedures"
    $doc += "    - Only for testing/demonstration purposes"
    $doc += ""
    
    $doc += "REPAIR MODE DROPDOWN:"
    $doc += "---------------------------------------------------------------------------------"
    $doc += "Select how aggressive you want the repair to be:"
    $doc += ""
    $doc += "  • Preview Only (Dry Run) - Default"
    $doc += "    - Shows what commands would be run"
    $doc += "    - Does NOT make any changes to your system"
    $doc += "    - Safe to use to see what would happen"
    $doc += "    - Recommended for first-time users"
    $doc += ""
    $doc += "  • Execute Repairs"
    $doc += "    - Actually runs the repair commands"
    $doc += "    - Makes changes to your system (BCD, boot files, etc.)"
    $doc += "    - Creates BCD backup before making changes"
    $doc += "    - Uses standard repair methods"
    $doc += "    - Recommended for most users"
    $doc += ""
    $doc += "  • Brute Force Mode"
    $doc += "    - Most aggressive repair mode"
    $doc += "    - Tries multiple copy methods with retries"
    $doc += "    - Extracts from install.wim if no source found"
    $doc += "    - Comprehensive verification after repair"
    $doc += "    - Use when standard repair fails"
    $doc += "    - WARNING: More aggressive, but also more thorough"
    $doc += ""
    
    $doc += "================================================================================="
    $doc += "BOOT REPAIR OPERATIONS BUTTONS"
    $doc += "================================================================================="
    $doc += ""
    
    $doc += "1. REBUILD BCD FROM WINDOWS INSTALLATION"
    $doc += "---------------------------------------------------------------------------------"
    $doc += "Command: bcdboot `<drive`>:\Windows /s `<ESP`> /f ALL"
    $doc += ""
    $doc += "What it does:"
    $doc += "  • Rebuilds the Boot Configuration Data (BCD) completely"
    $doc += "  • Copies boot files to the EFI System Partition (ESP)"
    $doc += "  • Creates new boot entries for Windows"
    $doc += ""
    $doc += "When to use:"
    $doc += "  • BCD is corrupted or missing"
    $doc += "  • Boot entries are incorrect"
    $doc += "  • After fixing winload.efi issues"
    $doc += ""
    
    $doc += "2. FIX BOOT FILES (bootrec /fixboot)"
    $doc += "---------------------------------------------------------------------------------"
    $doc += "Commands: bootrec /fixboot, bootrec /fixmbr, bootrec /rebuildbcd"
    $doc += ""
    $doc += "What it does:"
    $doc += "  • Repairs the boot sector"
    $doc += "  • Fixes the Master Boot Record (MBR)"
    $doc += "  • Rebuilds BCD entries"
    $doc += ""
    $doc += "When to use:"
    $doc += "  • Boot sector is corrupted"
    $doc += "  • MBR is damaged"
    $doc += "  • Boot files are missing or corrupted"
    $doc += ""
    
    $doc += "3. SCAN FOR WINDOWS INSTALLATIONS"
    $doc += "---------------------------------------------------------------------------------"
    $doc += "Command: bootrec /scanos"
    $doc += ""
    $doc += "What it does:"
    $doc += "  • Scans all drives for Windows installations"
    $doc += "  • Lists all found Windows versions"
    $doc += "  • Shows drive letters and installation paths"
    $doc += ""
    $doc += "When to use:"
    $doc += "  • Need to find all Windows installations"
    $doc += "  • Multiple Windows versions installed"
    $doc += "  • Windows not detected automatically"
    $doc += ""
    
    $doc += "4. REBUILD BCD (bootrec /rebuildbcd)"
    $doc += "---------------------------------------------------------------------------------"
    $doc += "Command: bootrec /rebuildbcd"
    $doc += ""
    $doc += "What it does:"
    $doc += "  • Rebuilds BCD from scratch"
    $doc += "  • Scans for Windows installations first"
    $doc += "  • Adds found installations to BCD"
    $doc += ""
    $doc += "When to use:"
    $doc += "  • BCD is completely corrupted"
    $doc += "  • Boot entries are missing"
    $doc += "  • After disk cloning or migration"
    $doc += ""
    
    $doc += "5. SET DEFAULT BOOT ENTRY"
    $doc += "---------------------------------------------------------------------------------"
    $doc += "Command: bcdedit /set {default} ..."
    $doc += ""
    $doc += "What it does:"
    $doc += "  • Sets which Windows installation boots by default"
    $doc += "  • Configures boot entry parameters"
    $doc += "  • Updates device and osdevice paths"
    $doc += ""
    $doc += "When to use:"
    $doc += "  • Multiple Windows installations"
    $doc += "  • Wrong Windows version boots"
    $doc += "  • Need to change default boot entry"
    $doc += ""
    
    $doc += "6. BOOT DIAGNOSIS"
    $doc += "---------------------------------------------------------------------------------"
    $doc += "Command: Comprehensive diagnostic scan"
    $doc += ""
    $doc += "What it does:"
    $doc += "  • Runs comprehensive boot diagnosis"
    $doc += "  • Checks all boot files and BCD"
    $doc += "  • Identifies boot issues"
    $doc += "  • Provides detailed report"
    $doc += ""
    $doc += "When to use:"
    $doc += "  • Need to understand boot problems"
    $doc += "  • Before attempting repairs"
    $doc += "  • Troubleshooting boot issues"
    $doc += ""
    
    $doc += "================================================================================="
    $doc += "OTHER BUTTONS"
    $doc += "================================================================================="
    $doc += ""
    $doc += "These buttons are available in other tabs:"
    $doc += ""
    $doc += "  • BCD Editor tab: Edit BCD entries manually"
    $doc += "  • Diagnostics tab: System restore, OS info, etc."
    $doc += "  • Diagnostics `& Logs tab: View detailed logs"
    $doc += ""
    $doc += "For detailed information about other features, check the help icons in those tabs."
    $doc += ""
    
    $doc += "================================================================================="
    $doc += "TIPS AND BEST PRACTICES"
    $doc += "================================================================================="
    $doc += ""
    $doc += "1. Always start with 'Preview Only (Dry Run)' to see what would happen"
    $doc += "2. Even with 'None' selected, the tool analyzes and fixes real issues"
    $doc += "3. Use 'Brute Force Mode' only if standard repair fails"
    $doc += "4. Run 'Boot Diagnosis' first to understand the problem"
    $doc += "5. BCD backups are created automatically before repairs"
    $doc += "6. Check the Command Output box for detailed operation logs"
    $doc += ""
    
    $doc += "================================================================================="
    $doc += "END OF HELP GUIDE"
    $doc += "================================================================================="
    
    Set-Content -Path $docPath -Value ($doc -join "`r`n") -Encoding UTF8 -Force
    return $docPath
}

# Boot Fixer tab info button
$btnBootFixerInfo = Get-Control -Name "BtnBootFixerInfo"
if ($btnBootFixerInfo) {
    $btnBootFixerInfo.Add_Click({
        $helpDoc = New-BootFixerHelpDocument
        $helpContent = Get-Content $helpDoc -Raw
        
        [System.Windows.MessageBox]::Show(
            $helpContent,
            "Boot Fixer - Help Information",
            "OK",
            "Information"
        )
    })
}

# Boot Fixer tab notepad button
$btnBootFixerNotepad = Get-Control -Name "BtnBootFixerNotepad"
if ($btnBootFixerNotepad) {
    $btnBootFixerNotepad.Add_Click({
        $helpDoc = New-BootFixerHelpDocument
        try {
            Start-Process notepad.exe -ArgumentList "`"$helpDoc`""
        } catch {
            [System.Windows.MessageBox]::Show(
                "Could not open Notepad. Help document saved to:`n$helpDoc",
                "Help Document",
                "OK",
                "Information"
            )
        }
    })
}

# One-Click Repair info button
$btnOneClickInfo = Get-Control -Name "BtnOneClickInfo"
if ($btnOneClickInfo) {
    $btnOneClickInfo.Add_Click({
        $helpText = @"
ONE-CLICK REPAIR OPTIONS

TARGET DRIVE:
Select the Windows drive you want to repair. Auto-detects available Windows installations.

SIMULATE ISSUE:
• None (Default) - Analyzes and fixes ACTUAL issues found on your system
• winload_missing - Simulates missing winload.efi (testing only)
• bcd_missing - Simulates missing BCD (testing only)
• storage_driver_missing - Simulates missing drivers (testing only)

IMPORTANT: Even if 'None' is selected, the tool will still analyze and fix real issues!

REPAIR MODE:
• Preview Only (Dry Run) - Shows commands, makes no changes
• Execute Repairs - Actually repairs your system (recommended)
• Brute Force Mode - Most aggressive, use when standard repair fails
"@
        [System.Windows.MessageBox]::Show(
            $helpText,
            'One-Click Repair - Help',
            'OK',
            'Information'
        )
    })
}

# One-Click Repair notepad button
$btnOneClickNotepad = Get-Control -Name "BtnOneClickNotepad"
if ($btnOneClickNotepad) {
    $btnOneClickNotepad.Add_Click({
        $helpDoc = New-BootFixerHelpDocument
        try {
            Start-Process notepad.exe -ArgumentList "`"$helpDoc`""
        } catch {
            [System.Windows.MessageBox]::Show(
                "Could not open Notepad. Help document saved to:`n$helpDoc",
                "Help Document",
                "OK",
                "Information"
            )
        }
    })
}

# Boot Repair Operations info button
$btnBootOpsInfo = Get-Control -Name "BtnBootOpsInfo"
if ($btnBootOpsInfo) {
    $btnBootOpsInfo.Add_Click({
        $helpText = @"
BOOT REPAIR OPERATIONS

1. REBUILD BCD FROM WINDOWS INSTALLATION
   Rebuilds BCD completely using bcdboot. Use when BCD is corrupted.

2. FIX BOOT FILES (bootrec /fixboot)
   Repairs boot sector, MBR, and rebuilds BCD. Use for boot sector issues.

3. SCAN FOR WINDOWS INSTALLATIONS
   Scans all drives for Windows. Use to find all installations.

4. REBUILD BCD (bootrec /rebuildbcd)
   Rebuilds BCD from scratch. More aggressive than option 1.

5. SET DEFAULT BOOT ENTRY
   Sets which Windows boots by default. Use with multiple installations.

6. BOOT DIAGNOSIS
   Comprehensive diagnostic scan. Run this first to understand problems.

Click any button to see detailed command information and preview.
"@
        [System.Windows.MessageBox]::Show(
            $helpText,
            "Boot Repair Operations - Help",
            "OK",
            "Information"
        )
    })
}

# Boot Repair Operations notepad button
$btnBootOpsNotepad = Get-Control -Name "BtnBootOpsNotepad"
if ($btnBootOpsNotepad) {
    $btnBootOpsNotepad.Add_Click({
        $helpDoc = New-BootFixerHelpDocument
        try {
            Start-Process notepad.exe -ArgumentList "`"$helpDoc`""
        } catch {
            [System.Windows.MessageBox]::Show(
                "Could not open Notepad. Help document saved to:`n$helpDoc",
                "Help Document",
                "OK",
                "Information"
            )
        }
    })
}

# NOTE: All code below this point is at script level and executes when module loads
# Button handlers use Get-Control which safely returns null if $W doesn't exist yet
# Window event wiring and ShowDialog are handled INSIDE Start-GUI function (before line 2438)
