# AutoLogAnalyzer - Visual Guide & Examples

## 📸 What You'll See

### Step 1: Running the Script

```
C:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code> .\AutoLogAnalyzer_Lite.ps1

==== AutoLogAnalyzer - System Log Analysis Tool v1.0 ====

Configuration:
  Hours Back: 48 hours
  Output Path: C:\...\LOG_ANALYSIS\LogAnalysis_2026-01-07_164015
  Time Range: 2026-01-07 04:40:15 to 2026-01-07 16:40:15

[1/4] Collecting Event Viewer Logs...
Collecting Event Viewer logs...
  Querying System log...
    Found 500 events
  Querying Application log...
    Found 500 events
  Querying Security log...
    Error accessing Security: Requested registry access is not allowed.
    Found 1000 events

[2/4] Extracting Error Codes...
Extracting error codes...
      Extracted 139 errors

[3/4] Summarizing Errors...
Summarizing errors...
      Found 18 unique error codes

[4/4] Generating Reports...
      CSV export: ...\ERROR_CODES.csv
      ChatGPT prompt: ...\CHATGPT_PROMPT.txt

==== ANALYSIS COMPLETE ====

KEY FINDINGS:
  Total Error Codes Found: 18
  Total Error Occurrences: 139

  TOP 5 MOST FREQUENT ERRORS:
    [1] EventID_36871 - 104 occurrences
    [2] EventID_10016 - 15 occurrences
    [3] EventID_7034 - 2 occurrences
    [4] EventID_7009 - 2 occurrences
    [5] EventID_219 - 2 occurrences
```

*(File explorer opens automatically with your reports)*

---

## 📄 Example: CHATGPT_PROMPT.txt

```
=== SYSTEM LOG ERROR ANALYSIS REPORT ===
Generated: 2026-01-07 16:40:16
Analysis Period: Last 12 hours

PROMPT 1 - PRIMARY ERROR CODES:
========================================
I am experiencing the following error codes on my Windows system:

Error Code: EventID_36871
  Type: Event Viewer
  Occurrences: 104
  Severity: Error
  Sources: Schannel

Error Code: EventID_10016
  Type: Event Viewer
  Occurrences: 15
  Severity: Warning
  Sources: DCOM

Error Code: EventID_7034
  Type: Event Viewer
  Occurrences: 2
  Severity: Error
  Sources: Service Control Manager

Error Code: EventID_7009
  Type: Event Viewer
  Occurrences: 2
  Severity: Error
  Sources: Service Control Manager

Error Code: EventID_219
  Type: Event Viewer
  Occurrences: 2
  Severity: Warning
  Sources: Microsoft-Windows-Kernel-PnP

Error Code: EventID_27
  Type: Event Viewer
  Occurrences: 2
  Severity: Warning
  Sources: e2fnexpress, e2fexpress

Error Code: EventID_4096
  Type: Event Viewer
  Occurrences: 1
  Severity: Warning
  Sources: VBScriptDeprecationAlert

Error Code: EventID_10005
  Type: Event Viewer
  Occurrences: 1
  Severity: Error
  Sources: MsiInstaller

Error Code: EventID_100
  Type: Event Viewer
  Occurrences: 1
  Severity: Warning
  Sources: winsrvext

Error Code: EventID_1000
  Type: Event Viewer
  Occurrences: 1
  Severity: Error
  Sources: Application Error


PROMPT 2 - ASK CHATGPT:
========================================
1. Copy the error codes above
2. Paste into ChatGPT with this message:
   'What do these error codes mean and how serious are they?'
3. For detailed troubleshooting, ask:
   'How can I fix these errors?'
```

---

## 📊 Example: ERROR_CODES.csv

```
ErrorCode,Count,Type,Severity,Sources
EventID_36871,104,Event Viewer,Error,Schannel
EventID_10016,15,Event Viewer,Warning,DCOM
EventID_7034,2,Event Viewer,Error,Service Control Manager
EventID_7009,2,Event Viewer,Error,Service Control Manager
EventID_219,2,Event Viewer,Warning,Microsoft-Windows-Kernel-PnP
EventID_27,2,Event Viewer,Warning,e2fnexpress, e2fexpress
EventID_4096,1,Event Viewer,Warning,VBScriptDeprecationAlert
EventID_10005,1,Event Viewer,Error,MsiInstaller
EventID_100,1,Event Viewer,Warning,winsrvext
EventID_1000,1,Event Viewer,Error,Application Error
```

*(Open in Excel for sorting and filtering)*

---

## 🎯 How to Use the Reports

### Using CHATGPT_PROMPT.txt

**Step 1: Open ChatGPT**
```
Go to: https://chat.openai.com/
```

**Step 2: Copy Error Codes**
- Open CHATGPT_PROMPT.txt
- Select all text from "Error Code:" to the last error
- Press Ctrl+C to copy

**Step 3: Paste into ChatGPT**
```
User: What do these error codes mean and how serious are they?

[PASTE ERROR CODES HERE]

ChatGPT: These errors indicate several issues with your system:

EventID_36871 (104 times) - Schannel SSL/TLS Issues
- This is the most common error
- Indicates problems with SSL/TLS certificate validation
- Could prevent secure connections
- Solutions:
  1. Run Windows Update
  2. Check certificate stores
  3. Clear SSL cache

EventID_10016 (15 times) - DCOM Permission Issues
- Moderate severity
- Components can't communicate properly
- Solutions:
  1. Run Dcomcnfg.exe to fix DCOM
  2. Reset DCOM permissions
  3. Reregister COM components
...
```

**Step 4: Get Detailed Help**
```
User: Based on these errors, what's the best way to fix them? 
      What should I do first?

ChatGPT: I recommend this order:

1. FIRST: Fix SSL/TLS issues (EventID_36871)
   - Run: sfc /scannow
   - Update Windows
   - Check dates on certificates

2. SECOND: Fix DCOM issues (EventID_10016)
   - Run: regsvr32 ...
   - Reset component registry

3. ONGOING: Monitor for Service crashes
...
```

---

### Using ERROR_CODES.csv

**Open in Excel**

1. Right-click ERROR_CODES.csv
2. Select "Open with" → Excel
3. Apply filters to explore data

**Example Analysis:**
```
Sort by Count (Descending):
- Shows which errors are most critical
- EventID_36871: 104 = CRITICAL
- EventID_10016: 15 = MEDIUM
- Others: 1-2 = LOW

Filter by Severity:
- Error = Critical issues
- Warning = Minor issues

Create Pivot Table:
- By Type: How many of each error type?
- By Source: Which components have errors?
```

---

## 🔄 Before/After Comparison Example

### Before Repairs (Day 1)
```
Analysis: 2026-01-07 16:40:16
Total Errors: 18 unique codes
Total Occurrences: 139

Top 3:
1. EventID_36871 - 104 occurrences (SSL Issues)
2. EventID_10016 - 15 occurrences (DCOM Issues)
3. EventID_7034 - 2 occurrences (Service Crash)
```

### Run MiracleBoot Repairs
```
Repairs applied:
- Windows Update
- System File Checker
- DCOM Registration
- Service Restart
- Registry Optimization
```

### After Repairs (Day 2)
```
Analysis: 2026-01-08 17:15:22
Total Errors: 8 unique codes
Total Occurrences: 12

Top 3:
1. EventID_10016 - 4 occurrences (DCOM Issues)
2. EventID_7009 - 2 occurrences (Service Timeout)
3. EventID_219 - 1 occurrence (Plug & Play)
```

### Improvement Report
```
Errors Fixed: 10 (-55.6%)
- EventID_36871: ELIMINATED ✅ (was 104, now 0)
- EventID_7034: ELIMINATED ✅ (was 2, now 0)
- EventID_4096: ELIMINATED ✅
- EventID_10005: ELIMINATED ✅
- EventID_100: ELIMINATED ✅
- EventID_1000: ELIMINATED ✅
- AND 4 MORE...

New Issues: 0
Overall Improvement: EXCELLENT ✅
```

---

## 💬 ChatGPT Conversation Example

### Full Dialogue Flow

```
USER:
What do these error codes mean and how serious are they?

EventID_36871 - 104 occurrences - Schannel
EventID_10016 - 15 occurrences - DCOM
EventID_7034 - 2 occurrences - Service Control Manager

---

CHATGPT:
These errors indicate three distinct issues:

1. **EventID_36871 (104 occurrences) - CRITICAL**
   - Issue: SSL/TLS certificate validation failing
   - Component: Schannel (Windows secure channel)
   - Severity: HIGH - affects all secure connections
   - Symptoms: Slow HTTPS, connection drops, authentication failures
   - Common Causes:
     * Outdated Windows
     * Corrupted certificate store
     * System clock incorrect
     * Antivirus SSL inspection
   
2. **EventID_10016 (15 occurrences) - MEDIUM**
   - Issue: DCOM permission denied
   - Component: Distributed COM
   - Severity: MEDIUM - affects component interaction
   - Symptoms: Application slow, some features don't work
   - Common Causes:
     * Corrupted registry
     * Missing DCOM components
     * Permission issues
   
3. **EventID_7034 (2 occurrences) - LOW**
   - Issue: Service terminated unexpectedly
   - Component: Windows Service Control Manager
   - Severity: LOW - but indicates instability
   - Symptoms: Service crashes intermittently
   - Common Causes:
     * Memory leak
     * Service dependency failure
     * Resource exhaustion

---

USER:
How do I fix these? What should I do first?

---

CHATGPT:
Priority order for fixes:

**STEP 1: Fix SSL/TLS Issues (EventID_36871) - MOST IMPORTANT**

a) Verify System Date/Time:
   - Settings > Time & Language > Date & Time
   - Ensure correct timezone
   - Enable "Set time automatically"

b) Update Windows:
   - Settings > Update & Security > Check for updates
   - Install all updates and reboot

c) Scan System Files:
   - Run as Administrator:
   - sfc /scannow
   - Wait for completion

d) Clear SSL Cache:
   - Run as Administrator:
   - certutil -setreg chain\\ChainCacheResync 1
   - Reboot

**STEP 2: Fix DCOM Issues (EventID_10016) - SECOND**

a) Register DCOM Components:
   - Run as Administrator:
   - regsvr32 combase.dll
   - regsvr32 dcomcnfg.exe

b) Reset DCOM Permissions:
   - Run dcomcnfg
   - Navigate to Component Services
   - Check DCOM permissions

**STEP 3: Monitor Service Crashes (EventID_7034) - AFTER ABOVE**

- Monitor Event Viewer
- If still occurring, identify which service
- Check service dependencies
- Restart service

---

USER:
I'll do these steps. How do I verify they worked?

---

CHATGPT:
Run the analysis again:

1. Run: AutoLogAnalyzer_Lite.ps1
2. Wait 3 minutes
3. Compare ERROR_CODES.csv before/after:
   - EventID_36871 should drop from 104 to <10
   - EventID_10016 should drop from 15 to <5
   - EventID_7034 should become 0

4. Success indicators:
   - Fewer total errors
   - No critical errors
   - Stable system
   - Better performance

5. If not improved:
   - Try System Restore to before issues
   - Consider repair-install Windows
   - Check for malware
```

---

## 📋 Common Error Codes Reference

### SSL/TLS Related
- **EventID_36871**: Schannel error (SSL/TLS validation failed)
- **EventID_36883**: Certificate validation failed
- **EventID_36884**: SSL/TLS security policy violation

### DCOM Related
- **EventID_10016**: DCOM permission denied
- **EventID_10005**: DCOM server process error
- **EventID_10001**: DCOM server startup failed

### Service Related
- **EventID_7034**: Service crashed (unexpected termination)
- **EventID_7009**: Service timeout (hung)
- **EventID_7000**: Service failed to start

### Driver Related
- **EventID_219**: Kernel PnP (Plug & Play issue)
- **EventID_27**: Network driver issue

### Application Related
- **EventID_1000**: Application error (crash)
- **EventID_1001**: Application error reporting
- **EventID_4096**: Deprecated VBScript

---

## 🎓 Understanding Frequency

### 100+ Occurrences
- **Priority**: CRITICAL
- **Impact**: Major system issue
- **Action**: Fix immediately
- **Example**: EventID_36871 (104x)

### 10-100 Occurrences
- **Priority**: HIGH
- **Impact**: Moderate system issue
- **Action**: Fix soon
- **Example**: EventID_10016 (15x)

### 2-10 Occurrences
- **Priority**: MEDIUM
- **Impact**: Minor issue
- **Action**: Monitor and fix if recurring
- **Example**: EventID_7034 (2x)

### 1 Occurrence
- **Priority**: LOW
- **Impact**: One-time event
- **Action**: Monitor for recurrence
- **Example**: EventID_1000 (1x)

---

## 🚀 Quick Reference Commands

### Run Analysis (Various Timeframes)
```powershell
# Last 12 hours (today's issues)
.\AutoLogAnalyzer_Lite.ps1 -HoursBack 12

# Last 24 hours (overnight issues too)
.\AutoLogAnalyzer_Lite.ps1 -HoursBack 24

# Last 7 days (see patterns)
.\AutoLogAnalyzer_Lite.ps1 -HoursBack 168

# Last 30 days (long-term issues)
.\AutoLogAnalyzer_Lite.ps1 -HoursBack 720
```

### View Results
```powershell
# Open latest reports
explorer.exe "C:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code\LOG_ANALYSIS"

# View specific report
Get-Content ".\LOG_ANALYSIS\LogAnalysis_*/CHATGPT_PROMPT.txt"

# Compare CSV files
notepad ".\LOG_ANALYSIS\LogAnalysis_*/ERROR_CODES.csv"
```

---

**Ready to analyze your system? Start with:**
```powershell
.\AutoLogAnalyzer_Lite.ps1
```

---

*For more help, see AUTOANALYZER_README.md*
