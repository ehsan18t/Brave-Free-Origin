# ============================================================================
#  Per-user settings file (remembered UI language).
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- Persisted UI settings --------------------------------------------------
# Stored per-user under LOCALAPPDATA, not beside the script: the script folder
# may be read-only (Program Files) or shared, and the repo should stay clean.
# The path is resolved BEFORE elevation and forwarded across the UAC relaunch
# so an elevated admin account still reads the original user's preference.
function Get-BfoSettings {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return @{} }
    try {
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        $obj = [System.IO.File]::ReadAllText($Path, $utf8) | ConvertFrom-Json
        $map = @{}
        foreach ($p in $obj.PSObject.Properties) { $map[$p.Name] = $p.Value }
        return $map
    } catch { return @{} }
}

function Save-BfoSettings {
    param([string]$Path, [hashtable]$Settings)
    if (-not $Path) { return }
    try {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $json = ([pscustomobject]$Settings | ConvertTo-Json -Depth 4)
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($Path, $json, $utf8)
    } catch {
        # Preferences are a convenience: the app keeps working without them.
        Write-BfoLog "Could not save preferences to ${Path}: $_" 'WARN'
    }
}

# ---- Backup folder ---------------------------------------------------------
# Registry and hosts backups, exported configs and saved reports all land here.
# -Create makes sure the folder exists; a file-open dialog only needs the path.
function Get-BackupDir {
    param([switch]$Create)
    $dir = Join-Path $env:USERPROFILE 'Documents\Brave-Free-Origin-Backups'
    if ($Create -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    return $dir
}
