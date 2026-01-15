# Detailed analysis of RunMiracleBoot.cmd

$cmdPath = "RunMiracleBoot.cmd"
$content = Get-Content $cmdPath -Raw
$lines = $content -split "`r?`n"

Write-Host "=== CODE LINES (excluding REM comments) ===" -ForegroundColor Cyan
$codeLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.Trim()
    
    # Skip REM comments
    if ($trimmed -match '^\s*REM\s') {
        continue
    }
    
    $codeLines += $line
    Write-Host "Line $($i+1): $line" -ForegroundColor Gray
}

$codeContent = $codeLines -join "`r`n"

Write-Host "`n=== PARENTHESES IN CODE ===" -ForegroundColor Cyan
$openParens = ([regex]::Matches($codeContent, '\(')).Count
$closeParens = ([regex]::Matches($codeContent, '\)')).Count
Write-Host "Open: $openParens, Close: $closeParens" -ForegroundColor $(if($openParens -eq $closeParens){'Green'}else{'Red'})

# Show each parenthesis with context
Write-Host "`nOpen parentheses:" -ForegroundColor Yellow
for ($i = 0; $i -lt $codeLines.Count; $i++) {
    if ($codeLines[$i] -match '\(') {
        $matches = [regex]::Matches($codeLines[$i], '\(')
        foreach ($match in $matches) {
            Write-Host "  Line $($i+1): $($codeLines[$i])" -ForegroundColor Gray
        }
    }
}

Write-Host "`nClose parentheses:" -ForegroundColor Yellow
for ($i = 0; $i -lt $codeLines.Count; $i++) {
    if ($codeLines[$i] -match '\)') {
        $matches = [regex]::Matches($codeLines[$i], '\)')
        foreach ($match in $matches) {
            Write-Host "  Line $($i+1): $($codeLines[$i])" -ForegroundColor Gray
        }
    }
}

Write-Host "`n=== VARIABLE EXPANSION PATTERNS ===" -ForegroundColor Cyan
# Check the specific patterns
$pattern1 = 'set\s+[^=]*=\s*[^"]*%[^%]*%[^"]*(?!")'
$pattern2 = 'if\s+exist\s+[^"]+%[^"]+[^"]*(?!")'
$pattern3 = 'for\s+.*in\s+\([^)]*%[^)]*[^"]*(?!")'

Write-Host "Pattern 1 (set with unquoted var):" -ForegroundColor Yellow
if ($codeContent -match $pattern1) {
    Write-Host "  MATCH FOUND" -ForegroundColor Red
    $matches = [regex]::Matches($codeContent, $pattern1)
    foreach ($match in $matches) {
        Write-Host "    $($match.Value)" -ForegroundColor Gray
    }
} else {
    Write-Host "  No match" -ForegroundColor Green
}

Write-Host "Pattern 2 (if exist unquoted):" -ForegroundColor Yellow
if ($codeContent -match $pattern2) {
    Write-Host "  MATCH FOUND" -ForegroundColor Red
    $matches = [regex]::Matches($codeContent, $pattern2)
    foreach ($match in $matches) {
        Write-Host "    $($match.Value)" -ForegroundColor Gray
    }
} else {
    Write-Host "  No match" -ForegroundColor Green
}

Write-Host "Pattern 3 (for loop unquoted):" -ForegroundColor Yellow
if ($codeContent -match $pattern3) {
    Write-Host "  MATCH FOUND" -ForegroundColor Red
    $matches = [regex]::Matches($codeContent, $pattern3)
    foreach ($match in $matches) {
        Write-Host "    $($match.Value)" -ForegroundColor Gray
    }
} else {
    Write-Host "  No match" -ForegroundColor Green
}
