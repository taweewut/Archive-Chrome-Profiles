<# ChromeProfileArchiver.ps1 (Windows)
   Features: list, archive, restore, cleanup, verify
   Run:  .\ChromeProfileArchiver.ps1 list
#>

param(
  [ValidateSet('list','archive','restore','cleanup','verify')]
  [string]$cmd = 'list',
  [string]$ArchiveDir = "$HOME\ChromeProfileBackups",
  [string]$ParkDir = "$HOME\ChromeProfileBackups\_parked",
  [string]$ChromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data"
)

function Ensure-Dirs {
  New-Item -ItemType Directory -Force -Path $ArchiveDir | Out-Null
  New-Item -ItemType Directory -Force -Path $ParkDir | Out-Null
}

function Get-ProfileFolders {
  Get-ChildItem -Path $ChromeDir -Directory |
    Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' } |
    Sort-Object Name
}

function List-Profiles {
  Ensure-Dirs
  $localState = Join-Path $ChromeDir 'Local State'
  $rows = @()
  if (Test-Path $localState) {
    try {
      $data = Get-Content $localState -Raw | ConvertFrom-Json
      $cache = $data.profile.info_cache.PSObject.Properties
      foreach ($p in $cache) {
        if ($p.Name -ne 'System Profile') {
          $rows += [PSCustomObject]@{ folder=$p.Name; name=$p.Value.name; last_used=$p.Value.last_used }
        }
      }
    } catch {}
  }
  $seen = $rows.folder
  foreach ($d in Get-ProfileFolders) {
    if ($seen -notcontains $d.Name) {
      $pref = Join-Path $d.FullName 'Preferences'
      $name = ''
      if (Test-Path $pref) {
        try {
          $j = Get-Content $pref -Raw | ConvertFrom-Json
          $name = $j.profile.name
        } catch {}
      }
      $rows += [PSCustomObject]@{ folder=$d.Name; name=$name; last_used='' }
    }
  }

  # Table
  $rows | Sort-Object folder | Format-Table -AutoSize

  # CSV
  $csvPath = Join-Path $ArchiveDir 'chrome_profile_mapping.csv'
  $rows | Sort-Object folder | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
  Write-Host "`n✔ Mapping saved to: $csvPath"
}

function Archive-Profiles {
  Ensure-Dirs
  $folders = Get-ProfileFolders
  if ($folders.Count -eq 0) { Write-Error "No Chrome profiles found in $ChromeDir"; return }

  Write-Host ""
  Write-Host "Pick profiles to archive (comma-separated), or 'a' for all:"
  $i=1; $index=@{}
  foreach ($f in $folders) {
    $index[$i]=$f.Name
    "{0,2}) {1}" -f $i, $f.Name
    $i++
  }
  $choice = Read-Host "Your choice"
  if ($choice -match '^[aA]$') {
    $selected = $folders.Name
  } else {
    $selected = @()
    foreach ($p in $choice -split ',') {
      $p = $p.Trim()
      if ($index.ContainsKey([int]$p)) { $selected += $index[[int]$p] }
    }
  }
  if (-not $selected -or $selected.Count -eq 0) { Write-Host "Nothing selected."; return }

  $datecode = Get-Date -Format 'yyyyMMdd-HHmmss'
  foreach ($folder in $selected) {
    $src = Join-Path $ChromeDir $folder
    if (-not (Test-Path $src)) { Write-Host "Skip: $folder not found."; continue }
    $zip = Join-Path $ArchiveDir ("{0}__{1}.zip" -f $folder, $datecode)
    Write-Host "→ Archiving $folder"
    Compress-Archive -Path $src -DestinationPath $zip -Force
    $park = Join-Path $ParkDir ("{0}__{1}" -f $folder, $datecode)
    New-Item -ItemType Directory -Force -Path $park | Out-Null
    Move-Item -Path $src -Destination $park
    Write-Host "   Created: $zip"
    Write-Host "   Moved live folder to: $park"
  }
  Write-Host "`n✔ Done. Zips in $ArchiveDir"
}

function Restore-Profile {
  Ensure-Dirs
  $zips = Get-ChildItem -Path $ArchiveDir -Filter *.zip
  if ($zips.Count -eq 0) { Write-Host "No .zip backups in $ArchiveDir"; return }
  Write-Host "Backups:"; $i=1; $index=@{}
  foreach ($z in $zips) { "{0,2}) {1}" -f $i, $z.Name; $index[$i]=$z.FullName; $i++ }
  $pick = Read-Host "Pick one to restore (number)"
  if (-not $index.ContainsKey([int]$pick)) { Write-Host "Invalid."; return }
  $zipfile = $index[[int]$pick]
  Write-Host "Restoring into: $ChromeDir"
  Expand-Archive -Path $zipfile -DestinationPath $ChromeDir -Force
  Write-Host "✔ Restored. Quit & reopen Chrome."
}

function Cleanup-Profiles {
  $localState = Join-Path $ChromeDir 'Local State'
  if (-not (Test-Path $localState)) { Write-Error "Local State not found at $localState"; return }
  $data = Get-Content $localState -Raw | ConvertFrom-Json
  $existing = (Get-ProfileFolders).Name
  $cache = $data.profile.info_cache
  $newCache = @{}
  foreach ($k in $cache.PSObject.Properties.Name) {
    if ($existing -contains $k) { $newCache[$k] = $cache.$k }
  }
  $data.profile.info_cache = $newCache
  if ($existing -notcontains $data.profile.last_used) {
    $data.profile.last_used = ($existing -contains 'Default') ? 'Default' : ($existing | Sort-Object | Select-Object -First 1)
  }
  $data.profile.last_active_profiles = @($data.profile.last_active_profiles | Where-Object { $existing -contains $_ })
  $json = $data | ConvertTo-Json -Depth 10
  Set-Content -Path $localState -Value $json -Encoding UTF8
  Write-Host "✔ Cleaned Local State. Remaining profiles: $($existing -join ', ')"
}

function Verify-Archives {
  Ensure-Dirs
  $zips = Get-ChildItem -Path $ArchiveDir -Filter *.zip
  if ($zips.Count -eq 0) { Write-Host "No .zip files in $ArchiveDir"; return }
  foreach ($z in $zips) {
    try {
      # Test by listing; Expand-Archive -WhatIf doesn't test content, so we catch errors via .NET ZipFile
      [System.IO.Compression.ZipFile]::OpenRead($z.FullName).Dispose()
      Write-Host "OK  $($z.Name)"
    } catch {
      Write-Host "❌ Problem with $($z.Name)"
    }
  }
  Write-Host "✔ Verification complete."
}

switch ($cmd) {
  'list'    { List-Profiles }
  'archive' { Archive-Profiles }
  'restore' { Restore-Profile }
  'cleanup' { Cleanup-Profiles }
  'verify'  { Verify-Archives }
  default   { Write-Host "Usage: .\ChromeProfileArchiver.ps1 [list|archive|restore|cleanup|verify]" }
}
