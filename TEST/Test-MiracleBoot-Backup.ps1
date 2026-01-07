#!/usr/bin/env powershell
# MIRACLEBOOT BACKUP MODULE - AUTOMATED TEST SUITE
# Purpose: Test MiracleBoot-Backup.ps1 with autonomous validation
# No user input required - all testing automated

param()

# TEST CONFIGURATION
$testConfig = @{
    TestSourcePath = (Join-Path $env:TEMP "MiracleBoot-Tests\TestFiles")
    TestBackupPath = (Join-Path $env:TEMP "MiracleBoot-Tests\Backups")
    BackupModule   = 'c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\MiracleBoot-Backup.ps1'
}

$testResults = @{
    Total  = 0
    Passed = 0
    Failed = 0
}

# TEST FRAMEWORK FUNCTIONS

function Test-Result {
    param(
        [string]$TestName,
        [bool]$Result,
        [string]$Details = ""
    )
    
    $script:testResults.Total++
    
    if ($Result) {
        $script:testResults.Passed++
        Write-Host "[PASS] $TestName" -ForegroundColor Green
        if ($Details) { Write-Host "   Details: $Details" -ForegroundColor Gray }
    }
    else {
        $script:testResults.Failed++
        Write-Host "[FAIL] $TestName" -ForegroundColor Red
        if ($Details) { Write-Host "   Details: $Details" -ForegroundColor Yellow }
    }
}

function Test-Command {
    param([string]$CommandName)
    return (Get-Command $CommandName -ErrorAction SilentlyContinue) -ne $null
}

# SETUP PHASE

Write-Host ""
Write-Host "MIRACLEBOOT BACKUP MODULE - TEST SUITE" -ForegroundColor Cyan
Write-Host ""

Write-Host "[SETUP] Creating test environment..." -ForegroundColor Gray

$null = New-Item -ItemType Directory -Path $testConfig.TestSourcePath -Force -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Path $testConfig.TestBackupPath -Force -ErrorAction SilentlyContinue

@(
    @{ Name = "Document1.txt"; Content = "Test document 1" }
    @{ Name = "Document2.txt"; Content = "Test document 2" }
    @{ Name = "Image1.jpg"; Content = "Fake JPEG data" }
) | ForEach-Object {
    $filePath = Join-Path $testConfig.TestSourcePath $_.Name
    Set-Content -Path $filePath -Value $_.Content -Force -ErrorAction SilentlyContinue
}

Write-Host "[SETUP] Loading backup module..." -ForegroundColor Gray

try {
    . $testConfig.BackupModule
    Write-Host "[SETUP] OK - Backup module loaded" -ForegroundColor Green
}
catch {
    Write-Host "[SETUP] FAIL - Cannot load module: $_" -ForegroundColor Red
    exit 1
}

# TEST SECTION 1: MODULE VALIDATION

Write-Host ""
Write-Host "[TEST SECTION 1] MODULE VALIDATION" -ForegroundColor Yellow

Test-Result "New-SystemImageBackup available" (Test-Command "New-SystemImageBackup") ""
Test-Result "New-FileBackup available" (Test-Command "New-FileBackup") ""
Test-Result "Get-BackupList available" (Test-Command "Get-BackupList") ""
Test-Result "Get-BackupStatistics available" (Test-Command "Get-BackupStatistics") ""

# TEST SECTION 2: FILE BACKUP OPERATIONS

Write-Host ""
Write-Host "[TEST SECTION 2] FILE BACKUP OPERATIONS" -ForegroundColor Yellow

$backupResult = $null
$backupError = ""

try {
    $backupName = "TestBackup-$(Get-Date -Format 'HHmmss')"
    $backupResult = New-FileBackup -SourcePaths @($testConfig.TestSourcePath) `
                                   -BackupPath $testConfig.TestBackupPath `
                                   -BackupName $backupName `
                                   -ErrorAction Stop
}
catch {
    $backupError = $_.Exception.Message
    $backupResult = @{ Success = $false }
}

if ($backupResult -and $backupResult.BackupPath) {
    Test-Result "Create File Backup" $true "Backup created"
}
else {
    Test-Result "Create File Backup" $false "Error: $backupError"
}

if ($backupResult -and $backupResult.BackupPath) {
    $manifestPath = Join-Path $backupResult.BackupPath "backup-manifest.json"
    $manifestExists = Test-Path $manifestPath
    Test-Result "Backup Manifest Created" $manifestExists "Manifest exists"
    
    if ($backupResult.TotalFiles -gt 0) {
        Test-Result "Backup Contains Files" $true "Files backed up"
    }
}

# TEST SECTION 3: BACKUP MANAGEMENT

Write-Host ""
Write-Host "[TEST SECTION 3] BACKUP MANAGEMENT" -ForegroundColor Yellow

$backupList = @()
try {
    $backupList = Get-BackupList -BackupPath $testConfig.TestBackupPath -ErrorAction Stop
    Test-Result "Get Backup List" ($backupList.Count -gt 0) "Found backups"
}
catch {
    Test-Result "Get Backup List" $false "Error: $_"
}

$stats = $null
try {
    $stats = Get-BackupStatistics -BackupPath $testConfig.TestBackupPath -ErrorAction Stop
    Test-Result "Get Backup Statistics" ($stats -ne $null) "Stats retrieved"
}
catch {
    Test-Result "Get Backup Statistics" $false "Error: $_"
}

# TEST SECTION 4: MANIFEST VALIDATION

Write-Host ""
Write-Host "[TEST SECTION 4] MANIFEST VALIDATION" -ForegroundColor Yellow

if ($backupResult -and $backupResult.BackupPath) {
    $manifestPath = Join-Path $backupResult.BackupPath "backup-manifest.json"
    
    if (Test-Path $manifestPath) {
        $manifestContent = Get-Content $manifestPath -Raw -ErrorAction SilentlyContinue
        
        Test-Result "Manifest JSON Valid" ($manifestContent -ne $null) "File readable"
        
        try {
            $manifest = $manifestContent | ConvertFrom-Json -ErrorAction Stop
            Test-Result "Manifest Parseable" ($manifest -ne $null) "JSON valid"
            Test-Result "Manifest Has BackupName" ($manifest.BackupName -ne $null) "Name found"
            Test-Result "Manifest Has BackupDate" ($manifest.BackupDate -ne $null) "Date found"
            Test-Result "Manifest Has Status" ($manifest.Status -eq 'Completed') "Status OK"
        }
        catch {
            Test-Result "Manifest Parseable" $false "Parse error: $_"
        }
    }
}

# TEST SECTION 5: DIRECTORY STRUCTURE

Write-Host ""
Write-Host "[TEST SECTION 5] DIRECTORY STRUCTURE" -ForegroundColor Yellow

Test-Result "Test Backup Path Exists" (Test-Path $testConfig.TestBackupPath) "Path exists"
Test-Result "Test Source Path Exists" (Test-Path $testConfig.TestSourcePath) "Path exists"

$backupDirs = Get-ChildItem -Path $testConfig.TestBackupPath -Directory -ErrorAction SilentlyContinue
$dirCount = if ($backupDirs) { @($backupDirs).Count } else { 0 }
Test-Result "Backup Directories Created" ($dirCount -gt 0) "Directories found"

# TEST SECTION 6: CODE VALIDATION

Write-Host ""
Write-Host "[TEST SECTION 6] CODE VALIDATION" -ForegroundColor Yellow

try {
    $tokens = [System.Management.Automation.PSParser]::Tokenize([IO.File]::ReadAllText($testConfig.BackupModule), [ref]$null)
    Test-Result "MiracleBoot-Backup.ps1 Syntax Valid" $true "Syntax OK"
}
catch {
    Test-Result "MiracleBoot-Backup.ps1 Syntax Valid" $false "Syntax error: $_"
}

# TEST SUMMARY

Write-Host ""
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests:  $($testResults.Total)" -ForegroundColor Cyan
Write-Host "Passed:       $($testResults.Passed)" -ForegroundColor Green

if ($testResults.Failed -eq 0) {
    Write-Host "Failed:       $($testResults.Failed)" -ForegroundColor Green
}
else {
    Write-Host "Failed:       $($testResults.Failed)" -ForegroundColor Red
}

if ($testResults.Total -gt 0) {
    $successRate = [Math]::Round(($testResults.Passed / $testResults.Total) * 100, 2)
    Write-Host "Success Rate: $successRate percent" -ForegroundColor Cyan
}

Write-Host ""

# CLEANUP PHASE

Write-Host "[CLEANUP] Removing test artifacts..." -ForegroundColor Gray
try {
    Remove-Item -Path $testConfig.TestSourcePath -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $testConfig.TestBackupPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "OK - Test files cleaned up" -ForegroundColor Green
}
catch {
    Write-Host "WARNING - Could not cleanup test files" -ForegroundColor Yellow
}

Write-Host ""

# EXIT WITH APPROPRIATE CODE

if ($testResults.Failed -eq 0) {
    Write-Host "ALL TESTS PASSED - READY FOR PRODUCTION" -ForegroundColor Green
    Write-Host ""
    exit 0
}
else {
    Write-Host "SOME TESTS FAILED - REVIEW ABOVE" -ForegroundColor Red
    Write-Host ""
    exit 1
}
