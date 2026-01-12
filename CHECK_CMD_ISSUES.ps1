# Quick diagnostic for RunMiracleBoot.cmd issues

$cmdPath = "RunMiracleBoot.cmd"
$content = Get-Content $cmdPath -Raw

Write-Host "=== LINE ENDINGS ===" -ForegroundColor Cyan
$hasCRLF = $content -match "`r`n"
$hasLF = $content -match "(?<!`r)`n"
Write-Host "Has CRLF: $hasCRLF"
Write-Host "Has LF only: $hasLF"
$lines = $content -split "`r?`n"
Write-Host "Total lines: $($lines.Count)"

Write-Host "`n=== PARENTHESES ===" -ForegroundColor Cyan
$openParens = ([regex]::Matches($content, '\(')).Count
$closeParens = ([regex]::Matches($content, '\)')).Count
Write-Host "Open: $openParens"
Write-Host "Close: $closeParens"
if ($openParens -ne $closeParens) {
    Write-Host "MISMATCH! Difference: $($openParens - $closeParens)" -ForegroundColor Red
    
    # Show lines with parentheses
    Write-Host "`nLines with parentheses:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '[()]') {
            Write-Host "Line $($i+1): $($lines[$i])" -ForegroundColor Gray
        }
    }
}

Write-Host "`n=== VARIABLE EXPANSION PATTERNS ===" -ForegroundColor Cyan
# Check for problematic patterns
if ($content -match 'set\s+[^=]*=.*%[^%]*%[^"]*"') {
    Write-Host "Found: set with unquoted variable expansion" -ForegroundColor Yellow
}
if ($content -match 'for\s+.*in\s+\([^)]*%[^)]*\)') {
    Write-Host "Found: for loop with potential variable expansion issue" -ForegroundColor Yellow
}
