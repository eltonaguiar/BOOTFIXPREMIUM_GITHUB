param(
    [string]$SourcePath = (Get-Location).Path,
    [string]$BackupParentPath = (Join-Path $SourcePath 'LAST_KNOWN_WORKING'),
    [int]$MaxVersions = 5,
    [string]$CommitMessage = "Backup stable version"
)

Write-Host "MIRACLEBOOT VERSION BACKUP SYSTEM" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $SourcePath)) {
    Write-Host "ERROR: Source path not found: $SourcePath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $BackupParentPath)) {
    New-Item -ItemType Directory -Path $BackupParentPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$versionName = "LAST_KNOWN_WORKING_$timestamp"
$backupPath = Join-Path $BackupParentPath $versionName

Write-Host "[1/4] Creating backup: $versionName..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

$excludePatterns = @('.git', 'LAST_KNOWN_WORKING*', '.gitignore', 'TEST_LOGS')
$itemsToCopy = Get-ChildItem -Path $SourcePath -Force | Where-Object {
    $name = $_.Name
    -not ($excludePatterns | Where-Object { $name -like $_ })
}

foreach ($item in $itemsToCopy) {
    $destPath = Join-Path $backupPath $item.Name
    if ($item.PSIsContainer) {
        Copy-Item -Path $item.FullName -Destination $destPath -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Copy-Item -Path $item.FullName -Destination $destPath -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Backup created successfully" -ForegroundColor Green

Write-Host "`n[2/4] Creating backup metadata..." -ForegroundColor Yellow
$metadata = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    CommitMessage = $CommitMessage
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    SourcePath = $SourcePath
    BackupVersion = $versionName
}

$metadataJson = $metadata | ConvertTo-Json
$metadataJson | Set-Content -Path (Join-Path $backupPath '.backup-metadata.json') -Force
Write-Host "Metadata file created" -ForegroundColor Green

Write-Host "`n[3/4] Cleaning up old versions (keeping $MaxVersions)..." -ForegroundColor Yellow

$backupFolders = Get-ChildItem -Path $BackupParentPath -Directory | 
    Where-Object { $_.Name -match '^LAST_KNOWN_WORKING_' } | 
    Sort-Object CreationTime -Descending

if ($backupFolders.Count -gt $MaxVersions) {
    $foldersToDelete = $backupFolders | Select-Object -Skip $MaxVersions
    foreach ($folder in $foldersToDelete) {
        Write-Host "  Removing old version: $($folder.Name)" -ForegroundColor Yellow
        Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  Cleanup complete - removed $($foldersToDelete.Count) old version(s)" -ForegroundColor Green
} else {
    Write-Host "  No cleanup needed - $($backupFolders.Count) versions exist" -ForegroundColor Green
}

Write-Host "`n[4/4] Backup Summary:" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Gray
Write-Host "Backup Location: $backupPath" -ForegroundColor Green
Write-Host "Timestamp: $timestamp" -ForegroundColor Green
Write-Host "Commit Message: $CommitMessage" -ForegroundColor Green

$backupSize = (Get-ChildItem -Path $backupPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "Backup Size: $([math]::Round($backupSize, 2)) MB" -ForegroundColor Green

$remainingBackups = Get-ChildItem -Path $BackupParentPath -Directory | 
    Where-Object { $_.Name -match '^LAST_KNOWN_WORKING_' } | 
    Measure-Object | Select-Object -ExpandProperty Count

Write-Host "Total Backups Stored: $remainingBackups / $MaxVersions" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Gray

Write-Host "`nBACKUP COMPLETE" -ForegroundColor Green
Write-Host "To restore from backup, copy contents from: $backupPath" -ForegroundColor Cyan

exit 0
