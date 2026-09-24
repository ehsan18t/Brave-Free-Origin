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

[void](New-LocControl Label $modePanel 'mode.intro' 14 10 620 18 -FontSize 9 -Semibold)

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
    $btn = New-LocControl Button $modePanel "preset.$($spec.Mode).name" 14 34 104 30 -BackColor $spec.Color `
        -TipKey "preset.$($spec.Mode).description" -OnClick { Apply-Preset $this.Tag }
    $btn.Tag = $spec.Mode
    $script:ModeButtons += $btn
}
Set-ModeButtonRow

# Summary labels: their text is written by Update-SelectionSummary.
$script:ModeLabel       = New-LocControl Label $modePanel '' 14 78 170 18 -FontSize 9 -Semibold
$script:SelectionLabel  = New-LocControl Label $modePanel '' 190 78 150 18
$script:SystemLabel     = New-LocControl Label $modePanel '' 346 78 190 18
$script:RiskLabel       = New-LocControl Label $modePanel '' 542 78 130 18 -FontSize 9 -Semibold
$script:ModeDescription = New-LocControl Label $modePanel '' 678 72 440 36 -FontSize 8.5 -ForeColor 'DimGray'
