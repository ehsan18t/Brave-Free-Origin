# ============================================================================
#  Commands: presets, load state, preview, apply, verify, full restore, config
#  import and export, the hosts page, overrides and the extension links.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Anything that reads or writes the machine goes through Start-BfoJob; the
# OnSuccess handler then updates the rows on the UI thread.

function Invoke-BfoPreset {
    param([string]$Preset)
    # Only jobs that rewrite the selection get in the way: a pick made while
    # this PC's state is being read is applied as soon as the read is done,
    # and one made during a full restore is dropped (the restore clears it).
    $jobNames = @(@($script:CurrentJob) + @($script:JobQueue.ToArray()) | Where-Object { $_ } | ForEach-Object { $_.Name })
    if ($jobNames -contains 'Load current state') { $script:PendingPreset = $Preset; return }
    if ($jobNames -contains 'Full restore') { return }
    $before = Get-PendingCounts
    Set-PresetSelection -Preset $Preset
    Update-SelectionSummary
    Write-BfoLog "Loaded mode: $(Get-PresetNameEn $Preset)"
    $message = T 'toast.presetText'
    # Presets tick hosts groups too, but the main Apply never writes hosts.
    $after = Get-PendingCounts
    if ($after.Hosts -gt 0 -and $after.Hosts -ne $before.Hosts) { $message = T 'toast.presetHosts' }
    Show-BfoToast -Severity Success -Title (T 'toast.presetLoaded' @((Get-PresetName $Preset))) -Message $message
}

# ---- Current state of this PC --------------------------------------------------------
function Set-SelectionFromMachine {
    param($State)
    $values = $State.Values
    Push-SuppressSelectionEvents
    try {
        foreach ($row in $script:Rows) {
            switch ($row.Kind) {
                'Policy' {
                    $present = $values.ContainsKey($row.Id)
                    if ($row.Policy.Choices) {
                        # A choice policy counts as "on" whenever a value is
                        # present; the picker shows whatever the registry holds.
                        if ($present) { Set-RowChoiceByValue $row $values[$row.Id] }
                        $row.Checked = $present
                    } else {
                        $row.Checked = ($present -and (Test-PolicyValueEqual $values[$row.Id] $row.Policy.ApplyValue))
                    }
                }
                'Flag'    { $row.Checked = (@($State.Flags) -contains $row.Flag.Entry) }
                'Task'    { $row.Checked = [bool]$State.Tasks[$row.Id] }
                'Service' { $row.Checked = [bool]$State.Services[$row.Id] }
            }
        }
        Set-HostsRowsFromDomains -Current $State.Hosts

        $vm = $script:Vm
        $vm.SearchEnabled = ($values.ContainsKey('DefaultSearchProviderEnabled') -and $values['DefaultSearchProviderEnabled'] -eq 1)
        if ($vm.SearchEnabled -and $values.ContainsKey('DefaultSearchProviderSearchURL')) {
            $url = $values['DefaultSearchProviderSearchURL']
            $engineId = @($script:SearchEngineIds | Where-Object {
                -not $script:SearchEngines[$_].IsCustom -and $script:SearchEngines[$_].URL -eq $url
            } | Select-Object -First 1)
            if ($engineId.Count -gt 0) {
                $vm.EngineIndex = Get-ChoiceIndex $vm.EngineItems $engineId[0]
            } else {
                $vm.EngineIndex = Get-ChoiceIndex $vm.EngineItems 'custom'
                $vm.CustomSearchUrl = [string]$url
            }
        }
        $vm.NtpEnabled = $values.ContainsKey('NewTabPageLocation')
        if ($vm.NtpEnabled) {
            $ntp = $values['NewTabPageLocation']
            $destinationId = @($script:DestinationIds | Where-Object { $script:DestinationOptions[$_].Value -eq $ntp } | Select-Object -First 1)
            if ($destinationId.Count -gt 0) {
                $vm.DestinationIndex = Get-ChoiceIndex $vm.DestinationItems $destinationId[0]
            } else {
                $vm.DestinationIndex = Get-ChoiceIndex $vm.DestinationItems 'custom'
                $vm.NtpCustomUrl = [string]$ntp
            }
        }
        $vm.HomeEnabled = ($values.ContainsKey('HomepageLocation') -and "$($values['HomepageIsNewTabPage'])" -ne '1')
        if ($vm.HomeEnabled) {
            $homeUrl = $values['HomepageLocation']
            $homeId = @($script:DestinationIds | Where-Object { $script:DestinationOptions[$_].Value -eq $homeUrl } | Select-Object -First 1)
            if ($homeId.Count -gt 0) {
                $vm.HomeDestinationIndex = Get-ChoiceIndex $vm.HomeDestinationItems $homeId[0]
            } else {
                $vm.HomeDestinationIndex = Get-ChoiceIndex $vm.HomeDestinationItems 'custom'
                $vm.HomeCustomUrl = [string]$homeUrl
            }
        }
        $vm.StartupEnabled = $values.ContainsKey('RestoreOnStartup')
        if ($vm.StartupEnabled) {
            $urls = @($State.StartupUrls)
            $modeId = Resolve-StartupModeId -Code $values['RestoreOnStartup'] -Urls $urls
            if ($modeId) { $vm.StartupModeIndex = Get-ChoiceIndex $vm.StartupModeItems $modeId }
            if ($urls.Count -gt 0) { $vm.StartupUrls = [string]($urls -join ', ') }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = 'CurrentState'
    Update-OverrideStates
    Set-Baseline -Scope All
    Update-SelectionSummary
}

# Ticks each hosts group whose every domain is already in the managed block.
function Set-HostsRowsFromDomains {
    param([string[]]$Current)
    foreach ($row in $script:Rows) {
        if ($row.Kind -ne 'Hosts') { continue }
        $missing = @($row.Block.Domains | Where-Object { $Current -notcontains $_ })
        $row.Checked = ($missing.Count -eq 0)
    }
}

function Invoke-BfoLoadState {
    param([switch]$Quiet)
    $script:LoadQuiet = [bool]$Quiet
    Start-BfoJob -Name 'Load current state' -BusyKey 'busy.loading' `
        -Script { Get-BfoMachineState } -OnSuccess {
        param($State)
        Set-SelectionFromMachine $State
        Write-BfoLog 'Loaded current system state.'
        $pending = $script:PendingPreset
        $script:PendingPreset = $null
        if ($pending) { Invoke-BfoPreset $pending }
        elseif (-not $script:LoadQuiet) { Show-BfoToast -Severity Success -Title (T 'toast.loaded') -Message (T 'toast.loadedText') }
    }
}

# ---- Preview, apply, verify ------------------------------------------------------------
# One plan, two views: the plain-language summary (src\ui\Summary.ps1) and the
# technical report, both built from the same Get-ApplyPlan result.
function Invoke-BfoPreview {
    $snapshot = Get-SelectionSnapshot
    Start-BfoJob -Name 'Preview' -BusyKey 'busy.preview' -Argument $snapshot -Tag $snapshot -Script {
        param($In)
        $plan = Get-ApplyPlan -Selection $In
        [pscustomobject]@{ Plan = $plan; Report = (Format-ApplyPlanReport -Selection $In -Plan $plan) }
    } -OnSuccess {
        param($Result, $Job)
        $summary = Get-PlanSummary -Plan $Result.Plan -Selection $Job.Tag
        Show-TextReport -Title (T 'report.previewTitle') -Text $Result.Report -Summary $summary `
            -DefaultFileName "brave-free-origin-apply-preview-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    }
}

# Flags live in Local State, which a running Brave rewrites on exit. When flag
# changes are pending and a channel is running, ask before applying: the rest
# can go ahead now and the flags on the next Apply.
function Invoke-BfoApply {
    $writeFlags = $true
    if ((Get-PendingCounts).Flags -gt 0) {
        $running = @(Get-FlagChannels | Where-Object { @(Get-ChannelProcesses $_).Count -gt 0 })
        if ($running.Count -gt 0) {
            if (-not (Show-BfoMessage 'msg.flags.braveRunning' @(($running -join ', ')) -TitleKey 'msg.title.flags' -Icon Warning -YesNo)) { return }
            $writeFlags = $false
        }
    }
    $script:ApplyMode = $script:ActiveProfile
    $script:ApplyState = Get-SelectionState
    $script:ApplyBaselineBefore = $script:Baseline.Clone()
    Start-BfoJob -Name 'Apply' -BusyKey 'busy.applying' `
        -Argument ([pscustomobject]@{ Selection = (Get-SelectionSnapshot); WriteFlags = $writeFlags }) `
        -Script { param($In) Invoke-Apply -Selection $In.Selection -WriteFlags $In.WriteFlags } -OnSuccess {
        param($Result)
        Set-Baseline -Scope Main -State $script:ApplyState
        if (@($Result.FlagsSkipped).Count -gt 0) {
            # Flags were not written: they stay pending.
            foreach ($key in @($script:ApplyState.Keys | Where-Object { $_.StartsWith('F:') })) {
                $script:Baseline[$key] = $script:ApplyBaselineBefore[$key]
            }
        }
        Update-SelectionSummary
        if (@($Result.FlagsSkipped).Count -gt 0) {
            Show-BfoToast -Severity Warning -Title (T 'toast.applied' @((Get-PresetName $script:ApplyMode))) `
                -Message (T 'toast.appliedNoFlags' @($Result.Applied, $Result.Cleared, (@($Result.FlagsSkipped) -join ', ')))
        } else {
            Show-BfoToast -Severity Success -Title (T 'toast.applied' @((Get-PresetName $script:ApplyMode))) `
                -Message (T 'toast.appliedText' @($Result.Applied, $Result.Cleared))
        }
        Invoke-BfoDriftCheck
    }
}

function Invoke-BfoVerify {
    Start-BfoJob -Name 'Verify' -BusyKey 'busy.verify' -Argument (Get-SelectionSnapshot) `
        -Script { param($In) New-VerifyReport -Selection $In } -OnSuccess {
        param($Report)
        Show-TextReport -Title (T 'report.verifyTitle') -Text $Report -DefaultFileName "brave-free-origin-verify-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    }
}

function Invoke-BfoFullRestore {
    if (-not (Show-BfoMessage 'msg.restore.confirm' -TitleKey 'msg.title.fullRestore' -Icon Warning -YesNo -Danger)) { return }
    Start-BfoJob -Name 'Full restore' -BusyKey 'busy.restoring' `
        -Argument ([pscustomobject]@{ Backup = [bool]$script:Vm.Backup }) `
        -Script { param($In) Invoke-FullRestore -Backup $In.Backup } -OnSuccess {
        Push-SuppressSelectionEvents
        try {
            foreach ($row in $script:Rows) { $row.Checked = $false }
            $script:Vm.SearchEnabled = $false
            $script:Vm.NtpEnabled = $false
            $script:Vm.HomeEnabled = $false
            $script:Vm.StartupEnabled = $false
        } finally { Pop-SuppressSelectionEvents }
        $script:ActiveProfile = 'Default'
        Update-OverrideStates
        Set-Baseline -Scope All
        Update-SelectionSummary
        $script:DriftReport = $null
        Update-DriftText
        Show-BfoToast -Severity Success -Title (T 'msg.title.done') -Message (T 'msg.restore.done')
    }
}

# ---- Drift: settings that stopped being in effect ----------------------------------------
# Quiet: reading the record and the machine changes nothing on screen until
# the banner appears.
function Invoke-BfoDriftCheck {
    Start-BfoJob -Name 'Drift check' -Quiet -Argument $script:BraveVersion `
        -Script { param($In) Get-DriftReport -BraveVersion $In } -OnSuccess {
        param($Report)
        $script:DriftReport = $Report
        Update-DriftText
        $count = @($Report.Items).Count
        if ($count -gt 0) { Write-BfoLog "$count applied setting(s) are no longer in effect." 'WARN' }
    } -OnError {
        param($Message)
        Write-BfoLog "Could not compare the last apply with this PC: $Message" 'WARN'
    }
}

# Runs one of the banner actions on some of the drift items, then reads the
# PC again so every page and the banner show the result.
function Invoke-BfoDriftAction {
    param([ValidateSet('Reapply', 'Cleanup', 'Accept')][string]$Action, [object[]]$Items)
    if (@($Items).Count -eq 0) { return }
    $script:DriftAction = $Action
    Start-BfoJob -Name "Drift $Action" -BusyKey 'busy.applying' `
        -Argument ([pscustomobject]@{ Action = $Action; Items = @($Items) }) -Script {
        param($In)
        switch ($In.Action) {
            'Reapply' { , @(Invoke-DriftReapply -Items $In.Items) }
            'Cleanup' { , @(Invoke-DriftCleanup -Items $In.Items) }
            'Accept'  { Remove-DriftItemsFromRecord -Items $In.Items; , @() }
        }
    } -OnSuccess {
        param($Skipped)
        if (@($Skipped).Count -gt 0) {
            Show-BfoToast -Severity Warning -Title (T 'msg.title.flags') -Message (T 'drift.skippedRunning')
        } else {
            Show-BfoToast -Severity Success -Title (T "drift.done.$($script:DriftAction)")  -Message (T 'drift.doneText')
        }
        Invoke-BfoLoadState -Quiet
        Invoke-BfoDriftCheck
    }
}

$ui.BtnDriftReapply.Add_Click({
    $items = @($script:DriftReport.Items | Where-Object { $_.Status -ne 'retired' })
    Invoke-BfoDriftAction -Action Reapply -Items $items
})
$ui.BtnDriftCleanup.Add_Click({
    $items = @($script:DriftReport.Items | Where-Object { $_.Status -eq 'retired' })
    Invoke-BfoDriftAction -Action Cleanup -Items $items
})
$ui.BtnDriftAccept.Add_Click({
    Invoke-BfoDriftAction -Action Accept -Items @($script:DriftReport.Items)
})

$ui.BtnApply.Add_Click({ Invoke-BfoApply })
$ui.BtnPreview.Add_Click({ Invoke-BfoPreview })
$ui.BtnLoadState.Add_Click({ Invoke-BfoLoadState })
$ui.BtnHomeReload.Add_Click({ Invoke-BfoLoadState })
$ui.BtnVerify.Add_Click({ Invoke-BfoVerify })
$ui.BtnFullRestore.Add_Click({ Invoke-BfoFullRestore })

foreach ($button in @($ui.BtnOpenPolicy, $ui.BtnHomePolicy)) {
    $button.Add_Click({
        if (-not (Open-BraveUrl 'brave://policy')) { Show-BfoMessage 'msg.braveMissing' -TitleKey 'msg.title.info' -Icon Information }
    })
}
$ui.BtnBackupFolder.Add_Click({ Start-Process explorer.exe (Get-BackupDir -Create) })

# Opens a URL in the installed Stable Brave. Returns $false when Brave is not
# installed, so the caller can fall back or explain.
function Open-BraveUrl {
    param([string]$Url)
    $exe = Test-BraveInstalled
    if (-not $exe) { return $false }
    Start-Process $exe $Url
    return $true
}

# ---- Config file ------------------------------------------------------------------------
# A config section's id: the schema 2 id when present, otherwise the pre-1.12
# English label mapped through its legacy table, otherwise nothing.
function Resolve-ConfigId {
    param($Id, $Legacy, [hashtable]$Map)
    if ($Id) { return "$Id" }
    if ($Legacy -and $Map.ContainsKey("$Legacy")) { return $Map["$Legacy"] }
    return $null
}

$ui.BtnExport.Add_Click({
    $file = Show-SaveDialog -FilterKey 'dialog.filter.config' -Extension 'json' -FileName "brave-free-origin-config-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    if (-not $file) { return }
    $config = ConvertTo-BfoConfig -Selection (Get-SelectionSnapshot) -AppVersion $script:AppVersion
    $config | ConvertTo-Json -Depth 5 | Set-Content -Path $file -Encoding UTF8
    Write-BfoLog "Config exported: $file" 'OK'
    Show-BfoToast -Severity Success -Title (T 'toast.exported') -Message $file
})

$ui.BtnImport.Add_Click({
    if (Test-BfoBusy) { return }
    $file = Show-OpenDialog -FilterKey 'dialog.filter.config' -Extension 'json' -InitialDirectory (Get-BackupDir)
    if (-not $file) { return }
    try {
        $cfg = Get-Content $file -Raw | ConvertFrom-Json
    } catch {
        Show-BfoMessage 'msg.config.badJson' @("$_") -TitleKey 'msg.title.importError' -Icon Error
        return
    }
    Import-BfoConfig $cfg
    $schema = if ($cfg.schemaVersion) { $cfg.schemaVersion } else { 1 }
    Write-BfoLog "Config imported from $file (schema $schema, app $($cfg.appVersion)$(if (-not $cfg.appVersion) { $cfg.version }))" 'OK'
    Show-BfoToast -Severity Success -Title (T 'msg.title.imported') -Message (T 'msg.config.imported')
})

# Sections and names the file omits are left as they are. A policy saved under
# an old name (LegacyNames in tweaks\policies) lands on the row that replaced
# it, and an old mode id is mapped onto today's modes (never onto Max).
function Import-BfoConfig {
    param($Config)
    $vm = $script:Vm
    $maps = @{ Policy = $Config.policies; Flag = $Config.flags; Task = $Config.tasks; Service = $Config.services }
    Push-SuppressSelectionEvents
    try {
        foreach ($row in $script:Rows) {
            if ($row.Kind -eq 'Hosts' -or -not $maps[$row.Kind]) { continue }
            $entry = $maps[$row.Kind].PSObject.Properties[$row.Id]
            if (-not $entry -and $row.Kind -eq 'Policy') {
                foreach ($old in @($script:LegacyPolicyNames.Keys | Where-Object { $script:LegacyPolicyNames[$_] -eq $row.Id })) {
                    $entry = $maps.Policy.PSObject.Properties[$old]
                    if ($entry) { break }
                }
            }
            if ($entry) { $row.Checked = [bool]$entry.Value -and $row.Supported }
        }
        if ($Config.policyValues) {
            # The picked value for choice policies (e.g. hardware acceleration).
            foreach ($row in $script:Rows) {
                if ($row.Kind -ne 'Policy' -or -not $row.Policy.Choices) { continue }
                $entry = $Config.policyValues.PSObject.Properties[$row.Id]
                if ($entry) { Set-RowChoiceByValue $row $entry.Value }
            }
        }
        if ($Config.hosts) {
            # Accept both schema 2 ids and the pre-1.12 English display names.
            $hostsById = @{}
            foreach ($p in $Config.hosts.PSObject.Properties) {
                $id = $p.Name
                if ($script:LegacyHostsIds.ContainsKey($id)) { $id = $script:LegacyHostsIds[$id] }
                $hostsById[$id] = [bool]$p.Value
            }
            foreach ($row in $script:Rows) {
                if ($row.Kind -eq 'Hosts' -and $hostsById.ContainsKey($row.Id)) { $row.Checked = $hostsById[$row.Id] }
            }
        }
        if ($Config.search) {
            $vm.SearchEnabled = [bool]$Config.search.enabled
            $engineId = Resolve-ConfigId -Id $Config.search.engineId -Legacy $Config.search.engine -Map $script:LegacySearchEngineIds
            if ($engineId -and (Get-ChoiceIndex $vm.EngineItems $engineId) -ge 0) { $vm.EngineIndex = Get-ChoiceIndex $vm.EngineItems $engineId }
            if ($Config.search.customUrl) { $vm.CustomSearchUrl = [string]$Config.search.customUrl }
        }
        if ($Config.ntp) {
            $vm.NtpEnabled = [bool]$Config.ntp.enabled
            $destinationId = Resolve-ConfigId -Id $Config.ntp.destinationId -Legacy $Config.ntp.destination -Map $script:LegacyDestinationIds
            if ($destinationId -and (Get-ChoiceIndex $vm.DestinationItems $destinationId) -ge 0) { $vm.DestinationIndex = Get-ChoiceIndex $vm.DestinationItems $destinationId }
            if ($Config.ntp.customUrl) { $vm.NtpCustomUrl = [string]$Config.ntp.customUrl }
        }
        if ($Config.home) {
            $vm.HomeEnabled = [bool]$Config.home.enabled
            $homeId = "$($Config.home.destinationId)"
            if ($homeId -and (Get-ChoiceIndex $vm.HomeDestinationItems $homeId) -ge 0) { $vm.HomeDestinationIndex = Get-ChoiceIndex $vm.HomeDestinationItems $homeId }
            if ($Config.home.customUrl) { $vm.HomeCustomUrl = [string]$Config.home.customUrl }
        }
        if ($Config.startup) {
            $vm.StartupEnabled = [bool]$Config.startup.enabled
            $modeId = Resolve-ConfigId -Id $Config.startup.modeId -Legacy $Config.startup.mode -Map $script:LegacyStartupModeIds
            if ($modeId -and (Get-ChoiceIndex $vm.StartupModeItems $modeId) -ge 0) { $vm.StartupModeIndex = Get-ChoiceIndex $vm.StartupModeItems $modeId }
            if ($Config.startup.urls) { $vm.StartupUrls = [string]$Config.startup.urls }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = if ($Config.profile) { Resolve-PresetId "$($Config.profile)" } else { 'Custom' }
    Update-OverrideStates
    Update-SelectionSummary
}

# ---- Search and startup overrides -----------------------------------------------------------
foreach ($toggle in @($ui.ChkSearch, $ui.ChkNtp, $ui.ChkHome, $ui.ChkStartup)) {
    $toggle.Add_Click({ Update-OverrideStates; Update-SelectionSummary })
}
foreach ($combo in @($ui.CmbEngine, $ui.CmbNtp, $ui.CmbHome, $ui.CmbStartup)) {
    $combo.Add_SelectionChanged({ Update-OverrideStates; Update-SelectionSummary })
}
# Deferred: TextChanged can arrive before the binding has written the new URL
# back to the view model.
$script:OnOverrideText = [System.Windows.Controls.TextChangedEventHandler]{
    [void]$script:Window.Dispatcher.BeginInvoke([Action]{ Update-SelectionSummary }, [System.Windows.Threading.DispatcherPriority]::Background)
}
$ui.PageSearch.AddHandler([System.Windows.Controls.TextBox]::TextChangedEvent, $script:OnOverrideText)

$ui.BtnExtUbo.Add_Click({
    $url = 'https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh'
    if (-not (Open-BraveUrl $url)) { Start-Process $url }
    Write-BfoLog 'Opened uBlock Origin Lite install page.'
})
$ui.BtnExtShields.Add_Click({
    if (-not (Open-BraveUrl 'brave://settings/shields')) { Write-BfoLog 'Brave not found.' 'WARN' }
})
$ui.BtnExtBitwarden.Add_Click({
    $url = 'https://chromewebstore.google.com/detail/bitwarden-password-manage/nngceckbapebfimnlniiiahkandclblb'
    if (-not (Open-BraveUrl $url)) { Start-Process $url }
    Write-BfoLog 'Opened Bitwarden install page.'
})

# ---- Hosts page ------------------------------------------------------------------------------
# Independent of the main Apply: these buttons are the only way hosts change.
function Get-CheckedHostsDomains {
    return @(Get-SelectionHostsDomains -Selection (Get-SelectionSnapshot))
}

$ui.BtnHostsApply.Add_Click({
    $domains = @(Get-CheckedHostsDomains)
    $confirmed = if ($domains.Count -eq 0) {
        Show-BfoMessage 'msg.hosts.noGroups' -TitleKey 'msg.title.hosts' -Icon Question -YesNo
    } else {
        Show-BfoMessage 'msg.hosts.confirmApply' @($domains.Count, $script:HostsFile) -TitleKey 'msg.title.hosts' -Icon Question -YesNo
    }
    if (-not $confirmed) { return }
    $script:HostsApplyCount = $domains.Count
    $script:HostsApplyState = Get-SelectionState
    Start-BfoJob -Name 'Hosts apply' -BusyKey 'busy.hosts' -Argument ([string[]]$domains) `
        -Script {
            param($In)
            Set-HostsBlockDomains -Domains $In
            # The drift check watches the blocked domains from now on.
            try { Save-AppliedHosts -Domains $In } catch { Write-BfoLog "Could not record the hosts block: $_" 'WARN' }
        } -OnSuccess {
        Set-Baseline -Scope Hosts -State $script:HostsApplyState
        Update-SelectionSummary
        Show-BfoToast -Severity Success -Title (T 'msg.title.hosts') -Message (T 'msg.hosts.applied' @($script:HostsApplyCount))
    }
})

$ui.BtnHostsRemove.Add_Click({
    if (-not (Show-BfoMessage 'msg.hosts.confirmRemove' -TitleKey 'msg.title.hosts' -Icon Warning -YesNo -Danger)) { return }
    Start-BfoJob -Name 'Hosts remove' -BusyKey 'busy.hosts' -Script {
        Clear-HostsBlock
        try { Save-AppliedHosts -Domains @() } catch { Write-BfoLog "Could not record the hosts block: $_" 'WARN' }
    } -OnSuccess {
        foreach ($row in $script:Rows) { if ($row.Kind -eq 'Hosts') { $row.Checked = $false } }
        Set-Baseline -Scope Hosts
        Update-SelectionSummary
        Show-BfoToast -Severity Success -Title (T 'msg.title.hosts') -Message (T 'msg.hosts.removed')
    }
})

$ui.BtnHostsLoad.Add_Click({
    Start-BfoJob -Name 'Hosts load' -BusyKey 'busy.loading' -Script { , @(Get-HostsCurrentDomains) } -OnSuccess {
        param($Current)
        Set-HostsRowsFromDomains -Current @($Current)
        Set-Baseline -Scope Hosts
        Update-SelectionSummary
        Write-BfoLog "Hosts state loaded: $(@($Current).Count) domain(s) currently blocked."
    }
})

$ui.BtnHostsPreview.Add_Click({
    $snapshot = Get-SelectionSnapshot
    $groups = @($snapshot.Hosts | Where-Object { $_.Checked }).Count
    Start-BfoJob -Name 'Hosts preview' -BusyKey 'busy.preview' `
        -Argument ([pscustomobject]@{ Domains = [string[]]@(Get-SelectionHostsDomains -Selection $snapshot); Groups = $groups }) `
        -Script { param($In) New-HostsPlanReport -Desired $In.Domains -GroupCount $In.Groups } -OnSuccess {
        param($Report)
        Show-TextReport -Title (T 'report.hostsTitle') -Text $Report -DefaultFileName "brave-free-origin-hosts-preview-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    }
})

$ui.BtnHostsOpen.Add_Click({ Start-Process notepad.exe $script:HostsFile })
