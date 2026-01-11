@echo off
REM Miracle Boot v7.2.0 Launcher
REM Compatible with Windows Recovery Environment (WinRE) Shift+F10 command prompt
REM Fixed: Properly handles paths with spaces and special characters

setlocal enabledelayedexpansion
set "ERROR_OCCURRED=0"

echo.
echo ========================================
echo   Miracle Boot v7.2.0 Launcher
echo ========================================
echo.

REM Get the directory where this batch file is located
REM Use quotes and proper expansion to handle paths with spaces
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=!SCRIPT_DIR:~0,-1!"

REM Locate a PowerShell executable (WinRE often lacks powershell.exe in PATH)
set "PS_EXE="
for %%P in (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
    "X:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    "!SCRIPT_DIR!\pwsh.exe"
    "!SCRIPT_DIR!\PowerShell\pwsh.exe"
    "!SCRIPT_DIR!\..\PowerShell\pwsh.exe"
) do (
    if exist "%%~P" (
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
if "!PS_EXE!"=="" (
    echo ERROR: PowerShell executable path is empty.
    echo This should not happen. Please report this issue.
    pause
    exit /b 1
)

echo Launching Miracle Boot with: !PS_EXE!
echo.

REM Verify MiracleBoot.ps1 exists before attempting to run
set "MAIN_SCRIPT=!SCRIPT_DIR!\MiracleBoot.ps1"
if not exist "!MAIN_SCRIPT!" (
    echo ERROR: MiracleBoot.ps1 not found at: !MAIN_SCRIPT!
    echo.
    echo Please ensure MiracleBoot.ps1 is in the same directory as this .cmd file.
    echo.
    pause
    exit /b 1
)

REM Execute PowerShell script with proper quoting for paths with spaces
"!PS_EXE!" -ExecutionPolicy Bypass -NoProfile -File "!MAIN_SCRIPT!" %*

set "EXIT_CODE=!ERRORLEVEL!"
if !EXIT_CODE! neq 0 (
    echo.
    echo ERROR: Script execution failed with exit code !EXIT_CODE!
    echo.
    echo Troubleshooting:
    echo 1. Ensure all .ps1 files are in the same directory as this .cmd file
    echo 2. Check that you have administrator privileges
    echo 3. Try running PowerShell directly: "!PS_EXE!" -ExecutionPolicy Bypass -File "!MAIN_SCRIPT!"
    echo.
    pause
    exit /b !EXIT_CODE!
)

endlocal
exit /b 0
