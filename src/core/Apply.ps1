# ============================================================================
#  Writing the selection to the machine, and the full restore.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

function Invoke-FullRestore {
    param([bool]$Backup)

    if ($Backup) { [void](Export-Backup) }

    foreach ($channel in $script:TargetChannels) {
        $path = $script:Channels[$channel].Path
        try {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                Write-Log "Removed policy key for $channel ($path)" 'OK'
            } else {
                Write-Log "$channel had no policy key - skipped." 'INFO'
            }
        } catch {
            Write-Log "Full restore policy remove [$channel]: $_" 'ERR'
        }
    }

    $currentHosts = @(Get-HostsCurrentDomains)
    if ($currentHosts.Count -gt 0) {
        try { Clear-HostsBlock } catch { Write-Log "Full restore hosts clear: $_" 'ERR' }
    } else {
        Write-Log 'No Brave-Free-Origin hosts block present.' 'INFO'
    }

    foreach ($t in $script:ScheduledTasks) {
        try {
            $task = Get-ScheduledTask -TaskName $t.Name -ErrorAction SilentlyContinue
            if ($task -and $task.State -eq 'Disabled') {
                Enable-ScheduledTask -TaskName $t.Name -ErrorAction Stop | Out-Null
                Write-Log "ENABLED task $($t.Name)" 'OK'
            }
        } catch {
            Write-Log "Full restore task $($t.Name): $_" 'WARN'
        }
    }

    foreach ($s in $script:Services) {
        try {
            $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            if ($svc -and $svc.StartType -eq 'Disabled') {
                Set-Service -Name $s.Name -StartupType Manual -ErrorAction Stop
                Write-Log "RESET service $($s.Name) to Manual" 'OK'
            }
        } catch {
            Write-Log "Full restore service $($s.Name): $_" 'WARN'
        }
    }

    Push-SuppressSelectionEvents
    try {
        foreach ($cb in $script:CheckBoxes)        { $cb.Checked = $false }
        foreach ($cb in $script:TaskCheckBoxes)    { $cb.Checked = $false }
        foreach ($cb in $script:ServiceCheckBoxes) { $cb.Checked = $false }
        foreach ($cb in $script:HostsCheckBoxes)   { $cb.Checked = $false }
        if ($script:ChkSearchOverride)  { $script:ChkSearchOverride.Checked = $false }
        if ($script:ChkNtpOverride)     { $script:ChkNtpOverride.Checked = $false }
        if ($script:ChkStartupOverride) { $script:ChkStartupOverride.Checked = $false }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = 'None'
    Update-OverrideControlStates
    Update-SelectionSummary
    Update-ConfigurationFilter
    Write-Log 'Full restore completed. Restart Brave to see stock behavior.' 'DONE'
}
