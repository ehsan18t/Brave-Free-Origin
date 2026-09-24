# ============================================================================
#  Preview report: what Apply would add, change or clear.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

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

# One override section. GetDesired is the matching Get-Desired*Override; if it
# throws (for example an empty custom URL) the section shows the error instead.
function Add-RegistryPlanLines {
    param(
        [System.Text.StringBuilder]$Report,
        [string]$Path,
        [scriptblock]$GetDesired,
        [string[]]$Names,
        [string]$Title
    )

    [void]$Report.AppendLine("  -- $Title")
    try { $desired = & $GetDesired }
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
    $report = New-Object System.Text.StringBuilder
    $modeKey = if ([string]::IsNullOrWhiteSpace($script:ActiveProfile)) { 'Custom' } else { $script:ActiveProfile }
    $modeLabel = Get-PresetNameEn $modeKey

    [void]$report.AppendLine('Brave Free Origin apply preview')
    [void]$report.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$report.AppendLine("Mode: $modeLabel")
    [void]$report.AppendLine("Target channel(s): $($script:TargetChannels -join ', ')")
    [void]$report.AppendLine("Backup before apply: $($chkBackup.Checked)")
    [void]$report.AppendLine('')
    [void]$report.AppendLine('This is a dry run. Nothing has been written.')
    [void]$report.AppendLine('')

    foreach ($channel in $script:TargetChannels) {
        $path = $script:Channels[$channel].Path
        [void]$report.AppendLine("=== $channel  ($path) ===")
        $counts = @{ ADD = 0; CHANGE = 0; CLEAR = 0; KEEP = 0 }
        foreach ($cb in $script:CheckBoxes) {
            $p = $cb.Tag.Policy
            $line = Get-PlanLine -State (Get-RegistryValueState -Path $path -Name $p.Name) -Name $p.Name -Wanted $cb.Checked -Target $p.ApplyValue
            if (-not $line) { continue }
            [void]$report.AppendLine("  $($line.Text)")
            $counts[$line.Verb]++
        }
        [void]$report.AppendLine("  Summary: $($counts.ADD) add, $($counts.CHANGE) change, $($counts.CLEAR) clear, $($counts.KEEP) already correct")
        [void]$report.AppendLine('')

        Add-RegistryPlanLines -Report $report -Path $path -GetDesired { Get-DesiredSearchOverride } -Names $script:SearchOverrideValueNames -Title 'Search override'
        [void]$report.AppendLine('')
        Add-RegistryPlanLines -Report $report -Path $path -GetDesired { Get-DesiredNtpOverride } -Names @('NewTabPageLocation') -Title 'New tab override'
        [void]$report.AppendLine('')

        [void]$report.AppendLine('  -- Startup override')
        try {
            $startup = Get-DesiredStartupOverride
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
    foreach ($cb in $script:TaskCheckBoxes) {
        $t = $cb.Tag
        $task = Get-ScheduledTask -TaskName $t.Name -ErrorAction SilentlyContinue
        if (-not $task) {
            [void]$report.AppendLine("  MISSING $($t.Name) - skipped")
        } elseif ($cb.Checked) {
            if ($task.State -eq 'Disabled') { [void]$report.AppendLine("  KEEP    $($t.Name) disabled") }
            else { [void]$report.AppendLine("  DISABLE $($t.Name) (currently $($task.State))") }
        } else {
            if ($task.State -eq 'Disabled') { [void]$report.AppendLine("  ENABLE  $($t.Name)") }
            else { [void]$report.AppendLine("  KEEP    $($t.Name) enabled/current state $($task.State)") }
        }
    }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Services ===')
    foreach ($cb in $script:ServiceCheckBoxes) {
        $s = $cb.Tag
        $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
        if (-not $svc) {
            [void]$report.AppendLine("  MISSING $($s.Name) - skipped")
        } elseif ($cb.Checked) {
            if ($svc.StartType -eq 'Disabled') { [void]$report.AppendLine("  KEEP    $($s.Name) disabled") }
            else { [void]$report.AppendLine("  DISABLE $($s.Name) (currently $($svc.StartType), $($svc.Status))") }
        } else {
            if ($svc.StartType -eq 'Disabled') { [void]$report.AppendLine("  RESET   $($s.Name) startup type to Manual") }
            else { [void]$report.AppendLine("  KEEP    $($s.Name) startup type $($svc.StartType)") }
        }
    }
    [void]$report.AppendLine('')

    [void]$report.AppendLine('=== Hosts blocklist ===')
    [void]$report.AppendLine('Main Apply does not edit hosts. Use Preview hosts / Apply hosts blocks inside the Hosts tab.')
    [void]$report.AppendLine("Selected hosts domains right now: $(@(Get-SelectedHostsDomains).Count)")

    return $report.ToString()
}
