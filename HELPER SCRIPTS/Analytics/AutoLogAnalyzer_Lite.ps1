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
    
#>

param(
    [int]$HoursBack = 48,
    [string]$OutputPath = "$PSScriptRoot\LOG_ANALYSIS",
    [switch]$IncludeOnlineKB,
    [switch]$GenerateChatGPTPrompt
)

$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$reportPath = Join-Path $OutputPath "LogAnalysis_$timestamp"
New-Item -ItemType Directory -Path $reportPath -Force | Out-Null

Write-Host "`n==== AutoLogAnalyzer - System Log Analysis Tool v1.0 ====" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Hours Back: $HoursBack hours"
Write-Host "  Output Path: $reportPath"
Write-Host "  Time Range: $(Get-Date -Date ((Get-Date).AddHours(-$HoursBack)) -Format 'yyyy-MM-dd HH:mm:ss') to $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# Error code patterns
$ErrorPatterns = @()
$ErrorPatterns += @{ PatternName = "EventID"; Regex = '\b(EventID|ID)[\s:=]*(\d+)\b'; Description = "Windows Event ID" }
$ErrorPatterns += @{ PatternName = "HResult"; Regex = '\b(0x[0-9A-Fa-f]{8})\b'; Description = "HRESULT Error Code" }
$ErrorPatterns += @{ PatternName = "HTTPStatus"; Regex = '\b(4\d{2}|5\d{2})\b'; Description = "HTTP Status Code" }
$ErrorPatterns += @{ PatternName = "NTStatus"; Regex = 'STATUS_[A-Z_0-9]+'; Description = "NT Status Code" }
$ErrorPatterns += @{ PatternName = "ProcessError"; Regex = '(?:error|failed|exception)'; Description = "Process/Application Error" }

# Collect Event Viewer logs
function Get-EventViewerLogs {
    param([int]$HoursBack)
    
    Write-Host "Collecting Event Viewer logs..." -ForegroundColor Green
    
    $logsToCollect = @("System", "Application", "Security")
    $allLogs = @()
    $cutoffTime = (Get-Date).AddHours(-$HoursBack)
    
    foreach ($log in $logsToCollect) {
        try {
            Write-Host "  Querying $log log..." -ForegroundColor Gray
            
            $events = Get-EventLog -LogName $log `
                -After $cutoffTime `
                -ErrorAction SilentlyContinue | 
                Select-Object -First 500
            
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
                Write-Host "    Found $($events.Count) events" -ForegroundColor Gray
            }
        } catch {
            Write-Host "    Error accessing $log : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    return $allLogs
}

# Extract error codes
function Extract-ErrorCodes {
    param(
        [PSCustomObject[]]$EventLogs
    )
    
    Write-Host "Extracting error codes..." -ForegroundColor Green
    
    $errors = @()
    
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
                Context = $message.Substring(0, [Math]::Min(150, $message.Length))
            }
            
            # Extract HRESULT codes
            if ($message -match '0x[0-9A-Fa-f]{8}') {
                $matches[0] | ForEach-Object {
                    $errors += [PSCustomObject]@{
                        ErrorCode = $_
                        Type = "HRESULT"
                        Severity = $event.Type
                        Source = $event.Source_Name
                        LogFile = $event.Source
                        Context = $message.Substring(0, [Math]::Min(150, $message.Length))
                    }
                }
            }
            
            # Extract NT Status codes
            if ($message -match 'STATUS_\w+') {
                $matches[0] | ForEach-Object {
                    $errors += [PSCustomObject]@{
                        ErrorCode = $_
                        Type = "NT Status"
                        Severity = $event.Type
                        Source = $event.Source_Name
                        LogFile = $event.Source
                        Context = $message.Substring(0, [Math]::Min(150, $message.Length))
                    }
                }
            }
        }
    }
    
    return $errors
}

# Deduplicate and summarize errors
function Get-ErrorSummary {
    param([PSCustomObject[]]$Errors)
    
    Write-Host "Summarizing errors..." -ForegroundColor Green
    
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
        }
    
    return $grouped | Sort-Object -Property Count -Descending
}

# Create ChatGPT prompt
function New-ChatGPTPrompt {
    param(
        [PSCustomObject[]]$ErrorSummary,
        [string]$OutputFile
    )
    
    Write-Host "Generating ChatGPT prompt..." -ForegroundColor Green
    
    $prompt = @()
    $prompt += "=== SYSTEM LOG ERROR ANALYSIS REPORT ==="
    $prompt += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $prompt += "Analysis Period: Last $HoursBack hours"
    $prompt += ""
    $prompt += "PROMPT 1 - PRIMARY ERROR CODES:"
    $prompt += "========================================"
    $prompt += "I am experiencing the following error codes on my Windows system:"
    $prompt += ""
    
    $topErrors = $ErrorSummary | Select-Object -First 10
    
    foreach ($error in $topErrors) {
        $prompt += "Error Code: $($error.ErrorCode)"
        $prompt += "  Type: $($error.Type)"
        $prompt += "  Occurrences: $($error.Count)"
        $prompt += "  Severity: $($error.Severity)"
        $prompt += "  Sources: $($error.Sources)"
        $prompt += ""
    }
    
    $prompt += ""
    $prompt += "PROMPT 2 - ASK CHATGPT:"
    $prompt += "========================================"
    $prompt += "1. Copy the error codes above"
    $prompt += "2. Paste into ChatGPT with this message:"
    $prompt += "   'What do these error codes mean and how serious are they?'"
    $prompt += "3. For detailed troubleshooting, ask:"
    $prompt += "   'How can I fix these errors?'"
    $prompt += ""
    
    $promptContent = $prompt -join "`r`n"
    Set-Content -Path $OutputFile -Value $promptContent -Force
    
    return $promptContent
}

# Main execution
try {
    Write-Host "[1/4] Collecting Event Viewer Logs..." -ForegroundColor Cyan
    $eventLogs = Get-EventViewerLogs -HoursBack $HoursBack
    Write-Host "      Found $($eventLogs.Count) events`n" -ForegroundColor Green
    
    Write-Host "[2/4] Extracting Error Codes..." -ForegroundColor Cyan
    $allErrors = Extract-ErrorCodes -EventLogs $eventLogs
    Write-Host "      Extracted $($allErrors.Count) errors`n" -ForegroundColor Green
    
    Write-Host "[3/4] Summarizing Errors..." -ForegroundColor Cyan
    $errorSummary = Get-ErrorSummary -Errors $allErrors
    Write-Host "      Found $($errorSummary.Count) unique error codes`n" -ForegroundColor Green
    
    Write-Host "[4/4] Generating Reports..." -ForegroundColor Cyan
    
    $csvPath = Join-Path $reportPath "ERROR_CODES.csv"
    $errorSummary | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "      CSV export: $csvPath" -ForegroundColor Green
    
    $chatgptPromptPath = Join-Path $reportPath "CHATGPT_PROMPT.txt"
    New-ChatGPTPrompt -ErrorSummary $errorSummary -OutputFile $chatgptPromptPath
    Write-Host "      ChatGPT prompt: $chatgptPromptPath`n" -ForegroundColor Green
    
    Write-Host "==== ANALYSIS COMPLETE ====" -ForegroundColor Green
    Write-Host ""
    Write-Host "KEY FINDINGS:" -ForegroundColor Yellow
    Write-Host "  Total Error Codes Found: $($errorSummary.Count)" -ForegroundColor White
    Write-Host "  Total Error Occurrences: $($allErrors.Count)" -ForegroundColor White
    
    if ($errorSummary.Count -gt 0) {
        Write-Host ""
        Write-Host "  TOP 5 MOST FREQUENT ERRORS:" -ForegroundColor Yellow
        $topErrors = $errorSummary | Select-Object -First 5
        for ($i = 0; $i -lt $topErrors.Count; $i++) {
            $error = $topErrors[$i]
            Write-Host "    [$($i+1)] $($error.ErrorCode) - $($error.Count) occurrences" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
    Write-Host "  OUTPUT FILES:" -ForegroundColor Yellow
    Write-Host "    * ChatGPT Prompt: $chatgptPromptPath" -ForegroundColor Gray
    Write-Host "    * CSV Data: $csvPath" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "    1. Open: $chatgptPromptPath" -ForegroundColor Gray
    Write-Host "    2. Copy the error codes" -ForegroundColor Gray
    Write-Host "    3. Paste into ChatGPT for troubleshooting" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Opening reports folder..." -ForegroundColor Gray
    Start-Process -FilePath explorer.exe -ArgumentList $reportPath
    
} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Analysis finished at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
