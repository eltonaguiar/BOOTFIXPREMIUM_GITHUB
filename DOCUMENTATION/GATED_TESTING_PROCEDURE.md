# GATED TESTING PROCEDURE v7.2

## Purpose
Prevent code from being marked "READY FOR TESTING" if pre-UI checks fail. This is the only gate that matters.

## The Golden Rule
> **If HARDENED_PRE_FLIGHT_VERIFICATION.ps1 returns exit code 1, the code is NOT ready and must be FIXED before proceeding.**

This gate cannot be bypassed, ignored, or worked around. Period.

## Testing Workflow

### Step 1: Run Pre-Flight Verification (Gate 1 - MANDATORY)

```powershell
cd "c:\path\to\MiracleBoot"
powershell -NoProfile -ExecutionPolicy Bypass -File "HARDENED_PRE_FLIGHT_VERIFICATION.ps1" -Verbose
```

**Exit Code Meanings:**
- **0** = ALL PRE-UI CHECKS PASSED. Code is safe to test.
- **1** = CRITICAL FAILURES. Code is NOT ready. DO NOT PROCEED.

**Log Location:** `LOGS\PREFLIGHT_yyyyMMdd_HHmmss.log`

### Step 2: Review Gate Results

```powershell
# View the most recent pre-flight log
Get-Content (Get-ChildItem LOGS\PREFLIGHT_*.log | Sort-Object LastWriteTime -Desc | Select-Object -First 1)
```

### Step 3: Decision Point

**IF exit code = 0:**
```
✓ PROCEED TO TESTING
- All pre-UI checks passed
- Run full test suite
- Run GUI tests
- Run integration tests
```

**IF exit code = 1:**
```
✗ STOP - DO NOT TEST
- Review the PREFLIGHT_*.log file
- Identify which checks failed
- Fix those failures in code
- Run HARDENED_PRE_FLIGHT_VERIFICATION.ps1 again
- Repeat until exit code = 0
```

### Step 4: Full Test Execution (Only if Gate 1 = PASS)

Once HARDENED_PRE_FLIGHT_VERIFICATION.ps1 returns exit code 0:

```powershell
# Run all tests
TEST\RUN_ALL_TESTS.ps1

# Check overall result
if ($LASTEXITCODE -eq 0) {
    Write-Host "READY FOR PRODUCTION" -ForegroundColor Green
} else {
    Write-Host "TESTS FAILED - NOT READY" -ForegroundColor Red
}
```

## What Gets Checked (Gate 1)

### PHASE 1: Environment and Privileges
- [ ] Administrator Privileges (required for boot operations)
- [ ] PowerShell 5.0 or higher
- [ ] Windows OS detected
- [ ] 64-bit architecture (required for WPF)

### PHASE 2: File and Path Validation
- [ ] MiracleBoot.ps1 exists in root
- [ ] All helper scripts exist (WinRepairCore, GUI, TUI)
- [ ] All required folders exist (HELPER SCRIPTS, TEST, LOGS)

### PHASE 3: Syntax and Import Validation
- [ ] MiracleBoot.ps1 syntax is valid (no parse errors)
- [ ] All helper script syntax is valid
- [ ] System.Windows.Forms assembly available
- [ ] PresentationFramework assembly available

### PHASE 4: WPF and Threading
- [ ] XamlReader type available
- [ ] WPF Window objects can be created
- [ ] STA thread available for GUI

## Critical Failure Examples

**These failures mean: DO NOT TEST**

1. **Syntax Error in MiracleBoot.ps1**
   - Cause: Typo, unclosed bracket, etc.
   - Fix: Review syntax errors in pre-flight log, correct in code

2. **Missing Helper Script**
   - Cause: File not found or moved incorrectly
   - Fix: Restore file to HELPER SCRIPTS\

3. **WPF Assembly Not Available**
   - Cause: .NET Framework issue
   - Fix: Reinstall .NET Framework or use different machine

4. **Admin Privileges Required**
   - Cause: Running non-elevated PowerShell
   - Fix: Run "powershell -RunAsAdministrator" or use batch launcher

## Preventing False Positives

### What Causes False Positives (NEVER do this)

1. **Running tests without pre-flight gate**
   - Bad: "Let's just try launching it..."
   - Good: Run pre-flight verification FIRST

2. **Ignoring pre-flight failures**
   - Bad: "Exit code 1 but let's test anyway..."
   - Good: Exit code 1 = STOP. Fix the failure.

3. **Assuming code is ready without verification**
   - Bad: "I made a change, it looks good..."
   - Good: Run pre-flight verification after EVERY change

4. **Not checking pre-flight logs**
   - Bad: "It failed but I don't know why..."
   - Good: Review LOGS\PREFLIGHT_*.log to see exact failure

### When to Run Pre-Flight Verification

✓ EVERY TIME before testing
✓ After ANY code change
✓ After ANY folder structure change
✓ After updating helper scripts
✓ After changing imports or paths
✓ Before marking code "READY FOR TESTING"

## Exit Codes Explained

```
Exit Code 0:  ALL PRE-FLIGHT CHECKS PASSED - proceed to testing
Exit Code 1:  CRITICAL FAILURES - must fix before testing
```

There are only TWO possible outcomes. No middle ground.

## Example: Complete Gate Workflow

```powershell
# 1. Run pre-flight verification
C:\MiracleBoot> .\HARDENED_PRE_FLIGHT_VERIFICATION.ps1
[18:57:57] CRITICAL FAILURES DETECTED
exit code: 1

# 2. Check log to see what failed
C:\MiracleBoot> cat .\LOGS\PREFLIGHT_20260107_185757.log
[ERROR] [FAIL] Administrator Privileges - Script must run as Administrator

# 3. Fix the issue (run as admin)
C:\MiracleBoot> powershell -RunAsAdministrator

# 4. Run pre-flight verification again
C:\MiracleBoot> .\HARDENED_PRE_FLIGHT_VERIFICATION.ps1
[18:57:57] ALL PRE-FLIGHT CHECKS PASSED
exit code: 0

# 5. NOW we can test
C:\MiracleBoot> .\TEST\RUN_ALL_TESTS.ps1
Test Summary: 15 passed, 0 failed
exit code: 0

# 6. Code is READY FOR TESTING (and passed)
```

## Automated CI/CD Integration

For continuous integration pipelines:

```powershell
# Gate 1: Pre-flight verification (BLOCKER)
$preFlightResult = & powershell -NoProfile -ExecutionPolicy Bypass -File "HARDENED_PRE_FLIGHT_VERIFICATION.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "GATE 1 FAILED: Pre-flight verification" -ForegroundColor Red
    exit 1  # Block pipeline
}

# Gate 1 passed, proceed to testing
$testResult = & .\TEST\RUN_ALL_TESTS.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "GATE 2 FAILED: Test suite" -ForegroundColor Red
    exit 1
}

# Both gates passed
Write-Host "ALL GATES PASSED: Code ready for deployment" -ForegroundColor Green
exit 0
```

## Debugging Gate Failures

### Finding the Log File
```powershell
# Most recent pre-flight log
Get-ChildItem LOGS\PREFLIGHT_*.log -Newest 1 | Select-Object -ExpandProperty FullName

# Read the log
Get-Content (Get-ChildItem LOGS\PREFLIGHT_*.log -Newest 1)
```

### Understanding Failure Messages

Each failure line follows this format:
```
[TIMESTAMP] [FAIL] Check Name - Description of what failed
```

Example:
```
[18:57:57.386] [FAIL] Administrator Privileges - Script must run as Administrator
```

**Action:** Run PowerShell as Administrator

---

### Common Failures and Fixes

| Failure | Cause | Fix |
|---------|-------|-----|
| Administrator Privileges | Not running as admin | Run `powershell -RunAsAdministrator` |
| MiracleBoot.ps1 Exists | File missing | Restore MiracleBoot.ps1 to root folder |
| Helper: WinRepairCore.ps1 | File moved | Move back to `HELPER SCRIPTS\` |
| Syntax errors | Code syntax invalid | Check syntax in VS Code, fix, re-run |
| WPF not available | .NET Framework issue | May require system admin to fix |

## The 10+ False Positives Prevention Plan

### Problem Statement
- Previous approach: Code marked "ready" but wasn't
- Root cause: No gating mechanism before testing
- Solution: HARDENED_PRE_FLIGHT_VERIFICATION.ps1 is the single source of truth

### How This Prevents False Positives

1. **Automated Checks** - No manual review, just code
2. **Immediate Feedback** - Fails fast if something is wrong
3. **Clear Exit Codes** - 0 or 1, no ambiguity
4. **Detailed Logs** - Every failure is logged and traceable
5. **No Bypass Option** - Can't mark ready without passing gate
6. **Repeatable** - Same result every time, every machine
7. **Pre-UI Focus** - Catches errors before UI even tries to launch

### Accountability
- IF pre-flight returns 0: Code is mathematically proven ready
- IF code still fails: Investigation focuses on gate itself (expand coverage)
- IF gate is wrong: Improve gate, then re-test

## Testing Sign-Off Checklist

Before marking code READY:

- [ ] Run HARDENED_PRE_FLIGHT_VERIFICATION.ps1
- [ ] Verify exit code = 0
- [ ] Review LOGS\PREFLIGHT_*.log for any warnings
- [ ] Run TEST\RUN_ALL_TESTS.ps1
- [ ] Verify all tests passed
- [ ] Manually test GUI launch
- [ ] Verify TUI fallback works
- [ ] Document any issues found
- [ ] Sign off as READY for production

## Questions to Ask

Before testing, ask:

1. **Did HARDENED_PRE_FLIGHT_VERIFICATION.ps1 return 0?**
   - No → FIX NOW
   - Yes → Continue

2. **Did all tests pass?**
   - No → FIX NOW
   - Yes → Continue

3. **Did manual testing confirm UI launches?**
   - No → INVESTIGATE
   - Yes → Code is READY

---

## Status: GATED TESTING ACTIVE

This procedure is now in effect. All future testing MUST go through the pre-flight gate first.

**If you are testing code that didn't pass HARDENED_PRE_FLIGHT_VERIFICATION.ps1, STOP and report it.**

