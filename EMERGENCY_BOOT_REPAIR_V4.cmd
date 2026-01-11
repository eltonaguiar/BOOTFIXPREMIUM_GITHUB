@echo off
REM ============================================================================
REM EMERGENCY BOOT REPAIR V4 - Intelligent Minimal Repair
REM ============================================================================
REM This version intelligently diagnoses issues and only runs necessary repairs.
REM Features:
REM   - Progress percentage display (0-100%)
REM   - Shows exact commands being executed
REM   - Skips unnecessary commands based on diagnostics
REM   - Only fixes what's actually broken
REM ============================================================================

setlocal enabledelayedexpansion
set "TOTAL_STEPS=0"
set "CURRENT_STEP=0"
set "WINDOWS_DRIVE="
set "EFI_DRIVE="
set "BCD_BROKEN=0"
set "WINLOAD_MISSING=0"
set "BOOTFILES_MISSING=0"
set "EFI_MISSING=0"
set "FIXES_APPLIED=0"
set "FIXES_FAILED=0"

echo.
echo ================================================================================
echo   EMERGENCY BOOT REPAIR V4 - Intelligent Minimal Repair
echo ================================================================================
echo.
echo This version only fixes what's actually broken.
echo Shows progress and exact commands being executed.
echo.
echo WARNING: This will modify your boot configuration.
echo Press Ctrl+C within 5 seconds to cancel...
echo.
timeout /t 5 /nobreak >nul 2>&1
if errorlevel 1 goto :CANCELED

echo.
echo Starting intelligent emergency boot repair V4...
echo.

REM ============================================================================
REM STEP 1: Environment Detection (10% progress)
REM ============================================================================
set "CURRENT_STEP=1"
set "TOTAL_STEPS=10"
call :SHOW_PROGRESS 10 "Detecting environment..."

echo [STEP 1/10] Detecting environment...
set "ENV_TYPE=Unknown"

REM Check WinPE/WinRE
if exist "X:\Windows\System32\winload.exe" (
    set "ENV_TYPE=WinPE"
    set "SYSTEM_DRIVE=X:"
    echo   Environment: WinPE/WinRE detected
    goto :FIND_WINDOWS
)

REM Check FullOS
if exist "C:\Windows\System32\winload.exe" (
    set "ENV_TYPE=FullOS"
    set "SYSTEM_DRIVE=C:"
    set "WINDOWS_DRIVE=C:"
    echo   Environment: Full Windows OS detected
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
set /a FIXES_FAILED+=1
goto :SUMMARY

:CHECK_ADMIN
echo   Windows drive: %WINDOWS_DRIVE%
echo.

REM ============================================================================
REM STEP 2: Check Administrator Privileges (20% progress)
REM ============================================================================
set "CURRENT_STEP=2"
call :SHOW_PROGRESS 20 "Checking administrator privileges..."

echo [STEP 2/10] Checking privileges...
net session >nul 2>&1
if errorlevel 1 (
    echo   ERROR: Not running as administrator!
    set /a FIXES_FAILED+=1
    goto :SUMMARY
)
echo   Administrator privileges: OK
echo.

REM ============================================================================
REM STEP 3: Intelligent Diagnostics (30-60% progress)
REM ============================================================================
set "CURRENT_STEP=3"
call :SHOW_PROGRESS 30 "Running intelligent diagnostics..."

echo [STEP 3/10] Running intelligent diagnostics...
echo.

REM Check 3a: BCD Status
set "CURRENT_STEP=4"
call :SHOW_PROGRESS 35 "Checking BCD status..."

echo   [DIAGNOSTIC] Checking BCD (Boot Configuration Data)...
if "%ENV_TYPE%"=="WinPE" (
    if exist "%WINDOWS_DRIVE%\Boot\BCD" (
        bcdedit /store "%WINDOWS_DRIVE%\Boot\BCD" /enum {default} >nul 2>&1
        if errorlevel 1 (
            echo     BCD: BROKEN (exists but cannot be accessed)
            set "BCD_BROKEN=1"
        ) else (
            echo     BCD: OK
        )
    ) else (
        echo     BCD: MISSING
        set "BCD_BROKEN=1"
    )
) else (
    bcdedit /enum {default} >nul 2>&1
    if errorlevel 1 (
        echo     BCD: BROKEN (cannot be accessed)
        set "BCD_BROKEN=1"
    ) else (
        echo     BCD: OK
    )
)

REM Check 3b: winload.efi/winload.exe
set "CURRENT_STEP=5"
call :SHOW_PROGRESS 40 "Checking boot loader files..."

echo   [DIAGNOSTIC] Checking boot loader files...
if exist "%WINDOWS_DRIVE%\Windows\System32\boot\winload.efi" (
    echo     winload.efi: OK
) else (
    echo     winload.efi: MISSING
    set "WINLOAD_MISSING=1"
)

if exist "%WINDOWS_DRIVE%\Windows\System32\winload.exe" (
    echo     winload.exe: OK
) else (
    echo     winload.exe: MISSING
    set "WINLOAD_MISSING=1"
)

REM Check 3c: EFI Partition
set "CURRENT_STEP=6"
call :SHOW_PROGRESS 45 "Checking EFI partition..."

echo   [DIAGNOSTIC] Checking EFI partition...
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\EFI\Microsoft\Boot\bootmgfw.efi" (
        set "EFI_DRIVE=%%D:"
        echo     EFI partition: Found on %%D:
        goto :CHECK_BOOTFILES
    )
)
echo     EFI partition: Not found (may be normal for BIOS systems)
set "EFI_MISSING=1"

:CHECK_BOOTFILES
REM Check 3d: Boot files
set "CURRENT_STEP=7"
call :SHOW_PROGRESS 50 "Checking boot files..."

echo   [DIAGNOSTIC] Checking boot files...
if not "%EFI_DRIVE%"=="" (
    if exist "%EFI_DRIVE%\EFI\Microsoft\Boot\bootmgfw.efi" (
        echo     bootmgfw.efi: OK
    ) else (
        echo     bootmgfw.efi: MISSING
        set "BOOTFILES_MISSING=1"
    )
    
    if exist "%EFI_DRIVE%\EFI\Microsoft\Boot\BCD" (
        echo     BCD on EFI: OK
    ) else (
        echo     BCD on EFI: MISSING
        if "%BCD_BROKEN%"=="0" set "BCD_BROKEN=1"
    )
) else (
    if exist "%WINDOWS_DRIVE%\Boot\BCD" (
        echo     BCD on Windows drive: OK
    ) else (
        echo     BCD on Windows drive: MISSING
        if "%BCD_BROKEN%"=="0" set "BCD_BROKEN=1"
    )
)

REM Check 3e: Driver issues (storage drivers that prevent boot)
set "CURRENT_STEP=8"
call :SHOW_PROGRESS 55 "Checking for driver issues..."

echo   [DIAGNOSTIC] Checking for driver issues that prevent boot...
set "DRIVER_ISSUE=0"
set "STORAGE_DRIVER_MISSING=0"

REM Check for common storage driver files
if exist "%WINDOWS_DRIVE%\Windows\System32\drivers\storahci.sys" (
    echo     storahci.sys (AHCI driver): OK
) else (
    echo     storahci.sys (AHCI driver): MISSING
    set "STORAGE_DRIVER_MISSING=1"
    set "DRIVER_ISSUE=1"
)

if exist "%WINDOWS_DRIVE%\Windows\System32\drivers\stornvme.sys" (
    echo     stornvme.sys (NVMe driver): OK
) else (
    echo     stornvme.sys (NVMe driver): MISSING (may be normal if not NVMe)
)

REM Check boot log for driver load failures (if available)
if exist "%WINDOWS_DRIVE%\Windows\ntbtlog.txt" (
    findstr /C:"Did not load driver" "%WINDOWS_DRIVE%\Windows\ntbtlog.txt" >nul 2>&1
    if errorlevel 1 (
        echo     Boot log: No driver load failures detected
    ) else (
        echo     Boot log: Driver load failures detected (check ntbtlog.txt)
        set "DRIVER_ISSUE=1"
    )
) else (
    echo     Boot log: Not available (enable boot logging to check)
)

echo.
echo   [DIAGNOSTIC SUMMARY]
echo     BCD broken: %BCD_BROKEN%
echo     winload missing: %WINLOAD_MISSING%
echo     Boot files missing: %BOOTFILES_MISSING%
echo     EFI missing: %EFI_MISSING%
echo     Driver issues: %DRIVER_ISSUE%
echo     Storage driver missing: %STORAGE_DRIVER_MISSING%
echo.

REM ============================================================================
REM STEP 4: Intelligent Repair (60-90% progress)
REM ============================================================================
set "CURRENT_STEP=8"
call :SHOW_PROGRESS 60 "Starting intelligent repairs..."

echo [STEP 4/10] Starting intelligent repairs...
echo   Only necessary repairs will be executed.
echo.

REM Repair 4a: BCD Issues (if BCD is broken, fix it - skip if OK)
if "%BCD_BROKEN%"=="1" (
    call :SHOW_PROGRESS 65 "Fixing BCD (Boot Configuration Data)..."
    echo   [REPAIR] BCD is broken - fixing...
    
    if not "%EFI_DRIVE%"=="" (
        echo     Command: bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_DRIVE% /f UEFI
        bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_DRIVE% /f UEFI
        if errorlevel 1 (
            echo     Result: FAILED
            set /a FIXES_FAILED+=1
        ) else (
            echo     Result: SUCCESS
            set /a FIXES_APPLIED+=1
            set "BCD_BROKEN=0"
        )
    ) else (
        echo     Command: bcdboot %WINDOWS_DRIVE%\Windows
        bcdboot %WINDOWS_DRIVE%\Windows
        if errorlevel 1 (
            echo     Result: FAILED
            set /a FIXES_FAILED+=1
        ) else (
            echo     Result: SUCCESS
            set /a FIXES_APPLIED+=1
            set "BCD_BROKEN=0"
        )
    )
    echo.
) else (
    echo   [SKIP] BCD is OK - skipping BCD repair
    echo.
)

REM Repair 4b: Boot Files (if missing, rebuild - skip if OK)
if "%BOOTFILES_MISSING%"=="1" (
    call :SHOW_PROGRESS 75 "Rebuilding boot files..."
    echo   [REPAIR] Boot files missing - rebuilding...
    
    if not "%EFI_DRIVE%"=="" (
        echo     Command: bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_DRIVE% /f ALL
        bcdboot %WINDOWS_DRIVE%\Windows /s %EFI_DRIVE% /f ALL
        if errorlevel 1 (
            echo     Result: FAILED
            set /a FIXES_FAILED+=1
        ) else (
            echo     Result: SUCCESS
            set /a FIXES_APPLIED+=1
            set "BOOTFILES_MISSING=0"
        )
    ) else (
        echo     Command: bcdboot %WINDOWS_DRIVE%\Windows /f ALL
        bcdboot %WINDOWS_DRIVE%\Windows /f ALL
        if errorlevel 1 (
            echo     Result: FAILED
            set /a FIXES_FAILED+=1
        ) else (
            echo     Result: SUCCESS
            set /a FIXES_APPLIED+=1
            set "BOOTFILES_MISSING=0"
        )
    )
    echo.
) else (
    echo   [SKIP] Boot files OK - skipping boot file rebuild
    echo.
)

REM Repair 4c: winload.efi (if missing, copy from backup - skip if OK)
if "%WINLOAD_MISSING%"=="1" (
    call :SHOW_PROGRESS 80 "Fixing winload.efi..."
    echo   [REPAIR] winload.efi missing - attempting to restore...
    
    REM Try to find winload.efi in common backup locations
    set "WINLOAD_FOUND=0"
    for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        if exist "%%D:\Windows\System32\boot\winload.efi" (
            if not "%%D:"=="%WINDOWS_DRIVE%" (
                echo     Command: copy "%%D:\Windows\System32\boot\winload.efi" "%WINDOWS_DRIVE%\Windows\System32\boot\winload.efi"
                copy "%%D:\Windows\System32\boot\winload.efi" "%WINDOWS_DRIVE%\Windows\System32\boot\winload.efi" >nul 2>&1
                if errorlevel 1 (
                    echo     Result: FAILED (could not copy from %%D:)
                ) else (
                    echo     Result: SUCCESS (copied from %%D:)
                    set /a FIXES_APPLIED+=1
                    set "WINLOAD_MISSING=0"
                    set "WINLOAD_FOUND=1"
                    goto :WINLOAD_FIXED
                )
            )
        )
    )
    
    :WINLOAD_FIXED
    if "%WINLOAD_FOUND%"=="0" (
        echo     Result: FAILED (no backup source found)
        set /a FIXES_FAILED+=1
    )
    echo.
) else (
    echo   [SKIP] winload.efi OK - skipping winload repair
    echo.
)

REM Repair 4d: Boot Sector (only if BCD was broken - skip if BCD was OK)
if "%BCD_BROKEN%"=="0" (
    REM BCD was already OK, but we may need to fix boot sector if other issues exist
    if "%BOOTFILES_MISSING%"=="1" (
        call :SHOW_PROGRESS 85 "Fixing boot sector..."
        echo   [REPAIR] Boot sector may need fixing...
        echo     Command: bootrec /fixboot
        bootrec /fixboot >nul 2>&1
        if errorlevel 1 (
            echo     Result: FAILED or not applicable
        ) else (
            echo     Result: SUCCESS
            set /a FIXES_APPLIED+=1
        )
        echo.
    ) else (
        echo   [SKIP] Boot sector OK - skipping boot sector repair
        echo.
    )
) else (
    REM BCD was broken, so boot sector likely needs fixing
    call :SHOW_PROGRESS 85 "Fixing boot sector..."
    echo   [REPAIR] BCD was broken - fixing boot sector...
    echo     Command: bootrec /fixboot
    bootrec /fixboot >nul 2>&1
    if errorlevel 1 (
        echo     Result: FAILED or not applicable
    ) else (
        echo     Result: SUCCESS
        set /a FIXES_APPLIED+=1
    )
    echo.
)

REM Repair 4e: Driver Issues (if detected, provide guidance)
if "%DRIVER_ISSUE%"=="1" (
    call :SHOW_PROGRESS 88 "Driver issues detected - providing guidance..."
    echo   [REPAIR] Driver issues detected - providing guidance...
    echo.
    echo     WARNING: Missing or failed storage drivers detected!
    echo     This may cause INACCESSIBLE_BOOT_DEVICE (0x7B) errors.
    echo.
    echo     RECOMMENDED ACTIONS:
    echo       1. Use MiracleBoot GUI → Driver Diagnostics tab
    echo       2. Click "Scan for Missing Drivers"
    echo       3. Click "Scan All Drivers" to find drivers on USB/other drives
    echo       4. Click "Install Drivers" to inject drivers using DISM
    echo.
    echo     OR use DISM command manually:
    echo       dism /Image:%WINDOWS_DRIVE%\ /Add-Driver /Driver:"<driver_path>" /Recurse
    echo.
    echo     After injecting drivers, run this emergency repair again.
    echo.
    set /a FIXES_FAILED+=1
) else (
    echo   [SKIP] No driver issues detected - skipping driver repair
    echo.
)

REM NOTE: We SKIP sfc /scannow and other time-consuming repairs
REM because they're not necessary if only BCD/boot files are broken
if "%DRIVER_ISSUE%"=="0" (
    echo   [SKIP] System File Checker (sfc /scannow) - SKIPPED
    echo     Reason: Only boot configuration issues detected. SFC is not necessary.
    echo.
)

REM ============================================================================
REM STEP 5: Final Verification (90-100% progress)
REM ============================================================================
set "CURRENT_STEP=9"
call :SHOW_PROGRESS 90 "Verifying repairs..."

echo [STEP 5/10] Verifying repairs...
echo.

REM Verify BCD
if "%BCD_BROKEN%"=="1" (
    call :SHOW_PROGRESS 92 "Verifying BCD..."
    echo   [VERIFY] Checking BCD...
    if "%ENV_TYPE%"=="WinPE" (
        bcdedit /store "%WINDOWS_DRIVE%\Boot\BCD" /enum {default} >nul 2>&1
    ) else (
        bcdedit /enum {default} >nul 2>&1
    )
    if errorlevel 1 (
        echo     BCD: STILL BROKEN
        set /a FIXES_FAILED+=1
    ) else (
        echo     BCD: FIXED
    )
) else (
    echo   [VERIFY] BCD was OK - no verification needed
)

REM Verify winload.efi
if "%WINLOAD_MISSING%"=="1" (
    call :SHOW_PROGRESS 95 "Verifying winload.efi..."
    echo   [VERIFY] Checking winload.efi...
    if exist "%WINDOWS_DRIVE%\Windows\System32\boot\winload.efi" (
        echo     winload.efi: FIXED
    ) else (
        echo     winload.efi: STILL MISSING
        set /a FIXES_FAILED+=1
    )
) else (
    echo   [VERIFY] winload.efi was OK - no verification needed
)

call :SHOW_PROGRESS 100 "Repair complete!"
echo.

REM ============================================================================
REM SUMMARY
REM ============================================================================
:SUMMARY
echo ================================================================================
echo   REPAIR SUMMARY (V4 - Intelligent Minimal Repair)
echo ================================================================================
echo   Issues fixed: %FIXES_APPLIED%
echo   Issues failed: %FIXES_FAILED%
echo.
echo   Diagnostic Results:
echo     BCD broken: %BCD_BROKEN%
echo     winload missing: %WINLOAD_MISSING%
echo     Boot files missing: %BOOTFILES_MISSING%
echo     EFI missing: %EFI_MISSING%
echo     Driver issues: %DRIVER_ISSUE%
echo     Storage driver missing: %STORAGE_DRIVER_MISSING%
echo.

if %FIXES_APPLIED% gtr 0 (
    echo   STATUS: Some issues were repaired
    echo   Please restart your computer to test the fixes.
) else (
    if %FIXES_FAILED% gtr 0 (
        echo   STATUS: Issues detected but could not be automatically repaired
        echo   Manual intervention may be required.
    ) else (
        echo   STATUS: No critical errors detected - system appears bootable
    )
)
echo.
echo ================================================================================
echo.
goto :END

:CANCELED
echo.
echo Operation canceled by user.
goto :END

:SHOW_PROGRESS
REM Function to show progress percentage
setlocal
set "PERCENT=%~1"
set "MESSAGE=%~2"
echo [%PERCENT%%%] %MESSAGE%
endlocal
goto :eof

:END
echo.
echo Emergency repair tool V4 finished.
echo.
pause
endlocal
exit /b %FIXES_FAILED%
