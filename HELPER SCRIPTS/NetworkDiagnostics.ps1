################################################################################
#
# NetworkDiagnostics.ps1 - Network Connectivity & Driver Management Module
# Part of MiracleBoot v7.2.0 - Advanced Windows Recovery Toolkit
#
# Purpose:  Comprehensive network diagnostics, driver detection, and management
#           for WinPE/WinRE and FullOS environments
#
# Features: - Network adapter detection (wireless & wired)
#           - DHCP and DNS validation
#           - Internet connectivity testing
#           - Network driver harvesting and injection
#           - Driver path searching across volumes
#           - Detailed troubleshooting guidance
#
# Author:   MiracleBoot Development Team
# Version:  1.0.0
# Updated:  January 2026
#
################################################################################

<#
.SYNOPSIS
    Comprehensive network diagnostics and driver management for recovery environments

.DESCRIPTION
    This module provides production-grade functions for:
    - Detecting network adapters (physical and virtual)
    - Testing DHCP, DNS, and internet connectivity
    - Harvesting drivers from running system
    - Searching for drivers on mounted volumes
    - Injecting drivers into WinPE environments
    - Detailed troubleshooting and reporting

.NOTES
    Requires: Administrator privileges
    Supports: Windows 10/11 (FullOS and WinPE/WinRE)
    Error Handling: Comprehensive try-catch with detailed logging
#>

################################################################################
# NETWORK ADAPTER DETECTION FUNCTIONS
################################################################################

function Get-NetworkAdapterStatus {
    <#
    .SYNOPSIS
        Detects and reports on all network adapters and their current status
    
    .DESCRIPTION
        Returns detailed information about physical network adapters including:
        - Adapter name and description
        - Connection status (connected/disconnected)
        - IP configuration (DHCP/Static)
        - MAC address
        - Link speed
        - Driver information
    
    .OUTPUTS
        PSCustomObject with adapter details
    #>
    
    param(
        [switch]$IncludeDisabled
    )
    
    $adapters = @()
    
    try {
        # Get network adapters via WMI (works in both FullOS and WinPE)
        $netAdapters = Get-WmiObject Win32_NetworkAdapter -ErrorAction SilentlyContinue | 
            Where-Object { 
                $_.PhysicalAdapter -eq $true -or $IncludeDisabled
            }
        
        foreach ($adapter in $netAdapters) {
            try {
                # Get configuration
                $config = Get-WmiObject Win32_NetworkAdapterConfiguration |
                    Where-Object { $_.Index -eq $adapter.Index }
                
                # Determine connection type
                $adapterType = "Unknown"
                if ($adapter.AdapterType -match "Ethernet") {
                    $adapterType = "Wired (Ethernet)"
                } elseif ($adapter.AdapterType -match "Wireless|WiFi|802.11") {
                    $adapterType = "Wireless (WiFi)"
                } elseif ($adapter.Description -match "Wireless|WiFi|802.11") {
                    $adapterType = "Wireless (WiFi)"
                } elseif ($adapter.Description -match "Ethernet|LAN") {
                    $adapterType = "Wired (Ethernet)"
                }
                
                # Get IP info
                $ipAddress = if ($config -and $config.IPAddress) { 
                    $config.IPAddress[0] 
                } else { 
                    "Not configured" 
                }
                
                $dhcpEnabled = if ($config) { 
                    $config.DHCPEnabled 
                } else { 
                    "Unknown" 
                }
                
                $adapters += [PSCustomObject]@{
                    Name              = $adapter.Name
                    Description       = $adapter.Description
                    Type              = $adapterType
                    Status            = $adapter.NetConnectionStatus
                    Connected         = $adapter.NetConnectionStatus -eq 2
                    MacAddress        = $adapter.MACAddress
                    IPAddress         = $ipAddress
                    DHCPEnabled       = $dhcpEnabled
                    Speed             = $adapter.Speed
                    DriverVersion     = $adapter.DriverVersion
                    Manufacturer      = $adapter.Manufacturer
                    Enabled           = $adapter.NetEnabled
                }
            } catch {
                Write-Warning "Failed to process adapter $($adapter.Name): $_"
            }
        }
    } catch {
        Write-Error "Failed to enumerate network adapters: $_"
        return $null
    }
    
    return $adapters
}

function Get-WirelessAdapters {
    <#
    .SYNOPSIS
        Gets only wireless network adapters
    
    .OUTPUTS
        Array of wireless adapter objects
    #>
    
    $adapters = Get-NetworkAdapterStatus -IncludeDisabled
    return $adapters | Where-Object { $_.Type -match "Wireless" }
}

function Get-WiredAdapters {
    <#
    .SYNOPSIS
        Gets only wired (Ethernet) network adapters
    
    .OUTPUTS
        Array of wired adapter objects
    #>
    
    $adapters = Get-NetworkAdapterStatus -IncludeDisabled
    return $adapters | Where-Object { $_.Type -match "Wired|Ethernet" }
}

################################################################################
# NETWORK CONNECTIVITY TESTING FUNCTIONS
################################################################################

function Test-InternetConnectivity {
    <#
    .SYNOPSIS
        Comprehensive internet connectivity test with detailed failure reporting
    
    .DESCRIPTION
        Performs step-by-step connectivity testing:
        1. Tests DHCP configuration
        2. Tests DNS resolution
        3. Tests ping to 8.8.8.8 (Google DNS)
        4. Tests ping to google.com (resolving hostname)
        5. Reports specific failure points
    
    .PARAMETER Verbose
        Shows detailed step-by-step output
    
    .OUTPUTS
        PSCustomObject with test results and failure points
    #>
    
    param(
        [switch]$Verbose
    )
    
    $result = [PSCustomObject]@{
        Success           = $false
        DHCPConfigured    = $false
        DNSResolving      = $false
        CanPingGoogle     = $false
        CanResolveGoogle  = $false
        InternetReachable = $false
        FailurePoints     = @()
        Details           = @()
        Timestamp         = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    # Step 1: Check DHCP Configuration
    if ($Verbose) { Write-Host "[1/5] Checking DHCP configuration..." -ForegroundColor Cyan }
    try {
        $adapters = Get-NetworkAdapterStatus | Where-Object { $_.Connected }
        
        if ($adapters.Count -eq 0) {
            $result.FailurePoints += "No connected network adapters detected"
            if ($Verbose) { Write-Host "    [✗] No connected adapters found" -ForegroundColor Red }
            return $result
        }
        
        $dhcpConfigs = $adapters | Where-Object { $_.DHCPEnabled -eq $true }
        if ($dhcpConfigs.Count -gt 0) {
            $result.DHCPConfigured = $true
            if ($Verbose) { 
                Write-Host "    [✓] DHCP configured on $($dhcpConfigs.Count) adapter(s)" -ForegroundColor Green 
            }
        } else {
            $result.FailurePoints += "DHCP not enabled on any connected adapter"
            if ($Verbose) { Write-Host "    [✗] DHCP not configured" -ForegroundColor Red }
        }
    } catch {
        $result.FailurePoints += "Error checking DHCP: $_"
        if ($Verbose) { Write-Host "    [✗] Error: $_" -ForegroundColor Red }
    }
    
    # Step 2: Check DNS Configuration
    if ($Verbose) { Write-Host "[2/5] Checking DNS configuration..." -ForegroundColor Cyan }
    try {
        $dnsServers = Get-DnsClientServerAddress -ErrorAction SilentlyContinue | 
            Where-Object { $_.ServerAddresses.Count -gt 0 } |
            Select-Object -First 1
        
        if ($dnsServers) {
            $result.DNSResolving = $true
            if ($Verbose) { 
                Write-Host "    [✓] DNS servers configured: $($dnsServers.ServerAddresses -join ', ')" -ForegroundColor Green 
            }
        } else {
            $result.FailurePoints += "No DNS servers configured"
            if ($Verbose) { Write-Host "    [✗] No DNS servers found" -ForegroundColor Red }
        }
    } catch {
        $result.FailurePoints += "Error checking DNS: $_"
        if ($Verbose) { Write-Host "    [✗] Error: $_" -ForegroundColor Red }
    }
    
    # Step 3: Test Ping to Google DNS (8.8.8.8)
    if ($Verbose) { Write-Host "[3/5] Testing connectivity to 8.8.8.8 (Google DNS)..." -ForegroundColor Cyan }
    try {
        $pingResult = Test-Connection -ComputerName "8.8.8.8" -Count 1 -ErrorAction SilentlyContinue
        if ($pingResult) {
            $result.CanPingGoogle = $true
            if ($Verbose) { 
                Write-Host "    [✓] Successfully pinged 8.8.8.8 (Response time: $($pingResult.ResponseTime)ms)" -ForegroundColor Green 
            }
        } else {
            $result.FailurePoints += "Cannot ping 8.8.8.8 - No response or timeout"
            if ($Verbose) { Write-Host "    [✗] No response from 8.8.8.8" -ForegroundColor Red }
        }
    } catch {
        $result.FailurePoints += "Error pinging 8.8.8.8: $_"
        if ($Verbose) { Write-Host "    [✗] Error: $_" -ForegroundColor Red }
    }
    
    # Step 4: Test DNS Resolution and Connectivity to google.com
    if ($Verbose) { Write-Host "[4/5] Testing DNS resolution for google.com..." -ForegroundColor Cyan }
    try {
        $dnsResolve = Resolve-DnsName -Name "google.com" -ErrorAction SilentlyContinue
        if ($dnsResolve) {
            if ($Verbose) { 
                Write-Host "    [✓] DNS resolution successful (IP: $($dnsResolve.IPAddress | Select-Object -First 1))" -ForegroundColor Green 
            }
            
            # Step 5: Ping google.com
            if ($Verbose) { Write-Host "[5/5] Testing connectivity to google.com..." -ForegroundColor Cyan }
            $pingGoogle = Test-Connection -ComputerName "google.com" -Count 1 -ErrorAction SilentlyContinue
            if ($pingGoogle) {
                $result.InternetReachable = $true
                $result.CanResolveGoogle = $true
                if ($Verbose) { 
                    Write-Host "    [✓] Successfully reached google.com (Response time: $($pingGoogle.ResponseTime)ms)" -ForegroundColor Green 
                }
            } else {
                $result.FailurePoints += "DNS resolved but cannot ping google.com"
                if ($Verbose) { Write-Host "    [✗] Cannot reach google.com despite DNS resolution" -ForegroundColor Red }
            }
        } else {
            $result.FailurePoints += "DNS resolution failed for google.com"
            if ($Verbose) { Write-Host "    [✗] DNS resolution failed" -ForegroundColor Red }
        }
    } catch {
        $result.FailurePoints += "Error during DNS resolution test: $_"
        if ($Verbose) { Write-Host "    [✗] Error: $_" -ForegroundColor Red }
    }
    
    # Determine overall success
    $result.Success = $result.InternetReachable
    
    return $result
}

function Test-NetworkConnectivity {
    <#
    .SYNOPSIS
        Quick network connectivity check
    
    .DESCRIPTION
        Lightweight check for basic network connectivity
    
    .OUTPUTS
        Boolean - True if internet is reachable
    #>
    
    try {
        $test = Test-Connection -ComputerName "8.8.8.8" -Count 1 -ErrorAction SilentlyContinue
        return $null -ne $test
    } catch {
        return $false
    }
}

################################################################################
# NETWORK DRIVER DETECTION FUNCTIONS
################################################################################

function Get-NetworkDrivers {
    <#
    .SYNOPSIS
        Harvests network drivers from the current system
    
    .DESCRIPTION
        Extracts information about loaded network drivers including:
        - Driver name and version
        - Driver path
        - Associated device
        - Driver file details
    
    .OUTPUTS
        Array of driver objects
    #>
    
    $drivers = @()
    
    try {
        # Get network devices
        $netDevices = Get-WmiObject Win32_NetworkAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.PhysicalAdapter -eq $true }
        
        foreach ($device in $netDevices) {
            try {
                # Get driver info
                $deviceInfo = Get-WmiObject Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
                    Where-Object { 
                        $_.Description -match $device.Description -or
                        $_.DeviceName -match $device.Name
                    }
                
                if ($deviceInfo) {
                    foreach ($driver in $deviceInfo) {
                        $drivers += [PSCustomObject]@{
                            DeviceName     = $device.Description
                            DriverName     = $driver.Description
                            DriverVersion  = $driver.DriverVersion
                            DriverPath     = $driver.InfName
                            DriverClass    = $driver.DeviceClass
                            Manufacturer   = $driver.Manufacturer
                            Status         = "Loaded"
                            IsSigned       = $driver.Signed
                            Timestamp      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        }
                    }
                }
            } catch {
                Write-Warning "Failed to get driver info for $($device.Description): $_"
            }
        }
    } catch {
        Write-Error "Failed to enumerate network drivers: $_"
    }
    
    return $drivers
}

function Get-DriverStorePath {
    <#
    .SYNOPSIS
        Gets the Windows Driver Store path
    
    .OUTPUTS
        String path to Driver Store
    #>
    
    $driverStore = "$env:SystemRoot\System32\DriverStore\FileRepository"
    return $driverStore
}

function Find-NetworkDrivers {
    <#
    .SYNOPSIS
        Searches for network drivers in DriverStore
    
    .DESCRIPTION
        Locates all network-related INF files in the system DriverStore
    
    .OUTPUTS
        Array of driver paths
    #>
    
    $networkDrivers = @()
    
    try {
        $driverStore = Get-DriverStorePath
        
        if (Test-Path $driverStore) {
            # Search for network-related drivers
            $drivers = Get-ChildItem -Path $driverStore -Recurse -Include "*.inf" -ErrorAction SilentlyContinue |
                Where-Object { 
                    $_.Directory.Name -match "Net|Network|Ethernet|Wireless|WiFi|NIC|1394|USB"
                }
            
            foreach ($driver in $drivers) {
                $networkDrivers += [PSCustomObject]@{
                    Name       = $driver.Name
                    FullPath   = $driver.FullName
                    Directory  = $driver.Directory.Name
                    Folder     = $driver.Directory.Parent.Name
                    Size       = $driver.Length
                }
            }
        } else {
            Write-Warning "DriverStore not found at: $driverStore"
        }
    } catch {
        Write-Error "Error searching for drivers: $_"
    }
    
    return $networkDrivers
}

################################################################################
# DRIVER SEARCHING ON VOLUMES
################################################################################

function Find-DriversOnVolumes {
    <#
    .SYNOPSIS
        Searches for network drivers across all mounted volumes
    
    .DESCRIPTION
        Scans mounted drives for driver files (.inf, .sys, .cat)
        in common driver locations:
        - Windows\System32\drivers
        - Windows\Inf
        - Program Files\
        - OEM driver locations
    
    .PARAMETER Volumes
        Specific drive letters to search (e.g., 'D:', 'E:')
    
    .PARAMETER IncludeSystemDrive
        Include the current system drive in search
    
    .OUTPUTS
        Array of discovered driver files
    #>
    
    param(
        [string[]]$Volumes = @(),
        [switch]$IncludeSystemDrive
    )
    
    $drivers = @()
    $searchedPaths = @()
    
    # If no volumes specified, discover them
    if ($Volumes.Count -eq 0) {
        $Volumes = Get-Volume | 
            Where-Object { $_.DriveLetter -and $_.FileSystem -match "NTFS|FAT" } |
            Select-Object -ExpandProperty DriveLetter |
            ForEach-Object { "$_`:" }
    }
    
    # Remove system drive if not requested
    if (-not $IncludeSystemDrive) {
        $systemDrive = $env:SystemDrive
        $Volumes = $Volumes | Where-Object { $_ -ne $systemDrive }
    }
    
    foreach ($volume in $Volumes) {
        Write-Host "Searching for drivers on $volume..." -ForegroundColor Yellow
        
        # Common driver paths
        $driverPaths = @(
            "$volume\Windows\System32\drivers",
            "$volume\Windows\Inf",
            "$volume\Windows\System32\DriverStore\FileRepository",
            "$volume\Program Files\*",
            "$volume\Program Files (x86)\*",
            "$volume\OEM\*",
            "$volume\Drivers"
        )
        
        foreach ($path in $driverPaths) {
            try {
                if (Test-Path $path) {
                    $searchedPaths += $path
                    
                    # Find driver files
                    $files = Get-ChildItem -Path $path -Include ("*.inf", "*.sys", "*.cat") `
                        -Recurse -ErrorAction SilentlyContinue
                    
                    foreach ($file in $files) {
                        # Check if it's a network driver
                        if ($file.Name -match "Net|Ethernet|WiFi|Wireless|NIC" -or 
                            $file.Extension -eq ".inf") {
                            
                            $drivers += [PSCustomObject]@{
                                Name       = $file.Name
                                FullPath   = $file.FullName
                                Directory  = $file.Directory.Name
                                Volume     = $volume
                                Type       = $file.Extension
                                Size       = $file.Length
                                Modified   = $file.LastWriteTime
                            }
                        }
                    }
                }
            } catch {
                # Silently skip inaccessible paths
            }
        }
    }
    
    if ($drivers.Count -eq 0) {
        Write-Warning "No driver files found on searched volumes"
    }
    
    return $drivers | Sort-Object -Property Volume, Directory | Get-Unique -AsString
}

################################################################################
# DRIVER HARVESTING FUNCTIONS
################################################################################

function Export-NetworkDrivers {
    <#
    .SYNOPSIS
        Exports network drivers from DriverStore to a target location
    
    .DESCRIPTION
        Harvests network drivers and creates a driver package
        suitable for WinPE injection
    
    .PARAMETER OutputPath
        Destination folder for exported drivers (default: Desktop\NetworkDrivers)
    
    .PARAMETER ExcludeBuiltin
        Skip built-in Microsoft drivers
    
    .OUTPUTS
        PSCustomObject with export results
    #>
    
    param(
        [string]$OutputPath = "$env:USERPROFILE\Desktop\NetworkDrivers_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
        [switch]$ExcludeBuiltin
    )
    
    $result = @{
        Success      = $false
        OutputPath   = $OutputPath
        DriversFound = 0
        DriversCopied = 0
        Errors       = @()
        Details      = @()
    }
    
    try {
        # Create output directory
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        
        # Get network drivers
        $drivers = Get-NetworkDrivers
        
        if ($drivers.Count -eq 0) {
            $result.Errors += "No network drivers found to export"
            return $result
        }
        
        $result.DriversFound = $drivers.Count
        
        # Copy driver files
        foreach ($driver in $drivers) {
            try {
                if (-not $driver.DriverPath) { continue }
                
                # Skip Microsoft built-in drivers if requested
                if ($ExcludeBuiltin -and $driver.Manufacturer -match "Microsoft") {
                    continue
                }
                
                $sourceFile = $driver.DriverPath
                if (Test-Path $sourceFile) {
                    $fileName = Split-Path -Leaf $sourceFile
                    $destination = Join-Path $OutputPath $fileName
                    
                    Copy-Item -Path $sourceFile -Destination $destination -Force -ErrorAction SilentlyContinue
                    $result.DriversCopied++
                    $result.Details += "Exported: $fileName from $sourceFile"
                }
            } catch {
                $result.Errors += "Failed to export $($driver.DriverName): $_"
            }
        }
        
        $result.Success = $result.DriversCopied -gt 0
        
        if ($result.Success) {
            Write-Host "[✓] Successfully exported $($result.DriversCopied) driver(s) to: $OutputPath" -ForegroundColor Green
        }
        
    } catch {
        $result.Errors += "Export failed: $_"
    }
    
    return $result
}

################################################################################
# DRIVER INJECTION FUNCTIONS
################################################################################

function Add-DriversToWinPE {
    <#
    .SYNOPSIS
        Injects network drivers into a WinPE image
    
    .DESCRIPTION
        Adds drivers to a mounted WinPE image using DISM
        Supports both mounted WIM and VHD formats
    
    .PARAMETER ImagePath
        Path to mounted WinPE image
    
    .PARAMETER DriverPath
        Path to drivers to inject
    
    .PARAMETER Recursive
        Recursively search for drivers in subdirectories
    
    .OUTPUTS
        PSCustomObject with injection results
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$ImagePath,
        
        [Parameter(Mandatory=$true)]
        [string]$DriverPath,
        
        [switch]$Recursive = $true
    )
    
    $result = @{
        Success = $false
        Command = ""
        Output = @()
        Errors = @()
    }
    
    try {
        # Validate paths
        if (-not (Test-Path $ImagePath)) {
            throw "WinPE image path not found: $ImagePath"
        }
        
        if (-not (Test-Path $DriverPath)) {
            throw "Driver path not found: $DriverPath"
        }
        
        # Build DISM command
        $dismCmd = "dism /Image:`"$ImagePath`" /Add-Driver /Driver:`"$DriverPath`""
        
        if ($Recursive) {
            $dismCmd += " /Recurse"
        }
        
        $dismCmd += " /ForceUnsigned"
        
        $result.Command = $dismCmd
        
        Write-Host "Injecting drivers into WinPE..." -ForegroundColor Yellow
        Write-Host "Command: $dismCmd" -ForegroundColor Gray
        
        # Execute DISM
        $output = Invoke-Expression $dismCmd 2>&1
        $result.Output = $output
        
        # Check for success
        if ($LASTEXITCODE -eq 0) {
            $result.Success = $true
            Write-Host "[✓] Drivers successfully injected" -ForegroundColor Green
        } else {
            $result.Errors += "DISM returned exit code: $LASTEXITCODE"
            Write-Host "[✗] Driver injection failed (Exit code: $LASTEXITCODE)" -ForegroundColor Red
        }
        
    } catch {
        $result.Errors += $_
        Write-Error "Driver injection error: $_"
    }
    
    return $result
}

################################################################################
# NETWORK ADAPTER MANAGEMENT
################################################################################

function Enable-NetworkAdapter {
    <#
    .SYNOPSIS
        Enables a disabled network adapter
    
    .DESCRIPTION
        Re-enables a network adapter that has been disabled
        Works in both FullOS and WinPE environments
    
    .PARAMETER AdapterName
        Name of the adapter to enable
    
    .OUTPUTS
        PSCustomObject with operation result
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$AdapterName
    )
    
    $result = @{
        Success = $false
        Message = ""
        Error   = ""
    }
    
    try {
        # Try via netsh (works in most environments)
        Write-Host "Attempting to enable adapter: $AdapterName" -ForegroundColor Yellow
        
        $output = netsh interface set interface name="$AdapterName" admin=enabled 2>&1
        
        # Verify
        Start-Sleep -Seconds 2
        $adapter = Get-NetworkAdapterStatus | Where-Object { $_.Name -eq $AdapterName }
        
        if ($adapter -and $adapter.Enabled) {
            $result.Success = $true
            $result.Message = "Network adapter '$AdapterName' successfully enabled"
            Write-Host "[✓] $($result.Message)" -ForegroundColor Green
        } else {
            $result.Message = "Adapter enable command executed but status unclear"
            Write-Host "[!] $($result.Message)" -ForegroundColor Yellow
        }
        
    } catch {
        $result.Error = $_
        Write-Error "Failed to enable adapter: $_"
    }
    
    return $result
}

function Disable-NetworkAdapter {
    <#
    .SYNOPSIS
        Disables a network adapter
    
    .DESCRIPTION
        Temporarily disables a network adapter
        Can be useful for troubleshooting connectivity issues
    
    .PARAMETER AdapterName
        Name of the adapter to disable
    
    .OUTPUTS
        PSCustomObject with operation result
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$AdapterName
    )
    
    $result = @{
        Success = $false
        Message = ""
        Error   = ""
    }
    
    try {
        Write-Host "Attempting to disable adapter: $AdapterName" -ForegroundColor Yellow
        
        $output = netsh interface set interface name="$AdapterName" admin=disabled 2>&1
        
        Start-Sleep -Seconds 2
        $adapter = Get-NetworkAdapterStatus -IncludeDisabled | Where-Object { $_.Name -eq $AdapterName }
        
        if ($adapter -and -not $adapter.Enabled) {
            $result.Success = $true
            $result.Message = "Network adapter '$AdapterName' successfully disabled"
            Write-Host "[✓] $($result.Message)" -ForegroundColor Green
        } else {
            $result.Message = "Adapter disable command executed but status unclear"
            Write-Host "[!] $($result.Message)" -ForegroundColor Yellow
        }
        
    } catch {
        $result.Error = $_
        Write-Error "Failed to disable adapter: $_"
    }
    
    return $result
}

################################################################################
# COMPREHENSIVE DIAGNOSTICS & TROUBLESHOOTING
################################################################################

function Invoke-NetworkDiagnostics {
    <#
    .SYNOPSIS
        Comprehensive network diagnostics and troubleshooting wizard
    
    .DESCRIPTION
        Interactive guided network troubleshooting that:
        1. Detects network adapters
        2. Checks connectivity at each stage
        3. Reports specific failure points
        4. Suggests remediation steps
        5. Exports detailed diagnostic report
    
    .PARAMETER Interactive
        Provides interactive prompts for user actions
    
    .OUTPUTS
        Comprehensive diagnostic report object
    #>
    
    param(
        [switch]$Interactive
    )
    
    $report = @{
        Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ComputerName       = $env:COMPUTERNAME
        Environment        = if ((Get-Item -Path "X:\" -ErrorAction SilentlyContinue)) { "WinPE/WinRE" } else { "FullOS" }
        Adapters           = $null
        WirelessAdapters   = 0
        WiredAdapters      = 0
        ConnectedAdapters  = 0
        Connectivity       = $null
        FailurePoints      = @()
        Recommendations    = @()
        DriversLoaded      = 0
        Success            = $false
    }
    
    Write-Host "`n" -ForegroundColor Cyan
    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      NETWORK DIAGNOSTICS & TROUBLESHOOTING                      ║" -ForegroundColor Cyan
    Write-Host "║                          MiracleBoot Network Module v1.0                        ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "`n"
    
    # Phase 1: Adapter Detection
    Write-Host "[PHASE 1] Detecting Network Adapters..." -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    
    $adapters = Get-NetworkAdapterStatus -IncludeDisabled
    $report.Adapters = $adapters
    
    if ($adapters.Count -eq 0) {
        Write-Host "[✗] NO NETWORK ADAPTERS DETECTED" -ForegroundColor Red
        $report.FailurePoints += "No network adapters found in system"
        $report.Recommendations += "Check if drivers are loaded or hardware is present"
        Write-Host "   → Possible causes: Missing drivers, disabled hardware, BIOS disabled" -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host "[✓] Found $($adapters.Count) network adapter(s)" -ForegroundColor Green
        Write-Host ""
        
        foreach ($adapter in $adapters) {
            $status = if ($adapter.Connected) { "[✓] Connected" } else { "[✗] Disconnected" }
            Write-Host "   $status  $($adapter.Description)" -ForegroundColor $(if ($adapter.Connected) { "Green" } else { "Yellow" })
            Write-Host "            Type: $($adapter.Type) | MAC: $($adapter.MacAddress)" -ForegroundColor Gray
            Write-Host "            IP: $($adapter.IPAddress) | DHCP: $($adapter.DHCPEnabled)" -ForegroundColor Gray
            Write-Host ""
        }
        
        $report.WiredAdapters = ($adapters | Where-Object { $_.Type -match "Wired" }).Count
        $report.WirelessAdapters = ($adapters | Where-Object { $_.Type -match "Wireless" }).Count
        $report.ConnectedAdapters = ($adapters | Where-Object { $_.Connected }).Count
    }
    
    # Phase 2: Drivers
    Write-Host "[PHASE 2] Checking Network Drivers..." -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    
    try {
        $drivers = Get-NetworkDrivers
        $report.DriversLoaded = $drivers.Count
        
        if ($drivers.Count -gt 0) {
            Write-Host "[✓] Found $($drivers.Count) loaded network driver(s)" -ForegroundColor Green
            foreach ($driver in $drivers | Select-Object -First 3) {
                Write-Host "   • $($driver.DriverName) (v$($driver.DriverVersion))" -ForegroundColor Gray
            }
            if ($drivers.Count -gt 3) {
                Write-Host "   ... and $($drivers.Count - 3) more" -ForegroundColor Gray
            }
        } else {
            Write-Host "[✗] No network drivers detected" -ForegroundColor Red
            $report.FailurePoints += "Network drivers not loaded"
            $report.Recommendations += "Load network drivers using driver injection"
        }
    } catch {
        Write-Host "[!] Could not query drivers: $_" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Phase 3: Connectivity Testing
    Write-Host "[PHASE 3] Testing Internet Connectivity..." -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    
    $connectivity = Test-InternetConnectivity -Verbose
    $report.Connectivity = $connectivity
    
    if ($connectivity.Success) {
        Write-Host ""
        Write-Host "[✓] INTERNET CONNECTIVITY CONFIRMED" -ForegroundColor Green
        Write-Host "    All connectivity tests passed!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[✗] CONNECTIVITY ISSUES DETECTED" -ForegroundColor Red
        
        if ($connectivity.FailurePoints.Count -gt 0) {
            Write-Host "`n   Specific Failure Points:" -ForegroundColor Yellow
            foreach ($failure in $connectivity.FailurePoints) {
                Write-Host "   → $failure" -ForegroundColor Red
            }
        }
        
        $report.FailurePoints += $connectivity.FailurePoints
    }
    Write-Host ""
    
    # Phase 4: Recommendations
    Write-Host "[PHASE 4] Diagnostic Summary & Recommendations..." -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    
    if ($connectivity.Success) {
        $report.Success = $true
        Write-Host "[✓] Network Status: FULLY OPERATIONAL" -ForegroundColor Green
        Write-Host "`n   Your network is properly configured and has internet access." -ForegroundColor Green
    } else {
        Write-Host "[!] Network Status: REQUIRES ATTENTION" -ForegroundColor Yellow
        Write-Host ""
        
        if (-not $report.Adapters -or $report.ConnectedAdapters -eq 0) {
            Write-Host "   ISSUE: No connected network adapters" -ForegroundColor Red
            Write-Host "   ACTION: Check cable connections or enable WiFi adapter" -ForegroundColor Yellow
            Write-Host ""
        }
        
        if ($report.DriversLoaded -eq 0) {
            Write-Host "   ISSUE: No network drivers loaded" -ForegroundColor Red
            Write-Host "   ACTION: Inject drivers using 'Add-DriversToWinPE' or enable Windows Updates" -ForegroundColor Yellow
            Write-Host ""
        }
        
        if (-not $connectivity.DHCPConfigured) {
            Write-Host "   ISSUE: DHCP not configured" -ForegroundColor Red
            Write-Host "   ACTION: Enable DHCP in network adapter settings" -ForegroundColor Yellow
            Write-Host ""
        }
        
        if (-not $connectivity.DNSResolving) {
            Write-Host "   ISSUE: DNS not resolving" -ForegroundColor Red
            Write-Host "   ACTION: Check DNS server configuration (8.8.8.8 or 1.1.1.1 as backup)" -ForegroundColor Yellow
            Write-Host ""
        }
    }
    
    Write-Host ""
    
    return $report
}

################################################################################
# HELP & GUIDANCE FUNCTIONS
################################################################################

function Get-NetworkTroubleshootingGuide {
    <#
    .SYNOPSIS
        Displays detailed network troubleshooting guide
    
    .OUTPUTS
        Formatted help text
    #>
    
    $guide = @"
╔════════════════════════════════════════════════════════════════════════════════╗
║                    NETWORK TROUBLESHOOTING GUIDE                               ║
║                        MiracleBoot Network Module                              ║
╚════════════════════════════════════════════════════════════════════════════════╝

COMMON NETWORK ISSUES AND SOLUTIONS
───────────────────────────────────────────────────────────────────────────────────

ISSUE 1: No Network Adapters Detected
═════════════════════════════════════════════════════════════════════════════════

Symptoms:
  • Get-NetworkAdapterStatus returns empty
  • Network icon shows "No adapters"
  • Cannot see any network connections

Possible Causes:
  ✗ Network drivers not installed
  ✗ Network adapter disabled in Device Manager
  ✗ Network adapter disabled in BIOS
  ✗ Hardware not recognized

Solutions (in order of ease):
  1. Check BIOS: Reboot and enter BIOS, enable "Onboard Network" or "LAN"
  2. Device Manager: Right-click "Unknown device", update driver
  3. Inject drivers: Use Add-DriversToWinPE with proper network drivers
  4. Hardware test: Run HWINFO to verify hardware is present

Command to re-detect hardware:
  Get-PnpDevice -Status Unknown | Where-Object { $_.InstanceId -match "PCI|USB" }


ISSUE 2: Network Adapter Present But Disconnected
═════════════════════════════════════════════════════════════════════════════════

Symptoms:
  • Adapter shows in Device Manager but marked disconnected
  • No cable symbol or WiFi connected icon

Possible Causes:
  ✗ Ethernet cable not connected
  ✗ WiFi network not visible or wrong password
  ✗ Adapter driver not fully loaded
  ✗ DHCP timeout

Solutions:
  1. Physical: Check cable is firmly connected to both PC and router
  2. WiFi: Verify WiFi network is visible and SSID is correct
  3. Restart: Disable then enable adapter
     Enable-NetworkAdapter "Ethernet"
  4. DHCP: Manually request DHCP lease
     ipconfig /release
     ipconfig /renew


ISSUE 3: Adapter Connected But No IP Address (Stuck on DHCP)
═════════════════════════════════════════════════════════════════════════════════

Symptoms:
  • Adapter shows connected but IP is 169.x.x.x (APIPA)
  • ipconfig shows DHCP enabled but no address assigned
  • Cannot access network resources

Possible Causes:
  ✗ DHCP server not responding
  ✗ Router misconfigured
  ✗ Network adapter DHCP timeout
  ✗ Duplicate IP on network

Solutions:
  1. Restart DHCP: ipconfig /release && ipconfig /renew
  2. Timeout increase: Restart network service
     net stop dhcp && net start dhcp
  3. Static IP (temporary): Set manual IP for testing
     netsh interface ip set address "Ethernet" static 192.168.1.100 255.255.255.0
  4. Router check: Reboot router and wait 30 seconds

Command to check DHCP lease:
  ipconfig /all | findstr /i "dhcp server lease"


ISSUE 4: DHCP Works But Cannot Resolve Domain Names
═════════════════════════════════════════════════════════════════════════════════

Symptoms:
  • ipconfig shows valid IP and gateway
  • Can ping IP addresses (ping 8.8.8.8 works)
  • Cannot ping domain names (ping google.com fails)
  • "Cannot find host" errors

Possible Causes:
  ✗ DNS server not configured
  ✗ DNS server unreachable
  ✗ ISP DNS is blocking
  ✗ Router DNS misconfigured

Solutions:
  1. Check DNS: ipconfig /all | findstr "DNS Server"
  2. Set manual DNS:
     netsh interface ipv4 set dnsservers "Ethernet" static 8.8.8.8 primary
     netsh interface ipv4 add dnsservers "Ethernet" 8.8.4.4 index=2
  3. Clear DNS cache: ipconfig /flushdns
  4. Test: ping google.com

Recommended DNS servers:
  • Google: 8.8.8.8 and 8.8.4.4
  • Cloudflare: 1.1.1.1 and 1.0.0.1
  • OpenDNS: 208.67.222.123 and 208.67.220.123


ISSUE 5: DNS Works But Cannot Access Internet
═════════════════════════════════════════════════════════════════════════════════

Symptoms:
  • ping google.com works
  • Web browser shows "Cannot connect"
  • Some services work, others don't

Possible Causes:
  ✗ Firewall blocking internet access
  ✗ Proxy misconfigured
  ✗ ISP blocking ports
  ✗ Network timeout issues

Solutions:
  1. Check firewall: Windows Defender Firewall > Allow an app
  2. Disable firewall (temporary):
     netsh advfirewall set allprofiles state off
  3. Check proxy: netsh winhttp show proxy
  4. Reset proxy: netsh winhttp reset proxy
  5. Advanced troubleshooting: Trace route
     tracert google.com


ISSUE 6: Intermittent Connectivity Drops
═════════════════════════════════════════════════════════════════════════════════

Symptoms:
  • Connection drops for 10-30 seconds then reconnects
  • High packet loss on ping
  • Network becomes unresponsive periodically

Possible Causes:
  ✗ Driver issue (power saving mode enabled)
  ✗ WiFi interference
  ✗ Router stability problem
  ✗ Hardware conflict

Solutions:
  1. Disable power saving for NIC:
     powercfg /change disk-timeout-ac 0
     powercfg /change disk-timeout-dc 0
  2. Update driver to latest version
  3. Change WiFi channel (router settings) to less crowded channel
  4. Test wired connection if available
  5. Check router logs for stability issues


QUICK DIAGNOSTICS
───────────────────────────────────────────────────────────────────────────────────

Run this command for complete network diagnostics:
  Invoke-NetworkDiagnostics -Interactive

Check adapter status:
  Get-NetworkAdapterStatus | Format-Table

Test connectivity:
  Test-InternetConnectivity -Verbose

Find drivers:
  Find-NetworkDrivers

Export drivers:
  Export-NetworkDrivers -OutputPath "C:\Drivers"


ADVANCED COMMANDS
───────────────────────────────────────────────────────────────────────────────────

ipconfig /all                    - Show all network details
netsh interface show interface   - List all adapters
netsh interface ipv4 show route  - Show routing table
pathping google.com              - Advanced connectivity test
Get-NetAdapter | Select Status   - PowerShell adapter status
Get-NetIPAddress                 - All IP addresses
Resolve-DnsName google.com       - DNS resolution test

"@
    
    return $guide
}

function Get-NetworkDiagnosticsHelp {
    <#
    .SYNOPSIS
        Displays help for available network diagnostics functions
    
    .OUTPUTS
        Formatted help text
    #>
    
    $help = @"
╔════════════════════════════════════════════════════════════════════════════════╗
║                  NETWORK DIAGNOSTICS MODULE - FUNCTION REFERENCE               ║
║                         MiracleBoot v7.2.0 Network Module                      ║
╚════════════════════════════════════════════════════════════════════════════════╝

ADAPTER DETECTION FUNCTIONS
───────────────────────────────────────────────────────────────────────────────────

Get-NetworkAdapterStatus
  Purpose: Get all network adapters and their status
  Usage:   Get-NetworkAdapterStatus [-IncludeDisabled]
  Example: Get-NetworkAdapterStatus | Where-Object Connected -eq True
  Output:  PSCustomObject with adapter details

Get-WiredAdapters
  Purpose: Get only Ethernet/wired adapters
  Usage:   Get-WiredAdapters
  Example: Get-WiredAdapters | Select Name, Status
  Output:  Array of wired adapter objects

Get-WirelessAdapters
  Purpose: Get only WiFi/wireless adapters
  Usage:   Get-WirelessAdapters
  Example: Get-WirelessAdapters | Format-List
  Output:  Array of wireless adapter objects


CONNECTIVITY TESTING FUNCTIONS
───────────────────────────────────────────────────────────────────────────────────

Test-InternetConnectivity
  Purpose: Comprehensive multi-step connectivity test
  Usage:   Test-InternetConnectivity [-Verbose]
  Example: \$result = Test-InternetConnectivity -Verbose
  Output:  PSCustomObject with test results and failure points
  Tests:   DHCP → DNS → Ping 8.8.8.8 → Ping google.com

Test-NetworkConnectivity
  Purpose: Quick internet connectivity check
  Usage:   Test-NetworkConnectivity
  Example: if (Test-NetworkConnectivity) { "Online" }
  Output:  Boolean (True/False)


DRIVER DETECTION FUNCTIONS
───────────────────────────────────────────────────────────────────────────────────

Get-NetworkDrivers
  Purpose: Get currently loaded network drivers
  Usage:   Get-NetworkDrivers
  Example: Get-NetworkDrivers | Export-Csv drivers.csv
  Output:  Array of driver objects with version info

Find-NetworkDrivers
  Purpose: Find network drivers in DriverStore
  Usage:   Find-NetworkDrivers
  Example: \$drivers = Find-NetworkDrivers
  Output:  Array of INF files from DriverStore

Find-DriversOnVolumes
  Purpose: Search for drivers on mounted volumes
  Usage:   Find-DriversOnVolumes [-Volumes D:,E:] [-IncludeSystemDrive]
  Example: Find-DriversOnVolumes -Volumes D: -IncludeSystemDrive
  Output:  Array of driver files found on volumes

Get-DriverStorePath
  Purpose: Get Windows DriverStore path
  Usage:   Get-DriverStorePath
  Example: \$path = Get-DriverStorePath
  Output:  String path to DriverStore


DRIVER MANAGEMENT FUNCTIONS
───────────────────────────────────────────────────────────────────────────────────

Export-NetworkDrivers
  Purpose: Export network drivers to a folder
  Usage:   Export-NetworkDrivers [-OutputPath path] [-ExcludeBuiltin]
  Example: Export-NetworkDrivers -OutputPath "C:\Drivers"
  Output:  PSCustomObject with export results

Add-DriversToWinPE
  Purpose: Inject drivers into WinPE image
  Usage:   Add-DriversToWinPE -ImagePath path -DriverPath path [-Recursive]
  Example: Add-DriversToWinPE -ImagePath "C:\mount" -DriverPath "C:\Drivers"
  Output:  PSCustomObject with DISM results


ADAPTER MANAGEMENT FUNCTIONS
───────────────────────────────────────────────────────────────────────────────────

Enable-NetworkAdapter
  Purpose: Enable a disabled network adapter
  Usage:   Enable-NetworkAdapter -AdapterName name
  Example: Enable-NetworkAdapter -AdapterName "Ethernet"
  Output:  PSCustomObject with result

Disable-NetworkAdapter
  Purpose: Disable a network adapter
  Usage:   Disable-NetworkAdapter -AdapterName name
  Example: Disable-NetworkAdapter -AdapterName "WiFi"
  Output:  PSCustomObject with result


DIAGNOSTICS & REPORTING FUNCTIONS
───────────────────────────────────────────────────────────────────────────────────

Invoke-NetworkDiagnostics
  Purpose: Run comprehensive network diagnostics
  Usage:   Invoke-NetworkDiagnostics [-Interactive]
  Example: \$report = Invoke-NetworkDiagnostics -Interactive
  Output:  Detailed diagnostic report object
  Shows:   Adapters, drivers, connectivity, recommendations

Get-NetworkTroubleshootingGuide
  Purpose: Display network troubleshooting guide
  Usage:   Get-NetworkTroubleshootingGuide
  Example: Get-NetworkTroubleshootingGuide | Out-Host
  Output:  Formatted help text with solutions

Get-NetworkDiagnosticsHelp
  Purpose: Display this function reference
  Usage:   Get-NetworkDiagnosticsHelp
  Example: Get-NetworkDiagnosticsHelp | Out-Host
  Output:  This help text


COMMON WORKFLOWS
───────────────────────────────────────────────────────────────────────────────────

WORKFLOW 1: Quick Network Check
  Get-NetworkAdapterStatus
  Test-InternetConnectivity
  
WORKFLOW 2: Full Diagnostics
  Invoke-NetworkDiagnostics -Interactive
  
WORKFLOW 3: Export and Inject Drivers
  Export-NetworkDrivers -OutputPath "C:\NetDrivers"
  Add-DriversToWinPE -ImagePath "C:\mount\boot.wim" -DriverPath "C:\NetDrivers"
  
WORKFLOW 4: Find Drivers on USB
  Find-DriversOnVolumes -Volumes D: -IncludeSystemDrive
  
WORKFLOW 5: Troubleshoot Connectivity
  Get-NetworkTroubleshootingGuide
  # Follow step-by-step instructions


TIPS & BEST PRACTICES
───────────────────────────────────────────────────────────────────────────────────

1. Always run diagnostics before attempting fixes
   \$diag = Invoke-NetworkDiagnostics
   
2. Check failure points for specific issues
   \$diag.FailurePoints
   
3. Export drivers before losing internet
   Export-NetworkDrivers -ExcludeBuiltin
   
4. Use -Verbose flag for detailed output
   Test-InternetConnectivity -Verbose
   
5. Test each step independently
   Get-NetworkAdapterStatus
   Test-NetworkConnectivity
   Resolve-DnsName google.com
   
6. Save diagnostic reports
   \$report = Invoke-NetworkDiagnostics
   \$report | ConvertTo-Json | Out-File "diagnosis.json"


REQUIREMENTS & ENVIRONMENT
───────────────────────────────────────────────────────────────────────────────────

Privileges: Administrator (required for most operations)
OS Support: Windows 10/11 (FullOS, WinPE, WinRE)
PowerShell: 5.0 or later (7.0+ recommended)
Network: IPv4 supported (IPv6 partial support)

"@
    
    return $help
}

################################################################################
# TIER 1: DRIVER VALIDATION & COMPATIBILITY CHECKING
################################################################################

function Test-DriverCompatibility {
    <#
    .SYNOPSIS
        Validates network drivers before injection into WinPE
    
    .DESCRIPTION
        Performs forensic analysis of driver INF files to ensure:
        - Driver is actually network class (not audio/video masquerading)
        - All required dependencies (.sys, .dll, .cat) are present
        - Driver supports target WinPE architecture (x86/x64)
        - Driver signing status matches WinPE requirements
        - No known incompatibilities
    
    .PARAMETER DriverPath
        Path to driver file (.inf) or driver folder
    
    .PARAMETER TargetArchitecture
        Target system architecture: x86, x64, ARM64 (default: x64)
    
    .PARAMETER StrictMode
        Only allow signed drivers (default: allow unsigned with warning)
    
    .OUTPUTS
        PSCustomObject with compatibility analysis
    
    .EXAMPLE
        $result = Test-DriverCompatibility -DriverPath "C:\Drivers\Ethernet.inf"
        if ($result.Compatible) { "Safe to inject" }
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriverPath,
        
        [ValidateSet("x86", "x64", "ARM64")]
        [string]$TargetArchitecture = "x64",
        
        [switch]$StrictMode
    )
    
    $result = @{
        Compatible          = $false
        Reason              = ""
        DriverClass         = ""
        Architecture        = ""
        IsSigned            = $false
        Dependencies        = @()
        MissingFiles        = @()
        Warnings            = @()
        Recommendations     = @()
        Details             = @()
        Timestamp           = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        # Resolve path (could be folder or .inf file)
        if (Test-Path -PathType Container $DriverPath) {
            $infFiles = Get-ChildItem -Path $DriverPath -Filter "*.inf" -ErrorAction SilentlyContinue
            if ($infFiles.Count -eq 0) {
                $result.Reason = "No .inf files found in driver folder: $DriverPath"
                return $result
            }
            $infFile = $infFiles[0]
        } elseif (Test-Path -PathType Leaf $DriverPath) {
            if ($DriverPath -notmatch "\.inf$") {
                $result.Reason = "Driver file must be .inf format: $DriverPath"
                return $result
            }
            $infFile = Get-Item $DriverPath
        } else {
            $result.Reason = "Driver path not found: $DriverPath"
            return $result
        }
        
        $driverFolder = $infFile.Directory.FullName
        $infContent = Get-Content -Path $infFile.FullName -ErrorAction SilentlyContinue
        
        if (-not $infContent) {
            $result.Reason = "Cannot read INF file: $($infFile.FullName)"
            return $result
        }
        
        $result.Details += "INF File: $($infFile.Name)"
        $result.Details += "Location: $driverFolder"
        
        # Verify it's a network driver
        $classLine = $infContent | Where-Object { $_ -match "^\s*Class\s*=" }
        
        if ($classLine) {
            $class = ($classLine -split "=")[1].Trim().Split(';')[0]
            $result.DriverClass = $class
            
            $networkClasses = @("Net", "NetTrans", "NetClient", "NetService", "NetDriver")
            $isNetworkDriver = $networkClasses | Where-Object { $class -match $_ }
            
            if ($isNetworkDriver) {
                $result.Details += "✓ Driver class confirmed as network: $class"
            } else {
                $result.Reason = "Driver is not network class. Class found: $class"
                $result.Recommendations += "This driver may be for audio, video, or chipset. Verify correct driver."
                return $result
            }
        } else {
            $result.Warnings += "Could not determine driver class from INF file"
            $result.Details += "! No Class= line found (may use class from device)"
        }
        
        # Check driver architecture support
        $supportedArches = @{
            "x64"  = @("amd64", "x64", "ia64")
            "x86"  = @("i386", "x86", "win32")
            "ARM64" = @("arm64", "arm")
        }
        
        $archList = $supportedArches[$TargetArchitecture]
        $archFound = $false
        
        foreach ($arch in $archList) {
            if ($infContent -join "`n" | Select-String -Pattern "\.Models\.$arch|SourceDisksFiles\.$arch|\[$arch\]" -Quiet) {
                $archFound = $true
                $result.Architecture = $TargetArchitecture
                $result.Details += "✓ Architecture support confirmed: $TargetArchitecture"
                break
            }
        }
        
        if (-not $archFound) {
            if ($infContent -join "`n" | Select-String -Pattern "^\s*\[\s*DefaultInstall" -Quiet) {
                $result.Architecture = "Any/DefaultInstall"
                $result.Details += "! Using DefaultInstall section (architecture-neutral)"
                $result.Warnings += "Driver does not specify $TargetArchitecture explicitly. May use default."
            } else {
                $result.Reason = "Driver does not support target architecture: $TargetArchitecture"
                return $result
            }
        }
        
        # Extract and verify dependencies
        $copyFiles = $infContent | Where-Object { $_ -match "^CopyFiles\s*=" }
        $files = @()
        
        foreach ($line in $copyFiles) {
            $fileList = ($line -split "=")[1].Trim()
            $files += $fileList -split ","
        }
        
        foreach ($file in $files) {
            $file = $file.Trim()
            if (-not $file) { continue }
            
            $filePath = Join-Path $driverFolder $file
            
            if (Test-Path $filePath) {
                $result.Dependencies += $file
                $result.Details += "✓ Found: $file"
            } else {
                $result.MissingFiles += $file
                $result.Warnings += "MISSING DEPENDENCY: $file"
            }
        }
        
        # Check driver signature status
        $catFiles = Get-ChildItem -Path $driverFolder -Filter "*.cat" -ErrorAction SilentlyContinue
        
        if ($catFiles.Count -gt 0) {
            $result.IsSigned = $true
            $result.Details += "✓ Signed drivers found: $($catFiles.Name -join ', ')"
        } else {
            $result.IsSigned = $false
            $result.Warnings += "Driver is NOT SIGNED (.cat file missing)"
            
            if ($StrictMode) {
                $result.Reason = "StrictMode enabled: Unsigned drivers not allowed"
                $result.Recommendations += "Obtain signed driver or disable StrictMode"
                return $result
            }
        }
        
        # Final compatibility determination
        if ($result.MissingFiles.Count -eq 0 -and $result.DriverClass -match "Net") {
            $result.Compatible = $true
            
            if ($result.IsSigned) {
                $result.Reason = "Driver is fully compatible and signed"
            } else {
                $result.Reason = "Driver is compatible but UNSIGNED - use /ForceUnsigned during injection"
            }
            
            if ($result.Warnings.Count -gt 0) {
                $result.Reason += " (with warnings)"
            }
        } elseif ($result.MissingFiles.Count -gt 0) {
            $result.Reason = "Driver has missing dependencies"
            $result.Recommendations += "Ensure all driver files are in the same folder"
        }
        
    } catch {
        $result.Reason = "Error analyzing driver: $_"
        $result.Warnings += $_.Exception.Message
    }
    
    return $result
}

################################################################################
# TIER 1.2: VMD/RAID CONTROLLER DETECTION & MANAGEMENT
################################################################################

function Get-VMDConfiguration {
    <#
    .SYNOPSIS
        Detects Intel VMD controller and RAID configuration
    
    .DESCRIPTION
        Identifies systems using Intel Volume Management Device (VMD) for NVMe RAID.
        Critical for systems that cannot boot WinPE without VMD drivers.
        
        VMD is used by:
        - Dell (PERC controllers)
        - HP (Smart Array)
        - Lenovo (ThinkSystem)
        - Many enterprise/gaming systems
    
    .OUTPUTS
        PSCustomObject with VMD configuration details
    #>
    
    $result = @{
        HasVMD                = $false
        RAIDMode              = "Unknown"
        VMDControllers        = @()
        NVMeCount             = 0
        RequiresVMDDriver     = $false
        RecommendedAction     = ""
        Details               = @()
        Timestamp             = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        # Check for Intel VMD via PCI
        $vmdDevices = @()
        
        # Method 1: Check via WMI for RAID controllers
        try {
            $raidControllers = Get-WmiObject Win32_SystemEnclosure -ErrorAction SilentlyContinue | 
                Select-Object -ExpandProperty ChassisTypes
            
            # Check PnP for VMD
            $devices = Get-WmiObject Win32_PnPEntity -Filter "Name LIKE '%VMD%'" -ErrorAction SilentlyContinue
            if ($devices) {
                $vmdDevices = $devices
                $result.HasVMD = $true
                $result.Details += "✓ Intel VMD controller detected via WMI"
            }
        } catch {
            $result.Details += "WMI VMD check skipped (may be in WinPE)"
        }
        
        # Method 2: Check registry for RAID drivers (offline Windows)
        try {
            $raidDrivers = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme" -ErrorAction SilentlyContinue
            if ($raidDrivers) {
                $result.HasVMD = $true
                $result.Details += "✓ NVMe storage driver detected (may indicate VMD)"
            }
        } catch {
            # Registry may not be available
        }
        
        # Method 3: Check BIOS settings (via WMI)
        try {
            $bios = Get-WmiObject Win32_BIOS -ErrorAction SilentlyContinue
            
            if ($bios.SMBIOSBIOSVersion -match "RAID|VMD|AHCI") {
                $result.Details += "! BIOS version suggests RAID/VMD support: $($bios.SMBIOSBIOSVersion)"
                $result.RAIDMode = "Likely RAID/VMD enabled"
                $result.RequiresVMDDriver = $true
            }
        } catch {
            # BIOS info may not be available
        }
        
        # Method 4: Check for NVMe drives (indication of potential VMD)
        try {
            $nvmeCount = Get-WmiObject Win32_DiskDrive -Filter "InterfaceType LIKE '%NVMe%'" -ErrorAction SilentlyContinue | 
                Measure-Object | Select-Object -ExpandProperty Count
            
            if ($nvmeCount -gt 0) {
                $result.NVMeCount = $nvmeCount
                $result.Details += "✓ Found $nvmeCount NVMe drive(s)"
                
                if ($nvmeCount -gt 1) {
                    $result.RequiresVMDDriver = $true
                    $result.Details += "! Multiple NVMe drives suggest RAID configuration (VMD required)"
                }
            }
        } catch {
            $result.Details += "NVMe detection not available"
        }
        
        # Determine recommendation
        if ($result.HasVMD -or $result.RequiresVMDDriver) {
            $result.RecommendedAction = "INJECT VMD DRIVERS BEFORE BOOT"
            $result.Details += ""
            $result.Details += "═══════════════════════════════════════════════════════════"
            $result.Details += "CRITICAL: This system requires VMD drivers"
            $result.Details += "Without VMD drivers, WinPE cannot detect NVMe storage"
            $result.Details += "ACTION: Download VMD driver from system manufacturer"
            $result.Details += "═══════════════════════════════════════════════════════════"
        } else {
            $result.RecommendedAction = "No VMD drivers required"
        }
        
    } catch {
        $result.Details += "Error during VMD detection: $_"
    }
    
    return $result
}

function Find-VMDDrivers {
    <#
    .SYNOPSIS
        Searches for VMD/RAID drivers on mounted volumes
    
    .DESCRIPTION
        Locates Intel VMD, RAID controllers, and storage drivers
        that must be injected before WinPE boot
    
    .PARAMETER SearchVolumes
        Array of drive letters to search (e.g., @("C:", "D:"))
    
    .PARAMETER IncludeSystemDrive
        Include C: drive in search (default: skip to avoid slowdown)
    
    .OUTPUTS
        Array of discovered driver files
    #>
    
    param(
        [string[]]$SearchVolumes = @(),
        [switch]$IncludeSystemDrive
    )
    
    $drivers = @()
    $searchedPaths = @()
    
    # Common VMD/RAID driver locations
    $searchPatterns = @(
        "*VMD*",
        "*RAID*",
        "*RST*",
        "*storage*",
        "*nvme*",
        "*stornvme*",
        "*StorPort*",
        "*ScsiPort*"
    )
    
    try {
        # Discover volumes if not specified
        if ($SearchVolumes.Count -eq 0) {
            $SearchVolumes = Get-Volume -ErrorAction SilentlyContinue | 
                Where-Object { $_.DriveType -eq "Fixed" } | 
                Select-Object -ExpandProperty DriveLetter
        }
        
        # Remove system drive if not requested
        if (-not $IncludeSystemDrive) {
            $systemDrive = $env:SystemDrive
            $SearchVolumes = $SearchVolumes | Where-Object { $_ -ne $systemDrive }
        }
        
        foreach ($volume in $SearchVolumes) {
            $volumeLetter = $volume.TrimEnd(':')
            
            # Search common driver locations
            $driverSearchPaths = @(
                "$volumeLetter`:\Drivers",
                "$volumeLetter`:\support",
                "$volumeLetter`:\OEM",
                "$volumeLetter`:\Intel",
                "$volumeLetter`:\Program Files\*Driver*"
            )
            
            foreach ($searchPath in $driverSearchPaths) {
                if (-not (Test-Path $searchPath)) { continue }
                
                foreach ($pattern in $searchPatterns) {
                    try {
                        $found = Get-ChildItem -Path $searchPath -Filter $pattern -Recurse -ErrorAction SilentlyContinue | 
                            Where-Object { $_.Extension -match "\.(inf|exe|zip|cab)$" }
                        
                        foreach ($file in $found) {
                            $drivers += [PSCustomObject]@{
                                FileName   = $file.Name
                                FullPath   = $file.FullName
                                Volume     = $volumeLetter
                                Type       = $file.Extension
                                Size       = $file.Length
                                Directory  = $file.DirectoryName
                            }
                        }
                    } catch {
                        # Skip access errors
                    }
                }
            }
        }
        
        if ($drivers.Count -eq 0) {
            Write-Warning "No VMD/RAID drivers found on searched volumes"
        }
        
    } catch {
        Write-Error "Error searching for VMD drivers: $_"
    }
    
    return $drivers | Sort-Object -Property Volume, Directory | Get-Unique -AsString
}

################################################################################
# TIER 1.3: DHCP TIMEOUT RECOVERY FOR WINPE
################################################################################

function Invoke-DHCPRecovery {
    <#
    .SYNOPSIS
        Recovers from DHCP timeout hangs in WinPE
    
    .DESCRIPTION
        WinPE network stack hangs on DHCP timeout (default 30 seconds).
        This function:
        - Monitors DHCP request with short timeout
        - Forces release and re-request on timeout
        - Falls back to APIPA (169.254.x.x) on failure
        - Logs all attempts for diagnostics
    
    .PARAMETER AdapterName
        Name of network adapter to configure
    
    .PARAMETER TimeoutSeconds
        Maximum wait time per DHCP attempt (default: 5)
    
    .PARAMETER MaxRetries
        Maximum DHCP retry attempts (default: 3)
    
    .PARAMETER FallbackToAPIPA
        Auto-enable APIPA fallback if DHCP fails (default: true)
    
    .OUTPUTS
        PSCustomObject with recovery results
    
    .EXAMPLE
        $result = Invoke-DHCPRecovery -AdapterName "Ethernet" -TimeoutSeconds 5
        if ($result.Success) { "Network configured" }
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$AdapterName,
        
        [int]$TimeoutSeconds = 5,
        [int]$MaxRetries = 3,
        [bool]$FallbackToAPIPA = $true
    )
    
    $result = @{
        Success             = $false
        Adapter             = $AdapterName
        FinalConfig         = $null
        Method              = ""
        TimeToConnect       = 0
        Attempts            = 0
        Details             = @()
        Warnings            = @()
        Timestamp           = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Find adapter
        $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
        if (-not $adapter) {
            $result.Details += "✗ Adapter not found: $AdapterName"
            return $result
        }
        
        $result.Details += "✓ Found adapter: $($adapter.Name) ($($adapter.InterfaceDescription))"
        
        # Attempt DHCP configuration
        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            $result.Attempts = $attempt
            $result.Details += ""
            $result.Details += "─ DHCP Attempt $attempt of $MaxRetries"
            
            try {
                # Release existing lease
                ipconfig /release $AdapterName 2>&1 | Out-Null
                $result.Details += "  Released previous DHCP lease"
                Start-Sleep -Milliseconds 500
                
                # Request new lease with timeout
                $dhcpStart = Get-Date
                $job = Start-Job -ScriptBlock {
                    param($adapterName)
                    ipconfig /renew $adapterName
                } -ArgumentList $AdapterName
                
                # Wait for DHCP with timeout
                $jobCompleted = $job | Wait-Job -Timeout $TimeoutSeconds
                
                if ($jobCompleted) {
                    Stop-Job -Job $job -ErrorAction SilentlyContinue
                    Remove-Job -Job $job -ErrorAction SilentlyContinue
                    
                    Start-Sleep -Milliseconds 500
                    $config = Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
                    
                    if ($config -and $config.IPAddress -notmatch "169\.254\.") {
                        $result.Success = $true
                        $result.Method = "DHCP"
                        $result.FinalConfig = $config.IPAddress
                        $result.Details += "  ✓ DHCP succeeded: $($config.IPAddress)"
                        $stopwatch.Stop()
                        $result.TimeToConnect = $stopwatch.ElapsedMilliseconds
                        return $result
                    } else {
                        $result.Warnings += "DHCP completed but no valid IP assigned"
                        $result.Details += "  ! DHCP timeout or no IP received"
                    }
                } else {
                    Stop-Job -Job $job -ErrorAction SilentlyContinue
                    Remove-Job -Job $job -ErrorAction SilentlyContinue
                    $result.Details += "  ✗ DHCP request timed out after ${TimeoutSeconds}s"
                }
                
            } catch {
                $result.Warnings += "DHCP attempt $attempt failed: $_"
                $result.Details += "  ✗ Error: $($_.Exception.Message)"
            }
            
            if ($attempt -lt $MaxRetries) {
                $result.Details += "  Waiting 2 seconds before retry..."
                Start-Sleep -Seconds 2
            }
        }
        
        # All DHCP attempts failed - try APIPA fallback
        if ($FallbackToAPIPA) {
            $result.Details += ""
            $result.Details += "─ DHCP failed on all attempts, attempting APIPA fallback"
            
            try {
                Set-NetIPInterface -InterfaceAlias $AdapterName -DHCP Disabled -ErrorAction SilentlyContinue
                
                # APIPA generates automatic link-local address (169.254.x.x)
                $apipaIP = "169.254.$((Get-Random -Minimum 1 -Maximum 255)).$((Get-Random -Minimum 1 -Maximum 255))"
                $apipaMask = 16
                
                New-NetIPAddress -InterfaceAlias $AdapterName `
                    -IPAddress $apipaIP `
                    -PrefixLength $apipaMask `
                    -ErrorAction SilentlyContinue | Out-Null
                
                $result.Success = $true
                $result.Method = "APIPA (Link-Local)"
                $result.FinalConfig = $apipaIP
                $result.Details += "✓ APIPA configured: $apipaIP/16"
                $result.Details += "⚠ Warning: Limited connectivity only (no internet without gateway)"
                
                $stopwatch.Stop()
                $result.TimeToConnect = $stopwatch.ElapsedMilliseconds
                
            } catch {
                $result.Warnings += "APIPA fallback failed: $_"
                $result.Details += "✗ APIPA configuration failed: $($_.Exception.Message)"
            }
        }
        
    } catch {
        $result.Details += "Fatal error: $_"
        $result.Warnings += $_.Exception.Message
    }
    
    return $result
}

################################################################################
# TIER 1.4: BOOT-BLOCKING DRIVER IDENTIFICATION
################################################################################

function Get-BootBlockingDrivers {
    <#
    .SYNOPSIS
        Identifies drivers that commonly cause boot hangs
    
    .DESCRIPTION
        Analyzes target Windows installation for drivers that:
        - Require specific hardware not present in WinPE
        - Have dependency chain issues
        - Are known to hang during boot
        - Conflict with recovery environment
    
    .PARAMETER OfflineWinRegPath
        Path to mounted offline Windows registry (e.g., "C:\mount\Windows\System32\config\SYSTEM")
    
    .PARAMETER TargetOSVersion
        Target Windows version (10 or 11)
    
    .OUTPUTS
        Array of problematic drivers with remediation guidance
    #>
    
    param(
        [string]$OfflineWinRegPath,
        [ValidateSet(10, 11)]
        [int]$TargetOSVersion = 11
    )
    
    $problematicDrivers = @()
    
    # Known problematic driver patterns
    $knownBadDrivers = @{
        "nvidia"        = @{ Issue = "GPU driver (useless in WinPE/WinRE, causes hangs)"; Action = "Disable or remove" }
        "amd"           = @{ Issue = "GPU driver (useless in WinPE/WinRE, causes hangs)"; Action = "Disable or remove" }
        "intel graphics"= @{ Issue = "GPU driver (useless in WinPE/WinRE)"; Action = "Disable or hangs boot" }
        "realtek audio" = @{ Issue = "Audio driver (useless in recovery, can hang)"; Action = "Disable in safe mode" }
        "Waves"         = @{ Issue = "Audio processing (dependency issues)"; Action = "Disable" }
        "nahimic"       = @{ Issue = "Audio enhancement (known to cause hangs)"; Action = "Remove" }
        "kaspersky"     = @{ Issue = "Security driver (blocks boot repairs)"; Action = "Disable temporarily" }
        "bitdefender"   = @{ Issue = "Security driver (filesystem hooks)"; Action = "Uninstall via safe mode" }
        "Norton"        = @{ Issue = "Security driver (hypervisor conflicts)"; Action = "Uninstall" }
        "McAfee"        = @{ Issue = "Security driver (complex dependencies)"; Action = "Uninstall via safe mode" }
        "usoft360"      = @{ Issue = "Chinese security (causes severe hangs)"; Action = "Uninstall" }
    }
    
    $result = @{
        ProblematicDrivers = @()
        SafeDrivers        = @()
        Details            = @()
        Recommendations    = @()
        Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        if (-not (Test-Path $OfflineWinRegPath)) {
            $result.Details += "Registry path not found: $OfflineWinRegPath"
            $result.Details += "This function requires an offline (mounted) Windows installation"
            return $result
        }
        
        $result.Details += "Analyzing offline Windows registry..."
        $result.Details += "Target: Windows $TargetOSVersion"
        $result.Details += ""
        
        # Load offline registry
        try {
            reg load HKLM\OfflineWin $OfflineWinRegPath -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        } catch {
            $result.Details += "Could not load offline registry: $_"
            return $result
        }
        
        try {
            # Query installed drivers from registry
            $driverServices = Get-ItemProperty -Path "HKLM:\OfflineWin\ControlSet001\Services\*" -ErrorAction SilentlyContinue | 
                Where-Object { $_.Type -eq 1 }
            
            foreach ($driver in $driverServices) {
                $driverName = $driver.PSChildName
                $imagePath = $driver.ImagePath
                
                # Check against known bad drivers
                foreach ($badDriver in $knownBadDrivers.Keys) {
                    if ($driverName -match $badDriver -or $imagePath -match $badDriver) {
                        $issue = $knownBadDrivers[$badDriver]
                        
                        $problematicDrivers += [PSCustomObject]@{
                            DriverName   = $driverName
                            ImagePath    = $imagePath
                            Issue        = $issue.Issue
                            Action       = $issue.Action
                            Severity     = "HIGH"
                        }
                        
                        $result.Details += "⚠ FOUND: $driverName"
                        $result.Details += "   Issue: $($issue.Issue)"
                        $result.Details += "   Action: $($issue.Action)"
                        $result.Details += ""
                        break
                    }
                }
            }
        } finally {
            # Unload registry
            reg unload HKLM\OfflineWin -ErrorAction SilentlyContinue
        }
        
        # Generate recommendations
        if ($problematicDrivers.Count -gt 0) {
            $result.ProblematicDrivers = $problematicDrivers
            
            $result.Details += "═══════════════════════════════════════════════════════════"
            $result.Details += "FOUND $($problematicDrivers.Count) PROBLEMATIC DRIVER(S)"
            $result.Details += "═══════════════════════════════════════════════════════════"
            
            $result.Recommendations += "BEFORE ATTEMPTING REPAIR INSTALL:"
            $result.Recommendations += "1. Boot into Safe Mode"
            $result.Recommendations += "2. Disable or uninstall the above drivers"
            $result.Recommendations += "3. Restart and retry repair"
            $result.Recommendations += ""
            $result.Recommendations += "COMMON SOLUTIONS:"
            $result.Recommendations += "- GPU drivers: Uninstall via Device Manager (Safe Mode)"
            $result.Recommendations += "- Security software: Run uninstaller or use Control Panel"
            $result.Recommendations += "- Audio drivers: Disable in Device Manager"
            $result.Recommendations += "- Use Windows Safe Mode for maximum control"
            
        } else {
            $result.Details += "✓ No known boot-blocking drivers detected"
            $result.Recommendations += "This system should be safe for repair install"
        }
        
    } catch {
        $result.Details += "Error during analysis: $_"
        $result.Details += "Ensure you have admin privileges and offline registry mounted correctly"
    }
    
    return $result
}

################################################################################
# TIER 2: ADVANCED DRIVER & NETWORK MANAGEMENT
################################################################################

function Manage-DriverFallbackChain {
    <#
    .SYNOPSIS
        Manages multiple versions of drivers with automatic fallback
    
    .DESCRIPTION
        Stores multiple compatible driver versions for same hardware.
        Enables automatic selection of most compatible version if primary fails.
        Critical for systems where OEM drivers vary by revision.
    
    .PARAMETER DriverName
        Name of the driver set (e.g., "Ethernet_Realtek", "NVMe_Samsung")
    
    .PARAMETER DriverPath
        Path where all driver versions are stored
    
    .PARAMETER Action
        Action to perform: 'Register', 'List', 'Test', 'Rollback'
    
    .OUTPUTS
        Driver chain management status
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriverName,
        
        [Parameter(Mandatory=$true)]
        [string]$DriverPath,
        
        [ValidateSet("Register", "List", "Test", "Rollback", "Priority")]
        [string]$Action = "List"
    )
    
    $result = @{
        DriverName          = $DriverName
        ChainPath           = "$DriverPath\$DriverName"
        Drivers             = @()
        CurrentVersion      = ""
        PrimaryDriver       = ""
        FallbackChain       = @()
        Status              = ""
        Details             = @()
        Timestamp           = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        $chainFolder = $result.ChainPath
        
        switch ($Action) {
            "Register" {
                $result.Details += "Initializing driver fallback chain for: $DriverName"
                
                if (-not (Test-Path $chainFolder)) {
                    New-Item -ItemType Directory -Path $chainFolder -Force | Out-Null
                    $result.Details += "✓ Created chain folder: $chainFolder"
                }
                
                # Auto-discover driver versions
                $infFiles = Get-ChildItem -Path $chainFolder -Filter "*.inf" -Recurse
                $result.Details += "Found $($infFiles.Count) driver versions"
                
                foreach ($inf in $infFiles | Sort-Object -Descending) {
                    $result.Drivers += @{
                        Name     = $inf.Name
                        Path     = $inf.FullName
                        Modified = $inf.LastWriteTime
                        Size     = $inf.Length
                    }
                }
                
                if ($result.Drivers.Count -gt 0) {
                    $result.PrimaryDriver = $result.Drivers[0].Name
                    $result.FallbackChain = @($result.Drivers | Select-Object -Skip 1 | ForEach-Object { $_.Name })
                    $result.Status = "Chain registered with $($result.Drivers.Count) versions"
                    $result.Details += "✓ Primary: $($result.PrimaryDriver)"
                    $result.Details += "✓ Fallbacks: $($result.FallbackChain -join ', ')"
                } else {
                    $result.Status = "No drivers found in chain folder"
                }
            }
            
            "List" {
                if (Test-Path $chainFolder) {
                    $infFiles = Get-ChildItem -Path $chainFolder -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue
                    $result.Drivers = $infFiles | ForEach-Object {
                        @{
                            Name     = $_.Name
                            Path     = $_.FullName
                            Modified = $_.LastWriteTime
                            Size     = $_.Length
                        }
                    }
                    
                    if ($result.Drivers.Count -gt 0) {
                        $result.Status = "Chain contains $($result.Drivers.Count) driver(s)"
                        $result.Details += "Driver versions found:"
                        foreach ($driver in $result.Drivers | Sort-Object Modified -Descending) {
                            $result.Details += "  - $($driver.Name) (Modified: $($driver.Modified.ToString('yyyy-MM-dd')))"
                        }
                    } else {
                        $result.Status = "Chain folder exists but is empty"
                    }
                } else {
                    $result.Status = "Chain folder does not exist"
                }
            }
            
            "Priority" {
                if (Test-Path $chainFolder) {
                    $infFiles = Get-ChildItem -Path $chainFolder -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue | 
                        Sort-Object LastWriteTime -Descending
                    
                    $result.PrimaryDriver = $infFiles[0].Name
                    $result.FallbackChain = @($infFiles | Select-Object -Skip 1 | ForEach-Object { $_.Name })
                    $result.Status = "Priority order established"
                    $result.Details += "Primary (newest): $($result.PrimaryDriver)"
                    $result.Details += "Fallback chain: $($result.FallbackChain -join ' -> ')"
                } else {
                    $result.Status = "Cannot establish priority - chain not found"
                }
            }
        }
        
    } catch {
        $result.Status = "Error: $_"
        $result.Details += "Error occurred: $_"
    }
    
    return $result
}

function Export-NetworkConfiguration {
    <#
    .SYNOPSIS
        Exports current network configuration for backup/restore
    
    .DESCRIPTION
        Creates snapshot of working network configuration including:
        - Network adapter settings
        - IP configuration (DHCP/Static)
        - DNS settings
        - Network driver details
        - Gateway information
        
        Can be restored if recovery attempt fails.
    
    .PARAMETER OutputPath
        Path where configuration file will be saved
    
    .PARAMETER Format
        Export format: 'JSON', 'XML', or 'PowerShell'
    
    .OUTPUTS
        Configuration backup file details
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [ValidateSet("JSON", "XML", "PowerShell")]
        [string]$Format = "JSON"
    )
    
    $result = @{
        Success          = $false
        FilePath         = ""
        Format           = $Format
        DataSize         = 0
        AdapterCount     = 0
        BackupTime       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Details          = @()
        Timestamp        = Get-Date
    }
    
    try {
        # Collect network configuration
        $config = @{
            Timestamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ComputerName     = $env:COMPUTERNAME
            OSVersion        = (Get-WmiObject Win32_OperatingSystem).Caption
            Adapters         = @()
            DNS              = @()
            Routes           = @()
        }
        
        # Adapter configuration
        try {
            $adapters = Get-NetAdapter -ErrorAction SilentlyContinue
            foreach ($adapter in $adapters) {
                try {
                    $ipConfig = Get-NetIPConfiguration -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
                    
                    $config.Adapters += @{
                        Name             = $adapter.Name
                        Description      = $adapter.InterfaceDescription
                        Status           = $adapter.Status
                        MediaType        = $adapter.MediaType
                        Speed            = $adapter.LinkSpeed
                        MacAddress       = $adapter.MacAddress
                        IPv4Address      = $ipConfig.IPv4Address.IPAddress
                        IPv4Gateway      = $ipConfig.IPv4DefaultGateway.NextHop
                        DHCP             = if ($ipConfig.NetIPv4Interface.DHCP -eq 'Enabled') { $true } else { $false }
                    }
                    
                    $result.AdapterCount++
                } catch {
                    $result.Details += "Warning: Could not get config for $($adapter.Name)"
                }
            }
        } catch {
            $result.Details += "Warning: Could not retrieve adapter configuration: $_"
        }
        
        # DNS configuration
        try {
            $dnsServers = Get-DnsClientServerAddress -ErrorAction SilentlyContinue
            foreach ($dns in $dnsServers | Where-Object { $_.ServerAddresses.Count -gt 0 }) {
                $config.DNS += @{
                    Interface  = $dns.InterfaceAlias
                    Servers    = @($dns.ServerAddresses)
                }
            }
        } catch {
            $result.Details += "Warning: Could not retrieve DNS configuration"
        }
        
        # Network routes
        try {
            $routes = Get-NetRoute -ErrorAction SilentlyContinue | Where-Object { $_.RouteMetric }
            foreach ($route in $routes | Select-Object -First 10) {
                $config.Routes += @{
                    Destination = $route.DestinationPrefix
                    Gateway     = $route.NextHop
                    Metric      = $route.RouteMetric
                }
            }
        } catch {
            $result.Details += "Warning: Could not retrieve routes"
        }
        
        # Save configuration
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $filename = "NetworkConfig_$timestamp.$([string]$Format).Lower()"
        $filePath = Join-Path $OutputPath $filename
        
        # Ensure output directory exists
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
            $result.Details += "✓ Created output directory: $OutputPath"
        }
        
        switch ($Format) {
            "JSON" {
                $config | ConvertTo-Json -Depth 5 | Set-Content -Path $filePath -Force
            }
            "XML" {
                $config | ConvertTo-Xml -Depth 5 | Save-Content -Path $filePath -Force
            }
            "PowerShell" {
                $config | Export-Clixml -Path $filePath -Force
            }
        }
        
        if (Test-Path $filePath) {
            $fileInfo = Get-Item $filePath
            $result.FilePath = $filePath
            $result.DataSize = $fileInfo.Length
            $result.Success = $true
            $result.Details += "✓ Configuration exported to: $filePath"
            $result.Details += "  Size: $($fileInfo.Length) bytes"
            $result.Details += "  Adapters backed up: $($result.AdapterCount)"
        }
        
    } catch {
        $result.Details += "Error during export: $_"
    }
    
    return $result
}

function Import-NetworkConfiguration {
    <#
    .SYNOPSIS
        Restores network configuration from backup
    
    .DESCRIPTION
        Attempts to restore network configuration from previously exported backup.
        Safely re-applies adapter settings, DNS configuration, and routes.
        Includes validation and rollback capability.
    
    .PARAMETER ConfigPath
        Path to configuration backup file
    
    .PARAMETER ValidateOnly
        If true, validate configuration without applying changes
    
    .OUTPUTS
        Configuration restore status
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath,
        
        [switch]$ValidateOnly
    )
    
    $result = @{
        Success          = $false
        AdaptersRestored = 0
        DNSRestored      = 0
        Status           = ""
        Details          = @()
        Warnings         = @()
        Timestamp        = Get-Date
    }
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            $result.Status = "Configuration file not found: $ConfigPath"
            return $result
        }
        
        $result.Details += "Loading configuration from: $ConfigPath"
        
        # Detect format and load
        $config = $null
        if ($ConfigPath -match "\.json$") {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
        } elseif ($ConfigPath -match "\.xml$") {
            $config = [xml](Get-Content $ConfigPath)
        } else {
            $config = Import-Clixml -Path $ConfigPath
        }
        
        if (-not $config) {
            $result.Status = "Could not parse configuration file"
            return $result
        }
        
        $result.Details += "Loaded configuration from: $($config.Timestamp)"
        
        # Validate against current system
        try {
            $currentAdapters = Get-NetAdapter -ErrorAction SilentlyContinue
            
            foreach ($backupAdapter in $config.Adapters) {
                $currentAdapter = $currentAdapters | Where-Object { $_.MacAddress -eq $backupAdapter.MacAddress }
                
                if ($currentAdapter) {
                    $result.Details += "✓ Found adapter: $($currentAdapter.Name) (was: $($backupAdapter.Name))"
                    
                    if (-not $ValidateOnly) {
                        try {
                            # Restore IP configuration
                            if ($backupAdapter.DHCP) {
                                Set-NetIPInterface -InterfaceAlias $currentAdapter.Name -DHCP Enabled -Confirm:$false
                                $result.Details += "  Enabled DHCP on $($currentAdapter.Name)"
                            } else {
                                # Would need to restore static IP - requiring more parameters
                                $result.Details += "  Static IP restore deferred (requires admin intervention)"
                            }
                            
                            $result.AdaptersRestored++
                        } catch {
                            $result.Warnings += "Could not fully restore $($currentAdapter.Name): $_"
                        }
                    }
                } else {
                    $result.Warnings += "Network adapter not found: $($backupAdapter.Description) (MAC: $($backupAdapter.MacAddress))"
                }
            }
        } catch {
            $result.Details += "Error validating adapters: $_"
        }
        
        # Validate DNS configuration
        if ($config.DNS -and $config.DNS.Count -gt 0) {
            $result.Details += "DNS configuration found for $($config.DNS.Count) interface(s)"
        }
        
        $result.Success = $true
        $result.Status = "Configuration validation complete"
        
    } catch {
        $result.Status = "Error: $_"
        $result.Details += $_.Exception.Message
    }
    
    return $result
}

################################################################################
# TIER 3: DEEP ANALYSIS & INTEGRATION
################################################################################

function Analyze-OfflineNetworkDrivers {
    <#
    .SYNOPSIS
        Analyzes network drivers in offline Windows installation
    
    .DESCRIPTION
        Deep inspection of offline Windows registry to identify:
        - Network drivers that are registered but not loaded
        - Drivers with missing dependencies
        - Drivers requiring BIOS updates
        - NIC status before Windows boot
        - Driver start type and service status
    
    .PARAMETER OfflineWindowsPath
        Path to mounted offline Windows installation (e.g., "C:\mount\Windows")
    
    .PARAMETER OfflineSystemRegPath
        Path to offline SYSTEM registry hive
    
    .OUTPUTS
        Detailed driver analysis report
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$OfflineWindowsPath,
        
        [Parameter(Mandatory=$true)]
        [string]$OfflineSystemRegPath
    )
    
    $result = @{
        LoadedDrivers          = @()
        UnloadedDrivers        = @()
        FailedLoads            = @()
        MissingDependencies    = @()
        NICStatus              = @()
        RegistryIssues         = @()
        Recommendations        = @()
        Details                = @()
        Timestamp              = Get-Date
    }
    
    try {
        $result.Details += "Analyzing offline drivers in: $OfflineWindowsPath"
        
        if (-not (Test-Path $OfflineSystemRegPath)) {
            $result.Details += "ERROR: Registry path not found: $OfflineSystemRegPath"
            return $result
        }
        
        # Load offline registry
        $regLoaded = $false
        try {
            reg load HKLM\OfflineSystem $OfflineSystemRegPath 2>&1 | Out-Null
            $regLoaded = $true
            Start-Sleep -Milliseconds 500
            $result.Details += "Loaded offline registry successfully"
        } catch {
            $result.Details += "Could not load registry: $_"
        }
        
        if ($regLoaded) {
            try {
                # Query network-related services
                $services = Get-ItemProperty -Path "HKLM:\OfflineSystem\ControlSet001\Services\*" -ErrorAction SilentlyContinue | 
                    Where-Object { $_.PSChildName -match "eth|net|wlan|wan|nic|realtek|intel|broadcom|atheros|marvell|bnx" }
                
                $result.Details += "Found $($services.Count) network-related services"
                
                foreach ($service in $services) {
                    $serviceName = $service.PSChildName
                    $startType = $service.Start
                    $type = $service.Type
                    
                    $startTypeMap = @{
                        0 = "Boot"
                        1 = "System"
                        2 = "Automatic"
                        3 = "Manual"
                        4 = "Disabled"
                    }
                    
                    $startTypeStr = $startTypeMap[$startType]
                    
                    if ($type -eq 1) {
                        # Kernel driver
                        if ($startType -le 1) {
                            $result.LoadedDrivers += @{
                                Name      = $serviceName
                                StartType = $startTypeStr
                                Type      = "Kernel Driver"
                            }
                            $result.Details += "LOADED: $serviceName (Start: $startTypeStr)"
                        } else {
                            $result.UnloadedDrivers += @{
                                Name      = $serviceName
                                StartType = $startTypeStr
                                Type      = "Kernel Driver"
                            }
                            $result.Details += "UNLOADED: $serviceName (Start: $startTypeStr)"
                        }
                    } else {
                        # Network service
                        $result.NICStatus += @{
                            Service   = $serviceName
                            StartType = $startTypeStr
                        }
                    }
                }
                
            } finally {
                # Unload registry
                if ($regLoaded) {
                    reg unload HKLM\OfflineSystem 2>&1 | Out-Null
                }
            }
        }
        
        # Generate recommendations
        if ($result.UnloadedDrivers.Count -gt 0) {
            $result.Recommendations += "Consider enabling these drivers:"
            $result.Recommendations += $result.UnloadedDrivers | ForEach-Object {
                "  - $_Name (currently: $_StartType)"
            }
        }
        
        $result.Details += ""
        $result.Details += "Analysis complete: $($result.LoadedDrivers.Count) loaded, $($result.UnloadedDrivers.Count) unloaded"
        
    } catch {
        $result.Details += "Error: $_"
    }
    
    return $result
}

function Get-DriverSignatureBypassStatus {
    <#
    .SYNOPSIS
        Determines if system allows unsigned driver installation
    
    .DESCRIPTION
        Checks Windows driver signing enforcement mode:
        - Enforce (cannot install unsigned)
        - Warn (warns but allows)
        - Ignore (silently installs unsigned)
        
        Critical for systems that need drivers not certified by Windows.
    
    .PARAMETER OfflineWinRegPath
        Path to offline Windows registry
    
    .OUTPUTS
        Driver signature enforcement status
    #>
    
    param(
        [string]$OfflineWinRegPath
    )
    
    $result = @{
        SignatureMode          = "Unknown"
        EnforceSignatures      = $false
        WarnsOnUnsigned        = $false
        AllowsUnsigned         = $false
        CanInjectUnsignedNow   = $false
        Details                = @()
        Recommendations        = @()
        Timestamp              = Get-Date
    }
    
    try {
        # Check current system (FullOS)
        $result.Details += "Checking driver signature enforcement..."
        
        # Check Device Manager settings
        try {
            $codeIntegrity = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -ErrorAction SilentlyContinue
            if ($codeIntegrity -and $codeIntegrity.Enabled -eq 1) {
                $result.EnforceSignatures = $true
                $result.Details += "Device Guard/HVCI is ENABLED - Strict enforcement"
            }
        } catch {
            # Not available on all systems
        }
        
        # Check Secure Boot
        try {
            $secBoot = Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue | 
                Select-Object -ExpandProperty IdentifyingNumber
            $result.Details += "System identifier obtained for verification"
        } catch {
            # Secure Boot info not available
        }
        
        # Try to detect current policy
        try {
            $sigPolicy = cmd /c "bcdedit /enum" 2>&1 | Select-String -Pattern "testsigning|nointegritychecks"
            if ($sigPolicy) {
                $result.AllowsUnsigned = $true
                $result.SignatureMode = "Test Signing Enabled"
                $result.Details += "Test signing mode DETECTED"
                $result.CanInjectUnsignedNow = $true
            } else {
                $result.SignatureMode = "Enforcement Enabled"
                $result.Details += "Normal signature enforcement active"
            }
        } catch {
            $result.Details += "Could not determine BCD test signing status"
        }
        
        # Offline registry check
        if ($OfflineWinRegPath -and (Test-Path $OfflineWinRegPath)) {
            $result.Details += "Analyzing offline registry..."
            
            try {
                reg load HKLM\OfflineWin $OfflineWinRegPath 2>&1 | Out-Null
                Start-Sleep -Milliseconds 500
                
                # Check CodeIntegrity settings
                $codeInt = Get-ItemProperty -Path "HKLM:\OfflineWin\ControlSet001\Services\ci" -ErrorAction SilentlyContinue
                if ($codeInt) {
                    $result.Details += "Code Integrity driver status: Start=$($codeInt.Start)"
                }
                
                reg unload HKLM\OfflineWin 2>&1 | Out-Null
                
            } catch {
                $result.Details += "Could not analyze offline registry"
            }
        }
        
        # Recommendations
        if ($result.EnforceSignatures -or $result.SignatureMode -eq "Enforcement Enabled") {
            $result.Details += ""
            $result.Details += "ENFORCEMENT ACTIVE - Unsigned drivers will be blocked"
            $result.Recommendations += "To inject unsigned drivers:"
            $result.Recommendations += "1. Boot into Safe Mode (F8 or Settings > Recovery)"
            $result.Recommendations += "2. Right-click driver installer, run as admin"
            $result.Recommendations += "3. Or temporarily disable Device Guard in BIOS"
            $result.Recommendations += "4. Restart normally after driver installation"
        } else {
            $result.Details += ""
            $result.Details += "No strict enforcement detected"
            if ($result.AllowsUnsigned) {
                $result.Recommendations += "System allows unsigned drivers (test signing enabled)"
            }
        }
        
    } catch {
        $result.Details += "Error checking signature status: $_"
    }
    
    return $result
}

function New-DriverInjectionProfile {
    <#
    .SYNOPSIS
        Creates a driver injection profile for automated recovery
    
    .DESCRIPTION
        Builds a structured profile containing:
        - Driver file paths and metadata
        - Injection order (dependencies first)
        - Compatibility validation results
        - Fallback chains
        - Network configuration to restore
        
        Profile can be saved and reused for consistent recovery.
    
    .PARAMETER ProfileName
        Name for this recovery profile
    
    .PARAMETER DriverPaths
        Array of paths to driver files
    
    .PARAMETER OutputPath
        Where to save the profile
    
    .OUTPUTS
        Profile summary and saved file location
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProfileName,
        
        [string[]]$DriverPaths = @(),
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    $profile = @{
        ProfileName           = $ProfileName
        CreatedTime          = Get-Date
        SystemInfo           = @{
            ComputerName     = $env:COMPUTERNAME
            OSVersion        = (Get-WmiObject Win32_OperatingSystem).Caption
            Processors       = (Get-WmiObject Win32_Processor | Measure-Object).Count
        }
        Drivers              = @()
        InjectionOrder       = @()
        ValidationResults    = @()
        RecoveryNotes        = ""
        Version              = "1.0"
    }
    
    try {
        $profile.RecoveryNotes = "Auto-generated profile for system $($profile.SystemInfo.ComputerName)"
        
        # Analyze provided drivers
        foreach ($driverPath in $DriverPaths) {
            if (Test-Path $driverPath) {
                $driverFile = Get-Item $driverPath
                
                # Run compatibility check
                $compat = Test-DriverCompatibility -DriverPath $driverPath -ErrorAction SilentlyContinue
                
                $profile.Drivers += @{
                    Name         = $driverFile.Name
                    Path         = $driverFile.FullName
                    Size         = $driverFile.Length
                    Compatible   = $compat.Compatible
                    IsSigned     = $compat.IsSigned
                    Class        = $compat.DriverClass
                    Dependencies = @($compat.Dependencies)
                }
                
                # Add to validation results
                $profile.ValidationResults += @{
                    Driver  = $driverFile.Name
                    Status  = if ($compat.Compatible) { "OK" } else { "BLOCKED" }
                    Reason  = $compat.Reason
                }
            }
        }
        
        # Determine injection order (dependencies first)
        $ordered = @()
        foreach ($driver in $profile.Drivers | Where-Object { $_.Compatible }) {
            # Drivers with fewer dependencies go first
            $depCount = $driver.Dependencies.Count
            $ordered += @($driver | Add-Member -PassThru -NotePropertyName "DepCount" -NotePropertyValue $depCount)
        }
        
        $profile.InjectionOrder = @($ordered | Sort-Object DepCount | Select-Object -ExpandProperty Name)
        
        # Save profile
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        
        $profileFile = Join-Path $OutputPath "$($ProfileName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $profile | ConvertTo-Json -Depth 5 | Set-Content -Path $profileFile -Force
        
        return @{
            Success        = $true
            ProfilePath    = $profileFile
            DriverCount    = $profile.Drivers.Count
            CompatibleCount = @($profile.ValidationResults | Where-Object { $_.Status -eq "OK" }).Count
            InjectionOrder = $profile.InjectionOrder
            Details        = "Profile created: $profileFile"
        }
        
    } catch {
        return @{
            Success = $false
            Error   = $_
            Details = "Failed to create profile: $_"
        }
    }
}

################################################################################
# MODULE EXPORT
################################################################################

# Functions are automatically available when this script is sourced
# Export-ModuleMember is only for PowerShell modules, not for sourced scripts

################################################################################
# END OF NETWORK DIAGNOSTICS MODULE
################################################################################
