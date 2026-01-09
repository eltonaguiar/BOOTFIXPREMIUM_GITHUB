@echo off
REM Launch pre-staged portable PowerShell (pwsh) from USB in WinRE/Shift+F10

wpeinit >nul 2>&1

set "USB=%~dp0"
set "PWSH=%USB%pwsh\pwsh.exe"
if not exist "%PWSH%" set "PWSH=%USB%pwsh.exe"

if exist "%PWSH%" (
  echo Starting pwsh: %PWSH%
  "%PWSH%" -NoLogo
) else (
  echo pwsh not found at: %PWSH%
  echo Expecting pwsh.exe in:
  echo   %USB%pwsh.exe
  echo or
  echo   %USB%pwsh\pwsh.exe
  pause
)

