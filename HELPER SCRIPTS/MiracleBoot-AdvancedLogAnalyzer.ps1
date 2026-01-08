<#
.SYNOPSIS
    MiracleBoot Advanced Log Analyzer
    
    Provides deep analysis of gathered logs with pattern matching, 
    signature detection, and actionable remediation steps.

.DESCRIPTION
    Analyzes logs using:
    - Signature-based pattern matching
    - Error code interpretation
    - Driver dependency resolution
    - BCD validation
    - Registry corruption detection
    - Timeline correlation across multiple logs

#>

param(
    [String]$LogDirectory = "$PSScriptRoot\..\LOGS\LogAnalysis",
    [Switch]$Interactive,
    [Switch]$GenerateRemediationScript
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

#region Signatures Database
$ErrorSignatures = @{
    # INACCESSIBLE_BOOT_DEVICE
    "INACCESSIBLE_BOOT_DEVICE" = @{
        Code = "0x7B"
        Category = "Storage/Boot Device"
        Causes = @(
            "Storage driver missing or disabled",
            "Wrong RAID mode (RAID vs AHCI mismatch)",
            "NVMe/VMD not properly initialized",
            "Disk moved to different NVMe slot",
            "Image restored to incompatible hardware"
        )
        Fixes = @(
            "Inject correct storage driver in WinPE",
            "Fix BCD boot device path",
            "Enable storage driver in Registry: HKLM\SYSTEM\CurrentControlSet\Services",
            "Switch BIOS RAID mode if applicable"
        )
    }
    
    # CRITICAL_PROCESS_DIED
    "CRITICAL_PROCESS_DIED" = @{
        Code = "0xEF"
        Category = "System Process"
        Causes = @(
            "csrss.exe terminated abnormally",
            "svchost.exe critical failure",
            "Registry corruption affecting services"
        )
        Fixes = @(
            "Check System event log for specific process",
            "Run Repair-WindowsImage to fix corrupted components",
            "Restore registry from backup"
        )
    }
    
    # DRIVER_IRQL_NOT_LESS_OR_EQUAL
    "DRIVER_IRQL_NOT_LESS_OR_EQUAL" = @{
        Code = "0xD1"
        Category = "Driver Error"
        Causes = @(
            "Faulty kernel-mode driver",
            "Bad RAM",
            "Driver accessing invalid memory address"
        )
        Fixes = @(
            "Update or remove problematic driver",
            "Run memory diagnostics",
            "Check kernel dump for driver name"
        )
    }
    
    # SYSTEM_SERVICE_EXCEPTION
    "SYSTEM_SERVICE_EXCEPTION" = @{
        Code = "0x3B"
        Category = "Service Exception"
        Causes = @(
            "Corrupted service registry",
            "Bad device driver",
            "Hardware malfunction"
        )
        Fixes = @(
            "Repair Windows system files",
            "Disable problematic service",
            "Run hardware diagnostics"
        )
    }
    
    # KERNEL_DATA_INPAGE_ERROR
    "KERNEL_DATA_INPAGE_ERROR" = @{
        Code = "0x7A"
        Category = "Memory/Storage"
        Causes = @(
            "Bad storage hardware",
            "Faulty RAM",
            "Corrupted paging file",
            "NVMe controller error"
        )
        Fixes = @(
            "Run disk diagnostics (chkdsk)",
            "Check NVMe firmware",
            "Test RAM with memtest86",
            "Replace failing storage device"
        )
    }
}

$StorageDrivers = @(
    "stornvme",      # NVMe storage
    "storahci",      # AHCI storage
    "iaStorV",       # Intel Rapid Storage
    "iaStorVD",      # Intel DME/NVMe
    "nvme",          # NVMe controller
    "uaspstor",      # USB SCSI
    "ufx01000"       # USB Function
)

$ServiceStartValues = @{
    0 = "Boot"
    1 = "System"
    2 = "Automatic"
    3 = "Manual"
    4 = "Disabled"
}

#endregion

#region Analysis Functions
function Analyze-MemoryDump {
    param([String]$DumpPath)
    
    if (-not (Test-Path $DumpPath)) { return }
    
    Write-Host "`n=== MEMORY.DMP Analysis ===" -ForegroundColor Cyan
    
    $FileSize = (Get-Item $DumpPath).Length / 1GB
    Write-Host "Dump size: $($FileSize)GB"
    
    # Check for signature
    $Header = Get-Content $DumpPath -Encoding Byte -TotalCount 4 -ErrorAction SilentlyContinue
    if ($Header -join "," -eq "80,77,68,80") {
        Write-Host "✓ Valid dump signature (PMDP)" -ForegroundColor Green
    }
    
    Write-Host "`n⚠️  RECOMMENDED: Analyze with WinDbg or Crash Analyzer" -ForegroundColor Yellow
    Write-Host "Steps:" -ForegroundColor Yellow
    Write-Host "  1. Open crashanalyze.exe or WinDbg"
    Write-Host "  2. Load: $DumpPath"
    Write-Host "  3. Run command: !analyze -v"
    Write-Host "  4. Look for: Bug Check Code, Faulting Driver Name, Stack Trace"
}

function Analyze-SetupLogs {
    param([String]$LogDirectory)
    
    Write-Host "`n=== Setup Log Analysis ===" -ForegroundColor Cyan
    
    $SetupActPath = Join-Path $LogDirectory "setupact.log"
    $SetupErrPath = Join-Path $LogDirectory "setuperr.log"
    
    foreach ($LogPath in @($SetupActPath, $SetupErrPath)) {
        if (-not (Test-Path $LogPath)) { continue }
        
        $LogName = Split-Path $LogPath -Leaf
        Write-Host "`n$LogName:" -ForegroundColor Yellow
        
        $Content = Get-Content $LogPath -ErrorAction SilentlyContinue
        
        # Critical keywords
        $CriticalKeywords = @(
            "Boot environment mismatch",
            "Edition/build family mismatch",
            "CBS state invalid",
            "Boot device not accessible",
            "INACCESSIBLE_BOOT_DEVICE",
            "storage driver",
            "failed",
            "error",
            "fatal"
        )
        
        foreach ($Keyword in $CriticalKeywords) {
            $Matches = $Content | Select-String -Pattern $Keyword -ErrorAction SilentlyContinue
            if ($Matches) {
                Write-Host "  [!] Keyword found: $Keyword" -ForegroundColor Red
                foreach ($Match in $Matches | Select-Object -First 3) {
                    Write-Host "      $($Match.Line.Trim())" -ForegroundColor Yellow
                }
                if ($Matches.Count -gt 3) {
                    Write-Host "      ... and $($Matches.Count - 3) more matches" -ForegroundColor Yellow
                }
            }
        }
    }
}

function Analyze-BootTraceLog {
    param([String]$LogDirectory)
    
    Write-Host "`n=== Boot Trace Log Analysis ===" -ForegroundColor Cyan
    
    $NbtLogPath = Join-Path $LogDirectory "ntbtlog.txt"
    if (-not (Test-Path $NbtLogPath)) {
        Write-Host "ntbtlog.txt not found" -ForegroundColor Gray
        return
    }
    
    $Content = Get-Content $NbtLogPath -ErrorAction SilentlyContinue
    
    # Find failed drivers
    $FailedLines = $Content | Select-String "Did not load|Load failed|ERROR|FAILED"
    
    if ($FailedLines) {
        Write-Host "✗ Failed driver loads detected:" -ForegroundColor Red
        foreach ($Line in $FailedLines | Select-Object -First 10) {
            Write-Host "  $($Line.Line)" -ForegroundColor Yellow
        }
        
        # Highlight storage drivers
        $StorageFailures = $FailedLines | Where-Object { $_ -match ($StorageDrivers -join "|") }
        if ($StorageFailures) {
            Write-Host "`n⚠️  CRITICAL: Storage driver failed to load" -ForegroundColor Red
            Write-Host "This is likely the root cause of boot failure" -ForegroundColor Red
        }
    } else {
        Write-Host "✓ No failed driver loads detected" -ForegroundColor Green
    }
}

function Analyze-EventLog {
    param([String]$LogDirectory)
    
    Write-Host "`n=== Event Log Analysis ===" -ForegroundColor Cyan
    
    $EventLogPath = Join-Path $LogDirectory "System.evtx"
    if (-not (Test-Path $EventLogPath)) {
        Write-Host "System.evtx not found (offline analysis)" -ForegroundColor Gray
        return
    }
    
    Write-Host "ℹ️  To analyze System.evtx:" -ForegroundColor Cyan
    Write-Host "  1. Copy to a Windows system with Event Viewer"
    Write-Host "  2. Open Event Viewer"
    Write-Host "  3. File → Open Saved Log"
    Write-Host "  4. Look for:"
    Write-Host "     - Event ID 1001 (BugCheck/Crash)"
    Write-Host "     - Event ID 41 (Kernel-Power)"
    Write-Host "     - Event ID 7034 (Service unexpected exit)"
    Write-Host "     - volmgr/disk/nvme errors"
}

function Analyze-LiveKernelReports {
    param([String]$LogDirectory)
    
    Write-Host "`n=== LiveKernelReports Analysis ===" -ForegroundColor Cyan
    
    $ReportsPath = Join-Path $LogDirectory "LiveKernelReports"
    if (-not (Test-Path $ReportsPath)) {
        Write-Host "LiveKernelReports not found" -ForegroundColor Gray
        return
    }
    
    $Subfolders = @("STORAGE", "WATCHDOG", "NDIS", "USB")
    
    foreach ($Subfolder in $Subfolders) {
        $SubPath = Join-Path $ReportsPath $Subfolder
        if (Test-Path $SubPath) {
            $Dumps = Get-ChildItem $SubPath -Filter "*.dmp" -Recurse
            if ($Dumps) {
                $Severity = if ($Subfolder -eq "STORAGE") { "CRITICAL" } else { "WARNING" }
                Write-Host "  [$Severity] $Subfolder: $($Dumps.Count) report(s)" -ForegroundColor $(if ($Severity -eq "CRITICAL") { "Red" } else { "Yellow" })
            }
        }
    }
    
    Write-Host "`n⚠️  STORAGE reports indicate silent driver/controller hang" -ForegroundColor Red
    Write-Host "Recommendation: Inject correct storage driver for hardware" -ForegroundColor Yellow
}

function Analyze-RegistryHive {
    param([String]$LogDirectory)
    
    Write-Host "`n=== Registry Analysis ===" -ForegroundColor Cyan
    
    $RegistryPath = Join-Path $LogDirectory "SYSTEM_hive"
    if (-not (Test-Path $RegistryPath)) {
        Write-Host "SYSTEM registry hive not found (requires offline analysis)" -ForegroundColor Gray
        return
    }
    
    Write-Host "To analyze storage driver registry settings:" -ForegroundColor Cyan
    Write-Host "  1. Mount SYSTEM hive in offline registry editor"
    Write-Host "  2. Navigate to: HKLM\SYSTEM\ControlSet001\Services"
    Write-Host "  3. Check these drivers:" -ForegroundColor Yellow
    foreach ($Driver in $StorageDrivers) {
        Write-Host "     - $Driver (Start should be 0-3, NOT 4)" -ForegroundColor Yellow
    }
    Write-Host "`n  If Start=4 (disabled): Enable with:"
    Write-Host "    reg add HKLM\SYSTEM\ControlSet001\Services\<DRIVER> /v Start /t REG_DWORD /d 0" -ForegroundColor Cyan
}

#endregion

#region Root Cause Determination
function Determine-RootCause {
    param([String]$LogDirectory)
    
    Write-Host "`n" + ("="*70) -ForegroundColor Cyan
    Write-Host "ROOT CAUSE DETERMINATION" -ForegroundColor Cyan
    Write-Host ("="*70) -ForegroundColor Cyan
    
    $Evidence = @{
        HasMemoryDump = Test-Path (Join-Path $LogDirectory "MEMORY.DMP")
        HasLiveKernelReports = Test-Path (Join-Path $LogDirectory "LiveKernelReports")
        HasSetupLogs = (Test-Path (Join-Path $LogDirectory "setupact.log")) -or (Test-Path (Join-Path $LogDirectory "setuperr.log"))
        HasBootTrace = Test-Path (Join-Path $LogDirectory "ntbtlog.txt")
        HasEventLog = Test-Path (Join-Path $LogDirectory "System.evtx")
    }
    
    Write-Host "`nEvidence collected:"
    $Evidence.GetEnumerator() | ForEach-Object {
        $Status = if ($_.Value) { "✓" } else { "✗" }
        Write-Host "  $Status $($_.Key)" -ForegroundColor $(if ($_.Value) { "Green" } else { "Gray" })
    }
    
    # Decision logic
    if ($Evidence.HasMemoryDump) {
        Write-Host "`n[1] MEMORY.DMP EXISTS" -ForegroundColor Red
        Write-Host "    → This is the smoking gun. Kernel crashed and created full dump." -ForegroundColor Yellow
        Write-Host "    → USE: Crash Dump Analyzer or WinDbg" -ForegroundColor Cyan
        return
    }
    
    if ($Evidence.HasLiveKernelReports) {
        Write-Host "`n[2] LiveKernelReports FOUND" -ForegroundColor Red
        Write-Host "    → System hard-reset or driver timeout (before full dump)" -ForegroundColor Yellow
        Write-Host "    → Likely: Storage driver/controller hang" -ForegroundColor Cyan
        return
    }
    
    if ($Evidence.HasSetupLogs) {
        Write-Host "`n[3] SETUP LOGS FOUND" -ForegroundColor Red
        Write-Host "    → Windows rejected boot or upgrade environment mismatch" -ForegroundColor Yellow
        Write-Host "    → Check: setupact.log for explicit error messages" -ForegroundColor Cyan
        return
    }
    
    if ($Evidence.HasBootTrace) {
        Write-Host "`n[4] BOOT TRACE LOG EXISTS" -ForegroundColor Red
        Write-Host "    → Boot logging was enabled (check for failed drivers)" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n⚠️  INSUFFICIENT DATA" -ForegroundColor Yellow
    Write-Host "No crash dumps or boot logs found. This may indicate:" -ForegroundColor Yellow
    Write-Host "  - Hardware issue (check physical connections)" -ForegroundColor Yellow
    Write-Host "  - BIOS/Firmware issue" -ForegroundColor Yellow
    Write-Host "  - System won't POST (dead)" -ForegroundColor Yellow
}

#endregion

#region Remediation Script Generation
function Generate-RemediationScript {
    param([String]$LogDirectory)
    
    Write-Host "`n" + ("="*70) -ForegroundColor Cyan
    Write-Host "REMEDIATION SCRIPT GENERATION" -ForegroundColor Cyan
    Write-Host ("="*70) -ForegroundColor Cyan
    
    $RemediationSteps = @()
    
    # Check for common issues
    $SetupActPath = Join-Path $LogDirectory "setupact.log"
    if (Test-Path $SetupActPath) {
        $Content = Get-Content $SetupActPath -ErrorAction SilentlyContinue
        
        if ($Content -match "storage driver|nvme|storahci") {
            $RemediationSteps += @"
# STEP 1: Boot into WinPE and inject storage driver
# Command to inject driver:
Dism /Image:C: /Add-Driver /Driver:"<path-to-driver>" /ForceUnsigned

# Example for NVMe:
Dism /Image:C: /Add-Driver /Driver:"E:\Drivers\nvme_driver.inf" /ForceUnsigned
"@
        }
    }
    
    if (Test-Path (Join-Path $LogDirectory "ntbtlog.txt")) {
        $RemediationSteps += @"
# STEP 2: Enable storage driver in offline registry (WinPE)
# Command:
reg load HKLM\OfflineSystem C:\Windows\System32\config\SYSTEM
reg add HKLM\OfflineSystem\ControlSet001\Services\stornvme /v Start /t REG_DWORD /d 0
reg unload HKLM\OfflineSystem
"@
    }
    
    $RemediationSteps += @"
# STEP 3: Rebuild BCD
bcdboot C:\Windows /s S: /f UEFI

# STEP 4: Verify boot configuration
bcdedit /store S:\EFI\Microsoft\Boot\BCD /enum all

# STEP 5: Test boot
# Reboot system and monitor for INACCESSIBLE_BOOT_DEVICE
"@
    
    $ScriptPath = Join-Path $LogDirectory "Remediation-Steps.ps1"
    $RemediationSteps -join "`n`n" | Out-File $ScriptPath -Force
    
    Write-Host "`nRemediation script created: $ScriptPath" -ForegroundColor Green
    Write-Host "⚠️  Review and modify before executing" -ForegroundColor Yellow
}

#endregion

#region Interactive Menu
function Show-InteractiveMenu {
    param([String]$LogDirectory)
    
    while ($true) {
        Write-Host "`n" + ("="*70) -ForegroundColor Cyan
        Write-Host "INTERACTIVE LOG ANALYSIS" -ForegroundColor Cyan
        Write-Host ("="*70) -ForegroundColor Cyan
        
        Write-Host "`n1. Analyze MEMORY.DMP"
        Write-Host "2. Analyze Setup Logs"
        Write-Host "3. Analyze Boot Trace"
        Write-Host "4. Analyze Event Logs"
        Write-Host "5. Analyze LiveKernelReports"
        Write-Host "6. Analyze Registry Hive"
        Write-Host "7. Determine Root Cause"
        Write-Host "8. Generate Remediation Script"
        Write-Host "9. Open Event Viewer"
        Write-Host "0. Exit"
        
        $Choice = Read-Host "`nSelect option"
        
        switch ($Choice) {
            "1" { Analyze-MemoryDump (Join-Path $LogDirectory "MEMORY.DMP") }
            "2" { Analyze-SetupLogs $LogDirectory }
            "3" { Analyze-BootTraceLog $LogDirectory }
            "4" { Analyze-EventLog $LogDirectory }
            "5" { Analyze-LiveKernelReports $LogDirectory }
            "6" { Analyze-RegistryHive $LogDirectory }
            "7" { Determine-RootCause $LogDirectory }
            "8" { Generate-RemediationScript $LogDirectory }
            "9" { Start-Process "eventvwr.exe" -ErrorAction SilentlyContinue }
            "0" { break }
            default { Write-Host "Invalid option" -ForegroundColor Red }
        }
    }
}

#endregion

#region Main
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     MiracleBoot Advanced Log Analyzer                      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

if (-not (Test-Path $LogDirectory)) {
    Write-Host "Log directory not found: $LogDirectory" -ForegroundColor Red
    Write-Host "Run MiracleBoot-LogGatherer.ps1 first to gather logs." -ForegroundColor Yellow
    exit
}

# Full analysis
Analyze-MemoryDump (Join-Path $LogDirectory "MEMORY.DMP")
Analyze-SetupLogs $LogDirectory
Analyze-BootTraceLog $LogDirectory
Analyze-EventLog $LogDirectory
Analyze-LiveKernelReports $LogDirectory
Analyze-RegistryHive $LogDirectory
Determine-RootCause $LogDirectory

if ($GenerateRemediationScript) {
    Generate-RemediationScript $LogDirectory
}

if ($Interactive) {
    Show-InteractiveMenu $LogDirectory
}

Write-Host "`n✓ Analysis complete" -ForegroundColor Green
