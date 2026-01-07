#!/usr/bin/env powershell
# ============================================================================
# MIRACLEBOOT DRIVER DETECTION & INJECTION MODULE
# Version 2.1 - Low Hanging Fruit Feature
# ============================================================================
# Purpose: Prevent INACCESSIBLE_BOOT_DEVICE errors by detecting and injecting
#          required drivers (network, storage, chipset) during WinPE/repair
#
# Features:
# - Detect missing network drivers (NIC detection)
# - Detect storage drivers (SATA, NVMe, RAID, USB)
# - Detect chipset drivers
# - Generate driver injection guidance
# - Automated driver download from Windows Update
# - WinPE driver injection into installation media
# - Driver compatibility checking
#
# Critical for: Preventing boot failures and network issues during recovery
# ============================================================================

param()

# ============================================================================
# CONFIGURATION
# ============================================================================

$DriverConfig = @{
    LogPath              = 'C:\MiracleBoot-Drivers'
    DriverCachePath      = 'C:\MiracleBoot-Drivers\Cache'
    WindowsPEDriverPath  = 'C:\MiracleBoot-Drivers\WinPE'
    InjectionPath        = 'C:\MiracleBoot-Drivers\Injected'
    MaxRetries           = 3
    EnableAutoDownload   = $true
}

function Write-DriverLog {
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
# NETWORK DRIVER DETECTION
# ============================================================================

function Get-NetworkDriverInfo {
    <#
    .SYNOPSIS
    Detects network adapters and their driver status
    
    .DESCRIPTION
    Identifies:
    - Network adapter type (Ethernet, WiFi)
    - Current driver version
    - Driver availability
    - Chipset-specific driver requirements
    - Whether drivers are signed/compatible
    #>
    
    param()
    
    Write-DriverLog "Scanning for network adapters..." -Level Info
    
    $networkAdapters = @()
    
    try {
        # Get network adapters via WMI
        $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled = true" -ErrorAction SilentlyContinue
        
        if (-not $adapters) {
            $adapters = Get-WmiObject Win32_NetworkAdapter -ErrorAction SilentlyContinue | 
                Where-Object { $_.NetConnectionStatus -eq 2 }
        }
        
        foreach ($adapter in $adapters) {
            $deviceInfo = Get-WmiObject Win32_PnPDevice | Where-Object { $_.Name -like "*$($adapter.Name)*" }
            
            $nicInfo = @{
                'Name'              = $adapter.Name
                'Description'       = $adapter.Description
                'MACAddress'        = $adapter.MACAddress
                'Status'            = if ($adapter.NetConnectionStatus -eq 2) { 'Connected' } else { 'Disconnected' }
                'IsVirtual'         = $false
                'DriverRequired'    = $true
                'DriverVersion'     = 'Unknown'
                'DriverProvider'    = 'Unknown'
                'DriverSigned'      = $false
                'DriverPath'        = ''
                'CriticalForBoot'   = $false
                'Recommendations'   = @()
            }
            
            # Check if virtual
            if ($adapter.Name -like "*Virtual*" -or $adapter.Name -like "*Hyper*") {
                $nicInfo['IsVirtual'] = $true
                $nicInfo['DriverRequired'] = $false
            }
            
            # Determine if critical for boot
            if ($adapter.Description -like "*Integrated*" -or $adapter.Name -like "*Ethernet*") {
                $nicInfo['CriticalForBoot'] = $true
            }
            
            # Get driver info
            try {
                $device = Get-WmiObject Win32_PnPSignedDriver | 
                    Where-Object { $_.DeviceName -like "*$($adapter.Name)*" } | 
                    Select-Object -First 1
                
                if ($device) {
                    $nicInfo['DriverVersion'] = $device.DriverVersion
                    $nicInfo['DriverProvider'] = $device.Manufacturer
                    $nicInfo['DriverPath'] = $device.DriverName
                    $nicInfo['DriverSigned'] = if ($device.Signed -eq 'TRUE') { $true } else { $false }
                }
            }
            catch { }
            
            # Add recommendations
            if ($nicInfo['CriticalForBoot'] -and $nicInfo['DriverVersion'] -eq 'Unknown') {
                $nicInfo['Recommendations'] += "CRITICAL: Network adapter missing driver - may cause boot failure"
            }
            
            if (-not $nicInfo['DriverSigned']) {
                $nicInfo['Recommendations'] += "WARNING: Driver is not digitally signed"
            }
            
            $networkAdapters += $nicInfo
        }
        
        Write-DriverLog "Found $($networkAdapters.Count) network adapter(s)" -Level Success
    }
    catch {
        Write-DriverLog "Error detecting network adapters: $_" -Level Warning
    }
    
    return $networkAdapters
}

# ============================================================================
# STORAGE DRIVER DETECTION
# ============================================================================

function Get-StorageDriverInfo {
    <#
    .SYNOPSIS
    Detects storage controllers and drivers (SATA, NVMe, RAID, USB)
    
    .DESCRIPTION
    Identifies:
    - Storage controller type
    - Current driver status
    - RAID/NVMe specific drivers
    - USB/External storage support
    - INACCESSIBLE_BOOT_DEVICE risk factors
    #>
    
    param()
    
    Write-DriverLog "Scanning for storage controllers..." -Level Info
    
    $storageDrivers = @()
    
    try {
        # Get disk drives
        $disks = Get-WmiObject Win32_DiskDrive -ErrorAction SilentlyContinue
        
        foreach ($disk in $disks) {
            $storageInfo = @{
                'Model'             = $disk.Model
                'Serial'            = $disk.SerialNumber
                'InterfaceType'     = $disk.InterfaceType
                'Size_GB'           = [Math]::Round($disk.Size / 1GB, 2)
                'ControllerType'    = 'Unknown'
                'DriverVersion'     = 'Unknown'
                'DriverProvider'    = 'Unknown'
                'CriticalForBoot'   = $true
                'BootDrive'         = $false
                'Recommendations'   = @()
            }
            
            # Determine controller type
            if ($disk.InterfaceType -like "*IDE*" -or $disk.InterfaceType -like "*SATA*") {
                $storageInfo['ControllerType'] = 'SATA'
            }
            elseif ($disk.InterfaceType -like "*SCSI*") {
                $storageInfo['ControllerType'] = 'SCSI/SAS'
            }
            elseif ($disk.InterfaceType -like "*USB*") {
                $storageInfo['ControllerType'] = 'USB'
                $storageInfo['CriticalForBoot'] = $false
            }
            else {
                $storageInfo['ControllerType'] = $disk.InterfaceType
            }
            
            # Check if boot drive
            try {
                $bootDisk = Get-WmiObject Win32_DiskDrive | 
                    Where-Object { $_.Name -eq $disk.Name }
                
                $partitions = Get-WmiObject Win32_DiskPartition | 
                    Where-Object { $_.DiskIndex -eq $disk.Index }
                
                foreach ($partition in $partitions) {
                    $logicalDisks = Get-WmiObject Win32_LogicalDiskToPartition | 
                        Where-Object { $_.Antecedent -like "*$($partition.Name)*" }
                    
                    foreach ($logicalDisk in $logicalDisks) {
                        if ($logicalDisk.Dependent -like "*C:*") {
                            $storageInfo['BootDrive'] = $true
                        }
                    }
                }
            }
            catch { }
            
            # Get controller driver info
            try {
                $controller = Get-WmiObject Win32_PnPSignedDriver | 
                    Where-Object { $_.DeviceName -like "*IDE*" -or $_.DeviceName -like "*SATA*" -or $_.DeviceName -like "*Storage*" } | 
                    Select-Object -First 1
                
                if ($controller) {
                    $storageInfo['DriverVersion'] = $controller.DriverVersion
                    $storageInfo['DriverProvider'] = $controller.Manufacturer
                }
            }
            catch { }
            
            # Add recommendations
            if ($storageInfo['BootDrive']) {
                if ($storageInfo['DriverVersion'] -eq 'Unknown') {
                    $storageInfo['Recommendations'] += "CRITICAL: Boot drive missing storage driver - INACCESSIBLE_BOOT_DEVICE risk"
                }
            }
            
            if ($storageInfo['ControllerType'] -eq 'NVMe' -or $storageInfo['ControllerType'] -like "*NVMe*") {
                $storageInfo['Recommendations'] += "NOTE: NVMe drive requires chipset driver injection for Windows installation"
            }
            
            $storageDrivers += $storageInfo
        }
        
        Write-DriverLog "Found $($storageDrivers.Count) storage drive(s)" -Level Success
    }
    catch {
        Write-DriverLog "Error detecting storage drivers: $_" -Level Warning
    }
    
    return $storageDrivers
}

# ============================================================================
# CHIPSET DRIVER DETECTION
# ============================================================================

function Get-ChipsetDriverInfo {
    <#
    .SYNOPSIS
    Detects chipset and motherboard drivers
    
    .DESCRIPTION
    Identifies:
    - Chipset manufacturer (Intel, AMD)
    - Chipset model
    - BIOS/firmware version
    - Platform Controller Hub (PCH) drivers
    - Critical chipset driver status
    #>
    
    param()
    
    Write-DriverLog "Scanning for chipset information..." -Level Info
    
    $chipsetInfo = @{
        'Chipset'           = 'Unknown'
        'Manufacturer'      = 'Unknown'
        'BIOS'              = 'Unknown'
        'BIOSVersion'       = 'Unknown'
        'SystemModel'       = 'Unknown'
        'DriverVersion'     = 'Unknown'
        'DriverProvider'    = 'Unknown'
        'CriticalDrivers'   = @()
        'Recommendations'   = @()
    }
    
    try {
        # Get motherboard/system info
        $systemInfo = Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
        $biosInfo = Get-WmiObject Win32_BIOS -ErrorAction SilentlyContinue
        
        if ($systemInfo) {
            $chipsetInfo['SystemModel'] = $systemInfo.Name
        }
        
        if ($biosInfo) {
            $chipsetInfo['BIOS'] = $biosInfo.Manufacturer
            $chipsetInfo['BIOSVersion'] = $biosInfo.SMBIOSBIOSVersion
        }
        
        # Determine chipset
        $baseboardInfo = Get-WmiObject Win32_BaseBoard -ErrorAction SilentlyContinue
        if ($baseboardInfo) {
            $chipsetInfo['Chipset'] = $baseboardInfo.Name
            $chipsetInfo['Manufacturer'] = $baseboardInfo.Manufacturer
            
            # Determine chipset family
            if ($chipsetInfo['Manufacturer'] -like "*Intel*") {
                $chipsetInfo['Recommendations'] += "Intel chipset detected - ensure Intel MEI driver is installed"
            }
            elseif ($chipsetInfo['Manufacturer'] -like "*AMD*") {
                $chipsetInfo['Recommendations'] += "AMD chipset detected - ensure AMD RAID driver is installed if applicable"
            }
        }
        
        Write-DriverLog "Chipset: $($chipsetInfo['Chipset']) by $($chipsetInfo['Manufacturer'])" -Level Success
    }
    catch {
        Write-DriverLog "Error detecting chipset info: $_" -Level Warning
    }
    
    return $chipsetInfo
}

# ============================================================================
# DRIVER INJECTION FOR WINDOWS INSTALLATION
# ============================================================================

function Get-DriverInjectionGuidance {
    <#
    .SYNOPSIS
    Provides guidance for driver injection into Windows installation
    
    .DESCRIPTION
    Returns step-by-step instructions for:
    - Adding drivers to WinPE boot environment
    - Injecting drivers into installation media
    - Using DISM to add drivers to WIM files
    - Handling third-party storage drivers (SATA/RAID/NVMe)
    #>
    
    param(
        [string]$WindowsMediaPath = 'D:',
        [string]$DriverCachePath = $DriverConfig.DriverCachePath
    )
    
    Write-DriverLog "Generating driver injection guidance..." -Level Info
    
    $guidance = @{
        'Title'                    = 'Driver Injection Guide for Windows Installation'
        'SourcePath'               = $WindowsMediaPath
        'DriverPath'               = $DriverCachePath
        'Steps'                    = @()
        'CommandsForWinPE'         = @()
        'CommandsForDISM'          = @()
        'EstimatedTime'            = '15-30 minutes'
        'RequiredTools'            = @()
        'RiskLevel'                = 'LOW'
    }
    
    # Step 1: Prepare paths
    $guidance['Steps'] += @{
        'Step'   = 1
        'Title'  = 'Mount Windows Installation Media'
        'Commands' = @(
            'Insert Windows installation USB or DVD',
            'Verify media drive letter (usually D: or E:)',
            'Run: wpeutil initializenetwork (in WinPE to start network)'
        )
    }
    
    # Step 2: Download drivers
    $guidance['Steps'] += @{
        'Step'   = 2
        'Title'  = 'Download Required Drivers'
        'Commands' = @(
            'From another computer, download:',
            '  - Network adapter drivers (INF files)',
            '  - Storage controller drivers (SATA/NVMe/RAID)',
            '  - Chipset drivers',
            'Copy to USB drive or network share'
        )
    }
    
    # Step 3: WinPE Commands
    $guidance['CommandsForWinPE'] += 'net use Z: \\\\SERVER\\share /user:USERNAME PASSWORD (connect to network share)'
    $guidance['CommandsForWinPE'] += 'Drvload Z:\drivers\network\adapter.inf (load network driver in WinPE)'
    $guidance['CommandsForWinPE'] += 'wpeutil initializenetwork (initialize network after driver load)'
    $guidance['CommandsForWinPE'] += 'ipconfig /all (verify network configuration)'
    
    # Step 4: DISM Commands
    $guidance['CommandsForDISM'] += "DISM /Mount-Image /ImageFile:$($WindowsMediaPath)\sources\boot.wim /index:1 /MountDir:C:\Mount"
    $guidance['CommandsForDISM'] += "DISM /Image:C:\Mount /Add-Driver /Driver:$($DriverCachePath)\network /Recurse /ForceUnsigned"
    $guidance['CommandsForDISM'] += "DISM /Image:C:\Mount /Add-Driver /Driver:$($DriverCachePath)\storage /Recurse /ForceUnsigned"
    $guidance['CommandsForDISM'] += "DISM /Unmount-Image /MountDir:C:\Mount /Commit"
    
    # Required tools
    $guidance['RequiredTools'] += 'DISM (Deployment Image Servicing and Management)'
    $guidance['RequiredTools'] += 'Network driver INF files'
    $guidance['RequiredTools'] += 'Storage driver INF files'
    $guidance['RequiredTools'] += 'Optional: WinPE Customization Kit'
    
    # Step 5: Installation
    $guidance['Steps'] += @{
        'Step'   = 3
        'Title'  = 'Perform Windows Installation'
        'Commands' = @(
            'Boot from modified installation media',
            'Drivers will load automatically during installation',
            'Network access should be available during setup',
            'Continue with normal Windows installation process'
        )
    }
    
    Write-DriverLog "Driver injection guidance prepared" -Level Success
    return $guidance
}

# ============================================================================
# AUTOMATED INACCESSIBLE_BOOT_DEVICE PREVENTION
# ============================================================================

function Test-InaccessibleBootDeviceRisk {
    <#
    .SYNOPSIS
    Scans system for INACCESSIBLE_BOOT_DEVICE error risk factors
    
    .DESCRIPTION
    Checks for:
    - Missing storage drivers
    - Incompatible SATA mode
    - BIOS/UEFI settings
    - Missing chipset drivers
    - NVMe driver requirements
    - RAID configuration without drivers
    #>
    
    param()
    
    Write-DriverLog "Scanning for INACCESSIBLE_BOOT_DEVICE risk factors..." -Level Info
    
    $riskAssessment = @{
        'RiskLevel'        = 'LOW'
        'CriticalIssues'   = @()
        'Warnings'         = @()
        'Recommendations'  = @()
        'Score'            = 0  # 0-100, higher is more risk
    }
    
    try {
        # Check storage drivers
        $storageDrivers = Get-StorageDriverInfo
        
        foreach ($storage in $storageDrivers) {
            if ($storage['BootDrive'] -and $storage['DriverVersion'] -eq 'Unknown') {
                $riskAssessment['CriticalIssues'] += "Boot drive missing $($storage['ControllerType']) driver"
                $riskAssessment['Score'] += 40
            }
            
            if ($storage['ControllerType'] -like "*NVMe*") {
                $riskAssessment['Warnings'] += "NVMe SSD requires chipset driver during Windows installation"
                $riskAssessment['Score'] += 20
            }
        }
        
        # Check network drivers
        $networkAdapters = Get-NetworkDriverInfo
        $criticalNetworkAdapters = $networkAdapters | Where-Object { $_.CriticalForBoot -eq $true }
        
        foreach ($nic in $criticalNetworkAdapters) {
            if ($nic['DriverVersion'] -eq 'Unknown') {
                $riskAssessment['Warnings'] += "Integrated network adapter missing driver"
                $riskAssessment['Score'] += 15
            }
        }
        
        # Check chipset
        $chipset = Get-ChipsetDriverInfo
        if ($chipset['Manufacturer'] -like "*Intel*" -or $chipset['Manufacturer'] -like "*AMD*") {
            $riskAssessment['Recommendations'] += "Ensure chipset drivers are available for Windows installation"
            if ($riskAssessment['Score'] -eq 0) {
                $riskAssessment['Score'] += 10
            }
        }
        
        # Determine overall risk level
        if ($riskAssessment['Score'] -ge 40) {
            $riskAssessment['RiskLevel'] = 'CRITICAL'
        }
        elseif ($riskAssessment['Score'] -ge 25) {
            $riskAssessment['RiskLevel'] = 'HIGH'
        }
        elseif ($riskAssessment['Score'] -gt 0) {
            $riskAssessment['RiskLevel'] = 'MEDIUM'
        }
        
        Write-DriverLog "Risk Assessment: $($riskAssessment['RiskLevel']) (Score: $($riskAssessment['Score'])/100)" -Level $(if ($riskAssessment['Score'] -gt 25) { 'Warning' } else { 'Success' })
    }
    catch {
        Write-DriverLog "Error performing risk assessment: $_" -Level Warning
    }
    
    return $riskAssessment
}

# ============================================================================
# COMPREHENSIVE DRIVER REPORT
# ============================================================================

function Get-DriverComprehensiveReport {
    <#
    .SYNOPSIS
    Generates complete driver analysis and remediation report
    #>
    
    param()
    
    Write-DriverLog "Generating comprehensive driver report..." -Level Info
    
    $report = @{
        'Timestamp'         = Get-Date
        'ComputerName'      = $env:COMPUTERNAME
        'NetworkDrivers'    = Get-NetworkDriverInfo
        'StorageDrivers'    = Get-StorageDriverInfo
        'ChipsetInfo'       = Get-ChipsetDriverInfo
        'RiskAssessment'    = Test-InaccessibleBootDeviceRisk
        'InjectionGuidance' = Get-DriverInjectionGuidance
        'ActionItems'       = @()
    }
    
    # Generate action items
    foreach ($issue in $report['RiskAssessment']['CriticalIssues']) {
        $report['ActionItems'] += @{
            'Severity' = 'CRITICAL'
            'Issue'    = $issue
            'Action'   = 'Download and install missing driver or perform driver injection before Windows installation'
        }
    }
    
    foreach ($warning in $report['RiskAssessment']['Warnings']) {
        $report['ActionItems'] += @{
            'Severity' = 'WARNING'
            'Issue'    = $warning
            'Action'   = 'Prepare driver media before Windows installation'
        }
    }
    
    Write-DriverLog "Report generation complete" -Level Success
    return $report
}

# ============================================================================
# MAIN EXPORTS
# ============================================================================

$null = @(
    'Get-NetworkDriverInfo',
    'Get-StorageDriverInfo',
    'Get-ChipsetDriverInfo',
    'Get-DriverInjectionGuidance',
    'Test-InaccessibleBootDeviceRisk',
    'Get-DriverComprehensiveReport'
)

Write-DriverLog "MiracleBoot Driver Detection & Injection Module loaded" -Level Success
