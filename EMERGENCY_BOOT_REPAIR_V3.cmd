@echo off
REM ============================================================================
REM EMERGENCY BOOT REPAIR V3 - Last Resort Implementation
REM ============================================================================
REM This is a minimal, brute-force implementation.
REM Uses only basic commands and simple logic.
REM No complex nested structures or delayed expansion.
REM ============================================================================

setlocal
set "FIXED=0"
set "FAILED=0"
set "WINDRIVE="
set "EFIDRIVE="

echo.
echo ================================================================================
echo   EMERGENCY BOOT REPAIR V3 - Last Resort Recovery Tool
echo ================================================================================
echo.
echo This is a minimal implementation using only basic commands.
echo.
echo WARNING: This will modify your boot configuration.
echo Press Ctrl+C within 5 seconds to cancel...
echo.
timeout /t 5 /nobreak >nul 2>&1
if errorlevel 1 goto CANCEL

echo.
echo Starting emergency boot repair V3...
echo.

REM ============================================================================
REM Simple Environment Detection
REM ============================================================================
echo [STEP 1] Detecting environment...

if exist "C:\Windows\System32\winload.exe" (
    set "WINDRIVE=C:"
    echo   Found Windows on C:
    goto CHECKADMIN
)

if exist "D:\Windows\System32\winload.exe" (
    set "WINDRIVE=D:"
    echo   Found Windows on D:
    goto CHECKADMIN
)

if exist "E:\Windows\System32\winload.exe" (
    set "WINDRIVE=E:"
    echo   Found Windows on E:
    goto CHECKADMIN
)

if exist "F:\Windows\System32\winload.exe" (
    set "WINDRIVE=F:"
    echo   Found Windows on F:
    goto CHECKADMIN
)

echo   ERROR: Could not find Windows installation!
goto SUMMARY

:CHECKADMIN
echo.
echo [STEP 2] Checking privileges...
net session >nul 2>&1
if errorlevel 1 (
    echo   ERROR: Not running as administrator!
    set /a FAILED+=1
    goto SUMMARY
)
echo   Administrator privileges: OK

REM ============================================================================
REM Find EFI Partition
REM ============================================================================
echo.
echo [STEP 3] Finding EFI partition...

if exist "C:\EFI\Microsoft\Boot\bootmgfw.efi" (
    set "EFIDRIVE=C:"
    echo   EFI partition found on C:
    goto CHECKBCD
)

if exist "D:\EFI\Microsoft\Boot\bootmgfw.efi" (
    set "EFIDRIVE=D:"
    echo   EFI partition found on D:
    goto CHECKBCD
)

if exist "E:\EFI\Microsoft\Boot\bootmgfw.efi" (
    set "EFIDRIVE=E:"
    echo   EFI partition found on E:
    goto CHECKBCD
)

echo   EFI partition: Not found (may be normal for BIOS systems)
goto CHECKBCD

:CHECKBCD
echo.
echo [STEP 4] Checking BCD...

if exist "%WINDRIVE%\Boot\BCD" (
    echo   BCD file exists
    goto REPAIR
) else (
    echo   BCD file: MISSING
    set /a FAILED+=1
    goto REPAIR
)

:REPAIR
echo.
echo [STEP 5] Attempting repairs...

if "%EFIDRIVE%"=="" (
    echo   [REPAIR] Running bcdboot without EFI partition...
    bcdboot %WINDRIVE%\Windows >nul 2>&1
    if errorlevel 1 (
        echo     BCD repair: FAILED
        set /a FAILED+=1
    ) else (
        echo     BCD repair: SUCCESS
        set /a FIXED+=1
    )
) else (
    echo   [REPAIR] Running bcdboot with EFI partition...
    bcdboot %WINDRIVE%\Windows /s %EFIDRIVE% >nul 2>&1
    if errorlevel 1 (
        echo     BCD repair: FAILED
        set /a FAILED+=1
    ) else (
        echo     BCD repair: SUCCESS
        set /a FIXED+=1
    )
)

if not "%EFIDRIVE%"=="" (
    echo.
    echo   [REPAIR] Rebuilding boot files...
    bcdboot %WINDRIVE%\Windows /s %EFIDRIVE% /f ALL >nul 2>&1
    if errorlevel 1 (
        echo     Boot file rebuild: FAILED
        set /a FAILED+=1
    ) else (
        echo     Boot file rebuild: SUCCESS
        set /a FIXED+=1
    )
)

REM ============================================================================
REM Final Check
REM ============================================================================
echo.
echo [STEP 6] Final verification...

if exist "%WINDRIVE%\Boot\BCD" (
    echo   BCD file: Found
) else (
    echo   BCD file: Still missing
    set /a FAILED+=1
)

REM ============================================================================
REM SUMMARY
REM ============================================================================
:SUMMARY
echo.
echo ================================================================================
echo   REPAIR SUMMARY (V3)
echo ================================================================================
echo   Issues fixed: %FIXED%
echo   Issues failed: %FAILED%
echo.

if %FIXED% gtr 0 (
    echo   STATUS: Some issues were repaired
    echo   Please restart your computer to test the fixes.
) else (
    if %FAILED% gtr 0 (
        echo   STATUS: Issues detected but could not be automatically repaired
        echo   Manual intervention may be required.
    ) else (
        echo   STATUS: No critical errors detected
    )
)
echo.
echo ================================================================================
echo.
goto END

:CANCEL
echo.
echo Operation canceled by user.
goto END

:END
echo.
echo Emergency repair tool V3 finished.
echo.
pause
endlocal
exit /b %FAILED%
