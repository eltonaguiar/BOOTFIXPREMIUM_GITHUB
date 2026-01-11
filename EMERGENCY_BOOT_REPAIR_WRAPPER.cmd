@echo off
REM ============================================================================
REM EMERGENCY BOOT REPAIR - AUTOMATIC FAILOVER WRAPPER
REM ============================================================================
REM This wrapper automatically tries V1, V2, then V3 if previous versions fail.
REM Each version uses completely different coding approaches to maximize success.
REM ============================================================================

setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set "V1_SUCCESS=0"
set "V2_SUCCESS=0"
set "V3_SUCCESS=0"
set "ATTEMPTED=0"

echo.
echo ================================================================================
echo   EMERGENCY BOOT REPAIR - AUTOMATIC FAILOVER SYSTEM
echo ================================================================================
echo.
echo This tool will automatically try multiple repair implementations:
echo   V1: Original implementation with nested if statements
echo   V2: Alternative implementation with goto-based flow control
echo   V3: Minimal implementation with basic commands only
echo.
echo If one version fails, the next will be tried automatically.
echo.
echo WARNING: This will modify your boot configuration.
echo Press Ctrl+C within 5 seconds to cancel...
echo.
timeout /t 5 /nobreak >nul 2>&1
if errorlevel 1 goto :CANCELED

echo.
echo ================================================================================
echo   ATTEMPTING REPAIR VERSION 1
echo ================================================================================
echo.
set /a ATTEMPTED+=1

if exist "%SCRIPT_DIR%EMERGENCY_BOOT_REPAIR.cmd" (
    call "%SCRIPT_DIR%EMERGENCY_BOOT_REPAIR.cmd"
    set "V1_EXITCODE=%ERRORLEVEL%"
    if %V1_EXITCODE% equ 0 (
        set "V1_SUCCESS=1"
        echo.
        echo ================================================================================
        echo   VERSION 1 SUCCESSFUL - REPAIR COMPLETE
        echo ================================================================================
        echo.
        goto :SUCCESS
    ) else (
        echo.
        echo ================================================================================
        echo   VERSION 1 FAILED (Exit code: %V1_EXITCODE%^)
        echo   Attempting Version 2...
        echo ================================================================================
        echo.
    )
) else (
    echo   ERROR: EMERGENCY_BOOT_REPAIR.cmd not found!
    echo   Skipping to Version 2...
    echo.
)

REM ============================================================================
REM Try Version 2
REM ============================================================================
echo ================================================================================
echo   ATTEMPTING REPAIR VERSION 2
echo ================================================================================
echo.
set /a ATTEMPTED+=1

if exist "%SCRIPT_DIR%EMERGENCY_BOOT_REPAIR_V2.cmd" (
    call "%SCRIPT_DIR%EMERGENCY_BOOT_REPAIR_V2.cmd"
    set "V2_EXITCODE=%ERRORLEVEL%"
    if %V2_EXITCODE% equ 0 (
        set "V2_SUCCESS=1"
        echo.
        echo ================================================================================
        echo   VERSION 2 SUCCESSFUL - REPAIR COMPLETE
        echo ================================================================================
        echo.
        goto :SUCCESS
    ) else (
        echo.
        echo ================================================================================
        echo   VERSION 2 FAILED (Exit code: %V2_EXITCODE%^)
        echo   Attempting Version 3 (Last Resort)...
        echo ================================================================================
        echo.
    )
) else (
    echo   ERROR: EMERGENCY_BOOT_REPAIR_V2.cmd not found!
    echo   Skipping to Version 3...
    echo.
)

REM ============================================================================
REM Try Version 3 (Last Resort)
REM ============================================================================
echo ================================================================================
echo   ATTEMPTING REPAIR VERSION 3 (LAST RESORT)
echo ================================================================================
echo.
set /a ATTEMPTED+=1

if exist "%SCRIPT_DIR%EMERGENCY_BOOT_REPAIR_V3.cmd" (
    call "%SCRIPT_DIR%EMERGENCY_BOOT_REPAIR_V3.cmd"
    set "V3_EXITCODE=%ERRORLEVEL%"
    if %V3_EXITCODE% equ 0 (
        set "V3_SUCCESS=1"
        echo.
        echo ================================================================================
        echo   VERSION 3 SUCCESSFUL - REPAIR COMPLETE
        echo ================================================================================
        echo.
        goto :SUCCESS
    ) else (
        echo.
        echo ================================================================================
        echo   VERSION 3 FAILED (Exit code: %V3_EXITCODE%^)
        echo   All repair attempts exhausted.
        echo ================================================================================
        echo.
        goto :ALL_FAILED
    )
) else (
    echo   ERROR: EMERGENCY_BOOT_REPAIR_V3.cmd not found!
    echo   All repair attempts exhausted.
    echo.
    goto :ALL_FAILED
)

REM ============================================================================
REM Success Path
REM ============================================================================
:SUCCESS
echo ================================================================================
echo   FAILOVER SYSTEM SUMMARY
echo ================================================================================
echo   Versions attempted: %ATTEMPTED%
if %V1_SUCCESS% equ 1 (
    echo   Successful version: V1 (Original implementation)
)
if %V2_SUCCESS% equ 1 (
    echo   Successful version: V2 (Goto-based implementation)
)
if %V3_SUCCESS% equ 1 (
    echo   Successful version: V3 (Minimal implementation)
)
echo.
echo   STATUS: REPAIR SUCCESSFUL
echo   Please restart your computer to test the fixes.
echo.
echo ================================================================================
echo.
goto :END

REM ============================================================================
REM All Failed Path
REM ============================================================================
:ALL_FAILED
echo ================================================================================
echo   FAILOVER SYSTEM SUMMARY
echo ================================================================================
echo   Versions attempted: %ATTEMPTED%
echo   V1 result: %V1_SUCCESS% (Exit: %V1_EXITCODE%^)
echo   V2 result: %V2_SUCCESS% (Exit: %V2_EXITCODE%^)
echo   V3 result: %V3_SUCCESS% (Exit: %V3_EXITCODE%^)
echo.
echo   STATUS: ALL REPAIR ATTEMPTS FAILED
echo.
echo   RECOMMENDED ACTIONS:
echo   1. Verify you are running as Administrator
echo   2. Check that Windows installation is accessible
echo   3. Try running each version manually to see detailed error messages
echo   4. Consider using Windows Recovery Environment (WinRE)
echo   5. Manual boot repair may be required
echo.
echo ================================================================================
echo.
goto :END

:CANCELED
echo.
echo Operation canceled by user.
goto :END

:END
echo.
echo Failover system finished.
echo.
pause
endlocal
exit /b 0
