---

# chrome-profile-archiver.sh (macOS)

```bash
#!/usr/bin/env bash
# Chrome Profile Archiver (macOS)
# Features: list, archive, restore, cleanup, verify
# Requires: bash, python3, zip, unzip
set -euo pipefail

# -------- Config (override via env when running) --------
ARCHIVE_DIR="${ARCHIVE_DIR:-$HOME/ChromeProfileBackups}"
PARK_DIR="${PARK_DIR:-$ARCHIVE_DIR/_parked}"
CHROME_DIR="${CHROME_DIR:-$HOME/Library/Application Support/Google/Chrome}"
MAPPING_CSV="${ARCHIVE_DIR}/chrome_profile_mapping.csv"

ensure_bins() {
  command -v python3 >/dev/null || command -v /usr/bin/python3 >/dev/null || {
    echo "❌ python3 not found. Install Xcode CLT or 'brew install python'." >&2; exit 1; }
  command -v zip >/dev/null || { echo "❌ 'zip' not found."; exit 1; }
  command -v unzip >/dev/null || { echo "❌ 'unzip' not found."; exit 1; }
}

ensure_dirs() {
  mkdir -p "$ARCHIVE_DIR" "$PARK_DIR"
}

# -------- Commands --------
list_profiles() {
  ensure_bins; ensure_dirs
  BASE_DIR="$CHROME_DIR" /usr/bin/env python3 - <<'PY'
import json, os, glob, csv
base = os.environ["BASE_DIR"]
local_state = os.path.join(base, "Local State")
rows = []

def add_row(folder, name, last_used=""):
    rows.append({"folder": folder, "name": name, "last_used": last_used})

# 1) Try Local State
if os.path.exists(local_state):
    try:
        with open(local_state, "r", encoding="utf-8") as f:
            data = json.load(f)
        info_cache = data.get("profile", {}).get("info_cache", {})
        for folder, meta in info_cache.items():
            if folder == "System Profile":
                continue
            add_row(folder, meta.get("name",""), meta.get("last_used",""))
    except Exception:
        pass

# 2) Add any missing by scanning folders
seen = {r["folder"] for r in rows}
candidates = sorted(glob.glob(os.path.join(base, "Profile *")) + [os.path.join(base, "Default")])
for p in candidates:
    folder = os.path.basename(p)
    if folder in seen or not os.path.isdir(p): 
        continue
    name = ""
    pref = os.path.join(p, "Preferences")
    if os.path.exists(pref):
        try:
            with open(pref, "r", encoding="utf-8") as f:
                j = json.load(f)
            name = j.get("profile", {}).get("name", "")
        except Exception:
            pass
    add_row(folder, name, "")

# Print table
w1 = max([6] + [len(r["folder"]) for r in rows])
w2 = max([4] + [len(r["name"]) for r in rows])
print(f"{'FOLDER'.ljust(w1)}  {'NAME'.ljust(w2)}  LAST_USED")
print("-"*w1 + "  " + "-"*w2 + "  " + "-"*19)
for r in rows:
    print(f"{r['folder'].ljust(w1)}  {r['name'].ljust(w2)}  {r['last_used']}")

# Write CSV
outdir = os.path.expanduser(os.path.join("~","ChromeProfileBackups"))
os.makedirs(outdir, exist_ok=True)
csv_path = os.path.join(outdir, "chrome_profile_mapping.csv")
with open(csv_path, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["folder","name","last_used"])
    w.writeheader()
    for r in rows:
        w.writerow(r)
print(f"\n✔ Mapping saved to: {csv_path}")
PY
}

archive_profiles() {
  ensure_bins; ensure_dirs
  echo "Scanning profiles…"
  FOLDERS=()
  while IFS= read -r f; do FOLDERS+=("$f"); done <<EOF
$(cd "$CHROME_DIR" && ls -1 | grep -E '^(Default|Profile [0-9]+)$' | sort -V)
EOF
  if [[ ${#FOLDERS[@]} -eq 0 ]]; then
    echo "No Chrome profiles found in: $CHROME_DIR"; exit 1; fi
  echo
  echo "Pick profiles to archive (comma-separated), or 'a' for all:"
  i=1; declare -A IDX2FOLDER
  for f in "${FOLDERS[@]}"; do
    FRIENDLY=""
    [[ -f "$MAPPING_CSV" ]] && FRIENDLY=$(awk -F, -v folder="$f" 'NR>1 && $1==folder {print $2; exit}' "$MAPPING_CSV")
    printf "%2d) %-12s  %s\n" "$i" "$f" "$FRIENDLY"
    IDX2FOLDER["$i"]="$f"; ((i++))
  done
  read -rp "Your choice: " choice
  SELECTED=()
  if [[ "$choice" =~ ^[aA]$ ]]; then
    SELECTED=("${FOLDERS[@]}")
  else
    IFS=',' read -ra picks <<<"$choice"
    for p in "${picks[@]}"; do
      p="${p//[[:space:]]/}"
      [[ -n "${IDX2FOLDER[$p]:-}" ]] && SELECTED+=("${IDX2FOLDER[$p]}")
    done
  fi
  [[ ${#SELECTED[@]} -eq 0 ]] && { echo "Nothing selected."; exit 0; }

  datecode=$(date +"%Y%m%d-%H%M%S")
  for folder in "${SELECTED[@]}"; do
    src="$CHROME_DIR/$folder"
    [[ -d "$src" ]] || { echo "Skip: $folder not found."; continue; }
    FRIENDLY=""
    [[ -f "$MAPPING_CSV" ]] && FRIENDLY=$(awk -F, -v folder="$folder" 'NR>1 && $1==folder {print $2; exit}' "$MAPPING_CSV")
    safe="${FRIENDLY//[^[:alnum:] _.-]/}"; safe="${safe// /_}"
    base="$folder"; [[ -n "$safe" ]] && base="${folder}__${safe}"
    zipfile="${ARCHIVE_DIR}/${base}__${datecode}.zip"
    echo "→ Archiving $folder  ($FRIENDLY)"
    (cd "$CHROME_DIR" && zip -qry "$zipfile" "$folder")
    parked="${PARK_DIR}/${folder}__${datecode}"
    mkdir -p "$(dirname "$parked")"; mv "$src" "$parked"
    echo "   Created: $zipfile"
    echo "   Moved live folder to: $parked"
  done
  echo; echo "✔ Done. Zips in $ARCHIVE_DIR"
}

restore_profile() {
  ensure_bins; ensure_dirs
  cd "$ARCHIVE_DIR"
  ZIPS=( *.zip )
  [[ ${#ZIPS[@]} -eq 1 && "${ZIPS[0]}" == "*.zip" ]] && { echo "No .zip backups in $ARCHIVE_DIR"; exit 0; }
  echo "Backups:"; i=1; declare -A IDX2ZIP
  for z in "${ZIPS[@]}"; do printf "%2d) %s\n" "$i" "$(basename "$z")"; IDX2ZIP["$i"]="$z"; ((i++)); done
  read -rp "Pick one to restore (number): " pick
  zipfile="${IDX2ZIP[$pick]:-}"; [[ -n "$zipfile" ]] || { echo "Invalid."; exit 1; }
  echo "Restoring into: $CHROME_DIR"; unzip -q "$zipfile" -d "$CHROME_DIR"
  echo "✔ Restored. Quit & reopen Chrome."
}

cleanup_profiles() {
  ensure_bins
  # Quit Chrome first!
  BASE_DIR="$CHROME_DIR" /usr/bin/env python3 - <<'PY'
import json, os
base = os.environ["BASE_DIR"]
ls_path = os.path.join(base, "Local State")
if not os.path.exists(ls_path):
    raise SystemExit(f"Local State not found: {ls_path}")

with open(ls_path, "r", encoding="utf-8") as f:
    data = json.load(f)

existing = {
    d for d in os.listdir(base)
    if os.path.isdir(os.path.join(base, d)) and (d == "Default" or d.startswith("Profile "))
}

prof = data.setdefault("profile", {})
prof["info_cache"] = {k:v for k,v in prof.get("info_cache", {}).items() if k in existing}

if prof.get("last_used") not in existing:
    prof["last_used"] = "Default" if "Default" in existing else (sorted(existing)[0] if existing else "")

prof["last_active_profiles"] = [p for p in prof.get("last_active_profiles", []) if p in existing]

with open(ls_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("✔ Cleaned Local State. Remaining profiles:", sorted(existing))
PY
}

verify_archives() {
  ensure_bins
  cd "$ARCHIVE_DIR" || { echo "No archive dir $ARCHIVE_DIR"; exit 1; }
  ZIPS=( *.zip )
  [[ ${#ZIPS[@]} -eq 1 && "${ZIPS[0]}" == "*.zip" ]] && { echo "No .zip files found."; exit 0; }
  for z in "${ZIPS[@]}"; do unzip -tq "$z" || echo "❌ Problem with $z"; done
  echo "✔ Verification complete."
}

usage() {
  cat <<EOF
Chrome Profile Archiver (macOS)
Location:
  CHROME_DIR = $CHROME_DIR
  ARCHIVE_DIR = $ARCHIVE_DIR
  PARK_DIR = $PARK_DIR

Commands:
  list        - show folder ↔ name mapping and save CSV
  archive     - zip selected profiles and park live folders
  restore     - restore a saved zip back to Chrome folder
  cleanup     - prune Local State to remove ghost entries
  verify      - test all zip archives for integrity

Examples:
  ./chrome-profile-archiver.sh list
  ./chrome-profile-archiver.sh archive
  ARCHIVE_DIR="/Volumes/Backup/Chrome" ./chrome-profile-archiver.sh archive
  ./chrome-profile-archiver.sh cleanup
EOF
}

cmd="${1:-}"; case "$cmd" in
  list)    list_profiles ;;
  archive) archive_profiles ;;
  restore) restore_profile ;;
  cleanup) cleanup_profiles ;;
  verify)  verify_archives ;;
  *)       usage ;;
esac
