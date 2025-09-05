#!/usr/bin/env bash
# Chrome Profile Archiver (macOS)
# Commands: list, archive, restore [ZIP_PATH], cleanup, verify
# Config via env: ARCHIVE_DIR, PARK_DIR, CHROME_DIR
# Requirements: bash, python3, zip, unzip
set -euo pipefail

# -------- Config (override via env) --------
ARCHIVE_DIR="${ARCHIVE_DIR:-$HOME/ChromeProfileBackups}"
PARK_DIR="${PARK_DIR:-$ARCHIVE_DIR/_parked}"
CHROME_DIR="${CHROME_DIR:-$HOME/Library/Application Support/Google/Chrome}"
MAPPING_CSV="$ARCHIVE_DIR/chrome_profile_mapping.csv"

ensure_bins() {
  command -v python3 >/dev/null || { echo "❌ python3 not found. Install Xcode CLT or 'brew install python'."; exit 1; }
  command -v zip >/dev/null || { echo "❌ 'zip' not found."; exit 1; }
  command -v unzip >/dev/null || { echo "❌ 'unzip' not found."; exit 1; }
}

ensure_dirs() {
  mkdir -p "$ARCHIVE_DIR" "$PARK_DIR"
}

# -------- Helpers --------
_print_table_and_csv() {
  # Uses python to read Local State + Preferences and write CSV + print table
  BASE_DIR="$CHROME_DIR" OUT_CSV="$MAPPING_CSV" /usr/bin/env python3 - <<'PY'
import json, os, glob, csv, sys
base = os.environ["BASE_DIR"]
csv_path = os.environ["OUT_CSV"]
rows = []

def add(folder, name, last_used=""):
    rows.append({"folder": folder, "name": name or "", "last_used": last_used or ""})

# Prefer Local State for names + last_used
local_state = os.path.join(base, "Local State")
if os.path.exists(local_state):
    try:
        with open(local_state, "r", encoding="utf-8") as f:
            data = json.load(f)
        info_cache = (data.get("profile") or {}).get("info_cache") or {}
        for folder, meta in info_cache.items():
            if folder == "System Profile":
                continue
            add(folder, (meta or {}).get("name",""), (meta or {}).get("last_used",""))
    except Exception:
        pass

seen = {r["folder"] for r in rows}
candidates = [os.path.join(base, "Default")]
candidates += glob.glob(os.path.join(base, "Profile *"))
for p in sorted(candidates, key=lambda x: (x!="Default", x)):
    folder = os.path.basename(p)
    if folder in seen or not os.path.isdir(p): 
        continue
    # Try Preferences for name
    name = ""
    pref = os.path.join(p, "Preferences")
    if os.path.exists(pref):
        try:
            with open(pref, "r", encoding="utf-8") as f:
                j = json.load(f)
            name = (j.get("profile") or {}).get("name","")
        except Exception:
            pass
    add(folder, name, "")

# Print table
if rows:
    w1 = max(6, max(len(r["folder"]) for r in rows))
    w2 = max(4, max(len(r["name"]) for r in rows))
    print(f"{'FOLDER'.ljust(w1)}  {'NAME'.ljust(w2)}  LAST_USED")
    print("-"*w1 + "  " + "-"*w2 + "  " + "-"*19)
    for r in rows:
        print(f"{r['folder'].ljust(w1)}  {r['name'].ljust(w2)}  {r['last_used']}")
else:
    print("No profiles found.")

# Write CSV
os.makedirs(os.path.dirname(csv_path), exist_ok=True)
with open(csv_path, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["folder","name","last_used"])
    w.writeheader()
    for r in rows:
        w.writerow(r)
print(f"\n✔ Mapping saved to: {csv_path}")
PY
}

# -------- Commands --------
list_profiles() {
  ensure_bins; ensure_dirs; _print_table_and_csv
}

archive_profiles() {
  ensure_bins; ensure_dirs
  echo "Scanning profiles…"
  # Build array of folder names
  mapfile -t FOLDERS < <(cd "$CHROME_DIR" 2>/dev/null && ls -1 | grep -E '^(Default|Profile [0-9]+)$' | sort -V || true)
  if [[ ${#FOLDERS[@]} -eq 0 ]]; then
    echo "No Chrome profiles found in: $CHROME_DIR"; exit 1; fi

  echo
  echo "Pick profiles to archive (comma-separated), or 'a' for all:"
  i=1
  for f in "${FOLDERS[@]}"; do
    FRIENDLY=""
    if [[ -f "$MAPPING_CSV" ]]; then
      FRIENDLY=$(awk -F, -v folder="$f" 'NR>1 && $1==folder {print $2; exit}' "$MAPPING_CSV")
    fi
    printf "%2d) %-12s  %s\n" "$i" "$f" "$FRIENDLY"
    i=$((i+1))
  done
  read -r -p "Your choice: " choice

  SELECTED=()
  if [[ "$choice" = "a" || "$choice" = "A" ]]; then
    SELECTED=("${FOLDERS[@]}")
  else
    # split by comma
    IFS=',' read -r -a picks <<<"$choice"
    for p in "${picks[@]}"; do
      p="${p//[[:space:]]/}"
      [[ "$p" =~ ^[0-9]+$ ]] || continue
      idx=$((p-1))
      if (( idx>=0 && idx<${#FOLDERS[@]} )); then
        SELECTED+=("${FOLDERS[$idx]}")
      fi
    done
  fi

  if [[ ${#SELECTED[@]} -eq 0 ]]; then
    echo "Nothing selected."; exit 0; fi

  datecode=$(date +"%Y%m%d-%H%M%S")
  for folder in "${SELECTED[@]}"; do
    src="$CHROME_DIR/$folder"
    [[ -d "$src" ]] || { echo "Skip: $folder not found."; continue; }
    FRIENDLY=""
    if [[ -f "$MAPPING_CSV" ]]; then
      FRIENDLY=$(awk -F, -v folder="$folder" 'NR>1 && $1==folder {print $2; exit}' "$MAPPING_CSV")
    fi
    safe="${FRIENDLY//[^[:alnum:] _.-]/}"; safe="${safe// /_}"
    base="$folder"; [[ -n "$safe" ]] && base="${folder}__${safe}"
    zipfile="${ARCHIVE_DIR}/${base}__${datecode}.zip"
    echo "→ Archiving $folder  (${FRIENDLY})"
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
  # Optional arg: explicit zip path
  if [[ "${2-}" != "" ]]; then
    zipfile="$2"
    [[ -f "$zipfile" ]] || { echo "❌ File not found: $zipfile"; exit 1; }
    echo "Restoring into: $CHROME_DIR"
    unzip -q "$zipfile" -d "$CHROME_DIR"
    echo "✔ Restored. Quit & reopen Chrome."
    exit 0
  fi

  cd "$ARCHIVE_DIR" 2>/dev/null || { echo "No archive dir $ARCHIVE_DIR"; exit 1; }
  shopt -s nullglob
  ZIPS=( *.zip )
  if [[ ${#ZIPS[@]} -eq 0 ]]; then
    echo "No .zip backups in $ARCHIVE_DIR"; exit 0; fi

  echo "Backups:"; i=1
  for z in "${ZIPS[@]}"; do printf "%2d) %s\n" "$i" "$(basename "$z")"; i=$((i+1)); done
  read -r -p "Pick one to restore (number): " pick
  [[ "$pick" =~ ^[0-9]+$ ]] || { echo "Invalid."; exit 1; }
  idx=$((pick-1))
  (( idx>=0 && idx<${#ZIPS[@]} )) || { echo "Invalid selection."; exit 1; }
  zipfile="${ZIPS[$idx]}"

  echo "Restoring into: $CHROME_DIR"
  unzip -q "$zipfile" -d "$CHROME_DIR"
  echo "✔ Restored. Quit & reopen Chrome."
}

cleanup_profiles() {
  ensure_bins
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
prof["info_cache"] = {k:v for k,v in (prof.get("info_cache") or {}).items() if k in existing}
if prof.get("last_used") not in existing:
    prof["last_used"] = "Default" if "Default" in existing else (sorted(existing)[0] if existing else "")
prof["last_active_profiles"] = [p for p in (prof.get("last_active_profiles") or []) if p in existing]

with open(ls_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("✔ Cleaned Local State. Remaining profiles:", sorted(existing))
PY
}

verify_archives() {
  ensure_bins
  cd "$ARCHIVE_DIR" 2>/dev/null || { echo "No archive dir $ARCHIVE_DIR"; exit 1; }
  shopt -s nullglob
  ZIPS=( *.zip )
  if [[ ${#ZIPS[@]} -eq 0 ]]; then
    echo "No .zip files in $ARCHIVE_DIR"; exit 0; fi
  ok=0; bad=0
  for z in "${ZIPS[@]}"; do
    if unzip -tq "$z" >/dev/null 2>&1; then
      echo "OK  $z"; ok=$((ok+1))
    else
      echo "❌ Problem with $z"; bad=$((bad+1))
    fi
  done
  echo "✔ Verification complete. OK=$ok, BAD=$bad"
}

usage() {
  cat <<EOF
Chrome Profile Archiver (macOS)
Location:
  CHROME_DIR  = $CHROME_DIR
  ARCHIVE_DIR = $ARCHIVE_DIR
  PARK_DIR    = $PARK_DIR

Commands:
  list                  Show folder ↔ name mapping and save CSV
  archive               Zip selected profiles and park live folders
  restore [ZIP_PATH]    Restore a saved zip (from ARCHIVE_DIR or explicit path)
  cleanup               Prune Local State to remove ghost entries
  verify                Test all zip archives for integrity

Examples:
  ./chrome-profile-archiver.sh list
  ./chrome-profile-archiver.sh archive
  ARCHIVE_DIR="/Volumes/Backup/Chrome" ./chrome-profile-archiver.sh archive
  ./chrome-profile-archiver.sh cleanup
  ./chrome-profile-archiver.sh restore "/Volumes/Backup/Chrome/Profile 9__Foo__20250101-120000.zip"
EOF
}

cmd="${1:-}"
case "$cmd" in
  list)    list_profiles ;;
  archive) archive_profiles ;;
  restore) restore_profile "$@" ;;
  cleanup) cleanup_profiles ;;
  verify)  verify_archives ;;
  *)       usage ;;
esac
