# ============================================================================
#  System tab: scheduled tasks and services.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- System tab: scheduled tasks + services --------------------------------
$sysTab = New-Object System.Windows.Forms.TabPage
$sysTab.Name = 'sysTab'
[void](Set-Loc $sysTab 'tab.system')
Set-FlowTabTitleKey $sysTab 'tab.system'
$sysTab.AutoScroll = $true
$sysTab.BackColor = [System.Drawing.Color]::White

$sysIntro = New-Object System.Windows.Forms.Label
[void](Set-Loc $sysIntro 'system.intro')
[void](Set-LocFont $sysIntro -Size 9)
$sysIntro.Location = New-Object System.Drawing.Point(10, 8)
$sysIntro.Size = New-Object System.Drawing.Size(1080, 30)
$sysIntro.ForeColor = [System.Drawing.Color]::FromArgb(120, 50, 50)
$sysTab.Controls.Add($sysIntro)

$script:TaskCheckBoxes = @()
$script:TaskCheckBoxIndex = @{}
$script:ServiceCheckBoxIndex = @{}
$y = 50
$taskHdr = New-Object System.Windows.Forms.Label
[void](Set-Loc $taskHdr 'system.tasksHdr')
[void](Set-LocFont $taskHdr -Size 10 -Semibold)
$taskHdr.Location = New-Object System.Drawing.Point(10, $y)
$taskHdr.AutoSize = $true
$sysTab.Controls.Add($taskHdr)
Register-FlowEntry -TabPage $sysTab -Kind 'Header' -Controls @($taskHdr) -BaseTop $y -Height 28 -Group 'tasks'
$y += 28
foreach ($t in $script:ScheduledTasks) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $t.Name
    $cb.Location = New-Object System.Drawing.Point(15, $y)
    $cb.Size = New-Object System.Drawing.Size(450, 20)
    $cb.Font = New-Object System.Drawing.Font('Consolas', 9)
    $cb.Tag = $t
    $cb.Add_CheckedChanged({
        if ($script:SuppressSelectionEvents) { return }
        Set-CustomMode
        Update-ConfigurationFilter
    })
    [void](Set-LocTooltip $cb ("task.$($t.Name).description"))
    $sysTab.Controls.Add($cb)
    $script:TaskCheckBoxes += $cb

    $desc = New-Object System.Windows.Forms.Label
    $desc.Location = New-Object System.Drawing.Point(475, ($y + 2))
    $desc.Size = New-Object System.Drawing.Size(630, (Get-PolicyDescHeight))
    $desc.ForeColor = [System.Drawing.Color]::DimGray
    $desc.Font = Get-BfoUiFont -Size (Get-PolicyDescFontSize)
    [void](Set-Loc $desc ("task.$($t.Name).description"))
    $sysTab.Controls.Add($desc)
    [void]$script:RowDescLabels.Add($desc)

    $taskName = $t.Name
    Register-FlowEntry -TabPage $sysTab -Kind 'Row' -Controls @($cb, $desc) -BaseTop $y `
        -Height 28 -CjkExtra 8 -Group 'tasks' -Id $taskName -Type 'ScheduledTask' `
        -SearchText ([scriptblock]::Create("@('$taskName', (T 'task.$taskName.description'), (T 'system.tasksHdr')) -join ' '")) `
        -IsSelected ([scriptblock]::Create('$script:TaskCheckBoxIndex[''' + $taskName + '''].Checked'))
    $script:TaskCheckBoxIndex[$taskName] = $cb
    $y += 28
}

$script:ServiceCheckBoxes = @()
$y += 15
$svcHdr = New-Object System.Windows.Forms.Label
[void](Set-Loc $svcHdr 'system.svcHdr')
[void](Set-LocFont $svcHdr -Size 10 -Semibold)
$svcHdr.Location = New-Object System.Drawing.Point(10, $y)
$svcHdr.AutoSize = $true
$sysTab.Controls.Add($svcHdr)
# BaseTop is 15px above the header so the visual gap re-flows with it.
Register-FlowEntry -TabPage $sysTab -Kind 'Header' -Controls @($svcHdr) -BaseTop ($y - 15) -Height 43 -Group 'services'
$y += 28
foreach ($s in $script:Services) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $s.Name
    $cb.Location = New-Object System.Drawing.Point(15, $y)
    $cb.Size = New-Object System.Drawing.Size(450, 20)
    $cb.Font = New-Object System.Drawing.Font('Consolas', 9)
    $cb.Tag = $s
    $cb.Add_CheckedChanged({
        if ($script:SuppressSelectionEvents) { return }
        Set-CustomMode
        Update-ConfigurationFilter
    })
    [void](Set-LocTooltip $cb ("service.$($s.Name).description"))
    $sysTab.Controls.Add($cb)
    $script:ServiceCheckBoxes += $cb

    $desc = New-Object System.Windows.Forms.Label
    $desc.Location = New-Object System.Drawing.Point(475, ($y + 2))
    $desc.Size = New-Object System.Drawing.Size(630, (Get-PolicyDescHeight))
    $desc.ForeColor = [System.Drawing.Color]::DimGray
    $desc.Font = Get-BfoUiFont -Size (Get-PolicyDescFontSize)
    [void](Set-Loc $desc ("service.$($s.Name).description"))
    $sysTab.Controls.Add($desc)
    [void]$script:RowDescLabels.Add($desc)

    $svcName = $s.Name
    Register-FlowEntry -TabPage $sysTab -Kind 'Row' -Controls @($cb, $desc) -BaseTop $y `
        -Height 28 -CjkExtra 8 -Group 'services' -Id $svcName -Type 'Service' `
        -SearchText ([scriptblock]::Create("@('$svcName', (T 'service.$svcName.description'), (T 'system.svcHdr')) -join ' '")) `
        -IsSelected ([scriptblock]::Create('$script:ServiceCheckBoxIndex[''' + $svcName + '''].Checked'))
    $script:ServiceCheckBoxIndex[$svcName] = $cb
    $y += 28
}

$tabs.TabPages.Add($sysTab)
