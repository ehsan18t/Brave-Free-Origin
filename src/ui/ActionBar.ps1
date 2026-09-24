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
    $result = Invoke-Apply -Backup $chkBackup.Checked
    [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.apply.done' @((Get-PresetName $script:ActiveProfile), $result.Applied, $result.Cleared)),
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
