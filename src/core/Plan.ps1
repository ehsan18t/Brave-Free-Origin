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

# One override section. GetDesired is the matching Get-Desired*Override, called
# with Overrides; if it throws (for example an empty custom URL) the section
# shows the error instead.
function Add-RegistryPlanLines {
    param(
        [System.Text.StringBuilder]$Report,
        [string]$Path,
        [scriptblock]$GetDesired,
        $Overrides,
        [string[]]$Names,
        [string]$Title
    )

    [void]$Report.AppendLine("  -- $Title")
    try { $desired = & $GetDesired $Overrides }
    catch { [void]$Report.AppendLine("     ERROR: $_"); return }

    $changes = 0
    foreach ($name in $Names) {
        $wanted = $desired.Contains($name)
        $target = if ($wanted) { $desired[$name].Value } else { $null }
        $line = Get-PlanLine -State (Get-RegistryValueState -Path $Path -Name $name) -Name $name -Wanted $wanted -Target $target
        if (-not $line) { continue }
        [void]$Report.AppendLine("     $($line.Text)")
        if ($line.Verb -ne 'KEEP') { $changes++ }
    }
    if ($changes -eq 0) { [void]$Report.AppendLine('     No write needed.') }
}

function New-ApplyPlanReport {
    param($Selection)
    $report = New-Object System.Text.StringBuilder
    $modeKey = if ([string]::IsNullOrWhiteSpace($Selection.Profile)) { 'Custom' } else { $Selection.Profile }
    $overrides = $Selection.Overrides

    [void]$report.AppendLine('Brave Free Origin apply preview')
    [void]$report.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$report.AppendLine("Mode: $(Get-PresetNameEn $modeKey)")
    [void]$report.AppendLine("Target channel(s): $($Selection.Channels -join ', ')")
    [void]$report.AppendLine("Backup before apply: $([bool]$Selection.Backup)")
    [void]$report.AppendLine('')
    [void]$report.AppendLine('This is a dry run. Nothing has been written.')
    [void]$report.AppendLine('')

    foreach ($channel in $Selection.Channels) {
        $path = $script:Channels[$channel].Path
        [void]$report.AppendLine("=== $channel  ($path) ===")
        $counts = @{ ADD = 0; CHANGE = 0; CLEAR = 0; KEEP = 0 }
        foreach ($p in $Selection.Policies) {
            $line = Get-PlanLine -State (Get-RegistryValueState -Path $path -Name $p.Name) -Name $p.Name -Wanted $p.Checked -Target $p.Value
            if (-not $line) { continue }
            [void]$report.AppendLine("  $($line.Text)")
            $counts[$line.Verb]++
        }
        [void]$report.AppendLine("  Summary: $($counts.ADD) add, $($counts.CHANGE) change, $($counts.CLEAR) clear, $($counts.KEEP) already correct")
        [void]$report.AppendLine('')

        Add-RegistryPlanLines -Report $report -Path $path -Overrides $overrides -Title 'Search override' `
            -GetDesired { param($o) Get-DesiredSearchOverride -Overrides $o } -Names $script:SearchOverrideValueNames
        [void]$report.AppendLine('')
        Add-RegistryPlanLines -Report $report -Path $path -Overrides $overrides -Title 'New tab override' `
            -GetDesired { param($o) Get-DesiredNtpOverride -Overrides $o } -Names @('NewTabPageLocation')
        [void]$report.AppendLine('')

        [void]$report.AppendLine('  -- Startup override')
        try {
            $startup = Get-DesiredStartupOverride -Overrides $overrides
            $curStartup = Get-RegistryValueState -Path $path -Name 'RestoreOnStartup'
            $curUrls = @(Get-RegistryNumberedValues -Path (Join-Path $path 'RestoreOnStartupURLs'))
            $line = Get-PlanLine -State $curStartup -Name 'RestoreOnStartup' -Wanted $startup.Enabled -Target $startup.Code
            if ($line) { [void]$report.AppendLine("     $($line.Text)") }
            if ($startup.Enabled) {
                if ($startup.Urls.Count -gt 0) {
                    [void]$report.AppendLine("     REPLACE RestoreOnStartupURLs with $($startup.Urls.Count) URL(s): $($startup.Urls -join ', ')")
                } elseif ($curUrls.Count -gt 0) {
                    [void]$report.AppendLine('     CLEAR  RestoreOnStartupURLs')
                } else {
                    [void]$report.AppendLine('     No startup URL list needed.')
                }
            } else {
                if ($curUrls.Count -gt 0) { [void]$report.AppendLine("     CLEAR  RestoreOnStartupURLs ($($curUrls.Count) URL(s))") }
                if (-not $line -and $curUrls.Count -eq 0) { [void]$report.AppendLine('     No write needed.') }
            }
        } catch {
            [void]$report.AppendLine("     ERROR: $_")
        }
        [void]$report.AppendLine('')
    }

    [void]$report.AppendLine('=== Scheduled tasks ===')
    foreach ($t in $Selection.Tasks) {
        $task = Get-ScheduledTask -TaskName $t.Name -ErrorAction SilentlyContinue
        if (-not $task) {
            [void]$report.AppendLine("  MISSING $($t.Name) - skipped")
        } elseif ($t.Checked) {
            if ($task.State -eq 'Disabled') { [void]$report.AppendLine("  KEEP    $($t.Name) disabled") }
            else { [void]$report.AppendLine("  DISABLE $($t.Name) (currently $($task.State))") }
        } else {
            if ($task.State -eq 'Disabled') { [void]$report.AppendLine("  ENABLE  $($t.Name)") }
            else { [void]$report.AppendLine("  KEEP    $($t.Name) enabled/current state $($task.State)") }
        }
    }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Services ===')
    foreach ($s in $Selection.Services) {
        $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
        if (-not $svc) {
            [void]$report.AppendLine("  MISSING $($s.Name) - skipped")
        } elseif ($s.Checked) {
            if ($svc.StartType -eq 'Disabled') { [void]$report.AppendLine("  KEEP    $($s.Name) disabled") }
            else { [void]$report.AppendLine("  DISABLE $($s.Name) (currently $($svc.StartType), $($svc.Status))") }
        } else {
            if ($svc.StartType -eq 'Disabled') { [void]$report.AppendLine("  RESET   $($s.Name) startup type to Manual") }
            else { [void]$report.AppendLine("  KEEP    $($s.Name) startup type $($svc.StartType)") }
        }
    }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Hosts blocklist ===')
    [void]$report.AppendLine('Main Apply does not edit hosts. Use Preview hosts / Apply hosts blocks on the Hosts page.')
    [void]$report.AppendLine("Selected hosts domains right now: $(@(Get-SelectionHostsDomains -Selection $Selection).Count)")

    return $report.ToString()
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
        foreach ($p in $Selection.Policies) {
            if (-not $p.Checked) { continue }
            $tickedCount++
            $state = Get-RegistryValueState -Path $path -Name $p.Name
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
