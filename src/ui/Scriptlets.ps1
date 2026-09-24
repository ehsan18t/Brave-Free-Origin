# ============================================================================
#  Default scriptlets page (advanced): scan, filter, check and edit rules.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Advanced, optional, and deliberately separate from presets and the main
# Apply. The scan and every edit of Brave's filter lists run on the worker;
# the table is virtualized, so thousands of rules show at once without the
# chunked rendering the old list needed.
$script:ScriptletScanning = $false
$script:Vm.ScriptletRoot = [string](Get-ScriptletDefaultRoot)

function Update-ScriptletStatusText {
    $vm = $script:Vm
    $vm.ScanButtonText = if ($script:ScriptletScanning) { [string](T 'dialog.cancel') } else { [string](T 'scriptlet.scan') }
    if ($script:ScriptletScanning) { return }
    $rules = @($script:ScriptletRules)
    if ($rules.Count -eq 0) {
        $vm.ScriptletStatus = [string](T 'scriptlet.statusIdle')
        return
    }
    $enabled = 0; $picked = 0
    foreach ($rule in $rules) {
        if ($rule.Enabled) { $enabled++ }
        if ($rule.Picked) { $picked++ }
    }
    $vm.ScriptletStatus = [string](T 'scriptlet.statusShowing' @(@($script:ScriptletVisibleRules).Count, $rules.Count, $enabled, ($rules.Count - $enabled), $picked))
}

# Rebuilds the visible list from the search box and the Disabled only switch.
# Each rule carries a lower-cased Hay built during the scan, so this is one
# pass of plain string checks.
function Update-ScriptletView {
    $needle = $script:Ui.TxtScriptletSearch.Text.Trim().ToLowerInvariant()
    $disabledOnly = [bool]$script:Vm.ScriptletDisabledOnly
    $visible = New-BfoList
    foreach ($rule in $script:ScriptletRules) {
        if ($disabledOnly -and $rule.Enabled) { continue }
        if ($needle -and -not $rule.Hay.Contains($needle)) { continue }
        $visible.Add($rule)
    }
    $script:ScriptletVisibleRules = $visible
    $script:Ui.ScriptletGrid.ItemsSource = $visible
    Update-ScriptletStatusText
}

# The Scan button doubles as Cancel while a scan runs. A scan only starts when
# nothing else is running (AfterEdit is the rescan that follows an edit), so the
# scan is always the running job when Cancel is pressed; the worker checks the
# flag between files.
function Invoke-ScriptletScan {
    param([switch]$AfterEdit)
    if ($script:ScriptletScanning) {
        if ($script:CurrentJob -and $script:CurrentJob.Name -eq 'Scriptlet scan') { $script:JobProgress.Cancel = $true }
        return
    }
    if (-not $AfterEdit -and (Test-BfoBusy)) { return }
    $root = $script:Vm.ScriptletRoot.Trim()
    $script:ScriptletScanning = $true
    $script:Vm.ScriptletProgress = 0
    $script:Vm.ScriptletProgressVisibility = $script:Visible
    $script:Vm.ScriptletStatus = [string](T 'scriptlet.statusFinding')
    Update-ScriptletStatusText
    Start-BfoJob -Name 'Scriptlet scan' -BusyKey 'busy.scriptlets' -Argument $root `
        -Script { param($In) Get-ScriptletRecords -Root $In -Progress $script:JobProgress } `
        -OnProgress {
            param($Progress)
            if ($null -ne $Progress.Value) { $script:Vm.ScriptletProgress = [int]$Progress.Value }
            if ($Progress.Key) { $script:Vm.ScriptletStatus = [string](T $Progress.Key @($Progress.Args)) }
        } `
        -OnSuccess {
            param($Result)
            $script:ScriptletScanning = $false
            $script:Vm.ScriptletProgressVisibility = $script:Collapsed
            $script:ScriptletRules = @($Result.Records)
            Update-ScriptletView
            if ($Result.Cancelled) {
                $script:Vm.ScriptletStatus = [string](T 'scriptlet.statusCancelled')
            } else {
                $script:Vm.ScriptletStatus += [string](T 'scriptlet.scanDone' @($Result.Seconds))
            }
            if ($Result.FileCount -eq 0) {
                Show-BfoMessage 'msg.scriptlet.noFiles' @($Result.Root) -TitleKey 'msg.title.scriptlet'
            } elseif ($script:ScriptletRules.Count -eq 0 -and -not $Result.Cancelled) {
                Show-BfoMessage 'msg.scriptlet.noRules' @($Result.Root) -TitleKey 'msg.title.scriptlet'
            }
        } `
        -OnError {
            param($Message)
            $script:ScriptletScanning = $false
            $script:Vm.ScriptletProgressVisibility = $script:Collapsed
            $script:ScriptletRules = @()
            Update-ScriptletView
            Show-BfoMessage 'msg.scriptlet.scanFailed' @($Message) -TitleKey 'msg.title.scriptlet' -Icon Error
        }
}

# Checked rules first; with none checked, the rows selected in the table.
function Get-SelectedScriptletRecords {
    $records = @($script:ScriptletRules | Where-Object { $_.Picked })
    if ($records.Count -gt 0) { return $records }
    return @($script:Ui.ScriptletGrid.SelectedItems)
}

function Set-ScriptletChecks {
    param([bool]$Checked)
    # Check filtered ticks every rule the filter matches, not just the rows
    # painted on screen; Clear checks clears every rule.
    $target = if ($Checked) { $script:ScriptletVisibleRules } else { $script:ScriptletRules }
    foreach ($rule in $target) { $rule.Picked = $Checked }
    $script:Ui.ScriptletGrid.Items.Refresh()
    Update-ScriptletStatusText
}

# Every edit of Brave's filter lists needs Advanced edit mode, and a warning
# when Brave is running: it may rewrite or cache the lists meanwhile.
function Test-ScriptletAdvancedWriteAllowed {
    if (-not $script:Vm.ScriptletAdvanced) {
        Show-BfoMessage 'msg.scriptlet.locked' -TitleKey 'msg.title.scriptlet' -Icon Warning
        return $false
    }
    $braveProcesses = @(Get-Process -Name brave -ErrorAction SilentlyContinue)
    if ($braveProcesses.Count -gt 0) {
        return (Show-BfoMessage 'msg.scriptlet.braveRunning' @($braveProcesses.Count) -TitleKey 'msg.title.scriptlet' -Icon Warning -YesNo)
    }
    return $true
}

# Runs one write to the filter lists on the worker. Script returns the log
# line for success; the lists are then rescanned so the table shows the files
# as they are now. On failure the error is shown under FailKey.
function Invoke-ScriptletWrite {
    param([scriptblock]$Script, $Argument, [string]$FailKey)
    Start-BfoJob -Name 'Scriptlet edit' -BusyKey 'busy.scriptlets' -Script $Script -Argument $Argument -Tag $FailKey -OnSuccess {
        param($Message)
        Write-Log $Message 'OK'
        Invoke-ScriptletScan -AfterEdit
    } -OnError {
        param($Message, $Job)
        Show-BfoMessage $Job.Tag @($Message) -TitleKey 'msg.title.scriptlet' -Icon Error
    }
}

function Show-ScriptletMessage {
    param([string]$Key, [object[]]$FormatArgs, [string]$Icon = 'Information', [switch]$YesNo, [switch]$Danger)
    Show-BfoMessage $Key $FormatArgs -TitleKey 'msg.title.scriptlet' -Icon $Icon -YesNo:$YesNo -Danger:$Danger
}

# ---- Wiring ------------------------------------------------------------------------------
$ui.BtnScriptletScan.Add_Click({ Invoke-ScriptletScan })
$ui.BtnScriptletAuto.Add_Click({
    $script:Vm.ScriptletRoot = [string](Get-ScriptletDefaultRoot)
    Write-Log "Scriptlet User Data path set to: $($script:Vm.ScriptletRoot)"
})
$ui.BtnScriptletBrowse.Add_Click({
    $folder = Show-FolderDialog -DescriptionKey 'dialog.browseUserData' -SelectedPath $script:Vm.ScriptletRoot
    if ($folder) {
        $script:Vm.ScriptletRoot = [string]$folder
        Write-Log "Scriptlet User Data path set manually: $folder"
    }
})
$ui.BtnScriptletFolder.Add_Click({
    if (Test-Path -LiteralPath $script:Vm.ScriptletRoot) { Start-Process explorer.exe $script:Vm.ScriptletRoot }
    else { Show-ScriptletMessage 'msg.scriptlet.folderMissing' -Icon Warning }
})

$script:ScriptletFilterTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:ScriptletFilterTimer.Interval = [TimeSpan]::FromMilliseconds(200)
$script:ScriptletFilterTimer.Add_Tick({
    $script:ScriptletFilterTimer.Stop()
    Update-ScriptletView
})
$ui.TxtScriptletSearch.Add_TextChanged({
    $script:ScriptletFilterTimer.Stop()
    $script:ScriptletFilterTimer.Start()
})
$ui.TxtScriptletSearch.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        $script:ScriptletFilterTimer.Stop()
        Update-ScriptletView
        $e.Handled = $true
    }
})
$ui.ChkScriptletDisabledOnly.Add_Click({ Update-ScriptletView })

# A tick in the table's check column.
$ui.ScriptletGrid.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    if ($e.OriginalSource -is [System.Windows.Controls.CheckBox]) { Update-ScriptletStatusText }
})

$ui.BtnScriptletCheckVisible.Add_Click({ Set-ScriptletChecks $true })
$ui.BtnScriptletClearChecks.Add_Click({ Set-ScriptletChecks $false })

$ui.BtnScriptletDisable.Add_Click({
    $records = @(Get-SelectedScriptletRecords)
    if ($records.Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.selectFirst'; return }
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    if (-not (Show-ScriptletMessage 'msg.scriptlet.confirmDisable' @($records.Count, $script:ScriptletDisablePrefix) -Icon Warning -YesNo -Danger)) { return }
    Invoke-ScriptletWrite -FailKey 'msg.scriptlet.disableFailed' `
        -Argument ([pscustomobject]@{ Records = $records; Dupes = [bool]$script:Vm.ScriptletAffectDupes }) -Script {
        param($In)
        $changed = Set-ScriptletRuleState -Records $In.Records -Enable:$false -AffectDuplicates:$In.Dupes
        "Scriptlets disabled: $changed line(s)."
    }
})

$ui.BtnScriptletEnable.Add_Click({
    $records = @(Get-SelectedScriptletRecords)
    if ($records.Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.selectFirst'; return }
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    Invoke-ScriptletWrite -FailKey 'msg.scriptlet.enableFailed' `
        -Argument ([pscustomobject]@{ Records = $records; Dupes = [bool]$script:Vm.ScriptletAffectDupes }) -Script {
        param($In)
        $changed = Set-ScriptletRuleState -Records $In.Records -Enable:$true -AffectDuplicates:$In.Dupes
        "Scriptlets enabled: $changed line(s)."
    }
})

# ---- More menu ----------------------------------------------------------------------------
$ui.BtnScriptletMore.Add_Click({
    $menu = $script:Ui.BtnScriptletMore.ContextMenu
    $menu.PlacementTarget = $script:Ui.BtnScriptletMore
    $menu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Top
    $menu.IsOpen = $true
})

$ui.MnuScriptletView.Add_Click({
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

$ui.MnuScriptletBackup.Add_Click({
    $files = @($script:ScriptletRules | Select-Object -ExpandProperty File -Unique)
    if ($files.Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.scanFirst'; return }
    $script:ScriptletBackupCount = $files.Count
    Start-BfoJob -Name 'Scriptlet backup' -BusyKey 'busy.scriptlets' -Argument ([string[]]$files) -Script {
        param($In)
        foreach ($file in $In) { [void](Backup-ScriptletFile -File $file) }
    } -OnSuccess {
        Show-ScriptletMessage 'msg.scriptlet.backupDone' @($script:ScriptletBackupCount)
    } -OnError {
        param($Message)
        Show-ScriptletMessage 'msg.scriptlet.backupFailed' @($Message) -Icon Error
    }
})

$ui.MnuScriptletRestoreSel.Add_Click({
    $records = @(Get-SelectedScriptletRecords)
    if ($records.Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.restoreSelectFile'; return }
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    $files = @($records | Select-Object -ExpandProperty File -Unique)
    if (-not (Show-ScriptletMessage 'msg.scriptlet.confirmRestoreSel' @($files.Count) -Icon Warning -YesNo -Danger)) { return }
    Invoke-ScriptletWrite -FailKey 'msg.scriptlet.restoreFailed' -Argument ([string[]]$files) -Script {
        param($In)
        foreach ($file in $In) { Restore-ScriptletBackup -File $file }
        "Restored $(@($In).Count) scriptlet list file(s) from backup."
    }
})

$ui.MnuScriptletRestoreAll.Add_Click({
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    $root = $script:Vm.ScriptletRoot.Trim()
    if (-not (Show-ScriptletMessage 'msg.scriptlet.confirmRestoreAll' @($root) -Icon Warning -YesNo -Danger)) { return }
    Invoke-ScriptletWrite -FailKey 'msg.scriptlet.restoreAllFailed' -Argument $root -Script {
        param($In)
        $count = Restore-AllScriptletBackups -Root $In
        "Restored $count scriptlet backup file(s)."
    }
})

$ui.MnuScriptletCsv.Add_Click({
    if (@($script:ScriptletVisibleRules).Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.nothingVisible'; return }
    $file = Show-SaveDialog -FilterKey 'dialog.filter.csv' -Extension 'csv' -FileName "brave-free-origin-scriptlets-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv" -InitialDirectory ''
    if (-not $file) { return }
    $script:ScriptletVisibleRules |
        Select-Object Enabled, Domain, Scriptlet, Arguments, Source, Version, ComponentId, File, LineNumber, Rule |
        Export-Csv -Path $file -NoTypeInformation -Encoding UTF8
    Write-Log "Scriptlet CSV exported: $file" 'OK'
})

$ui.MnuScriptletExportPrefs.Add_Click({
    if (@($script:ScriptletRules).Count -eq 0) { Show-ScriptletMessage 'msg.scriptlet.noRulesLoaded'; return }
    $file = Show-SaveDialog -FilterKey 'dialog.filter.scriptletPrefs' -Extension 'json' -FileName "brave-free-origin-disabled-scriptlets-$(Get-Date -Format 'yyyyMMdd-HHmmss').json" -InitialDirectory ''
    if (-not $file) { return }
    try {
        $count = Export-ScriptletDisabledPreferences -File $file -Rules $script:ScriptletRules
        Write-Log "Disabled scriptlet prefs exported: $count rule(s)." 'OK'
    } catch {
        Show-ScriptletMessage 'msg.scriptlet.exportFailed' @("$_") -Icon Error
    }
})

$ui.MnuScriptletImportPrefs.Add_Click({
    if (-not (Test-ScriptletAdvancedWriteAllowed)) { return }
    $file = Show-OpenDialog -FilterKey 'dialog.filter.scriptletPrefs' -Extension 'json'
    if (-not $file) { return }
    $root = $script:Vm.ScriptletRoot.Trim()
    if (-not (Show-ScriptletMessage 'msg.scriptlet.confirmReapply' @($root) -Icon Warning -YesNo)) { return }
    Invoke-ScriptletWrite -FailKey 'msg.scriptlet.reapplyFailed' `
        -Argument ([pscustomobject]@{ File = $file; Root = $root }) -Script {
        param($In)
        $changed = Import-ScriptletPreferencesAndReapply -PrefsFile $In.File -Root $In.Root
        "Reapplied disabled scriptlet prefs: $changed line(s)."
    }
})

Update-ScriptletStatusText
