# ============================================================================
#  Tweak data loader.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
#
#  Everything the app can change lives as plain data in tweaks\*.psd1 (see
#  tweaks\README.md). This file reads it and builds the script-scope tables the
#  rest of the app uses. Nothing in tweaks\ is ever executed: .psd1 files are
#  parsed by Import-PowerShellDataFile, which only accepts literal data.
# ============================================================================

$script:TweaksDir = Join-Path $script:AppRoot 'tweaks'

function Import-TweakFile {
    param([string]$RelativePath)
    $path = Join-Path $script:TweaksDir $RelativePath
    # Parsing ourselves points at the line a hand edit broke, where
    # Import-PowerShellDataFile only says "could not be parsed".
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors) {
        throw "tweaks\$RelativePath, line $($parseErrors[0].Extent.StartLineNumber): $($parseErrors[0].Message)"
    }
    # Then exactly what Import-PowerShellDataFile does with the parse, without
    # its per-call module overhead (most of the time spent loading tweaks):
    # SafeGetValue returns the table and refuses anything that is not literal
    # data, so nothing in these files can ever run.
    $table = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false)
    if (-not $table) { throw "tweaks\$RelativePath - the file must hold one @{ ... } table." }
    try {
        return $table.SafeGetValue()
    } catch {
        throw "tweaks\$RelativePath - $($_.Exception.Message)"
    }
}

function Assert-TweakField {
    param([bool]$Condition, [string]$RelativePath, [string]$Message)
    if (-not $Condition) { throw "tweaks\$RelativePath - $Message" }
}

# Import-PowerShellDataFile has no ordered hashtables, so every list is an array
# of entries and this turns it back into an id-keyed, ordered table. Each entry
# is copied into a fresh hashtable: the UI updates some of them in place.
function ConvertTo-TweakTable {
    param([object[]]$Entries, [string]$LabelPrefix)
    # Id becomes the table key and LegacyName only feeds the import maps.
    $Drop = @('Id', 'LegacyName')
    $table = [ordered]@{}
    foreach ($entry in $Entries) {
        $item = @{}
        foreach ($key in $entry.Keys) { if ($Drop -notcontains $key) { $item[$key] = $entry[$key] } }
        if ($LabelPrefix) { $item['LabelKey'] = "$LabelPrefix.$($entry.Id)" }
        $table[$entry.Id] = $item
    }
    return $table
}

function Get-LegacyIdMap {
    param([object[]]$Entries)
    $map = @{}
    foreach ($entry in $Entries) { if ($entry.LegacyName) { $map[$entry.LegacyName] = $entry.Id } }
    return $map
}

# Every policy, task, service and hosts group carries one Effect and optional
# Impacts, ids from tweaks\tags.psd1. Checked on load, so a typo stops the app
# with the file and entry named instead of silently dropping out of the preview.
function Assert-TweakTags {
    param($Entry, [string]$What, [string]$RelativePath)
    Assert-TweakField -Condition ($script:EffectIds -contains $Entry.Effect) -RelativePath $RelativePath `
        -Message "${What}: Effect must be one of $($script:EffectIds -join ', ') (tweaks\tags.psd1)."
    foreach ($impact in @($Entry.Impacts)) {
        if ($null -eq $impact) { continue }
        Assert-TweakField -Condition ($script:ImpactIds -contains $impact) -RelativePath $RelativePath `
            -Message "${What}: unknown Impact '$impact'. Known: $($script:ImpactIds -join ', ') (tweaks\tags.psd1)."
    }
}

# A task or service entry: a hashtable with Name and tags. A bare name string
# is accepted too, so the check below can say what is missing.
function ConvertTo-SystemEntry {
    param($Entry, [string]$Kind)
    $item = if ($Entry -is [hashtable]) { $Entry } else { @{ Name = "$Entry" } }
    Assert-TweakField -Condition ([bool]$item.Name) -RelativePath 'system.psd1' -Message "Every $Kind needs a Name."
    Assert-TweakTags -Entry $item -What "$Kind $($item.Name)" -RelativePath 'system.psd1'
    return @{ Name = $item.Name; Effect = $item.Effect; Impacts = @($item.Impacts | Where-Object { $_ }) }
}

# Loads every tweak file into the script-scope tables. Wrapped in a function so
# its temporaries stay local: this file is dot-sourced into the app's scope.
function Import-Tweaks {
    # ---- Tags ----------------------------------------------------------------------
    # Loaded first: every other file is checked against them.
    $tagData = Import-TweakFile 'tags.psd1'
    $script:EffectIds = @($tagData.Effects | ForEach-Object { $_.Id })
    $script:ImpactIds = @($tagData.Impacts | ForEach-Object { $_.Id })
    Assert-TweakField -Condition ($script:EffectIds.Count -gt 0) -RelativePath 'tags.psd1' -Message 'Effects is empty.'

    # ---- Policies ----------------------------------------------------------------
    # One file per tab in tweaks\policies; the numeric file name prefix sets the tab
    # order. Each policy: Name (registry value name, never translated), Type
    # (DWORD/STRING), ApplyValue (what to write when ticked), Recommended,
    # MaxPrivacy and optional Choices. Human-readable text lives in the string
    # catalog under 'policy.<Name>.description' so it can be localized without ever
    # touching the technical identifiers.
    $script:Policies = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $script:TweaksDir 'policies') -Filter '*.psd1' -File | Sort-Object Name)) {
        $relative = "policies\$($file.Name)"
        $data = Import-TweakFile $relative
        Assert-TweakField -Condition ([bool]$data.Category) -RelativePath $relative -Message 'Category is missing.'
        Assert-TweakField -Condition (-not $script:Policies.Contains($data.Category)) -RelativePath $relative -Message "Category '$($data.Category)' is already used by another file."
        $list = @()
        foreach ($entry in $data.Policies) {
            Assert-TweakField -Condition ($entry -is [hashtable] -and $entry.Name) -RelativePath $relative -Message 'Every policy needs a Name.'
            Assert-TweakField -Condition (@('DWORD', 'STRING') -contains $entry.Type) -RelativePath $relative -Message "$($entry.Name): Type must be 'DWORD' or 'STRING'."
            Assert-TweakField -Condition ($entry.ContainsKey('ApplyValue')) -RelativePath $relative -Message "$($entry.Name): ApplyValue is missing."
            Assert-TweakTags -Entry $entry -What $entry.Name -RelativePath $relative
            $policy = @{}
            foreach ($key in $entry.Keys) { $policy[$key] = $entry[$key] }
            if ($entry.Choices) {
                $choices = [ordered]@{}
                foreach ($choice in $entry.Choices) { $choices[$choice.Id] = $choice.Value }
                $policy['Choices'] = $choices
            }
            $policy['Impacts'] = @($entry.Impacts | Where-Object { $_ })
            $list += $policy
        }
        $script:Policies[$data.Category] = $list
    }

    # ---- System: scheduled tasks and services -----------------------------------
    # Task / service descriptions live under task.<Name>.description and
    # service.<Name>.description in the string catalog.
    $systemData = Import-TweakFile 'system.psd1'
    $script:ScheduledTasks = @(foreach ($entry in $systemData.ScheduledTasks) { ConvertTo-SystemEntry $entry 'task' })
    $script:Services       = @(foreach ($entry in $systemData.Services) { ConvertTo-SystemEntry $entry 'service' })

    # ---- Hosts blocklist groups --------------------------------------------------
    $hostsData = Import-TweakFile 'hosts.psd1'
    $script:HostsBlocks = @(foreach ($group in $hostsData.Groups) {
        Assert-TweakTags -Entry $group -What "hosts group $($group.Id)" -RelativePath 'hosts.psd1'
        @{
            Id             = $group.Id
            NameKey        = "hosts.$($group.Id).name"
            DescriptionKey = "hosts.$($group.Id).description"
            Recommended    = $group.Recommended
            Domains        = $group.Domains
            Effect         = $group.Effect
            Impacts        = @($group.Impacts | Where-Object { $_ })
        }
    })

    # ---- Search engines, destinations, startup modes ----------------------------
    $searchData = Import-TweakFile 'search.psd1'
    $script:SearchEngines      = ConvertTo-TweakTable -Entries $searchData.Engines      -LabelPrefix 'engine'
    $script:DestinationOptions = ConvertTo-TweakTable -Entries $searchData.Destinations -LabelPrefix 'destination'
    $script:StartupModes       = ConvertTo-TweakTable -Entries $searchData.StartupModes -LabelPrefix 'startupMode'

    # ---- Stable id arrays that back the ComboBoxes -----------------------------
    # Item order in each ComboBox matches the order of these arrays; the link is
    # SelectedIndex, which is the one binding WinForms guarantees for a
    # non-data-bound ComboBox and which survives re-translation intact.
    $script:SearchEngineIds       = @($script:SearchEngines.Keys)
    $script:SearchEngineLabelKeys = @($script:SearchEngineIds | ForEach-Object { $script:SearchEngines[$_].LabelKey })
    $script:DestinationIds        = @($script:DestinationOptions.Keys)
    $script:DestinationLabelKeys  = @($script:DestinationIds | ForEach-Object { $script:DestinationOptions[$_].LabelKey })
    $script:StartupModeIds        = @($script:StartupModes.Keys)
    $script:StartupModeLabelKeys  = @($script:StartupModeIds | ForEach-Object { $script:StartupModes[$_].LabelKey })

    # Legacy config migration: v1.5-v1.11 exports stored the English display
    # label. Importing those must keep working.
    $script:LegacyHostsIds        = Get-LegacyIdMap $hostsData.Groups
    $script:LegacySearchEngineIds = Get-LegacyIdMap $searchData.Engines
    $script:LegacyDestinationIds  = Get-LegacyIdMap $searchData.Destinations
    $script:LegacyStartupModeIds  = Get-LegacyIdMap $searchData.StartupModes

    # ---- Presets -----------------------------------------------------------------
    $script:PresetDefinitions = Import-TweakFile 'presets.psd1'
}

# A hand-edited .psd1 with a typo must stop the app with a readable message,
# not a stack of errors from every tab that expected the data.
try {
    Import-Tweaks
} catch {
    $script:StartupError = "Brave Free Origin could not load its tweak data.`r`n`r`n$($_.Exception.Message)"
}
