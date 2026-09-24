# ============================================================================
#  Brave channels (Stable, Beta, Nightly, Dev), their policy hives and install detection.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- Multi-channel support (v1.5) -------------------------------------------
# Each Brave channel keeps its own policy hive. Default target is Stable.
# If user picks "All installed channels", every detected install gets the apply.
# Every channel follows the same naming: the Stable names plus a suffix, probed
# in Program Files, Program Files (x86) and the per-user install folder.
$script:Channels = & {
    $table = [ordered]@{}
    foreach ($spec in @(@('Stable', ''), @('Beta', '-Beta'), @('Nightly', '-Nightly'), @('Dev', '-Dev'))) {
        $suffix = $spec[1]
        $table[$spec[0]] = @{
            Path          = "HKLM:\Software\Policies\BraveSoftware\Brave$suffix"
            InstallProbes = @(foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
                "$base\BraveSoftware\Brave-Browser$suffix\Application\brave.exe"
            })
        }
    }
    $table
}
$script:TargetChannels = @('Stable')

function Get-DetectedChannels {
    $found = @()
    foreach ($name in $script:Channels.Keys) {
        foreach ($probe in $script:Channels[$name].InstallProbes) {
            if (Test-Path $probe) { $found += $name; break }
        }
    }
    return $found
}

# Path of the Stable brave.exe, or $null when Stable is not installed.
function Test-BraveInstalled {
    foreach ($p in $script:Channels['Stable'].InstallProbes) { if (Test-Path $p) { return $p } }
    return $null
}

function Get-BraveVersion {
    $exe = Test-BraveInstalled
    if ($exe) {
        try { return (Get-Item $exe).VersionInfo.FileVersion } catch { return 'unknown' }
    }
    return 'not installed'
}
