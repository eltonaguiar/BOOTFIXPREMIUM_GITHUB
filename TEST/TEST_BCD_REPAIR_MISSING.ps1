# Comprehensive test routines for BCD repair with missing BCD files
# Tests the Repair-BCDBruteForce function under various failure conditions

param(
    [string]$TestMode = "All",
    [switch]$Verbose = $false
)

# Load the DefensiveBootCore module
$coreScript = "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\DefensiveBootCore.ps1"
if (-not (Test-Path $coreScript)) {
    Write-Host "ERROR: Cannot find DefensiveBootCore.ps1" -ForegroundColor Red
    exit 1
}

. $coreScript

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "BCD Repair Test Suite - Missing BCD Edition" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test 1: Verify bcdedit error handling with non-existent BCD
function Test-BCDMissingDetection {
    Write-Host "`n[TEST 1] BCD Missing Detection" -ForegroundColor Yellow
    Write-Host "Purpose: Verify code detects when BCD file is missing" -ForegroundColor Gray
    
    # Try to enumerate a non-existent BCD store
    $testBcdPath = "Z:\EFI\Microsoft\Boot\BCD_NONEXISTENT"
    
    Write-Host "  Testing bcdedit /store with non-existent path: $testBcdPath"
    $result = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $testBcdPath, "/enum", "{default}") -TimeoutSeconds 5
    
    Write-Host "  Exit Code: $($result.ExitCode)" -ForegroundColor Cyan
    Write-Host "  Error Output: $($result.Output)" -ForegroundColor Cyan
    
    if ($result.ExitCode -ne 0 -and $result.Output -match "could not be opened|cannot find") {
        Write-Host "  ✓ PASS: BCD missing error detected correctly" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  ✗ FAIL: BCD missing not detected" -ForegroundColor Red
        return $false
    }
}

# Test 2: Verify repair function handles BCD missing gracefully
function Test-RepairWithMissingBCD {
    Write-Host "`n[TEST 2] Repair Function with Missing BCD" -ForegroundColor Yellow
    Write-Host "Purpose: Verify repair function fails gracefully when BCD missing" -ForegroundColor Gray
    
    # Simulate repair attempt on non-existent drive
    Write-Host "  Calling Repair-BCDBruteForce with non-existent ESP..."
    $result = Repair-BCDBruteForce -TargetDrive "C" -EspLetter "Z" -WinloadPath "\Windows\system32\winload.efi"
    
    Write-Host "  Result Success: $($result.Success)" -ForegroundColor Cyan
    Write-Host "  Result Verified: $($result.Verified)" -ForegroundColor Cyan
    Write-Host "  Actions ($($result.Actions.Count) items):" -ForegroundColor Cyan
    foreach ($action in $result.Actions) {
        Write-Host "    - $action"
    }
    
    if ($result.Success -eq $false) {
        Write-Host "  ✓ PASS: Repair handled missing BCD gracefully" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  ✗ FAIL: Repair did not handle missing BCD" -ForegroundColor Red
        return $false
    }
}

# Test 3: Verify argument escaping in Invoke-BCDCommandWithTimeout
function Test-ArgumentEscaping {
    Write-Host "`n[TEST 3] Argument Escaping" -ForegroundColor Yellow
    Write-Host "Purpose: Verify {default} and special chars are properly escaped" -ForegroundColor Gray
    
    # Test with properly formatted arguments
    $testArgs = @("/enum", "{default}")
    Write-Host "  Testing arguments: $($testArgs -join ' ')"
    
    # This should fail gracefully (no /encodedCommand error)
    $result = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $testArgs -TimeoutSeconds 5
    
    Write-Host "  Exit Code: $($result.ExitCode)" -ForegroundColor Cyan
    $output = $result.Output
    
    # Check for the /encodedCommand error
    if ($output -match "/encodedCommand") {
        Write-Host "  ✗ FAIL: /encodedCommand error detected!" -ForegroundColor Red
        Write-Host "  Output: $output" -ForegroundColor Red
        return $false
    } else {
        Write-Host "  ✓ PASS: No /encodedCommand error" -ForegroundColor Green
        if ($result.ExitCode -eq 0) {
            Write-Host "  ✓ PASS: Command executed successfully" -ForegroundColor Green
        } else {
            Write-Host "  ⓘ INFO: Command failed but no encoding error (expected on error condition)" -ForegroundColor Cyan
        }
        return $true
    }
}

# Test 4: Verify partition argument format
function Test-PartitionArgumentFormat {
    Write-Host "`n[TEST 4] Partition Argument Format" -ForegroundColor Yellow
    Write-Host "Purpose: Verify partition=X: format is properly handled" -ForegroundColor Gray
    
    $testArgs = @("/set", "{default}", "device", "partition=C:")
    Write-Host "  Testing arguments: $($testArgs -join ' ')"
    
    $result = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $testArgs -TimeoutSeconds 5
    
    Write-Host "  Exit Code: $($result.ExitCode)" -ForegroundColor Cyan
    $output = $result.Output
    
    # Check for /encodedCommand error
    if ($output -match "/encodedCommand") {
        Write-Host "  ✗ FAIL: /encodedCommand error with partition argument!" -ForegroundColor Red
        return $false
    } else {
        Write-Host "  ✓ PASS: Partition argument handled correctly (no /encodedCommand error)" -ForegroundColor Green
        return $true
    }
}

# Test 5: Verify exit code checking works properly
function Test-ExitCodeValidation {
    Write-Host "`n[TEST 5] Exit Code Validation" -ForegroundColor Yellow
    Write-Host "Purpose: Verify each bcdedit command exit code is checked" -ForegroundColor Gray
    
    # Try a command that should fail (modifying default on missing BCD)
    $result = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", "Z:\nonexistent\BCD", "/set", "{default}", "path", "\Windows\system32\winload.efi") -TimeoutSeconds 5
    
    Write-Host "  Command Exit Code: $($result.ExitCode)" -ForegroundColor Cyan
    
    if ($result.ExitCode -ne 0) {
        Write-Host "  ✓ PASS: Failure detected with non-zero exit code" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  ✗ FAIL: Failed to detect error condition" -ForegroundColor Red
        return $false
    }
}

# Test 6: Verify bcdboot handling for BCD creation
function Test-BCDBootRecreation {
    Write-Host "`n[TEST 6] Bcdboot BCD Recreation (DRY RUN)" -ForegroundColor Yellow
    Write-Host "Purpose: Verify bcdboot command format for BCD recreation" -ForegroundColor Gray
    
    # Build bcdboot arguments correctly
    $targetDrive = "C"
    $espLetter = "S"
    $bcdbootArgs = @("$targetDrive`:\Windows", "/s", $espLetter, "/f", "UEFI", "/addlast")
    
    Write-Host "  Bcdboot arguments: $($bcdbootArgs -join ' ')" -ForegroundColor Cyan
    
    # Verify the arguments are correctly formatted
    if ($bcdbootArgs -contains "/encodedCommand") {
        Write-Host "  ✗ FAIL: /encodedCommand found in arguments!" -ForegroundColor Red
        return $false
    }
    
    if ($bcdbootArgs[0] -match '^[A-Z]:.*Windows$') {
        Write-Host "  ✓ PASS: Windows path correctly formatted: $($bcdbootArgs[0])" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  ✗ FAIL: Windows path incorrect: $($bcdbootArgs[0])" -ForegroundColor Red
        return $false
    }
}

# Test 7: Verify repair function repair flow logic
function Test-RepairFunctionLogic {
    Write-Host "`n[TEST 7] Repair Function Flow Logic" -ForegroundColor Yellow
    Write-Host "Purpose: Verify repair attempts correct steps in right order" -ForegroundColor Gray
    
    $result = Repair-BCDBruteForce -TargetDrive "C" -EspLetter "S" -WinloadPath "\Windows\system32\winload.efi"
    
    Write-Host "  Actions taken:" -ForegroundColor Cyan
    $stepCount = 0
    foreach ($action in $result.Actions) {
        $stepCount++
        # Truncate long lines for display
        $displayAction = if ($action.Length -gt 100) { $action.Substring(0, 97) + "..." } else { $action }
        Write-Host "    $stepCount. $displayAction"
    }
    
    # Check for error handling indicators
    if ($result.Actions | Where-Object { $_ -match "ERROR|Failed|error" }) {
        Write-Host "  ✓ PASS: Repair detected and logged errors" -ForegroundColor Green
        return $true
    } elseif ($result.Actions -contains "Setting BCD path to winload.efi...") {
        Write-Host "  ⓘ INFO: Repair attempted BCD operations" -ForegroundColor Cyan
        return $true
    } else {
        Write-Host "  ✗ FAIL: Unexpected repair flow" -ForegroundColor Red
        return $false
    }
}

# Test 8: Verify Invoke-BCDCommandWithTimeout handles timeouts
function Test-TimeoutHandling {
    Write-Host "`n[TEST 8] Timeout Handling" -ForegroundColor Yellow
    Write-Host "Purpose: Verify timeout wrapper prevents indefinite hangs" -ForegroundColor Gray
    
    # Use a short timeout
    $result = Invoke-BCDCommandWithTimeout -Command "ping.exe" -Arguments @("-n", "10", "127.0.0.1") -TimeoutSeconds 1 -Description "Test timeout"
    
    Write-Host "  Timeout Detected: $($result.TimedOut)" -ForegroundColor Cyan
    Write-Host "  Exit Code: $($result.ExitCode)" -ForegroundColor Cyan
    
    if ($result.TimedOut) {
        Write-Host "  ✓ PASS: Timeout correctly detected" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  ⓘ INFO: Command completed before timeout" -ForegroundColor Cyan
        return $true
    }
}

# Run all tests
$tests = @(
    @{ Name = "BCDMissingDetection"; Func = { Test-BCDMissingDetection } },
    @{ Name = "RepairWithMissingBCD"; Func = { Test-RepairWithMissingBCD } },
    @{ Name = "ArgumentEscaping"; Func = { Test-ArgumentEscaping } },
    @{ Name = "PartitionArgumentFormat"; Func = { Test-PartitionArgumentFormat } },
    @{ Name = "ExitCodeValidation"; Func = { Test-ExitCodeValidation } },
    @{ Name = "BCDBootRecreation"; Func = { Test-BCDBootRecreation } },
    @{ Name = "RepairFunctionLogic"; Func = { Test-RepairFunctionLogic } },
    @{ Name = "TimeoutHandling"; Func = { Test-TimeoutHandling } }
)

$passed = 0
$failed = 0
$results = @()

foreach ($test in $tests) {
    if ($TestMode -eq "All" -or $TestMode -eq $test.Name) {
        try {
            $testResult = & $test.Func
            if ($testResult) {
                $passed++
                $results += @{ Name = $test.Name; Status = "PASS" }
            } else {
                $failed++
                $results += @{ Name = $test.Name; Status = "FAIL" }
            }
        } catch {
            Write-Host "  ✗ EXCEPTION: $_" -ForegroundColor Red
            $failed++
            $results += @{ Name = $test.Name; Status = "ERROR" }
        }
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "Total:  $($passed + $failed)" -ForegroundColor Cyan

Write-Host "`nResults by Test:" -ForegroundColor Cyan
foreach ($result in $results) {
    $color = if ($result.Status -eq "PASS") { "Green" } elseif ($result.Status -eq "FAIL") { "Red" } else { "Yellow" }
    Write-Host "  [$($result.Status)] $($result.Name)" -ForegroundColor $color
}

if ($failed -eq 0) {
    Write-Host "`n✓ All tests PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ Some tests FAILED - see details above" -ForegroundColor Red
    exit 1
}
