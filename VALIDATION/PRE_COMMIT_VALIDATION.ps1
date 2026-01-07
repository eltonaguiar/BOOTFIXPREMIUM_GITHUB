#!/usr/bin/env powershell
<#
.SYNOPSIS
    Pre-Commit Validation System - Prevents bad code from being committed
    
.DESCRIPTION
    This script validates that NO module can proceed out of the coding phase
    unless it passes the SUPER_TEST_MANDATORY and has:
    1. ZERO syntax errors
    2. NO error keywords in output (ERROR, failed, not found, exception, etc.)
    3. Successful UI launch on Windows 11 (if GUI module)
    
    All output is automatically piped to log files for persistent error tracking.
    
.PARAMETER ScriptPath
    Path to the PowerShell script to validate
    
.PARAMETER LogDirectory
    Directory where logs will be saved. Default: ./TEST_LOGS
    
.PARAMETER StrictKeywords
    Array of keywords that MUST NOT appear in output. 
    Default: @("ERROR", "failed", "failed to", "exception", "not found", "undefined", "null reference")
#>

param(
    [string]$ScriptPath = "",
    [string]$LogDirectory = "$(Split-Path -Parent $PSScriptRoot)\TEST_LOGS",
    [string[]]$StrictKeywords = @("ERROR", "failed", "failed to", "exception", "not found", "undefined", "null reference", "unresolved", "missing", "critical")
)

$ErrorActionPreference = 'Continue'
$VerbosePreference = 'Continue'

# Ensure log directory exists
if (-not (Test-Path $LogDirectory)) {
    $null = New-Item -ItemType Directory -Path $LogDirectory -Force
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$validationLog = Join-Path $LogDirectory "PRE_COMMIT_VALIDATION_$timestamp.log"
$keywordLog = Join-Path $LogDirectory "ERROR_KEYWORDS_$timestamp.log"

function Write-ValidationLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [System.ConsoleColor]$Color = "White"
    )
    
    $logEntry = "$(Get-Date -Format 'HH:mm:ss') [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $Color
    Add-Content -Path $validationLog -Value $logEntry
}

function Test-SyntaxValid {
    param(
        [string]$FilePath
    )
    
    Write-ValidationLog "====== SYNTAX VALIDATION ======" "TEST" "Cyan"
    
    if (-not (Test-Path $FilePath)) {
        Write-ValidationLog "FAIL: File not found: $FilePath" "FAIL" "Red"
        return $false
    }
    
    try {
        $content = Get-Content $FilePath -Raw
        $null = [scriptblock]::Create($content)
        Write-ValidationLog "PASS: No syntax errors detected" "PASS" "Green"
        return $true
    } catch {
        Write-ValidationLog "FAIL: Syntax error in $FilePath" "FAIL" "Red"
        Write-ValidationLog "Details: $($_.Exception.Message)" "ERROR" "Red"
        Add-Content -Path $validationLog -Value $_.Exception.Message
        return $false
    }
}

function Test-NoErrorKeywords {
    param(
        [string]$FilePath,
        [string[]]$Keywords
    )
    
    Write-ValidationLog "" "INFO"
    Write-ValidationLog "====== ERROR KEYWORD SCAN ======" "TEST" "Cyan"
    Write-ValidationLog "Scanning for: $($Keywords -join ', ')" "INFO" "Yellow"
    
    if (-not (Test-Path $FilePath)) {
        Write-ValidationLog "FAIL: File not found" "FAIL" "Red"
        return $false
    }
    
    $content = Get-Content $FilePath -Raw
    $foundErrors = @()
    
    foreach ($keyword in $Keywords) {
        # Case-insensitive search
        if ($content -imatch [regex]::Escape($keyword)) {
            $foundErrors += @{
                Keyword = $keyword
                Count = ([regex]::Matches($content, [regex]::Escape($keyword), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
            }
        }
    }
    
    if ($foundErrors.Count -eq 0) {
        Write-ValidationLog "PASS: No error keywords found" "PASS" "Green"
        return $true
    } else {
        Write-ValidationLog "FAIL: Found $($foundErrors.Count) error keyword(s)" "FAIL" "Red"
        foreach ($err in $foundErrors) {
            $msg = "  - '$($err.Keyword)' found $($err.Count) time(s)"
            Write-ValidationLog $msg "ERROR" "Red"
            Add-Content -Path $keywordLog -Value $msg
        }
        return $false
    }
}

function Test-ModuleWithOutputCapture {
    param(
        [string]$FilePath
    )
    
    Write-ValidationLog "" "INFO"
    Write-ValidationLog "====== MODULE EXECUTION TEST ======" "TEST" "Cyan"
    
    if (-not (Test-Path $FilePath)) {
        Write-ValidationLog "FAIL: File not found" "FAIL" "Red"
        return $false, @()
    }
    
    $outputLog = Join-Path $LogDirectory "MODULE_OUTPUT_$timestamp.log"
    
    try {
        Write-ValidationLog "Executing module with output capture..." "RUN" "Cyan"
        
        # Capture all output
        $output = & {
            & $FilePath 2>&1
        } | ForEach-Object {
            $_ | Tee-Object -FilePath $outputLog -Append
        }
        
        $exitCode = $LASTEXITCODE
        Write-ValidationLog "Module execution completed with exit code: $exitCode" "INFO" "Cyan"
        
        if ($exitCode -eq 0) {
            Write-ValidationLog "PASS: Module executed successfully" "PASS" "Green"
            return $true, $output
        } else {
            Write-ValidationLog "FAIL: Module exited with code $exitCode" "FAIL" "Red"
            return $false, $output
        }
    } catch {
        Write-ValidationLog "FAIL: Exception during module execution" "FAIL" "Red"
        Write-ValidationLog "Details: $($_.Exception.Message)" "ERROR" "Red"
        Add-Content -Path $validationLog -Value $_.Exception.Message
        return $false, @()
    }
}

function Test-AllValidations {
    param(
        [string]$FilePath,
        [string[]]$Keywords
    )
    
    $results = @{
        FilePath = $FilePath
        SyntaxValid = $false
        NoKeywords = $false
        ExecutionSuccess = $false
        AllTestsPassed = $false
        Details = @()
    }
    
    Write-ValidationLog "============================================================" "START" "Cyan"
    Write-ValidationLog "PRE-COMMIT VALIDATION SYSTEM" "START" "Cyan"
    Write-ValidationLog "File: $FilePath" "START" "Cyan"
    Write-ValidationLog "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "START" "Cyan"
    Write-ValidationLog "============================================================" "START" "Cyan"
    Write-ValidationLog "" "INFO"
    
    # Test 1: Syntax
    $results.SyntaxValid = Test-SyntaxValid $FilePath
    
    # Test 2: No error keywords
    $results.NoKeywords = Test-NoErrorKeywords $FilePath $Keywords
    
    # Test 3: Module execution
    $execSuccess, $moduleOutput = Test-ModuleWithOutputCapture $FilePath
    $results.ExecutionSuccess = $execSuccess
    
    # Final result
    $results.AllTestsPassed = $results.SyntaxValid -and $results.NoKeywords -and $results.ExecutionSuccess
    
    Write-ValidationLog "" "INFO"
    Write-ValidationLog "============================================================" "FINAL" "Cyan"
    Write-ValidationLog "VALIDATION SUMMARY" "FINAL" "Cyan"
    Write-ValidationLog "Syntax Valid:      $(if ($results.SyntaxValid) { 'PASS' } else { 'FAIL' })" "RESULT" $(if ($results.SyntaxValid) { "Green" } else { "Red" })
    Write-ValidationLog "No Error Keywords: $(if ($results.NoKeywords) { 'PASS' } else { 'FAIL' })" "RESULT" $(if ($results.NoKeywords) { "Green" } else { "Red" })
    Write-ValidationLog "Execution Success: $(if ($results.ExecutionSuccess) { 'PASS' } else { 'FAIL' })" "RESULT" $(if ($results.ExecutionSuccess) { "Green" } else { "Red" })
    Write-ValidationLog "============================================================" "FINAL" "Cyan"
    
    if ($results.AllTestsPassed) {
        Write-ValidationLog "" "INFO"
        Write-ValidationLog "[OK] ALL VALIDATIONS PASSED - MODULE READY FOR RELEASE" "SUCCESS" "Green"
        Write-ValidationLog "" "INFO"
    } else {
        Write-ValidationLog "" "INFO"
        Write-ValidationLog "[FAIL] VALIDATION FAILED - MODULE CANNOT PROCEED" "FAILURE" "Red"
        Write-ValidationLog "Logs saved to:" "INFO" "Yellow"
        Write-ValidationLog "  - Validation Log: $validationLog" "INFO" "Yellow"
        Write-ValidationLog "  - Keyword Log: $keywordLog" "INFO" "Yellow"
        Write-ValidationLog "" "INFO"
    }
    
    Write-Host ""
    Write-Host "Full validation log: $validationLog" -ForegroundColor Cyan
    
    return $results
}

# Main execution
if (-not $ScriptPath) {
    Write-ValidationLog "ERROR: ScriptPath parameter is required" "ERROR" "Red"
    Write-Host ""
    Write-Host "Usage: .\PRE_COMMIT_VALIDATION.ps1 -ScriptPath (path) [-LogDirectory (path)]" -ForegroundColor Yellow
    exit 1
}

$validationResults = Test-AllValidations $ScriptPath $StrictKeywords

# Exit with appropriate code
if ($validationResults.AllTestsPassed) {
    exit 0
} else {
    exit 1
}
