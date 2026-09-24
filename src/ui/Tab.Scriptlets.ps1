# ============================================================================
#  Default scriptlets tab (advanced).
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

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
        $script:ScriptletFilterTimer.Stop()
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
    $script:ScriptletFilterTimer.Stop()
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
