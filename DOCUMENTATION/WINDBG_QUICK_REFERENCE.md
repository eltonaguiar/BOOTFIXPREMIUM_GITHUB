# WinDBG & Debugging Tools - Quick Reference

## Quick Access

**Location in MiracleBoot GUI:**
- Main Window → Recommended Tools → Analysis & Debugging Tools tab

## The Tools

### 1. Windows Debugger (WinDBG) - Deep System Analysis
**Best for:** Crash dumps, BSOD analysis, kernel debugging

**One-Click Access:**
- Click "Get WinDBG from Store" button
- Opens Windows Store app page
- Free download and installation

**What it does:**
- Analyzes crash dump files (MEMORY.DMP)
- Debugs live processes
- Performs kernel-mode debugging
- Identifies root causes of system failures

**How to use:**
```
1. Collect MEMORY.DMP file from system crash
2. Open WinDBG
3. File → Open Dump File → Select MEMORY.DMP
4. Type: !analyze -v
5. Review crash analysis results
```

### 2. Event Viewer - System Event Logs
**Best for:** Quick event log review, error checking

**One-Click Access:**
- Click "Open Event Viewer" button
- Launches Windows Event Viewer immediately

**What to check:**
- System logs (critical system errors)
- Application logs (program crashes)
- Security logs (access issues)

### 3. MiracleBoot Event Log Analyzer - Automated Analysis
**Best for:** Quick automated error detection, 60-second scan

**Location:** Diagnostics & Logs → Analyze Event Logs

**What it does:**
- Scans logs automatically
- Matches 37+ known error codes
- Identifies critical issues
- Provides suggested fixes

## Recommended Workflow

### For General Troubleshooting:
```
Step 1: Click "Analyze Event Logs" (Diagnostics & Logs tab)
        └─ Get quick overview of issues (60 seconds)

Step 2: If issues found → Click "Open Event Viewer"
        └─ Review detailed event information

Step 3: For crashes → Click "Get WinDBG from Store"
        └─ Analyze MEMORY.DMP for root cause
```

### For BSOD (Blue Screen):
```
Step 1: Get MEMORY.DMP from: C:\Windows\Memory.dmp

Step 2: Open WinDBG (Get from Store)

Step 3: File → Open Dump File → Select MEMORY.dmp

Step 4: Type: !analyze -v (press Enter)

Step 5: Review output for error code and recommendations
```

### For Performance Issues:
```
Step 1: Analyze Event Logs → Look for warnings

Step 2: Open Event Viewer → Check Application logs

Step 3: Use WinDBG to examine process memory usage

Step 4: Identify resource hogging applications
```

## Key Features

### WinDBG Capabilities
✓ Crash dump analysis  
✓ Live process debugging  
✓ Memory inspection  
✓ Kernel debugging  
✓ Root cause analysis  
✓ Automated crash analysis (!analyze -v)  

### MiracleBoot Event Analyzer
✓ 37+ error codes identified  
✓ Severity ranking (1-10)  
✓ Automatic analysis (60 seconds)  
✓ Suggested fixes for each error  
✓ ChatGPT-ready reports  

## Common Error Codes Found

**Critical Issues (Severity 9-10):**
- EventID_36871 - SSL/TLS certificate errors
- EventID_1000 - Application crashes
- EventID_7000 - Driver load failures
- EventID_7034 - Service terminated

**Medium Issues (Severity 5-7):**
- EventID_10016 - DCOM permission issues
- EventID_219 - Hardware problems
- EventID_1001 - Bugcheck events

## Button Reference

| Button | Function | Opens |
|--------|----------|-------|
| Get WinDBG from Store | Install WinDBG | Microsoft Store |
| Microsoft Docs | View documentation | Microsoft Learn |
| Open Event Viewer | Browse event logs | eventvwr.msc |

## Installation Requirements

**For WinDBG:**
- Windows 10 or 11
- Microsoft Store (recommended method)
- ~500 MB disk space
- Admin rights for kernel debugging

**For Event Viewer:**
- Built-in to Windows (no installation)
- Already available in all Windows versions

## Troubleshooting

### "Store page won't open"
✓ Click "Microsoft Docs" for web link
✓ Visit: https://www.microsoft.com/store/apps/9pgjgd53tn86
✓ Search Microsoft Store for "Windows Debugger"

### "Event Viewer won't open"
✓ Run: eventvwr.msc in Command Prompt
✓ Or search Windows for "Event Viewer"

### "WinDBG analysis shows confusing output"
✓ Visit Microsoft documentation link
✓ Search error code on Microsoft Docs
✓ Try command: !help in WinDBG for assistance

## Advanced Tips

### Enable Kernel Memory Dumps
For better WinDBG analysis:
1. Settings → System → About
2. Advanced system settings
3. Startup and Recovery
4. Select "Kernel Memory Dump"
5. Restart system to apply

### Common WinDBG Commands
```
!analyze -v          → Automatic crash analysis
!bugcheck            → Show last bugcheck code
lm                   → List loaded modules
!process 0 0         → Show all processes
!address -summary    → Memory usage summary
quit                 → Exit WinDBG
```

### Export Event Logs
In Event Viewer:
1. Right-click log name
2. Save All Events As...
3. Choose format (EVT or EVTX)
4. Import into analysis tools

## Links & Resources

| Resource | Link |
|----------|------|
| WinDBG Store Page | ms-windows-store://pdp/?ProductId=9pgjgd53tn86 |
| Microsoft Documentation | https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/ |
| Windows Symbols | https://msdl.microsoft.com/download/symbols |
| Event IDs Reference | https://learn.microsoft.com/en-us/shows/inside-windows-podcast/inside-windows-podcast-35-windows-error-reporting |

## Performance Notes

- **Event Log Analysis:** ~60 seconds for full system scan
- **Event Viewer Launch:** Immediate
- **WinDBG Launch:** First run 5-10 seconds (installation required)
- **Dump Analysis:** 30-120 seconds depending on dump size

## Files & Locations

- **Crash Dumps:** `C:\Windows\Memory.dmp`
- **Event Logs:** `%SystemRoot%\System32\winevt\Logs\`
- **MiracleBoot Analyzer:** HELPER SCRIPTS folder
- **WinDBG Installation:** C:\Program Files\WindowsApps\

## Version Info

- **MiracleBoot:** v7.1.1+
- **PowerShell:** 5.0+
- **Windows:** 10/11
- **WinDBG:** Latest from Microsoft Store

## Support

If issues occur:
1. Check Event Viewer for error details
2. Review MiracleBoot analysis results
3. Use WinDBG for crash dumps
4. Consult Microsoft documentation
5. Search error code on Microsoft Learn

---

**Last Updated:** 2025-01  
**Status:** ✅ Production Ready  
**Integration:** Complete
