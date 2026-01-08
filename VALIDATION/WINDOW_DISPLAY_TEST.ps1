# WINDOW DISPLAY TEST - Verify GUI window actually launches and displays
# This test will create the window in a background job and check if it exists

$rootPath = Split-Path -Parent -Path $PSScriptRoot
$coreFile = Join-Path $rootPath "HELPER SCRIPTS\WinRepairCore.ps1"
$guiFile = Join-Path $rootPath "HELPER SCRIPTS\WinRepairGUI.ps1"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "WINDOW DISPLAY TEST" -ForegroundColor Cyan
Write-Host "Creates GUI in job and verifies window shows up" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Create the invocation script
$guiScript = {
    param($coreFile, $guiFile)
    
    $global:Error.Clear()
    
    # Load assemblies
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    
    # Source the files
    . $coreFile -ErrorAction Stop
    . $guiFile -ErrorAction Stop
    
    Write-Host "[INFO] About to call Start-GUI"
    
    try {
        Start-GUI
        Write-Host "[SUCCESS] Start-GUI returned successfully"
    } catch {
        Write-Host "[ERROR] Exception in Start-GUI: $($_.Exception.Message)"
        Write-Host "[ERROR] Stack: $($_.ScriptStackTrace)"
        throw
    }
}

# Run in background job
Write-Host "[JOB] Starting GUI in background job..."
$job = Start-Job -ScriptBlock $guiScript -ArgumentList @($coreFile, $guiFile)

# Wait for job to complete or timeout
Write-Host "[JOB] Waiting for GUI to initialize (timeout: 8 seconds)..."
Start-Sleep -Seconds 2

# Check if window exists using .NET
Write-Host "[CHECK] Looking for GUI window..."
$allWindows = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
    [System.Windows.Automation.TreeScope]::Children,
    [System.Windows.Automation.Condition]::TrueCondition
)

Write-Host "[CHECK] Found $($allWindows.Count) windows"

$guiWindow = $allWindows | Where-Object { $_.Current.Name -like "*Miracle*" -or $_.Current.Name -like "*Recovery*" }

if ($guiWindow) {
    Write-Host "[SUCCESS] GUI window found: $($guiWindow.Current.Name)" -ForegroundColor Green
} else {
    Write-Host "[WARNING] GUI window not detected" -ForegroundColor Yellow
}

# Wait for job to complete
Wait-Job -Job $job -Timeout 8 | Out-Null

# Check job status
if ($job.State -eq 'Completed') {
    Write-Host "[JOB] Job completed" -ForegroundColor Green
    $output = Receive-Job -Job $job
    if ($output) {
        Write-Host "[OUTPUT]"
        $output | ForEach-Object { Write-Host "  $_" }
    }
} else {
    Write-Host "[JOB] Job status: $($job.State)" -ForegroundColor Yellow
    
    $output = Receive-Job -Job $job
    if ($output) {
        Write-Host "[OUTPUT]"
        $output | ForEach-Object { Write-Host "  $_" }
    }
}

# Terminate job
Stop-Job -Job $job -ErrorAction SilentlyContinue
Remove-Job -Job $job -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "[INFO] Test completed"
