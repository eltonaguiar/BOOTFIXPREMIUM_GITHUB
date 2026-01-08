# Boot Issue Mapping & Virtual Agent

**Status:** Reference guide for technicians and power users  
**Purpose:** Help you describe the boot issue, match it to known classes, and point you to remediation steps (including Microsoft’s official troubleshooting article).

---

## 1. Describe Your Issue

Use this checklist before running automated tools:
- **Symptom keywords:** stop code, boot loop, recovery, start menu broken, blue screen, inaccessible boot device, missing boot manager, flickering logo.
- **Environment:** FullOS or WinPE/WinRE; is WinRE automatically loading?
- **Recent changes:** Driver/firmware update, Windows update, hardware swap, disk cloning.
- **Log clues:** Look at `ntbtlog.txt`, `setuperr.log`, `CBS.log`, `Panther\setupact.log`.

Then capture a short description (example: “System bluescreens with 0x7B right after clicking login”).

## 2. Mapping Table

| Issue | Keywords/Symptoms | Suggested Commands | Notes & Reference |
| --- | --- | --- | --- |
| **Stop error 0x7B (INACCESSIBLE_BOOT_DEVICE)** | “0x7B”, “inaccessible boot device”, storage driver failed | `DISM /Online /Cleanup-Image /RestoreHealth` → `sfc /scannow`; review `ntbtlog.txt`; ensure storage drivers available; check RAID/VMD | Microsoft guide: https://learn.microsoft.com/windows/troubleshoot/.../stop-error-7b-or-inaccessible-boot-device-troubleshooting |
| **Boot loop into recovery options** | “recovery options”, “looping into repair screen”, automatic repair | `bcdedit /set {default} recoveryenabled no` to stop loop; inspect `setuperr.log`; ensure disk integrity | Add `bcdedit /set {default} bootmenupolicy legacy` if F8 menu missing |
| **F8 (“Advanced boot options”) commands unavailable** | F8 nothing, boot fails before menu | `bcdedit /set {default} bootmenupolicy legacy`; `reagentc /boottore` if you need WinRE | Remember: Windows 10/11 default is “Auto”; legacy menu is disabled but can be re-enabled for troubleshooting. |
| **Missing boot manager or BCD corrupt** | “Boot manager is missing”, “0xc000000e”, “No bootable device” | `bcdboot C:\Windows /s <EFI>`; rebuild BCD with `bootrec /rebuildbcd`; use documented BootCase steps | Document modern UEFI vs legacy differences in BCD. |
| **Start menu/Settings broken after setup** | “Start menu crashes”, “Settings not opening” | Re-register AppX packages (`Get-AppxPackage -AllUsers | ForEach-Object {...}`); fill in Setup log details | Happens when AppX components are corrupted; local remediation ensures re-registration. |

> **Tip:** The Virtual Agent (https://chatgpt.com/s/t_695f6243fe9481919a76f51b7510aeb9) can help you cross-reference symptoms with these issues and suggest commands quickly.

---

## 3. Technical Resources

- **Microsoft’s Inaccessible Boot Device troubleshooting:** https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/stop-error-7b-or-inaccessible-boot-device-troubleshooting  
- **Windows RE management:** https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/reagentc-command-line-options (use Winrecfg.exe for WinPE 2.x/3.x/4.x offline work)
- **Boot logs:** Enable `ntbtlog.txt` (`bcdedit /set {current} bootlog yes`) before reproducing the issue; review the file with the Boot Log Analyzer.
- **Setup logs:** `C:\$WINDOWS.~BT\Sources\Panther\setuperr.log` and `setupact.log`.

## 4. Next Steps After Mapping

1. Run the commands from the “Suggested Commands” column; capture their output in MiracleBoot logs.
2. Use the GUI’s “Boot Issue Mapping” button to open this guide anytime.
3. When in WinPE/WinRE, remember to use **Winrecfg.exe** (from Windows ADK) instead of REAgentC for offline operations.
4. Report the symptoms and actions into your ticket or support case, referencing the official Microsoft guide for detail.
