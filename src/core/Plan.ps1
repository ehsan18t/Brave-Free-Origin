# ============================================================================
#  Preview and verify reports: what Apply would change, and whether it landed.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Both reports take a selection snapshot (see core\State.ps1) rather than
# reading the window, so they can run on the background runspace. Report text
# stays English on purpose: it gets pasted into bug reports.

# How the reports name the levels of core\Registry.ps1.
$script:LevelLabels = @{ mandatory = 'locked'; recommended = 'recommended'; pref = 'Brave setting' }

# One preview line for one registry value: ADD, KEEP or CHANGE when it is
# wanted, CLEAR when it is not wanted but present, or $null when there is
# nothing to say. Verb is returned separately so callers can count.
function Get-PlanLine {
    param($State, [string]$Name, [bool]$Wanted, $Target)
    $verb = $null
    $current = Format-PolicyValueText $State.Value
    $target = Format-PolicyValueText $Target
    if ($Wanted) {
        if (-not $State.Exists)                                  { $verb = 'ADD';    $text = "ADD    $Name = $target" }
        elseif (Test-PolicyValueEqual $State.Value $Target)      { $verb = 'KEEP';   $text = "KEEP   $Name = $target" }
        else                                                     { $verb = 'CHANGE'; $text = "CHANGE $Name : $current -> $target" }
    } elseif ($State.Exists) {
        $verb = 'CLEAR'; $text = "CLEAR  $Name (currently $current)"
    }
    if (-not $verb) { return $null }
    return [pscustomobject]@{ Verb = $verb; Text = $text }
}

# The same for a policy that has a level: it must end up in the key of Level
# and nowhere else. MOVE is a value that stays but changes key (the lock
# switch changed); a pref-level row only reports the policy being removed.
function Get-LevelPlanLine {
    param($Tables, [string]$Name, [bool]$Wanted, $Target, [string]$Level)
    $state = Get-LevelValueState -Tables $Tables -Name $Name
    $current = Format-PolicyValueText $state.Value
    $target = Format-PolicyValueText $Target
    $label = $script:LevelLabels[$Level]
    $line = { param($Verb, $Text) [pscustomobject]@{ Verb = $Verb; Text = $Text; Current = $state.Value; Level = $Level; From = $state.Level } }
    if (-not $Wanted) {
        if ($state.Exists) { return (& $line 'CLEAR' "CLEAR  $Name (currently $current, $($script:LevelLabels[$state.Level]))") }
        return $null
    }
    if ($Level -eq 'pref') {
        if ($state.Exists) { return (& $line 'MOVE' "MOVE   $Name : policy removed, kept as Brave's own setting") }
        return $null
    }
    $here = if ($Level -eq 'mandatory') { $Tables.Mandatory } else { $Tables.Recommended }
    $there = if ($Level -eq 'mandatory') { $Tables.Recommended } else { $Tables.Mandatory }
    if ($here.ContainsKey($Name)) {
        $same = Test-PolicyValueEqual $here[$Name] $Target
        if ($same -and -not $there.ContainsKey($Name)) { return (& $line 'KEEP' "KEEP   $Name = $target ($label)") }
        if ($same) { return (& $line 'MOVE' "MOVE   $Name = $target (only $label)") }
        return (& $line 'CHANGE' "CHANGE $Name : $(Format-PolicyValueText $here[$Name]) -> $target ($label)")
    }
    if ($there.ContainsKey($Name)) {
        if (Test-PolicyValueEqual $there[$Name] $Target) { return (& $line 'MOVE' "MOVE   $Name = $target : $($script:LevelLabels[$state.Level]) -> $label") }
        return (& $line 'CHANGE' "CHANGE $Name : $current ($($script:LevelLabels[$state.Level])) -> $target ($label)")
    }
    return (& $line 'ADD' "ADD    $Name = $target ($label)")
}

# ---- The plan -----------------------------------------------------------------
# Get-ApplyPlan reads the machine once and records, for every value, flag,
# task and service, what Apply would do. Both views of the preview are built
# from it: Format-ApplyPlanReport (the technical report, below) and the
# plain-language summary in src\ui\Summary.ps1. One plan, so the two can never
# disagree.
#
#   Path       the policy key; RecommendedPath its Recommended subkey
#   Lock       whether the selection locks every setting in Brave
#   Counts     ADD / CHANGE / MOVE / CLEAR / KEEP totals for the policies
#   Policies   Name, Verb, Text, Current, Target, Level, From
#   Retired    Name, Reason, Text: retired policies present, which Apply removes
#   LegacyKeys old per-channel keys present, which Apply removes
#   Search, Ntp, Home, Startup   the overrides (see Get-OverridePlan)
#   Prefs      Name, Verb (SET, KEEP, RESET, LEAVE), Text: Brave's own
#              settings, read from the first profile (PrefTarget). Only a
#              new or changed value is set; one an earlier Apply wrote is kept
#              as Brave holds it
#   Protected  Name, Kind (Policy or Override): settings Brave keeps its own
#              signed value for, which wins over the recommendation
#   Flags      Name, Verb (ADD, CHANGE, CLEAR, KEEP), Text
#   FlagChannels, FlagsBlocked   channels flags and settings go to, and the
#              running ones
#   Tasks      Name, Verb (MISSING, KEEP, DISABLE, ENABLE), Text
#   Services   Name, Verb (MISSING, KEEP, DISABLE, RESET), Text
#   HostsDomains  how many hosts domains the selection holds

# One override section. GetDesired is the matching Get-Desired*Override, called
# with Overrides; if it throws (for example an empty custom URL) the section
# carries the error instead. Changes counts the values Apply would really
# write or remove; Lines are the report lines, Desired what would be written.
# Level is the key the values go to; any copy in the other key is removed.
function Get-OverridePlan {
    param($Tables, [string]$Level, [scriptblock]$GetDesired, $Overrides, [string[]]$Names)
    try { $desired = & $GetDesired $Overrides }
    catch { return [pscustomobject]@{ Error = "$_"; Lines = @(); Changes = 0; Desired = $null; Level = $Level } }

    $values = if ($Level -eq 'mandatory') { $Tables.Mandatory } else { $Tables.Recommended }
    $other = if ($Level -eq 'mandatory') { $Tables.Recommended } else { $Tables.Mandatory }
    $lines = @()
    $changes = 0
    foreach ($name in $Names) {
        $wanted = $desired.Contains($name)
        $target = if ($wanted) { $desired[$name].Value } else { $null }
        $line = Get-PlanLine -State (Get-TableValueState -Values $values -Name $name) -Name $name -Wanted $wanted -Target $target
        if ($line) {
            $lines += "$($line.Text)$(if ($wanted) { " ($($script:LevelLabels[$Level]))" })"
            if ($line.Verb -ne 'KEEP') { $changes++ }
        }
        if ($other.ContainsKey($name)) {
            $lines += "CLEAR  $name from the $(if ($Level -eq 'mandatory') { 'recommended' } else { 'locked' }) key"
            $changes++
        }
    }
    if ($changes -eq 0) { $lines += 'No write needed.' }
    return [pscustomobject]@{ Error = $null; Lines = $lines; Changes = $changes; Desired = $desired; Level = $Level }
}

function Get-StartupPlan {
    param($Tables, [string]$Level, $Overrides)
    try {
        $startup = Get-DesiredStartupOverride -Overrides $Overrides
        $path = Get-LevelPath $Level
        $otherPath = if ($Level -eq 'mandatory') { $script:RecommendedPath } else { $script:PolicyPath }
        $values = if ($Level -eq 'mandatory') { $Tables.Mandatory } else { $Tables.Recommended }
        $other = if ($Level -eq 'mandatory') { $Tables.Recommended } else { $Tables.Mandatory }
        $curStartup = Get-TableValueState -Values $values -Name 'RestoreOnStartup'
        $curUrls = @(Get-RegistryNumberedValues -Path (Join-Path $path 'RestoreOnStartupURLs'))
        $otherUrls = @(Get-RegistryNumberedValues -Path (Join-Path $otherPath 'RestoreOnStartupURLs'))
        $line = Get-PlanLine -State $curStartup -Name 'RestoreOnStartup' -Wanted $startup.Enabled -Target $startup.Code
        $lines = @()
        $changes = 0
        if ($line) {
            $lines += "$($line.Text)$(if ($startup.Enabled) { " ($($script:LevelLabels[$Level]))" })"
            if ($line.Verb -ne 'KEEP') { $changes++ }
        }
        if ($startup.Enabled) {
            if ($startup.Urls.Count -gt 0) {
                $lines += "REPLACE RestoreOnStartupURLs with $($startup.Urls.Count) URL(s): $($startup.Urls -join ', ')"
                if (($curUrls -join "`n") -ne ($startup.Urls -join "`n")) { $changes++ }
            } elseif ($curUrls.Count -gt 0) {
                $lines += 'CLEAR  RestoreOnStartupURLs'
                $changes++
            } else {
                $lines += 'No startup URL list needed.'
            }
        } else {
            if ($curUrls.Count -gt 0) {
                $lines += "CLEAR  RestoreOnStartupURLs ($($curUrls.Count) URL(s))"
                $changes++
            }
            if (-not $line -and $curUrls.Count -eq 0 -and -not $other.ContainsKey('RestoreOnStartup') -and $otherUrls.Count -eq 0) { $lines += 'No write needed.' }
        }
        if ($other.ContainsKey('RestoreOnStartup') -or $otherUrls.Count -gt 0) {
            $lines += "CLEAR  RestoreOnStartup from the $(if ($Level -eq 'mandatory') { 'recommended' } else { 'locked' }) key"
            $changes++
        }
        return [pscustomobject]@{ Error = $null; Lines = $lines; Changes = $changes; Desired = $startup; Level = $Level }
    } catch {
        return [pscustomobject]@{ Error = "$_"; Lines = @(); Changes = 0; Desired = $null; Level = $Level }
    }
}

# What Apply would do to each managed flag, against the Local State of the
# first channel that has one (the one Load current state reads).
function Get-FlagsPlan {
    param($Selection, [string[]]$Current)
    $plan = @()
    foreach ($f in $Selection.Flags) {
        $present = @($Current | Where-Object { (($_ -split '@')[0]) -eq $f.Name })
        $now = if ($present.Count -gt 0) { $present[0] } else { $null }
        if ($f.Checked) {
            if (-not $now) { $verb = 'ADD'; $text = "ADD    $($f.Entry)" }
            elseif ($now -eq $f.Entry) { $verb = 'KEEP'; $text = "KEEP   $($f.Entry)" }
            else { $verb = 'CHANGE'; $text = "CHANGE $($f.Name) : $now -> $($f.Entry)" }
        } elseif ($now) {
            $verb = 'CLEAR'; $text = "CLEAR  $now (back to Default)"
        } else { continue }
        $plan += [pscustomobject]@{ Name = $f.Name; Verb = $verb; Text = $text }
    }
    return $plan
}

# What Apply would do to Brave's own settings, read from the first profile
# (Get-PrefReadTarget). Desired and Stale come from core\Prefs.ps1.
function Get-PrefsPlan {
    param([object[]]$Desired, [object[]]$Fresh, [object[]]$Stale, [hashtable]$Current)
    $plan = @()
    foreach ($d in $Desired) {
        $now = $Current[$d.Key]
        $where = "$(if ($d.File -eq 'LocalState') { 'Local State: ' })$($d.Path -join '.')"
        # Written by an earlier Apply: whatever Brave holds now is the user's.
        if (@($Fresh | Where-Object { $_.Name -eq $d.Name -and $_.Key -eq $d.Key }).Count -eq 0) {
            $plan += [pscustomobject]@{ Name = $d.Name; Verb = 'KEEP'; Text = "KEEP   $where (set by an earlier Apply; Brave's current value $(if ($null -eq $now) { 'is its default' } else { $now }) stays; $($d.Name))" }
            continue
        }
        if (Test-PrefJsonEqual $now $d.Json) { $plan += [pscustomobject]@{ Name = $d.Name; Verb = 'KEEP'; Text = "KEEP   $where = $($d.Json)  ($($d.Name))" } }
        else { $plan += [pscustomobject]@{ Name = $d.Name; Verb = 'SET'; Text = "SET    $where = $($d.Json)  (currently $(if ($null -eq $now) { 'not set' } else { $now }); $($d.Name))" } }
    }
    foreach ($s in $Stale) {
        $now = $Current[$s.Key]
        $where = "$(if ($s.File -eq 'LocalState') { 'Local State: ' })$($s.Path -join '.')"
        if ($null -eq $now) { continue }
        if (Test-PrefJsonEqual $now $s.Json) { $plan += [pscustomobject]@{ Name = $s.Name; Verb = 'RESET'; Text = "RESET  $where (back to Brave's default; $($s.Name))" } }
        else { $plan += [pscustomobject]@{ Name = $s.Name; Verb = 'LEAVE'; Text = "LEAVE  $where = $now (changed in Brave since; $($s.Name))" } }
    }
    return $plan
}

# Brave keeps these settings signed in Secure Preferences, so the app never
# writes them: while Brave holds its own value, that value wins over a
# recommended policy. Only a lock overrides it.
$script:ProtectedOverridePrefs = [ordered]@{
    Search  = 'Profile|default_search_provider_data|template_url_data'
    Home    = 'Profile|homepage'
    Startup = 'Profile|session|restore_on_startup'
}

function Get-ProtectedPlan {
    param($Selection, $Target)
    $lock = [bool]$Selection.Lock
    if ($lock -or -not $Target) { return @() }
    $checks = @()
    foreach ($p in $Selection.Policies) {
        if (-not $p.Checked) { continue }
        $policy = $script:PolicyByName[$p.Name]
        if ((Get-PolicyLevel -Policy $policy -Lock $lock) -ne 'recommended') { continue }
        foreach ($pref in @($policy.Prefs | Where-Object { $_.Protected })) {
            $checks += [pscustomobject]@{ Name = $p.Name; Kind = 'Policy'; Key = $pref.Key; Json = (ConvertTo-PrefValueJson -Pref $pref -PolicyValue $p.Value); Contains = $null }
        }
    }
    $o = $Selection.Overrides
    try {
        $search = Get-DesiredSearchOverride -Overrides $o
        if ($search.Count -gt 0) { $checks += [pscustomobject]@{ Name = 'Search'; Kind = 'Override'; Key = $script:ProtectedOverridePrefs.Search; Json = $null; Contains = [string]$search['DefaultSearchProviderSearchURL'].Value } }
    } catch { Write-Verbose "Search override not checked: $_" }
    try {
        $homePage = Get-DesiredHomeOverride -Overrides $o
        if ($homePage.Count -gt 0) { $checks += [pscustomobject]@{ Name = 'Home'; Kind = 'Override'; Key = $script:ProtectedOverridePrefs.Home; Json = (ConvertTo-PrefJson ([string]$homePage['HomepageLocation'].Value)); Contains = $null } }
    } catch { Write-Verbose "Homepage override not checked: $_" }
    try {
        $startup = Get-DesiredStartupOverride -Overrides $o
        if ($startup.Enabled) { $checks += [pscustomobject]@{ Name = 'Startup'; Kind = 'Override'; Key = $script:ProtectedOverridePrefs.Startup; Json = [string]$startup.Code; Contains = $null } }
    } catch { Write-Verbose "Startup override not checked: $_" }
    if ($checks.Count -eq 0) { return @() }

    $current = Read-PrefKeys -Keys ([string[]]@($checks | ForEach-Object { $_.Key })) -Target $Target
    return @(foreach ($c in $checks) {
        $now = $current[$c.Key]
        if ($null -eq $now) { continue }
        $same = if ($c.Contains) { $now.Contains($c.Contains) } else { Test-PrefJsonEqual $now $c.Json }
        if (-not $same) { [pscustomobject]@{ Name = $c.Name; Kind = $c.Kind } }
    })
}

function Get-ApplyPlan {
    param($Selection)
    $overrides = $Selection.Overrides
    $lock = [bool]$Selection.Lock
    # One read of both policy keys for every value.
    $tables = Get-PolicyValueTables
    $prefTarget = Get-PrefReadTarget
    $previous = Read-AppliedRecord
    $desiredPrefs = @(Get-DesiredPrefs -Selection $Selection)
    $freshPrefs = @(Select-FreshPrefs -Desired $desiredPrefs -Previous $previous)
    $stalePrefs = @(Get-StalePrefs -Selection $Selection -Previous $previous -Desired $desiredPrefs)
    $prefKeys = [string[]]@(@($desiredPrefs) + @($stalePrefs) | ForEach-Object { $_.Key } | Select-Object -Unique)
    $prefCurrent = Read-PrefKeys -Keys $prefKeys -Target $prefTarget
    $prefsPlan = @(Get-PrefsPlan -Desired $desiredPrefs -Fresh $freshPrefs -Stale $stalePrefs -Current $prefCurrent)

    $counts = @{ ADD = 0; CHANGE = 0; MOVE = 0; CLEAR = 0; KEEP = 0 }
    $policies = @(foreach ($p in $Selection.Policies) {
        $level = Get-PolicyLevel -Policy $script:PolicyByName[$p.Name] -Lock $lock
        $line = Get-LevelPlanLine -Tables $tables -Name $p.Name -Wanted $p.Checked -Target $p.Value -Level $level
        if (-not $line -and $p.Checked -and $level -eq 'pref') {
            # No policy involved: the row is new or kept by its prefs alone.
            $changed = @($prefsPlan | Where-Object { $_.Name -eq $p.Name -and $_.Verb -eq 'SET' }).Count -gt 0
            $line = [pscustomobject]@{ Verb = $(if ($changed) { 'ADD' } else { 'KEEP' }); Text = "$(if ($changed) { 'ADD   ' } else { 'KEEP  ' }) $($p.Name) = $(Format-PolicyValueText $p.Value) (Brave setting)"; Current = $null; Level = $level; From = $null }
        }
        if (-not $line) { continue }
        $counts[$line.Verb]++
        [pscustomobject]@{ Name = $p.Name; Verb = $line.Verb; Text = $line.Text; Current = $line.Current; Target = $p.Value; Level = $level; From = $line.From }
    })
    $retired = @(foreach ($name in $script:RetiredPolicies.Keys) {
        if (-not ($tables.Mandatory.ContainsKey($name) -or $tables.Recommended.ContainsKey($name))) { continue }
        $entry = $script:RetiredPolicies[$name]
        [pscustomobject]@{ Name = $name; Reason = $entry.Reason; Text = "CLEAR  $name (retired: $($entry.Reason))" }
    })
    $legacyKeys = @($script:LegacyPolicyPaths | Where-Object { Test-Path $_ })

    $flagCurrent = @(Get-MachineFlagEntries)
    $flagChannels = @(Get-FlagChannels)
    $flagsBlocked = @($flagChannels | Where-Object { @(Get-ChannelProcesses $_).Count -gt 0 })

    $tasks = @(foreach ($t in $Selection.Tasks) {
        $task = Get-BraveTaskState -Name $t.Name
        if (-not $task) { $verb = 'MISSING'; $text = "MISSING $($t.Name) - skipped" }
        elseif ($t.Checked) {
            if ($task.State -eq 'Disabled') { $verb = 'KEEP'; $text = "KEEP    $($t.Name) disabled" }
            else { $verb = 'DISABLE'; $text = "DISABLE $($t.Name) (currently $($task.State))" }
        } else {
            if ($task.State -eq 'Disabled') { $verb = 'ENABLE'; $text = "ENABLE  $($t.Name)" }
            else { $verb = 'KEEP'; $text = "KEEP    $($t.Name) enabled/current state $($task.State)" }
        }
        [pscustomobject]@{ Name = $t.Name; Verb = $verb; Text = $text }
    })

    $services = @(foreach ($s in $Selection.Services) {
        $found = @(Get-BraveServices -Name $s.Name)
        $names = ($found | ForEach-Object { $_.Name }) -join ', '
        if ($found.Count -eq 0) { $verb = 'MISSING'; $text = "MISSING $($s.Name) - skipped" }
        elseif ($s.Checked) {
            if (Test-BraveServiceDisabled -Name $s.Name) { $verb = 'KEEP'; $text = "KEEP    $names disabled" }
            else { $verb = 'DISABLE'; $text = "DISABLE $names" }
        } else {
            if (@($found | Where-Object { $_.StartType -eq 'Disabled' }).Count -gt 0) { $verb = 'RESET'; $text = "RESET   $names startup type to Manual" }
            else { $verb = 'KEEP'; $text = "KEEP    $names" }
        }
        [pscustomobject]@{ Name = $s.Name; Verb = $verb; Text = $text }
    })

    $searchLevel = Get-OverrideLevel -Name 'DefaultSearchProviderEnabled' -Lock $lock
    return [pscustomobject]@{
        Path            = $script:PolicyPath
        RecommendedPath = $script:RecommendedPath
        Lock            = $lock
        Counts          = $counts
        Policies        = $policies
        Retired         = $retired
        LegacyKeys      = $legacyKeys
        Search          = (Get-OverridePlan -Tables $tables -Level $searchLevel -Overrides $overrides -Names $script:SearchOverrideValueNames `
                               -GetDesired { param($o) Get-DesiredSearchOverride -Overrides $o })
        Ntp             = (Get-OverridePlan -Tables $tables -Level (Get-OverrideLevel -Name 'NewTabPageLocation' -Lock $lock) -Overrides $overrides -Names @('NewTabPageLocation') `
                               -GetDesired { param($o) Get-DesiredNtpOverride -Overrides $o })
        Home            = (Get-OverridePlan -Tables $tables -Level $searchLevel -Overrides $overrides -Names $script:HomeOverrideValueNames `
                               -GetDesired { param($o) Get-DesiredHomeOverride -Overrides $o })
        Startup         = (Get-StartupPlan -Tables $tables -Level $searchLevel -Overrides $overrides)
        Prefs           = $prefsPlan
        PrefTarget      = $prefTarget
        Protected       = @(Get-ProtectedPlan -Selection $Selection -Target $prefTarget)
        Flags           = @(Get-FlagsPlan -Selection $Selection -Current $flagCurrent)
        FlagChannels    = $flagChannels
        FlagsBlocked    = $flagsBlocked
        Tasks           = $tasks
        Services        = $services
        HostsDomains    = @(Get-SelectionHostsDomains -Selection $Selection).Count
    }
}

# ---- The technical report ----------------------------------------------------------
function Format-ApplyPlanReport {
    param($Selection, $Plan)
    $report = New-Object System.Text.StringBuilder
    $modeKey = if ([string]::IsNullOrWhiteSpace($Selection.Profile)) { 'Custom' } else { $Selection.Profile }

    [void]$report.AppendLine('Brave Free Origin apply preview')
    [void]$report.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$report.AppendLine("Mode: $(Get-ModeLabel -Mode $modeKey -Base $Selection.BaseProfile -Count $Selection.ChangeCount -English)")
    [void]$report.AppendLine("Policy key (read by every Brave channel): $($Plan.Path)")
    [void]$report.AppendLine("Recommended key (changeable in Brave): $($Plan.RecommendedPath)")
    [void]$report.AppendLine("Lock settings in Brave: $([bool]$Plan.Lock)")
    [void]$report.AppendLine("Backup before apply: $([bool]$Selection.Backup)")
    [void]$report.AppendLine('')
    [void]$report.AppendLine('This is a dry run. Nothing has been written.')
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Policies ===')
    foreach ($p in $Plan.Policies) { [void]$report.AppendLine("  $($p.Text)") }
    foreach ($r in $Plan.Retired) { [void]$report.AppendLine("  $($r.Text)") }
    foreach ($k in $Plan.LegacyKeys) { [void]$report.AppendLine("  REMOVE old key $k (Brave never read it)") }
    $counts = $Plan.Counts
    [void]$report.AppendLine("  Summary: $($counts.ADD) add, $($counts.CHANGE) change, $($counts.MOVE) move, $($counts.CLEAR) clear, $($counts.KEEP) already correct, $(@($Plan.Retired).Count) retired to remove")
    [void]$report.AppendLine('')
    foreach ($section in @(@('Search override', $Plan.Search), @('New tab override', $Plan.Ntp), @('Homepage override', $Plan.Home), @('Startup override', $Plan.Startup))) {
        [void]$report.AppendLine("  -- $($section[0])")
        if ($section[1].Error) { [void]$report.AppendLine("     ERROR: $($section[1].Error)") }
        foreach ($line in $section[1].Lines) { [void]$report.AppendLine("     $line") }
        [void]$report.AppendLine('')
    }

    [void]$report.AppendLine("=== Brave settings (Preferences and Local State) ===")
    if (-not $Plan.PrefTarget) { [void]$report.AppendLine('  No Brave channel has a profile yet (Brave has not run). Its settings are skipped.') }
    else { [void]$report.AppendLine("  Written to every profile of: $($Plan.FlagChannels -join ', '). Read from $($Plan.PrefTarget.Channel), first profile of $($Plan.PrefTarget.Profiles).") }
    foreach ($line in $Plan.Prefs) { [void]$report.AppendLine("  $($line.Text)") }
    if (@($Plan.Prefs).Count -eq 0) { [void]$report.AppendLine('  No Brave settings to write.') }
    foreach ($c in $Plan.FlagsBlocked) { [void]$report.AppendLine("  SKIP   $c is running; its settings cannot be written until it is closed.") }
    foreach ($w in $Plan.Protected) { [void]$report.AppendLine("  NOTE   Brave holds its own value for $($w.Name); it wins over the recommendation until reset in Brave or locked.") }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Flags (Local State) ===')
    if (@($Plan.FlagChannels).Count -eq 0) { [void]$report.AppendLine('  No Brave channel has a Local State yet (Brave has not run). Flags are skipped.') }
    else { [void]$report.AppendLine("  Channels: $($Plan.FlagChannels -join ', ')") }
    foreach ($f in $Plan.Flags) { [void]$report.AppendLine("  $($f.Text)") }
    if (@($Plan.Flags).Count -eq 0) { [void]$report.AppendLine('  No flag changes.') }
    foreach ($c in $Plan.FlagsBlocked) { [void]$report.AppendLine("  SKIP   $c is running; its flags cannot be written until it is closed.") }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Scheduled tasks ===')
    foreach ($t in $Plan.Tasks) { [void]$report.AppendLine("  $($t.Text)") }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Services ===')
    foreach ($s in $Plan.Services) { [void]$report.AppendLine("  $($s.Text)") }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Hosts blocklist ===')
    [void]$report.AppendLine('Main Apply does not edit hosts. Use Preview hosts / Apply hosts blocks on the Hosts page.')
    [void]$report.AppendLine("Selected hosts domains right now: $($Plan.HostsDomains)")

    return $report.ToString()
}

function New-ApplyPlanReport {
    param($Selection)
    return Format-ApplyPlanReport -Selection $Selection -Plan (Get-ApplyPlan -Selection $Selection)
}

# Reads the registry, Brave's settings, the flags and the hosts file back and
# compares them with the selection. Each ticked row is looked for where its
# level puts it.
function New-VerifyReport {
    param($Selection)
    $report = New-Object System.Text.StringBuilder
    $lock = [bool]$Selection.Lock
    $tables = Get-PolicyValueTables
    $prefTarget = Get-PrefReadTarget
    $desiredPrefs = @(Get-DesiredPrefs -Selection $Selection)
    $prefCurrent = Read-PrefKeys -Keys ([string[]]@($desiredPrefs | ForEach-Object { $_.Key })) -Target $prefTarget

    [void]$report.AppendLine("=== Policies  ($script:PolicyPath, and $script:RecommendedPath) ===")
    [void]$report.AppendLine("  Lock settings in Brave: $lock")
    $matchCount = 0; $missingCount = 0; $mismatchCount = 0; $tickedCount = 0
    $missingList = @(); $mismatchList = @()
    foreach ($p in $Selection.Policies) {
        if (-not $p.Checked) { continue }
        $tickedCount++
        $level = Get-PolicyLevel -Policy $script:PolicyByName[$p.Name] -Lock $lock
        if ($level -eq 'pref') {
            $mine = @($desiredPrefs | Where-Object { $_.Name -eq $p.Name })
            $off = @($mine | Where-Object { -not (Test-PrefJsonEqual $prefCurrent[$_.Key] $_.Json) })
            if ($off.Count -eq 0) { $matchCount++ }
            else { $mismatchCount++; $mismatchList += "$($p.Name): Brave setting $(@($off | ForEach-Object { $_.Path -join '.' }) -join ', ') differs (changed in Brave, or Brave was running at Apply)" }
            continue
        }
        $table = if ($level -eq 'mandatory') { $tables.Mandatory } else { $tables.Recommended }
        $state = Get-TableValueState -Values $table -Name $p.Name
        if (-not $state.Exists) {
            $elsewhere = Get-LevelValueState -Tables $tables -Name $p.Name
            if ($elsewhere.Exists) { $mismatchCount++; $mismatchList += "$($p.Name): $($script:LevelLabels[$elsewhere.Level]), expected $($script:LevelLabels[$level])" }
            else { $missingCount++; $missingList += $p.Name }
        }
        elseif (Test-PolicyValueEqual $state.Value $p.Value) { $matchCount++ }
        else { $mismatchCount++; $mismatchList += "$($p.Name): registry=$(Format-PolicyValueText $state.Value), expected=$(Format-PolicyValueText $p.Value)" }
    }
    [void]$report.AppendLine("  Ticked in UI: $tickedCount")
    [void]$report.AppendLine("  Match: $matchCount")
    [void]$report.AppendLine("  Missing (not in registry): $missingCount")
    [void]$report.AppendLine("  Mismatch (wrong value or place): $mismatchCount")
    if ($missingList) {
        [void]$report.AppendLine('  -- missing:')
        foreach ($n in $missingList) { [void]$report.AppendLine("     - $n") }
    }
    if ($mismatchList) {
        [void]$report.AppendLine('  -- mismatch:')
        foreach ($n in $mismatchList) { [void]$report.AppendLine("     - $n") }
    }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Brave settings ===')
    if (-not $prefTarget) { [void]$report.AppendLine('  (no Brave profile found)') }
    else {
        $prefOff = @($desiredPrefs | Where-Object { -not (Test-PrefJsonEqual $prefCurrent[$_.Key] $_.Json) })
        [void]$report.AppendLine("  Read from $($prefTarget.Channel), first profile of $($prefTarget.Profiles).")
        [void]$report.AppendLine("  Written by the app and still in place: $(@($desiredPrefs).Count - $prefOff.Count) of $(@($desiredPrefs).Count)")
        foreach ($d in $prefOff) { [void]$report.AppendLine("     - $($d.Path -join '.') ($($d.Name)): now $(if ($null -eq $prefCurrent[$d.Key]) { 'not set' } else { $prefCurrent[$d.Key] }), set $($d.Json)") }
    }
    [void]$report.AppendLine('')

    $flagCurrent = @(Get-MachineFlagEntries)
    [void]$report.AppendLine('=== Flags ===')
    foreach ($f in $Selection.Flags) {
        if (-not $f.Checked) { continue }
        $status = if ($flagCurrent -contains $f.Entry) { 'set' } else { 'NOT SET' }
        [void]$report.AppendLine("  $($f.Entry): $status")
    }
    [void]$report.AppendLine('')

    $hostsCurrent = @(Get-HostsCurrentDomains)
    [void]$report.AppendLine('=== Hosts blocklist ===')
    [void]$report.AppendLine("  Currently blocked domains: $($hostsCurrent.Count)")
    foreach ($d in $hostsCurrent) { [void]$report.AppendLine("     - $d") }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Search & Startup overrides ===')
    $read = { param($Name) Get-LevelValueState -Tables $tables -Name $Name }
    $where = { param($State) " ($($script:LevelLabels[$State.Level]))" }
    $se = & $read 'DefaultSearchProviderEnabled'
    if ($se.Exists -and $se.Value -eq 1) {
        [void]$report.AppendLine("     Search engine: $((& $read 'DefaultSearchProviderName').Value) ($((& $read 'DefaultSearchProviderSearchURL').Value))$(& $where $se)")
    } else { [void]$report.AppendLine('     Search engine override: not set') }
    $ntp = & $read 'NewTabPageLocation'
    if ($ntp.Exists) { [void]$report.AppendLine("     New tab page: $($ntp.Value)$(& $where $ntp)") }
    else { [void]$report.AppendLine('     New tab page override: not set') }
    $homePage = & $read 'HomepageLocation'
    if ($homePage.Exists) { [void]$report.AppendLine("     Homepage: $($homePage.Value)$(& $where $homePage)") }
    else { [void]$report.AppendLine('     Homepage override: not set') }
    $rc = & $read 'RestoreOnStartup'
    if ($rc.Exists) {
        $urls = @(Get-RegistryNumberedValues -Path (Join-Path (Get-LevelPath $rc.Level) 'RestoreOnStartupURLs'))
        $extra = if ($urls.Count -gt 0) { " URLs: $($urls -join ', ')" } else { '' }
        [void]$report.AppendLine("     Startup: code $($rc.Value)$extra$(& $where $rc)")
    } else { [void]$report.AppendLine('     Startup override: not set') }
    return $report.ToString()
}
