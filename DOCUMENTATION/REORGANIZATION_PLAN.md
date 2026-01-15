# REORGANIZATION AND REFACTORING PLAN
## MiracleBoot v7.2 - Production Ready Restructuring

---

## CURRENT STATE ANALYSIS

### ROOT FOLDER CLEANUP NEEDED

**Type A: PRODUCTION CODE (Keep in Root or move to src/)**
- MiracleBoot.ps1 - MAIN ENTRY POINT
- AutoLogAnalyzer.ps1 - PRODUCTION
- AutoLogAnalyzer_Enhanced.ps1 - PRODUCTION
- AutoLogAnalyzer_Lite.ps1 - PRODUCTION
- ErrorCodeDatabase.ps1 - PRODUCTION
- NetworkDiagnostics.ps1 - PRODUCTION

**Type B: TEST SCRIPTS (Move to TEST/ folder)**
- TEST_SIMPLE_LOAD.ps1
- TEST_LOAD_DIAGNOSTIC.ps1
- TEST_GUI_ERRORS_DETAILED.ps1
- COMPREHENSIVE_GUI_TEST.ps1
- DEBUG_GUI_ERRORS.ps1
- RUN_ALL_TESTS.ps1

**Type C: LAUNCH HELPERS (Keep in Root as quick launchers)**
- RUN_MIRACLEBOOT_ADMIN.bat
- RUN_ANALYZER_ENHANCED.cmd
- RUN_LOG_ANALYZER.cmd
- RUN_DIAGNOSTIC_AS_ADMIN.bat
- RunMiracleBoot.cmd

**Type D: DOCUMENTATION (Move to DOCS/)**
- *.md files (except critical README)
- *.txt info files
- *.txt guide files

**Type E: VALIDATION SCRIPTS (Already in VALIDATION/)**
- Keep as is - contains QA tests

**Type F: LOG/OUTPUT FILES (Clean up - these are temp)**
- *.log files
- GUI_ERROR_REPORT.log
- TEST_SIMPLE_LOAD_OUTPUT.log
- PRODUCTION_AUDIT_OUTPUT.txt
- PRODUCTION_ASSESSMENT_REPORT.txt

**Type G: ARCHIVES/OUTDATED (Move to ARCHIVE/)**
- LAST_KNOWN_WORKING/
- RunMiracleBoot_Github.zip
- Outdated summary files

---

## RECOMMENDED NEW STRUCTURE

```
MiracleBoot_v7.2/
├── MiracleBoot.ps1 ........................ MAIN ENTRY POINT
├── README.md .............................. QUICK START
├── LICENSE ............................... Apache 2.0
│
├── HELPER SCRIPTS/ ........................ CORE FUNCTIONALITY
│   ├── WinRepairCore.ps1 ................. Main repair operations
│   ├── WinRepairGUI.ps1 .................. GUI implementation
│   ├── WinRepairTUI.ps1 .................. Terminal UI fallback
│   ├── EnsureRepairInstallReady.ps1 ..... Pre-flight checks
│   │
│   ├── Analytics/ ........................ Subsystem: Logging/Analysis
│   │   ├── AutoLogAnalyzer.ps1
│   │   ├── AutoLogAnalyzer_Enhanced.ps1
│   │   ├── AutoLogAnalyzer_Lite.ps1
│   │   └── ErrorCodeDatabase.ps1
│   │
│   ├── Diagnostics/ ...................... Subsystem: System Diagnostics
│   │   ├── NetworkDiagnostics.ps1
│   │   └── MiracleBoot-SlowPCAnalyzer.ps1
│   │
│   └── Utils/ ............................ Utility Functions
│       └── (Any common utility modules)
│
├── TEST/ ................................. AUTOMATED TESTS
│   ├── Core/ ............................. Unit tests for core functions
│   │   ├── Test-WinRepairCore.ps1
│   │   ├── Test-XAML-Parsing.ps1
│   │   └── Test-Admin-Check.ps1
│   │
│   ├── Integration/ ...................... End-to-end tests
│   │   ├── Test-GUI-Launch.ps1
│   │   ├── Test-TUI-Fallback.ps1
│   │   └── Test-Error-Handling.ps1
│   │
│   └── Scenarios/ ........................ Force-fail tests
│       ├── Test-MTA-Thread.ps1
│       ├── Test-Missing-Assembly.ps1
│       └── Test-Missing-Script.ps1
│
├── VALIDATION/ ........................... PRODUCTION QA SUITE
│   ├── Production-Audit.ps1
│   ├── Final-QA-Verification.ps1
│   ├── Load-Test.ps1
│   └── README.md
│
├── DOCS/ ................................. DOCUMENTATION
│   ├── Quick-Start-Guide.md
│   ├── Advanced-Usage.md
│   ├── Troubleshooting.md
│   ├── Error-Database.md
│   ├── API-Reference.md
│   └── Architecture.md
│
├── EXAMPLES/ ............................. EXAMPLE SCRIPTS
│   ├── custom-repair-script-template.ps1
│   ├── automated-daily-check.ps1
│   └── enterprise-integration.ps1
│
├── LOGS/ ................................. OUTPUT & LOGS (gitignored)
│   └── (runtime logs go here)
│
└── ARCHIVE/ ............................. OLD VERSIONS
    └── v7.1/
```

---

## FUNCTION REFACTORING NEEDED

### In WinRepairCore.ps1 - SPLIT THESE:

**1. Get-WindowsHealthSummary() - TOO LARGE**
   Current: ~300+ lines in one function
   Split into:
   - Get-BCDHealth()
   - Get-EFIHealth()
   - Get-BootStackOrder()
   - Get-UpdateEligibility()
   - Get-WindowsHealthSummary() - Orchestrator (calls above)

**2. Start-GUI() in WinRepairGUI.ps1 - TOO LARGE**
   Current: ~4000 lines in one function
   Split into:
   - Initialize-GUI() - XAML parsing
   - Register-ButtonHandlers() - Event binding
   - Register-TabHandlers() - Tab functionality
   - Populate-InitialData() - Load data
   - Show-MainWindow() - Display

**3. Any function > 200 lines should be reviewed**

---

## IMMEDIATE ACTIONS NEEDED

### Step 1: Create Folder Structure
```powershell
mkdir HELPER SCRIPTS\Analytics
mkdir HELPER SCRIPTS\Diagnostics
mkdir HELPER SCRIPTS\Utils
mkdir TEST\Core
mkdir TEST\Integration
mkdir TEST\Scenarios
mkdir DOCS
mkdir EXAMPLES
mkdir LOGS
mkdir ARCHIVE
```

### Step 2: Move & Rename Files
- Move AutoLogAnalyzer*.ps1 → HELPER SCRIPTS/Analytics/
- Move ErrorCodeDatabase.ps1 → HELPER SCRIPTS/Analytics/
- Move NetworkDiagnostics.ps1 → HELPER SCRIPTS/Diagnostics/
- Move MiracleBoot-SlowPCAnalyzer.ps1 → HELPER SCRIPTS/Diagnostics/
- Move all TEST_*.ps1 → TEST/Core/ or TEST/Integration/
- Move all *.md → DOCS/ (except this file)
- Move LAST_KNOWN_WORKING/ → ARCHIVE/v7.1/

### Step 3: Update Import Paths in MiracleBoot.ps1
- Update all `. $path` calls to reflect new locations
- Use `$PSScriptRoot` relative paths

### Step 4: Create Quick-Start Launchers
Keep in root:
- MiracleBoot.ps1 (entry point)
- RunMiracleBoot.cmd (quick launch)
- README.md (first look)

---

## VALIDATION AFTER REORGANIZATION

```
[ ] All imports still work
[ ] No broken relative paths
[ ] MiracleBoot.ps1 launches GUI successfully
[ ] TUI fallback works
[ ] All tests in TEST/ folder pass
[ ] VALIDATION/ suite passes
[ ] Production audit shows 0 import errors
```

---

## CRITICAL FIXES TO APPLY DURING REFACTORING

While moving files, also apply these critical fixes:

### Fix 1: Remove SilentlyContinue (Line 2 of MiracleBoot.ps1)
```powershell
# BEFORE:
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue

# AFTER:
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
} catch {
    Write-Host "Cannot set execution policy. Run as Administrator." -ForegroundColor Red
    exit 1
}
```

### Fix 2: Add STA Thread Check (Start of Start-GUI in WinRepairGUI.ps1)
```powershell
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    throw 'WPF requires STA thread'
}
```

### Fix 3: Protect ShowDialog (WinRepairGUI.ps1 line ~3978)
```powershell
try {
    $W.ShowDialog() | Out-Null
} catch {
    Write-Host "GUI failed: $_" -ForegroundColor Red
    # Fallback to TUI
    . (Join-Path (Split-Path $PSScriptRoot) 'WinRepairTUI.ps1')
    Start-TUI
}
```

---

## NEXT STEPS (PRIORITY ORDER)

1. **Create new folder structure** (5 minutes)
2. **Move files to appropriate folders** (10 minutes)
3. **Update all import paths** (30 minutes)
4. **Apply 6 critical fixes** (15 minutes)
5. **Test all imports** (15 minutes)
6. **Validate with audit** (10 minutes)
7. **Update documentation** (20 minutes)

**Total Time: ~2 hours**

---

## SUCCESS CRITERIA

✓ Root folder has < 10 scripts (only entry points)
✓ All helper scripts in HELPER SCRIPTS/ with subfolders
✓ All tests in TEST/ folder
✓ All docs in DOCS/ folder
✓ All imports working
✓ MiracleBoot launches GUI
✓ Fallback to TUI works
✓ Production audit passes
✓ No broken file references

