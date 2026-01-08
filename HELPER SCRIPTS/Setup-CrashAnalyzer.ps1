<#
.SYNOPSIS
    Setup CrashAnalyzer Environment
    
    Copies CrashAnalyzer files from I:\Dart Crash analyzer\v10 to helper directory
    and creates launcher wrappers.

.DESCRIPTION
    Organizes CrashAnalyzer components:
    - HELPER SCRIPTS\CrashAnalyzer\crashanalyze.exe
    - HELPER SCRIPTS\CrashAnalyzer\Dependencies\*.dll
    - Creates launch wrapper and shortcuts

#>

param(
    [String]$SourcePath = "I:\Dart Crash analyzer\v10",
    [String]$DestinationPath = "$PSScriptRoot\..\CrashAnalyzer",
    [Switch]$Force
)

$ErrorActionPreference = "Continue"

function Setup-CrashAnalyzer {
    Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║    CrashAnalyzer Environment Setup         ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Check source
    if (-not (Test-Path $SourcePath)) {
        Write-Host "✗ Source path not found: $SourcePath" -ForegroundColor Red
        Write-Host "  Please ensure I:\Dart Crash analyzer\v10 is accessible" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "✓ Source path found: $SourcePath" -ForegroundColor Green
    
    # Create destination
    if (Test-Path $DestinationPath -and -not $Force) {
        Write-Host "⚠ Destination exists. Use -Force to overwrite" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "Creating destination: $DestinationPath"
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    
    # Copy executable
    $ExePath = Join-Path $SourcePath "crashanalyze.exe"
    if (Test-Path $ExePath) {
        Copy-Item $ExePath $DestinationPath -Force
        Write-Host "✓ Copied crashanalyze.exe" -ForegroundColor Green
    } else {
        Write-Host "✗ crashanalyze.exe not found" -ForegroundColor Red
        return $false
    }
    
    # Copy DLLs
    $DepsPath = Join-Path $DestinationPath "Dependencies"
    New-Item -ItemType Directory -Path $DepsPath -Force | Out-Null
    
    Get-ChildItem $SourcePath -Filter "*.dll" | ForEach-Object {
        Copy-Item $_.FullName $DepsPath -Force
    }
    
    $DLLCount = (Get-ChildItem $DepsPath -Filter "*.dll").Count
    Write-Host "✓ Copied $DLLCount DLL files" -ForegroundColor Green
    
    # Copy other support files
    Get-ChildItem $SourcePath -Filter "*.txt" -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName $DestinationPath -Force
    }
    
    # Create launcher wrapper
    Create-LauncherScript $DestinationPath
    
    Write-Host "`n✓ CrashAnalyzer setup complete!" -ForegroundColor Green
    Write-Host "  Location: $DestinationPath" -ForegroundColor Cyan
    
    return $true
}

function Create-LauncherScript {
    param([String]$DestPath)
    
    $LauncherScript = @"
@echo off
REM CrashAnalyzer Launcher
REM Ensures DLL dependencies are in path

set ORIGINAL_PATH=%PATH%
set PATH=$DestPath\Dependencies;%PATH%

"$DestPath\crashanalyze.exe" %*

set PATH=%ORIGINAL_PATH%
"@
    
    $LauncherPath = Join-Path $DestPath "CrashAnalyzer-Launcher.cmd"
    $LauncherScript | Out-File $LauncherPath -Encoding ASCII -Force
    
    Write-Host "✓ Created launcher: CrashAnalyzer-Launcher.cmd" -ForegroundColor Green
}

# Main
Setup-CrashAnalyzer
