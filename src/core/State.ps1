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
#   Profile    string     active preset id, for reports and the config file
#   Backup     bool       export a .reg backup before writing
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
    $path = $script:PolicyPath
    $values = Get-PolicyValueTable -Path $path

    $tasks = @{}
    foreach ($t in $script:ScheduledTasks) {
        $task = Get-BraveTaskState -Name $t.Name
        $tasks[$t.Name] = [bool]($task -and $task.State -eq 'Disabled')
    }
    $services = @{}
    foreach ($s in $script:Services) { $services[$s.Name] = Test-BraveServiceDisabled -Name $s.Name }

    return [pscustomobject]@{
        Values      = $values
        Tasks       = $tasks
        Services    = $services
        Flags       = @(Get-MachineFlagEntries)
        Hosts       = @(Get-HostsCurrentDomains)
        StartupUrls = @(Get-RegistryNumberedValues -Path (Join-Path $path 'RestoreOnStartupURLs'))
    }
}

# ---- Config file --------------------------------------------------------------
# schemaVersion tracks the config format, appVersion tracks the app. They move
# independently: gaining a button must not force a config migration. The
# importer (src\ui\Actions.ps1) still reads schema 1 and 2 files.
function ConvertTo-BfoConfig {
    param($Selection, [string]$AppVersion)
    $o = $Selection.Overrides
    $cfg = [ordered]@{
        schemaVersion = 3
        appVersion    = $AppVersion
        exported      = (Get-Date -Format 's')
        profile       = $Selection.Profile
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
    return $cfg
}
