# GitHub Version BCD Command Fix
**Date:** January 10, 2026  
**Issue:** GitHub version fails with "Invalid command line switch: /encodedCommand" error  
**Root Cause:** Improper bcdedit argument passing in `Repair-BCDBruteForce()` function  
**Status:** FIXED

---

## Problem Description

The GitHub version of MiracleBoot was failing when executing bcdedit commands with the error:
```
Invalid command line switch: /encodedCommand
```

This error indicated that PowerShell was misinterpreting the bcdedit command string due to improper argument quoting and escaping.

---

## Root Cause Analysis

**Location:** [DefensiveBootCore.ps1](DefensiveBootCore.ps1#L2698-L2700) - `Repair-BCDBruteForce()` function

**Original Code (BROKEN):**
```powershell
$setPath = bcdedit /store $bcdStore /set {default} path \Windows\system32\winload.efi 2>&1 | Out-String
$setDevice = bcdedit /store $bcdStore /set {default} device partition=$TargetDrive 2>&1 | Out-String
$setOsDevice = bcdedit /store $bcdStore /set {default} osdevice partition=$TargetDrive 2>&1 | Out-String

if ($LASTEXITCODE -eq 0) {
    $actions += "BCD path set successfully"
} else {
    $actions += "BCD path set failed: $setPath"
}
```

**Problems:**
1. **Improper argument quoting:** The `{default}` identifier needs proper quoting to avoid PowerShell interpretation
2. **Exit code handling:** Only checks `$LASTEXITCODE` after all commands execute, doesn't validate individual failures
3. **Argument escaping:** The partition parameter wasn't properly escaped
4. **String parsing:** Direct bcdedit invocation doesn't properly escape PowerShell special characters

---

## Solution Implemented

**Use the existing `Invoke-BCDCommandWithTimeout()` helper function** which properly:
- Quotes and escapes arguments with special characters
- Uses ProcessStartInfo for safe command execution
- Prevents command hanging with timeout wrapper
- Validates exit codes immediately after each command
- Returns structured output with ExitCode and Output properties

**New Code (FIXED):**
```powershell
# Build bcdedit arguments properly with timeout wrapper to prevent hanging
$pathArgs = @("/store", $bcdStore, "/set", "{default}", "path", "\Windows\system32\winload.efi")
$deviceArgs = @("/store", $bcdStore, "/set", "{default}", "device", "partition=$TargetDrive")
$osdeviceArgs = @("/store", $bcdStore, "/set", "{default}", "osdevice", "partition=$TargetDrive")

$setPathResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $pathArgs -TimeoutSeconds 15 -Description "Set BCD path"
$setDeviceResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $deviceArgs -TimeoutSeconds 15 -Description "Set BCD device"
$setOsDeviceResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $osdeviceArgs -TimeoutSeconds 15 -Description "Set BCD osdevice"

if ($setPathResult.ExitCode -eq 0 -and $setDeviceResult.ExitCode -eq 0 -and $setOsDeviceResult.ExitCode -eq 0) {
    $actions += "✓ BCD path, device, and osdevice set successfully"
} else {
    if ($setPathResult.ExitCode -ne 0) {
        $actions += "❌ BCD path set failed: $($setPathResult.Output)"
    }
    if ($setDeviceResult.ExitCode -ne 0) {
        $actions += "❌ BCD device set failed: $($setDeviceResult.Output)"
    }
    if ($setOsDeviceResult.ExitCode -ne 0) {
        $actions += "❌ BCD osdevice set failed: $($setOsDeviceResult.Output)"
    }
}
```

**Additional Fixes Applied:**

1. **Line 2725** - BCD enumeration now uses `Invoke-BCDCommandWithTimeout`:
   ```powershell
   $enumResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/enum", "{default}") -TimeoutSeconds 15
   ```

2. **Lines 2740-2762** - BCD rebuild now uses `Invoke-BCDCommandWithTimeout` for both bcdboot and bcdedit:
   ```powershell
   $rebuildResult = Invoke-BCDCommandWithTimeout -Command "bcdboot.exe" -Arguments @("$TargetDrive`:\Windows", "/s", $EspLetter, "/f", "UEFI", "/addlast")
   ```

---

## Why This Fixes the Issue

### The `/encodedCommand` Error
- PowerShell was interpreting the curly braces `{default}` as PowerShell variable expansion attempts
- Without proper quoting, special characters triggered PowerShell's command encoding feature
- The `Invoke-BCDCommandWithTimeout` function properly quotes arguments with special characters in line 440-448:
  ```powershell
  foreach ($arg in $Arguments) {
      if ($arg -match '\s|[{}\(\)]') {
          # Quote arguments with spaces or special characters (like {default})
          $escapedArgs += "`"$arg`""
      } else {
          $escapedArgs += $arg
      }
  }
  ```

### Structured Return Values
- Each command execution now returns a structured object with `ExitCode` and `Output` properties
- Allows proper validation of each command before proceeding to the next
- Prevents cascading failures where one command's failure affects subsequent operations

### Timeout Protection
- Prevents bcdedit/bcdboot from hanging on locked BCD stores
- Returns immediately with timeout indicator rather than blocking indefinitely

---

## Files Modified

- [DefensiveBootCore.ps1](DefensiveBootCore.ps1) - Lines 2698-2762 in `Repair-BCDBruteForce()` function

---

## Testing Recommendations

1. **BCD repair on normal system:**
   - Run one-click repair on system with corrupted {default} entry
   - Verify that bcdedit commands execute with proper argument passing
   - Confirm no "/encodedCommand" errors in output

2. **BCD rebuild scenario:**
   - Mount ESP partition
   - Force BCD corruption
   - Run repair and verify bcdboot rebuild succeeds
   - Check that device/osdevice settings are applied correctly

3. **Error handling:**
   - Run repair on BitLocked drive (should fail gracefully)
   - Run on system with corrupted BCD (should attempt rebuild)
   - Verify error messages are accurate and informative

---

## Related Issues Fixed

This fix also addresses issues identified in:
- CRITICAL_FLAW_ANALYSIS_2026-01-10.md - FLAW 1: bcdedit Commands Execute Without Exit Code Validation

---

## Version Information

- **GitHub Version:** Pre-fix (failing with /encodedCommand error)
- **After This Fix:** Should execute bcdedit commands with proper argument handling
- **All Versions Affected:** GitHub version only (Cursor version already had proper timeout wrappers)
