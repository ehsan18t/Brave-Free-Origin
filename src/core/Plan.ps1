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
    if ($Wanted) {
        if (-not $State.Exists)                { $verb = 'ADD';    $text = "ADD    $Name = $Target" }
        elseif ("$($State.Value)" -eq "$Target") { $verb = 'KEEP';   $text = "KEEP   $Name = $Target" }
        else                                   { $verb = 'CHANGE'; $text = "CHANGE $Name : $($State.Value) -> $Target" }
    } elseif ($State.Exists) {
        $verb = 'CLEAR'; $text = "CLEAR  $Name (currently $($State.Value))"
    }
    if (-not $verb) { return $null }
    return [pscustomobject]@{ Verb = $verb; Text = $text }
}

# ---- The plan -----------------------------------------------------------------
# Get-ApplyPlan reads the machine once and records, for every value, task and
# service, what Apply would do. Both views of the preview are built from it:
# Format-ApplyPlanReport (the technical report, below) and the plain-language
# summary in src\ui\Summary.ps1. One plan, so the two can never disagree.
#
#   Channels   one entry per target channel: Channel, Path, Counts,
#              Policies (Name, Verb, Text, Current, Target) and the three
#              overrides Search, Ntp, Startup (see Get-OverridePlan)
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

function Get-ApplyPlan {
    param($Selection)
    $overrides = $Selection.Overrides
    $channels = @(foreach ($channel in $Selection.Channels) {
        $path = $script:Channels[$channel].Path
        # One read of the policy key for every value this channel needs.
        $values = Get-RegistryValueTable -Path $path
        $counts = @{ ADD = 0; CHANGE = 0; CLEAR = 0; KEEP = 0 }
        $policies = @(foreach ($p in $Selection.Policies) {
            $state = Get-TableValueState -Values $values -Name $p.Name
            $line = Get-PlanLine -State $state -Name $p.Name -Wanted $p.Checked -Target $p.Value
            if (-not $line) { continue }
            $counts[$line.Verb]++
            [pscustomobject]@{ Name = $p.Name; Verb = $line.Verb; Text = $line.Text; Current = $state.Value; Target = $p.Value }
        })
        [pscustomobject]@{
            Channel  = $channel
            Path     = $path
            Counts   = $counts
            Policies = $policies
            Search   = (Get-OverridePlan -Values $values -Overrides $overrides -Names $script:SearchOverrideValueNames `
                            -GetDesired { param($o) Get-DesiredSearchOverride -Overrides $o })
            Ntp      = (Get-OverridePlan -Values $values -Overrides $overrides -Names @('NewTabPageLocation') `
                            -GetDesired { param($o) Get-DesiredNtpOverride -Overrides $o })
            Startup  = (Get-StartupPlan -Path $path -Values $values -Overrides $overrides)
        }
    })

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
        $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
        if (-not $svc) { $verb = 'MISSING'; $text = "MISSING $($s.Name) - skipped" }
        elseif ($s.Checked) {
            if ($svc.StartType -eq 'Disabled') { $verb = 'KEEP'; $text = "KEEP    $($s.Name) disabled" }
            else { $verb = 'DISABLE'; $text = "DISABLE $($s.Name) (currently $($svc.StartType), $($svc.Status))" }
        } else {
            if ($svc.StartType -eq 'Disabled') { $verb = 'RESET'; $text = "RESET   $($s.Name) startup type to Manual" }
            else { $verb = 'KEEP'; $text = "KEEP    $($s.Name) startup type $($svc.StartType)" }
        }
        [pscustomobject]@{ Name = $s.Name; Verb = $verb; Text = $text }
    })

    return [pscustomobject]@{
        Channels     = $channels
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
    [void]$report.AppendLine("Target channel(s): $($Selection.Channels -join ', ')")
    [void]$report.AppendLine("Backup before apply: $([bool]$Selection.Backup)")
    [void]$report.AppendLine('')
    [void]$report.AppendLine('This is a dry run. Nothing has been written.')
    [void]$report.AppendLine('')

    foreach ($channel in $Plan.Channels) {
        [void]$report.AppendLine("=== $($channel.Channel)  ($($channel.Path)) ===")
        foreach ($p in $channel.Policies) { [void]$report.AppendLine("  $($p.Text)") }
        $counts = $channel.Counts
        [void]$report.AppendLine("  Summary: $($counts.ADD) add, $($counts.CHANGE) change, $($counts.CLEAR) clear, $($counts.KEEP) already correct")
        [void]$report.AppendLine('')
        foreach ($section in @(@('Search override', $channel.Search), @('New tab override', $channel.Ntp), @('Startup override', $channel.Startup))) {
            [void]$report.AppendLine("  -- $($section[0])")
            if ($section[1].Error) { [void]$report.AppendLine("     ERROR: $($section[1].Error)") }
            foreach ($line in $section[1].Lines) { [void]$report.AppendLine("     $line") }
            [void]$report.AppendLine('')
        }
    }

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

# Reads the registry and the hosts file back and compares them with the
# selection.
function New-VerifyReport {
    param($Selection)
    $report = New-Object System.Text.StringBuilder
    foreach ($channel in $Selection.Channels) {
        $path = $script:Channels[$channel].Path
        [void]$report.AppendLine("=== $channel  ($path) ===")
        if (-not (Test-Path $path)) {
            [void]$report.AppendLine('  (no policy key exists - nothing applied)')
            [void]$report.AppendLine('')
            continue
        }
        $matchCount = 0; $missingCount = 0; $mismatchCount = 0; $tickedCount = 0
        $missingList = @(); $mismatchList = @()
        $values = Get-RegistryValueTable -Path $path
        foreach ($p in $Selection.Policies) {
            if (-not $p.Checked) { continue }
            $tickedCount++
            $state = Get-TableValueState -Values $values -Name $p.Name
            if (-not $state.Exists) { $missingCount++; $missingList += $p.Name }
            elseif ("$($state.Value)" -eq "$($p.Value)") { $matchCount++ }
            else { $mismatchCount++; $mismatchList += "$($p.Name): registry=$($state.Value), expected=$($p.Value)" }
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
        [void]$report.AppendLine('')
    }

    $hostsCurrent = @(Get-HostsCurrentDomains)
    [void]$report.AppendLine('=== Hosts blocklist ===')
    [void]$report.AppendLine("  Currently blocked domains: $($hostsCurrent.Count)")
    foreach ($d in $hostsCurrent) { [void]$report.AppendLine("     - $d") }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Search & Startup overrides ===')
    foreach ($channel in $Selection.Channels) {
        $path = $script:Channels[$channel].Path
        [void]$report.AppendLine("  [$channel]")
        if (-not (Test-Path $path)) { [void]$report.AppendLine('     (no policy key - nothing set)'); continue }
        $se = Get-RegistryValueState -Path $path -Name 'DefaultSearchProviderEnabled'
        if ($se.Exists -and $se.Value -eq 1) {
            $name = (Get-RegistryValueState -Path $path -Name 'DefaultSearchProviderName').Value
            $url  = (Get-RegistryValueState -Path $path -Name 'DefaultSearchProviderSearchURL').Value
            [void]$report.AppendLine("     Search engine forced: $name ($url)")
        } else { [void]$report.AppendLine('     Search engine override: not set') }
        $ntp = Get-RegistryValueState -Path $path -Name 'NewTabPageLocation'
        if ($ntp.Exists) { [void]$report.AppendLine("     New tab page forced: $($ntp.Value)") }
        else { [void]$report.AppendLine('     New tab page override: not set') }
        $rc = Get-RegistryValueState -Path $path -Name 'RestoreOnStartup'
        if ($rc.Exists) {
            $urls = @(Get-RegistryNumberedValues -Path (Join-Path $path 'RestoreOnStartupURLs'))
            $extra = if ($urls.Count -gt 0) { " URLs: $($urls -join ', ')" } else { '' }
            [void]$report.AppendLine("     Startup forced: code $($rc.Value)$extra")
        } else { [void]$report.AppendLine('     Startup override: not set') }
    }
    return $report.ToString()
}
