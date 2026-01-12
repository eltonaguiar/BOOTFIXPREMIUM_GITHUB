# GUI Debugging QA Panel
# This script helps diagnose GUI loading issues

$ErrorActionPreference = 'Stop'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GUI DEBUGGING QA PANEL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$issues = @()
$warnings = @()

# Test 1: Check PowerShell version
Write-Host "[1/10] Checking PowerShell version..." -ForegroundColor Yellow
try {
    $psVersion = $PSVersionTable.PSVersion
    Write-Host "  PowerShell Version: $psVersion" -ForegroundColor Green
    if ($psVersion.Major -lt 5) {
        $issues += "PowerShell version $psVersion is too old. Requires PowerShell 5.0 or higher."
    }
} catch {
    $issues += "Could not determine PowerShell version: $_"
}

# Test 2: Check STA mode
Write-Host "[2/10] Checking STA mode..." -ForegroundColor Yellow
try {
    $isSta = ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA)
    if ($isSta) {
        Write-Host "  STA Mode: OK" -ForegroundColor Green
    } else {
        $issues += "PowerShell is not running in STA mode. GUI requires STA mode. Run: powershell.exe -Sta"
    }
} catch {
    $warnings += "Could not check STA mode: $_"
}

# Test 3: Check WPF assemblies
Write-Host "[3/10] Checking WPF assemblies..." -ForegroundColor Yellow
$wpfAssemblies = @(
    "PresentationFramework",
    "PresentationCore",
    "WindowsBase"
)
foreach ($assembly in $wpfAssemblies) {
    try {
        Add-Type -AssemblyName $assembly -ErrorAction Stop
        Write-Host "  $assembly : OK" -ForegroundColor Green
    } catch {
        $issues += "Failed to load $assembly : $_"
    }
}

# Test 4: Check XAML file exists
Write-Host "[4/10] Checking XAML file..." -ForegroundColor Yellow
$xamlPath = "WinRepairGUI.xaml"
if (Test-Path $xamlPath) {
    Write-Host "  XAML file found: $xamlPath" -ForegroundColor Green
    $xamlSize = (Get-Item $xamlPath).Length
    Write-Host "  File size: $xamlSize bytes" -ForegroundColor Gray
} else {
    $issues += "XAML file not found: $xamlPath"
}

# Test 5: Validate XAML XML structure
Write-Host "[5/10] Validating XAML XML structure..." -ForegroundColor Yellow
if (Test-Path $xamlPath) {
    try {
        $xamlContent = Get-Content $xamlPath -Raw
        [xml]$xaml = $xamlContent
        Write-Host "  XAML XML structure: OK" -ForegroundColor Green
        
        # Check for duplicate TabItems
        $tabItems = $xaml.SelectNodes("//TabItem")
        $tabItemCount = $tabItems.Count
        Write-Host "  TabItems found: $tabItemCount" -ForegroundColor Gray
        
        # Check for duplicate names
        $allNames = @()
        foreach ($tabItem in $tabItems) {
            $header = $tabItem.Header
            if ($header) {
                if ($allNames -contains $header) {
                    $warnings += "Duplicate tab header found: $header"
                } else {
                    $allNames += $header
                }
            }
        }
        
    } catch {
        $issues += "XAML XML validation failed: $_"
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.InnerException) {
            Write-Host "  Inner: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
    }
}

# Test 6: Check PowerShell script syntax
Write-Host "[6/10] Checking PowerShell script syntax..." -ForegroundColor Yellow
$scriptPath = "WinRepairGUI.ps1"
if (Test-Path $scriptPath) {
    try {
        $scriptContent = Get-Content $scriptPath -Raw
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$tokens, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            Write-Host "  Syntax errors found:" -ForegroundColor Red
            foreach ($error in $errors | Select-Object -First 5) {
                $issues += "Line $($error.Extent.StartLineNumber): $($error.Message)"
                Write-Host "    Line $($error.Extent.StartLineNumber): $($error.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  PowerShell syntax: OK" -ForegroundColor Green
        }
    } catch {
        $issues += "Failed to parse PowerShell script: $_"
    }
} else {
    $issues += "PowerShell script not found: $scriptPath"
}

# Test 7: Check for required functions
Write-Host "[7/10] Checking for required functions..." -ForegroundColor Yellow
$requiredFunctions = @(
    "Start-GUI",
    "Get-Control",
    "Start-NotepadSafely"
)
foreach ($func in $requiredFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "  $func : Found" -ForegroundColor Green
    } else {
        $warnings += "Function not found: $func (may be defined in script)"
    }
}

# Test 8: Test minimal XAML loading
Write-Host "[8/10] Testing minimal XAML loading..." -ForegroundColor Yellow
try {
    $minimalXaml = '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" />'
    $testWindow = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$minimalXaml)))
    $testWindow.Close()
    Write-Host "  Minimal XAML loading: OK" -ForegroundColor Green
} catch {
    $issues += "Minimal XAML loading failed: $_"
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 9: Check for duplicate TabItem definitions
Write-Host "[9/10] Checking for duplicate TabItem definitions..." -ForegroundColor Yellow
if (Test-Path $xamlPath) {
    $xamlContent = Get-Content $xamlPath -Raw
    $bootFixerCount = ([regex]::Matches($xamlContent, 'Boot Fixer')).Count
    if ($bootFixerCount -gt 2) {
        $warnings += "Multiple 'Boot Fixer' references found in XAML ($bootFixerCount). May indicate duplicate tab."
    }
    Write-Host "  'Boot Fixer' references: $bootFixerCount" -ForegroundColor Gray
}

# Test 10: Check XAML for common issues
Write-Host "[10/10] Checking XAML for common issues..." -ForegroundColor Yellow
if (Test-Path $xamlPath) {
    $xamlContent = Get-Content $xamlPath -Raw
    
    # Check for unclosed tags
    $openTags = ([regex]::Matches($xamlContent, '<TabItem[^>]*>')).Count
    $closeTags = ([regex]::Matches($xamlContent, '</TabItem>')).Count
    if ($openTags -ne $closeTags) {
        $issues += "Mismatched TabItem tags: $openTags open, $closeTags close"
        Write-Host "  ERROR: TabItem tag mismatch!" -ForegroundColor Red
    } else {
        Write-Host "  TabItem tags: Balanced ($openTags)" -ForegroundColor Green
    }
    
    # Check for duplicate control names
    $controlNames = [regex]::Matches($xamlContent, 'Name="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    $duplicates = $controlNames | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($duplicates) {
        foreach ($dup in $duplicates) {
            $warnings += "Duplicate control name: $($dup.Name)"
        }
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "All checks passed! GUI should load successfully." -ForegroundColor Green
    exit 0
} else {
    if ($issues.Count -gt 0) {
        Write-Host ""
        Write-Host "CRITICAL ISSUES FOUND:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "  ✗ $issue" -ForegroundColor Red
        }
    }
    
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "WARNINGS:" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "  ⚠ $warning" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "Please fix the issues above before launching the GUI." -ForegroundColor Yellow
    exit 1
}
