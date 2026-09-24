# ============================================================================
#  Writing the selection to the machine, and the full restore.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Both run on the background runspace (src\ui\Jobs.ps1) and take a selection
# snapshot (see core\State.ps1), never the window, so the UI stays responsive
# while tasks and services are stopped and reconfigured.

# Unticking a task or service, and the full restore, both put it back to how
# Brave installs it. Errors are left to the caller, which knows what to log.
function Enable-BraveTask {
    param([string]$Name)
    $task = Get-BraveTaskState -Name $Name
    if ($task -and $task.State -eq 'Disabled') {
        Enable-ScheduledTask -TaskName $Name -ErrorAction Stop | Out-Null
        Write-BfoLog "ENABLED task $Name" 'OK'
    }
}

function Reset-BraveService {
    param([string]$Name, [string]$StartType)
    if ($StartType -eq 'Disabled') {
        Set-Service -Name $Name -StartupType Manual -ErrorAction Stop
        Write-BfoLog "RESET service $Name to Manual" 'OK'
    }
}

# Writes the selection to every target channel: policies first, then the
# search / new tab / startup overrides, then scheduled tasks and services.
# Hosts blocks and scriptlets are not touched; their own pages apply them.
# Returns the counts for the confirmation message.
function Invoke-Apply {
    param($Selection)

    if ($Selection.Backup) { [void](Export-Backup) }

    $applied = 0
    $cleared = 0
    foreach ($channel in $Selection.Channels) {
        $path = $script:Channels[$channel].Path
        Write-BfoLog "--- Applying to channel: $channel ($path) ---"
        foreach ($p in $Selection.Policies) {
            if ($p.Checked) {
                try {
                    Set-PolicyValue -Path $path -Name $p.Name -Type $p.Type -Value $p.Value
                    Write-BfoLog "[$channel] SET $($p.Name) = $($p.Value)" 'OK'
                    $applied++
                } catch {
                    Write-BfoLog "[$channel] FAIL $($p.Name): $_" 'ERR'
                }
            } else {
                if (Remove-PolicyValue -Path $path -Name $p.Name) {
                    Write-BfoLog "[$channel] CLEARED $($p.Name)" 'OK'
                    $cleared++
                }
            }
        }

        # Search/NTP/Startup overrides run LAST so they always win over any
        # NewTabPageLocation/HomepageLocation/RestoreOnStartup ticks above.
        # Each helper clears its own values first, so unticking + Apply truly
        # removes them, and creates the policy key only when it has a value to write.
        $overrides = $Selection.Overrides
        try { [void](Write-SearchEngineOverride -Path $path -Overrides $overrides) } catch { Write-BfoLog "[$channel] Search override: $_" 'ERR' }
        try { [void](Write-NtpOverride          -Path $path -Overrides $overrides) } catch { Write-BfoLog "[$channel] NTP override: $_" 'ERR' }
        try { [void](Write-StartupOverride      -Path $path -Overrides $overrides) } catch { Write-BfoLog "[$channel] Startup override: $_" 'ERR' }
    }

    foreach ($t in $Selection.Tasks) {
        try {
            if ($t.Checked) {
                Disable-ScheduledTask -TaskName $t.Name -ErrorAction Stop | Out-Null
                Write-BfoLog "DISABLED task $($t.Name)" 'OK'
            } else {
                Enable-BraveTask -Name $t.Name
            }
        } catch {
            Write-BfoLog "Task $($t.Name): $_" 'WARN'
        }
    }

    foreach ($s in $Selection.Services) {
        try {
            $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            if (-not $svc) {
                Write-BfoLog "Service $($s.Name) not present - skipped." 'INFO'
                continue
            }
            if ($s.Checked) {
                if ($svc.Status -eq 'Running') { Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue }
                Set-Service -Name $s.Name -StartupType Disabled -ErrorAction Stop
                Write-BfoLog "DISABLED service $($s.Name)" 'OK'
            } else {
                Reset-BraveService -Name $s.Name -StartType $svc.StartType
            }
        } catch {
            Write-BfoLog "Service $($s.Name): $_" 'WARN'
        }
    }

    Write-BfoLog "Done. Applied $applied policies, cleared $cleared. Restart Brave to take effect." 'DONE'

    return [pscustomobject]@{ Applied = $applied; Cleared = $cleared }
}

# Puts the machine back to stock for the given channels. The window clears its
# own selection afterwards.
function Invoke-FullRestore {
    param([string[]]$Channels, [bool]$Backup)

    if ($Backup) { [void](Export-Backup) }

    foreach ($channel in $Channels) {
        $path = $script:Channels[$channel].Path
        try {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                Write-BfoLog "Removed policy key for $channel ($path)" 'OK'
            } else {
                Write-BfoLog "$channel had no policy key - skipped." 'INFO'
            }
        } catch {
            Write-BfoLog "Full restore policy remove [$channel]: $_" 'ERR'
        }
    }

    $currentHosts = @(Get-HostsCurrentDomains)
    if ($currentHosts.Count -gt 0) {
        try { Clear-HostsBlock } catch { Write-BfoLog "Full restore hosts clear: $_" 'ERR' }
    } else {
        Write-BfoLog 'No Brave-Free-Origin hosts block present.' 'INFO'
    }

    foreach ($t in $script:ScheduledTasks) {
        try {
            Enable-BraveTask -Name $t.Name
        } catch {
            Write-BfoLog "Full restore task $($t.Name): $_" 'WARN'
        }
    }

    foreach ($s in $script:Services) {
        try {
            $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            if ($svc) { Reset-BraveService -Name $s.Name -StartType $svc.StartType }
        } catch {
            Write-BfoLog "Full restore service $($s.Name): $_" 'WARN'
        }
    }

    Write-BfoLog 'Full restore completed. Restart Brave to see stock behavior.' 'DONE'
}
