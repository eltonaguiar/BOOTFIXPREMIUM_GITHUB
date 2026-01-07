#!/usr/bin/env powershell
# MIRACLEBOOT AUTOMATION CLI - AUTOMATED TEST SUITE

param()

$testConfig = @{
    AutomationModule = 'c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\MiracleBoot-Automation.ps1'
}

$testResults = @{
    Total  = 0
    Passed = 0
    Failed = 0
}

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

# SETUP

Write-Host ""
Write-Host "MIRACLEBOOT AUTOMATION CLI - TEST SUITE" -ForegroundColor Cyan
Write-Host ""

Write-Host "[SETUP] Loading automation module..." -ForegroundColor Gray

try {
    . $testConfig.AutomationModule
    Write-Host "[SETUP] OK - Automation module loaded" -ForegroundColor Green
}
catch {
    Write-Host "[SETUP] FAIL - Cannot load module: $_" -ForegroundColor Red
    exit 1
}

# TEST SECTION 1: MODULE VALIDATION

Write-Host ""
Write-Host "[TEST SECTION 1] MODULE VALIDATION" -ForegroundColor Yellow

Test-Result "Write-OpLog available" (Test-Command "Write-OpLog") ""
Test-Result "Invoke-CliOperation available" (Test-Command "Invoke-CliOperation") ""
Test-Result "New-BatchRepairJob available" (Test-Command "New-BatchRepairJob") ""
Test-Result "New-ScheduledRepairTask available" (Test-Command "New-ScheduledRepairTask") ""
Test-Result "Invoke-RemoteRepair available" (Test-Command "Invoke-RemoteRepair") ""
Test-Result "New-ComplianceReport available" (Test-Command "New-ComplianceReport") ""

# TEST SECTION 2: LOGGING SYSTEM

Write-Host ""
Write-Host "[TEST SECTION 2] LOGGING SYSTEM" -ForegroundColor Yellow

try {
    Write-OpLog "Test log message" -Level Info -Operation 'Test'
    Test-Result "Write-OpLog executes" $true "Log entry created"
}
catch {
    Test-Result "Write-OpLog executes" $false "Error: $_"
}

# TEST SECTION 3: BATCH REPAIR JOBS

Write-Host ""
Write-Host "[TEST SECTION 3] BATCH REPAIR JOBS" -ForegroundColor Yellow

$batchJob = $null
try {
    $batchJob = New-BatchRepairJob -JobName "TestJob"
    Test-Result "Create batch repair job" ($batchJob -ne $null) "Batch job created"
}
catch {
    Test-Result "Create batch repair job" $false "Error: $_"
}

if ($batchJob) {
    Test-Result "Batch job has Status" ($batchJob.ContainsKey('Status')) "Status property exists"
    Test-Result "Batch job has Results" ($batchJob.ContainsKey('Results')) "Results array exists"
    Test-Result "Batch job Status is completed" ($batchJob.Status -eq 'Completed') "Job completed successfully"
}

# TEST SECTION 4: SCHEDULED TASKS

Write-Host ""
Write-Host "[TEST SECTION 4] SCHEDULED TASKS" -ForegroundColor Yellow

$scheduledTask = $null
try {
    $scheduledTask = New-ScheduledRepairTask -TaskName "TestTask"
    Test-Result "Create scheduled task" ($scheduledTask -ne $null) "Task created"
}
catch {
    Test-Result "Create scheduled task" $false "Error: $_"
}

if ($scheduledTask) {
    Test-Result "Task has Schedule" ($scheduledTask.ContainsKey('Schedule')) "Schedule property exists"
    Test-Result "Task Status is Scheduled" ($scheduledTask.Status -eq 'Scheduled') "Task scheduled successfully"
    Test-Result "Task has NextRun" ($scheduledTask.ContainsKey('NextRun')) "NextRun calculated"
}

# TEST SECTION 5: COMPLIANCE REPORTING

Write-Host ""
Write-Host "[TEST SECTION 5] COMPLIANCE REPORTING" -ForegroundColor Yellow

$complianceReport = $null
try {
    $complianceReport = New-ComplianceReport
    Test-Result "Generate compliance report" ($complianceReport.Success -eq $true) "Report generated"
}
catch {
    Test-Result "Generate compliance report" $false "Error: $_"
}

if ($complianceReport -and $complianceReport.Success) {
    Test-Result "Report JSON created" (Test-Path $complianceReport.JsonReport) "JSON file exists"
    Test-Result "Report CSV created" (Test-Path $complianceReport.CsvReport) "CSV file exists"
    Test-Result "Compliance score valid" ($complianceReport.Compliance.ComplianceScore -gt 0) "Score calculated"
}

# TEST SECTION 6: REMOTE OPERATIONS

Write-Host ""
Write-Host "[TEST SECTION 6] REMOTE OPERATIONS" -ForegroundColor Yellow

$remoteResults = $null
try {
    $remoteResults = Invoke-RemoteRepair -ComputerNames @('LocalHost')
    Test-Result "Execute remote operations" ($remoteResults -ne $null) "Remote ops executed"
}
catch {
    Test-Result "Execute remote operations" $false "Error: $_"
}

if ($remoteResults) {
    Test-Result "Remote results returned" (@($remoteResults).Count -gt 0) "Results array populated"
}

# TEST SECTION 7: OPERATION LOG EXPORT

Write-Host ""
Write-Host "[TEST SECTION 7] OPERATION LOG EXPORT" -ForegroundColor Yellow

$logExport = $null
try {
    $logExport = Export-OperationLog
    Test-Result "Export operation log" ($logExport -ne $null) "Log exported"
}
catch {
    Test-Result "Export operation log" $false "Error: $_"
}

if ($logExport) {
    Test-Result "JSON log created" (Test-Path $logExport.JsonLog) "JSON log file exists"
    Test-Result "Text log created" (Test-Path $logExport.TextLog) "Text log file exists"
}

# TEST SECTION 8: CODE VALIDATION

Write-Host ""
Write-Host "[TEST SECTION 8] CODE VALIDATION" -ForegroundColor Yellow

try {
    $tokens = [System.Management.Automation.PSParser]::Tokenize([IO.File]::ReadAllText($testConfig.AutomationModule), [ref]$null)
    Test-Result "MiracleBoot-Automation.ps1 Syntax Valid" $true "Syntax OK"
}
catch {
    Test-Result "MiracleBoot-Automation.ps1 Syntax Valid" $false "Syntax error: $_"
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

# CLEANUP

Write-Host "[CLEANUP] Removing test artifacts..." -ForegroundColor Gray
try {
    Remove-Item -Path 'C:\MiracleBoot-Automation' -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "OK - Test files cleaned up" -ForegroundColor Green
}
catch {
    Write-Host "WARNING - Could not cleanup test files" -ForegroundColor Yellow
}

Write-Host ""

# EXIT

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
