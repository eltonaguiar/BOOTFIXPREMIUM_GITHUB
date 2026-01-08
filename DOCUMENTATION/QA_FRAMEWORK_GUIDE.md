# MiracleBoot QA Framework Documentation

## Overview

The MiracleBoot QA Framework is a comprehensive quality assurance system designed to ensure code reliability before user testing. It performs rigorous validation across multiple dimensions: **syntax, health, and functionality**.

---

## Quick Start

### Run Full QA Suite (Recommended)
```powershell
cd "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\VALIDATION"
.\QA_ORCHESTRATOR.ps1
```

### Run Individual Stages
```powershell
# Syntax validation only
.\QA_ORCHESTRATOR.ps1 -Stage syntax

# Health check only
.\QA_ORCHESTRATOR.ps1 -Stage health

# Runtime tests only
.\QA_ORCHESTRATOR.ps1 -Stage runtime
```

### Strict Mode (Fail on First Error)
```powershell
.\QA_ORCHESTRATOR.ps1 -StrictMode $true
```

---

## QA Framework Components

### 1. QA_SYNTAX_CHECKER.ps1
**Purpose:** Deep static analysis of PowerShell syntax

**What It Checks:**
- File tokenization and parsing
- Brace/parenthesis/bracket matching
- Function definition completeness
- Common syntax errors
- AST (Abstract Syntax Tree) compilation

**Output:**
- ✓ File-by-file syntax validation
- Error details with line context
- Summary statistics

**When to Use:**
- After any code modifications
- Before committing changes
- Pre-deployment validation

**Example Output:**
```
✓ MiracleBoot.ps1
✓ WinRepairCore.ps1
✗ BuggyScript.ps1
  → Brace mismatch: 5 open, 4 close
```

---

### 2. PRE_EXECUTION_HEALTH_CHECK.ps1
**Purpose:** Verifies system environment readiness before execution

**What It Checks:**

**Environment (Critical):**
- Administrator privileges
- PowerShell version (≥5.0)
- Windows OS detection
- System drive accessibility

**Project Structure (Critical):**
- Main scripts present
- Helper scripts folder exists
- Core modules available
- Documentation present

**Dependencies:**
- WPF Framework (for GUI mode)
- Windows Forms
- bcdedit command
- Network availability

**System Registry:**
- BCD store accessibility
- Windows installation validity
- Registry key permissions

**Critical Failures:**
The script will **STOP** if any critical check fails:
- Missing administrator rights
- PowerShell < 5.0
- Core scripts missing
- BCD access denied

**Example Output:**
```
✓ Administrator Privileges
✓ PowerShell Version: v5.1
✓ Windows Operating System
✓ Core Helper Scripts (4 scripts)
✗ BCD Store Access: Access denied - admin may be needed
```

---

### 3. QA_RUNTIME_TESTS.ps1
**Purpose:** Functional testing without user interaction

**Test Categories:**

#### Script Loading & Parsing (Critical)
- Main script existence
- File readability
- File size validation

#### Core Function Availability (Critical)
- Test-AdminPrivileges
- Get-WindowsVolumes
- Get-BCDEntries
- Get-BCDEntriesParsed

#### Utility Functions
- Get-EnvironmentType
- Test-PowerShellAvailability
- Test-NetworkAvailability
- Test-BrowserAvailability

#### System Integration
- System drive access
- Windows directory access
- bcdedit availability
- Network adapter detection

#### Error Handling
- Invalid path handling
- Edge case management
- Exception catching

#### Framework Dependencies
- WPF availability
- Windows Forms availability
- COM object creation

#### Syntax Validation (Critical)
- Main script tokenization
- Brace matching
- Parenthesis balance
- Bracket balance

**Example Output:**
```
Testing: Main script exists... PASS
Testing: Core functions available... PASS
Testing: bcdedit command available... PASS
Testing: WPF available for GUI... PASS

Pass Rate: 98.5%
✓ ALL TESTS PASSED - CODE IS READY FOR USE
```

---

### 4. QA_ORCHESTRATOR.ps1
**Purpose:** Master coordinator for all QA stages

**Responsibilities:**
1. Runs all stages in correct sequence
2. Captures and logs all output
3. Enforces strict mode (optional)
4. Generates comprehensive report
5. Returns proper exit codes

**Stages (in order):**
1. Syntax Validation
2. Pre-Execution Health Check
3. Runtime Functional Tests

**Exit Codes:**
- `0` = All stages passed ✓
- `1` = One or more stages failed ✗

**Log Output:**
- Location: `TEST_LOGS/QA_ORCHESTRATOR_[timestamp].log`
- Contains full output from all stages
- Timestamped for archival

---

## QA Workflow

### Before User Testing
```
1. Modify code → QA_SYNTAX_CHECKER → Fix syntax errors
2. Verify environment → PRE_EXECUTION_HEALTH_CHECK → Fix missing dependencies
3. Functional testing → QA_RUNTIME_TESTS → Fix runtime issues
4. Coordinate all → QA_ORCHESTRATOR → Review final report
```

### Continuous Integration
```
On Code Commit → QA_ORCHESTRATOR.ps1 -StrictMode $true → Block commit if fails
```

### Pre-Deployment
```
Final validation → QA_ORCHESTRATOR.ps1 → Review logs → Deploy if PASS
```

---

## Common Issues & Resolution

### Issue: "Administrator Privileges Required"
**Cause:** Script ran without admin rights
**Solution:** Right-click PowerShell → "Run as Administrator"

### Issue: "BCD Store Access: Access Denied"
**Cause:** Administrative rights needed for bcdedit
**Solution:** Run with admin privileges

### Issue: "WPF not available"
**Cause:** Windows installation missing presentation framework
**Solution:** Not critical - TUI mode will be used as fallback

### Issue: "Core Helper Scripts missing"
**Cause:** Scripts not in expected location
**Solution:** Verify HELPER SCRIPTS folder exists and contains required files

### Issue: "Syntax Error: Brace Mismatch"
**Cause:** Unmatched braces in script
**Solution:** Review file in editor, find and fix brace mismatch

### Issue: "Function Not Found"
**Cause:** Function defined in separate script not loaded
**Solution:** Verify script is loaded with `. $path` before calling function

---

## QA Checklist (Pre-Release)

Before releasing MiracleBoot to users:

```
□ Run QA_SYNTAX_CHECKER.ps1 - All scripts pass
□ Run PRE_EXECUTION_HEALTH_CHECK.ps1 - All critical checks pass
□ Run QA_RUNTIME_TESTS.ps1 - All functional tests pass
□ Run QA_ORCHESTRATOR.ps1 -StrictMode $true - Complete success
□ Review TEST_LOGS/QA_ORCHESTRATOR_[latest].log - No errors
□ Test on clean Windows installation - Manual smoke test
□ Verify GUI mode launches successfully
□ Verify TUI mode launches successfully
□ Test in WinRE/WinPE environment - Environment detection
```

---

## Test Results Interpretation

### All Green ✓
```
✓ Syntax Validation PASSED
✓ Health Check PASSED  
✓ Runtime Tests PASSED
Result: CODE IS PRODUCTION READY
Action: Proceed with user testing
```

### Mixed Results ⚠
```
✓ Syntax Validation PASSED
✓ Health Check PASSED
✗ Runtime Tests FAILED
Result: FUNCTIONAL ISSUES FOUND
Action: Review specific test failures, fix issues, rerun
```

### All Red ✗
```
✗ Syntax Validation FAILED
Result: CANNOT PROCEED
Action: Fix syntax errors immediately, verify file integrity
```

---

## Performance Expectations

| Stage | Typical Duration | Max Duration |
|-------|------------------|--------------|
| Syntax Validation | 2-5 seconds | 10 seconds |
| Health Check | 3-7 seconds | 15 seconds |
| Runtime Tests | 5-10 seconds | 30 seconds |
| **Total (All)** | **10-22 seconds** | **55 seconds** |

---

## Logging & Artifacts

### Log Locations
- **QA Logs:** `TEST_LOGS/QA_ORCHESTRATOR_*.log`
- **Test Results:** `TEST_LOGS/` (timestamped)
- **Validation Reports:** `VALIDATION/` folder

### Log Format
```
================================================================================
MiracleBoot QA Orchestrator Report
Generated: 2026-01-07 15:30:45
Stage: all
Strict Mode: false
================================================================================
[Stage output here...]
================================================================================
✓ ALL QA STAGES PASSED - CODE IS PRODUCTION READY
================================================================================
```

### Archival
- Logs automatically timestamped
- Review logs for compliance verification
- Keep logs for deployment audit trail

---

## Advanced Usage

### Custom Script Validation
```powershell
$scriptPath = "C:\path\to\script.ps1"
. $scriptPath  # Load your script
# Run manual tests on loaded functions
```

### Batch Validation
```powershell
# Validate all scripts in a folder
Get-ChildItem "C:\path" -Filter "*.ps1" | ForEach-Object {
    .\QA_SYNTAX_CHECKER.ps1 -FilePath $_.FullPath
}
```

### Continuous Monitoring
```powershell
# Run QA every hour (Windows Task Scheduler)
# Action: powershell.exe -File "QA_ORCHESTRATOR.ps1"
# Trigger: Recurring every 1 hour
```

---

## Best Practices

1. **Always run full QA before user testing**
   - Don't skip stages
   - Review all output

2. **Fix issues in order**
   - Syntax errors first
   - Then health issues
   - Then functional problems

3. **Run in admin PowerShell**
   - Required for full diagnostics
   - Ensures accurate results

4. **Review logs for warnings**
   - Even if "PASSED", check for warnings
   - Address warnings before release

5. **Test on target systems**
   - Windows 10/11 (GUI mode)
   - Windows PE (TUI mode)
   - Windows Recovery (TUI mode)

---

## Support & Troubleshooting

If QA fails unexpectedly:

1. **Check PowerShell version:** `$PSVersionTable.PSVersion`
2. **Verify admin rights:** Run as Administrator
3. **Review error messages:** Read full error output
4. **Check logs:** Review detailed log file
5. **Isolate issue:** Run individual stages
6. **Consult documentation:** See specific QA script docs

---

## Summary

The MiracleBoot QA Framework ensures:
- ✓ **Syntax Correctness** - No parsing errors
- ✓ **Environment Readiness** - All dependencies available
- ✓ **Functional Integrity** - All features work
- ✓ **Error Handling** - Graceful failure modes
- ✓ **Production Quality** - Ready for deployment

**Golden Rule:** Never proceed to user testing without a passing QA_ORCHESTRATOR run.
