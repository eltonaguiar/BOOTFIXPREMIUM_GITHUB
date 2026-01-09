@echo off
REM MiracleBoot Shift+F10 bootstrapper
REM Attempts to run GUI if possible; otherwise falls back to TUI.

setlocal

REM Resolve script directory
set "SCRIPT_DIR=%~dp0"

REM Optional network bring-up (if helper exists)
if exist "%SCRIPT_DIR%WINRE_NETWORK_INIT.cmd" (
    call "%SCRIPT_DIR%WINRE_NETWORK_INIT.cmd"
)

REM Locate a PowerShell executable (prefer portable pwsh 7.x)
set "PS_EXE="
for %%P in (
    "%SCRIPT_DIR%pwsh.exe"
    "%SCRIPT_DIR%pwsh\pwsh.exe"
    "%SCRIPT_DIR%PowerShell\pwsh.exe"
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
    "X:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
) do (
    if exist %%~P (
        set "PS_EXE=%%~P"
        goto :PS_FOUND
    )
)

echo ERROR: PowerShell was not found in this WinRE / Shift+F10 environment.
echo.
echo Most reliable: pre-stage portable PowerShell 7 (pwsh.exe) next to this file,
echo or in a pwsh\ folder beside it. Then rerun SHIFT_F10.cmd.
echo.
echo If available in this image, you can also enable built-in WinPS:
echo   dism /online /enable-feature /featurename:MicrosoftWindowsPowerShell /all
echo.
pause
exit /b 1

:PS_FOUND
echo Using PowerShell: %PS_EXE%
echo.

REM Run MiracleBoot; auto GUI when possible, TUI otherwise.
"%PS_EXE%" -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%MiracleBoot.ps1"
if errorlevel 1 (
    echo.
    echo MiracleBoot returned an error. If GUI is unavailable in WinRE,
    echo try the text mode directly:
    echo   "%PS_EXE%" -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%HELPER SCRIPTS\WinRepairTUI.ps1"
    echo   "%PS_EXE%" -ExecutionPolicy Bypass -NoProfile -Command "Set-Location '%SCRIPT_DIR%'; . '.\\HELPER SCRIPTS\\WinRepairTUI.ps1'; Start-TUI"
    echo.
    pause
)

endlocal

