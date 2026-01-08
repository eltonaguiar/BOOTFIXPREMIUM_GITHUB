<#
.SYNOPSIS
    AutoLogAnalyzer Integration Wrapper for MiracleBoot
    
.DESCRIPTION
    Provides seamless integration of AutoLogAnalyzer with MiracleBoot workflow,
    enabling pre/post repair analysis and side-by-side comparison reports.
    
.USAGE
    .\AUTO_ANALYZE_LOGS.ps1
    .\AUTO_ANALYZE_LOGS.ps1 -Mode "PreRepair"
    .\AUTO_ANALYZE_LOGS.ps1 -Mode "PostRepair"
    .\AUTO_ANALYZE_LOGS.ps1 -Mode "CompareReports"
    
#>

param(
    [ValidateSet("Interactive", "PreRepair", "PostRepair", "CompareReports", "Quick")]
    [string]$Mode = "Interactive",
    [int]$HoursBack = 48
)

$ErrorActionPreference = "Continue"

# Ensure we're in the right directory
if (-not (Test-Path ".\AutoLogAnalyzer.ps1")) {
    Write-Host "Error: AutoLogAnalyzer.ps1 not found in current directory" -ForegroundColor Red
    Write-Host "Current location: $(Get-Location)" -ForegroundColor Yellow
    exit 1
}

# ============================================================================
# FUNCTION: Display Menu
# ============================================================================

function Show-MainMenu {
    Clear-Host
    Write-Host ""
    Write-Host "" -ForegroundColor Cyan
    Write-Host "     MiracleBoot - AutoLogAnalyzer Integration Menu            " -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "What would you like to do?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Quick Log Analysis (Current Issues)" -ForegroundColor Cyan
    Write-Host "        Analyzes last 48 hours" -ForegroundColor Gray
    Write-Host "        Shows top errors immediately" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2] Pre-Repair Analysis" -ForegroundColor Cyan
    Write-Host "        Baseline analysis before MiracleBoot repairs" -ForegroundColor Gray
    Write-Host "        Saves 'Before' snapshot" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3] Post-Repair Analysis" -ForegroundColor Cyan
    Write-Host "        Analysis after repairs" -ForegroundColor Gray
    Write-Host "        Compares with pre-repair baseline" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [4] Compare Before/After Reports" -ForegroundColor Cyan
    Write-Host "        Side-by-side error code comparison" -ForegroundColor Gray
    Write-Host "        Shows improvement metrics" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [5] Custom Analysis" -ForegroundColor Cyan
    Write-Host "        Specify custom time range" -ForegroundColor Gray
    Write-Host "        Choose output location" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [6] View Previous Reports" -ForegroundColor Cyan
    Write-Host "        Browse existing analysis reports" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [Q] Quit" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Enter selection (1-6 or Q): " -ForegroundColor Yellow -NoNewline
}

# ============================================================================
# FUNCTION: Run Analysis
# ============================================================================

function Invoke-LogAnalysis {
    param(
        [string]$Snapshot = "",
        [int]$Hours = 48
    )
    
    $args = @("-HoursBack", $Hours)
    
    if ($Snapshot -ne "") {
        $snapshotDir = ".\LOG_ANALYSIS\$Snapshot"
        $args += @("-OutputPath", $snapshotDir)
    }
    
    Write-Host "`nStarting analysis..." -ForegroundColor Green
    Write-Host "Time range: Last $Hours hours" -ForegroundColor Gray
    Write-Host ""
    
    & ".\AutoLogAnalyzer.ps1" @args
}

# ============================================================================
# FUNCTION: Quick Analysis Display
# ============================================================================

function Show-QuickAnalysis {
    Write-Host ""
    Write-Host "" -ForegroundColor Cyan
    Write-Host "                    QUICK LOG ANALYSIS                          " -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    
    Invoke-LogAnalysis -Hours 48
    
    Write-Host ""
    Write-Host "Quick analysis complete!" -ForegroundColor Green
    Read-Host "Press Enter to return to menu"
}

# ============================================================================
# FUNCTION: Pre-Repair Analysis
# ============================================================================

function Invoke-PreRepairAnalysis {
    Write-Host ""
    Write-Host "" -ForegroundColor Cyan
    Write-Host "                  PRE-REPAIR BASELINE ANALYSIS                  " -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    
    $timestamp = Get-Date -Format "PRE_REPAIR_yyyy-MM-dd_HHmmss"
    
    Write-Host ""
    Write-Host "Creating baseline snapshot: $timestamp" -ForegroundColor Yellow
    Write-Host "This will be compared against post-repair analysis." -ForegroundColor Gray
    Write-Host ""
    
    Invoke-LogAnalysis -Snapshot $timestamp -Hours 48
    
    Write-Host ""
    Write-Host "Baseline saved! Next steps:" -ForegroundColor Green
    Write-Host "1. Run MiracleBoot repairs (.\MiracleBoot.ps1)" -ForegroundColor Cyan
    Write-Host "2. After repairs, run POST-REPAIR ANALYSIS to compare" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to return to menu"
}

# ============================================================================
# FUNCTION: Post-Repair Analysis
# ============================================================================

function Invoke-PostRepairAnalysis {
    Write-Host ""
    Write-Host "" -ForegroundColor Cyan
    Write-Host "                   POST-REPAIR ANALYSIS                          " -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    
    $timestamp = Get-Date -Format "POST_REPAIR_yyyy-MM-dd_HHmmss"
    
    Write-Host ""
    Write-Host "Creating post-repair snapshot: $timestamp" -ForegroundColor Yellow
    Write-Host ""
    
    Invoke-LogAnalysis -Snapshot $timestamp -Hours 48
    
    Write-Host ""
    Write-Host "Post-repair analysis complete!" -ForegroundColor Green
    Write-Host "You can now compare with pre-repair baseline using option [4]" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to return to menu"
}

# ============================================================================
# FUNCTION: Compare Reports
# ============================================================================

function Invoke-CompareReports {
    Write-Host ""
    Write-Host "" -ForegroundColor Cyan
    Write-Host "               BEFORE/AFTER COMPARISON                          " -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    
    $logDir = ".\LOG_ANALYSIS"
    
    if (-not (Test-Path $logDir)) {
        Write-Host ""
        Write-Host "No analysis reports found. Run an analysis first!" -ForegroundColor Yellow
        Read-Host "Press Enter to return to menu"
        return
    }
    
    $preReports = Get-ChildItem -Path $logDir -Directory | Where-Object { $_.Name -match "PRE_REPAIR" } | Sort-Object -Property Name -Descending
    $postReports = Get-ChildItem -Path $logDir -Directory | Where-Object { $_.Name -match "POST_REPAIR" } | Sort-Object -Property Name -Descending
    
    if ($preReports.Count -eq 0 -or $postReports.Count -eq 0) {
        Write-Host ""
        Write-Host "You need both PRE-REPAIR and POST-REPAIR analyses to compare." -ForegroundColor Yellow
        Write-Host "Current reports:" -ForegroundColor Gray
        Write-Host "  Pre-Repair: $($preReports.Count)" -ForegroundColor Gray
        Write-Host "  Post-Repair: $($postReports.Count)" -ForegroundColor Gray
        Write-Host ""
        Read-Host "Press Enter to return to menu"
        return
    }
    
    $latestPre = $preReports[0]
    $latestPost = $postReports[0]
    
    Write-Host ""
    Write-Host "Selected Reports:" -ForegroundColor Cyan
    Write-Host "  Pre-Repair:  $($latestPre.Name)" -ForegroundColor Yellow
    Write-Host "  Post-Repair: $($latestPost.Name)" -ForegroundColor Yellow
    Write-Host ""
    
    # Load CSV data
    $preCsv = Join-Path $latestPre.FullName "ERROR_CODES.csv"
    $postCsv = Join-Path $latestPost.FullName "ERROR_CODES.csv"
    
    if ((Test-Path $preCsv) -and (Test-Path $postCsv)) {
        $preErrors = Import-Csv -Path $preCsv
        $postErrors = Import-Csv -Path $postCsv
        
        Write-Host "COMPARISON RESULTS:" -ForegroundColor Cyan
        Write-Host "" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Pre-Repair Summary:" -ForegroundColor Yellow
        Write-Host "  Unique Error Codes: $($preErrors.Count)" -ForegroundColor White
        Write-Host "  Total Occurrences: $($preErrors | Measure-Object -Property Count -Sum | Select-Object -ExpandProperty Sum)" -ForegroundColor White
        
        Write-Host ""
        Write-Host "Post-Repair Summary:" -ForegroundColor Yellow
        Write-Host "  Unique Error Codes: $($postErrors.Count)" -ForegroundColor White
        Write-Host "  Total Occurrences: $($postErrors | Measure-Object -Property Count -Sum | Select-Object -ExpandProperty Sum)" -ForegroundColor White
        
        $preCount = $preErrors.Count
        $postCount = $postErrors.Count
        $reduction = $preCount - $postCount
        $percentage = if ($preCount -gt 0) { [Math]::Round(($reduction / $preCount) * 100, 2) } else { 0 }
        
        Write-Host ""
        Write-Host "Improvement:" -ForegroundColor Yellow
        Write-Host "  Errors Reduced: $reduction unique codes (-$percentage%)" -ForegroundColor $(if ($reduction -gt 0) { "Green" } else { "Red" })
        
        # Find new errors
        $preErrorCodes = $preErrors | Select-Object -ExpandProperty ErrorCode
        $postErrorCodes = $postErrors | Select-Object -ExpandProperty ErrorCode
        
        $fixed = @($preErrorCodes | Where-Object { $_ -notin $postErrorCodes })
        $newIssues = @($postErrorCodes | Where-Object { $_ -notin $preErrorCodes })
        
        if ($fixed.Count -gt 0) {
            Write-Host ""
            Write-Host "Errors Fixed: $($fixed.Count)" -ForegroundColor Green
            $fixed | Select-Object -First 5 | ForEach-Object {
                Write-Host "   $_" -ForegroundColor Green
            }
            if ($fixed.Count -gt 5) {
                Write-Host "  ... and $($fixed.Count - 5) more" -ForegroundColor Gray
            }
        }
        
        if ($newIssues.Count -gt 0) {
            Write-Host ""
            Write-Host "New Issues: $($newIssues.Count)" -ForegroundColor Yellow
            $newIssues | Select-Object -First 5 | ForEach-Object {
                Write-Host "   $_" -ForegroundColor Yellow
            }
            if ($newIssues.Count -gt 5) {
                Write-Host "  ... and $($newIssues.Count - 5) more" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        Write-Host "" -ForegroundColor Gray
        Write-Host "Full reports available at:" -ForegroundColor Cyan
        Write-Host "  Pre-Report:  $($latestPre.FullName)" -ForegroundColor Gray
        Write-Host "  Post-Report: $($latestPost.FullName)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Read-Host "Press Enter to return to menu"
}

# ============================================================================
# FUNCTION: Custom Analysis
# ============================================================================

function Invoke-CustomAnalysis {
    Write-Host ""
    Write-Host "" -ForegroundColor Cyan
    Write-Host "                    CUSTOM ANALYSIS                             " -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "Time Range Options:" -ForegroundColor Yellow
    Write-Host "  [1] Last 24 hours" -ForegroundColor Cyan
    Write-Host "  [2] Last 7 days (168 hours)" -ForegroundColor Cyan
    Write-Host "  [3] Last 30 days (720 hours)" -ForegroundColor Cyan
    Write-Host "  [4] Custom hours" -ForegroundColor Cyan
    Write-Host ""
    $timeChoice = Read-Host "Select time range (1-4)"
    
    $hours = switch ($timeChoice) {
        "1" { 24 }
        "2" { 168 }
        "3" { 720 }
        "4" { [int](Read-Host "Enter number of hours") }
        default { 48 }
    }
    
    Write-Host ""
    Invoke-LogAnalysis -Hours $hours
    
    Write-Host ""
    Read-Host "Press Enter to return to menu"
}

# ============================================================================
# FUNCTION: View Previous Reports
# ============================================================================

function Show-PreviousReports {
    Write-Host ""
    Write-Host "" -ForegroundColor Cyan
    Write-Host "                   PREVIOUS REPORTS                             " -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    
    $logDir = ".\LOG_ANALYSIS"
    
    if (-not (Test-Path $logDir)) {
        Write-Host ""
        Write-Host "No reports found yet." -ForegroundColor Yellow
        Read-Host "Press Enter to return to menu"
        return
    }
    
    $reports = Get-ChildItem -Path $logDir -Directory | Sort-Object -Property Name -Descending
    
    if ($reports.Count -eq 0) {
        Write-Host ""
        Write-Host "No reports found yet." -ForegroundColor Yellow
        Read-Host "Press Enter to return to menu"
        return
    }
    
    Write-Host ""
    Write-Host "Available Reports:" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $reports.Count; $i++) {
        $report = $reports[$i]
        Write-Host "[$($i+1)] $($report.Name)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "[O] Open selected report in File Explorer" -ForegroundColor Cyan
    Write-Host "[Q] Back to menu" -ForegroundColor Cyan
    Write-Host ""
    $choice = Read-Host "Enter selection"
    
    if ($choice -eq "O" -or $choice -eq "o") {
        $selection = [int](Read-Host "Which report? (1-$($reports.Count))") - 1
        if ($selection -ge 0 -and $selection -lt $reports.Count) {
            Start-Process -FilePath explorer.exe -ArgumentList $reports[$selection].FullName
        }
    }
}

# ============================================================================
# MAIN INTERACTIVE LOOP
# ============================================================================

function Start-InteractiveMenu {
    while ($true) {
        Show-MainMenu
        $choice = Read-Host
        
        switch ($choice) {
            "1" { Show-QuickAnalysis }
            "2" { Invoke-PreRepairAnalysis }
            "3" { Invoke-PostRepairAnalysis }
            "4" { Invoke-CompareReports }
            "5" { Invoke-CustomAnalysis }
            "6" { Show-PreviousReports }
            "Q" { exit 0 }
            "q" { exit 0 }
            default {
                Write-Host ""
                Write-Host "Invalid selection. Press Enter to try again." -ForegroundColor Red
                Read-Host
            }
        }
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

switch ($Mode) {
    "Interactive" {
        Start-InteractiveMenu
    }
    "Quick" {
        Invoke-LogAnalysis -Hours 48
    }
    "PreRepair" {
        $timestamp = Get-Date -Format "PRE_REPAIR_yyyy-MM-dd_HHmmss"
        Invoke-LogAnalysis -Snapshot $timestamp -Hours 48
    }
    "PostRepair" {
        $timestamp = Get-Date -Format "POST_REPAIR_yyyy-MM-dd_HHmmss"
        Invoke-LogAnalysis -Snapshot $timestamp -Hours 48
    }
    "CompareReports" {
        Invoke-CompareReports
    }
    default {
        Start-InteractiveMenu
    }
}
