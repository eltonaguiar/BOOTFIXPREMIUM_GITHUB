<#
.SYNOPSIS
    Error Code Database for Windows System Analysis
    
.DESCRIPTION
    Comprehensive database of common Windows error codes, Event IDs, HRESULT codes,
    and NT Status codes with explanations, causes, and suggested fixes.
    
#>

# ============================================================================
# ERROR CODE DATABASE
# ============================================================================

$ErrorCodeDatabase = @{
    # EVENT VIEWER EVENT IDS - System Events
    'EventID_1' = @{
        Name = 'System Time Changed'
        Component = 'Windows System'
        Severity = 'Warning'
        Description = 'The system clock was adjusted. This can affect time-sensitive operations.'
        Causes = @('Manual system time adjustment', 'NTP synchronization', 'BIOS time correction')
        Impact = 'Possible time-based service interruptions'
        Fixes = @(
            'Check if time synchronization is enabled',
            'Enable automatic time sync: Settings > Time & Language > Date & Time > Automatic time',
            'Verify NTP server is reachable',
            'Check CMOS battery if time drifts frequently'
        )
    }
    
    'EventID_7' = @{
        Name = 'System Shutdown'
        Component = 'Windows Shutdown'
        Severity = 'Informational'
        Description = 'System initiated a shutdown process.'
        Causes = @('User initiated shutdown', 'Automatic updates', 'Power failure', 'Scheduled maintenance')
        Impact = 'Normal operating procedure'
        Fixes = @(
            'If unexpected, check Windows Update schedule',
            'Review Power settings',
            'Check Event Viewer for shutdown reason'
        )
    }
    
    'EventID_10' = @{
        Name = 'SCSI/Disk Error'
        Component = 'Storage Subsystem'
        Severity = 'Error'
        Description = 'SCSI or disk controller detected an error during I/O operation.'
        Causes = @('Failing hard drive', 'SATA cable issues', 'Controller malfunction', 'Firmware bug')
        Impact = 'Data corruption risk, system instability'
        Fixes = @(
            'Run: chkdsk /F /R (requires reboot)',
            'Check S.M.A.R.T. status: wmic logicaldisk get name',
            'Update storage drivers',
            'Replace failing drive if detected'
        )
    }
    
    'EventID_36' = @{
        Name = 'Disk Full or Near Capacity'
        Component = 'Storage'
        Severity = 'Warning'
        Description = 'Hard drive is near capacity or full.'
        Causes = @('Large files accumulated', 'Temp files not cleaned', 'Large log files', 'Application cache')
        Impact = 'Reduced performance, eventual failure to write'
        Fixes = @(
            'Run Disk Cleanup: cleanmgr',
            'Delete temp files: %temp%',
            'Check largest folders: WizTree or TreeSize',
            'Move large files to external storage',
            'Uninstall unused applications'
        )
    }
    
    'EventID_219' = @{
        Name = 'Kernel Plug and Play Event'
        Component = 'Device Manager / Plug & Play'
        Severity = 'Warning'
        Description = 'Device driver or hardware issue detected by Plug and Play system.'
        Causes = @('Unsigned driver', 'Driver incompatibility', 'Hardware malfunction', 'USB device issue')
        Impact = 'Device may not function properly'
        Fixes = @(
            'Update device drivers: devmgmt.msc',
            'Check Device Manager for yellow exclamation marks',
            'Disable driver signature enforcement (test only)',
            'Check manufacturer for updated drivers',
            'Try different USB port',
            'Reinstall device'
        )
    }
    
    'EventID_1000' = @{
        Name = 'Application Error / Crash'
        Component = 'Application'
        Severity = 'Error'
        Description = 'An application terminated unexpectedly or encountered a fatal error.'
        Causes = @('Memory corruption', 'Unhandled exception', 'Insufficient resources', 'Driver incompatibility', 'Software bug')
        Impact = 'Application unavailable, potential data loss'
        Fixes = @(
            'Update application to latest version',
            'Repair/reinstall application',
            'Check system resources (RAM, disk space)',
            'Update video/chipset drivers',
            'Run in compatibility mode',
            'Disable full-screen optimizations'
        )
    }
    
    'EventID_7000' = @{
        Name = 'Service Failed to Start'
        Component = 'Windows Services'
        Severity = 'Error'
        Description = 'A Windows service failed to start during boot or manual start attempt.'
        Causes = @('Missing dependencies', 'Corrupted registry', 'Permission issues', 'File not found', 'Port already in use')
        Impact = 'Service functionality unavailable'
        Fixes = @(
            'Check service startup type: services.msc',
            'Verify dependencies are running',
            'Reset service permissions',
            'Run: sfc /scannow',
            'Check Event ID details for specific error',
            'Check if port is already in use'
        )
    }
    
    'EventID_7001' = @{
        Name = 'Service Dependency Failed'
        Component = 'Windows Services'
        Severity = 'Error'
        Description = 'A service depends on another service that failed or did not start.'
        Causes = @('Dependency service down', 'Dependency misconfigured', 'Startup order issue', 'Missing prerequisites')
        Impact = 'Service cannot start'
        Fixes = @(
            'Check service dependencies: sc query SERVICE_NAME',
            'Ensure dependent services are running',
            'Verify correct startup order',
            'Reset service startup types',
            'Restart dependency: net start SERVICE_NAME'
        )
    }
    
    'EventID_7009' = @{
        Name = 'Service Timeout (Start Hung)'
        Component = 'Windows Services'
        Severity = 'Error'
        Description = 'A service took too long to start and was terminated.'
        Causes = @('Service performing heavy operation', 'System overloaded', 'Dependency delay', 'Performance issue')
        Impact = 'Service unavailable, may indicate system problems'
        Fixes = @(
            'Increase service startup timeout: sc config SERVICE_NAME start= DEMAND',
            'Check system performance (high CPU/disk)',
            'Review service startup dependencies',
            'Restart service manually: net start SERVICE_NAME',
            'Check if startup disk is full or slow'
        )
    }
    
    'EventID_7034' = @{
        Name = 'Service Crashed / Unexpected Termination'
        Component = 'Windows Services'
        Severity = 'Error'
        Description = 'A service terminated unexpectedly during operation.'
        Causes = @('Memory leak', 'Unhandled exception', 'Resource exhaustion', 'Incompatible update', 'Hardware issue')
        Impact = 'Service interrupted, functionality lost'
        Fixes = @(
            'Restart service: net stop SERVICE_NAME && net start SERVICE_NAME',
            'Check Application Event Log for detailed error',
            'Update service application',
            'Check available memory and disk space',
            'Disable problematic plugins/extensions',
            'Run System File Checker: sfc /scannow'
        )
    }
    
    'EventID_10005' = @{
        Name = 'DCOM Server Process Launch Failed'
        Component = 'Component Object Model (DCOM)'
        Severity = 'Error'
        Description = 'Failed to launch a DCOM server process, preventing component communication.'
        Causes = @('Corrupted registry', 'Permission denied', 'Missing DCOM component', 'File system error')
        Impact = 'Component communication broken, applications may fail'
        Fixes = @(
            'Re-register DCOM components: regsvr32 combase.dll',
            'Run Distributed COM Configuration: dcomcnfg',
            'Reset permissions: HKCU\\Software\\Microsoft\\OLE\\DefaultLaunchPermission',
            'Restart COM+ System Application service',
            'Run: sfc /scannow'
        )
    }
    
    'EventID_10016' = @{
        Name = 'DCOM Permission Denied'
        Component = 'Component Object Model (DCOM)'
        Severity = 'Warning'
        Description = 'Access to DCOM object was denied due to insufficient permissions.'
        Causes = @('Incorrect DCOM permissions', 'User not in required group', 'Registry corruption', 'Security policy change')
        Impact = 'Component may not function, operations blocked'
        Fixes = @(
            'Run: dcomcnfg',
            'Go to: Component Services > Computers > My Computer > DCOM Config',
            'Right-click problematic component > Properties > Security',
            'Verify user has Execute and Launch permissions',
            'Reset DCOM permissions to default: Registry Hive > Delete and recreate',
            'Add current user to necessary groups'
        )
    }
    
    'EventID_36871' = @{
        Name = 'SSL/TLS Error - Schannel'
        Component = 'Schannel (SSL/TLS Security)'
        Severity = 'Error'
        Description = 'Secure channel (SSL/TLS) certificate validation or handshake failed.'
        Causes = @('Expired certificate', 'Untrusted root CA', 'System clock incorrect', 'SSL policy mismatch', 'Antivirus SSL inspection')
        Impact = 'CRITICAL - Secure connections fail, HTTPS sites unavailable'
        Fixes = @(
            'Verify system date/time is correct: Settings > Time & Language > Date & Time',
            'Enable automatic time sync',
            'Update Windows: Settings > Update & Security > Check for updates',
            'Clear SSL cache: certutil -setreg chain\\ChainCacheResync 1',
            'Disable antivirus SSL inspection temporarily',
            'Update root certificates: certutil -generateSSTFromWU root.sst',
            'Run: sfc /scannow'
        )
    }
    
    'EventID_4096' = @{
        Name = 'VBScript Deprecation Alert'
        Component = 'VBScript / Scripting'
        Severity = 'Warning'
        Description = 'VBScript is deprecated and may be disabled in future Windows versions.'
        Causes = @('Running legacy VBScript', 'Scheduled task uses VBScript', 'Application dependency', 'Old administrative script')
        Impact = 'Future compatibility issue, may break scripts'
        Fixes = @(
            'Identify scripts using VBScript: Find .vbs files',
            'Migrate to PowerShell',
            'If necessary, update scripts to use modern language',
            'Test migration thoroughly',
            'Document all VBScript dependencies'
        )
    }
    
    'EventID_4625' = @{
        Name = 'Account Logon Failed'
        Component = 'Security / Authentication'
        Severity = 'Warning'
        Description = 'A user failed to log on to the computer.'
        Causes = @('Wrong password', 'Account locked', 'Password expired', 'Wrong domain', 'Account disabled', 'Time sync issue')
        Impact = 'User cannot access system'
        Fixes = @(
            'Verify credentials are correct',
            'Check if account is locked: net user USERNAME',
            'Unlock account: net user USERNAME /active:yes',
            'Check if password expired',
            'Verify system time matches domain time',
            'Check user group memberships',
            'Review logon hours restrictions'
        )
    }
    
    'EventID_6005' = @{
        Name = 'Event Log Service Started'
        Component = 'Event Logging'
        Severity = 'Informational'
        Description = 'The Event Log service started (typically at system boot).'
        Causes = @('System boot', 'Service restart', 'Administrator action')
        Impact = 'Normal operation, informational only'
        Fixes = @(
            'No action required'
        )
    }
    
    # Application Event IDs
    'EventID_MsiInstaller_1000' = @{
        Name = 'MSI Installer Error'
        Component = 'Windows Installer (MSI)'
        Severity = 'Error'
        Description = 'Windows Installer encountered an error during installation or removal.'
        Causes = @('Corrupted installer', 'Missing prerequisites', 'Registry corruption', 'File permissions', 'Disk space', 'Running installer conflict')
        Impact = 'Installation/removal failed'
        Fixes = @(
            'Run as Administrator',
            'Try: msiexec /i installer.msi /v',
            'Clean temp MSI files: %temp%\\MSI*',
            'Reset installer: msiexec /unregister',
            'Re-register installer: msiexec /regserver',
            'Check disk space and permissions',
            'Close all applications',
            'Try safe mode installation'
        )
    }
    
    'EventID_Warning_27' = @{
        Name = 'Network Driver Warning'
        Component = 'Network Driver'
        Severity = 'Warning'
        Description = 'Network driver encountered a warning condition (often e2f drivers).'
        Causes = @('Driver issue', 'Network adapter problem', 'Speed negotiation issue', 'Firmware outdated')
        Impact = 'Possible network performance degradation'
        Fixes = @(
            'Update network drivers: Device Manager > Network adapters > Update driver',
            'Check manufacturer website for latest driver',
            'Check network adapter settings for speed/duplex mismatch',
            'Run: ipconfig /all (verify configuration)',
            'Try different cable or port',
            'Update BIOS/firmware',
            'Check for hardware issues'
        )
    }
    
    # HRESULT Codes
    '0x80004005' = @{
        Name = 'E_FAIL - General Failure'
        Component = 'Windows API'
        Severity = 'Error'
        Description = 'Unspecified COM/API failure. Generic error code indicating operation failed.'
        Causes = @('Resource exhausted', 'Initialization failed', 'Unknown COM error', 'System resource issue', 'Permission denied')
        Impact = 'Operation failed, reason unclear'
        Fixes = @(
            'Check system resources (RAM, disk)',
            'Run as Administrator',
            'Restart application',
            'Update application/drivers',
            'Check Application Event Log for details',
            'Try in safe mode'
        )
    }
    
    '0x80070005' = @{
        Name = 'E_ACCESSDENIED - Access Denied'
        Component = 'Windows API'
        Severity = 'Error'
        Description = 'Access denied due to insufficient permissions or security restrictions.'
        Causes = @('Insufficient privileges', 'File permissions', 'Registry permissions', 'UAC restriction', 'Account permissions')
        Impact = 'Operation blocked, permission required'
        Fixes = @(
            'Run as Administrator',
            'Check file permissions: Right-click > Properties > Security',
            'Grant user necessary permissions',
            'Check registry permissions',
            'Disable UAC temporarily (test only)',
            'Add user to appropriate groups'
        )
    }
    
    '0x80070002' = @{
        Name = 'E_FILENOTFOUND - File Not Found'
        Component = 'Windows API'
        Severity = 'Error'
        Description = 'Required file or resource not found.'
        Causes = @('File deleted', 'Wrong path', 'Incomplete installation', 'Corrupted installation', 'Missing dependency')
        Impact = 'Application or operation cannot proceed'
        Fixes = @(
            'Verify file exists',
            'Check file path spelling',
            'Reinstall application',
            'Use System File Checker: sfc /scannow',
            'Restore from backup if deleted'
        )
    }
    
    '0x80070003' = @{
        Name = 'E_PATHNOTFOUND - Path Not Found'
        Component = 'Windows API'
        Severity = 'Error'
        Description = 'Directory path does not exist or is inaccessible.'
        Causes = @('Directory deleted', 'Wrong path', 'Drive not mapped', 'Permission denied', 'Network path unavailable')
        Impact = 'Cannot access directory or files within'
        Fixes = @(
            'Verify path exists',
            'Check spelling',
            'Verify network drive is connected',
            'Check permissions',
            'Restore from backup if deleted'
        )
    }
    
    '0x80070006' = @{
        Name = 'E_INVALIDHANDLE - Invalid Handle'
        Component = 'Windows API'
        Severity = 'Error'
        Description = 'Invalid or corrupted system handle/reference.'
        Causes = @('Corrupted file', 'Memory corruption', 'Handle closed prematurely', 'Resource leak')
        Impact = 'Operation cannot proceed'
        Fixes = @(
            'Restart application',
            'Restart system',
            'Update drivers',
            'Check RAM for errors: Run Memory Diagnostic',
            'Restore from backup if corrupted'
        )
    }
    
    '0x800704EC' = @{
        Name = 'E_ABORT - Operation Aborted'
        Component = 'Windows API'
        Severity = 'Error'
        Description = 'Operation was aborted, typically by user action or timeout.'
        Causes = @('User cancel', 'Timeout', 'Resource unavailable', 'Operation interrupted')
        Impact = 'Operation incomplete'
        Fixes = @(
            'Check why operation was aborted',
            'Increase timeout if applicable',
            'Retry operation',
            'Check available resources'
        )
    }
    
    '0x80004003' = @{
        Name = 'E_POINTER - Invalid Pointer'
        Component = 'Windows API'
        Severity = 'Error'
        Description = 'Invalid pointer/reference passed to function.'
        Causes = @('Null pointer', 'Memory corruption', 'Freed memory access', 'API misuse')
        Impact = 'Application crash or incorrect behavior'
        Fixes = @(
            'Update application',
            'Check RAM: Run Memory Diagnostic',
            'Update drivers',
            'Restart system'
        )
    }
    
    # NT Status Codes
    'STATUS_ACCESS_DENIED' = @{
        Name = 'Access Denied'
        Component = 'Windows Kernel'
        Severity = 'Error'
        Description = 'Kernel-level access denied, user lacks necessary permissions.'
        Causes = @('Insufficient privileges', 'File/registry permissions', 'Security policy', 'Account restrictions')
        Impact = 'Operation blocked'
        Fixes = @(
            'Run as Administrator',
            'Check file/folder permissions',
            'Add user to necessary security groups',
            'Review security policies'
        )
    }
    
    'STATUS_FILE_NOT_FOUND' = @{
        Name = 'File Not Found'
        Component = 'Windows Kernel'
        Severity = 'Error'
        Description = 'Required file not found in file system.'
        Causes = @('File deleted', 'Wrong path', 'Network issue', 'Permission denied')
        Impact = 'Cannot access file'
        Fixes = @(
            'Verify file exists',
            'Check path spelling',
            'Restore from backup',
            'Check network connectivity'
        )
    }
    
    'STATUS_OBJECT_NAME_NOT_FOUND' = @{
        Name = 'Object Name Not Found'
        Component = 'Windows Kernel'
        Severity = 'Error'
        Description = 'Kernel object (file, registry key, etc.) not found.'
        Causes = @('Object deleted', 'Wrong name', 'Registry key missing', 'Permission denied')
        Impact = 'Cannot access object'
        Fixes = @(
            'Verify object exists',
            'Check spelling/path',
            'Restore registry from backup',
            'Recreate object if deleted'
        )
    }
    
    'STATUS_INSUFFICIENT_RESOURCES' = @{
        Name = 'Insufficient Resources'
        Component = 'Windows Kernel'
        Severity = 'Error'
        Description = 'Not enough system resources available (memory, handles, etc.).'
        Causes = @('Memory exhausted', 'Too many open handles', 'Resource leak', 'System overload')
        Impact = 'Operation fails, system may become unstable'
        Fixes = @(
            'Check RAM: Task Manager > Performance',
            'Close unnecessary applications',
            'Increase virtual memory/page file',
            'Check for memory leaks',
            'Restart system',
            'Add more RAM if persistently low'
        )
    }
    
    'STATUS_DEVICE_NOT_READY' = @{
        Name = 'Device Not Ready'
        Component = 'Device Driver'
        Severity = 'Error'
        Description = 'Device is not ready for operation (may be offline, disconnected, or powered off).'
        Causes = @('Device offline', 'Disconnected', 'Driver issue', 'Device powered off', 'Device failed')
        Impact = 'Cannot use device'
        Fixes = @(
            'Check device is powered on',
            'Check connections',
            'Restart device',
            'Update device drivers',
            'Check Device Manager for errors',
            'Try different port/cable',
            'Replace device if failed'
        )
    }
    
    'STATUS_TIMEOUT' = @{
        Name = 'Operation Timeout'
        Component = 'Windows Kernel'
        Severity = 'Error'
        Description = 'Operation did not complete within expected time.'
        Causes = @('Slow operation', 'System overload', 'Network latency', 'Device slow', 'Deadlock')
        Impact = 'Operation hung or failed'
        Fixes = @(
            'Wait for operation to complete',
            'Increase timeout if possible',
            'Check system performance',
            'Check network if applicable',
            'Restart system if hung',
            'Update drivers'
        )
    }
    
    # ============================================================================
    # BOOT LOG FAILURES - ntbtlog.txt Analysis
    # ============================================================================
    
    'BOOTLOG_DSOUND_FAILED' = @{
        Name = 'DirectSound Driver Load Failed'
        Component = 'Audio System'
        Severity = 'Warning'
        Description = 'The dsound.vxd driver failed to load. This is typically not a critical issue.'
        Causes = @('DirectSound not supported on this system', 'Audio subsystem not available', 'Optional component')
        Impact = 'Direct Sound applications may not work; most audio functionality unaffected'
        Fixes = @(
            'This is typically safe to ignore if audio works normally',
            'Check audio device in Device Manager (devmgmt.msc)',
            'Update audio drivers from manufacturer',
            'If audio is needed, install DirectX audio components'
        )
    }
    
    'BOOTLOG_EBIOS_FAILED' = @{
        Name = 'Extended BIOS Load Failed'
        Component = 'System Boot'
        Severity = 'Info'
        Description = 'Extended BIOS support (ebios) failed to load. This is normal on modern systems.'
        Causes = @('Modern systems do not use extended BIOS', 'Legacy hardware support not needed', 'Expected on UEFI systems')
        Impact = 'No impact - this is deprecated functionality'
        Fixes = @(
            'This is expected behavior and safe to ignore',
            'No action required'
        )
    }
    
    'BOOTLOG_NDIS2SUP_FAILED' = @{
        Name = 'NDIS 2.0 Support Load Failed'
        Component = 'Network Drivers'
        Severity = 'Info'
        Description = 'NDIS 2.0 (legacy networking protocol) support failed to load.'
        Causes = @('Modern systems use NDIS 6.x', 'Legacy protocol not needed', 'Optional component')
        Impact = 'No impact - legacy networking protocol not used on modern Windows'
        Fixes = @(
            'This is expected and safe to ignore',
            'If legacy network support needed, manually install NDIS 2.0 support',
            'Check: Control Panel > Programs > Turn Windows features on or off'
        )
    }
    
    'BOOTLOG_VPOWERD_FAILED' = @{
        Name = 'Virtual Power Device Load Failed'
        Component = 'Power Management'
        Severity = 'Info'
        Description = 'Virtual power device support (vpowerd) failed to load.'
        Causes = @('System manages power independently', 'Optional legacy component', 'Not needed on modern hardware')
        Impact = 'No impact - modern power management works independently'
        Fixes = @(
            'This is expected behavior and safe to ignore',
            'Power management should work through modern drivers',
            'No action required'
        )
    }
    
    'BOOTLOG_VSERVER_FAILED' = @{
        Name = 'Network Server Support Load Failed'
        Component = 'Network Services'
        Severity = 'Info'
        Description = 'Virtual server support (vserver.vxd) failed to load.'
        Causes = @('Optional networking component', 'Server role not enabled', 'Not needed on workstations')
        Impact = 'No impact - most workstations do not need server support'
        Fixes = @(
            'This is expected behavior and safe to ignore',
            'If server functionality needed, enable through Windows Features',
            'Check: Control Panel > Programs > Turn Windows features on or off > Server roles'
        )
    }
    
    'BOOTLOG_VSHARE_FAILED' = @{
        Name = 'File Sharing Support Load Failed'
        Component = 'Network Services'
        Severity = 'Info'
        Description = 'Virtual file sharing support (vshare.vxd) failed to load.'
        Causes = @('File sharing not needed', 'Optional component', 'Workgroup networking disabled')
        Impact = 'No impact unless file sharing is required'
        Fixes = @(
            'Safe to ignore if file sharing not needed',
            'To enable file sharing: Settings > Network & Internet > Sharing options',
            'Verify SMB/CIFS services are running if sharing needed'
        )
    }
    
    'BOOTLOG_SDVXD_FAILED' = @{
        Name = 'SD VXD Init Completion Failed'
        Component = 'System Device'
        Severity = 'Warning'
        Description = 'SD (Secure Digital) device initialization failed to complete.'
        Causes = @('SD card reader not present', 'SD device not needed', 'Optional hardware support')
        Impact = 'SD card reader may not work; does not affect system boot'
        Fixes = @(
            'This is typically safe to ignore unless SD card access needed',
            'Check Device Manager for SD card reader',
            'Update chipset/card reader drivers if SD access needed',
            'Check BIOS for integrated card reader settings'
        )
    }
    
    'BOOTLOG_MTRR_FAILED' = @{
        Name = 'Memory Type Range Register Init Failed (Windows 98)'
        Component = 'Memory Management'
        Severity = 'Warning'
        Description = 'MTRR (Memory Type Range Register) initialization failed on Windows 98.'
        Causes = @('Modern memory management not compatible', 'Windows 98 legacy issue', 'Processor limitation')
        Impact = 'Memory access may be slower; system typically still boots'
        Fixes = @(
            'This is common on Windows 98 and often safe to ignore',
            'Verify system boots normally despite failure',
            'Check BIOS settings for cache configuration',
            'Consider upgrading to modern Windows if still using Windows 98'
        )
    }
    
    'BOOTLOG_JAVASUP_FAILED' = @{
        Name = 'Java Support Init Failed (Windows 98)'
        Component = 'Runtime Environment'
        Severity = 'Info'
        Description = 'Java support failed to initialize on Windows 98.'
        Causes = @('Java not installed', 'Java support not needed', 'Optional component')
        Impact = 'Java applications may not run; does not affect core system'
        Fixes = @(
            'This is safe to ignore unless Java support needed',
            'To enable Java: Install Java Runtime Environment (JRE)',
            'Download from: java.com',
            'Verify Java installation: java -version'
        )
    }
    
    'BOOTLOG_CRITICAL_DRIVER_FAILED' = @{
        Name = 'Critical Driver Load Failed'
        Component = 'Boot System'
        Severity = 'Critical'
        Description = 'A critical boot driver failed to load. System will not boot properly.'
        Causes = @(
            'Corrupted driver file',
            'Missing storage driver',
            'Incompatible driver',
            'Driver registry corruption',
            'Hardware failure',
            'Image restored to incompatible hardware'
        )
        Impact = 'CRITICAL - System will fail to boot. INACCESSIBLE_BOOT_DEVICE (0x7B) or similar BSOD'
        Fixes = @(
            'Boot into WinPE/Recovery Environment',
            'Verify driver file exists: Test-Path C:\Windows\System32\drivers\<drivername>.sys',
            'If missing, inject from recovery media: Dism /Image:C: /Add-Driver /Driver:driver.inf',
            'Check Registry for driver startup type: Should be 0 (Boot) or 1 (System)',
            'Verify hardware is compatible with drivers',
            'If restoring image to new hardware, update storage drivers first',
            'Run: Bootrec /RebuildBcd',
            'Run: Chkdsk /F /R'
        )
    }
    
    # Common Phrases / Keywords
    'CRITICAL_KEYWORDS' = @{
        Keywords = @('fatal', 'crash', 'failed', 'critical', 'error', 'corrupted', 'destroyed')
        Severity = 'Critical'
        Recommendation = 'These keywords indicate serious issues requiring immediate attention'
    }
    
    'WARNING_KEYWORDS' = @{
        Keywords = @('warning', 'issue', 'problem', 'abnormal', 'unexpected', 'deprecated', 'obsolete')
        Severity = 'Warning'
        Recommendation = 'Monitor and address these issues to prevent escalation'
    }
    
    'PERFORMANCE_KEYWORDS' = @{
        Keywords = @('slow', 'hang', 'freeze', 'lag', 'timeout', 'delay', 'resource', 'memory', 'cpu', 'disk')
        Severity = 'Performance'
        Recommendation = 'Address resource constraints and optimize system performance'
    }
    
    'SECURITY_KEYWORDS' = @{
        Keywords = @('denied', 'unauthorized', 'permission', 'access', 'privilege', 'security', 'protected', 'restricted')
        Severity = 'Security'
        Recommendation = 'Review security settings and permissions'
    }
}

# Export database
$ErrorCodeDatabase
