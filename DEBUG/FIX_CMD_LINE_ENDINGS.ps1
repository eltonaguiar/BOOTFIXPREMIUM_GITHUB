# Fix line endings in RunMiracleBoot.cmd to CRLF

$cmdPath = "RunMiracleBoot.cmd"
$content = Get-Content $cmdPath -Raw

# Convert all line endings to CRLF
$content = $content -replace "`r?`n", "`r`n"

# Write back with ASCII encoding (no BOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Resolve-Path $cmdPath), $content, $utf8NoBom)

Write-Host "Fixed line endings in $cmdPath" -ForegroundColor Green
