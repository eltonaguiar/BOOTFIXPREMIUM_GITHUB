#!/usr/bin/env powershell
<#
.SYNOPSIS
    Comprehensive Error Keyword Scanner and Reporter
    
.DESCRIPTION
    Scans log files and source code for error keywords that indicate problems.
    This module ensures that NO module with errors can pass validation.
    
    Designed to work with the testing pipeline to catch issues early.
#>

param(
    [string]$LogFile = "",
    [string]$SourceFiles = "",
    [bool]$ThrowOnError = $true
)

$ErrorActionPreference = 'Continue'

# Comprehensive list of error keywords
$errorKeywords = @{
    Critical = @(
        "ERROR:",
        "FATAL:",
        "CRITICAL:",
        "Exception",
        "UnauthorizedAccessException",
        "InvalidOperationException",
        "FileNotFoundException",
        "NullReferenceException"
    )
    Failures = @(
        "failed to",
        "cannot load",
        "could not",
        "does not exist",
        "not found",
        "missing",
        "undefined",
        "null"
    )
    Syntax = @(
        "Syntax error",
        "Parse error",
        "Invalid syntax",
        "Unexpected token",
        "Missing parameter"
    )
    Runtime = @(
        "Unresolved",
        "not recognized",
        "Access denied",
        "Permission denied",
        "Timeout"
    )
}

function Scan-LogForErrors {
    param(
        [string]$LogPath,
        [hashtable]$Keywords
    )
    
    $findings = @{
        TotalIssues = 0
        Critical = @()
        Failures = @()
        Syntax = @()
        Runtime = @()
        AllIssues = @()
    }
    
    if (-not (Test-Path $LogPath)) {
        Write-Host "Log file not found: $LogPath" -ForegroundColor Yellow
        return $findings
    }
    
    $content = Get-Content $LogPath -Raw
    
    foreach ($category in $Keywords.Keys) {
        foreach ($keyword in $Keywords[$category]) {
            $pattern = [regex]::Escape($keyword)
            $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            
            if ($matches.Count -gt 0) {
                $findings[$category] += @{
                    Keyword = $keyword
                    Count = $matches.Count
                    Category = $category
                }
                
                $findings.TotalIssues += $matches.Count
                $findings.AllIssues += @{
                    Keyword = $keyword
                    Count = $matches.Count
                    Category = $category
                }
            }
        }
    }
    
    return $findings
}

function Scan-SourceForErrors {
    param(
        [string]$FilePath,
        [hashtable]$Keywords
    )
    
    $findings = @{
        TotalIssues = 0
        Critical = @()
        Failures = @()
        Syntax = @()
        Runtime = @()
        AllIssues = @()
    }
    
    if (-not (Test-Path $FilePath)) {
        return $findings
    }
    
    # Validate syntax first
    try {
        $content = Get-Content $FilePath -Raw
        $null = [scriptblock]::Create($content)
    } catch {
        $findings.Critical += @{
            Keyword = "Syntax Error"
            Count = 1
            Details = $_.Exception.Message
        }
        $findings.TotalIssues++
        return $findings
    }
    
    # Scan content
    foreach ($category in $Keywords.Keys) {
        foreach ($keyword in $Keywords[$category]) {
            if ($content -imatch [regex]::Escape($keyword)) {
                $count = ([regex]::Matches($content, [regex]::Escape($keyword), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
                
                $findings[$category] += @{
                    Keyword = $keyword
                    Count = $count
                    Category = $category
                }
                
                $findings.TotalIssues += $count
            }
        }
    }
    
    return $findings
}

function Format-ErrorReport {
    param(
        [hashtable]$Findings,
        [string]$Title = "Error Scan Report"
    )
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    if ($Findings.TotalIssues -eq 0) {
        Write-Host "[OK] NO ERRORS FOUND - Module is clean!" -ForegroundColor Green
        Write-Host ""
        return $true
    }
    
    Write-Host "[FAIL] FOUND $($Findings.TotalIssues) ERROR(S)" -ForegroundColor Red
    Write-Host ""
    
    foreach ($category in $Findings.Keys) {
        if ($category -eq "TotalIssues" -or $category -eq "AllIssues") {
            continue
        }
        
        if ($Findings[$category].Count -gt 0) {
            Write-Host "  [$category]" -ForegroundColor Yellow
            foreach ($issue in $Findings[$category]) {
                Write-Host "    - $($issue.Keyword): $($issue.Count) occurrence(s)" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
    return $false
}

# Main execution
if ($LogFile) {
    Write-Host "Scanning log file: $LogFile" -ForegroundColor Cyan
    $findings = Scan-LogForErrors $LogFile $errorKeywords
    $success = Format-ErrorReport $findings "LOG FILE ERROR SCAN"
} elseif ($SourceFiles) {
    Write-Host "Scanning source files: $SourceFiles" -ForegroundColor Cyan
    
    if (Test-Path $SourceFiles -PathType Container) {
        $files = Get-ChildItem $SourceFiles -Filter "*.ps1" -Recurse
    } else {
        $files = Get-Item $SourceFiles
    }
    
    $totalFindings = @{
        TotalIssues = 0
        Critical = @()
        Failures = @()
        Syntax = @()
        Runtime = @()
    }
    
    foreach ($file in $files) {
        Write-Host ""
        Write-Host "Scanning: $($file.Name)" -ForegroundColor Cyan
        $findings = Scan-SourceForErrors $file.FullPath $errorKeywords
        
        if ($findings.TotalIssues -gt 0) {
            Format-ErrorReport $findings "Found in $($file.Name)"
            $totalFindings.TotalIssues += $findings.TotalIssues
        } else {
            Write-Host "[OK] No errors found in $($file.Name)" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "TOTAL SCAN RESULTS" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Total Issues Found: $($totalFindings.TotalIssues)" -ForegroundColor $(if ($totalFindings.TotalIssues -eq 0) { "Green" } else { "Red" })
    Write-Host ""
    
    $success = $totalFindings.TotalIssues -eq 0
} else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\ERROR_KEYWORD_SCANNER.ps1 -LogFile (path)" -ForegroundColor White
    Write-Host "  .\ERROR_KEYWORD_SCANNER.ps1 -SourceFiles (path)" -ForegroundColor White
    exit 1
}

if (-not $success -and $ThrowOnError) {
    Write-Host "ERROR DETECTION: Module contains errors and cannot be released!" -ForegroundColor Red
    exit 1
} else {
    exit 0
}
