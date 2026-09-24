# ============================================================================
#  Localization engine: string tables, T lookups, locale file loading.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Localization engine.
#
# Design rules (see TRANSLATING.md):
#   * This .ps1 stays pure ASCII. Windows PowerShell 5.1 decodes a BOM-less
#     script with the system ANSI code page, so literal CJK here would
#     mojibake on any machine whose code page is not the translator's.
#   * The English catalog below is the single runtime source of truth. The app
#     is fully usable with no locales\ folder at all.
#   * Translations are inert JSON data. They are never executed, they can only
#     replace keys that already exist in English, and they can never supply a
#     registry path, policy name, domain, URL or numeric value.
$script:EnglishStrings  = @{}
$script:LocaleStrings   = @{}
$script:CurrentLocale   = 'en-US'
$script:LocaleDir       = Join-Path $script:AppRoot 'locales'
$script:MaxLocaleValue  = 2000

# Re-entrant guard for "the code is changing the selection, not the user".
# A value picker raises SelectionChanged when code moves its bound index
# exactly as it does for a click, so every bulk update (preset, import, load
# current state) mutes the handlers or the app would conclude the user
# hand-picked a Custom loadout. Depth-counted because these operations nest.
$script:SuppressSelectionEvents = $false
$script:SuppressDepth           = 0

function Push-SuppressSelectionEvents {
    $script:SuppressDepth++
    $script:SuppressSelectionEvents = $true
}

function Pop-SuppressSelectionEvents {
    if ($script:SuppressDepth -gt 0) { $script:SuppressDepth-- }
    if ($script:SuppressDepth -le 0) {
        $script:SuppressDepth = 0
        $script:SuppressSelectionEvents = $false
    }
}

function Add-Strings {
    param([hashtable]$Map)
    foreach ($k in $Map.Keys) { $script:EnglishStrings[$k] = $Map[$k] }
}

function T {
    param(
        [Parameter(Mandatory)][string]$Key,
        # Deliberately NOT named $Args: that would shadow the automatic
        # variable inside a simple function.
        [object[]]$FormatArgs
    )
    if ($script:LocaleStrings.ContainsKey($Key)) {
        $text = $script:LocaleStrings[$Key]
    } elseif ($script:EnglishStrings.ContainsKey($Key)) {
        $text = $script:EnglishStrings[$Key]
    } else {
        # Loud on purpose: a missing key should be obvious during development.
        return "!!$Key!!"
    }
    if ($FormatArgs -and $FormatArgs.Count -gt 0) {
        try { return ($text -f $FormatArgs) } catch { return $text }
    }
    return $text
}

# ---- Locale files -----------------------------------------------------------
# Listing the languages only needs each file's meta block, so the strings are
# neither parsed nor validated here: Set-BfoLocale does both for the one that
# actually loads, and stays on English if it cannot. Cached, because startup
# asks more than once.
$script:AvailableLocales = $null

function Get-AvailableLocales {
    if ($script:AvailableLocales) { return $script:AvailableLocales }
    $list = @([pscustomobject]@{ Code = 'en-US'; Name = 'English'; Path = $null; Reviewed = $true })
    if (-not (Test-Path -LiteralPath $script:LocaleDir)) { return $list }
    foreach ($file in (Get-ChildItem -LiteralPath $script:LocaleDir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $code = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        if ($code -eq 'en-US') { continue }
        # Only the small meta object is parsed; it holds no nested objects.
        $meta = $null
        try {
            $utf8 = New-Object System.Text.UTF8Encoding($false)
            $match = [regex]::Match([System.IO.File]::ReadAllText($file.FullName, $utf8), '"meta"\s*:\s*(\{[^{}]*\})')
            if ($match.Success) { $meta = $match.Groups[1].Value | ConvertFrom-Json }
        } catch { continue }
        if (-not $meta) { continue }
        $display = $code
        if ($meta.name) { $display = "$($meta.name)" }
        $list += [pscustomobject]@{
            Code     = $code
            Name     = $display
            Path     = $file.FullName
            Reviewed = [bool]$meta.reviewed
        }
    }
    $script:AvailableLocales = $list
    return $list
}

function Read-LocaleJson {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    # Explicit UTF-8 decode. Get-Content -Encoding UTF8 behaves differently
    # between Windows PowerShell 5.1 and PowerShell 7, this does not.
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    return ([System.IO.File]::ReadAllText($Path, $utf8) | ConvertFrom-Json)
}

function Import-LocaleFile {
    param([string]$Path)
    $obj = Read-LocaleJson -Path $Path
    if (-not $obj -or -not $obj.strings) { return $null }

    if ($obj.strings -isnot [System.Management.Automation.PSCustomObject]) { return $null }

    $map = @{}
    $rejected = 0
    foreach ($p in $obj.strings.PSObject.Properties) {
        # Structural boundary: a locale may only override keys English already
        # defines. Unknown keys cannot introduce new behavior or new data.
        if (-not $script:EnglishStrings.ContainsKey($p.Name)) { $rejected++; continue }
        if ($p.Value -isnot [string]) { $rejected++; continue }
        if ($p.Value.Length -gt $script:MaxLocaleValue) { $rejected++; continue }
        if ($p.Value -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') { $rejected++; continue }
        # A translation that drops or invents a {0} would make -f throw or
        # print a raw placeholder at the user. Reject that one key and keep its
        # English text; never fail a whole locale over a single bad string.
        if (-not (Test-LocalePlaceholderParity -English $script:EnglishStrings[$p.Name] -Candidate $p.Value)) {
            $rejected++; continue
        }
        $map[$p.Name] = $p.Value
    }
    return @{ Meta = $obj.meta; Strings = $map; Rejected = $rejected }
}

# {0}/{1} must appear in both, and {{ }} escapes must balance, or the runtime
# -f would either throw or emit literal braces into the UI.
function Test-LocalePlaceholderParity {
    param([string]$English, [string]$Candidate)
    $rx = [regex]'\{(\d+)\}'
    $en = @($rx.Matches($English)   | ForEach-Object { $_.Groups[1].Value } | Sort-Object) -join ','
    $lo = @($rx.Matches($Candidate) | ForEach-Object { $_.Groups[1].Value } | Sort-Object) -join ','
    if ($en -ne $lo) { return $false }
    if (([regex]::Matches($English, '\{\{')).Count -ne ([regex]::Matches($Candidate, '\{\{')).Count) { return $false }
    if (([regex]::Matches($English, '\}\}')).Count -ne ([regex]::Matches($Candidate, '\}\}')).Count) { return $false }
    return $true
}

function Set-BfoLocale {
    param([string]$Code)

    if (-not $Code -or $Code -eq 'en-US') {
        $script:LocaleStrings = @{}
        $script:CurrentLocale = 'en-US'
        return $true
    }

    $path = Join-Path $script:LocaleDir ("{0}.json" -f $Code)
    try {
        $loaded = Import-LocaleFile -Path $path
    } catch {
        Write-BfoLog "Locale '$Code' could not be parsed, staying on English: $_" 'WARN'
        return $false
    }
    if (-not $loaded) {
        Write-BfoLog "Locale '$Code' not found or empty, staying on English." 'WARN'
        return $false
    }

    $script:LocaleStrings = $loaded.Strings
    $script:CurrentLocale = $Code
    $coverage = if ($script:EnglishStrings.Count -gt 0) {
        [math]::Round(100.0 * $loaded.Strings.Count / $script:EnglishStrings.Count)
    } else { 0 }
    Write-BfoLog "Locale '$Code' loaded: $($loaded.Strings.Count) strings ($coverage% coverage), $($loaded.Rejected) rejected." 'OK'
    return $true
}

# Coarse script tag for a culture name. Only Chinese actually needs this:
# Simplified and Traditional are different writing systems, so silently
# handing a zh-TW / zh-HK / zh-MO / zh-Hant user the Simplified catalog is
# worse than leaving them in English. Every other language we are likely to
# ship has a single script, so $null (= "no script constraint") is correct.
function Get-LocaleScriptTag {
    param([string]$Code)
    if ([string]::IsNullOrWhiteSpace($Code)) { return $null }
    $parts = @($Code -split '-' | Where-Object { $_ })
    if ($parts.Count -eq 0) { return $null }
    if ($parts[0].ToLowerInvariant() -ne 'zh') { return $null }
    for ($i = 1; $i -lt $parts.Count; $i++) {
        # Script subtags first, then the regions that imply one (case-insensitive).
        switch -Regex ($parts[$i]) {
            '^(hans|cn|sg|my)$' { return 'Hans' }
            '^(hant|tw|hk|mo)$' { return 'Hant' }
        }
    }
    # Bare 'zh' carries no script information at all. Simplified is both the
    # larger population and the only Chinese catalog we ship, so prefer it.
    return 'Hans'
}

# Startup precedence: -Lang, then the persisted BFO setting, then the Windows
# UI culture, then a same-language / same-script file, then English.
function Resolve-StartupLocale {
    param([string]$Requested, [string]$Saved)
    $codes = @((Get-AvailableLocales).Code)
    foreach ($candidate in @($Requested, $Saved, [System.Globalization.CultureInfo]::CurrentUICulture.Name)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $exact = @($codes | Where-Object { $_ -eq $candidate })
        if ($exact.Count -gt 0) { return $exact[0] }

        $lang       = ($candidate -split '-')[0]
        $wantScript = Get-LocaleScriptTag -Code $candidate
        $near = @($codes | Where-Object {
            (($_ -split '-')[0]) -eq $lang -and (Get-LocaleScriptTag -Code $_) -eq $wantScript
        })
        if ($near.Count -gt 0) { return $near[0] }
    }
    return 'en-US'
}
