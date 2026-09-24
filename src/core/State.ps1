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
#   Channels   string[]   target channel ids, e.g. 'Stable'
#   Profile    string     active preset id, for reports and the config file
#   Backup     bool       export a .reg backup before writing
#   Policies   one entry per policy, in display order:
#              Name, Type, Value (what Apply writes), Checked, HasChoices
#   Tasks      Name, Checked
#   Services   Name, Checked
#   Hosts      Id, Checked, Domains
#   Overrides  SearchEnabled, EngineId, CustomSearchUrl,
#              NtpEnabled, DestinationId, NtpCustomUrl,
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
# Raw values only; the window decides what they mean for each row. Loading is
# single-source by design: only the first target channel is read.
$script:RegistryProviderProperties = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')

function Get-BfoMachineState {
    param([string]$Channel)
    $path = $script:Channels[$Channel].Path

    # One read of the whole policy key instead of one per policy.
    $values = @{}
    if (Test-Path $path) {
        $props = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        if ($props) {
            foreach ($p in $props.PSObject.Properties) {
                if ($script:RegistryProviderProperties -notcontains $p.Name) { $values[$p.Name] = $p.Value }
            }
        }
    }

    $tasks = @{}
    foreach ($t in $script:ScheduledTasks) {
        $task = Get-ScheduledTask -TaskName $t.Name -ErrorAction SilentlyContinue
        $tasks[$t.Name] = [bool]($task -and $task.State -eq 'Disabled')
    }
    $services = @{}
    foreach ($s in $script:Services) {
        $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
        $services[$s.Name] = [bool]($svc -and $svc.StartType -eq 'Disabled')
    }

    return [pscustomobject]@{
        Channel     = $Channel
        Values      = $values
        Tasks       = $tasks
        Services    = $services
        Hosts       = @(Get-HostsCurrentDomains)
        StartupUrls = @(Get-RegistryNumberedValues -Path (Join-Path $path 'RestoreOnStartupURLs'))
    }
}

# ---- Config file --------------------------------------------------------------
# schemaVersion tracks the config format, appVersion tracks the app. They move
# independently: gaining a button must not force a config migration. The
# importer (src\ui\Actions.ps1) still reads schema 1 files.
function ConvertTo-BfoConfig {
    param($Selection, [string]$AppVersion)
    $o = $Selection.Overrides
    $cfg = [ordered]@{
        schemaVersion = 2
        appVersion    = $AppVersion
        exported      = (Get-Date -Format 's')
        channel       = @($Selection.Channels)
        profile       = $Selection.Profile
        policies      = [ordered]@{}
        policyValues  = [ordered]@{}
        tasks         = [ordered]@{}
        services      = [ordered]@{}
        hosts         = [ordered]@{}
        search        = [ordered]@{ enabled = [bool]$o.SearchEnabled;  engineId      = "$($o.EngineId)";      customUrl = "$($o.CustomSearchUrl)" }
        ntp           = [ordered]@{ enabled = [bool]$o.NtpEnabled;     destinationId = "$($o.DestinationId)"; customUrl = "$($o.NtpCustomUrl)" }
        startup       = [ordered]@{ enabled = [bool]$o.StartupEnabled; modeId        = "$($o.StartupModeId)"; urls      = "$($o.StartupUrls)" }
    }
    foreach ($p in $Selection.Policies) {
        $cfg.policies[$p.Name] = [bool]$p.Checked
        # Remember the picked value for choice policies (e.g. hardware accel).
        if ($p.HasChoices) { $cfg.policyValues[$p.Name] = $p.Value }
    }
    foreach ($t in $Selection.Tasks)    { $cfg.tasks[$t.Name]    = [bool]$t.Checked }
    foreach ($s in $Selection.Services) { $cfg.services[$s.Name] = [bool]$s.Checked }
    foreach ($h in $Selection.Hosts)    { $cfg.hosts[$h.Id]      = [bool]$h.Checked }
    return $cfg
}
