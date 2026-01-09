@echo off
REM Fetch portable PowerShell 7 (pwsh.exe) for Shift+F10 / WinRE use.
REM Run this when internet is available (e.g., Full Windows or WinRE with network).

setlocal

REM Target version (adjust if needed)
set "PWSH_VERSION=7.4.1"
set "PWSH_ZIP=powershell-%PWSH_VERSION%-win-x64.zip"
set "PWSH_URL=https://github.com/PowerShell/PowerShell/releases/download/v%PWSH_VERSION%/%PWSH_ZIP%"

REM Download destinations
set "OUT_DIR=%~dp0PowerShell"
set "OUT_ZIP=%OUT_DIR%\%PWSH_ZIP%"

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

echo.
echo Downloading %PWSH_URL%
echo Target: %OUT_ZIP%
echo.

REM Try curl (Win10+), then bitsadmin (legacy), then PowerShell, then certutil
where curl >nul 2>&1
if %errorlevel%==0 (
    curl -L "%PWSH_URL%" -o "%OUT_ZIP%"
    if %errorlevel%==0 goto :UNZIP
)

where bitsadmin >nul 2>&1
if %errorlevel%==0 (
    bitsadmin /transfer pwshdl /download /priority normal "%PWSH_URL%" "%OUT_ZIP%"
    if %errorlevel%==0 goto :UNZIP
)

where powershell >nul 2>&1
if %errorlevel%==0 (
    powershell -Command "Invoke-WebRequest -Uri '%PWSH_URL%' -OutFile '%OUT_ZIP%'" 
    if %errorlevel%==0 goto :UNZIP
)

where certutil >nul 2>&1
if %errorlevel%==0 (
    certutil -urlcache -split -f "%PWSH_URL%" "%OUT_ZIP%"
    if %errorlevel%==0 goto :UNZIP
)

echo ERROR: Failed to download PowerShell. Ensure internet is available and retry.
pause
exit /b 1

:UNZIP
echo.
echo Download complete. Extracting...

REM Try 7za.exe if present, else built-in tar
set "SEVENZIP=%~dp0tools\7za.exe"
if exist "%SEVENZIP%" (
    "%SEVENZIP%" x "%OUT_ZIP%" -o"%OUT_DIR%" -y
) else (
    tar -xf "%OUT_ZIP%" -C "%OUT_DIR%"
)
if errorlevel 1 (
    echo Extraction failed. Please unzip "%OUT_ZIP%" manually into "%OUT_DIR%".
    echo If WinRE lacks tar, place a tiny 7za.exe in %~dp0tools\ and re-run.
    pause
    exit /b 1
)

REM Move pwsh.exe up one level for SHIFT_F10.cmd to find it easily
if exist "%OUT_DIR%\pwsh.exe" del /f /q "%OUT_DIR%\pwsh.exe"
for %%F in ("%OUT_DIR%\\*\pwsh.exe") do copy /y "%%F" "%~dp0pwsh.exe" >nul

echo.
echo Portable PowerShell fetched. You can now run SHIFT_F10.cmd in WinRE/Shift+F10.
echo pwsh.exe placed in: %~dp0pwsh.exe
echo.
pause

endlocal

