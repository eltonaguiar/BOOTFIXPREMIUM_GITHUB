<#
.SYNOPSIS
    Enhanced Event Log Analyzer for MiracleBoot Integration
    Bridges AutoLogAnalyzer_Enhanced with GUI/Batch interfaces
    
.DESCRIPTION
    Replaces simple Get-OfflineEventLogs with:
    - Real log collection from Event Viewer
    - Error database matching
    - Severity ranking
    - Suggested fixes
    - Three report types
#>

param(
    [string]$TargetDrive = "C",
    [switch]$ReturnRawData,
    [int]$HoursBack = 48
)

Add-Type -AssemblyName System.Windows.Forms
$ErrorActionPreference = "Continue"

# ============================================================================
# ERROR DATABASE (Inline - Same as AutoLogAnalyzer_Enhanced)
# ============================================================================

$ErrorDatabase = @{
    'EventID_1000' = @{
        Name = 'Application Error / Crash'
        Severity = 'CRITICAL'
        Description = 'An application terminated unexpectedly.'
        CommonCauses = @('Memory corruption', 'Driver incompatibility', 'Insufficient resources', 'Software bug')
        SuggestedFixes = @('Update application to latest version', 'Update video/chipset drivers', 'Run: sfc /scannow', 'Check available RAM and disk space', 'Run in compatibility mode')
        Severity_Level = 9
    }
    
    'EventID_7000' = @{
        Name = 'Service Failed to Start'
        Severity = 'ERROR'
        Description = 'Windows service failed to start during boot.'
        CommonCauses = @('Missing dependencies', 'Corrupted registry', 'Permission issues', 'File not found')
        SuggestedFixes = @('Check service in services.msc', 'Verify dependencies are running', 'Run: sfc /scannow', 'Reset service permissions', 'Check if port is already in use')
        Severity_Level = 8
    }
    
    'EventID_7034' = @{
        Name = 'Service Crashed'
        Severity = 'CRITICAL'
        Description = 'Service terminated unexpectedly during operation.'
        CommonCauses = @('Memory leak', 'Unhandled exception', 'Resource exhaustion', 'Incompatible update')
        SuggestedFixes = @('Restart service: net stop SERVICE && net start SERVICE', 'Check Application Event Log for details', 'Update service application', 'Run: sfc /scannow', 'Check available memory')
        Severity_Level = 9
    }
    
    'EventID_36871' = @{
        Name = 'SSL/TLS Certificate Error'
        Severity = 'CRITICAL'
        Description = 'Secure channel SSL/TLS certificate validation or handshake failed.'
        CommonCauses = @('System clock incorrect', 'Expired certificate', 'Untrusted root CA', 'SSL policy mismatch')
        SuggestedFixes = @('IMMEDIATE: Fix system date/time (Settings > Time & Language)', 'Run Windows Update', 'Clear SSL cache: certutil -setreg chain\ChainCacheResync 1', 'Update root certificates: certutil -generateSSTFromWU root.sst', 'Run: sfc /scannow')
        Severity_Level = 10
    }
    
    'EventID_10016' = @{
        Name = 'DCOM Permission Denied'
        Severity = 'WARNING'
        Description = 'DCOM object access denied - permission issue.'
        CommonCauses = @('Incorrect DCOM permissions', 'User not in required group', 'Registry corruption')
        SuggestedFixes = @('Run: dcomcnfg', 'Check Component Services permissions', 'Verify user has Execute/Launch permissions', 'Add user to necessary groups', 'Restart service')
        Severity_Level = 5
    }
    
    'EventID_219' = @{
        Name = 'Kernel Plug and Play Event'
        Severity = 'WARNING'
        Description = 'Device driver or hardware issue detected.'
        CommonCauses = @('Unsigned driver', 'Driver incompatibility', 'Hardware malfunction', 'USB device issue')
        SuggestedFixes = @('Update device drivers: devmgmt.msc', 'Check Device Manager for yellow marks', 'Check manufacturer for updated drivers', 'Try different USB port', 'Reinstall device')
        Severity_Level = 5
    }
    
    '0x80004005' = @{
        Name = 'E_FAIL - General Failure'
        Severity = 'ERROR'
        Description = 'Unspecified COM/API failure.'
        CommonCauses = @('Resource exhausted', 'Permission denied', 'Unknown COM error', 'System resource issue')
        SuggestedFixes = @('Check system resources (RAM, disk)', 'Run as Administrator', 'Restart application', 'Update application/drivers', 'Check Event Log for details')
        Severity_Level = 6
    }
    
    '0x80070005' = @{
        Name = 'E_ACCESSDENIED - Access Denied'
        Severity = 'ERROR'
        Description = 'Access denied due to insufficient permissions.'
        CommonCauses = @('Insufficient privileges', 'File permissions', 'Registry permissions', 'UAC restriction')
        SuggestedFixes = @('Run as Administrator', 'Check file permissions: Right-click > Properties > Security', 'Grant necessary permissions', 'Add user to appropriate groups', 'Check registry permissions')
        Severity_Level = 6
    }
}

# ============================================================================
# COLLECT AND ANALYZE LOGS
# ============================================================================

function Get-EnhancedEventLogAnalysis {
    param(
        [int]$HoursBack = 48
    )
    
    $cutoffTime = (Get-Date).AddHours(-$HoursBack)
    $allLogs = @()
    
    try {
        foreach ($log in @("System", "Application")) {
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
            }
        }
    } catch {
        Write-Verbose "Error collecting logs: $_"
    }
    
    # Extract and match errors
    $enrichedErrors = @()
    
    foreach ($event in $allLogs) {
        if ($event.Type -in @("Error", "Warning")) {
            $errorCode = "EventID_$($event.EventID)"
            
            if ($ErrorDatabase.ContainsKey($errorCode)) {
                $dbEntry = $ErrorDatabase[$errorCode]
                
                $enrichedErrors += [PSCustomObject]@{
                    ErrorCode = $errorCode
                    Name = $dbEntry.Name
                    Count = 1
                    Severity = $dbEntry.Severity
                    Severity_Level = $dbEntry.Severity_Level
                    Description = $dbEntry.Description
                    CommonCauses = $dbEntry.CommonCauses
                    SuggestedFixes = $dbEntry.SuggestedFixes
                    Source = $event.Source_Name
                    Context = $event.Message.Substring(0, [Math]::Min(150, $event.Message.Length))
                }
            }
            
            # Check for HRESULT codes
            if ($event.Message -match '0x[0-9A-Fa-f]{8}') {
                $hresult = $matches[0]
                if ($ErrorDatabase.ContainsKey($hresult)) {
                    $dbEntry = $ErrorDatabase[$hresult]
                    $enrichedErrors += [PSCustomObject]@{
                        ErrorCode = $hresult
                        Name = $dbEntry.Name
                        Count = 1
                        Severity = $dbEntry.Severity
                        Severity_Level = $dbEntry.Severity_Level
                        Description = $dbEntry.Description
                        CommonCauses = $dbEntry.CommonCauses
                        SuggestedFixes = $dbEntry.SuggestedFixes
                        Source = $event.Source_Name
                        Context = $event.Message.Substring(0, [Math]::Min(150, $event.Message.Length))
                    }
                }
            }
        }
    }
    
    # Group by error code
    $grouped = $enrichedErrors | Group-Object -Property ErrorCode | ForEach-Object {
        $first = $_.Group[0]
        [PSCustomObject]@{
            ErrorCode = $_.Name
            Name = $first.Name
            Count = $_.Count
            Severity = $first.Severity
            Severity_Level = $first.Severity_Level
            Description = $first.Description
            CommonCauses = $first.CommonCauses
            SuggestedFixes = $first.SuggestedFixes
            Sources = ($_.Group.Source | Select-Object -Unique) -join ", "
        }
    } | Sort-Object -Property Severity_Level -Descending
    
    return @{
        Success = $true
        Errors = $grouped
        TotalCount = $enrichedErrors.Count
        UniqueCount = $grouped.Count
        CriticalCount = ($grouped | Where-Object { $_.Severity_Level -ge 9 }).Count
        WarningCount = ($grouped | Where-Object { $_.Severity_Level -lt 9 -and $_.Severity_Level -ge 5 }).Count
    }
}

# ============================================================================
# FORMAT FOR GUI DISPLAY
# ============================================================================

function Format-ForGUI {
    param($Analysis)
    
    $output = @()
    $output += "=========================================================="
    $output += "ENHANCED EVENT LOG ANALYSIS WITH FIXES"
    $output += "=========================================================="
    $output += ""
    $output += "Scan Period: Last 48 hours"
    $output += "Total Errors: $($Analysis.TotalCount) occurrences"
    $output += "Unique Codes: $($Analysis.UniqueCount)"
    $output += "Critical Issues: $($Analysis.CriticalCount)"
    $output += ""
    
    if ($Analysis.CriticalCount -gt 0) {
        $output += "=========================================================="
        $output += "CRITICAL ISSUES (Fix IMMEDIATELY):"
        $output += "=========================================================="
        $output += ""
        
        foreach ($error in $Analysis.Errors | Where-Object { $_.Severity_Level -ge 9 }) {
            $output += "[!!! CRITICAL !!!] $($error.ErrorCode) - $($error.Name)"
            $output += "  Count: $($error.Count) occurrences"
            $output += "  Severity: $($error.Severity_Level)/10"
            $output += "  Why: $($error.Description)"
            $output += ""
            $output += "  COMMON CAUSES:"
            foreach ($cause in $error.CommonCauses) {
                $output += "    * $cause"
            }
            $output += ""
            $output += "  SUGGESTED FIXES (In Order):"
            $num = 1
            foreach ($fix in $error.SuggestedFixes) {
                $output += "    $num. $fix"
                $num++
            }
            $output += ""
        }
    }
    
    if ($Analysis.WarningCount -gt 0) {
        $output += "=========================================================="
        $output += "WARNINGS & OTHER ISSUES:"
        $output += "=========================================================="
        $output += ""
        
        foreach ($error in $Analysis.Errors | Where-Object { $_.Severity_Level -lt 9 -and $_.Severity_Level -ge 5 }) {
            $output += "[Warning] $($error.ErrorCode) - $($error.Name)"
            $output += "    Occurrences: $($error.Count)"
            $output += "    Description: $($error.Description)"
            $output += ""
        }
    }
    
    if ($Analysis.UniqueCount -eq 0) {
        $output += "OK - No critical errors found in event logs (last 48 hours)"
    }
    
    $output += ""
    $output += "=========================================================="
    $output += "NEXT STEPS:"
    $output += "  1. Read error descriptions above"
    $output += "  2. Follow suggested fixes in order"
    $output += "  3. Restart system after applying fixes"
    $output += "  4. Run analysis again to verify improvement"
    
    return $output -join "`r`n"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    $analysis = Get-EnhancedEventLogAnalysis -HoursBack $HoursBack
    
    if ($ReturnRawData) {
        return $analysis
    }
    
    # Return formatted output for GUI
    [PSCustomObject]@{
        Success = $true
        Summary = Format-ForGUI $analysis
        ErrorCount = $analysis.UniqueCount
        CriticalCount = $analysis.CriticalCount
        Errors = $analysis.Errors
    }
}
catch {
    [PSCustomObject]@{
        Success = $false
        Summary = "ERROR: Failed to analyze event logs`n`n$($_.Exception.Message)`n`nPlease try again or check Event Viewer manually (eventvwr.msc)"
        ErrorCount = 0
        CriticalCount = 0
        Errors = @()
    }
}
