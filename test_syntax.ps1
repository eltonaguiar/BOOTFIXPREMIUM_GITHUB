$content = Get-Content .\WinRepairGUI.ps1 -Raw
try {
    $null = [scriptblock]::Create($content)
    Write-Host "SUCCESS: File parsed without errors"
} catch {
    Write-Host "Parse error found:"
    Write-Host $_.Exception.Message
}
