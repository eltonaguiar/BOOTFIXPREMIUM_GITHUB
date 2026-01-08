# Check syntax of WinRepairGUI.ps1 using AST
$content = Get-Content 'HELPER SCRIPTS/WinRepairGUI.ps1' -Raw
try {
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
    if ($ast) {
        Write-Host "AST parsing successful"
    }
} catch {
    Write-Host "AST parsing failed: $($_.Exception.Message)"
}

# Also try PSParser
$errors = $null
$null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
Write-Host "PSParser found $($errors.Count) errors"
foreach ($err in $errors) {
    Write-Host "Line $($err.Token.StartLine): $($err.Message)"
}