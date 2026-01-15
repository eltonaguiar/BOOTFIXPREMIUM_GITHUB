# Test RunMiracleBoot.cmd execution

$cmdPath = Resolve-Path "RunMiracleBoot.cmd"
Write-Host "=== TEST 4: CMD File Execution Test ===" -ForegroundColor Cyan
Write-Host "Testing: $cmdPath" -ForegroundColor Gray
Write-Host ""

Write-Host "Running dry-run test (--help)..." -ForegroundColor Yellow
$output = & cmd.exe /c "`"$cmdPath`" --help 2>&1" 2>&1
$exitCode = $LASTEXITCODE

Write-Host "Exit Code: $exitCode" -ForegroundColor $(if($exitCode -eq 0){'Green'}else{'Yellow'})

# Check for ". was unexpected" error specifically
$unexpectedError = $output -match '\.\s+was\s+unexpected|was\s+unexpected\s+at\s+this\s+time'

if ($unexpectedError) {
    Write-Host "[FAIL] Found '. was unexpected' error!" -ForegroundColor Red
    Write-Host ""
    Write-Host "ERROR OUTPUT:" -ForegroundColor Red
    Write-Host $output -ForegroundColor Red
    exit 1
} else {
    Write-Host "[PASS] No '. was unexpected' error detected" -ForegroundColor Green
    
    # Check if it shows banner or any output
    $showsBanner = $output -match 'Miracle|Launcher|Boot'
    if ($showsBanner) {
        Write-Host "[PASS] Shows banner/identifier" -ForegroundColor Green
    }
    
    if ($output) {
        Write-Host ""
        Write-Host "Output (first 15 lines):" -ForegroundColor Gray
        $output | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }
    
    exit 0
}
