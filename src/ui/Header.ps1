# ============================================================================
#  Header: title, detected Brave version, target channel and language picker.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

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
