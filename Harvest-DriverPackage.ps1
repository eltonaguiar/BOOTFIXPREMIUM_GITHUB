<#
.SYNOPSIS
MiracleBoot Driver Harvesting Module
Extracts, organizes, and packages drivers for offline injection into broken systems.

.DESCRIPTION
This module provides comprehensive driver harvesting capabilities:
- Scans running system for installed drivers
- Organizes drivers by category (Storage, Network, Display, Audio, etc.)
- Exports drivers to structured folder format
- Creates driver inventory CSV with metadata
- Prepares drivers for offline DISM injection

.AUTHOR
MiracleBoot Team - v7.2.0

.VERSION
1.0 - January 2026
#>

function Get-SystemDrivers {
    <#
    .SYNOPSIS
    Retrieves all system drivers from the running Windows installation.
    
    .OUTPUTS
    Array of PnpDevice objects with driver information
    #>
    Write-Host "Scanning system drivers..." -ForegroundColor Cyan
    
    try {
        $drivers = Get-PnpDevice | Where-Object { 
            $_.Status -eq 'OK' -and $null -ne $_.DriverVersion 
        } | Select-Object Name, DeviceID, Class, DriverVersion, Manufacturer, Present
        
        return $drivers
    } catch {
        Write-Host "Error retrieving drivers: $_" -ForegroundColor Red
        return $null
    }
}

function Get-DriverCategory {
    <#
    .SYNOPSIS
    Determines the category of a driver based on device class.
    
    .PARAMETER DeviceClass
    The Windows device class (e.g., 'Net', 'Display', 'MEDIA')
    
    .OUTPUTS
    String representing driver category folder
    #>
    param(
        [string]$DeviceClass
    )
    
    $categoryMap = @{
        'Net'           = 'Network'
        'Net_'          = 'Network'
        'HDC'           = 'Storage'
        'SCSIAdapter'   = 'Storage'
        'STORAGE'       = 'Storage'
        'Display'       = 'Display'
        'Monitor'       = 'Display'
        'MEDIA'         = 'Audio'
        'Ports'         = 'Ports'
        'USB'           = 'USB'
        'WDFDriver'     = 'System'
        'System'        = 'System'
        'CDROM'         = 'Storage'
        'DiskDrive'     = 'Storage'
    }
    
    foreach ($key in $categoryMap.Keys) {
        if ($DeviceClass -match $key) {
            return $categoryMap[$key]
        }
    }
    
    return 'Other'
}

function Export-DriverFiles {
    <#
    .SYNOPSIS
    Exports driver files from DriverStore to a structured folder.
    
    .PARAMETER OutputPath
    Root directory where drivers will be exported
    
    .PARAMETER Categories
    Array of driver categories to export (all by default)
    
    .OUTPUTS
    Summary of exported drivers
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [string[]]$Categories = @('Network', 'Storage', 'Display', 'Audio', 'USB', 'Ports', 'System', 'Other')
    )
    
    Write-Host "Exporting driver files from DriverStore..." -ForegroundColor Cyan
    
    $driverStoreRoot = "$env:SystemRoot\System32\DriverStore\FileRepository"
    $exportCount = 0
    $errorCount = 0
    
    if (-not (Test-Path $driverStoreRoot)) {
        Write-Host "DriverStore not found at: $driverStoreRoot" -ForegroundColor Red
        return $false
    }
    
    # Create category folders
    foreach ($category in $Categories) {
        $categoryPath = Join-Path $OutputPath $category
        if (-not (Test-Path $categoryPath)) {
            New-Item -ItemType Directory -Path $categoryPath -Force | Out-Null
            Write-Host "  Created folder: $category" -ForegroundColor Green
        }
    }
    
    # Export drivers by category
    Write-Host ""
    Write-Host "Copying driver files..." -ForegroundColor Yellow
    
    try {
        Get-ChildItem -Path $driverStoreRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $driverFolder = $_
            
            # Try to identify category from folder name
            $category = 'Other'
            if ($driverFolder.Name -match 'nic_|network|ethernet|wlan|wifi|broadcom|intel.*net|realtek.*net') {
                $category = 'Network'
            } elseif ($driverFolder.Name -match 'nvme|ahci|raid|storage|disk|scsi|sata|ata') {
                $category = 'Storage'
            } elseif ($driverFolder.Name -match 'nvidia|amd|intel.*gpu|display|video|graphics') {
                $category = 'Display'
            } elseif ($driverFolder.Name -match 'audio|sound|realtek.*audio|hdmi.*audio') {
                $category = 'Audio'
            } elseif ($driverFolder.Name -match 'usb|xhci|ehci|usbhub') {
                $category = 'USB'
            }
            
            $targetPath = Join-Path $OutputPath $category
            
            # Copy .inf, .sys, and other critical files
            Get-ChildItem -Path $driverFolder.FullName -File | Where-Object {
                $_.Extension -match '\.(inf|sys|cat|dll|bin)$'
            } | ForEach-Object {
                try {
                    Copy-Item -Path $_.FullName -Destination $targetPath -Force -ErrorAction SilentlyContinue
                    $exportCount++
                } catch {
                    $errorCount++
                }
            }
        }
    } catch {
        Write-Host "Error during driver export: $_" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Exported $exportCount driver files ($errorCount errors)" -ForegroundColor Green
    return $true
}

function Create-DriverInventory {
    <#
    .SYNOPSIS
    Creates a CSV inventory of all system drivers with metadata.
    
    .PARAMETER OutputPath
    Directory where inventory CSV will be created
    
    .OUTPUTS
    Path to created CSV file
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    Write-Host "Creating driver inventory..." -ForegroundColor Cyan
    
    $inventoryFile = Join-Path $OutputPath "DriverInventory.csv"
    $drivers = @()
    
    try {
        Get-PnpDevice | Where-Object { $null -ne $_.DriverVersion } | ForEach-Object {
            $driver = [PSCustomObject]@{
                Name = $_.Name
                DeviceID = $_.DeviceID
                Class = $_.Class
                Status = $_.Status
                DriverVersion = $_.DriverVersion
                Manufacturer = $_.Manufacturer
                HardwareIDs = ($_.HardwareIDs -join ';')
                ExportDate = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            }
            $drivers += $driver
        }
        
        $drivers | Export-Csv -Path $inventoryFile -NoTypeInformation -Encoding UTF8
        Write-Host "Inventory created: $inventoryFile" -ForegroundColor Green
        Write-Host "Total drivers: $($drivers.Count)" -ForegroundColor Yellow
        
        return $inventoryFile
    } catch {
        Write-Host "Error creating inventory: $_" -ForegroundColor Red
        return $null
    }
}

function New-DriverPackage {
    <#
    .SYNOPSIS
    Creates a complete driver package for offline injection.
    
    .PARAMETER OutputPath
    Root directory for the driver package
    
    .PARAMETER IncludeNetworkDrivers
    Include network drivers (default: $true)
    
    .PARAMETER IncludeStorageDrivers
    Include storage drivers (default: $true)
    
    .OUTPUTS
    Summary of package creation
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [bool]$IncludeNetworkDrivers = $true,
        [bool]$IncludeStorageDrivers = $true,
        [bool]$IncludeAllDrivers = $false
    )
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          MiracleBoot Driver Package Creator                   ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Create root package directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Determine categories to export
    $categoriesToExport = @()
    if ($IncludeAllDrivers) {
        $categoriesToExport = @('Network', 'Storage', 'Display', 'Audio', 'USB', 'Ports', 'System', 'Other')
    } else {
        if ($IncludeNetworkDrivers) { $categoriesToExport += 'Network' }
        if ($IncludeStorageDrivers) { $categoriesToExport += 'Storage' }
    }
    
    Write-Host "Creating package for categories: $($categoriesToExport -join ', ')" -ForegroundColor Yellow
    Write-Host ""
    
    # Export drivers
    $driversExported = Export-DriverFiles -OutputPath $OutputPath -Categories $categoriesToExport
    
    # Create inventory
    Create-DriverInventory -OutputPath $OutputPath
    
    # Create README
    $readmePath = Join-Path $OutputPath "README_DRIVERS.txt"
    @"
═══════════════════════════════════════════════════════════════════════
  MiracleBoot Driver Package
═══════════════════════════════════════════════════════════════════════

This driver package contains drivers exported from your current system.

FOLDER STRUCTURE:
  Network/          - Network adapter drivers (Ethernet, WiFi)
  Storage/          - Storage controller drivers (NVMe, AHCI, RAID, SATA)
  Display/          - Graphics and video drivers
  Audio/            - Sound card drivers
  USB/              - USB controller drivers
  Ports/            - Serial port and parallel port drivers
  System/           - System drivers and firmware
  Other/            - Miscellaneous drivers

HOW TO USE WITH OFFLINE INJECTION:
1. Copy these driver folders to a USB drive or network location
2. Boot broken system into WinRE/WinPE/Recovery environment
3. Run MiracleBoot TUI mode
4. Select "Inject Drivers Offline (DISM)"
5. Point to this package folder
6. Select target Windows drive
7. MiracleBoot will automatically inject all drivers

HOW TO USE WITH DISM MANUALLY:
  dism /Image:C: /Add-Driver /Driver:[Path] /Recurse /ForceUnsigned

DRIVER INVENTORY:
  See DriverInventory.csv for complete list of drivers with versions

CREATED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
SYSTEM: $env:COMPUTERNAME
"@ | Out-File -FilePath $readmePath -Encoding UTF8 -Force
    
    Write-Host "Package created successfully!" -ForegroundColor Green
    Write-Host "Location: $OutputPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Files created:" -ForegroundColor Cyan
    Get-ChildItem -Path $OutputPath -Recurse -File | ForEach-Object {
        Write-Host "  $($_.FullName)" -ForegroundColor Gray
    }
    
    return $OutputPath
}

# Interactive function for user-friendly driver harvesting
function Start-DriverHarvest {
    <#
    .SYNOPSIS
    Interactive driver harvesting wizard.
    #>
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║       MiracleBoot - Driver Harvesting Wizard                  ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "This wizard will harvest drivers from your system" -ForegroundColor Yellow
    Write-Host "and prepare them for offline injection into broken systems." -ForegroundColor Yellow
    Write-Host ""
    
    # Get output directory
    Write-Host "Enter output directory (default: $env:USERPROFILE\DriverPackage):" -ForegroundColor Cyan
    $outputPath = Read-Host
    if ([string]::IsNullOrWhiteSpace($outputPath)) {
        $outputPath = Join-Path $env:USERPROFILE "DriverPackage_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
    
    # Select driver categories
    Write-Host ""
    Write-Host "Select driver categories to harvest:" -ForegroundColor Cyan
    Write-Host "  1) Network drivers only (recommended for LAN issues)" -ForegroundColor Yellow
    Write-Host "  2) Storage drivers only (recommended for boot issues)" -ForegroundColor Yellow
    Write-Host "  3) Both Network and Storage" -ForegroundColor Yellow
    Write-Host "  4) All drivers (Network, Storage, Display, Audio, USB, etc.)" -ForegroundColor Yellow
    Write-Host ""
    
    $choice = Read-Host "Enter choice (1-4)"
    
    switch ($choice) {
        '1' { New-DriverPackage -OutputPath $outputPath -IncludeNetworkDrivers $true -IncludeStorageDrivers $false }
        '2' { New-DriverPackage -OutputPath $outputPath -IncludeNetworkDrivers $false -IncludeStorageDrivers $true }
        '3' { New-DriverPackage -OutputPath $outputPath -IncludeNetworkDrivers $true -IncludeStorageDrivers $true }
        '4' { New-DriverPackage -OutputPath $outputPath -IncludeAllDrivers $true }
        default { Write-Host "Invalid choice" -ForegroundColor Red; return }
    }
    
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Green
    Write-Host "  1. Copy the entire folder to a USB drive or network share" -ForegroundColor White
    Write-Host "  2. Boot broken system into WinRE/WinPE recovery mode" -ForegroundColor White
    Write-Host "  3. Run MiracleBoot in TUI mode" -ForegroundColor White
    Write-Host "  4. Select 'Inject Drivers Offline' and point to this package" -ForegroundColor White
    Write-Host ""
    Write-Host "Package location: $outputPath" -ForegroundColor Cyan
}
