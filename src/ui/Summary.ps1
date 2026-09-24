# ============================================================================
#  The "What will happen" tab of the Apply preview: the plan from
#  core\Plan.ps1 told in plain language.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Nothing here knows about individual tweaks. Every change is filed under its
# tweak's Effect tag and described by its own translated description, and
# every Impact tag of a change that gets enforced becomes a warning (tags are
# defined in tweaks\tags.psd1). A new or retagged tweak shows up here with no
# code change.

# Heading icons per Effect; an Effect missing here gets the generic one.
$script:EffectGlyphs = @{
    feature = 0xE711; privacy = 0xE72E; protection = 0xEA18; performance = 0xEC4A
    clutter = 0xE74D; behavior = 0xE713; updates = 0xE895
}

function New-SummaryEntry {
    param([string]$Kind, [string]$Text, [string]$Detail = '', [string]$Tone = '', [int]$Glyph = 0, [string]$Count = '')
    , (New-BfoObject @{
        Kind = $Kind; Text = $Text; Detail = $Detail; Tone = $Tone; Count = $Count
        Glyph = $(if ($Glyph) { [string][char]$Glyph } else { '' })
    })
}

# A policy value the way the row shows it: a choice's label, or the raw value.
function Format-PolicyValue {
    param($Row, $Value)
    if ($Row -and $Row.Choices) {
        $values = @($Row.Policy.Choices.Values)
        for ($i = 0; $i -lt $values.Count; $i++) {
            if ("$($values[$i])" -eq "$Value") { return [string]$Row.Choices[$i].Label }
        }
    }
    return "$Value"
}

# Plan is Get-ApplyPlan's result, Selection the snapshot it was built from.
function Get-PlanSummary {
    param($Plan, $Selection)
    $effects = [ordered]@{}
    foreach ($id in $script:EffectIds) { $effects[$id] = New-BfoList }
    $backToDefault = New-BfoList
    $overrides = New-BfoList
    $impacts = [ordered]@{}
    $changes = 0
    $keeps = 0
    $multi = @($Plan.Channels).Count -gt 1

    # Files one enforced change under its Effect and notes its Impacts.
    $enforce = {
        param([string]$Effect, $ImpactIds, [string]$Text, [string]$Detail)
        # Indexed, never assigned from an if: that would unroll an empty list
        # into $null.
        if (-not $effects.Contains($Effect)) { $Effect = @($effects.Keys)[0] }
        $effects[$Effect].Add((New-SummaryEntry -Kind Item -Text $Text -Detail $Detail))
        foreach ($impact in @($ImpactIds | Where-Object { $_ })) {
            if (-not $impacts.Contains($impact)) { $impacts[$impact] = New-BfoList }
            if (-not $impacts[$impact].Contains($Text)) { $impacts[$impact].Add($Text) }
        }
    }

    foreach ($channel in $Plan.Channels) {
        $prefix = if ($multi) { "[$($channel.Channel)] " } else { '' }
        foreach ($p in $channel.Policies) {
            $row = $script:RowIndex["Policy:$($p.Name)"]
            $title = if ($row) { $row.Title } else { $p.Name }
            switch ($p.Verb) {
                'KEEP' { $keeps++ }
                'ADD' {
                    $changes++
                    & $enforce $row.Effect $row.ImpactIds $title "$prefix$($p.Name) = $(Format-PolicyValue $row $p.Target)"
                }
                'CHANGE' {
                    $changes++
                    & $enforce $row.Effect $row.ImpactIds $title ($prefix + (T 'preview.changed' @($p.Name, (Format-PolicyValue $row $p.Current), (Format-PolicyValue $row $p.Target))))
                }
                'CLEAR' {
                    $changes++
                    $backToDefault.Add((New-SummaryEntry -Kind Item -Text $title -Detail ($prefix + (T 'preview.cleared' @($p.Name, (Format-PolicyValue $row $p.Current))))))
                }
            }
        }

        foreach ($spec in @(
            @{ Plan = $channel.Search;  Section = 'searchTab.secSearch';  Set = 'preview.searchSet';  Cleared = 'preview.searchCleared';  Label = { Get-SearchLabel $args[0] $Selection.Overrides } }
            @{ Plan = $channel.Ntp;     Section = 'searchTab.secNtp';     Set = 'preview.ntpSet';     Cleared = 'preview.ntpCleared';     Label = { Get-NtpLabel $args[0] $Selection.Overrides } }
            @{ Plan = $channel.Startup; Section = 'searchTab.secStartup'; Set = 'preview.startupSet'; Cleared = 'preview.startupCleared'; Label = { Get-StartupLabel $args[0] $Selection.Overrides } }
        )) {
            $part = $spec.Plan
            if ($part.Error) {
                $overrides.Add((New-SummaryEntry -Kind Item -Text (T 'preview.overrideSkipped' @((T $spec.Section))) -Detail "$prefix$($part.Error)"))
                continue
            }
            if ($part.Changes -eq 0) { continue }
            $changes++
            $enabled = if ($part.Desired -is [System.Collections.IDictionary]) { $part.Desired.Count -gt 0 } else { [bool]$part.Desired.Enabled }
            $text = if ($enabled) { T $spec.Set @((& $spec.Label $part.Desired)) } else { T $spec.Cleared }
            $overrides.Add((New-SummaryEntry -Kind Item -Text $text -Detail ($prefix.Trim())))
        }
    }

    foreach ($kind in @('Task', 'Service')) {
        $items = if ($kind -eq 'Task') { $Plan.Tasks } else { $Plan.Services }
        foreach ($item in $items) {
            $row = $script:RowIndex["${kind}:$($item.Name)"]
            $title = if ($row) { $row.Title } else { $item.Name }
            switch ($item.Verb) {
                'KEEP' { $keeps++ }
                'DISABLE' {
                    $changes++
                    $detail = if ($kind -eq 'Task') { T 'preview.taskOff' @($item.Name) } else { T 'preview.serviceOff' @($item.Name) }
                    & $enforce $row.Effect $row.ImpactIds $title $detail
                }
                'ENABLE' { $changes++; $backToDefault.Add((New-SummaryEntry -Kind Item -Text $title -Detail (T 'preview.taskOn' @($item.Name)))) }
                'RESET'  { $changes++; $backToDefault.Add((New-SummaryEntry -Kind Item -Text $title -Detail (T 'preview.serviceReset' @($item.Name)))) }
            }
        }
    }

    # ---- Assemble ---------------------------------------------------------------
    $entries = New-BfoList
    $channelText = $Selection.Channels -join ', '
    if ($changes -eq 0) {
        $entries.Add((New-SummaryEntry -Kind Lead -Text (T 'preview.leadNone' @($channelText))))
    } else {
        # A named mode reads as "Applying Recommended"; a hand-picked mix as
        # "Applying your selection".
        $mode = if (@('Custom', 'CurrentState') -contains $Selection.Profile) { T 'preview.yourSelection' } else { Get-PresetName $Selection.Profile }
        $entries.Add((New-SummaryEntry -Kind Lead -Text (T 'preview.lead' @($mode, $channelText, $changes, $keeps))))
    }

    if ($impacts.Count -gt 0) {
        $entries.Add((New-SummaryEntry -Kind Section -Text (T 'preview.secHeadsUp') -Tone caution -Glyph 0xE7BA))
        foreach ($impact in $impacts.Keys) {
            $entries.Add((New-SummaryEntry -Kind Note -Text (T "impact.$impact.name") -Detail (T "impact.$impact.explain") -Tone caution))
            foreach ($text in $impacts[$impact]) { $entries.Add((New-SummaryEntry -Kind Item -Text $text)) }
        }
    }

    foreach ($effect in $effects.Keys) {
        $group = $effects[$effect]
        if ($group.Count -eq 0) { continue }
        $glyph = if ($script:EffectGlyphs.ContainsKey($effect)) { $script:EffectGlyphs[$effect] } else { 0xE8FD }
        $entries.Add((New-SummaryEntry -Kind Section -Text (T "effect.$effect.title") -Glyph $glyph -Count "  $($group.Count)"))
        foreach ($entry in $group) { $entries.Add($entry) }
    }
    if ($overrides.Count -gt 0) {
        $entries.Add((New-SummaryEntry -Kind Section -Text (T 'preview.secOverrides') -Glyph 0xE721 -Count "  $($overrides.Count)"))
        foreach ($entry in $overrides) { $entries.Add($entry) }
    }
    if ($backToDefault.Count -gt 0) {
        $entries.Add((New-SummaryEntry -Kind Section -Text (T 'preview.secDefault') -Glyph 0xE7A7 -Count "  $($backToDefault.Count)"))
        foreach ($entry in $backToDefault) { $entries.Add($entry) }
    }

    if ($changes -gt 0) {
        $entries.Add((New-SummaryEntry -Kind Section -Text '' -Glyph 0))
        if ($Selection.Backup) { $entries.Add((New-SummaryEntry -Kind Note -Text (T 'preview.noteBackup'))) }
        else { $entries.Add((New-SummaryEntry -Kind Note -Text (T 'preview.noteNoBackup') -Tone caution)) }
        $entries.Add((New-SummaryEntry -Kind Note -Text (T 'preview.noteRestart')))
    }
    if ((Get-PendingCounts).Hosts -gt 0) { $entries.Add((New-SummaryEntry -Kind Note -Text (T 'preview.noteHosts'))) }
    , $entries
}

# Labels for the three overrides, from what would actually be written.
function Get-SearchLabel {
    param($Desired, $Overrides)
    $item = $script:Vm.EngineItems[(Get-ChoiceIndex $script:Vm.EngineItems $Overrides.EngineId)]
    if ($item.Id -eq 'custom') { return [string]$Desired['DefaultSearchProviderSearchURL'].Value }
    return [string]$item.Label
}

function Get-NtpLabel {
    param($Desired, $Overrides)
    $item = $script:Vm.DestinationItems[(Get-ChoiceIndex $script:Vm.DestinationItems $Overrides.DestinationId)]
    if ($item.Id -eq 'custom' -or $item.Id -eq 'matchSearch') { return [string]$Desired['NewTabPageLocation'].Value }
    return [string]$item.Label
}

function Get-StartupLabel {
    param($Desired, $Overrides)
    $label = [string]$script:Vm.StartupModeItems[(Get-ChoiceIndex $script:Vm.StartupModeItems $Overrides.StartupModeId)].Label
    if (@($Desired.Urls).Count -gt 0 -and -not $script:StartupModes[$Desired.ModeId].FixedURL) { $label += " ($($Desired.Urls -join ', '))" }
    return $label
}

# The same summary as plain text, for Copy and Save.
function ConvertTo-SummaryText {
    param($Entries)
    $text = New-Object System.Text.StringBuilder
    foreach ($entry in $Entries) {
        switch ($entry.Kind) {
            'Lead'    { [void]$text.AppendLine($entry.Text) }
            'Section' { if ($entry.Text) { [void]$text.AppendLine(''); [void]$text.AppendLine("$($entry.Text)$($entry.Count)") } else { [void]$text.AppendLine('') } }
            'Item'    {
                [void]$text.AppendLine("  - $($entry.Text)")
                if ($entry.Detail) { [void]$text.AppendLine("    $($entry.Detail)") }
            }
            'Note'    {
                [void]$text.AppendLine("  ! $($entry.Text)")
                if ($entry.Detail) { [void]$text.AppendLine("    $($entry.Detail)") }
            }
        }
    }
    return $text.ToString()
}

# ---- Wiring ----------------------------------------------------------------------------
$ui.DialogTabSummary.Add_Checked({ Update-DialogTab })
$ui.DialogTabDetails.Add_Checked({ Update-DialogTab })
