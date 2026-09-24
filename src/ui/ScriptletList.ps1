# ============================================================================
#  Scriptlet list view: incremental scan, render and selection handling.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

function Resize-ScriptletColumns {
    if (-not $script:ScriptletList) { return }
    if ($script:ScriptletList.Columns.Count -lt 7) { return }

    $width = [Math]::Max(760, $script:ScriptletList.ClientSize.Width - 10)
    $pickWidth = 92
    $lineWidth = 55
    $flex = [Math]::Max(600, $width - $pickWidth - $lineWidth)
    $domainWidth = [Math]::Max(105, [int]($flex * 0.16))
    $scriptletWidth = [Math]::Max(115, [int]($flex * 0.17))
    $argsWidth = [Math]::Max(145, [int]($flex * 0.22))
    $sourceWidth = [Math]::Max(125, [int]($flex * 0.15))
    $rawWidth = [Math]::Max(170, $width - ($pickWidth + $domainWidth + $scriptletWidth + $argsWidth + $sourceWidth + $lineWidth + 4))

    $script:ScriptletList.Columns[0].Width = $pickWidth
    $script:ScriptletList.Columns[1].Width = $domainWidth
    $script:ScriptletList.Columns[2].Width = $scriptletWidth
    $script:ScriptletList.Columns[3].Width = $argsWidth
    $script:ScriptletList.Columns[4].Width = $sourceWidth
    $script:ScriptletList.Columns[5].Width = $lineWidth
    $script:ScriptletList.Columns[6].Width = $rawWidth
}

function Update-ScriptletStatusText {
    param([int]$Shown = -1)

    if (-not $script:LblScriptletStatus) { return }
    if ($Shown -lt 0) { $Shown = @($script:ScriptletVisibleRules).Count }

    $enabled = @($script:ScriptletRules | Where-Object { $_.Enabled }).Count
    $disabled = @($script:ScriptletRules | Where-Object { -not $_.Enabled }).Count
    $checked = $script:ScriptletCheckedKeys.Count
    $script:LblScriptletStatus.Text = T 'scriptlet.statusShowing' @($Shown, $script:ScriptletRules.Count, $enabled, $disabled, $checked)
}

# The scriptlet tab keeps live text outside the binding table: the ListView
# column headers, the per-row Enabled/Disabled cell and the status line are
# all written imperatively as the scan/render progresses. A language switch
# therefore has to re-text them explicitly, in place, without re-scanning.
function Update-ScriptletLocalizedText {
    if ($script:ScriptletList -and $script:ScriptletList.Columns.Count -ge 7) {
        $headerKeys = @(
            'scriptlet.col.pick', 'scriptlet.col.domain', 'scriptlet.col.scriptlet',
            'scriptlet.col.arguments', 'scriptlet.col.source', 'scriptlet.col.line',
            'scriptlet.col.rawRule'
        )
        for ($i = 0; $i -lt $headerKeys.Count; $i++) {
            $script:ScriptletList.Columns[$i].Text = T $headerKeys[$i]
        }
    }
    if ($script:ScriptletList -and $script:ScriptletList.Items.Count -gt 0) {
        $script:SuppressScriptletStatusEvents = $true
        $script:ScriptletList.BeginUpdate()
        try {
            foreach ($item in $script:ScriptletList.Items) {
                if (-not $item.Tag) { continue }
                $item.Text = if ($item.Tag.Enabled) { T 'scriptlet.state.enabled' } else { T 'scriptlet.state.disabled' }
            }
        } finally {
            $script:ScriptletList.EndUpdate()
            $script:SuppressScriptletStatusEvents = $false
        }
    }
    # Only refresh the counter line if a scan has actually produced rules;
    # otherwise the binding table's idle prompt is the correct text.
    if (@($script:ScriptletRules).Count -gt 0) { Update-ScriptletStatusText }
}

function Set-ScriptletUiBusy {
    param([bool]$Busy, [string]$Message = '')

    foreach ($control in @(
        $script:BtnScriptletScan,
        $script:BtnScriptletFilter,
        $script:BtnScriptletDisable,
        $script:BtnScriptletEnable,
        $script:BtnScriptletCheckVisible,
        $script:BtnScriptletClearChecks,
        $script:BtnScriptletImportPrefs
    )) {
        if ($control) { $control.Enabled = -not $Busy }
    }

    if ($script:LblScriptletStatus -and $Message) { $script:LblScriptletStatus.Text = $Message }
    if ($form) { $form.UseWaitCursor = $Busy }
    [System.Windows.Forms.Application]::DoEvents()
}

function Start-ScriptletFilterDelay {
    if ($script:ScriptletFilterTimer) {
        $script:ScriptletFilterTimer.Stop()
        $script:ScriptletFilterTimer.Start()
    } else {
        Update-ScriptletListView
    }
}

function Get-ScriptletRecordKey {
    param([object]$Record)

    if (-not $Record) { return $null }
    return ('{0}`t{1}' -f [string]$Record.File, [int]$Record.LineNumber)
}

function Test-ScriptletRecordChecked {
    param([object]$Record)

    $key = Get-ScriptletRecordKey -Record $Record
    return ($key -and $script:ScriptletCheckedKeys.ContainsKey($key))
}

function Set-ScriptletRecordChecked {
    param(
        [object]$Record,
        [bool]$Checked
    )

    $key = Get-ScriptletRecordKey -Record $Record
    if (-not $key) { return }

    if ($Checked) {
        $script:ScriptletCheckedKeys[$key] = $true
    } else {
        [void]$script:ScriptletCheckedKeys.Remove($key)
    }
}

function New-ScriptletListItem {
    param([object]$Record)

    $stateText = if ($Record.Enabled) { T 'scriptlet.state.enabled' } else { T 'scriptlet.state.disabled' }
    $item = New-Object System.Windows.Forms.ListViewItem($stateText)
    [void]$item.SubItems.Add($Record.Domain)
    [void]$item.SubItems.Add($Record.Scriptlet)
    [void]$item.SubItems.Add($Record.Arguments)
    [void]$item.SubItems.Add("$($Record.Source) $($Record.Version)")
    [void]$item.SubItems.Add([string]$Record.LineNumber)
    [void]$item.SubItems.Add($Record.Rule)
    $item.Tag = $Record
    $item.Checked = Test-ScriptletRecordChecked -Record $Record
    if (-not $Record.Enabled) {
        $item.ForeColor = [System.Drawing.Color]::FromArgb(150, 60, 60)
    }
    return $item
}

function Stop-ScriptletRender {
    if ($script:ScriptletRenderTimer) { $script:ScriptletRenderTimer.Stop() }
    $script:ScriptletRenderState = $null
    $script:SuppressScriptletStatusEvents = $false
}

function Start-ScriptletRender {
    param([object[]]$Rows)

    if (-not $script:ScriptletList) { return }
    Stop-ScriptletRender
    Set-ScriptletUiBusy $true (T 'scriptlet.statusRender0' @($Rows.Count))
    Resize-ScriptletColumns

    $script:SuppressScriptletStatusEvents = $true
    $script:ScriptletList.BeginUpdate()
    try {
        $script:ScriptletList.Items.Clear()
    } finally {
        $script:ScriptletList.EndUpdate()
    }

    $script:ScriptletRenderState = [pscustomobject]@{
        Rows      = @($Rows)
        Index     = 0
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }

    if ($script:ScriptletProgress) {
        $script:ScriptletProgress.Visible = $true
        $script:ScriptletProgress.Style = 'Continuous'
        $script:ScriptletProgress.Value = 0
    }
    if ($script:LblScriptletStatus) {
        $script:LblScriptletStatus.Text = T 'scriptlet.statusRender0' @($Rows.Count)
    }

    if ($Rows.Count -eq 0) {
        Stop-ScriptletRender
        if ($script:ScriptletProgress) { $script:ScriptletProgress.Value = 0 }
        Update-ScriptletStatusText -Shown 0
        Set-ScriptletUiBusy $false
        return
    }

    if (-not $script:ScriptletRenderTimer) {
        $script:ScriptletRenderTimer = New-Object System.Windows.Forms.Timer
        $script:ScriptletRenderTimer.Interval = 10
        $script:ScriptletRenderTimer.Add_Tick({ Step-ScriptletRender })
    }
    $script:ScriptletRenderTimer.Start()
}

function Step-ScriptletRender {
    $state = $script:ScriptletRenderState
    if (-not $state) {
        Stop-ScriptletRender
        return
    }

    $total = $state.Rows.Count
    if ($total -eq 0) {
        Stop-ScriptletRender
        Update-ScriptletStatusText -Shown 0
        return
    }

    $startTick = [Environment]::TickCount64
    $batch = New-Object System.Collections.Generic.List[System.Windows.Forms.ListViewItem]
    while ($state.Index -lt $total -and (([Environment]::TickCount64 - $startTick) -lt 25) -and $batch.Count -lt 400) {
        [void]$batch.Add((New-ScriptletListItem -Record $state.Rows[$state.Index]))
        $state.Index++
    }

    if ($batch.Count -gt 0) {
        $items = $batch.ToArray()
        $script:ScriptletList.BeginUpdate()
        try {
            $script:ScriptletList.Items.AddRange($items)
        } finally {
            $script:ScriptletList.EndUpdate()
        }
    }

    $percent = [int](($state.Index * 1000L) / [Math]::Max(1, $total))
    $percent = [Math]::Max(0, [Math]::Min(1000, $percent))
    if ($script:ScriptletProgress) { $script:ScriptletProgress.Value = $percent }
    if ($script:LblScriptletStatus) {
        $seconds = [Math]::Round($state.Stopwatch.Elapsed.TotalSeconds, 1)
        $script:LblScriptletStatus.Text = T 'scriptlet.statusRendering' @($state.Index, $total, $seconds)
    }

    if ($state.Index -ge $total) {
        $elapsed = [Math]::Round($state.Stopwatch.Elapsed.TotalSeconds, 1)
        Stop-ScriptletRender
        if ($script:ScriptletProgress) { $script:ScriptletProgress.Value = 1000 }
        Update-ScriptletStatusText -Shown $total
        if ($script:LblScriptletStatus) {
            $script:LblScriptletStatus.Text += (T 'scriptlet.renderDone' @($elapsed))
        }
        Set-ScriptletUiBusy $false
    }
}

function Update-ScriptletListView {
    if (-not $script:ScriptletList) { return }

    $query = if ($script:TxtScriptletSearch) { $script:TxtScriptletSearch.Text.Trim() } else { '' }
    $disabledOnly = ($script:ChkScriptletDisabledOnly -and $script:ChkScriptletDisabledOnly.Checked)
    $rows = @($script:ScriptletRules)
    if ($disabledOnly) { $rows = @($rows | Where-Object { -not $_.Enabled }) }
    if (-not [string]::IsNullOrWhiteSpace($query)) {
        $needle = $query.ToLowerInvariant()
        $rows = @($rows | Where-Object {
            ("$($_.Domain) $($_.Scriptlet) $($_.Arguments) $($_.Source) $($_.Rule) $($_.File)").ToLowerInvariant().Contains($needle)
        })
    }

    $script:ScriptletVisibleRules = $rows
    Start-ScriptletRender -Rows $rows
}

function Get-SelectedScriptletRecords {
    if (-not $script:ScriptletList) { return @() }
    $records = @()

    if ($script:ScriptletCheckedKeys.Count -gt 0) {
        foreach ($record in $script:ScriptletRules) {
            if (Test-ScriptletRecordChecked -Record $record) { $records += $record }
        }
        return $records
    }

    foreach ($item in $script:ScriptletList.SelectedItems) {
        if ($item.Tag) { $records += $item.Tag }
    }
    return $records
}

function Set-ScriptletVisibleChecks {
    param([bool]$Checked)

    if (-not $script:ScriptletList) { return }
    if ($Checked) {
        foreach ($record in $script:ScriptletVisibleRules) {
            Set-ScriptletRecordChecked -Record $record -Checked $true
        }
    } else {
        $script:ScriptletCheckedKeys.Clear()
    }

    $script:SuppressScriptletStatusEvents = $true
    $script:ScriptletList.BeginUpdate()
    try {
        foreach ($item in $script:ScriptletList.Items) {
            $item.Checked = Test-ScriptletRecordChecked -Record $item.Tag
        }
    } finally {
        $script:ScriptletList.EndUpdate()
        $script:SuppressScriptletStatusEvents = $false
    }
    Update-ScriptletStatusText
}

function Update-ScriptletScanProgress {
    param([string]$Message = '')

    $state = $script:ScriptletScanState
    if (-not $state) { return }

    $currentBytes = 0L
    if ($state.Reader -and $state.Reader.BaseStream) {
        try { $currentBytes = [int64]$state.Reader.BaseStream.Position } catch { $currentBytes = 0L }
    }
    $doneBytes = [Math]::Min([int64]$state.TotalBytes, [int64]($state.ProcessedBytes + $currentBytes))
    $percent = if ($state.TotalBytes -gt 0) { [int](($doneBytes * 1000L) / $state.TotalBytes) } else { 0 }
    $percent = [Math]::Max(0, [Math]::Min(1000, $percent))

    if ($script:ScriptletProgress) {
        $script:ScriptletProgress.Visible = $true
        $script:ScriptletProgress.Style = 'Continuous'
        $script:ScriptletProgress.Value = $percent
    }

    if ($script:LblScriptletStatus) {
        if ([string]::IsNullOrWhiteSpace($Message)) {
            $fileName = if ($state.CurrentFile) { Split-Path $state.CurrentFile.FullName -Leaf } else { T 'scriptlet.statusStarting' }
            $seconds = [Math]::Max(1, [int]$state.Stopwatch.Elapsed.TotalSeconds)
            $Message = T 'scriptlet.statusScanning' @(
                $state.FileIndex, $state.Files.Count, $fileName,
                $state.Records.Count, [int]($percent / 10), $seconds)
        }
        $script:LblScriptletStatus.Text = $Message
    }
}

function Stop-ScriptletScan {
    if ($script:ScriptletScanTimer) { $script:ScriptletScanTimer.Stop() }
    if ($script:ScriptletScanState -and $script:ScriptletScanState.Reader) {
        try { $script:ScriptletScanState.Reader.Dispose() } catch {}
    }
    $script:ScriptletScanState = $null
    Set-ScriptletUiBusy $false
}

function Complete-ScriptletScan {
    $state = $script:ScriptletScanState
    if (-not $state) { return }

    if ($script:ScriptletScanTimer) { $script:ScriptletScanTimer.Stop() }
    if ($state.Reader) {
        try { $state.Reader.Dispose() } catch {}
        $state.Reader = $null
    }
    $state.Stopwatch.Stop()

    $script:ScriptletRules = @($state.Records.ToArray())
    foreach ($warning in @($state.Warnings)) { Write-Log $warning 'WARN' }

    if ($script:ScriptletProgress) {
        $script:ScriptletProgress.Visible = $true
        $script:ScriptletProgress.Style = 'Continuous'
        $script:ScriptletProgress.Value = 1000
    }

    $elapsed = [Math]::Round($state.Stopwatch.Elapsed.TotalSeconds, 1)
    $root = $state.Root
    $script:ScriptletScanState = $null
    if ($script:LblScriptletStatus) {
        $script:LblScriptletStatus.Text = T 'scriptlet.statusRenderN' @($script:ScriptletRules.Count)
    }
    [System.Windows.Forms.Application]::DoEvents()
    Update-ScriptletListView
    Write-Log "Scriptlet scan complete: $($script:ScriptletRules.Count) rule(s) from $root in ${elapsed}s" 'OK'

    if ($script:LblScriptletStatus) {
        $script:LblScriptletStatus.Text += (T 'scriptlet.scanDone' @($elapsed))
    }
    if ($script:ScriptletRules.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'msg.scriptlet.noRules' @($root)),
            (T 'msg.title.scriptlet'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    }
}

function Step-ScriptletScan {
    $state = $script:ScriptletScanState
    if (-not $state) {
        if ($script:ScriptletScanTimer) { $script:ScriptletScanTimer.Stop() }
        return
    }

    $startTick = [Environment]::TickCount64
    $linesThisTick = 0
    while ((([Environment]::TickCount64 - $startTick) -lt 35) -and ($linesThisTick -lt 2500)) {
        if (-not $state.Reader) {
            if ($state.FileIndex -ge $state.Files.Count) {
                Complete-ScriptletScan
                return
            }

            $file = $state.Files[$state.FileIndex]
            $state.FileIndex++
            $state.CurrentFile = $file
            $state.CurrentLine = 0
            try {
                $state.Reader = [System.IO.File]::OpenText($file.FullName)
            } catch {
                [void]$state.Warnings.Add("Scriptlet scan failed $($file.FullName): $_")
                $state.ProcessedBytes += [int64]$file.Length
                $state.Reader = $null
                continue
            }
        }

        try {
            $line = $state.Reader.ReadLine()
        } catch {
            [void]$state.Warnings.Add("Scriptlet scan failed $($state.CurrentFile.FullName): $_")
            try { $state.Reader.Dispose() } catch {}
            $state.ProcessedBytes += [int64]$state.CurrentFile.Length
            $state.Reader = $null
            continue
        }

        if ($null -eq $line) {
            try { $state.Reader.Dispose() } catch {}
            $state.ProcessedBytes += [int64]$state.CurrentFile.Length
            $state.Reader = $null
            continue
        }

        $state.CurrentLine++
        $linesThisTick++
        $record = ConvertTo-ScriptletRecord -File $state.CurrentFile.FullName -Root $state.Root -Line $line -LineNumber $state.CurrentLine
        if ($record) { [void]$state.Records.Add($record) }
    }

    Update-ScriptletScanProgress
}

function Invoke-ScriptletScan {
    $root = $script:TxtScriptletRoot.Text.Trim()
    if ($script:ScriptletScanState) {
        Write-Log 'Scriptlet scan is already running.' 'INFO'
        return
    }

    try {
        Set-ScriptletUiBusy $true (T 'scriptlet.statusFinding')
        $warnings = New-Object System.Collections.ArrayList
        $files = @(Get-ScriptletListFiles -Root $root -Warnings $warnings)
        if ($files.Count -eq 0) {
            Set-ScriptletUiBusy $false
            if ($script:ScriptletProgress) { $script:ScriptletProgress.Value = 0 }
            [System.Windows.Forms.MessageBox]::Show(
                (T 'msg.scriptlet.noFiles' @($root)),
                (T 'msg.title.scriptlet'),
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }

        $totalBytes = [int64](@($files | Measure-Object Length -Sum).Sum)
        if ($totalBytes -lt 1) { $totalBytes = 1 }
        $script:ScriptletRules = @()
        $script:ScriptletVisibleRules = @()
        $script:ScriptletCheckedKeys.Clear()
        if ($script:ScriptletList) { $script:ScriptletList.Items.Clear() }

        $script:ScriptletScanState = [pscustomobject]@{
            Root           = $root
            Files          = $files
            FileIndex      = 0
            CurrentFile    = $null
            CurrentLine    = 0
            Reader         = $null
            ProcessedBytes = 0L
            TotalBytes     = $totalBytes
            Records        = (New-Object System.Collections.Generic.List[object])
            Warnings       = $warnings
            Stopwatch      = [System.Diagnostics.Stopwatch]::StartNew()
        }

        if ($script:ScriptletProgress) {
            $script:ScriptletProgress.Visible = $true
            $script:ScriptletProgress.Style = 'Continuous'
            $script:ScriptletProgress.Value = 0
        }
        Update-ScriptletScanProgress (T 'scriptlet.statusFound' @($files.Count))
        Write-Log "Scriptlet scan started: $root ($($files.Count) list file(s), $([Math]::Round($totalBytes / 1MB, 2)) MB)" 'INFO'

        if (-not $script:ScriptletScanTimer) {
            $script:ScriptletScanTimer = New-Object System.Windows.Forms.Timer
            $script:ScriptletScanTimer.Interval = 15
            $script:ScriptletScanTimer.Add_Tick({ Step-ScriptletScan })
        }
        $script:ScriptletScanTimer.Start()
    } catch {
        Stop-ScriptletScan
        $script:ScriptletRules = @()
        Update-ScriptletListView
        Write-Log "Scriptlet scan failed: $_" 'ERR'
        [System.Windows.Forms.MessageBox]::Show(
            (T 'msg.scriptlet.scanFailed' @("$_")),
            (T 'msg.title.scriptlet'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
}
