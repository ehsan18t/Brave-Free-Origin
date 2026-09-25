# ============================================================================
#  Preview and verify reports: what Apply would change, and whether it landed.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Both reports take a selection snapshot (see core\State.ps1) rather than
# reading the window, so they can run on the background runspace. Report text
# stays English on purpose: it gets pasted into bug reports.

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

# ---- The plan -----------------------------------------------------------------
# Get-ApplyPlan reads the machine once and records, for every value, flag,
# task and service, what Apply would do. Both views of the preview are built
# from it: Format-ApplyPlanReport (the technical report, below) and the
# plain-language summary in src\ui\Summary.ps1. One plan, so the two can never
# disagree.
#
#   Path       the policy key
#   Counts     ADD / CHANGE / CLEAR / KEEP totals for the policies
#   Policies   Name, Verb, Text, Current, Target
#   Retired    Name, Reason, Text: retired policies present, which Apply removes
#   LegacyKeys old per-channel keys present, which Apply removes
#   Search, Ntp, Home, Startup   the overrides (see Get-OverridePlan)
#   Flags      Name, Verb (ADD, CHANGE, CLEAR, KEEP), Text
#   FlagChannels, FlagsBlocked   channels flags go to, and the running ones
#   Tasks      Name, Verb (MISSING, KEEP, DISABLE, ENABLE), Text
#   Services   Name, Verb (MISSING, KEEP, DISABLE, RESET), Text
#   HostsDomains  how many hosts domains the selection holds

# One override section. GetDesired is the matching Get-Desired*Override, called
# with Overrides; if it throws (for example an empty custom URL) the section
# carries the error instead. Changes counts the values Apply would really
# write or remove; Lines are the report lines, Desired what would be written.
function Get-OverridePlan {
    param([hashtable]$Values, [scriptblock]$GetDesired, $Overrides, [string[]]$Names)
    try { $desired = & $GetDesired $Overrides }
    catch { return [pscustomobject]@{ Error = "$_"; Lines = @(); Changes = 0; Desired = $null } }

    $lines = @()
    $changes = 0
    foreach ($name in $Names) {
        $wanted = $desired.Contains($name)
        $target = if ($wanted) { $desired[$name].Value } else { $null }
        $line = Get-PlanLine -State (Get-TableValueState -Values $Values -Name $name) -Name $name -Wanted $wanted -Target $target
        if (-not $line) { continue }
        $lines += $line.Text
        if ($line.Verb -ne 'KEEP') { $changes++ }
    }
    if ($changes -eq 0) { $lines += 'No write needed.' }
    return [pscustomobject]@{ Error = $null; Lines = $lines; Changes = $changes; Desired = $desired }
}

function Get-StartupPlan {
    param([string]$Path, [hashtable]$Values, $Overrides)
    try {
        $startup = Get-DesiredStartupOverride -Overrides $Overrides
        $curStartup = Get-TableValueState -Values $Values -Name 'RestoreOnStartup'
        $curUrls = @(Get-RegistryNumberedValues -Path (Join-Path $Path 'RestoreOnStartupURLs'))
        $line = Get-PlanLine -State $curStartup -Name 'RestoreOnStartup' -Wanted $startup.Enabled -Target $startup.Code
        $lines = @()
        $changes = 0
        if ($line) {
            $lines += $line.Text
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
            if (-not $line -and $curUrls.Count -eq 0) { $lines += 'No write needed.' }
        }
        return [pscustomobject]@{ Error = $null; Lines = $lines; Changes = $changes; Desired = $startup }
    } catch {
        return [pscustomobject]@{ Error = "$_"; Lines = @(); Changes = 0; Desired = $null }
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

function Get-ApplyPlan {
    param($Selection)
    $overrides = $Selection.Overrides
    $path = $script:PolicyPath
    # One read of the policy key for every value.
    $values = Get-PolicyValueTable -Path $path
    $counts = @{ ADD = 0; CHANGE = 0; CLEAR = 0; KEEP = 0 }
    $policies = @(foreach ($p in $Selection.Policies) {
        $state = Get-TableValueState -Values $values -Name $p.Name
        $line = Get-PlanLine -State $state -Name $p.Name -Wanted $p.Checked -Target $p.Value
        if (-not $line) { continue }
        $counts[$line.Verb]++
        [pscustomobject]@{ Name = $p.Name; Verb = $line.Verb; Text = $line.Text; Current = $state.Value; Target = $p.Value }
    })
    $retired = @(foreach ($name in $script:RetiredPolicies.Keys) {
        if (-not $values.ContainsKey($name)) { continue }
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

    return [pscustomobject]@{
        Path         = $path
        Counts       = $counts
        Policies     = $policies
        Retired      = $retired
        LegacyKeys   = $legacyKeys
        Search       = (Get-OverridePlan -Values $values -Overrides $overrides -Names $script:SearchOverrideValueNames `
                            -GetDesired { param($o) Get-DesiredSearchOverride -Overrides $o })
        Ntp          = (Get-OverridePlan -Values $values -Overrides $overrides -Names @('NewTabPageLocation') `
                            -GetDesired { param($o) Get-DesiredNtpOverride -Overrides $o })
        Home         = (Get-OverridePlan -Values $values -Overrides $overrides -Names $script:HomeOverrideValueNames `
                            -GetDesired { param($o) Get-DesiredHomeOverride -Overrides $o })
        Startup      = (Get-StartupPlan -Path $path -Values $values -Overrides $overrides)
        Flags        = @(Get-FlagsPlan -Selection $Selection -Current $flagCurrent)
        FlagChannels = $flagChannels
        FlagsBlocked = $flagsBlocked
        Tasks        = $tasks
        Services     = $services
        HostsDomains = @(Get-SelectionHostsDomains -Selection $Selection).Count
    }
}

# ---- The technical report ----------------------------------------------------------
function Format-ApplyPlanReport {
    param($Selection, $Plan)
    $report = New-Object System.Text.StringBuilder
    $modeKey = if ([string]::IsNullOrWhiteSpace($Selection.Profile)) { 'Custom' } else { $Selection.Profile }

    [void]$report.AppendLine('Brave Free Origin apply preview')
    [void]$report.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$report.AppendLine("Mode: $(Get-PresetNameEn $modeKey)")
    [void]$report.AppendLine("Policy key (read by every Brave channel): $($Plan.Path)")
    [void]$report.AppendLine("Backup before apply: $([bool]$Selection.Backup)")
    [void]$report.AppendLine('')
    [void]$report.AppendLine('This is a dry run. Nothing has been written.')
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Policies ===')
    foreach ($p in $Plan.Policies) { [void]$report.AppendLine("  $($p.Text)") }
    foreach ($r in $Plan.Retired) { [void]$report.AppendLine("  $($r.Text)") }
    foreach ($k in $Plan.LegacyKeys) { [void]$report.AppendLine("  REMOVE old key $k (Brave never read it)") }
    $counts = $Plan.Counts
    [void]$report.AppendLine("  Summary: $($counts.ADD) add, $($counts.CHANGE) change, $($counts.CLEAR) clear, $($counts.KEEP) already correct, $(@($Plan.Retired).Count) retired to remove")
    [void]$report.AppendLine('')
    foreach ($section in @(@('Search override', $Plan.Search), @('New tab override', $Plan.Ntp), @('Homepage override', $Plan.Home), @('Startup override', $Plan.Startup))) {
        [void]$report.AppendLine("  -- $($section[0])")
        if ($section[1].Error) { [void]$report.AppendLine("     ERROR: $($section[1].Error)") }
        foreach ($line in $section[1].Lines) { [void]$report.AppendLine("     $line") }
        [void]$report.AppendLine('')
    }

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

# Reads the registry, the flags and the hosts file back and compares them with
# the selection.
function New-VerifyReport {
    param($Selection)
    $report = New-Object System.Text.StringBuilder
    $path = $script:PolicyPath
    [void]$report.AppendLine("=== Policies  ($path) ===")
    if (-not (Test-Path $path)) {
        [void]$report.AppendLine('  (no policy key exists - nothing applied)')
    } else {
        $matchCount = 0; $missingCount = 0; $mismatchCount = 0; $tickedCount = 0
        $missingList = @(); $mismatchList = @()
        $values = Get-PolicyValueTable -Path $path
        foreach ($p in $Selection.Policies) {
            if (-not $p.Checked) { continue }
            $tickedCount++
            $state = Get-TableValueState -Values $values -Name $p.Name
            if (-not $state.Exists) { $missingCount++; $missingList += $p.Name }
            elseif (Test-PolicyValueEqual $state.Value $p.Value) { $matchCount++ }
            else { $mismatchCount++; $mismatchList += "$($p.Name): registry=$(Format-PolicyValueText $state.Value), expected=$(Format-PolicyValueText $p.Value)" }
        }
        [void]$report.AppendLine("  Ticked in UI: $tickedCount")
        [void]$report.AppendLine("  Match in registry: $matchCount")
        [void]$report.AppendLine("  Missing (not in registry): $missingCount")
        [void]$report.AppendLine("  Mismatch (wrong value): $mismatchCount")
        if ($missingList) {
            [void]$report.AppendLine('  -- missing:')
            foreach ($n in $missingList) { [void]$report.AppendLine("     - $n") }
        }
        if ($mismatchList) {
            [void]$report.AppendLine('  -- mismatch:')
            foreach ($n in $mismatchList) { [void]$report.AppendLine("     - $n") }
        }
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
    if (-not (Test-Path $path)) { [void]$report.AppendLine('     (no policy key - nothing set)'); return $report.ToString() }
    $se = Get-RegistryValueState -Path $path -Name 'DefaultSearchProviderEnabled'
    if ($se.Exists -and $se.Value -eq 1) {
        $name = (Get-RegistryValueState -Path $path -Name 'DefaultSearchProviderName').Value
        $url  = (Get-RegistryValueState -Path $path -Name 'DefaultSearchProviderSearchURL').Value
        [void]$report.AppendLine("     Search engine forced: $name ($url)")
    } else { [void]$report.AppendLine('     Search engine override: not set') }
    $ntp = Get-RegistryValueState -Path $path -Name 'NewTabPageLocation'
    if ($ntp.Exists) { [void]$report.AppendLine("     New tab page forced: $($ntp.Value)") }
    else { [void]$report.AppendLine('     New tab page override: not set') }
    $homePage = Get-RegistryValueState -Path $path -Name 'HomepageLocation'
    if ($homePage.Exists) { [void]$report.AppendLine("     Homepage forced: $($homePage.Value)") }
    else { [void]$report.AppendLine('     Homepage override: not set') }
    $rc = Get-RegistryValueState -Path $path -Name 'RestoreOnStartup'
    if ($rc.Exists) {
        $urls = @(Get-RegistryNumberedValues -Path (Join-Path $path 'RestoreOnStartupURLs'))
        $extra = if ($urls.Count -gt 0) { " URLs: $($urls -join ', ')" } else { '' }
        [void]$report.AppendLine("     Startup forced: code $($rc.Value)$extra")
    } else { [void]$report.AppendLine('     Startup override: not set') }
    return $report.ToString()
}
