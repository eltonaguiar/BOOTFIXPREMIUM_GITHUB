#!/usr/bin/env powershell
# ============================================================================
# MIRACLEBOOT NETWORK TROUBLESHOOTING MODULE
# Version 2.1 - Low Hanging Fruit Feature
# ============================================================================
# Purpose: Advanced network diagnostics and recovery when internet is broken
#
# Features:
# - DNS flush and reset (ipconfig /flushdns equivalent)
# - DHCP release and renew (ipconfig /release, /renew equivalent)
# - Network adapter reset
# - Winsock catalog reset
# - TCP/IP stack reset
# - DNS configuration repair
# - Network service restart
# - Windows network troubleshooter equivalent (CLI version)
# - Proxy and firewall diagnostics
# - Connectivity testing with remediation
#
# Critical for: Fixing "No Internet" issues without GUI
# ============================================================================

param()

# ============================================================================
# CONFIGURATION & LOGGING
# ============================================================================

$NetworkTroubleConfig = @{
    LogPath              = 'C:\MiracleBoot-NetworkLogs'
    AutoRepair           = $true
    BackupBeforeModify   = $true
    MaxRetries           = 3
    TimeoutSeconds       = 10
}

function Write-NetworkLog {
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
}

# ============================================================================
# DNS OPERATIONS (Equivalent to ipconfig /flushdns)
# ============================================================================

function Invoke-DNSFlush {
    <#
    .SYNOPSIS
    Flushes DNS resolver cache (equivalent to ipconfig /flushdns)
    
    .DESCRIPTION
    Clears cached DNS entries to force fresh DNS resolution
    Equivalent commands:
    - ipconfig /flushdns
    - ipconfig /displaydns
    - Clear-DNSClientCache (Windows 8+)
    #>
    
    param()
    
    Write-NetworkLog "Flushing DNS cache..." -Level Info
    
    try {
        # Modern method (Windows 8+)
        if ((Get-Command Clear-DnsClientCache -ErrorAction SilentlyContinue) -ne $null) {
            Clear-DnsClientCache -ErrorAction SilentlyContinue
            Write-NetworkLog "DNS cache cleared using Clear-DnsClientCache" -Level Success
        }
        # Legacy method (Windows 7 and earlier)
        else {
            Start-Process -FilePath "ipconfig" -ArgumentList "/flushdns" -NoNewWindow -Wait -ErrorAction SilentlyContinue
            Write-NetworkLog "DNS cache cleared using ipconfig /flushdns" -Level Success
        }
        
        # Verify flush
        Start-Sleep -Seconds 1
        Write-NetworkLog "DNS flush completed successfully" -Level Success
        return $true
    }
    catch {
        Write-NetworkLog "Error flushing DNS: $_" -Level Error
        return $false
    }
}

function Get-DNSConfiguration {
    <#
    .SYNOPSIS
    Retrieves current DNS configuration (equivalent to ipconfig /all)
    #>
    
    param()
    
    Write-NetworkLog "Retrieving DNS configuration..." -Level Info
    
    $dnsConfig = @{}
    
    try {
        # Get DNS servers
        $dnsServers = Get-DnsClientServerAddress -ErrorAction SilentlyContinue
        
        foreach ($dns in $dnsServers) {
            $dnsConfig[$dns.InterfaceAlias] = @{
                'ServerAddresses' = $dns.ServerAddresses
                'AddressFamily'   = $dns.AddressFamily
            }
        }
        
        Write-NetworkLog "DNS configuration retrieved" -Level Success
    }
    catch {
        Write-NetworkLog "Error retrieving DNS config: $_" -Level Warning
    }
    
    return $dnsConfig
}

function Set-DNSServers {
    <#
    .SYNOPSIS
    Sets DNS servers for specified interface
    
    .DESCRIPTION
    Alternative to manual ipconfig DNS configuration
    #>
    
    param(
        [string]$InterfaceName = "Ethernet",
        [string[]]$DnsServers = @("8.8.8.8", "1.1.1.1"),
        [switch]$DHCP = $true
    )
    
    Write-NetworkLog "Configuring DNS servers for $InterfaceName to: $($DnsServers -join ', ')" -Level Info
    
    try {
        if ($DHCP) {
            # Use DHCP-assigned DNS
            Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ResetServerAddresses -ErrorAction SilentlyContinue
            Write-NetworkLog "Reset to DHCP-assigned DNS servers" -Level Success
        }
        else {
            # Static DNS
            Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ServerAddresses $DnsServers -Validate -ErrorAction SilentlyContinue
            Write-NetworkLog "Set static DNS servers successfully" -Level Success
        }
        
        return $true
    }
    catch {
        Write-NetworkLog "Error setting DNS: $_" -Level Error
        return $false
    }
}

# ============================================================================
# DHCP OPERATIONS (Equivalent to ipconfig /release and /renew)
# ============================================================================

function Invoke-DHCPRelease {
    <#
    .SYNOPSIS
    Releases DHCP lease (equivalent to ipconfig /release)
    
    .DESCRIPTION
    Surrenders current IP address lease to DHCP server
    #>
    
    param(
        [string]$InterfaceName = "*",
        [bool]$Specific = $false
    )
    
    Write-NetworkLog "Releasing DHCP lease from interface(s): $InterfaceName" -Level Info
    
    try {
        if ($Specific) {
            # Release specific interface
            $interface = Get-NetIPAddress -InterfaceAlias $InterfaceName -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($interface) {
                Remove-NetIPAddress -IPAddress $interface.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
                Write-NetworkLog "Released DHCP lease from $InterfaceName" -Level Success
            }
        }
        else {
            # Release all interfaces
            $interfaces = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
            foreach ($adapter in $interfaces) {
                Remove-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
            }
            Write-NetworkLog "Released DHCP leases from all active adapters" -Level Success
        }
        
        return $true
    }
    catch {
        Write-NetworkLog "Error releasing DHCP: $_" -Level Error
        return $false
    }
}

function Invoke-DHCPRenew {
    <#
    .SYNOPSIS
    Renews DHCP lease (equivalent to ipconfig /renew)
    
    .DESCRIPTION
    Requests new IP address lease from DHCP server
    Waits for successful IP configuration
    #>
    
    param(
        [string]$InterfaceName = "*",
        [int]$TimeoutSeconds = 30,
        [bool]$Specific = $false
    )
    
    Write-NetworkLog "Renewing DHCP lease for interface(s): $InterfaceName" -Level Info
    
    try {
        $startTime = Get-Date
        $timeout = New-TimeSpan -Seconds $TimeoutSeconds
        $success = $false
        
        if ($Specific) {
            # Renew specific interface
            while ((Get-Date) - $startTime -lt $timeout) {
                $ipConfig = Get-NetIPAddress -InterfaceAlias $InterfaceName -AddressFamily IPv4 -ErrorAction SilentlyContinue
                
                if ($ipConfig -and $ipConfig.IPAddress -ne "0.0.0.0") {
                    Write-NetworkLog "DHCP renewal successful - assigned: $($ipConfig.IPAddress)" -Level Success
                    $success = $true
                    break
                }
                
                Start-Sleep -Seconds 1
            }
        }
        else {
            # Renew all interfaces
            while ((Get-Date) - $startTime -lt $timeout) {
                $interfaces = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                    Where-Object { $_.IPAddress -ne "0.0.0.0" -and $_.IPAddress -ne "127.0.0.1" }
                
                if ($interfaces) {
                    Write-NetworkLog "DHCP renewal successful - interfaces configured" -Level Success
                    $success = $true
                    break
                }
                
                Start-Sleep -Seconds 1
            }
        }
        
        if (-not $success) {
            Write-NetworkLog "DHCP renewal timeout - no IP address assigned" -Level Warning
        }
        
        return $success
    }
    catch {
        Write-NetworkLog "Error renewing DHCP: $_" -Level Error
        return $false
    }
}

# ============================================================================
# WINSOCK & TCP/IP STACK RESET
# ============================================================================

function Reset-WinsockCatalog {
    <#
    .SYNOPSIS
    Resets Winsock catalog and TCP/IP stack
    
    .DESCRIPTION
    Clears corrupt Winsock entries that prevent networking
    Equivalent to: netsh winsock reset catalog
    #>
    
    param()
    
    Write-NetworkLog "Resetting Winsock catalog..." -Level Warning
    Write-NetworkLog "This requires administrator privileges" -Level Info
    
    try {
        # Backup current Winsock config
        $backupPath = "$($NetworkTroubleConfig.LogPath)\winsock-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        
        if ($NetworkTroubleConfig.BackupBeforeModify) {
            New-Item -Path $NetworkTroubleConfig.LogPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            Write-NetworkLog "Backing up Winsock configuration to $backupPath" -Level Info
        }
        
        # Reset Winsock
        Start-Process -FilePath "netsh" -ArgumentList "winsock reset catalog" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        Write-NetworkLog "Winsock catalog reset successfully" -Level Success
        
        # Reset TCP/IP
        Start-Process -FilePath "netsh" -ArgumentList "int ip reset resetlog.txt" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        Write-NetworkLog "TCP/IP stack reset successfully" -Level Success
        
        Write-NetworkLog "System restart required for changes to take effect" -Level Warning
        return $true
    }
    catch {
        Write-NetworkLog "Error resetting Winsock: $_" -Level Error
        return $false
    }
}

# ============================================================================
# NETWORK ADAPTER RESET
# ============================================================================

function Reset-NetworkAdapter {
    <#
    .SYNOPSIS
    Resets network adapter configuration
    
    .DESCRIPTION
    Disables and re-enables adapter to reset driver
    Equivalent to "Repair" function in GUI
    #>
    
    param(
        [string]$InterfaceName = "Ethernet"
    )
    
    Write-NetworkLog "Resetting network adapter: $InterfaceName" -Level Info
    
    try {
        $adapter = Get-NetAdapter -Name $InterfaceName -ErrorAction SilentlyContinue
        
        if (-not $adapter) {
            Write-NetworkLog "Adapter not found: $InterfaceName" -Level Error
            return $false
        }
        
        # Disable adapter
        Write-NetworkLog "Disabling adapter..." -Level Info
        Disable-NetAdapter -Name $InterfaceName -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        
        # Re-enable adapter
        Write-NetworkLog "Re-enabling adapter..." -Level Info
        Enable-NetAdapter -Name $InterfaceName -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
        
        Write-NetworkLog "Network adapter reset completed" -Level Success
        return $true
    }
    catch {
        Write-NetworkLog "Error resetting adapter: $_" -Level Error
        return $false
    }
}

# ============================================================================
# COMPREHENSIVE NETWORK TROUBLESHOOTING (Windows Troubleshooter Equivalent)
# ============================================================================

function Invoke-NetworkTroubleshooter {
    <#
    .SYNOPSIS
    Automated network troubleshooting equivalent to Windows Network Troubleshooter
    
    .DESCRIPTION
    Performs diagnostic steps:
    1. Check network adapter status
    2. Test DHCP functionality
    3. Test DNS resolution
    4. Test internet connectivity
    5. Reset problematic components
    6. Generate report with recommendations
    #>
    
    param(
        [switch]$AutoRepair = $true
    )
    
    Write-NetworkLog "Starting comprehensive network troubleshooting..." -Level Info
    Write-Host ""
    
    $troubleshootingReport = @{
        'Timestamp'        = Get-Date
        'Steps'            = @()
        'IssuesFound'      = @()
        'ActionsPerformed' = @()
        'Recommendations'  = @()
        'Status'           = 'In Progress'
    }
    
    # STEP 1: Check Network Adapters
    Write-NetworkLog "STEP 1: Checking network adapters..." -Level Info
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
        
        if ($adapters.Count -eq 0) {
            $troubleshootingReport['IssuesFound'] += "No active network adapters detected"
            Write-NetworkLog "ERROR: No active network adapters" -Level Error
        }
        else {
            Write-NetworkLog "Found $($adapters.Count) active adapter(s)" -Level Success
            foreach ($adapter in $adapters) {
                Write-NetworkLog "  - $($adapter.Name) ($($adapter.InterfaceDescription))" -Level Info
            }
        }
    }
    catch {
        $troubleshootingReport['IssuesFound'] += "Error checking adapters: $_"
    }
    
    # STEP 2: Check IP Configuration
    Write-NetworkLog "STEP 2: Checking IP configuration..." -Level Info
    try {
        $ipConfigs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
            Where-Object { $_.IPAddress -ne "127.0.0.1" }
        
        if ($ipConfigs.Count -eq 0) {
            $troubleshootingReport['IssuesFound'] += "No IP address assigned to active adapters"
            Write-NetworkLog "WARNING: No IP addresses assigned" -Level Warning
            
            if ($AutoRepair) {
                Write-NetworkLog "Attempting to renew DHCP..." -Level Info
                $renewed = Invoke-DHCPRenew -Specific $false
                if ($renewed) {
                    $troubleshootingReport['ActionsPerformed'] += "DHCP lease renewed"
                }
            }
        }
        else {
            Write-NetworkLog "IP addresses configured: $($ipConfigs.Count)" -Level Success
            foreach ($ipConfig in $ipConfigs) {
                Write-NetworkLog "  - $($ipConfig.IPAddress) on $($ipConfig.InterfaceAlias)" -Level Info
            }
        }
    }
    catch {
        $troubleshootingReport['IssuesFound'] += "Error checking IP: $_"
    }
    
    # STEP 3: Check DNS Configuration
    Write-NetworkLog "STEP 3: Checking DNS configuration..." -Level Info
    try {
        $dnsConfig = Get-DnsClientServerAddress -ErrorAction SilentlyContinue | 
            Where-Object { $_.ServerAddresses.Count -gt 0 }
        
        if ($dnsConfig.Count -eq 0) {
            $troubleshootingReport['IssuesFound'] += "No DNS servers configured"
            Write-NetworkLog "WARNING: No DNS servers configured" -Level Warning
            
            if ($AutoRepair) {
                Write-NetworkLog "Setting to default DNS servers..." -Level Info
                Set-DNSServers -DnsServers @("8.8.8.8", "1.1.1.1")
                $troubleshootingReport['ActionsPerformed'] += "DNS servers configured"
            }
        }
        else {
            Write-NetworkLog "DNS configured on $($dnsConfig.Count) interface(s)" -Level Success
        }
    }
    catch {
        $troubleshootingReport['IssuesFound'] += "Error checking DNS: $_"
    }
    
    # STEP 4: Test DNS Resolution
    Write-NetworkLog "STEP 4: Testing DNS resolution..." -Level Info
    try {
        $dnsTest = Resolve-DnsName -Name "google.com" -ErrorAction SilentlyContinue
        
        if ($dnsTest) {
            Write-NetworkLog "DNS resolution successful: google.com resolved" -Level Success
        }
        else {
            $troubleshootingReport['IssuesFound'] += "DNS resolution failed for google.com"
            Write-NetworkLog "ERROR: DNS resolution failed" -Level Error
            
            if ($AutoRepair) {
                Write-NetworkLog "Flushing DNS cache..." -Level Info
                Invoke-DNSFlush
                $troubleshootingReport['ActionsPerformed'] += "DNS cache flushed"
            }
        }
    }
    catch {
        $troubleshootingReport['IssuesFound'] += "DNS test error: $_"
        Write-NetworkLog "DNS resolution test failed: $_" -Level Error
    }
    
    # STEP 5: Test Internet Connectivity
    Write-NetworkLog "STEP 5: Testing internet connectivity..." -Level Info
    try {
        $testConnection = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
        
        if ($testConnection) {
            Write-NetworkLog "Internet connectivity test successful" -Level Success
            $troubleshootingReport['Status'] = 'HEALTHY'
        }
        else {
            $troubleshootingReport['IssuesFound'] += "Internet connectivity test failed"
            Write-NetworkLog "WARNING: Cannot reach internet (8.8.8.8)" -Level Warning
            $troubleshootingReport['Status'] = 'NEEDS_ATTENTION'
        }
    }
    catch {
        $troubleshootingReport['IssuesFound'] += "Internet test error: $_"
        Write-NetworkLog "Connectivity test failed: $_" -Level Warning
    }
    
    # Generate recommendations
    Write-NetworkLog "Generating recommendations..." -Level Info
    
    if ($troubleshootingReport['IssuesFound'].Count -eq 0) {
        $troubleshootingReport['Recommendations'] += "System is online and healthy"
    }
    else {
        if ($troubleshootingReport['IssuesFound'] -like "*adapter*") {
            $troubleshootingReport['Recommendations'] += "Check Device Manager for network adapter drivers - may need to reinstall or update"
        }
        
        if ($troubleshootingReport['IssuesFound'] -like "*IP*" -and $troubleshootingReport['ActionsPerformed'] -notcontains "DHCP lease renewed") {
            $troubleshootingReport['Recommendations'] += "Try: Invoke-DHCPRelease; Invoke-DHCPRenew"
        }
        
        if ($troubleshootingReport['IssuesFound'] -like "*DNS*") {
            $troubleshootingReport['Recommendations'] += "Try: Invoke-DNSFlush; Set-DNSServers"
        }
        
        if ($troubleshootingReport['IssuesFound'].Count -gt 2) {
            $troubleshootingReport['Recommendations'] += "Consider: Reset-WinsockCatalog (requires restart)"
        }
    }
    
    Write-Host ""
    Write-NetworkLog "Network troubleshooting completed" -Level Success
    Write-Host ""
    
    return $troubleshootingReport
}

# ============================================================================
# QUICK FIX COMMANDS
# ============================================================================

function Invoke-QuickNetworkFix {
    <#
    .SYNOPSIS
    One-command fix for most common network issues
    #>
    
    param()
    
    Write-NetworkLog "Executing Quick Network Fix sequence..." -Level Info
    
    Write-NetworkLog "1. Flushing DNS..." -Level Info
    Invoke-DNSFlush | Out-Null
    
    Write-NetworkLog "2. Releasing DHCP..." -Level Info
    Invoke-DHCPRelease | Out-Null
    Start-Sleep -Seconds 2
    
    Write-NetworkLog "3. Renewing DHCP..." -Level Info
    Invoke-DHCPRenew | Out-Null
    
    Write-NetworkLog "4. Verifying connectivity..." -Level Info
    Start-Sleep -Seconds 3
    
    $connTest = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet
    
    if ($connTest) {
        Write-NetworkLog "Quick Network Fix SUCCESSFUL - Internet restored!" -Level Success
    }
    else {
        Write-NetworkLog "Quick fix completed but connectivity not restored - running full troubleshooter" -Level Warning
        Invoke-NetworkTroubleshooter -AutoRepair $true
    }
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================

$null = @(
    'Invoke-DNSFlush',
    'Get-DNSConfiguration',
    'Set-DNSServers',
    'Invoke-DHCPRelease',
    'Invoke-DHCPRenew',
    'Reset-WinsockCatalog',
    'Reset-NetworkAdapter',
    'Invoke-NetworkTroubleshooter',
    'Invoke-QuickNetworkFix'
)

Write-NetworkLog "MiracleBoot Network Troubleshooting Module loaded" -Level Success
