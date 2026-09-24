# ============================================================================
#  Binding controls to string keys, fonts and re-texting the UI on a language switch.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

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
