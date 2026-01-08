param([string]$FilePath)

# If no file specified, use the main GUI file
if (-not $FilePath) {
    $FilePath = Join-Path (Split-Path $PSScriptRoot -Parent) "HELPER SCRIPTS\WinRepairGUI.ps1"
}

if (-not (Test-Path $FilePath)) {
    Write-Host "ERROR: File not found - $FilePath" -ForegroundColor Red
    exit 1
}

Write-Host "XAML Validator - Checking: $FilePath" -ForegroundColor Cyan

$content = Get-Content $FilePath -Raw
$allValid = $true

# Extract main XAML block
$start = $content.IndexOf('$XAML = @"')
$end = $content.IndexOf('"@', $start)

if ($start -lt 0 -or $end -lt 0) {
    Write-Host "ERROR: XAML block not found" -ForegroundColor Red
    exit 1
}

$xaml = $content.Substring($start + 11, $end - $start - 11)

# Check tags
Write-Host "Checking tag balance..."
$tags = @('Window','Grid','TabControl','TabItem','StackPanel')

foreach ($tag in $tags) {
    $open = ([regex]::Matches($xaml, "\<$tag" + '(\>|\s)')).Count
    $close = ([regex]::Matches($xaml, "\</$tag\>")).Count
    
    if ($open -ne $close) {
        Write-Host "  ERROR: $tag = open:$open close:$close" -ForegroundColor Red
        $allValid = $false
    }
}

# Try XML parsing
Write-Host "Checking XML validity..."
try {
    [xml]$test = $xaml
    Write-Host "  OK: XML parsed successfully" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: XML parsing failed" -ForegroundColor Red
    $allValid = $false
}

if ($allValid) {
    Write-Host ""
    Write-Host "RESULT: PASS" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "RESULT: FAIL" -ForegroundColor Red
    exit 1
}
