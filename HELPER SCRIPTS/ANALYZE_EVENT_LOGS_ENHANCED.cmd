@echo off
REM Enhanced Event Log Analyzer for MiracleBoot
REM Provides both interactive menu and GUI access to error analysis with database matching

setlocal enabledelayedexpansion

:menu
cls
echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║   MiracleBoot - Enhanced Event Log Analyzer                ║
echo ║   Error Database with Suggested Fixes                      ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo What would you like to do?
echo.
echo 1. Analyze Event Logs (GUI - Recommended)
echo 2. Analyze Event Logs (Text Output)
echo 3. Quick Scan (Last 24 hours)
echo 4. Deep Scan (Last 7 days)
echo 5. Launch Standalone AutoLogAnalyzer
echo 6. Open Event Viewer
echo 7. Return to Main Menu
echo 8. Exit
echo.
set /p choice=Enter choice (1-8): 

if "%choice%"=="1" goto gui_analysis
if "%choice%"=="2" goto text_analysis
if "%choice%"=="3" goto quick_scan
if "%choice%"=="4" goto deep_scan
if "%choice%"=="5" goto autoanalyzer
if "%choice%"=="6" goto eventviewer
if "%choice%"=="7" goto end
if "%choice%"=="8" goto end

echo Invalid choice. Please try again.
timeout /t 2 >nul
goto menu

:gui_analysis
cls
echo.
echo Running Enhanced Event Log Analysis (GUI)...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Invoke-EnhancedEventLogAnalyzer.ps1" -HoursBack 48
pause
goto menu

:text_analysis
cls
echo.
echo Running Enhanced Event Log Analysis...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Invoke-EnhancedEventLogAnalyzer.ps1" -HoursBack 48
echo.
pause
goto menu

:quick_scan
cls
echo.
echo Quick Scan - Last 24 Hours
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Invoke-EnhancedEventLogAnalyzer.ps1" -HoursBack 24
echo.
pause
goto menu

:deep_scan
cls
echo.
echo Deep Scan - Last 7 Days
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Invoke-EnhancedEventLogAnalyzer.ps1" -HoursBack 168
echo.
pause
goto menu

:autoanalyzer
cls
echo.
echo Launching AutoLogAnalyzer Enhanced...
echo.
if exist "%~dp0..\AutoLogAnalyzer_Enhanced.ps1" (
    powershell -ExecutionPolicy Bypass -File "%~dp0..\AutoLogAnalyzer_Enhanced.ps1"
) else if exist "%~dp0AutoLogAnalyzer_Enhanced.ps1" (
    powershell -ExecutionPolicy Bypass -File "%~dp0AutoLogAnalyzer_Enhanced.ps1"
) else (
    echo AutoLogAnalyzer_Enhanced.ps1 not found in expected locations.
    echo Searching...
    for /r "%~dp0.." %%F in (AutoLogAnalyzer_Enhanced.ps1) do (
        powershell -ExecutionPolicy Bypass -File "%%F"
        goto menu
    )
    echo File not found. Please ensure AutoLogAnalyzer_Enhanced.ps1 is in the correct location.
)
pause
goto menu

:eventviewer
start eventvwr.exe
goto menu

:end
exit /b 0
