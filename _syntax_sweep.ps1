$failures = @()
Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object {
    $p = $_.FullName
    $output = & powershell -NoLogo -NoProfile -Command {
        param($f)
        try {
            Set-StrictMode -Version Latest
            . $f
            exit 0
        } catch {
            Write-Error $_
            exit 1
        }
    } -ArgumentList $p 2>&1
    if ($LASTEXITCODE -ne 0) {
        $msg = if ($output) { ($output -join "; ") } else { "Unknown error" }
        $failures += "FAIL: $p - $msg"
    }
}
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output $_ }
    exit 1
}
