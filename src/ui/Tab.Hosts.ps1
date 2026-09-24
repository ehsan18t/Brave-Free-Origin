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

[void](New-LocControl Label $hostsTab 'hostsTab.intro' 10 8 1100 36 -FontSize 9 -ForeColor ([System.Drawing.Color]::FromArgb(70, 70, 90)))
[void](New-LocControl Label $hostsTab 'hostsTab.warn' 10 44 1100 18 -FontSize 8.5 -Semibold -ForeColor ([System.Drawing.Color]::FromArgb(160, 70, 30)))

$script:HostsCheckBoxes = @()
$y = 70
$script:HostsCheckBoxIndex = @{}
foreach ($block in $script:HostsBlocks) {
    # Unlike the policy rows this caption is translated (group name plus
    # domain count), and ticking a group does not change the active mode.
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
    Set-LocTooltip $cb $block.DescriptionKey
    $hostsTab.Controls.Add($cb)
    $script:HostsCheckBoxes += $cb

    $desc = New-RowDescLabel -Parent $hostsTab -Key $block.DescriptionKey -X 385 -Y ($y + 2) -Width 720

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

$btnApplyHosts = New-LocControl Button $hostsTab 'hostsTab.apply' 15 ($y + 10) 160 30 `
    -BackColor ([System.Drawing.Color]::FromArgb(37, 99, 63)) -ForeColor 'White' -OnClick {
    $domains = @(Get-SelectedHostsDomains)
    $confirm = if ($domains.Count -eq 0) {
        Show-BfoMessage 'msg.hosts.noGroups' -TitleKey 'msg.title.hosts' -Icon Question -YesNo
    } else {
        Show-BfoMessage 'msg.hosts.confirmApply' @($domains.Count, $script:HostsFile) -TitleKey 'msg.title.hosts' -Icon Question -YesNo
    }
    if (-not $confirm) { return }
    try {
        Set-HostsBlockDomains -Domains $domains
        Show-BfoMessage 'msg.hosts.applied' @($domains.Count) -TitleKey 'msg.title.done'
    } catch {
        Write-Log "Hosts apply failed: $_" 'ERR'
        Show-BfoMessage 'msg.failed' @("$_") -TitleKey 'msg.title.error' -Icon Error
    }
}

$btnClearHosts = New-LocControl Button $hostsTab 'hostsTab.remove' 185 ($y + 10) 160 30 -OnClick {
    if (-not (Show-BfoMessage 'msg.hosts.confirmRemove' -TitleKey 'msg.title.hosts' -Icon Warning -YesNo)) { return }
    try {
        Clear-HostsBlock
        foreach ($cb in $script:HostsCheckBoxes) { $cb.Checked = $false }
        Show-BfoMessage 'msg.hosts.removed' -TitleKey 'msg.title.done'
    } catch {
        Show-BfoMessage 'msg.failed' @("$_") -TitleKey 'msg.title.error' -Icon Error
    }
}

$btnLoadHosts = New-LocControl Button $hostsTab 'hostsTab.load' 355 ($y + 10) 160 30 -OnClick {
    $current = @(Get-HostsCurrentDomains)
    Sync-HostsCheckBoxes -Current $current
    Write-Log "Hosts state loaded: $($current.Count) domain(s) currently blocked."
}

$btnPreviewHosts = New-LocControl Button $hostsTab 'hostsTab.preview' 525 ($y + 10) 130 30 -OnClick {
    Show-TextReport -Title (T 'report.hostsTitle') -Text (New-HostsPlanReport) -DefaultFileName "brave-free-origin-hosts-preview-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
}

$btnOpenHosts = New-LocControl Button $hostsTab 'hostsTab.open' 665 ($y + 10) 140 30 -OnClick { Start-Process notepad.exe $script:HostsFile }

# The button strip flows after the group rows so filtering does not leave a
# hole between the last visible group and the actions.
Register-FlowEntry -TabPage $hostsTab -Kind 'Trailer' `
    -Controls @($btnApplyHosts, $btnClearHosts, $btnLoadHosts, $btnPreviewHosts, $btnOpenHosts) `
    -BaseTop $y -Height 50 -Group 'hosts'

$tabs.TabPages.Add($hostsTab)
