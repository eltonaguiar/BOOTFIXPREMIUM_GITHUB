# Debug ShowDialog issue
$ErrorActionPreference = "Continue"

Write-Host "=== DEBUG: ShowDialog Issue ===" -ForegroundColor Cyan
Write-Host ""

# Load modules
. ".\DefensiveBootCore.ps1"
. ".\WinRepairGUI.ps1"

Write-Host "Calling Start-GUI with detailed debugging..." -ForegroundColor Yellow
Write-Host ""

# Hook into ShowDialog to see what's happening
$originalShowDialog = [System.Windows.Window].GetMethod("ShowDialog", [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Instance)

# Create a wrapper to monitor ShowDialog calls
Add-Type @"
using System;
using System.Windows;
using System.Reflection;

public class WindowMonitor {
    public static void MonitorShowDialog(Window window) {
        var method = typeof(Window).GetMethod("ShowDialog", BindingFlags.Public | BindingFlags.Instance);
        Console.WriteLine("ShowDialog called on window: " + window.Title);
        Console.WriteLine("Window Visibility: " + window.Visibility);
        Console.WriteLine("Window IsLoaded: " + window.IsLoaded);
    }
}
"@ -ErrorAction SilentlyContinue

# Call Start-GUI and monitor
try {
    Write-Host "Before Start-GUI call..." -ForegroundColor Gray
    Start-GUI
    Write-Host "After Start-GUI call..." -ForegroundColor Gray
} catch {
    Write-Host "ERROR in Start-GUI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host ""
Write-Host "=== DEBUG COMPLETE ===" -ForegroundColor Cyan
