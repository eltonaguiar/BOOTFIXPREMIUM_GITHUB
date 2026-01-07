################################################################################
#
# Test-NetworkDiagnostics-TIER1.ps1
# Comprehensive test suite for NetworkDiagnostics TIER 1 features
#
# Purpose: Validate all TIER 1 functions without modifying system state
# Tests: Driver Compatibility, VMD Detection, DHCP Recovery, Boot Blockers
#
# Author: MiracleBoot Development Team
# Date: January 2026
#
################################################################################

# Load the NetworkDiagnostics module
$modulePath = "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\NetworkDiagnostics.ps1"
. $modulePath

$script:testsPassed = 0
$script:testsFailed = 0
$script:testResults = @()

################################################################################
# TEST INFRASTRUCTURE
################################################################################

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $($Title.PadRight(62)) ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Write-Test {
    param(
        [string]$Name,
        [ValidateSet("PASS", "FAIL", "SKIP")]
        [string]$Result,
        [string]$Message
    )
    
    $color = @{
        "PASS" = "Green"
        "FAIL" = "Red"
        "SKIP" = "Yellow"
    }[$Result]
    
    Write-Host "[$Result] $Name" -ForegroundColor $color
    if ($Message) {
        Write-Host "       $Message" -ForegroundColor Gray
    }
    
    if ($Result -eq "PASS") { $script:testsPassed++ }
    elseif ($Result -eq "FAIL") { $script:testsFailed++ }
    
    $script:testResults += [PSCustomObject]@{
        Name    = $Name
        Result  = $Result
        Message = $Message
        Time    = Get-Date
    }
}

################################################################################
# TIER 1.1: DRIVER COMPATIBILITY TESTS
################################################################################

Write-TestHeader "TIER 1.1: Driver Compatibility Checker Tests"

# Test 1.1.1: Function loads
try {
    $func = Get-Command Test-DriverCompatibility -ErrorAction Stop
    Write-Test "Function loads without syntax errors" "PASS"
} catch {
    Write-Test "Function loads without syntax errors" "FAIL" $_
}

# Test 1.1.2: Rejects non-existent paths
try {
    $result = Test-DriverCompatibility -DriverPath "C:\NonExistent\Driver.inf" -ErrorAction SilentlyContinue
    
    if ($result.Compatible -eq $false -and $result.Reason -match "not found") {
        Write-Test "Rejects non-existent driver path" "PASS"
    } else {
        Write-Test "Rejects non-existent driver path" "FAIL" "Should have returned Compatible=false"
    }
} catch {
    Write-Test "Rejects non-existent driver path" "FAIL" $_
}

# Test 1.1.3: Parameter validation - Architecture
try {
    $result = Test-DriverCompatibility -DriverPath "C:\test.inf" -TargetArchitecture "ARMv7" -ErrorAction Stop 2>&1
    Write-Test "Architecture parameter validation" "FAIL" "Should have rejected invalid architecture"
} catch {
    if ($_ -match "ValidateSet|ParameterArgumentValidation") {
        Write-Test "Architecture parameter validation" "PASS"
    } else {
        Write-Test "Architecture parameter validation" "FAIL" "Wrong error: $_"
    }
}

# Test 1.1.4: Test with real INF file
try {
    $tempFolder = "$env:TEMP\TestDriver_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
    
    $infContent = '[Version]' + "`r`n"
    $infContent += 'Signature="$WINDOWS NT$"' + "`r`n"
    $infContent += 'Class=Net' + "`r`n"
    $infContent += 'ClassGuid={4d36e972-e325-11ce-bfc1-08002be10318}' + "`r`n"
    $infContent += 'Provider=%ManufacturerName%' + "`r`n"
    $infContent += 'DriverVer=01/01/2020,1.0.0.0' + "`r`n`r`n"
    $infContent += '[Manufacturer]' + "`r`n"
    $infContent += '%ManufacturerName%=Standard,NTx64' + "`r`n`r`n"
    $infContent += '[Standard.NTx64]' + "`r`n"
    $infContent += '%DeviceDescription%=TestNet_Inst, PCI\VEN_1234&DEV_5678' + "`r`n`r`n"
    $infContent += '[TestNet_Inst]' + "`r`n"
    $infContent += 'Include=netrndis.inf' + "`r`n"
    $infContent += 'Needs=Ndisuio.Service' + "`r`n`r`n"
    $infContent += '[TestNet_Inst.Services]' + "`r`n"
    $infContent += 'AddService=TestNet, 2, TestNet_Service' + "`r`n`r`n"
    $infContent += '[TestNet_Service]' + "`r`n"
    $infContent += 'ServiceType=1' + "`r`n"
    $infContent += 'StartType=3' + "`r`n"
    $infContent += 'ErrorControl=1' + "`r`n"
    $infContent += 'ServiceBinary=%12%\testnet.sys' + "`r`n`r`n"
    $infContent += '[SourceDisksNames]' + "`r`n"
    $infContent += '1=%DiskName%' + "`r`n`r`n"
    $infContent += '[SourceDisksFiles]' + "`r`n"
    $infContent += 'testnet.sys=1' + "`r`n`r`n"
    $infContent += '[Strings]' + "`r`n"
    $infContent += 'ManufacturerName="Test Vendor"' + "`r`n"
    $infContent += 'DiskName="Test Driver Disk"' + "`r`n"
    $infContent += 'DeviceDescription="Test Network Device"'
    
    $infPath = Join-Path $tempFolder "TestDriver.inf"
    Set-Content -Path $infPath -Value $infContent -Force
    Set-Content -Path (Join-Path $tempFolder "testnet.sys") -Value "DUMMY" -Force
    
    $result = Test-DriverCompatibility -DriverPath $infPath -ErrorAction SilentlyContinue
    
    if ($result.Compatible -eq $true -and $result.DriverClass -match "Net") {
        Write-Test "Parse valid network driver INF" "PASS" "Correctly identified as compatible"
    } else {
        Write-Test "Parse valid network driver INF" "FAIL" "Should have been compatible: $($result.Reason)"
    }
    
    Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
    
} catch {
    Write-Test "Parse valid network driver INF" "FAIL" $_
}

# Test 1.1.5: Detect missing dependencies
try {
    $tempFolder = "$env:TEMP\TestDriver_NoFiles_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
    
    $infContent = '[Version]' + "`r`n"
    $infContent += 'Signature="$WINDOWS NT$"' + "`r`n"
    $infContent += 'Class=Net' + "`r`n"
    $infContent += 'ClassGuid={4d36e972-e325-11ce-bfc1-08002be10318}' + "`r`n`r`n"
    $infContent += '[SourceDisksFiles]' + "`r`n"
    $infContent += 'missing.sys=1' + "`r`n"
    $infContent += 'missing.dll=1' + "`r`n`r`n"
    $infContent += '[Strings]'
    
    $infPath = Join-Path $tempFolder "TestDriver.inf"
    Set-Content -Path $infPath -Value $infContent -Force
    
    $result = Test-DriverCompatibility -DriverPath $infPath -ErrorAction SilentlyContinue
    
    if ($result.Compatible -eq $false -and $result.MissingFiles.Count -gt 0) {
        Write-Test "Detect missing dependencies" "PASS" "Found missing files: $($result.MissingFiles -join ', ')"
    } else {
        Write-Test "Detect missing dependencies" "FAIL" "Should have detected missing files"
    }
    
    Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
    
} catch {
    Write-Test "Detect missing dependencies" "FAIL" $_
}

################################################################################
# TIER 1.2: VMD/RAID DETECTION TESTS
################################################################################

Write-TestHeader "TIER 1.2: VMD/RAID Controller Detection Tests"

# Test 1.2.1: Function loads
try {
    $func = Get-Command Get-VMDConfiguration -ErrorAction Stop
    Write-Test "Get-VMDConfiguration loads" "PASS"
} catch {
    Write-Test "Get-VMDConfiguration loads" "FAIL" $_
}

# Test 1.2.2: Returns valid result structure
try {
    $result = Get-VMDConfiguration -ErrorAction SilentlyContinue
    
    $expectedProps = @("HasVMD", "RAIDMode", "VMDControllers", "RequiresVMDDriver", "Details")
    $hasAllProps = $expectedProps | Where-Object { -not ($result.PSObject.Properties.Name -contains $_) }
    
    if (-not $hasAllProps) {
        Write-Test "Returns valid result structure" "PASS"
    } else {
        Write-Test "Returns valid result structure" "FAIL" "Missing properties: $hasAllProps"
    }
} catch {
    Write-Test "Returns valid result structure" "FAIL" $_
}

# Test 1.2.3: Details contain useful information
try {
    $result = Get-VMDConfiguration -ErrorAction SilentlyContinue
    
    if ($result.Details.Count -gt 0) {
        Write-Test "Provides diagnostic details" "PASS" "$($result.Details.Count) detail lines"
    } else {
        Write-Test "Provides diagnostic details" "FAIL" "No details generated"
    }
} catch {
    Write-Test "Provides diagnostic details" "FAIL" $_
}

# Test 1.2.4: Find-VMDDrivers function loads
try {
    $func = Get-Command Find-VMDDrivers -ErrorAction Stop
    Write-Test "Find-VMDDrivers loads" "PASS"
} catch {
    Write-Test "Find-VMDDrivers loads" "FAIL" $_
}

# Test 1.2.5: Find-VMDDrivers handles non-existent volumes
try {
    $result = Find-VMDDrivers -SearchVolumes @("Z:") -ErrorAction SilentlyContinue
    
    # Should return empty array without crashing
    if ($result -is [System.Collections.IEnumerable] -or $result.Count -eq 0) {
        Write-Test "Gracefully handles missing volumes" "PASS"
    } else {
        Write-Test "Gracefully handles missing volumes" "FAIL" "Should return array/empty result"
    }
} catch {
    Write-Test "Gracefully handles missing volumes" "FAIL" $_
}

################################################################################
# TIER 1.3: DHCP RECOVERY TESTS
################################################################################

Write-TestHeader "TIER 1.3: DHCP Timeout Recovery Tests"

# Test 1.3.1: Function loads
try {
    $func = Get-Command Invoke-DHCPRecovery -ErrorAction Stop
    Write-Test "Invoke-DHCPRecovery loads" "PASS"
} catch {
    Write-Test "Invoke-DHCPRecovery loads" "FAIL" $_
}

# Test 1.3.2: Requires AdapterName parameter
try {
    Invoke-DHCPRecovery -ErrorAction Stop 2>&1 | Out-Null
    Write-Test "Requires mandatory AdapterName parameter" "FAIL" "Should have thrown error"
} catch {
    if ($_ -match "AdapterName|mandatory|required") {
        Write-Test "Requires mandatory AdapterName parameter" "PASS"
    } else {
        Write-Test "Requires mandatory AdapterName parameter" "FAIL" "Wrong error: $_"
    }
}

# Test 1.3.3: Returns valid result structure
try {
    # Use a non-existent adapter to avoid actual configuration
    $result = Invoke-DHCPRecovery -AdapterName "NonExistentAdapter99999" -ErrorAction SilentlyContinue
    
    $expectedProps = @("Success", "Adapter", "Method", "Details", "Warnings")
    $hasAllProps = $expectedProps | Where-Object { -not ($result.PSObject.Properties.Name -contains $_) }
    
    if (-not $hasAllProps) {
        Write-Test "Returns valid result structure" "PASS"
    } else {
        Write-Test "Returns valid result structure" "FAIL" "Missing properties: $hasAllProps"
    }
} catch {
    Write-Test "Returns valid result structure" "FAIL" $_
}

# Test 1.3.4: Timeout parameter validation
try {
    $result = Invoke-DHCPRecovery -AdapterName "Test" -TimeoutSeconds -1 -ErrorAction SilentlyContinue
    
    # Should handle gracefully (negative timeout treated as 0)
    if ($result -is [hashtable] -or $result.PSObject.Properties) {
        Write-Test "Handles invalid timeout values gracefully" "PASS"
    } else {
        Write-Test "Handles invalid timeout values gracefully" "FAIL"
    }
} catch {
    Write-Test "Handles invalid timeout values gracefully" "FAIL" $_
}

################################################################################
# TIER 1.4: BOOT-BLOCKING DRIVER DETECTION TESTS
################################################################################

Write-TestHeader "TIER 1.4: Boot-Blocking Driver Detection Tests"

# Test 1.4.1: Function loads
try {
    $func = Get-Command Get-BootBlockingDrivers -ErrorAction Stop
    Write-Test "Get-BootBlockingDrivers loads" "PASS"
} catch {
    Write-Test "Get-BootBlockingDrivers loads" "FAIL" $_
}

# Test 1.4.2: Handles missing registry path
try {
    $result = Get-BootBlockingDrivers -OfflineWinRegPath "C:\NonExistent\SYSTEM" -ErrorAction SilentlyContinue
    
    if ($result.Details -join "" -match "not found|path not found") {
        Write-Test "Handles missing offline registry path" "PASS"
    } else {
        Write-Test "Handles missing offline registry path" "FAIL" "Should report path not found"
    }
} catch {
    Write-Test "Handles missing offline registry path" "FAIL" $_
}

# Test 1.4.3: Returns valid result structure
try {
    $result = Get-BootBlockingDrivers -OfflineWinRegPath "C:\NonExistent" -ErrorAction SilentlyContinue
    
    $expectedProps = @("ProblematicDrivers", "Details", "Recommendations", "Timestamp")
    $hasAllProps = $expectedProps | Where-Object { -not ($result.PSObject.Properties.Name -contains $_) }
    
    if (-not $hasAllProps) {
        Write-Test "Returns valid result structure" "PASS"
    } else {
        Write-Test "Returns valid result structure" "FAIL" "Missing properties: $hasAllProps"
    }
} catch {
    Write-Test "Returns valid result structure" "FAIL" $_
}

# Test 1.4.4: TargetOSVersion parameter validation
try {
    $result = Get-BootBlockingDrivers -OfflineWinRegPath "C:\test" -TargetOSVersion 99 -ErrorAction Stop 2>&1
    Write-Test "Validates TargetOSVersion parameter" "FAIL" "Should reject invalid OS version"
} catch {
    if ($_ -match "ValidateSet|ParameterArgumentValidation") {
        Write-Test "Validates TargetOSVersion parameter" "PASS"
    } else {
        Write-Test "Validates TargetOSVersion parameter" "FAIL" "Wrong error: $_"
    }
}

################################################################################
# SUMMARY REPORT
################################################################################

Write-TestHeader "TEST EXECUTION SUMMARY"

Write-Host "Total Tests: $($script:testsPassed + $script:testsFailed)" -ForegroundColor Cyan
Write-Host "Passed: $($script:testsPassed)" -ForegroundColor Green
Write-Host "Failed: $($script:testsFailed)" -ForegroundColor $(if ($script:testsFailed -eq 0) { "Green" } else { "Red" })

if ($script:testsFailed -eq 0) {
    Write-Host "`n[✓] ALL TESTS PASSED - TIER 1 FEATURES READY FOR DEPLOYMENT`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[✗] $($script:testsFailed) TEST(S) FAILED - REVIEW ERRORS ABOVE`n" -ForegroundColor Red
    exit 1
}
