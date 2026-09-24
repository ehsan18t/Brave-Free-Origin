# ============================================================================
#  Mode deck: one-click preset buttons and the selection summary.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

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
