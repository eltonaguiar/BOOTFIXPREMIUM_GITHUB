@echo off
REM ============================================================================
REM EMERGENCY BOOT REPAIR - Standalone Recovery Tool
REM ============================================================================
REM This is a completely standalone batch file that requires NO dependencies.
REM Use this if MiracleBoot.ps1 or other scripts are broken.
REM
REM It can:
REM   - Detect boot configuration issues
REM   - Repair BCD (Boot Configuration Data)
REM   - Rebuild boot files
REM   - Fix partition boot sectors
REM   - Identify common boot problems
REM ============================================================================

setlocal enabledelayedexpansion
set "ERROR_COUNT=0"
set "FIXED_COUNT=0"

echo.
echo ================================================================================
echo   EMERGENCY BOOT REPAIR - Standalone Recovery Tool
echo ================================================================================
echo.
echo This tool is completely standalone and requires no dependencies.
echo Use this if MiracleBoot.ps1 or other scripts are broken.
echo.
echo WARNING: This will modify your boot configuration.
echo Press Ctrl+C within 5 seconds to cancel...
echo.
timeout /t 5 /nobreak >nul 2>&1
if errorlevel 1 goto :CANCELED

echo.
echo Starting emergency boot repair...
echo.

REM ============================================================================
REM STEP 1: Environment Detection
REM ============================================================================
echo [STEP 1] Detecting environment...
set "ENV_TYPE=Unknown"
set "SYSTEM_DRIVE="
set "WINDOWS_DRIVE="

REM Check if we're in WinPE/WinRE (usually X:)
if exist "X:\Windows\System32\winload.exe" (
    set "ENV_TYPE=WinPE"
    set "SYSTEM_DRIVE=X:"
    echo   Environment: WinPE/WinRE detected
) else (
    REM Check for full Windows installation
    if exist "C:\Windows\System32\winload.exe" (
        set "ENV_TYPE=FullOS"
        set "SYSTEM_DRIVE=C:"
        set "WINDOWS_DRIVE=C:"
        echo   Environment: Full Windows OS detected
    ) else (
        echo   WARNING: Could not detect Windows installation
        echo   Attempting to find Windows drive...
    )
)

REM Try to find Windows installation on other drives
if "%WINDOWS_DRIVE%"=="" (
    for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        if exist "%%D:\Windows\System32\winload.exe" (
            set "WINDOWS_DRIVE=%%D:"
            echo   Found Windows on drive %%D:
            goto :FOUND_WINDOWS
        )
    )
    :FOUND_WINDOWS
)

if "%WINDOWS_DRIVE%"=="" (
    echo   ERROR: Could not find Windows installation!
    set /a ERROR_COUNT+=1
    goto :DIAGNOSTIC_MODE
)

echo   Windows drive: %WINDOWS_DRIVE%
echo.

REM ============================================================================
REM STEP 2: Check Administrator Privileges
REM ============================================================================
echo [STEP 2] Checking privileges...
net session >nul 2>&1
if errorlevel 1 (
    echo   ERROR: Not running as administrator!
    echo   Please run this script as administrator.
    set /a ERROR_COUNT+=1
    goto :DIAGNOSTIC_MODE
) else (
    echo   Administrator privileges: OK
)
echo.

REM ============================================================================
REM STEP 3: Check Boot Configuration
REM ============================================================================
echo [STEP 3] Checking boot configuration...
bcdedit /enum {default} >nul 2>&1
if errorlevel 1 (
    echo   WARNING: Cannot access BCD store
    echo   This may be normal in WinPE if targeting a different drive
    set /a ERROR_COUNT+=1
) else (
    echo   BCD store: Accessible
    echo.
    echo   Current boot configuration:
    bcdedit /enum {default} 2>&1 | findstr /C:"device" /C:"path" /C:"osdevice" /C:"description"
)
echo.

REM ============================================================================
REM STEP 4: Diagnostic Checks
REM ============================================================================
echo [STEP 4] Running diagnostic checks...
echo.

REM Check 4a: Boot files exist
echo   [CHECK] Boot files...
if exist "%WINDOWS_DRIVE%\Windows\System32\winload.exe" (
    echo     winload.exe: OK
) else (
    echo     winload.exe: MISSING ^(CRITICAL^)
    set /a ERROR_COUNT+=1
)

if exist "%WINDOWS_DRIVE%\Windows\System32\winload.efi" (
    echo     winload.efi: OK
) else (
    echo     winload.efi: MISSING ^(if UEFI^)
)

REM Check 4b: BCD store exists
if "%ENV_TYPE%"=="WinPE" (
    REM In WinPE, check for BCD on target drive
    if exist "%WINDOWS_DRIVE%\Boot\BCD" (
        echo     BCD store: Found on target drive
    ) else (
        echo     BCD store: Not found on target drive
        set /a ERROR_COUNT+=1
    )
) else (
    if exist "%WINDOWS_DRIVE%\Boot\BCD" (
        echo     BCD store: Found
    ) else (
        echo     BCD store: MISSING ^(CRITICAL^)
        set /a ERROR_COUNT+=1
    )
)

REM Check 4c: EFI System Partition (for UEFI)
echo   [CHECK] EFI System Partition...
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\EFI\Microsoft\Boot\bootmgfw.efi" (
        echo     EFI boot files found on %%D:
        set "EFI_PARTITION=%%D:"
        goto :FOUND_EFI
    )
)
:FOUND_EFI

if "%EFI_PARTITION%"=="" (
    echo     EFI partition: Not found ^(may be normal for BIOS systems^)
) else (
    echo     EFI partition: Found on %EFI_PARTITION%
)
echo.

REM ============================================================================
REM STEP 5: Repair Attempts
REM ============================================================================
if %ERROR_COUNT% gtr 0 (
    echo [STEP 5] Attempting repairs...
    echo.
    
    REM Repair 5a: Rebuild BCD
    echo   [REPAIR] Rebuilding BCD...
    if "%ENV_TYPE%"=="WinPE" (
        REM In WinPE, use /store to target the actual Windows BCD
        if exist "%WINDOWS_DRIVE%\Boot\BCD" (
            bcdedit /store "%WINDOWS_DRIVE%\Boot\BCD" /enum {default} >nul 2>&1
            if errorlevel 1 (
                echo     Attempting to repair BCD store...
                bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_PARTITION% >nul 2>&1
                if errorlevel 1 (
                    echo     BCD repair: FAILED
                ) else (
                    echo     BCD repair: SUCCESS
                    set /a FIXED_COUNT+=1
                )
            ) else (
                echo     BCD store: Already accessible
            )
        ) else (
            echo     Creating new BCD store...
            bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_PARTITION% >nul 2>&1
            if errorlevel 1 (
                echo     BCD creation: FAILED
            ) else (
                echo     BCD creation: SUCCESS
                set /a FIXED_COUNT+=1
            )
        )
    ) else (
        REM In full OS, use standard commands
        bcdedit /enum {default} >nul 2>&1
        if errorlevel 1 (
            echo     Attempting to repair BCD...
            bcdboot %WINDOWS_DRIVE%\Windows >nul 2>&1
            if errorlevel 1 (
                echo     BCD repair: FAILED
            ) else (
                echo     BCD repair: SUCCESS
                set /a FIXED_COUNT+=1
            )
        ) else (
            echo     BCD: Already accessible
        )
    )
    echo.
    
    REM Repair 5b: Rebuild boot files
    echo   [REPAIR] Rebuilding boot files...
    if "%EFI_PARTITION%"=="" (
        echo     Skipping EFI boot file rebuild ^(no EFI partition found^)
    ) else (
        bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_PARTITION% /f ALL >nul 2>&1
        if errorlevel 1 (
            echo     Boot file rebuild: FAILED
        ) else (
            echo     Boot file rebuild: SUCCESS
            set /a FIXED_COUNT+=1
        )
    )
    echo.
    
    REM Repair 5c: Fix boot sector (if bootrec is available)
    echo   [REPAIR] Checking boot sector...
    where bootrec.exe >nul 2>&1
    if errorlevel 1 (
        echo     bootrec.exe: Not available ^(normal in WinPE^)
    ) else (
        echo     Running bootrec /fixmbr...
        bootrec /fixmbr >nul 2>&1
        if errorlevel 1 (
            echo     MBR fix: FAILED
        ) else (
            echo     MBR fix: SUCCESS
            set /a FIXED_COUNT+=1
        )
        
        echo     Running bootrec /fixboot...
        bootrec /fixboot >nul 2>&1
        if errorlevel 1 (
            echo     Boot sector fix: FAILED or not needed
        ) else (
            echo     Boot sector fix: SUCCESS
            set /a FIXED_COUNT+=1
        )
    )
    echo.
) else (
    echo [STEP 5] No critical errors detected - skipping repairs
    echo.
)

REM ============================================================================
REM STEP 6: Final Verification
REM ============================================================================
echo [STEP 6] Final verification...
bcdedit /enum {default} >nul 2>&1
if errorlevel 1 (
    echo   WARNING: BCD store still not accessible
    echo   You may need to run this from the target Windows installation
) else (
    echo   BCD store: Accessible
    echo.
    echo   Boot configuration summary:
    bcdedit /enum {default} 2>&1 | findstr /C:"identifier" /C:"device" /C:"path" /C:"description"
)
echo.

REM ============================================================================
REM SUMMARY
REM ============================================================================
echo ================================================================================
echo   REPAIR SUMMARY
echo ================================================================================
echo   Errors detected: %ERROR_COUNT%
echo   Issues fixed: %FIXED_COUNT%
echo.

if %ERROR_COUNT% equ 0 (
    echo   STATUS: No critical errors detected
    echo   Your boot configuration appears to be healthy.
) else (
    if %FIXED_COUNT% gtr 0 (
        echo   STATUS: Some issues were detected and repaired
        echo   Please restart your computer to test the fixes.
    ) else (
        echo   STATUS: Issues detected but could not be automatically repaired
        echo.
        echo   RECOMMENDED ACTIONS:
        echo   1. Ensure you are running from WinPE/WinRE or as Administrator
        echo   2. Verify the Windows drive letter is correct: %WINDOWS_DRIVE%
        if not "%EFI_PARTITION%"=="" (
            echo   3. Verify EFI partition: %EFI_PARTITION%
        )
        echo   4. Try running: bcdboot %WINDOWS_DRIVE%\Windows
        if not "%EFI_PARTITION%"=="" (
            echo   5. Try running: bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_PARTITION%
        )
    )
)
echo.
echo ================================================================================
echo.

goto :END

:DIAGNOSTIC_MODE
echo.
echo ================================================================================
echo   DIAGNOSTIC MODE
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
goto :STEP_3

:STEP_3
REM Jump back to step 3 with manually specified drive
echo [STEP 3] Checking boot configuration for %WINDOWS_DRIVE%...
if exist "%WINDOWS_DRIVE%\Boot\BCD" (
    bcdedit /store "%WINDOWS_DRIVE%\Boot\BCD" /enum {default} >nul 2>&1
    if errorlevel 1 (
        echo   WARNING: Cannot access BCD store
    ) else (
        echo   BCD store: Accessible
        bcdedit /store "%WINDOWS_DRIVE%\Boot\BCD" /enum {default} 2>&1 | findstr /C:"device" /C:"path" /C:"osdevice"
    )
) else (
    echo   BCD store: Not found
)
echo.
goto :STEP_4

:STEP_4
REM Continue with repairs using manually specified drive
echo [STEP 4] Attempting repairs for %WINDOWS_DRIVE%...
echo.
echo   [REPAIR] Rebuilding BCD...
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\EFI\Microsoft\Boot\bootmgfw.efi" (
        set "EFI_PARTITION=%%D:"
        goto :DO_REPAIR
    )
)
:DO_REPAIR
if "%EFI_PARTITION%"=="" (
    bcdboot %WINDOWS_DRIVE%\Windows >nul 2>&1
) else (
    bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_PARTITION% >nul 2>&1
)
if errorlevel 1 (
    echo     BCD repair: FAILED
) else (
    echo     BCD repair: SUCCESS
)
echo.
goto :STEP_6

:STEP_6
echo [STEP 6] Final verification...
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
echo.
goto :END

:CANCELED
echo.
echo Operation canceled by user.
goto :END

:END
echo.
echo Emergency repair tool finished.
echo.
pause
endlocal
exit /b 0
