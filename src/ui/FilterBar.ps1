# ============================================================================
#  Filter bar above the tabs.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- Global configuration filter -------------------------------------------
# Searches every policy, task, service and hosts group at once. The Scriptlets
# tab keeps its own scanner - it handles thousands of rows and is already tuned.
$filterPanel = New-Object System.Windows.Forms.Panel
$filterPanel.Location = New-Object System.Drawing.Point(10, 252)
$filterPanel.Size = New-Object System.Drawing.Size(1145, 32)
$filterPanel.Anchor = 'Top, Left, Right'
$form.Controls.Add($filterPanel)

$lblFilter = New-Object System.Windows.Forms.Label
$lblFilter.Location = New-Object System.Drawing.Point(4, 8)
$lblFilter.AutoSize = $true
[void](Set-LocFont $lblFilter -Size 9 -Semibold)
[void](Set-Loc $lblFilter 'filter.label')
$filterPanel.Controls.Add($lblFilter)

$script:TxtConfigFilter = New-Object System.Windows.Forms.TextBox
$script:TxtConfigFilter.Location = New-Object System.Drawing.Point(140, 5)
$script:TxtConfigFilter.Size = New-Object System.Drawing.Size(430, 22)
$script:TxtConfigFilter.Add_TextChanged({ Start-FilterDebounce })
$filterPanel.Controls.Add($script:TxtConfigFilter)
[void](Set-LocTooltip $script:TxtConfigFilter 'filter.placeholder')

$script:ChkSelectedOnly = New-Object System.Windows.Forms.CheckBox
$script:ChkSelectedOnly.Location = New-Object System.Drawing.Point(582, 6)
$script:ChkSelectedOnly.Size = New-Object System.Drawing.Size(160, 20)
$script:ChkSelectedOnly.Add_CheckedChanged({ Update-ConfigurationFilter })
[void](Set-Loc $script:ChkSelectedOnly 'filter.selectedOnly')
$filterPanel.Controls.Add($script:ChkSelectedOnly)

$btnClearFilter = New-Object System.Windows.Forms.Button
$btnClearFilter.Location = New-Object System.Drawing.Point(748, 4)
$btnClearFilter.Size = New-Object System.Drawing.Size(80, 24)
$btnClearFilter.Add_Click({ Clear-ConfigurationFilter })
[void](Set-Loc $btnClearFilter 'filter.clear')
$filterPanel.Controls.Add($btnClearFilter)

$script:LblFilterCount = New-Object System.Windows.Forms.Label
$script:LblFilterCount.Location = New-Object System.Drawing.Point(840, 8)
$script:LblFilterCount.Size = New-Object System.Drawing.Size(300, 18)
$script:LblFilterCount.ForeColor = [System.Drawing.Color]::DimGray
$filterPanel.Controls.Add($script:LblFilterCount)
