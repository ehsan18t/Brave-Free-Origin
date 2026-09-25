# ============================================================================
#  Search engine, new tab page and startup overrides.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Every value the search override owns, whether or not a given engine uses it.
$script:SearchOverrideValueNames = @(
    'DefaultSearchProviderEnabled'
    'DefaultSearchProviderName'
    'DefaultSearchProviderKeyword'
    'DefaultSearchProviderSearchURL'
    'DefaultSearchProviderSuggestURL'
)

# The four overrides read the Overrides part of a selection snapshot (see
# core\State.ps1): SearchEnabled, EngineId, CustomSearchUrl, NtpEnabled,
# DestinationId, NtpCustomUrl, HomeEnabled, HomeDestinationId, HomeCustomUrl,
# StartupEnabled, StartupModeId and StartupUrls. This page is the only writer
# of the startup, homepage and new tab policies.
function Get-DesiredSearchOverride {
    param($Overrides)
    $desired = [ordered]@{}
    if (-not $Overrides.SearchEnabled) { return $desired }

    $eng = $script:SearchEngines[$Overrides.EngineId]
    if (-not $eng) { throw "Unknown search engine '$($Overrides.EngineId)'." }
    $url = $eng.URL
    $sug = $eng.Suggest
    # ProviderName, not the translated label: this string is written to the
    # registry and shown by Brave itself.
    $name = $eng.ProviderName
    $keyword = $eng.Keyword

    if ($eng.IsCustom) {
        $url = "$($Overrides.CustomSearchUrl)".Trim()
        if ([string]::IsNullOrWhiteSpace($url)) { throw 'Custom search URL is empty.' }
        if ($url -notmatch '\{searchTerms\}') { throw 'Custom search URL must contain {searchTerms}.' }
        $name = 'Custom Search'
    }

    $desired['DefaultSearchProviderEnabled'] = @{ Type='DWORD'; Value=1 }
    $desired['DefaultSearchProviderName'] = @{ Type='STRING'; Value=$name }
    $desired['DefaultSearchProviderKeyword'] = @{ Type='STRING'; Value=$keyword }
    $desired['DefaultSearchProviderSearchURL'] = @{ Type='STRING'; Value=$url }
    if ($sug) { $desired['DefaultSearchProviderSuggestURL'] = @{ Type='STRING'; Value=$sug } }
    return $desired
}

function Get-DesiredNtpOverride {
    param($Overrides)
    $desired = [ordered]@{}
    if (-not $Overrides.NtpEnabled) { return $desired }

    $engine = $script:SearchEngines[$Overrides.EngineId]
    $engineHome = if (-not $engine -or $engine.IsCustom) { '' } else { $engine.Home }
    $url = Resolve-Destination -DestinationId $Overrides.DestinationId -CustomUrl "$($Overrides.NtpCustomUrl)" -SearchEngineHome $engineHome
    if ([string]::IsNullOrWhiteSpace($url)) { throw 'New tab override has no resolvable URL.' }
    $desired['NewTabPageLocation'] = @{ Type='STRING'; Value=$url }
    return $desired
}

# The home button's page. Uses the same destinations as the new tab page.
$script:HomeOverrideValueNames = @('HomepageIsNewTabPage', 'HomepageLocation')

function Get-DesiredHomeOverride {
    param($Overrides)
    $desired = [ordered]@{}
    if (-not $Overrides.HomeEnabled) { return $desired }

    $engine = $script:SearchEngines[$Overrides.EngineId]
    $engineHome = if (-not $engine -or $engine.IsCustom) { '' } else { $engine.Home }
    $url = Resolve-Destination -DestinationId $Overrides.HomeDestinationId -CustomUrl "$($Overrides.HomeCustomUrl)" -SearchEngineHome $engineHome
    if ([string]::IsNullOrWhiteSpace($url)) { throw 'Homepage override has no resolvable URL.' }
    $desired['HomepageIsNewTabPage'] = @{ Type='DWORD'; Value=0 }
    $desired['HomepageLocation'] = @{ Type='STRING'; Value=$url }
    return $desired
}

function Get-DesiredStartupOverride {
    param($Overrides)
    if (-not $Overrides.StartupEnabled) {
        return [pscustomobject]@{ Enabled = $false; ModeId = $null; Code = $null; Urls = @() }
    }

    $modeId = $Overrides.StartupModeId
    $mode = $script:StartupModes[$modeId]
    if (-not $mode) { throw "Unknown startup mode '$modeId'." }
    $urls = @()
    if ($mode.UsesURL) {
        $urls = if ($mode.FixedURL) { @($mode.FixedURL) }
                else { @("$($Overrides.StartupUrls)" -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
        if ($urls.Count -eq 0) { throw 'Startup override has no URL.' }
    }
    return [pscustomobject]@{ Enabled = $true; ModeId = $modeId; Code = $mode.Code; Urls = $urls }
}

# Which startup mode a stored RestoreOnStartup value means. Several modes can
# share a code (blank page and specific pages are both 4), so the stored URL
# list decides: a mode with a fixed URL only matches that exact URL, and any
# other list means the user's own pages.
function Resolve-StartupModeId {
    param($Code, [string[]]$Urls)
    $candidates = @($script:StartupModeIds | Where-Object { "$($script:StartupModes[$_].Code)" -eq "$Code" })
    foreach ($id in $candidates) {
        $mode = $script:StartupModes[$id]
        if (-not $mode.UsesURL) { return $id }
        if ($mode.FixedURL -and @($Urls).Count -eq 1 -and $Urls[0] -eq $mode.FixedURL) { return $id }
    }
    foreach ($id in $candidates) {
        if (-not $script:StartupModes[$id].FixedURL) { return $id }
    }
    return $null
}

# ---- Helpers: write search-engine + startup overrides into one channel ------
function Resolve-Destination {
    param([string]$DestinationId, [string]$CustomUrl, [string]$SearchEngineHome)
    $entry = $script:DestinationOptions[$DestinationId]
    if (-not $entry) { return $null }
    $code = $entry.Value
    switch ($code) {
        '__SEARCH__' { return $SearchEngineHome }
        '__CUSTOM__' { return $CustomUrl.Trim() }
        default      { return $code }
    }
}

# The Write-*Override functions write exactly what the matching
# Get-Desired*Override computes, the same table Preview reports, so the two
# cannot drift apart. Each clears its values first so unticking + Apply truly
# removes them, and a selection that cannot be applied is logged and skipped.
function Write-SearchEngineOverride {
    param([string]$Path, $Overrides)
    foreach ($n in $script:SearchOverrideValueNames) { [void](Remove-PolicyValue -Path $Path -Name $n) }
    try { $desired = Get-DesiredSearchOverride -Overrides $Overrides }
    catch { Write-BfoLog "Search override skipped: $($_.Exception.Message)" 'WARN'; return $false }
    if ($desired.Count -eq 0) { return $false }

    Write-DesiredValues -Path $Path -Desired $desired
    Write-BfoLog "Search engine override -> $($desired['DefaultSearchProviderName'].Value)" 'OK'
    return $true
}

function Write-NtpOverride {
    param([string]$Path, $Overrides)
    [void](Remove-PolicyValue -Path $Path -Name 'NewTabPageLocation')
    try { $desired = Get-DesiredNtpOverride -Overrides $Overrides }
    catch { Write-BfoLog "NTP override skipped: $($_.Exception.Message)" 'WARN'; return $false }
    if ($desired.Count -eq 0) { return $false }

    Write-DesiredValues -Path $Path -Desired $desired
    Write-BfoLog "New tab page override -> $($desired['NewTabPageLocation'].Value)" 'OK'
    return $true
}

function Write-HomeOverride {
    param([string]$Path, $Overrides)
    foreach ($n in $script:HomeOverrideValueNames) { [void](Remove-PolicyValue -Path $Path -Name $n) }
    try { $desired = Get-DesiredHomeOverride -Overrides $Overrides }
    catch { Write-BfoLog "Homepage override skipped: $($_.Exception.Message)" 'WARN'; return $false }
    if ($desired.Count -eq 0) { return $false }

    Write-DesiredValues -Path $Path -Desired $desired
    Write-BfoLog "Homepage override -> $($desired['HomepageLocation'].Value)" 'OK'
    return $true
}

function Write-StartupOverride {
    param([string]$Path, $Overrides)
    [void](Remove-PolicyValue -Path $Path -Name 'RestoreOnStartup')
    try { Remove-Item -Path (Join-Path $Path 'RestoreOnStartupURLs') -Recurse -Force -ErrorAction Stop }
    catch { Write-Verbose "No RestoreOnStartupURLs list to remove under $Path." }
    try { $startup = Get-DesiredStartupOverride -Overrides $Overrides }
    catch { Write-BfoLog "Startup override skipped: $($_.Exception.Message)" 'WARN'; return $false }
    if (-not $startup.Enabled) { return $false }

    Set-PolicyValue -Path $Path -Name 'RestoreOnStartup' -Type 'DWORD' -Value $startup.Code
    if ($startup.Urls.Count -gt 0) {
        $listPath = Join-Path $Path 'RestoreOnStartupURLs'
        New-Item -Path $listPath -Force | Out-Null
        $i = 1
        foreach ($u in @($startup.Urls)) {
            Set-PolicyValue -Path $listPath -Name "$i" -Type 'STRING' -Value $u
            $i++
        }
        Write-BfoLog "Startup override -> code $($startup.Code), URLs: $($startup.Urls -join ', ')" 'OK'
    } else {
        Write-BfoLog "Startup override -> $($startup.ModeId) (code $($startup.Code))" 'OK'
    }
    return $true
}
