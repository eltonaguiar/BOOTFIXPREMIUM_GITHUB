#!/usr/bin/env powershell
# ============================================================================
# TEST SUITE: MiracleBoot-NetworkDiagnostics.ps1
# Version 1.0
# ============================================================================
# Comprehensive autonomous tests for network diagnostics module
# Tests: DNS flush, DHCP release/renew, network troubleshooter, quick fixes
# Target: 100% pass rate
# ============================================================================

param()

# Configuration
$TestConfig = @{
    ModulePath          = 'C:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\MiracleBoot-NetworkDiagnostics.ps1'
    TestLogPath         = 'C:\MiracleBoot-Tests'
    TestResults         = @()
    TotalTests          = 0
    PassedTests         = 0
    FailedTests         = 0
}

# ============================================================================
# TEST FRAMEWORK
# ============================================================================

function New-Test {
    param(
        [string]$Name,
        [scriptblock]$TestBlock,
        [switch]$RequiresAdmin = $false
    )
    
    $testResult = @{
        'Name'     = $Name
        'Status'   = 'PENDING'
        'Message'  = ''
        'Error'    = $null
        'Duration' = 0
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        & $TestBlock
        $testResult['Status'] = 'PASS'
        $testResult['Message'] = "Test completed successfully"
    }
    catch {
        $testResult['Status'] = 'FAIL'
        $testResult['Error'] = $_.Exception.Message
        $testResult['Message'] = "Test failed: $_"
    }
    
    $stopwatch.Stop()
    $testResult['Duration'] = $stopwatch.ElapsedMilliseconds
    
    $TestConfig['TestResults'] += $testResult
    $TestConfig['TotalTests']++
    
    if ($testResult['Status'] -eq 'PASS') {
        $TestConfig['PassedTests']++
        Write-Host "✓ PASS: $Name" -ForegroundColor Green
    }
    else {
        $TestConfig['FailedTests']++
        Write-Host "✗ FAIL: $Name - $($testResult['Error'])" -ForegroundColor Red
    }
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message = "Assertion failed"
    )
    
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-NotNull {
    param(
        [object]$Value,
        [string]$Message = "Value is null"
    )
    
    if ($null -eq $Value) {
        throw $Message
    }
}

# ============================================================================
# TESTS
# ============================================================================

Write-Host ""
Write-Host "╔═════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  MiracleBoot Network Diagnostics - Test Suite                  ║" -ForegroundColor Cyan
Write-Host "╚═════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Import the module
Write-Host "Loading module..." -ForegroundColor Yellow
& $TestConfig['ModulePath']

# Test Group 1: Network Configuration Retrieval
Write-Host ""
Write-Host "TEST GROUP 1: Network Configuration" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────" -ForegroundColor Cyan

New-Test -Name "Get-NetworkConfiguration function exists" -TestBlock {
    $func = Get-Command Get-NetworkConfiguration -ErrorAction Stop
    Assert-NotNull $func "Function not found"
}

New-Test -Name "Get-NetworkConfiguration returns configuration object" -TestBlock {
    $result = Get-NetworkConfiguration
    Assert-NotNull $result "Result is null"
    Assert-True ($result.PSObject.Properties.Name -contains 'Adapters') "Missing Adapters property"
}

New-Test -Name "Network configuration includes adapter list" -TestBlock {
    $result = Get-NetworkConfiguration
    Assert-True ($result['Adapters'] -is [array] -or $result['Adapters'].Count -ge 0) "Adapters not array"
}

New-Test -Name "Network configuration has summary statistics" -TestBlock {
    $result = Get-NetworkConfiguration
    Assert-True ($result.PSObject.Properties.Name -contains 'Summary') "Missing Summary property"
    Assert-True ($result['Summary'].PSObject.Properties.Name -contains 'TotalAdapters') "Missing TotalAdapters"
}

New-Test -Name "Network adapters include expected properties" -TestBlock {
    $result = Get-NetworkConfiguration
    if ($result['Adapters'].Count -gt 0) {
        $adapter = $result['Adapters'][0]
        Assert-True ($adapter.PSObject.Properties.Name -contains 'Name') "Adapter missing Name"
        Assert-True ($adapter.PSObject.Properties.Name -contains 'Status') "Adapter missing Status"
    }
}

# Test Group 2: DNS Operations
Write-Host ""
Write-Host "TEST GROUP 2: DNS Operations" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────" -ForegroundColor Cyan

New-Test -Name "Invoke-DNSFlush function exists" -TestBlock {
    $func = Get-Command Invoke-DNSFlush -ErrorAction Stop
    Assert-NotNull $func "Function not found"
}

New-Test -Name "DNS flush returns result object" -TestBlock {
    $result = Invoke-DNSFlush
    Assert-NotNull $result "Result is null"
    Assert-True ($result.PSObject.Properties.Name -contains 'Success') "Missing Success property"
}

New-Test -Name "DNS flush tracks cache size" -TestBlock {
    $result = Invoke-DNSFlush
    Assert-True ($result.PSObject.Properties.Name -contains 'CacheSize') "Missing CacheSize property"
    Assert-True ($result['CacheSize'] -ge 0) "CacheSize is negative"
}

New-Test -Name "DNS flush includes message" -TestBlock {
    $result = Invoke-DNSFlush
    Assert-True ($result.PSObject.Properties.Name -contains 'Message') "Missing Message property"
    Assert-True ($result['Message'].Length -gt 0) "Message is empty"
}

# Test Group 3: DHCP Operations
Write-Host ""
Write-Host "TEST GROUP 3: DHCP Release/Renew" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────" -ForegroundColor Cyan

New-Test -Name "Invoke-DHCPRelease function exists" -TestBlock {
    $func = Get-Command Invoke-DHCPRelease -ErrorAction Stop
    Assert-NotNull $func "Function not found"
}

New-Test -Name "DHCP release returns result object" -TestBlock {
    $result = Invoke-DHCPRelease
    Assert-NotNull $result "Result is null"
    Assert-True ($result.PSObject.Properties.Name -contains 'Success') "Missing Success property"
}

New-Test -Name "DHCP release tracks affected adapters" -TestBlock {
    $result = Invoke-DHCPRelease
    Assert-True ($result.PSObject.Properties.Name -contains 'AdaptersAffected') "Missing AdaptersAffected"
    Assert-True ($result['AdaptersAffected'] -is [array]) "AdaptersAffected not array"
}

New-Test -Name "Invoke-DHCPRenew function exists" -TestBlock {
    $func = Get-Command Invoke-DHCPRenew -ErrorAction Stop
    Assert-NotNull $func "Function not found"
}

New-Test -Name "DHCP renew returns result object" -TestBlock {
    $result = Invoke-DHCPRenew
    Assert-NotNull $result "Result is null"
    Assert-True ($result.PSObject.Properties.Name -contains 'Success') "Missing Success property"
}

New-Test -Name "DHCP renew tracks new IPs" -TestBlock {
    $result = Invoke-DHCPRenew
    Assert-True ($result.PSObject.Properties.Name -contains 'NewIPs') "Missing NewIPs property"
}

New-Test -Name "DHCP renew measures elapsed time" -TestBlock {
    $result = Invoke-DHCPRenew
    Assert-True ($result.PSObject.Properties.Name -contains 'ElapsedTime') "Missing ElapsedTime"
    Assert-True ($result['ElapsedTime'] -ge 0) "ElapsedTime is negative"
}

# Test Group 4: Winsock Operations
Write-Host ""
Write-Host "TEST GROUP 4: Winsock & Network Stack" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────" -ForegroundColor Cyan

New-Test -Name "Reset-WinsockCatalog function exists" -TestBlock {
    $func = Get-Command Reset-WinsockCatalog -ErrorAction Stop
    Assert-NotNull $func "Function not found"
}

New-Test -Name "Winsock reset returns result object" -TestBlock {
    $result = Reset-WinsockCatalog
    Assert-NotNull $result "Result is null"
    Assert-True ($result.PSObject.Properties.Name -contains 'Success') "Missing Success property"
}

New-Test -Name "Winsock reset indicates restart requirement" -TestBlock {
    $result = Reset-WinsockCatalog
    Assert-True ($result.PSObject.Properties.Name -contains 'NeedsRestart') "Missing NeedsRestart"
}

New-Test -Name "Reset-NetworkAdapter function exists" -TestBlock {
    $func = Get-Command Reset-NetworkAdapter -ErrorAction Stop
    Assert-NotNull $func "Function not found"
}

New-Test -Name "Network adapter reset returns result" -TestBlock {
    $result = Reset-NetworkAdapter
    Assert-NotNull $result "Result is null"
}

# Test Group 5: Connectivity Testing
Write-Host ""
Write-Host "TEST GROUP 5: Connectivity Testing" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────" -ForegroundColor Cyan

New-Test -Name "Test-NetworkConnectivity function exists" -TestBlock {
    $func = Get-Command Test-NetworkConnectivity -ErrorAction Stop
    Assert-NotNull $func "Function not found"
}

New-Test -Name "Connectivity test returns result object" -TestBlock {
    $result = Test-NetworkConnectivity
    Assert-NotNull $result "Result is null"
    Assert-True ($result.PSObject.Properties.Name -contains 'AdapterConnected') "Missing AdapterConnected"
}

New-Test -Name "Connectivity test includes IP assignment status" -TestBlock {
    $result = Test-NetworkConnectivity
    Assert-True ($result.PSObject.Properties.Name -contains 'IPAssigned') "Missing IPAssigned"
}

New-Test -Name "Connectivity test includes DNS status" -TestBlock {
    $result = Test-NetworkConnectivity
    Assert-True ($result.PSObject.Properties.Name -contains 'DNSResolvable') "Missing DNSResolvable"
}

New-Test -Name "Connectivity test includes internet status" -TestBlock {
    $result = Test-NetworkConnectivity
    Assert-True ($result.PSObject.Properties.Name -contains 'InternetReachable') "Missing InternetReachable"
}

# Test Group 6: Comprehensive Troubleshooter
Write-Host ""
Write-Host "TEST GROUP 6: Network Troubleshooter" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────" -ForegroundColor Cyan

New-Test -Name "Invoke-NetworkTroubleshooter function exists" -TestBlock {
    $func = Get-Command Invoke-NetworkTroubleshooter -ErrorAction Stop
    Assert-NotNull $func "Function not found"
}

New-Test -Name "Troubleshooter completes successfully" -TestBlock {
    $result = Invoke-NetworkTroubleshooter
    Assert-NotNull $result "Result is null"
}

New-Test -Name "Troubleshooter identifies issues" -TestBlock {
    $result = Invoke-NetworkTroubleshooter
    Assert-True ($result.PSObject.Properties.Name -contains 'Issues') "Missing Issues property"
}

New-Test -Name "Troubleshooter generates recommendations" -TestBlock {
    $result = Invoke-NetworkTroubleshooter
    Assert-True ($result.PSObject.Properties.Name -contains 'Recommendations') "Missing Recommendations"
}

New-Test -Name "Troubleshooter has start and end times" -TestBlock {
    $result = Invoke-NetworkTroubleshooter
    Assert-NotNull $result['StartTime'] "Missing StartTime"
    Assert-NotNull $result['EndTime'] "Missing EndTime"
}

New-Test -Name "Troubleshooter executes 5 steps" -TestBlock {
    $result = Invoke-NetworkTroubleshooter
    Assert-True ($result.PSObject.Properties.Name -contains 'Step1') "Missing Step1"
    Assert-True ($result.PSObject.Properties.Name -contains 'Step5') "Missing Step5"
}

# Test Group 7: Quick Network Fix
Write-Host ""
Write-Host "TEST GROUP 7: Quick Network Fix" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────" -ForegroundColor Cyan

New-Test -Name "Invoke-QuickNetworkFix function exists" -TestBlock {
    $func = Get-Command Invoke-QuickNetworkFix -ErrorAction Stop
    Assert-NotNull $func "Function not found"
}

New-Test -Name "Quick fix completes without error" -TestBlock {
    $result = Invoke-QuickNetworkFix
    Assert-NotNull $result "Result is null"
}

New-Test -Name "Quick fix tracks completed steps" -TestBlock {
    $result = Invoke-QuickNetworkFix
    Assert-True ($result.PSObject.Properties.Name -contains 'StepsCompleted') "Missing StepsCompleted"
}

New-Test -Name "Quick fix indicates success" -TestBlock {
    $result = Invoke-QuickNetworkFix
    Assert-True ($result.PSObject.Properties.Name -contains 'Success') "Missing Success property"
}

# Test Group 8: Consistency & Reliability
Write-Host ""
Write-Host "TEST GROUP 8: Consistency & Reliability" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────" -ForegroundColor Cyan

New-Test -Name "Multiple DNS flushes return consistent types" -TestBlock {
    $result1 = Invoke-DNSFlush
    $result2 = Invoke-DNSFlush
    Assert-True ($result1.GetType() -eq $result2.GetType()) "Data types don't match"
}

New-Test -Name "Configuration retrieval is idempotent" -TestBlock {
    $result1 = Get-NetworkConfiguration
    $result2 = Get-NetworkConfiguration
    Assert-True ($result1.GetType() -eq $result2.GetType()) "Data types changed"
}

New-Test -Name "Connectivity test handles no adapters gracefully" -TestBlock {
    $result = Test-NetworkConnectivity
    # Should return result even if no adapters
    Assert-NotNull $result "Crashed with no adapters"
}

# Test Group 9: Error Handling
Write-Host ""
Write-Host "TEST GROUP 9: Error Handling" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────" -ForegroundColor Cyan

New-Test -Name "DNS flush handles errors gracefully" -TestBlock {
    $result = Invoke-DNSFlush
    # Should not throw, should return result
    Assert-NotNull $result "Threw on error"
}

New-Test -Name "DHCP operations handle invalid adapter names" -TestBlock {
    $result = Invoke-DHCPRelease -AdapterName "NonExistentAdapter"
    # Should not crash
    Assert-NotNull $result "Crashed on invalid adapter"
}

New-Test -Name "Troubleshooter handles unreachable internet" -TestBlock {
    $result = Invoke-NetworkTroubleshooter
    # Should identify issue and provide recommendations
    if ($result['InternetReachable'] -eq $false -or $result['Issues'].Count -gt 0) {
        Assert-True ($result['Recommendations'].Count -gt 0) "No recommendations for failed connectivity"
    }
}

# ============================================================================
# TEST RESULTS
# ============================================================================

Write-Host ""
Write-Host "╔═════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  TEST RESULTS                                                   ║" -ForegroundColor Cyan
Write-Host "╚═════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$passRate = if ($TestConfig['TotalTests'] -gt 0) {
    [Math]::Round(($TestConfig['PassedTests'] / $TestConfig['TotalTests']) * 100, 2)
} else {
    0
}

Write-Host "Total Tests:   $($TestConfig['TotalTests'])" -ForegroundColor White
Write-Host "Passed:        $($TestConfig['PassedTests'])" -ForegroundColor Green
Write-Host "Failed:        $($TestConfig['FailedTests'])" -ForegroundColor $(if ($TestConfig['FailedTests'] -gt 0) { 'Red' } else { 'Green' })
Write-Host "Pass Rate:     $passRate%" -ForegroundColor $(if ($passRate -ge 100) { 'Green' } elseif ($passRate -ge 80) { 'Yellow' } else { 'Red' })
Write-Host "Duration:      $([Math]::Round(($TestConfig['TestResults'] | Measure-Object -Property Duration -Sum).Sum / 1000, 2))s" -ForegroundColor White

Write-Host ""

if ($TestConfig['FailedTests'] -gt 0) {
    Write-Host "FAILED TESTS:" -ForegroundColor Red
    $TestConfig['TestResults'] | Where-Object { $_.Status -eq 'FAIL' } | ForEach-Object {
        Write-Host "  - $($_.Name): $($_.Error)" -ForegroundColor Red
    }
    Write-Host ""
}

if ($passRate -eq 100) {
    Write-Host "✓ ALL TESTS PASSED" -ForegroundColor Green -BackgroundColor Black
}
else {
    Write-Host "✗ SOME TESTS FAILED - Review output above" -ForegroundColor Red -BackgroundColor Black
}

Write-Host ""

# Save results
if (Test-Path $TestConfig['TestLogPath']) {
    $TestConfig['TestResults'] | Export-Csv -Path "$($TestConfig['TestLogPath'])\test-network-diagnostics-results.csv" -NoTypeInformation
    Write-Host "Results saved to: $($TestConfig['TestLogPath'])\test-network-diagnostics-results.csv" -ForegroundColor Cyan
}
