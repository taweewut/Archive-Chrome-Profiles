# Chrome Profile Archiver – Backup & Restore Guide

Easily **archive**, **backup**, **clean up**, and **restore** Google Chrome profiles.  
Great for keeping only active profiles visible while preserving the rest as zips.

---

## Contents
- [Where Chrome Stores Profiles](#where-chrome-stores-profiles)
- [Requirements](#requirements)
- [macOS (bash script)](#macos-bash-script)
  - [Install](#install)
  - [Commands](#commands)
- [Windows (PowerShell script)](#windows-powershell-script)
  - [Install](#install-1)
  - [Commands](#commands-1)
- [Typical Workflow](#typical-workflow)
- [Notes & Safety](#notes--safety)

---

## Where Chrome Stores Profiles

### macOS
```text
~/Library/Application Support/Google/Chrome
```

### Windows
```text
%LOCALAPPDATA%\Google\Chrome\User Data
```

- `Default` = your first profile  
- `Profile 1`, `Profile 2`, … = additional profiles  
- Friendly names are stored in `Local State` (JSON) alongside these folders.

---

## Requirements

- Close Chrome completely before **archive / restore / cleanup**.
- Ensure enough free disk space (zip size ≈ profile folder size).

---

## macOS (bash script)

This uses `chrome-profile-archiver.sh`.

### Install
```bash
# Download the script into this repo (or any folder you control)
# Make it executable
chmod +x chrome-profile-archiver.sh
```

### Commands

#### List profiles (and write mapping CSV)
```bash
./chrome-profile-archiver.sh list
```

#### Archive profiles (select numbers or `a` for all)
```bash
./chrome-profile-archiver.sh archive
```
Zips are written to:
```text
~/ChromeProfileBackups/
```
Moved live folders (parked) go to:
```text
~/ChromeProfileBackups/_parked/
```

#### Restore a profile from a zip
```bash
./chrome-profile-archiver.sh restore
```

#### Remove ghost tiles from Chrome’s chooser (prune “Local State”)
```bash
./chrome-profile-archiver.sh cleanup
```

#### Verify all zips (integrity test)
```bash
./chrome-profile-archiver.sh verify
```

#### Optional: override backup location per run
```bash
ARCHIVE_DIR="/Volumes/Backup/ChromeBackups" \
PARK_DIR="/Volumes/Backup/ChromeBackups/_parked" \
./chrome-profile-archiver.sh archive
```

---

## Windows (PowerShell script)

This uses `ChromeProfileArchiver.ps1`.

### Install
```powershell
# Download ChromeProfileArchiver.ps1 into your repo/folder
# Allow local scripts if needed
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Commands

#### List profiles (and write mapping CSV)
```powershell
.\ChromeProfileArchiver.ps1 list
```

#### Archive profiles (select numbers or `a` for all)
```powershell
.\ChromeProfileArchiver.ps1 archive
```
Zips are written to:
```powershell
$HOME\ChromeProfileBackups```
Moved live folders (parked) go to:
```powershell
$HOME\ChromeProfileBackups\_parked```

#### Restore a profile from a zip
```powershell
.\ChromeProfileArchiver.ps1 restore
```

#### Cleanup ghost tiles (prune “Local State”)
```powershell
.\ChromeProfileArchiver.ps1 cleanup
```

#### Verify all zips
```powershell
.\ChromeProfileArchiver.ps1 verify
```

#### Optional: override backup location per run
```powershell
.\ChromeProfileArchiver.ps1 archive -ArchiveDir "D:\ChromeBackups" -ParkDir "D:\ChromeBackups\_parked"
```

---

## Typical Workflow

### macOS
```bash
./chrome-profile-archiver.sh list
./chrome-profile-archiver.sh archive
./chrome-profile-archiver.sh cleanup   # removes ghost tiles
./chrome-profile-archiver.sh verify    # optional
# later…
./chrome-profile-archiver.sh restore
```

### Windows
```powershell
.\ChromeProfileArchiver.ps1 list
.\ChromeProfileArchiver.ps1 archive
.\ChromeProfileArchiver.ps1 cleanup    # removes ghost tiles
.\ChromeProfileArchiver.ps1 verify     # optional
# later…
.\ChromeProfileArchiver.ps1 restore
```

---

## Notes & Safety

- **Passwords** are encrypted to your OS user. Restoring to a different OS user may not decrypt saved passwords.  
- Large zips are normal for active profiles (extensions/history/caches).  
- Rename only via Chrome UI (Manage profiles → Edit). Avoid renaming `Profile N` folders manually.  
- Keep your `chrome_profile_mapping.csv` — it’s the folder ↔ friendly name reference.

Happy archiving! 🎉
