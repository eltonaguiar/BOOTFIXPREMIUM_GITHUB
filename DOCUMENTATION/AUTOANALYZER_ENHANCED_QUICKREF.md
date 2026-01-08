# AutoLogAnalyzer Enhanced - Quick Reference

## 30-Second Start

```bash
# Option 1: Click this file
RUN_ANALYZER_ENHANCED.cmd

# Option 2: PowerShell
.\AutoLogAnalyzer_Enhanced.ps1 -HoursBack 48
```

Choose scan duration → Wait 2-3 minutes → Read ANALYSIS_WITH_FIXES.txt

---

## Critical Errors You'll See

### EventID_36871 - SSL/TLS Error (Most Common)
**FIX:** `Settings > Time & Language` → Set correct date/time
- Most likely cause: System clock is wrong
- Check: Windows Update fails? = Clock wrong
- Then run: `certutil -generateSSTFromWU root.sst`

### EventID_7034 - Service Crashed
**FIX:** `net stop ServiceName && net start ServiceName`
- Find service name in Error Details
- Restart it, monitor Event Log

### EventID_1000 - App Crashed
**FIX:** `sfc /scannow` then update drivers
- Let system complete scan
- Restart computer

### EventID_7000 - Service Won't Start
**FIX:** `services.msc` → find service → check Dependencies
- Make sure dependent services are running
- If corrupted: `sfc /scannow`

---

## Understanding Report Sections

### Severity Levels
```
10 = FIX NOW (system broken)
9  = FIX SOON (critical issue)
7-8 = FIX THIS WEEK (high priority)
5-6 = FIX WHEN READY (medium)
1-4 = IGNORE (just warnings)
```

### Fix Priority
1. Do critical fixes (9-10) first
2. Restart computer
3. Re-run analyzer
4. Fix high priority (7-8) next

---

## Command Cheat Sheet

### Quick Scans
```powershell
# Last 2 days
.\AutoLogAnalyzer_Enhanced.ps1

# Last 7 days  
.\AutoLogAnalyzer_Enhanced.ps1 -HoursBack 168

# Last 30 days
.\AutoLogAnalyzer_Enhanced.ps1 -HoursBack 720

# Custom hours
.\AutoLogAnalyzer_Enhanced.ps1 -HoursBack 12
```

### Output Files
```
ANALYSIS_WITH_FIXES.txt  → Read this first (all fixes)
FIXES_FOR_CHATGPT.txt    → Paste in ChatGPT (with AI)
ERROR_ANALYSIS.csv       → Open in Excel (sort/filter)
```

---

## Common Fixes at a Glance

| Error | Quick Fix | Command |
|-------|-----------|---------|
| SSL/TLS Error | Fix system time | Settings > Date & Time |
| Service Crashed | Restart service | `net start SERVICE` |
| App Crash | Scan files | `sfc /scannow` |
| Permission Denied | Run as Admin | Hold Shift + Right-click |
| File Not Found | Reinstall | Uninstall app, restart, reinstall |

---

## When Report Says...

**"Common Causes: System clock incorrect"**
→ Go to Settings > Date & Time → Fix the time

**"Suggested Fixes: Run sfc /scannow"**
→ Open Command Prompt as Admin → Type: `sfc /scannow` → Wait

**"Severity: CRITICAL"**
→ Stop what you're doing and fix it first

**"Run: net stop SERVICE && net start SERVICE"**
→ Open Command Prompt as Admin → Copy/paste command → Press Enter

---

## Troubleshooting Report Problems

### No errors found?
→ Run with longer period: `-HoursBack 168` (7 days)

### Error not in database?
→ Note the error code → Google: `EventID_XXXX Windows`

### Don't understand a fix?
→ Copy error entry → Paste in ChatGPT → Ask for step-by-step help

### Too many warnings?
→ Focus on Severity 9-10 first → Rest can wait

---

## The Three Reports

1. **ANALYSIS_WITH_FIXES.txt**
   - Read this file completely first
   - Most important: Follow fixes in order
   - Organized by severity (critical first)

2. **FIXES_FOR_CHATGPT.txt**
   - For when you're stuck
   - Paste entire content into ChatGPT
   - Ask: "Can you explain step 3 in detail?"

3. **ERROR_ANALYSIS.csv**
   - Open in Excel
   - Sort by error count (highest first)
   - Good for seeing patterns

---

## After You Fix Issues

1. **Restart computer** (important!)
2. **Run analyzer again**: `.\AutoLogAnalyzer_Enhanced.ps1`
3. **Compare results:**
   - Error count went down? = Working
   - Same errors? = Try next fix
   - New errors? = Might have caused new issue

4. **Track progress:**
   - Save reports with dates
   - Compare week-to-week
   - Look for improvements

---

## Getting Help

### For a specific error:
1. Find error code (e.g., EventID_36871)
2. Read "Common Causes" section
3. Follow "Suggested Fixes" in order

### For a confusing fix:
1. Copy the error entry
2. Open ChatGPT
3. Paste: "Can you help me understand this error and its fix?"

### For stuck issues:
1. Copy FIXES_FOR_CHATGPT.txt
2. Paste in ChatGPT
3. Share system specs: `systeminfo | clip` (in Admin PowerShell)

---

## Important Notes

- **Run as Admin:** Some logs require elevated privileges
- **Backup first:** If making big changes, backup system
- **Read fixes completely:** Don't skip steps
- **Restart often:** Many fixes need reboot to work
- **Don't ignore critical:** Severity 9-10 = real problems

---

## File Locations

```
Reports go here:
C:\Users\[YourUser]\Downloads\MiracleBoot_v7_1_1...\LOG_ANALYSIS_ENHANCED

Latest reports:
Windows Explorer opens automatically after scan
Look for folder named: Analysis_2026-01-XX_XXXXXX
```

---

## Pro Tips

✓ Run scan early morning (captures overnight errors)
✓ Run before reinstalling software (baseline)
✓ Run after Windows Update (catch new issues)
✓ Keep reports in folder (track changes)
✓ Share reports with support (shows what you tried)

❌ Don't delete errors you don't recognize
❌ Don't ignore CRITICAL severity
❌ Don't run multiple times in a row (reload time)
❌ Don't make random fixes (follow suggestions)
❌ Don't skip restarts (changes need reboot)
