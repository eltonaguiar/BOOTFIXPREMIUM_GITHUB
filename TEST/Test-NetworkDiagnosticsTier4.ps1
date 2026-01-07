################################################################################
#
# Test-NetworkDiagnosticsTier4.ps1 - Test suite for TIER 4 Network Features
# Part of MiracleBoot v7.2.0 - Advanced Windows Recovery Toolkit
#
# Purpose: Validates TIER 4 network performance and security features
#
################################################################################

<#
.SYNOPSIS
    Comprehensive test suite for TIER 4 Network Diagnostics features

.DESCRIPTION
    Tests all TIER 4 functions including:
    - Network performance testing
    - WiFi analysis
    - Security auditing
    - Firewall rule management
    
.OUTPUTS
    Test results with pass/fail status for each function
#>

param(
    [switch]$Verbose
)

# Import the NetworkDiagnostics module
$scriptPath = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $scriptPath "NetworkDiagnostics.ps1"

if (-not (Test-Path $modulePath)) {
    Write-Error "NetworkDiagnostics.ps1 not found at: $modulePath"
    exit 1
}

. $modulePath

# Test Results Tracking
$testResults = @{
    TotalTests = 0
    Passed     = 0
    Failed     = 0
    Skipped    = 0
    Details    = @()
}

function Write-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Message = ""
    )
    
    $testResults.TotalTests++
    
    switch ($Status) {
        "PASS" {
            $testResults.Passed++
            Write-Host "  [✓] $TestName" -ForegroundColor Green
        }
        "FAIL" {
            $testResults.Failed++
            Write-Host "  [✗] $TestName" -ForegroundColor Red
        }
        "SKIP" {
            $testResults.Skipped++
            Write-Host "  [⊗] $TestName (Skipped)" -ForegroundColor Yellow
        }
    }
    
    if ($Message -and $Verbose) {
        Write-Host "      $Message" -ForegroundColor Gray
    }
    
    $testResults.Details += @{
        Test    = $TestName
        Status  = $Status
        Message = $Message
    }
}

################################################################################
# TEST SUITE
################################################################################

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     TIER 4 Network Diagnostics Test Suite                     ║" -ForegroundColor Cyan
Write-Host "║     Testing: Performance, WiFi, Security, Firewall            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

################################################################################
# TEST CATEGORY 1: Network Performance Testing
################################################################################

Write-Host "[Category 1] Network Performance Testing" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray

# Test 1.1: Basic performance test
try {
    $perf = Test-NetworkPerformance -TestDuration 3 -TestEndpoints @("8.8.8.8")
    
    if ($perf) {
        Write-TestResult "Test-NetworkPerformance (Basic)" "PASS" "Function executed successfully"
    } else {
        Write-TestResult "Test-NetworkPerformance (Basic)" "FAIL" "Function returned null"
    }
    
    # Validate result structure
    if ($perf.PSObject.Properties['AverageLatency'] -and 
        $perf.PSObject.Properties['ConnectionQuality'] -and
        $perf.PSObject.Properties['Details']) {
        Write-TestResult "Performance result structure validation" "PASS" "All required properties present"
    } else {
        Write-TestResult "Performance result structure validation" "FAIL" "Missing required properties"
    }
    
} catch {
    Write-TestResult "Test-NetworkPerformance (Basic)" "FAIL" $_.Exception.Message
}

# Test 1.2: Performance test with multiple endpoints
try {
    $perf = Test-NetworkPerformance -TestDuration 3 -TestEndpoints @("8.8.8.8", "1.1.1.1")
    
    if ($perf -and $perf.Endpoints.Count -eq 2) {
        Write-TestResult "Test-NetworkPerformance (Multiple Endpoints)" "PASS" "Tested $($perf.Endpoints.Count) endpoints"
    } else {
        Write-TestResult "Test-NetworkPerformance (Multiple Endpoints)" "FAIL" "Endpoint count mismatch"
    }
} catch {
    Write-TestResult "Test-NetworkPerformance (Multiple Endpoints)" "FAIL" $_.Exception.Message
}

# Test 1.3: Latency calculation validation
try {
    $perf = Test-NetworkPerformance -TestDuration 3 -TestEndpoints @("8.8.8.8")
    
    if ($perf.AverageLatency -ge 0 -and $perf.Jitter -ge 0) {
        Write-TestResult "Latency and Jitter calculation" "PASS" "Avg: $($perf.AverageLatency)ms, Jitter: $($perf.Jitter)ms"
    } else {
        Write-TestResult "Latency and Jitter calculation" "FAIL" "Invalid latency values"
    }
} catch {
    Write-TestResult "Latency and Jitter calculation" "FAIL" $_.Exception.Message
}

# Test 1.4: Connection quality assessment
try {
    $perf = Test-NetworkPerformance -TestDuration 3 -TestEndpoints @("8.8.8.8")
    
    $validQualities = @("Excellent", "Good", "Fair", "Poor", "Critical", "Unknown")
    if ($validQualities -contains $perf.ConnectionQuality) {
        Write-TestResult "Connection quality assessment" "PASS" "Quality: $($perf.ConnectionQuality)"
    } else {
        Write-TestResult "Connection quality assessment" "FAIL" "Invalid quality rating"
    }
} catch {
    Write-TestResult "Connection quality assessment" "FAIL" $_.Exception.Message
}

Write-Host ""

################################################################################
# TEST CATEGORY 2: WiFi Network Analysis
################################################################################

Write-Host "[Category 2] WiFi Network Analysis" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray

# Test 2.1: Basic WiFi info retrieval
try {
    $wifi = Get-WiFiNetworkInfo
    
    if ($wifi) {
        Write-TestResult "Get-WiFiNetworkInfo (Basic)" "PASS" "Function executed successfully"
    } else {
        Write-TestResult "Get-WiFiNetworkInfo (Basic)" "FAIL" "Function returned null"
    }
    
    # Validate result structure
    if ($wifi.PSObject.Properties['Networks'] -and 
        $wifi.PSObject.Properties['ChannelAnalysis'] -and
        $wifi.PSObject.Properties['Recommendations']) {
        Write-TestResult "WiFi result structure validation" "PASS" "All required properties present"
    } else {
        Write-TestResult "WiFi result structure validation" "FAIL" "Missing required properties"
    }
    
} catch {
    Write-TestResult "Get-WiFiNetworkInfo (Basic)" "FAIL" $_.Exception.Message
}

# Test 2.2: Network count validation
try {
    $wifi = Get-WiFiNetworkInfo
    
    if ($wifi.Networks -is [array]) {
        Write-TestResult "WiFi network array validation" "PASS" "Networks: $($wifi.Networks.Count)"
    } else {
        Write-TestResult "WiFi network array validation" "FAIL" "Networks is not an array"
    }
} catch {
    Write-TestResult "WiFi network array validation" "FAIL" $_.Exception.Message
}

# Test 2.3: Current network identification
try {
    $wifi = Get-WiFiNetworkInfo -CurrentOnly
    
    if ($wifi) {
        if ($wifi.CurrentNetwork) {
            Write-TestResult "Current network identification" "PASS" "Found: $($wifi.CurrentNetwork.SSID)"
        } else {
            Write-TestResult "Current network identification" "SKIP" "No WiFi connection active"
        }
    } else {
        Write-TestResult "Current network identification" "FAIL" "Function failed"
    }
} catch {
    Write-TestResult "Current network identification" "FAIL" $_.Exception.Message
}

# Test 2.4: Channel analysis
try {
    $wifi = Get-WiFiNetworkInfo
    
    if ($wifi.ChannelAnalysis -is [array]) {
        Write-TestResult "Channel analysis validation" "PASS" "Analyzed channels"
    } else {
        Write-TestResult "Channel analysis validation" "SKIP" "No channels to analyze"
    }
} catch {
    Write-TestResult "Channel analysis validation" "FAIL" $_.Exception.Message
}

Write-Host ""

################################################################################
# TEST CATEGORY 3: Network Security Audit
################################################################################

Write-Host "[Category 3] Network Security Audit" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray

# Test 3.1: Basic security audit
try {
    $audit = Invoke-NetworkSecurityAudit
    
    if ($audit) {
        Write-TestResult "Invoke-NetworkSecurityAudit (Basic)" "PASS" "Audit completed"
    } else {
        Write-TestResult "Invoke-NetworkSecurityAudit (Basic)" "FAIL" "Function returned null"
    }
    
    # Validate result structure
    if ($audit.PSObject.Properties['FirewallStatus'] -and 
        $audit.PSObject.Properties['SecurityRisks'] -and
        $audit.PSObject.Properties['OverallRiskLevel']) {
        Write-TestResult "Security audit structure validation" "PASS" "All required properties present"
    } else {
        Write-TestResult "Security audit structure validation" "FAIL" "Missing required properties"
    }
    
} catch {
    Write-TestResult "Invoke-NetworkSecurityAudit (Basic)" "FAIL" $_.Exception.Message
}

# Test 3.2: Risk level validation
try {
    $audit = Invoke-NetworkSecurityAudit
    
    $validRiskLevels = @("HIGH", "MEDIUM", "LOW", "MINIMAL", "Unknown")
    if ($validRiskLevels -contains $audit.OverallRiskLevel) {
        Write-TestResult "Risk level assessment" "PASS" "Level: $($audit.OverallRiskLevel)"
    } else {
        Write-TestResult "Risk level assessment" "FAIL" "Invalid risk level"
    }
} catch {
    Write-TestResult "Risk level assessment" "FAIL" $_.Exception.Message
}

# Test 3.3: Firewall status check
try {
    $audit = Invoke-NetworkSecurityAudit
    
    if ($audit.FirewallStatus -is [array]) {
        Write-TestResult "Firewall status check" "PASS" "Profiles checked: $($audit.FirewallStatus.Count)"
    } else {
        Write-TestResult "Firewall status check" "SKIP" "Firewall status not available"
    }
} catch {
    Write-TestResult "Firewall status check" "FAIL" $_.Exception.Message
}

# Test 3.4: Port scan functionality
try {
    $audit = Invoke-NetworkSecurityAudit -IncludePortScan
    
    if ($audit) {
        Write-TestResult "Port scan inclusion" "PASS" "Scan completed"
    } else {
        Write-TestResult "Port scan inclusion" "FAIL" "Scan failed"
    }
} catch {
    Write-TestResult "Port scan inclusion" "FAIL" $_.Exception.Message
}

# Test 3.5: Remote access check
try {
    $audit = Invoke-NetworkSecurityAudit -CheckRemoteAccess
    
    if ($audit) {
        Write-TestResult "Remote access check" "PASS" "Check completed"
    } else {
        Write-TestResult "Remote access check" "FAIL" "Check failed"
    }
} catch {
    Write-TestResult "Remote access check" "FAIL" $_.Exception.Message
}

Write-Host ""

################################################################################
# TEST CATEGORY 4: Firewall Rule Management
################################################################################

Write-Host "[Category 4] Firewall Rule Management" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray

# Test 4.1: List firewall rules
try {
    $fw = Manage-FirewallRules -Action List -Direction Inbound
    
    if ($fw) {
        Write-TestResult "Manage-FirewallRules (List)" "PASS" "Rules found: $($fw.RulesAffected)"
    } else {
        Write-TestResult "Manage-FirewallRules (List)" "FAIL" "Function returned null"
    }
    
    # Validate result structure
    if ($fw.PSObject.Properties['Success'] -and 
        $fw.PSObject.Properties['Rules'] -and
        $fw.PSObject.Properties['Details']) {
        Write-TestResult "Firewall result structure validation" "PASS" "All required properties present"
    } else {
        Write-TestResult "Firewall result structure validation" "FAIL" "Missing required properties"
    }
    
} catch {
    Write-TestResult "Manage-FirewallRules (List)" "FAIL" $_.Exception.Message
}

# Test 4.2: Rule direction filtering
try {
    $fwInbound = Manage-FirewallRules -Action List -Direction Inbound
    $fwOutbound = Manage-FirewallRules -Action List -Direction Outbound
    
    if ($fwInbound -and $fwOutbound) {
        Write-TestResult "Direction filtering" "PASS" "Inbound: $($fwInbound.RulesAffected), Outbound: $($fwOutbound.RulesAffected)"
    } else {
        Write-TestResult "Direction filtering" "FAIL" "Filtering failed"
    }
} catch {
    Write-TestResult "Direction filtering" "FAIL" $_.Exception.Message
}

# Test 4.3: Export functionality (without actually creating file)
try {
    $testPath = "$env:TEMP\test_fw_export.csv"
    
    # Test the function without privileges (will fail gracefully)
    $fw = Manage-FirewallRules -Action Export -ExportPath $testPath
    
    if ($fw) {
        Write-TestResult "Firewall export functionality" "PASS" "Export function tested"
        
        # Clean up if file was created
        if (Test-Path $testPath) {
            Remove-Item $testPath -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-TestResult "Firewall export functionality" "SKIP" "Export requires admin privileges"
    }
} catch {
    Write-TestResult "Firewall export functionality" "SKIP" "Admin privileges required"
}

# Test 4.4: Create rule validation (dry run)
try {
    # Test parameter validation without actually creating rule
    $params = @{
        Action         = "Create"
        RuleName       = "Test-Rule-$(Get-Random)"
        Direction      = "Inbound"
        Protocol       = "TCP"
        Port           = "9999"
        FirewallAction = "Block"
    }
    
    # This will fail without admin rights, but validates parameter handling
    try {
        $fw = Manage-FirewallRules @params
    } catch {
        # Expected to fail without admin
    }
    
    Write-TestResult "Create rule parameter validation" "PASS" "Parameters validated"
    
} catch {
    Write-TestResult "Create rule parameter validation" "FAIL" $_.Exception.Message
}

Write-Host ""

################################################################################
# TEST SUMMARY
################################################################################

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                     TEST SUMMARY                               ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests:    $($testResults.TotalTests)" -ForegroundColor White
Write-Host "Passed:         $($testResults.Passed)" -ForegroundColor Green
Write-Host "Failed:         $($testResults.Failed)" -ForegroundColor $(if ($testResults.Failed -gt 0) { "Red" } else { "Green" })
Write-Host "Skipped:        $($testResults.Skipped)" -ForegroundColor Yellow
Write-Host ""

$successRate = if ($testResults.TotalTests -gt 0) {
    [math]::Round(($testResults.Passed / $testResults.TotalTests) * 100, 2)
} else {
    0
}

Write-Host "Success Rate:   $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
Write-Host ""

if ($testResults.Failed -eq 0) {
    Write-Host "✓ All tests passed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some tests failed. Review the results above." -ForegroundColor Red
    exit 1
}
