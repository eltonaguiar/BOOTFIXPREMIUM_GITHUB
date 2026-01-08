
# DIRECT GUI TEST - Call Start-GUI directly in current session to see ALL errors immediately
# This is the most reliable way to capture actual GUI errors

$rootPath = Split-Path -Parent -Path $PSScriptRoot
$coreFile = Join-Path $rootPath "HELPER SCRIPTS\WinRepairCore.ps1"
$guiFile = Join-Path $rootPath "HELPER SCRIPTS\WinRepairGUI.ps1"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "DIRECT GUI INVOCATION TEST" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Clear error collection first
$global:Error.Clear()

# Load required assemblies
Write-Host "[LOAD] Loading PresentationFramework..." -NoNewline
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Write-Host " [OK]" -ForegroundColor Green
} catch {
    Write-Host " [FAIL]" -ForegroundColor Red
    Write-Host "[ERROR] $_" -ForegroundColor Red
    exit 1
}

Write-Host "[LOAD] Loading System.Windows.Forms..." -NoNewline
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Write-Host " [OK]" -ForegroundColor Green
} catch {
    Write-Host " [FAIL]" -ForegroundColor Red
    Write-Host "[ERROR] $_" -ForegroundColor Red
    exit 1
}

# Source the files
Write-Host "[LOAD] Loading $coreFile..." -NoNewline
try {
    . $coreFile -ErrorAction Stop
    Write-Host " [OK]" -ForegroundColor Green
} catch {
    Write-Host " [FAIL]" -ForegroundColor Red
    Write-Host "[ERROR] $_" -ForegroundColor Red
    exit 1
}

Write-Host "[LOAD] Loading $guiFile..." -NoNewline
try {
    . $guiFile -ErrorAction Stop
    Write-Host " [OK]" -ForegroundColor Green
} catch {
    Write-Host " [FAIL]" -ForegroundColor Red
    Write-Host "[ERROR] $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "INVOKING Start-GUI FUNCTION" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Capture error state before
$errorsBefore = $global:Error.Count
Write-Host "[INFO] Errors before Start-GUI call: $errorsBefore" -ForegroundColor Yellow

# Call Start-GUI and capture any errors
Write-Host "[INVOKE] Calling Start-GUI..." -ForegroundColor Yellow

try {
    Start-GUI
    $result = "Start-GUI completed"
} catch {
    $result = "Start-GUI threw exception"
    Write-Host "[EXCEPTION] During Start-GUI call:" -ForegroundColor Red
    Write-Host "  Exception: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  InvocationInfo: $($_.InvocationInfo)" -ForegroundColor Red
    Write-Host "  ScriptStackTrace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host ""
Write-Host "[INFO] Start-GUI execution completed" -ForegroundColor Yellow

# Check errors that occurred
$errorsAfter = $global:Error.Count
$newErrors = $errorsAfter - $errorsBefore

Write-Host "[INFO] Errors after Start-GUI call: $errorsAfter" -ForegroundColor Yellow
Write-Host "[INFO] New errors added: $newErrors" -ForegroundColor Yellow

if ($newErrors -gt 0) {
    Write-Host ""
    Write-Host "================================" -ForegroundColor Red
    Write-Host "ERRORS DETECTED DURING GUI INIT" -ForegroundColor Red
    Write-Host "================================" -ForegroundColor Red
    Write-Host ""
    
    $global:Error | Select-Object -First $newErrors | ForEach-Object {
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Category: $($_.CategoryInfo.Category)" -ForegroundColor DarkRed
        Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor DarkRed
    }
    
    Write-Host ""
    Write-Host "[RESULT] TEST FAILED - $newErrors error(s) found" -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "================================" -ForegroundColor Green
    Write-Host "TEST PASSED - NO ERRORS" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
    exit 0
}
