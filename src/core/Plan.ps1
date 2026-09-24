# ============================================================================
#  Preview report: what Apply would add, change or clear.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

function Add-RegistryPlanLines {
    param(
        [System.Text.StringBuilder]$Report,
        [string]$Path,
        [System.Collections.IDictionary]$Desired,
        [string[]]$Names,
        [string]$Title
    )

    [void]$Report.AppendLine("  -- $Title")
    $changes = 0
    foreach ($name in $Names) {
        $state = Get-RegistryValueState -Path $Path -Name $name
        if ($Desired.Contains($name)) {
            $target = $Desired[$name].Value
            if (-not $state.Exists) {
                [void]$Report.AppendLine("     ADD    $name = $target")
                $changes++
            } elseif ("$($state.Value)" -eq "$target") {
                [void]$Report.AppendLine("     KEEP   $name = $target")
            } else {
                [void]$Report.AppendLine("     CHANGE $name : $($state.Value) -> $target")
                $changes++
            }
        } elseif ($state.Exists) {
            [void]$Report.AppendLine("     CLEAR  $name (currently $($state.Value))")
            $changes++
        }
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
        $adds = 0; $changes = 0; $clears = 0; $keeps = 0

        foreach ($cb in $script:CheckBoxes) {
            $p = $cb.Tag.Policy
            $state = Get-RegistryValueState -Path $path -Name $p.Name
            if ($cb.Checked) {
                if (-not $state.Exists) {
                    [void]$report.AppendLine("  ADD    $($p.Name) = $($p.ApplyValue)")
                    $adds++
                } elseif ("$($state.Value)" -eq "$($p.ApplyValue)") {
                    [void]$report.AppendLine("  KEEP   $($p.Name) = $($p.ApplyValue)")
                    $keeps++
                } else {
                    [void]$report.AppendLine("  CHANGE $($p.Name) : $($state.Value) -> $($p.ApplyValue)")
                    $changes++
                }
            } elseif ($state.Exists) {
                [void]$report.AppendLine("  CLEAR  $($p.Name) (currently $($state.Value))")
                $clears++
            }
        }
        [void]$report.AppendLine("  Summary: $adds add, $changes change, $clears clear, $keeps already correct")
        [void]$report.AppendLine('')

        try {
            $searchDesired = Get-DesiredSearchOverride
            Add-RegistryPlanLines -Report $report -Path $path -Desired $searchDesired -Names @(
                'DefaultSearchProviderEnabled',
                'DefaultSearchProviderName',
                'DefaultSearchProviderKeyword',
                'DefaultSearchProviderSearchURL',
                'DefaultSearchProviderSuggestURL'
            ) -Title 'Search override'
        } catch {
            [void]$report.AppendLine("  -- Search override")
            [void]$report.AppendLine("     ERROR: $_")
        }
        [void]$report.AppendLine('')

        try {
            $ntpDesired = Get-DesiredNtpOverride
            Add-RegistryPlanLines -Report $report -Path $path -Desired $ntpDesired -Names @('NewTabPageLocation') -Title 'New tab override'
        } catch {
            [void]$report.AppendLine("  -- New tab override")
            [void]$report.AppendLine("     ERROR: $_")
        }
        [void]$report.AppendLine('')

        try {
            $startup = Get-DesiredStartupOverride
            [void]$report.AppendLine('  -- Startup override')
            $curStartup = Get-RegistryValueState -Path $path -Name 'RestoreOnStartup'
            $urlPath = Join-Path $path 'RestoreOnStartupURLs'
            $curUrls = @(Get-RegistryNumberedValues -Path $urlPath)
            if ($startup.Enabled) {
                if (-not $curStartup.Exists) {
                    [void]$report.AppendLine("     ADD    RestoreOnStartup = $($startup.Code)")
                } elseif ("$($curStartup.Value)" -eq "$($startup.Code)") {
                    [void]$report.AppendLine("     KEEP   RestoreOnStartup = $($startup.Code)")
                } else {
                    [void]$report.AppendLine("     CHANGE RestoreOnStartup : $($curStartup.Value) -> $($startup.Code)")
                }
                if ($startup.Urls.Count -gt 0) {
                    [void]$report.AppendLine("     REPLACE RestoreOnStartupURLs with $($startup.Urls.Count) URL(s): $($startup.Urls -join ', ')")
                } elseif ($curUrls.Count -gt 0) {
                    [void]$report.AppendLine('     CLEAR  RestoreOnStartupURLs')
                } else {
                    [void]$report.AppendLine('     No startup URL list needed.')
                }
            } else {
                if ($curStartup.Exists) { [void]$report.AppendLine("     CLEAR  RestoreOnStartup (currently $($curStartup.Value))") }
                if ($curUrls.Count -gt 0) { [void]$report.AppendLine("     CLEAR  RestoreOnStartupURLs ($($curUrls.Count) URL(s))") }
                if (-not $curStartup.Exists -and $curUrls.Count -eq 0) { [void]$report.AppendLine('     No write needed.') }
            }
        } catch {
            [void]$report.AppendLine('  -- Startup override')
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
