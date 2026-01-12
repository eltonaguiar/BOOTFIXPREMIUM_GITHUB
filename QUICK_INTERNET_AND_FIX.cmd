@echo off
REM ============================================================================
REM QUICK INTERNET + EMERGENCY FIX FROM GITHUB
REM ============================================================================
REM Complete command sequence to:
REM   1. Enable internet in Windows RE (Shift+F10)
REM   2. Download and run Emergency Boot Repair from GitHub
REM ============================================================================
REM
REM USAGE: Copy and paste this entire file into Shift+F10 CMD window
REM        OR save as .cmd and run it
REM ============================================================================

echo.
echo ================================================================================
echo   QUICK INTERNET + EMERGENCY FIX FROM GITHUB
echo ================================================================================
echo.
echo This script will:
echo   1. Enable internet connection in Windows RE
echo   2. Download Emergency Boot Repair V4 from GitHub
echo   3. Run the emergency fix automatically
echo.
echo Press Ctrl+C within 5 seconds to cancel...
echo.
timeout /t 5 /nobreak >nul 2>&1
if errorlevel 1 goto :CANCELED

echo.
echo ================================================================================
echo STEP 1: ENABLING INTERNET CONNECTION
echo ================================================================================
echo.

REM Step 1.1: Initialize WinPE network stack
echo [1.1] Initializing WinPE network stack (wpeinit)...
wpeinit >nul 2>&1
if errorlevel 1 (
    echo   WARNING: wpeinit failed or not available (may be normal in some environments)
) else (
    echo   Network stack initialized
)

REM Step 1.2: Show current network interfaces
echo.
echo [1.2] Current network interfaces:
netsh interface show interface
echo.

REM Step 1.3: Enable network adapters (try common names)
echo [1.3] Enabling network adapters...
for %%N in ("Ethernet" "Local Area Connection" "Wi-Fi" "Wireless Network Connection") do (
    netsh interface set interface name=%%~N admin=enable >nul 2>&1
    if not errorlevel 1 (
        echo   Enabled: %%~N
    )
)

REM Step 1.4: Configure DHCP for common interface names
echo.
echo [1.4] Configuring DHCP...
for %%N in ("Ethernet" "Local Area Connection") do (
    netsh interface ip set address name=%%~N source=dhcp >nul 2>&1
    netsh interface ip set dns name=%%~N source=dhcp >nul 2>&1
    if not errorlevel 1 (
        echo   Configured: %%~N
    )
)

REM Step 1.5: Set static DNS (8.8.8.8) as backup
echo.
echo [1.5] Setting DNS to 8.8.8.8 (if DHCP fails)...
for %%N in ("Ethernet" "Local Area Connection") do (
    netsh interface ip set dns name=%%~N static 8.8.8.8 >nul 2>&1
    if not errorlevel 1 (
        echo   DNS set for: %%~N
    )
)

REM Step 1.6: Renew IP configuration
echo.
echo [1.6] Renewing IP configuration...
ipconfig /renew >nul 2>&1
echo   IP configuration renewed

REM Step 1.7: Test connectivity
echo.
echo [1.7] Testing connectivity...
echo   Testing: ping 1.1.1.1 (Cloudflare DNS)
ping -n 2 1.1.1.1 >nul 2>&1
if errorlevel 1 (
    echo   WARNING: Cannot reach 1.1.1.1 - network may not be working
    echo   You may need to load network drivers manually
    goto :NETWORK_FAILED
) else (
    echo   SUCCESS: Network connectivity confirmed
)

echo.
echo   Testing: ping github.com
ping -n 2 github.com >nul 2>&1
if errorlevel 1 (
    echo   WARNING: Cannot reach github.com - DNS may not be working
    echo   Will try to download anyway...
) else (
    echo   SUCCESS: GitHub is reachable
)

echo.
echo ================================================================================
echo STEP 2: DOWNLOADING EMERGENCY BOOT REPAIR FROM GITHUB
echo ================================================================================
echo.

set "GITHUB_URL=https://raw.githubusercontent.com/eltonaguiar/BOOTFIXPREMIUM_GITHUB/main/EMERGENCY_BOOT_REPAIR_V4.cmd"
set "DOWNLOAD_FILE=%TEMP%\EMERGENCY_BOOT_REPAIR_V4.cmd"

REM Try curl first (Windows 10+)
echo [2.1] Attempting download with curl...
curl -L -o "%DOWNLOAD_FILE%" "%GITHUB_URL%" 2>nul
if not errorlevel 1 (
    echo   SUCCESS: Downloaded with curl
    goto :DOWNLOAD_SUCCESS
)

REM Try PowerShell Invoke-WebRequest as fallback
echo.
echo [2.2] Attempting download with PowerShell...
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%GITHUB_URL%' -OutFile '%DOWNLOAD_FILE%' -UseBasicParsing -ErrorAction Stop; exit 0 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 (
    echo   SUCCESS: Downloaded with PowerShell
    goto :DOWNLOAD_SUCCESS
)

REM Try bitsadmin as last resort (legacy Windows)
echo.
echo [2.3] Attempting download with bitsadmin (legacy method)...
bitsadmin /transfer "MiracleBootDownload" /download /priority high "%GITHUB_URL%" "%DOWNLOAD_FILE%" >nul 2>&1
if exist "%DOWNLOAD_FILE%" (
    echo   SUCCESS: Downloaded with bitsadmin
    goto :DOWNLOAD_SUCCESS
)

REM All download methods failed
echo.
echo   ERROR: All download methods failed!
echo   Possible reasons:
echo     - No internet connection
echo     - Firewall blocking access
echo     - GitHub is unreachable
echo.
echo   You can manually download from:
echo     https://github.com/eltonaguiar/BOOTFIXPREMIUM_GITHUB/blob/main/EMERGENCY_BOOT_REPAIR_V4.cmd
echo.
goto :END

:DOWNLOAD_SUCCESS
if not exist "%DOWNLOAD_FILE%" (
    echo   ERROR: Download file not found at: %DOWNLOAD_FILE%
    goto :END
)

echo.
echo   File downloaded to: %DOWNLOAD_FILE%
echo   File size: 
for %%A in ("%DOWNLOAD_FILE%") do echo     %%~zA bytes

echo.
echo ================================================================================
echo STEP 3: RUNNING EMERGENCY BOOT REPAIR
echo ================================================================================
echo.

echo [3.1] Executing Emergency Boot Repair V4...
echo.
call "%DOWNLOAD_FILE%"

set "EXIT_CODE=%ERRORLEVEL%"
echo.
echo ================================================================================
echo COMPLETE
echo ================================================================================
echo.
if %EXIT_CODE% equ 0 (
    echo Emergency Boot Repair completed successfully!
) else (
    echo Emergency Boot Repair exited with code: %EXIT_CODE%
    echo Check the output above for details.
)
echo.
goto :END

:NETWORK_FAILED
echo.
echo ================================================================================
echo NETWORK SETUP FAILED
echo ================================================================================
echo.
echo Network could not be enabled. Possible solutions:
echo.
echo 1. Load network driver manually:
echo    drvload X:\path\to\network_driver.inf
echo    wpeinit
echo    ipconfig /renew
echo.
echo 2. Use USB drive instead:
echo    - Download Emergency Boot Repair to USB on another computer
echo    - Insert USB in this computer
echo    - Run: D:\EMERGENCY_BOOT_REPAIR_V4.cmd (replace D: with your USB drive)
echo.
echo 3. Try alternative network initialization:
echo    wpeutil InitializeNetwork
echo    netsh interface show interface
echo    netsh interface set interface "Ethernet" admin=enable
echo.
goto :END

:CANCELED
echo.
echo Operation canceled by user.
goto :END

:END
echo.
echo Press any key to exit...
pause >nul 2>&1
exit /b %EXIT_CODE%
