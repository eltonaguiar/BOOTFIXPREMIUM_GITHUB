@echo off
REM ============================================================================
REM  AutoLogAnalyzer Launcher - Easy Access Batch File
REM ============================================================================

title MiracleBoot - AutoLogAnalyzer

REM Check if we're in the right directory
if not exist "AutoLogAnalyzer.ps1" (
    echo.
    echo ERROR: AutoLogAnalyzer.ps1 not found!
    echo.
    echo Please run this from: c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code
    echo.
    pause
    exit /b 1
)

REM Launch PowerShell with the interactive menu
powershell -NoProfile -ExecutionPolicy Bypass -File "AUTO_ANALYZE_LOGS.ps1" -Mode Interactive

pause
