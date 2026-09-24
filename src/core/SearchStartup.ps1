# ============================================================================
#  Search engine, new tab page and startup overrides.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

function Get-DesiredSearchOverride {
    $desired = [ordered]@{}
    if (-not $script:ChkSearchOverride.Checked) { return $desired }

    $engineId = Get-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds
    $eng = $script:SearchEngines[$engineId]
    $url = $eng.URL
    $sug = $eng.Suggest
    # ProviderName, not the translated label: this string is written to the
    # registry and shown by Brave itself.
    $name = $eng.ProviderName
    $keyword = $eng.Keyword

    if ($eng.IsCustom) {
        $url = $script:TxtCustomSearchUrl.Text.Trim()
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
    $desired = [ordered]@{}
    if (-not $script:ChkNtpOverride.Checked) { return $desired }

    $engineId = Get-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds
    $engineHome = if ($script:SearchEngines[$engineId].IsCustom) { '' } else { $script:SearchEngines[$engineId].Home }
    $url = Resolve-Destination -DestinationId (Get-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds) -CustomUrl $script:TxtNtpCustomUrl.Text -SearchEngineHome $engineHome
    if ([string]::IsNullOrWhiteSpace($url)) { throw 'New tab override has no resolvable URL.' }
    $desired['NewTabPageLocation'] = @{ Type='STRING'; Value=$url }
    return $desired
}

function Get-DesiredStartupOverride {
    if (-not $script:ChkStartupOverride.Checked) {
        return [pscustomobject]@{ Enabled = $false; Code = $null; Urls = @() }
    }

    $modeId = Get-ComboId -Combo $script:CmbStartupMode -Ids $script:StartupModeIds
    $mode = $script:StartupModes[$modeId]
    $urls = @()
    if ($mode.UsesURL) {
        $urls = if ($mode.FixedURL) { @($mode.FixedURL) }
                else { @($script:TxtStartupUrl.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
        if ($urls.Count -eq 0) { throw 'Startup override has no URL.' }
    }
    return [pscustomobject]@{ Enabled = $true; Code = $mode.Code; Urls = $urls }
}

# ---- Helpers: write search-engine + startup overrides into one channel ------
function Resolve-Destination {
    param([string]$DestinationId, [string]$CustomUrl, [string]$SearchEngineHome)
    $entry = $script:DestinationOptions[$DestinationId]
    if (-not $entry) { return $null }
    $code = $entry.Value
    switch ($code) {
        '__SKIP__'   { return $null }
        '__SEARCH__' { return $SearchEngineHome }
        '__CUSTOM__' { return $CustomUrl.Trim() }
        default      { return $code }
    }
}

function Apply-SearchEngineOverride {
    param([string]$Path)
    # Always clear first so toggling off truly removes them
    foreach ($n in @('DefaultSearchProviderEnabled','DefaultSearchProviderName','DefaultSearchProviderKeyword','DefaultSearchProviderSearchURL','DefaultSearchProviderSuggestURL')) {
        try { Remove-ItemProperty -Path $Path -Name $n -ErrorAction Stop } catch {}
    }
    if (-not $script:ChkSearchOverride.Checked) { return $false }

    $engineId = Get-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds
    $eng = $script:SearchEngines[$engineId]
    $url = $eng.URL
    $sug = $eng.Suggest
    $name = $eng.ProviderName
    $keyword = $eng.Keyword
    if ($eng.IsCustom) {
        $url = $script:TxtCustomSearchUrl.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($url)) { Write-Log 'Search override skipped: custom URL is empty.' 'WARN'; return $false }
        if ($url -notmatch '\{searchTerms\}') { Write-Log 'Search override skipped: custom URL must contain {searchTerms}.' 'WARN'; return $false }
        $name = 'Custom Search'
    }
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name 'DefaultSearchProviderEnabled'   -Value 1     -PropertyType DWord  -Force | Out-Null
    New-ItemProperty -Path $Path -Name 'DefaultSearchProviderName'      -Value $name -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $Path -Name 'DefaultSearchProviderKeyword'   -Value $keyword -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $Path -Name 'DefaultSearchProviderSearchURL' -Value $url  -PropertyType String -Force | Out-Null
    if ($sug) {
        New-ItemProperty -Path $Path -Name 'DefaultSearchProviderSuggestURL' -Value $sug -PropertyType String -Force | Out-Null
    }
    Write-Log "Search engine override -> $name" 'OK'
    return $true
}

function Apply-NtpOverride {
    param([string]$Path)
    # Clear first
    try { Remove-ItemProperty -Path $Path -Name 'NewTabPageLocation' -ErrorAction Stop } catch {}
    if (-not $script:ChkNtpOverride.Checked) { return $false }

    # Resolve destination
    $engineId = Get-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds
    $engineHome = if ($script:SearchEngines[$engineId].IsCustom) { '' } else { $script:SearchEngines[$engineId].Home }
    $url = Resolve-Destination -DestinationId (Get-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds) -CustomUrl $script:TxtNtpCustomUrl.Text -SearchEngineHome $engineHome
    if (-not $url) { Write-Log 'NTP override skipped: no resolvable URL.' 'WARN'; return $false }
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name 'NewTabPageLocation' -Value $url -PropertyType String -Force | Out-Null
    Write-Log "New tab page override -> $url" 'OK'
    return $true
}

function Apply-StartupOverride {
    param([string]$Path)
    # Clear first
    try { Remove-ItemProperty -Path $Path -Name 'RestoreOnStartup' -ErrorAction Stop } catch {}
    try { Remove-Item -Path (Join-Path $Path 'RestoreOnStartupURLs') -Recurse -Force -ErrorAction Stop } catch {}
    if (-not $script:ChkStartupOverride.Checked) { return $false }

    $modeId = Get-ComboId -Combo $script:CmbStartupMode -Ids $script:StartupModeIds
    $mode = $script:StartupModes[$modeId]
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name 'RestoreOnStartup' -Value $mode.Code -PropertyType DWord -Force | Out-Null

    if ($mode.UsesURL) {
        $listPath = Join-Path $Path 'RestoreOnStartupURLs'
        New-Item -Path $listPath -Force | Out-Null
        $urls = if ($mode.FixedURL) { @($mode.FixedURL) }
                else { ($script:TxtStartupUrl.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
        if ($urls.Count -eq 0) { Write-Log 'Startup override skipped: no URL provided.' 'WARN'; return $false }
        $i = 1
        foreach ($u in $urls) {
            New-ItemProperty -Path $listPath -Name "$i" -Value $u -PropertyType String -Force | Out-Null
            $i++
        }
        Write-Log "Startup override -> code $($mode.Code), URLs: $($urls -join ', ')" 'OK'
    } else {
        Write-Log "Startup override -> $modeId (code $($mode.Code))" 'OK'
    }
    return $true
}
