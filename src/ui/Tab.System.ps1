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

[void](New-LocControl Label $sysTab 'system.intro' 10 8 1080 30 -FontSize 9 -ForeColor ([System.Drawing.Color]::FromArgb(120, 50, 50)))

# One row per task or service under a section header. The name is the Windows
# name (never translated); the description comes from <KeyPrefix>.<Name>.description.
# IndexName is the script variable (name -> checkbox) behind the filter's
# "Selected only" check. Returns the next free Y.
function Add-SystemRows {
    param($Tab, [object[]]$Items, [string]$KeyPrefix, [string]$HeaderKey, [string]$Group,
          [string]$Type, [string]$IndexName, [hashtable]$Index, [int]$Y, [System.Collections.IList]$Boxes)
    foreach ($item in $Items) {
        $name = $item.Name
        $key = "$KeyPrefix.$name.description"
        $cb = New-RowCheckBox -Parent $Tab -Text $name -Y $Y -Width 450 -Tag $item -TipKey $key
        [void]$Boxes.Add($cb)
        $desc = New-RowDescLabel -Parent $Tab -Key $key -X 475 -Y ($Y + 2) -Width 630
        Register-FlowEntry -TabPage $Tab -Kind 'Row' -Controls @($cb, $desc) -BaseTop $Y `
            -Height 28 -CjkExtra 8 -Group $Group -Id $name -Type $Type `
            -SearchText ([scriptblock]::Create("@('$name', (T '$key'), (T '$HeaderKey')) -join ' '")) `
            -IsSelected ([scriptblock]::Create('$script:' + $IndexName + '[''' + $name + '''].Checked'))
        $Index[$name] = $cb
        $Y += 28
    }
    return $Y
}

$script:TaskCheckBoxIndex = @{}
$script:ServiceCheckBoxIndex = @{}
$taskBoxes = New-Object System.Collections.ArrayList
$serviceBoxes = New-Object System.Collections.ArrayList

$y = 50
$taskHdr = New-LocControl Label $sysTab 'system.tasksHdr' 10 $y -FontSize 10 -Semibold
$taskHdr.AutoSize = $true
Register-FlowEntry -TabPage $sysTab -Kind 'Header' -Controls @($taskHdr) -BaseTop $y -Height 28 -Group 'tasks'
$y = Add-SystemRows -Tab $sysTab -Items $script:ScheduledTasks -KeyPrefix 'task' -HeaderKey 'system.tasksHdr' `
    -Group 'tasks' -Type 'ScheduledTask' -IndexName 'TaskCheckBoxIndex' -Index $script:TaskCheckBoxIndex -Y ($y + 28) -Boxes $taskBoxes
$script:TaskCheckBoxes = @($taskBoxes)

$y += 15
$svcHdr = New-LocControl Label $sysTab 'system.svcHdr' 10 $y -FontSize 10 -Semibold
$svcHdr.AutoSize = $true
# BaseTop is 15px above the header so the visual gap re-flows with it.
Register-FlowEntry -TabPage $sysTab -Kind 'Header' -Controls @($svcHdr) -BaseTop ($y - 15) -Height 43 -Group 'services'
$y = Add-SystemRows -Tab $sysTab -Items $script:Services -KeyPrefix 'service' -HeaderKey 'system.svcHdr' `
    -Group 'services' -Type 'Service' -IndexName 'ServiceCheckBoxIndex' -Index $script:ServiceCheckBoxIndex -Y ($y + 28) -Boxes $serviceBoxes
$script:ServiceCheckBoxes = @($serviceBoxes)

$tabs.TabPages.Add($sysTab)
