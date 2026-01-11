# Boot Repair Readiness Check System

## Overview

The **Boot Repair Readiness Check System** is a comprehensive pre-flight validation system that prevents common errors before repair operations begin. It was implemented to address issues like "Cannot bind argument to parameter 'Path' because it is an empty string" and similar production failures.

## Purpose

This system ensures that:
1. All required parameters are valid and non-empty
2. Required functions are loaded and available
3. Environment is suitable for repair operations
4. Permissions are adequate
5. Critical paths exist and are accessible

## Function: `Test-BootRepairReadiness`

### Location
`DefensiveBootCore.ps1` (after helper functions, before repair functions)

### Parameters
- **TargetDrive** (Mandatory): The target drive letter to validate
- **RequiredFunctions** (Optional): Array of function names that must be available
- **CheckPermissions** (Switch): Whether to verify Administrator privileges
- **CheckPaths** (Switch): Whether to validate critical file paths

### Return Value
Returns a hashtable with:
- **Ready** (Boolean): Whether all critical checks passed
- **Issues** (Array): List of blocking issues
- **Warnings** (Array): List of non-blocking warnings
- **Checks** (Hashtable): Detailed results for each check
- **Summary** (String): Human-readable summary

### Checks Performed

#### 1. TargetDrive Not Empty
- Validates that `TargetDrive` parameter is not null or empty
- **Failure Impact**: Blocks all operations

#### 2. TargetDrive Format Valid
- Validates format is a single letter (A-Z)
- Strips colons and whitespace
- **Failure Impact**: Blocks all operations

#### 3. TargetDrive Exists
- Verifies drive exists using `Get-PSDrive`
- Checks drive is accessible
- **Failure Impact**: Blocks all operations

#### 4. Required Functions Available
- Checks each function in `RequiredFunctions` array
- Uses `Get-Command` to verify availability
- **Failure Impact**: Blocks all operations

#### 5. Administrator Permissions
- Verifies current process has Administrator privileges
- Uses `WindowsPrincipal` and `WindowsBuiltInRole`
- **Failure Impact**: Blocks all operations

#### 6. Critical Paths Accessible
- Validates `C:\Windows` exists
- Validates `C:\Windows\System32` exists
- **Failure Impact**: Warning only (non-blocking)

#### 7. Environment State
- Determines if running in WinPE/WinRE or Full Windows
- Uses `Get-EnvState` function
- **Failure Impact**: Warning only (non-blocking)

## Integration Points

### 1. GUI Handler (`WinRepairGUI.ps1`)

**Location**: Before calling repair functions (after user confirmation)

**Behavior**:
- Runs readiness check with required functions list
- Shows detailed error dialog if checks fail
- Displays all issues and warnings in output box
- Prevents repair execution if any critical check fails

**Example**:
```powershell
$readiness = Test-BootRepairReadiness -TargetDrive $targetDrive `
    -RequiredFunctions @("Invoke-DefensiveBootRepair") `
    -CheckPermissions -CheckPaths

if (-not $readiness.Ready) {
    # Show error dialog with details
    # Prevent repair execution
}
```

### 2. TUI Handler (`WinRepairTUI.ps1`)

**Location**: In `Invoke-OneClickRepairTUI` function

**Behavior**:
- Runs readiness check before repair
- Displays results in console with color coding
- Shows issues in red, warnings in yellow
- Blocks repair if critical checks fail

**Example**:
```powershell
$readiness = Test-BootRepairReadiness -TargetDrive $TargetDrive `
    -RequiredFunctions @("Invoke-DefensiveBootRepair") `
    -CheckPermissions -CheckPaths

if (-not $readiness.Ready) {
    Write-Host "READINESS CHECK FAILED:" -ForegroundColor Red
    # Display issues and exit
}
```

### 3. Repair Functions (`DefensiveBootCore.ps1`)

**Location**: At the start of `Invoke-DefensiveBootRepair` and `Invoke-BruteForceBootRepair`

**Behavior**:
- Runs readiness check as first operation
- Falls back to basic validation if readiness check unavailable
- Returns error result if checks fail
- Prevents execution of repair logic

**Example**:
```powershell
if (Get-Command Test-BootRepairReadiness -ErrorAction SilentlyContinue) {
    $readiness = Test-BootRepairReadiness -TargetDrive $TargetDrive `
        -CheckPermissions -CheckPaths
    if (-not $readiness.Ready) {
        return @{
            Output = "Readiness check failed: ..."
            Bootable = $false
            # ...
        }
    }
}
```

## Error Prevention

### Before Readiness Checks
Common errors that occurred:
- "Cannot bind argument to parameter 'Path' because it is an empty string"
- "Drive not found" errors
- "Function not found" errors
- Permission denied errors
- Invalid path errors

### After Readiness Checks
All these errors are caught **before** repair operations begin:
- Empty parameters are detected immediately
- Invalid drive letters are caught
- Missing functions are identified
- Permission issues are flagged
- Invalid paths are detected

## Usage Examples

### Basic Usage
```powershell
$readiness = Test-BootRepairReadiness -TargetDrive "C"
if (-not $readiness.Ready) {
    Write-Error "Readiness check failed: $($readiness.Issues -join '; ')"
    return
}
```

### With Required Functions
```powershell
$readiness = Test-BootRepairReadiness -TargetDrive "C" `
    -RequiredFunctions @("Invoke-DefensiveBootRepair", "Test-BootabilityComprehensive")
if (-not $readiness.Ready) {
    # Handle failure
}
```

### Detailed Check Results
```powershell
$readiness = Test-BootRepairReadiness -TargetDrive "C" -CheckPermissions -CheckPaths

# Check individual results
foreach ($checkName in $readiness.Checks.Keys) {
    $check = $readiness.Checks[$checkName]
    Write-Host "$checkName : $($check.Message) - Passed: $($check.Passed)"
}
```

## Best Practices

1. **Always run readiness checks before repair operations**
   - Prevents runtime errors
   - Provides clear diagnostic information
   - Improves user experience

2. **Include required functions in check**
   - Ensures all dependencies are loaded
   - Prevents "function not found" errors

3. **Enable permission checks in production**
   - Prevents permission-related failures
   - Provides clear error messages

4. **Enable path checks when appropriate**
   - Validates critical directories exist
   - Provides warnings for missing paths

5. **Handle warnings appropriately**
   - Warnings don't block operations
   - But may indicate potential issues
   - Log warnings for troubleshooting

## Future Enhancements

Potential improvements:
- Network drive validation
- Disk space checks
- BitLocker status checks
- UEFI/BIOS compatibility checks
- Windows version compatibility
- Boot file integrity pre-checks
- BCD accessibility validation

## Related Functions

- `Test-BootabilityComprehensive`: Post-repair validation
- `Get-EnvState`: Environment detection
- `Invoke-DefensiveBootRepair`: Main repair function
- `Invoke-BruteForceBootRepair`: Aggressive repair function

## See Also

- `DefensiveBootCore.ps1`: Core repair logic
- `WinRepairGUI.ps1`: GUI integration
- `WinRepairTUI.ps1`: TUI integration
