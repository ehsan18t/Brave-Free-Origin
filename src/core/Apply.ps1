# ============================================================================
#  Writing the selection to the machine, and the full restore.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Unticking a task or service, and the full restore, both put it back to how
# Brave installs it. Errors are left to the caller, which knows what to log.
function Enable-BraveTask {
    param([string]$Name)
    $task = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
    if ($task -and $task.State -eq 'Disabled') {
        Enable-ScheduledTask -TaskName $Name -ErrorAction Stop | Out-Null
        Write-Log "ENABLED task $Name" 'OK'
    }
}

function Reset-BraveService {
    param([string]$Name, [string]$StartType)
    if ($StartType -eq 'Disabled') {
        Set-Service -Name $Name -StartupType Manual -ErrorAction Stop
        Write-Log "RESET service $Name to Manual" 'OK'
    }
}

# Writes the current selection to every target channel: policies first, then
# the search / new tab / startup overrides, then scheduled tasks and services.
# Hosts blocks and scriptlets are not touched; their own tabs apply them.
# Returns the counts for the confirmation message.
function Invoke-Apply {
    param([bool]$Backup)

    if ($Backup) { [void](Export-Backup) }

    $applied = 0
    $cleared = 0
    foreach ($channel in $script:TargetChannels) {
        $path = $script:Channels[$channel].Path
        Write-Log "--- Applying to channel: $channel ($path) ---"
        foreach ($cb in $script:CheckBoxes) {
            $p = $cb.Tag.Policy
            if ($cb.Checked) {
                try {
                    Set-PolicyValue -Path $path -Name $p.Name -Type $p.Type -Value $p.ApplyValue
                    Write-Log "[$channel] SET $($p.Name) = $($p.ApplyValue)" 'OK'
                    $applied++
                } catch {
                    Write-Log "[$channel] FAIL $($p.Name): $_" 'ERR'
                }
            } else {
                if (Remove-PolicyValue -Path $path -Name $p.Name) {
                    Write-Log "[$channel] CLEARED $($p.Name)" 'OK'
                    $cleared++
                }
            }
        }

        # Search/NTP/Startup overrides run LAST so they always win over any
        # NewTabPageLocation/HomepageLocation/RestoreOnStartup ticks above.
        # Each helper clears its own values first, so unticking + Apply truly
        # removes them, and creates the policy key only when it has a value to write.
        try { [void](Apply-SearchEngineOverride -Path $path) } catch { Write-Log "[$channel] Search override: $_" 'ERR' }
        try { [void](Apply-NtpOverride          -Path $path) } catch { Write-Log "[$channel] NTP override: $_" 'ERR' }
        try { [void](Apply-StartupOverride      -Path $path) } catch { Write-Log "[$channel] Startup override: $_" 'ERR' }
    }

    foreach ($cb in $script:TaskCheckBoxes) {
        $t = $cb.Tag
        try {
            if ($cb.Checked) {
                Disable-ScheduledTask -TaskName $t.Name -ErrorAction Stop | Out-Null
                Write-Log "DISABLED task $($t.Name)" 'OK'
            } else {
                Enable-BraveTask -Name $t.Name
            }
        } catch {
            Write-Log "Task $($t.Name): $_" 'WARN'
        }
    }

    foreach ($cb in $script:ServiceCheckBoxes) {
        $s = $cb.Tag
        try {
            $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            if (-not $svc) {
                Write-Log "Service $($s.Name) not present - skipped." 'INFO'
                continue
            }
            if ($cb.Checked) {
                if ($svc.Status -eq 'Running') { Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue }
                Set-Service -Name $s.Name -StartupType Disabled -ErrorAction Stop
                Write-Log "DISABLED service $($s.Name)" 'OK'
            } else {
                Reset-BraveService -Name $s.Name -StartType $svc.StartType
            }
        } catch {
            Write-Log "Service $($s.Name): $_" 'WARN'
        }
    }

    Update-SelectionSummary
    Write-Log "Done. Applied $applied policies, cleared $cleared. Restart Brave to take effect." 'DONE'

    return [pscustomobject]@{ Applied = $applied; Cleared = $cleared }
}

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
            Enable-BraveTask -Name $t.Name
        } catch {
            Write-Log "Full restore task $($t.Name): $_" 'WARN'
        }
    }

    foreach ($s in $script:Services) {
        try {
            $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            if ($svc) { Reset-BraveService -Name $s.Name -StartType $svc.StartType }
        } catch {
            Write-Log "Full restore service $($s.Name): $_" 'WARN'
        }
    }

    Push-SuppressSelectionEvents
    try {
        $everyBox = @($script:CheckBoxes) + @($script:TaskCheckBoxes) + @($script:ServiceCheckBoxes) +
                    @($script:HostsCheckBoxes) + @($script:ChkSearchOverride, $script:ChkNtpOverride, $script:ChkStartupOverride)
        foreach ($cb in $everyBox) { $cb.Checked = $false }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = 'None'
    Update-OverrideControlStates
    Update-SelectionSummary
    Update-ConfigurationFilter
    Write-Log 'Full restore completed. Restart Brave to see stock behavior.' 'DONE'
}
