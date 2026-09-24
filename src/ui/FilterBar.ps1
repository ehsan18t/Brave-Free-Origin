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

$lblFilter = New-LocControl Label $filterPanel 'filter.label' 4 8 -FontSize 9 -Semibold
$lblFilter.AutoSize = $true

$script:TxtConfigFilter = New-LocControl TextBox $filterPanel '' 140 5 430 22 -TipKey 'filter.placeholder'
$script:TxtConfigFilter.Add_TextChanged({ Start-FilterDebounce })

$script:ChkSelectedOnly = New-LocControl CheckBox $filterPanel 'filter.selectedOnly' 582 6 160 20
$script:ChkSelectedOnly.Add_CheckedChanged({ Update-ConfigurationFilter })

[void](New-LocControl Button $filterPanel 'filter.clear' 748 4 80 24 -OnClick { Clear-ConfigurationFilter })

$script:LblFilterCount = New-LocControl Label $filterPanel '' 840 8 300 18 -ForeColor 'DimGray'
