# Boot Repair Failover System

## Overview

The **Boot Repair Failover System** provides multiple layers of repair functions to ensure boot repair can succeed even when primary functions fail or are unavailable. This system prevents total failure by automatically switching to simpler, more robust repair methods.

## Architecture

The failover system consists of three repair layers:

```
┌─────────────────────────────────────────────────────────┐
│                    PRIMARY REPAIR                         │
│  (Invoke-DefensiveBootRepair / Invoke-BruteForceBootRepair)│
│  - Full-featured repair with comprehensive logic         │
│  - Uses advanced functions and error handling            │
│  - May fail if dependencies break                        │
└──────────────────────┬────────────────────────────────────┘
                       │
                       ▼ (if fails)
┌─────────────────────────────────────────────────────────┐
│                    BACKUP REPAIR                         │
│  (Invoke-BackupBootRepair)                               │
│  - Simplified repair using basic Windows commands        │
│  - Minimal dependencies                                  │
│  - Focuses on core boot repair only                     │
└──────────────────────┬────────────────────────────────────┘
                       │
                       ▼ (if fails)
┌─────────────────────────────────────────────────────────┐
│                 LAST EFFORT REPAIR                       │
│  (Invoke-LastEffortBootRepair)                          │
│  - Absolute bare minimum repair                         │
│  - Only: copy winload.efi + run bcdboot                 │
│  - No complex logic, no dependencies                     │
└─────────────────────────────────────────────────────────┘
```

## Functions

### 1. `Invoke-BackupBootRepair`

**Purpose**: Simplified repair function using basic Windows commands directly.

**Characteristics**:
- Uses `Test-Path`, `Copy-Item`, `bcdboot.exe` directly
- Minimal error handling (fail fast)
- No complex dependencies
- Focuses on core boot repair only

**Operations**:
1. Check if `winload.efi` exists
2. Search for `winload.efi` on other drives if missing
3. Copy `winload.efi` if source found
4. Use `bcdboot.exe` to rebuild BCD (simplest method)
5. Basic verification

**When Used**:
- Primary repair function fails or throws exception
- Primary repair function not available
- Primary repair completes but system not bootable

### 2. `Invoke-LastEffortBootRepair`

**Purpose**: Absolute last resort repair - bare minimum to fix boot.

**Characteristics**:
- Only does two things: copy winload.efi + run bcdboot
- No complex logic
- No dependencies on other functions
- Uses only built-in Windows commands

**Operations**:
1. Find and copy `winload.efi` if missing (from any available source)
2. Run `bcdboot.exe` once to create/repair BCD
3. Basic success/failure check

**When Used**:
- Backup repair function fails
- All other repair methods have failed
- System is in critical state

### 3. `Invoke-BootRepairWithFailover`

**Purpose**: Automatic failover wrapper that tries all repair methods in order.

**Behavior**:
1. Attempts primary repair function first
2. If primary fails or returns non-bootable, switches to backup
3. If backup fails, switches to last effort
4. Returns result from first successful repair, or last attempt if all fail
5. Logs all attempts for diagnostic purposes

**Return Value**:
- Includes `RepairMode` field indicating which method was used
- Includes `FailoverUsed` boolean indicating if failover was needed
- Includes `LastResort` boolean if last effort was used

## Integration

### GUI Handler (`WinRepairGUI.ps1`)

**Location**: One-Click Repair button handler

**Behavior**:
1. Attempts primary repair function
2. If primary fails or unavailable, automatically calls `Invoke-BootRepairWithFailover`
3. Displays repair mode used in status text
4. Shows warning if failover was used

**User Experience**:
- Seamless - user doesn't need to do anything
- Status bar shows which repair mode is active
- Output box shows detailed results from all attempts

### TUI Handler (`WinRepairTUI.ps1`)

**Location**: `Invoke-OneClickRepairTUI` function

**Behavior**:
1. Attempts primary repair function
2. If primary fails, automatically calls `Invoke-BootRepairWithFailover`
3. Displays repair mode in console with color coding
4. Shows clear messages when switching modes

**User Experience**:
- Color-coded output (Cyan for primary, Yellow for backup, Red for last effort)
- Clear messages when switching modes
- Detailed error reporting

## Failure Scenarios Handled

### Scenario 1: Primary Function Not Available
**Cause**: Function not loaded, dependency missing, script error
**Solution**: Automatically switches to backup function

### Scenario 2: Primary Function Throws Exception
**Cause**: Unexpected error, permission issue, file system problem
**Solution**: Catches exception and switches to backup function

### Scenario 3: Primary Function Completes But System Not Bootable
**Cause**: Complex logic failed, edge case not handled
**Solution**: Detects non-bootable result and switches to backup function

### Scenario 4: Backup Function Also Fails
**Cause**: Severe system corruption, hardware issue
**Solution**: Switches to last effort function (bare minimum)

### Scenario 5: All Functions Fail
**Cause**: Critical system failure, hardware failure
**Solution**: Returns comprehensive failure report with all attempt details

## Benefits

1. **Resilience**: System can recover from failures in primary functions
2. **Reliability**: Multiple fallback options ensure repair is attempted
3. **Simplicity**: Backup functions use simpler methods that are less likely to fail
4. **Transparency**: Users see which repair mode was used
5. **Diagnostics**: All attempts are logged for troubleshooting

## Usage Examples

### Automatic Failover (Recommended)
```powershell
# GUI/TUI automatically use failover
# User just clicks "Repair" - system handles failover automatically
```

### Manual Backup Function
```powershell
$result = Invoke-BackupBootRepair -TargetDrive "C"
if ($result.Bootable) {
    Write-Host "Backup repair succeeded!"
}
```

### Manual Last Effort
```powershell
$result = Invoke-LastEffortBootRepair -TargetDrive "C"
if ($result.Success) {
    Write-Host "Last effort repair succeeded!"
}
```

### Manual Failover Wrapper
```powershell
$result = Invoke-BootRepairWithFailover -TargetDrive "C" -Mode "Auto"
Write-Host "Repair mode used: $($result.RepairMode)"
Write-Host "Failover used: $($result.FailoverUsed)"
```

## Best Practices

1. **Always use failover wrapper in production**
   - Provides automatic recovery from failures
   - Ensures repair is attempted even if primary fails

2. **Log repair mode used**
   - Helps diagnose issues
   - Identifies when failover was needed

3. **Report failover to user**
   - Transparency builds trust
   - Helps user understand what happened

4. **Test all three layers**
   - Ensure backup functions work
   - Verify last effort function works
   - Test failover logic

## Troubleshooting

### Issue: All repair attempts fail
**Diagnosis**: Check failure summary in result
**Solution**: Review all attempt details, check hardware, verify drive accessibility

### Issue: Failover always used
**Diagnosis**: Primary function may have a bug
**Solution**: Check primary function logs, fix underlying issue

### Issue: Last effort always used
**Diagnosis**: Backup function may have a bug
**Solution**: Check backup function logs, verify dependencies

## Related Functions

- `Invoke-DefensiveBootRepair`: Primary repair function
- `Invoke-BruteForceBootRepair`: Primary repair function (aggressive mode)
- `Test-BootRepairReadiness`: Pre-flight validation
- `Test-BootabilityComprehensive`: Post-repair verification

## See Also

- `DefensiveBootCore.ps1`: Core repair logic
- `WinRepairGUI.ps1`: GUI integration
- `WinRepairTUI.ps1`: TUI integration
- `READINESS_CHECK_SYSTEM.md`: Pre-flight validation
