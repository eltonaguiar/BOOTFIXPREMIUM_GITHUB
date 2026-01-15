# ============================================================================
# COMPREHENSIVE TEST PROCEDURE FOR RunMiracleBoot.cmd
# ============================================================================
# This test validates that RunMiracleBoot.cmd works correctly in all scenarios
# and checks for the ". was unexpected" error specifically.

param(
    [switch]$Verbose,
    [switch]$FailFast
)

$ErrorActionPreference = "Stop"
$script:TestResults = @()
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0
$script:CriticalFailures = @()

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = "",
        [bool]$Critical = $false
    )
    
    $script:TotalTests++
    if ($Passed) {
        $script:PassedTests++
        $color = "Green"
        $status = "PASS"
    } else {
        $script:FailedTests++
        $color = "Red"
        $status = "FAIL"
        if ($Critical) {
            $script:CriticalFailures += "${TestName}: ${Message}"
        }
    }
    
    $result = @{
        TestName = $TestName
        Passed = $Passed
        Message = $Message
        Critical = $Critical
        Timestamp = Get-Date
    }
    $script:TestResults += $result
    
    Write-Host "[$status] $TestName" -ForegroundColor $color
    if ($Message -and $Verbose) {
        Write-Host "  $Message" -ForegroundColor Gray
    }
    if (-not $Passed -and $Critical) {
        Write-Host "  CRITICAL: $Message" -ForegroundColor Red
        if ($FailFast) {
            throw "Critical test failed: $TestName"
        }
    }
}

function Test-CmdFileExists {
    Write-Host "`n=== TEST 1: CMD File Existence ===" -ForegroundColor Cyan
    
    $cmdPath = Join-Path $PSScriptRoot "RunMiracleBoot.cmd"
    $exists = Test-Path $cmdPath -ErrorAction SilentlyContinue
    
    Write-TestResult -TestName "RunMiracleBoot.cmd exists" -Passed $exists -Message "Path: $cmdPath" -Critical $true
    
    return $exists
}

function Test-CmdFileEncoding {
    Write-Host "`n=== TEST 2: CMD File Encoding ===" -ForegroundColor Cyan
    
    $cmdPath = Join-Path $PSScriptRoot "RunMiracleBoot.cmd"
    $content = Get-Content $cmdPath -Raw -ErrorAction SilentlyContinue
    
    # Check for BOM (should not have UTF-8 BOM for batch files)
    $bytes = [System.IO.File]::ReadAllBytes($cmdPath)
    $hasBOM = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    
    Write-TestResult -TestName "CMD file has no BOM" -Passed (-not $hasBOM) -Message "BOM detected: $hasBOM" -Critical $true
    
    # Check for CRLF line endings (required for batch files)
    $hasCRLF = $content -match "`r`n"
    Write-TestResult -TestName "CMD file has CRLF line endings" -Passed $hasCRLF -Message "CRLF detected: $hasCRLF"
    
    return (-not $hasBOM -and $hasCRLF)
}

function Test-CmdFileSyntax {
    Write-Host "`n=== TEST 3: CMD File Syntax Validation ===" -ForegroundColor Cyan
    
    $cmdPath = Join-Path $PSScriptRoot "RunMiracleBoot.cmd"
    $content = Get-Content $cmdPath -Raw
    
    $issues = @()
    
    # Remove comment lines and echo text for accurate parenthesis counting
    $lines = $content -split "`r?`n"
    $codeLines = @()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        # Skip REM comments
        if ($trimmed -match '^\s*REM\s') {
            continue
        }
        # Skip echo statements (they may contain parentheses in text like "echo 1)")
        if ($trimmed -match '^\s*echo\s') {
            continue
        }
        $codeLines += $line
    }
    $codeContent = $codeLines -join "`r`n"
    
    # Check for common batch file syntax issues
    # 1. Unclosed parentheses (in code only, not comments or echo text)
    $openParens = ([regex]::Matches($codeContent, '\(')).Count
    $closeParens = ([regex]::Matches($codeContent, '\)')).Count
    if ($openParens -ne $closeParens) {
        $issues += "Unmatched parentheses in code: $openParens open, $closeParens close"
    }
    
    # 2. Unclosed quotes (check for even number of double quotes)
    $quotes = ([regex]::Matches($content, '"')).Count
    if ($quotes % 2 -ne 0) {
        $issues += "Unmatched quotes: $quotes quotes found (should be even)"
    }
    
    # 3. Check for problematic patterns that cause ". was unexpected"
    # More specific patterns that actually cause issues - only flag unquoted variable expansions
    # Pattern: set VAR=value with %VAR% not in quotes (but allow "VAR=%value%" which is safe)
    if ($codeContent -match 'set\s+[^=]+=\s*[^"]*%[^%]+%[^"]*(?!")') {
        # But exclude if the whole assignment is quoted: set "VAR=value"
        $setLines = [regex]::Matches($codeContent, 'set\s+[^=]+=\s*[^`r`n]+')
        foreach ($match in $setLines) {
            $setLine = $match.Value
            # If line has %VAR% but is not fully quoted, it's a problem
            if ($setLine -match '%[^%]+%' -and $setLine -notmatch '^set\s+"[^"]*%[^"]*"') {
                $issues += "Unquoted variable expansion in set statement: $setLine"
            }
        }
    }
    
    # Pattern: for loop with unquoted paths containing variables
    # This is actually OK if paths in the list are quoted, which they are in our case
    # So we'll skip this check as it's too broad
    
    $passed = $issues.Count -eq 0
    $message = if ($issues.Count -gt 0) { $issues -join "; " } else { "No syntax issues detected" }
    
    Write-TestResult -TestName "CMD file syntax validation" -Passed $passed -Message $message -Critical $true
    
    return $passed
}

function Test-CmdExecution {
    Write-Host "`n=== TEST 4: CMD File Execution Test ===" -ForegroundColor Cyan
    
    $cmdPath = Join-Path $PSScriptRoot "RunMiracleBoot.cmd"
    
    # Test 4a: Dry run (should not actually launch, but should parse correctly)
    Write-Host "  Running dry-run test..." -ForegroundColor Gray
    
    $output = & cmd.exe /c "`"$cmdPath`" --help 2>&1" 2>&1
    $exitCode = $LASTEXITCODE
    
    # Check for ". was unexpected" error specifically
    $unexpectedError = $output -match "\.\s+was\s+unexpected|was\s+unexpected\s+at\s+this\s+time"
    
    if ($unexpectedError) {
        Write-TestResult -TestName "CMD execution - no '. was unexpected' error" -Passed $false -Message "Found '. was unexpected' error in output" -Critical $true
        Write-Host "  ERROR OUTPUT:" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        return $false
    }
    
    # Test 4b: Check if it at least starts (shows banner)
    $showsBanner = $output -match "Miracle Boot|Launcher"
    
    Write-TestResult -TestName "CMD execution - no '. was unexpected' error" -Passed $true -Message "No '. was unexpected' error detected"
    Write-TestResult -TestName "CMD execution - shows banner" -Passed $showsBanner -Message "Banner detected: $showsBanner"
    
    return $true
}

function Test-CmdWithSpacesInPath {
    Write-Host "`n=== TEST 5: CMD Execution with Spaces in Path ===" -ForegroundColor Cyan
    
    # Create a temporary directory with spaces in the name
    $tempDir = Join-Path $env:TEMP "Test Miracle Boot Path"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    try {
        # Copy CMD file to path with spaces
        $sourceCmd = Join-Path $PSScriptRoot "RunMiracleBoot.cmd"
        $destCmd = Join-Path $tempDir "RunMiracleBoot.cmd"
        Copy-Item $sourceCmd $destCmd -Force
        
        # Try to execute it
        $output = & cmd.exe /c "`"$destCmd`" --help 2>&1" 2>&1
        
        # Check for ". was unexpected" error
        $unexpectedError = $output -match "\.\s+was\s+unexpected|was\s+unexpected\s+at\s+this\s+time"
        
        Write-TestResult -TestName "CMD with spaces in path - no '. was unexpected' error" -Passed (-not $unexpectedError) -Message "Error detected: $unexpectedError" -Critical $true
        
        if ($unexpectedError) {
            Write-Host "  ERROR OUTPUT:" -ForegroundColor Red
            Write-Host $output -ForegroundColor Red
        }
        
        return (-not $unexpectedError)
    } finally {
        # Cleanup
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-CmdVariableExpansion {
    Write-Host "`n=== TEST 6: CMD Variable Expansion Safety ===" -ForegroundColor Cyan
    
    $cmdPath = Join-Path $PSScriptRoot "RunMiracleBoot.cmd"
    $content = Get-Content $cmdPath -Raw
    
    $issues = @()
    
    # Check that all paths with variables are properly quoted
    # Pattern: set "VAR=%something%" - should be quoted
    # Pattern: if exist %%~P - should be if exist "%%~P"
    
    # Check for unquoted variable expansions in paths
    if ($content -match 'if\s+exist\s+%%~[^"]+[^"]*\)') {
        $issues += "Found unquoted path in 'if exist' statement"
    }
    
    # Check for unquoted SCRIPT_DIR usage
    if ($content -match '%SCRIPT_DIR%[^"]+[^"]*"') {
        $issues += "Found unquoted SCRIPT_DIR variable expansion"
    }
    
    $passed = $issues.Count -eq 0
    $message = if ($issues.Count -gt 0) { $issues -join "; " } else { "All variable expansions are properly quoted" }
    
    Write-TestResult -TestName "CMD variable expansion safety" -Passed $passed -Message $message -Critical $true
    
    return $passed
}

function Test-CmdDelayedExpansion {
    Write-Host "`n=== TEST 7: CMD Delayed Expansion Usage ===" -ForegroundColor Cyan
    
    $cmdPath = Join-Path $PSScriptRoot "RunMiracleBoot.cmd"
    $content = Get-Content $cmdPath -Raw
    
    # Check if delayed expansion is enabled
    $hasDelayedExpansion = $content -match 'setlocal\s+enabledelayedexpansion'
    
    # Check if variables are accessed with ! instead of % inside loops/blocks
    $usesDelayedExpansion = $content -match '![A-Z_]+\!'
    
    Write-TestResult -TestName "CMD uses delayed expansion" -Passed $hasDelayedExpansion -Message "Delayed expansion enabled: $hasDelayedExpansion" -Critical $true
    Write-TestResult -TestName "CMD uses ! for variable access" -Passed $usesDelayedExpansion -Message "Uses ! syntax: $usesDelayedExpansion"
    
    return ($hasDelayedExpansion -and $usesDelayedExpansion)
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "COMPREHENSIVE TEST PROCEDURE FOR RunMiracleBoot.cmd" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

$allTestsPassed = $true

try {
    # Test 1: File existence
    if (-not (Test-CmdFileExists)) {
        $allTestsPassed = $false
        if ($FailFast) { throw "Critical: CMD file does not exist" }
    }
    
    # Test 2: File encoding
    if (-not (Test-CmdFileEncoding)) {
        $allTestsPassed = $false
        if ($FailFast) { throw "Critical: CMD file encoding issue" }
    }
    
    # Test 3: Syntax validation
    if (-not (Test-CmdFileSyntax)) {
        $allTestsPassed = $false
        if ($FailFast) { throw "Critical: CMD file syntax error" }
    }
    
    # Test 4: Execution test
    if (-not (Test-CmdExecution)) {
        $allTestsPassed = $false
        if ($FailFast) { throw "Critical: CMD execution failed" }
    }
    
    # Test 5: Spaces in path
    if (-not (Test-CmdWithSpacesInPath)) {
        $allTestsPassed = $false
        if ($FailFast) { throw "Critical: CMD fails with spaces in path" }
    }
    
    # Test 6: Variable expansion
    if (-not (Test-CmdVariableExpansion)) {
        $allTestsPassed = $false
        if ($FailFast) { throw "Critical: CMD variable expansion issue" }
    }
    
    # Test 7: Delayed expansion
    if (-not (Test-CmdDelayedExpansion)) {
        $allTestsPassed = $false
        if ($FailFast) { throw "Critical: CMD delayed expansion issue" }
    }
    
} catch {
    Write-Host "`nTEST EXECUTION FAILED: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# ============================================================================
# TEST SUMMARY
# ============================================================================

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests: $script:TotalTests" -ForegroundColor White
Write-Host "Passed: $script:PassedTests" -ForegroundColor Green
Write-Host "Failed: $script:FailedTests" -ForegroundColor $(if ($script:FailedTests -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($script:CriticalFailures.Count -gt 0) {
    Write-Host "CRITICAL FAILURES:" -ForegroundColor Red
    foreach ($failure in $script:CriticalFailures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    Write-Host ""
}

if ($allTestsPassed -and $script:CriticalFailures.Count -eq 0) {
    Write-Host "RESULT: ALL TESTS PASSED" -ForegroundColor Green
    Write-Host "RunMiracleBoot.cmd is ready for production use." -ForegroundColor Green
    exit 0
} else {
    Write-Host "RESULT: TESTS FAILED" -ForegroundColor Red
    Write-Host "RunMiracleBoot.cmd has issues that must be fixed before production." -ForegroundColor Red
    exit 1
}
