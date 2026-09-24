# ============================================================================
#  Brave channels (Stable, Beta, Nightly, Dev), their policy hives and install detection.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

$script:BravePolicyPath = 'HKLM:\Software\Policies\BraveSoftware\Brave'

# ---- Multi-channel support (v1.5) -------------------------------------------
# Each Brave channel keeps its own policy hive. Default target is Stable.
# If user picks "All installed channels", every detected install gets the apply.
$script:Channels = [ordered]@{
    'Stable'  = @{
        Path = 'HKLM:\Software\Policies\BraveSoftware\Brave'
        InstallProbes = @(
            "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
            "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
            "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe"
        )
    }
    'Beta'    = @{
        Path = 'HKLM:\Software\Policies\BraveSoftware\Brave-Beta'
        InstallProbes = @(
            "$env:ProgramFiles\BraveSoftware\Brave-Browser-Beta\Application\brave.exe",
            "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser-Beta\Application\brave.exe",
            "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser-Beta\Application\brave.exe"
        )
    }
    'Nightly' = @{
        Path = 'HKLM:\Software\Policies\BraveSoftware\Brave-Nightly'
        InstallProbes = @(
            "$env:ProgramFiles\BraveSoftware\Brave-Browser-Nightly\Application\brave.exe",
            "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser-Nightly\Application\brave.exe",
            "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser-Nightly\Application\brave.exe"
        )
    }
    'Dev'     = @{
        Path = 'HKLM:\Software\Policies\BraveSoftware\Brave-Dev'
        InstallProbes = @(
            "$env:ProgramFiles\BraveSoftware\Brave-Browser-Dev\Application\brave.exe",
            "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser-Dev\Application\brave.exe",
            "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser-Dev\Application\brave.exe"
        )
    }
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

function Test-BraveInstalled {
    $paths = @(
        "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
        "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe"
    )
    foreach ($p in $paths) { if (Test-Path $p) { return $p } }
    return $null
}

function Get-BraveVersion {
    $exe = Test-BraveInstalled
    if ($exe) {
        try { return (Get-Item $exe).VersionInfo.FileVersion } catch { return 'unknown' }
    }
    return 'not installed'
}
