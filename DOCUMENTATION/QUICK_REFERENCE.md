# Repair-Install Readiness Check - Quick Reference Card

## What Is It?
A tool that verifies Windows is eligible for **in-place upgrade repair** (keeps apps + files) before launching setup.exe.

---

## Why Do I Need It?
```
❌ OLD WAY:  Broken boot → Try repairs → If fails → Clean install (LOSE EVERYTHING)
✅ NEW WAY:  Broken boot → Try repairs → Check eligibility → Safe in-place upgrade
```

---

## How to Use

### IF YOU'RE IN WINDOWS (GUI Mode)
```
1. Run MiracleBoot GUI
2. Click "Repair-Install Readiness" tab
3. Click one:
   • "Run Readiness Check" (just diagnose)
   • "Run Check + Auto-Repair" (fix issues too)
4. Wait for results
5. See final recommendation
```

**Color Guide:**
- 🟢 **Green** = Healthy, no issues
- 🟡 **Yellow** = Warning, might need attention
- 🔴 **Red** = Blocker, must fix before repair-install

---

### IF YOU'RE IN WinPE/WinRE (TUI Mode)
```
1. At main menu, press: 6
2. Choose:
   (1) Check Only - Just diagnose
   (2) Check + Auto-Repair - Fix issues
   (Q) Go back
3. Watch the output
4. Read final message
```

---

### IF YOU'RE AN IT ADMIN (PowerShell)
```powershell
# Import the module
. .\EnsureRepairInstallReady.ps1

# Run the check
$result = Invoke-RepairInstallReadinessCheck -TargetDrive C -AutoRepair $true

# Check the result
if ($result.FinalRecommendation -eq "READY_FOR_REPAIR_INSTALL") {
    Write-Host "Safe to proceed!"
} else {
    Write-Host "Need more repairs: $($result.FinalRecommendation)"
}
```

---

## What It Checks

### ✓ Setup Eligibility
- Is Windows Edition detected? (Pro/Home/Enterprise)
- Is Build format valid?
- Are critical registry keys present?
- Any RebootPending flags set?

### ✓ Component Store Health
- Can DISM see the component store?
- Any pending file operations blocking setup?
- Component store integrity OK?

### ✓ WinRE Status
- Is Windows Recovery Environment registered?
- Is ReAgent.xml valid?
- Are BCD recovery entries correct?

### ✓ Setup.exe Prerequisites
- At least 10GB free disk space?
- Is antivirus running? (might block setup)
- Network available? (for updates)
- System not in middle of updates?

---

## What It Fixes (If You Choose Auto-Repair)

✓ Clears RebootPending flags  
✓ Removes stuck pending operations  
✓ Validates & cleans component store  
✓ Re-registers WinRE  
✓ Updates BCD recovery entries  

⚠️ **Note:** Some fixes might take 15+ minutes (this is normal)

---

## Possible Results

### ✅ READY_FOR_REPAIR_INSTALL
**You can safely:**
1. Open Windows 11/10 ISO
2. Run setup.exe
3. Choose "Keep personal files and apps"
4. System will repair and stay functional

### ⚠️ READY_WITH_WARNINGS
**Can proceed but address these first:**
- Disable antivirus
- Free up disk space
- Install pending updates
- Then try setup.exe

### ❌ NOT_READY
**Cannot use repair-install yet. Must:**
1. Review the blockers shown
2. Either fix manually OR
3. Perform clean install with data preservation

### 🔧 ERROR
**Something went wrong:**
- Check admin privileges
- Review log file
- Try "Run Check + Auto-Repair" again

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Not admin" error | Right-click MiracleBoot → Run as Administrator |
| "Module not found" | Ensure EnsureRepairInstallReady.ps1 in same folder |
| Takes 20+ minutes | This is normal (DISM cleanup is slow) - be patient |
| Still shows "NOT_READY" after repair | Export report, see specific blocker, fix manually |
| Antivirus blocking | Temporarily disable real-time protection |

---

## Timeline to Repair

**What takes time:**
- Setup Eligibility Check: **2-3 seconds**
- CBS Cleanup (if broken): **5-30 minutes** ← Main time!
- WinRE Repair: **1-2 seconds**
- Final Validation: **3-5 seconds**

**Total: 10-40 minutes depending on how broken it is**

---

## Example Scenarios

### Scenario 1: Technician in WinPE
```
1. Boot WinPE
2. Mount C: drive
3. Run MiracleBoot TUI
4. Select option 6
5. Pick "Check + Auto-Repair"
6. Get "READY_FOR_REPAIR_INSTALL"
7. Tell user: "Safe to run setup.exe repair-install"
```

### Scenario 2: End User in Windows
```
1. Download Windows 11 ISO
2. Mount ISO
3. Run MiracleBoot GUI
4. Click "Repair-Install Readiness"
5. Click "Run Readiness Check"
6. Gets green checkmarks
7. Confident to run setup.exe
8. Selects "Keep apps & files"
9. System repaired - data preserved!
```

### Scenario 3: IT Admin (Automated)
```powershell
# Remote check
Invoke-Command -ComputerName PC01 -ScriptBlock {
    . C:\Tools\EnsureRepairInstallReady.ps1
    $r = Invoke-RepairInstallReadinessCheck -TargetDrive C
    return $r.FinalRecommendation
}

# Returns: READY_FOR_REPAIR_INSTALL
# → Can approve automatic setup push
```

---

## Key Facts

- **Non-destructive:** Diagnostic mode is read-only
- **Safe:** Only repairs on explicit user confirmation
- **Fast:** Diagnosis takes seconds, repair takes minutes
- **Smart:** Detects environment automatically (WinPE/FullOS)
- **Portable:** Works from USB, doesn't need installation
- **Logged:** Can export results to file for records

---

## Related Tools

| What | When to Use |
|------|------------|
| Boot Fixer tab | When system won't boot at all |
| Repair-Install Readiness | When you want to keep apps & files |
| Recommended Tools tab | To learn about backup solutions |
| Driver Injection | When missing storage drivers |
| BCD Editor | To manually edit boot configuration |

---

## Quick Decision Tree

```
System won't boot?
    ├─ Run Boot Fixer → Get it booting again
    │
Does it boot now?
    ├─ YES → Done! Skip repair-install
    ├─ NO → Continue...
    │
Want to keep apps & files?
    ├─ YES → Run Repair-Install Readiness Check
    │       ├─ READY? → Run setup.exe repair-install
    │       └─ NOT READY? → Try auto-repair first
    │
    └─ NO → Do clean install (fresh start)
```

---

## Export Your Results

In GUI:
```
Click "Export Report" button
→ Saves to Desktop as: RepairReadinessReport_TIMESTAMP.txt
→ Share with support if needed
```

In TUI:
```
Check output manually
Option to export coming in next version
```

---

## When to Contact Support

📧 **Include when reporting issues:**
- The error message shown
- The exported report file
- Your Windows edition (10/11)
- Your system specs (if possible)
- Steps you did before error

---

## For More Information

📖 **Full Technical Guide:**  
See REPAIR_INSTALL_READINESS.md

📖 **Implementation Details:**  
See IMPLEMENTATION_SUMMARY.md

🎓 **How MiracleBoot Works:**  
See README.md

---

**Version:** 1.0  
**Last Updated:** January 7, 2026  
**Status:** Ready to Use

💡 **Remember:** This is your safety net before doing repair-install. Use it!
