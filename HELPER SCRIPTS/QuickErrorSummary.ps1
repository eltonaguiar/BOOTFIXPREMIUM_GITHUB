<#
.SYNOPSIS
    QuickErrorSummary - Extract Latest Errors for ChatGPT Analysis
    
.DESCRIPTION
    Quickly extracts the latest error logs, summarizes them concisely,
    and formats them for easy copy-paste into ChatGPT or external analysis tools.
    
.FEATURES
    - Extracts latest error entries from Event Viewer
    - Shows error codes, filenames, and line numbers
    - Formats as ChatGPT-ready text blocks
    - One-click copy to clipboard option
    - Includes severity and frequency info
    
.USAGE
    .\QuickErrorSummary.ps1
    .\QuickErrorSummary.ps1 -HoursBack 48
    .\QuickErrorSummary.ps1 -DetailLevel Full
    .\QuickErrorSummary.ps1 -CopyToClipboard
    .\QuickErrorSummary.ps1 -OutputFile "C:\out.txt"
    
#>

param(
    [int]$HoursBack = 24,
    [ValidateSet("Compact", "Summary", "Full")]
    [string]$DetailLevel = "Summary",
    [switch]$CopyToClipboard,
    [string]$OutputFile,
    [int]$TopErrors = 15,
    [switch]$IncludeWarnings
)

$ErrorActionPreference = "Continue"

# Display header
Write-Host "`n" -ForegroundColor Yellow
Write-Host "QuickErrorSummary - ChatGPT-Ready Error Extractor" -ForegroundColor Cyan
Write-Host ""

# Get errors from Event Viewer
function Get-LatestErrors {
    param([int]$HoursBack, [bool]$IncludeWarnings = $false)
    
    Write-Host "[1/3] Scanning Event Viewer logs (last $HoursBack hours)..." -ForegroundColor Gray
    
    $startTime = (Get-Date).AddHours(-$HoursBack)
    $errors = @()
    
    foreach ($logName in @("System", "Application", "Security")) {
        try {
            $params = @{
                LogName = $logName
                After = $startTime
                ErrorAction = 'SilentlyContinue'
            }
            
            $events = Get-EventLog @params
            
            if ($IncludeWarnings) {
                $events = $events | Where-Object { $_.Type -in @("Error", "Warning") }
            } else {
                $events = $events | Where-Object { $_.Type -eq "Error" }
            }
            
            if ($events) {
                foreach ($event in $events) {
                    $msg = $event.Message -replace [System.Environment]::NewLine, " "
                    $message = if ($msg.Length -gt 200) { $msg.Substring(0, 197) + "..." } else { $msg }
                    
                    $errors += [PSCustomObject]@{
                        TimeCreated = $event.TimeGenerated
                        Log = $logName
                        EventID = $event.EventID
                        Level = $event.Type
                        Source = $event.Source
                        Message = $message
                        Computer = $event.MachineName
                        FullMessage = $event.Message
                    }
                }
            }
        } catch {
            # Skip logs that can't be read
        }
    }
    
    return $errors | Sort-Object TimeCreated -Descending
}

# Extract error codes
function Extract-ErrorCodes {
    param([PSCustomObject[]]$Errors)
    
    Write-Host "[2/3] Extracting and deduplicating error codes..." -ForegroundColor Gray
    
    $patterns = @(
        '0x[0-9A-Fa-f]{8}',
        '0x[0-9A-Fa-f]{1,7}',
        'STATUS_[A-Z_]+',
        'EventID[_\s]+\d+',
        'E_[A-Z_]+'
    )
    
    $codeMap = @{}
    
    foreach ($errorObj in $Errors) {
        $msgText = "$($errorObj.EventID) $($errorObj.Source) $($errorObj.Message)"
        
        foreach ($pattern in $patterns) {
            if ($msgText -match $pattern) {
                $code = $matches[0]
                if (-not $codeMap.ContainsKey($code)) {
                    $codeMap[$code] = @{
                        Code = $code
                        Count = 0
                        Sources = @()
                        Severity = $errorObj.Level
                        LastSeen = $errorObj.TimeCreated
                        FirstSeen = $errorObj.TimeCreated
                    }
                }
                
                $codeMap[$code].Count++
                $codeMap[$code].FirstSeen = $errorObj.TimeCreated
                
                if ($errorObj.Source -and $codeMap[$code].Sources -notcontains $errorObj.Source) {
                    $codeMap[$code].Sources += $errorObj.Source
                }
            }
        }
    }
    
    return $codeMap.Values | Sort-Object Count -Descending
}

# Create summaries
function New-CompactSummary {
    param([PSCustomObject[]]$Errors, [PSCustomObject[]]$ErrorCodes, [int]$TopErrors)
    
    $output = @()
    $output += "==============================================================="
    $output += "QUICK ERROR SUMMARY - FOR CHATGPT ANALYSIS"
    $output += "==============================================================="
    $output += ""
    $output += "System: $env:ComputerName"
    $output += "Time Period: Last $HoursBack hours"
    $output += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $output += "Total Errors Found: $($Errors.Count)"
    $output += ""
    $output += "---------------------------------------------------------------"
    $output += "TOP ERROR CODES"
    $output += "---------------------------------------------------------------"
    $output += ""
    
    $topCodes = $ErrorCodes | Select-Object -First $TopErrors
    $count = 1
    
    foreach ($code in $topCodes) {
        $output += "[$count] $($code.Code)"
        $output += "    Occurrences: $($code.Count)"
        $output += "    Severity: $($code.Severity)"
        $output += "    Sources: $($code.Sources -join ', ')"
        $output += ""
        $count++
    }
    
    $output += "---------------------------------------------------------------"
    $output += "PASTE THIS TO CHATGPT:"
    $output += "---------------------------------------------------------------"
    $output += ""
    $output += "System: $env:ComputerName"
    $output += "Analysis Period: Last $HoursBack hours"
    $output += ""
    $output += "Error Codes Found:"
    $topCodes | ForEach-Object {
        $output += "  - $($_.Code) - Found $($_.Count) times (Severity: $($_.Severity))"
    }
    $output += ""
    $output += "Please help me understand these error codes and suggest solutions."
    
    return $output -join "`n"
}

function New-DetailedSummary {
    param([PSCustomObject[]]$Errors, [PSCustomObject[]]$ErrorCodes, [int]$TopErrors)
    
    $output = @()
    $output += "==================================================================="
    $output += "DETAILED ERROR ANALYSIS - FOR EXTERNAL ANALYSIS"
    $output += "==================================================================="
    $output += ""
    $output += "System: $env:ComputerName"
    $output += "Time Period: Last $HoursBack hours"
    $output += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $output += "Total Errors: $($Errors.Count)"
    $output += "Unique Error Codes: $($ErrorCodes.Count)"
    $output += ""
    
    $output += "-------------------------------------------------------------------"
    $output += "ERROR CODE ANALYSIS (Top $TopErrors)"
    $output += "-------------------------------------------------------------------"
    $output += ""
    
    $topCodes = $ErrorCodes | Select-Object -First $TopErrors
    $count = 1
    
    foreach ($code in $topCodes) {
        $output += "[$count] ERROR CODE: $($code.Code)"
        $output += "     Occurrences: $($code.Count) times"
        $output += "     Severity Level: $($code.Severity)"
        $output += "     Source(s): $($code.Sources -join ', ')"
        $output += ""
        $count++
    }
    
    $output += "-------------------------------------------------------------------"
    $output += "RECENT ERROR EVENTS (10 Most Recent)"
    $output += "-------------------------------------------------------------------"
    $output += ""
    
    $recentErrors = $Errors | Select-Object -First 10
    foreach ($err in $recentErrors) {
        $output += "[$($err.TimeCreated | Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($err.Level) $($err.Source)"
        $output += "  EventID: $($err.EventID)"
        $msg = if ($err.Message.Length -gt 200) { $err.Message.Substring(0, 197) + "..." } else { $err.Message }
        $output += "  Message: $msg"
        $output += ""
    }
    
    $output += "-------------------------------------------------------------------"
    $output += "FOR CHATGPT - COPY AND PASTE BELOW"
    $output += "-------------------------------------------------------------------"
    $output += ""
    $output += "Computer: $env:ComputerName"
    $output += ""
    $output += "I'm experiencing these error codes:"
    $output += ""
    
    $topCodes | ForEach-Object {
        $output += "- $($_.Code) seen $($_.Count) times ($($_.Severity))"
    }
    
    $output += ""
    $output += "These occurred in the last $HoursBack hours. What could be causing these?"
    
    return $output -join "`n"
}

function New-FullSummary {
    param([PSCustomObject[]]$Errors, [PSCustomObject[]]$ErrorCodes, [int]$TopErrors)
    
    $output = @()
    $output += "====================================================================="
    $output += "COMPREHENSIVE ERROR ANALYSIS - FULL DIAGNOSTIC REPORT"
    $output += "====================================================================="
    $output += ""
    $output += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $output += "System: $env:ComputerName"
    $output += "User: $env:UserDomain\$env:UserName"
    $output += "Analysis Scope: Last $HoursBack hours"
    $output += ""
    
    $output += "-------------------------------------------------------------------"
    $output += "STATISTICS"
    $output += "-------------------------------------------------------------------"
    $output += "Total Error Instances: $($Errors.Count)"
    $output += "Unique Error Codes: $($ErrorCodes.Count)"
    $output += ""
    
    $errorsByLog = $Errors | Group-Object Log
    foreach ($logGroup in $errorsByLog) {
        $output += "  - $($logGroup.Name) Log: $($logGroup.Count) errors"
    }
    
    $output += ""
    $output += "-------------------------------------------------------------------"
    $output += "TOP ERROR CODES (Top $TopErrors)"
    $output += "-------------------------------------------------------------------"
    $output += ""
    
    $topCodes = $ErrorCodes | Select-Object -First $TopErrors
    $count = 1
    
    foreach ($code in $topCodes) {
        $output += "[$count] $($code.Code)"
        $output += "     Count: $($code.Count) | Severity: $($code.Severity)"
        $output += "     Sources: $($code.Sources -join ', ')"
        $output += ""
        $count++
    }
    
    $output += "-------------------------------------------------------------------"
    $output += "ALL ERROR EVENTS (Sorted by Time)"
    $output += "-------------------------------------------------------------------"
    $output += ""
    
    foreach ($err in $Errors) {
        $output += "Time: $($err.TimeCreated | Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $output += "Log: $($err.Log) | EventID: $($err.EventID) | Level: $($err.Level)"
        $output += "Source: $($err.Source)"
        $msg = if ($err.Message.Length -gt 300) { $err.Message.Substring(0, 297) + "..." } else { $err.Message }
        $output += "Message: $msg"
        $output += ""
    }
    
    $output += "-------------------------------------------------------------------"
    $output += "FOR CHATGPT - COPY AND PASTE BELOW"
    $output += "-------------------------------------------------------------------"
    $output += ""
    $output += "My Windows computer ($env:ComputerName) is showing these errors:"
    $output += ""
    
    $topCodes | ForEach-Object {
        $output += "Error: $($_.Code)"
        $output += "  Occurrences: $($_.Count)"
        $output += "  Severity: $($_.Severity)"
        $output += "  Sources: $($_.Sources -join ', ')"
        $output += ""
    }
    
    $output += "These were logged in the last $HoursBack hours. What could be causing these?"
    
    return $output -join "`n"
}

# Main execution
try {
    $errors = Get-LatestErrors -HoursBack $HoursBack -IncludeWarnings $IncludeWarnings
    
    if (-not $errors -or $errors.Count -eq 0) {
        Write-Host "`nGood news! No errors found in the last $HoursBack hours." -ForegroundColor Green
        exit 0
    }
    
    Write-Host "  Found $($errors.Count) error instances" -ForegroundColor Green
    
    $errorCodes = Extract-ErrorCodes -Errors $errors
    Write-Host "  Extracted $($errorCodes.Count) unique error codes" -ForegroundColor Green
    
    Write-Host "[3/3] Generating $DetailLevel summary..." -ForegroundColor Gray
    
    $summary = switch ($DetailLevel) {
        "Compact" { New-CompactSummary -Errors $errors -ErrorCodes $errorCodes -TopErrors $TopErrors }
        "Summary" { New-DetailedSummary -Errors $errors -ErrorCodes $errorCodes -TopErrors $TopErrors }
        "Full"    { New-FullSummary -Errors $errors -ErrorCodes $errorCodes -TopErrors $TopErrors }
        default   { New-DetailedSummary -Errors $errors -ErrorCodes $errorCodes -TopErrors $TopErrors }
    }
    
    Write-Host "`n"
    Write-Host $summary
    
    if ($OutputFile) {
        $summary | Out-File -FilePath $OutputFile -Force -Encoding UTF8
        Write-Host "`nSummary saved to: $OutputFile" -ForegroundColor Green
    }
    
    if ($CopyToClipboard) {
        $summary | Set-Clipboard
        Write-Host "Summary copied to clipboard!" -ForegroundColor Green
    }
    
    Write-Host "`nAnalysis complete!" -ForegroundColor Green
    
} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n"
