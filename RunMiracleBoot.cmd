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

REM Check if PowerShell is available
powershell.exe -Command "exit 0" >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell is not available in this environment.
    echo This script requires PowerShell to run.
    pause
    exit /b 1
)

REM Launch the PowerShell script
echo Launching Miracle Boot...
echo.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%MiracleBoot.ps1"

if errorlevel 1 (
    echo.
    echo ERROR: Script execution failed.
    echo.
    echo Troubleshooting:
    echo 1. Ensure all .ps1 files are in the same directory as this .cmd file
    echo 2. Check that you have administrator privileges
    echo 3. Try running PowerShell directly: powershell.exe -ExecutionPolicy Bypass -File MiracleBoot.ps1
    echo.
    pause
)

