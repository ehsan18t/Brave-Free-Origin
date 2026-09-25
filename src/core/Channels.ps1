# ============================================================================
#  Brave channels (Stable, Beta, Nightly, Dev): install detection, the policy
#  key they share, their Local State files and the installed version.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- The policy key ---------------------------------------------------------
# Every Brave channel reads its policies from this one key. Brave's policy
# generator hardcodes it (brave-core chromium_src/components/policy/tools/
# generate_policy_source.py), so Beta, Nightly and Dev share Stable's policies.
$script:PolicyPath = 'HKLM:\Software\Policies\BraveSoftware\Brave'

# Versions before 2.1 wrote Beta, Nightly and Dev policies under these keys.
# Brave never read them; Apply and the full restore remove them.
$script:LegacyPolicyPaths = @(
    'HKLM:\Software\Policies\BraveSoftware\Brave-Beta'
    'HKLM:\Software\Policies\BraveSoftware\Brave-Nightly'
    'HKLM:\Software\Policies\BraveSoftware\Brave-Dev'
)

# ---- Channels -----------------------------------------------------------------
# The per-user folder is the original user's, forwarded across the UAC
# boundary: an elevated administrator account has its own LOCALAPPDATA, but
# Brave's user data (and a per-user install) live in the user's.
$script:UserLocalAppData = if ($BfoLocalAppData) { $BfoLocalAppData } else { $env:LOCALAPPDATA }

# Each channel follows the same naming: the Stable names plus a suffix. AppId is
# the prefix Brave's installer gives the channel's Windows services.
$script:Channels = & {
    $table = [ordered]@{}
    foreach ($spec in @(@('Stable', '', 'Brave'), @('Beta', '-Beta', 'BraveBeta'), @('Nightly', '-Nightly', 'BraveNightly'), @('Dev', '-Dev', 'BraveDev'))) {
        $suffix = $spec[1]
        $table[$spec[0]] = @{
            AppId         = $spec[2]
            InstallDirs   = @(foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $script:UserLocalAppData)) {
                "$base\BraveSoftware\Brave-Browser$suffix\Application"
            })
            LocalState    = "$($script:UserLocalAppData)\BraveSoftware\Brave-Browser$suffix\User Data\Local State"
        }
    }
    $table
}

function Get-DetectedChannels {
    $found = @()
    foreach ($name in $script:Channels.Keys) {
        foreach ($dir in $script:Channels[$name].InstallDirs) {
            if (Test-Path (Join-Path $dir 'brave.exe')) { $found += $name; break }
        }
    }
    return $found
}

# Path of one channel's brave.exe, or $null when it is not installed.
function Get-ChannelExe {
    param([string]$Channel)
    foreach ($dir in $script:Channels[$Channel].InstallDirs) {
        $exe = Join-Path $dir 'brave.exe'
        if (Test-Path $exe) { return $exe }
    }
    return $null
}

# Path of the brave.exe the app talks about: Stable when installed, otherwise
# the first other channel found. $null when no Brave is installed.
function Test-BraveInstalled {
    foreach ($name in $script:Channels.Keys) {
        $exe = Get-ChannelExe $name
        if ($exe) { return $exe }
    }
    return $null
}

function Get-BraveVersion {
    $exe = Test-BraveInstalled
    if ($exe) {
        try { return (Get-Item $exe).VersionInfo.FileVersion } catch { return 'unknown' }
    }
    return 'not installed'
}

# Brave's file version is <Chromium major>.<Brave major>.<Brave minor>.<build>,
# for example 153.1.95.104: Chromium 153, Brave 1.95. Policies are gated on the
# Chromium major, flags on the Brave minor. Both are 0 when unknown, which the
# callers read as "do not gate".
function ConvertTo-BraveVersionInfo {
    param([string]$Version)
    $info = [pscustomobject]@{ Text = $Version; Chromium = 0; BraveMinor = 0 }
    if ($Version -match '^(\d+)\.(\d+)\.(\d+)\.\d+$') {
        $info.Chromium = [int]$Matches[1]
        $info.BraveMinor = [int]$Matches[3]
    }
    return $info
}

# The brave.exe processes of one channel, found by path. Flags can only be
# written while the channel is closed: Brave rewrites Local State on exit.
function Get-ChannelProcesses {
    param([string]$Channel)
    $dirs = @($script:Channels[$Channel].InstallDirs | ForEach-Object { $_.TrimEnd('\') + '\' })
    return @(Get-Process -Name 'brave' -ErrorAction SilentlyContinue | Where-Object {
        $path = $null
        try { $path = $_.Path } catch { Write-Verbose "Cannot read the path of process $($_.Id)." }
        $path -and @($dirs | Where-Object { $path.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
    })
}
