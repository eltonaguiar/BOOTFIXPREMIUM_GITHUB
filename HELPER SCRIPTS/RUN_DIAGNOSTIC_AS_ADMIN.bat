@echo off
REM Batch file to run PowerShell diagnostic script with Admin elevation
REM This uses the UAC elevation trick

setlocal enabledelayedexpansion

cd /d "c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code"

REM Create a temporary VBScript to elevate privileges
set "vbsFile=%temp%\elevate.vbs"
(
    echo Set UAC = CreateObject^("Shell.Application"^)
    echo UAC.ShellExecute "powershell.exe", "-NoProfile -ExecutionPolicy Bypass -File ""TEST_LOAD_DIAGNOSTIC.ps1""", "", "runas", 1
) > "%vbsFile%"

REM Run the VBScript
cscript.exe "%vbsFile%"

REM Clean up
del /q "%vbsFile%"

pause
