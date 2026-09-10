# ============================================================================
#  Brave Free Origin - GUI edition for Windows
#  Applies Brave Browser group policies via the registry with a checkbox UI.
#  Source policies researched from brave/brave-core and Chromium enterprise docs.
#
#  This file is deliberately pure ASCII. Windows PowerShell 5.1 decodes a
#  BOM-less .ps1 using the system ANSI code page, so any literal non-ASCII text
#  here would mojibake on machines with a different code page. Translations
#  live in locales\*.json and are read with an explicit UTF-8 decoder.
# ============================================================================

[CmdletBinding()]
param(
    # Force a UI language, e.g. -Lang zh-CN. Falls back to the saved setting,
    # then the Windows UI culture, then English.
    [string]$Lang,

    # Resolved before elevation and forwarded across the UAC boundary, so an
    # elevated administrator account still reads and writes the original
    # user's preference file instead of its own.
    [string]$BfoSettingsPath
)

#region Elevation -------------------------------------------------------------
if (-not $BfoSettingsPath) {
    $BfoSettingsPath = Join-Path $env:LOCALAPPDATA 'Brave-Free-Origin\settings.json'
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Forward our own parameters. The old code rebuilt a fixed command line, so
    # anything passed on the command line vanished at the UAC boundary.
    $relaunchArgs = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $PSCommandPath)
        '-BfoSettingsPath', ('"{0}"' -f $BfoSettingsPath)
    )
    if ($Lang) { $relaunchArgs += @('-Lang', ('"{0}"' -f $Lang)) }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $relaunchArgs
    exit
}
#endregion

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppVersion = '1.12'

#region i18n runtime ----------------------------------------------------------
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
$script:LocaleMeta      = $null
$script:CurrentLocale   = 'en-US'
$script:I18nBindings    = New-Object System.Collections.ArrayList
$script:LocFontBindings = New-Object System.Collections.ArrayList
$script:LocaleDir       = Join-Path $PSScriptRoot 'locales'
$script:MaxLocaleValue  = 2000

# Re-entrant guard for "the code is changing controls, not the user".
# WinForms raises SelectedIndexChanged / CheckedChanged for programmatic
# writes exactly as it does for clicks, so every bulk update (preset, import,
# load current state, language switch) has to mute the handlers or the app
# would conclude the user hand-picked a Custom loadout. Depth-counted because
# these operations nest: a language switch relabels ComboBoxes, which
# reselects, which would otherwise clear the flag too early.
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
function Get-AvailableLocales {
    $list = @([pscustomobject]@{ Code = 'en-US'; Name = 'English'; Path = $null; Reviewed = $true })
    if (-not (Test-Path -LiteralPath $script:LocaleDir)) { return $list }
    foreach ($file in (Get-ChildItem -LiteralPath $script:LocaleDir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $code = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        if ($code -eq 'en-US') { continue }
        $meta = $null
        try {
            $probe = Import-LocaleFile -Path $file.FullName
            if ($probe) { $meta = $probe.Meta }
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
    return $list
}

function Import-LocaleFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    # Explicit UTF-8 decode. Get-Content -Encoding UTF8 behaves differently
    # between Windows PowerShell 5.1 and PowerShell 7, this does not.
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $raw  = [System.IO.File]::ReadAllText($Path, $utf8)
    $obj  = $raw | ConvertFrom-Json
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
        $script:LocaleMeta    = $null
        $script:CurrentLocale = 'en-US'
        return $true
    }

    $path = Join-Path $script:LocaleDir ("{0}.json" -f $Code)
    try {
        $loaded = Import-LocaleFile -Path $path
    } catch {
        Write-Log "Locale '$Code' could not be parsed, staying on English: $_" 'WARN'
        return $false
    }
    if (-not $loaded) {
        Write-Log "Locale '$Code' not found or empty, staying on English." 'WARN'
        return $false
    }

    $script:LocaleStrings = $loaded.Strings
    $script:LocaleMeta    = $loaded.Meta
    $script:CurrentLocale = $Code
    $coverage = if ($script:EnglishStrings.Count -gt 0) {
        [math]::Round(100.0 * $loaded.Strings.Count / $script:EnglishStrings.Count)
    } else { 0 }
    Write-Log "Locale '$Code' loaded: $($loaded.Strings.Count) strings ($coverage% coverage), $($loaded.Rejected) rejected." 'OK'
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
        switch ($parts[$i].ToLowerInvariant()) {
            'hans' { return 'Hans' }
            'hant' { return 'Hant' }
            'cn'   { return 'Hans' }
            'sg'   { return 'Hans' }
            'my'   { return 'Hans' }
            'tw'   { return 'Hant' }
            'hk'   { return 'Hant' }
            'mo'   { return 'Hant' }
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

# ---- Control bindings -------------------------------------------------------
# Every localized control registers itself once, so switching language is a
# single pass instead of 120 hand-maintained assignments.
function Set-Loc {
    param(
        $Control,
        [string]$Key,
        [string]$Property = 'Text',
        [object[]]$FormatArgs,
        # Re-evaluated on every language switch, for arguments that are
        # themselves translated (a group name inside a counted label).
        [scriptblock]$ArgsScript,
        [switch]$Fit,
        [int]$MinWidth = 0
    )
    if ($ArgsScript) { $FormatArgs = @(& $ArgsScript) }
    $Control.$Property = T $Key $FormatArgs
    [void]$script:I18nBindings.Add([pscustomobject]@{
        Kind = 'Property'; Control = $Control; Property = $Property
        Key  = $Key;       Args    = $FormatArgs; ArgsScript = $ArgsScript
        Fit  = [bool]$Fit; MinWidth = $MinWidth
    })
    if ($Fit) { Resize-ToText -Control $Control -MinWidth $MinWidth }
    return $Control
}

function Set-LocTooltip {
    param($Control, [string]$Key, [object[]]$FormatArgs)
    if ($script:ToolTip) { $script:ToolTip.SetToolTip($Control, (T $Key $FormatArgs)) }
    [void]$script:I18nBindings.Add([pscustomobject]@{
        Kind = 'Tooltip'; Control = $Control; Key = $Key; Args = $FormatArgs
    })
}

# Fonts have to be re-resolved on every language switch, not only at build
# time: Segoe UI has no CJK coverage, so a control pinned to it renders
# Chinese through GDI font linking at the wrong metrics. Registering the
# *intent* (size + weight) rather than a Font object lets one pass rebuild
# every localized control for the active locale.
function Set-LocFont {
    param($Control, [single]$Size = 9, [switch]$Semibold)
    [void]$script:LocFontBindings.Add([pscustomobject]@{
        Control = $Control; Size = $Size; Semibold = [bool]$Semibold
    })
    $Control.Font = Get-BfoUiFont -Size $Size -Semibold:$Semibold
    return $Control
}

function Update-LocalizedFonts {
    foreach ($binding in $script:LocFontBindings) {
        try { $binding.Control.Font = Get-BfoUiFont -Size $binding.Size -Semibold:$binding.Semibold }
        catch { }
    }
}

function Resize-ToText {
    param($Control, [int]$MinWidth = 0, [int]$Padding = 24)
    try {
        $measured = [System.Windows.Forms.TextRenderer]::MeasureText($Control.Text, $Control.Font)
        $Control.Width = [Math]::Max($MinWidth, $measured.Width + $Padding)
    } catch { }
}

# A language switch is a pure re-text: it must not move one checkbox, one
# combo selection or the active preset. Relabelling a ComboBox means
# Items.Clear() + refill, which WinForms reports as a user selection change,
# so the whole pass runs with the handlers muted and the active profile is
# captured and restored around it.
function Update-UiLanguage {
    $keepProfile = $script:ActiveProfile
    Push-SuppressSelectionEvents
    try {
        foreach ($binding in $script:I18nBindings) {
            try {
                if ($binding.Kind -eq 'Tooltip') {
                    $script:ToolTip.SetToolTip($binding.Control, (T $binding.Key $binding.Args))
                    continue
                }
                $bindArgs = $binding.Args
                if ($binding.ArgsScript) { $bindArgs = @(& $binding.ArgsScript) }
                $binding.Control.($binding.Property) = T $binding.Key $bindArgs
                if ($binding.Fit) { Resize-ToText -Control $binding.Control -MinWidth $binding.MinWidth }
            } catch { }
        }
        Update-LocalizedFonts
        Update-LocalizedCombos
        Update-LocalizedRowText
        Update-ScriptletLocalizedText
        Set-ModeButtonRow
    } finally {
        Pop-SuppressSelectionEvents
    }
    # Restored explicitly: a handler that somehow slipped through must not be
    # able to downgrade "Recommended" to "Custom" just because labels changed.
    $script:ActiveProfile = $keepProfile
    # Enabled-state of the custom-URL boxes is derived from combo selection,
    # so re-derive it now that the selections are known to be the originals.
    Update-OverrideControlStates
    Update-SelectionSummary
    Update-ConfigurationFilter
}

# ---- Localized widgets that are not plain .Text properties ------------------
function Update-ChannelComboLabels {
    if (-not $script:ChannelCombo) { return }
    $keep = Get-ComboId -Combo $script:ChannelCombo -Ids $script:ChannelIds
    Push-SuppressSelectionEvents
    try {
        $script:ChannelCombo.BeginUpdate()
        try {
            $script:ChannelCombo.Items.Clear()
            for ($i = 0; $i -lt @($script:ChannelIds).Count; $i++) {
                $id  = @($script:ChannelIds)[$i]
                $key = @($script:ChannelLabelKeys)[$i]
                if ($id -eq '__ALL__') { [void]$script:ChannelCombo.Items.Add((T $key)) }
                else                   { [void]$script:ChannelCombo.Items.Add((T $key @($id))) }
            }
        } finally {
            $script:ChannelCombo.EndUpdate()
        }
        if (-not (Set-ComboId -Combo $script:ChannelCombo -Ids $script:ChannelIds -Id $keep)) {
            if ($script:ChannelCombo.Items.Count -gt 0) { $script:ChannelCombo.SelectedIndex = 0 }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
}

# The three custom-URL text boxes are enabled purely as a function of their
# combo's selected id. Derived state, so it is safe to recompute at any time -
# and it has to be recomputed after any suppressed bulk update.
function Update-OverrideControlStates {
    if ($script:CmbSearchEngine -and $script:TxtCustomSearchUrl) {
        $script:TxtCustomSearchUrl.Enabled =
            ((Get-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds) -eq 'custom')
    }
    if ($script:CmbNtpDest -and $script:TxtNtpCustomUrl) {
        $script:TxtNtpCustomUrl.Enabled =
            ((Get-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds) -eq 'custom')
    }
    if ($script:CmbStartupMode -and $script:TxtStartupUrl) {
        $modeId = Get-ComboId -Combo $script:CmbStartupMode -Ids $script:StartupModeIds
        $mode   = if ($modeId) { $script:StartupModes[$modeId] } else { $null }
        $script:TxtStartupUrl.Enabled = [bool]($mode -and $mode.UsesURL -and -not $mode.FixedURL)
    }
}

function Update-LocalizedCombos {
    Update-ChannelComboLabels
    Set-ComboLabels -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds  -LabelKeys $script:SearchEngineLabelKeys
    Set-ComboLabels -Combo $script:CmbNtpDest      -Ids $script:DestinationIds   -LabelKeys $script:DestinationLabelKeys
    Set-ComboLabels -Combo $script:CmbStartupMode  -Ids $script:StartupModeIds   -LabelKeys $script:StartupModeLabelKeys
    foreach ($name in @($script:PolicyCombos.Keys)) {
        Set-ComboLabels -Combo $script:PolicyCombos[$name] `
                        -Ids $script:PolicyChoiceIds[$name] `
                        -LabelKeys $script:PolicyChoiceKeys[$name]
    }
}

# The preset row is the one place where a longer translated caption could
# overlap its neighbour, so it is measured and re-flowed instead of pinned.
function Set-ModeButtonRow {
    if (-not $script:ModeButtons) { return }
    $buttons = @($script:ModeButtons)
    if ($buttons.Count -eq 0) { return }

    $gap       = 6
    $available = 1120
    if ($buttons[0].Parent) {
        $available = [Math]::Max(500, $buttons[0].Parent.ClientSize.Width - 28)
    }

    # Trim the caption padding before letting the row run off the panel. Seven
    # buttons at the 90px floor always fit, so this terminates.
    $padding = 24
    while ($padding -gt 8) {
        $total = -$gap
        foreach ($btn in $buttons) {
            $measured = [System.Windows.Forms.TextRenderer]::MeasureText($btn.Text, $btn.Font)
            $total += [Math]::Max(90, $measured.Width + $padding) + $gap
        }
        if ($total -le $available) { break }
        $padding -= 4
    }
    if ($padding -lt 8) { $padding = 8 }

    $x = 14
    foreach ($btn in $buttons) {
        $measured = [System.Windows.Forms.TextRenderer]::MeasureText($btn.Text, $btn.Font)
        $btn.Width = [Math]::Max(90, $measured.Width + $padding)
        $btn.Left  = $x
        $x = $btn.Right + $gap
    }
}

# ---- Fonts / metrics --------------------------------------------------------
# Segoe UI has no CJK coverage and there is no "Microsoft YaHei UI Semibold"
# family, so bold has to be requested as a style rather than a family name.
function Get-BfoUiFont {
    param([single]$Size = 9, [switch]$Semibold)
    if ($script:CurrentLocale -like 'zh-*') {
        foreach ($family in @('Microsoft YaHei UI', 'Microsoft YaHei')) {
            try {
                $style = if ($Semibold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
                return New-Object System.Drawing.Font($family, $Size, $style)
            } catch { }
        }
    }
    $fallback = if ($Semibold) { 'Segoe UI Semibold' } else { 'Segoe UI' }
    try { return New-Object System.Drawing.Font($fallback, $Size) }
    catch { return New-Object System.Drawing.Font('Segoe UI', $Size) }
}

# CJK needs more vertical room at the same point size.
function Get-PolicyRowHeight { if ($script:CurrentLocale -like 'zh-*') { return 36 } else { return 28 } }
function Get-PolicyDescHeight { if ($script:CurrentLocale -like 'zh-*') { return 34 } else { return 30 } }
function Get-PolicyDescFontSize { if ($script:CurrentLocale -like 'zh-*') { return 9 } else { return 8 } }

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
    } catch { }
}
#endregion

#region English string catalog ------------------------------------------------
# Runtime source of truth for every user-visible string.
# locales\en-US.json is GENERATED from this block (tools\Export-EnglishLocale.ps1)
# and exists only as a reference for translators - it is never loaded.

# ---- Application chrome ------------------------------------------------------
Add-Strings @{
    'app.name'                = 'Brave Free Origin'
    'app.title'               = 'Brave Free Origin v{0}  -  the free answer to Brave Origin''s paywalled minimal mode'
    'channel.installed'       = '{0}  (installed)'
    'channel.notInstalled'    = '{0}  (not installed)'
    'header.allChannels'      = 'All installed channels'
    'header.braveDetected'    = 'Brave detected: {0}'
    'header.hives'            = '-> {0} ({1} hives)'
    'header.language'         = 'Language:'
    'header.originNote'       = 'Context: Brave described Origin on April 16, 2026 as a minimalist build, then put that stripped-down idea behind a paywall. This is the free local version.'
    'header.subtitle'         = 'Strip out the AI, crypto, VPN, promo junk, and background clutter Brave stuffed in, then tune it for a lighter desktop footprint.'
    'header.targetChannel'    = 'Target channel:'
    'header.unreviewedLocale' = 'community translation, unreviewed'
}

# ---- Mode deck ---------------------------------------------------------------
Add-Strings @{
    'mode.intro'    = 'Pick a one-click mode, then tweak the tabs below if you want to go deeper.'
    'mode.label'    = 'Mode: {0}'
    'mode.policies' = 'Policies: {0} / {1}'
    'mode.risk'     = 'Risk: {0}'
    'mode.system'   = 'System: {0} tasks, {1} services'
}

# ---- Presets -----------------------------------------------------------------
# Preset ids (Minimal, Origin, ...) are stable and never translated.
Add-Strings @{
    'preset.CurrentState.description'   = 'Read from this PC. Shows what is already disabled right now.'
    'preset.CurrentState.name'          = 'Current State'
    'preset.CurrentState.risk'          = 'Read only'
    'preset.Custom.description'         = 'Hand-picked mix. Use the tabs below to build your own Brave loadout.'
    'preset.Custom.name'                = 'Custom'
    'preset.Custom.risk'                = 'Depends on your picks'
    'preset.MaxPerformance.description' = 'Full fusion mode: Origin Mode, Privacy + Boost, and the strong privacy set combined, plus a few extra UI trims. This is the closest thing to an all-in gamer build.'
    'preset.MaxPerformance.name'        = 'Max Performance'
    'preset.MaxPerformance.risk'        = 'High risk'
    'preset.MaxPrivacy.description'     = 'Aggressive lockdown. Great for hard privacy, but it can disable sync, sign-in, imports, and Brave update services.'
    'preset.MaxPrivacy.name'            = 'Max Privacy'
    'preset.MaxPrivacy.risk'            = 'High risk'
    'preset.Minimal.description'        = 'Quick debloat. Removes the loudest commercial extras without changing the whole browser.'
    'preset.Minimal.name'               = 'Quick Debloat'
    'preset.Minimal.risk'               = 'Low risk'
    'preset.None.description'           = 'Stock behavior. Nothing selected, nothing will be enforced.'
    'preset.None.name'                  = 'Stock / None'
    'preset.None.risk'                  = 'No changes'
    'preset.Origin.description'         = 'Matches Brave Origin''s stripped-down idea from April 2026: off by default for Leo, Rewards, Wallet, VPN, News, Talk, Tor, Wayback, Web Discovery, and related stats.'
    'preset.Origin.name'                = 'Origin Mode'
    'preset.Origin.risk'                = 'Low risk'
    'preset.Performance.description'    = 'Privacy + Boost. Origin-style debloat plus startup and latency tuning for a leaner browser during gaming, streaming, or music use.'
    'preset.Performance.name'           = 'Privacy + Boost'
    'preset.Performance.risk'           = 'Medium risk'
    'preset.Recommended.description'    = 'Balanced daily-driver setup. Good privacy, lighter UI, keeps core compatibility and media-friendly defaults.'
    'preset.Recommended.name'           = 'Recommended'
    'preset.Recommended.risk'           = 'Low risk'
}

# ---- Configuration filter ----------------------------------------------------
Add-Strings @{
    'filter.clear'         = 'Clear'
    'filter.label'         = 'Filter configuration:'
    'filter.matches'       = '{0} of {1} settings shown'
    'filter.noMatches'     = 'No settings match this filter.'
    'filter.placeholder'   = 'Type to filter every setting (name, description, category)...'
    'filter.selectedOnly'  = 'Selected only'
    'filter.tabCount'      = '{0} ({1})'
    'policyTab.selectAll'  = 'Select all'
    'policyTab.selectNone' = 'Select none'
}

# ---- Tabs --------------------------------------------------------------------
Add-Strings @{
    'tab.hosts'         = 'Hosts Blocklist (DNS-level)'
    'tab.scriptlets'    = 'Default Scriptlets (Advanced)'
    'tab.searchStartup' = 'Search & Startup'
    'tab.system'        = 'System (Tasks / Services)'
}

# ---- Policy categories -------------------------------------------------------
Add-Strings @{
    'category.aiGenAi'               = 'AI / GenAI'
    'category.autofillPasswords'     = 'Autofill / Passwords'
    'category.braveFeatures'         = 'Brave Features'
    'category.performanceStartup'    = 'Performance / Startup'
    'category.privacyTelemetry'      = 'Privacy / Telemetry'
    'category.safetyUpdates'         = 'Safety / Updates'
    'category.searchSuggestions'     = 'Search / Suggestions'
    'category.uiBloatExtras'         = 'UI Bloat / Extras'
    'category.webServicesBackground' = 'Web Services / Background'
}

# ---- Policy descriptions -----------------------------------------------------
# Keyed on the registry value name, which is never translated.
Add-Strings @{
    'policy.AccessibilityImageLabelsEnabled.description'              = 'Disable cloud image-description service (sends images to Google).'
    'policy.AlternateErrorPagesEnabled.description'                   = 'Disable Google-hosted suggestion page on DNS errors.'
    'policy.AutofillAddressEnabled.description'                       = 'Disable autofill of addresses / contact info.'
    'policy.AutofillCreditCardEnabled.description'                    = 'Disable autofill of credit cards.'
    'policy.AutoplayAllowed.description'                              = 'Block autoplaying media site-wide.'
    'policy.BackgroundModeEnabled.description'                        = 'Stop Brave from running in the background after window close.'
    'policy.BatterySaverModeAvailability.description'                 = 'Allow Battery Saver on low battery (2). 1=always on unplugged, 0=disabled.'
    'policy.BookmarkBarEnabled.description'                           = 'Hide bookmark bar globally (small render win). Unticking lets user toggle.'
    'policy.BraveAIChatEnabled.description'                           = 'Disable Leo AI Chat assistant.'
    'policy.BraveDeAmpEnabled.description'                            = 'Bypass Google AMP pages to reach publisher directly. (Leave ON for privacy.)'
    'policy.BraveDebouncingEnabled.description'                       = 'Protect against bounce-tracking redirect chains. (Leave ON for privacy.)'
    'policy.BraveGlobalPrivacyControlEnabled.description'             = 'Enable Sec-GPC "do not sell/share" signal. (Leave ON for privacy.)'
    'policy.BraveNewsDisabled.description'                            = 'Disable Brave News feed on the new tab page.'
    'policy.BraveP3AEnabled.description'                              = 'Disable P3A privacy-preserving product analytics.'
    'policy.BravePlaylistEnabled.description'                         = 'Disable Playlist feature (save videos/audio).'
    'policy.BraveReduceLanguageEnabled.description'                   = 'Reduce language-preference fingerprinting. (Leave ON for privacy.)'
    'policy.BraveRewardsDisabled.description'                         = 'Disable Brave Rewards (BAT ads/tips) and hide all Rewards UI.'
    'policy.BraveSpeedreaderEnabled.description'                      = 'Disable Speedreader reading-mode feature.'
    'policy.BraveStatsPingEnabled.description'                        = 'Disable anonymous daily/weekly/monthly usage ping.'
    'policy.BraveTalkDisabled.description'                            = 'Disable Brave Talk (Jitsi-based video calls).'
    'policy.BraveTrackingQueryParametersFilteringEnabled.description' = 'Strip tracking params (utm_, fbclid, etc.) from URLs. (Leave ON for privacy.)'
    'policy.BraveVPNDisabled.description'                             = 'Disable Brave VPN integration and all VPN UI.'
    'policy.BraveWalletDisabled.description'                          = 'Disable the built-in crypto wallet (ETH/BTC/SOL/FIL/ZEC).'
    'policy.BraveWaybackMachineEnabled.description'                   = 'Disable the "Check Wayback Machine" prompt on 404 pages.'
    'policy.BraveWebDiscoveryEnabled.description'                     = 'Disable Web Discovery Project search index contribution.'
    'policy.BrowserLabsEnabled.description'                           = 'Hide the Labs / experimental features icon in the toolbar.'
    'policy.BrowserSignin.description'                                = 'Fully disable sign-in UI (0). 1=allow, 2=force.'
    'policy.BuiltInDnsClientEnabled.description'                      = 'Use OS resolver instead of async DoH client. Only tick if you want OS DNS.'
    'policy.ChromeCleanupEnabled.description'                         = 'Disable the software-cleanup scanner (harmless on Brave).'
    'policy.ChromeCleanupReportingEnabled.description'                = 'Disable reporting from the cleanup scanner.'
    'policy.ChromeVariations.description'                             = 'Opt out of all Chromium field trials/experiments (2). 1=critical only, 0=all.'
    'policy.CloudPrintSubmitEnabled.description'                      = 'Disable legacy cloud-print submissions.'
    'policy.CloudReportingEnabled.description'                        = 'Disable enterprise cloud reporting.'
    'policy.ComponentUpdatesEnabled.description'                      = 'Disable Chromium component updates (e.g. Widevine). Only tick if you know what this breaks.'
    'policy.CreateThemesSettings.description'                         = 'Disable AI-generated themes.'
    'policy.DefaultBraveAdblockSetting.description'                   = 'Force default ad-blocking to Block (2). 1=Allow.'
    'policy.DefaultBraveFingerprintingV2Setting.description'          = 'Set fingerprint protection to Standard (3). 1=Off.'
    'policy.DefaultBraveHttpsUpgradeSetting.description'              = 'Force HTTPS upgrade to Strict (2). 3=Standard, 1=Disabled.'
    'policy.DefaultBraveReferrersSetting.description'                 = 'Cap cross-site referrers to strict-origin-when-cross-origin (2).'
    'policy.DefaultBraveRemember1PStorageSetting.description'         = 'Forget first-party storage on tab close (2). 1=Remember.'
    'policy.DefaultBrowserSettingEnabled.description'                 = 'Disable the "make default browser" prompt.'
    'policy.DevToolsGenAiSettings.description'                        = 'Disable GenAI features inside DevTools.'
    'policy.DiskCacheSize.description'                                = 'Cap disk cache at 250 MB (value in bytes). Prevents unbounded cache growth on SSDs.'
    'policy.DnsOverHttpsMode.description'                             = 'Allow DoH ("automatic"). Set to "secure" to force, "off" to disable.'
    'policy.GenAiDefaultSettings.description'                         = 'Disable ALL upstream Chromium GenAI features (2).'
    'policy.HardwareAccelerationModeEnabled.choice.disable'           = 'Disable (0)'
    'policy.HardwareAccelerationModeEnabled.choice.enable'            = 'Enable (1)'
    'policy.HardwareAccelerationModeEnabled.description'              = 'GPU hardware acceleration. Enabled by default in every mode. Pick Disable (0) to fix GPU driver glitches, artifacts or crashes. Untick the box to leave Brave in control.'
    'policy.HelpMeWriteSettings.description'                          = 'Disable "Help me write" compose features.'
    'policy.HighEfficiencyModeEnabled.description'                    = 'Memory Saver: sleep inactive tabs to reclaim RAM/CPU.'
    'policy.HistorySearchSettings.description'                        = 'Disable AI-powered history search.'
    'policy.HomepageIsNewTabPage.description'                         = 'Decouple home button from the bloated NTP.'
    'policy.HomepageLocation.description'                             = 'Blank homepage = fastest possible startup.'
    'policy.IPFSEnabled.description'                                  = 'Disable IPFS protocol support.'
    'policy.ImportAutofillFormData.description'                       = 'Block autofill import on first run.'
    'policy.ImportBookmarks.description'                              = 'Block bookmark import prompt on first run.'
    'policy.ImportHistory.description'                                = 'Block history import on first run.'
    'policy.ImportSavedPasswords.description'                         = 'Block password import on first run.'
    'policy.ImportSearchEngine.description'                           = 'Block search-engine import on first run.'
    'policy.LensDesktopNTPSearchEnabled.description'                  = 'Hide Google Lens search box on new tab page.'
    'policy.LensOverlaySettings.description'                          = 'Disable the Lens overlay feature (1 = disabled).'
    'policy.LensRegionSearchEnabled.description'                      = 'Disable right-click Google Lens region search.'
    'policy.LiveCaptionEnabled.description'                           = 'Disable Live Caption (stops background download of speech-recognition model).'
    'policy.MediaRouterEnabled.description'                           = 'Disable Google Cast / Media Router. Stops background mDNS discovery and memory overhead.'
    'policy.MetricsReportingEnabled.description'                      = 'Disable Chromium UMA crash/usage metrics.'
    'policy.NTPCustomBackgroundEnabled.description'                   = 'Disable the custom new-tab-page background (stops wallpaper download).'
    'policy.NetworkPredictionOptions.description'                     = 'Never prefetch DNS/TCP/SSL (2). 0/1 = predict.'
    'policy.NewTabPageLocation.description'                           = 'Force new tab page to about:blank. Kills all NTP bloat.'
    'policy.PasswordLeakDetectionEnabled.description'                 = 'Disable leaked-credential check (avoids sending hashed pw to Google).'
    'policy.PasswordManagerEnabled.description'                       = 'Disable built-in password manager (use Bitwarden / Proton Pass instead).'
    'policy.PaymentMethodQueryEnabled.description'                    = 'Prevent sites from querying for saved payment methods.'
    'policy.PromotionalTabsEnabled.description'                       = 'Disable the welcome/promo new-tab content.'
    'policy.PromptForDownloadLocation.description'                    = 'Auto-save to Downloads without prompting. Set 1 if you prefer prompts.'
    'policy.QuicAllowed.description'                                  = 'Enable QUIC / HTTP/3 protocol. Faster TLS handshake, lower latency.'
    'policy.ReadingListEnabled.description'                           = 'Remove the Reading List UI.'
    'policy.RestoreOnStartup.description'                             = 'Open blank new-tab on launch (5). Faster than restoring last session (1).'
    'policy.SafeBrowsingDeepScanningEnabled.description'              = 'Disable uploading downloads to Google for deep scan.'
    'policy.SafeBrowsingExtendedReportingEnabled.description'         = 'Disable sending extra info to Google Safe Browsing.'
    'policy.SafeBrowsingProtectionLevel.description'                  = 'Set Safe Browsing to Standard (1). 0=Off, 2=Enhanced (sends more to Google).'
    'policy.SafeBrowsingSurveysEnabled.description'                   = 'Disable Safe Browsing user surveys.'
    'policy.SearchSuggestEnabled.description'                         = 'Disable search-engine autosuggest in the omnibox.'
    'policy.ShowHomeButton.description'                               = 'Hide the Home button (tiny UI/render win).'
    'policy.SigninAllowed.description'                                = 'Disable Google/Brave account sign-in.'
    'policy.SpellCheckServiceEnabled.description'                     = 'Disable the enhanced (cloud) spellcheck service.'
    'policy.SpellcheckEnabled.description'                            = 'Disable local spellcheck entirely.'
    'policy.SyncDisabled.description'                                 = 'Disable profile sync entirely.'
    'policy.TabOrganizerSettings.description'                         = 'Disable AI Tab Organizer.'
    'policy.TorDisabled.description'                                  = 'Disable "Private Window with Tor". (Brave Tor is not recommended over real Tor Browser.)'
    'policy.TranslateEnabled.description'                             = 'Disable the "translate this page" Google prompt.'
    'policy.UrlKeyedAnonymizedDataCollectionEnabled.description'      = 'Disable "Make searches and browsing better" URL reporting.'
    'policy.UserFeedbackAllowed.description'                          = 'Disable the "Send feedback" UI that uploads diagnostics to Brave/Google.'
    'policy.WebRtcEventLogCollectionAllowed.description'              = 'Block upload of WebRTC event logs to Google.'
    'policy.WebTorrentDisabled.description'                           = 'Disable WebTorrent / magnet link integration.'
    'policy.WelcomePageOnOSUpgradeEnabled.description'                = 'Disable the "welcome back after OS upgrade" tab.'
}

# ---- Tasks and services ------------------------------------------------------
Add-Strings @{
    'service.BraveElevationService.description'           = 'Brave Elevation Service - helper used by Omaha for per-machine updates.'
    'service.BraveVPNService.description'                 = 'Brave VPN Service (present only if VPN feature installed).'
    'service.BraveVpnWireguardService.description'        = 'Brave VPN Wireguard Service (present only if VPN feature installed).'
    'service.brave.description'                           = 'Brave Update Service - main Omaha update service.'
    'service.bravem.description'                          = 'Brave Update Service (medium-integrity on-demand helper).'
    'system.intro'                                        = 'Background updaters matter most for the Privacy + Boost, Max Performance, and Max Privacy modes. Disabling services is the riskiest step because it can block Brave auto-updates.'
    'system.svcHdr'                                       = 'Windows Services'
    'system.tasksHdr'                                     = 'Scheduled Tasks'
    'task.BraveSoftwareUpdateTaskMachineCore.description' = 'Hourly "core" update check launched by Brave Omaha.'
    'task.BraveSoftwareUpdateTaskMachineUA.description'   = 'The actual version-check/download task.'
}

# ---- Hosts blocklist ---------------------------------------------------------
Add-Strings @{
    'hosts.components.description'   = 'WARNING: blocking this stops Widevine/CRX/iOS-style components from updating. Use only if ComponentUpdatesEnabled is also off.'
    'hosts.components.name'          = 'Component Updates'
    'hosts.news.description'         = 'News content CDN. Block ONLY if you have disabled News - unblocking is needed if you ever re-enable it.'
    'hosts.news.name'                = 'Brave News CDN'
    'hosts.p3a.description'          = 'Privacy-preserving analytics endpoints. Pure telemetry, never user-facing. Safe to block.'
    'hosts.p3a.name'                 = 'Brave P3A telemetry'
    'hosts.rewards.description'      = 'Brave Rewards (BAT) servers. Block ONLY if you do not use Rewards. Will break the feature if you turn it on later.'
    'hosts.rewards.name'             = 'Brave Rewards / BAT'
    'hosts.stats.description'        = 'Daily/weekly/monthly anonymous usage ping. Safe to block.'
    'hosts.stats.name'               = 'Brave Stats ping'
    'hosts.variations.description'   = 'Field-trial / experiment config. Safe to block - matches ChromeVariations=2 policy.'
    'hosts.variations.name'          = 'Brave Variations'
    'hosts.webDiscovery.description' = 'Web Discovery Project endpoints. Already covered by BraveWebDiscoveryEnabled policy; only useful if policy is bypassed.'
    'hosts.webDiscovery.name'        = 'Web Discovery'
    'hostsTab.apply'                 = 'Apply hosts blocks'
    'hostsTab.groupLabel'            = '{0}  [{1} domain(s)]'
    'hostsTab.intro'                 = 'Optional second layer of defense: nullroute Brave telemetry domains in C:\Windows\System32\drivers\etc\hosts. Even if a policy is bypassed by an update, the network call still fails. Sentinel-tagged for clean revert. Backups land in Documents\Brave-Free-Origin-Backups.'
    'hostsTab.load'                  = 'Load current state'
    'hostsTab.open'                  = 'Open hosts file'
    'hostsTab.preview'               = 'Preview hosts'
    'hostsTab.remove'                = 'Remove hosts block'
    'hostsTab.warn'                  = 'Independent of the "Apply to Brave" button. Use the buttons in this tab to apply or remove the hosts block.'
}

# ---- Scriptlet manager -------------------------------------------------------
Add-Strings @{
    'scriptlet.advancedMode'    = 'Advanced edit mode (allow list.txt modifications)'
    'scriptlet.affectDupes'     = 'Affect duplicate raw rules in the same file'
    'scriptlet.autoPath'        = 'Auto path'
    'scriptlet.backupAll'       = 'Backup all lists'
    'scriptlet.browse'          = 'Browse...'
    'scriptlet.checkFiltered'   = 'Check filtered'
    'scriptlet.clearChecks'     = 'Clear checks'
    'scriptlet.col.arguments'   = 'Arguments'
    'scriptlet.col.domain'      = 'Domain'
    'scriptlet.col.line'        = 'Line'
    'scriptlet.col.pick'        = 'Pick / status'
    'scriptlet.col.rawRule'     = 'Raw rule'
    'scriptlet.col.scriptlet'   = 'Scriptlet'
    'scriptlet.col.source'      = 'Source / version'
    'scriptlet.disableChecked'  = 'Disable checked'
    'scriptlet.disabledOnly'    = 'Show disabled by this app only'
    'scriptlet.enableChecked'   = 'Enable checked'
    'scriptlet.exportCsv'       = 'Export visible CSV'
    'scriptlet.exportPrefs'     = 'Export disabled prefs'
    'scriptlet.filter'          = 'Filter'
    'scriptlet.footer'          = 'Tip: if Scan finds nothing, use Browse and select the folder named "User Data" under your Brave profile. This feature edits component filter lists only when Advanced edit mode is ticked.'
    'scriptlet.importPrefs'     = 'Import + reapply prefs'
    'scriptlet.intro'           = 'Optional advanced tool: view Brave''s built-in adblock scriptlet rules from component filter lists. Editing is manual-only, never part of presets, and never triggered by Apply to Brave.'
    'scriptlet.openFolder'      = 'Open folder'
    'scriptlet.restoreAll'      = 'Restore all backups'
    'scriptlet.restoreSelected' = 'Restore selected file'
    'scriptlet.risk'            = 'Risk: disabling scriptlets can break adblocking, anti-annoyance fixes, cookie banners, video sites, or site compatibility. Brave updates may replace component versions; export disabled preferences and reapply after updates if needed.'
    'scriptlet.rootLabel'       = 'Brave User Data folder:'
    'scriptlet.renderDone'      = ' Render completed in {0}s.'
    'scriptlet.scan'            = 'Scan'
    'scriptlet.scanDone'        = ' Scan completed in {0}s.'
    'scriptlet.searchLabel'     = 'Search/filter:'
    'scriptlet.state.disabled'  = 'Disabled'
    'scriptlet.state.enabled'   = 'Enabled'
    'scriptlet.statusFinding'   = 'Finding Brave scriptlet list files...'
    'scriptlet.statusFound'     = 'Found {0} list file(s). Scanning in chunks...'
    'scriptlet.statusIdle'      = 'Scan a Brave User Data folder to list internal scriptlet rules.'
    'scriptlet.statusRender0'   = 'Rendering 0 / {0} visible scriptlet row(s)...'
    'scriptlet.statusRenderN'   = 'Rendering {0} scriptlet row(s)...'
    'scriptlet.statusRendering' = 'Rendering {0} / {1} visible scriptlet row(s)... {2}s'
    'scriptlet.statusScanning'  = 'Scanning file {0} / {1}: {2}. Found {3} rule(s). {4}%. {5}s'
    'scriptlet.statusShowing'   = 'Showing {0} / {1}. Enabled: {2}. Disabled: {3}. Checked: {4}.'
    'scriptlet.statusStarting'  = 'starting...'
    'scriptlet.tipAffectDupes'  = 'Brave lists can contain the same scriptlet rule multiple times. Leave this on unless you only want the exact selected line.'
    'scriptlet.tipCheckFiltered' = 'Checks every row matching the active search/show filters, including rows not currently painted in the table.'
    'scriptlet.viewSelected'    = 'View selected'
}

# ---- Search and startup ------------------------------------------------------
# Search engine brand names are labels only; ProviderName in the data model is what reaches the registry.
Add-Strings @{
    'destination.blank'           = 'Blank page (about:blank)'
    'destination.braveSearchHome' = 'Brave Search homepage'
    'destination.custom'          = 'Custom URL...'
    'destination.duckduckgoHome'  = 'DuckDuckGo homepage'
    'destination.googleHome'      = 'Google homepage'
    'destination.matchSearch'     = 'Match the search engine I picked above'
    'destination.ntpDefault'      = 'Default new tab page (do not override)'
    'engine.bing'                 = 'Bing'
    'engine.brave'                = 'Brave Search'
    'engine.custom'               = 'Custom...'
    'engine.duckduckgo'           = 'DuckDuckGo'
    'engine.ecosia'               = 'Ecosia'
    'engine.google'               = 'Google'
    'engine.kagi'                 = 'Kagi (paid)'
    'engine.mojeek'               = 'Mojeek'
    'engine.qwant'                = 'Qwant'
    'engine.startpage'            = 'Startpage'
    'engine.yandex'               = 'Yandex'
    'searchTab.chkNtp'            = 'Override new tab page (writes NewTabPageLocation policy)'
    'searchTab.chkSearch'         = 'Force a default search engine (writes DefaultSearchProvider* policies)'
    'searchTab.chkStartup'        = 'Override startup behavior (writes RestoreOnStartup + RestoreOnStartupURLs policies)'
    'searchTab.conflictNote'      = 'Note: this tab is processed AFTER the Performance / Startup tab, so it cleanly overrides any ''NewTabPageLocation'' / ''HomepageLocation'' / ''RestoreOnStartup'' values set there. Untick + Apply removes the override and lets your Performance tab values (or stock Brave) take back over.'
    'searchTab.customLabel'       = 'Custom search URL:'
    'searchTab.engineLabel'       = 'Engine:'
    'searchTab.intro'             = 'Pick the omnibox search engine and what opens when Brave launches / when you open a new tab. Each section is independent and only fires when its checkbox is ticked. Unticking + Apply removes the override.'
    'searchTab.modeLabel'         = 'Mode:'
    'searchTab.ntpCustomLabel'    = 'Custom URL:'
    'searchTab.ntpOpenLabel'      = 'Open:'
    'searchTab.searchHelp'        = 'Custom must use {{searchTerms}} as the placeholder. Example: https://my-searx/search?q={{searchTerms}}'
    'searchTab.secNtp'            = 'New Tab Page'
    'searchTab.secSearch'         = 'Default search engine (omnibox / address bar)'
    'searchTab.secStartup'        = 'Startup Behavior (what opens when you launch Brave)'
    'searchTab.startupHelp'       = 'For "specific page or set", separate multiple URLs with a comma. Each opens in its own tab.'
    'searchTab.urlLabel'          = 'URL(s):'
    'startupMode.blankPage'       = 'Open a blank page'
    'startupMode.newTab'          = 'Open the new tab page'
    'startupMode.restoreSession'  = 'Restore my last session'
    'startupMode.specificPages'   = 'Open a specific page or set'
}

# ---- Extensions --------------------------------------------------------------
Add-Strings @{
    'ext.bitwarden' = 'Install Bitwarden (password manager)'
    'ext.intro'     = 'Brave Shields is already a native ad/tracker blocker (same filter-list lineage as uBlock Origin, runs in-engine so slightly faster). We do NOT force-install anything - that would show a ''Managed by your organization'' banner and lock the extension on. These buttons just open the install pages in Brave so you can decide.'
    'ext.section'   = 'Extensions (optional, manual install)'
    'ext.shields'   = 'Open Brave Shields settings'
    'ext.uboLite'   = 'Install uBlock Origin Lite (MV3)'
    'ext.warn'      = 'Caution: running uBlock Origin on top of Shields = double-blocking. Wastes CPU per tab and can break sites Shields handles fine. If you install uBO, consider switching Shields to Standard (not Aggressive) to reduce overlap.'
}

# ---- Utility bar -------------------------------------------------------------
Add-Strings @{
    'action.apply'       = 'Apply to Brave'
    'action.backup'      = 'Backup existing policies before applying'
    'action.fullRestore' = 'Full restore / stock'
    'action.preview'     = 'Preview changes'
    'util.close'         = 'Close'
    'util.export'        = 'Export config'
    'util.flow'          = 'Pick mode -> tweak -> Preview -> Apply -> restart Brave -> Verify'
    'util.import'        = 'Import config'
    'util.loadState'     = 'Load current state'
    'util.openPolicy'    = 'Open brave://policy'
    'util.verify'        = 'Verify'
}

# ---- Reports -----------------------------------------------------------------
# Report bodies stay English on purpose - they get pasted into bug reports.
Add-Strings @{
    'report.close'          = 'Close'
    'report.copy'           = 'Copy'
    'report.hostsTitle'     = 'Hosts preview'
    'report.previewTitle'   = 'Preview apply changes'
    'report.save'           = 'Save report'
    'report.scriptletTitle' = 'Scriptlet details'
    'report.verifyTitle'    = 'Verify - registry vs selections'
}

# ---- File dialogs ------------------------------------------------------------
# Only the human-readable half of a filter is translatable. The *.txt / *.json
# glob is concatenated in code, so a translation can never produce a filter
# string that Windows refuses to parse.
Add-Strings @{
    'dialog.browseUserData'        = 'Select Brave User Data folder'
    'dialog.filter.config'         = 'JSON config'
    'dialog.filter.csv'            = 'CSV'
    'dialog.filter.scriptletPrefs' = 'Scriptlet preferences'
    'dialog.filter.textReport'     = 'Text report'
}

# ---- Dialogs -----------------------------------------------------------------
Add-Strings @{
    'msg.apply.done'                  = "Mode: {0}`r`nApplied {1} policies, cleared {2}.`r`n`r`nRestart Brave to see changes.`r`nVerify at: brave://policy"
    'msg.braveMissing'                = 'Brave not found on this machine.'
    'msg.config.badJson'              = 'Bad JSON: {0}'
    'msg.config.imported'             = "Config loaded into checkboxes.`r`nClick 'Apply to Brave' (and the Hosts tab if needed) to commit."
    'msg.failed'                      = 'Failed: {0}'
    'msg.hosts.applied'               = "Hosts file updated. {0} domain(s) blocked.`r`nDNS cache flushed."
    'msg.hosts.confirmApply'          = "About to add {0} entries to:`r`n{1}`r`n`r`nA timestamped backup will be saved first. Continue?"
    'msg.hosts.confirmRemove'         = "Remove the Brave-Free-Origin sentinel block from hosts?`r`n(Your other hosts entries are not touched.)"
    'msg.hosts.noGroups'              = 'No groups ticked. This will remove the existing hosts block (if any). Continue?'
    'msg.hosts.removed'               = 'Sentinel block removed.'
    'msg.language.switched'           = 'Language switched to {0}.'
    'msg.restore.confirm'             = "This will restore stock behavior for: {0}`r`n`r`nIt removes Brave policy keys, clears the Brave-Free-Origin hosts block, re-enables known Brave update tasks, and resets known disabled Brave services to Manual.`r`n`r`nContinue?"
    'msg.restore.done'                = 'Full restore completed. Restart Brave to see stock behavior.'
    'msg.scriptlet.backupDone'        = 'Backups checked/created for {0} list file(s).'
    'msg.scriptlet.backupFailed'      = "Backup failed:`r`n{0}"
    'msg.scriptlet.braveRunning'      = "Brave is currently running ({0} process(es)).`r`n`r`nClose Brave first if you want the safest patch. Continue anyway?"
    'msg.scriptlet.confirmDisable'    = "Disable {0} checked/selected scriptlet rule(s)?`r`n`r`nThis comments rules with: {1}`r`nBackups are created as list.txt.bfo-backup before the first edit."
    'msg.scriptlet.confirmReapply'    = "Reapply disabled scriptlet preferences to the current component lists under:`r`n{0}`r`n`r`nThis comments active rules whose raw text matches the preference file. Continue?"
    'msg.scriptlet.confirmRestoreAll' = "Restore every list.txt.bfo-backup under:`r`n{0}`r`n`r`nThis discards all BFO scriptlet edits in backed-up lists. Continue?"
    'msg.scriptlet.confirmRestoreSel' = "Restore {0} selected list file(s) from .bfo-backup?`r`nThis discards BFO scriptlet edits in those file(s)."
    'msg.scriptlet.disableFailed'     = "Disable failed:`r`n{0}"
    'msg.scriptlet.enableFailed'      = "Enable failed:`r`n{0}"
    'msg.scriptlet.exportFailed'      = "Export failed:`r`n{0}"
    'msg.scriptlet.folderMissing'     = 'Folder not found. Use Browse to choose the correct Brave User Data folder.'
    'msg.scriptlet.locked'            = "Editing Brave's internal filter-list files is disabled.`r`n`r`nTick 'Advanced edit mode' in the Scriptlets tab first."
    'msg.scriptlet.noFiles'           = "No Brave filter-list files were found in:`r`n{0}`r`n`r`nUse Browse if your Brave User Data folder lives somewhere else."
    'msg.scriptlet.noRules'           = "No Brave scriptlet rules were found in:`r`n{0}`r`n`r`nUse Browse if your Brave User Data folder lives somewhere else."
    'msg.scriptlet.noRulesLoaded'     = 'Scan first; there are no scriptlet rules loaded.'
    'msg.scriptlet.nothingVisible'    = 'Nothing visible to export. Scan or change the filter first.'
    'msg.scriptlet.reapplyFailed'     = "Reapply failed:`r`n{0}"
    'msg.scriptlet.restoreAllFailed'  = "Restore all failed:`r`n{0}"
    'msg.scriptlet.restoreFailed'     = "Restore failed:`r`n{0}"
    'msg.scriptlet.restoreSelectFile' = 'Select a rule from the file you want to restore.'
    'msg.scriptlet.scanFailed'        = "Could not scan scriptlets:`r`n{0}`r`n`r`nUse Browse to point Brave-Free-Origin at the correct Brave User Data folder."
    'msg.scriptlet.scanFirst'         = 'Scan first; no scriptlet list files are loaded.'
    'msg.scriptlet.selectFirst'       = 'Check or select one or more scriptlet rules first.'
    'msg.scriptlet.selectOne'         = 'Select a scriptlet rule first.'
    'msg.title.app'                   = 'Brave Free Origin'
    'msg.title.done'                  = 'Done'
    'msg.title.error'                 = 'Error'
    'msg.title.fullRestore'           = 'Full restore / stock'
    'msg.title.hosts'                 = 'Hosts blocklist'
    'msg.title.importError'           = 'Import error'
    'msg.title.imported'              = 'Imported'
    'msg.title.info'                  = 'Info'
    'msg.title.scriptlet'             = 'Scriptlet manager'
}

#endregion

#region Configuration filter --------------------------------------------------
# One index over every configurable row in the app (policies, scheduled tasks,
# Windows services, hosts groups). The Scriptlets tab keeps its own dedicated
# scanner/filter - it deals with thousands of records and is already tuned.
#
# Rows are absolutely positioned, so filtering also re-flows each tab: hidden
# rows collapse instead of leaving holes.
$script:ConfigFilterItems = New-Object System.Collections.ArrayList
$script:TabFlows          = @{}
$script:RowDescLabels     = New-Object System.Collections.ArrayList
$script:FilterDebounce    = $null
$script:FilterReady       = $false

# One flow record per tab, created by whichever call reaches the tab first.
# That is deliberately not always Register-FlowEntry: a tab sets its title key
# while it is being built, before it has any rows.
function Get-TabFlow {
    param($TabPage, [int]$BaseTop = 0)
    $key = $TabPage.Name
    if (-not $script:TabFlows.ContainsKey($key)) {
        $script:TabFlows[$key] = [pscustomobject]@{
            TabPage  = $TabPage
            Top      = $BaseTop
            TitleKey = $null
            Entries  = (New-Object System.Collections.ArrayList)
        }
    }
    return $script:TabFlows[$key]
}

function Register-FlowEntry {
    param(
        $TabPage,
        [ValidateSet('Row', 'Header', 'Trailer')][string]$Kind,
        $Controls,
        [int]$BaseTop,
        [int]$Height,
        [int]$CjkExtra = 0,
        [string]$Group = 'default',
        [string]$Id,
        [string]$Type,
        [string]$CategoryId,
        [scriptblock]$SearchText,
        [scriptblock]$IsSelected
    )
    $flow = Get-TabFlow -TabPage $TabPage -BaseTop $BaseTop
    # The first entry registered defines where the tab's flow starts, whether
    # or not the record already existed.
    if ($flow.Entries.Count -eq 0) { $flow.Top = $BaseTop }
    $offsets = @()
    foreach ($c in $Controls) { $offsets += ($c.Top - $BaseTop) }

    $entry = [pscustomobject]@{
        Kind = $Kind; Controls = $Controls; Offsets = $offsets
        Height = $Height; CjkExtra = $CjkExtra; Group = $Group
        Id = $Id; Type = $Type; CategoryId = $CategoryId
        SearchText = $SearchText; IsSelected = $IsSelected
        Visible = $true
    }
    [void]$flow.Entries.Add($entry)
    if ($Kind -eq 'Row') { [void]$script:ConfigFilterItems.Add($entry) }
    # No return value on purpose: call sites are statements at script scope,
    # and emitting the object would print it to the console the .bat opened.
}

# Called while the tab is still being built, so the flow record has to be
# created on demand here - looking it up and giving up when absent silently
# dropped every title key, and the per-tab match count never appeared.
function Set-FlowTabTitleKey {
    param($TabPage, [string]$Key)
    (Get-TabFlow -TabPage $TabPage).TitleKey = $Key
}

function Start-FilterDebounce {
    if (-not $script:FilterDebounce) {
        $script:FilterDebounce = New-Object System.Windows.Forms.Timer
        $script:FilterDebounce.Interval = 180
        $script:FilterDebounce.Add_Tick({
            $script:FilterDebounce.Stop()
            Update-ConfigurationFilter
        })
    }
    $script:FilterDebounce.Stop()
    $script:FilterDebounce.Start()
}

function Update-ConfigurationFilter {
    if (-not $script:FilterReady) { return }
    if (-not $script:TxtConfigFilter) { return }

    $query        = "$($script:TxtConfigFilter.Text)".Trim()
    $selectedOnly = [bool]$script:ChkSelectedOnly.Checked
    $terms        = @($query -split '\s+' | Where-Object { $_ })
    $filtering    = ($terms.Count -gt 0 -or $selectedOnly)
    $cjk          = ($script:CurrentLocale -like 'zh-*')

    $totalRows = 0
    $shownRows = 0
    $firstMatchTab = $null

    foreach ($key in @($script:TabFlows.Keys)) {
        $flow = $script:TabFlows[$key]

        # Pass 1 - decide row visibility.
        $groupHasVisible = @{}
        foreach ($entry in $flow.Entries) {
            if ($entry.Kind -ne 'Row') { continue }
            $totalRows++
            $visible = $true
            if ($selectedOnly) {
                try { $visible = [bool](& $entry.IsSelected) } catch { $visible = $true }
            }
            if ($visible -and $terms.Count -gt 0) {
                $hay = ''
                try { $hay = "$(& $entry.SearchText)" } catch { $hay = '' }
                foreach ($t in $terms) {
                    if ($hay -notmatch [regex]::Escape($t)) { $visible = $false; break }
                }
            }
            $entry.Visible = $visible
            if ($visible) {
                $shownRows++
                $groupHasVisible[$entry.Group] = $true
            }
        }

        # Pass 2 - headers follow their group, trailers always stay.
        foreach ($entry in $flow.Entries) {
            if ($entry.Kind -eq 'Header')  { $entry.Visible = [bool]$groupHasVisible[$entry.Group] }
            if ($entry.Kind -eq 'Trailer') { $entry.Visible = $true }
        }

        # Pass 3 - re-flow.
        $tabVisibleRows = 0
        $y = $flow.Top
        $flow.TabPage.SuspendLayout()
        foreach ($entry in $flow.Entries) {
            if (-not $entry.Visible) {
                foreach ($c in $entry.Controls) { $c.Visible = $false }
                continue
            }
            for ($i = 0; $i -lt $entry.Controls.Count; $i++) {
                $c = $entry.Controls[$i]
                $c.Top = $y + $entry.Offsets[$i]
                $c.Visible = $true
            }
            $y += $entry.Height
            if ($cjk) { $y += $entry.CjkExtra }
            if ($entry.Kind -eq 'Row') { $tabVisibleRows++ }
        }
        $flow.TabPage.ResumeLayout()

        # Tab caption gets a live match count while filtering.
        if ($flow.TitleKey) {
            if ($filtering) {
                $flow.TabPage.Text = T 'filter.tabCount' @((T $flow.TitleKey), $tabVisibleRows)
            } else {
                $flow.TabPage.Text = T $flow.TitleKey
            }
        }
        if ($filtering -and $tabVisibleRows -gt 0 -and -not $firstMatchTab) { $firstMatchTab = $flow.TabPage }
    }

    if ($script:LblFilterCount) {
        if ($shownRows -eq 0 -and $filtering) {
            $script:LblFilterCount.Text = T 'filter.noMatches'
        } else {
            $script:LblFilterCount.Text = T 'filter.matches' @($shownRows, $totalRows)
        }
    }

    # Jump to the first tab that actually has a hit, but never fight the user
    # while they are reading a tab that already matches.
    if ($filtering -and $firstMatchTab -and $script:Tabs) {
        # SelectedTab can legitimately be $null (no tab selected yet, or the
        # control has no handle), and indexing a hashtable with $null is a
        # terminating error - which would abort the whole filter pass.
        $currentTab  = $script:Tabs.SelectedTab
        $currentFlow = $null
        if ($currentTab -and $currentTab.Name) { $currentFlow = $script:TabFlows[$currentTab.Name] }
        $currentHasHit = $false
        if ($currentFlow) {
            foreach ($e in $currentFlow.Entries) {
                if ($e.Kind -eq 'Row' -and $e.Visible) { $currentHasHit = $true; break }
            }
        }
        if (-not $currentHasHit) { $script:Tabs.SelectedTab = $firstMatchTab }
    }
}

function Clear-ConfigurationFilter {
    $script:TxtConfigFilter.Text = ''
    $script:ChkSelectedOnly.Checked = $false
    Update-ConfigurationFilter
}

# Description labels are re-measured on language switch: CJK needs a larger
# point size and more vertical room than the 8pt English default.
#
# The height is ASSIGNED, never max()'d against the current value. Growing
# monotonically looked fine going en -> zh, then left 34px labels inside 28px
# rows on the way back, so consecutive descriptions overlapped. The active
# locale alone decides the geometry, every time, in both directions.
function Update-LocalizedRowText {
    $size = Get-PolicyDescFontSize
    $h    = Get-PolicyDescHeight
    foreach ($lbl in $script:RowDescLabels) {
        try {
            $lbl.Font   = Get-BfoUiFont -Size $size
            $lbl.Height = $h
        } catch { }
    }
}
#endregion


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
$script:ScriptletUserDataRoots = [ordered]@{
    'Stable'  = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
    'Beta'    = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser-Beta\User Data"
    'Nightly' = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser-Nightly\User Data"
    'Dev'     = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser-Dev\User Data"
}
$script:ScriptletDisablePrefix = '! BFO disabled: '
$script:ScriptletRules = @()
$script:ScriptletVisibleRules = @()
$script:ScriptletScanState = $null
$script:ScriptletScanTimer = $null
$script:ScriptletRenderState = $null
$script:ScriptletRenderTimer = $null
$script:ScriptletFilterTimer = $null
$script:ScriptletCheckedKeys = @{}
$script:SuppressScriptletStatusEvents = $false
$script:ScriptletComponentNames = @{
    'iodkpdagapdfkphljnddpjlldadblomo' = 'uBlock filters'
    'adcocjohghhfpidemphmcmlmhnfgikei' = 'Brave Firstparty specific filters'
    'cdbbhgbmjhfnhnmgeddbliobbofkgdhe' = 'EasyList Cookie'
    'kihnoaefogbkmblfimmibknnmkllbhlf' = 'EasyPrivacy'
    'flnkmpokemfpaajmiimmjeiandgoodgg' = 'AdGuard French'
}

function Get-DetectedChannels {
    $found = @()
    foreach ($name in $script:Channels.Keys) {
        foreach ($probe in $script:Channels[$name].InstallProbes) {
            if (Test-Path $probe) { $found += $name; break }
        }
    }
    return $found
}

#region Policy Data -----------------------------------------------------------
# Each policy: Name (registry value name, never translated), Type (DWORD/STRING),
#              ApplyValue (what to write when ticked), Recommended, MaxPrivacy.
# Human-readable text lives in the string catalog under 'policy.<Name>.description'
# so it can be localized without ever touching the technical identifiers.
$script:Policies = [ordered]@{
    'braveFeatures' = @(
        @{Name='HardwareAccelerationModeEnabled'; Type='DWORD'; ApplyValue=1; Recommended=$true;  MaxPrivacy=$true;  Choices=([ordered]@{'enable'=1; 'disable'=0})},
        @{Name='BraveRewardsDisabled';         Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveWalletDisabled';          Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveVPNDisabled';             Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveAIChatEnabled';           Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveNewsDisabled';            Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveTalkDisabled';            Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveWaybackMachineEnabled';   Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true},
        @{Name='BravePlaylistEnabled';         Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='BraveSpeedreaderEnabled';      Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='TorDisabled';                  Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$false},
        @{Name='IPFSEnabled';                  Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='WebTorrentDisabled';           Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true}
    )
    'privacyTelemetry' = @(
        @{Name='BraveP3AEnabled';                             Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveStatsPingEnabled';                       Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveWebDiscoveryEnabled';                    Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='MetricsReportingEnabled';                     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveGlobalPrivacyControlEnabled';            Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveReduceLanguageEnabled';                  Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveTrackingQueryParametersFilteringEnabled';Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveDeAmpEnabled';                           Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveDebouncingEnabled';                      Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='DefaultBraveFingerprintingV2Setting';         Type='DWORD';  ApplyValue=3; Recommended=$true;  MaxPrivacy=$true},
        @{Name='DefaultBraveAdblockSetting';                  Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='DefaultBraveHttpsUpgradeSetting';             Type='DWORD';  ApplyValue=2; Recommended=$false; MaxPrivacy=$true},
        @{Name='DefaultBraveReferrersSetting';                Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='DefaultBraveRemember1PStorageSetting';        Type='DWORD';  ApplyValue=2; Recommended=$false; MaxPrivacy=$true},
        @{Name='ChromeVariations';                            Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='CloudReportingEnabled';                       Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='UserFeedbackAllowed';                         Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true}
    )
    'autofillPasswords' = @(
        @{Name='PasswordManagerEnabled';        Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='PasswordLeakDetectionEnabled';  Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='AutofillAddressEnabled';        Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='AutofillCreditCardEnabled';     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='PaymentMethodQueryEnabled';     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='AutoplayAllowed';               Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true}
    )
    'searchSuggestions' = @(
        @{Name='SearchSuggestEnabled';                        Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='UrlKeyedAnonymizedDataCollectionEnabled';     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='SpellCheckServiceEnabled';                    Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='SpellcheckEnabled';                           Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='TranslateEnabled';                            Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='AlternateErrorPagesEnabled';                  Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true}
    )
    'safetyUpdates' = @(
        @{Name='SafeBrowsingProtectionLevel';         Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$false},
        @{Name='SafeBrowsingExtendedReportingEnabled';Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='SafeBrowsingDeepScanningEnabled';     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='SafeBrowsingSurveysEnabled';          Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ComponentUpdatesEnabled';             Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='DefaultBrowserSettingEnabled';        Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ChromeCleanupEnabled';                Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ChromeCleanupReportingEnabled';       Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true}
    )
    'aiGenAi' = @(
        @{Name='GenAiDefaultSettings';      Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='HelpMeWriteSettings';       Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='TabOrganizerSettings';      Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='CreateThemesSettings';      Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='HistorySearchSettings';     Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='DevToolsGenAiSettings';     Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true}
    )
    'webServicesBackground' = @(
        @{Name='BackgroundModeEnabled';           Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='NetworkPredictionOptions';        Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='CloudPrintSubmitEnabled';         Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BuiltInDnsClientEnabled';         Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='DnsOverHttpsMode';                Type='STRING'; ApplyValue='automatic'; Recommended=$true;  MaxPrivacy=$true},
        @{Name='WebRtcEventLogCollectionAllowed'; Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='SyncDisabled';                    Type='DWORD';  ApplyValue=1; Recommended=$false; MaxPrivacy=$true},
        @{Name='SigninAllowed';                   Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true},
        @{Name='BrowserSignin';                   Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true},
        @{Name='PromotionalTabsEnabled';          Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='WelcomePageOnOSUpgradeEnabled';   Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ImportAutofillFormData';          Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ImportBookmarks';                 Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true},
        @{Name='ImportHistory';                   Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ImportSavedPasswords';            Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ImportSearchEngine';              Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true}
    )
    'performanceStartup' = @(
        @{Name='QuicAllowed';                     Type='DWORD';  ApplyValue=1;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='HighEfficiencyModeEnabled';       Type='DWORD';  ApplyValue=1;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='BatterySaverModeAvailability';    Type='DWORD';  ApplyValue=2;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='MediaRouterEnabled';              Type='DWORD';  ApplyValue=0;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='DiskCacheSize';                   Type='DWORD';  ApplyValue=262144000;  Recommended=$true;  MaxPrivacy=$false},
        @{Name='BrowserLabsEnabled';              Type='DWORD';  ApplyValue=0;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='RestoreOnStartup';                Type='DWORD';  ApplyValue=5;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='HomepageIsNewTabPage';            Type='DWORD';  ApplyValue=0;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='HomepageLocation';                Type='STRING'; ApplyValue='about:blank'; Recommended=$true;  MaxPrivacy=$true},
        @{Name='NewTabPageLocation';              Type='STRING'; ApplyValue='about:blank'; Recommended=$false; MaxPrivacy=$true},
        @{Name='NTPCustomBackgroundEnabled';      Type='DWORD';  ApplyValue=0;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='ShowHomeButton';                  Type='DWORD';  ApplyValue=0;          Recommended=$false; MaxPrivacy=$false}
    )
    'uiBloatExtras' = @(
        @{Name='LiveCaptionEnabled';              Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='AccessibilityImageLabelsEnabled'; Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='LensDesktopNTPSearchEnabled';     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='LensRegionSearchEnabled';         Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='LensOverlaySettings';             Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ReadingListEnabled';              Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='PromptForDownloadLocation';       Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='BookmarkBarEnabled';              Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false}
    )
}

# Task / service descriptions live under task.<Name>.description and
# service.<Name>.description in the string catalog.
$script:ScheduledTasks = @(
    @{Name='BraveSoftwareUpdateTaskMachineCore'},
    @{Name='BraveSoftwareUpdateTaskMachineUA'}
)

$script:Services = @(
    @{Name='brave'},
    @{Name='bravem'},
    @{Name='BraveElevationService'},
    @{Name='BraveVPNService'},
    @{Name='BraveVpnWireguardService'}
)

# ---- Hosts blocklist groups (v1.5, ID-keyed since v1.12) --------------------
# DNS-level kill switch via the Windows hosts file. Conservative on purpose -
# only the safest groups are pre-ticked. Id is the stable key used by presets
# and by exported configs; the visible name is a translatable string.
$script:HostsBlocks = @(
    @{Id='p3a'; NameKey='hosts.p3a.name'; DescriptionKey='hosts.p3a.description'; Recommended=$true; Domains=@('p3a.brave.com', 'p3a-creative.brave.com', 'p2a.brave.com', 'p2a-creative.brave.com')},
    @{Id='variations'; NameKey='hosts.variations.name'; DescriptionKey='hosts.variations.description'; Recommended=$true; Domains=@('variations.brave.com', 'go-updater.brave.com')},
    @{Id='stats'; NameKey='hosts.stats.name'; DescriptionKey='hosts.stats.description'; Recommended=$true; Domains=@('laptop-updates.brave.com')},
    @{Id='rewards'; NameKey='hosts.rewards.name'; DescriptionKey='hosts.rewards.description'; Recommended=$false; Domains=@('rewards.brave.com', 'grant.rewards.brave.com', 'creators.brave.com')},
    @{Id='news'; NameKey='hosts.news.name'; DescriptionKey='hosts.news.description'; Recommended=$false; Domains=@('brave-today-cdn.brave.com', 'brave-today.brave.com')},
    @{Id='components'; NameKey='hosts.components.name'; DescriptionKey='hosts.components.description'; Recommended=$false; Domains=@('componentupdater.brave.com', 'brave-core-ext.s3.brave.com')},
    @{Id='webDiscovery'; NameKey='hosts.webDiscovery.name'; DescriptionKey='hosts.webDiscovery.description'; Recommended=$false; Domains=@('search.anonymous.brave.com', 'wdp.brave.com')}
)
$script:HostsSentinelStart = '# === Brave-Free-Origin START - managed block, do not edit between sentinels ==='
$script:HostsSentinelEnd   = '# === Brave-Free-Origin END ==='
$script:HostsFile = "$env:WINDIR\System32\drivers\etc\hosts"

# ---- Search engines (v1.6, ID-keyed since v1.12) ---------------------------
# {searchTerms} is the standard Chromium placeholder Brave fills in.
# Brand names are NOT translated; only the "Custom..." entry has a real label.
$script:SearchEngines = [ordered]@{
    'brave'       = @{ LabelKey='engine.brave'; ProviderName='Brave Search'; URL='https://search.brave.com/search?q={searchTerms}';     Suggest='https://search.brave.com/api/suggest?q={searchTerms}';                       Keyword='brave';     Home='https://search.brave.com' }
    'duckduckgo'  = @{ LabelKey='engine.duckduckgo'; ProviderName='DuckDuckGo'; URL='https://duckduckgo.com/?q={searchTerms}';             Suggest='https://duckduckgo.com/ac/?q={searchTerms}&type=list';                      Keyword='ddg';       Home='https://duckduckgo.com' }
    'startpage'   = @{ LabelKey='engine.startpage'; ProviderName='Startpage'; URL='https://www.startpage.com/do/search?q={searchTerms}';  Suggest='';                                                                          Keyword='startpage'; Home='https://www.startpage.com' }
    'qwant'       = @{ LabelKey='engine.qwant'; ProviderName='Qwant'; URL='https://www.qwant.com/?q={searchTerms}';               Suggest='https://api.qwant.com/api/suggest?q={searchTerms}';                         Keyword='qwant';     Home='https://www.qwant.com' }
    'ecosia'      = @{ LabelKey='engine.ecosia'; ProviderName='Ecosia'; URL='https://www.ecosia.org/search?q={searchTerms}';        Suggest='https://ac.ecosia.org/?q={searchTerms}';                                    Keyword='ecosia';    Home='https://www.ecosia.org' }
    'mojeek'      = @{ LabelKey='engine.mojeek'; ProviderName='Mojeek'; URL='https://www.mojeek.com/search?q={searchTerms}';        Suggest='';                                                                          Keyword='mojeek';    Home='https://www.mojeek.com' }
    'kagi'        = @{ LabelKey='engine.kagi'; ProviderName='Kagi (paid)'; URL='https://kagi.com/search?q={searchTerms}';              Suggest='https://kagi.com/api/autosuggest?q={searchTerms}';                          Keyword='kagi';      Home='https://kagi.com' }
    'google'      = @{ LabelKey='engine.google'; ProviderName='Google'; URL='https://www.google.com/search?q={searchTerms}';        Suggest='https://www.google.com/complete/search?output=chrome&q={searchTerms}';     Keyword='google';    Home='https://www.google.com' }
    'bing'        = @{ LabelKey='engine.bing'; ProviderName='Bing'; URL='https://www.bing.com/search?q={searchTerms}';          Suggest='https://www.bing.com/osjson.aspx?query={searchTerms}';                      Keyword='bing';      Home='https://www.bing.com' }
    'yandex'      = @{ LabelKey='engine.yandex'; ProviderName='Yandex'; URL='https://yandex.com/search/?text={searchTerms}';        Suggest='https://suggest.yandex.com/suggest-ff.cgi?part={searchTerms}';             Keyword='yandex';    Home='https://yandex.com' }
    'custom'      = @{ LabelKey='engine.custom'; ProviderName='Custom...'; URL='';                                                     Suggest='';                                                                          Keyword='custom';    Home='';                                IsCustom=$true }
}

# Destination presets for "new tab" and "startup specific page" dropdowns.
# '__SEARCH__' resolves at apply-time to the chosen engine's home URL.
$script:DestinationOptions = [ordered]@{
    'blank'           = @{ LabelKey='destination.blank'; Value='about:blank' }
    'ntpDefault'      = @{ LabelKey='destination.ntpDefault'; Value='__SKIP__' }
    'matchSearch'     = @{ LabelKey='destination.matchSearch'; Value='__SEARCH__' }
    'braveSearchHome' = @{ LabelKey='destination.braveSearchHome'; Value='https://search.brave.com' }
    'duckduckgoHome'  = @{ LabelKey='destination.duckduckgoHome'; Value='https://duckduckgo.com' }
    'googleHome'      = @{ LabelKey='destination.googleHome'; Value='https://www.google.com' }
    'custom'          = @{ LabelKey='destination.custom'; Value='__CUSTOM__' }
}

# Startup behavior modes (RestoreOnStartup policy values).
$script:StartupModes = [ordered]@{
    'newTab'          = @{ LabelKey='startupMode.newTab'; Code=5; UsesURL=$false }
    'restoreSession'  = @{ LabelKey='startupMode.restoreSession'; Code=1; UsesURL=$false }
    'blankPage'       = @{ LabelKey='startupMode.blankPage'; Code=4; UsesURL=$true; FixedURL='about:blank' }
    'specificPages'   = @{ LabelKey='startupMode.specificPages'; Code=4; UsesURL=$true; FixedURL=$null }
}

# ---- Stable id arrays that back the ComboBoxes -----------------------------
# Item order in each ComboBox matches the order of these arrays; the link is
# SelectedIndex, which is the one binding WinForms guarantees for a
# non-data-bound ComboBox and which survives re-translation intact.
$script:SearchEngineIds       = @($script:SearchEngines.Keys)
$script:SearchEngineLabelKeys = @($script:SearchEngineIds | ForEach-Object { $script:SearchEngines[$_].LabelKey })
# 'ntpDefault' stays in the data model for Load current state matching but is
# never offered in the new-tab dropdown (parity with v1.11).
$script:DestinationIds        = @($script:DestinationOptions.Keys | Where-Object { $_ -ne 'ntpDefault' })
$script:DestinationLabelKeys  = @($script:DestinationIds | ForEach-Object { $script:DestinationOptions[$_].LabelKey })
$script:StartupModeIds        = @($script:StartupModes.Keys)
$script:StartupModeLabelKeys  = @($script:StartupModeIds | ForEach-Object { $script:StartupModes[$_].LabelKey })

# Legacy config migration: v1.5-v1.11 exports stored the English display
# label. Importing those must keep working.
$script:LegacyHostsIds = @{
    'Brave P3A telemetry' = 'p3a'
    'Brave Variations' = 'variations'
    'Brave Stats ping' = 'stats'
    'Brave Rewards / BAT' = 'rewards'
    'Brave News CDN' = 'news'
    'Component Updates' = 'components'
    'Web Discovery' = 'webDiscovery'
}
$script:LegacySearchEngineIds = @{
    'Brave Search' = 'brave'
    'DuckDuckGo' = 'duckduckgo'
    'Startpage' = 'startpage'
    'Qwant' = 'qwant'
    'Ecosia' = 'ecosia'
    'Mojeek' = 'mojeek'
    'Kagi (paid)' = 'kagi'
    'Google' = 'google'
    'Bing' = 'bing'
    'Yandex' = 'yandex'
    'Custom...' = 'custom'
}
$script:LegacyDestinationIds = @{
    'Blank page (about:blank)' = 'blank'
    'Default new tab page (do not override)' = 'ntpDefault'
    'Match the search engine I picked above' = 'matchSearch'
    'Brave Search homepage' = 'braveSearchHome'
    'DuckDuckGo homepage' = 'duckduckgoHome'
    'Google homepage' = 'googleHome'
    'Custom URL...' = 'custom'
}
$script:LegacyStartupModeIds = @{
    'Open the new tab page' = 'newTab'
    'Restore my last session' = 'restoreSession'
    'Open a blank page' = 'blankPage'
    'Open a specific page or set' = 'specificPages'
}
#endregion

#region Helpers ---------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts = Get-Date -Format 'HH:mm:ss'
    $line = "[$ts] [$Level] $Message"
    if ($script:LogBox) {
        $script:LogBox.AppendText("$line`r`n")
        $script:LogBox.SelectionStart = $script:LogBox.Text.Length
        $script:LogBox.ScrollToCaret()
    }
}

function Get-ExistingPolicy {
    param([string]$Name)
    try {
        $v = Get-ItemProperty -Path $script:BravePolicyPath -Name $Name -ErrorAction Stop
        return $v.$Name
    } catch { return $null }
}

function Set-PolicyValue {
    param([string]$Name, [string]$Type, $Value)
    if (-not (Test-Path $script:BravePolicyPath)) {
        New-Item -Path $script:BravePolicyPath -Force | Out-Null
    }
    $regType = if ($Type -eq 'DWORD') { 'DWord' } else { 'String' }
    New-ItemProperty -Path $script:BravePolicyPath -Name $Name -Value $Value -PropertyType $regType -Force | Out-Null
}

function Remove-PolicyValue {
    param([string]$Name)
    try {
        Remove-ItemProperty -Path $script:BravePolicyPath -Name $Name -ErrorAction Stop
        return $true
    } catch { return $false }
}

function Export-Backup {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dir = Join-Path $env:USERPROFILE 'Documents\Brave-Free-Origin-Backups'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $file = Join-Path $dir "brave-policies-backup-$stamp.reg"
    $regKey = 'HKLM\Software\Policies\BraveSoftware'
    $result = & reg.exe EXPORT $regKey $file /y 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Backup saved: $file" 'OK'
        return $file
    } else {
        Write-Log "Backup skipped (no existing policies)." 'INFO'
        return $null
    }
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

# ---- Hosts file helpers (v1.5) ----------------------------------------------
function Backup-HostsFile {
    if (-not (Test-Path $script:HostsFile)) { return $null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dir = Join-Path $env:USERPROFILE 'Documents\Brave-Free-Origin-Backups'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $file = Join-Path $dir "hosts-backup-$stamp.bak"
    Copy-Item $script:HostsFile $file -Force
    Write-Log "Hosts backup saved: $file" 'OK'
    return $file
}

function Get-HostsCurrentDomains {
    if (-not (Test-Path $script:HostsFile)) { return @() }
    $lines = Get-Content $script:HostsFile -ErrorAction SilentlyContinue
    $inBlock = $false
    $domains = @()
    foreach ($line in $lines) {
        if ($line -eq $script:HostsSentinelStart) { $inBlock = $true; continue }
        if ($line -eq $script:HostsSentinelEnd)   { $inBlock = $false; continue }
        if ($inBlock -and $line -match '^\s*0\.0\.0\.0\s+(\S+)') {
            $domains += $Matches[1]
        }
    }
    return $domains
}

function Set-HostsBlockDomains {
    param([string[]]$Domains)
    [void](Backup-HostsFile)

    # Read all lines, strip out our existing sentinel block (if any)
    $lines = if (Test-Path $script:HostsFile) { Get-Content $script:HostsFile } else { @() }
    $kept = New-Object System.Collections.ArrayList
    $skipping = $false
    foreach ($line in $lines) {
        if ($line -eq $script:HostsSentinelStart) { $skipping = $true; continue }
        if ($line -eq $script:HostsSentinelEnd)   { $skipping = $false; continue }
        if (-not $skipping) { [void]$kept.Add($line) }
    }

    # Trim trailing blank lines from existing content for tidiness
    while ($kept.Count -gt 0 -and [string]::IsNullOrWhiteSpace($kept[$kept.Count - 1])) {
        $kept.RemoveAt($kept.Count - 1)
    }

    if ($Domains -and $Domains.Count -gt 0) {
        [void]$kept.Add('')
        [void]$kept.Add($script:HostsSentinelStart)
        [void]$kept.Add("# Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') by Brave Free Origin. Remove via the GUI.")
        foreach ($d in ($Domains | Sort-Object -Unique)) {
            [void]$kept.Add("0.0.0.0 $d")
        }
        [void]$kept.Add($script:HostsSentinelEnd)
    }

    # ASCII encoding - matches what Windows expects for hosts. Some AVs flag UTF-16 hosts.
    Set-Content -Path $script:HostsFile -Value $kept -Encoding ASCII -Force

    # Flush DNS so the change takes effect immediately for new connections
    & ipconfig.exe /flushdns | Out-Null
    Write-Log "Hosts block written: $($Domains.Count) domain(s). DNS cache flushed." 'OK'
}

function Clear-HostsBlock {
    Set-HostsBlockDomains -Domains @()
    Write-Log 'Hosts sentinel block removed.' 'OK'
}
# -----------------------------------------------------------------------------

function Get-BraveVersion {
    $exe = Test-BraveInstalled
    if ($exe) {
        try { return (Get-Item $exe).VersionInfo.FileVersion } catch { return 'unknown' }
    }
    return 'not installed'
}

function Show-TextReport {
    param(
        [string]$Title,
        [string]$Text,
        [string]$DefaultFileName = 'brave-free-origin-report.txt'
    )

    $rf = New-Object System.Windows.Forms.Form
    $rf.Text = $Title
    $rf.Size = New-Object System.Drawing.Size(760, 560)
    $rf.StartPosition = 'CenterParent'
    $rf.MinimumSize = New-Object System.Drawing.Size(620, 420)

    $buttons = New-Object System.Windows.Forms.Panel
    $buttons.Dock = 'Bottom'
    $buttons.Height = 44
    $rf.Controls.Add($buttons)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true
    $tb.ReadOnly = $true
    $tb.ScrollBars = 'Both'
    $tb.WordWrap = $false
    $tb.Font = New-Object System.Drawing.Font('Consolas', 9)
    $tb.Dock = 'Fill'
    $tb.Text = $Text
    $rf.Controls.Add($tb)

    $copy = New-Object System.Windows.Forms.Button
    $copy.Text = T 'report.copy'
    $copy.Size = New-Object System.Drawing.Size(90, 28)
    $copy.Location = New-Object System.Drawing.Point(10, 8)
    $copy.Add_Click({
        # Clipboard.SetText throws on an empty string.
        if ($tb.Text) { [System.Windows.Forms.Clipboard]::SetText($tb.Text) }
    })
    $buttons.Controls.Add($copy)

    $save = New-Object System.Windows.Forms.Button
    $save.Text = T 'report.save'
    $save.Size = New-Object System.Drawing.Size(110, 28)
    $save.Location = New-Object System.Drawing.Point(110, 8)
    $save.Add_Click({
        $sfd = New-Object System.Windows.Forms.SaveFileDialog
        $sfd.Filter = '{0} (*.txt)|*.txt' -f (T 'dialog.filter.textReport')
        $sfd.FileName = $DefaultFileName
        $sfd.InitialDirectory = Join-Path $env:USERPROFILE 'Documents\Brave-Free-Origin-Backups'
        if (-not (Test-Path $sfd.InitialDirectory)) { New-Item -ItemType Directory -Path $sfd.InitialDirectory | Out-Null }
        if ($sfd.ShowDialog() -eq 'OK') {
            Set-Content -Path $sfd.FileName -Value $tb.Text -Encoding UTF8
            Write-Log "Report saved: $($sfd.FileName)" 'OK'
        }
    })
    $buttons.Controls.Add($save)

    $close = New-Object System.Windows.Forms.Button
    $close.Text = T 'report.close'
    $close.Size = New-Object System.Drawing.Size(90, 28)
    $close.Location = New-Object System.Drawing.Point(230, 8)
    $close.Add_Click({ $rf.Close() })
    $buttons.Controls.Add($close)

    $buttons.BringToFront()
    [void]$rf.ShowDialog()
}

# ---- ComboBox id plumbing ---------------------------------------------------
# Combo Items hold translated labels; the stable id lives in a parallel array
# and is linked by SelectedIndex. That is the one binding WinForms guarantees
# for a non-data-bound ComboBox, and it survives re-translation intact.
function Get-ComboId {
    param($Combo, $Ids)
    if (-not $Combo -or -not $Ids) { return $null }
    $i = $Combo.SelectedIndex
    if ($i -lt 0 -or $i -ge @($Ids).Count) { return $null }
    return @($Ids)[$i]
}

function Set-ComboId {
    param($Combo, $Ids, [string]$Id)
    if (-not $Combo -or -not $Ids -or -not $Id) { return $false }
    $arr = @($Ids)
    for ($i = 0; $i -lt $arr.Count; $i++) {
        if ($arr[$i] -eq $Id) { $Combo.SelectedIndex = $i; return $true }
    }
    return $false
}

# Relabelling is Items.Clear() + refill, which drives SelectedIndex to -1 and
# back. Both transitions raise SelectedIndexChanged, so the handlers are muted
# for the duration and the previously selected stable id is restored exactly.
function Set-ComboLabels {
    param($Combo, $Ids, $LabelKeys)
    if (-not $Combo) { return }
    $keep = Get-ComboId -Combo $Combo -Ids $Ids
    Push-SuppressSelectionEvents
    try {
        $Combo.BeginUpdate()
        try {
            $Combo.Items.Clear()
            foreach ($k in @($LabelKeys)) { [void]$Combo.Items.Add((T $k)) }
        } finally {
            $Combo.EndUpdate()
        }
        if (-not (Set-ComboId -Combo $Combo -Ids $Ids -Id $keep)) {
            if ($Combo.Items.Count -gt 0) { $Combo.SelectedIndex = 0 }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
}

# One place that knows how to move a choice policy to another option: it keeps
# the picker, the in-memory ApplyValue and therefore every downstream write
# (apply / preview / verify / export) in agreement, without depending on the
# ComboBox event firing - which is muted during import and load-state.
function Set-PolicyChoiceId {
    param($Policy, [string]$ChoiceId)
    if (-not $Policy -or -not $Policy.Choices -or [string]::IsNullOrWhiteSpace($ChoiceId)) { return $false }
    if (-not $Policy.Choices.Contains($ChoiceId)) { return $false }
    $Policy.ApplyValue = $Policy.Choices[$ChoiceId]
    $combo = $script:PolicyCombos[$Policy.Name]
    if ($combo) {
        [void](Set-ComboId -Combo $combo -Ids $script:PolicyChoiceIds[$Policy.Name] -Id $ChoiceId)
    }
    return $true
}

function Get-RegistryValueState {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path $Path)) {
        return [pscustomobject]@{ Exists = $false; Value = $null }
    }
    try {
        $props = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return [pscustomobject]@{ Exists = $true; Value = $props.PSObject.Properties[$Name].Value }
    } catch {
        return [pscustomobject]@{ Exists = $false; Value = $null }
    }
}

function Get-RegistryNumberedValues {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return @() }
    $props = Get-ItemProperty -Path $Path
    $items = @()
    foreach ($p in $props.PSObject.Properties) {
        if ($p.Name -match '^\d+$') {
            $items += [pscustomobject]@{ Index = [int]$p.Name; Value = $p.Value }
        }
    }
    return @($items | Sort-Object Index | ForEach-Object { $_.Value })
}

function Get-SelectedHostsDomains {
    $domains = @()
    if ($script:HostsCheckBoxes) {
        foreach ($cb in $script:HostsCheckBoxes) {
            if ($cb.Checked) { $domains += $cb.Tag.Domains }
        }
    }
    return @($domains | Sort-Object -Unique)
}

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

function Add-RegistryPlanLines {
    param(
        [System.Text.StringBuilder]$Report,
        [string]$Path,
        [System.Collections.IDictionary]$Desired,
        [string[]]$Names,
        [string]$Title
    )

    [void]$Report.AppendLine("  -- $Title")
    $changes = 0
    foreach ($name in $Names) {
        $state = Get-RegistryValueState -Path $Path -Name $name
        if ($Desired.Contains($name)) {
            $target = $Desired[$name].Value
            if (-not $state.Exists) {
                [void]$Report.AppendLine("     ADD    $name = $target")
                $changes++
            } elseif ("$($state.Value)" -eq "$target") {
                [void]$Report.AppendLine("     KEEP   $name = $target")
            } else {
                [void]$Report.AppendLine("     CHANGE $name : $($state.Value) -> $target")
                $changes++
            }
        } elseif ($state.Exists) {
            [void]$Report.AppendLine("     CLEAR  $name (currently $($state.Value))")
            $changes++
        }
    }
    if ($changes -eq 0) { [void]$Report.AppendLine('     No write needed.') }
}

function New-HostsPlanReport {
    $desired = @(Get-SelectedHostsDomains)
    $current = @(Get-HostsCurrentDomains)
    $toAdd = @($desired | Where-Object { $current -notcontains $_ })
    $toKeep = @($desired | Where-Object { $current -contains $_ })
    $toRemove = @($current | Where-Object { $desired -notcontains $_ })

    $report = New-Object System.Text.StringBuilder
    [void]$report.AppendLine('Brave Free Origin hosts preview')
    [void]$report.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$report.AppendLine("File: $($script:HostsFile)")
    [void]$report.AppendLine('')
    [void]$report.AppendLine("Selected groups: $(@($script:HostsCheckBoxes | Where-Object { $_.Checked }).Count)")
    [void]$report.AppendLine("Current managed domains: $($current.Count)")
    [void]$report.AppendLine("Desired managed domains: $($desired.Count)")
    [void]$report.AppendLine('')
    [void]$report.AppendLine("Add: $($toAdd.Count)")
    foreach ($d in $toAdd) { [void]$report.AppendLine("  + $d") }
    [void]$report.AppendLine("Keep: $($toKeep.Count)")
    foreach ($d in $toKeep) { [void]$report.AppendLine("  = $d") }
    [void]$report.AppendLine("Remove from managed block: $($toRemove.Count)")
    foreach ($d in $toRemove) { [void]$report.AppendLine("  - $d") }
    [void]$report.AppendLine('')
    [void]$report.AppendLine('No other hosts entries are touched. The GUI only replaces the Brave-Free-Origin sentinel block.')
    return $report.ToString()
}

function New-ApplyPlanReport {
    $report = New-Object System.Text.StringBuilder
    $modeKey = if ([string]::IsNullOrWhiteSpace($script:ActiveProfile)) { 'Custom' } else { $script:ActiveProfile }
    $modeLabel = Get-PresetNameEn $modeKey

    [void]$report.AppendLine('Brave Free Origin apply preview')
    [void]$report.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$report.AppendLine("Mode: $modeLabel")
    [void]$report.AppendLine("Target channel(s): $($script:TargetChannels -join ', ')")
    [void]$report.AppendLine("Backup before apply: $($chkBackup.Checked)")
    [void]$report.AppendLine('')
    [void]$report.AppendLine('This is a dry run. Nothing has been written.')
    [void]$report.AppendLine('')

    foreach ($channel in $script:TargetChannels) {
        $path = $script:Channels[$channel].Path
        [void]$report.AppendLine("=== $channel  ($path) ===")
        $adds = 0; $changes = 0; $clears = 0; $keeps = 0

        foreach ($cb in $script:CheckBoxes) {
            $p = $cb.Tag.Policy
            $state = Get-RegistryValueState -Path $path -Name $p.Name
            if ($cb.Checked) {
                if (-not $state.Exists) {
                    [void]$report.AppendLine("  ADD    $($p.Name) = $($p.ApplyValue)")
                    $adds++
                } elseif ("$($state.Value)" -eq "$($p.ApplyValue)") {
                    [void]$report.AppendLine("  KEEP   $($p.Name) = $($p.ApplyValue)")
                    $keeps++
                } else {
                    [void]$report.AppendLine("  CHANGE $($p.Name) : $($state.Value) -> $($p.ApplyValue)")
                    $changes++
                }
            } elseif ($state.Exists) {
                [void]$report.AppendLine("  CLEAR  $($p.Name) (currently $($state.Value))")
                $clears++
            }
        }
        [void]$report.AppendLine("  Summary: $adds add, $changes change, $clears clear, $keeps already correct")
        [void]$report.AppendLine('')

        try {
            $searchDesired = Get-DesiredSearchOverride
            Add-RegistryPlanLines -Report $report -Path $path -Desired $searchDesired -Names @(
                'DefaultSearchProviderEnabled',
                'DefaultSearchProviderName',
                'DefaultSearchProviderKeyword',
                'DefaultSearchProviderSearchURL',
                'DefaultSearchProviderSuggestURL'
            ) -Title 'Search override'
        } catch {
            [void]$report.AppendLine("  -- Search override")
            [void]$report.AppendLine("     ERROR: $_")
        }
        [void]$report.AppendLine('')

        try {
            $ntpDesired = Get-DesiredNtpOverride
            Add-RegistryPlanLines -Report $report -Path $path -Desired $ntpDesired -Names @('NewTabPageLocation') -Title 'New tab override'
        } catch {
            [void]$report.AppendLine("  -- New tab override")
            [void]$report.AppendLine("     ERROR: $_")
        }
        [void]$report.AppendLine('')

        try {
            $startup = Get-DesiredStartupOverride
            [void]$report.AppendLine('  -- Startup override')
            $curStartup = Get-RegistryValueState -Path $path -Name 'RestoreOnStartup'
            $urlPath = Join-Path $path 'RestoreOnStartupURLs'
            $curUrls = @(Get-RegistryNumberedValues -Path $urlPath)
            if ($startup.Enabled) {
                if (-not $curStartup.Exists) {
                    [void]$report.AppendLine("     ADD    RestoreOnStartup = $($startup.Code)")
                } elseif ("$($curStartup.Value)" -eq "$($startup.Code)") {
                    [void]$report.AppendLine("     KEEP   RestoreOnStartup = $($startup.Code)")
                } else {
                    [void]$report.AppendLine("     CHANGE RestoreOnStartup : $($curStartup.Value) -> $($startup.Code)")
                }
                if ($startup.Urls.Count -gt 0) {
                    [void]$report.AppendLine("     REPLACE RestoreOnStartupURLs with $($startup.Urls.Count) URL(s): $($startup.Urls -join ', ')")
                } elseif ($curUrls.Count -gt 0) {
                    [void]$report.AppendLine('     CLEAR  RestoreOnStartupURLs')
                } else {
                    [void]$report.AppendLine('     No startup URL list needed.')
                }
            } else {
                if ($curStartup.Exists) { [void]$report.AppendLine("     CLEAR  RestoreOnStartup (currently $($curStartup.Value))") }
                if ($curUrls.Count -gt 0) { [void]$report.AppendLine("     CLEAR  RestoreOnStartupURLs ($($curUrls.Count) URL(s))") }
                if (-not $curStartup.Exists -and $curUrls.Count -eq 0) { [void]$report.AppendLine('     No write needed.') }
            }
        } catch {
            [void]$report.AppendLine('  -- Startup override')
            [void]$report.AppendLine("     ERROR: $_")
        }
        [void]$report.AppendLine('')
    }

    [void]$report.AppendLine('=== Scheduled tasks ===')
    foreach ($cb in $script:TaskCheckBoxes) {
        $t = $cb.Tag
        $task = Get-ScheduledTask -TaskName $t.Name -ErrorAction SilentlyContinue
        if (-not $task) {
            [void]$report.AppendLine("  MISSING $($t.Name) - skipped")
        } elseif ($cb.Checked) {
            if ($task.State -eq 'Disabled') { [void]$report.AppendLine("  KEEP    $($t.Name) disabled") }
            else { [void]$report.AppendLine("  DISABLE $($t.Name) (currently $($task.State))") }
        } else {
            if ($task.State -eq 'Disabled') { [void]$report.AppendLine("  ENABLE  $($t.Name)") }
            else { [void]$report.AppendLine("  KEEP    $($t.Name) enabled/current state $($task.State)") }
        }
    }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Services ===')
    foreach ($cb in $script:ServiceCheckBoxes) {
        $s = $cb.Tag
        $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
        if (-not $svc) {
            [void]$report.AppendLine("  MISSING $($s.Name) - skipped")
        } elseif ($cb.Checked) {
            if ($svc.StartType -eq 'Disabled') { [void]$report.AppendLine("  KEEP    $($s.Name) disabled") }
            else { [void]$report.AppendLine("  DISABLE $($s.Name) (currently $($svc.StartType), $($svc.Status))") }
        } else {
            if ($svc.StartType -eq 'Disabled') { [void]$report.AppendLine("  RESET   $($s.Name) startup type to Manual") }
            else { [void]$report.AppendLine("  KEEP    $($s.Name) startup type $($svc.StartType)") }
        }
    }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Hosts blocklist ===')
    [void]$report.AppendLine('Main Apply does not edit hosts. Use Preview hosts / Apply hosts blocks inside the Hosts tab.')
    [void]$report.AppendLine("Selected hosts domains right now: $(@(Get-SelectedHostsDomains).Count)")

    return $report.ToString()
}

function Invoke-FullRestore {
    param([bool]$Backup)

    if ($Backup) { [void](Export-Backup) }

    foreach ($channel in $script:TargetChannels) {
        $path = $script:Channels[$channel].Path
        try {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                Write-Log "Removed policy key for $channel ($path)" 'OK'
            } else {
                Write-Log "$channel had no policy key - skipped." 'INFO'
            }
        } catch {
            Write-Log "Full restore policy remove [$channel]: $_" 'ERR'
        }
    }

    $currentHosts = @(Get-HostsCurrentDomains)
    if ($currentHosts.Count -gt 0) {
        try { Clear-HostsBlock } catch { Write-Log "Full restore hosts clear: $_" 'ERR' }
    } else {
        Write-Log 'No Brave-Free-Origin hosts block present.' 'INFO'
    }

    foreach ($t in $script:ScheduledTasks) {
        try {
            $task = Get-ScheduledTask -TaskName $t.Name -ErrorAction SilentlyContinue
            if ($task -and $task.State -eq 'Disabled') {
                Enable-ScheduledTask -TaskName $t.Name -ErrorAction Stop | Out-Null
                Write-Log "ENABLED task $($t.Name)" 'OK'
            }
        } catch {
            Write-Log "Full restore task $($t.Name): $_" 'WARN'
        }
    }

    foreach ($s in $script:Services) {
        try {
            $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            if ($svc -and $svc.StartType -eq 'Disabled') {
                Set-Service -Name $s.Name -StartupType Manual -ErrorAction Stop
                Write-Log "RESET service $($s.Name) to Manual" 'OK'
            }
        } catch {
            Write-Log "Full restore service $($s.Name): $_" 'WARN'
        }
    }

    Push-SuppressSelectionEvents
    try {
        foreach ($cb in $script:CheckBoxes)        { $cb.Checked = $false }
        foreach ($cb in $script:TaskCheckBoxes)    { $cb.Checked = $false }
        foreach ($cb in $script:ServiceCheckBoxes) { $cb.Checked = $false }
        foreach ($cb in $script:HostsCheckBoxes)   { $cb.Checked = $false }
        if ($script:ChkSearchOverride)  { $script:ChkSearchOverride.Checked = $false }
        if ($script:ChkNtpOverride)     { $script:ChkNtpOverride.Checked = $false }
        if ($script:ChkStartupOverride) { $script:ChkStartupOverride.Checked = $false }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = 'None'
    Update-OverrideControlStates
    Update-SelectionSummary
    Update-ConfigurationFilter
    Write-Log 'Full restore completed. Restart Brave to see stock behavior.' 'DONE'
}

function Get-ScriptletDefaultRoot {
    $channel = if ($script:TargetChannels -and $script:TargetChannels.Count -gt 0) { $script:TargetChannels[0] } else { 'Stable' }
    if ($script:ScriptletUserDataRoots.Contains($channel)) { return $script:ScriptletUserDataRoots[$channel] }
    return $script:ScriptletUserDataRoots['Stable']
}

function Get-ScriptletComponentInfo {
    param([string]$File, [string]$Root)

    $componentId = 'unknown'
    $version = 'unknown'
    $source = 'Unknown filter list'
    try {
        $full = [System.IO.Path]::GetFullPath($File)
        $base = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
        if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relative = $full.Substring($base.Length)
            $parts = $relative -split '[\\/]'
            if ($parts.Count -ge 1) { $componentId = $parts[0] }
            if ($parts.Count -ge 2) { $version = $parts[1] }
        }
        if ($script:ScriptletComponentNames.ContainsKey($componentId)) {
            $source = $script:ScriptletComponentNames[$componentId]
        } elseif ($componentId -ne 'unknown') {
            $source = $componentId
        }
    } catch {}

    return [pscustomobject]@{
        ComponentId = $componentId
        Version     = $version
        Source      = $source
    }
}

function Get-BfoDisabledScriptletRule {
    param([string]$Line)
    if ($Line -match '^\s*!\s*BFO disabled:\s*(?<rule>.+)$') {
        return $Matches.rule.Trim()
    }
    return $null
}

function Get-ScriptletRuleFromLine {
    param([string]$Line)
    $disabled = Get-BfoDisabledScriptletRule -Line $Line
    if ($disabled) { return $disabled }

    $trimmed = $Line.Trim()
    if ($trimmed.StartsWith('!')) { return $null }
    return $trimmed
}

function ConvertTo-ScriptletRecord {
    param(
        [string]$File,
        [string]$Root,
        [string]$Line,
        [int]$LineNumber
    )

    $disabledRule = Get-BfoDisabledScriptletRule -Line $Line
    $enabled = -not [bool]$disabledRule
    $rule = if ($disabledRule) { $disabledRule } else { $Line.Trim() }
    if ([string]::IsNullOrWhiteSpace($rule)) { return $null }
    if ($rule.StartsWith('!')) { return $null }
    if ($rule -notmatch '##\+js\((?<body>.*)\)') { return $null }

    $marker = $rule.IndexOf('##+js(', [System.StringComparison]::Ordinal)
    if ($marker -lt 0) { return $null }
    $domain = $rule.Substring(0, $marker)
    $body = $Matches.body
    $scriptlet = $body
    $arguments = ''
    $comma = $body.IndexOf(',')
    if ($comma -ge 0) {
        $scriptlet = $body.Substring(0, $comma).Trim()
        $arguments = $body.Substring($comma + 1).Trim()
    } else {
        $scriptlet = $body.Trim()
    }

    $info = Get-ScriptletComponentInfo -File $File -Root $Root
    return [pscustomobject]@{
        Enabled     = $enabled
        Domain      = $domain
        Scriptlet   = $scriptlet
        Arguments   = $arguments
        Source      = $info.Source
        ComponentId = $info.ComponentId
        Version     = $info.Version
        File        = $File
        LineNumber  = $LineNumber
        Rule        = $rule
    }
}

function Get-ScriptletListFiles {
    param(
        [string]$Root,
        [System.Collections.IList]$Warnings = $null
    )

    if ([string]::IsNullOrWhiteSpace($Root)) { throw 'User Data folder is empty.' }
    if (-not (Test-Path $Root)) { throw "User Data folder not found: $Root" }

    $files = @()
    $componentDirs = @(Get-ChildItem -Path $Root -Directory -ErrorAction Stop | Where-Object { $_.Name -match '^[a-z]{32}$' })
    foreach ($dir in $componentDirs) {
        try {
            $files += Get-ChildItem -Path $dir.FullName -Recurse -Filter 'list.txt' -File -ErrorAction Stop
        } catch {
            $warning = "Scriptlet scan skipped $($dir.FullName): $_"
            if ($Warnings) { [void]$Warnings.Add($warning) } else { Write-Log $warning 'WARN' }
        }
    }
    return @($files | Sort-Object FullName)
}

function Get-ScriptletRules {
    param(
        [string]$Root,
        [System.Collections.IList]$Warnings = $null
    )

    $records = New-Object System.Collections.Generic.List[object]
    $files = Get-ScriptletListFiles -Root $Root -Warnings $Warnings
    foreach ($file in $files) {
        try {
            $lineNo = 0
            foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
                $lineNo++
                $record = ConvertTo-ScriptletRecord -File $file.FullName -Root $Root -Line $line -LineNumber $lineNo
                if ($record) { [void]$records.Add($record) }
            }
        } catch {
            $warning = "Scriptlet scan failed $($file.FullName): $_"
            if ($Warnings) { [void]$Warnings.Add($warning) } else { Write-Log $warning 'WARN' }
        }
    }
    return @($records.ToArray())
}

function Backup-ScriptletFile {
    param([string]$File)

    if (-not (Test-Path $File)) { throw "Scriptlet list file not found: $File" }
    $backup = "$File.bfo-backup"
    if (-not (Test-Path $backup)) {
        Copy-Item -LiteralPath $File -Destination $backup -Force
        Write-Log "Scriptlet backup created: $backup" 'OK'
    }
    return $backup
}

function Test-ScriptletAdvancedWriteAllowed {
    if (-not $script:ChkScriptletAdvanced -or -not $script:ChkScriptletAdvanced.Checked) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'msg.scriptlet.locked'),
            (T 'msg.title.scriptlet'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return $false
    }

    $braveProcesses = @(Get-Process -Name brave -ErrorAction SilentlyContinue)
    if ($braveProcesses.Count -gt 0) {
        $ans = [System.Windows.Forms.MessageBox]::Show(
            (T 'msg.scriptlet.braveRunning' @($braveProcesses.Count)),
            (T 'msg.title.scriptlet'),
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($ans -ne 'Yes') { return $false }
    }

    return $true
}

function Set-ScriptletRuleState {
    param(
        [object[]]$Records,
        [bool]$Enable,
        [bool]$AffectDuplicates
    )

    if (-not $Records -or $Records.Count -eq 0) { return 0 }
    $changed = 0
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $byFile = $Records | Group-Object File

    foreach ($group in $byFile) {
        $file = $group.Name
        [void](Backup-ScriptletFile -File $file)
        $lines = [System.IO.File]::ReadAllLines($file)

        if ($AffectDuplicates) {
            $wanted = @{}
            foreach ($record in $group.Group) { $wanted[$record.Rule] = $true }
            for ($i = 0; $i -lt $lines.Length; $i++) {
                $original = Get-ScriptletRuleFromLine -Line $lines[$i]
                if (-not $original -or -not $wanted.ContainsKey($original)) { continue }

                $disabledRule = Get-BfoDisabledScriptletRule -Line $lines[$i]
                if ($Enable -and $disabledRule) {
                    $lines[$i] = $disabledRule
                    $changed++
                } elseif (-not $Enable -and -not $disabledRule) {
                    $lines[$i] = "$($script:ScriptletDisablePrefix)$original"
                    $changed++
                }
            }
        } else {
            foreach ($record in $group.Group) {
                $idx = [int]$record.LineNumber - 1
                if ($idx -lt 0 -or $idx -ge $lines.Length) { continue }
                $original = Get-ScriptletRuleFromLine -Line $lines[$idx]
                if ($original -ne $record.Rule) { continue }

                $disabledRule = Get-BfoDisabledScriptletRule -Line $lines[$idx]
                if ($Enable -and $disabledRule) {
                    $lines[$idx] = $disabledRule
                    $changed++
                } elseif (-not $Enable -and -not $disabledRule) {
                    $lines[$idx] = "$($script:ScriptletDisablePrefix)$original"
                    $changed++
                }
            }
        }

        [System.IO.File]::WriteAllLines($file, [string[]]$lines, $utf8NoBom)
    }

    return $changed
}

function Restore-ScriptletBackup {
    param([string]$File)

    $backup = "$File.bfo-backup"
    if (-not (Test-Path $backup)) { throw "No backup exists for: $File" }
    Copy-Item -LiteralPath $backup -Destination $File -Force
}

function Restore-AllScriptletBackups {
    param([string]$Root)

    if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path $Root)) { throw "User Data folder not found: $Root" }
    $backups = @(Get-ChildItem -Path $Root -Recurse -Filter 'list.txt.bfo-backup' -File -ErrorAction SilentlyContinue)
    $count = 0
    foreach ($backup in $backups) {
        $target = $backup.FullName.Substring(0, $backup.FullName.Length - '.bfo-backup'.Length)
        Copy-Item -LiteralPath $backup.FullName -Destination $target -Force
        $count++
    }
    return $count
}

function Export-ScriptletDisabledPreferences {
    param([string]$File)

    $disabled = @($script:ScriptletRules | Where-Object { -not $_.Enabled } | Sort-Object Rule -Unique)
    $payload = [ordered]@{
        version       = '1.9'
        exported      = (Get-Date -Format 's')
        disabledRules = @(
            foreach ($r in $disabled) {
                [ordered]@{
                    rule      = $r.Rule
                    domain    = $r.Domain
                    scriptlet = $r.Scriptlet
                    source    = $r.Source
                }
            }
        )
    }
    $payload | ConvertTo-Json -Depth 5 | Set-Content -Path $File -Encoding UTF8
    return $disabled.Count
}

function Import-ScriptletPreferencesAndReapply {
    param([string]$PrefsFile, [string]$Root)

    if (-not (Test-Path $PrefsFile)) { throw "Preference file not found: $PrefsFile" }
    $prefs = Get-Content $PrefsFile -Raw | ConvertFrom-Json
    if (-not $prefs.disabledRules) { throw 'Preference file has no disabledRules array.' }

    $wanted = @{}
    foreach ($entry in $prefs.disabledRules) {
        if ($entry.rule) { $wanted["$($entry.rule)"] = $true }
    }
    if ($wanted.Count -eq 0) { return 0 }

    $changed = 0
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    foreach ($file in (Get-ScriptletListFiles -Root $Root)) {
        $lines = [System.IO.File]::ReadAllLines($file.FullName)
        $fileChanged = $false
        for ($i = 0; $i -lt $lines.Length; $i++) {
            $original = Get-ScriptletRuleFromLine -Line $lines[$i]
            if (-not $original -or -not $wanted.ContainsKey($original)) { continue }
            if (Get-BfoDisabledScriptletRule -Line $lines[$i]) { continue }
            if (-not $fileChanged) {
                [void](Backup-ScriptletFile -File $file.FullName)
                $fileChanged = $true
            }
            $lines[$i] = "$($script:ScriptletDisablePrefix)$original"
            $changed++
        }
        if ($fileChanged) {
            [System.IO.File]::WriteAllLines($file.FullName, [string[]]$lines, $utf8NoBom)
        }
    }
    return $changed
}

function Resize-ScriptletColumns {
    if (-not $script:ScriptletList) { return }
    if ($script:ScriptletList.Columns.Count -lt 7) { return }

    $width = [Math]::Max(760, $script:ScriptletList.ClientSize.Width - 10)
    $pickWidth = 92
    $lineWidth = 55
    $flex = [Math]::Max(600, $width - $pickWidth - $lineWidth)
    $domainWidth = [Math]::Max(105, [int]($flex * 0.16))
    $scriptletWidth = [Math]::Max(115, [int]($flex * 0.17))
    $argsWidth = [Math]::Max(145, [int]($flex * 0.22))
    $sourceWidth = [Math]::Max(125, [int]($flex * 0.15))
    $rawWidth = [Math]::Max(170, $width - ($pickWidth + $domainWidth + $scriptletWidth + $argsWidth + $sourceWidth + $lineWidth + 4))

    $script:ScriptletList.Columns[0].Width = $pickWidth
    $script:ScriptletList.Columns[1].Width = $domainWidth
    $script:ScriptletList.Columns[2].Width = $scriptletWidth
    $script:ScriptletList.Columns[3].Width = $argsWidth
    $script:ScriptletList.Columns[4].Width = $sourceWidth
    $script:ScriptletList.Columns[5].Width = $lineWidth
    $script:ScriptletList.Columns[6].Width = $rawWidth
}

function Update-ScriptletStatusText {
    param([int]$Shown = -1)

    if (-not $script:LblScriptletStatus) { return }
    if ($Shown -lt 0) { $Shown = @($script:ScriptletVisibleRules).Count }

    $enabled = @($script:ScriptletRules | Where-Object { $_.Enabled }).Count
    $disabled = @($script:ScriptletRules | Where-Object { -not $_.Enabled }).Count
    $checked = $script:ScriptletCheckedKeys.Count
    $script:LblScriptletStatus.Text = T 'scriptlet.statusShowing' @($Shown, $script:ScriptletRules.Count, $enabled, $disabled, $checked)
}

# The scriptlet tab keeps live text outside the binding table: the ListView
# column headers, the per-row Enabled/Disabled cell and the status line are
# all written imperatively as the scan/render progresses. A language switch
# therefore has to re-text them explicitly, in place, without re-scanning.
function Update-ScriptletLocalizedText {
    if ($script:ScriptletList -and $script:ScriptletList.Columns.Count -ge 7) {
        $headerKeys = @(
            'scriptlet.col.pick', 'scriptlet.col.domain', 'scriptlet.col.scriptlet',
            'scriptlet.col.arguments', 'scriptlet.col.source', 'scriptlet.col.line',
            'scriptlet.col.rawRule'
        )
        for ($i = 0; $i -lt $headerKeys.Count; $i++) {
            $script:ScriptletList.Columns[$i].Text = T $headerKeys[$i]
        }
    }
    if ($script:ScriptletList -and $script:ScriptletList.Items.Count -gt 0) {
        $script:SuppressScriptletStatusEvents = $true
        $script:ScriptletList.BeginUpdate()
        try {
            foreach ($item in $script:ScriptletList.Items) {
                if (-not $item.Tag) { continue }
                $item.Text = if ($item.Tag.Enabled) { T 'scriptlet.state.enabled' } else { T 'scriptlet.state.disabled' }
            }
        } finally {
            $script:ScriptletList.EndUpdate()
            $script:SuppressScriptletStatusEvents = $false
        }
    }
    # Only refresh the counter line if a scan has actually produced rules;
    # otherwise the binding table's idle prompt is the correct text.
    if (@($script:ScriptletRules).Count -gt 0) { Update-ScriptletStatusText }
}

function Set-ScriptletUiBusy {
    param([bool]$Busy, [string]$Message = '')

    foreach ($control in @(
        $script:BtnScriptletScan,
        $script:BtnScriptletFilter,
        $script:BtnScriptletDisable,
        $script:BtnScriptletEnable,
        $script:BtnScriptletCheckVisible,
        $script:BtnScriptletClearChecks,
        $script:BtnScriptletImportPrefs
    )) {
        if ($control) { $control.Enabled = -not $Busy }
    }

    if ($script:LblScriptletStatus -and $Message) { $script:LblScriptletStatus.Text = $Message }
    if ($form) { $form.UseWaitCursor = $Busy }
    [System.Windows.Forms.Application]::DoEvents()
}

function Start-ScriptletFilterDelay {
    if ($script:ScriptletFilterTimer) {
        $script:ScriptletFilterTimer.Stop()
        $script:ScriptletFilterTimer.Start()
    } else {
        Update-ScriptletListView
    }
}

function Get-ScriptletRecordKey {
    param([object]$Record)

    if (-not $Record) { return $null }
    return ('{0}`t{1}' -f [string]$Record.File, [int]$Record.LineNumber)
}

function Test-ScriptletRecordChecked {
    param([object]$Record)

    $key = Get-ScriptletRecordKey -Record $Record
    return ($key -and $script:ScriptletCheckedKeys.ContainsKey($key))
}

function Set-ScriptletRecordChecked {
    param(
        [object]$Record,
        [bool]$Checked
    )

    $key = Get-ScriptletRecordKey -Record $Record
    if (-not $key) { return }

    if ($Checked) {
        $script:ScriptletCheckedKeys[$key] = $true
    } else {
        [void]$script:ScriptletCheckedKeys.Remove($key)
    }
}

function New-ScriptletListItem {
    param([object]$Record)

    $stateText = if ($Record.Enabled) { T 'scriptlet.state.enabled' } else { T 'scriptlet.state.disabled' }
    $item = New-Object System.Windows.Forms.ListViewItem($stateText)
    [void]$item.SubItems.Add($Record.Domain)
    [void]$item.SubItems.Add($Record.Scriptlet)
    [void]$item.SubItems.Add($Record.Arguments)
    [void]$item.SubItems.Add("$($Record.Source) $($Record.Version)")
    [void]$item.SubItems.Add([string]$Record.LineNumber)
    [void]$item.SubItems.Add($Record.Rule)
    $item.Tag = $Record
    $item.Checked = Test-ScriptletRecordChecked -Record $Record
    if (-not $Record.Enabled) {
        $item.ForeColor = [System.Drawing.Color]::FromArgb(150, 60, 60)
    }
    return $item
}

function Stop-ScriptletRender {
    if ($script:ScriptletRenderTimer) { $script:ScriptletRenderTimer.Stop() }
    $script:ScriptletRenderState = $null
    $script:SuppressScriptletStatusEvents = $false
}

function Start-ScriptletRender {
    param([object[]]$Rows)

    if (-not $script:ScriptletList) { return }
    Stop-ScriptletRender
    Set-ScriptletUiBusy $true (T 'scriptlet.statusRender0' @($Rows.Count))
    Resize-ScriptletColumns

    $script:SuppressScriptletStatusEvents = $true
    $script:ScriptletList.BeginUpdate()
    try {
        $script:ScriptletList.Items.Clear()
    } finally {
        $script:ScriptletList.EndUpdate()
    }

    $script:ScriptletRenderState = [pscustomobject]@{
        Rows      = @($Rows)
        Index     = 0
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }

    if ($script:ScriptletProgress) {
        $script:ScriptletProgress.Visible = $true
        $script:ScriptletProgress.Style = 'Continuous'
        $script:ScriptletProgress.Value = 0
    }
    if ($script:LblScriptletStatus) {
        $script:LblScriptletStatus.Text = T 'scriptlet.statusRender0' @($Rows.Count)
    }

    if ($Rows.Count -eq 0) {
        Stop-ScriptletRender
        if ($script:ScriptletProgress) { $script:ScriptletProgress.Value = 0 }
        Update-ScriptletStatusText -Shown 0
        Set-ScriptletUiBusy $false
        return
    }

    if (-not $script:ScriptletRenderTimer) {
        $script:ScriptletRenderTimer = New-Object System.Windows.Forms.Timer
        $script:ScriptletRenderTimer.Interval = 10
        $script:ScriptletRenderTimer.Add_Tick({ Step-ScriptletRender })
    }
    $script:ScriptletRenderTimer.Start()
}

function Step-ScriptletRender {
    $state = $script:ScriptletRenderState
    if (-not $state) {
        Stop-ScriptletRender
        return
    }

    $total = $state.Rows.Count
    if ($total -eq 0) {
        Stop-ScriptletRender
        Update-ScriptletStatusText -Shown 0
        return
    }

    $startTick = [Environment]::TickCount64
    $batch = New-Object System.Collections.Generic.List[System.Windows.Forms.ListViewItem]
    while ($state.Index -lt $total -and (([Environment]::TickCount64 - $startTick) -lt 25) -and $batch.Count -lt 400) {
        [void]$batch.Add((New-ScriptletListItem -Record $state.Rows[$state.Index]))
        $state.Index++
    }

    if ($batch.Count -gt 0) {
        $items = $batch.ToArray()
        $script:ScriptletList.BeginUpdate()
        try {
            $script:ScriptletList.Items.AddRange($items)
        } finally {
            $script:ScriptletList.EndUpdate()
        }
    }

    $percent = [int](($state.Index * 1000L) / [Math]::Max(1, $total))
    $percent = [Math]::Max(0, [Math]::Min(1000, $percent))
    if ($script:ScriptletProgress) { $script:ScriptletProgress.Value = $percent }
    if ($script:LblScriptletStatus) {
        $seconds = [Math]::Round($state.Stopwatch.Elapsed.TotalSeconds, 1)
        $script:LblScriptletStatus.Text = T 'scriptlet.statusRendering' @($state.Index, $total, $seconds)
    }

    if ($state.Index -ge $total) {
        $elapsed = [Math]::Round($state.Stopwatch.Elapsed.TotalSeconds, 1)
        Stop-ScriptletRender
        if ($script:ScriptletProgress) { $script:ScriptletProgress.Value = 1000 }
        Update-ScriptletStatusText -Shown $total
        if ($script:LblScriptletStatus) {
            $script:LblScriptletStatus.Text += (T 'scriptlet.renderDone' @($elapsed))
        }
        Set-ScriptletUiBusy $false
    }
}

function Update-ScriptletListView {
    if (-not $script:ScriptletList) { return }

    $query = if ($script:TxtScriptletSearch) { $script:TxtScriptletSearch.Text.Trim() } else { '' }
    $disabledOnly = ($script:ChkScriptletDisabledOnly -and $script:ChkScriptletDisabledOnly.Checked)
    $rows = @($script:ScriptletRules)
    if ($disabledOnly) { $rows = @($rows | Where-Object { -not $_.Enabled }) }
    if (-not [string]::IsNullOrWhiteSpace($query)) {
        $needle = $query.ToLowerInvariant()
        $rows = @($rows | Where-Object {
            ("$($_.Domain) $($_.Scriptlet) $($_.Arguments) $($_.Source) $($_.Rule) $($_.File)").ToLowerInvariant().Contains($needle)
        })
    }

    $script:ScriptletVisibleRules = $rows
    Start-ScriptletRender -Rows $rows
}

function Get-SelectedScriptletRecords {
    if (-not $script:ScriptletList) { return @() }
    $records = @()

    if ($script:ScriptletCheckedKeys.Count -gt 0) {
        foreach ($record in $script:ScriptletRules) {
            if (Test-ScriptletRecordChecked -Record $record) { $records += $record }
        }
        return $records
    }

    foreach ($item in $script:ScriptletList.SelectedItems) {
        if ($item.Tag) { $records += $item.Tag }
    }
    return $records
}

function Set-ScriptletVisibleChecks {
    param([bool]$Checked)

    if (-not $script:ScriptletList) { return }
    if ($Checked) {
        foreach ($record in $script:ScriptletVisibleRules) {
            Set-ScriptletRecordChecked -Record $record -Checked $true
        }
    } else {
        $script:ScriptletCheckedKeys.Clear()
    }

    $script:SuppressScriptletStatusEvents = $true
    $script:ScriptletList.BeginUpdate()
    try {
        foreach ($item in $script:ScriptletList.Items) {
            $item.Checked = Test-ScriptletRecordChecked -Record $item.Tag
        }
    } finally {
        $script:ScriptletList.EndUpdate()
        $script:SuppressScriptletStatusEvents = $false
    }
    Update-ScriptletStatusText
}

function Update-ScriptletScanProgress {
    param([string]$Message = '')

    $state = $script:ScriptletScanState
    if (-not $state) { return }

    $currentBytes = 0L
    if ($state.Reader -and $state.Reader.BaseStream) {
        try { $currentBytes = [int64]$state.Reader.BaseStream.Position } catch { $currentBytes = 0L }
    }
    $doneBytes = [Math]::Min([int64]$state.TotalBytes, [int64]($state.ProcessedBytes + $currentBytes))
    $percent = if ($state.TotalBytes -gt 0) { [int](($doneBytes * 1000L) / $state.TotalBytes) } else { 0 }
    $percent = [Math]::Max(0, [Math]::Min(1000, $percent))

    if ($script:ScriptletProgress) {
        $script:ScriptletProgress.Visible = $true
        $script:ScriptletProgress.Style = 'Continuous'
        $script:ScriptletProgress.Value = $percent
    }

    if ($script:LblScriptletStatus) {
        if ([string]::IsNullOrWhiteSpace($Message)) {
            $fileName = if ($state.CurrentFile) { Split-Path $state.CurrentFile.FullName -Leaf } else { T 'scriptlet.statusStarting' }
            $seconds = [Math]::Max(1, [int]$state.Stopwatch.Elapsed.TotalSeconds)
            $Message = T 'scriptlet.statusScanning' @(
                $state.FileIndex, $state.Files.Count, $fileName,
                $state.Records.Count, [int]($percent / 10), $seconds)
        }
        $script:LblScriptletStatus.Text = $Message
    }
}

function Stop-ScriptletScan {
    if ($script:ScriptletScanTimer) { $script:ScriptletScanTimer.Stop() }
    if ($script:ScriptletScanState -and $script:ScriptletScanState.Reader) {
        try { $script:ScriptletScanState.Reader.Dispose() } catch {}
    }
    $script:ScriptletScanState = $null
    Set-ScriptletUiBusy $false
}

function Complete-ScriptletScan {
    $state = $script:ScriptletScanState
    if (-not $state) { return }

    if ($script:ScriptletScanTimer) { $script:ScriptletScanTimer.Stop() }
    if ($state.Reader) {
        try { $state.Reader.Dispose() } catch {}
        $state.Reader = $null
    }
    $state.Stopwatch.Stop()

    $script:ScriptletRules = @($state.Records.ToArray())
    foreach ($warning in @($state.Warnings)) { Write-Log $warning 'WARN' }

    if ($script:ScriptletProgress) {
        $script:ScriptletProgress.Visible = $true
        $script:ScriptletProgress.Style = 'Continuous'
        $script:ScriptletProgress.Value = 1000
    }

    $elapsed = [Math]::Round($state.Stopwatch.Elapsed.TotalSeconds, 1)
    $root = $state.Root
    $script:ScriptletScanState = $null
    if ($script:LblScriptletStatus) {
        $script:LblScriptletStatus.Text = T 'scriptlet.statusRenderN' @($script:ScriptletRules.Count)
    }
    [System.Windows.Forms.Application]::DoEvents()
    Update-ScriptletListView
    Write-Log "Scriptlet scan complete: $($script:ScriptletRules.Count) rule(s) from $root in ${elapsed}s" 'OK'

    if ($script:LblScriptletStatus) {
        $script:LblScriptletStatus.Text += (T 'scriptlet.scanDone' @($elapsed))
    }
    if ($script:ScriptletRules.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'msg.scriptlet.noRules' @($root)),
            (T 'msg.title.scriptlet'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    }
}

function Step-ScriptletScan {
    $state = $script:ScriptletScanState
    if (-not $state) {
        if ($script:ScriptletScanTimer) { $script:ScriptletScanTimer.Stop() }
        return
    }

    $startTick = [Environment]::TickCount64
    $linesThisTick = 0
    while ((([Environment]::TickCount64 - $startTick) -lt 35) -and ($linesThisTick -lt 2500)) {
        if (-not $state.Reader) {
            if ($state.FileIndex -ge $state.Files.Count) {
                Complete-ScriptletScan
                return
            }

            $file = $state.Files[$state.FileIndex]
            $state.FileIndex++
            $state.CurrentFile = $file
            $state.CurrentLine = 0
            try {
                $state.Reader = [System.IO.File]::OpenText($file.FullName)
            } catch {
                [void]$state.Warnings.Add("Scriptlet scan failed $($file.FullName): $_")
                $state.ProcessedBytes += [int64]$file.Length
                $state.Reader = $null
                continue
            }
        }

        try {
            $line = $state.Reader.ReadLine()
        } catch {
            [void]$state.Warnings.Add("Scriptlet scan failed $($state.CurrentFile.FullName): $_")
            try { $state.Reader.Dispose() } catch {}
            $state.ProcessedBytes += [int64]$state.CurrentFile.Length
            $state.Reader = $null
            continue
        }

        if ($null -eq $line) {
            try { $state.Reader.Dispose() } catch {}
            $state.ProcessedBytes += [int64]$state.CurrentFile.Length
            $state.Reader = $null
            continue
        }

        $state.CurrentLine++
        $linesThisTick++
        $record = ConvertTo-ScriptletRecord -File $state.CurrentFile.FullName -Root $state.Root -Line $line -LineNumber $state.CurrentLine
        if ($record) { [void]$state.Records.Add($record) }
    }

    Update-ScriptletScanProgress
}

function Invoke-ScriptletScan {
    $root = $script:TxtScriptletRoot.Text.Trim()
    if ($script:ScriptletScanState) {
        Write-Log 'Scriptlet scan is already running.' 'INFO'
        return
    }

    try {
        Set-ScriptletUiBusy $true (T 'scriptlet.statusFinding')
        $warnings = New-Object System.Collections.ArrayList
        $files = @(Get-ScriptletListFiles -Root $root -Warnings $warnings)
        if ($files.Count -eq 0) {
            Set-ScriptletUiBusy $false
            if ($script:ScriptletProgress) { $script:ScriptletProgress.Value = 0 }
            [System.Windows.Forms.MessageBox]::Show(
                (T 'msg.scriptlet.noFiles' @($root)),
                (T 'msg.title.scriptlet'),
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }

        $totalBytes = [int64](@($files | Measure-Object Length -Sum).Sum)
        if ($totalBytes -lt 1) { $totalBytes = 1 }
        $script:ScriptletRules = @()
        $script:ScriptletVisibleRules = @()
        $script:ScriptletCheckedKeys.Clear()
        if ($script:ScriptletList) { $script:ScriptletList.Items.Clear() }

        $script:ScriptletScanState = [pscustomobject]@{
            Root           = $root
            Files          = $files
            FileIndex      = 0
            CurrentFile    = $null
            CurrentLine    = 0
            Reader         = $null
            ProcessedBytes = 0L
            TotalBytes     = $totalBytes
            Records        = (New-Object System.Collections.Generic.List[object])
            Warnings       = $warnings
            Stopwatch      = [System.Diagnostics.Stopwatch]::StartNew()
        }

        if ($script:ScriptletProgress) {
            $script:ScriptletProgress.Visible = $true
            $script:ScriptletProgress.Style = 'Continuous'
            $script:ScriptletProgress.Value = 0
        }
        Update-ScriptletScanProgress (T 'scriptlet.statusFound' @($files.Count))
        Write-Log "Scriptlet scan started: $root ($($files.Count) list file(s), $([Math]::Round($totalBytes / 1MB, 2)) MB)" 'INFO'

        if (-not $script:ScriptletScanTimer) {
            $script:ScriptletScanTimer = New-Object System.Windows.Forms.Timer
            $script:ScriptletScanTimer.Interval = 15
            $script:ScriptletScanTimer.Add_Tick({ Step-ScriptletScan })
        }
        $script:ScriptletScanTimer.Start()
    } catch {
        Stop-ScriptletScan
        $script:ScriptletRules = @()
        Update-ScriptletListView
        Write-Log "Scriptlet scan failed: $_" 'ERR'
        [System.Windows.Forms.MessageBox]::Show(
            (T 'msg.scriptlet.scanFailed' @("$_")),
            (T 'msg.title.scriptlet'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
}
#endregion

#region GUI Build -------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(1180, 940)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(1080, 860)
$form.Font = Get-BfoUiFont -Size 9

# Tooltip provider is script-scoped so Set-LocTooltip can reach it.
$script:ToolTip = New-Object System.Windows.Forms.ToolTip
$script:ToolTip.AutoPopDelay = 30000
$script:ToolTip.InitialDelay = 300
$script:ToolTip.ReshowDelay  = 300

[void](Set-Loc $form 'app.title' -FormatArgs @($script:AppVersion))
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)

$braveVer = Get-BraveVersion
$script:ActiveProfile = 'Custom'
$script:MinimalPolicies = @(
    'HardwareAccelerationModeEnabled',
    'BraveRewardsDisabled','BraveWalletDisabled','BraveVPNDisabled',
    'BraveAIChatEnabled','PasswordManagerEnabled'
)
$script:OriginPolicies = @(
    'HardwareAccelerationModeEnabled',
    'BraveAIChatEnabled',
    'BraveNewsDisabled',
    'BraveP3AEnabled',
    'BravePlaylistEnabled',
    'BraveRewardsDisabled',
    'BraveSpeedreaderEnabled',
    'BraveStatsPingEnabled',
    'BraveTalkDisabled',
    'BraveVPNDisabled',
    'BraveWalletDisabled',
    'BraveWaybackMachineEnabled',
    'BraveWebDiscoveryEnabled',
    'MetricsReportingEnabled',
    'TorDisabled',
    # Shields / privacy-engine policies - keeping ad-block ON is a *performance* win
    # (fewer requests, less DOM, less JS). It's also Brave's identity. Origin Mode
    # and everything that derives from it (Privacy + Boost) now enforces these.
    'DefaultBraveAdblockSetting',
    'DefaultBraveFingerprintingV2Setting',
    'DefaultBraveReferrersSetting',
    'BraveTrackingQueryParametersFilteringEnabled',
    'BraveDeAmpEnabled',
    'BraveDebouncingEnabled'
)
$script:PerformancePolicies = @(
    $script:OriginPolicies +
    @(
        'BackgroundModeEnabled',
        'BrowserLabsEnabled',
        'CloudPrintSubmitEnabled',
        'DiskCacheSize',
        'HardwareAccelerationModeEnabled',
        'HighEfficiencyModeEnabled',
        'HomepageIsNewTabPage',
        'HomepageLocation',
        'IPFSEnabled',
        'LiveCaptionEnabled',
        'MediaRouterEnabled',
        'NetworkPredictionOptions',
        'NewTabPageLocation',
        'NTPCustomBackgroundEnabled',
        'PromotionalTabsEnabled',
        'QuicAllowed',
        'ReadingListEnabled',
        'RestoreOnStartup',
        'WebRtcEventLogCollectionAllowed',
        'WebTorrentDisabled',
        'WelcomePageOnOSUpgradeEnabled'
    )
) | Select-Object -Unique
$script:MaxPrivacyPolicies = @(
    foreach ($cat in $script:Policies.Keys) {
        foreach ($policy in $script:Policies[$cat]) {
            if ($policy.MaxPrivacy) { $policy.Name }
        }
    }
) | Select-Object -Unique
$script:MaxPerformancePolicies = @(
    $script:MaxPrivacyPolicies +
    $script:PerformancePolicies +
    @(
        'BookmarkBarEnabled',
        'PromptForDownloadLocation',
        'ShowHomeButton',
        'SpellcheckEnabled'
    )
) | Select-Object -Unique
# Preset ids are stable and language independent; the labels come from the
# string catalog under preset.<Id>.name / .description / .risk.
$script:PresetKeys = @('Minimal','Recommended','Origin','Performance','MaxPerformance','MaxPrivacy','None','CurrentState','Custom')

function Get-PresetName        { param([string]$Key) if ($script:PresetKeys -contains $Key) { T "preset.$Key.name" }        else { $Key } }
function Get-PresetDescription { param([string]$Key) if ($script:PresetKeys -contains $Key) { T "preset.$Key.description" } else { '' } }
function Get-PresetRisk        { param([string]$Key) if ($script:PresetKeys -contains $Key) { T "preset.$Key.risk" }        else { '' } }

# Reports and the log stay English so a translated install still produces
# bug reports the maintainer can read.
function Get-PresetNameEn {
    param([string]$Key)
    $k = "preset.$Key.name"
    if ($script:EnglishStrings.ContainsKey($k)) { return $script:EnglishStrings[$k] }
    return $Key
}

function Get-PresetPayload {
    param([string]$Preset)

    # Hosts groups: only auto-tick a group when the corresponding feature is
    # ALSO disabled by policy in this preset. No orphan blocks.
    $hostsAlwaysSafe   = @('p3a','variations','stats','webDiscovery')
    $hostsRewards      = @('rewards')
    $hostsNews         = @('news')
    $hostsComponents   = @('components')

    switch ($Preset) {
        'Recommended' {
            return @{
                Policies = @(
                    foreach ($cat in $script:Policies.Keys) {
                        foreach ($policy in $script:Policies[$cat]) {
                            if ($policy.Recommended) { $policy.Name }
                        }
                    }
                )
                Tasks    = @($script:ScheduledTasks.Name)
                Services = @()
                Hosts    = $hostsAlwaysSafe + $hostsRewards + $hostsNews
            }
        }
        'MaxPrivacy' {
            return @{
                Policies = @($script:MaxPrivacyPolicies)
                Tasks    = @($script:ScheduledTasks.Name)
                Services = @($script:Services.Name)
                Hosts    = $hostsAlwaysSafe + $hostsRewards + $hostsNews + $hostsComponents
            }
        }
        'Minimal' {
            return @{
                Policies = @($script:MinimalPolicies)
                Tasks    = @()
                Services = @()
                Hosts    = $hostsAlwaysSafe + $hostsRewards   # Quick disables Rewards, leaves News on
            }
        }
        'Origin' {
            return @{
                Policies = @($script:OriginPolicies)
                Tasks    = @()
                Services = @()
                Hosts    = $hostsAlwaysSafe + $hostsRewards + $hostsNews   # Origin disables both
            }
        }
        'Performance' {
            return @{
                Policies = @($script:PerformancePolicies)
                Tasks    = @($script:ScheduledTasks.Name)
                Services = @()
                Hosts    = $hostsAlwaysSafe + $hostsRewards + $hostsNews
            }
        }
        'MaxPerformance' {
            return @{
                Policies = @($script:MaxPerformancePolicies)
                Tasks    = @($script:ScheduledTasks.Name)
                Services = @($script:Services.Name)
                Hosts    = $hostsAlwaysSafe + $hostsRewards + $hostsNews + $hostsComponents
            }
        }
        default {
            return @{
                Policies = @()
                Tasks    = @()
                Services = @()
                Hosts    = @()
            }
        }
    }
}

function Update-SelectionSummary {
    if (-not $script:ModeLabel) { return }

    $selectedPolicies = @($script:CheckBoxes | Where-Object { $_.Checked })
    $selectedTasks = @($script:TaskCheckBoxes | Where-Object { $_.Checked })
    $selectedServices = @($script:ServiceCheckBoxes | Where-Object { $_.Checked })
    $modeKey = if ([string]::IsNullOrWhiteSpace($script:ActiveProfile)) { 'Custom' } else { $script:ActiveProfile }
    $script:ModeLabel.Text       = T 'mode.label'    @((Get-PresetName $modeKey))
    $script:SelectionLabel.Text  = T 'mode.policies' @($selectedPolicies.Count, $script:CheckBoxes.Count)
    $script:SystemLabel.Text     = T 'mode.system'   @($selectedTasks.Count, $selectedServices.Count)
    $script:RiskLabel.Text       = T 'mode.risk'     @((Get-PresetRisk $modeKey))
    $script:ModeDescription.Text = Get-PresetDescription $modeKey
}

function Set-CustomMode {
    if ($script:SuppressSelectionEvents) { return }
    $script:ActiveProfile = 'Custom'
    Update-SelectionSummary
}

function Apply-Preset {
    param([string]$Preset)

    $payload = Get-PresetPayload -Preset $Preset
    # Suppressed for correctness (no "Custom" downgrade) and for speed: the
    # per-checkbox handler re-runs the whole configuration filter, and there
    # are ninety-odd checkboxes. One recompute at the end is enough.
    Push-SuppressSelectionEvents
    try {
        foreach ($cb in $script:CheckBoxes) {
            $policyName = $cb.Tag.Policy.Name
            $cb.Checked = $payload.Policies -contains $policyName
        }
        foreach ($cb in $script:TaskCheckBoxes) {
            $cb.Checked = $payload.Tasks -contains $cb.Tag.Name
        }
        foreach ($cb in $script:ServiceCheckBoxes) {
            $cb.Checked = $payload.Services -contains $cb.Tag.Name
        }
        # Hosts checkboxes (created later in the GUI; guard if not yet built)
        if ($script:HostsCheckBoxes) {
            foreach ($cb in $script:HostsCheckBoxes) {
                $cb.Checked = $payload.Hosts -contains $cb.Tag.Id
            }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = $Preset
    Update-SelectionSummary
    Update-ConfigurationFilter
    Write-Log "Loaded mode: $(Get-PresetNameEn $Preset)"
}

# Header panel
$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 112
$header.BackColor = [System.Drawing.Color]::FromArgb(22, 27, 34)

$titleLabel = New-Object System.Windows.Forms.Label
[void](Set-Loc $titleLabel 'app.name')
$titleLabel.ForeColor = [System.Drawing.Color]::White
[void](Set-LocFont $titleLabel -Size 18 -Semibold)
$titleLabel.Location = New-Object System.Drawing.Point(18, 10)
$titleLabel.AutoSize = $true
$header.Controls.Add($titleLabel)

$subLabel = New-Object System.Windows.Forms.Label
[void](Set-Loc $subLabel 'header.subtitle')
$subLabel.ForeColor = [System.Drawing.Color]::Gainsboro
[void](Set-LocFont $subLabel -Size 9)
$subLabel.Location = New-Object System.Drawing.Point(20, 43)
$subLabel.Size = New-Object System.Drawing.Size(760, 18)
$header.Controls.Add($subLabel)

$metaLabel = New-Object System.Windows.Forms.Label
[void](Set-Loc $metaLabel 'header.braveDetected' -FormatArgs @($braveVer))
$metaLabel.ForeColor = [System.Drawing.Color]::LightSteelBlue
[void](Set-LocFont $metaLabel -Size 8.5)
$metaLabel.Location = New-Object System.Drawing.Point(20, 70)
$metaLabel.Size = New-Object System.Drawing.Size(280, 18)
$header.Controls.Add($metaLabel)

# Channel selector (multi-channel support)
$detectedChannels = Get-DetectedChannels
$channelLabel = New-Object System.Windows.Forms.Label
[void](Set-Loc $channelLabel 'header.targetChannel')
$channelLabel.ForeColor = [System.Drawing.Color]::LightSteelBlue
[void](Set-LocFont $channelLabel -Size 8.5)
$channelLabel.Location = New-Object System.Drawing.Point(310, 70)
$channelLabel.Size = New-Object System.Drawing.Size(95, 18)
$header.Controls.Add($channelLabel)

$script:ChannelCombo = New-Object System.Windows.Forms.ComboBox
$script:ChannelCombo.Location = New-Object System.Drawing.Point(405, 67)
$script:ChannelCombo.Size = New-Object System.Drawing.Size(220, 22)
$script:ChannelCombo.DropDownStyle = 'DropDownList'
$script:ChannelCombo.FlatStyle = 'Flat'
# Channel ids run in parallel with the visible items; the label may be
# translated, the id never is.
$script:ChannelIds      = @()
$script:ChannelLabelKeys = @()
foreach ($name in $script:Channels.Keys) {
    $script:ChannelIds += $name
    if ($detectedChannels -contains $name) { $script:ChannelLabelKeys += 'channel.installed' }
    else                                   { $script:ChannelLabelKeys += 'channel.notInstalled' }
}
if ($detectedChannels.Count -gt 1) {
    $script:ChannelIds += '__ALL__'
    $script:ChannelLabelKeys += 'header.allChannels'
}
Update-ChannelComboLabels
$script:ChannelCombo.SelectedIndex = 0
$header.Controls.Add($script:ChannelCombo)

$script:TargetPathLabel = New-Object System.Windows.Forms.Label
$script:TargetPathLabel.Text = "-> $($script:Channels['Stable'].Path)"
$script:TargetPathLabel.ForeColor = [System.Drawing.Color]::Gray
$script:TargetPathLabel.Font = New-Object System.Drawing.Font('Consolas', 8)
$script:TargetPathLabel.Location = New-Object System.Drawing.Point(635, 70)
$script:TargetPathLabel.Size = New-Object System.Drawing.Size(500, 18)
$header.Controls.Add($script:TargetPathLabel)

$script:ChannelCombo.Add_SelectedIndexChanged({
    if ($script:SuppressSelectionEvents) { return }
    $id = Get-ComboId -Combo $script:ChannelCombo -Ids $script:ChannelIds
    if ($id -eq '__ALL__') {
        $script:TargetChannels = Get-DetectedChannels
        if ($script:TargetChannels.Count -eq 0) { $script:TargetChannels = @('Stable') }
        $script:BravePolicyPath = $script:Channels[$script:TargetChannels[0]].Path
        $script:TargetPathLabel.Text = T 'header.hives' @(($script:TargetChannels -join ', '), $script:TargetChannels.Count)
    } elseif ($id) {
        $script:TargetChannels = @($id)
        $script:BravePolicyPath = $script:Channels[$id].Path
        $script:TargetPathLabel.Text = "-> $($script:Channels[$id].Path)"
    }
    Write-Log "Target channel(s): $($script:TargetChannels -join ', ')"
})

# ---- Language picker --------------------------------------------------------
$lblLanguage = New-Object System.Windows.Forms.Label
$lblLanguage.ForeColor = [System.Drawing.Color]::LightSteelBlue
[void](Set-LocFont $lblLanguage -Size 8.5)
$lblLanguage.Location = New-Object System.Drawing.Point(880, 10)
$lblLanguage.Size = New-Object System.Drawing.Size(70, 18)
[void](Set-Loc $lblLanguage 'header.language')
$header.Controls.Add($lblLanguage)

$script:LocaleList = @(Get-AvailableLocales)
$script:LanguageCombo = New-Object System.Windows.Forms.ComboBox
$script:LanguageCombo.Location = New-Object System.Drawing.Point(950, 7)
$script:LanguageCombo.Size = New-Object System.Drawing.Size(170, 22)
$script:LanguageCombo.DropDownStyle = 'DropDownList'
$script:LanguageCombo.FlatStyle = 'Flat'
foreach ($loc in $script:LocaleList) { [void]$script:LanguageCombo.Items.Add($loc.Name) }
$header.Controls.Add($script:LanguageCombo)

$script:LblLocaleNote = New-Object System.Windows.Forms.Label
$script:LblLocaleNote.ForeColor = [System.Drawing.Color]::FromArgb(255, 212, 153)
[void](Set-LocFont $script:LblLocaleNote -Size 7.5)
$script:LblLocaleNote.Location = New-Object System.Drawing.Point(950, 31)
$script:LblLocaleNote.Size = New-Object System.Drawing.Size(200, 14)
$script:LblLocaleNote.Text = ''
$header.Controls.Add($script:LblLocaleNote)

function Update-LocaleNote {
    if (-not $script:LblLocaleNote) { return }
    $entry = @($script:LocaleList | Where-Object { $_.Code -eq $script:CurrentLocale })
    if ($entry.Count -gt 0 -and -not $entry[0].Reviewed -and $script:CurrentLocale -ne 'en-US') {
        $script:LblLocaleNote.Text = T 'header.unreviewedLocale'
    } else {
        $script:LblLocaleNote.Text = ''
    }
}

$script:LanguageCombo.Add_SelectedIndexChanged({
    $i = $script:LanguageCombo.SelectedIndex
    if ($i -lt 0 -or $i -ge $script:LocaleList.Count) { return }
    $code = $script:LocaleList[$i].Code
    if ($code -eq $script:CurrentLocale) { return }
    [void](Set-BfoLocale -Code $code)
    $form.Font = Get-BfoUiFont -Size 9
    Update-UiLanguage
    Update-LocaleNote
    $settings = Get-BfoSettings -Path $BfoSettingsPath
    $settings['language'] = $code
    Save-BfoSettings -Path $BfoSettingsPath -Settings $settings
    Write-Log "$(T 'msg.language.switched' @($script:LocaleList[$i].Name))" 'OK'
})

$originNote = New-Object System.Windows.Forms.Label
[void](Set-Loc $originNote 'header.originNote')
$originNote.ForeColor = [System.Drawing.Color]::FromArgb(255, 212, 153)
[void](Set-LocFont $originNote -Size 8.5)
$originNote.Location = New-Object System.Drawing.Point(20, 88)
$originNote.Size = New-Object System.Drawing.Size(950, 18)
$header.Controls.Add($originNote)

$form.Controls.Add($header)

# Mode deck
$modePanel = New-Object System.Windows.Forms.Panel
$modePanel.Location = New-Object System.Drawing.Point(10, 122)
$modePanel.Size = New-Object System.Drawing.Size(1145, 126)
$modePanel.Anchor = 'Top, Left, Right'
$modePanel.BackColor = [System.Drawing.Color]::White
$modePanel.BorderStyle = 'FixedSingle'
$form.Controls.Add($modePanel)

$modeIntro = New-Object System.Windows.Forms.Label
[void](Set-Loc $modeIntro 'mode.intro')
$modeIntro.Location = New-Object System.Drawing.Point(14, 10)
$modeIntro.Size = New-Object System.Drawing.Size(620, 18)
[void](Set-LocFont $modeIntro -Size 9 -Semibold)
$modePanel.Controls.Add($modeIntro)

# X positions are no longer hard-coded: Set-ModeButtonRow measures the
# translated caption and re-flows the row, so a longer or shorter label in
# another language cannot overlap its neighbour.
$buttonSpecs = @(
    @{Mode='Minimal';        Color=[System.Drawing.Color]::FromArgb(235, 236, 240)},
    @{Mode='Recommended';    Color=[System.Drawing.Color]::FromArgb(220, 238, 222)},
    @{Mode='Origin';         Color=[System.Drawing.Color]::FromArgb(250, 232, 210)},
    @{Mode='Performance';    Color=[System.Drawing.Color]::FromArgb(218, 231, 248)},
    @{Mode='MaxPerformance'; Color=[System.Drawing.Color]::FromArgb(255, 224, 224)},
    @{Mode='MaxPrivacy';     Color=[System.Drawing.Color]::FromArgb(229, 220, 240)},
    @{Mode='None';           Color=[System.Drawing.Color]::FromArgb(241, 241, 241)}
)
$script:ModeButtons = @()
foreach ($spec in $buttonSpecs) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Size = New-Object System.Drawing.Size(104, 30)
    $btn.Location = New-Object System.Drawing.Point(14, 34)
    $btn.BackColor = $spec.Color
    $btn.Tag = $spec.Mode
    $btn.Add_Click({ Apply-Preset $this.Tag })
    [void](Set-Loc $btn ("preset.{0}.name" -f $spec.Mode))
    [void](Set-LocTooltip $btn ("preset.{0}.description" -f $spec.Mode))
    $modePanel.Controls.Add($btn)
    $script:ModeButtons += $btn
}
Set-ModeButtonRow

$script:ModeLabel = New-Object System.Windows.Forms.Label
$script:ModeLabel.Location = New-Object System.Drawing.Point(14, 78)
$script:ModeLabel.Size = New-Object System.Drawing.Size(170, 18)
[void](Set-LocFont $script:ModeLabel -Size 9 -Semibold)
$modePanel.Controls.Add($script:ModeLabel)

$script:SelectionLabel = New-Object System.Windows.Forms.Label
$script:SelectionLabel.Location = New-Object System.Drawing.Point(190, 78)
$script:SelectionLabel.Size = New-Object System.Drawing.Size(150, 18)
$modePanel.Controls.Add($script:SelectionLabel)

$script:SystemLabel = New-Object System.Windows.Forms.Label
$script:SystemLabel.Location = New-Object System.Drawing.Point(346, 78)
$script:SystemLabel.Size = New-Object System.Drawing.Size(190, 18)
$modePanel.Controls.Add($script:SystemLabel)

$script:RiskLabel = New-Object System.Windows.Forms.Label
$script:RiskLabel.Location = New-Object System.Drawing.Point(542, 78)
$script:RiskLabel.Size = New-Object System.Drawing.Size(130, 18)
[void](Set-LocFont $script:RiskLabel -Size 9 -Semibold)
$modePanel.Controls.Add($script:RiskLabel)

$script:ModeDescription = New-Object System.Windows.Forms.Label
$script:ModeDescription.Location = New-Object System.Drawing.Point(678, 72)
$script:ModeDescription.Size = New-Object System.Drawing.Size(440, 36)
$script:ModeDescription.ForeColor = [System.Drawing.Color]::DimGray
[void](Set-LocFont $script:ModeDescription -Size 8.5)
$modePanel.Controls.Add($script:ModeDescription)

# ---- Global configuration filter -------------------------------------------
# Searches every policy, task, service and hosts group at once. The Scriptlets
# tab keeps its own scanner - it handles thousands of rows and is already tuned.
$filterPanel = New-Object System.Windows.Forms.Panel
$filterPanel.Location = New-Object System.Drawing.Point(10, 252)
$filterPanel.Size = New-Object System.Drawing.Size(1145, 32)
$filterPanel.Anchor = 'Top, Left, Right'
$form.Controls.Add($filterPanel)

$lblFilter = New-Object System.Windows.Forms.Label
$lblFilter.Location = New-Object System.Drawing.Point(4, 8)
$lblFilter.AutoSize = $true
[void](Set-LocFont $lblFilter -Size 9 -Semibold)
[void](Set-Loc $lblFilter 'filter.label')
$filterPanel.Controls.Add($lblFilter)

$script:TxtConfigFilter = New-Object System.Windows.Forms.TextBox
$script:TxtConfigFilter.Location = New-Object System.Drawing.Point(140, 5)
$script:TxtConfigFilter.Size = New-Object System.Drawing.Size(430, 22)
$script:TxtConfigFilter.Add_TextChanged({ Start-FilterDebounce })
$filterPanel.Controls.Add($script:TxtConfigFilter)
[void](Set-LocTooltip $script:TxtConfigFilter 'filter.placeholder')

$script:ChkSelectedOnly = New-Object System.Windows.Forms.CheckBox
$script:ChkSelectedOnly.Location = New-Object System.Drawing.Point(582, 6)
$script:ChkSelectedOnly.Size = New-Object System.Drawing.Size(160, 20)
$script:ChkSelectedOnly.Add_CheckedChanged({ Update-ConfigurationFilter })
[void](Set-Loc $script:ChkSelectedOnly 'filter.selectedOnly')
$filterPanel.Controls.Add($script:ChkSelectedOnly)

$btnClearFilter = New-Object System.Windows.Forms.Button
$btnClearFilter.Location = New-Object System.Drawing.Point(748, 4)
$btnClearFilter.Size = New-Object System.Drawing.Size(80, 24)
$btnClearFilter.Add_Click({ Clear-ConfigurationFilter })
[void](Set-Loc $btnClearFilter 'filter.clear')
$filterPanel.Controls.Add($btnClearFilter)

$script:LblFilterCount = New-Object System.Windows.Forms.Label
$script:LblFilterCount.Location = New-Object System.Drawing.Point(840, 8)
$script:LblFilterCount.Size = New-Object System.Drawing.Size(300, 18)
$script:LblFilterCount.ForeColor = [System.Drawing.Color]::DimGray
$filterPanel.Controls.Add($script:LblFilterCount)

# Tab control
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(10, 288)
$tabs.Size = New-Object System.Drawing.Size(1145, 418)
$tabs.Anchor = 'Top, Left, Right, Bottom'
$script:Tabs = $tabs
$form.Controls.Add($tabs)

# Track every checkbox so we can iterate on apply/reset
$script:CheckBoxes = @()
# Maps a policy Name -> its value-picker ComboBox (only for policies that
# define a Choices map, e.g. HardwareAccelerationModeEnabled). Used by
# refresh/import so the picker reflects the real registry value.
$script:PolicyCombos = @{}
$script:PolicyChoiceIds = @{}
$script:PolicyChoiceKeys = @{}
$script:PolicyCheckBoxIndex = @{}

foreach ($cat in $script:Policies.Keys) {
    $tab = New-Object System.Windows.Forms.TabPage
    # Tab caption is translated; $cat stays the stable category id and is what
    # Select all / Select none and the filter index match on.
    $tab.Name = "policyTab_$cat"
    [void](Set-Loc $tab ("category.$cat"))
    Set-FlowTabTitleKey $tab ("category.$cat")
    $tab.AutoScroll = $true
    $tab.BackColor = [System.Drawing.Color]::White

    $selAll = New-Object System.Windows.Forms.LinkLabel
    [void](Set-Loc $selAll 'policyTab.selectAll')
    $selAll.Location = New-Object System.Drawing.Point(10, 8)
    $selAll.AutoSize = $true
    $selAll.Tag = $cat
    $selAll.Add_LinkClicked({
        $myCat = $this.Tag
        Push-SuppressSelectionEvents
        try {
            foreach ($cb in $script:CheckBoxes) {
                if ($cb.Tag.Category -eq $myCat) { $cb.Checked = $true }
            }
        } finally {
            Pop-SuppressSelectionEvents
        }
        $script:ActiveProfile = 'Custom'
        Update-SelectionSummary
        Update-ConfigurationFilter
    })
    $tab.Controls.Add($selAll)

    $selNone = New-Object System.Windows.Forms.LinkLabel
    [void](Set-Loc $selNone 'policyTab.selectNone')
    $selNone.Location = New-Object System.Drawing.Point(90, 8)
    $selNone.AutoSize = $true
    $selNone.Tag = $cat
    $selNone.Add_LinkClicked({
        $myCat = $this.Tag
        Push-SuppressSelectionEvents
        try {
            foreach ($cb in $script:CheckBoxes) {
                if ($cb.Tag.Category -eq $myCat) { $cb.Checked = $false }
            }
        } finally {
            Pop-SuppressSelectionEvents
        }
        $script:ActiveProfile = 'Custom'
        Update-SelectionSummary
        Update-ConfigurationFilter
    })
    $tab.Controls.Add($selNone)

    $y = 35
    foreach ($p in $script:Policies[$cat]) {
        $cb = New-Object System.Windows.Forms.CheckBox
        # The caption is the raw registry value name. It is deliberately NOT
        # translated: users cross-check it against brave://policy, and the
        # Consolas face has no CJK coverage anyway. Only the description is
        # localized.
        if ($p.Choices) { $cb.Text = $p.Name } else { $cb.Text = "$($p.Name)    =>  $($p.ApplyValue)" }
        $cb.Location = New-Object System.Drawing.Point(15, $y)
        $cb.Size = New-Object System.Drawing.Size(($(if ($p.Choices) { 300 } else { 450 })), 20)
        $cb.Font = New-Object System.Drawing.Font('Consolas', 9)
        $cb.Tag = @{Policy = $p; Category = $cat}
        $cb.Add_CheckedChanged({
            if ($script:SuppressSelectionEvents) { return }
            Set-CustomMode
            Update-ConfigurationFilter
        })
        [void](Set-LocTooltip $cb ("policy.$($p.Name).description"))
        $tab.Controls.Add($cb)
        $script:CheckBoxes += $cb
        $rowControls = @($cb)

        # Value picker for choice-based policies. Selecting an item rewrites the
        # policy's ApplyValue in place, so every downstream path (apply, verify,
        # export) automatically uses the chosen value with no extra plumbing.
        if ($p.Choices) {
            $combo = New-Object System.Windows.Forms.ComboBox
            $combo.DropDownStyle = 'DropDownList'
            $combo.Location = New-Object System.Drawing.Point(320, ($y - 1))
            $combo.Size = New-Object System.Drawing.Size(140, 22)
            $combo.Font = New-Object System.Drawing.Font('Consolas', 9)
            $choiceIds  = @($p.Choices.Keys)
            $choiceKeys = @($choiceIds | ForEach-Object { "policy.$($p.Name).choice.$_" })
            $script:PolicyChoiceIds[$p.Name] = $choiceIds
            $script:PolicyChoiceKeys[$p.Name] = $choiceKeys
            Set-ComboLabels -Combo $combo -Ids $choiceIds -LabelKeys $choiceKeys
            $script:PolicyCombos[$p.Name] = $combo
            # Preselect the id whose value matches the current ApplyValue.
            foreach ($cid in $choiceIds) {
                if ("$($p.Choices[$cid])" -eq "$($p.ApplyValue)") {
                    [void](Set-PolicyChoiceId -Policy $p -ChoiceId $cid); break
                }
            }
            if ($combo.SelectedIndex -lt 0) { $combo.SelectedIndex = 0 }
            $combo.Tag = $p
            # Gated: relabelling the picker for a new language clears and
            # refills Items, which would otherwise land here with a transient
            # SelectedIndex of -1 and then flip the profile to Custom.
            $combo.Add_SelectedIndexChanged({
                if ($script:SuppressSelectionEvents) { return }
                $pol = $this.Tag
                $cid = Get-ComboId -Combo $this -Ids $script:PolicyChoiceIds[$pol.Name]
                if (-not $cid) { return }
                # Set-PolicyChoiceId writes the picker back as well as the
                # value. Assigning the index it already holds does not raise
                # the event again, but muting makes that structural rather
                # than a WinForms detail we are relying on.
                Push-SuppressSelectionEvents
                try { [void](Set-PolicyChoiceId -Policy $pol -ChoiceId $cid) }
                finally { Pop-SuppressSelectionEvents }
                Set-CustomMode
            })
            [void](Set-LocTooltip $combo ("policy.$($p.Name).description"))
            $tab.Controls.Add($combo)
            $rowControls += $combo
        }

        $desc = New-Object System.Windows.Forms.Label
        $desc.Location = New-Object System.Drawing.Point(475, ($y + 2))
        $desc.Size = New-Object System.Drawing.Size(630, (Get-PolicyDescHeight))
        $desc.ForeColor = [System.Drawing.Color]::DimGray
        $desc.Font = Get-BfoUiFont -Size (Get-PolicyDescFontSize)
        [void](Set-Loc $desc ("policy.$($p.Name).description"))
        $tab.Controls.Add($desc)
        [void]$script:RowDescLabels.Add($desc)
        $rowControls += $desc

        $policyName = $p.Name
        $categoryId = $cat
        Register-FlowEntry -TabPage $tab -Kind 'Row' -Controls $rowControls -BaseTop $y `
            -Height 28 -CjkExtra 8 -Group 'policies' -Id $policyName -Type 'Policy' -CategoryId $cat `
            -SearchText ([scriptblock]::Create("@('$policyName', (T 'policy.$policyName.description'), (T 'category.$categoryId')) -join ' '")) `
            -IsSelected ([scriptblock]::Create('$script:PolicyCheckBoxIndex[''' + $policyName + '''].Checked'))
        $script:PolicyCheckBoxIndex[$policyName] = $cb

        $y += 28
    }
    $tabs.TabPages.Add($tab)
}

# ---- System tab: scheduled tasks + services --------------------------------
$sysTab = New-Object System.Windows.Forms.TabPage
$sysTab.Name = 'sysTab'
[void](Set-Loc $sysTab 'tab.system')
Set-FlowTabTitleKey $sysTab 'tab.system'
$sysTab.AutoScroll = $true
$sysTab.BackColor = [System.Drawing.Color]::White

$sysIntro = New-Object System.Windows.Forms.Label
[void](Set-Loc $sysIntro 'system.intro')
[void](Set-LocFont $sysIntro -Size 9)
$sysIntro.Location = New-Object System.Drawing.Point(10, 8)
$sysIntro.Size = New-Object System.Drawing.Size(1080, 30)
$sysIntro.ForeColor = [System.Drawing.Color]::FromArgb(120, 50, 50)
$sysTab.Controls.Add($sysIntro)

$script:TaskCheckBoxes = @()
$script:TaskCheckBoxIndex = @{}
$script:ServiceCheckBoxIndex = @{}
$y = 50
$taskHdr = New-Object System.Windows.Forms.Label
[void](Set-Loc $taskHdr 'system.tasksHdr')
[void](Set-LocFont $taskHdr -Size 10 -Semibold)
$taskHdr.Location = New-Object System.Drawing.Point(10, $y)
$taskHdr.AutoSize = $true
$sysTab.Controls.Add($taskHdr)
Register-FlowEntry -TabPage $sysTab -Kind 'Header' -Controls @($taskHdr) -BaseTop $y -Height 28 -Group 'tasks'
$y += 28
foreach ($t in $script:ScheduledTasks) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $t.Name
    $cb.Location = New-Object System.Drawing.Point(15, $y)
    $cb.Size = New-Object System.Drawing.Size(450, 20)
    $cb.Font = New-Object System.Drawing.Font('Consolas', 9)
    $cb.Tag = $t
    $cb.Add_CheckedChanged({
        if ($script:SuppressSelectionEvents) { return }
        Set-CustomMode
        Update-ConfigurationFilter
    })
    [void](Set-LocTooltip $cb ("task.$($t.Name).description"))
    $sysTab.Controls.Add($cb)
    $script:TaskCheckBoxes += $cb

    $desc = New-Object System.Windows.Forms.Label
    $desc.Location = New-Object System.Drawing.Point(475, ($y + 2))
    $desc.Size = New-Object System.Drawing.Size(630, (Get-PolicyDescHeight))
    $desc.ForeColor = [System.Drawing.Color]::DimGray
    $desc.Font = Get-BfoUiFont -Size (Get-PolicyDescFontSize)
    [void](Set-Loc $desc ("task.$($t.Name).description"))
    $sysTab.Controls.Add($desc)
    [void]$script:RowDescLabels.Add($desc)

    $taskName = $t.Name
    Register-FlowEntry -TabPage $sysTab -Kind 'Row' -Controls @($cb, $desc) -BaseTop $y `
        -Height 28 -CjkExtra 8 -Group 'tasks' -Id $taskName -Type 'ScheduledTask' `
        -SearchText ([scriptblock]::Create("@('$taskName', (T 'task.$taskName.description'), (T 'system.tasksHdr')) -join ' '")) `
        -IsSelected ([scriptblock]::Create('$script:TaskCheckBoxIndex[''' + $taskName + '''].Checked'))
    $script:TaskCheckBoxIndex[$taskName] = $cb
    $y += 28
}

$script:ServiceCheckBoxes = @()
$y += 15
$svcHdr = New-Object System.Windows.Forms.Label
[void](Set-Loc $svcHdr 'system.svcHdr')
[void](Set-LocFont $svcHdr -Size 10 -Semibold)
$svcHdr.Location = New-Object System.Drawing.Point(10, $y)
$svcHdr.AutoSize = $true
$sysTab.Controls.Add($svcHdr)
# BaseTop is 15px above the header so the visual gap re-flows with it.
Register-FlowEntry -TabPage $sysTab -Kind 'Header' -Controls @($svcHdr) -BaseTop ($y - 15) -Height 43 -Group 'services'
$y += 28
foreach ($s in $script:Services) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $s.Name
    $cb.Location = New-Object System.Drawing.Point(15, $y)
    $cb.Size = New-Object System.Drawing.Size(450, 20)
    $cb.Font = New-Object System.Drawing.Font('Consolas', 9)
    $cb.Tag = $s
    $cb.Add_CheckedChanged({
        if ($script:SuppressSelectionEvents) { return }
        Set-CustomMode
        Update-ConfigurationFilter
    })
    [void](Set-LocTooltip $cb ("service.$($s.Name).description"))
    $sysTab.Controls.Add($cb)
    $script:ServiceCheckBoxes += $cb

    $desc = New-Object System.Windows.Forms.Label
    $desc.Location = New-Object System.Drawing.Point(475, ($y + 2))
    $desc.Size = New-Object System.Drawing.Size(630, (Get-PolicyDescHeight))
    $desc.ForeColor = [System.Drawing.Color]::DimGray
    $desc.Font = Get-BfoUiFont -Size (Get-PolicyDescFontSize)
    [void](Set-Loc $desc ("service.$($s.Name).description"))
    $sysTab.Controls.Add($desc)
    [void]$script:RowDescLabels.Add($desc)

    $svcName = $s.Name
    Register-FlowEntry -TabPage $sysTab -Kind 'Row' -Controls @($cb, $desc) -BaseTop $y `
        -Height 28 -CjkExtra 8 -Group 'services' -Id $svcName -Type 'Service' `
        -SearchText ([scriptblock]::Create("@('$svcName', (T 'service.$svcName.description'), (T 'system.svcHdr')) -join ' '")) `
        -IsSelected ([scriptblock]::Create('$script:ServiceCheckBoxIndex[''' + $svcName + '''].Checked'))
    $script:ServiceCheckBoxIndex[$svcName] = $cb
    $y += 28
}

$tabs.TabPages.Add($sysTab)

# ---- Hosts blocklist tab (v1.5) --------------------------------------------
# Independent from the main Apply button - has its own Apply/Remove inside the tab.
# Sentinel-tagged so revert is surgical. Auto-backs up hosts file before any write.
$hostsTab = New-Object System.Windows.Forms.TabPage
$hostsTab.Name = 'hostsTab'
[void](Set-Loc $hostsTab 'tab.hosts')
Set-FlowTabTitleKey $hostsTab 'tab.hosts'
$hostsTab.AutoScroll = $true
$hostsTab.BackColor = [System.Drawing.Color]::White

$hostsIntro = New-Object System.Windows.Forms.Label
[void](Set-Loc $hostsIntro 'hostsTab.intro')
[void](Set-LocFont $hostsIntro -Size 9)
$hostsIntro.Location = New-Object System.Drawing.Point(10, 8)
$hostsIntro.Size = New-Object System.Drawing.Size(1100, 36)
$hostsIntro.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 90)
$hostsTab.Controls.Add($hostsIntro)

$hostsWarn = New-Object System.Windows.Forms.Label
[void](Set-Loc $hostsWarn 'hostsTab.warn')
$hostsWarn.Location = New-Object System.Drawing.Point(10, 44)
$hostsWarn.Size = New-Object System.Drawing.Size(1100, 18)
$hostsWarn.ForeColor = [System.Drawing.Color]::FromArgb(160, 70, 30)
[void](Set-LocFont $hostsWarn -Size 8.5 -Semibold)
$hostsTab.Controls.Add($hostsWarn)

$script:HostsCheckBoxes = @()
$y = 70
$script:HostsCheckBoxIndex = @{}
foreach ($block in $script:HostsBlocks) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Location = New-Object System.Drawing.Point(15, $y)
    $cb.Size = New-Object System.Drawing.Size(360, 20)
    [void](Set-LocFont $cb -Size 9)
    $cb.Checked = [bool]$block.Recommended
    $cb.Tag = $block
    $cb.Add_CheckedChanged({
        if ($script:SuppressSelectionEvents) { return }
        Update-ConfigurationFilter
    })
    # ArgsScript re-evaluates the group name at switch time, so the domain
    # count and the translated name stay in sync.
    [void](Set-Loc $cb 'hostsTab.groupLabel' -ArgsScript ([scriptblock]::Create(
        "@((T '$($block.NameKey)'), $($block.Domains.Count))")))
    [void](Set-LocTooltip $cb $block.DescriptionKey)
    $hostsTab.Controls.Add($cb)
    $script:HostsCheckBoxes += $cb

    $desc = New-Object System.Windows.Forms.Label
    $desc.Location = New-Object System.Drawing.Point(385, ($y + 2))
    # Same height rule as every other row description, so the initial build
    # and a later language switch agree on the geometry.
    $desc.Size = New-Object System.Drawing.Size(720, (Get-PolicyDescHeight))
    $desc.ForeColor = [System.Drawing.Color]::DimGray
    $desc.Font = Get-BfoUiFont -Size (Get-PolicyDescFontSize)
    [void](Set-Loc $desc $block.DescriptionKey)
    $hostsTab.Controls.Add($desc)
    [void]$script:RowDescLabels.Add($desc)

    $domLabel = New-Object System.Windows.Forms.Label
    $domLabel.Text = ($block.Domains -join ', ')
    $domLabel.Location = New-Object System.Drawing.Point(35, ($y + 22))
    $domLabel.Size = New-Object System.Drawing.Size(340, 16)
    $domLabel.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $domLabel.Font = New-Object System.Drawing.Font('Consolas', 8)
    $hostsTab.Controls.Add($domLabel)

    $blockId = $block.Id
    $nameKey = $block.NameKey
    $descKey = $block.DescriptionKey
    $domainText = ($block.Domains -join ' ')
    Register-FlowEntry -TabPage $hostsTab -Kind 'Row' -Controls @($cb, $desc, $domLabel) -BaseTop $y `
        -Height 44 -CjkExtra 6 -Group 'hosts' -Id $blockId -Type 'HostBlock' `
        -SearchText ([scriptblock]::Create("@('$blockId', (T '$nameKey'), (T '$descKey'), '$domainText') -join ' '")) `
        -IsSelected ([scriptblock]::Create('$script:HostsCheckBoxIndex[''' + $blockId + '''].Checked'))
    $script:HostsCheckBoxIndex[$blockId] = $cb

    $y += 44
}

$btnApplyHosts = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnApplyHosts 'hostsTab.apply')
$btnApplyHosts.Size = New-Object System.Drawing.Size(160, 30)
$btnApplyHosts.Location = New-Object System.Drawing.Point(15, ($y + 10))
$btnApplyHosts.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 63)
$btnApplyHosts.ForeColor = [System.Drawing.Color]::White
$btnApplyHosts.Add_Click({
    $domains = @()
    foreach ($cb in $script:HostsCheckBoxes) {
        if ($cb.Checked) { $domains += $cb.Tag.Domains }
    }
    if ($domains.Count -eq 0) {
        $ans = [System.Windows.Forms.MessageBox]::Show(
            (T 'msg.hosts.noGroups'),
            (T 'msg.title.hosts'), 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }
    } else {
        $msg = T 'msg.hosts.confirmApply' @($domains.Count, $script:HostsFile)
        $ans = [System.Windows.Forms.MessageBox]::Show($msg, (T 'msg.title.hosts'), 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }
    }
    try {
        Set-HostsBlockDomains -Domains $domains
        [System.Windows.Forms.MessageBox]::Show((T 'msg.hosts.applied' @($domains.Count)), (T 'msg.title.done'), 'OK', 'Information') | Out-Null
    } catch {
        Write-Log "Hosts apply failed: $_" 'ERR'
        [System.Windows.Forms.MessageBox]::Show((T 'msg.failed' @("$_")), (T 'msg.title.error'), 'OK', 'Error') | Out-Null
    }
})
$hostsTab.Controls.Add($btnApplyHosts)

$btnClearHosts = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnClearHosts 'hostsTab.remove')
$btnClearHosts.Size = New-Object System.Drawing.Size(160, 30)
$btnClearHosts.Location = New-Object System.Drawing.Point(185, ($y + 10))
$btnClearHosts.Add_Click({
    $ans = [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.hosts.confirmRemove'),
        (T 'msg.title.hosts'), 'YesNo', 'Warning')
    if ($ans -ne 'Yes') { return }
    try {
        Clear-HostsBlock
        foreach ($cb in $script:HostsCheckBoxes) { $cb.Checked = $false }
        [System.Windows.Forms.MessageBox]::Show((T 'msg.hosts.removed'), (T 'msg.title.done'), 'OK', 'Information') | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show((T 'msg.failed' @("$_")), (T 'msg.title.error'), 'OK', 'Error') | Out-Null
    }
})
$hostsTab.Controls.Add($btnClearHosts)

$btnLoadHosts = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnLoadHosts 'hostsTab.load')
$btnLoadHosts.Size = New-Object System.Drawing.Size(160, 30)
$btnLoadHosts.Location = New-Object System.Drawing.Point(355, ($y + 10))
$btnLoadHosts.Add_Click({
    $current = Get-HostsCurrentDomains
    foreach ($cb in $script:HostsCheckBoxes) {
        $blockDomains = $cb.Tag.Domains
        $allPresent = $true
        foreach ($d in $blockDomains) { if ($current -notcontains $d) { $allPresent = $false; break } }
        $cb.Checked = $allPresent
    }
    Write-Log "Hosts state loaded: $($current.Count) domain(s) currently blocked."
})
$hostsTab.Controls.Add($btnLoadHosts)

$btnPreviewHosts = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnPreviewHosts 'hostsTab.preview')
$btnPreviewHosts.Size = New-Object System.Drawing.Size(130, 30)
$btnPreviewHosts.Location = New-Object System.Drawing.Point(525, ($y + 10))
$btnPreviewHosts.Add_Click({
    Show-TextReport -Title (T 'report.hostsTitle') -Text (New-HostsPlanReport) -DefaultFileName "brave-free-origin-hosts-preview-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
})
$hostsTab.Controls.Add($btnPreviewHosts)

$btnOpenHosts = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnOpenHosts 'hostsTab.open')
$btnOpenHosts.Size = New-Object System.Drawing.Size(140, 30)
$btnOpenHosts.Location = New-Object System.Drawing.Point(665, ($y + 10))
$btnOpenHosts.Add_Click({ Start-Process notepad.exe $script:HostsFile })
$hostsTab.Controls.Add($btnOpenHosts)

# The button strip flows after the group rows so filtering does not leave a
# hole between the last visible group and the actions.
Register-FlowEntry -TabPage $hostsTab -Kind 'Trailer' `
    -Controls @($btnApplyHosts, $btnClearHosts, $btnLoadHosts, $btnPreviewHosts, $btnOpenHosts) `
    -BaseTop $y -Height 50 -Group 'hosts'

$tabs.TabPages.Add($hostsTab)

# ---- Default scriptlets tab (v1.11) ----------------------------------------
# Advanced, optional, and deliberately separate from presets/main Apply.
# Scans Brave component filter lists, displays ##+js(...) rules, and can
# comment/uncomment rules with a BFO marker after explicit user opt-in.
$scriptletsTab = New-Object System.Windows.Forms.TabPage
$scriptletsTab.Name = 'scriptletsTab'
[void](Set-Loc $scriptletsTab 'tab.scriptlets')
$scriptletsTab.AutoScroll = $true
$scriptletsTab.BackColor = [System.Drawing.Color]::White

$scriptletIntro = New-Object System.Windows.Forms.Label
[void](Set-Loc $scriptletIntro 'scriptlet.intro')
[void](Set-LocFont $scriptletIntro -Size 9)
$scriptletIntro.Location = New-Object System.Drawing.Point(10, 8)
$scriptletIntro.Size = New-Object System.Drawing.Size(1100, 34)
$scriptletIntro.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 90)
$scriptletsTab.Controls.Add($scriptletIntro)

$scriptletRisk = New-Object System.Windows.Forms.Label
[void](Set-Loc $scriptletRisk 'scriptlet.risk')
$scriptletRisk.Location = New-Object System.Drawing.Point(10, 38)
$scriptletRisk.Size = New-Object System.Drawing.Size(1100, 34)
$scriptletRisk.ForeColor = [System.Drawing.Color]::FromArgb(160, 70, 30)
[void](Set-LocFont $scriptletRisk -Size 8.5 -Semibold)
$scriptletsTab.Controls.Add($scriptletRisk)

$lblScriptletRoot = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblScriptletRoot 'scriptlet.rootLabel')
[void](Set-LocFont $lblScriptletRoot -Size 9)
$lblScriptletRoot.Location = New-Object System.Drawing.Point(10, 80)
$lblScriptletRoot.Size = New-Object System.Drawing.Size(145, 18)
$scriptletsTab.Controls.Add($lblScriptletRoot)

$script:TxtScriptletRoot = New-Object System.Windows.Forms.TextBox
$script:TxtScriptletRoot.Location = New-Object System.Drawing.Point(155, 76)
$script:TxtScriptletRoot.Size = New-Object System.Drawing.Size(560, 22)
$script:TxtScriptletRoot.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$script:TxtScriptletRoot.Text = Get-ScriptletDefaultRoot
$scriptletsTab.Controls.Add($script:TxtScriptletRoot)

$btnScriptletAutoRoot = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnScriptletAutoRoot 'scriptlet.autoPath')
$btnScriptletAutoRoot.Size = New-Object System.Drawing.Size(85, 26)
$btnScriptletAutoRoot.Location = New-Object System.Drawing.Point(725, 74)
$btnScriptletAutoRoot.Add_Click({
    $script:TxtScriptletRoot.Text = Get-ScriptletDefaultRoot
    Write-Log "Scriptlet User Data path set to: $($script:TxtScriptletRoot.Text)"
})
$scriptletsTab.Controls.Add($btnScriptletAutoRoot)

$btnScriptletBrowse = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnScriptletBrowse 'scriptlet.browse')
$btnScriptletBrowse.Size = New-Object System.Drawing.Size(85, 26)
$btnScriptletBrowse.Location = New-Object System.Drawing.Point(815, 74)
$btnScriptletBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = T 'dialog.browseUserData'
    if (Test-Path $script:TxtScriptletRoot.Text) { $dlg.SelectedPath = $script:TxtScriptletRoot.Text }
    if ($dlg.ShowDialog() -eq 'OK') {
        $script:TxtScriptletRoot.Text = $dlg.SelectedPath
        Write-Log "Scriptlet User Data path set manually: $($dlg.SelectedPath)"
    }
})
$scriptletsTab.Controls.Add($btnScriptletBrowse)

$script:BtnScriptletScan = New-Object System.Windows.Forms.Button
[void](Set-Loc $script:BtnScriptletScan 'scriptlet.scan')
$script:BtnScriptletScan.Size = New-Object System.Drawing.Size(80, 26)
$script:BtnScriptletScan.Location = New-Object System.Drawing.Point(905, 74)
$script:BtnScriptletScan.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 63)
$script:BtnScriptletScan.ForeColor = [System.Drawing.Color]::White
$script:BtnScriptletScan.Add_Click({ Invoke-ScriptletScan })
$scriptletsTab.Controls.Add($script:BtnScriptletScan)

$btnScriptletOpenFolder = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnScriptletOpenFolder 'scriptlet.openFolder')
$btnScriptletOpenFolder.Size = New-Object System.Drawing.Size(95, 26)
$btnScriptletOpenFolder.Location = New-Object System.Drawing.Point(990, 74)
$btnScriptletOpenFolder.Add_Click({
    if (Test-Path $script:TxtScriptletRoot.Text) { Start-Process explorer.exe $script:TxtScriptletRoot.Text }
    else { [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.folderMissing'), (T 'msg.title.scriptlet'), 'OK', 'Warning') | Out-Null }
})
$scriptletsTab.Controls.Add($btnScriptletOpenFolder)

$lblScriptletSearch = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblScriptletSearch 'scriptlet.searchLabel')
[void](Set-LocFont $lblScriptletSearch -Size 9)
$lblScriptletSearch.Location = New-Object System.Drawing.Point(10, 112)
$lblScriptletSearch.Size = New-Object System.Drawing.Size(85, 18)
$scriptletsTab.Controls.Add($lblScriptletSearch)

$script:TxtScriptletSearch = New-Object System.Windows.Forms.TextBox
$script:TxtScriptletSearch.Location = New-Object System.Drawing.Point(95, 108)
$script:TxtScriptletSearch.Size = New-Object System.Drawing.Size(360, 22)
$script:TxtScriptletSearch.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$script:TxtScriptletSearch.Add_TextChanged({ Start-ScriptletFilterDelay })
$script:TxtScriptletSearch.Add_KeyDown({
    if ($_.KeyCode -eq 'Enter') {
        if ($script:ScriptletFilterTimer) { $script:ScriptletFilterTimer.Stop() }
        Update-ScriptletListView
        $_.SuppressKeyPress = $true
    }
})
$scriptletsTab.Controls.Add($script:TxtScriptletSearch)

$script:ScriptletFilterTimer = New-Object System.Windows.Forms.Timer
$script:ScriptletFilterTimer.Interval = 250
$script:ScriptletFilterTimer.Add_Tick({
    $script:ScriptletFilterTimer.Stop()
    Update-ScriptletListView
})

$script:BtnScriptletFilter = New-Object System.Windows.Forms.Button
[void](Set-Loc $script:BtnScriptletFilter 'scriptlet.filter')
$script:BtnScriptletFilter.Size = New-Object System.Drawing.Size(75, 26)
$script:BtnScriptletFilter.Location = New-Object System.Drawing.Point(465, 106)
$script:BtnScriptletFilter.Add_Click({
    if ($script:ScriptletFilterTimer) { $script:ScriptletFilterTimer.Stop() }
    Update-ScriptletListView
})
$scriptletsTab.Controls.Add($script:BtnScriptletFilter)

$script:ChkScriptletDisabledOnly = New-Object System.Windows.Forms.CheckBox
[void](Set-Loc $script:ChkScriptletDisabledOnly 'scriptlet.disabledOnly')
$script:ChkScriptletDisabledOnly.Location = New-Object System.Drawing.Point(550, 110)
$script:ChkScriptletDisabledOnly.Size = New-Object System.Drawing.Size(190, 20)
$script:ChkScriptletDisabledOnly.Add_CheckedChanged({ Update-ScriptletListView })
$scriptletsTab.Controls.Add($script:ChkScriptletDisabledOnly)

$script:ChkScriptletAdvanced = New-Object System.Windows.Forms.CheckBox
[void](Set-Loc $script:ChkScriptletAdvanced 'scriptlet.advancedMode')
$script:ChkScriptletAdvanced.Location = New-Object System.Drawing.Point(755, 110)
$script:ChkScriptletAdvanced.Size = New-Object System.Drawing.Size(330, 20)
$script:ChkScriptletAdvanced.ForeColor = [System.Drawing.Color]::FromArgb(150, 60, 60)
$scriptletsTab.Controls.Add($script:ChkScriptletAdvanced)

$script:ScriptletList = New-Object System.Windows.Forms.ListView
$script:ScriptletList.Location = New-Object System.Drawing.Point(10, 140)
$script:ScriptletList.Size = New-Object System.Drawing.Size(1110, 190)
$script:ScriptletList.View = 'Details'
$script:ScriptletList.FullRowSelect = $true
$script:ScriptletList.GridLines = $true
$script:ScriptletList.MultiSelect = $true
$script:ScriptletList.HideSelection = $false
$script:ScriptletList.CheckBoxes = $true
$script:ScriptletList.Anchor = 'Top, Left, Right'
$script:ScriptletList.Add_SizeChanged({ Resize-ScriptletColumns })
$script:ScriptletList.Add_ItemChecked({
    param($sender, $eventArgs)

    if (-not $script:SuppressScriptletStatusEvents) {
        Set-ScriptletRecordChecked -Record $eventArgs.Item.Tag -Checked $eventArgs.Item.Checked
        Update-ScriptletStatusText
    }
})
[void]$script:ScriptletList.Columns.Add((T 'scriptlet.col.pick'), 96)
[void]$script:ScriptletList.Columns.Add((T 'scriptlet.col.domain'), 190)
[void]$script:ScriptletList.Columns.Add((T 'scriptlet.col.scriptlet'), 190)
[void]$script:ScriptletList.Columns.Add((T 'scriptlet.col.arguments'), 260)
[void]$script:ScriptletList.Columns.Add((T 'scriptlet.col.source'), 180)
[void]$script:ScriptletList.Columns.Add((T 'scriptlet.col.line'), 55)
[void]$script:ScriptletList.Columns.Add((T 'scriptlet.col.rawRule'), 520)
$scriptletsTab.Controls.Add($script:ScriptletList)

$script:LblScriptletStatus = New-Object System.Windows.Forms.Label
[void](Set-Loc $script:LblScriptletStatus 'scriptlet.statusIdle')
[void](Set-LocFont $script:LblScriptletStatus -Size 9)
$script:LblScriptletStatus.Location = New-Object System.Drawing.Point(10, 336)
$script:LblScriptletStatus.Size = New-Object System.Drawing.Size(520, 18)
$script:LblScriptletStatus.ForeColor = [System.Drawing.Color]::DimGray
$scriptletsTab.Controls.Add($script:LblScriptletStatus)

$script:ScriptletProgress = New-Object System.Windows.Forms.ProgressBar
$script:ScriptletProgress.Location = New-Object System.Drawing.Point(545, 336)
$script:ScriptletProgress.Size = New-Object System.Drawing.Size(575, 16)
$script:ScriptletProgress.Minimum = 0
$script:ScriptletProgress.Maximum = 1000
$script:ScriptletProgress.Value = 0
$script:ScriptletProgress.Style = 'Continuous'
$script:ScriptletProgress.Anchor = 'Top, Left, Right'
$scriptletsTab.Controls.Add($script:ScriptletProgress)

$script:ChkScriptletAffectDuplicates = New-Object System.Windows.Forms.CheckBox
[void](Set-Loc $script:ChkScriptletAffectDuplicates 'scriptlet.affectDupes')
$script:ChkScriptletAffectDuplicates.Checked = $true
$script:ChkScriptletAffectDuplicates.Location = New-Object System.Drawing.Point(10, 360)
$script:ChkScriptletAffectDuplicates.Size = New-Object System.Drawing.Size(270, 20)
[void](Set-LocTooltip $script:ChkScriptletAffectDuplicates 'scriptlet.tipAffectDupes')
$scriptletsTab.Controls.Add($script:ChkScriptletAffectDuplicates)

$script:BtnScriptletCheckVisible = New-Object System.Windows.Forms.Button
[void](Set-Loc $script:BtnScriptletCheckVisible 'scriptlet.checkFiltered')
$script:BtnScriptletCheckVisible.Size = New-Object System.Drawing.Size(125, 26)
$script:BtnScriptletCheckVisible.Location = New-Object System.Drawing.Point(290, 356)
$script:BtnScriptletCheckVisible.Add_Click({ Set-ScriptletVisibleChecks $true })
[void](Set-LocTooltip $script:BtnScriptletCheckVisible 'scriptlet.tipCheckFiltered')
$scriptletsTab.Controls.Add($script:BtnScriptletCheckVisible)

$script:BtnScriptletClearChecks = New-Object System.Windows.Forms.Button
[void](Set-Loc $script:BtnScriptletClearChecks 'scriptlet.clearChecks')
$script:BtnScriptletClearChecks.Size = New-Object System.Drawing.Size(105, 26)
$script:BtnScriptletClearChecks.Location = New-Object System.Drawing.Point(425, 356)
$script:BtnScriptletClearChecks.Add_Click({ Set-ScriptletVisibleChecks $false })
$scriptletsTab.Controls.Add($script:BtnScriptletClearChecks)

$script:BtnScriptletDisable = New-Object System.Windows.Forms.Button
[void](Set-Loc $script:BtnScriptletDisable 'scriptlet.disableChecked')
$script:BtnScriptletDisable.Size = New-Object System.Drawing.Size(125, 28)
$script:BtnScriptletDisable.Location = New-Object System.Drawing.Point(10, 388)
$script:BtnScriptletDisable.BackColor = [System.Drawing.Color]::FromArgb(150, 60, 60)
$script:BtnScriptletDisable.ForeColor = [System.Drawing.Color]::White
$script:BtnScriptletDisable.Add_Click({
    $records = @(Get-SelectedScriptletRecords)
    if ($records.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.selectFirst'), (T 'msg.title.scriptlet'), 'OK', 'Information') | Out-Null; return }
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    $ans = [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.scriptlet.confirmDisable' @($records.Count, $script:ScriptletDisablePrefix)),
        (T 'msg.title.scriptlet'),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($ans -ne 'Yes') { return }
    try {
        $changed = Set-ScriptletRuleState -Records $records -Enable:$false -AffectDuplicates:$script:ChkScriptletAffectDuplicates.Checked
        Write-Log "Scriptlets disabled: $changed line(s)." 'OK'
        Invoke-ScriptletScan
    } catch {
        Write-Log "Scriptlet disable failed: $_" 'ERR'
        [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.disableFailed' @("$_")), (T 'msg.title.scriptlet'), 'OK', 'Error') | Out-Null
    }
})
$scriptletsTab.Controls.Add($script:BtnScriptletDisable)

$script:BtnScriptletEnable = New-Object System.Windows.Forms.Button
[void](Set-Loc $script:BtnScriptletEnable 'scriptlet.enableChecked')
$script:BtnScriptletEnable.Size = New-Object System.Drawing.Size(120, 28)
$script:BtnScriptletEnable.Location = New-Object System.Drawing.Point(145, 388)
$script:BtnScriptletEnable.Add_Click({
    $records = @(Get-SelectedScriptletRecords)
    if ($records.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.selectFirst'), (T 'msg.title.scriptlet'), 'OK', 'Information') | Out-Null; return }
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    try {
        $changed = Set-ScriptletRuleState -Records $records -Enable:$true -AffectDuplicates:$script:ChkScriptletAffectDuplicates.Checked
        Write-Log "Scriptlets enabled: $changed line(s)." 'OK'
        Invoke-ScriptletScan
    } catch {
        Write-Log "Scriptlet enable failed: $_" 'ERR'
        [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.enableFailed' @("$_")), (T 'msg.title.scriptlet'), 'OK', 'Error') | Out-Null
    }
})
$scriptletsTab.Controls.Add($script:BtnScriptletEnable)

$btnScriptletDetails = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnScriptletDetails 'scriptlet.viewSelected')
$btnScriptletDetails.Size = New-Object System.Drawing.Size(115, 28)
$btnScriptletDetails.Location = New-Object System.Drawing.Point(275, 388)
$btnScriptletDetails.Add_Click({
    $records = @(Get-SelectedScriptletRecords)
    if ($records.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.selectOne'), (T 'msg.title.scriptlet'), 'OK', 'Information') | Out-Null; return }
    $report = New-Object System.Text.StringBuilder
    foreach ($r in $records) {
        [void]$report.AppendLine("Enabled: $($r.Enabled)")
        [void]$report.AppendLine("Domain: $($r.Domain)")
        [void]$report.AppendLine("Scriptlet: $($r.Scriptlet)")
        [void]$report.AppendLine("Arguments: $($r.Arguments)")
        [void]$report.AppendLine("Source: $($r.Source) $($r.Version)")
        [void]$report.AppendLine("File: $($r.File)")
        [void]$report.AppendLine("Line: $($r.LineNumber)")
        [void]$report.AppendLine("Rule: $($r.Rule)")
        [void]$report.AppendLine('')
    }
    Show-TextReport -Title (T 'report.scriptletTitle') -Text ($report.ToString()) -DefaultFileName "brave-free-origin-scriptlet-details-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
})
$scriptletsTab.Controls.Add($btnScriptletDetails)

$btnScriptletBackupAll = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnScriptletBackupAll 'scriptlet.backupAll')
$btnScriptletBackupAll.Size = New-Object System.Drawing.Size(120, 28)
$btnScriptletBackupAll.Location = New-Object System.Drawing.Point(400, 388)
$btnScriptletBackupAll.Add_Click({
    try {
        $files = @($script:ScriptletRules | Select-Object -ExpandProperty File -Unique)
        if ($files.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.scanFirst'), (T 'msg.title.scriptlet'), 'OK', 'Information') | Out-Null; return }
        foreach ($file in $files) { [void](Backup-ScriptletFile -File $file) }
        [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.backupDone' @($files.Count)), (T 'msg.title.scriptlet'), 'OK', 'Information') | Out-Null
    } catch {
        Write-Log "Scriptlet backup failed: $_" 'ERR'
        [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.backupFailed' @("$_")), (T 'msg.title.scriptlet'), 'OK', 'Error') | Out-Null
    }
})
$scriptletsTab.Controls.Add($btnScriptletBackupAll)

$btnScriptletRestoreSelected = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnScriptletRestoreSelected 'scriptlet.restoreSelected')
$btnScriptletRestoreSelected.Size = New-Object System.Drawing.Size(145, 28)
$btnScriptletRestoreSelected.Location = New-Object System.Drawing.Point(530, 388)
$btnScriptletRestoreSelected.Add_Click({
    $records = @(Get-SelectedScriptletRecords)
    if ($records.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.restoreSelectFile'), (T 'msg.title.scriptlet'), 'OK', 'Information') | Out-Null; return }
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    $files = @($records | Select-Object -ExpandProperty File -Unique)
    $ans = [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.scriptlet.confirmRestoreSel' @($files.Count)),
        (T 'msg.title.scriptlet'),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($ans -ne 'Yes') { return }
    try {
        foreach ($file in $files) { Restore-ScriptletBackup -File $file }
        Write-Log "Restored $($files.Count) scriptlet list file(s) from backup." 'OK'
        Invoke-ScriptletScan
    } catch {
        Write-Log "Scriptlet restore selected failed: $_" 'ERR'
        [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.restoreFailed' @("$_")), (T 'msg.title.scriptlet'), 'OK', 'Error') | Out-Null
    }
})
$scriptletsTab.Controls.Add($btnScriptletRestoreSelected)

$btnScriptletRestoreAll = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnScriptletRestoreAll 'scriptlet.restoreAll')
$btnScriptletRestoreAll.Size = New-Object System.Drawing.Size(140, 28)
$btnScriptletRestoreAll.Location = New-Object System.Drawing.Point(685, 388)
$btnScriptletRestoreAll.Add_Click({
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    $ans = [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.scriptlet.confirmRestoreAll' @($script:TxtScriptletRoot.Text)),
        (T 'msg.title.scriptlet'),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($ans -ne 'Yes') { return }
    try {
        $count = Restore-AllScriptletBackups -Root $script:TxtScriptletRoot.Text.Trim()
        Write-Log "Restored $count scriptlet backup file(s)." 'OK'
        Invoke-ScriptletScan
    } catch {
        Write-Log "Scriptlet restore all failed: $_" 'ERR'
        [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.restoreAllFailed' @("$_")), (T 'msg.title.scriptlet'), 'OK', 'Error') | Out-Null
    }
})
$scriptletsTab.Controls.Add($btnScriptletRestoreAll)

$btnScriptletExportCsv = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnScriptletExportCsv 'scriptlet.exportCsv')
$btnScriptletExportCsv.Size = New-Object System.Drawing.Size(130, 28)
$btnScriptletExportCsv.Location = New-Object System.Drawing.Point(835, 388)
$btnScriptletExportCsv.Add_Click({
    if (-not $script:ScriptletVisibleRules -or $script:ScriptletVisibleRules.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.nothingVisible'), (T 'msg.title.scriptlet'), 'OK', 'Information') | Out-Null; return }
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Filter = '{0} (*.csv)|*.csv' -f (T 'dialog.filter.csv')
    $sfd.FileName = "brave-free-origin-scriptlets-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    if ($sfd.ShowDialog() -ne 'OK') { return }
    $script:ScriptletVisibleRules |
        Select-Object Enabled,Domain,Scriptlet,Arguments,Source,Version,ComponentId,File,LineNumber,Rule |
        Export-Csv -Path $sfd.FileName -NoTypeInformation -Encoding UTF8
    Write-Log "Scriptlet CSV exported: $($sfd.FileName)" 'OK'
})
$scriptletsTab.Controls.Add($btnScriptletExportCsv)

$btnScriptletExportPrefs = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnScriptletExportPrefs 'scriptlet.exportPrefs')
$btnScriptletExportPrefs.Size = New-Object System.Drawing.Size(150, 28)
$btnScriptletExportPrefs.Location = New-Object System.Drawing.Point(10, 424)
$btnScriptletExportPrefs.Add_Click({
    if (-not $script:ScriptletRules -or $script:ScriptletRules.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.noRulesLoaded'), (T 'msg.title.scriptlet'), 'OK', 'Information') | Out-Null; return }
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Filter = '{0} (*.json)|*.json' -f (T 'dialog.filter.scriptletPrefs')
    $sfd.FileName = "brave-free-origin-disabled-scriptlets-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    if ($sfd.ShowDialog() -ne 'OK') { return }
    try {
        $count = Export-ScriptletDisabledPreferences -File $sfd.FileName
        Write-Log "Disabled scriptlet prefs exported: $count rule(s)." 'OK'
    } catch {
        [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.exportFailed' @("$_")), (T 'msg.title.scriptlet'), 'OK', 'Error') | Out-Null
    }
})
$scriptletsTab.Controls.Add($btnScriptletExportPrefs)

$script:BtnScriptletImportPrefs = New-Object System.Windows.Forms.Button
[void](Set-Loc $script:BtnScriptletImportPrefs 'scriptlet.importPrefs')
$script:BtnScriptletImportPrefs.Size = New-Object System.Drawing.Size(165, 28)
$script:BtnScriptletImportPrefs.Location = New-Object System.Drawing.Point(170, 424)
$script:BtnScriptletImportPrefs.Add_Click({
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = '{0} (*.json)|*.json' -f (T 'dialog.filter.scriptletPrefs')
    if ($ofd.ShowDialog() -ne 'OK') { return }
    $ans = [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.scriptlet.confirmReapply' @($script:TxtScriptletRoot.Text)),
        (T 'msg.title.scriptlet'),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($ans -ne 'Yes') { return }
    try {
        $changed = Import-ScriptletPreferencesAndReapply -PrefsFile $ofd.FileName -Root $script:TxtScriptletRoot.Text.Trim()
        Write-Log "Reapplied disabled scriptlet prefs: $changed line(s)." 'OK'
        Invoke-ScriptletScan
    } catch {
        Write-Log "Scriptlet preference reapply failed: $_" 'ERR'
        [System.Windows.Forms.MessageBox]::Show((T 'msg.scriptlet.reapplyFailed' @("$_")), (T 'msg.title.scriptlet'), 'OK', 'Error') | Out-Null
    }
})
$scriptletsTab.Controls.Add($script:BtnScriptletImportPrefs)

$scriptletFooter = New-Object System.Windows.Forms.Label
[void](Set-Loc $scriptletFooter 'scriptlet.footer')
$scriptletFooter.Location = New-Object System.Drawing.Point(350, 429)
$scriptletFooter.Size = New-Object System.Drawing.Size(760, 32)
$scriptletFooter.ForeColor = [System.Drawing.Color]::DimGray
[void](Set-LocFont $scriptletFooter -Size 8)
$scriptletsTab.Controls.Add($scriptletFooter)

$tabs.TabPages.Add($scriptletsTab)

# ---- Search & Startup tab (v1.6) -------------------------------------------
# Three independent, opt-in sections. Each has its own "Override" checkbox.
# Off by default: Brave's user-chosen search engine and startup behavior stay
# untouched unless the user actively ticks an override.
$searchTab = New-Object System.Windows.Forms.TabPage
$searchTab.Name = 'searchTab'
[void](Set-Loc $searchTab 'tab.searchStartup')
$searchTab.AutoScroll = $true
$searchTab.BackColor = [System.Drawing.Color]::White

$searchIntro = New-Object System.Windows.Forms.Label
[void](Set-Loc $searchIntro 'searchTab.intro')
[void](Set-LocFont $searchIntro -Size 9)
$searchIntro.Location = New-Object System.Drawing.Point(10, 8)
$searchIntro.Size = New-Object System.Drawing.Size(1100, 36)
$searchIntro.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 90)
$searchTab.Controls.Add($searchIntro)

# --- Section 1: Default search engine ---
$secSearch = New-Object System.Windows.Forms.GroupBox
[void](Set-Loc $secSearch 'searchTab.secSearch')
$secSearch.Location = New-Object System.Drawing.Point(10, 50)
$secSearch.Size = New-Object System.Drawing.Size(1110, 110)
[void](Set-LocFont $secSearch -Size 9 -Semibold)
$searchTab.Controls.Add($secSearch)

$script:ChkSearchOverride = New-Object System.Windows.Forms.CheckBox
[void](Set-Loc $script:ChkSearchOverride 'searchTab.chkSearch')
$script:ChkSearchOverride.Location = New-Object System.Drawing.Point(15, 22)
$script:ChkSearchOverride.Size = New-Object System.Drawing.Size(530, 20)
[void](Set-LocFont $script:ChkSearchOverride -Size 9)
$secSearch.Controls.Add($script:ChkSearchOverride)

$lblEngine = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblEngine 'searchTab.engineLabel')
$lblEngine.Location = New-Object System.Drawing.Point(35, 50)
$lblEngine.Size = New-Object System.Drawing.Size(60, 18)
[void](Set-LocFont $lblEngine -Size 9)
$secSearch.Controls.Add($lblEngine)

$script:CmbSearchEngine = New-Object System.Windows.Forms.ComboBox
$script:CmbSearchEngine.Location = New-Object System.Drawing.Point(95, 47)
$script:CmbSearchEngine.Size = New-Object System.Drawing.Size(200, 22)
$script:CmbSearchEngine.DropDownStyle = 'DropDownList'
Set-ComboLabels -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds -LabelKeys $script:SearchEngineLabelKeys
$script:CmbSearchEngine.SelectedIndex = 0
$secSearch.Controls.Add($script:CmbSearchEngine)

$lblCustomSearch = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblCustomSearch 'searchTab.customLabel')
$lblCustomSearch.Location = New-Object System.Drawing.Point(310, 50)
$lblCustomSearch.Size = New-Object System.Drawing.Size(115, 18)
[void](Set-LocFont $lblCustomSearch -Size 9)
$secSearch.Controls.Add($lblCustomSearch)

$script:TxtCustomSearchUrl = New-Object System.Windows.Forms.TextBox
$script:TxtCustomSearchUrl.Location = New-Object System.Drawing.Point(425, 47)
$script:TxtCustomSearchUrl.Size = New-Object System.Drawing.Size(370, 22)
$script:TxtCustomSearchUrl.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$script:TxtCustomSearchUrl.Enabled = $false
$secSearch.Controls.Add($script:TxtCustomSearchUrl)

$searchHelp = New-Object System.Windows.Forms.Label
[void](Set-Loc $searchHelp 'searchTab.searchHelp')
$searchHelp.Location = New-Object System.Drawing.Point(35, 78)
$searchHelp.Size = New-Object System.Drawing.Size(900, 18)
$searchHelp.ForeColor = [System.Drawing.Color]::DimGray
[void](Set-LocFont $searchHelp -Size 8)
$secSearch.Controls.Add($searchHelp)

$script:CmbSearchEngine.Add_SelectedIndexChanged({
    $isCustom = ((Get-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds) -eq 'custom')
    $script:TxtCustomSearchUrl.Enabled = $isCustom
})

# --- Section 2: New tab page ---
$secNtp = New-Object System.Windows.Forms.GroupBox
[void](Set-Loc $secNtp 'searchTab.secNtp')
$secNtp.Location = New-Object System.Drawing.Point(10, 168)
$secNtp.Size = New-Object System.Drawing.Size(1110, 90)
[void](Set-LocFont $secNtp -Size 9 -Semibold)
$searchTab.Controls.Add($secNtp)

$script:ChkNtpOverride = New-Object System.Windows.Forms.CheckBox
[void](Set-Loc $script:ChkNtpOverride 'searchTab.chkNtp')
$script:ChkNtpOverride.Location = New-Object System.Drawing.Point(15, 22)
$script:ChkNtpOverride.Size = New-Object System.Drawing.Size(450, 20)
[void](Set-LocFont $script:ChkNtpOverride -Size 9)
$secNtp.Controls.Add($script:ChkNtpOverride)

$lblNtpDest = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblNtpDest 'searchTab.ntpOpenLabel')
[void](Set-LocFont $lblNtpDest -Size 9)
$lblNtpDest.Location = New-Object System.Drawing.Point(35, 50)
$lblNtpDest.Size = New-Object System.Drawing.Size(50, 18)
$secNtp.Controls.Add($lblNtpDest)

$script:CmbNtpDest = New-Object System.Windows.Forms.ComboBox
$script:CmbNtpDest.Location = New-Object System.Drawing.Point(85, 47)
$script:CmbNtpDest.Size = New-Object System.Drawing.Size(310, 22)
$script:CmbNtpDest.DropDownStyle = 'DropDownList'
Set-ComboLabels -Combo $script:CmbNtpDest -Ids $script:DestinationIds -LabelKeys $script:DestinationLabelKeys
$script:CmbNtpDest.SelectedIndex = 0
$secNtp.Controls.Add($script:CmbNtpDest)

$lblNtpCustom = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblNtpCustom 'searchTab.ntpCustomLabel')
[void](Set-LocFont $lblNtpCustom -Size 9)
$lblNtpCustom.Location = New-Object System.Drawing.Point(410, 50)
$lblNtpCustom.Size = New-Object System.Drawing.Size(80, 18)
$secNtp.Controls.Add($lblNtpCustom)

$script:TxtNtpCustomUrl = New-Object System.Windows.Forms.TextBox
$script:TxtNtpCustomUrl.Location = New-Object System.Drawing.Point(490, 47)
$script:TxtNtpCustomUrl.Size = New-Object System.Drawing.Size(305, 22)
$script:TxtNtpCustomUrl.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$script:TxtNtpCustomUrl.Enabled = $false
$secNtp.Controls.Add($script:TxtNtpCustomUrl)

$script:CmbNtpDest.Add_SelectedIndexChanged({
    $isCustom = ((Get-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds) -eq 'custom')
    $script:TxtNtpCustomUrl.Enabled = $isCustom
})

# --- Section 3: Startup behavior ---
$secStartup = New-Object System.Windows.Forms.GroupBox
[void](Set-Loc $secStartup 'searchTab.secStartup')
$secStartup.Location = New-Object System.Drawing.Point(10, 266)
$secStartup.Size = New-Object System.Drawing.Size(1110, 110)
[void](Set-LocFont $secStartup -Size 9 -Semibold)
$searchTab.Controls.Add($secStartup)

$script:ChkStartupOverride = New-Object System.Windows.Forms.CheckBox
[void](Set-Loc $script:ChkStartupOverride 'searchTab.chkStartup')
$script:ChkStartupOverride.Location = New-Object System.Drawing.Point(15, 22)
$script:ChkStartupOverride.Size = New-Object System.Drawing.Size(550, 20)
[void](Set-LocFont $script:ChkStartupOverride -Size 9)
$secStartup.Controls.Add($script:ChkStartupOverride)

$lblStartMode = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblStartMode 'searchTab.modeLabel')
[void](Set-LocFont $lblStartMode -Size 9)
$lblStartMode.Location = New-Object System.Drawing.Point(35, 50)
$lblStartMode.Size = New-Object System.Drawing.Size(50, 18)
$secStartup.Controls.Add($lblStartMode)

$script:CmbStartupMode = New-Object System.Windows.Forms.ComboBox
$script:CmbStartupMode.Location = New-Object System.Drawing.Point(85, 47)
$script:CmbStartupMode.Size = New-Object System.Drawing.Size(310, 22)
$script:CmbStartupMode.DropDownStyle = 'DropDownList'
Set-ComboLabels -Combo $script:CmbStartupMode -Ids $script:StartupModeIds -LabelKeys $script:StartupModeLabelKeys
$script:CmbStartupMode.SelectedIndex = 0
$secStartup.Controls.Add($script:CmbStartupMode)

$lblStartUrl = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblStartUrl 'searchTab.urlLabel')
[void](Set-LocFont $lblStartUrl -Size 9)
$lblStartUrl.Location = New-Object System.Drawing.Point(410, 50)
$lblStartUrl.Size = New-Object System.Drawing.Size(60, 18)
$secStartup.Controls.Add($lblStartUrl)

$script:TxtStartupUrl = New-Object System.Windows.Forms.TextBox
$script:TxtStartupUrl.Location = New-Object System.Drawing.Point(470, 47)
$script:TxtStartupUrl.Size = New-Object System.Drawing.Size(325, 22)
$script:TxtStartupUrl.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$script:TxtStartupUrl.Enabled = $false
$secStartup.Controls.Add($script:TxtStartupUrl)

$startupHelp = New-Object System.Windows.Forms.Label
[void](Set-Loc $startupHelp 'searchTab.startupHelp')
$startupHelp.Location = New-Object System.Drawing.Point(35, 78)
$startupHelp.Size = New-Object System.Drawing.Size(900, 18)
$startupHelp.ForeColor = [System.Drawing.Color]::DimGray
[void](Set-LocFont $startupHelp -Size 8)
$secStartup.Controls.Add($startupHelp)

$script:CmbStartupMode.Add_SelectedIndexChanged({
    $mode = $script:StartupModes[(Get-ComboId -Combo $script:CmbStartupMode -Ids $script:StartupModeIds)]
    $script:TxtStartupUrl.Enabled = ($mode -and $mode.UsesURL -and -not $mode.FixedURL)
})

# Conflict note
$conflictNote = New-Object System.Windows.Forms.Label
[void](Set-Loc $conflictNote 'searchTab.conflictNote')
$conflictNote.Location = New-Object System.Drawing.Point(10, 384)
$conflictNote.Size = New-Object System.Drawing.Size(1100, 36)
$conflictNote.ForeColor = [System.Drawing.Color]::FromArgb(120, 60, 30)
[void](Set-LocFont $conflictNote -Size 8)
$searchTab.Controls.Add($conflictNote)

# --- Section 4: Extensions (manual installs, no force-push) -----------------
$secExt = New-Object System.Windows.Forms.GroupBox
[void](Set-Loc $secExt 'ext.section')
$secExt.Location = New-Object System.Drawing.Point(10, 426)
$secExt.Size = New-Object System.Drawing.Size(1110, 130)
[void](Set-LocFont $secExt -Size 9 -Semibold)
$searchTab.Controls.Add($secExt)

$extIntro = New-Object System.Windows.Forms.Label
[void](Set-Loc $extIntro 'ext.intro')
$extIntro.Location = New-Object System.Drawing.Point(15, 22)
$extIntro.Size = New-Object System.Drawing.Size(1080, 36)
[void](Set-LocFont $extIntro -Size 8.5)
$extIntro.ForeColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$secExt.Controls.Add($extIntro)

$extWarn = New-Object System.Windows.Forms.Label
[void](Set-Loc $extWarn 'ext.warn')
$extWarn.Location = New-Object System.Drawing.Point(15, 60)
$extWarn.Size = New-Object System.Drawing.Size(1080, 32)
[void](Set-LocFont $extWarn -Size 8)
$extWarn.ForeColor = [System.Drawing.Color]::FromArgb(160, 70, 30)
$secExt.Controls.Add($extWarn)

$btnUboLite = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnUboLite 'ext.uboLite')
$btnUboLite.Size = New-Object System.Drawing.Size(220, 28)
$btnUboLite.Location = New-Object System.Drawing.Point(15, 95)
$btnUboLite.Add_Click({
    $exe = Test-BraveInstalled
    $url = 'https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh'
    if ($exe) { Start-Process $exe $url } else { Start-Process $url }
    Write-Log 'Opened uBlock Origin Lite install page.'
})
$secExt.Controls.Add($btnUboLite)

$btnShieldsSettings = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnShieldsSettings 'ext.shields')
$btnShieldsSettings.Size = New-Object System.Drawing.Size(200, 28)
$btnShieldsSettings.Location = New-Object System.Drawing.Point(245, 95)
$btnShieldsSettings.Add_Click({
    $exe = Test-BraveInstalled
    if ($exe) { Start-Process $exe 'brave://settings/shields' } else { Write-Log 'Brave not found.' 'WARN' }
})
$secExt.Controls.Add($btnShieldsSettings)

$btnBitwarden = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnBitwarden 'ext.bitwarden')
$btnBitwarden.Size = New-Object System.Drawing.Size(240, 28)
$btnBitwarden.Location = New-Object System.Drawing.Point(455, 95)
$btnBitwarden.Add_Click({
    $exe = Test-BraveInstalled
    $url = 'https://chromewebstore.google.com/detail/bitwarden-password-manage/nngceckbapebfimnlniiiahkandclblb'
    if ($exe) { Start-Process $exe $url } else { Start-Process $url }
    Write-Log 'Opened Bitwarden install page.'
})
$secExt.Controls.Add($btnBitwarden)

$tabs.TabPages.Add($searchTab)

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

# ---- Utility buttons --------------------------------------------------------
$utilityPanel = New-Object System.Windows.Forms.Panel
$utilityPanel.Location = New-Object System.Drawing.Point(10, 716)
$utilityPanel.Size = New-Object System.Drawing.Size(1145, 40)
$utilityPanel.Anchor = 'Left, Right, Bottom'
$form.Controls.Add($utilityPanel)

# Export config to JSON
$btnExport = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnExport 'util.export')
$btnExport.Size = New-Object System.Drawing.Size(110, 30)
$btnExport.Location = New-Object System.Drawing.Point(420, 5)
$btnExport.Add_Click({
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Filter = '{0} (*.json)|*.json' -f (T 'dialog.filter.config')
    $sfd.FileName = "brave-free-origin-config-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $sfd.InitialDirectory = Join-Path $env:USERPROFILE 'Documents\Brave-Free-Origin-Backups'
    if (-not (Test-Path $sfd.InitialDirectory)) { New-Item -ItemType Directory -Path $sfd.InitialDirectory | Out-Null }
    if ($sfd.ShowDialog() -ne 'OK') { return }

    # schemaVersion tracks the config format, appVersion tracks the app. They
    # move independently: gaining a button must not force a config migration.
    $cfg = [ordered]@{
        schemaVersion = 2
        appVersion    = $script:AppVersion
        exported      = (Get-Date -Format 's')
        channel       = $script:TargetChannels
        profile       = $script:ActiveProfile
        policies      = [ordered]@{}
        policyValues  = [ordered]@{}
        tasks         = [ordered]@{}
        services      = [ordered]@{}
        hosts         = [ordered]@{}
        search   = [ordered]@{
            enabled   = [bool]$script:ChkSearchOverride.Checked
            engineId  = "$(Get-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds)"
            customUrl = "$($script:TxtCustomSearchUrl.Text)"
        }
        ntp = [ordered]@{
            enabled       = [bool]$script:ChkNtpOverride.Checked
            destinationId = "$(Get-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds)"
            customUrl     = "$($script:TxtNtpCustomUrl.Text)"
        }
        startup = [ordered]@{
            enabled = [bool]$script:ChkStartupOverride.Checked
            modeId  = "$(Get-ComboId -Combo $script:CmbStartupMode -Ids $script:StartupModeIds)"
            urls    = "$($script:TxtStartupUrl.Text)"
        }
    }
    foreach ($cb in $script:CheckBoxes)        {
        $cfg.policies[$cb.Tag.Policy.Name] = [bool]$cb.Checked
        # Remember the picked value for choice policies (e.g. hardware accel).
        if ($cb.Tag.Policy.Choices) { $cfg.policyValues[$cb.Tag.Policy.Name] = $cb.Tag.Policy.ApplyValue }
    }
    foreach ($cb in $script:TaskCheckBoxes)    { $cfg.tasks[$cb.Tag.Name]            = [bool]$cb.Checked }
    foreach ($cb in $script:ServiceCheckBoxes) { $cfg.services[$cb.Tag.Name]         = [bool]$cb.Checked }
    foreach ($cb in $script:HostsCheckBoxes)   { $cfg.hosts[$cb.Tag.Id]              = [bool]$cb.Checked }

    $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $sfd.FileName -Encoding UTF8
    Write-Log "Config exported: $($sfd.FileName)" 'OK'
})
$utilityPanel.Controls.Add($btnExport)

# Import config from JSON
$btnImport = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnImport 'util.import')
$btnImport.Size = New-Object System.Drawing.Size(110, 30)
$btnImport.Location = New-Object System.Drawing.Point(535, 5)
$btnImport.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = '{0} (*.json)|*.json' -f (T 'dialog.filter.config')
    $ofd.InitialDirectory = Join-Path $env:USERPROFILE 'Documents\Brave-Free-Origin-Backups'
    if ($ofd.ShowDialog() -ne 'OK') { return }
    try {
        $cfg = Get-Content $ofd.FileName -Raw | ConvertFrom-Json
    } catch {
        [System.Windows.Forms.MessageBox]::Show((T 'msg.config.badJson' @("$_")), (T 'msg.title.importError'), 'OK', 'Error') | Out-Null
        return
    }
    Push-SuppressSelectionEvents
    try {
        if ($cfg.policies) {
            foreach ($cb in $script:CheckBoxes) {
                $name = $cb.Tag.Policy.Name
                if ($cfg.policies.PSObject.Properties.Name -contains $name) { $cb.Checked = [bool]$cfg.policies.$name }
            }
        }
        if ($cfg.policyValues) {
            # Restore the picked value for choice policies (e.g. hardware accel).
            foreach ($cb in $script:CheckBoxes) {
                $p = $cb.Tag.Policy
                if (-not $p.Choices) { continue }
                if ($cfg.policyValues.PSObject.Properties.Name -notcontains $p.Name) { continue }
                $wanted = "$($cfg.policyValues.$($p.Name))"
                foreach ($cid in $p.Choices.Keys) {
                    if ("$($p.Choices[$cid])" -eq $wanted) {
                        [void](Set-PolicyChoiceId -Policy $p -ChoiceId $cid)
                        break
                    }
                }
            }
        }
        if ($cfg.tasks) {
            foreach ($cb in $script:TaskCheckBoxes) {
                $name = $cb.Tag.Name
                if ($cfg.tasks.PSObject.Properties.Name -contains $name) { $cb.Checked = [bool]$cfg.tasks.$name }
            }
        }
        if ($cfg.services) {
            foreach ($cb in $script:ServiceCheckBoxes) {
                $name = $cb.Tag.Name
                if ($cfg.services.PSObject.Properties.Name -contains $name) { $cb.Checked = [bool]$cfg.services.$name }
            }
        }
        if ($cfg.hosts) {
            # Accept both schema 2 ids and the pre-1.12 English display names.
            $hostsById = @{}
            foreach ($p in $cfg.hosts.PSObject.Properties) {
                $id = $p.Name
                if ($script:LegacyHostsIds.ContainsKey($id)) { $id = $script:LegacyHostsIds[$id] }
                $hostsById[$id] = [bool]$p.Value
            }
            foreach ($cb in $script:HostsCheckBoxes) {
                if ($hostsById.ContainsKey($cb.Tag.Id)) { $cb.Checked = $hostsById[$cb.Tag.Id] }
            }
        }
        if ($cfg.search) {
            $script:ChkSearchOverride.Checked = [bool]$cfg.search.enabled
            $engineId = if ($cfg.search.engineId) { "$($cfg.search.engineId)" }
                        elseif ($cfg.search.engine -and $script:LegacySearchEngineIds.ContainsKey("$($cfg.search.engine)")) {
                            $script:LegacySearchEngineIds["$($cfg.search.engine)"]
                        } else { $null }
            if ($engineId) { [void](Set-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds -Id $engineId) }
            if ($cfg.search.customUrl) { $script:TxtCustomSearchUrl.Text = $cfg.search.customUrl }
        }
        if ($cfg.ntp) {
            $script:ChkNtpOverride.Checked = [bool]$cfg.ntp.enabled
            $destId = if ($cfg.ntp.destinationId) { "$($cfg.ntp.destinationId)" }
                      elseif ($cfg.ntp.destination -and $script:LegacyDestinationIds.ContainsKey("$($cfg.ntp.destination)")) {
                          $script:LegacyDestinationIds["$($cfg.ntp.destination)"]
                      } else { $null }
            if ($destId) { [void](Set-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds -Id $destId) }
            if ($cfg.ntp.customUrl) { $script:TxtNtpCustomUrl.Text = $cfg.ntp.customUrl }
        }
        if ($cfg.startup) {
            $script:ChkStartupOverride.Checked = [bool]$cfg.startup.enabled
            $modeId = if ($cfg.startup.modeId) { "$($cfg.startup.modeId)" }
                      elseif ($cfg.startup.mode -and $script:LegacyStartupModeIds.ContainsKey("$($cfg.startup.mode)")) {
                          $script:LegacyStartupModeIds["$($cfg.startup.mode)"]
                      } else { $null }
            if ($modeId) { [void](Set-ComboId -Combo $script:CmbStartupMode -Ids $script:StartupModeIds -Id $modeId) }
            if ($cfg.startup.urls) { $script:TxtStartupUrl.Text = $cfg.startup.urls }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = if ($cfg.profile) { "$($cfg.profile)" } else { 'Custom' }
    Update-OverrideControlStates
    Update-SelectionSummary
    $schema = if ($cfg.schemaVersion) { $cfg.schemaVersion } else { 1 }
    Write-Log "Config imported from $($ofd.FileName) (schema $schema, app $($cfg.appVersion)$(if (-not $cfg.appVersion) { $cfg.version }))" 'OK'
    Update-ConfigurationFilter
    [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.config.imported'),
        (T 'msg.title.imported'), 'OK', 'Information') | Out-Null
})
$utilityPanel.Controls.Add($btnImport)

# Verify - read registry, compare to UI selections
$btnVerify = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnVerify 'util.verify')
$btnVerify.Size = New-Object System.Drawing.Size(80, 30)
$btnVerify.Location = New-Object System.Drawing.Point(650, 5)
$btnVerify.Add_Click({
    $report = New-Object System.Text.StringBuilder
    foreach ($channel in $script:TargetChannels) {
        $path = $script:Channels[$channel].Path
        [void]$report.AppendLine("=== $channel  ($path) ===")
        if (-not (Test-Path $path)) {
            [void]$report.AppendLine('  (no policy key exists - nothing applied)')
            [void]$report.AppendLine('')
            continue
        }
        $matchCount = 0; $missingCount = 0; $mismatchCount = 0; $tickedCount = 0
        $missingList = @(); $mismatchList = @()
        foreach ($cb in $script:CheckBoxes) {
            if (-not $cb.Checked) { continue }
            $tickedCount++
            $p = $cb.Tag.Policy
            try {
                $cur = (Get-ItemProperty -Path $path -Name $p.Name -ErrorAction Stop).$($p.Name)
                if ("$cur" -eq "$($p.ApplyValue)") { $matchCount++ }
                else { $mismatchCount++; $mismatchList += "$($p.Name): registry=$cur, expected=$($p.ApplyValue)" }
            } catch {
                $missingCount++; $missingList += $p.Name
            }
        }
        [void]$report.AppendLine("  Ticked in UI: $tickedCount")
        [void]$report.AppendLine("  Match in registry: $matchCount")
        [void]$report.AppendLine("  Missing (not in registry): $missingCount")
        [void]$report.AppendLine("  Mismatch (wrong value): $mismatchCount")
        if ($missingList) {
            [void]$report.AppendLine('  -- missing:')
            foreach ($n in $missingList) { [void]$report.AppendLine("     - $n") }
        }
        if ($mismatchList) {
            [void]$report.AppendLine('  -- mismatch:')
            foreach ($n in $mismatchList) { [void]$report.AppendLine("     - $n") }
        }
        [void]$report.AppendLine('')
    }

    # Hosts state
    $hostsCurrent = Get-HostsCurrentDomains
    [void]$report.AppendLine("=== Hosts blocklist ===")
    [void]$report.AppendLine("  Currently blocked domains: $($hostsCurrent.Count)")
    if ($hostsCurrent.Count -gt 0) {
        foreach ($d in $hostsCurrent) { [void]$report.AppendLine("     - $d") }
    }
    [void]$report.AppendLine('')

    # Search / NTP / Startup overrides
    [void]$report.AppendLine('=== Search & Startup overrides ===')
    foreach ($channel in $script:TargetChannels) {
        $path = $script:Channels[$channel].Path
        [void]$report.AppendLine("  [$channel]")
        if (-not (Test-Path $path)) { [void]$report.AppendLine('     (no policy key - nothing set)'); continue }
        try {
            $se = (Get-ItemProperty -Path $path -Name 'DefaultSearchProviderEnabled' -ErrorAction Stop).DefaultSearchProviderEnabled
            $name = (Get-ItemProperty -Path $path -Name 'DefaultSearchProviderName' -ErrorAction SilentlyContinue).DefaultSearchProviderName
            $url  = (Get-ItemProperty -Path $path -Name 'DefaultSearchProviderSearchURL' -ErrorAction SilentlyContinue).DefaultSearchProviderSearchURL
            if ($se -eq 1) { [void]$report.AppendLine("     Search engine forced: $name ($url)") }
            else           { [void]$report.AppendLine('     Search engine override: not set') }
        } catch { [void]$report.AppendLine('     Search engine override: not set') }
        try {
            $ntp = (Get-ItemProperty -Path $path -Name 'NewTabPageLocation' -ErrorAction Stop).NewTabPageLocation
            [void]$report.AppendLine("     New tab page forced: $ntp")
        } catch { [void]$report.AppendLine('     New tab page override: not set') }
        try {
            $rc = (Get-ItemProperty -Path $path -Name 'RestoreOnStartup' -ErrorAction Stop).RestoreOnStartup
            $listPath = Join-Path $path 'RestoreOnStartupURLs'
            $urls = @()
            if (Test-Path $listPath) {
                $props = Get-ItemProperty -Path $listPath
                foreach ($p in $props.PSObject.Properties) {
                    if ($p.Name -match '^\d+$') { $urls += $p.Value }
                }
            }
            $extra = if ($urls.Count -gt 0) { " URLs: $($urls -join ', ')" } else { '' }
            [void]$report.AppendLine("     Startup forced: code $rc$extra")
        } catch { [void]$report.AppendLine('     Startup override: not set') }
    }

    Show-TextReport -Title (T 'report.verifyTitle') -Text ($report.ToString()) -DefaultFileName "brave-free-origin-verify-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
})
$utilityPanel.Controls.Add($btnVerify)

$btnLoad = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnLoad 'util.loadState')
$btnLoad.Size = New-Object System.Drawing.Size(145, 30)
$btnLoad.Location = New-Object System.Drawing.Point(0, 5)
$btnLoad.Add_Click({
    Push-SuppressSelectionEvents
    try {
        # Read from the FIRST target channel (loading is single-source by design)
        $loadPath = $script:Channels[$script:TargetChannels[0]].Path
        $originalPath = $script:BravePolicyPath
        $script:BravePolicyPath = $loadPath
        foreach ($cb in $script:CheckBoxes) {
            $p = $cb.Tag.Policy
            $cur = Get-ExistingPolicy $p.Name
            if ($p.Choices) {
                # A choice policy counts as "on" whenever a value is present; point
                # the picker at whatever the registry actually holds.
                if ($null -ne $cur) {
                    foreach ($cid in $p.Choices.Keys) {
                        if ("$($p.Choices[$cid])" -eq "$cur") {
                            [void](Set-PolicyChoiceId -Policy $p -ChoiceId $cid)
                            break
                        }
                    }
                    $cb.Checked = $true
                } else {
                    $cb.Checked = $false
                }
            } else {
                $cb.Checked = ($null -ne $cur -and "$cur" -eq "$($p.ApplyValue)")
            }
        }
        $script:BravePolicyPath = $originalPath
        foreach ($cb in $script:TaskCheckBoxes) {
            $t = $cb.Tag
            $task = Get-ScheduledTask -TaskName $t.Name -ErrorAction SilentlyContinue
            $cb.Checked = ($task -and $task.State -eq 'Disabled')
        }
        foreach ($cb in $script:ServiceCheckBoxes) {
            $s = $cb.Tag
            $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            $cb.Checked = ($svc -and $svc.StartType -eq 'Disabled')
        }
        # Hosts state
        if ($script:HostsCheckBoxes) {
            $current = Get-HostsCurrentDomains
            foreach ($cb in $script:HostsCheckBoxes) {
                $blockDomains = $cb.Tag.Domains
                $allPresent = $true
                foreach ($d in $blockDomains) { if ($current -notcontains $d) { $allPresent = $false; break } }
                $cb.Checked = $allPresent
            }
        }
        # Search engine override state
        if ($script:ChkSearchOverride) {
            $sePath = $loadPath
            $seEnabled = $false
            try {
                $val = (Get-ItemProperty -Path $sePath -Name 'DefaultSearchProviderEnabled' -ErrorAction Stop).DefaultSearchProviderEnabled
                $seEnabled = ($val -eq 1)
            } catch { $seEnabled = $false }
            $script:ChkSearchOverride.Checked = $seEnabled
            if ($seEnabled) {
                try {
                    $url = (Get-ItemProperty -Path $sePath -Name 'DefaultSearchProviderSearchURL' -ErrorAction Stop).DefaultSearchProviderSearchURL
                    $matched = $false
                    foreach ($key in $script:SearchEngines.Keys) {
                        if (-not $script:SearchEngines[$key].IsCustom -and $script:SearchEngines[$key].URL -eq $url) {
                            [void](Set-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds -Id $key)
                            $matched = $true; break
                        }
                    }
                    if (-not $matched) {
                        [void](Set-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds -Id 'custom')
                        $script:TxtCustomSearchUrl.Text = $url
                    }
                } catch {}
            }
        }
        # NTP override state
        if ($script:ChkNtpOverride) {
            try {
                $ntpUrl = (Get-ItemProperty -Path $loadPath -Name 'NewTabPageLocation' -ErrorAction Stop).NewTabPageLocation
                $script:ChkNtpOverride.Checked = $true
                $matched = $false
                foreach ($k in $script:DestinationOptions.Keys) {
                    if ($script:DestinationOptions[$k].Value -eq $ntpUrl) {
                        $matched = [bool](Set-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds -Id $k)
                        if ($matched) { break }
                    }
                }
                if (-not $matched) {
                    [void](Set-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds -Id 'custom')
                    $script:TxtNtpCustomUrl.Text = $ntpUrl
                }
            } catch { $script:ChkNtpOverride.Checked = $false }
        }
        # Startup override state
        if ($script:ChkStartupOverride) {
            try {
                $code = (Get-ItemProperty -Path $loadPath -Name 'RestoreOnStartup' -ErrorAction Stop).RestoreOnStartup
                $script:ChkStartupOverride.Checked = $true
                foreach ($k in $script:StartupModes.Keys) {
                    if ($script:StartupModes[$k].Code -eq $code) {
                        [void](Set-ComboId -Combo $script:CmbStartupMode -Ids $script:StartupModeIds -Id $k); break
                    }
                }
                $listPath = Join-Path $loadPath 'RestoreOnStartupURLs'
                if (Test-Path $listPath) {
                    $props = Get-ItemProperty -Path $listPath
                    $urls = @()
                    foreach ($p in $props.PSObject.Properties) {
                        if ($p.Name -match '^\d+$') { $urls += $p.Value }
                    }
                    if ($urls.Count -gt 0) { $script:TxtStartupUrl.Text = ($urls -join ', ') }
                }
            } catch { $script:ChkStartupOverride.Checked = $false }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = 'CurrentState'
    Update-OverrideControlStates
    Update-SelectionSummary
    Update-ConfigurationFilter
    Write-Log 'Loaded current system state.'
})
$utilityPanel.Controls.Add($btnLoad)

$btnOpenBrave = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnOpenBrave 'util.openPolicy')
$btnOpenBrave.Size = New-Object System.Drawing.Size(150, 30)
$btnOpenBrave.Location = New-Object System.Drawing.Point(155, 5)
$btnOpenBrave.Add_Click({
    $exe = Test-BraveInstalled
    if ($exe) { Start-Process $exe 'brave://policy' }
    else { [System.Windows.Forms.MessageBox]::Show((T 'msg.braveMissing'), (T 'msg.title.info')) | Out-Null }
})
$utilityPanel.Controls.Add($btnOpenBrave)

$btnClose = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnClose 'util.close')
$btnClose.Size = New-Object System.Drawing.Size(95, 30)
$btnClose.Location = New-Object System.Drawing.Point(315, 5)
$btnClose.Add_Click({ $form.Close() })
$utilityPanel.Controls.Add($btnClose)

$flowLabel = New-Object System.Windows.Forms.Label
[void](Set-Loc $flowLabel 'util.flow')
[void](Set-LocFont $flowLabel -Size 9)
$flowLabel.Location = New-Object System.Drawing.Point(740, 11)
$flowLabel.Size = New-Object System.Drawing.Size(400, 18)
$flowLabel.ForeColor = [System.Drawing.Color]::DimGray
$utilityPanel.Controls.Add($flowLabel)

# ---- Action buttons ---------------------------------------------------------
$actionPanel = New-Object System.Windows.Forms.Panel
$actionPanel.Location = New-Object System.Drawing.Point(10, 760)
$actionPanel.Size = New-Object System.Drawing.Size(1145, 44)
$actionPanel.Anchor = 'Left, Right, Bottom'
$form.Controls.Add($actionPanel)

$chkBackup = New-Object System.Windows.Forms.CheckBox
[void](Set-Loc $chkBackup 'action.backup')
$chkBackup.Checked = $true
$chkBackup.Location = New-Object System.Drawing.Point(0, 12)
$chkBackup.Size = New-Object System.Drawing.Size(270, 20)
$actionPanel.Controls.Add($chkBackup)

$btnPreview = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnPreview 'action.preview')
$btnPreview.Size = New-Object System.Drawing.Size(140, 34)
$btnPreview.Location = New-Object System.Drawing.Point(280, 4)
$btnPreview.Add_Click({
    Show-TextReport -Title (T 'report.previewTitle') -Text (New-ApplyPlanReport) -DefaultFileName "brave-free-origin-apply-preview-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
})
$actionPanel.Controls.Add($btnPreview)

$btnApply = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnApply 'action.apply')
$btnApply.Size = New-Object System.Drawing.Size(150, 34)
$btnApply.Location = New-Object System.Drawing.Point(430, 4)
$btnApply.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 63)
$btnApply.ForeColor = [System.Drawing.Color]::White
[void](Set-LocFont $btnApply -Size 9 -Semibold)
$btnApply.Add_Click({
    if ($chkBackup.Checked) { [void](Export-Backup) }

    $applied = 0
    $cleared = 0
    $originalPath = $script:BravePolicyPath
    foreach ($channel in $script:TargetChannels) {
        $script:BravePolicyPath = $script:Channels[$channel].Path
        Write-Log "--- Applying to channel: $channel ($($script:BravePolicyPath)) ---"
        foreach ($cb in $script:CheckBoxes) {
            $p = $cb.Tag.Policy
            if ($cb.Checked) {
                try {
                    Set-PolicyValue -Name $p.Name -Type $p.Type -Value $p.ApplyValue
                    Write-Log "[$channel] SET $($p.Name) = $($p.ApplyValue)" 'OK'
                    $applied++
                } catch {
                    Write-Log "[$channel] FAIL $($p.Name): $_" 'ERR'
                }
            } else {
                if (Remove-PolicyValue -Name $p.Name) {
                    Write-Log "[$channel] CLEARED $($p.Name)" 'OK'
                    $cleared++
                }
            }
        }

        # Search/NTP/Startup overrides run LAST so they always win over any
        # NewTabPageLocation/HomepageLocation/RestoreOnStartup ticks above.
        # Each helper clears its own keys first, so unticking + Apply truly removes them.
        if ($script:BravePolicyPath -and (Test-Path $script:BravePolicyPath)) {
            try { [void](Apply-SearchEngineOverride -Path $script:BravePolicyPath) } catch { Write-Log "[$channel] Search override: $_" 'ERR' }
            try { [void](Apply-NtpOverride          -Path $script:BravePolicyPath) } catch { Write-Log "[$channel] NTP override: $_" 'ERR' }
            try { [void](Apply-StartupOverride      -Path $script:BravePolicyPath) } catch { Write-Log "[$channel] Startup override: $_" 'ERR' }
        } elseif ($script:ChkSearchOverride.Checked -or $script:ChkNtpOverride.Checked -or $script:ChkStartupOverride.Checked) {
            # No policy key yet but overrides are requested - create the key and run them
            New-Item -Path $script:BravePolicyPath -Force | Out-Null
            try { [void](Apply-SearchEngineOverride -Path $script:BravePolicyPath) } catch { Write-Log "[$channel] Search override: $_" 'ERR' }
            try { [void](Apply-NtpOverride          -Path $script:BravePolicyPath) } catch { Write-Log "[$channel] NTP override: $_" 'ERR' }
            try { [void](Apply-StartupOverride      -Path $script:BravePolicyPath) } catch { Write-Log "[$channel] Startup override: $_" 'ERR' }
        }
    }
    $script:BravePolicyPath = $originalPath

    foreach ($cb in $script:TaskCheckBoxes) {
        $t = $cb.Tag
        try {
            if ($cb.Checked) {
                Disable-ScheduledTask -TaskName $t.Name -ErrorAction Stop | Out-Null
                Write-Log "DISABLED task $($t.Name)" 'OK'
            } else {
                $existing = Get-ScheduledTask -TaskName $t.Name -ErrorAction SilentlyContinue
                if ($existing -and $existing.State -eq 'Disabled') {
                    Enable-ScheduledTask -TaskName $t.Name -ErrorAction Stop | Out-Null
                    Write-Log "ENABLED task $($t.Name)" 'OK'
                }
            }
        } catch {
            Write-Log "Task $($t.Name): $_" 'WARN'
        }
    }

    foreach ($cb in $script:ServiceCheckBoxes) {
        $s = $cb.Tag
        try {
            $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            if (-not $svc) {
                Write-Log "Service $($s.Name) not present - skipped." 'INFO'
                continue
            }
            if ($cb.Checked) {
                if ($svc.Status -eq 'Running') { Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue }
                Set-Service -Name $s.Name -StartupType Disabled -ErrorAction Stop
                Write-Log "DISABLED service $($s.Name)" 'OK'
            } else {
                if ($svc.StartType -eq 'Disabled') {
                    Set-Service -Name $s.Name -StartupType Manual -ErrorAction Stop
                    Write-Log "RESET service $($s.Name) to Manual" 'OK'
                }
            }
        } catch {
            Write-Log "Service $($s.Name): $_" 'WARN'
        }
    }

    Update-SelectionSummary
    Write-Log "Done. Applied $applied policies, cleared $cleared. Restart Brave to take effect." 'DONE'
    [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.apply.done' @((Get-PresetName $script:ActiveProfile), $applied, $cleared)),
        (T 'msg.title.app'),
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
})
$actionPanel.Controls.Add($btnApply)

$btnRemoveAll = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnRemoveAll 'action.fullRestore')
$btnRemoveAll.Size = New-Object System.Drawing.Size(170, 34)
$btnRemoveAll.Location = New-Object System.Drawing.Point(590, 4)
$btnRemoveAll.BackColor = [System.Drawing.Color]::FromArgb(150, 60, 60)
$btnRemoveAll.ForeColor = [System.Drawing.Color]::White
$btnRemoveAll.Add_Click({
    $targets = $script:TargetChannels -join ', '
    $ans = [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.restore.confirm' @($targets)),
        (T 'msg.title.fullRestore'),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($ans -ne 'Yes') { return }
    Invoke-FullRestore -Backup $chkBackup.Checked
    [System.Windows.Forms.MessageBox]::Show((T 'msg.restore.done'), (T 'msg.title.app'), 'OK', 'Information') | Out-Null
})
$actionPanel.Controls.Add($btnRemoveAll)

# ---- Log box ----------------------------------------------------------------
$script:LogBox = New-Object System.Windows.Forms.TextBox
$script:LogBox.Location = New-Object System.Drawing.Point(10, 810)
$script:LogBox.Size = New-Object System.Drawing.Size(1145, 90)
$script:LogBox.Multiline = $true
$script:LogBox.ScrollBars = 'Vertical'
$script:LogBox.ReadOnly = $true
$script:LogBox.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$script:LogBox.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 18)
$script:LogBox.ForeColor = [System.Drawing.Color]::LightGreen
$script:LogBox.Anchor = 'Left, Right, Bottom'
$form.Controls.Add($script:LogBox)

# ---- Locale bootstrap -------------------------------------------------------
# Order: -Lang, then the saved preference, then the Windows UI culture, then
# English. Applied after the whole UI exists so one pass re-texts everything.
$script:BfoSettings = Get-BfoSettings -Path $BfoSettingsPath
$startupLocale = Resolve-StartupLocale -Requested $Lang -Saved "$($script:BfoSettings['language'])"
if ($startupLocale -ne 'en-US') {
    if (Set-BfoLocale -Code $startupLocale) {
        $form.Font = Get-BfoUiFont -Size 9
        Update-UiLanguage
    }
}
for ($i = 0; $i -lt $script:LocaleList.Count; $i++) {
    if ($script:LocaleList[$i].Code -eq $script:CurrentLocale) { $script:LanguageCombo.SelectedIndex = $i; break }
}
if ($script:LanguageCombo.SelectedIndex -lt 0) { $script:LanguageCombo.SelectedIndex = 0 }
Update-LocaleNote

$script:FilterReady = $true
Update-SelectionSummary
Update-ConfigurationFilter

# ---- Startup ---------------------------------------------------------------
$form.Add_Shown({
    Write-Log "Brave Free Origin v$($script:AppVersion) - running as administrator, OK."
    Write-Log "Brave version: $braveVer"
    Write-Log "UI locale: $($script:CurrentLocale)"
    Write-Log 'Loading current policy state...'
    $btnLoad.PerformClick()
})

[void]$form.ShowDialog()
