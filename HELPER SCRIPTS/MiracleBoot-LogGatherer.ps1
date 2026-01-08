<#
.SYNOPSIS
    MiracleBoot Log Gatherer & Analyzer
    
    Systematically collects and analyzes diagnostic logs following the TIER-based 
    priority system for root cause analysis of boot failures and system issues.
    
.DESCRIPTION
    Gathers logs from multiple sources organized by diagnostic priority:
    - TIER 1: Boot-critical crash dumps (MEMORY.DMP, LiveKernelReports)
    - TIER 2: Boot pipeline logs (Setup logs, ntbtlog.txt)
    - TIER 3: Event logs (System.evtx)
    - TIER 4: Boot structure (BCD, Registry)
    - TIER 5: Image/hardware context
    
    Analyzes findings and provides actionable root cause summaries.

.AUTHOR
    MiracleBoot Team
    
.VERSION
    7.2
#>

param(
    [Switch]$GatherOnly,
    [Switch]$AnalyzeOnly,
    [String]$OfflineSystemDrive = "C:",
    [String]$OutputDirectory = "$PSScriptRoot\..\LOGS\LogAnalysis",
    [Switch]$OpenEventViewer,
    [Switch]$LaunchCrashAnalyzer,
    [Switch]$Verbose
)

#region Initialize
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$ScriptVersion = "7.2"
$ScriptName = "MiracleBoot-LogGatherer"

# Ensure output directory exists
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$LogFile = Join-Path $OutputDirectory "GatherAnalysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$AnalysisReport = Join-Path $OutputDirectory "RootCauseAnalysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$JSONReport = Join-Path $OutputDirectory "Analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

# Initialize collections
$Findings = @()
$Tiers = @{
    "TIER_1_CriticalDumps" = @()
    "TIER_2_BootLogs" = @()
    "TIER_3_EventLogs" = @()
    "TIER_4_BootStructure" = @()
    "TIER_5_Context" = @()
}

#endregion

#region Logging
function Write-Log {
    param([String]$Message, [String]$Level = "INFO")
    $Timestamp = Get-Date -Format "HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

function Add-Finding {
    param(
        [String]$Tier,
        [String]$Category,
        [String]$Finding,
        [String]$Severity = "INFO",
        [String]$Recommendation = ""
    )
    
    $Finding = [PSCustomObject]@{
        Tier = $Tier
        Category = $Category
        Finding = $Finding
        Severity = $Severity
        Recommendation = $Recommendation
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $Tiers[$Tier] += $Finding
    $Findings += $Finding
    
    $SeverityColor = switch ($Severity) {
        "CRITICAL" { "Red" }
        "WARNING" { "Yellow" }
        "INFO" { "Green" }
        default { "White" }
    }
    
    Write-Host "  [$Severity] $Finding" -ForegroundColor $SeverityColor
}

#endregion

#region TIER 1: Boot-Critical Crash Dumps
function Gather-BootCriticalDumps {
    Write-Log "=== TIER 1: Boot-Critical Crash Dumps ===" "INFO"
    
    # MEMORY.DMP (Kernel crash dump)
    $MemoryDmp = Join-Path $OfflineSystemDrive "\Windows\MEMORY.DMP"
    if (Test-Path $MemoryDmp) {
        $Size = (Get-Item $MemoryDmp).Length / 1GB
        Write-Log "  ✓ MEMORY.DMP found (${Size:F2} GB)" "SUCCESS"
        Add-Finding "TIER_1_CriticalDumps" "Kernel Dump" "MEMORY.DMP exists - indicates kernel crash" "CRITICAL" "Analyze with WinDbg or Crash Dump Analyzer"
        
        # Copy for analysis
        Copy-Item $MemoryDmp "$OutputDirectory\MEMORY.DMP" -Force -ErrorAction SilentlyContinue
    } else {
        Write-Log "  ✗ MEMORY.DMP not found" "WARNING"
    }
    
    # LiveKernelReports
    $LiveKernelPath = Join-Path $OfflineSystemDrive "\Windows\LiveKernelReports\"
    if (Test-Path $LiveKernelPath) {
        $Reports = Get-ChildItem $LiveKernelPath -Recurse -Filter "*.dmp" | Measure-Object
        if ($Reports.Count -gt 0) {
            Write-Log "  ✓ LiveKernelReports found ($($Reports.Count) dumps)" "SUCCESS"
            Add-Finding "TIER_1_CriticalDumps" "LiveKernelReports" "Found $($Reports.Count) kernel reports" "WARNING" "Check STORAGE, WATCHDOG, NDIS, USB subfolders"
            
            # Copy reports
            Copy-Item $LiveKernelPath "$OutputDirectory\LiveKernelReports\" -Recurse -Force -ErrorAction SilentlyContinue
            
            # Analyze by subfolder
            foreach ($Subfolder in @("STORAGE", "WATCHDOG", "NDIS", "USB")) {
                $SubPath = Join-Path $LiveKernelPath $Subfolder
                if (Test-Path $SubPath) {
                    $Count = (Get-ChildItem $SubPath -Recurse -Filter "*.dmp").Count
                    if ($Count -gt 0) {
                        $Severity = if ($Subfolder -eq "STORAGE") { "CRITICAL" } else { "WARNING" }
                        Add-Finding "TIER_1_CriticalDumps" "LiveKernelReports-$Subfolder" "$Subfolder reports: $Count" $Severity ""
                    }
                }
            }
        }
    } else {
        Write-Log "  ✗ LiveKernelReports not found" "INFO"
    }
    
    # Minidumps (lower priority)
    $MinidumpPath = Join-Path $OfflineSystemDrive "\Windows\Minidump\"
    if (Test-Path $MinidumpPath) {
        $Minidumps = Get-ChildItem $MinidumpPath -Filter "*.dmp" | Measure-Object
        if ($Minidumps.Count -gt 0) {
            Write-Log "  ✓ Minidumps found ($($Minidumps.Count))" "INFO"
            Add-Finding "TIER_1_CriticalDumps" "Minidumps" "Found $($Minidumps.Count) minidumps (lower priority)" "INFO" "Analyze if MEMORY.DMP and LiveKernelReports empty"
            Copy-Item $MinidumpPath "$OutputDirectory\Minidump\" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

#endregion

#region TIER 2: Boot Pipeline Logs
function Gather-BootPipelineLogs {
    Write-Log "=== TIER 2: Boot Pipeline Logs ===" "INFO"
    
    # Setup logs in WinRE/Setup context
    $PantherPaths = @(
        (Join-Path $OfflineSystemDrive "\`$WINDOWS.~BT\Sources\Panther\"),
        (Join-Path $OfflineSystemDrive "\Windows\Panther\")
    )
    
    $PantherFound = $false
    foreach ($PantherPath in $PantherPaths) {
        if (Test-Path $PantherPath) {
            $PantherFound = $true
            Write-Log "  ✓ Panther logs found at $PantherPath" "SUCCESS"
            Add-Finding "TIER_2_BootLogs" "Setup Logs" "Panther logs located" "CRITICAL" "Parse setupact.log and setuperr.log"
            
            foreach ($LogFile in @("setupact.log", "setuperr.log")) {
                $FullPath = Join-Path $PantherPath $LogFile
                if (Test-Path $FullPath) {
                    Write-Log "    ✓ Found $LogFile" "SUCCESS"
                    Copy-Item $FullPath "$OutputDirectory\$LogFile" -Force -ErrorAction SilentlyContinue
                    
                    # Parse for critical errors
                    Analyze-SetupLog $FullPath
                }
            }
            
            break
        }
    }
    
    if (-not $PantherFound) {
        Write-Log "  ✗ Panther logs not found" "WARNING"
    }
    
    # Boot logging (ntbtlog.txt)
    $NbtLog = Join-Path $OfflineSystemDrive "\Windows\ntbtlog.txt"
    if (Test-Path $NbtLog) {
        Write-Log "  ✓ ntbtlog.txt found" "SUCCESS"
        Add-Finding "TIER_2_BootLogs" "Boot Trace Log" "ntbtlog.txt exists - boot logging was enabled" "WARNING" "Check for failed driver loads"
        
        Copy-Item $NbtLog "$OutputDirectory\ntbtlog.txt" -Force -ErrorAction SilentlyContinue
        Analyze-BootTraceLog $NbtLog
    } else {
        Write-Log "  ✗ ntbtlog.txt not found" "INFO"
    }
    
    # Boot event logs from LogFiles
    $LogFilesPath = Join-Path $OfflineSystemDrive "\Windows\System32\LogFiles\"
    if (Test-Path $LogFilesPath) {
        foreach ($LogName in @("SrtTrail.txt", "BootCKCL.etl")) {
            $FullPath = Join-Path $LogFilesPath $LogName
            if (Test-Path $FullPath) {
                Write-Log "  ✓ Found $LogName" "SUCCESS"
                Add-Finding "TIER_2_BootLogs" "Diagnostics" "Found $LogName" "WARNING" "Check for BCD and boot environment issues"
                Copy-Item $FullPath "$OutputDirectory\$LogName" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

#endregion

#region TIER 3: Event Logs
function Gather-EventLogs {
    Write-Log "=== TIER 3: Event Logs ===" "INFO"
    
    $EventLogPath = Join-Path $OfflineSystemDrive "\Windows\System32\winevt\Logs\System.evtx"
    if (Test-Path $EventLogPath) {
        Write-Log "  ✓ System.evtx found" "SUCCESS"
        Add-Finding "TIER_3_EventLogs" "System Event Log" "System.evtx located" "CRITICAL" "Look for Event 1001 (BugCheck), Event 41 (Kernel-Power)"
        
        Copy-Item $EventLogPath "$OutputDirectory\System.evtx" -Force -ErrorAction SilentlyContinue
        Analyze-EventLog $EventLogPath
    } else {
        Write-Log "  ✗ System.evtx not found (offline system)" "INFO"
    }
}

#endregion

#region TIER 4: Boot Structure
function Gather-BootStructure {
    Write-Log "=== TIER 4: Boot Structure ===" "INFO"
    
    # BCD Store check
    Add-Finding "TIER_4_BootStructure" "BCD Store" "For offline BCD analysis, mount ESP or System partition and run: bcdedit /store <path> /enum all" "CRITICAL" "Check for missing {default}, wrong device paths, partition GUIDs"
    
    # Registry: boot-critical services
    $RegistryPath = Join-Path $OfflineSystemDrive "\Windows\System32\config\SYSTEM"
    if (Test-Path $RegistryPath) {
        Write-Log "  ✓ SYSTEM registry hive found" "SUCCESS"
        Add-Finding "TIER_4_BootStructure" "Registry" "SYSTEM hive accessible for offline analysis" "WARNING" "Check HKLM\SYSTEM\ControlSet001\Services for storage drivers"
        
        Copy-Item $RegistryPath "$OutputDirectory\SYSTEM_hive" -Force -ErrorAction SilentlyContinue
        Analyze-StorageDriverRegistry $RegistryPath
    }
}

#endregion

#region TIER 5: Image Context
function Gather-ImageContext {
    Write-Log "=== TIER 5: Image/Hardware Context ===" "INFO"
    
    # Check for hardware context markers
    $BootINI = Join-Path $OfflineSystemDrive "\boot.ini"
    if (Test-Path $BootINI) {
        Add-Finding "TIER_5_Context" "Boot Configuration" "boot.ini found (LEGACY BIOS)" "WARNING" "System uses legacy boot mode"
    }
    
    # Check EFI structure
    $EFIPath = Join-Path $OfflineSystemDrive "\EFI\Microsoft\Boot\"
    if (Test-Path $EFIPath) {
        Write-Log "  ✓ UEFI boot structure detected" "INFO"
        Add-Finding "TIER_5_Context" "Boot Mode" "UEFI boot detected" "INFO" ""
    }
    
    Add-Finding "TIER_5_Context" "Image Context" "⚠️  Manual check required: Was image restored from SATA→NVMe? RAID↔AHCI? VMD toggled?" "WARNING" "INACCESSIBLE_BOOT_DEVICE is 80% storage context mismatch"
}

#endregion

#region Log Analysis Functions
function Analyze-SetupLog {
    param([String]$LogPath)
    
    if (-not (Test-Path $LogPath)) { return }
    
    $Content = Get-Content $LogPath -ErrorAction SilentlyContinue
    
    $CriticalKeywords = @(
        "Boot environment mismatch",
        "Edition/build family mismatch",
        "CBS state invalid",
        "Boot device not accessible",
        "INACCESSIBLE_BOOT_DEVICE",
        "storage driver",
        "nvme",
        "storahci"
    )
    
    foreach ($Keyword in $CriticalKeywords) {
        $Matches = $Content | Where-Object { $_ -match $Keyword }
        if ($Matches) {
            Add-Finding "TIER_2_BootLogs" "Setup Log Analysis" "Found: $Keyword" "CRITICAL" ""
        }
    }
}

function Analyze-BootTraceLog {
    param([String]$LogPath)
    
    if (-not (Test-Path $LogPath)) { return }
    
    $Content = Get-Content $LogPath -ErrorAction SilentlyContinue
    
    $FailedDrivers = $Content | Where-Object { $_ -match "Failed to load|Load failed|ERROR" }
    if ($FailedDrivers) {
        Add-Finding "TIER_2_BootLogs" "Boot Drivers" "Found failed driver loads: check ntbtlog.txt for details" "WARNING" "If storage driver failed: inject driver or enable in registry"
    }
}

function Analyze-EventLog {
    param([String]$LogPath)
    
    if (-not (Test-Path $LogPath)) { return }
    
    Write-Log "  Note: System.evtx analysis requires mounting on live system" "INFO"
    Add-Finding "TIER_3_EventLogs" "Manual Review Needed" "Copy System.evtx to live system and analyze with Event Viewer" "INFO" "Look for Event 1001 (BugCheck), 41 (Kernel-Power), storage errors"
}

function Analyze-StorageDriverRegistry {
    param([String]$RegistryPath)
    
    Write-Log "  Note: Registry analysis requires offline registry mount" "INFO"
    
    $StorageDrivers = @("stornvme", "storahci", "iaStorV", "iaStorVD", "nvme")
    $CheckList = "Storage drivers to verify Start values:`n"
    foreach ($Driver in $StorageDrivers) {
        $CheckList += "  - $Driver (Start should be 0 or 1, not 4)`n"
    }
    
    Add-Finding "TIER_4_BootStructure" "Storage Drivers" "Manual registry check needed" "CRITICAL" $CheckList
}

#endregion

#region Decision Tree
function Build-RootCauseAnalysis {
    Write-Log "`n=== ROOT CAUSE ANALYSIS ===" "INFO"
    
    $Analysis = @"
╔════════════════════════════════════════════════════════════════════╗
║                     ROOT CAUSE ANALYSIS REPORT                     ║
║                        $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                          ║
╚════════════════════════════════════════════════════════════════════╝

DECISION TREE FOR INACCESSIBLE_BOOT_DEVICE / WON'T BOOT:
─────────────────────────────────────────────────────────

1. MEMORY.DMP exists?
   → YES: Analyze with WinDbg or Crash Dump Analyzer (highest priority)
   → NO: Continue to step 2

2. LiveKernelReports\STORAGE exists?
   → YES: Storage/controller hang detected → Inject correct driver
   → NO: Continue to step 3

3. setupact.log / setuperr.log exist?
   → YES: Parse for boot environment mismatch or CBS corruption
   → NO: Continue to step 4

4. System.evtx shows crashes?
   → YES: Review Event 1001 (BugCheck), Event 41 (Kernel-Power)
   → NO: Continue to step 5

5. ntbtlog.txt shows storage driver failed?
   → YES: Enable driver in registry or inject in WinPE
   → NO: Continue to step 6

6. BCD missing / corrupt?
   → YES: Rebuild: bcdboot C:\Windows /s S: /f UEFI
   → NO: Check context (step 7)

7. Image context (SATA→NVMe, RAID↔AHCI, VMD toggle)?
   → YES: Inject correct driver for new hardware
   → NO: Escalate - needs deeper analysis

─────────────────────────────────────────────────────────

FINDINGS SUMMARY:
"@

    # Add findings by tier
    foreach ($Tier in @("TIER_1_CriticalDumps", "TIER_2_BootLogs", "TIER_3_EventLogs", "TIER_4_BootStructure", "TIER_5_Context")) {
        $TierFindings = $Tiers[$Tier]
        if ($TierFindings.Count -gt 0) {
            $Analysis += "`n`n$Tier ($($TierFindings.Count) findings):`n"
            foreach ($Finding in $TierFindings) {
                $Analysis += "`n  [$($Finding.Severity)] $($Finding.Finding)`n"
                if ($Finding.Recommendation) {
                    $Analysis += "      → $($Finding.Recommendation)`n"
                }
            }
        }
    }
    
    $Analysis += "`n`n" + ("="*70) + "`n"
    
    return $Analysis
}

#endregion

#region Event Viewer Integration
function Launch-EventViewer {
    Write-Log "Launching Event Viewer..." "INFO"
    try {
        Start-Process "eventvwr.exe" -ErrorAction SilentlyContinue
    } catch {
        Write-Log "Could not launch Event Viewer: $_" "ERROR"
    }
}

#endregion

#region Crash Analyzer Integration
function Launch-CrashAnalyzer {
    $CrashAnalyzerPath = "$PSScriptRoot\..\CrashAnalyzer\crashanalyze.exe"
    
    if (Test-Path $CrashAnalyzerPath) {
        Write-Log "Launching Crash Dump Analyzer..." "INFO"
        try {
            Start-Process $CrashAnalyzerPath
        } catch {
            Write-Log "Error launching Crash Analyzer: $_" "ERROR"
        }
    } else {
        Write-Log "Crash Analyzer not found at $CrashAnalyzerPath" "WARNING"
        Write-Log "Please copy CrashAnalyzer files to: $PSScriptRoot\..\CrashAnalyzer\" "INFO"
    }
}

#endregion

#region Export Results
function Export-AnalysisResults {
    param([String]$Analysis)
    
    Write-Log "`n=== EXPORTING RESULTS ===" "INFO"
    
    # Export text report
    $Analysis | Out-File $AnalysisReport -Force
    Write-Log "Analysis report saved: $AnalysisReport" "SUCCESS"
    
    # Export JSON for programmatic analysis
    $JSONOutput = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ScriptVersion = $ScriptVersion
        Tiers = @{}
        Summary = @{
            CriticalFindings = ($Findings | Where-Object { $_.Severity -eq "CRITICAL" }).Count
            Warnings = ($Findings | Where-Object { $_.Severity -eq "WARNING" }).Count
            Info = ($Findings | Where-Object { $_.Severity -eq "INFO" }).Count
        }
    }
    
    foreach ($Tier in $Tiers.Keys) {
        $JSONOutput.Tiers[$Tier] = $Tiers[$Tier]
    }
    
    $JSONOutput | ConvertTo-Json -Depth 10 | Out-File $JSONReport -Force
    Write-Log "JSON report saved: $JSONReport" "SUCCESS"
    
    Write-Log "`nAll logs gathered to: $OutputDirectory" "SUCCESS"
}

#endregion

#region Main Execution
function Main {
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       MiracleBoot Log Gatherer & Analyzer v$ScriptVersion        ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Write-Log "Script started" "INFO"
    Write-Log "Output Directory: $OutputDirectory" "INFO"
    
    if ($OpenEventViewer) {
        Launch-EventViewer
    }
    
    if (-not $AnalyzeOnly) {
        # Gather phase
        Write-Log "`n*** GATHERING PHASE ***" "INFO"
        
        Gather-BootCriticalDumps
        Gather-BootPipelineLogs
        Gather-EventLogs
        Gather-BootStructure
        Gather-ImageContext
    }
    
    if (-not $GatherOnly) {
        # Analysis phase
        Write-Log "`n*** ANALYSIS PHASE ***" "INFO"
        $RootCauseAnalysis = Build-RootCauseAnalysis
        Write-Host $RootCauseAnalysis
        
        Export-AnalysisResults $RootCauseAnalysis
    }
    
    if ($LaunchCrashAnalyzer) {
        Launch-CrashAnalyzer
    }
    
    Write-Log "`nScript completed" "INFO"
    Write-Host "`n✓ Analysis complete. Check $OutputDirectory for results." -ForegroundColor Green
}

Main
