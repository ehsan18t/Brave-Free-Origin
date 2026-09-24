# ============================================================================
#  Action bar (preview, apply, full restore) and the log box.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- Action buttons ---------------------------------------------------------
$actionPanel = New-Object System.Windows.Forms.Panel
$actionPanel.Location = New-Object System.Drawing.Point(10, 760)
$actionPanel.Size = New-Object System.Drawing.Size(1145, 44)
$actionPanel.Anchor = 'Left, Right, Bottom'
$form.Controls.Add($actionPanel)

# Read by the Preview report as well as by Apply and Full restore.
$chkBackup = New-LocControl CheckBox $actionPanel 'action.backup' 0 12 270 20
$chkBackup.Checked = $true

[void](New-LocControl Button $actionPanel 'action.preview' 280 4 140 34 -OnClick {
    Show-TextReport -Title (T 'report.previewTitle') -Text (New-ApplyPlanReport) -DefaultFileName "brave-free-origin-apply-preview-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
})

[void](New-LocControl Button $actionPanel 'action.apply' 430 4 150 34 -FontSize 9 -Semibold `
    -BackColor ([System.Drawing.Color]::FromArgb(37, 99, 63)) -ForeColor 'White' -OnClick {
    $result = Invoke-Apply -Backup $chkBackup.Checked
    Show-BfoMessage 'msg.apply.done' @((Get-PresetName $script:ActiveProfile), $result.Applied, $result.Cleared)
})

[void](New-LocControl Button $actionPanel 'action.fullRestore' 590 4 170 34 `
    -BackColor ([System.Drawing.Color]::FromArgb(150, 60, 60)) -ForeColor 'White' -OnClick {
    $targets = $script:TargetChannels -join ', '
    if (-not (Show-BfoMessage 'msg.restore.confirm' @($targets) -TitleKey 'msg.title.fullRestore' -Icon Warning -YesNo)) { return }
    Invoke-FullRestore -Backup $chkBackup.Checked
    Show-BfoMessage 'msg.restore.done'
})

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
