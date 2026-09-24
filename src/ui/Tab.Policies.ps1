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

    # Select all / Select none: tick or untick every policy on this tab.
    foreach ($link in @(@{ Key = 'policyTab.selectAll'; X = 10; Value = $true },
                        @{ Key = 'policyTab.selectNone'; X = 90; Value = $false })) {
        $sel = New-LocControl LinkLabel $tab $link.Key $link.X 8
        $sel.AutoSize = $true
        $sel.Tag = @{ Category = $cat; Value = $link.Value }
        $sel.Add_LinkClicked({
            Push-SuppressSelectionEvents
            try {
                foreach ($cb in $script:CheckBoxes) {
                    if ($cb.Tag.Category -eq $this.Tag.Category) { $cb.Checked = $this.Tag.Value }
                }
            } finally {
                Pop-SuppressSelectionEvents
            }
            Set-CustomMode
            Update-ConfigurationFilter
        })
    }

    $y = 35
    foreach ($p in $script:Policies[$cat]) {
        # The caption is the raw registry value name; only the description is
        # localized. Choice policies show their value in the picker instead.
        $caption = if ($p.Choices) { $p.Name } else { "$($p.Name)    =>  $($p.ApplyValue)" }
        $width = if ($p.Choices) { 300 } else { 450 }
        $cb = New-RowCheckBox -Parent $tab -Text $caption -Y $y -Width $width `
            -Tag @{Policy = $p; Category = $cat} -TipKey "policy.$($p.Name).description"
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
            Set-PolicyChoiceByValue -Policy $p -Value $p.ApplyValue
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
            Set-LocTooltip $combo ("policy.$($p.Name).description")
            $tab.Controls.Add($combo)
            $rowControls += $combo
        }

        $rowControls += New-RowDescLabel -Parent $tab -Key "policy.$($p.Name).description" -X 475 -Y ($y + 2) -Width 630

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
