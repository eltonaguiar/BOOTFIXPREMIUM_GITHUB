$ErrorActionPreference = "Stop"

$threshold = 20

$hooksDir = (git rev-parse --git-path hooks).Trim()
$countFile = Join-Path $hooksDir "auto-push-count.txt"

$count = 0
if (Test-Path $countFile) {
    $raw = Get-Content -Path $countFile -TotalCount 1 -ErrorAction SilentlyContinue
    [int]::TryParse($raw, [ref]$count) | Out-Null
}

$filesChanged = @(git diff-tree --no-commit-id --name-only -r HEAD | Where-Object { $_ -and $_.Trim() -ne "" })
$count += $filesChanged.Count

if ($count -ge $threshold) {
    $upstream = git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($upstream)) {
        Write-Host "[auto-push] No upstream configured; skipping push."
    } else {
        git push
        if ($LASTEXITCODE -eq 0) {
            $count = 0
        } else {
            Write-Host "[auto-push] git push failed; keeping counter at $count."
        }
    }
}

Set-Content -Path $countFile -Value $count -Encoding ASCII
