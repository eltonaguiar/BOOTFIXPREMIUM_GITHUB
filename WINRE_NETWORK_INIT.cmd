@echo off
REM Quick network bring-up for WinRE / Shift+F10

echo [1/4] Running wpeinit...
wpeinit >nul 2>&1

echo [2/4] Current interfaces:
netsh interface show interface
echo.

echo [3/4] Forcing DHCP on common interface names (adjust if needed)...
for %%N in ("Ethernet" "Local Area Connection") do (
    netsh interface ip set address name=%%~N source=dhcp >nul 2>&1
    netsh interface ip set dns     name=%%~N source=dhcp >nul 2>&1
)

echo Renewing IP...
ipconfig /renew
echo.

echo [4/4] IP configuration:
ipconfig /all
echo.

echo Connectivity checks:
echo   ping 1.1.1.1
ping 1.1.1.1
echo.
echo   ping github.com
ping github.com
echo.

echo If 1.1.1.1 works but github.com fails -> DNS issue.
echo If neither works, driver/link/DHCP is missing.
echo.
echo To load a driver (if you have the INF on USB):
echo   drvload X:\path\to\driver.inf
echo   wpeinit
echo   ipconfig
echo.
pause

