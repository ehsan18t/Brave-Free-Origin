# ============================================================================
#  The selection snapshot, reading this PC's current state, and the exported
#  config format.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- Selection snapshot -----------------------------------------------------
# Everything that writes to the machine or reports on it takes a snapshot of
# the selection instead of reading the window, because it runs on the
# background runspace (src\ui\Jobs.ps1). The window builds it with
# Get-SelectionSnapshot (src\ui\Model.ps1). Its shape:
#
#   Profile    string     active preset id, 'Custom' or 'CurrentState'
#   BaseProfile string    the mode a Custom selection started from, or $null
#   ChangeCount int       how many settings differ from BaseProfile
#   Backup     bool       export a .reg backup before writing
#   Lock       bool       lock every setting in Brave (mandatory policies
#                         only); see Get-PolicyLevel in core\Registry.ps1
#   Policies   one entry per policy, in display order:
#              Name, Type, Value (what Apply writes), Checked, HasChoices
#   Flags      Name, Entry (name@option), Checked
#   Tasks      Name, Checked
#   Services   Name, Checked
#   Hosts      Id, Checked, Domains
#   Overrides  SearchEnabled, EngineId, CustomSearchUrl,
#              NtpEnabled, DestinationId, NtpCustomUrl,
#              HomeEnabled, HomeDestinationId, HomeCustomUrl,
#              StartupEnabled, StartupModeId, StartupUrls

function Get-SelectionHostsDomains {
    param($Selection)
    $domains = @()
    foreach ($group in $Selection.Hosts) {
        if ($group.Checked) { $domains += @($group.Domains) }
    }
    return @($domains | Sort-Object -Unique)
}

# ---- Current state of this PC -----------------------------------------------
# Raw values only; the window decides what they mean for each row.

# A task or service row acts on every Windows name matching one of its Match
# patterns (see tweaks\system.psd1).
function Test-SystemNameMatch {
    param([string]$Actual, [string[]]$Patterns)
    foreach ($pattern in $Patterns) { if ($Actual -like $pattern) { return $true } }
    return $false
}

function Get-SystemEntry {
    param([object[]]$Entries, [string]$Name)
    foreach ($entry in $Entries) { if ($entry.Name -eq $Name) { return $entry } }
    return $null
}

# The tasks in the root folder, where Brave registers them, as Name and State,
# the state named the way Get-ScheduledTask names it (Disabled, Ready,
# Running, Queued, Unknown). Read through the Task Scheduler COM API:
# Get-ScheduledTask goes through CIM and costs about half a second per call,
# which made loading the state and the preview wait a second or more. If COM
# is unavailable, the cmdlet answers instead. Writes use the cmdlets.
$script:TaskStateNames = @{ 0 = 'Unknown'; 1 = 'Disabled'; 2 = 'Queued'; 3 = 'Ready'; 4 = 'Running' }
$script:TaskRootFolder = $null

function Get-RootTaskList {
    try {
        if (-not $script:TaskRootFolder) {
            $service = New-Object -ComObject Schedule.Service
            $service.Connect()
            $script:TaskRootFolder = $service.GetFolder('\')
        }
        # 1 = include hidden tasks.
        $tasks = $script:TaskRootFolder.GetTasks(1)
        return @(foreach ($task in $tasks) { [pscustomobject]@{ Name = $task.Name; State = $script:TaskStateNames[[int]$task.State] } })
    } catch {
        return @(foreach ($task in @(Get-ScheduledTask -TaskPath '\' -ErrorAction SilentlyContinue)) {
            [pscustomobject]@{ Name = $task.TaskName; State = "$($task.State)" }
        })
    }
}

# One configured task: Name, State, and Tasks, every task on this PC it
# matches. State is Disabled only when all of them are. $null when none match.
function Get-BraveTaskState {
    param([string]$Name)
    $entry = Get-SystemEntry -Entries $script:ScheduledTasks -Name $Name
    $patterns = if ($entry) { [string[]]$entry.Match } else { [string[]]@($Name) }
    $matched = @(Get-RootTaskList | Where-Object { Test-SystemNameMatch -Actual $_.Name -Patterns $patterns })
    if ($matched.Count -eq 0) { return $null }
    $active = @($matched | Where-Object { $_.State -ne 'Disabled' })
    $state = if ($active.Count -gt 0) { $active[0].State } else { 'Disabled' }
    return [pscustomobject]@{ Name = $Name; State = $state; Tasks = $matched }
}

# Every Windows service a configured row matches, as Get-Service returns them.
function Get-BraveServices {
    param([string]$Name)
    $entry = Get-SystemEntry -Entries $script:Services -Name $Name
    $patterns = if ($entry) { [string[]]$entry.Match } else { [string[]]@($Name) }
    return @(foreach ($pattern in $patterns) { Get-Service -Name $pattern -ErrorAction SilentlyContinue }) |
        Sort-Object Name -Unique
}

# A service row counts as disabled when every service it matches is.
function Test-BraveServiceDisabled {
    param([string]$Name)
    $services = @(Get-BraveServices -Name $Name)
    if ($services.Count -eq 0) { return $false }
    return (@($services | Where-Object { $_.StartType -ne 'Disabled' }).Count -eq 0)
}

function Get-BfoMachineState {
    # Both policy keys as one table, name -> value: a setting is applied
    # whether it is locked or only recommended. Mandatory wins, as in Brave.
    $tables = Get-PolicyValueTables
    $values = @{}
    foreach ($k in $tables.Recommended.Keys) { $values[$k] = $tables.Recommended[$k] }
    foreach ($k in $tables.Mandatory.Keys) { $values[$k] = $tables.Mandatory[$k] }
    $record = $null
    try { $record = Read-AppliedRecord } catch { Write-Verbose "No usable record of the last apply: $_" }
    # A row written only as Brave's own pref has no policy to read: it counts
    # as applied while Brave still holds every value the app wrote for it.
    if ($record -and $record.policies -and $record.prefs) {
        $recorded = ConvertTo-RecordTable $record.prefs
        $keys = @(foreach ($entry in $recorded.Values) { $entry.PSObject.Properties.Name })
        $current = Read-PrefKeys -Keys $keys -Target (Get-PrefReadTarget)
        foreach ($p in $record.policies.PSObject.Properties) {
            if ((Get-RecordLevel $p.Value) -ne 'pref' -or -not $recorded.Contains($p.Name)) { continue }
            $same = $true
            foreach ($entry in $recorded[$p.Name].PSObject.Properties) {
                if (-not (Test-PrefJsonEqual $current[$entry.Name] ([string]$entry.Value))) { $same = $false }
            }
            if ($same) { $values[$p.Name] = $p.Value.value }
        }
    }

    $tasks = @{}
    foreach ($t in $script:ScheduledTasks) {
        $task = Get-BraveTaskState -Name $t.Name
        $tasks[$t.Name] = [bool]($task -and $task.State -eq 'Disabled')
    }
    $services = @{}
    foreach ($s in $script:Services) { $services[$s.Name] = Test-BraveServiceDisabled -Name $s.Name }

    # The mode last applied, from the drift record: the window names the
    # selection after it when this PC no longer matches any mode exactly.
    $lastApplied = $null
    try {
        if ($record) {
            $mode = Resolve-PresetId "$($record.mode)"
            if ($mode -eq 'Custom' -and $record.baseMode) { $mode = Resolve-PresetId "$($record.baseMode)" }
            if ($script:PresetOrder -contains $mode) { $lastApplied = $mode }
        }
    } catch { Write-Verbose "No usable record of the last apply: $_" }

    # Lock is what the switch on Home shows: the choice of the last Apply, and
    # off (settings stay changeable in Brave) when there is none. MachineLock
    # is what this PC really has. They differ after an update from a version
    # that locked everything: the window then shows the switch off with one
    # change pending, and the next Apply moves those settings.
    # A setting that could stay changeable but sits in the policy key also
    # counts as locked: left there by an earlier version, or by an Apply
    # while Brave was running.
    $hasLock = $record -and $record.PSObject.Properties['lock']
    $lock = [bool]($hasLock -and $record.lock)
    $machineLock = $lock
    if (-not $lock) {
        foreach ($name in $tables.Mandatory.Keys) {
            $policy = $script:PolicyByName[$name]
            if ($policy -and -not $policy.Lock) { $machineLock = $true; break }
        }
        foreach ($name in @('DefaultSearchProviderEnabled', 'HomepageLocation', 'RestoreOnStartup')) {
            if ($tables.Mandatory.ContainsKey($name)) { $machineLock = $true }
        }
    }
    # The startup URL list sits next to RestoreOnStartup, in either key.
    $startupKey = if ($tables.Mandatory.ContainsKey('RestoreOnStartup')) { $script:PolicyPath } else { $script:RecommendedPath }
    return [pscustomobject]@{
        LastApplied = $lastApplied
        Lock        = $lock
        MachineLock = $machineLock
        Values      = $values
        Tasks       = $tasks
        Services    = $services
        Flags       = @(Get-MachineFlagEntries)
        Hosts       = @(Get-HostsCurrentDomains)
        StartupUrls = @(Get-RegistryNumberedValues -Path (Join-Path $startupKey 'RestoreOnStartupURLs'))
    }
}

# ---- Config file --------------------------------------------------------------
# schemaVersion tracks the config format, appVersion tracks the app. They move
# independently: gaining a button must not force a config migration. The
# importer (src\ui\Actions.ps1) still reads schema 1 to 3 files.
# Schema 4 is the full export for moving to another PC: App holds the app's
# own preferences (language, theme, backup) and ScriptletRules the raw text of
# the scriptlet rules this app disabled.
function ConvertTo-BfoConfig {
    param($Selection, [string]$AppVersion, $App, [string[]]$ScriptletRules)
    $o = $Selection.Overrides
    $cfg = [ordered]@{
        schemaVersion = 4
        appVersion    = $AppVersion
        exported      = (Get-Date -Format 's')
        profile       = $Selection.Profile
        baseProfile   = $Selection.BaseProfile
        lock          = [bool]$Selection.Lock
        policies      = [ordered]@{}
        policyValues  = [ordered]@{}
        flags         = [ordered]@{}
        tasks         = [ordered]@{}
        services      = [ordered]@{}
        hosts         = [ordered]@{}
        search        = [ordered]@{ enabled = [bool]$o.SearchEnabled;  engineId      = "$($o.EngineId)";          customUrl = "$($o.CustomSearchUrl)" }
        ntp           = [ordered]@{ enabled = [bool]$o.NtpEnabled;     destinationId = "$($o.DestinationId)";     customUrl = "$($o.NtpCustomUrl)" }
        home          = [ordered]@{ enabled = [bool]$o.HomeEnabled;    destinationId = "$($o.HomeDestinationId)"; customUrl = "$($o.HomeCustomUrl)" }
        startup       = [ordered]@{ enabled = [bool]$o.StartupEnabled; modeId        = "$($o.StartupModeId)";     urls      = "$($o.StartupUrls)" }
    }
    foreach ($p in $Selection.Policies) {
        $cfg.policies[$p.Name] = [bool]$p.Checked
        # Remember the picked value for choice policies (e.g. hardware accel).
        if ($p.HasChoices) { $cfg.policyValues[$p.Name] = $p.Value }
    }
    foreach ($f in $Selection.Flags)    { $cfg.flags[$f.Name]    = [bool]$f.Checked }
    foreach ($t in $Selection.Tasks)    { $cfg.tasks[$t.Name]    = [bool]$t.Checked }
    foreach ($s in $Selection.Services) { $cfg.services[$s.Name] = [bool]$s.Checked }
    foreach ($h in $Selection.Hosts)    { $cfg.hosts[$h.Id]      = [bool]$h.Checked }
    if ($App) { $cfg['app'] = [ordered]@{ language = "$($App.Language)"; theme = "$($App.Theme)"; backup = [bool]$App.Backup } }
    $cfg['scriptlets'] = [ordered]@{ disabledRules = [string[]]@($ScriptletRules | Where-Object { $_ }) }
    return $cfg
}
