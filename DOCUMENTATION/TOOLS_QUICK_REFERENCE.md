# QUICK REFERENCE: Microsoft Tools for System Analysis

## ✅ USE THESE (Microsoft-Official)

### 🧠 **WinDbg** - START HERE FOR CRASHES
- **Best for:** BSODs, crash dumps, Explorer crashes
- **How to use:** Open MEMORY.DMP → !analyze -v
- **Microsoft:** Official Microsoft debugger, engineers use this
- **Result:** Professional analysis Microsoft accepts

### 🪵 **Windows Performance Toolkit** - FOR HANGS & SLOWNESS
- **Best for:** Boot hangs, slow startup, Explorer hangs
- **How to use:** Record with WPR → Analyze with WPA
- **Microsoft:** Official solution for "doesn't crash but is broken"
- **Result:** Detailed timeline of what's wrong

### 🧩 **Sysinternals** - SYSTEM DIAGNOSTICS
- **Best for:** Process monitoring, memory dumps (ProcDump)
- **Command:** `procdump -ma explorer.exe explorer_full.dmp`
- **Microsoft:** Microsoft-owned, actively recommended
- **Result:** Professional-grade system analysis

### 🧠 **Windows Error Reporting** - AUTOMATIC DUMPS
- **Best for:** Automatic crash collection
- **Location:** C:\ProgramData\Microsoft\Windows\WER\ReportQueue
- **Microsoft:** Microsoft uses this for support cases
- **Result:** Authoritative dump file

### 🧪 **dotnet-dump / SOS** - .NET CRASHES
- **Best for:** .NET application crashes
- **Tools:** dotnet-dump, sos.dll inside WinDbg
- **Microsoft:** Microsoft-official
- **Result:** Managed code analysis

---

## ❌ DON'T USE THESE (Not Microsoft-Supported)

### ❌ **BlueScreenView**
- **Problem:** No symbol resolution
- **Microsoft:** Won't accept this
- **Why:** Too simplified, wrong results

### ❌ **WhoCrashed**
- **Problem:** Often wrong with modern Windows
- **Microsoft:** Won't accept this
- **Why:** Unreliable, misinterprets modern features

### ❌ **Visual Studio Dump Viewer**
- **Problem:** Not a debugger
- **Microsoft:** Won't accept this
- **Why:** Missing kernel context, not CET-aware

### ❌ **3rd-Party "All-in-One" Tools**
- **Problem:** Outdated, unreliable
- **Microsoft:** Won't accept this
- **Why:** Zero Windows knowledge, causes damage

---

## 📊 QUICK WORKFLOW

### For Crashes (BSODs):
1. Capture: `procdump -ma explorer.exe dump.dmp` (or WER)
2. Load: Open in WinDbg
3. Setup: `.symfix` + `.reload`
4. Analyze: `!analyze -v`
5. Submit: Send to Microsoft support ✅

### For Hangs/Slowness:
1. Record: Windows Performance Recorder
2. Analyze: Windows Performance Analyzer
3. Review: Boot timing and bottlenecks
4. Submit: Professional timeline to support ✅

### For System Diagnostics:
1. Use: Sysinternals Process Explorer or ProcDump
2. Analyze: Monitor memory/CPU
3. Capture: ProcDump for dumps
4. Submit: With WinDbg analysis ✅

---

## 🎯 THE RULE

**If Microsoft won't accept it, don't waste your time with it.**

- ✅ WinDbg = Microsoft will accept
- ✅ Performance Toolkit = Microsoft will accept
- ✅ Sysinternals = Microsoft will accept
- ❌ BlueScreenView = Microsoft will reject
- ❌ WhoCrashed = Microsoft will reject
- ❌ Visual Studio Viewer = Microsoft will reject

---

## 📱 SYMBOL SETUP (Required for WinDbg)

```
srv*C:\symbols*https://msdl.microsoft.com/download/symbols
```

Copy this into: `.symfix` (automatic) or Settings → Symbol Path

---

## 💡 REMEMBER

**If you're not using Microsoft-official tools, Microsoft does not take your analysis seriously.**

Use the right tool. Get professional results. Impress Microsoft support.
