# ============================================================================
#  Shared UI helpers: the text report window and ComboBox id plumbing.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

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
        $sfd.InitialDirectory = Join-Path $env:USERPROFILE 'Documents\Brave-Free-Origin-Backups'
        if (-not (Test-Path $sfd.InitialDirectory)) { New-Item -ItemType Directory -Path $sfd.InitialDirectory | Out-Null }
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
function Set-ComboLabels {
    param($Combo, $Ids, $LabelKeys)
    if (-not $Combo) { return }
    $keep = Get-ComboId -Combo $Combo -Ids $Ids
    Push-SuppressSelectionEvents
    try {
        $Combo.BeginUpdate()
        try {
            $Combo.Items.Clear()
            foreach ($k in @($LabelKeys)) { [void]$Combo.Items.Add((T $k)) }
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
