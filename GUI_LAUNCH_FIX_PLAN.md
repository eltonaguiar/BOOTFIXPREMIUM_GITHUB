# GUI Launch Failure - Comprehensive Fix Plan

## Problem Summary

**Error:** "The variable '$W' cannot be retrieved because it has not been set."
**Root Cause:** Code outside the `Start-GUI` function is accessing `$W` at script load time, before `Start-GUI` is called and `$W` is created.

## Root Cause Analysis

1. **`$W` Creation Location:** Line 401 inside `Start-GUI` function
2. **Problem Areas:**
   - Line 478: `if ($null -eq $W)` - Executes at script load time
   - Line 7910: `if ($W)` - Executes at script load time  
   - Line 826: `if (-not $W)` - Inside function but may be called early
   - Line 692: `$W.Dispatcher.Invoke` - Inside event handler (should be safe)

3. **Why This Happens:**
   - When `WinRepairGUI.ps1` is dot-sourced (`. $guiModule`), all top-level code executes immediately
   - Code outside functions runs at load time, not when `Start-GUI` is called
   - `$W` doesn't exist until `Start-GUI` creates it at line 401

## Solution Strategy

### Phase 1: Identify All Problem Areas
- [x] Find all `$W` accesses outside `Start-GUI`
- [ ] Categorize: Script-level vs Function-level vs Event-handler-level
- [ ] Map execution order: What runs when

### Phase 2: Fix Strategy
**Option A: Move Code Inside Start-GUI** (Preferred)
- Move all `$W`-dependent code inside `Start-GUI` function
- Execute after `$W` is created (after line 401)

**Option B: Make Code Safe** (Fallback)
- Use `Get-Variable` to check existence
- Use script scope (`$script:W`)
- Return early if `$W` doesn't exist

### Phase 3: Implementation
1. Fix line 478: Move validation inside Start-GUI or make safe
2. Fix line 7910: Move window event wiring inside Start-GUI
3. Fix line 826: Ensure function checks safely
4. Verify all other `$W` accesses are safe

### Phase 4: Verification
- Test GUI launch in FullOS
- Verify no "variable not set" errors
- Ensure all button handlers work correctly

## Implementation Plan

### Todo 1: Fix Line 478 (Window Validation)
**Current:** `if ($null -eq $W) { throw ... }` at script level
**Fix:** Move inside Start-GUI after `$W` is created, OR make safe check

### Todo 2: Fix Line 7910 (Window Event Wiring)
**Current:** `if ($W) { $W.Add_SizeChanged(...) }` at script level
**Fix:** Move inside Start-GUI after `$W` is created

### Todo 3: Fix Line 826 (Apply-DarkMode Function)
**Current:** `if (-not $W) { return }` - May be called before $W exists
**Fix:** Use safe variable check: `Get-Variable -Name "W" -ErrorAction SilentlyContinue`

### Todo 4: Verify All Other Accesses
**Action:** Search for all `$W` references and ensure they're either:
- Inside `Start-GUI` function (after line 401)
- Inside event handlers (safe, called after window created)
- Using safe existence checks

### Todo 5: Test and Verify
**Action:** Launch GUI and verify no errors

## Expected Outcome

After fixes:
- ✅ No "variable not set" errors
- ✅ GUI launches successfully
- ✅ All button handlers work
- ✅ Window events wired correctly
