#!/usr/bin/env python3
"""
BOOTFIX PREMIUM - Professional Boot Repair & Recovery Utility
Version: 1.0.0
Author: Elton Aguiar
License: MIT
"""

import os
import sys
import platform
import subprocess
import argparse
import json
from datetime import datetime
from pathlib import Path

# Windows-specific imports
try:
    import ctypes
except ImportError:
    ctypes = None


class BootFixPremium:
    """Main class for boot repair operations"""
    
    def __init__(self, verbose=False, dry_run=False):
        self.verbose = verbose
        self.dry_run = dry_run
        self.os_type = platform.system()
        self.backup_dir = Path.home() / ".bootfix_backups"
        self.backup_dir.mkdir(exist_ok=True)
        
    def log(self, message, level="INFO"):
        """Log messages with timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
    
    def check_privileges(self):
        """Check if running with admin/root privileges"""
        if self.os_type == "Windows":
            if ctypes is None:
                return False
            try:
                return ctypes.windll.shell32.IsUserAnAdmin() != 0
            except:
                return False
        else:
            return os.geteuid() == 0
    
    def run_command(self, command, capture_output=True):
        """Execute shell command safely"""
        if self.dry_run:
            self.log(f"[DRY-RUN] Would execute: {command}", "INFO")
            return True, ""
        
        try:
            if self.verbose:
                self.log(f"Executing: {command}", "DEBUG")
            
            result = subprocess.run(
                command,
                shell=True,
                capture_output=capture_output,
                text=True,
                timeout=300
            )
            
            if result.returncode == 0:
                return True, result.stdout
            else:
                self.log(f"Command failed: {result.stderr}", "ERROR")
                return False, result.stderr
        except Exception as e:
            self.log(f"Error executing command: {str(e)}", "ERROR")
            return False, str(e)
    
    def diagnose(self):
        """Run comprehensive boot diagnostics"""
        self.log("Starting boot diagnostics...", "INFO")
        
        issues = []
        
        # Check disk information
        self.log("Checking disk configuration...", "INFO")
        if self.os_type == "Linux":
            success, output = self.run_command("lsblk -o NAME,SIZE,TYPE,MOUNTPOINT")
            if success and self.verbose:
                print(output)
            
            # Check for GRUB
            if not Path("/boot/grub/grub.cfg").exists() and not Path("/boot/grub2/grub.cfg").exists():
                issues.append("GRUB configuration not found")
            
            # Check boot partition
            success, output = self.run_command("mount | grep /boot")
            if not success:
                issues.append("Boot partition not mounted")
                
        elif self.os_type == "Windows":
            success, output = self.run_command("wmic diskdrive list brief")
            if success and self.verbose:
                print(output)
            
            # Check BCD store
            success, output = self.run_command("bcdedit")
            if not success:
                issues.append("Boot Configuration Data (BCD) issues detected")
        
        # Report findings
        if issues:
            self.log("Issues detected:", "WARNING")
            for issue in issues:
                self.log(f"  - {issue}", "WARNING")
        else:
            self.log("No critical issues detected", "INFO")
        
        return len(issues) == 0
    
    def create_backup(self, backup_type="full"):
        """Create backup of boot configuration"""
        self.log(f"Creating {backup_type} backup...", "INFO")
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = self.backup_dir / f"backup_{backup_type}_{timestamp}.json"
        
        backup_data = {
            "timestamp": timestamp,
            "os_type": self.os_type,
            "backup_type": backup_type,
            "status": "created"
        }
        
        if self.os_type == "Linux":
            # Backup MBR
            if not self.dry_run:
                self.run_command(f"dd if=/dev/sda of={self.backup_dir}/mbr_{timestamp}.bin bs=512 count=1")
                backup_data["mbr_backup"] = str(self.backup_dir / f"mbr_{timestamp}.bin")
            
            # Backup GRUB config
            grub_cfg = Path("/boot/grub/grub.cfg")
            if grub_cfg.exists():
                backup_data["grub_config"] = str(grub_cfg)
        
        elif self.os_type == "Windows":
            # Backup BCD
            if not self.dry_run:
                bcd_backup = self.backup_dir / f"bcd_{timestamp}.bak"
                self.run_command(f"bcdedit /export {bcd_backup}")
                backup_data["bcd_backup"] = str(bcd_backup)
        
        # Save backup metadata
        with open(backup_file, 'w') as f:
            json.dump(backup_data, f, indent=2)
        
        self.log(f"Backup created: {backup_file}", "INFO")
        return backup_file
    
    def repair_mbr(self, target_disk="/dev/sda"):
        """Repair Master Boot Record"""
        self.log(f"Repairing MBR on {target_disk}...", "INFO")
        
        if not self.check_privileges():
            self.log("Root/Admin privileges required", "ERROR")
            return False
        
        if self.os_type == "Linux":
            # Install GRUB to MBR
            success, _ = self.run_command(f"grub-install {target_disk}")
            if success:
                self.log("MBR repair completed", "INFO")
                return True
            else:
                self.log("MBR repair failed", "ERROR")
                return False
        
        elif self.os_type == "Windows":
            # Use bootrec to fix MBR
            success, _ = self.run_command("bootrec /fixmbr")
            if success:
                self.log("MBR repair completed", "INFO")
                return True
            else:
                self.log("MBR repair failed", "ERROR")
                return False
        
        return False
    
    def repair_grub(self, target_disk="/dev/sda"):
        """Repair GRUB bootloader"""
        self.log(f"Repairing GRUB on {target_disk}...", "INFO")
        
        if self.os_type != "Linux":
            self.log("GRUB repair only available on Linux", "ERROR")
            return False
        
        if not self.check_privileges():
            self.log("Root privileges required", "ERROR")
            return False
        
        # Install GRUB
        success, _ = self.run_command(f"grub-install {target_disk}")
        if not success:
            self.log("GRUB installation failed", "ERROR")
            return False
        
        # Update GRUB config
        success, _ = self.run_command("update-grub")
        if not success:
            success, _ = self.run_command("grub-mkconfig -o /boot/grub/grub.cfg")
        
        if success:
            self.log("GRUB repair completed", "INFO")
            return True
        else:
            self.log("GRUB configuration update failed", "ERROR")
            return False
    
    def repair_windows_boot(self):
        """Repair Windows Boot Manager"""
        self.log("Repairing Windows Boot Manager...", "INFO")
        
        if self.os_type != "Windows":
            self.log("Windows boot repair only available on Windows", "ERROR")
            return False
        
        if not self.check_privileges():
            self.log("Administrator privileges required", "ERROR")
            return False
        
        # Fix boot sector
        success1, _ = self.run_command("bootrec /fixboot")
        
        # Rebuild BCD
        success2, _ = self.run_command("bootrec /rebuildbcd")
        
        # Fix MBR
        success3, _ = self.run_command("bootrec /fixmbr")
        
        if success1 and success2 and success3:
            self.log("Windows boot repair completed", "INFO")
            return True
        else:
            self.log("Some repair operations failed", "WARNING")
            return False
    
    def auto_fix(self):
        """Automatic diagnosis and repair"""
        self.log("Starting automatic repair...", "INFO")
        
        if not self.check_privileges():
            self.log("Root/Admin privileges required", "ERROR")
            return False
        
        # Create backup first
        self.create_backup("auto_fix")
        
        # Run diagnostics
        self.diagnose()
        
        # Attempt repairs based on OS
        if self.os_type == "Linux":
            self.repair_grub()
        elif self.os_type == "Windows":
            self.repair_windows_boot()
        
        self.log("Automatic repair completed", "INFO")
        return True
    
    def install(self):
        """Install BOOTFIX PREMIUM"""
        self.log("Installing BOOTFIX PREMIUM...", "INFO")
        
        # Create necessary directories
        self.backup_dir.mkdir(exist_ok=True)
        
        # Create config file
        config_file = Path.home() / ".bootfix_config.json"
        config = {
            "version": "1.0.0",
            "installed": datetime.now().isoformat(),
            "backup_dir": str(self.backup_dir)
        }
        
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
        
        self.log("Installation completed successfully", "INFO")
        self.log(f"Config file: {config_file}", "INFO")
        self.log(f"Backup directory: {self.backup_dir}", "INFO")
        
        return True


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="BOOTFIX PREMIUM - Professional Boot Repair & Recovery Utility"
    )
    
    # Operation modes
    parser.add_argument("--diagnose", action="store_true", help="Run boot diagnostics")
    parser.add_argument("--repair-mbr", action="store_true", help="Repair Master Boot Record")
    parser.add_argument("--repair-grub", action="store_true", help="Repair GRUB bootloader")
    parser.add_argument("--repair-windows-boot", action="store_true", help="Repair Windows Boot Manager")
    parser.add_argument("--auto-fix", action="store_true", help="Automatic diagnosis and repair")
    parser.add_argument("--backup", action="store_true", help="Create backup of boot configuration")
    parser.add_argument("--install", action="store_true", help="Install BOOTFIX PREMIUM")
    
    # Options
    parser.add_argument("--target-disk", default="/dev/sda", help="Target disk (default: /dev/sda)")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose output")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without making changes")
    
    args = parser.parse_args()
    
    # Create BootFix instance
    bootfix = BootFixPremium(verbose=args.verbose, dry_run=args.dry_run)
    
    # Show banner
    print("=" * 60)
    print("  BOOTFIX PREMIUM - Professional Boot Repair Utility")
    print("  Version 1.0.0")
    print("=" * 60)
    print()
    
    # Execute requested operation
    if args.install:
        bootfix.install()
    elif args.diagnose:
        bootfix.diagnose()
    elif args.backup:
        bootfix.create_backup()
    elif args.repair_mbr:
        bootfix.repair_mbr(args.target_disk)
    elif args.repair_grub:
        bootfix.repair_grub(args.target_disk)
    elif args.repair_windows_boot:
        bootfix.repair_windows_boot()
    elif args.auto_fix:
        bootfix.auto_fix()
    else:
        parser.print_help()
        print("\nNo operation specified. Use --help for usage information.")
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
