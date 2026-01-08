# ============================================================================
# MIRACLEBOOT SLOW PC ANALYZER
# Version: 7.2.0
# Purpose: Diagnose slow PC performance and provide hardware upgrade recommendations
# Last Updated: January 7, 2026
# ============================================================================
#
# This module analyzes system performance and identifies root causes of slowness.
# Provides actionable recommendations including hardware upgrades where applicable.
#
# Key Features:
# - CPU analysis with performance metrics
# - RAM usage and availability analysis
# - Storage performance diagnostics (HDD vs SSD detection)
# - Startup programs and services analysis
# - Hardware temperature monitoring
# - Disk fragmentation analysis
# - Background process analysis
# - Hardware upgrade recommendations
#
# ============================================================================

function Get-SlowPCAnalysis {
    <#
    .SYNOPSIS
    Comprehensive analysis of system performance and slowness causes.
    
    .DESCRIPTION
    Performs deep analysis of system performance across multiple categories
    including CPU, RAM, storage, startup services, and background processes.
    
    .OUTPUTS
    PSCustomObject with detailed analysis and recommendations
    #>
    
    [CmdletBinding()]
    param()
    
    Write-Host "Starting comprehensive slow PC analysis..." -ForegroundColor Cyan
    
    $analysis = @{
        Timestamp = Get-Date
        CPUAnalysis = $null
        RAMAnalysis = $null
        StorageAnalysis = $null
        StartupAnalysis = $null
        TemperatureAnalysis = $null
        ProcessAnalysis = $null
        ServicesAnalysis = $null
        HardwareRecommendations = @()
        OverallSlownessCauses = @()
        HardwareBottleneck = $null
    }
    
    # ========================================================================
    # 1. CPU ANALYSIS
    # ========================================================================
    Write-Host "Analyzing CPU performance..." -ForegroundColor Yellow
    try {
        $cpuInfo = Get-WmiObject -Class Win32_Processor
        $cpuLoad = (Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 5 | Measure-Object -Property CookedValue -Average).Average
        $logicalCores = $cpuInfo.NumberOfLogicalProcessors
        $physicalCores = $cpuInfo.NumberOfCores
        
        $analysis.CPUAnalysis = @{
            Name = $cpuInfo.Name
            Cores = $physicalCores
            LogicalCores = $logicalCores
            MaxClockSpeed = $cpuInfo.MaxClockSpeed
            CurrentLoad = [Math]::Round($cpuLoad, 2)
            Generation = if ($cpuInfo.Name -match "i[3579]|Ryzen [3579]") { "Modern" } else { "Older" }
        }
        
        # CPU Performance Issues
        if ($analysis.CPUAnalysis.CurrentLoad -gt 80) {
            $analysis.OverallSlownessCauses += "High CPU usage detected ($($analysis.CPUAnalysis.CurrentLoad)%)"
        }
        
        if ($analysis.CPUAnalysis.Generation -eq "Older" -and $cpuInfo.MaxClockSpeed -lt 2000) {
            $analysis.HardwareBottleneck = "CPU"
            $analysis.OverallSlownessCauses += "CPU is aging and may be limiting system performance"
            $analysis.HardwareRecommendations += @{
                Component = "Processor"
                Current = $analysis.CPUAnalysis.Name
                Issue = "Older/slower CPU with limited cores"
                Recommendation = "Upgrade to modern multi-core processor (Intel i5/i7/i9 or AMD Ryzen 5/7/9)"
                ExpectedImprovement = "30-50% faster overall responsiveness"
                EstimatedCost = "Processor: `$200-400 | Motherboard: `$100-250 (if needed)"
                Note = "May require motherboard upgrade depending on current model"
            }
        }
    } catch {
        Write-Warning "Failed to analyze CPU: $_"
        $analysis.CPUAnalysis = @{ Error = $_.Exception.Message }
    }
    
    # ========================================================================
    # 2. RAM ANALYSIS
    # ========================================================================
    Write-Host "Analyzing RAM performance..." -ForegroundColor Yellow
    try {
        $memInfo = Get-WmiObject -Class Win32_ComputerSystem
        $osInfo = Get-WmiObject -Class Win32_OperatingSystem
        $totalRAM = [Math]::Round($osInfo.TotalVisibleMemorySize / 1024 / 1024, 2)
        $availableRAM = [Math]::Round($osInfo.FreePhysicalMemory / 1024 / 1024, 2)
        $usedRAM = $totalRAM - $availableRAM
        $ramUsagePercent = [Math]::Round(($usedRAM / $totalRAM) * 100, 2)
        
        $analysis.RAMAnalysis = @{
            TotalGB = $totalRAM
            UsedGB = $usedRAM
            AvailableGB = $availableRAM
            UsagePercent = $ramUsagePercent
            Type = if ($memInfo.SystemFamily -match "Virtual") { "Virtual Machine" } else { "Physical" }
        }
        
        # RAM Issues
        if ($ramUsagePercent -gt 90) {
            $analysis.OverallSlownessCauses += "RAM is critically low ($($analysis.RAMAnalysis.UsagePercent)% used)"
            if ($totalRAM -le 4) {
                $analysis.HardwareBottleneck = "RAM"
                $analysis.HardwareRecommendations += @{
                    Component = "Memory (RAM)"
                    Current = "$($analysis.RAMAnalysis.TotalGB)GB"
                    Issue = "Insufficient RAM for modern applications"
                    Recommendation = "Upgrade to at least 16GB RAM (32GB recommended)"
                    ExpectedImprovement = "Dramatic improvement in multitasking and application performance"
                    EstimatedCost = "`$50-100 (for 16GB DDR4/DDR5 kit)"
                    Note = "Most common cause of slow PCs. Upgrading RAM provides biggest performance boost."
                }
            } elseif ($totalRAM -eq 8) {
                $analysis.HardwareRecommendations += @{
                    Component = "Memory (RAM)"
                    Current = "8GB"
                    Issue = "8GB is minimal for modern Windows 11 and applications"
                    Recommendation = "Upgrade to 16GB or 32GB RAM"
                    ExpectedImprovement = "Significant improvement in multitasking"
                    EstimatedCost = "`$50-150 (for additional 8-24GB)"
                    Note = "Adding more RAM is often the most cost-effective upgrade."
                }
            }
        }
    } catch {
        Write-Warning "Failed to analyze RAM: $_"
        $analysis.RAMAnalysis = @{ Error = $_.Exception.Message }
    }
    
    # ========================================================================
    # 3. STORAGE ANALYSIS
    # ========================================================================
    Write-Host "Analyzing storage performance..." -ForegroundColor Yellow
    try {
        $volumes = Get-Volume | Where-Object { $_.DriveLetter } | Sort-Object DriveLetter
        $analysis.StorageAnalysis = @()
        
        foreach ($vol in $volumes) {
            $driveLetterPath = "$($vol.DriveLetter):"
            
            # Detect drive type
            $driveType = Detect-DriveType -DrivePath $driveLetterPath
            
            # Get size info
            $driveInfo = Get-PSDrive -Name $vol.DriveLetter -ErrorAction SilentlyContinue
            $totalSpace = $driveInfo.Used + $driveInfo.Free
            $freeSpace = $driveInfo.Free
            $usedSpace = $driveInfo.Used
            $freePercent = [Math]::Round(($freeSpace / $totalSpace) * 100, 2)
            $usedPercent = 100 - $freePercent
            
            # Fragmentation analysis (for HDD only)
            $fragmentation = 0
            if ($driveType -eq "HDD") {
                $fragmentation = Get-DiskFragmentation -DriveLetter $vol.DriveLetter
            }
            
            $storageInfo = @{
                DriveLetter = $vol.DriveLetter
                Label = $vol.FileSystemLabel
                Type = $driveType
                TotalGB = [Math]::Round($totalSpace / 1GB, 2)
                UsedGB = [Math]::Round($usedSpace / 1GB, 2)
                FreeGB = [Math]::Round($freeSpace / 1GB, 2)
                FreePercent = $freePercent
                UsedPercent = $usedPercent
                Fragmentation = $fragmentation
            }
            
            $analysis.StorageAnalysis += $storageInfo
            
            # Storage Issues
            if ($driveType -eq "HDD" -and $vol.DriveLetter -eq "C") {
                $analysis.OverallSlownessCauses += "System drive is using traditional HDD (mechanical)"
                $analysis.HardwareBottleneck = "Storage"
                
                $analysis.HardwareRecommendations += @{
                    Component = "Storage Drive"
                    Current = "HDD ($driveType)"
                    Issue = "System installed on slow mechanical hard drive"
                    Recommendation = "Upgrade to NVMe SSD (M.2 PCIe 4.0/5.0) or SATA SSD as minimum"
                    ExpectedImprovement = "Most dramatic improvement: 5-10x faster boot, application loading, and file operations"
                    EstimatedCost = "NVMe SSD: `$80-300 | SATA SSD: `$50-150"
                    Note = "This is the SINGLE BEST upgrade for a slow PC. Transforms system responsiveness."
                    Details = @{
                        NVMe = "PCIe 4.0: 5,000 MB/s | PCIe 5.0: 10,000+ MB/s | Cost: `$150-300 for 1TB"
                        SATA = "550 MB/s | Cost: `$50-150 for 1TB | Older but compatible with all systems"
                    }
                }
            }
            
            if ($freePercent -lt 10) {
                $analysis.OverallSlownessCauses += "Drive $($vol.DriveLetter): critically low free space ($freePercent%)"
            } elseif ($freePercent -lt 20) {
                $analysis.OverallSlownessCauses += "Drive $($vol.DriveLetter): low free space ($freePercent%)"
            }
            
            if ($driveType -eq "HDD" -and $fragmentation -gt 30) {
                $analysis.OverallSlownessCauses += "Drive $($vol.DriveLetter): Fragmented ($fragmentation%)"
            }
        }
    } catch {
        Write-Warning "Failed to analyze storage: $_"
        $analysis.StorageAnalysis = @{ Error = $_.Exception.Message }
    }
    
    # ========================================================================
    # 4. STARTUP PROGRAMS & SERVICES
    # ========================================================================
    Write-Host "Analyzing startup programs and services..." -ForegroundColor Yellow
    try {
        $startupApps = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue | Select-Object -Property * -ExcludeProperty PSPath, PSParentPath, PSChildName, PSDrive, PSProvider | Get-Member -MemberType NoteProperty | Measure-Object
        $startupServices = Get-Service | Where-Object { $_.StartType -eq "Automatic" -and $_.Status -eq "Running" } | Measure-Object
        
        $analysis.StartupAnalysis = @{
            StartupPrograms = $startupApps.Count
            AutomaticServices = $startupServices.Count
        }
        
        if ($analysis.StartupAnalysis.StartupPrograms -gt 20) {
            $analysis.OverallSlownessCauses += "Too many startup programs ($($analysis.StartupAnalysis.StartupPrograms))"
        }
    } catch {
        $analysis.StartupAnalysis = @{ Error = $_.Exception.Message }
    }
    
    # ========================================================================
    # 5. PROCESS ANALYSIS
    # ========================================================================
    Write-Host "Analyzing running processes..." -ForegroundColor Yellow
    try {
        $topProcesses = Get-Process | Sort-Object -Property WorkingSet -Descending | Select-Object -First 10 -Property Name, @{Name="MemoryMB";Expression={[Math]::Round($_.WorkingSet / 1MB, 2)}}
        $analysis.ProcessAnalysis = $topProcesses
    } catch {
        $analysis.ProcessAnalysis = @{ Error = $_.Exception.Message }
    }
    
    # ========================================================================
    # 6. BOOT TIME & STARTUP DIAGNOSTICS
    # ========================================================================
    Write-Host "Analyzing boot performance..." -ForegroundColor Yellow
    try {
        $lastBoot = (Get-Date) - (Get-Uptime)
        $bootTime = (Get-Uptime).TotalSeconds
        
        $analysis.BootAnalysis = @{
            LastBootTime = $lastBoot
            BootTimeSeconds = [Math]::Round($bootTime, 2)
            BootTimeMinutes = [Math]::Round($bootTime / 60, 2)
        }
        
        if ($bootTime -gt 120) {
            $analysis.OverallSlownessCauses += "Slow boot time detected ($($analysis.BootAnalysis.BootTimeMinutes) minutes)"
        }
    } catch {
        Write-Warning "Failed to get boot time: $_"
    }
    
    return $analysis
}

function Detect-DriveType {
    <#
    .SYNOPSIS
    Detects whether a drive is SSD or HDD
    #>
    param(
        [string]$DrivePath
    )
    
    try {
        $disk = Get-PhysicalDisk | Where-Object { (Get-Partition -DiskNumber $_.DiskNumber -ErrorAction SilentlyContinue | Get-Volume).DriveLetter -contains $DrivePath.TrimEnd(':') }
        
        if ($disk) {
            if ($disk.MediaType -eq "SSD" -or $disk.BusType -eq "NVMe") {
                return "SSD (NVMe)"
            } elseif ($disk.MediaType -eq "SSD") {
                return "SSD (SATA)"
            } else {
                return "HDD"
            }
        }
        
        # Fallback: Check Windows registry for storage info
        $regPath = "HKLM:\System\CurrentControlSet\Services\disk\Enum"
        if (Test-Path $regPath) {
            $diskInfo = Get-ItemProperty -Path $regPath
            if ($diskInfo.Device0 -match "SSD" -or $diskInfo.Device0 -match "NVMe") {
                return "SSD"
            }
        }
        
        return "Unknown"
    } catch {
        return "Unknown"
    }
}

function Get-DiskFragmentation {
    <#
    .SYNOPSIS
    Calculates disk fragmentation percentage
    #>
    param(
        [char]$DriveLetter
    )
    
    try {
        $fragmentation = 0
        $volumes = Get-Volume | Where-Object { $_.DriveLetter -eq $DriveLetter }
        
        if ($volumes) {
            # Try using Defrag API
            $defragOutput = Defrag "${DriveLetter}:" /U /V 2>&1
            if ($defragOutput -match "(\d+)% fragmented") {
                $fragmentation = [int]$matches[1]
            }
        }
        
        return $fragmentation
    } catch {
        return 0
    }
}

function Format-SlowPCAnalysisReport {
    <#
    .SYNOPSIS
    Formats analysis results into a readable report
    #>
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$Analysis
    )
    
    $lines = @()
    $lines += "MIRACLEBOOT SLOW PC ANALYSIS REPORT"
    $lines += "Generated: $($Analysis.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))"
    $lines += ""
    $lines += "Summary:"
    
    if ($Analysis.OverallSlownessCauses.Count -eq 0) {
        $lines += "  - No critical slowness causes detected."
    } else {
        $lines += "  - Found $($Analysis.OverallSlownessCauses.Count) performance issue(s):"
        $num = 1
        foreach ($cause in $Analysis.OverallSlownessCauses) {
            $lines += "    $num. $cause"
            $num++
        }
    }
    
    $lines += ""
    $lines += "CPU: $($Analysis.CPUAnalysis.Name) (Load: $($Analysis.CPUAnalysis.CurrentLoad)%)"
    $lines += "RAM: $($Analysis.RAMAnalysis.UsedGB)/$($Analysis.RAMAnalysis.TotalGB) GB ($($Analysis.RAMAnalysis.UsagePercent)%)"
    $lines += ""
    $lines += "Storage:"
    foreach ($storage in $Analysis.StorageAnalysis) {
        $lines += "  - $($storage.DriveLetter): $($storage.UsedPercent)% used"
    }
    
    return ($lines -join "`n")
}
function Get-PerformanceComparison {
    <#
    .SYNOPSIS
    Compares current hardware performance to typical modern standards
    #>
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$Analysis
    )
    
    $lines = @()
    $lines += "HARDWARE PERFORMANCE COMPARISON"
    $lines += "Storage: SSD/NVMe is the top upgrade for responsiveness."
    $lines += "RAM: $($Analysis.RAMAnalysis.TotalGB) GB (Usage: $($Analysis.RAMAnalysis.UsagePercent)%)"
    $lines += "CPU: $($Analysis.CPUAnalysis.Name) ($($Analysis.CPUAnalysis.Cores) cores)"
    
    if ($Analysis.RAMAnalysis.UsagePercent -gt 80) {
        $lines += "Recommendation: Consider upgrading RAM (16GB+)."
    }
    if ($Analysis.CPUAnalysis.Generation -eq "Older") {
        $lines += "Recommendation: CPU is older; newer CPUs improve performance per watt."
    }
    
    return ($lines -join "`n")
}

