# Brute Force Boot Fixer - Research & Implementation Plan

## Problem Statement

Users report that after running the repair, the system reports success but critical files (like `winload.efi`) are still missing. The current repair mode:
- Only checks `Test-Path` after copy (doesn't verify integrity)
- Doesn't extract from install.wim if no source found
- Doesn't retry failed operations
- Doesn't verify BCD was actually updated correctly
- Doesn't do comprehensive post-repair verification

## Research: What Makes a "Brute Force" Repair?

### Current Repair Gaps Identified

1. **File Verification**
   - Current: Only checks if file exists (`Test-Path`)
   - Missing: File size validation, hash verification, permission checks
   - Missing: Multiple verification attempts

2. **Source Discovery**
   - Current: Checks other Windows installs, WinRE paths
   - Missing: Extract from install.wim/esd if no source found
   - Missing: Search mounted ISOs/USB drives
   - Missing: Search network shares if available

3. **Copy Operations**
   - Current: Single attempt with `Copy-Item`
   - Missing: Retry logic with exponential backoff
   - Missing: Alternative copy methods (robocopy, xcopy, direct file I/O)
   - Missing: Verify copy succeeded before proceeding

4. **BCD Repair**
   - Current: Single `bcdedit /set` command
   - Missing: Verify BCD was actually updated
   - Missing: Rebuild BCD completely if set fails
   - Missing: Verify BCD path matches actual file location

5. **Post-Repair Verification**
   - Current: Basic `Test-Path` check
   - Missing: Comprehensive bootability verification
   - Missing: All boot files present check
   - Missing: BCD integrity validation
   - Missing: Boot file permissions verification

## Brute Force Mode Requirements

### Phase 1: Aggressive Source Discovery
1. Search all mounted drives for `winload.efi`
2. Search mounted ISOs/USB drives
3. Extract from `install.wim`/`install.esd` if found
4. Search network shares (if available)
5. Use WinRE as last resort

### Phase 2: Aggressive File Operations
1. Try multiple copy methods:
   - `Copy-Item` (PowerShell)
   - `robocopy` (more reliable)
   - `xcopy` (legacy compatibility)
   - Direct .NET file I/O (bypasses some permission issues)
2. Retry failed operations (3-5 attempts with backoff)
3. Force permissions before/after copy:
   - `takeown /f <file>`
   - `icacls <file> /grant Administrators:F /T`
   - `attrib -s -h -r <file>`
4. Verify file integrity:
   - File size matches source
   - File exists and is readable
   - Permissions are correct

### Phase 3: Aggressive BCD Repair
1. Backup BCD (always)
2. Try `bcdedit /set` (standard method)
3. Verify BCD was updated (read back and check)
4. If verification fails, rebuild BCD completely:
   - `bcdedit /export <backup>`
   - `bootrec /rebuildbcd`
   - `bcdboot <drive>:\Windows /s <ESP> /f ALL`
5. Verify BCD path matches actual file location

### Phase 4: Comprehensive Verification
1. **File Presence Verification**
   - `winload.efi` exists at target location
   - `bootmgfw.efi` exists in ESP
   - `BCD` exists and is readable
   - All critical boot files present

2. **File Integrity Verification**
   - File sizes match expected values
   - Files are readable (not corrupted)
   - Permissions are correct

3. **BCD Verification**
   - BCD can be enumerated
   - Default entry points to `winload.efi`
   - Device and osdevice match target drive
   - Path is correct format

4. **Bootability Indicators**
   - All boot files present
   - BCD is valid and points to correct files
   - ESP is accessible
   - No BitLocker lock (if applicable)

## Implementation Steps

### Step 1: Create Core Brute Force Function
- Function: `Invoke-BruteForceBootRepair`
- Parameters: `-TargetDrive`, `-Mode`, `-MaxRetries`, `-ExtractFromWim`
- Returns: Detailed repair report with verification results

### Step 2: Implement Aggressive Source Discovery
- Function: `Find-WinloadSourceAggressive`
- Searches: All drives, ISOs, install.wim, network shares
- Returns: Best source with confidence score

### Step 3: Implement Robust File Copy
- Function: `Copy-BootFileBruteForce`
- Methods: Multiple copy methods with retry logic
- Verification: Size, existence, permissions

### Step 4: Implement BCD Repair with Verification
- Function: `Repair-BCDBruteForce`
- Steps: Set, verify, rebuild if needed
- Verification: Read back and validate

### Step 5: Implement Comprehensive Verification
- Function: `Test-BootabilityComprehensive`
- Checks: All files, BCD, permissions, integrity
- Returns: Detailed verification report

### Step 6: Integrate into GUI
- Add "Brute Force Mode" option to One-Click Repair
- Show aggressive operations in preview
- Display comprehensive verification results

## Verification Test Cases

1. **Missing winload.efi (no source found)**
   - Should extract from install.wim if available
   - Should verify file after copy
   - Should verify BCD after repair

2. **winload.efi copy fails (permissions)**
   - Should retry with different methods
   - Should force permissions
   - Should verify after each attempt

3. **BCD repair fails**
   - Should rebuild BCD completely
   - Should verify BCD after rebuild
   - Should verify path matches file location

4. **Post-repair verification**
   - Should check all boot files
   - Should verify BCD integrity
   - Should report actual bootability status

## Risk Mitigation

1. **Always backup BCD** before any modifications
2. **Verify after each operation** before proceeding
3. **Rollback capability** if verification fails
4. **Comprehensive logging** of all operations
5. **User confirmation** for destructive operations

## Success Criteria

1. ✅ `winload.efi` is actually present after repair (verified, not just reported)
2. ✅ BCD actually points to correct file (verified, not just set)
3. ✅ All boot files are present and accessible
4. ✅ Comprehensive verification report shows actual status
5. ✅ Users can see exactly what was fixed and verified
