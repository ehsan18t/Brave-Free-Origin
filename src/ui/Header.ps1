# ============================================================================
#  Header: title, detected Brave version, target channel and language picker.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Header panel
$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 112
$header.BackColor = [System.Drawing.Color]::FromArgb(22, 27, 34)

$titleLabel = New-LocControl Label $header 'app.name' 18 10 -FontSize 18 -Semibold -ForeColor 'White'
$titleLabel.AutoSize = $true
[void](New-LocControl Label $header 'header.subtitle' 20 43 760 18 -FontSize 9 -ForeColor 'Gainsboro')
[void](New-LocControl Label $header 'header.braveDetected' 20 70 280 18 -FontSize 8.5 -ForeColor 'LightSteelBlue' -FormatArgs @($braveVer))

# Channel selector (multi-channel support)
$detectedChannels = Get-DetectedChannels
[void](New-LocControl Label $header 'header.targetChannel' 310 70 95 18 -FontSize 8.5 -ForeColor 'LightSteelBlue')

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
        $script:TargetPathLabel.Text = T 'header.hives' @(($script:TargetChannels -join ', '), $script:TargetChannels.Count)
    } elseif ($id) {
        $script:TargetChannels = @($id)
        $script:TargetPathLabel.Text = "-> $($script:Channels[$id].Path)"
    }
    Write-Log "Target channel(s): $($script:TargetChannels -join ', ')"
})

# ---- Language picker --------------------------------------------------------
[void](New-LocControl Label $header 'header.language' 880 10 70 18 -FontSize 8.5 -ForeColor 'LightSteelBlue')

$script:LocaleList = @(Get-AvailableLocales)
$script:LanguageCombo = New-Object System.Windows.Forms.ComboBox
$script:LanguageCombo.Location = New-Object System.Drawing.Point(950, 7)
$script:LanguageCombo.Size = New-Object System.Drawing.Size(170, 22)
$script:LanguageCombo.DropDownStyle = 'DropDownList'
$script:LanguageCombo.FlatStyle = 'Flat'
foreach ($loc in $script:LocaleList) { [void]$script:LanguageCombo.Items.Add($loc.Name) }
$header.Controls.Add($script:LanguageCombo)

# Text is set by Update-LocaleNote, not bound: it depends on the locale file.
$script:LblLocaleNote = New-LocControl Label $header '' 950 31 200 14 -FontSize 7.5 -ForeColor ([System.Drawing.Color]::FromArgb(255, 212, 153))

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

[void](New-LocControl Label $header 'header.originNote' 20 88 950 18 -FontSize 8.5 -ForeColor ([System.Drawing.Color]::FromArgb(255, 212, 153)))

$form.Controls.Add($header)
