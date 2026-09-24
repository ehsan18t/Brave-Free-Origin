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

# Scriptlet message boxes all share the scriptlet title.
function Show-ScriptletMessage {
    param([string]$Key, [object[]]$FormatArgs, [string]$Icon = 'Information', [switch]$YesNo)
    Show-BfoMessage $Key $FormatArgs -TitleKey 'msg.title.scriptlet' -Icon $Icon -YesNo:$YesNo
}

[void](New-LocControl Label $scriptletsTab 'scriptlet.intro' 10 8 1100 34 -FontSize 9 -ForeColor ([System.Drawing.Color]::FromArgb(70, 70, 90)))
[void](New-LocControl Label $scriptletsTab 'scriptlet.risk' 10 38 1100 34 -FontSize 8.5 -Semibold -ForeColor ([System.Drawing.Color]::FromArgb(160, 70, 30)))
[void](New-LocControl Label $scriptletsTab 'scriptlet.rootLabel' 10 80 145 18 -FontSize 9)

$script:TxtScriptletRoot = New-Object System.Windows.Forms.TextBox
$script:TxtScriptletRoot.Location = New-Object System.Drawing.Point(155, 76)
$script:TxtScriptletRoot.Size = New-Object System.Drawing.Size(560, 22)
$script:TxtScriptletRoot.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$script:TxtScriptletRoot.Text = Get-ScriptletDefaultRoot
$scriptletsTab.Controls.Add($script:TxtScriptletRoot)

[void](New-LocControl Button $scriptletsTab 'scriptlet.autoPath' 725 74 85 26 -OnClick {
    $script:TxtScriptletRoot.Text = Get-ScriptletDefaultRoot
    Write-Log "Scriptlet User Data path set to: $($script:TxtScriptletRoot.Text)"
})
[void](New-LocControl Button $scriptletsTab 'scriptlet.browse' 815 74 85 26 -OnClick {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = T 'dialog.browseUserData'
    if (Test-Path $script:TxtScriptletRoot.Text) { $dlg.SelectedPath = $script:TxtScriptletRoot.Text }
    if ($dlg.ShowDialog() -eq 'OK') {
        $script:TxtScriptletRoot.Text = $dlg.SelectedPath
        Write-Log "Scriptlet User Data path set manually: $($dlg.SelectedPath)"
    }
})
$script:BtnScriptletScan = New-LocControl Button $scriptletsTab 'scriptlet.scan' 905 74 80 26 `
    -BackColor ([System.Drawing.Color]::FromArgb(37, 99, 63)) -ForeColor 'White' -OnClick { Invoke-ScriptletScan }
[void](New-LocControl Button $scriptletsTab 'scriptlet.openFolder' 990 74 95 26 -OnClick {
    if (Test-Path $script:TxtScriptletRoot.Text) { Start-Process explorer.exe $script:TxtScriptletRoot.Text }
    else { Show-ScriptletMessage 'msg.scriptlet.folderMissing' -Icon Warning }
})

[void](New-LocControl Label $scriptletsTab 'scriptlet.searchLabel' 10 112 85 18 -FontSize 9)

$script:TxtScriptletSearch = New-Object System.Windows.Forms.TextBox
$script:TxtScriptletSearch.Location = New-Object System.Drawing.Point(95, 108)
$script:TxtScriptletSearch.Size = New-Object System.Drawing.Size(360, 22)
$script:TxtScriptletSearch.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$script:TxtScriptletSearch.Add_TextChanged({ Start-ScriptletFilterDelay })
$script:TxtScriptletSearch.Add_KeyDown({
    if ($_.KeyCode -eq 'Enter') {
        Invoke-ScriptletFilterNow
        $_.SuppressKeyPress = $true
    }
})
$scriptletsTab.Controls.Add($script:TxtScriptletSearch)

$script:ScriptletFilterTimer = New-Object System.Windows.Forms.Timer
$script:ScriptletFilterTimer.Interval = 250
$script:ScriptletFilterTimer.Add_Tick({ Invoke-ScriptletFilterNow })

$script:BtnScriptletFilter = New-LocControl Button $scriptletsTab 'scriptlet.filter' 465 106 75 26 -OnClick { Invoke-ScriptletFilterNow }

$script:ChkScriptletDisabledOnly = New-LocControl CheckBox $scriptletsTab 'scriptlet.disabledOnly' 550 110 190 20
$script:ChkScriptletDisabledOnly.Add_CheckedChanged({ Update-ScriptletListView })

$script:ChkScriptletAdvanced = New-LocControl CheckBox $scriptletsTab 'scriptlet.advancedMode' 755 110 330 20 -ForeColor ([System.Drawing.Color]::FromArgb(150, 60, 60))

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
    # $_ is the ItemCheckedEventArgs.
    if (-not $script:SuppressScriptletStatusEvents) {
        Set-ScriptletRecordChecked -Record $_.Item.Tag -Checked $_.Item.Checked
        Update-ScriptletStatusText
    }
})
foreach ($column in $script:ScriptletColumns) { [void]$script:ScriptletList.Columns.Add((T $column[0]), $column[1]) }
$scriptletsTab.Controls.Add($script:ScriptletList)

$script:LblScriptletStatus = New-LocControl Label $scriptletsTab 'scriptlet.statusIdle' 10 336 520 18 -FontSize 9 -ForeColor 'DimGray'

$script:ScriptletProgress = New-Object System.Windows.Forms.ProgressBar
$script:ScriptletProgress.Location = New-Object System.Drawing.Point(545, 336)
$script:ScriptletProgress.Size = New-Object System.Drawing.Size(575, 16)
$script:ScriptletProgress.Minimum = 0
$script:ScriptletProgress.Maximum = 1000
$script:ScriptletProgress.Value = 0
$script:ScriptletProgress.Style = 'Continuous'
$script:ScriptletProgress.Anchor = 'Top, Left, Right'
$scriptletsTab.Controls.Add($script:ScriptletProgress)

$script:ChkScriptletAffectDuplicates = New-LocControl CheckBox $scriptletsTab 'scriptlet.affectDupes' 10 360 270 20 -TipKey 'scriptlet.tipAffectDupes'
$script:ChkScriptletAffectDuplicates.Checked = $true

$script:BtnScriptletCheckVisible = New-LocControl Button $scriptletsTab 'scriptlet.checkFiltered' 290 356 125 26 `
    -TipKey 'scriptlet.tipCheckFiltered' -OnClick { Set-ScriptletVisibleChecks $true }
$script:BtnScriptletClearChecks = New-LocControl Button $scriptletsTab 'scriptlet.clearChecks' 425 356 105 26 -OnClick { Set-ScriptletVisibleChecks $false }

# ---- Write actions ------------------------------------------------------------
# Every button that edits Brave's filter lists requires Advanced edit mode (see
# Test-ScriptletAdvancedWriteAllowed) and rescans afterwards.
$script:BtnScriptletDisable = New-LocControl Button $scriptletsTab 'scriptlet.disableChecked' 10 388 125 28 `
    -BackColor ([System.Drawing.Color]::FromArgb(150, 60, 60)) -ForeColor 'White' -OnClick {
    $records = @(Get-SelectedScriptletRecords)
    if ($records.Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.selectFirst'; return }
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    if (-not (Show-ScriptletMessage 'msg.scriptlet.confirmDisable' @($records.Count, $script:ScriptletDisablePrefix) -Icon Warning -YesNo)) { return }
    Invoke-ScriptletWrite -FailLog 'Scriptlet disable failed' -FailKey 'msg.scriptlet.disableFailed' -Action {
        $changed = Set-ScriptletRuleState -Records $records -Enable:$false -AffectDuplicates:$script:ChkScriptletAffectDuplicates.Checked
        "Scriptlets disabled: $changed line(s)."
    }
}
$script:BtnScriptletEnable = New-LocControl Button $scriptletsTab 'scriptlet.enableChecked' 145 388 120 28 -OnClick {
    $records = @(Get-SelectedScriptletRecords)
    if ($records.Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.selectFirst'; return }
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    Invoke-ScriptletWrite -FailLog 'Scriptlet enable failed' -FailKey 'msg.scriptlet.enableFailed' -Action {
        $changed = Set-ScriptletRuleState -Records $records -Enable:$true -AffectDuplicates:$script:ChkScriptletAffectDuplicates.Checked
        "Scriptlets enabled: $changed line(s)."
    }
}
[void](New-LocControl Button $scriptletsTab 'scriptlet.viewSelected' 275 388 115 28 -OnClick {
    $records = @(Get-SelectedScriptletRecords)
    if ($records.Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.selectOne'; return }
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
[void](New-LocControl Button $scriptletsTab 'scriptlet.backupAll' 400 388 120 28 -OnClick {
    try {
        $files = @($script:ScriptletRules | Select-Object -ExpandProperty File -Unique)
        if ($files.Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.scanFirst'; return }
        foreach ($file in $files) { [void](Backup-ScriptletFile -File $file) }
        Show-ScriptletMessage 'msg.scriptlet.backupDone' @($files.Count)
    } catch {
        Write-Log "Scriptlet backup failed: $_" 'ERR'
        Show-ScriptletMessage 'msg.scriptlet.backupFailed' @("$_") -Icon Error
    }
})
[void](New-LocControl Button $scriptletsTab 'scriptlet.restoreSelected' 530 388 145 28 -OnClick {
    $records = @(Get-SelectedScriptletRecords)
    if ($records.Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.restoreSelectFile'; return }
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    $files = @($records | Select-Object -ExpandProperty File -Unique)
    if (-not (Show-ScriptletMessage 'msg.scriptlet.confirmRestoreSel' @($files.Count) -Icon Warning -YesNo)) { return }
    Invoke-ScriptletWrite -FailLog 'Scriptlet restore selected failed' -FailKey 'msg.scriptlet.restoreFailed' -Action {
        foreach ($file in $files) { Restore-ScriptletBackup -File $file }
        "Restored $($files.Count) scriptlet list file(s) from backup."
    }
})
[void](New-LocControl Button $scriptletsTab 'scriptlet.restoreAll' 685 388 140 28 -OnClick {
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    if (-not (Show-ScriptletMessage 'msg.scriptlet.confirmRestoreAll' @($script:TxtScriptletRoot.Text) -Icon Warning -YesNo)) { return }
    Invoke-ScriptletWrite -FailLog 'Scriptlet restore all failed' -FailKey 'msg.scriptlet.restoreAllFailed' -Action {
        $count = Restore-AllScriptletBackups -Root $script:TxtScriptletRoot.Text.Trim()
        "Restored $count scriptlet backup file(s)."
    }
})
[void](New-LocControl Button $scriptletsTab 'scriptlet.exportCsv' 835 388 130 28 -OnClick {
    if (-not $script:ScriptletVisibleRules -or $script:ScriptletVisibleRules.Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.nothingVisible'; return }
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Filter = '{0} (*.csv)|*.csv' -f (T 'dialog.filter.csv')
    $sfd.FileName = "brave-free-origin-scriptlets-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    if ($sfd.ShowDialog() -ne 'OK') { return }
    $script:ScriptletVisibleRules |
        Select-Object Enabled,Domain,Scriptlet,Arguments,Source,Version,ComponentId,File,LineNumber,Rule |
        Export-Csv -Path $sfd.FileName -NoTypeInformation -Encoding UTF8
    Write-Log "Scriptlet CSV exported: $($sfd.FileName)" 'OK'
})
[void](New-LocControl Button $scriptletsTab 'scriptlet.exportPrefs' 10 424 150 28 -OnClick {
    if (-not $script:ScriptletRules -or $script:ScriptletRules.Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.noRulesLoaded'; return }
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Filter = '{0} (*.json)|*.json' -f (T 'dialog.filter.scriptletPrefs')
    $sfd.FileName = "brave-free-origin-disabled-scriptlets-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    if ($sfd.ShowDialog() -ne 'OK') { return }
    try {
        $count = Export-ScriptletDisabledPreferences -File $sfd.FileName
        Write-Log "Disabled scriptlet prefs exported: $count rule(s)." 'OK'
    } catch {
        Show-ScriptletMessage 'msg.scriptlet.exportFailed' @("$_") -Icon Error
    }
})
$script:BtnScriptletImportPrefs = New-LocControl Button $scriptletsTab 'scriptlet.importPrefs' 170 424 165 28 -OnClick {
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = '{0} (*.json)|*.json' -f (T 'dialog.filter.scriptletPrefs')
    if ($ofd.ShowDialog() -ne 'OK') { return }
    if (-not (Show-ScriptletMessage 'msg.scriptlet.confirmReapply' @($script:TxtScriptletRoot.Text) -Icon Warning -YesNo)) { return }
    Invoke-ScriptletWrite -FailLog 'Scriptlet preference reapply failed' -FailKey 'msg.scriptlet.reapplyFailed' -Action {
        $changed = Import-ScriptletPreferencesAndReapply -PrefsFile $ofd.FileName -Root $script:TxtScriptletRoot.Text.Trim()
        "Reapplied disabled scriptlet prefs: $changed line(s)."
    }
}

[void](New-LocControl Label $scriptletsTab 'scriptlet.footer' 350 429 760 32 -FontSize 8 -ForeColor 'DimGray')

$tabs.TabPages.Add($scriptletsTab)
