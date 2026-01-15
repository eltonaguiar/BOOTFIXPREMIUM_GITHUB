@echo off
REM MiracleBoot Launcher with Admin Elevation
REM This script properly elevates MiracleBoot.ps1 with administrative privileges

setlocal enabledelayedexpansion

REM Get the script directory
set "scriptDir=%~dp0"

REM Create a temporary PowerShell script that will be elevated
set "tempScript=%temp%\miracleboot_launcher_%random%.ps1"

(
    echo # MiracleBoot Auto-Launcher
    echo cd "%scriptDir%"
    echo powershell -NoProfile -ExecutionPolicy Bypass -File "MiracleBoot.ps1" 2^>^&1 ^| Tee-Object -FilePath "MIRACLEBOOT_RUN_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    echo pause
) > "%tempScript%"

REM Use PowerShell to elevate the script
powershell -NoProfile -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%tempScript%\"' -Verb RunAs"

REM Clean up temp file after a delay
timeout /t 2 /nobreak
del /q "%tempScript%" 2>nul

exit /b 0
