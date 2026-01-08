@echo off
REM Quick Error Summary Launcher
REM This batch file provides easy access to the QuickErrorSummary tool

setlocal enabledelayedexpansion

cls
echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║   QuickErrorSummary - Get Error Logs for ChatGPT Analysis   ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.

REM Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo Please run as Administrator.
    echo.
    pause
    exit /b 1
)

REM Get the script directory
for %%I in ("%~dp0.") do set "SCRIPT_DIR=%%~fI"

echo Select analysis mode:
echo.
echo 1. Quick Summary (last 24 hours, compact format)
echo 2. Detailed Analysis (last 24 hours, for ChatGPT)
echo 3. Extended Analysis (last 48 hours, full details)
echo 4. Custom (configure options)
echo 5. Copy to Clipboard (24 hours, auto-copy)
echo.

set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" (
    echo.
    echo Starting Quick Summary...
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\QuickErrorSummary.ps1" -DetailLevel Compact -HoursBack 24
    goto end
)

if "%choice%"=="2" (
    echo.
    echo Starting Detailed Analysis...
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\QuickErrorSummary.ps1" -DetailLevel Summary -HoursBack 24
    goto end
)

if "%choice%"=="3" (
    echo.
    echo Starting Extended Analysis...
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\QuickErrorSummary.ps1" -DetailLevel Full -HoursBack 48 -TopErrors 20
    goto end
)

if "%choice%"=="4" (
    set /p hours="Hours back to analyze (default 24): "
    if "!hours!"=="" set hours=24
    
    echo.
    echo Detail Levels: 1=Compact, 2=Summary, 3=Full
    set /p detail="Select detail level (default 2): "
    if "!detail!"=="" set detail=2
    
    set detailName=Summary
    if "!detail!"=="1" set detailName=Compact
    if "!detail!"=="3" set detailName=Full
    
    echo.
    set /p topn="Number of top errors to show (default 15): "
    if "!topn!"=="" set topn=15
    
    echo.
    echo Starting Custom Analysis...
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\QuickErrorSummary.ps1" -DetailLevel !detailName! -HoursBack !hours! -TopErrors !topn!
    goto end
)

if "%choice%"=="5" (
    echo.
    echo Starting Quick Summary and copying to clipboard...
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\QuickErrorSummary.ps1" -DetailLevel Compact -HoursBack 24 -CopyToClipboard
    echo.
    echo ✓ Error summary has been copied to your clipboard!
    echo   Paste it into ChatGPT using Ctrl+V
    pause
    goto end
)

echo Invalid choice. Please run the script again.
pause
exit /b 1

:end
echo.
echo Press any key to close...
pause >nul
exit /b 0
