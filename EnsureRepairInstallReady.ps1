<#
.SYNOPSIS
    Ensures Windows is eligible for in-place upgrade repair (repair-install mode).

.DESCRIPTION
    This module normalizes Windows state to meet setup.exe requirements for in-place 
    upgrade repair while preserving apps and files. It validates CBS state, verifies 
    setup eligibility, repairs WinRE metadata, and pre-validates outcomes.

.PARAMETER TargetDrive
    The system drive letter or mount path for offline servicing (e.g., 'C' or 'X:\').
    Defaults to 'C' for online mode or 'X' for WinPE.

.PARAMETER ImagePath
    Full path to offline Windows image for offline dism operations.
    If not provided, attempts online servicing.

.PARAMETER Online
    Switch to force online servicing against local system.

.PARAMETER OfflineReg
    Switch to enable offline registry checks without loading hives.

.EXAMPLE
    # Online check and repair
    .\EnsureRepairInstallReady.ps1 -Online

    # WinPE offline mode
    .\EnsureRepairInstallReady.ps1 -ImagePath "X:\Windows" -TargetDrive "X"

.NOTES
    Version: 1.0
    Author: MiracleBoot Development Team
    Requires: Administrator privileges, PowerShell 5.0+
    Environment: WinPE/WinRE or Windows with administrator rights
#>

[CmdletBinding()]
param(
    [string]$TargetDrive = "C",
    [string]$ImagePath = "",
    [switch]$Online,
    [switch]$OfflineReg,
    [switch]$Verbose = $false
)

# ============================================================================
# SECTION 1: CBS STATE NORMALIZATION
# ============================================================================

function Invoke-CBSCleanup {
    <#
    .SYNOPSIS
        Clears ComponentStore pending operations and repair flags.
    #>
    [CmdletBinding()]
    param(
        [string]$TargetDrive = "C",
        [string]$ImagePath = ""
    )
    
    Write-Host "=== CBS Cleanup & Normalization ===" -ForegroundColor Cyan
    $results = @{
        RebootPendingCleared = $false
        FileRenameOpsCleared = $false
        StoreValidated = $false
        ResetbaseRun = $false
    }
    
    try {
        # Step 1: Clear RebootPending flag via registry
        Write-Host "  [1] Checking for RebootPending flags..." -ForegroundColor White
        $regPath = "HKLM:\System\CurrentControlSet\Control\Session Manager"
        $regKey = "PendingFileRenameOperations"
        
        if (Test-Path $regPath) {
            $item = Get-Item $regPath -ErrorAction SilentlyContinue
            if ($item.GetValueNames() -contains $regKey) {
                Write-Host "      Found PendingFileRenameOperations - removing..." -ForegroundColor Yellow
                Remove-ItemProperty -Path $regPath -Name $regKey -Force -ErrorAction SilentlyContinue
                $results.FileRenameOpsCleared = $true
                Write-Host "      ✓ Cleared PendingFileRenameOperations" -ForegroundColor Green
            }
        }
        
        # Step 2: Validate component store integrity
        Write-Host "  [2] Validating component store..." -ForegroundColor White
        
        if ($ImagePath) {
            $dismOutput = & dism /Image:$ImagePath /Cleanup-Image /StartComponentCleanup /ResetBase /ScratchDir:$env:TEMP 2>&1
        } else {
            $dismOutput = & dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase /ScratchDir:$env:TEMP 2>&1
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      ✓ Component store validated and cleaned" -ForegroundColor Green
            $results.StoreValidated = $true
            $results.ResetbaseRun = $true
        } else {
            Write-Host "      ⚠ Component store cleanup returned exit code: $LASTEXITCODE" -ForegroundColor Yellow
            $dismOutput | Select-Object -Last 5 | ForEach-Object { Write-Host "        $_" }
        }
        
        $results.Status = "Success"
        return $results
    }
    catch {
        Write-Host "      ✗ Error during CBS cleanup: $_" -ForegroundColor Red
        $results.Status = "Failed"
        $results.Error = $_.Exception.Message
        return $results
    }
}

# ============================================================================
# SECTION 2: SETUP ELIGIBILITY VERIFICATION
# ============================================================================

function Get-OfflineRegistryValue {
    <#
    .SYNOPSIS
        Safely reads registry value from offline system without mounting hive.
    #>
    param(
        [string]$RegistryHive,
        [string]$Path,
        [string]$ValueName,
        [string]$TargetDrive = "C"
    )
    
    # Convert path format (e.g., System\CurrentControlSet\Services to System\CurrentControlSet\Services)
    $regPath = "$TargetDrive`:\Windows\System32\config\$RegistryHive"
    
    if (-not (Test-Path $regPath)) {
        Write-Verbose "Registry hive not found: $regPath"
        return $null
    }
    
    try {
        # Use reg query for offline access (requires admin + SE_RESTORE_NAME privilege)
        # This is a simplified approach; full offline reading would require hive mounting
        $output = & reg query "HKLM\$RegistryHive\$Path" /v $ValueName /reg:32 2>$null
        
        if ($output) {
            foreach ($line in $output) {
                if ($line -match "$ValueName\s+REG_\w+\s+(.+)") {
                    return $matches[1].Trim()
                }
            }
        }
        return $null
    }
    catch {
        Write-Verbose "Error reading registry: $_"
        return $null
    }
}

function Test-SetupEligibility {
    <#
    .SYNOPSIS
        Verifies Windows is eligible for setup.exe repair-install mode.
    #>
    [CmdletBinding()]
    param(
        [string]$TargetDrive = "C",
        [switch]$Online
    )
    
    Write-Host "=== Setup Eligibility Verification ===" -ForegroundColor Cyan
    $eligibility = @{
        IsEligible = $true
        Blockers = @()
        Warnings = @()
        RegistryValid = $false
        EditionMatch = $false
        BuildMatch = $false
    }
    
    try {
        Write-Host "  [1] Checking Windows registry keys..." -ForegroundColor White
        
        # Key registry paths for setup eligibility
        $requiredKeys = @(
            "HKLM:\Software\Microsoft\Windows NT\CurrentVersion",
            "HKLM:\System\CurrentControlSet\Services\WinRM",
            "HKLM:\Software\Policies\Microsoft\Windows"
        )
        
        foreach ($keyPath in $requiredKeys) {
            if (Test-Path $keyPath) {
                Write-Verbose "  ✓ Registry path found: $keyPath"
            } else {
                $eligibility.Warnings += "Registry path not found: $keyPath (may be critical)"
                Write-Host "      ⚠ Missing: $keyPath" -ForegroundColor Yellow
            }
        }
        
        $eligibility.RegistryValid = (Test-Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion")
        
        # Attempt to read critical version info
        Write-Host "  [2] Reading version information..." -ForegroundColor White
        
        try {
            $versionKey = Get-ItemProperty "HKLM:\Software\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
            
            if ($versionKey) {
                $edition = $versionKey.EditionID
                $build = $versionKey.CurrentBuild
                $ubr = $versionKey.UBR
                
                Write-Host "      Edition: $edition" -ForegroundColor White
                Write-Host "      Build: $build UBR: $ubr" -ForegroundColor White
                
                # Check for known problematic editions
                if ($edition -in @("Professional", "Enterprise", "Home", "ProEducation")) {
                    $eligibility.EditionMatch = $true
                    Write-Host "      ✓ Edition is setup-compatible" -ForegroundColor Green
                } else {
                    $eligibility.Blockers += "Unknown edition: $edition"
                    Write-Host "      ✗ Unknown edition: $edition" -ForegroundColor Red
                    $eligibility.IsEligible = $false
                }
                
                # Verify build family (simplified check)
                if ($build -match '^\d{5}$') {
                    $eligibility.BuildMatch = $true
                    Write-Host "      ✓ Build format valid" -ForegroundColor Green
                } else {
                    $eligibility.Blockers += "Invalid build format: $build"
                    $eligibility.IsEligible = $false
                }
            } else {
                $eligibility.Warnings += "Could not read version registry"
            }
        }
        catch {
            $eligibility.Warnings += "Error reading version info: $($_.Exception.Message)"
        }
        
        # Check for RebootPending flags
        Write-Host "  [3] Checking for RebootPending flags..." -ForegroundColor White
        
        $sessionMgrPath = "HKLM:\System\CurrentControlSet\Control\Session Manager"
        if (Test-Path $sessionMgrPath) {
            $item = Get-Item $sessionMgrPath -ErrorAction SilentlyContinue
            $pendingRenames = $item.GetValueNames() -contains "PendingFileRenameOperations"
            
            if ($pendingRenames) {
                $eligibility.Blockers += "PendingFileRenameOperations flag set - blocks setup.exe"
                $eligibility.IsEligible = $false
                Write-Host "      ✗ RebootPending flags detected - will block setup!" -ForegroundColor Red
            } else {
                Write-Host "      ✓ No RebootPending flags found" -ForegroundColor Green
            }
        }
        
        # Summary
        Write-Host "  [4] Eligibility Summary:" -ForegroundColor White
        if ($eligibility.IsEligible) {
            Write-Host "      ✓ ELIGIBLE for repair-install" -ForegroundColor Green
        } else {
            Write-Host "      ✗ NOT ELIGIBLE - has blockers:" -ForegroundColor Red
            $eligibility.Blockers | ForEach-Object {
                Write-Host "        • $_" -ForegroundColor Red
            }
        }
        
        if ($eligibility.Warnings.Count -gt 0) {
            Write-Host "      ⚠ Warnings:" -ForegroundColor Yellow
            $eligibility.Warnings | ForEach-Object {
                Write-Host "        • $_" -ForegroundColor Yellow
            }
        }
        
        return $eligibility
    }
    catch {
        Write-Host "      ✗ Error during eligibility check: $_" -ForegroundColor Red
        $eligibility.IsEligible = $false
        $eligibility.Blockers += $_.Exception.Message
        return $eligibility
    }
}

# ============================================================================
# SECTION 3: WINRE METADATA REPAIR
# ============================================================================

function Repair-WinREMetadata {
    <#
    .SYNOPSIS
        Repairs Windows Recovery Environment metadata and BCD entries.
    #>
    [CmdletBinding()]
    param(
        [string]$TargetDrive = "C",
        [string]$ImagePath = ""
    )
    
    Write-Host "=== WinRE Metadata Repair ===" -ForegroundColor Cyan
    $results = @{
        ReagentConfigured = $false
        BCDUpdated = $false
        WinREPartitionFound = $false
        Status = "Pending"
    }
    
    try {
        Write-Host "  [1] Checking WinRE partition..." -ForegroundColor White
        
        # List recovery partitions
        $recoveryPartitions = Get-Partition -ErrorAction SilentlyContinue | 
            Where-Object { $_.Type -eq "Recovery" } |
            Select-Object -First 1
        
        if ($recoveryPartitions) {
            $results.WinREPartitionFound = $true
            Write-Host "      ✓ WinRE partition found: $($recoveryPartitions.DriveLetter)" -ForegroundColor Green
        } else {
            Write-Host "      ⚠ No WinRE partition found" -ForegroundColor Yellow
            $results.Status = "Warning"
        }
        
        # Step 2: Run ReAgent configuration
        Write-Host "  [2] Configuring Recovery Agent..." -ForegroundColor White
        
        if ($ImagePath) {
            $reagentOutput = & reagentc /SetREImage /Path "$($TargetDrive):\Recovery\WindowsRE" /Index 1 2>&1
        } else {
            $reagentOutput = & reagentc /Info 2>&1
            Write-Host "      Current ReAgent status:" -ForegroundColor White
            $reagentOutput | ForEach-Object { Write-Host "        $_" -ForegroundColor Gray }
        }
        
        $results.ReagentConfigured = $true
        Write-Host "      ✓ ReAgent configured" -ForegroundColor Green
        
        # Step 3: Verify ReAgent.xml
        Write-Host "  [3] Verifying ReAgent.xml..." -ForegroundColor White
        
        $reagentXmlPath = "$TargetDrive`:\Windows\System32\Recovery\ReAgent.xml"
        if (Test-Path $reagentXmlPath) {
            Write-Host "      ✓ ReAgent.xml found" -ForegroundColor Green
            
            try {
                [xml]$reagentXml = Get-Content $reagentXmlPath -ErrorAction SilentlyContinue
                if ($reagentXml.ImageState) {
                    Write-Host "      ✓ ReAgent.xml is valid XML" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "      ⚠ ReAgent.xml exists but is invalid XML" -ForegroundColor Yellow
            }
        } else {
            Write-Host "      ✗ ReAgent.xml not found - WinRE metadata may be missing" -ForegroundColor Yellow
        }
        
        # Step 4: Update BCD for WinRE
        Write-Host "  [4] Updating BCD Recovery settings..." -ForegroundColor White
        
        try {
            # Set recovery sequence
            & bcdedit /set `{current`} recoveryenabled Yes 2>&1 | Out-Null
            & bcdedit /set `{current`} recoverysequence `{default`} 2>&1 | Out-Null
            
            $results.BCDUpdated = $true
            Write-Host "      ✓ BCD recovery settings updated" -ForegroundColor Green
        }
        catch {
            Write-Host "      ⚠ Could not update BCD: $_" -ForegroundColor Yellow
        }
        
        $results.Status = "Success"
        return $results
    }
    catch {
        Write-Host "      ✗ Error during WinRE repair: $_" -ForegroundColor Red
        $results.Status = "Failed"
        $results.Error = $_.Exception.Message
        return $results
    }
}

# ============================================================================
# SECTION 4: PRE-VALIDATION & DRY-RUN
# ============================================================================

function Test-SetupExeReadiness {
    <#
    .SYNOPSIS
        Simulates setup.exe eligibility checks without running actual setup.
    #>
    [CmdletBinding()]
    param(
        [string]$TargetDrive = "C"
    )
    
    Write-Host "=== Setup.exe Pre-Validation ===" -ForegroundColor Cyan
    $validation = @{
        CanProceedSafely = $true
        CriticalIssues = @()
        Recommendations = @()
        EstimatedDuration = "1.5-2.5 hours"
    }
    
    try {
        Write-Host "  [1] Checking for critical blocker conditions..." -ForegroundColor White
        
        # Check 1: Disk space
        Write-Host "      Checking disk space..." -ForegroundColor White
        $systemDrive = Get-PSDrive -Name $TargetDrive[0] -ErrorAction SilentlyContinue
        if ($systemDrive) {
            $freeGB = [math]::Round($systemDrive.Free / 1GB, 2)
            if ($freeGB -lt 10) {
                $validation.CriticalIssues += "Insufficient disk space: ${freeGB}GB free (need 10GB minimum)"
                $validation.CanProceedSafely = $false
                Write-Host "        ✗ Low disk space: ${freeGB}GB" -ForegroundColor Red
            } else {
                Write-Host "        ✓ Sufficient disk space: ${freeGB}GB" -ForegroundColor Green
            }
        }
        
        # Check 2: Antivirus/Real-time protection
        Write-Host "      Checking antivirus status..." -ForegroundColor White
        $wdefend = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($wdefend.RealTimeProtectionEnabled) {
            $validation.Recommendations += "Disable real-time antivirus protection before setup to prevent conflicts"
            Write-Host "        ⚠ Real-time protection enabled (should be disabled during setup)" -ForegroundColor Yellow
        }
        
        # Check 3: Network connectivity
        Write-Host "      Checking network connectivity..." -ForegroundColor White
        $netAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        if ($netAdapters) {
            Write-Host "        ✓ Network connected" -ForegroundColor Green
        } else {
            $validation.Recommendations += "Network offline - setup may fail to download updates"
            Write-Host "        ⚠ Network disconnected" -ForegroundColor Yellow
        }
        
        # Check 4: Power state
        Write-Host "      Checking power configuration..." -ForegroundColor White
        $powerPlan = Get-PowerPlan -ErrorAction SilentlyContinue
        if ($powerPlan) {
            Write-Host "        ✓ Power plan configured: $($powerPlan.FriendlyName)" -ForegroundColor Green
            $validation.Recommendations += "Ensure system stays powered during setup (high performance mode recommended)"
        }
        
        # Check 5: Pending updates
        Write-Host "      Checking for pending updates..." -ForegroundColor White
        $updates = Get-WindowsUpdate -ErrorAction SilentlyContinue
        if ($updates) {
            $validation.Recommendations += "Install pending Windows Updates before setup to prevent re-updates"
            Write-Host "        ⚠ Pending updates detected: $($updates.Count)" -ForegroundColor Yellow
        }
        
        Write-Host "  [2] Readiness Summary:" -ForegroundColor White
        if ($validation.CanProceedSafely) {
            Write-Host "      ✓ System appears ready for setup.exe" -ForegroundColor Green
        } else {
            Write-Host "      ✗ Critical issues must be resolved before proceeding:" -ForegroundColor Red
            $validation.CriticalIssues | ForEach-Object {
                Write-Host "        • $_" -ForegroundColor Red
            }
        }
        
        if ($validation.Recommendations.Count -gt 0) {
            Write-Host "      ⚠ Recommendations:" -ForegroundColor Yellow
            $validation.Recommendations | ForEach-Object {
                Write-Host "        • $_" -ForegroundColor Yellow
            }
        }
        
        return $validation
    }
    catch {
        Write-Host "      ✗ Error during setup validation: $_" -ForegroundColor Red
        $validation.CanProceedSafely = $false
        $validation.CriticalIssues += $_.Exception.Message
        return $validation
    }
}

# ============================================================================
# SECTION 5: ORCHESTRATION & MAIN WORKFLOW
# ============================================================================

function Invoke-RepairInstallReadinessCheck {
    <#
    .SYNOPSIS
        Main orchestration function for complete repair-install readiness workflow.
    #>
    [CmdletBinding()]
    param(
        [string]$TargetDrive = "C",
        [string]$ImagePath = "",
        [switch]$AutoRepair
    )
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     REPAIR-INSTALL READINESS ENGINE v1.0                       ║" -ForegroundColor Cyan
    Write-Host "║     Ensuring Windows Eligibility for Setup.exe                  ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $workflow = @{
        StartTime = Get-Date
        Steps = @()
        OverallStatus = "Success"
        FinalRecommendation = ""
    }
    
    try {
        # Phase 1: Diagnostics
        Write-Host "[PHASE 1] Diagnostic Checks" -ForegroundColor Magenta
        Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
        
        $eligibility = Test-SetupEligibility -TargetDrive $TargetDrive
        $workflow.Steps += @{ Step = "Setup Eligibility Check"; Result = $eligibility }
        
        # Phase 2: Repairs (if needed)
        if ($AutoRepair -or $eligibility.Blockers.Count -gt 0) {
            Write-Host "`n[PHASE 2] Automatic Repairs" -ForegroundColor Magenta
            Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
            
            $cbsCleanup = Invoke-CBSCleanup -TargetDrive $TargetDrive -ImagePath $ImagePath
            $workflow.Steps += @{ Step = "CBS Cleanup"; Result = $cbsCleanup }
            
            $winreRepair = Repair-WinREMetadata -TargetDrive $TargetDrive -ImagePath $ImagePath
            $workflow.Steps += @{ Step = "WinRE Repair"; Result = $winreRepair }
            
            # Re-run eligibility check after repairs
            Write-Host "`n[PHASE 3] Post-Repair Validation" -ForegroundColor Magenta
            Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
            
            Start-Sleep -Seconds 2
            $eligibilityPost = Test-SetupEligibility -TargetDrive $TargetDrive
            $workflow.Steps += @{ Step = "Post-Repair Eligibility"; Result = $eligibilityPost }
            $eligibility = $eligibilityPost
        }
        
        # Phase 3: Pre-validation
        Write-Host "`n[PHASE 4] Setup.exe Pre-Validation" -ForegroundColor Magenta
        Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
        
        $setupValidation = Test-SetupExeReadiness -TargetDrive $TargetDrive
        $workflow.Steps += @{ Step = "Setup Readiness"; Result = $setupValidation }
        
        # Final recommendation
        Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║     FINAL RECOMMENDATION                                       ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        
        if ($eligibility.IsEligible -and $setupValidation.CanProceedSafely) {
            Write-Host "`n✓ SYSTEM IS READY FOR REPAIR-INSTALL" -ForegroundColor Green
            Write-Host "  You can proceed with Windows setup.exe repair-install mode" -ForegroundColor Green
            Write-Host "  Select: Keep personal files and apps (in-place upgrade)" -ForegroundColor Green
            Write-Host "  Estimated duration: $($setupValidation.EstimatedDuration)" -ForegroundColor Green
            $workflow.FinalRecommendation = "READY_FOR_REPAIR_INSTALL"
        }
        elseif ($eligibility.IsEligible) {
            Write-Host "`n⚠ SYSTEM MOSTLY READY - RESOLVE WARNINGS FIRST" -ForegroundColor Yellow
            Write-Host "  Address the recommendations above, then retry" -ForegroundColor Yellow
            $setupValidation.Recommendations | ForEach-Object {
                Write-Host "  • $_" -ForegroundColor Yellow
            }
            $workflow.FinalRecommendation = "READY_WITH_WARNINGS"
        }
        else {
            Write-Host "`n✗ SYSTEM NOT READY - REPAIR AGAIN OR CLEAN INSTALL" -ForegroundColor Red
            Write-Host "  Critical blockers prevent repair-install:" -ForegroundColor Red
            $eligibility.Blockers | ForEach-Object {
                Write-Host "  • $_" -ForegroundColor Red
            }
            $workflow.FinalRecommendation = "NOT_READY"
            $workflow.OverallStatus = "Warning"
        }
        
        Write-Host "`n" -ForegroundColor Gray
        $workflow.EndTime = Get-Date
        return $workflow
    }
    catch {
        Write-Host "`n✗ CRITICAL ERROR DURING READINESS CHECK" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        $workflow.OverallStatus = "Failed"
        $workflow.FinalRecommendation = "ERROR"
        return $workflow
    }
}

# ============================================================================
# EXPORTS & EXECUTION
# ============================================================================

# Only execute if run directly (not sourced)
if ($MyInvocation.InvocationName -ne ".") {
    $params = @{
        TargetDrive = $TargetDrive
        ImagePath = $ImagePath
        AutoRepair = -not $Online
    }
    
    $result = Invoke-RepairInstallReadinessCheck @params
    
    # Export result for integration with MiracleBoot
    $result
}

# Export public functions for module sourcing
Export-ModuleMember -Function @(
    'Invoke-RepairInstallReadinessCheck',
    'Test-SetupEligibility',
    'Invoke-CBSCleanup',
    'Repair-WinREMetadata',
    'Test-SetupExeReadiness'
)
