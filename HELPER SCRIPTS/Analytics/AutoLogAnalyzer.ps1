<#
.SYNOPSIS
    AutoLogAnalyzer - Comprehensive System Log Analysis Tool
    
.DESCRIPTION
    Automatically collects system logs from the current machine, analyzes them for errors,
    extracts error codes, and generates ChatGPT-friendly summaries for troubleshooting.
    
.FEATURES
    - Collects Event Viewer logs (System, Application, Security)
    - Analyzes local application logs
    - Extracts and deduplicates error codes
    - Generates summary reports
    - Creates ChatGPT-friendly prompt snippets
    - Organizes errors by frequency and severity
    
.USAGE
    .\AutoLogAnalyzer.ps1
    .\AutoLogAnalyzer.ps1 -HoursBack 24
    .\AutoLogAnalyzer.ps1 -OutputPath "C:\CustomPath"
    .\AutoLogAnalyzer.ps1 -IncludeOnlineKB
    
#>

param(
    [int]$HoursBack = 48,
    [string]$OutputPath = "$PSScriptRoot\LOG_ANALYSIS",
    [switch]$IncludeOnlineKB,
    [switch]$GenerateChatGPTPrompt
)

# ============================================================================
# INITIALIZATION
# ============================================================================

$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$reportPath = Join-Path $OutputPath "LogAnalysis_$timestamp"
New-Item -ItemType Directory -Path $reportPath -Force | Out-Null

Write-Host "`n" -ForegroundColor Cyan
Write-Host "        AutoLogAnalyzer - System Log Analysis Tool v1.0         " -ForegroundColor Cyan
Write-Host "`n" -ForegroundColor Cyan

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Hours Back: $HoursBack hours"
Write-Host "  Output Path: $reportPath"
Write-Host "  Time Range: $(Get-Date -Date ((Get-Date).AddHours(-$HoursBack)) -Format "yyyy-MM-dd HH:mm:ss") to $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
Write-Host ""

# ============================================================================
# ERROR CODE PATTERNS LIBRARY
# ============================================================================

$ErrorPatterns = @()
$ErrorPatterns += @{ PatternName = "EventID"; Regex = '\b(EventID|ID)[\s:=]*(\d+)\b'; Description = "Windows Event ID" }
$ErrorPatterns += @{ PatternName = "HResult"; Regex = '\b(0x[0-9A-Fa-f]{8})\b'; Description = "HRESULT Error Code" }
$ErrorPatterns += @{ PatternName = "HTTPStatus"; Regex = '\b(4\d{2}|5\d{2})\b\s*(error|status)'; Description = "HTTP Status Code" }
$ErrorPatterns += @{ PatternName = "NTStatus"; Regex = 'STATUS_[A-Z_0-9]+'; Description = "NT Status Code" }
$ErrorPatterns += @{ PatternName = "LogonType"; Regex = 'Logon Type:\s*(\d+)'; Description = "Windows Logon Type" }
$ErrorPatterns += @{ PatternName = "ProcessError"; Regex = '(?:error|failed|exception)[\s:]*([A-Za-z0-9_-]*)'; Description = "Process/Application Error" }

# ============================================================================
# FUNCTION: COLLECT EVENT VIEWER LOGS
# ============================================================================

function Get-EventViewerLogs {
    param([int]$HoursBack)
    
    Write-Host "Collecting Event Viewer logs..." -ForegroundColor Green
    
    $logsToCollect = @(
        @{ Name = "System"; MaxEvents = 500 }
        @{ Name = "Application"; MaxEvents = 500 }
        @{ Name = "Security"; MaxEvents = 200 }
    )
    
    $allLogs = @()
    $cutoffTime = (Get-Date).AddHours(-$HoursBack)
    
    foreach ($log in $logsToCollect) {
        try {
            Write-Host "  Querying $($log.Name) log..." -ForegroundColor Gray
            
            $events = Get-EventLog -LogName $log.Name `
                -After $cutoffTime `
                -ErrorAction SilentlyContinue | 
                Select-Object -First $log.MaxEvents
            
            if ($events) {
                $allLogs += $events | ForEach-Object {
                    [PSCustomObject]@{
                        Source = $log.Name
                        EventID = $_.EventID
                        Type = $_.EntryType
                        TimeGenerated = $_.TimeGenerated
                        Source_Name = $_.Source
                        Message = $_.Message
                        Computer = $_.MachineName
                    }
                }
                Write-Host "    Found $($events.Count) events" -ForegroundColor Gray
            }
        } catch {
            Write-Host "    Error accessing $($log.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    return $allLogs
}

# ============================================================================
# FUNCTION: COLLECT LOCAL APPLICATION LOGS
# ============================================================================

function Get-LocalApplicationLogs {
    param([int]$HoursBack)
    
    Write-Host "Collecting local application logs..." -ForegroundColor Green
    
    $logPaths = @(
        "$env:LOCALAPPDATA\*\*\logs\*.log",
        "$env:ProgramFiles\*\logs\*.log",
        "$env:ProgramFiles(x86)\*\logs\*.log",
        "$env:TEMP\*.log",
        "$env:WINDIR\Logs\*\*.log"
    )
    
    $allLogs = @()
    $cutoffTime = (Get-Date).AddHours(-$HoursBack)
    
    foreach ($path in $logPaths) {
        try {
            $files = Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -gt $cutoffTime } |
                Select-Object -First 20
            
            foreach ($file in $files) {
                try {
                    $content = Get-Content -Path $file.FullName -ErrorAction SilentlyContinue -Raw
                    if ($content) {
                        $allLogs += [PSCustomObject]@{
                            Source = "Application Log"
                            File = $file.Name
                            Path = $file.FullName
                            LastModified = $file.LastWriteTime
                            Content = $content
                        }
                    }
                } catch {
                    # Skip files that can't be read
                }
            }
        } catch {
            # Skip paths that don't exist
        }
    }
    
    return $allLogs
}

# ============================================================================
# FUNCTION: EXTRACT ERROR CODES
# ============================================================================

function Extract-ErrorCodes {
    param(
        [PSCustomObject[]]$EventLogs,
        [PSCustomObject[]]$FileLogs
    )
    
    Write-Host "Extracting error codes and patterns..." -ForegroundColor Green
    
    $errors = @()
    
    # Process Event Viewer logs
    foreach ($event in $EventLogs) {
        if ($event.Type -in @("Error", "Warning")) {
            $message = $event.Message -join " "
            
            # Extract EventID
            $errors += [PSCustomObject]@{
                ErrorCode = "EventID_$($event.EventID)"
                Type = "Event Viewer"
                Severity = $event.Type
                Source = $event.Source_Name
                LogFile = $event.Source
                TimeGenerated = $event.TimeGenerated
                Context = $message.Substring(0, [Math]::Min(200, $message.Length))
                FullMessage = $message
            }
            
            # Extract HRESULT codes
            if ($message -match "0x[0-9A-Fa-f]{8}") {
                $matches[0] | ForEach-Object {
                    $errors += [PSCustomObject]@{
                        ErrorCode = $_
                        Type = "HRESULT"
                        Severity = $event.Type
                        Source = $event.Source_Name
                        LogFile = $event.Source
                        TimeGenerated = $event.TimeGenerated
                        Context = $message.Substring(0, [Math]::Min(200, $message.Length))
                        FullMessage = $message
                    }
                }
            }
            
            # Extract NT Status codes
            if ($message -match "STATUS_\w+") {
                $matches[0] | ForEach-Object {
                    $errors += [PSCustomObject]@{
                        ErrorCode = $_
                        Type = "NT Status"
                        Severity = $event.Type
                        Source = $event.Source_Name
                        LogFile = $event.Source
                        TimeGenerated = $event.TimeGenerated
                        Context = $message.Substring(0, [Math]::Min(200, $message.Length))
                        FullMessage = $message
                    }
                }
            }
        }
    }
    
    # Process file logs
    foreach ($log in $FileLogs) {
        $lines = ($log.Content -split "`r`n") | Where-Object { $_ -match "error|warning|failed|exception" -and $_.Length -gt 0 }
        
        foreach ($line in $lines) {
            # Extract HRESULT
            if ($line -match "0x[0-9A-Fa-f]{8}") {
                $matches[0] | ForEach-Object {
                    $errors += [PSCustomObject]@{
                        ErrorCode = $_
                        Type = "HRESULT"
                        Severity = if ($line -match "error") { "Error" } else { "Warning" }
                        Source = "Application"
                        LogFile = $log.File
                        TimeGenerated = $log.LastModified
                        Context = $line.Substring(0, [Math]::Min(200, $line.Length))
                        FullMessage = $line
                    }
                }
            }
            
            # Extract NT Status
            if ($line -match "STATUS_\w+") {
                $matches[0] | ForEach-Object {
                    $errors += [PSCustomObject]@{
                        ErrorCode = $_
                        Type = "NT Status"
                        Severity = if ($line -match "error") { "Error" } else { "Warning" }
                        Source = "Application"
                        LogFile = $log.File
                        TimeGenerated = $log.LastModified
                        Context = $line.Substring(0, [Math]::Min(200, $line.Length))
                        FullMessage = $line
                    }
                }
            }
        }
    }
    
    return $errors
}

# ============================================================================
# FUNCTION: DEDUPLICATE AND SUMMARIZE ERRORS
# ============================================================================

function Get-ErrorSummary {
    param([PSCustomObject[]]$Errors)
    
    Write-Host "Deduplicating and summarizing errors..." -ForegroundColor Green
    
    $grouped = $Errors | 
        Group-Object -Property ErrorCode |
        Select-Object -Property @{
            Name = "ErrorCode"
            Expression = { $_.Name }
        }, @{
            Name = "Count"
            Expression = { $_.Count }
        }, @{
            Name = "Type"
            Expression = { $_.Group[0].Type }
        }, @{
            Name = "Severity"
            Expression = { $_.Group[0].Severity }
        }, @{
            Name = "Sources"
            Expression = { ($_.Group.Source | Select-Object -Unique) -join ", " }
        }, @{
            Name = "LogFiles"
            Expression = { ($_.Group.LogFile | Select-Object -Unique) -join ", " }
        }, @{
            Name = "FirstOccurrence"
            Expression = { $_.Group.TimeGenerated | Sort-Object | Select-Object -First 1 }
        }, @{
            Name = "LastOccurrence"
            Expression = { $_.Group.TimeGenerated | Sort-Object | Select-Object -Last 1 }
        }, @{
            Name = "SampleContext"
            Expression = { $_.Group[0].Context }
        }
    
    return $grouped | Sort-Object -Property Count -Descending
}

# ============================================================================
# FUNCTION: GENERATE CHATGPT PROMPT
# ============================================================================

function New-ChatGPTPrompt {
    param(
        [PSCustomObject[]]$ErrorSummary,
        [string]$OutputFile
    )
    
    Write-Host "Generating ChatGPT-friendly prompt..." -ForegroundColor Green
    
    $prompt = @()
    $prompt += "=== SYSTEM LOG ERROR ANALYSIS REPORT ==="
    $prompt += "Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
    $prompt += "Analysis Period: Last $HoursBack hours"
    $prompt += ""
    $prompt += "PROMPT 1 - PRIMARY ERROR CODES:"
    $prompt += "========================================="
    $prompt += ""
    $prompt += "I'm experiencing the following error codes on my Windows system. Please help me understand what each means and suggest troubleshooting steps:"
    $prompt += ""
    
    $topErrors = $ErrorSummary | Select-Object -First 10
    
    foreach ($error in $topErrors) {
        $prompt += "Error Code: $($error.ErrorCode)"
        $prompt += "  - Type: $($error.Type)"
        $prompt += "  - Occurrences: $($error.Count)"
        $prompt += "  - Severity: $($error.Severity)"
        $prompt += "  - Affected Components: $($error.Sources)"
        $prompt += "  - Context: $($error.SampleContext)"
        $prompt += ""
    }
    
    $prompt += ""
    $prompt += "PROMPT 2 - DETAILED ERROR CONTEXT:"
    $prompt += "========================================="
    $prompt += ""
    $prompt += "Here are the top error patterns from my system logs. Please identify common root causes and provide remediation steps:"
    $prompt += ""
    
    $errorsByType = $ErrorSummary | Group-Object -Property Type
    
    foreach ($typeGroup in $errorsByType) {
        $prompt += "[$($typeGroup.Name) Errors - $($typeGroup.Group.Count) total occurrences]"
        
        foreach ($error in $typeGroup.Group | Select-Object -First 5) {
            $prompt += "   $($error.ErrorCode) (appeared $($error.Count) times)"
            $prompt += "    Sources: $($error.Sources)"
            $prompt += "    Details: $($error.SampleContext)"
        }
        $prompt += ""
    }
    
    $prompt += ""
    $prompt += "=== ADDITIONAL INFORMATION ==="
    $prompt += "System: $env:ComputerName"
    $prompt += "OS: $([System.Environment]::OSVersion.VersionString)"
    $prompt += "PowerShell: $($PSVersionTable.PSVersion.ToString())"
    $prompt += ""
    
    $promptContent = $prompt -join "`r`n"
    Set-Content -Path $OutputFile -Value $promptContent -Force
    
    return $promptContent
}

# ============================================================================
# FUNCTION: CREATE DETAILED REPORT
# ============================================================================

function New-DetailedReport {
    param(
        [PSCustomObject[]]$ErrorSummary,
        [PSCustomObject[]]$AllErrors,
        [string]$OutputFile
    )
    
    Write-Host "Creating detailed report..." -ForegroundColor Green
    
    $report = @()
    $report += ""
    $report += "          COMPREHENSIVE SYSTEM LOG ANALYSIS REPORT             "
    $report += ""
    $report += ""
    $report += "Report Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
    $report += "Analysis Scope: Last $HoursBack hours"
    $report += "System: $env:ComputerName ($env:UserDomain\$env:UserName)"
    $report += "OS: $([System.Environment]::OSVersion.VersionString)"
    $report += ""
    
    $report += ""
    $report += "SUMMARY STATISTICS"
    $report += ""
    $report += "Total Unique Error Codes: $($ErrorSummary.Count)"
    $report += "Total Error Occurrences: $($AllErrors.Count)"
    $report += "Most Frequent Error: $($ErrorSummary[0].ErrorCode) ($($ErrorSummary[0].Count) times)"
    $report += ""
    
    $report += ""
    $report += "TOP 20 ERROR CODES"
    $report += ""
    
    $topErrors = $ErrorSummary | Select-Object -First 20
    $rankNum = 1
    
    foreach ($error in $topErrors) {
        $report += ""
        $report += "[$rankNum] $($error.ErrorCode)"
        $report += "    Type:              $($error.Type)"
        $report += "    Occurrences:       $($error.Count)"
        $report += "    Severity:          $($error.Severity)"
        $report += "    Sources:           $($error.Sources)"
        $report += "    Log Files:         $($error.LogFiles)"
        $report += "    First Seen:        $($error.FirstOccurrence)"
        $report += "    Last Seen:         $($error.LastOccurrence)"
        $report += "    Sample Context:    $($error.SampleContext)"
        $rankNum++
    }
    
    $report += ""
    $report += ""
    $report += ""
    $report += "ERROR DISTRIBUTION BY TYPE"
    $report += ""
    
    $byType = $ErrorSummary | Group-Object -Property Type | Sort-Object -Property Count -Descending
    
    foreach ($type in $byType) {
        $report += "$($type.Name): $($type.Count) unique errors"
    }
    
    $report += ""
    $report += ""
    $report += ""
    $report += "ERROR DISTRIBUTION BY SEVERITY"
    $report += ""
    
    $bySeverity = $ErrorSummary | Group-Object -Property Severity | Sort-Object -Property Count -Descending
    
    foreach ($sev in $bySeverity) {
        $report += "$($sev.Name): $($sev.Count) unique errors"
    }
    
    $report += ""
    $report += ""
    $report += ""
    $report += "End of Report"
    $report += ""
    
    $reportContent = $report -join "`r`n"
    Set-Content -Path $OutputFile -Value $reportContent -Force
    
    return $reportContent
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    # Step 1: Collect Event Viewer Logs
    Write-Host "`n[1/5] Collecting Event Viewer Logs..." -ForegroundColor Cyan
    $eventLogs = Get-EventViewerLogs -HoursBack $HoursBack
    Write-Host "       Collected $($eventLogs.Count) events" -ForegroundColor Green
    
    # Step 2: Collect Local Application Logs
    Write-Host "`n[2/5] Collecting Local Application Logs..." -ForegroundColor Cyan
    $appLogs = Get-LocalApplicationLogs -HoursBack $HoursBack
    Write-Host "       Collected $($appLogs.Count) log files" -ForegroundColor Green
    
    # Step 3: Extract Error Codes
    Write-Host "`n[3/5] Extracting Error Codes and Patterns..." -ForegroundColor Cyan
    $allErrors = Extract-ErrorCodes -EventLogs $eventLogs -FileLogs $appLogs
    Write-Host "       Extracted $($allErrors.Count) error instances" -ForegroundColor Green
    
    # Step 4: Summarize and Deduplicate
    Write-Host "`n[4/5] Summarizing Errors..." -ForegroundColor Cyan
    $errorSummary = Get-ErrorSummary -Errors $allErrors
    Write-Host "       Found $($errorSummary.Count) unique error codes" -ForegroundColor Green
    
    # Step 5: Generate Reports
    Write-Host "`n[5/5] Generating Reports..." -ForegroundColor Cyan
    
    $detailedReportPath = Join-Path $reportPath "DETAILED_REPORT.txt"
    New-DetailedReport -ErrorSummary $errorSummary -AllErrors $allErrors -OutputFile $detailedReportPath
    Write-Host "       Detailed report: $detailedReportPath" -ForegroundColor Green
    
    $chatgptPromptPath = Join-Path $reportPath "CHATGPT_PROMPT.txt"
    $promptContent = New-ChatGPTPrompt -ErrorSummary $errorSummary -OutputFile $chatgptPromptPath
    Write-Host "       ChatGPT prompt: $chatgptPromptPath" -ForegroundColor Green
    
    # Export raw data as CSV
    $csvPath = Join-Path $reportPath "ERROR_CODES.csv"
    $errorSummary | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "       CSV export: $csvPath" -ForegroundColor Green
    
    $rawCsvPath = Join-Path $reportPath "ALL_ERRORS_RAW.csv"
    $allErrors | Export-Csv -Path $rawCsvPath -NoTypeInformation
    Write-Host "       Raw errors CSV: $rawCsvPath" -ForegroundColor Green
    
    # Generate summary for console output
    Write-Host "`n" -ForegroundColor Cyan
    Write-Host "                    ANALYSIS COMPLETE                          " -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Green
    
    Write-Host "`nKEY FINDINGS:" -ForegroundColor Yellow
    Write-Host "  Total Error Codes Found: $($errorSummary.Count)" -ForegroundColor White
    Write-Host "  Total Error Occurrences: $($allErrors.Count)" -ForegroundColor White
    
    if ($errorSummary.Count -gt 0) {
        Write-Host "`n  TOP 5 MOST FREQUENT ERRORS:" -ForegroundColor Yellow
        $topErrors = $errorSummary | Select-Object -First 5
        for ($i = 0; $i -lt $topErrors.Count; $i++) {
            $error = $topErrors[$i]
            Write-Host "    [$($i+1)] $($error.ErrorCode) - $($error.Count) occurrences" -ForegroundColor Cyan
        }
    }
    
    Write-Host "`n  OUTPUT FILES:" -ForegroundColor Yellow
    Write-Host "     Detailed Report: $detailedReportPath" -ForegroundColor Gray
    Write-Host "     ChatGPT Prompt: $chatgptPromptPath" -ForegroundColor Gray
    Write-Host "     CSV Data: $csvPath" -ForegroundColor Gray
    Write-Host "     Raw Errors: $rawCsvPath" -ForegroundColor Gray
    
    Write-Host "`n  NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "    1. Review the detailed report for context" -ForegroundColor Gray
    Write-Host "    2. Copy CHATGPT_PROMPT.txt content into ChatGPT" -ForegroundColor Gray
    Write-Host "    3. Use the prompts to get AI-assisted troubleshooting" -ForegroundColor Gray
    Write-Host "    4. Cross-reference error codes with the CSV for full details" -ForegroundColor Gray
    
    Write-Host "`n  REPORT LOCATION:" -ForegroundColor Yellow
    Write-Host "    $reportPath" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "Opening report directory..." -ForegroundColor Gray
    Start-Process -FilePath explorer.exe -ArgumentList $reportPath
    
} catch {
    Write-Host "`n ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host "`nAnalysis finished at $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" -ForegroundColor Gray
