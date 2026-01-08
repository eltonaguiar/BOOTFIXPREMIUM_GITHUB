# Local Remote Remediation (No MDM, No Account)

Status: Draft - Technician Ready

This guide documents the "Local RemoteRemediation" workflow and how to run it from MiracleBoot. It mirrors a known-good remediation sequence and is designed to run locally (no MDM, no cloud account).

---

## 1) Quick Checklist (Before You Run)

Confirm the issue matches one of these:
- Windows Update is stuck or broken
- In-place upgrade fails with vague errors
- Settings/Start menu is broken
- Component store corruption suspected
- Setup.exe blocks or rolls back

If YES, continue. If you only have boot failure with no OS boot, use WinRE/WinPE first.

---

## 2) Recommended Method (Technician Flow)

1. Launch MiracleBoot GUI (FullOS).
2. Use "Local Remediation (No MDM)" button.
3. Select steps in order (defaults are safe and recommended).
4. If DISM fails, re-run with a mounted ISO source.
5. Run in-place upgrade only after steps 1-5 complete.

This sequence is intentional:
DISM must run before SFC, or SFC results are unreliable.

---

## 3) Steps (Local RemoteRemediation)

### Step 1 - Reset servicing stack and update plumbing
Run as admin:
```
net stop wuauserv
net stop bits
net stop cryptsvc
net stop trustedinstaller

ren %windir%\SoftwareDistribution SoftwareDistribution.old
ren %windir%\System32\catroot2 catroot2.old

net start trustedinstaller
net start cryptsvc
net start bits
net start wuauserv
```

### Step 2 - Heal component store (real fix, not ScanHealth theater)
```
DISM /Online /Cleanup-Image /RestoreHealth
```
If Windows Update is broken, force a source:
```
DISM /Online /Cleanup-Image /RestoreHealth /Source:wim:X:\sources\install.wim:1 /LimitAccess
```
Replace X: with the mounted ISO drive letter.

### Step 3 - AppX re-registration (fixes Settings/Start/Setup deps)
```
Get-AppxPackage -AllUsers |
Foreach {
  Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"
}
```

### Step 4 - Repair system files (SFC only after DISM)
```
sfc /scannow
```

### Step 5 - Clear Setup blockers (critical)
Delete or rename:
```
C:\$WINDOWS.~BT
C:\$WINDOWS.~WS
C:\Windows\Panther
C:\Windows\SoftwareDistribution\Download
```
These folders can poison future in-place upgrades.

### Step 6 - Run in-place upgrade (repair install)
Mount matching or newer Windows 11 ISO, then run:
```
setup.exe
```
Choose:
- Keep apps
- Keep files

If it still blocks, logs are now honest:
```
C:\$WINDOWS.~BT\Sources\Panther\setuperr.log
```

---

## 4) What You Lose Without MDM (Be Real)

Without MDM you do not get:
- Microsoft's internal repair orchestration
- Automatic retry logic
- Cloud-triggered fixes
- Telemetry-based remediation paths

Local remediation still works if the order is correct and sources are available.

---

## 5) REAgentC Guidance (Online vs Offline)

REAgentC.exe is built into Windows and can configure Windows RE.
Use it when running inside Windows (FullOS).

If you are in WinPE 2.x/3.x/4.x, use Winrecfg.exe from Windows ADK:
- REAgentC supports online and offline modes
- Winrecfg.exe supports offline only (WinPE environments)

When in WinPE, REAgentC commands will only work in offline mode.

Reference: https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/reagentc-command-line-options?view=windows-11

---

## 6) Windows RE Checklist and Best Practices

When Windows boots:
```
reagentc /info
reagentc /enable
```

To boot into Windows RE one-time:
```
reagentc /boottore
shutdown /r /t 0
```

If WinRE is missing:
1. Mount Windows ISO
2. Locate winre.wim (install image or recovery partition)
3. Set it:
```
reagentc /setreimage /path C:\Recovery\WindowsRE
reagentc /enable
```

Note: In WinPE, use Winrecfg.exe for offline targets.

---

## 7) Optional: Add a Recovery Boot Menu Entry (Advanced)

This can be helpful for technicians but should be used carefully.
Recommended approach for non-experts is to use:
```
reagentc /boottore
```

For persistent menu entries, use bcdedit to create a WinRE entry and test carefully.
Document this in a separate advanced guide before enabling by default.

---

## 8) Windows ADK + WinPE (Portable USB Strategy)

Recommended technician bundle on USB:
- MiracleBoot folder
- Windows 11 ISO (matching target build)
- DriverPack (harvested drivers)
- WinPE build (optional)

Steps (technician workstation):
1. Install Windows ADK + WinPE Add-on
2. Create WinPE working directory:
```
copype amd64 C:\WinPE_amd64
```
3. Copy MiracleBoot into the WinPE media folder:
```
copy C:\MiracleBoot C:\WinPE_amd64\media\MiracleBoot /E
```
4. Create USB:
```
MakeWinPEMedia /UFD C:\WinPE_amd64 E:
```
Replace E: with your USB drive.

This produces a portable USB that can boot and run MiracleBoot in WinPE.

---

## 9) How the GUI Button Works

In the MiracleBoot GUI:
- Click "Local Remediation (No MDM)"
- Choose steps to run
- Optionally provide an ISO source for DISM
- Optionally provide setup.exe for in-place upgrade

All steps log output to a report file.
