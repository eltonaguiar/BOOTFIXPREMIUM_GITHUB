# LAST_KNOWN_WORKING Version System

## Overview

The `LAST_KNOWN_WORKING_<datetime>` system provides a safety mechanism for MiracleBoot development. Each time code is validated as error-free and confirmed working, a complete backup is created with a timestamp.

## Purpose

- **Stability:** Users can always access the last confirmed working version
- **Development Freedom:** Developers can work on new features without breaking existing functionality
- **Quick Rollback:** If issues arise, restore from a previous working backup in seconds
- **Version History:** Maintain a clear history of working releases

## Folder Structure

```
MiracleBoot/
├── LAST_KNOWN_WORKING/
│   ├── LAST_KNOWN_WORKING_2026-01-07_14-30-45/
│   │   ├── MiracleBoot.ps1
│   │   ├── WinRepairGUI.ps1
│   │   ├── DOCUMENTATION/
│   │   ├── TEST/
│   │   ├── .backup-metadata.json
│   │   └── ... (all project files)
│   ├── LAST_KNOWN_WORKING_2026-01-07_12-15-30/
│   └── ... (previous versions, max 5 kept)
├── MiracleBoot.ps1
└── ... (current development version)
```

## Usage

### Creating a Backup

When code is confirmed working and error-free:

```powershell
# Navigate to project root
cd 'c:\Users\zerou\Downloads\MiracleBoot_v7_1_1 - Github code'

# Create backup with description
.\Backup-WorkingVersion.ps1 -CommitMessage "Fixed GUI null reference errors - version stable"
```

### Backup Details

The script automatically:
- Creates timestamped folder: `LAST_KNOWN_WORKING_yyyy-MM-dd_HH-mm-ss`
- Copies all project files (excludes `.git`, other backups, test logs)
- Creates `.backup-metadata.json` with backup info
- **Keeps only the 5 most recent versions**
- Removes versions older than the 5 newest

### Restoring from Backup

If issues occur in current code:

1. **Identify backup to restore:** Browse `LAST_KNOWN_WORKING/` folder
2. **Copy backup contents:**
   ```powershell
   Copy-Item -Path 'LAST_KNOWN_WORKING\LAST_KNOWN_WORKING_2026-01-07_14-30-45\*' -Destination '.\' -Recurse -Force
   ```
3. **Verify restoration:** Run tests to confirm
4. **Commit to GitHub:** Push stable version

## Automatic Cleanup

The system automatically maintains exactly **5 recent versions**:
- When creating backup #6, version #1 (oldest) is deleted
- When creating backup #7, version #2 is deleted
- This ensures the folder never grows unbounded

## Metadata File

Each backup includes `.backup-metadata.json`:

```json
{
  "Timestamp": "2026-01-07 14:30:45",
  "CommitMessage": "Fixed GUI null reference errors",
  "PowerShellVersion": "5.1.19041.1023",
  "SourcePath": "c:\\Users\\zerou\\Downloads\\MiracleBoot_v7_1_1 - Github code",
  "BackupVersion": "LAST_KNOWN_WORKING_2026-01-07_14-30-45"
}
```

## Workflow Integration

### For Active Development:
1. Make changes to code
2. Run validation tests
3. If all tests pass → Create backup with `Backup-WorkingVersion.ps1`
4. Commit to GitHub with same message
5. Continue development

### For Emergency Rollback:
1. Run validation suite
2. If critical errors found
3. Restore from most recent `LAST_KNOWN_WORKING_*` backup
4. Run validation tests again
5. Commit fix and create new backup

## Storage Considerations

Each backup is a complete copy of the project:
- Typical size: ~5-10 MB
- 5 backups: ~25-50 MB max
- **No cleanup needed:** System handles automatically

## GitHub Integration

Backups are stored **locally only** (excluded from `.gitignore`):
- Keeps repository clean
- Each developer has their own working versions
- GitHub always receives only current development code
- Users can clone and immediately access stable version

### To Exclude from Git:
```
# In .gitignore
LAST_KNOWN_WORKING*
TEST_LOGS/
*.tmp
```

## Best Practices

✅ **Do:**
- Create backup after each successful test run
- Use descriptive commit messages
- Backup before major refactoring
- Clean old versions automatically (system does this)

❌ **Don't:**
- Manually delete backup folders (system manages count)
- Commit backups to GitHub
- Store backup outside `LAST_KNOWN_WORKING/` folder
- Keep more than 5 versions (system enforces this)

## Troubleshooting

**Q: Backup script fails with permission error**
- Run PowerShell as Administrator
- Check disk space availability

**Q: Want to keep more than 5 versions?**
- Manually set `-MaxVersions 10` when running backup script
- Update CICD pipeline configuration

**Q: How do I see backup metadata?**
- Open `.backup-metadata.json` in any text editor
- Located in each backup folder

**Q: Can I backup to external drive?**
- Yes: `.\Backup-WorkingVersion.ps1 -BackupParentPath 'D:\Backups\MiracleBoot'`

## Automation

To run backup automatically after successful tests:

```powershell
# In your CI/CD pipeline or test script
if ($TestsPass -eq $true) {
    .\Backup-WorkingVersion.ps1 -CommitMessage "Automated backup after successful validation"
}
```

---

**Version:** 1.0  
**Last Updated:** January 7, 2026  
**Status:** Active
