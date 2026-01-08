# FUNCTION REFACTORING PLAN
## Split Overly Complex Functions into Modular Pieces

---

## PHASE 1: WinRepairCore.ps1 Refactoring

### Function: Get-WindowsHealthSummary()
**Current Status**: ~300+ lines, doing too much
**Issues**:
- BCD health check
- EFI health check
- Boot stack analysis
- Update eligibility check
- Recommendations generation
- All in ONE function

**Refactoring Plan**:

Split into 5 focused functions:

```
Get-BCDHealth() ........................ 50 lines
  ├─ Check BCD validity
  ├─ Count entries
  ├─ Get default entry
  └─ Return: @{ Status, IsValid, EntryCount, DefaultEntry, Details }

Get-EFIHealth() ........................ 40 lines
  ├─ Check EFI partition
  ├─ Get size
  ├─ Check accessibility
  └─ Return: @{ Status, Location, Size, Details }

Get-BootStackOrder() ................... 50 lines
  ├─ Query boot order
  ├─ Get component details
  ├─ Order by priority
  └─ Return: @( @{ Order, Component, Status, Path }, ... )

Get-UpdateEligibility() ................ 60 lines
  ├─ Check CBS state
  ├─ Verify setup.exe
  ├─ Check space
  ├─ Test network (optional)
  └─ Return: @{ Eligible, Requirements@(), Details, Reason }

Get-WindowsHealthSummary() ............. 80 lines [ORCHESTRATOR]
  ├─ Call Get-BCDHealth()
  ├─ Call Get-EFIHealth()
  ├─ Call Get-BootStackOrder()
  ├─ Call Get-UpdateEligibility()
  ├─ Generate recommendations
  └─ Return: Complete health object
```

---

## PHASE 2: WinRepairGUI.ps1 Refactoring

### Function: Start-GUI()
**Current Status**: ~4000 lines (!), entire GUI in one function
**Issues**:
- XAML definition (2000+ lines)
- XAML parsing
- Window object initialization
- Event handler registration (1500+ lines)
- All in ONE function!

**Refactoring Plan**:

Split into 5 focused functions:

```
Initialize-GUIXaml() ................... 2000 lines
  ├─ Define XAML string (just the definition)
  └─ Return: $xamlString

Load-GUIWindow() ....................... 80 lines
  ├─ Parse XAML
  ├─ Create window object
  ├─ Handle parse errors
  └─ Return: $windowObject

Register-ButtonHandlers() .............. 500 lines
  ├─ Utility buttons (Notepad, Registry, PowerShell, etc.)
  ├─ Summary tab buttons
  ├─ BCD tab buttons
  ├─ Repair tab buttons
  └─ Event binding

Register-TabHandlers() ................. 700 lines
  ├─ Summary tab initialization
  ├─ Volume tab initialization
  ├─ BCD tab initialization
  ├─ Repair wizard setup
  └─ Event binding for tab changes

Populate-InitialData() ................. 200 lines
  ├─ Load initial values
  ├─ Populate dropdowns
  ├─ Set default selections
  └─ Initialize status

Show-MainWindow() ...................... 50 lines [ORCHESTRATOR]
  ├─ Verify STA thread
  ├─ Call Initialize-GUIXaml()
  ├─ Call Load-GUIWindow()
  ├─ Call Populate-InitialData()
  ├─ Call Register-ButtonHandlers()
  ├─ Call Register-TabHandlers()
  ├─ Show window (ShowDialog)
  └─ Handle errors + fallback
```

---

## PHASE 3: Other Large Functions to Review

### In WinRepairCore.ps1:

**Function: Repair-Windows() or similar**
- If > 200 lines: split by repair operation type

**Function: Test-BCDIntegrity() or similar**
- If > 150 lines: split by test type

---

## PHASE 4: New Utility Modules

Create `HELPER SCRIPTS\Utils\` modules:

```
PSModule-ErrorHandling.ps1 ............ 80 lines
  ├─ Log-Error()
  ├─ Log-Warning()
  ├─ Log-Success()
  └─ Invoke-WithFallback()

PSModule-Threading.ps1 ................ 60 lines
  ├─ Assert-STAThread()
  ├─ Invoke-InSTAThread()
  └─ Get-ThreadInfo()

PSModule-WindowsInterop.ps1 ........... 100 lines
  ├─ Import-WinAPI()
  ├─ Get-WindowHandle()
  └─ Send-WindowsMessage()

PSModule-Logging.ps1 .................. 80 lines
  ├─ Initialize-Log()
  ├─ Write-Log()
  ├─ Close-Log()
  └─ Get-LogPath()
```

---

## IMPLEMENTATION TIMELINE

### Week 1: Core Refactoring
- [ ] Day 1: Split Get-WindowsHealthSummary() (**2 hours**)
- [ ] Day 2: Split Start-GUI() - XAML part (**3 hours**)
- [ ] Day 3: Split Start-GUI() - Button handlers (**3 hours**)
- [ ] Day 4: Split Start-GUI() - Tab handlers (**2 hours**)
- [ ] Day 5: Create utility modules (**2 hours**)

### Week 2: Integration & Testing
- [ ] Day 1: Update all imports (**1 hour**)
- [ ] Day 2-3: Integration testing (**4 hours**)
- [ ] Day 4: Performance testing (**2 hours**)
- [ ] Day 5: Documentation (**2 hours**)

**Total**: ~24 hours

---

## BENEFITS OF REFACTORING

✓ **Maintainability**: Smaller functions = easier to understand
✓ **Testability**: Each function can be tested independently
✓ **Reusability**: Functions can be called from other scripts
✓ **Performance**: No performance cost (actually might improve)
✓ **Debugging**: Easier to locate and fix bugs
✓ **Documentation**: Each function can have clear documentation

---

## EXAMPLE: Get-WindowsHealthSummary() Split

### BEFORE (Current - 300+ lines):
```powershell
function Get-WindowsHealthSummary {
    # Check BCD
    # Check EFI
    # Check Boot order
    # Check Update eligibility
    # Generate recommendations
    # Return everything
    # ... 300+ lines ...
}
```

### AFTER (Split):
```powershell
function Get-BCDHealth {
    # Just BCD checks - 50 lines
    # Clear, focused, testable
}

function Get-EFIHealth {
    # Just EFI checks - 40 lines
    # Clear, focused, testable
}

function Get-WindowsHealthSummary {
    # Orchestrator - 80 lines
    $bcd = Get-BCDHealth
    $efi = Get-EFIHealth
    $bootStack = Get-BootStackOrder
    $updateEligibility = Get-UpdateEligibility
    
    return @{
        OverallHealth = Calculate-OverallHealth $bcd $efi
        Components = @{ BCD = $bcd; EFI = $efi; ... }
        # etc
    }
}
```

---

## SUCCESS CRITERIA

✓ No function > 150 lines (except orchestrators)
✓ Each function has single responsibility
✓ All imports still work
✓ GUI launches without errors
✓ All tests pass
✓ 0 performance regression
✓ New structure clearly documented

