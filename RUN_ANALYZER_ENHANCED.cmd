@echo off
REM AutoLogAnalyzer Enhanced - Interactive Launcher
REM Provides menu-driven access to log analysis with automatic error fixes

setlocal enabledelayedexpansion

:menu
cls
echo.
echo ============================================
echo     AutoLogAnalyzer - Enhanced Edition
echo ============================================
echo.
echo What would you like to do?
echo.
echo 1. Quick Scan (Last 48 hours)
echo 2. Deep Scan (Last 7 days)
echo 3. Custom Period (Enter hours)
echo 4. View Previous Report
echo 5. Open Help Documentation
echo 6. Exit
echo.
set /p choice=Enter choice (1-6): 

if "%choice%"=="1" goto scan48
if "%choice%"=="2" goto scan7days
if "%choice%"=="3" goto scancustom
if "%choice%"=="4" goto viewreport
if "%choice%"=="5" goto help
if "%choice%"=="6" goto end

echo Invalid choice. Please try again.
timeout /t 2 >nul
goto menu

:scan48
echo.
echo Running quick scan (48 hours)...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0AutoLogAnalyzer_Enhanced.ps1" -HoursBack 48
pause
goto menu

:scan7days
echo.
echo Running deep scan (7 days)...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0AutoLogAnalyzer_Enhanced.ps1" -HoursBack 168
pause
goto menu

:scancustom
echo.
set /p hours=Enter number of hours to scan back: 
echo.
echo Running custom scan (%hours% hours)...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0AutoLogAnalyzer_Enhanced.ps1" -HoursBack %hours%
pause
goto menu

:viewreport
echo.
echo Opening reports folder...
start explorer "%~dp0LOG_ANALYSIS_ENHANCED"
goto menu

:help
echo.
echo ===== AutoLogAnalyzer Help =====
echo.
echo This tool automatically:
echo  - Collects Windows Event Viewer logs
echo  - Matches errors against built-in knowledge database
echo  - Provides likely causes for each error
echo  - Suggests specific fixes in priority order
echo.
echo Key Features:
echo  - No internet required (offline database)
echo  - Identifies critical vs warning issues
echo  - Generates ChatGPT-ready reports
echo  - Creates CSV for Excel analysis
echo.
echo For more info, see documentation files.
echo.
pause
goto menu

:end
exit /b 0
