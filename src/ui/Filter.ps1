# ============================================================================
#  Global configuration filter engine.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# One index over every configurable row in the app (policies, scheduled tasks,
# Windows services, hosts groups). The Scriptlets tab keeps its own dedicated
# scanner/filter - it deals with thousands of records and is already tuned.
#
# Rows are absolutely positioned, so filtering also re-flows each tab: hidden
# rows collapse instead of leaving holes.
$script:ConfigFilterItems = New-Object System.Collections.ArrayList
$script:TabFlows          = @{}
$script:RowDescLabels     = New-Object System.Collections.ArrayList
$script:FilterDebounce    = $null
$script:FilterReady       = $false

# One flow record per tab, created by whichever call reaches the tab first.
# That is deliberately not always Register-FlowEntry: a tab sets its title key
# while it is being built, before it has any rows.
function Get-TabFlow {
    param($TabPage, [int]$BaseTop = 0)
    $key = $TabPage.Name
    if (-not $script:TabFlows.ContainsKey($key)) {
        $script:TabFlows[$key] = [pscustomobject]@{
            TabPage  = $TabPage
            Top      = $BaseTop
            TitleKey = $null
            Entries  = (New-Object System.Collections.ArrayList)
        }
    }
    return $script:TabFlows[$key]
}

function Register-FlowEntry {
    param(
        $TabPage,
        [ValidateSet('Row', 'Header', 'Trailer')][string]$Kind,
        $Controls,
        [int]$BaseTop,
        [int]$Height,
        [int]$CjkExtra = 0,
        [string]$Group = 'default',
        [string]$Id,
        [string]$Type,
        [string]$CategoryId,
        [scriptblock]$SearchText,
        [scriptblock]$IsSelected
    )
    $flow = Get-TabFlow -TabPage $TabPage -BaseTop $BaseTop
    # The first entry registered defines where the tab's flow starts, whether
    # or not the record already existed.
    if ($flow.Entries.Count -eq 0) { $flow.Top = $BaseTop }
    $offsets = @()
    foreach ($c in $Controls) { $offsets += ($c.Top - $BaseTop) }

    $entry = [pscustomobject]@{
        Kind = $Kind; Controls = $Controls; Offsets = $offsets
        Height = $Height; CjkExtra = $CjkExtra; Group = $Group
        Id = $Id; Type = $Type; CategoryId = $CategoryId
        SearchText = $SearchText; IsSelected = $IsSelected
        Visible = $true
    }
    [void]$flow.Entries.Add($entry)
    if ($Kind -eq 'Row') { [void]$script:ConfigFilterItems.Add($entry) }
    # No return value on purpose: call sites are statements at script scope,
    # and emitting the object would print it to the console the .bat opened.
}

# Called while the tab is still being built, so the flow record has to be
# created on demand here - looking it up and giving up when absent silently
# dropped every title key, and the per-tab match count never appeared.
function Set-FlowTabTitleKey {
    param($TabPage, [string]$Key)
    (Get-TabFlow -TabPage $TabPage).TitleKey = $Key
}

function Start-FilterDebounce {
    if (-not $script:FilterDebounce) {
        $script:FilterDebounce = New-Object System.Windows.Forms.Timer
        $script:FilterDebounce.Interval = 180
        $script:FilterDebounce.Add_Tick({
            $script:FilterDebounce.Stop()
            Update-ConfigurationFilter
        })
    }
    $script:FilterDebounce.Stop()
    $script:FilterDebounce.Start()
}

function Update-ConfigurationFilter {
    if (-not $script:FilterReady) { return }
    if (-not $script:TxtConfigFilter) { return }

    $query        = "$($script:TxtConfigFilter.Text)".Trim()
    $selectedOnly = [bool]$script:ChkSelectedOnly.Checked
    $terms        = @($query -split '\s+' | Where-Object { $_ })
    $filtering    = ($terms.Count -gt 0 -or $selectedOnly)
    $cjk          = ($script:CurrentLocale -like 'zh-*')

    $totalRows = 0
    $shownRows = 0
    $firstMatchTab = $null

    foreach ($key in @($script:TabFlows.Keys)) {
        $flow = $script:TabFlows[$key]

        # Pass 1 - decide row visibility.
        $groupHasVisible = @{}
        foreach ($entry in $flow.Entries) {
            if ($entry.Kind -ne 'Row') { continue }
            $totalRows++
            $visible = $true
            if ($selectedOnly) {
                try { $visible = [bool](& $entry.IsSelected) } catch { $visible = $true }
            }
            if ($visible -and $terms.Count -gt 0) {
                $hay = ''
                try { $hay = "$(& $entry.SearchText)" } catch { $hay = '' }
                foreach ($t in $terms) {
                    if ($hay -notmatch [regex]::Escape($t)) { $visible = $false; break }
                }
            }
            $entry.Visible = $visible
            if ($visible) {
                $shownRows++
                $groupHasVisible[$entry.Group] = $true
            }
        }

        # Pass 2 - headers follow their group. Trailers are never hidden.
        foreach ($entry in $flow.Entries) {
            if ($entry.Kind -eq 'Header') { $entry.Visible = [bool]$groupHasVisible[$entry.Group] }
        }

        # Pass 3 - re-flow.
        $tabVisibleRows = 0
        $y = $flow.Top
        $flow.TabPage.SuspendLayout()
        foreach ($entry in $flow.Entries) {
            if (-not $entry.Visible) {
                foreach ($c in $entry.Controls) { $c.Visible = $false }
                continue
            }
            for ($i = 0; $i -lt $entry.Controls.Count; $i++) {
                $c = $entry.Controls[$i]
                $c.Top = $y + $entry.Offsets[$i]
                $c.Visible = $true
            }
            $y += $entry.Height
            if ($cjk) { $y += $entry.CjkExtra }
            if ($entry.Kind -eq 'Row') { $tabVisibleRows++ }
        }
        $flow.TabPage.ResumeLayout()

        # Tab caption gets a live match count while filtering.
        if ($flow.TitleKey) {
            if ($filtering) {
                $flow.TabPage.Text = T 'filter.tabCount' @((T $flow.TitleKey), $tabVisibleRows)
            } else {
                $flow.TabPage.Text = T $flow.TitleKey
            }
        }
        if ($filtering -and $tabVisibleRows -gt 0 -and -not $firstMatchTab) { $firstMatchTab = $flow.TabPage }
    }

    if ($script:LblFilterCount) {
        if ($shownRows -eq 0 -and $filtering) {
            $script:LblFilterCount.Text = T 'filter.noMatches'
        } else {
            $script:LblFilterCount.Text = T 'filter.matches' @($shownRows, $totalRows)
        }
    }

    # Jump to the first tab that actually has a hit, but never fight the user
    # while they are reading a tab that already matches.
    if ($filtering -and $firstMatchTab -and $script:Tabs) {
        # SelectedTab can legitimately be $null (no tab selected yet, or the
        # control has no handle), and indexing a hashtable with $null is a
        # terminating error - which would abort the whole filter pass.
        $currentTab  = $script:Tabs.SelectedTab
        $currentFlow = $null
        if ($currentTab -and $currentTab.Name) { $currentFlow = $script:TabFlows[$currentTab.Name] }
        $currentHasHit = $false
        if ($currentFlow) {
            foreach ($e in $currentFlow.Entries) {
                if ($e.Kind -eq 'Row' -and $e.Visible) { $currentHasHit = $true; break }
            }
        }
        if (-not $currentHasHit) { $script:Tabs.SelectedTab = $firstMatchTab }
    }
}

function Clear-ConfigurationFilter {
    $script:TxtConfigFilter.Text = ''
    $script:ChkSelectedOnly.Checked = $false
    Update-ConfigurationFilter
}

# Description labels are re-measured on language switch: CJK needs a larger
# point size and more vertical room than the 8pt English default.
#
# The height is ASSIGNED, never max()'d against the current value. Growing
# monotonically looked fine going en -> zh, then left 34px labels inside 28px
# rows on the way back, so consecutive descriptions overlapped. The active
# locale alone decides the geometry, every time, in both directions.
function Update-LocalizedRowText {
    $size = Get-PolicyDescFontSize
    $h    = Get-PolicyDescHeight
    foreach ($lbl in $script:RowDescLabels) {
        try {
            $lbl.Font   = Get-BfoUiFont -Size $size
            $lbl.Height = $h
        } catch { }
    }
}
