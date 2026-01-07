function Start-TUI {
    # Detect environment for display (matching main script logic)
    $envDisplay = "FullOS"
    
    if ($env:SystemDrive -eq 'X:') {
        # X: drive indicates WinPE/WinRE
        if (Test-Path 'HKLM:\System\Setup') {
            $setupType = (Get-ItemProperty -Path 'HKLM:\System\Setup' -Name 'CmdLine' -ErrorAction SilentlyContinue).CmdLine
            if ($setupType -match 'recovery|WinRE') {
                $envDisplay = "WinRE"
            } else {
                $envDisplay = "WinPE"
            }
        } elseif (Test-Path 'HKLM:\System\CurrentControlSet\Control\MiniNT') {
            $envDisplay = "WinPE"
        } else {
            $envDisplay = "WinRE"
        }
    } elseif ($env:SystemDrive -ne 'X:' -and (Test-Path "$env:SystemDrive\Windows")) {
        $envDisplay = "FullOS"
    }
    
    do {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  MIRACLE BOOT v7.2.0 - MS-DOS STYLE MODE" -ForegroundColor Cyan
        Write-Host "  Environment: $envDisplay" -ForegroundColor Gray
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1) List Windows Volumes (Sorted)" -ForegroundColor White
        Write-Host "2) Scan Storage Drivers (Detailed)" -ForegroundColor White
        Write-Host "3) Inject Drivers Offline (DISM)" -ForegroundColor White
        Write-Host "4) Quick View BCD" -ForegroundColor White
        Write-Host "5) Edit BCD Entry" -ForegroundColor White
        Write-Host "Q) Quit" -ForegroundColor Yellow
        Write-Host ""

        $c = Read-Host "Select"
        switch ($c) {
            "1" { 
                Write-Host "`nScanning volumes..." -ForegroundColor Gray
                Get-WindowsVolumes | Format-Table -AutoSize
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Write-Host "`nScanning for storage driver issues..." -ForegroundColor Gray
                Write-Host ""
                Write-Host (Get-MissingStorageDevices) -ForegroundColor Yellow
                $ans = Read-Host "`nAttempt to harvest drivers from a Windows drive? (Y/N)"
                if ($ans -eq 'Y' -or $ans -eq 'y') {
                    $src = Read-Host "Source drive (e.g. C)"
                    if ($src) {
                        Write-Host "Harvesting drivers from ${src}:..." -ForegroundColor Gray
                        Harvest-StorageDrivers "$($src):"
                        Write-Host "Loading drivers..." -ForegroundColor Gray
                        Load-Drivers-Live "X:\Harvested"
                        Write-Host "Drivers loaded. Press any key to continue..." -ForegroundColor Green
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                }
            }
            "3" {
                $win = Read-Host "Target Windows drive letter (e.g. C)"
                $path = Read-Host "Path to driver folder"
                if ($win -and $path) {
                    Write-Host "Injecting drivers into ${win}: using DISM..." -ForegroundColor Gray
                    Inject-Drivers-Offline $win $path
                    Write-Host "Driver injection complete. Press any key to continue..." -ForegroundColor Green
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            }
            "4" { 
                Write-Host "`nBCD Entries:" -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
                bcdedit /enum
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "5" {
                Write-Host "`nCurrent BCD Entries:" -ForegroundColor Cyan
                bcdedit /enum | Select-String "identifier" | ForEach-Object { Write-Host $_.Line -ForegroundColor Gray }
                Write-Host ""
                $id = Read-Host "Enter BCD Identifier (GUID)"
                $name = Read-Host "Enter new description"
                if ($id -and $name) {
                    Set-BCDDescription $id $name
                    Write-Host "BCD entry updated successfully!" -ForegroundColor Green
                    Write-Host "Press any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            }
            "Q" { 
                Write-Host "`nExiting..." -ForegroundColor Yellow
                break 
            }
            "q" { 
                Write-Host "`nExiting..." -ForegroundColor Yellow
                break 
            }
            default {
                Write-Host "`nInvalid selection. Press any key to continue..." -ForegroundColor Red
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
    } while ($c -ne "Q" -and $c -ne "q")
}
