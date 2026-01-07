# NetworkDiagnostics.ps1 - TIER 4 Features Documentation

## Overview

TIER 4 introduces advanced network performance analysis, WiFi diagnostics, security auditing, and firewall management capabilities to MiracleBoot's NetworkDiagnostics module.

---

## TIER 4: Network Performance & Security Analysis

### 1. Test-NetworkPerformance

**Purpose**: Comprehensive network performance testing suite

**Features**:
- Measures bandwidth (upload/download speeds)
- Tests latency (ping times to multiple targets)
- Calculates jitter (latency variation)
- Monitors packet loss percentage
- Assesses connection stability over time
- Provides quality rating (Excellent/Good/Fair/Poor/Critical)

**Usage**:
```powershell
# Basic performance test
$perf = Test-NetworkPerformance

# Custom test with specific duration and endpoints
$perf = Test-NetworkPerformance -TestDuration 10 -TestEndpoints @("8.8.8.8", "1.1.1.1", "4.2.2.2")

# View results
Write-Host "Average Latency: $($perf.AverageLatency)ms"
Write-Host "Jitter: $($perf.Jitter)ms"
Write-Host "Packet Loss: $($perf.PacketLoss)%"
Write-Host "Download Speed: $($perf.DownloadSpeed) Mbps"
Write-Host "Connection Quality: $($perf.ConnectionQuality)"
```

**Output Structure**:
```powershell
@{
    TestStartTime      = DateTime
    Duration           = Integer (seconds)
    Endpoints          = Array of IP addresses
    LatencyResults     = Array of per-endpoint results
    AverageLatency     = Decimal (milliseconds)
    MinLatency         = Integer (milliseconds)
    MaxLatency         = Integer (milliseconds)
    Jitter             = Decimal (milliseconds)
    PacketLoss         = Decimal (percentage)
    DownloadSpeed      = Decimal (Mbps)
    ConnectionQuality  = String (Excellent/Good/Fair/Poor/Critical)
    Details            = Array of diagnostic messages
    Warnings           = Array of warning messages
    Timestamp          = String (yyyy-MM-dd HH:mm:ss)
}
```

**Use Cases**:
- Diagnose slow network connections
- Measure connection stability for VoIP/video calls
- Compare performance across different times of day
- Validate network upgrades
- Troubleshoot intermittent connectivity issues

---

### 2. Get-WiFiNetworkInfo

**Purpose**: Analyzes WiFi networks and signal strength

**Features**:
- Scans and displays all available WiFi networks
- Measures signal strength (RSSI)
- Identifies channel utilization
- Detects security protocols (WPA2, WPA3, Open, WEP)
- Distinguishes 2.4GHz vs 5GHz bands
- Analyzes network congestion
- Recommends best channels

**Usage**:
```powershell
# Scan all WiFi networks
$wifi = Get-WiFiNetworkInfo

# Show only currently connected network
$wifi = Get-WiFiNetworkInfo -CurrentOnly

# View results
Write-Host "Networks found: $($wifi.Networks.Count)"
Write-Host "Current Network: $($wifi.CurrentNetwork.SSID)"
Write-Host "Signal Strength: $($wifi.CurrentNetwork.Signal)%"
Write-Host "Channel: $($wifi.CurrentNetwork.Channel)"
Write-Host "Best Channel: $($wifi.BestChannel)"

# Display all networks
$wifi.Networks | Format-Table SSID, Signal, Channel, Band, Authentication
```

**Output Structure**:
```powershell
@{
    Networks          = Array of network objects
    CurrentNetwork    = Object (currently connected network)
    ChannelAnalysis   = Array of channel congestion data
    BestChannel       = String (recommended channel)
    Recommendations   = Array of improvement suggestions
    Details           = Array of diagnostic messages
    Timestamp         = String (yyyy-MM-dd HH:mm:ss)
}
```

**Network Object Structure**:
```powershell
@{
    SSID           = String (network name)
    Authentication = String (security type)
    Encryption     = String (encryption method)
    Signal         = Integer (0-100%)
    Channel        = Integer (channel number)
    Band           = String ("2.4 GHz" or "5 GHz")
    BSSID          = String (MAC address)
    Connected      = Boolean
}
```

**Use Cases**:
- Troubleshoot weak WiFi signals
- Identify channel congestion
- Find optimal WiFi channel for router
- Detect security vulnerabilities (Open/WEP networks)
- Choose between 2.4GHz and 5GHz networks

---

### 3. Invoke-NetworkSecurityAudit

**Purpose**: Performs comprehensive network security audit

**Features**:
- Checks Windows Defender Firewall status (all profiles)
- Scans for open ports and listening services
- Identifies remote access status (RDP, WinRM, SSH)
- Validates SMB protocol security (detects vulnerable SMBv1)
- Assesses network adapter security settings
- Provides risk assessment with severity levels
- Generates actionable remediation recommendations

**Usage**:
```powershell
# Basic security audit
$audit = Invoke-NetworkSecurityAudit

# Comprehensive audit with port scan and remote access check
$audit = Invoke-NetworkSecurityAudit -IncludePortScan -CheckRemoteAccess

# View results
Write-Host "Overall Risk Level: $($audit.OverallRiskLevel)"
Write-Host "Security Risks Found: $($audit.SecurityRisks.Count)"

# Show high-severity risks
$audit.SecurityRisks | Where-Object Severity -eq "HIGH" | Format-Table Issue, Remediation
```

**Output Structure**:
```powershell
@{
    FirewallStatus      = Array of firewall profile status
    OpenPorts           = Array of listening ports
    ListeningServices   = Array of services
    RemoteAccessStatus  = Array of remote access services
    SecurityRisks       = Array of identified risks
    Recommendations     = Array of security improvements
    OverallRiskLevel    = String (HIGH/MEDIUM/LOW/MINIMAL)
    Details             = Array of diagnostic messages
    Timestamp           = String (yyyy-MM-dd HH:mm:ss)
}
```

**Security Risk Object**:
```powershell
@{
    Severity    = String (HIGH/MEDIUM/LOW)
    Category    = String (Firewall/Open Port/Protocol Security/Remote Access)
    Issue       = String (description of security issue)
    Remediation = String (PowerShell command or action to fix)
}
```

**Common Issues Detected**:
- Disabled firewall profiles
- Vulnerable SMBv1 protocol enabled
- Open high-risk ports (RDP, Telnet, FTP)
- Unencrypted remote access services
- Public network configured as Private
- Weak WiFi security (Open/WEP networks)

**Use Cases**:
- Pre-deployment security validation
- Compliance auditing (PCI-DSS, HIPAA)
- Incident response and forensics
- Penetration testing preparation
- Security baseline assessment

---

### 4. Manage-FirewallRules

**Purpose**: Advanced firewall rule management utility

**Features**:
- Lists all firewall rules with filtering
- Creates new rules with templates
- Enables/disables existing rules
- Deletes unwanted rules
- Exports/imports rule configurations
- Supports all profiles (Domain, Private, Public)
- Handles both Inbound and Outbound rules

**Usage**:
```powershell
# List all inbound rules
$rules = Manage-FirewallRules -Action List -Direction Inbound
$rules.Rules | Format-Table DisplayName, Enabled, Action, Protocol, LocalPort

# Create a new blocking rule
Manage-FirewallRules -Action Create `
    -RuleName "Block Telnet" `
    -Direction Inbound `
    -Protocol TCP `
    -Port 23 `
    -FirewallAction Block

# Enable a specific rule
Manage-FirewallRules -Action Enable -RuleName "Remote Desktop"

# Disable a rule
Manage-FirewallRules -Action Disable -RuleName "File and Printer Sharing"

# Delete a rule
Manage-FirewallRules -Action Delete -RuleName "Block Telnet"

# Export all rules to CSV
Manage-FirewallRules -Action Export -ExportPath "C:\Backup\firewall_rules.csv"
```

**Actions Supported**:
- `List` - Display firewall rules
- `Create` - Create new rule
- `Enable` - Enable existing rule
- `Disable` - Disable existing rule
- `Delete` - Remove rule
- `Export` - Export rules to CSV
- `Import` - Import rules from CSV (future)

**Parameters**:
- `-Action` - Required. The operation to perform
- `-RuleName` - Rule display name
- `-Profile` - Domain, Private, Public, Any (default: Any)
- `-Direction` - Inbound, Outbound (default: Inbound)
- `-Protocol` - TCP, UDP, ICMPv4, ICMPv6, Any (default: TCP)
- `-Port` - Port number or range (e.g., "80", "8000-8080")
- `-FirewallAction` - Allow, Block (default: Block)
- `-ExportPath` - Path for export file

**Output Structure**:
```powershell
@{
    Success        = Boolean
    Action         = String (action performed)
    RulesAffected  = Integer (number of rules)
    Rules          = Array of rule objects
    Details        = Array of operation messages
    Warnings       = Array of warnings
    Timestamp      = String (yyyy-MM-dd HH:mm:ss)
}
```

**Use Cases**:
- Temporarily block suspicious ports
- Manage corporate firewall policies
- Export rules before system migration
- Quickly enable/disable services
- Audit firewall configuration

---

## Integration with MiracleBoot

### GUI Integration (WinRepairGUI.ps1)

Add to the "Network & Connectivity" tab:

```powershell
# Network Performance Button
$btnNetworkPerf = New-Object System.Windows.Controls.Button
$btnNetworkPerf.Content = "Test Network Performance"
$btnNetworkPerf.Add_Click({
    $result = Test-NetworkPerformance -TestDuration 10
    Show-ResultDialog -Title "Network Performance" -Message @"
Average Latency: $($result.AverageLatency)ms
Jitter: $($result.Jitter)ms
Packet Loss: $($result.PacketLoss)%
Connection Quality: $($result.ConnectionQuality)
"@
})

# WiFi Analysis Button
$btnWiFiAnalysis = New-Object System.Windows.Controls.Button
$btnWiFiAnalysis.Content = "Analyze WiFi"
$btnWiFiAnalysis.Add_Click({
    $result = Get-WiFiNetworkInfo
    Show-ResultDialog -Title "WiFi Analysis" -Message @"
Networks Found: $($result.Networks.Count)
Current Network: $($result.CurrentNetwork.SSID)
Signal: $($result.CurrentNetwork.Signal)%
Best Channel: $($result.BestChannel)
"@
})

# Security Audit Button
$btnSecurityAudit = New-Object System.Windows.Controls.Button
$btnSecurityAudit.Content = "Security Audit"
$btnSecurityAudit.Add_Click({
    $result = Invoke-NetworkSecurityAudit -IncludePortScan -CheckRemoteAccess
    Show-ResultDialog -Title "Security Audit" -Message @"
Risk Level: $($result.OverallRiskLevel)
Risks Found: $($result.SecurityRisks.Count)

$($result.SecurityRisks | ForEach-Object { "• $($_.Issue)`n" })
"@
})

# Firewall Manager Button
$btnFirewallMgr = New-Object System.Windows.Controls.Button
$btnFirewallMgr.Content = "Manage Firewall"
$btnFirewallMgr.Add_Click({
    Show-FirewallManagerDialog
})
```

### TUI Integration (WinRepairTUI.ps1)

Add to the main menu:

```powershell
Write-Host "  [N] Network Performance Test" -ForegroundColor Cyan
Write-Host "  [W] WiFi Analysis" -ForegroundColor Cyan
Write-Host "  [S] Security Audit" -ForegroundColor Cyan
Write-Host "  [F] Firewall Manager" -ForegroundColor Cyan

switch ($choice) {
    'N' {
        Clear-Host
        Write-Host "Running network performance test..." -ForegroundColor Yellow
        $perf = Test-NetworkPerformance
        $perf.Details | ForEach-Object { Write-Host $_ }
        Pause
    }
    'W' {
        Clear-Host
        Write-Host "Analyzing WiFi networks..." -ForegroundColor Yellow
        $wifi = Get-WiFiNetworkInfo
        $wifi.Details | ForEach-Object { Write-Host $_ }
        Pause
    }
    'S' {
        Clear-Host
        Write-Host "Running security audit..." -ForegroundColor Yellow
        $audit = Invoke-NetworkSecurityAudit -IncludePortScan -CheckRemoteAccess
        $audit.Details | ForEach-Object { Write-Host $_ }
        Pause
    }
    'F' {
        Clear-Host
        Show-FirewallMenu
    }
}
```

---

## Performance Considerations

### Test-NetworkPerformance
- Default test duration: 10 seconds
- Network traffic: ~5-10 MB for bandwidth test
- Recommended for: Systems with active internet connection
- Avoid running during: Critical network operations

### Get-WiFiNetworkInfo
- Scans only when WiFi adapter present
- Network traffic: Minimal (passive scan)
- Execution time: 2-5 seconds
- Safe to run: Anytime

### Invoke-NetworkSecurityAudit
- Execution time: 5-15 seconds (with port scan)
- Requires: Administrator privileges for full audit
- Safe to run: Anytime (read-only operations)

### Manage-FirewallRules
- Requires: Administrator privileges for Create/Enable/Disable/Delete
- List/Export: Can run without admin
- Caution: Creating rules requires careful validation

---

## Security Considerations

1. **Administrator Privileges**: Most TIER 4 functions require admin rights for full functionality
2. **Firewall Changes**: Always test firewall rule changes before applying to production
3. **Port Scanning**: May trigger IDS/IPS alerts in corporate environments
4. **WiFi Scanning**: Passive scanning is safe; active scanning may require permissions
5. **Data Privacy**: Performance tests connect to external endpoints (Google, Cloudflare)

---

## Troubleshooting

### Test-NetworkPerformance shows 0 Mbps
- **Cause**: No internet connection or blocked by firewall
- **Solution**: Verify internet connectivity with `Test-Connection 8.8.8.8`

### Get-WiFiNetworkInfo returns empty
- **Cause**: No WiFi adapter or WLAN service stopped
- **Solution**: Start WLAN AutoConfig service with `net start WlanSvc`

### Invoke-NetworkSecurityAudit shows "Access Denied"
- **Cause**: Insufficient privileges
- **Solution**: Run PowerShell as Administrator

### Manage-FirewallRules create fails
- **Cause**: Administrator rights required
- **Solution**: Right-click PowerShell → "Run as Administrator"

---

## Future Enhancements (TIER 5 Roadmap)

1. **Network Traffic Analysis**
   - Real-time bandwidth monitoring
   - Per-application traffic breakdown
   - Historical usage graphs

2. **VPN Diagnostics**
   - VPN connection testing
   - Tunnel integrity validation
   - Performance impact analysis

3. **DNS Analysis**
   - DNS response time testing
   - DNS leak detection
   - Alternative DNS recommendations

4. **Advanced Port Scanning**
   - Service version detection
   - Vulnerability scanning
   - CVE database integration

5. **Automated Remediation**
   - One-click security fixes
   - Automated firewall rule templates
   - Compliance policy enforcement

---

## Changelog

### Version 1.0 (TIER 4 Release)
- Added Test-NetworkPerformance for comprehensive performance testing
- Added Get-WiFiNetworkInfo for WiFi network analysis
- Added Invoke-NetworkSecurityAudit for security assessment
- Added Manage-FirewallRules for firewall management
- Created Test-NetworkDiagnosticsTier4.ps1 test suite
- Full documentation and usage examples

---

## Support & Feedback

For issues, feature requests, or questions about TIER 4 features:
- GitHub Issues: https://github.com/eltonaguiar/BOOTFIXPREMIUM_GITHUB/issues
- Documentation: See DOCUMENTATION/
- Community: See PROJECT_STATUS.txt

---

**MiracleBoot v7.2.0 - Advanced Windows Recovery Toolkit**  
**NetworkDiagnostics TIER 4 - Network Performance & Security Analysis**
