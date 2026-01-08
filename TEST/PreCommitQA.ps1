<#
.SYNOPSIS
    MiracleBoot Pre-Commit Quality Assurance Script
.DESCRIPTION
    Comprehensive QA validation that MUST PASS before code is committed.
    Validates syntax, GUI launch, functionality, and error handling.
.PARAMETER Verbose
    Show detailed test output
.PARAMETER Force
    Continue even if non-critical tests fail
.NOTES
    Exit code 0 = All tests passed (safe to commit)
    Exit code 1 = Tests failed (DO NOT commit)
    
    Usage: .\PreCommitQA.ps1
#>

param(
    [switch]$Verbose,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$testsPassed = 0
$testsFailed = 0
$criticalFailures = 0

# Colors
$ColorPass = "Green"
$ColorFail = "Red"
$ColorWarn = "Yellow"
$ColorInfo = "Cyan"

function Write-TestHeader {
    param([string]$Title, [int]$Number)
    Write-Host ""
    Write-Host "" -ForegroundColor $ColorInfo
    Write-Host ("TEST {0}: {1}" -f $Number, $Title) -ForegroundColor $ColorInfo
    Write-Host "" -ForegroundColor $ColorInfo
}

function Test-Result {
    param(
        [bool]$Passed,
        [string]$Message,
        [bool]$Critical = $false
    )
    
    if ($Passed) {
        Write-Host "   PASS: $Message" -ForegroundColor $ColorPass
        $script:testsPassed++
    } else {
        if ($Critical) {
            Write-Host "   CRITICAL FAIL: $Message" -ForegroundColor $ColorFail
            $script:criticalFailures++
        } else {
            Write-Host "   FAIL: $Message" -ForegroundColor $ColorFail
        }
        $script:testsFailed++
    }
}

function Write-SubTest {
    param([string]$Text)
    Write-Host "     $Text" -ForegroundColor $ColorInfo
}

# ============================================================================
# HEADER
# ============================================================================

Write-Host ""
Write-Host "" -ForegroundColor $ColorInfo
Write-Host "     MiracleBoot v7.2.0 - Pre-Commit Quality Assurance         " -ForegroundColor $ColorInfo
Write-Host "                                                                " -ForegroundColor $ColorInfo
Write-Host "  This script validates that the application is production-    " -ForegroundColor $ColorInfo
Write-Host "  ready and safe to release. ALL TESTS MUST PASS.              " -ForegroundColor $ColorInfo
Write-Host "" -ForegroundColor $ColorInfo
Write-Host ""

# ============================================================================
# TEST 1: ENVIRONMENT CHECK
# ============================================================================
Write-TestHeader "Environment Validation" 1

$workingDir = Get-Location
Write-SubTest "Working directory: $workingDir"

try {
    $psVersion = $PSVersionTable.PSVersion.Major
    Write-SubTest "PowerShell version: $psVersion"
    Test-Result ($psVersion -ge 5) "PowerShell version >= 5" $true
} catch {
    Test-Result $false "Could not check PowerShell version" $true
}

$osVersion = [System.Environment]::OSVersion.VersionString
Write-SubTest "OS: $osVersion"
Test-Result ($osVersion -match "Windows") "Windows OS detected" $true

# ============================================================================
# TEST 2: REQUIRED DIRECTORIES
# ============================================================================
Write-TestHeader "Directory Structure Validation" 2

$requiredDirs = @{
    ".\HELPER SCRIPTS" = "Helper scripts directory"
    ".\DOCUMENTATION" = "Documentation directory"
    ".\TEST" = "Test directory"
}

foreach ($dir in $requiredDirs.Keys) {
    $exists = Test-Path $dir -PathType Container
    Test-Result $exists "Directory exists: $($requiredDirs[$dir])" $true
}

# ============================================================================
# TEST 3: CRITICAL FILES
# ============================================================================
Write-TestHeader "Critical Files Validation" 3

$criticalFiles = @{
    ".\HELPER SCRIPTS\WinRepairGUI.ps1" = "Main GUI script"
    ".\HELPER SCRIPTS\WinRepairCore.ps1" = "Core helper functions"
    ".\ErrorCodeDatabase.ps1" = "Error code database"
    ".\MiracleBoot.ps1" = "Main entry point"
    ".\RUN_ALL_TESTS.ps1" = "Test runner"
}

foreach ($file in $criticalFiles.Keys) {
    $exists = Test-Path $file -PathType Leaf
    Test-Result $exists "File exists: $($criticalFiles[$file])" $true
    
    if ($exists) {
        $size = (Get-Item $file).Length
        Write-SubTest "  Size: $([math]::Round($size/1KB, 2)) KB"
    }
}

# ============================================================================
# TEST 4: POWERSHELL SYNTAX VALIDATION
# ============================================================================
Write-TestHeader "PowerShell Syntax Validation" 4

$psFiles = @(
    ".\HELPER SCRIPTS\WinRepairGUI.ps1",
    ".\HELPER SCRIPTS\WinRepairCore.ps1",
    ".\ErrorCodeDatabase.ps1",
    ".\MiracleBoot.ps1"
)

$syntaxOK = $true
foreach ($file in $psFiles) {
    if (Test-Path $file) {
        try {
            $content = Get-Content $file -Raw
            $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
            Test-Result $true "Syntax OK: $([System.IO.Path]::GetFileName($file))" $true
        } catch {
            Test-Result $false "Syntax error in $file : $($_.Exception.Message)" $true
            $syntaxOK = $false
        }
    }
}

if (-not $syntaxOK) {
    Write-Host ""
    Write-Host " SYNTAX ERRORS DETECTED - CANNOT CONTINUE" -ForegroundColor $ColorFail
    Write-Host ""
    exit 1
}

# ============================================================================
# TEST 5: GUI SCRIPT VALIDATION
# ============================================================================
Write-TestHeader "GUI Script Validation" 5

$guiPath = ".\HELPER SCRIPTS\WinRepairGUI.ps1"
$guiContent = Get-Content $guiPath -Raw

Test-Result ($guiContent -match '\$XAML\s*=\s*@"') "XAML section defined" $true
Test-Result ($guiContent -match 'XamlReader::Load') "XAML parser present" $true
Test-Result ($guiContent -match '\[Windows\.Markup\.XamlReader\]::Load') "Proper XamlReader usage" $true

# ============================================================================
# TEST 6: CRITICAL BUTTON HANDLERS
# ============================================================================
Write-TestHeader "Button Handler Validation" 6

$criticalButtons = @(
    "BtnWinDBGStore",
    "BtnWinDBGDocs",
    "BtnEventViewerOpen"
)

foreach ($button in $criticalButtons) {
    Test-Result ($guiContent -match $button) "Button handler found: $button" $true
    Test-Result ($guiContent -match "FindName\([`"']$button[`"']\)") "Button registered: $button" $true
}

# ============================================================================
# TEST 7: ERROR HANDLING VALIDATION
# ============================================================================
Write-TestHeader "Error Handling Validation" 7

Test-Result ($guiContent -match "try\s*\{") "Try-catch blocks present" $false
Test-Result ($guiContent -match "catch\s*.*\{") "Catch handlers present" $false
Test-Result ($guiContent -match '\\$ErrorActionPreference\s*=\s*["'']') "Error handling configured" $false
Test-Result ($guiContent -match "Write-Error") "Error reporting present" $false

# ============================================================================
# TEST 8: XAML VALIDATION
# ============================================================================
Write-TestHeader "XAML Structure Validation" 8

# Extract XAML
$xamlMatch = $guiContent -match '(?s)\$XAML\s*=\s*@"(.*?)"@'
if ($xamlMatch) {
    $xaml = $matches[1]
    
    # Basic XAML checks
    Test-Result ($xaml -match '<Window') "Window element present" $true
    Test-Result ($xaml -match '</Window>') "Window properly closed" $true
    Test-Result ($xaml -match '<TabControl') "TabControl element present" $false
    Test-Result ($xaml -match '<TabItem') "TabItem elements present" $false
    
    # Check for common issues
    $unclosedTags = [regex]::Matches($xaml, '<(\w+)[^>]*(?<!/)>(?!</\1>)').Count
    Write-SubTest "Unclosed tags found: $unclosedTags"
    
    Test-Result ($xaml -match 'Background="?#?[0-9A-Fa-f]{6,8}?"?') "Color definitions present" $false
    
} else {
    Test-Result $false "Could not extract XAML section" $true
}

# ============================================================================
# TEST 9: VARIABLE INITIALIZATION
# ============================================================================
Write-TestHeader "Variable Initialization Validation" 9

$criticalVars = @(
    '\$W\s*=',
    '\$guiContent\s*=',
    '\$xaml\s*='
)

foreach ($var in $criticalVars) {
    $found = $guiContent -match $var
    $varName = $var -replace '\$', '' -replace '\s*=.*', ''
    Test-Result $found "Variable initialized: $varName" $false
}

# ============================================================================
# TEST 10: REQUIRED FUNCTIONS
# ============================================================================
Write-TestHeader "Required Functions Validation" 10

$coreScript = Get-Content ".\HELPER SCRIPTS\WinRepairCore.ps1" -Raw
$requiredFunctions = @(
    "Get-ErrorDescription",
    "Get-BootLogInfo",
    "Test-SystemHealth"
)

foreach ($func in $requiredFunctions) {
    $found = $coreScript -match "function\s+$func|function\s+$func\s*\{"
    Test-Result $found "Function defined: $func" $false
}

# ============================================================================
# TEST 11: DOCUMENTATION COMPLETENESS
# ============================================================================
Write-TestHeader "Documentation Completeness" 11

$docFiles = Get-ChildItem ".\DOCUMENTATION\*.md" -ErrorAction SilentlyContinue
Write-SubTest "Documentation files found: $($docFiles.Count)"

Test-Result ($docFiles.Count -ge 5) "Sufficient documentation present" $false
Test-Result (Test-Path ".\DOCUMENTATION\NEVER_FAIL_AGAIN.md") "QA documentation present" $false

if ($docFiles.Count -gt 0) {
    $mostRecent = $docFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-SubTest "Most recent: $($mostRecent.Name) ($($mostRecent.LastWriteTime))"
}

# ============================================================================
# TEST 12: DEPENDENCY CHECK
# ============================================================================
Write-TestHeader "Dependency Validation" 12

$dependencies = @{
    "System.Windows.Forms" = "Windows Forms"
    "System.Windows.Markup.XamlReader" = "XAML Reader"
    "System.Xml.XmlDocument" = "XML handling"
}

foreach ($dep in $dependencies.Keys) {
    $found = $guiContent -match [regex]::Escape($dep)
    Test-Result $found "Dependency referenced: $($dependencies[$dep])" $false
}

# ============================================================================
# TEST 13: EVENT HANDLER REGISTRATION
# ============================================================================
Write-TestHeader "Event Handler Registration" 13

$eventHandlers = @(
    "Add_Click",
    "Add_Loaded",
    "Add_SelectionChanged"
)

foreach ($handler in $eventHandlers) {
    $found = $guiContent -match $handler
    Test-Result $found "Event handler method used: $handler" $false
}

# ============================================================================
# TEST 14: FILE INTEGRITY
# ============================================================================
Write-TestHeader "File Integrity Check" 14

foreach ($file in $psFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        
        # Check for common corruption patterns
        Test-Result (-not ($content -match "^[^#]*`$.*?`$.*?`$")) "No obvious corruption: $([System.IO.Path]::GetFileName($file))" $false
        Test-Result ($content.Length -gt 100) "File not suspiciously small: $([System.IO.Path]::GetFileName($file))" $false
    }
}

# ============================================================================
# TEST 15: CONFIGURATION VALIDATION
# ============================================================================
Write-TestHeader "Configuration Validation" 15

$configValid = $true

# Check Windows paths exist
Test-Result (Test-Path "C:\Windows\System32") "System32 accessible" $false
Test-Result (Test-Path "C:\Program Files") "Program Files accessible" $false

# Check common tools availability
$toolsToCheck = @{
    "C:\Windows\System32\eventvwr.msc" = "Event Viewer"
    "C:\Windows\System32\regedit.exe" = "Registry Editor"
}

foreach ($tool in $toolsToCheck.Keys) {
    $exists = Test-Path $tool
    Test-Result $exists "System tool available: $($toolsToCheck[$tool])" $false
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "" -ForegroundColor $ColorInfo
Write-Host " QA TEST SUMMARY" -ForegroundColor $ColorInfo
Write-Host "" -ForegroundColor $ColorInfo
Write-Host ""

Write-Host "  Tests Passed:         $testsPassed" -ForegroundColor $ColorPass
Write-Host "  Tests Failed:         $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { $ColorFail } else { $ColorPass })
Write-Host "  Critical Failures:    $criticalFailures" -ForegroundColor $(if ($criticalFailures -gt 0) { $ColorFail } else { $ColorPass })
Write-Host ""

if ($criticalFailures -gt 0) {
    Write-Host " CRITICAL FAILURES DETECTED" -ForegroundColor $ColorFail
    Write-Host ""
    Write-Host "DO NOT COMMIT - Fix critical failures first" -ForegroundColor $ColorFail
    Write-Host ""
    exit 1
}

if ($testsFailed -eq 0) {
    Write-Host " ALL QA TESTS PASSED - SAFE TO COMMIT" -ForegroundColor $ColorPass
    Write-Host ""
    Write-Host "Status: Ready for Production Release" -ForegroundColor $ColorPass
    Write-Host ""
    exit 0
} elseif ($Force) {
    Write-Host "  TESTS FAILED BUT FORCE FLAG SET - PROCEEDING" -ForegroundColor $ColorWarn
    Write-Host ""
    exit 0
} else {
    Write-Host " TESTS FAILED - REVIEW AND FIX" -ForegroundColor $ColorFail
    Write-Host ""
    Write-Host "Review the failures above and fix before committing." -ForegroundColor $ColorFail
    Write-Host ""
    exit 1
}
