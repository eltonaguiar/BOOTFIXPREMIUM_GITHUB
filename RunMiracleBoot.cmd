@echo off
REM Miracle Boot v7.2.0 Launcher
REM Compatible with Windows Recovery Environment (WinRE) Shift+F10 command prompt

echo.
echo ========================================
echo   Miracle Boot v7.2.0 Launcher
echo ========================================
echo.

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"

REM Locate a PowerShell executable (WinRE often lacks powershell.exe in PATH)
set "PS_EXE="
for %%P in (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
    "X:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    "%SCRIPT_DIR%pwsh.exe"
    "%SCRIPT_DIR%PowerShell\pwsh.exe"
    "%SCRIPT_DIR%..\PowerShell\pwsh.exe"
) do (
    if exist %%~P (
        set "PS_EXE=%%~P"
        goto :PS_FOUND
    )
)

echo ERROR: PowerShell was not found.
echo.
echo To use MiracleBoot in WinRE/Shift+F10:
echo 1) If available, copy portable PowerShell 7 (pwsh.exe) into this folder.
echo 2) Or use a WinRE image that includes the PowerShell optional component.
echo.
pause
exit /b 1

:PS_FOUND
echo Launching Miracle Boot with: %PS_EXE%
echo.
"%PS_EXE%" -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%MiracleBoot.ps1" %*

if errorlevel 1 (
    echo.
    echo ERROR: Script execution failed.
    echo.
    echo Troubleshooting:
    echo 1. Ensure all .ps1 files are in the same directory as this .cmd file
    echo 2. Check that you have administrator privileges
    echo 3. Try running PowerShell directly: "%PS_EXE%" -ExecutionPolicy Bypass -File MiracleBoot.ps1
    echo.
    pause
)

