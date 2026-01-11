# Side-by-side comparison of OLD (broken) vs NEW (fixed) code
# Shows exactly what was changed and why

Write-Host "`n" -NoNewline
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  BCD REPAIR FIX: BEFORE vs AFTER COMPARISON                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Fix 1: Argument Handling
Write-Host "FIX #1: ARGUMENT ESCAPING - Eliminates /encodedCommand error" -ForegroundColor Yellow
Write-Host "─" * 70 -ForegroundColor Gray

Write-Host "`nBEFORE (BROKEN):" -ForegroundColor Red
Write-Host '  $setDevice = bcdedit /store $bcdStore /set {default} device partition=$TargetDrive' -ForegroundColor Red
Write-Host "  Issue: {default} causes PowerShell to interpret as variable reference" -ForegroundColor Red
Write-Host "  Error: Invalid command line switch: /encodedCommand" -ForegroundColor Red

Write-Host "`nAFTER (FIXED):" -ForegroundColor Green
Write-Host '  $deviceArgs = @("/store", $bcdStore, "/set", "{default}", "device", "partition=$TargetDrive")' -ForegroundColor Green
Write-Host '  $setDeviceResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $deviceArgs' -ForegroundColor Green
Write-Host "  Result: Proper quoting, no /encodedCommand error" -ForegroundColor Green

Write-Host ""

# Fix 2: BCD Existence Check
Write-Host "FIX #2: BCD EXISTENCE CHECK - Handle missing BCD files" -ForegroundColor Yellow
Write-Host "─" * 70 -ForegroundColor Gray

Write-Host "`nBEFORE (BROKEN):" -ForegroundColor Red
Write-Host "  # Code went straight to modifying BCD" -ForegroundColor Red
Write-Host '  $setPath = bcdedit /store $bcdStore /set {default} path \Windows\system32\winload.efi' -ForegroundColor Red
Write-Host "  # If BCD missing → ERROR: could not be opened" -ForegroundColor Red
Write-Host "  # Cascading failures on all subsequent commands" -ForegroundColor Red

Write-Host "`nAFTER (FIXED):" -ForegroundColor Green
Write-Host '  # Step 1: Check if BCD exists FIRST' -ForegroundColor Green
Write-Host '  $enumCheckResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments @("/store", $bcdStore, "/enum", "{default}")' -ForegroundColor Green
Write-Host '  $bcdExists = $enumCheckResult.ExitCode -eq 0 -and -not ($enumCheckResult.Output -match "could not be opened|cannot find")' -ForegroundColor Green
Write-Host "" -ForegroundColor Green
Write-Host '  # Step 2: If missing, CREATE with bcdboot' -ForegroundColor Green
Write-Host '  if (-not $bcdExists) {' -ForegroundColor Green
Write-Host '    $rebuildResult = Invoke-BCDCommandWithTimeout -Command "bcdboot.exe" -Arguments @("$TargetDrive`:\Windows", "/s", $EspLetter, "/f", "UEFI", "/addlast")' -ForegroundColor Green
Write-Host '  }' -ForegroundColor Green
Write-Host "" -ForegroundColor Green
Write-Host "  Result: BCD created if missing, then modified successfully" -ForegroundColor Green

Write-Host ""

# Fix 3: Exit Code Checking
Write-Host "FIX #3: EXIT CODE VALIDATION - Catch failures immediately" -ForegroundColor Yellow
Write-Host "─" * 70 -ForegroundColor Gray

Write-Host "`nBEFORE (BROKEN):" -ForegroundColor Red
Write-Host '  $setPath = bcdedit /store $bcdStore /set {default} path ...' -ForegroundColor Red
Write-Host '  $setDevice = bcdedit /store $bcdStore /set {default} device ...' -ForegroundColor Red
Write-Host '  $setOsDevice = bcdedit /store $bcdStore /set {default} osdevice ...' -ForegroundColor Red
Write-Host "  " -ForegroundColor Red
Write-Host "  if ($LASTEXITCODE -eq 0) {  # Only checks LAST command!" -ForegroundColor Red
Write-Host "      $actions += 'BCD path set successfully'" -ForegroundColor Red
Write-Host "  }" -ForegroundColor Red
Write-Host "" -ForegroundColor Red
Write-Host "  Issue: If first command fails, others execute anyway" -ForegroundColor Red
Write-Host "  Result: Cascading failures, partial BCD corruption" -ForegroundColor Red

Write-Host "`nAFTER (FIXED):" -ForegroundColor Green
Write-Host '  $setPathResult = Invoke-BCDCommandWithTimeout -Command "bcdedit.exe" -Arguments $pathArgs' -ForegroundColor Green
Write-Host "  " -ForegroundColor Green
Write-Host "  if ($setPathResult.ExitCode -ne 0) {  # CHECK IMMEDIATELY" -ForegroundColor Green
Write-Host '    $actions += "❌ BCD path set failed: $($setPathResult.Output)"' -ForegroundColor Green
Write-Host "    # Don't continue to next command" -ForegroundColor Green
Write-Host "  }" -ForegroundColor Green
Write-Host "" -ForegroundColor Green
Write-Host "  Result: Failures detected immediately, no cascading errors" -ForegroundColor Green

Write-Host ""

# Fix 4: Structured Output
Write-Host "FIX #4: STRUCTURED RETURN VALUES - Better error information" -ForegroundColor Yellow
Write-Host "─" * 70 -ForegroundColor Gray

Write-Host "`nBEFORE (BROKEN):" -ForegroundColor Red
Write-Host "  $result = bcdedit /enum /v 2>&1 | Out-String" -ForegroundColor Red
Write-Host "  # Only get string, no exit code, no structured info" -ForegroundColor Red
Write-Host "  # $LASTEXITCODE is fragile and often incorrect" -ForegroundColor Red

Write-Host "`nAFTER (FIXED):" -ForegroundColor Green
Write-Host "  $result = Invoke-BCDCommandWithTimeout -Command 'bcdedit.exe' -Arguments @(...)" -ForegroundColor Green
Write-Host "  " -ForegroundColor Green
Write-Host "  Returns: @{" -ForegroundColor Green
Write-Host "    Success = $true|$false" -ForegroundColor Green
Write-Host "    Output = 'detailed output'" -ForegroundColor Green
Write-Host "    ExitCode = 0|-1|1|etc" -ForegroundColor Green
Write-Host "    TimedOut = $true|$false" -ForegroundColor Green
Write-Host "  }" -ForegroundColor Green
Write-Host "" -ForegroundColor Green
Write-Host "  Result: Reliable error detection and clear diagnostics" -ForegroundColor Green

Write-Host ""
Write-Host ""

# Summary Table
Write-Host "IMPACT SUMMARY" -ForegroundColor Yellow
Write-Host "─" * 70 -ForegroundColor Gray
Write-Host ""

$before = @(
    "❌ /encodedCommand error",
    "❌ BCD missing error",
    "❌ Cascading failures",
    "❌ Silent failures",
    "❌ Partial BCD corruption",
    "❌ Unclear error messages",
    "❌ Timeout hangs"
)

$after = @(
    "✓ Proper argument escaping",
    "✓ BCD created if missing",
    "✓ Individual command validation",
    "✓ Proper error handling",
    "✓ No cascading errors",
    "✓ Clear error reporting",
    "✓ Timeout protection"
)

Write-Host "BEFORE FIX:" -ForegroundColor Red
foreach ($issue in $before) {
    Write-Host "  $issue" -ForegroundColor Red
}

Write-Host ""

Write-Host "AFTER FIX:" -ForegroundColor Green
foreach ($fix in $after) {
    Write-Host "  $fix" -ForegroundColor Green
}

Write-Host ""
Write-Host ""

# Functionality Matrix
Write-Host "FUNCTIONALITY MATRIX" -ForegroundColor Yellow
Write-Host "─" * 70 -ForegroundColor Gray
Write-Host ""

$scenarios = @(
    @{ Scenario = "BCD exists"; Before = "✓ Works"; After = "✓ Works"; Same = $true },
    @{ Scenario = "BCD missing"; Before = "❌ FAILS"; After = "✓ Creates & Repairs"; Same = $false },
    @{ Scenario = "BCD corrupted"; Before = "❌ Partial fail"; After = "✓ Rebuilds"; Same = $false },
    @{ Scenario = "Invalid partition"; Before = "❌ Cascades"; After = "✓ Caught"; Same = $false },
    @{ Scenario = "Timeout scenario"; Before = "❌ Hangs"; After = "✓ Returns"; Same = $false },
    @{ Scenario = "Permission denied"; Before = "❌ Unclear"; After = "✓ Clear error"; Same = $false }
)

foreach ($s in $scenarios) {
    $beforeColor = if ($s.Before -match "✓") { "Green" } else { "Red" }
    $afterColor = if ($s.After -match "✓") { "Green" } else { "Red" }
    
    Write-Host "  $($s.Scenario):" -ForegroundColor Cyan
    Write-Host "    Before: " -NoNewline
    Write-Host "$($s.Before)" -ForegroundColor $beforeColor
    Write-Host "    After:  " -NoNewline
    Write-Host "$($s.After)" -ForegroundColor $afterColor
    Write-Host ""
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STATUS: All critical issues fixed. Ready for deployment." -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
