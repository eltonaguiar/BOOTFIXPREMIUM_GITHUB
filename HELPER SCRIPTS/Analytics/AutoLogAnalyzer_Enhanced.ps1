<#
.SYNOPSIS
    AutoLogAnalyzer Enhanced - With Error Code Database & Suggested Fixes
    
.DESCRIPTION
    Analyzes system logs and matches errors against built-in database to provide
    explanations, likely causes, and suggested fixes without external lookups.
    
.USAGE
    .\AutoLogAnalyzer_Enhanced.ps1
    .\AutoLogAnalyzer_Enhanced.ps1 -HoursBack 24
    .\AutoLogAnalyzer_Enhanced.ps1 -GenerateDetailedReport
    
#>

param(
    [int]$HoursBack = 48,
    [string]$OutputPath = "$PSScriptRoot\LOG_ANALYSIS_ENHANCED",
    [switch]$GenerateDetailedReport
)

$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"

# ============================================================================
# LOAD ERROR CODE DATABASE
# ============================================================================

Write-Host "Loading error code database..." -ForegroundColor Cyan

# Build database inline to avoid file dependency
$ErrorDatabase = @{
    'EventID_1000' = @{
        Name = 'Application Error / Crash'
        Severity = 'CRITICAL'
        Category = 'Application'
        Description = 'An application terminated unexpectedly.'
        CommonCauses = @('Memory corruption', 'Driver incompatibility', 'Insufficient resources', 'Software bug')
        SuggestedFixes = @(
            'Update application to latest version',
            'Update video/chipset drivers',
            'Run: sfc /scannow (check system files)',
            'Check available RAM and disk space',
            'Run in compatibility mode'
        )
        Severity_Level = 9
    }
    
    'EventID_7000' = @{
        Name = 'Service Failed to Start'
        Severity = 'ERROR'
        Category = 'Services'
        Description = 'Windows service failed to start during boot.'
        CommonCauses = @('Missing dependencies', 'Corrupted registry', 'Permission issues', 'File not found')
        SuggestedFixes = @(
            'Check service in services.msc',
            'Verify dependencies are running',
            'Run: sfc /scannow',
            'Reset service permissions',
            'Check if port is already in use'
        )
        Severity_Level = 8
    }
    
    'EventID_7009' = @{
        Name = 'Service Timeout'
        Severity = 'ERROR'
        Category = 'Services'
        Description = 'Service took too long to start and was terminated.'
        CommonCauses = @('System overloaded', 'Service performing heavy operation', 'Dependency delay')
        SuggestedFixes = @(
            'Increase startup timeout',
            'Check system performance (high CPU/disk)',
            'Review startup dependencies',
            'Restart service manually',
            'Check if startup disk is slow'
        )
        Severity_Level = 7
    }
    
    'EventID_7034' = @{
        Name = 'Service Crashed'
        Severity = 'CRITICAL'
        Category = 'Services'
        Description = 'Service terminated unexpectedly during operation.'
        CommonCauses = @('Memory leak', 'Unhandled exception', 'Resource exhaustion', 'Incompatible update')
        SuggestedFixes = @(
            'Restart service: net stop SERVICE && net start SERVICE',
            'Check Application Event Log for details',
            'Update service application',
            'Run: sfc /scannow',
            'Check available memory: Task Manager'
        )
        Severity_Level = 9
    }
    
    'EventID_10016' = @{
        Name = 'DCOM Permission Denied'
        Severity = 'WARNING'
        Category = 'COM'
        Description = 'DCOM object access denied - permission issue.'
        CommonCauses = @('Incorrect DCOM permissions', 'User not in required group', 'Registry corruption')
        SuggestedFixes = @(
            'Run: dcomcnfg',
            'Check Component Services permissions',
            'Verify user has Execute/Launch permissions',
            'Add user to necessary groups',
            'Restart service'
        )
        Severity_Level = 5
    }
    
    'EventID_36871' = @{
        Name = 'SSL/TLS Certificate Error'
        Severity = 'CRITICAL'
        Category = 'Security'
        Description = 'Secure channel SSL/TLS certificate validation or handshake failed.'
        CommonCauses = @('System clock incorrect', 'Expired certificate', 'Untrusted root CA', 'SSL policy mismatch')
        SuggestedFixes = @(
            '1. IMMEDIATE: Fix system date/time (Settings > Time & Language)',
            '2. Run Windows Update',
            '3. Clear SSL cache: certutil -setreg chain\\ChainCacheResync 1',
            '4. Update root certificates: certutil -generateSSTFromWU root.sst',
            '5. Run: sfc /scannow',
            '6. Disable antivirus SSL inspection temporarily'
        )
        Severity_Level = 10
    }
    
    'EventID_219' = @{
        Name = 'Kernel Plug and Play Event'
        Severity = 'WARNING'
        Category = 'Devices'
        Description = 'Device driver or hardware issue detected.'
        CommonCauses = @('Unsigned driver', 'Driver incompatibility', 'Hardware malfunction', 'USB device issue')
        SuggestedFixes = @(
            'Update device drivers: devmgmt.msc',
            'Check Device Manager for yellow exclamation marks',
            'Check manufacturer for updated drivers',
            'Try different USB port',
            'Reinstall device'
        )
        Severity_Level = 5
    }
    
    'EventID_4096' = @{
        Name = 'VBScript Deprecation'
        Severity = 'WARNING'
        Category = 'Scripting'
        Description = 'VBScript is deprecated and may be disabled.'
        CommonCauses = @('Running legacy VBScript', 'Scheduled task uses VBScript', 'Old administrative script')
        SuggestedFixes = @(
            'Identify scripts using VBScript',
            'Plan migration to PowerShell',
            'Update scripts to use modern language',
            'Test migration thoroughly'
        )
        Severity_Level = 3
    }
    
    '0x80004005' = @{
        Name = 'E_FAIL - General Failure'
        Severity = 'ERROR'
        Category = 'API'
        Description = 'Unspecified COM/API failure - generic error.'
        CommonCauses = @('Resource exhausted', 'Permission denied', 'Unknown COM error', 'System resource issue')
        SuggestedFixes = @(
            'Check system resources (RAM, disk)',
            'Run as Administrator',
            'Restart application',
            'Update application/drivers',
            'Check Event Log for details'
        )
        Severity_Level = 6
    }
    
    '0x80070005' = @{
        Name = 'E_ACCESSDENIED - Access Denied'
        Severity = 'ERROR'
        Category = 'API'
        Description = 'Access denied due to insufficient permissions.'
        CommonCauses = @('Insufficient privileges', 'File permissions', 'Registry permissions', 'UAC restriction')
        SuggestedFixes = @(
            'Run as Administrator',
            'Check file permissions: Right-click > Properties > Security',
            'Grant necessary permissions',
            'Add user to appropriate groups',
            'Check registry permissions'
        )
        Severity_Level = 6
    }
    
    '0x80070002' = @{
        Name = 'E_FILENOTFOUND - File Not Found'
        Severity = 'ERROR'
        Category = 'FileSystem'
        Description = 'Required file or resource not found.'
        CommonCauses = @('File deleted', 'Wrong path', 'Incomplete installation', 'Missing dependency')
        SuggestedFixes = @(
            'Verify file exists',
            'Check file path spelling',
            'Reinstall application',
            'Run: sfc /scannow',
            'Restore from backup'
        )
        Severity_Level = 7
    }
    
    'STATUS_ACCESS_DENIED' = @{
        Name = 'Kernel Access Denied'
        Severity = 'ERROR'
        Category = 'Kernel'
        Description = 'Kernel-level access denied - insufficient permissions.'
        CommonCauses = @('Insufficient privileges', 'File/registry permissions', 'Security policy', 'Account restrictions')
        SuggestedFixes = @(
            'Run as Administrator',
            'Check file/folder permissions',
            'Add user to security groups',
            'Review security policies'
        )
        Severity_Level = 7
    }
    
    'STATUS_INSUFFICIENT_RESOURCES' = @{
        Name = 'Insufficient Resources'
        Severity = 'WARNING'
        Category = 'Resources'
        Description = 'Not enough system resources (memory, handles, etc.).'
        CommonCauses = @('Memory exhausted', 'Too many open handles', 'Resource leak', 'System overload')
        SuggestedFixes = @(
            'Check RAM: Task Manager > Performance',
            'Close unnecessary applications',
            'Increase virtual memory',
            'Check for memory leaks',
            'Restart system',
            'Add more RAM if needed'
        )
        Severity_Level = 7
    }
}

Write-Host "Database loaded: $($ErrorDatabase.Count) error codes indexed" -ForegroundColor Green

# ============================================================================
# SETUP OUTPUT DIRECTORY
# ============================================================================

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$reportPath = Join-Path $OutputPath "Analysis_$timestamp"
New-Item -ItemType Directory -Path $reportPath -Force | Out-Null

Write-Host "`n==== AutoLogAnalyzer Enhanced ====" -ForegroundColor Cyan
Write-Host "Analysis Period: Last $HoursBack hours" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# COLLECT LOGS
# ============================================================================

Write-Host "[1/4] Collecting Event Viewer Logs..." -ForegroundColor Green

$allLogs = @()
$cutoffTime = (Get-Date).AddHours(-$HoursBack)

foreach ($log in @("System", "Application")) {
    try {
        $events = Get-EventLog -LogName $log -After $cutoffTime -ErrorAction SilentlyContinue | Select-Object -First 1000
        
        if ($events) {
            $allLogs += $events | ForEach-Object {
                [PSCustomObject]@{
                    Source = $log
                    EventID = $_.EventID
                    Type = $_.EntryType
                    TimeGenerated = $_.TimeGenerated
                    Source_Name = $_.Source
                    Message = $_.Message
                }
            }
            Write-Host "  Collected $($events.Count) from $log" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Skipped $log : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ============================================================================
# EXTRACT AND MATCH ERRORS
# ============================================================================

Write-Host "`n[2/4] Extracting and Matching Errors..." -ForegroundColor Green

$enrichedErrors = @()

foreach ($event in $allLogs) {
    if ($event.Type -in @("Error", "Warning")) {
        $errorCode = "EventID_$($event.EventID)"
        
        # Look up in database
        if ($ErrorDatabase.ContainsKey($errorCode)) {
            $dbEntry = $ErrorDatabase[$errorCode]
            
            $enrichedErrors += [PSCustomObject]@{
                ErrorCode = $errorCode
                Name = $dbEntry.Name
                Count = 1
                Type = "Event Viewer"
                Severity = $dbEntry.Severity
                Severity_Level = $dbEntry.Severity_Level
                Category = $dbEntry.Category
                Description = $dbEntry.Description
                CommonCauses = $dbEntry.CommonCauses
                SuggestedFixes = $dbEntry.SuggestedFixes
                Source = $event.Source_Name
                LogFile = $event.Source
                Context = $event.Message.Substring(0, [Math]::Min(150, $event.Message.Length))
            }
        }
        
        # Also check for HRESULT patterns
        if ($event.Message -match '0x[0-9A-Fa-f]{8}') {
            $hresult = $matches[0]
            if ($ErrorDatabase.ContainsKey($hresult)) {
                $dbEntry = $ErrorDatabase[$hresult]
                $enrichedErrors += [PSCustomObject]@{
                    ErrorCode = $hresult
                    Name = $dbEntry.Name
                    Count = 1
                    Type = "HRESULT"
                    Severity = $dbEntry.Severity
                    Severity_Level = $dbEntry.Severity_Level
                    Category = $dbEntry.Category
                    Description = $dbEntry.Description
                    CommonCauses = $dbEntry.CommonCauses
                    SuggestedFixes = $dbEntry.SuggestedFixes
                    Source = $event.Source_Name
                    LogFile = $event.Source
                    Context = $event.Message.Substring(0, [Math]::Min(150, $event.Message.Length))
                }
            }
        }
    }
}

$grouped = $enrichedErrors | Group-Object -Property ErrorCode | ForEach-Object {
    $first = $_.Group[0]
    [PSCustomObject]@{
        ErrorCode = $_.Name
        Name = $first.Name
        Count = $_.Count
        Type = $first.Type
        Severity = $first.Severity
        Severity_Level = $first.Severity_Level
        Category = $first.Category
        Description = $first.Description
        CommonCauses = $first.CommonCauses
        SuggestedFixes = $first.SuggestedFixes
        Sources = ($_.Group.Source | Select-Object -Unique) -join ", "
    }
} | Sort-Object -Property Severity_Level -Descending

Write-Host "  Found $($grouped.Count) unique error codes with database matches" -ForegroundColor Green

# ============================================================================
# GENERATE REPORTS
# ============================================================================

Write-Host "`n[3/4] Generating Reports..." -ForegroundColor Green

# Report 1: Enriched Summary
$summaryReport = @()
$summaryReport += "==== SYSTEM LOG ANALYSIS WITH ERROR DATABASE ===="
$summaryReport += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$summaryReport += "Analysis Period: Last $HoursBack hours"
$summaryReport += ""
$summaryReport += "CRITICAL ISSUES (Priority First)"
$summaryReport += "=" * 60
$summaryReport += ""

$critical = $grouped | Where-Object { $_.Severity_Level -ge 9 }
if ($critical.Count -gt 0) {
    foreach ($err in $critical) {
        $summaryReport += ""
        $summaryReport += "ERROR: $($err.ErrorCode) - $($err.Name)"
        $summaryReport += "  Occurrences: $($err.Count)"
        $summaryReport += "  Severity: $($err.Severity)"
        $summaryReport += "  Description: $($err.Description)"
        $summaryReport += "  Affected: $($err.Sources)"
        $summaryReport += ""
        $summaryReport += "  Common Causes:"
        foreach ($cause in $err.CommonCauses) {
            $summaryReport += "    • $cause"
        }
        $summaryReport += ""
        $summaryReport += "  Suggested Fixes (In Order):"
        $fixNum = 1
        foreach ($fix in $err.SuggestedFixes) {
            $summaryReport += "    $fixNum. $fix"
            $fixNum++
        }
        $summaryReport += ""
    }
} else {
    $summaryReport += "No critical issues found."
    $summaryReport += ""
}

$summaryReport += ""
$summaryReport += "WARNING ISSUES"
$summaryReport += "=" * 60
$summaryReport += ""

$warnings = $grouped | Where-Object { $_.Severity -eq "WARNING" }
if ($warnings.Count -gt 0) {
    foreach ($err in $warnings) {
        $summaryReport += ""
        $summaryReport += "WARNING: $($err.ErrorCode) - $($err.Name)"
        $summaryReport += "  Occurrences: $($err.Count)"
        $summaryReport += "  Description: $($err.Description)"
        $summaryReport += "  Suggested Fixes:"
        foreach ($fix in $err.SuggestedFixes) {
            $summaryReport += "    • $fix"
        }
        $summaryReport += ""
    }
} else {
    $summaryReport += "No warnings."
    $summaryReport += ""
}

$reportFile = Join-Path $reportPath "ANALYSIS_WITH_FIXES.txt"
Set-Content -Path $reportFile -Value ($summaryReport -join "`r`n")
Write-Host "  Generated: ANALYSIS_WITH_FIXES.txt" -ForegroundColor Gray

# Report 2: ChatGPT Prompt (Enhanced)
$chatPrompt = @()
$chatPrompt += "=== SYSTEM ERROR ANALYSIS REPORT WITH SUGGESTED FIXES ==="
$chatPrompt += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$chatPrompt += ""
$chatPrompt += "CRITICAL ERRORS FOUND:"
$chatPrompt += ""

foreach ($err in $critical) {
    $chatPrompt += "Error: $($err.ErrorCode) - $($err.Name)"
    $chatPrompt += "  Occurrences: $($err.Count)"
    $chatPrompt += "  Severity: CRITICAL"
    $chatPrompt += "  Why it matters: $($err.Description)"
    $chatPrompt += ""
    $chatPrompt += "  Likely causes:"
    foreach ($cause in $err.CommonCauses) {
        $chatPrompt += "    - $cause"
    }
    $chatPrompt += ""
    $chatPrompt += "  Recommended steps:"
    $stepNum = 1
    foreach ($fix in $err.SuggestedFixes) {
        $chatPrompt += "    $stepNum. $fix"
        $stepNum++
    }
    $chatPrompt += ""
}

$chatFile = Join-Path $reportPath "FIXES_FOR_CHATGPT.txt"
Set-Content -Path $chatFile -Value ($chatPrompt -join "`r`n")
Write-Host "  Generated: FIXES_FOR_CHATGPT.txt" -ForegroundColor Gray

# Report 3: CSV with Enriched Data
$csvData = $grouped | Select-Object ErrorCode, Name, Count, Type, Severity, Category, Description, Sources
$csvFile = Join-Path $reportPath "ERROR_ANALYSIS.csv"
$csvData | Export-Csv -Path $csvFile -NoTypeInformation
Write-Host "  Generated: ERROR_ANALYSIS.csv" -ForegroundColor Gray

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================

Write-Host "`n[4/4] Summary" -ForegroundColor Green
Write-Host ""
Write-Host "Total Errors Found: $($grouped.Count)" -ForegroundColor Yellow
Write-Host "Critical Issues: $($critical.Count)" -ForegroundColor Red
Write-Host "Warnings: $($warnings.Count)" -ForegroundColor Yellow

if ($critical.Count -gt 0) {
    Write-Host ""
    Write-Host "TOP CRITICAL ISSUES:" -ForegroundColor Red
    foreach ($err in $critical | Select-Object -First 5) {
        Write-Host "  [$($err.Severity_Level)/10] $($err.ErrorCode) - $($err.Name) ($($err.Count)x)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Report Location: $reportPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Key Files Generated:" -ForegroundColor Cyan
Write-Host "  1. ANALYSIS_WITH_FIXES.txt - Detailed analysis with all fixes" -ForegroundColor Gray
Write-Host "  2. FIXES_FOR_CHATGPT.txt - Share with AI for discussion" -ForegroundColor Gray
Write-Host "  3. ERROR_ANALYSIS.csv - Data for Excel" -ForegroundColor Gray
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review ANALYSIS_WITH_FIXES.txt" -ForegroundColor Gray
Write-Host "  2. Implement suggested fixes in order of priority" -ForegroundColor Gray
Write-Host "  3. For complex issues, share FIXES_FOR_CHATGPT.txt with ChatGPT" -ForegroundColor Gray
Write-Host "  4. Re-run analyzer after fixes to validate improvements" -ForegroundColor Gray
Write-Host ""

Write-Host "Opening reports..." -ForegroundColor Gray
Start-Process -FilePath explorer.exe -ArgumentList $reportPath
