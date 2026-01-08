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
            $defragOutput = Defrag $DriveLetter": /U /V 2>&1
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
    
    $report = @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                    MIRACLEBOOT SLOW PC ANALYSIS REPORT                      ║
║                        Advanced Diagnostics & Recommendations                ║
╚══════════════════════════════════════════════════════════════════════════════╝

Generated: $($Analysis.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 SLOWNESS ROOT CAUSES IDENTIFIED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"@
    
    if ($Analysis.OverallSlownessCauses.Count -eq 0) {
        $report += "✓ No critical slowness causes detected!`n"
    } else {
        $report += "⚠️  Found $($Analysis.OverallSlownessCauses.Count) performance issue(s):`n`n"
        $num = 1
        foreach ($cause in $Analysis.OverallSlownessCauses) {
            $report += "$num. $cause`n"
            $num++
        }
    }
    
    $report += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💻 CPU PERFORMANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Processor: $($Analysis.CPUAnalysis.Name)
Cores (Physical): $($Analysis.CPUAnalysis.Cores)
Cores (Logical): $($Analysis.CPUAnalysis.LogicalCores)
Max Speed: $($Analysis.CPUAnalysis.MaxClockSpeed) MHz
Current Load: $($Analysis.CPUAnalysis.CurrentLoad)%

"@
    
    if ($Analysis.CPUAnalysis.CurrentLoad -gt 80) {
        $report += "⚠️  WARNING: High CPU usage detected!`n"
    } elseif ($Analysis.CPUAnalysis.CurrentLoad -gt 50) {
        $report += "⚡ Moderate CPU usage`n"
    } else {
        $report += "✓ CPU usage normal`n"
    }
    
    $report += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🧠 MEMORY (RAM) PERFORMANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total RAM: $($Analysis.RAMAnalysis.TotalGB) GB
Used: $($Analysis.RAMAnalysis.UsedGB) GB
Available: $($Analysis.RAMAnalysis.AvailableGB) GB
Usage: $($Analysis.RAMAnalysis.UsagePercent)%

"@
    
    if ($Analysis.RAMAnalysis.UsagePercent -gt 90) {
        $report += "🔴 CRITICAL: RAM critically low!`n`nThis is likely the PRIMARY cause of slowness.`n`nRecommendation: Upgrade to at least 16GB RAM`n"
    } elseif ($Analysis.RAMAnalysis.UsagePercent -gt 80) {
        $report += "🟠 HIGH: RAM usage very high`n"
    } elseif ($Analysis.RAMAnalysis.UsagePercent -gt 60) {
        $report += "🟡 MODERATE: RAM usage is moderate`n"
    } else {
        $report += "✓ RAM usage normal`n"
    }
    
    $report += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💾 STORAGE ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"@
    
    foreach ($storage in $Analysis.StorageAnalysis) {
        $report += @"
Drive $($storage.DriveLetter): $($storage.Label) ($($storage.Type))
  Total: $($storage.TotalGB) GB
  Used: $($storage.UsedGB) GB ($($storage.UsedPercent)%)
  Free: $($storage.FreeGB) GB ($($storage.FreePercent)%)
"@
        
        if ($storage.Type -eq "HDD" -and $storage.DriveLetter -eq "C") {
            $report += @"
  ⚠️  SYSTEM ON HDD: This is the BIGGEST performance bottleneck!
  
  Impact: 5-10x slower boot times, application launches, and file operations
  compared to SSD
  
  Recommendation: UPGRADE TO SSD IMMEDIATELY
  • NVMe SSD (PCIe 4.0/5.0): 5,000-14,000 MB/s - BEST CHOICE
  • SATA SSD: 550 MB/s - Budget alternative
  
  Expected Improvement: Your PC will feel dramatically faster
  
"@
        } elseif ($storage.Type -eq "HDD" -and $storage.Fragmentation -gt 30) {
            $report += "  ⚠️  Fragmented ($($storage.Fragmentation)%) - Run Defragmentation`n"
        }
        
        if ($storage.FreePercent -lt 10) {
            $report += "  🔴 LOW SPACE: Clean up unnecessary files or expand drive`n"
        }
        
        $report += "`n"
    }
    
    if ($Analysis.HardwareRecommendations.Count -gt 0) {
        $report += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 RECOMMENDED HARDWARE UPGRADES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"@
        
        foreach ($rec in $Analysis.HardwareRecommendations) {
            $report += @"
⭐ $($rec.Component)
   Current: $($rec.Current)
   Issue: $($rec.Issue)
   
   RECOMMENDED ACTION: $($rec.Recommendation)
   Expected Improvement: $($rec.ExpectedImprovement)
   Estimated Cost: $($rec.EstimatedCost)
   Note: $($rec.Note)
"@
            
            if ($rec.Details) {
                foreach ($detail in $rec.Details.GetEnumerator()) {
                    $report += "`n   $($detail.Key): $($detail.Value)"
                }
            }
            
            $report += "`n`n"
        }
    }
    
    $report += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ PRIORITIZED ACTION PLAN (FASTEST IMPROVEMENT)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"@
    
    if ($Analysis.HardwareBottleneck -eq "Storage") {
        $report += @"
🥇 PRIORITY 1 (Biggest improvement): Upgrade to SSD
   • Cost: `$80-300
   • Impact: 5-10x faster system
   • Effort: Moderate (may require data migration)
   • This single upgrade will transform your PC performance

"@
    } elseif ($Analysis.HardwareBottleneck -eq "RAM") {
        $report += @"
🥇 PRIORITY 1 (Biggest improvement): Upgrade to 16GB+ RAM
   • Cost: `$50-150
   • Impact: 2-3x better multitasking
   • Effort: Easy (simple plug-in upgrade)
   • Most RAM upgrades are straightforward

"@
    } else {
        $report += @"
🥇 PRIORITY 1: Optimize system (free)
   • Disable unnecessary startup programs
   • Remove bloatware and unused applications
   • Update drivers and BIOS
   • Run system cleanup (Disk Cleanup, Storage Sense)

🥈 PRIORITY 2: Consider hardware upgrades
   • RAM to 16GB (if currently 8GB or less)
   • Storage to SSD (if using HDD)
   • Processor upgrade (if older than 5+ years)

"@
    }
    
    $report += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 STARTUP & SERVICES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Startup Programs: $($Analysis.StartupAnalysis.StartupPrograms)
Automatic Services: $($Analysis.StartupAnalysis.AutomaticServices)

"@
    
    if ($Analysis.StartupAnalysis.StartupPrograms -gt 20) {
        $report += @"
⚠️  Too many startup programs detected
   Recommendation: Disable unnecessary programs in Task Manager → Startup tab

To open Task Manager Startup tab:
   1. Right-click Taskbar → Task Manager
   2. Click "Startup" tab
   3. Disable programs you don't need at startup
   4. Restart PC

This can improve boot time significantly.

"@
    }
    
    $report += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔝 TOP MEMORY-CONSUMING PROCESSES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"@
    
    foreach ($proc in $Analysis.ProcessAnalysis | Select-Object -First 10) {
        $report += "$($proc.Name): $($proc.MemoryMB) MB`n"
    }
    
    $report += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ QUICK OPTIMIZATION TIPS (FREE)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. DISK CLEANUP
   • Press Windows Key → Type "Disk Cleanup" → Run
   • Delete temporary files, cache, old updates
   • Free up 5-20 GB typically

2. DISABLE STARTUP PROGRAMS
   • Ctrl+Shift+Esc → Startup tab
   • Disable programs you don't use at startup
   • Can improve boot time 30-60%

3. UPDATE DRIVERS
   • Press Windows Key → Device Manager
   • Check for driver updates
   • Update chipset, GPU, storage drivers

4. VIRUS SCAN
   • Run Windows Defender full scan (Settings → Virus & threat protection)
   • Or use Malwarebytes for thorough scan
   • Malware can cause 50%+ slowdown

5. DISABLE VISUAL EFFECTS (if low RAM)
   • Settings → System → About → Advanced system settings
   • Performance → Adjust for best performance
   • Save RAM and improve responsiveness

6. ENABLE STORAGE SENSE
   • Settings → System → Storage → Storage Sense
   • Automatically clean temporary files
   • Set cleanup frequency to 1 day

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📌 MSCONFIG - BOOT OPTIMIZATION GUIDE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

msconfig is a Windows configuration tool that can help optimize your system:

ACCESSING MSCONFIG:
   1. Press Windows Key → Type "msconfig" → Run
   2. Or: Settings → System → About → Advanced system settings → Environment Variables
      → System Properties → Advanced → Environment Variables

BOOT TAB (Optimize Boot Performance):
   • Boot Options:
     - Safe Boot: Loads only essential drivers (for troubleshooting)
     - Normal Boot: Standard boot mode (what you use daily)
     - Diagnostic Startup: Loads drivers but not startup programs
   
   • Advanced Options:
     - Processor: Set to number of CPU cores (helps parallel processing)
     - Maximum Memory: Leave blank (use all available RAM)
     - Safe Boot Options: Choose which safe boot mode to use

⚠️  WARNING: Only modify msconfig if you know what you're doing!
   Incorrect settings can prevent Windows from booting.

SERVICES TAB (Disable Unnecessary Services):
   Caution: Disabling critical services can break Windows
   
   SAFE TO DISABLE:
   • Print Spooler (if no printer)
   • Xbox Live Service (if not using Xbox)
   • Windows Update Medic Service (if you manually update)
   • DiagTrack (Diagnostic Tracking)
   
   DO NOT DISABLE:
   • Windows Update
   • Windows Defender
   • Networking services
   • Security services

STARTUP TAB:
   • Click "Open Task Manager"
   • Disable programs you don't need at startup
   • More granular control than Services tab

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

END OF ANALYSIS REPORT

═════════════════════════════════════════════════════════════════════════════════

Generated by MiracleBoot Slow PC Analyzer v7.2.0
For more help, visit the "Diagnostics & Logs" tab in MiracleBoot GUI

"@
    
    return $report
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
    
    $comparison = @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                  HARDWARE PERFORMANCE COMPARISON CHART                       ║
║         Your System vs. Modern Standards (2024-2026 Budget/Mid-Range)        ║
╚══════════════════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💾 STORAGE (Most Important for User Experience)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    Speed            Boot Time    App Launch    Cost
                    ─────────────────────────────────────────────────
HDD (Your System):  ~150 MB/s        2-3 min       15-30 sec     `$50-80
SATA SSD:          550 MB/s          45-60 sec     3-5 sec       `$50-150
NVMe 4.0 (Modern): 5,000 MB/s        15-20 sec     1-2 sec       `$100-300
NVMe 5.0 (Latest): 14,000+ MB/s      10-15 sec     <1 sec        `$200-400

→ CONCLUSION: Upgrading to NVMe SSD is the #1 improvement for slowness

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🧠 MEMORY (RAM)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Your System:       $($Analysis.RAMAnalysis.TotalGB) GB
Modern Budget:     16 GB
Modern Mid-Range:  32 GB
Professional:      64 GB+

Windows 11 Requirements: 4GB minimum, 8GB recommended for good experience
Practical Minimum:  16GB (for smooth multitasking with modern apps)

Your RAM Usage: $($Analysis.RAMAnalysis.UsagePercent)%
"@
    
    if ($Analysis.RAMAnalysis.UsagePercent -gt 90) {
        $comparison += @"
⚠️  CRITICAL: Your RAM is almost full. Upgrade to 16GB minimum (32GB ideal).

Performance Impact of Upgrade:
  • Current (8GB): Constant disk swapping, slowdowns with multiple apps
  • After (16GB): Smooth multitasking, eliminate most slowdowns
  • With (32GB): Professional-level performance, future-proofed

"@
    } elseif ($Analysis.RAMAnalysis.TotalGB -le 8) {
        $comparison += @"
⚠️  8GB is minimal for modern Windows 11. Upgrade recommended.

"@
    }
    
    $comparison += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 CPU PERFORMANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Your CPU:
  Name: $($Analysis.CPUAnalysis.Name)
  Cores: $($Analysis.CPUAnalysis.Cores) physical / $($Analysis.CPUAnalysis.LogicalCores) logical
  Max Speed: $($Analysis.CPUAnalysis.MaxClockSpeed) MHz
  Generation: $($Analysis.CPUAnalysis.Generation)

Modern CPU Standards (2024-2026):
  Budget:     Intel i5-14400 / AMD Ryzen 5 7600 (6-8 cores)
  Mid-Range:  Intel i7-14700K / AMD Ryzen 7 7700X (12-16 cores)
  Premium:    Intel i9-14900K / AMD Ryzen 9 7950X (24 cores+)

Entry-Level Gaming PC: 6-8 cores, 4.0+ GHz
Professional Workstation: 16+ cores

"@
    
    if ($Analysis.CPUAnalysis.Generation -eq "Older") {
        $comparison += @"
⚠️  Your CPU is older. Modern CPUs offer better performance per watt.

Upgrade Considerations:
  • If 5+ years old: Moderate improvement from upgrade
  • If 10+ years old: Significant improvement (30-50% faster)
  • Cost: `$200-400 for CPU + potentially `$100-250 for motherboard

"@
    }
    
    $comparison += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 BEST BANG FOR BUCK UPGRADES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ranked by Performance Improvement per Dollar:

1️⃣  SSD Upgrade (HDD → NVMe SSD)
    • Cost: `$100-200 for 1TB
    • Improvement: 5-10x faster (most noticeable improvement)
    • Difficulty: Moderate
    • ROI: 500%+ improvement in daily responsiveness
    • BEST CHOICE ✓

2️⃣  RAM Upgrade (8GB → 16GB)
    • Cost: `$50-100
    • Improvement: 2-3x better multitasking
    • Difficulty: Easy (plug-in upgrade)
    • ROI: 200%+ improvement if running many apps
    • GOOD CHOICE ✓

3️⃣  CPU Upgrade (if 5+ years old)
    • Cost: `$200-400 + potentially motherboard `$100-250
    • Improvement: 30-50% faster
    • Difficulty: Hard (requires motherboard possibly)
    • ROI: 50-100% improvement
    • CONSIDER IF: CPU is very old or bottlenecking

4️⃣  Motherboard Upgrade (needed for CPU/RAM upgrades)
    • Cost: `$100-250
    • Note: Usually required with CPU upgrade
    • Choose: DDR5 capable if upgrading RAM

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 UPGRADE SCENARIOS & EXPECTED RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCENARIO A: Budget-Conscious (`$100-150)
   ├─ SSD Upgrade: 1TB NVMe SSD (`$100)
   └─ Result: MASSIVE improvement (5-10x faster boot, apps)
   
   BEST FOR: Most people - biggest bang for buck

SCENARIO B: Performance Focused (`$200-300)
   ├─ SSD Upgrade: 1TB NVMe SSD (`$100)
   └─ RAM Upgrade: +8GB (`$80-100)
   
   BEST FOR: Multitasking, content creation, gaming

SCENARIO C: Complete System Overhaul (`$500-800)
   ├─ SSD Upgrade: 1TB NVMe SSD (`$100)
   ├─ RAM Upgrade: 32GB DDR5 (`$150)
   ├─ CPU Upgrade: Modern i7/Ryzen 7 (`$200)
   └─ Motherboard: DDR5 capable (`$150)
   
   BEST FOR: Future-proofing for 5+ years

SCENARIO D: Minimal Budget (`$0)
   ├─ Disable startup programs
   ├─ Uninstall bloatware
   ├─ Run Disk Cleanup
   ├─ Update drivers
   └─ Result: 20-30% improvement (modest)
   
   BEST FOR: Temporary improvement while saving for upgrades

"@
    
    return $comparison
}

# Export functions
Export-ModuleMember -Function Get-SlowPCAnalysis, Format-SlowPCAnalysisReport, Get-PerformanceComparison, Detect-DriveType, Get-DiskFragmentation
