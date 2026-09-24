# ============================================================================
#  Tab control and one tab per policy category.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Tab control
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(10, 288)
$tabs.Size = New-Object System.Drawing.Size(1145, 418)
$tabs.Anchor = 'Top, Left, Right, Bottom'
$script:Tabs = $tabs
$form.Controls.Add($tabs)

# Track every checkbox so we can iterate on apply/reset
$script:CheckBoxes = @()
# Maps a policy Name -> its value-picker ComboBox (only for policies that
# define a Choices map, e.g. HardwareAccelerationModeEnabled). Used by
# refresh/import so the picker reflects the real registry value.
$script:PolicyCombos = @{}
$script:PolicyChoiceIds = @{}
$script:PolicyChoiceKeys = @{}
$script:PolicyCheckBoxIndex = @{}

foreach ($cat in $script:Policies.Keys) {
    $tab = New-Object System.Windows.Forms.TabPage
    # Tab caption is translated; $cat stays the stable category id and is what
    # Select all / Select none and the filter index match on.
    $tab.Name = "policyTab_$cat"
    [void](Set-Loc $tab ("category.$cat"))
    Set-FlowTabTitleKey $tab ("category.$cat")
    $tab.AutoScroll = $true
    $tab.BackColor = [System.Drawing.Color]::White

    $selAll = New-Object System.Windows.Forms.LinkLabel
    [void](Set-Loc $selAll 'policyTab.selectAll')
    $selAll.Location = New-Object System.Drawing.Point(10, 8)
    $selAll.AutoSize = $true
    $selAll.Tag = $cat
    $selAll.Add_LinkClicked({
        $myCat = $this.Tag
        Push-SuppressSelectionEvents
        try {
            foreach ($cb in $script:CheckBoxes) {
                if ($cb.Tag.Category -eq $myCat) { $cb.Checked = $true }
            }
        } finally {
            Pop-SuppressSelectionEvents
        }
        $script:ActiveProfile = 'Custom'
        Update-SelectionSummary
        Update-ConfigurationFilter
    })
    $tab.Controls.Add($selAll)

    $selNone = New-Object System.Windows.Forms.LinkLabel
    [void](Set-Loc $selNone 'policyTab.selectNone')
    $selNone.Location = New-Object System.Drawing.Point(90, 8)
    $selNone.AutoSize = $true
    $selNone.Tag = $cat
    $selNone.Add_LinkClicked({
        $myCat = $this.Tag
        Push-SuppressSelectionEvents
        try {
            foreach ($cb in $script:CheckBoxes) {
                if ($cb.Tag.Category -eq $myCat) { $cb.Checked = $false }
            }
        } finally {
            Pop-SuppressSelectionEvents
        }
        $script:ActiveProfile = 'Custom'
        Update-SelectionSummary
        Update-ConfigurationFilter
    })
    $tab.Controls.Add($selNone)

    $y = 35
    foreach ($p in $script:Policies[$cat]) {
        $cb = New-Object System.Windows.Forms.CheckBox
        # The caption is the raw registry value name. It is deliberately NOT
        # translated: users cross-check it against brave://policy, and the
        # Consolas face has no CJK coverage anyway. Only the description is
        # localized.
        if ($p.Choices) { $cb.Text = $p.Name } else { $cb.Text = "$($p.Name)    =>  $($p.ApplyValue)" }
        $cb.Location = New-Object System.Drawing.Point(15, $y)
        $cb.Size = New-Object System.Drawing.Size(($(if ($p.Choices) { 300 } else { 450 })), 20)
        $cb.Font = New-Object System.Drawing.Font('Consolas', 9)
        $cb.Tag = @{Policy = $p; Category = $cat}
        $cb.Add_CheckedChanged({
            if ($script:SuppressSelectionEvents) { return }
            Set-CustomMode
            Update-ConfigurationFilter
        })
        [void](Set-LocTooltip $cb ("policy.$($p.Name).description"))
        $tab.Controls.Add($cb)
        $script:CheckBoxes += $cb
        $rowControls = @($cb)

        # Value picker for choice-based policies. Selecting an item rewrites the
        # policy's ApplyValue in place, so every downstream path (apply, verify,
        # export) automatically uses the chosen value with no extra plumbing.
        if ($p.Choices) {
            $combo = New-Object System.Windows.Forms.ComboBox
            $combo.DropDownStyle = 'DropDownList'
            $combo.Location = New-Object System.Drawing.Point(320, ($y - 1))
            $combo.Size = New-Object System.Drawing.Size(140, 22)
            $combo.Font = New-Object System.Drawing.Font('Consolas', 9)
            $choiceIds  = @($p.Choices.Keys)
            $choiceKeys = @($choiceIds | ForEach-Object { "policy.$($p.Name).choice.$_" })
            $script:PolicyChoiceIds[$p.Name] = $choiceIds
            $script:PolicyChoiceKeys[$p.Name] = $choiceKeys
            Set-ComboLabels -Combo $combo -Ids $choiceIds -LabelKeys $choiceKeys
            $script:PolicyCombos[$p.Name] = $combo
            # Preselect the id whose value matches the current ApplyValue.
            foreach ($cid in $choiceIds) {
                if ("$($p.Choices[$cid])" -eq "$($p.ApplyValue)") {
                    [void](Set-PolicyChoiceId -Policy $p -ChoiceId $cid); break
                }
            }
            $combo.Tag = $p
            # Gated: relabelling the picker for a new language clears and
            # refills Items, which would otherwise land here with a transient
            # SelectedIndex of -1 and then flip the profile to Custom.
            $combo.Add_SelectedIndexChanged({
                if ($script:SuppressSelectionEvents) { return }
                $pol = $this.Tag
                $cid = Get-ComboId -Combo $this -Ids $script:PolicyChoiceIds[$pol.Name]
                if (-not $cid) { return }
                # Set-PolicyChoiceId writes the picker back as well as the
                # value. Assigning the index it already holds does not raise
                # the event again, but muting makes that structural rather
                # than a WinForms detail we are relying on.
                Push-SuppressSelectionEvents
                try { [void](Set-PolicyChoiceId -Policy $pol -ChoiceId $cid) }
                finally { Pop-SuppressSelectionEvents }
                Set-CustomMode
            })
            [void](Set-LocTooltip $combo ("policy.$($p.Name).description"))
            $tab.Controls.Add($combo)
            $rowControls += $combo
        }

        $desc = New-Object System.Windows.Forms.Label
        $desc.Location = New-Object System.Drawing.Point(475, ($y + 2))
        $desc.Size = New-Object System.Drawing.Size(630, (Get-PolicyDescHeight))
        $desc.ForeColor = [System.Drawing.Color]::DimGray
        $desc.Font = Get-BfoUiFont -Size (Get-PolicyDescFontSize)
        [void](Set-Loc $desc ("policy.$($p.Name).description"))
        $tab.Controls.Add($desc)
        [void]$script:RowDescLabels.Add($desc)
        $rowControls += $desc

        $policyName = $p.Name
        $categoryId = $cat
        Register-FlowEntry -TabPage $tab -Kind 'Row' -Controls $rowControls -BaseTop $y `
            -Height 28 -CjkExtra 8 -Group 'policies' -Id $policyName -Type 'Policy' -CategoryId $cat `
            -SearchText ([scriptblock]::Create("@('$policyName', (T 'policy.$policyName.description'), (T 'category.$categoryId')) -join ' '")) `
            -IsSelected ([scriptblock]::Create('$script:PolicyCheckBoxIndex[''' + $policyName + '''].Checked'))
        $script:PolicyCheckBoxIndex[$policyName] = $cb

        $y += 28
    }
    $tabs.TabPages.Add($tab)
}
