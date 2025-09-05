# Archive-Chrome-Profiles
The instruction how to backup inactive chrome profile ( using when testing some frontend application use case)
Absolutely 👍 Here’s a complete README.md you can save directly and upload into your repo:

⸻


# Chrome Profile Archiver – Backup & Restore Guide

Easily **archive, backup, and restore Google Chrome profiles**.  
Useful when you have many test/demo profiles and want to keep only the active ones visible.

---

## 📂 Where Chrome Stores Profiles

- **macOS**  

~/Library/Application Support/Google/Chrome

- **Windows**  

%LOCALAPPDATA%\Google\Chrome\User Data

Each Chrome profile is stored as a folder:
- `Default` = your first profile  
- `Profile 1`, `Profile 2`, … = other profiles  

Friendly names (like *Work*, *Demo*, etc.) are stored in **Local State** JSON.

---

## ⚙️ Installation

1. Download `chrome-profile-archiver.sh` from this repo.  
2. Place it somewhere convenient:  
 - macOS → e.g. `~/Desktop`  
 - Windows → e.g. `C:\Users\<you>\Desktop` (requires Git Bash or WSL)  
3. Make it executable:

### macOS
```bash
chmod +x ~/Desktop/chrome-profile-archiver.sh

Windows (Git Bash or WSL)

chmod +x ~/Desktop/chrome-profile-archiver.sh


⸻

🚀 Commands

1. List Profiles

./chrome-profile-archiver.sh list

Shows folder ↔ name mapping and saves chrome_profile_mapping.csv in your backup folder.

⸻

2. Archive Profiles

./chrome-profile-archiver.sh archive

	•	Prompts you to select profiles to archive (or a for all).
	•	Creates .zip backups in:
	•	macOS → ~/ChromeProfileBackups
	•	Windows → %USERPROFILE%\ChromeProfileBackups
	•	Moves the live profile folders into _parked.

⸻

3. Restore a Profile

./chrome-profile-archiver.sh restore

	•	Lets you pick a .zip backup.
	•	Restores it into the Chrome profile directory.
	•	Quit & reopen Chrome to use it.

⸻

4. Cleanup Ghost Entries (macOS only)

If Chrome still shows archived profiles, run:

./chrome-profile-archiver.sh cleanup

This prunes the Local State file so Chrome only shows folders that still exist.

(Windows users usually don’t need this; Chrome auto-removes missing profiles.)

⸻

🔄 Typical Workflow

# 1. List profiles
./chrome-profile-archiver.sh list

# 2. Archive unused ones
./chrome-profile-archiver.sh archive

# 3. Clean ghost entries (macOS only)
./chrome-profile-archiver.sh cleanup

# 4. Restore later if needed
./chrome-profile-archiver.sh restore


⸻

📝 Notes
	•	Archived profiles are safe in .zip form; restore anytime.
	•	Large ZIP size = profile had lots of cache/extensions.
	•	You can safely rename profiles from Chrome’s UI after restore.
	•	Best practice: close Chrome completely before archiving.

⸻

✅ With this workflow, you can keep Chrome clean and still preserve your test/demo environments.


