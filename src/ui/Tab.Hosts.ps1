# ============================================================================
#  Hosts blocklist tab.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- Hosts blocklist tab (v1.5) --------------------------------------------
# Independent from the main Apply button - has its own Apply/Remove inside the tab.
# Sentinel-tagged so revert is surgical. Auto-backs up hosts file before any write.
$hostsTab = New-Object System.Windows.Forms.TabPage
$hostsTab.Name = 'hostsTab'
[void](Set-Loc $hostsTab 'tab.hosts')
Set-FlowTabTitleKey $hostsTab 'tab.hosts'
$hostsTab.AutoScroll = $true
$hostsTab.BackColor = [System.Drawing.Color]::White

$hostsIntro = New-Object System.Windows.Forms.Label
[void](Set-Loc $hostsIntro 'hostsTab.intro')
[void](Set-LocFont $hostsIntro -Size 9)
$hostsIntro.Location = New-Object System.Drawing.Point(10, 8)
$hostsIntro.Size = New-Object System.Drawing.Size(1100, 36)
$hostsIntro.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 90)
$hostsTab.Controls.Add($hostsIntro)

$hostsWarn = New-Object System.Windows.Forms.Label
[void](Set-Loc $hostsWarn 'hostsTab.warn')
$hostsWarn.Location = New-Object System.Drawing.Point(10, 44)
$hostsWarn.Size = New-Object System.Drawing.Size(1100, 18)
$hostsWarn.ForeColor = [System.Drawing.Color]::FromArgb(160, 70, 30)
[void](Set-LocFont $hostsWarn -Size 8.5 -Semibold)
$hostsTab.Controls.Add($hostsWarn)

$script:HostsCheckBoxes = @()
$y = 70
$script:HostsCheckBoxIndex = @{}
foreach ($block in $script:HostsBlocks) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Location = New-Object System.Drawing.Point(15, $y)
    $cb.Size = New-Object System.Drawing.Size(360, 20)
    [void](Set-LocFont $cb -Size 9)
    $cb.Checked = [bool]$block.Recommended
    $cb.Tag = $block
    $cb.Add_CheckedChanged({
        if ($script:SuppressSelectionEvents) { return }
        Update-ConfigurationFilter
    })
    # ArgsScript re-evaluates the group name at switch time, so the domain
    # count and the translated name stay in sync.
    [void](Set-Loc $cb 'hostsTab.groupLabel' -ArgsScript ([scriptblock]::Create(
        "@((T '$($block.NameKey)'), $($block.Domains.Count))")))
    [void](Set-LocTooltip $cb $block.DescriptionKey)
    $hostsTab.Controls.Add($cb)
    $script:HostsCheckBoxes += $cb

    $desc = New-Object System.Windows.Forms.Label
    $desc.Location = New-Object System.Drawing.Point(385, ($y + 2))
    # Same height rule as every other row description, so the initial build
    # and a later language switch agree on the geometry.
    $desc.Size = New-Object System.Drawing.Size(720, (Get-PolicyDescHeight))
    $desc.ForeColor = [System.Drawing.Color]::DimGray
    $desc.Font = Get-BfoUiFont -Size (Get-PolicyDescFontSize)
    [void](Set-Loc $desc $block.DescriptionKey)
    $hostsTab.Controls.Add($desc)
    [void]$script:RowDescLabels.Add($desc)

    $domLabel = New-Object System.Windows.Forms.Label
    $domLabel.Text = ($block.Domains -join ', ')
    $domLabel.Location = New-Object System.Drawing.Point(35, ($y + 22))
    $domLabel.Size = New-Object System.Drawing.Size(340, 16)
    $domLabel.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $domLabel.Font = New-Object System.Drawing.Font('Consolas', 8)
    $hostsTab.Controls.Add($domLabel)

    $blockId = $block.Id
    $nameKey = $block.NameKey
    $descKey = $block.DescriptionKey
    $domainText = ($block.Domains -join ' ')
    Register-FlowEntry -TabPage $hostsTab -Kind 'Row' -Controls @($cb, $desc, $domLabel) -BaseTop $y `
        -Height 44 -CjkExtra 6 -Group 'hosts' -Id $blockId -Type 'HostBlock' `
        -SearchText ([scriptblock]::Create("@('$blockId', (T '$nameKey'), (T '$descKey'), '$domainText') -join ' '")) `
        -IsSelected ([scriptblock]::Create('$script:HostsCheckBoxIndex[''' + $blockId + '''].Checked'))
    $script:HostsCheckBoxIndex[$blockId] = $cb

    $y += 44
}

$btnApplyHosts = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnApplyHosts 'hostsTab.apply')
$btnApplyHosts.Size = New-Object System.Drawing.Size(160, 30)
$btnApplyHosts.Location = New-Object System.Drawing.Point(15, ($y + 10))
$btnApplyHosts.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 63)
$btnApplyHosts.ForeColor = [System.Drawing.Color]::White
$btnApplyHosts.Add_Click({
    $domains = @(Get-SelectedHostsDomains)
    if ($domains.Count -eq 0) {
        $ans = [System.Windows.Forms.MessageBox]::Show(
            (T 'msg.hosts.noGroups'),
            (T 'msg.title.hosts'), 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }
    } else {
        $msg = T 'msg.hosts.confirmApply' @($domains.Count, $script:HostsFile)
        $ans = [System.Windows.Forms.MessageBox]::Show($msg, (T 'msg.title.hosts'), 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }
    }
    try {
        Set-HostsBlockDomains -Domains $domains
        [System.Windows.Forms.MessageBox]::Show((T 'msg.hosts.applied' @($domains.Count)), (T 'msg.title.done'), 'OK', 'Information') | Out-Null
    } catch {
        Write-Log "Hosts apply failed: $_" 'ERR'
        [System.Windows.Forms.MessageBox]::Show((T 'msg.failed' @("$_")), (T 'msg.title.error'), 'OK', 'Error') | Out-Null
    }
})
$hostsTab.Controls.Add($btnApplyHosts)

$btnClearHosts = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnClearHosts 'hostsTab.remove')
$btnClearHosts.Size = New-Object System.Drawing.Size(160, 30)
$btnClearHosts.Location = New-Object System.Drawing.Point(185, ($y + 10))
$btnClearHosts.Add_Click({
    $ans = [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.hosts.confirmRemove'),
        (T 'msg.title.hosts'), 'YesNo', 'Warning')
    if ($ans -ne 'Yes') { return }
    try {
        Clear-HostsBlock
        foreach ($cb in $script:HostsCheckBoxes) { $cb.Checked = $false }
        [System.Windows.Forms.MessageBox]::Show((T 'msg.hosts.removed'), (T 'msg.title.done'), 'OK', 'Information') | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show((T 'msg.failed' @("$_")), (T 'msg.title.error'), 'OK', 'Error') | Out-Null
    }
})
$hostsTab.Controls.Add($btnClearHosts)

$btnLoadHosts = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnLoadHosts 'hostsTab.load')
$btnLoadHosts.Size = New-Object System.Drawing.Size(160, 30)
$btnLoadHosts.Location = New-Object System.Drawing.Point(355, ($y + 10))
$btnLoadHosts.Add_Click({
    $current = @(Get-HostsCurrentDomains)
    Sync-HostsCheckBoxes -Current $current
    Write-Log "Hosts state loaded: $($current.Count) domain(s) currently blocked."
})
$hostsTab.Controls.Add($btnLoadHosts)

$btnPreviewHosts = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnPreviewHosts 'hostsTab.preview')
$btnPreviewHosts.Size = New-Object System.Drawing.Size(130, 30)
$btnPreviewHosts.Location = New-Object System.Drawing.Point(525, ($y + 10))
$btnPreviewHosts.Add_Click({
    Show-TextReport -Title (T 'report.hostsTitle') -Text (New-HostsPlanReport) -DefaultFileName "brave-free-origin-hosts-preview-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
})
$hostsTab.Controls.Add($btnPreviewHosts)

$btnOpenHosts = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnOpenHosts 'hostsTab.open')
$btnOpenHosts.Size = New-Object System.Drawing.Size(140, 30)
$btnOpenHosts.Location = New-Object System.Drawing.Point(665, ($y + 10))
$btnOpenHosts.Add_Click({ Start-Process notepad.exe $script:HostsFile })
$hostsTab.Controls.Add($btnOpenHosts)

# The button strip flows after the group rows so filtering does not leave a
# hole between the last visible group and the actions.
Register-FlowEntry -TabPage $hostsTab -Kind 'Trailer' `
    -Controls @($btnApplyHosts, $btnClearHosts, $btnLoadHosts, $btnPreviewHosts, $btnOpenHosts) `
    -BaseTop $y -Height 50 -Group 'hosts'

$tabs.TabPages.Add($hostsTab)
