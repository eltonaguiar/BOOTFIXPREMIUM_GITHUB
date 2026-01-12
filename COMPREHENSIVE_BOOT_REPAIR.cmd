@echo off
REM ============================================================================
REM COMPREHENSIVE BOOT REPAIR - All-in-One Standalone Repair Tool
REM ============================================================================
REM This is a completely standalone batch file that requires NO PowerShell.
REM It diagnoses boot issues and runs ALL available repairs sequentially
REM until boot is restored.
REM
REM Repair Sequence:
REM   1. Custom repair based on detected boot issues
REM   2. Emergency Boot Repair V4 (Intelligent Minimal Repair)
REM   3. Emergency Boot Repair V1 (Standard Repair)
REM   4. Emergency Boot Repair V2 (Alternative Implementation)
REM   5. Emergency Boot Repair V3 (Minimal Last Resort)
REM
REM After each repair, validates boot readiness and stops if successful.
REM ============================================================================

setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set "WINDOWS_DRIVE="
set "EFI_DRIVE="
set "BOOT_READY=0"
set "REPAIR_ATTEMPTED=0"
set "REPAIR_SUCCESS=0"
set "ISSUES_FOUND="
set "FIXES_APPLIED="

echo.
echo ================================================================================
echo   COMPREHENSIVE BOOT REPAIR - All-in-One Standalone Tool
echo ================================================================================
echo.
echo This tool will:
echo   1. Diagnose your boot issues
echo   2. Run a custom repair based on detected issues
echo   3. Try Emergency Fixes 1-4 sequentially until boot is restored
echo.
echo WARNING: This will modify your boot configuration.
echo Press Ctrl+C within 5 seconds to cancel...
echo.
timeout /t 5 /nobreak >nul 2>&1
if errorlevel 1 goto :CANCELED

echo.
echo Starting comprehensive boot repair...
echo.

REM ============================================================================
REM STEP 1: Environment Detection
REM ============================================================================
echo [STEP 1] Detecting environment and Windows installation...
set "ENV_TYPE=Unknown"

REM Check WinPE/WinRE
if exist "X:\Windows\System32\winload.exe" (
    set "ENV_TYPE=WinPE"
    echo   Environment: WinPE/WinRE detected
    goto :FIND_WINDOWS
)

REM Check FullOS
if exist "C:\Windows\System32\winload.exe" (
    set "ENV_TYPE=FullOS"
    set "WINDOWS_DRIVE=C:"
    echo   Environment: Full Windows OS detected
    echo   Windows drive: C:
    goto :CHECK_ADMIN
)

:FIND_WINDOWS
echo   Searching for Windows installation...
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\Windows\System32\winload.exe" (
        set "WINDOWS_DRIVE=%%D:"
        echo   Found Windows on drive %%D:
        goto :CHECK_ADMIN
    )
)

echo   ERROR: Could not find Windows installation!
goto :END_ERROR

:CHECK_ADMIN
echo.
echo [STEP 2] Checking administrator privileges...
net session >nul 2>&1
if errorlevel 1 (
    echo   ERROR: Not running as administrator!
    echo   Please run this script as administrator.
    goto :END_ERROR
)
echo   Administrator privileges: OK
echo.

REM ============================================================================
REM STEP 3: Diagnose Boot Issues
REM ============================================================================
echo [STEP 3] Diagnosing boot issues...
echo.

set "BCD_BROKEN=0"
set "WINLOAD_MISSING=0"
set "BOOTFILES_MISSING=0"
set "EFI_MISSING=0"
set "BOOTMGR_MISSING=0"

REM Check winload.efi
set "WINLOAD_PATH=%WINDOWS_DRIVE%\Windows\System32\boot\winload.efi"
set "WINLOAD_PATH_ALT=%WINDOWS_DRIVE%\Windows\System32\winload.efi"
if exist "%WINLOAD_PATH%" (
    echo   [OK] winload.efi found at: %WINLOAD_PATH%
) else if exist "%WINLOAD_PATH_ALT%" (
    echo   [OK] winload.efi found at: %WINLOAD_PATH_ALT%
) else (
    echo   [FAIL] winload.efi MISSING
    set "WINLOAD_MISSING=1"
    set "ISSUES_FOUND=!ISSUES_FOUND!winload.efi missing; "
)

REM Check BCD
echo   Checking BCD configuration...
bcdedit /enum {default} >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] BCD entry missing or invalid
    set "BCD_BROKEN=1"
    set "ISSUES_FOUND=!ISSUES_FOUND!BCD broken; "
) else (
    echo   [OK] BCD entry exists
    REM Check if BCD references winload
    bcdedit /enum {default} | findstr /i "winload" >nul 2>&1
    if errorlevel 1 (
        echo   [WARN] BCD does not reference winload.efi
        set "BCD_BROKEN=1"
        set "ISSUES_FOUND=!ISSUES_FOUND!BCD path mismatch; "
    ) else (
        echo   [OK] BCD references winload.efi
    )
)

REM Check bootmgr.efi
set "BOOTMGR_PATH=%WINDOWS_DRIVE%\Windows\System32\boot\bootmgr.efi"
set "BOOTMGR_PATH2=%WINDOWS_DRIVE%\Windows\Boot\EFI\bootmgfw.efi"
if exist "%BOOTMGR_PATH%" (
    echo   [OK] bootmgr.efi found
) else if exist "%BOOTMGR_PATH2%" (
    echo   [OK] bootmgfw.efi found
) else (
    echo   [FAIL] Boot manager files MISSING
    set "BOOTFILES_MISSING=1"
    set "ISSUES_FOUND=!ISSUES_FOUND!boot manager missing; "
)

REM Check EFI partition
echo   Checking EFI partition...
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\EFI\Microsoft\Boot\bootmgfw.efi" (
        set "EFI_DRIVE=%%D:"
        echo   [OK] EFI partition found on drive %%D:
        goto :EFI_FOUND
    )
)
echo   [WARN] EFI partition not found (may be normal for BIOS systems)
set "EFI_MISSING=1"

:EFI_FOUND
echo.

REM Summary of issues
if "%WINLOAD_MISSING%"=="1" (
    echo   ISSUE DETECTED: winload.efi is missing
)
if "%BCD_BROKEN%"=="1" (
    echo   ISSUE DETECTED: BCD is broken or misconfigured
)
if "%BOOTFILES_MISSING%"=="1" (
    echo   ISSUE DETECTED: Boot manager files are missing
)
if "%EFI_MISSING%"=="1" (
    echo   ISSUE DETECTED: EFI partition not found
)

if "%WINLOAD_MISSING%%BCD_BROKEN%%BOOTFILES_MISSING%%EFI_MISSING%"=="0000" (
    echo   [OK] No critical boot issues detected!
    echo   System appears to be bootable.
    goto :VALIDATION_PASSED
)

echo.
echo ================================================================================
echo   CUSTOM REPAIR BASED ON DETECTED ISSUES
echo ================================================================================
echo.

REM ============================================================================
REM STEP 4: Custom Repair Based on Issues
REM ============================================================================
echo [STEP 4] Running custom repair based on detected issues...
echo.

REM If winload.efi is missing, try to find and copy it
if "%WINLOAD_MISSING%"=="1" (
    echo   Attempting to fix missing winload.efi...
    echo   Searching for winload.efi on other drives...
    
    set "WINLOAD_SOURCE="
    for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        if not "%%D:"=="%WINDOWS_DRIVE%" (
            if exist "%%D:\Windows\System32\boot\winload.efi" (
                set "WINLOAD_SOURCE=%%D:\Windows\System32\boot\winload.efi"
                echo     Found winload.efi on drive %%D:
                goto :COPY_WINLOAD
            )
            if exist "%%D:\Windows\System32\winload.efi" (
                set "WINLOAD_SOURCE=%%D:\Windows\System32\winload.efi"
                echo     Found winload.efi on drive %%D:
                goto :COPY_WINLOAD
            )
        )
    )
    
    :COPY_WINLOAD
    if defined WINLOAD_SOURCE (
        echo   Copying winload.efi from %WINLOAD_SOURCE%...
        if not exist "%WINDOWS_DRIVE%\Windows\System32\boot" mkdir "%WINDOWS_DRIVE%\Windows\System32\boot"
        copy /Y "%WINLOAD_SOURCE%" "%WINDOWS_DRIVE%\Windows\System32\boot\winload.efi" >nul 2>&1
        if errorlevel 1 (
            echo     [FAIL] Copy failed
        ) else (
            echo     [OK] winload.efi copied successfully
            set "FIXES_APPLIED=!FIXES_APPLIED!winload.efi restored; "
            set "WINLOAD_MISSING=0"
        )
    ) else (
        echo   [WARN] Could not find winload.efi source - will try emergency repairs
    )
)

REM If BCD is broken, try to rebuild it
if "%BCD_BROKEN%"=="1" (
    echo   Attempting to fix BCD...
    
    REM Try bcdboot to rebuild BCD
    echo   Running bcdboot to rebuild BCD...
    bcdboot %WINDOWS_DRIVE%\Windows >nul 2>&1
    if errorlevel 1 (
        echo     [WARN] bcdboot failed - will try emergency repairs
    ) else (
        echo     [OK] BCD rebuilt successfully
        set "FIXES_APPLIED=!FIXES_APPLIED!BCD rebuilt; "
        set "BCD_BROKEN=0"
    )
)

REM Validate after custom repair
call :VALIDATE_BOOT
if "%BOOT_READY%"=="1" (
    echo.
    echo ================================================================================
    echo   SUCCESS: Boot restored by custom repair!
    echo ================================================================================
    echo.
    echo Issues Found: %ISSUES_FOUND%
    echo Fixes Applied: %FIXES_APPLIED%
    echo.
    goto :END_SUCCESS
)

echo.
echo Custom repair did not fully restore boot. Continuing with emergency repairs...
echo.

REM ============================================================================
REM STEP 5: Run Emergency Repairs Sequentially
REM ============================================================================
echo ================================================================================
echo   EMERGENCY REPAIR SEQUENCE
echo ================================================================================
echo.

set "EMERGENCY_REPAIRS=V4 V1 V2 V3"
set "REPAIR_COUNT=0"

for %%R in (%EMERGENCY_REPAIRS%) do (
    set /a REPAIR_COUNT+=1
    
    if "%%R"=="V4" (
        set "REPAIR_FILE=EMERGENCY_BOOT_REPAIR_V4.cmd"
        set "REPAIR_NAME=Emergency Boot Repair V4 (Intelligent Minimal Repair)"
    ) else if "%%R"=="V1" (
        set "REPAIR_FILE=EMERGENCY_BOOT_REPAIR.cmd"
        set "REPAIR_NAME=Emergency Boot Repair V1 (Standard Repair)"
    ) else if "%%R"=="V2" (
        set "REPAIR_FILE=EMERGENCY_BOOT_REPAIR_V2.cmd"
        set "REPAIR_NAME=Emergency Boot Repair V2 (Alternative Implementation)"
    ) else if "%%R"=="V3" (
        set "REPAIR_FILE=EMERGENCY_BOOT_REPAIR_V3.cmd"
        set "REPAIR_NAME=Emergency Boot Repair V3 (Minimal Last Resort)"
    )
    
    set "REPAIR_PATH=%SCRIPT_DIR%!REPAIR_FILE!"
    
    if not exist "!REPAIR_PATH!" (
        echo   [SKIP] !REPAIR_NAME! - File not found: !REPAIR_FILE!
        continue
    )
    
    echo.
    echo [REPAIR !REPAIR_COUNT!/4] Running !REPAIR_NAME!...
    echo   File: !REPAIR_FILE!
    echo.
    
    call "!REPAIR_PATH!"
    set "REPAIR_EXIT=!ERRORLEVEL!"
    set /a REPAIR_ATTEMPTED+=1
    
    if "!REPAIR_EXIT!"=="0" (
        echo   [OK] !REPAIR_NAME! completed successfully
    ) else (
        echo   [WARN] !REPAIR_NAME! completed with exit code !REPAIR_EXIT!
    )
    
    echo.
    echo   Validating boot readiness after !REPAIR_NAME!...
    call :VALIDATE_BOOT
    
    if "%BOOT_READY%"=="1" (
        echo.
        echo ================================================================================
        echo   SUCCESS: Boot restored by !REPAIR_NAME!
        echo ================================================================================
        echo.
        echo Issues Found: %ISSUES_FOUND%
        echo Emergency Repair That Fixed It: !REPAIR_NAME!
        echo.
        set "REPAIR_SUCCESS=1"
        goto :END_SUCCESS
    ) else (
        echo   [INFO] Boot not ready yet. Continuing to next repair...
        echo.
    )
)

REM ============================================================================
REM FINAL VALIDATION
REM ============================================================================
echo.
echo ================================================================================
echo   FINAL VALIDATION
echo ================================================================================
echo.

call :VALIDATE_BOOT

if "%BOOT_READY%"=="1" (
    echo   [SUCCESS] Boot readiness restored!
    set "REPAIR_SUCCESS=1"
    goto :END_SUCCESS
) else (
    echo   [FAIL] Boot readiness not restored after all repairs
    goto :END_FAILED
)

REM ============================================================================
REM VALIDATION FUNCTION
REM ============================================================================
:VALIDATE_BOOT
set "BOOT_READY=0"

REM Check winload.efi
set "WINLOAD_PATH=%WINDOWS_DRIVE%\Windows\System32\boot\winload.efi"
set "WINLOAD_PATH_ALT=%WINDOWS_DRIVE%\Windows\System32\winload.efi"
if exist "%WINLOAD_PATH%" (
    set "WINLOAD_OK=1"
) else if exist "%WINLOAD_PATH_ALT%" (
    set "WINLOAD_OK=1"
) else (
    set "WINLOAD_OK=0"
    echo     [FAIL] winload.efi still missing
    goto :VALIDATION_DONE
)

REM Check BCD
bcdedit /enum {default} >nul 2>&1
if errorlevel 1 (
    echo     [FAIL] BCD entry still invalid
    goto :VALIDATION_DONE
)

bcdedit /enum {default} | findstr /i "winload" >nul 2>&1
if errorlevel 1 (
    echo     [FAIL] BCD does not reference winload.efi
    goto :VALIDATION_DONE
)

REM Check boot files
set "BOOTMGR_PATH=%WINDOWS_DRIVE%\Windows\System32\boot\bootmgr.efi"
set "BOOTMGR_PATH2=%WINDOWS_DRIVE%\Windows\Boot\EFI\bootmgfw.efi"
if exist "%BOOTMGR_PATH%" (
    set "BOOTFILES_OK=1"
) else if exist "%BOOTMGR_PATH2%" (
    set "BOOTFILES_OK=1"
) else (
    echo     [FAIL] Boot manager files still missing
    goto :VALIDATION_DONE
)

REM All checks passed
set "BOOT_READY=1"
echo     [OK] All boot components validated successfully

:VALIDATION_DONE
goto :eof

REM ============================================================================
REM END ROUTINES
REM ============================================================================
:END_SUCCESS
echo.
echo ================================================================================
echo   REPAIR SUMMARY
echo ================================================================================
echo.
echo Status: SUCCESS
echo Issues Found: %ISSUES_FOUND%
if defined FIXES_APPLIED (
    echo Fixes Applied: %FIXES_APPLIED%
)
echo Repairs Attempted: %REPAIR_ATTEMPTED%
echo.
echo System should now be bootable!
echo.
pause
exit /b 0

:END_FAILED
echo.
echo ================================================================================
echo   REPAIR SUMMARY
echo ================================================================================
echo.
echo Status: FAILED
echo Issues Found: %ISSUES_FOUND%
echo Repairs Attempted: %REPAIR_ATTEMPTED%
echo.
echo Boot could not be restored after all repair attempts.
echo Please check the detailed output above for specific issues.
echo.
pause
exit /b 1

:END_ERROR
echo.
echo Repair aborted due to error.
pause
exit /b 1

:CANCELED
echo.
echo Repair canceled by user.
pause
exit /b 2
