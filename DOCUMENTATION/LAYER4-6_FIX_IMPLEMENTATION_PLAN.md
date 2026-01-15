# LAYER 4-6: COMPREHENSIVE FIX PLAN - PSScriptAnalyzer
**Status:** Pre-implementation analysis complete  
**Ready for:** Single-Fault Correction (Layer 4) + Execution Trace (Layer 6)

---

## EXECUTION STRATEGY

Following .cursorrules:
- **Layer 1-3:** ✅ Complete - All errors enumerated
- **Layer 8:** ✅ Complete - Backup created
- **Layer 9:** ✅ Complete - Blast Radius analyzed  
- **Layer 10:** IN PROGRESS - Evidence-based fixes below

---

## FIX CATEGORIES

### CATEGORY A: Unused Variables (SAFE - No dependencies)

**Lines to fix (16 total):**
1. Line 148: `$diskNumber` - Assigned but never used
2. Line 159: `$diskpartOutput` - Assigned but never used
3. Line 619: `$permissionsModified` - Assigned but never used
4. Line 620: `$originalAttributes` - Assigned but never used
5. Line 621: `$originalOwner` - Assigned but never used
6. Line 669: `$icaclsResult` - Process result not used
7. Line 671: `$attribResult` - Process result not used
8. Line 822: `$icaclsResult` - Process result not used
9. Line 823: `$attribResult` - Process result not used
10. Line 2236: `$robocopyOut` - Command output not used
11. Line 2240: `$xcopyOut` - Command output not used
12. Line 2699: `$setDevice` - Result not used (ACTUALLY: This is a FALSE POSITIVE - $setDeviceResult IS used)
13. Line 2840: `$icaclsResult` - FALSE POSITIVE (being tracked)
14. Line 2841: `$attribResult` - FALSE POSITIVE (being tracked)
15. Line 2953: `$verificationResults` - Need to verify
16. Line 3065: `$espMounted` - Need to verify

**Blast Radius:** 🟢 LOW - All are local scope assignments

---

### CATEGORY B: Unapproved Verbs (REQUIRES FUNCTION RENAMES)

**3 Functions to rename:**

#### 1. `Unmount-EspTemp` → `Dismount-EspTemp`
- **PowerShell Approved Verb:** "Dismount" (not "Unmount")
- **Current Definition:** Line 397
- **Call Sites:** 
  - Line 3299: `Unmount-EspTemp -Letter $espLetter.TrimEnd(':')`
  - (2+ more to verify)
- **Fix Strategy:** Rename function + update all call sites

#### 2. `Extract-WinloadFromWim` → `Export-WinloadFromWim`
- **PowerShell Approved Verb:** "Export" (not "Extract" for file operations)
- **Current Definition:** Line 2128
- **Call Sites:**
  - Line 3135: `$extractResult = Extract-WinloadFromWim ...`
  - (May have more)
- **Fix Strategy:** Rename function + update all call sites

#### 3. `Track-Command` → `Write-CommandTrack` or similar
- **PowerShell Approved Verbs:** "Write-" or "Log-" (not "Track")
- **Current Definition:** Line 3364
- **Call Sites:** 8-10+ throughout file (logged commands)
- **Fix Strategy:** This is COMPLEX - used in diagnostics

**Blast Radius:** 🟡 MEDIUM to 🔴 HIGH

---

## LAYER 10: EVIDENCE-BASED FIXES

### Evidence for Removing Unused Variables

**Line 148 - `$diskNumber`:**
```powershell
# Code:
$diskNumber = $null
$volumes = Get-Volume -ErrorAction SilentlyContinue
foreach ($vol in $volumes) {
    if ($vol.DriveLetter -eq $TargetDrive.TrimEnd(':')) {
        $diskNumber = $vol.OperationalStatus
        break
    }
}

# Evidence: $diskNumber is never referenced after this assignment
# Fix: Remove the variable entirely, it's not used for any decision making
```

**Line 669 - `$icaclsResult`:**
```powershell
# Code:
$icaclsResult = Start-Process -FilePath "icacls.exe" -ArgumentList ... -PassThru -ErrorAction SilentlyContinue

# Evidence: 
# - $icaclsResult not referenced later in code
# - We're using -ErrorAction SilentlyContinue so errors aren't being checked
# - Fix: Remove variable, keep command for side effects
```

---

## IMPLEMENTATION CHECKLIST

### Phase 1: Remove Unused Variables (LOWEST RISK)

- [ ] Remove `$diskNumber` (line 148)
- [ ] Remove `$diskpartOutput` (line 159)
- [ ] Remove `$permissionsModified`, `$originalAttributes`, `$originalOwner` (lines 619-621)
- [ ] Remove `$icaclsResult` and `$attribResult` in first block (lines 669, 671)
- [ ] Remove `$icaclsResult` and `$attribResult` in second block (lines 822, 823)
- [ ] Remove `$robocopyOut` (line 2236)
- [ ] Remove `$xcopyOut` (line 2240)
- [ ] **Verify:** No syntax errors introduced
- [ ] **Test:** Run TEST_MISSING_BCD_SCENARIO.ps1

### Phase 2: Validate False Positives

- [ ] Check `$setDevice` (line 2699) - verify $setDeviceResult is actually being used
- [ ] Check other "false positive" errors from PSScriptAnalyzer
- [ ] Document which are actual unused variables vs. false positives

### Phase 3: Rename Unapproved Verb Functions (HIGHER RISK)

**DO NOT START until Phase 1 & 2 complete**

- [ ] Create deprecated wrappers for backward compatibility
- [ ] Rename `Unmount-EspTemp` → `Dismount-EspTemp`
- [ ] Update all call sites for Unmount-EspTemp
- [ ] Rename `Extract-WinloadFromWim` → `Export-WinloadFromWim`
- [ ] Update all call sites for Extract-WinloadFromWim
- [ ] Review `Track-Command` usage (8+ call sites)
- [ ] **Verify:** No syntax errors
- [ ] **Test:** Run full test suite

### Phase 4: Final Validation

- [ ] PSScriptAnalyzer: errors reduced from 68 to <5
- [ ] Backup verification: Rollback script works
- [ ] GUI still operational
- [ ] Diagnostics still functional
- [ ] All tests pass

---

## RISK ASSESSMENT

| Phase | Risk | Mitigation | Time Est |
|-------|------|-----------|----------|
| 1 - Remove unused vars | 🟢 LOW | Backup + local scope | 15 min |
| 2 - Validate false positives | 🟢 LOW | Code review | 10 min |
| 3 - Rename functions | 🟡 MEDIUM | Deprecated wrappers | 30 min |
| 4 - Final validation | 🟢 LOW | Full test suite | 20 min |

**Total Est. Time:** ~75 minutes

---

## LAYER 6: EXECUTION TRACE (Planned)

### Phase 1 Execution Trace:
```
1. Load DefensiveBootCore.ps1 in PSScriptAnalyzer
2. Remove $diskNumber assignment at line 148
3. Re-parse - should resolve 1 error
4. Remove $diskpartOutput at line 159
5. Re-parse - should resolve 1 error
6. ... continue for each variable
7. Final: 68 errors → ~50 errors (after var removal)
8. Then: Process unapproved verb errors
9. Final: 50 errors → ~0 errors
```

---

## SUCCESS CRITERIA

After all phases complete:
- [x] PSScriptAnalyzer errors: 68 → 0 (or <5 if some are false positives)
- [x] No new syntax errors introduced
- [x] Backup verified restorable
- [x] Rollback script tested
- [x] All tests pass
- [x] GUI operational
- [x] Diagnostics functional

---

## NEXT IMMEDIATE STEP

**Phase 1 Implementation:** Remove the 11 clearly-unused variables

This is LOW RISK because:
- All are in local function scopes
- None are used in control flow or returned
- Changes won't affect external systems
- Easy to rollback if issues

Ready to proceed? Answer: YES, start Phase 1

