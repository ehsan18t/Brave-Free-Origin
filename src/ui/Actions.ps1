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
    if ((Get-PendingCounts).Hosts -gt 0 -and (Get-PendingCounts).Hosts -ne $before.Hosts) { $message = T 'toast.presetHosts' }
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
                        $row.Checked = ($present -and "$($values[$row.Id])" -eq "$($row.Policy.ApplyValue)")
                    }
                }
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
    Start-BfoJob -Name 'Load current state' -BusyKey 'busy.loading' -Argument $script:TargetChannels[0] `
        -Script { param($In) Get-BfoMachineState -Channel $In } -OnSuccess {
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

function Invoke-BfoApply {
    $script:ApplyMode = $script:ActiveProfile
    $script:ApplyState = Get-SelectionState
    Start-BfoJob -Name 'Apply' -BusyKey 'busy.applying' -Argument (Get-SelectionSnapshot) `
        -Script { param($In) Invoke-Apply -Selection $In } -OnSuccess {
        param($Result)
        Set-Baseline -Scope Main -State $script:ApplyState
        Update-SelectionSummary
        Show-BfoToast -Severity Success -Title (T 'toast.applied' @((Get-PresetName $script:ApplyMode))) `
            -Message (T 'toast.appliedText' @($Result.Applied, $Result.Cleared))
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
    $targets = $script:TargetChannels -join ', '
    if (-not (Show-BfoMessage 'msg.restore.confirm' @($targets) -TitleKey 'msg.title.fullRestore' -Icon Warning -YesNo -Danger)) { return }
    Start-BfoJob -Name 'Full restore' -BusyKey 'busy.restoring' `
        -Argument ([pscustomobject]@{ Channels = @($script:TargetChannels); Backup = [bool]$script:Vm.Backup }) `
        -Script { param($In) Invoke-FullRestore -Channels $In.Channels -Backup $In.Backup } -OnSuccess {
        Push-SuppressSelectionEvents
        try {
            foreach ($row in $script:Rows) { $row.Checked = $false }
            $script:Vm.SearchEnabled = $false
            $script:Vm.NtpEnabled = $false
            $script:Vm.StartupEnabled = $false
        } finally { Pop-SuppressSelectionEvents }
        $script:ActiveProfile = 'None'
        Update-OverrideStates
        Set-Baseline -Scope All
        Update-SelectionSummary
        Show-BfoToast -Severity Success -Title (T 'msg.title.done') -Message (T 'msg.restore.done')
    }
}

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

# Sections and names the file omits are left as they are.
function Import-BfoConfig {
    param($Config)
    $vm = $script:Vm
    $maps = @{ Policy = $Config.policies; Task = $Config.tasks; Service = $Config.services }
    Push-SuppressSelectionEvents
    try {
        foreach ($row in $script:Rows) {
            if ($row.Kind -eq 'Hosts' -or -not $maps[$row.Kind]) { continue }
            $entry = $maps[$row.Kind].PSObject.Properties[$row.Id]
            if ($entry) { $row.Checked = [bool]$entry.Value }
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
        if ($Config.startup) {
            $vm.StartupEnabled = [bool]$Config.startup.enabled
            $modeId = Resolve-ConfigId -Id $Config.startup.modeId -Legacy $Config.startup.mode -Map $script:LegacyStartupModeIds
            if ($modeId -and (Get-ChoiceIndex $vm.StartupModeItems $modeId) -ge 0) { $vm.StartupModeIndex = Get-ChoiceIndex $vm.StartupModeItems $modeId }
            if ($Config.startup.urls) { $vm.StartupUrls = [string]$Config.startup.urls }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = if ($Config.profile) { "$($Config.profile)" } else { 'Custom' }
    Update-OverrideStates
    Update-SelectionSummary
}

# ---- Search and startup overrides -----------------------------------------------------------
foreach ($toggle in @($ui.ChkSearch, $ui.ChkNtp, $ui.ChkStartup)) {
    $toggle.Add_Click({ Update-OverrideStates; Update-SelectionSummary })
}
foreach ($combo in @($ui.CmbEngine, $ui.CmbNtp, $ui.CmbStartup)) {
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
        -Script { param($In) Set-HostsBlockDomains -Domains $In } -OnSuccess {
        Set-Baseline -Scope Hosts -State $script:HostsApplyState
        Update-SelectionSummary
        Show-BfoToast -Severity Success -Title (T 'msg.title.hosts') -Message (T 'msg.hosts.applied' @($script:HostsApplyCount))
    }
})

$ui.BtnHostsRemove.Add_Click({
    if (-not (Show-BfoMessage 'msg.hosts.confirmRemove' -TitleKey 'msg.title.hosts' -Icon Warning -YesNo -Danger)) { return }
    Start-BfoJob -Name 'Hosts remove' -BusyKey 'busy.hosts' -Script { Clear-HostsBlock } -OnSuccess {
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
