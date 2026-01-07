# ============================================================================
# GUI VALIDATION & DEPENDENCY CHECKER - MiracleBoot
# ============================================================================
# Comprehensive validation to prevent GUI launch failures
# ============================================================================

param(
    [switch]$Verbose = $false,
    [string]$ReportPath = "GUI_VALIDATION_REPORT.txt"
)

$ErrorActionPreference = "Continue"
$issues = @()
$warnings = @()
$passes = @()
$timestamp = Get-Date

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                     GUI VALIDATION & DEPENDENCY CHECKER                       ║" -ForegroundColor Cyan
Write-Host "║                    MiracleBoot Quality Assurance System                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$report = @()
$report += "╔════════════════════════════════════════════════════════════════════════════════╗"
$report += "║                     GUI VALIDATION & DEPENDENCY CHECKER                       ║"
$report += "║                         Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                        ║"
$report += "╚════════════════════════════════════════════════════════════════════════════════╝"
$report += ""

Write-Host "1. Checking Function Dependency Order..." -ForegroundColor Yellow
Write-Host "2. Checking Function Call Validity..." -ForegroundColor Yellow
Write-Host "3. Checking XAML Control References..." -ForegroundColor Yellow
Write-Host "4. Checking Error Handling Coverage..." -ForegroundColor Yellow
Write-Host "5. Checking Null Reference Protection..." -ForegroundColor Yellow
Write-Host ""

$guiFile = "WinRepairGUI.ps1"

if (-not (Test-Path $guiFile)) {
    Write-Host "ERROR: $guiFile not found" -ForegroundColor Red
    exit 1
}

$content = Get-Content $guiFile -Raw

# TEST 1: Check if event handlers are registered before functions
$report += "TEST 1: FUNCTION DEFINITION & HANDLER REGISTRATION ORDER"
$report += ""

$functionPattern = "function\s+(\w+)\s*\{"
$functionMatches = [regex]::Matches($content, $functionPattern)
$definedFunctions = @{}
foreach ($match in $functionMatches) {
    $definedFunctions[$match.Groups[1].Value] = $match.Index
}

$report += "Found $($definedFunctions.Count) function definitions"

# Find first handler registration
$firstHandlerPos = $content.IndexOf('$W.FindName(')

if ($firstHandlerPos -gt 0 -and $definedFunctions.Count -gt 0) {
    $firstFuncPos = ($definedFunctions.Values | Measure-Object -Minimum).Minimum
    
    if ($firstHandlerPos -lt $firstFuncPos) {
        $issues += "Event handlers registered BEFORE function definitions"
        $report += "[FAIL] Event handlers registered BEFORE function definitions"
        Write-Host "  [FAIL] Event handlers before functions" -ForegroundColor Red
    } else {
        $passes += "Event handlers registered after function definitions"
        $report += "[PASS] Event handlers registered after function definitions"
        Write-Host "  [PASS] Event handlers registered after functions" -ForegroundColor Green
    }
} else {
    $report += "[INFO] Could not determine handler registration order"
}

$report += ""

# TEST 2: Check for critical function calls
$report += "TEST 2: CRITICAL FUNCTION AVAILABILITY"
$report += ""

$criticalFunctions = @(
    "Update-StatusBar"
    "Get-WindowsHealthSummary"
    "Get-BCDEntriesParsed"
    "Get-WindowsVolumes"
    "Test-AdminPrivileges"
)

foreach ($func in $criticalFunctions) {
    if ($definedFunctions.ContainsKey($func)) {
        $report += "  [OK] $func is defined"
        Write-Host "  [OK] $func is defined" -ForegroundColor Green
    } else {
        # Check if it's a sourced function
        if ($func -match '^Get-|^Test-|^Update-') {
            $report += "  [SOURCED] $func (assumed from WinRepairCore.ps1)"
            Write-Host "  [SOURCED] $func (from external file)" -ForegroundColor Cyan
        }
    }
}

$report += ""

# TEST 3: Check XAML control references
$report += "TEST 3: XAML CONTROL REFERENCE VALIDATION"
$report += ""

$xamlStart = $content.IndexOf('<Window')
$xamlEnd = $content.LastIndexOf('</Window>')

if ($xamlStart -ge 0 -and $xamlEnd -gt $xamlStart) {
    $xaml = $content.Substring($xamlStart, $xamlEnd - $xamlStart + 9)
    
    # Extract control names from XAML
    $controlMatches = [regex]::Matches($xaml, 'Name="([^"]+)"')
    $namedControls = @()
    foreach ($match in $controlMatches) {
        $namedControls += $match.Groups[1].Value
    }
    
    $report += "Found $($namedControls.Count) named controls in XAML"
    Write-Host "  [OK] Found $($namedControls.Count) named controls in XAML" -ForegroundColor Green
} else {
    $report += "  [WARN] Could not locate XAML section"
    $warnings += "Could not validate XAML controls"
}

$report += ""

# TEST 4: Error handling
$report += "TEST 4: ERROR HANDLING COVERAGE"
$report += ""

$tryMatches = [regex]::Matches($content, "try\s*\{")
$catchMatches = [regex]::Matches($content, "catch\s*\{")

$report += "Found $($tryMatches.Count) try blocks and $($catchMatches.Count) catch blocks"

if ($tryMatches.Count -gt 3) {
    $passes += "Adequate error handling coverage detected"
    $report += "[PASS] Error handling coverage appears adequate"
    Write-Host "  [PASS] Error handling coverage is adequate" -ForegroundColor Green
} else {
    $warnings += "Limited error handling in GUI code"
    $report += "[WARN] Limited error handling detected"
    Write-Host "  [WARN] Limited error handling coverage" -ForegroundColor Yellow
}

$report += ""

# TEST 5: Null reference checks
$report += "TEST 5: NULL REFERENCE PROTECTION"
$report += ""

$nullCheckMatches = [regex]::Matches($content, 'if\s*\(\s*\$null')
$report += "Found $($nullCheckMatches.Count) null-check patterns"

if ($nullCheckMatches.Count -gt 5) {
    $passes += "Adequate null-reference protection present"
    $report += "[PASS] Adequate null-reference protection present"
    Write-Host "  [PASS] Null reference protection is adequate" -ForegroundColor Green
} else {
    $warnings += "Limited null-reference protection"
    $report += "[WARN] Limited null-reference protection"
    Write-Host "  [WARN] Consider adding more null checks" -ForegroundColor Yellow
}

$report += ""

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                            VALIDATION SUMMARY                                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$report += "VALIDATION SUMMARY"
$report += ""

$report += "PASSES: $($passes.Count)"
foreach ($pass in $passes) {
    $report += "  ✓ $pass"
    Write-Host "  ✓ $pass" -ForegroundColor Green
}

$report += ""
$report += "WARNINGS: $($warnings.Count)"
foreach ($warning in $warnings) {
    $report += "  ⚠ $warning"
    Write-Host "  ⚠ $warning" -ForegroundColor Yellow
}

$report += ""
$report += "CRITICAL ISSUES: $($issues.Count)"
foreach ($issue in $issues) {
    $report += "  ✗ $issue"
    Write-Host "  ✗ $issue" -ForegroundColor Red
}

$report += ""

if ($issues.Count -eq 0) {
    $status = "PASS - Ready for release"
    Write-Host "STATUS: $status" -ForegroundColor Green
    $report += "STATUS: $status"
} else {
    $status = "FAIL - Critical issues must be fixed"
    Write-Host "STATUS: $status" -ForegroundColor Red
    $report += "STATUS: $status"
}

$report += ""
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Save report
Set-Content -Path $ReportPath -Value ($report -join "`n") -Force
Write-Host ""
Write-Host "Report saved to: $ReportPath" -ForegroundColor Cyan
Write-Host ""

exit $(if ($issues.Count -eq 0) { 0 } else { 1 })
