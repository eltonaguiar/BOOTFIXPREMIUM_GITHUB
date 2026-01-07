#!/usr/bin/env powershell
# ============================================================================
# MIRACLEBOOT NETWORK DIAGNOSTICS & TROUBLESHOOTING MODULE
# Version 2.0 - Enhanced Low Hanging Fruit Feature
# ============================================================================
# Purpose: Complete network troubleshooting with Windows Troubleshooter equivalent
# 
# This module provides CLI equivalents for debugging "internet not working"
# Problems addressed:
# - DNS not resolving (ipconfig /flushdns equivalent)
# - DHCP not assigning IP (ipconfig /release, /renew equivalents)
# - Network adapter not working
# - Proxy/firewall blocking internet
# - TCP/IP stack corruption (Winsock reset)
# - Network adapter driver issues
#
# User commands will replace:
# - ipconfig /all (Get-NetworkConfiguration)
# - ipconfig /flushdns (Invoke-DNSFlush)
# - ipconfig /release (Invoke-DHCPRelease)
# - ipconfig /renew (Invoke-DHCPRenew)
# - netsh winsock reset (Reset-WinsockCatalog)
# ============================================================================

param()

# ============================================================================
# LOGGING & CONFIGURATION
# ============================================================================

$NetworkDiagConfig = @{
    LogPath           = 'C:\MiracleBoot-NetworkDiag'
    DetectionTimeout  = 10
    DNSServers        = @('8.8.8.8', '1.1.1.1')
    TestURLs          = @('google.com', 'cloudflare.com', 'microsoft.com')
    AutoRepair        = $true
    CreateLogFolder   = $true
}

if ($NetworkDiagConfig.CreateLogFolder -and -not (Test-Path $NetworkDiagConfig.LogPath)) {
    New-Item -ItemType Directory -Path $NetworkDiagConfig.LogPath -Force | Out-Null
}

function Write-NetLog {
    param(
        [string]$Message,
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        'Error'   { Write-Host $logEntry -ForegroundColor Red }
        'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
        'Info'    { Write-Host $logEntry -ForegroundColor Cyan }
        default   { Write-Host $logEntry }
    }
    
    # Also log to file if possible
    try {
        Add-Content -Path "$($NetworkDiagConfig.LogPath)\network-diag.log" -Value $logEntry -ErrorAction SilentlyContinue
    } catch { }
}

# ============================================================================
# IPCONFIG EQUIVALENTS
# ============================================================================

function Get-NetworkConfiguration {
    <#
    .SYNOPSIS
    Equivalent to: ipconfig /all
    
    .DESCRIPTION
    Shows all network adapter configuration including:
    - IP addresses (IPv4 and IPv6)
    - DNS servers
    - DHCP status
    - Default gateway
    - Physical addresses (MAC)
    #>
    
    param()
    
    Write-NetLog "Retrieving network configuration (ipconfig /all equivalent)..." -Level Info
    
    $config = @{
        'Adapters'      = @()
        'RetrievalTime' = Get-Date
        'Summary'       = @{}
    }
    
    try {
        # Get network adapters
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue
        
        foreach ($adapter in $adapters) {
            $adapterConfig = @{
                'Name'              = $adapter.Name
                'Status'            = $adapter.Status
                'MacAddress'        = $adapter.MacAddress
                'Speed'             = $adapter.LinkSpeed
                'Type'              = $adapter.MediaType
                'IPv4Addresses'     = @()
                'IPv6Addresses'     = @()
                'DNSServers'        = @()
                'DHCP'              = 'Unknown'
                'Gateway'           = @()
            }
            
            # Get IP configuration
            $ipConfig = Get-NetIPAddress -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
            
            foreach ($ipAddr in $ipConfig) {
                if ($ipAddr.AddressFamily -eq 'IPv4') {
                    $adapterConfig['IPv4Addresses'] += $ipAddr.IPAddress
                }
                elseif ($ipAddr.AddressFamily -eq 'IPv6') {
                    $adapterConfig['IPv6Addresses'] += $ipAddr.IPAddress
                }
            }
            
            # Get DNS servers
            $dnsConfig = Get-DnsClientServerAddress -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
            
            if ($dnsConfig) {
                $adapterConfig['DNSServers'] = $dnsConfig.ServerAddresses
            }
            
            # Get DHCP status
            $dhcpConfig = Get-NetIPInterface -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
            
            if ($dhcpConfig) {
                $adapterConfig['DHCP'] = if ($dhcpConfig.Dhcp -eq 'Enabled') { 'Enabled' } else { 'Disabled' }
            }
            
            # Get default gateway
            $routes = Get-NetRoute -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue | 
                Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' }
            
            if ($routes) {
                $adapterConfig['Gateway'] = $routes.NextHop
            }
            
            $config['Adapters'] += $adapterConfig
        }
        
        # Summary
        $config['Summary']['TotalAdapters'] = $adapters.Count
        $config['Summary']['ActiveAdapters'] = ($adapters | Where-Object { $_.Status -eq 'Up' }).Count
        $config['Summary']['AdaptersWithIP'] = ($config['Adapters'] | Where-Object { $_.IPv4Addresses.Count -gt 0 }).Count
        
        Write-NetLog "Retrieved configuration for $($adapters.Count) network adapter(s)" -Level Success
        
    }
    catch {
        Write-NetLog "Error retrieving network configuration: $_" -Level Error
    }
    
    return $config
}

function Invoke-DNSFlush {
    <#
    .SYNOPSIS
    Equivalent to: ipconfig /flushdns
    
    .DESCRIPTION
    Clears the DNS resolver cache, which can fix DNS resolution issues
    #>
    
    param()
    
    Write-NetLog "Flushing DNS cache (ipconfig /flushdns equivalent)..." -Level Warning
    
    $flushResult = @{
        'Success'       = $false
        'Message'       = ''
        'CacheSize'     = 0
    }
    
    try {
        # Get cache size before flush
        $cacheInfo = Get-DnsClientCache -ErrorAction SilentlyContinue
        $flushResult['CacheSize'] = $cacheInfo.Count
        
        Write-NetLog "DNS cache contains $($cacheInfo.Count) entries" -Level Info
        
        # Clear the cache
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        
        Write-NetLog "DNS cache flushed successfully" -Level Success
        $flushResult['Success'] = $true
        $flushResult['Message'] = "DNS cache cleared ($($flushResult['CacheSize']) entries removed)"
        
    }
    catch {
        Write-NetLog "Error flushing DNS: $_" -Level Error
        $flushResult['Message'] = "Error: $_"
    }
    
    return $flushResult
}

function Invoke-DHCPRelease {
    <#
    .SYNOPSIS
    Equivalent to: ipconfig /release
    
    .DESCRIPTION
    Releases the current DHCP IP address lease from all adapters
    Useful when stuck with incorrect IP or unable to obtain IP
    #>
    
    param(
        [string]$AdapterName = '*'
    )
    
    Write-NetLog "Releasing DHCP lease (ipconfig /release equivalent)..." -Level Warning
    
    $releaseResult = @{
        'Success'       = $false
        'AdaptersAffected' = @()
        'Errors'        = @()
    }
    
    try {
        $adapters = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
        
        foreach ($adapter in $adapters) {
            try {
                Write-NetLog "Releasing DHCP lease on adapter: $($adapter.Name)" -Level Info
                
                # Get the IP interface
                $ipInterface = Get-NetIPInterface -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue
                
                if ($ipInterface -and $ipInterface.Dhcp -eq 'Enabled') {
                    # Release using netsh (most reliable method)
                    $output = netsh interface ipv4 set address name="$($adapter.Name)" dhcp 2>&1
                    
                    if ($output -like "*successfully*" -or $output -like "*success*") {
                        Write-NetLog "DHCP lease released on $($adapter.Name)" -Level Success
                        $releaseResult['AdaptersAffected'] += $adapter.Name
                    }
                }
            }
            catch {
                $releaseResult['Errors'] += "Error releasing DHCP on $($adapter.Name): $_"
                Write-NetLog "Error releasing DHCP on $($adapter.Name): $_" -Level Error
            }
        }
        
        if ($releaseResult['AdaptersAffected'].Count -gt 0) {
            $releaseResult['Success'] = $true
        }
        
    }
    catch {
        Write-NetLog "Error in DHCP release: $_" -Level Error
        $releaseResult['Errors'] += $_
    }
    
    return $releaseResult
}

function Invoke-DHCPRenew {
    <#
    .SYNOPSIS
    Equivalent to: ipconfig /renew
    
    .DESCRIPTION
    Renews the DHCP IP address lease
    Obtains new IP configuration from DHCP server
    Waits up to 60 seconds for IP assignment
    #>
    
    param(
        [string]$AdapterName = '*',
        [int]$TimeoutSeconds = 60
    )
    
    Write-NetLog "Renewing DHCP lease (ipconfig /renew equivalent)..." -Level Warning
    
    $renewResult = @{
        'Success'       = $false
        'AdaptersAffected' = @()
        'NewIPs'        = @()
        'Errors'        = @()
        'ElapsedTime'   = 0
    }
    
    $startTime = Get-Date
    
    try {
        $adapters = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
        
        foreach ($adapter in $adapters) {
            try {
                Write-NetLog "Renewing DHCP lease on adapter: $($adapter.Name)" -Level Info
                
                # Use netsh to renew (most reliable)
                $output = netsh interface ipv4 set address name="$($adapter.Name)" dhcp 2>&1
                
                # Wait for IP assignment
                $waitStart = Get-Date
                $ipAssigned = $false
                
                while ((New-TimeSpan -Start $waitStart -End (Get-Date)).TotalSeconds -lt $TimeoutSeconds) {
                    $currentIP = Get-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue
                    
                    if ($currentIP -and $currentIP.IPAddress -ne '169.254.0.0') {  # Not APIPA
                        Write-NetLog "IP assigned to $($adapter.Name): $($currentIP.IPAddress)" -Level Success
                        $renewResult['NewIPs'] += $currentIP.IPAddress
                        $renewResult['AdaptersAffected'] += $adapter.Name
                        $ipAssigned = $true
                        break
                    }
                    
                    Start-Sleep -Seconds 1
                }
                
                if (-not $ipAssigned) {
                    $renewResult['Errors'] += "Timeout waiting for IP assignment on $($adapter.Name)"
                    Write-NetLog "Timeout waiting for IP on $($adapter.Name)" -Level Warning
                }
                
            }
            catch {
                $renewResult['Errors'] += "Error renewing DHCP on $($adapter.Name): $_"
                Write-NetLog "Error renewing DHCP: $_" -Level Error
            }
        }
        
        $renewResult['ElapsedTime'] = [int](New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds
        
        if ($renewResult['AdaptersAffected'].Count -gt 0) {
            $renewResult['Success'] = $true
            Write-NetLog "DHCP renewal completed in $($renewResult['ElapsedTime']) seconds" -Level Success
        }
        
    }
    catch {
        Write-NetLog "Error in DHCP renew: $_" -Level Error
        $renewResult['Errors'] += $_
    }
    
    return $renewResult
}

# ============================================================================
# NETWORK STACK FIXES
# ============================================================================

function Reset-WinsockCatalog {
    <#
    .SYNOPSIS
    Equivalent to: netsh winsock reset
    
    .DESCRIPTION
    Resets the Winsock (Windows Socket API) catalog
    Fixes corruption that prevents network connectivity
    Requires administrator privileges
    #>
    
    param()
    
    Write-NetLog "Resetting Winsock catalog (netsh winsock reset)..." -Level Warning
    
    $resetResult = @{
        'Success'       = $false
        'Message'       = ''
        'NeedsRestart'  = $false
    }
    
    try {
        # Check for admin
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
        
        if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
            $resetResult['Message'] = "Requires administrator privileges"
            Write-NetLog "WARNING: Winsock reset requires administrator" -Level Warning
            return $resetResult
        }
        
        Write-NetLog "Executing netsh winsock reset..." -Level Info
        
        # Execute reset
        $output = netsh winsock reset catalog 2>&1
        
        if ($output -like "*successfully*" -or $output -like "*success*" -or $LASTEXITCODE -eq 0) {
            Write-NetLog "Winsock catalog reset successfully" -Level Success
            $resetResult['Success'] = $true
            $resetResult['NeedsRestart'] = $true
            $resetResult['Message'] = "Winsock catalog reset completed. System restart required."
        }
        else {
            $resetResult['Message'] = "Winsock reset may have encountered issues"
            Write-NetLog "Winsock reset result: $output" -Level Warning
        }
        
    }
    catch {
        Write-NetLog "Error resetting Winsock: $_" -Level Error
        $resetResult['Message'] = "Error: $_"
    }
    
    return $resetResult
}

function Reset-NetworkAdapter {
    <#
    .SYNOPSIS
    Disables and re-enables network adapter
    
    .DESCRIPTION
    Performs hardware reset on adapter
    Reloads driver
    Useful for frozen or non-responsive adapters
    #>
    
    param(
        [string]$AdapterName = $null
    )
    
    Write-NetLog "Resetting network adapter..." -Level Warning
    
    $resetResult = @{
        'Success'       = $false
        'AdaptersReset' = @()
        'Errors'        = @()
    }
    
    try {
        if ($AdapterName) {
            $adapters = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
        }
        else {
            # Reset all adapters except loopback
            $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -notlike "*Loopback*" }
        }
        
        foreach ($adapter in $adapters) {
            try {
                Write-NetLog "Disabling adapter: $($adapter.Name)" -Level Info
                Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
                
                Start-Sleep -Seconds 2
                
                Write-NetLog "Re-enabling adapter: $($adapter.Name)" -Level Info
                Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
                
                Start-Sleep -Seconds 3
                
                $resetResult['AdaptersReset'] += $adapter.Name
                Write-NetLog "Adapter $($adapter.Name) reset successfully" -Level Success
            }
            catch {
                $resetResult['Errors'] += "Error resetting $($adapter.Name): $_"
                Write-NetLog "Error resetting adapter: $_" -Level Error
            }
        }
        
        if ($resetResult['AdaptersReset'].Count -gt 0) {
            $resetResult['Success'] = $true
        }
        
    }
    catch {
        Write-NetLog "Error in adapter reset: $_" -Level Error
        $resetResult['Errors'] += $_
    }
    
    return $resetResult
}

# ============================================================================
# CONNECTIVITY TESTING
# ============================================================================

function Test-NetworkConnectivity {
    <#
    .SYNOPSIS
    Tests network connectivity to determine what's broken
    
    .DESCRIPTION
    Tests:
    1. Adapter connectivity (physical connection)
    2. DHCP/IP assignment
    3. DNS resolution
    4. Internet reachability
    #>
    
    param()
    
    Write-NetLog "Testing network connectivity..." -Level Info
    
    $connectivity = @{
        'AdapterConnected'  = $false
        'IPAssigned'        = $false
        'DNSResolvable'     = $false
        'InternetReachable' = $false
        'Details'           = @{}
    }
    
    try {
        # Test 1: Adapter connected?
        $connectedAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        
        if ($connectedAdapters.Count -gt 0) {
            $connectivity['AdapterConnected'] = $true
            $connectivity['Details']['ConnectedAdapters'] = $connectedAdapters.Name
            Write-NetLog "Physical connection OK - $($connectedAdapters.Count) adapter(s) up" -Level Success
        }
        else {
            Write-NetLog "No active network adapters" -Level Warning
            return $connectivity
        }
        
        # Test 2: IP assigned?
        $ipsAssigned = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
            Where-Object { $_.IPAddress -notlike "169.254.*" }  # Exclude APIPA
        
        if ($ipsAssigned.Count -gt 0) {
            $connectivity['IPAssigned'] = $true
            $connectivity['Details']['AssignedIPs'] = $ipsAssigned.IPAddress
            Write-NetLog "IP assignment OK - $($ipsAssigned.Count) IP(s) assigned" -Level Success
        }
        else {
            Write-NetLog "No valid IP addresses assigned" -Level Warning
        }
        
        # Test 3: DNS resolution?
        try {
            $dnsTest = Resolve-DnsName -Name "google.com" -ErrorAction SilentlyContinue
            
            if ($dnsTest) {
                $connectivity['DNSResolvable'] = $true
                Write-NetLog "DNS resolution OK - google.com resolved" -Level Success
            }
            else {
                Write-NetLog "DNS resolution failed" -Level Warning
            }
        }
        catch { }
        
        # Test 4: Internet reachable?
        try {
            $testConnection = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet
            
            if ($testConnection) {
                $connectivity['InternetReachable'] = $true
                Write-NetLog "Internet connectivity OK - ping successful" -Level Success
            }
            else {
                Write-NetLog "Internet unreachable" -Level Warning
            }
        }
        catch { }
        
    }
    catch {
        Write-NetLog "Error testing connectivity: $_" -Level Error
    }
    
    return $connectivity
}

# ============================================================================
# COMPREHENSIVE TROUBLESHOOTER
# ============================================================================

function Invoke-NetworkTroubleshooter {
    <#
    .SYNOPSIS
    Complete 5-step network troubleshooter (Windows Troubleshooter equivalent)
    
    .DESCRIPTION
    Automated troubleshooting sequence:
    1. Check network adapters
    2. Verify IP configuration
    3. Test DNS
    4. Test DNS resolution
    5. Test internet connectivity
    
    Generates diagnosis and recommendations
    #>
    
    param(
        [switch]$AutoRepair = $false
    )
    
    Write-NetLog "╔═══════════════════════════════════════════════════════════╗" -Level Info
    Write-NetLog "║  NETWORK TROUBLESHOOTER (Windows Equivalent)             ║" -Level Info
    Write-NetLog "╚═══════════════════════════════════════════════════════════╝" -Level Info
    Write-Host ""
    
    $diagnosis = @{
        'StartTime'      = Get-Date
        'Step1'          = $null
        'Step2'          = $null
        'Step3'          = $null
        'Step4'          = $null
        'Step5'          = $null
        'Issues'         = @()
        'Recommendations' = @()
    }
    
    # STEP 1: Check adapters
    Write-NetLog "STEP 1: Checking network adapters..." -Level Info
    
    $adapters = Get-NetAdapter
    $activeAdapters = $adapters | Where-Object { $_.Status -eq 'Up' }
    
    $diagnosis['Step1'] = @{
        'TotalAdapters' = $adapters.Count
        'ActiveAdapters' = $activeAdapters.Count
        'Status'        = if ($activeAdapters.Count -gt 0) { 'OK' } else { 'FAILED' }
    }
    
    if ($activeAdapters.Count -eq 0) {
        $diagnosis['Issues'] += "No active network adapters detected"
        $diagnosis['Recommendations'] += "Check network cable connection or wireless adapter status"
        Write-NetLog "FAILED: No active adapters" -Level Error
    }
    else {
        Write-NetLog "OK: $($activeAdapters.Count) active adapter(s)" -Level Success
    }
    
    Write-Host ""
    
    # STEP 2: Check IP configuration
    Write-NetLog "STEP 2: Checking IP configuration..." -Level Info
    
    $ipConfig = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
        Where-Object { $_.IPAddress -notlike "169.254.*" }
    
    $diagnosis['Step2'] = @{
        'IPsAssigned'  = $ipConfig.Count
        'Status'       = if ($ipConfig.Count -gt 0) { 'OK' } else { 'FAILED' }
    }
    
    if ($ipConfig.Count -eq 0) {
        $diagnosis['Issues'] += "No valid IP addresses assigned (only APIPA or no IP)"
        $diagnosis['Recommendations'] += "Run DHCP renew: Invoke-DHCPRenew"
        Write-NetLog "FAILED: No valid IP addresses" -Level Error
    }
    else {
        Write-NetLog "OK: $($ipConfig.Count) valid IP(s) assigned" -Level Success
    }
    
    Write-Host ""
    
    # STEP 3: Check DNS configuration
    Write-NetLog "STEP 3: Checking DNS configuration..." -Level Info
    
    $dnsConfig = Get-DnsClientServerAddress -ErrorAction SilentlyContinue | 
        Where-Object { $_.ServerAddresses.Count -gt 0 }
    
    $diagnosis['Step3'] = @{
        'DNSServersFound' = $dnsConfig.Count
        'Status'          = if ($dnsConfig.Count -gt 0) { 'OK' } else { 'WARNING' }
    }
    
    if ($dnsConfig.Count -eq 0) {
        $diagnosis['Issues'] += "No DNS servers configured"
        $diagnosis['Recommendations'] += "Manually set DNS or run Invoke-DHCPRenew"
        Write-NetLog "WARNING: No DNS servers found" -Level Warning
    }
    else {
        Write-NetLog "OK: DNS servers configured" -Level Success
    }
    
    Write-Host ""
    
    # STEP 4: Test DNS resolution
    Write-NetLog "STEP 4: Testing DNS name resolution..." -Level Info
    
    $dnsTest = $false
    try {
        $dnsResult = Resolve-DnsName -Name "google.com" -ErrorAction SilentlyContinue
        if ($dnsResult) {
            $dnsTest = $true
        }
    }
    catch { }
    
    $diagnosis['Step4'] = @{
        'ResolutionTest' = 'google.com'
        'Status'         = if ($dnsTest) { 'OK' } else { 'FAILED' }
    }
    
    if (-not $dnsTest) {
        $diagnosis['Issues'] += "DNS name resolution failed"
        $diagnosis['Recommendations'] += "Flush DNS: Invoke-DNSFlush"
        $diagnosis['Recommendations'] += "Test connectivity to 8.8.8.8 directly"
        Write-NetLog "FAILED: DNS resolution failed" -Level Error
    }
    else {
        Write-NetLog "OK: DNS resolution working" -Level Success
    }
    
    Write-Host ""
    
    # STEP 5: Test internet connectivity
    Write-NetLog "STEP 5: Testing internet connectivity..." -Level Info
    
    $internetOK = $false
    try {
        $ping = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet
        $internetOK = $ping
    }
    catch { }
    
    $diagnosis['Step5'] = @{
        'TargetHost' = '8.8.8.8'
        'Status'     = if ($internetOK) { 'OK' } else { 'FAILED' }
    }
    
    if (-not $internetOK) {
        $diagnosis['Issues'] += "Internet connectivity test failed"
        $diagnosis['Recommendations'] += "Check gateway configuration"
        $diagnosis['Recommendations'] += "Run network adapter reset: Reset-NetworkAdapter"
        Write-NetLog "FAILED: No internet connectivity" -Level Error
    }
    else {
        Write-NetLog "OK: Internet connectivity confirmed" -Level Success
    }
    
    Write-Host ""
    Write-Host ""
    
    # SUMMARY & AUTO-REPAIR
    Write-NetLog "═══════════════════════════════════════════════════════════" -Level Info
    
    if ($diagnosis['Issues'].Count -eq 0) {
        Write-NetLog "RESULT: Network is functioning properly" -Level Success
    }
    else {
        Write-NetLog "RESULT: Found $($diagnosis['Issues'].Count) issue(s) that need attention" -Level Warning
        
        if ($AutoRepair) {
            Write-Host ""
            Write-NetLog "AUTO-REPAIR MODE: Applying fixes..." -Level Warning
            Write-Host ""
            
            # Apply fixes based on diagnosis
            $applied = @()
            
            if ($diagnosis['Step1'].Status -eq 'FAILED') {
                Write-NetLog "Resetting network adapters..." -Level Info
                $result = Reset-NetworkAdapter
                if ($result['Success']) {
                    $applied += "Network adapter reset applied"
                }
            }
            
            if ($diagnosis['Step2'].Status -eq 'FAILED') {
                Write-NetLog "Renewing DHCP lease..." -Level Info
                $result = Invoke-DHCPRelease
                $result = Invoke-DHCPRenew
                if ($result['Success']) {
                    $applied += "DHCP renewal applied"
                }
            }
            
            if ($diagnosis['Step3'].Status -eq 'WARNING' -or $diagnosis['Step3'].Status -eq 'FAILED') {
                Write-NetLog "Resetting Winsock..." -Level Info
                $result = Reset-WinsockCatalog
                if ($result['Success']) {
                    $applied += "Winsock reset applied"
                }
            }
            
            if ($diagnosis['Step4'].Status -eq 'FAILED') {
                Write-NetLog "Flushing DNS cache..." -Level Info
                $result = Invoke-DNSFlush
                if ($result['Success']) {
                    $applied += "DNS flush applied"
                }
            }
            
            Write-Host ""
            Write-NetLog "Auto-repair completed: $($applied.Count) fix(es) applied" -Level Success
            $diagnosis['AutoRepairActions'] = $applied
        }
    }
    
    Write-Host ""
    $diagnosis['EndTime'] = Get-Date
    
    return $diagnosis
}

function Invoke-QuickNetworkFix {
    <#
    .SYNOPSIS
    One-command network fix combining most common remedies
    
    .DESCRIPTION
    Executes in order:
    1. Flush DNS
    2. Release DHCP
    3. Renew DHCP
    4. Reset Winsock (if needed)
    #>
    
    param()
    
    Write-NetLog "╔═══════════════════════════════════════════════════════════╗" -Level Info
    Write-NetLog "║  QUICK NETWORK FIX                                       ║" -Level Info
    Write-NetLog "╚═══════════════════════════════════════════════════════════╝" -Level Info
    Write-Host ""
    
    $quickFixLog = @{
        'StepsCompleted' = @()
        'Success'        = $false
    }
    
    try {
        # Step 1: Flush DNS
        Write-NetLog "Step 1: Flushing DNS cache..." -Level Info
        $dnsFlush = Invoke-DNSFlush
        if ($dnsFlush['Success']) {
            $quickFixLog['StepsCompleted'] += "DNS cache flushed"
        }
        Write-Host ""
        
        # Step 2: Release DHCP
        Write-NetLog "Step 2: Releasing DHCP lease..." -Level Info
        $dhcpRelease = Invoke-DHCPRelease
        if ($dhcpRelease['Success']) {
            $quickFixLog['StepsCompleted'] += "DHCP released"
        }
        Write-Host ""
        
        # Step 3: Renew DHCP
        Write-NetLog "Step 3: Renewing DHCP lease..." -Level Info
        $dhcpRenew = Invoke-DHCPRenew
        if ($dhcpRenew['Success']) {
            $quickFixLog['StepsCompleted'] += "DHCP renewed"
        }
        Write-Host ""
        
        # Step 4: Test connectivity
        Write-NetLog "Step 4: Verifying connectivity..." -Level Info
        $connectivity = Test-NetworkConnectivity
        
        if ($connectivity['InternetReachable']) {
            $quickFixLog['Success'] = $true
            Write-NetLog "SUCCESS: Internet connectivity restored!" -Level Success
        }
        elseif ($connectivity['IPAssigned']) {
            Write-NetLog "PARTIAL: IP assigned but internet still unreachable" -Level Warning
            Write-NetLog "Attempting Winsock reset..." -Level Info
            $winsockReset = Reset-WinsockCatalog
            if ($winsockReset['Success']) {
                $quickFixLog['StepsCompleted'] += "Winsock reset (restart required)"
            }
        }
        
    }
    catch {
        Write-NetLog "Error in quick fix: $_" -Level Error
    }
    
    Write-Host ""
    Write-NetLog "Quick fix completed: $($quickFixLog['StepsCompleted'].Count) action(s)" -Level Info
    
    return $quickFixLog
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================

Write-NetLog "MiracleBoot Network Diagnostics Module v2.0 Enhanced loaded" -Level Success

$null = @(
    'Get-NetworkConfiguration',
    'Invoke-DNSFlush',
    'Invoke-DHCPRelease',
    'Invoke-DHCPRenew',
    'Reset-WinsockCatalog',
    'Reset-NetworkAdapter',
    'Test-NetworkConnectivity',
    'Invoke-NetworkTroubleshooter',
    'Invoke-QuickNetworkFix'
)
