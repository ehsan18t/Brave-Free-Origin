# ============================================================================
#  Shared UI helpers: building localized controls, message boxes, the text
#  report window and ComboBox id plumbing.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Builds one control, binds its text to a string key, places it and adds it to
# Parent, replacing the usual New-Object / Set-Loc / Location / Size / font /
# Controls.Add block. Everything after Y is optional: FontSize registers a
# localized font, Width is skipped for auto-sized labels, and OnClick is written
# at the call site, so it sees the same variables a hand-built handler would.
function New-LocControl {
    param(
        [string]$Type,
        $Parent,
        [string]$Key,
        [int]$X,
        [int]$Y,
        [int]$Width = 0,
        [int]$Height = 0,
        [single]$FontSize = 0,
        [switch]$Semibold,
        $ForeColor,
        $BackColor,
        [scriptblock]$OnClick,
        [string]$TipKey,
        [object[]]$FormatArgs
    )
    $control = New-Object "System.Windows.Forms.$Type"
    if ($Key) { [void](Set-Loc $control $Key -FormatArgs $FormatArgs) }
    if ($FontSize -gt 0) { [void](Set-LocFont $control -Size $FontSize -Semibold:$Semibold) }
    $control.Location = New-Object System.Drawing.Point($X, $Y)
    if ($Width -gt 0) { $control.Size = New-Object System.Drawing.Size($Width, $Height) }
    if ($ForeColor) { $control.ForeColor = $ForeColor }
    if ($BackColor) { $control.BackColor = $BackColor }
    if ($OnClick) { $control.Add_Click($OnClick) }
    if ($TipKey) { Set-LocTooltip $control $TipKey }
    $Parent.Controls.Add($control)
    return $control
}

# ---- Setting rows -------------------------------------------------------------
# Policy, task, service and hosts rows share one shape: a checkbox, and a grey
# description beside it that the language switch re-sizes (RowDescLabels).
# Ticking a row by hand turns the active mode into Custom.
$script:OnRowChecked = {
    if ($script:SuppressSelectionEvents) { return }
    Set-CustomMode
    Update-ConfigurationFilter
}

# A row checkbox captioned with a raw identifier (policy, task or service name).
# Not translated on purpose: users cross-check it against brave://policy,
# services.msc or Task Scheduler, and Consolas has no CJK coverage anyway.
function New-RowCheckBox {
    param($Parent, [string]$Text, [int]$Y, [int]$Width, $Tag, [string]$TipKey)
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $Text
    $cb.Location = New-Object System.Drawing.Point(15, $Y)
    $cb.Size = New-Object System.Drawing.Size($Width, 20)
    $cb.Font = New-Object System.Drawing.Font('Consolas', 9)
    $cb.Tag = $Tag
    $cb.Add_CheckedChanged($script:OnRowChecked)
    Set-LocTooltip $cb $TipKey
    $Parent.Controls.Add($cb)
    return $cb
}

function New-RowDescLabel {
    param($Parent, [string]$Key, [int]$X, [int]$Y, [int]$Width)
    $desc = New-Object System.Windows.Forms.Label
    $desc.Location = New-Object System.Drawing.Point($X, $Y)
    $desc.Size = New-Object System.Drawing.Size($Width, (Get-PolicyDescHeight))
    $desc.ForeColor = [System.Drawing.Color]::DimGray
    $desc.Font = Get-BfoUiFont -Size (Get-PolicyDescFontSize)
    [void](Set-Loc $desc $Key)
    $Parent.Controls.Add($desc)
    [void]$script:RowDescLabels.Add($desc)
    return $desc
}

# Every message box: text and title are string keys. With -YesNo it returns
# $true when the user answered Yes; otherwise it returns nothing.
function Show-BfoMessage {
    param(
        [string]$Key,
        [object[]]$FormatArgs,
        [string]$TitleKey = 'msg.title.app',
        [ValidateSet('None', 'Information', 'Warning', 'Error', 'Question')][string]$Icon = 'Information',
        [switch]$YesNo
    )
    $buttons = if ($YesNo) { 'YesNo' } else { 'OK' }
    $answer = [System.Windows.Forms.MessageBox]::Show((T $Key $FormatArgs), (T $TitleKey), $buttons, $Icon)
    if ($YesNo) { return ($answer -eq 'Yes') }
}

# Opens a URL in the installed Stable Brave. Returns $false when Brave is not
# installed, so the caller can fall back or explain.
function Open-BraveUrl {
    param([string]$Url)
    $exe = Test-BraveInstalled
    if (-not $exe) { return $false }
    Start-Process $exe $Url
    return $true
}

function Show-TextReport {
    param(
        [string]$Title,
        [string]$Text,
        [string]$DefaultFileName = 'brave-free-origin-report.txt'
    )

    $rf = New-Object System.Windows.Forms.Form
    $rf.Text = $Title
    $rf.Size = New-Object System.Drawing.Size(760, 560)
    $rf.StartPosition = 'CenterParent'
    $rf.MinimumSize = New-Object System.Drawing.Size(620, 420)

    $buttons = New-Object System.Windows.Forms.Panel
    $buttons.Dock = 'Bottom'
    $buttons.Height = 44
    $rf.Controls.Add($buttons)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true
    $tb.ReadOnly = $true
    $tb.ScrollBars = 'Both'
    $tb.WordWrap = $false
    $tb.Font = New-Object System.Drawing.Font('Consolas', 9)
    $tb.Dock = 'Fill'
    $tb.Text = $Text
    $rf.Controls.Add($tb)

    $copy = New-Object System.Windows.Forms.Button
    $copy.Text = T 'report.copy'
    $copy.Size = New-Object System.Drawing.Size(90, 28)
    $copy.Location = New-Object System.Drawing.Point(10, 8)
    $copy.Add_Click({
        # Clipboard.SetText throws on an empty string.
        if ($tb.Text) { [System.Windows.Forms.Clipboard]::SetText($tb.Text) }
    })
    $buttons.Controls.Add($copy)

    $save = New-Object System.Windows.Forms.Button
    $save.Text = T 'report.save'
    $save.Size = New-Object System.Drawing.Size(110, 28)
    $save.Location = New-Object System.Drawing.Point(110, 8)
    $save.Add_Click({
        $sfd = New-Object System.Windows.Forms.SaveFileDialog
        $sfd.Filter = '{0} (*.txt)|*.txt' -f (T 'dialog.filter.textReport')
        $sfd.FileName = $DefaultFileName
        $sfd.InitialDirectory = Get-BackupDir -Create
        if ($sfd.ShowDialog() -eq 'OK') {
            Set-Content -Path $sfd.FileName -Value $tb.Text -Encoding UTF8
            Write-Log "Report saved: $($sfd.FileName)" 'OK'
        }
    })
    $buttons.Controls.Add($save)

    $close = New-Object System.Windows.Forms.Button
    $close.Text = T 'report.close'
    $close.Size = New-Object System.Drawing.Size(90, 28)
    $close.Location = New-Object System.Drawing.Point(230, 8)
    $close.Add_Click({ $rf.Close() })
    $buttons.Controls.Add($close)

    $buttons.BringToFront()
    [void]$rf.ShowDialog()
}

# ---- ComboBox id plumbing ---------------------------------------------------
# Combo Items hold translated labels; the stable id lives in a parallel array
# and is linked by SelectedIndex. That is the one binding WinForms guarantees
# for a non-data-bound ComboBox, and it survives re-translation intact.
function Get-ComboId {
    param($Combo, $Ids)
    if (-not $Combo -or -not $Ids) { return $null }
    $i = $Combo.SelectedIndex
    if ($i -lt 0 -or $i -ge @($Ids).Count) { return $null }
    return @($Ids)[$i]
}

function Set-ComboId {
    param($Combo, $Ids, [string]$Id)
    if (-not $Combo -or -not $Ids -or -not $Id) { return $false }
    $arr = @($Ids)
    for ($i = 0; $i -lt $arr.Count; $i++) {
        if ($arr[$i] -eq $Id) { $Combo.SelectedIndex = $i; return $true }
    }
    return $false
}

# Relabelling is Items.Clear() + refill, which drives SelectedIndex to -1 and
# back. Both transitions raise SelectedIndexChanged, so the handlers are muted
# for the duration and the previously selected stable id is restored exactly.
# -FormatWithId passes each item's id into its label (e.g. "{0} (installed)").
function Set-ComboLabels {
    param($Combo, $Ids, $LabelKeys, [switch]$FormatWithId)
    if (-not $Combo) { return }
    $keep = Get-ComboId -Combo $Combo -Ids $Ids
    Push-SuppressSelectionEvents
    try {
        $Combo.BeginUpdate()
        try {
            $Combo.Items.Clear()
            $keys = @($LabelKeys); $idList = @($Ids)
            for ($i = 0; $i -lt $keys.Count; $i++) {
                $label = if ($FormatWithId) { T $keys[$i] @($idList[$i]) } else { T $keys[$i] }
                [void]$Combo.Items.Add($label)
            }
        } finally {
            $Combo.EndUpdate()
        }
        if (-not (Set-ComboId -Combo $Combo -Ids $Ids -Id $keep)) {
            if ($Combo.Items.Count -gt 0) { $Combo.SelectedIndex = 0 }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
}

# One place that knows how to move a choice policy to another option: it keeps
# the picker, the in-memory ApplyValue and therefore every downstream write
# (apply / preview / verify / export) in agreement, without depending on the
# ComboBox event firing - which is muted during import and load-state.
function Set-PolicyChoiceId {
    param($Policy, [string]$ChoiceId)
    if (-not $Policy -or -not $Policy.Choices -or [string]::IsNullOrWhiteSpace($ChoiceId)) { return $false }
    if (-not $Policy.Choices.Contains($ChoiceId)) { return $false }
    $Policy.ApplyValue = $Policy.Choices[$ChoiceId]
    $combo = $script:PolicyCombos[$Policy.Name]
    if ($combo) {
        [void](Set-ComboId -Combo $combo -Ids $script:PolicyChoiceIds[$Policy.Name] -Id $ChoiceId)
    }
    return $true
}

# Same, starting from a stored value (registry, config file) instead of an id.
# A value that matches no choice leaves the policy as it is.
function Set-PolicyChoiceByValue {
    param($Policy, $Value)
    foreach ($choiceId in $Policy.Choices.Keys) {
        if ("$($Policy.Choices[$choiceId])" -eq "$Value") {
            [void](Set-PolicyChoiceId -Policy $Policy -ChoiceId $choiceId)
            return
        }
    }
}
