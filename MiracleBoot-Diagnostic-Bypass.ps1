# MiracleBoot Diagnostic Bypass - Full Logging
# Runs GUI initialization with complete diagnostics

Write-Host "MiracleBoot Diagnostic Mode - GUI Launch Test" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

# Enable all error output
$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"

# Create logging
$logFile = "MiracleBoot-Diagnostic-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:logBuffer = @()

function Log-Event {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $logLine = "[$timestamp] [$Level] $Message"
    Write-Host $logLine -ForegroundColor $(
        switch($Level) {
            "ERROR" {"Red"}
            "WARNING" {"Yellow"}
            "SUCCESS" {"Green"}
            default {"Gray"}
        }
    )
    $script:logBuffer += $logLine
}

Log-Event "Starting diagnostic mode" "INFO"
Log-Event "Loading core modules..." "INFO"

# Load core module
try {
    Log-Event "Dot-sourcing WinRepairCore.ps1..." "DEBUG"
    . ".\Helper\WinRepairCore.ps1" -ErrorAction Stop
    Log-Event "✓ Core module loaded" "SUCCESS"
} catch {
    Log-Event "✗ Failed to load core module: $_" "ERROR"
    $script:logBuffer | Out-File $logFile -Encoding UTF8
    exit 1
}

# Load GUI module with diagnostics
Log-Event "Starting GUI initialization..." "INFO"
try {
    Log-Event "Loading PresentationFramework..." "DEBUG"
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Log-Event "✓ PresentationFramework loaded" "SUCCESS"
    
    Log-Event "Loading System.Windows.Forms..." "DEBUG"
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Log-Event "✓ System.Windows.Forms loaded" "SUCCESS"
    
    Log-Event "Dot-sourcing WinRepairGUI.ps1..." "DEBUG"
    . ".\Helper\WinRepairGUI.ps1" -ErrorAction Stop
    Log-Event "✓ GUI module loaded" "SUCCESS"
    
    Log-Event "Calling Start-GUI function..." "DEBUG"
    Start-GUI
    Log-Event "✓ GUI launched successfully" "SUCCESS"
    
} catch {
    Log-Event "✗ GUI initialization failed: $($_.Exception.Message)" "ERROR"
    Log-Event "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    Log-Event "Inner exception: $($_.Exception.InnerException)" "ERROR"
}

# Save logs
$script:logBuffer | Out-File $logFile -Encoding UTF8
Log-Event "Logs saved to: $logFile" "INFO"
Log-Event "Diagnostic complete" "INFO"
