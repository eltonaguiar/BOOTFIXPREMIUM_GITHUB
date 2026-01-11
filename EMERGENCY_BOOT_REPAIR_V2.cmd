@echo off
REM ============================================================================
REM EMERGENCY BOOT REPAIR V2 - Alternative Implementation
REM ============================================================================
REM This is a completely different implementation from V1.
REM Uses goto-based flow control instead of nested if statements.
REM No dependencies required.
REM ============================================================================

setlocal enabledelayedexpansion
set "REPAIR_SUCCESS=0"
set "REPAIR_FAILED=0"
set "WINDOWS_DRIVE="
set "EFI_PARTITION="

echo.
echo ================================================================================
echo   EMERGENCY BOOT REPAIR V2 - Alternative Recovery Tool
echo ================================================================================
echo.
echo This is an alternative implementation with different coding approach.
echo.
echo WARNING: This will modify your boot configuration.
echo Press Ctrl+C within 5 seconds to cancel...
echo.
timeout /t 5 /nobreak >nul 2>&1
if errorlevel 1 goto :USER_CANCELED

echo.
echo Starting emergency boot repair V2...
echo.

REM ============================================================================
REM Environment Detection - Using goto labels instead of nested if
REM ============================================================================
echo [STEP 1] Detecting environment...

REM Check WinPE first
if exist "X:\Windows\System32\winload.exe" goto :WINPE_DETECTED

REM Check FullOS
if exist "C:\Windows\System32\winload.exe" goto :FULLOS_DETECTED

REM Search all drives
goto :SEARCH_DRIVES

:WINPE_DETECTED
set "ENV_TYPE=WinPE"
set "SYSTEM_DRIVE=X:"
echo   Environment: WinPE/WinRE detected
goto :FIND_WINDOWS_DRIVE

:FULLOS_DETECTED
set "ENV_TYPE=FullOS"
set "SYSTEM_DRIVE=C:"
set "WINDOWS_DRIVE=C:"
echo   Environment: Full Windows OS detected
goto :CHECK_PRIVILEGES

:SEARCH_DRIVES
echo   WARNING: Could not detect Windows installation
echo   Attempting to find Windows drive...
goto :FIND_WINDOWS_DRIVE

:FIND_WINDOWS_DRIVE
if not "%WINDOWS_DRIVE%"=="" goto :CHECK_PRIVILEGES
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\Windows\System32\winload.exe" (
        set "WINDOWS_DRIVE=%%D:"
        echo   Found Windows on drive %%D:
        goto :CHECK_PRIVILEGES
    )
)

echo   ERROR: Could not find Windows installation!
goto :DIAGNOSTIC_ONLY

:CHECK_PRIVILEGES
echo   Windows drive: %WINDOWS_DRIVE%
echo.
echo [STEP 2] Checking privileges...
net session >nul 2>&1
if errorlevel 1 (
    echo   ERROR: Not running as administrator!
    set /a REPAIR_FAILED+=1
    goto :DIAGNOSTIC_ONLY
)
echo   Administrator privileges: OK
echo.

REM ============================================================================
REM Boot Configuration Check
REM ============================================================================
echo [STEP 3] Checking boot configuration...
if "%ENV_TYPE%"=="WinPE" goto :CHECK_BCD_WINPE
goto :CHECK_BCD_FULLOS

:CHECK_BCD_WINPE
if exist "%WINDOWS_DRIVE%\Boot\BCD" (
    bcdedit /store "%WINDOWS_DRIVE%\Boot\BCD" /enum {default} >nul 2>&1
    if errorlevel 1 (
        echo   WARNING: Cannot access BCD store
        set /a REPAIR_FAILED+=1
    ) else (
        echo   BCD store: Accessible
    )
) else (
    echo   BCD store: Not found
    set /a REPAIR_FAILED+=1
)
goto :FIND_EFI

:CHECK_BCD_FULLOS
bcdedit /enum {default} >nul 2>&1
if errorlevel 1 (
    echo   WARNING: Cannot access BCD store
    set /a REPAIR_FAILED+=1
) else (
    echo   BCD store: Accessible
)
goto :FIND_EFI

:FIND_EFI
echo.
echo [STEP 4] Finding EFI partition...
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\EFI\Microsoft\Boot\bootmgfw.efi" (
        set "EFI_PARTITION=%%D:"
        echo   EFI partition found on %%D:
        goto :RUN_REPAIRS
    )
)
echo   EFI partition: Not found (may be normal for BIOS systems)
goto :RUN_REPAIRS

:RUN_REPAIRS
echo.
if %REPAIR_FAILED% gtr 0 (
    echo [STEP 5] Attempting repairs...
    echo.
    goto :REPAIR_BCD
) else (
    echo [STEP 5] No critical errors detected - skipping repairs
    echo.
    goto :VERIFY
)

:REPAIR_BCD
echo   [REPAIR] Rebuilding BCD...
if "%ENV_TYPE%"=="WinPE" goto :REPAIR_BCD_WINPE
goto :REPAIR_BCD_FULLOS

:REPAIR_BCD_WINPE
if exist "%WINDOWS_DRIVE%\Boot\BCD" (
    bcdedit /store "%WINDOWS_DRIVE%\Boot\BCD" /enum {default} >nul 2>&1
    if errorlevel 1 (
        echo     Attempting to repair BCD store...
        if not "%EFI_PARTITION%"=="" (
            bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_PARTITION% >nul 2>&1
        ) else (
            bcdboot %WINDOWS_DRIVE%\Windows >nul 2>&1
        )
        if errorlevel 1 (
            echo     BCD repair: FAILED
            set /a REPAIR_FAILED+=1
        ) else (
            echo     BCD repair: SUCCESS
            set /a REPAIR_SUCCESS+=1
        )
    ) else (
        echo     BCD store: Already accessible
    )
) else (
    echo     Creating new BCD store...
    if not "%EFI_PARTITION%"=="" (
        bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_PARTITION% >nul 2>&1
    ) else (
        bcdboot %WINDOWS_DRIVE%\Windows >nul 2>&1
    )
    if errorlevel 1 (
        echo     BCD creation: FAILED
        set /a REPAIR_FAILED+=1
    ) else (
        echo     BCD creation: SUCCESS
        set /a REPAIR_SUCCESS+=1
    )
)
goto :REPAIR_BOOTFILES

:REPAIR_BCD_FULLOS
bcdedit /enum {default} >nul 2>&1
if errorlevel 1 (
    echo     Attempting to repair BCD...
    bcdboot %WINDOWS_DRIVE%\Windows >nul 2>&1
    if errorlevel 1 (
        echo     BCD repair: FAILED
        set /a REPAIR_FAILED+=1
    ) else (
        echo     BCD repair: SUCCESS
        set /a REPAIR_SUCCESS+=1
    )
) else (
    echo     BCD: Already accessible
)
goto :REPAIR_BOOTFILES

:REPAIR_BOOTFILES
echo.
echo   [REPAIR] Rebuilding boot files...
if "%EFI_PARTITION%"=="" (
    echo     Skipping EFI boot file rebuild (no EFI partition found)
) else (
    bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_PARTITION% /f ALL >nul 2>&1
    if errorlevel 1 (
        echo     Boot file rebuild: FAILED
        set /a REPAIR_FAILED+=1
    ) else (
        echo     Boot file rebuild: SUCCESS
        set /a REPAIR_SUCCESS+=1
    )
)
goto :VERIFY

:VERIFY
echo.
echo [STEP 6] Final verification...
if "%ENV_TYPE%"=="WinPE" (
    if exist "%WINDOWS_DRIVE%\Boot\BCD" (
        bcdedit /store "%WINDOWS_DRIVE%\Boot\BCD" /enum {default} >nul 2>&1
        if errorlevel 1 (
            echo   WARNING: BCD store still not accessible
        ) else (
            echo   BCD store: Accessible
        )
    ) else (
        echo   BCD store: Still not found
    )
) else (
    bcdedit /enum {default} >nul 2>&1
    if errorlevel 1 (
        echo   WARNING: BCD store still not accessible
    ) else (
        echo   BCD store: Accessible
    )
)
echo.

REM ============================================================================
REM SUMMARY
REM ============================================================================
echo ================================================================================
echo   REPAIR SUMMARY (V2)
echo ================================================================================
echo   Issues fixed: %REPAIR_SUCCESS%
echo   Issues failed: %REPAIR_FAILED%
echo.

if %REPAIR_SUCCESS% gtr 0 (
    echo   STATUS: Some issues were repaired
    echo   Please restart your computer to test the fixes.
) else (
    if %REPAIR_FAILED% gtr 0 (
        echo   STATUS: Issues detected but could not be automatically repaired
        echo   Consider trying V1 or V3 emergency repair tools.
    ) else (
        echo   STATUS: No critical errors detected
        echo   Your boot configuration appears to be healthy.
    )
)
echo.
echo ================================================================================
echo.
goto :END

:DIAGNOSTIC_ONLY
echo.
echo ================================================================================
echo   DIAGNOSTIC MODE (V2)
echo ================================================================================
echo   Could not automatically detect Windows installation.
echo   Please provide the drive letter where Windows is installed.
echo.
set /p "WINDOWS_DRIVE=Enter Windows drive letter (e.g., C:): "
if "%WINDOWS_DRIVE%"=="" (
    echo   No drive specified. Exiting.
    goto :END
)
set "WINDOWS_DRIVE=%WINDOWS_DRIVE:~0,2%"
if not exist "%WINDOWS_DRIVE%\Windows\System32\winload.exe" (
    echo   ERROR: Windows not found on %WINDOWS_DRIVE%
    goto :END
)
echo   Windows found on %WINDOWS_DRIVE%
echo.
goto :FIND_EFI

:USER_CANCELED
echo.
echo Operation canceled by user.
goto :END

:END
echo.
echo Emergency repair tool V2 finished.
echo.
pause
endlocal
exit /b %REPAIR_FAILED%
