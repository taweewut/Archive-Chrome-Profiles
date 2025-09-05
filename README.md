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
- [💾 Storing Backups on External Disk or NAS](#-storing-backups-on-external-disk-or-nas)
- [Typical Workflow](#typical-workflow)
- [Notes & Safety](#notes--safety)

---

## Where Chrome Stores Profiles

### macOS
```text
~/Library/Application Support/Google/Chrome

Windows

%LOCALAPPDATA%\Google\Chrome\User Data

	•	Default = your first profile
	•	Profile 1, Profile 2, … = additional profiles
	•	Friendly names are stored in Local State (JSON) alongside these folders.

⸻

Requirements
	•	Close Chrome completely before archive / restore / cleanup.
	•	Ensure enough free disk space (zip size ≈ profile folder size).

⸻

macOS (bash script)

This uses chrome-profile-archiver.sh.

Install

# Download the script into this repo (or any folder you control)
# Make it executable
chmod +x chrome-profile-archiver.sh

Commands

List profiles (and write mapping CSV)

./chrome-profile-archiver.sh list

Archive profiles (select numbers or a for all)

./chrome-profile-archiver.sh archive

Zips are written to:

~/ChromeProfileBackups/

Moved live folders (parked) go to:

~/ChromeProfileBackups/_parked/

Restore a profile from a zip

./chrome-profile-archiver.sh restore

Remove ghost tiles from Chrome’s chooser (prune “Local State”)

./chrome-profile-archiver.sh cleanup

Verify all zips (integrity test)

./chrome-profile-archiver.sh verify

Optional: override backup location per run

ARCHIVE_DIR="/Volumes/Backup/ChromeBackups" \
PARK_DIR="/Volumes/Backup/ChromeBackups/_parked" \
./chrome-profile-archiver.sh archive


⸻

Windows (PowerShell script)

This uses ChromeProfileArchiver.ps1.

Install

# Download ChromeProfileArchiver.ps1 into your repo/folder
# Allow local scripts if needed
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

Commands

List profiles (and write mapping CSV)

.\ChromeProfileArchiver.ps1 list

Archive profiles (select numbers or a for all)

.\ChromeProfileArchiver.ps1 archive

Zips are written to:

$HOME\ChromeProfileBackups\

Moved live folders (parked) go to:

$HOME\ChromeProfileBackups\_parked\

Restore a profile from a zip

.\ChromeProfileArchiver.ps1 restore

Cleanup ghost tiles (prune “Local State”)

.\ChromeProfileArchiver.ps1 cleanup

Verify all zips

.\ChromeProfileArchiver.ps1 verify

Optional: override backup location per run

.\ChromeProfileArchiver.ps1 archive -ArchiveDir "D:\ChromeBackups" -ParkDir "D:\ChromeBackups\_parked"


⸻

💾 Storing Backups on External Disk or NAS

By default, backups are written to:
	•	macOS: ~/ChromeProfileBackups
	•	Windows: %USERPROFILE%\ChromeProfileBackups

If you want to free up disk space and keep archives on an external disk or NAS, you have two options:

1. Change Backup Directory (edit script)

Open chrome-profile-archiver.sh (or .ps1) and edit:

# Example for macOS/Linux
BACKUP_DIR="/Volumes/MyDisk/ChromeBackups"

# Example for Windows PowerShell
param([string]$ArchiveDir = "$HOME\ChromeProfileBackups")


⸻

2. Use a Symlink (recommended for macOS/Linux)

Keep the script unchanged, but replace the default folder with a symlink pointing to your external storage:

# Remove old backup folder if it exists
rm -rf ~/ChromeProfileBackups

# Create symlink to external disk or NAS
ln -s /Volumes/MyDisk/ChromeBackups ~/ChromeProfileBackups

Now the script continues using ~/ChromeProfileBackups, but files are actually stored externally.

⸻

3. Hybrid Workflow

If you only want to occasionally restore:
	1.	Archive profiles to external storage (move .zip files off your Mac).
	2.	When you need to restore:
	•	Copy the desired .zip back into ~/ChromeProfileBackups.
	•	Run ./chrome-profile-archiver.sh restore.
	•	Delete it from local disk again if space is limited.

⸻

⚡ Best practice:
If you always want to keep archives externally, use Option 2 (symlink) for seamless workflow.
If you only rarely restore, Option 3 may be simpler.

⸻

Typical Workflow

macOS

./chrome-profile-archiver.sh list
./chrome-profile-archiver.sh archive
./chrome-profile-archiver.sh cleanup   # removes ghost tiles
./chrome-profile-archiver.sh verify    # optional
# later…
./chrome-profile-archiver.sh restore

Windows

.\ChromeProfileArchiver.ps1 list
.\ChromeProfileArchiver.ps1 archive
.\ChromeProfileArchiver.ps1 cleanup    # removes ghost tiles
.\ChromeProfileArchiver.ps1 verify     # optional
# later…
.\ChromeProfileArchiver.ps1 restore


⸻

Notes & Safety
	•	Passwords are encrypted to your OS user. Restoring to a different OS user may not decrypt saved passwords.
	•	Large zips are normal for active profiles (extensions/history/caches).
	•	Rename only via Chrome UI (Manage profiles → Edit). Avoid renaming Profile N folders manually.
	•	Keep your chrome_profile_mapping.csv — it’s the folder ↔ friendly name reference.

Happy archiving! 🎉

