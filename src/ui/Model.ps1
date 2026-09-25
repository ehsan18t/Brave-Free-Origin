# ============================================================================
#  View model: the rows, presets, navigation entries and summary text the
#  window binds to, and the selection snapshot handed to core\.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- Bindable objects -----------------------------------------------------------
# Rows and the view model are ExpandoObjects: WPF binds to their members and
# they raise change notifications, so assigning $row.Checked = $true moves the
# switch on screen and a click writes back into $row.Checked. Two PowerShell
# habits break that and are avoided throughout the UI code:
#   * An ExpandoObject is enumerable, so a function that outputs one unrolls it
#     into key/value pairs. New-BfoObject returns it wrapped (,$object), and rows
#     never travel through the pipeline; loops and List[object] carry them.
#   * New-Object and pipeline output come wrapped in PSObject, which WPF cannot
#     read as a list or compare as an item. Collections are built with ::new()
#     and New-BfoObject stores the unwrapped value.
#     The members are filled through the dictionary interface: the same result,
#     but without paying for a dynamic call site per new member name, which is
#     most of the cost of building a hundred rows at startup.
$script:ExpandoSetItem = [System.Collections.Generic.IDictionary[string, object]].GetMethod('set_Item')

function New-BfoObject {
    param([hashtable]$Properties)
    $object = [System.Dynamic.ExpandoObject]::new()
    foreach ($key in $Properties.Keys) {
        $value = $Properties[$key]
        if ($null -ne $value) { $value = $value.psobject.BaseObject }
        [void]$script:ExpandoSetItem.Invoke($object, [object[]]@($key, $value))
    }
    , $object
}

function New-BfoList { , [System.Collections.Generic.List[object]]::new() }

$script:Visible   = [System.Windows.Visibility]::Visible
$script:Collapsed = [System.Windows.Visibility]::Collapsed
function ConvertTo-Visibility { param([bool]$Show) if ($Show) { $script:Visible } else { $script:Collapsed } }

# ---- Choice lists (combo boxes) -------------------------------------------------
# A combo's items are { Id, Label, LabelKey } objects bound by index. Relabelling
# for a new language only rewrites Label, so the selection never moves.
function New-ChoiceList {
    param([object[]]$Ids, [object[]]$LabelKeys, [switch]$FormatWithId)
    $list = New-BfoList
    for ($i = 0; $i -lt @($Ids).Count; $i++) {
        $item = New-BfoObject @{ Id = [string]$Ids[$i]; LabelKey = [string]$LabelKeys[$i]; FormatWithId = [bool]$FormatWithId; Label = '' }
        $list.Add($item)
    }
    Update-ChoiceLabels $list
    , $list
}

function Update-ChoiceLabels {
    param($List)
    foreach ($item in $List) {
        $item.Label = if ($item.FormatWithId) { [string](T $item.LabelKey @($item.Id)) } else { [string](T $item.LabelKey) }
    }
}

function Get-ChoiceId {
    param($List, [int]$Index)
    if ($Index -lt 0 -or $Index -ge $List.Count) { return $null }
    return $List[$Index].Id
}

function Get-ChoiceIndex {
    param($List, [string]$Id)
    for ($i = 0; $i -lt $List.Count; $i++) { if ($List[$i].Id -eq $Id) { return $i } }
    return -1
}

# ---- The view model -----------------------------------------------------------------
$script:ActiveProfile = 'Custom'

$script:Vm = New-BfoObject @{
    VersionText = ''; BraveText = ''; ChannelChipText = ''; AboutTitle = ''; PolicyKeyText = ''
    Presets = (New-BfoList); PresetColumns = 4
    ModeName = ''; ModeDescription = ''; RiskLine = ''; PolicyStat = ''; FlagStat = ''; TaskStat = ''; ServiceStat = ''
    ListTitle = ''; ListSubtitle = ''; ListIntro = ''; ListIntroVisibility = $script:Collapsed
    SelectedOnly = $false; SelectedOnlyVisibility = $script:Collapsed; SelectButtonsVisibility = $script:Collapsed
    ListEmptyVisibility = $script:Collapsed
    HostsPendingText = ''
    SearchEnabled = $false; EngineItems = $null; EngineIndex = 0; CustomSearchUrl = ''; CustomSearchUrlEnabled = $false
    NtpEnabled = $false; DestinationItems = $null; DestinationIndex = 0; NtpCustomUrl = ''; NtpCustomUrlEnabled = $false
    HomeEnabled = $false; HomeDestinationItems = $null; HomeDestinationIndex = 0; HomeCustomUrl = ''; HomeCustomUrlEnabled = $false
    StartupEnabled = $false; StartupModeItems = $null; StartupModeIndex = 0; StartupUrls = ''; StartupUrlsEnabled = $false
    ScriptletRoot = ''; ScriptletDisabledOnly = $false; ScriptletAdvanced = $false; ScriptletAffectDupes = $true
    ScriptletStatus = ''; ScriptletProgress = 0; ScriptletProgressVisibility = $script:Collapsed; ScanButtonText = ''
    LanguageItems = $null; LanguageIndex = 0; LanguageNote = ''
    ThemeItems = $null; ThemeIndex = 0
    Backup = $true
    BarTitle = ''; BarSubtitle = ''; BusyText = ''
    IsBusy = $false; IsIdle = $true; BusyVisibility = $script:Collapsed
    AlertCount = ''; AlertVisibility = $script:Collapsed
    DriftVisibility = $script:Collapsed; DriftTitle = ''; DriftText = ''; DriftItems = (New-BfoList)
    DriftReapplyVisibility = $script:Collapsed; DriftCleanupVisibility = $script:Collapsed
}

$script:Vm.EngineItems          = New-ChoiceList -Ids $script:SearchEngineIds -LabelKeys $script:SearchEngineLabelKeys
$script:Vm.DestinationItems     = New-ChoiceList -Ids $script:DestinationIds  -LabelKeys $script:DestinationLabelKeys
$script:Vm.HomeDestinationItems = New-ChoiceList -Ids $script:DestinationIds  -LabelKeys $script:DestinationLabelKeys
$script:Vm.StartupModeItems     = New-ChoiceList -Ids $script:StartupModeIds  -LabelKeys $script:StartupModeLabelKeys
$script:Vm.ThemeItems           = New-ChoiceList -Ids $script:ThemeModes -LabelKeys @('theme.system', 'theme.light', 'theme.dark')

# Every channel reads the same policy key, so there is nothing to pick: the
# Home page only says which channels are installed.
$script:DetectedChannels = @(Get-DetectedChannels)

# Languages carry their own display names, so they are never relabelled.
$script:LocaleList = @(Get-AvailableLocales)
$languageItems = New-BfoList
foreach ($locale in $script:LocaleList) { $languageItems.Add((New-BfoObject @{ Id = $locale.Code; Label = $locale.Name })) }
$script:Vm.LanguageItems = $languageItems

# ---- Rows ----------------------------------------------------------------------------
# One row per policy, scheduled task, service and hosts group. PageRows holds
# what each list page shows, including the section headers on the System page.
$script:Rows = New-BfoList
$script:PageRows = @{}
$script:RowIndex = @{}

function New-SettingRow {
    param([hashtable]$Properties)
    $defaults = @{
        Checked = $false; Title = ''; Note = ''; NoteVisibility = $script:Collapsed; Detail = ''; Tip = $null
        Supported = $true; Enabled = $true
        CardVisibility = $script:Visible; HeaderVisibility = $script:Collapsed
        Choices = $null; ChoiceIndex = -1; ChoiceVisibility = $script:Collapsed; Search = ''
        Effect = $null; ImpactIds = @(); ImpactItems = $null; ImpactVisibility = $script:Collapsed
    }
    foreach ($key in $Properties.Keys) { $defaults[$key] = $Properties[$key] }
    # Side-effect tags (tweaks	ags.psd1) show as chips on the card; their
    # labels are filled in by Update-RowText.
    $impacts = @($defaults.ImpactIds | Where-Object { $_ })
    if ($impacts.Count -gt 0) {
        $chips = New-BfoList
        foreach ($id in $impacts) { $chips.Add((New-BfoObject @{ Id = $id; Label = '' })) }
        $defaults.ImpactItems = $chips
        $defaults.ImpactVisibility = $script:Visible
    }
    , (New-BfoObject $defaults)
}

function New-HeaderRow {
    param([string]$TitleKey, [string]$Title)
    , (New-BfoObject @{
        Kind = 'Header'; TitleKey = $TitleKey; Title = $(if ($TitleKey) { [string](T $TitleKey) } else { $Title })
        HeaderVisibility = $script:Visible; CardVisibility = $script:Collapsed; NoteVisibility = $script:Collapsed
        ChoiceVisibility = $script:Collapsed; ImpactVisibility = $script:Collapsed; Checked = $false; Enabled = $true
    })
}

function Add-SettingRow {
    param($Row)
    $script:Rows.Add($Row)
    $script:RowIndex["$($Row.Kind):$($Row.Id)"] = $Row
    if (-not $script:PageRows.ContainsKey($Row.PageId)) { $script:PageRows[$Row.PageId] = New-BfoList }
    $script:PageRows[$Row.PageId].Add($Row)
}

# Version gating: a row the installed Brave does not support yet (or any
# more) is greyed out and never ticked. With no Brave installed, nothing is
# gated. Policies follow the Chromium version, flags the Brave version.
$script:InstalledVersion = if ($script:BraveVersionInfo) { $script:BraveVersionInfo } else { ConvertTo-BraveVersionInfo $script:BraveVersion }

function Test-PolicySupported {
    param($Policy)
    $chromium = $script:InstalledVersion.Chromium
    if ($chromium -le 0) { return $true }
    if ($Policy.MinChromium -and $chromium -lt $Policy.MinChromium) { return $false }
    if ($Policy.MaxChromium -and $chromium -gt $Policy.MaxChromium) { return $false }
    return $true
}

function Test-FlagSupported {
    param($Flag)
    $minor = $script:InstalledVersion.BraveMinor
    return ($minor -le 0 -or $minor -ge $Flag.MinBrave)
}

foreach ($category in $script:Policies.Keys) {
    $pageId = "cat:$category"
    $script:PageRows[$pageId] = New-BfoList
    foreach ($policy in $script:Policies[$category]) {
        $supported = Test-PolicySupported $policy
        $properties = @{
            Kind = 'Policy'; Id = $policy.Name; PageId = $pageId; GroupKey = "category.$category"
            Policy = $policy; TitleKey = "policy.$($policy.Name).description"
            Detail = "$($policy.Name) = $(Format-PolicyValueText $policy.ApplyValue)"
            Effect = $policy.Effect; ImpactIds = @($policy.Impacts)
            Supported = $supported; Enabled = $supported
        }
        if ($policy.Choices) {
            # The value picker shows translated labels; the id behind each one
            # picks the registry value. It starts on the policy's default value.
            $choiceIds = @($policy.Choices.Keys)
            $choiceKeys = @($choiceIds | ForEach-Object { "policy.$($policy.Name).choice.$_" })
            $properties.Choices = New-ChoiceList -Ids $choiceIds -LabelKeys $choiceKeys
            $properties.ChoiceVisibility = $script:Visible
            $properties.ChoiceIndex = [Math]::Max(0, [Array]::IndexOf([object[]]@($policy.Choices.Values | ForEach-Object { "$_" }), "$($policy.ApplyValue)"))
            $properties.Detail = $policy.Name
        }
        Add-SettingRow (New-SettingRow $properties)
    }
}

# brave://flags rows. A ticked row writes the flag's State; unticked is Default.
$script:PageRows['flags'] = New-BfoList
foreach ($flag in $script:Flags) {
    $supported = Test-FlagSupported $flag
    Add-SettingRow (New-SettingRow @{ Kind = 'Flag'; Id = $flag.Name; PageId = 'flags'; GroupKey = 'tab.flags'
        Flag = $flag; TitleKey = "flag.$($flag.Name).description"
        Detail = "$($flag.Name) = $(if ($flag.State -eq 'enabled') { 'Enabled' } else { 'Disabled' })"
        Effect = $flag.Effect; ImpactIds = @($flag.Impacts); Supported = $supported; Enabled = $supported })
}

$script:PageRows['system'] = New-BfoList
$script:PageRows['system'].Add((New-HeaderRow -TitleKey 'system.tasksHdr'))
foreach ($task in $script:ScheduledTasks) {
    Add-SettingRow (New-SettingRow @{ Kind = 'Task'; Id = $task.Name; PageId = 'system'; GroupKey = 'system.tasksHdr'
        TitleKey = "task.$($task.Name).description"; Detail = $task.Name; Effect = $task.Effect; ImpactIds = @($task.Impacts) })
}
$script:PageRows['system'].Add((New-HeaderRow -TitleKey 'system.svcHdr'))
foreach ($service in $script:Services) {
    Add-SettingRow (New-SettingRow @{ Kind = 'Service'; Id = $service.Name; PageId = 'system'; GroupKey = 'system.svcHdr'
        TitleKey = "service.$($service.Name).description"; Detail = $service.Name; Effect = $service.Effect; ImpactIds = @($service.Impacts) })
}

# Hosts groups start on their Recommended flag, as they always have, until the
# current hosts file is read.
$script:PageRows['hosts'] = New-BfoList
foreach ($block in $script:HostsBlocks) {
    Add-SettingRow (New-SettingRow @{ Kind = 'Hosts'; Id = $block.Id; PageId = 'hosts'; GroupKey = 'tab.hosts'
        Block = $block; Checked = [bool]$block.Recommended; NoteVisibility = $script:Visible
        Detail = ($block.Domains -join ', '); Effect = $block.Effect; ImpactIds = @($block.Impacts) })
}

# Title, note and the search text are the parts of a row that depend on the
# language; everything else is fixed at build time. Update-ModelText fills them
# in, at startup and on every language switch.
# The small line under a policy or flag title: why it is greyed out, or what
# Brave does when the row is left alone.
function Get-RowNote {
    param($Row)
    $installed = $script:InstalledVersion
    if ($Row.Kind -eq 'Flag') {
        if (-not $Row.Supported) { return [string](T 'row.needsBrave' @($Row.Flag.MinBrave, $installed.BraveMinor)) }
        # A flag the row turns on is off by default, and the other way round.
        if ($Row.Flag.State -eq 'enabled') { return [string](T 'row.flagDefaultOff') }
        return [string](T 'row.flagDefaultOn')
    }
    $policy = $Row.Policy
    if (-not $Row.Supported) {
        if ($policy.MaxChromium -and $installed.Chromium -gt $policy.MaxChromium) { return [string](T 'row.tooNew' @($policy.MaxChromium, $installed.Chromium)) }
        return [string](T 'row.needsChromium' @($policy.MinChromium, $installed.Chromium))
    }
    if (-not $policy.ContainsKey('BraveDefault')) { return '' }
    $default = $policy.BraveDefault
    if ($policy.Choices) {
        $ids = @($policy.Choices.Keys)
        $values = @($policy.Choices.Values)
        for ($i = 0; $i -lt $values.Count; $i++) {
            if ("$($values[$i])" -eq "$default") { return [string](T 'row.braveDefault' @((T "policy.$($policy.Name).choice.$($ids[$i])"))) }
        }
        return [string](T 'row.changesDefault')
    }
    if (Test-PolicyValueEqual $default $policy.ApplyValue) { return [string](T 'row.lockOnly') }
    return [string](T 'row.changesDefault')
}

function Update-RowText {
    param($Row)
    switch ($Row.Kind) {
        'Header' { if ($Row.TitleKey) { $Row.Title = [string](T $Row.TitleKey) }; return }
        'Hosts' {
            $Row.Title = [string](T 'hostsTab.groupLabel' @((T $Row.Block.NameKey), $Row.Block.Domains.Count))
            $Row.Note  = [string](T $Row.Block.DescriptionKey)
        }
        default {
            $Row.Title = [string](T $Row.TitleKey)
            if ($Row.Kind -eq 'Policy' -or $Row.Kind -eq 'Flag') {
                $Row.Note = Get-RowNote $Row
                $Row.NoteVisibility = ConvertTo-Visibility ([bool]$Row.Note)
            }
        }
    }
    if ($Row.Choices) { Update-ChoiceLabels $Row.Choices }
    $chipText = ''
    if ($Row.ImpactItems) {
        foreach ($chip in $Row.ImpactItems) { $chip.Label = [string](T "impact.$($chip.Id).name"); $chipText += " $($chip.Label)" }
    }
    $Row.Search = ("$($Row.Id) $($Row.Title) $($Row.Note) $($Row.Detail) $(T $Row.GroupKey)$chipText").ToLowerInvariant()
}

# The value a policy row writes: the picked choice, or the fixed ApplyValue.
function Get-RowValue {
    param($Row)
    $policy = $Row.Policy
    if ($policy.Choices -and $Row.ChoiceIndex -ge 0 -and $Row.ChoiceIndex -lt $policy.Choices.Count) {
        return @($policy.Choices.Values)[$Row.ChoiceIndex]
    }
    return $policy.ApplyValue
}

# Points a choice row at the choice holding Value. A value that matches no
# choice leaves the row alone.
function Set-RowChoiceByValue {
    param($Row, $Value)
    if (-not $Row.Policy.Choices) { return }
    $values = @($Row.Policy.Choices.Values)
    for ($i = 0; $i -lt $values.Count; $i++) {
        if ("$($values[$i])" -eq "$Value") { $Row.ChoiceIndex = $i; return }
    }
}

# ---- Navigation --------------------------------------------------------------------
$script:CategoryGlyphs = @{
    braveFeatures = 0xEA86; aiGenAi = 0xE99A; privacyTelemetry = 0xE9D9; shields = 0xEA18; sitePermissions = 0xE8D7
    historyData = 0xE81C; autofillPasswords = 0xE72E; searchSuggestions = 0xE721; safetyUpdates = 0xE777
    webServicesBackground = 0xE753; performanceStartup = 0xEC4A; uiBloatExtras = 0xE74D
}

$script:NavItems = New-BfoList
function Add-NavItem {
    param([string]$Id, [string]$LabelKey, [int]$Glyph, [switch]$Header)
    $script:NavItems.Add((New-BfoObject @{
        Id = $Id; Kind = $(if ($Header) { 'Header' } else { 'Item' }); LabelKey = $LabelKey; Label = [string](T $LabelKey)
        Glyph = $(if ($Glyph) { [string][char]$Glyph } else { '' }); Count = ''
        HeaderVisibility = (ConvertTo-Visibility $Header); ItemVisibility = (ConvertTo-Visibility (-not $Header))
    }))
}
Add-NavItem -Id 'home' -LabelKey 'nav.home' -Glyph 0xE80F
Add-NavItem -Id '' -LabelKey 'nav.policies' -Header
foreach ($category in $script:Policies.Keys) {
    $glyph = if ($script:CategoryGlyphs.ContainsKey($category)) { $script:CategoryGlyphs[$category] } else { 0xE8FD }
    Add-NavItem -Id "cat:$category" -LabelKey "category.$category" -Glyph $glyph
}
Add-NavItem -Id '' -LabelKey 'nav.systemNetwork' -Header
Add-NavItem -Id 'system' -LabelKey 'tab.system' -Glyph 0xE770
Add-NavItem -Id 'hosts' -LabelKey 'tab.hosts' -Glyph 0xE774
Add-NavItem -Id 'search' -LabelKey 'tab.searchStartup' -Glyph 0xE7E8
Add-NavItem -Id '' -LabelKey 'nav.advanced' -Header
Add-NavItem -Id 'flags' -LabelKey 'tab.flags' -Glyph 0xE7C1
Add-NavItem -Id 'scriptlets' -LabelKey 'tab.scriptlets' -Glyph 0xE943
Add-NavItem -Id 'settings' -LabelKey 'nav.settings' -Glyph 0xE713

# ---- Presets (home page cards) ------------------------------------------------------
# The color of each card's risk label; the order is tweaks\presets.psd1's.
$script:PresetRisk = @{ Default = 'neutral'; Origin = 'low'; Recommended = 'low'; Strict = 'medium'; Max = 'high' }
foreach ($preset in $script:PresetOrder) {
    $script:Vm.Presets.Add((New-BfoObject @{
        Id = $preset; Name = ''; Description = ''; Risk = ''; RiskLevel = $(if ($script:PresetRisk.ContainsKey($preset)) { $script:PresetRisk[$preset] } else { 'neutral' })
        IsActive = $false; ActiveVisibility = $script:Collapsed
    }))
}

function Update-PresetText {
    foreach ($card in $script:Vm.Presets) {
        $card.Name = [string](Get-PresetName $card.Id)
        $card.Description = [string](Get-PresetDescription $card.Id)
        $card.Risk = [string](Get-PresetRisk $card.Id)
    }
}


# ---- Overrides (Search & Startup page) ----------------------------------------------
function Get-OverrideSnapshot {
    $vm = $script:Vm
    return [pscustomobject]@{
        SearchEnabled     = [bool]$vm.SearchEnabled
        EngineId          = (Get-ChoiceId $vm.EngineItems $vm.EngineIndex)
        CustomSearchUrl   = [string]$vm.CustomSearchUrl
        NtpEnabled        = [bool]$vm.NtpEnabled
        DestinationId     = (Get-ChoiceId $vm.DestinationItems $vm.DestinationIndex)
        NtpCustomUrl      = [string]$vm.NtpCustomUrl
        HomeEnabled       = [bool]$vm.HomeEnabled
        HomeDestinationId = (Get-ChoiceId $vm.HomeDestinationItems $vm.HomeDestinationIndex)
        HomeCustomUrl     = [string]$vm.HomeCustomUrl
        StartupEnabled    = [bool]$vm.StartupEnabled
        StartupModeId     = (Get-ChoiceId $vm.StartupModeItems $vm.StartupModeIndex)
        StartupUrls       = [string]$vm.StartupUrls
    }
}

# Which URL boxes are usable depends only on the picks, so it is derived state
# and safe to recompute at any time.
function Update-OverrideStates {
    $o = Get-OverrideSnapshot
    $engine = $script:SearchEngines[$o.EngineId]
    $script:Vm.CustomSearchUrlEnabled = [bool]($engine -and $engine.IsCustom)
    $script:Vm.NtpCustomUrlEnabled = ($o.DestinationId -eq 'custom')
    $script:Vm.HomeCustomUrlEnabled = ($o.HomeDestinationId -eq 'custom')
    $mode = $script:StartupModes[$o.StartupModeId]
    $script:Vm.StartupUrlsEnabled = [bool]($mode -and $mode.UsesURL -and -not $mode.FixedURL)
}

# ---- Selection snapshot (see core\State.ps1) ------------------------------------------
# A row the installed Brave does not support is never sent as ticked.
function Get-SelectionSnapshot {
    $policies = New-BfoList; $flags = New-BfoList; $tasks = New-BfoList; $services = New-BfoList; $hosts = New-BfoList
    foreach ($row in $script:Rows) {
        switch ($row.Kind) {
            'Policy' {
                $policies.Add([pscustomobject]@{
                    Name = $row.Id; Type = $row.Policy.Type; Value = (Get-RowValue $row)
                    Checked = [bool]($row.Checked -and $row.Supported); HasChoices = [bool]$row.Policy.Choices
                })
            }
            'Flag'    { $flags.Add([pscustomobject]@{ Name = $row.Id; Entry = $row.Flag.Entry; Checked = [bool]($row.Checked -and $row.Supported) }) }
            'Task'    { $tasks.Add([pscustomobject]@{ Name = $row.Id; Checked = [bool]$row.Checked }) }
            'Service' { $services.Add([pscustomobject]@{ Name = $row.Id; Checked = [bool]$row.Checked }) }
            'Hosts'   { $hosts.Add([pscustomobject]@{ Id = $row.Id; Checked = [bool]$row.Checked; Domains = @($row.Block.Domains) }) }
        }
    }
    return [pscustomobject]@{
        Profile   = $script:ActiveProfile
        Backup    = [bool]$script:Vm.Backup
        Policies  = $policies.ToArray()
        Flags     = $flags.ToArray()
        Tasks     = $tasks.ToArray()
        Services  = $services.ToArray()
        Hosts     = $hosts.ToArray()
        Overrides = (Get-OverrideSnapshot)
    }
}

# ---- Pending changes ------------------------------------------------------------------
# The baseline is the selection as last read from, or written to, this PC. The
# difference is what the bottom bar reports as not applied yet. Hosts groups
# are counted apart because their own page applies them.
$script:Baseline = @{}

function Get-SelectionState {
    $state = @{}
    foreach ($row in $script:Rows) {
        switch ($row.Kind) {
            'Policy'  { $state["P:$($row.Id)"] = $(if ($row.Checked) { "1|$(Format-PolicyValueText (Get-RowValue $row))" } else { '0' }) }
            'Flag'    { $state["F:$($row.Id)"] = [string][bool]$row.Checked }
            'Task'    { $state["T:$($row.Id)"] = [string][bool]$row.Checked }
            'Service' { $state["S:$($row.Id)"] = [string][bool]$row.Checked }
            'Hosts'   { $state["H:$($row.Id)"] = [string][bool]$row.Checked }
        }
    }
    $o = Get-OverrideSnapshot
    $state['O:search']  = if ($o.SearchEnabled)  { "1|$($o.EngineId)|$($o.CustomSearchUrl)" } else { '0' }
    $state['O:ntp']     = if ($o.NtpEnabled)     { "1|$($o.DestinationId)|$($o.NtpCustomUrl)" } else { '0' }
    $state['O:home']    = if ($o.HomeEnabled)    { "1|$($o.HomeDestinationId)|$($o.HomeCustomUrl)" } else { '0' }
    $state['O:startup'] = if ($o.StartupEnabled) { "1|$($o.StartupModeId)|$($o.StartupUrls)" } else { '0' }
    return $state
}

# Scope Main covers everything the main Apply writes; Hosts only the groups.
# State is the Get-SelectionState taken when a job was started: the window
# stays editable while it runs, so what was written is the selection handed to
# the job, not whatever the switches show when it finishes.
function Set-Baseline {
    param([ValidateSet('All', 'Main', 'Hosts')][string]$Scope = 'All', [hashtable]$State)
    $current = if ($State) { $State } else { Get-SelectionState }
    foreach ($key in $current.Keys) {
        $isHosts = $key.StartsWith('H:')
        if ($Scope -eq 'All' -or ($Scope -eq 'Hosts' -and $isHosts) -or ($Scope -eq 'Main' -and -not $isHosts)) {
            $script:Baseline[$key] = $current[$key]
        }
    }
}

function Get-PendingCounts {
    $current = Get-SelectionState
    $main = 0; $hosts = 0; $flags = 0
    foreach ($key in $current.Keys) {
        if ($script:Baseline[$key] -eq $current[$key]) { continue }
        if ($key.StartsWith('H:')) { $hosts++ } else { $main++ }
        if ($key.StartsWith('F:')) { $flags++ }
    }
    return @{ Main = $main; Hosts = $hosts; Flags = $flags }
}

# ---- Summary ---------------------------------------------------------------------------
function Get-CountText { param([int]$Selected, [int]$Total) "$Selected / $Total" }

function Update-SelectionSummary {
    $vm = $script:Vm
    $mode = if ([string]::IsNullOrWhiteSpace($script:ActiveProfile)) { 'Custom' } else { $script:ActiveProfile }

    $counts = @{}
    foreach ($kind in @('Policy', 'Flag', 'Task', 'Service', 'Hosts')) { $counts[$kind] = @{ On = 0; All = 0 } }
    $pageCounts = @{}
    foreach ($row in $script:Rows) {
        $counts[$row.Kind].All++
        if (-not $pageCounts.ContainsKey($row.PageId)) { $pageCounts[$row.PageId] = @{ On = 0; All = 0 } }
        $pageCounts[$row.PageId].All++
        if ($row.Checked) { $counts[$row.Kind].On++; $pageCounts[$row.PageId].On++ }
    }

    $vm.ModeName = [string](Get-PresetName $mode)
    $vm.ModeDescription = [string](Get-PresetDescription $mode)
    $vm.RiskLine = [string](T 'mode.risk' @((Get-PresetRisk $mode)))
    $vm.PolicyStat = Get-CountText $counts.Policy.On $counts.Policy.All
    $vm.FlagStat = Get-CountText $counts.Flag.On $counts.Flag.All
    $vm.TaskStat = Get-CountText $counts.Task.On $counts.Task.All
    $vm.ServiceStat = Get-CountText $counts.Service.On $counts.Service.All

    foreach ($card in $vm.Presets) {
        $active = ($card.Id -eq $mode)
        $card.IsActive = $active
        $card.ActiveVisibility = ConvertTo-Visibility $active
    }
    foreach ($item in $script:NavItems) {
        if ($item.Kind -eq 'Item' -and $pageCounts.ContainsKey($item.Id)) {
            $item.Count = Get-CountText $pageCounts[$item.Id].On $pageCounts[$item.Id].All
        }
    }

    $pending = Get-PendingCounts
    $script:PendingMain = $pending.Main
    $vm.HostsPendingText = if ($pending.Hosts -gt 0) { [string](T 'hostsTab.pending' @($pending.Hosts)) } else { [string](T 'hostsTab.inSync') }
    if ($script:CurrentPage -and $script:PageRows.ContainsKey($script:CurrentPage)) { Update-ListSubtitle }
    Update-BarText
}

function Update-BarText {
    $vm = $script:Vm
    $vm.BarTitle = $vm.ModeName
    if ($vm.IsBusy) {
        $vm.BarSubtitle = $vm.BusyText
        return
    }
    # The counts are on Home and beside each page in the navigation; the bar
    # only says whether there is anything left to apply.
    $vm.BarSubtitle = if ($script:PendingMain -gt 0) { [string](T 'bar.pending' @($script:PendingMain)) } else { [string](T 'bar.noPending') }
}

# Ticking a policy, flag, task or service by hand, or picking a value, makes
# the loadout Custom. Hosts groups do not: they are not part of a mode's apply.
function Set-CustomMode {
    if ($script:SuppressSelectionEvents) { return }
    $script:ActiveProfile = 'Custom'
}

# Loads a preset into the rows. Nothing is written until Apply. A mode sets
# every policy and flag row (and puts choice rows back on their mode value)
# and the hosts groups it may touch; it leaves the System page, the
# ManualOnly hosts groups and the Search & Startup picks alone, except that it
# can set the startup mode. Default resets everything.
function Set-PresetSelection {
    param([string]$Preset)
    $payload = Get-PresetPayload -Preset $Preset
    $vm = $script:Vm
    Push-SuppressSelectionEvents
    try {
        foreach ($row in $script:Rows) {
            switch ($row.Kind) {
                'Policy' {
                    $row.Checked = [bool]($row.Supported -and $payload.Policies -contains $row.Id)
                    if ($row.Policy.Choices) {
                        $value = if ($payload.Values.ContainsKey($row.Id)) { $payload.Values[$row.Id] } else { $row.Policy.ApplyValue }
                        Set-RowChoiceByValue $row $value
                    }
                }
                'Flag'    { $row.Checked = [bool]($row.Supported -and $payload.Flags -contains $row.Id) }
                'Task'    { if ($payload.Reset) { $row.Checked = $false } }
                'Service' { if ($payload.Reset) { $row.Checked = $false } }
                'Hosts'   {
                    if ($payload.Reset) { $row.Checked = $false }
                    elseif (-not $row.Block.ManualOnly) { $row.Checked = $payload.Hosts -contains $row.Id }
                }
            }
        }
        if ($payload.Reset) {
            $vm.SearchEnabled = $false
            $vm.NtpEnabled = $false
            $vm.HomeEnabled = $false
            $vm.StartupEnabled = $false
        } elseif ($payload.Startup) {
            $index = Get-ChoiceIndex $vm.StartupModeItems $payload.Startup
            if ($index -ge 0) {
                $vm.StartupEnabled = $true
                $vm.StartupModeIndex = $index
            }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
    Update-OverrideStates
    $script:ActiveProfile = $Preset
}

# Language-dependent text that is not a plain resource string.
function Update-ModelText {
    $vm = $script:Vm
    foreach ($row in $script:Rows) { Update-RowText $row }
    foreach ($list in $script:PageRows.Values) {
        foreach ($row in $list) { if ($row.Kind -eq 'Header') { Update-RowText $row } }
    }
    foreach ($item in $script:NavItems) { $item.Label = [string](T $item.LabelKey) }
    foreach ($list in @($vm.EngineItems, $vm.DestinationItems, $vm.HomeDestinationItems, $vm.StartupModeItems, $vm.ThemeItems)) {
        Update-ChoiceLabels $list
    }
    Update-PresetText
    $vm.VersionText = [string](T 'settings.version' @($script:AppVersion))
    $vm.AboutTitle = [string](T 'app.title' @($script:AppVersion))
    $vm.BraveText = [string](T 'header.braveDetected' @($script:BraveVersion))
    $vm.ChannelChipText = if ($script:DetectedChannels.Count -gt 0) {
        [string](T 'header.channels' @(($script:DetectedChannels -join ', ')))
    } else { [string](T 'header.noChannels') }
    $vm.PolicyKeyText = ($script:PolicyPath -replace '^HKLM:', 'HKLM')
    $entry = @($script:LocaleList | Where-Object { $_.Code -eq $script:CurrentLocale })
    $vm.LanguageNote = if ($entry.Count -gt 0 -and -not $entry[0].Reviewed -and $script:CurrentLocale -ne 'en-US') {
        [string](T 'header.unreviewedLocale')
    } else { [string](T 'settings.languageDesc') }
    Update-DriftText
}

# ---- Drift banner (Home page) ------------------------------------------------------------
# The last Get-DriftReport result. Each banner line is one item with its reason.
$script:DriftReport = $null

function Get-DriftItemTitle {
    param($Item)
    switch ($Item.Kind) {
        'Policy'   { $row = $script:RowIndex["Policy:$($Item.Name)"]; if ($row) { return [string]$row.Title }; return $Item.Name }
        'Flag'     { $row = $script:RowIndex["Flag:$($Item.Name)"]; if ($row) { return [string]$row.Title }; return $Item.Name }
        'Task'     { return [string](T "task.$($Item.Name).description") }
        'Service'  { return [string](T "service.$($Item.Name).description") }
        'Hosts'    { return [string](T 'drift.hostsTitle') }
        default    { return [string](T 'drift.overrideTitle' @($Item.Name)) }
    }
}

function Get-DriftItemDetail {
    param($Item)
    $where = if ($Item.Channel) { " [$($Item.Channel)]" } else { '' }
    switch ($Item.Status) {
        'retired' {
            $reason = if ($Item.Reason) { [string](T "retired.reason.$($Item.Reason)") } else { '' }
            return [string](T 'drift.retiredDetail' @($Item.Name, $reason)) + $where
        }
        'repeat' { return [string](T 'drift.repeatDetail' @($Item.Name)) + $where }
        default {
            $actual = if ($null -eq $Item.Actual) { [string](T 'drift.missing') } else { $Item.Actual }
            return [string](T 'drift.revertedDetail' @($Item.Name, $Item.Expected, $actual)) + $where
        }
    }
}

function Update-DriftText {
    $vm = $script:Vm
    $report = $script:DriftReport
    $vm.DriftItems.Clear()
    $items = if ($report) { @($report.Items) } else { @() }
    if ($items.Count -eq 0) {
        $vm.DriftVisibility = $script:Collapsed
        return
    }
    $mode = Resolve-PresetId "$($report.Mode)"
    $vm.DriftTitle = [string](T 'drift.title' @((Get-PresetName $mode), $items.Count))
    $reverted = @($items | Where-Object { $_.Status -ne 'retired' }).Count
    $retired = @($items | Where-Object { $_.Status -eq 'retired' }).Count
    # The record stores a sortable timestamp; show it the way Windows shows dates.
    $saved = [datetime]::MinValue
    $when = if ([datetime]::TryParse("$($report.SavedAt)", [ref]$saved)) { $saved.ToString('g') } else { "$($report.SavedAt)" }
    $vm.DriftText = [string](T 'drift.text' @($when))
    foreach ($item in $items) {
        $vm.DriftItems.Add((New-BfoObject @{
            Title = (Get-DriftItemTitle $item); Detail = (Get-DriftItemDetail $item); Status = $item.Status
        }))
    }
    $vm.DriftReapplyVisibility = ConvertTo-Visibility ($reverted -gt 0)
    $vm.DriftCleanupVisibility = ConvertTo-Visibility ($retired -gt 0)
    $vm.DriftVisibility = $script:Visible
}
