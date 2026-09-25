# ============================================================================
#  Writing the selection to the machine, and the full restore.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Both run on the background runspace (src\ui\Jobs.ps1) and take a selection
# snapshot (see core\State.ps1), never the window, so the UI stays responsive
# while tasks and services are stopped and reconfigured.

# Tasks are acted on under their real names, which carry the {GUID} Brave's
# installer adds (see Get-BraveTaskState), in the root folder. Unticking a
# task or service, and the full restore, both put it back to how Brave
# installs it. Errors are left to the caller, which knows what to log.
function Disable-BraveTask {
    param([string]$Name)
    $task = Get-BraveTaskState -Name $Name
    if (-not $task) {
        Write-BfoLog "Task $Name not present - skipped." 'INFO'
        return
    }
    foreach ($match in $task.Tasks) {
        Disable-ScheduledTask -TaskPath '\' -TaskName $match.Name -ErrorAction Stop | Out-Null
        Write-BfoLog "DISABLED task $($match.Name)" 'OK'
    }
}

function Enable-BraveTask {
    param([string]$Name)
    $task = Get-BraveTaskState -Name $Name
    if (-not $task) { return }
    foreach ($match in $task.Tasks) {
        if ($match.State -ne 'Disabled') { continue }
        Enable-ScheduledTask -TaskPath '\' -TaskName $match.Name -ErrorAction Stop | Out-Null
        Write-BfoLog "ENABLED task $($match.Name)" 'OK'
    }
}

# Stops and disables every Windows service a row matches.
function Disable-BraveService {
    param([string]$Name)
    $services = @(Get-BraveServices -Name $Name)
    if ($services.Count -eq 0) {
        Write-BfoLog "Service $Name not present - skipped." 'INFO'
        return
    }
    foreach ($svc in $services) {
        if ($svc.Status -eq 'Running') { Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue }
        Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction Stop
        Write-BfoLog "DISABLED service $($svc.Name)" 'OK'
    }
}

# Puts every disabled service a row matches back to Manual.
function Reset-BraveService {
    param([string]$Name)
    foreach ($svc in @(Get-BraveServices -Name $Name)) {
        if ($svc.StartType -ne 'Disabled') { continue }
        Set-Service -Name $svc.Name -StartupType Manual -ErrorAction Stop
        Write-BfoLog "RESET service $($svc.Name) to Manual" 'OK'
    }
}

# Policy keys that earlier versions wrote for Beta, Nightly and Dev. Brave
# never read them, so they are removed rather than left to confuse.
function Remove-LegacyPolicyKeys {
    foreach ($key in $script:LegacyPolicyPaths) {
        if (-not (Test-Path $key)) { continue }
        try {
            Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
            Write-BfoLog "Removed old policy key $key (Brave never read it)" 'OK'
        } catch {
            Write-BfoLog "Could not remove old policy key ${key}: $_" 'WARN'
        }
    }
}

# Writes the selection: policies first, then the search / new tab / homepage
# / startup overrides, then flags, scheduled tasks and services. Hosts blocks
# and scriptlets are not touched; their own pages apply them. WriteFlags is
# $false when the user chose to skip flags because Brave is running.
# Returns the counts for the confirmation message and saves the record the
# drift check compares against.
function Invoke-Apply {
    param($Selection, [bool]$WriteFlags = $true)

    if ($Selection.Backup) { [void](Export-Backup) }

    $path = $script:PolicyPath
    $applied = 0
    $cleared = 0
    Write-BfoLog "--- Applying to $path ---"
    foreach ($p in $Selection.Policies) {
        if ($p.Checked) {
            try {
                Set-Policy -Path $path -Name $p.Name -Type $p.Type -Value $p.Value
                Write-BfoLog "SET $($p.Name) = $(Format-PolicyValueText $p.Value)" 'OK'
                $applied++
            } catch {
                Write-BfoLog "FAIL $($p.Name): $_" 'ERR'
            }
        } else {
            try {
                if (Remove-Policy -Path $path -Name $p.Name -Type $p.Type) {
                    Write-BfoLog "CLEARED $($p.Name)" 'OK'
                    $cleared++
                }
            } catch {
                Write-BfoLog "FAIL clearing $($p.Name): $_" 'ERR'
            }
        }
    }
    foreach ($name in $script:RetiredPolicies.Keys) {
        if (Remove-PolicyValue -Path $path -Name $name) {
            Write-BfoLog "CLEARED retired policy $name ($($script:RetiredPolicies[$name].Reason))" 'OK'
            $cleared++
        }
    }
    Remove-LegacyPolicyKeys

    # Each override helper clears its own values first, so unticking + Apply
    # truly removes them, and creates the policy key only when it has a value
    # to write.
    $overrides = $Selection.Overrides
    try { [void](Write-SearchEngineOverride -Path $path -Overrides $overrides) } catch { Write-BfoLog "Search override: $_" 'ERR' }
    try { [void](Write-NtpOverride          -Path $path -Overrides $overrides) } catch { Write-BfoLog "NTP override: $_" 'ERR' }
    try { [void](Write-HomeOverride         -Path $path -Overrides $overrides) } catch { Write-BfoLog "Homepage override: $_" 'ERR' }
    try { [void](Write-StartupOverride      -Path $path -Overrides $overrides) } catch { Write-BfoLog "Startup override: $_" 'ERR' }

    $flagResults = @()
    if ($WriteFlags) {
        $flagResults = @(Invoke-FlagsApply -Flags $Selection.Flags)
    } else {
        Write-BfoLog 'Flags skipped: Brave is running.' 'WARN'
        $flagResults = @(Get-FlagChannels | ForEach-Object { [pscustomobject]@{ Channel = $_; Status = 'running' } })
    }

    foreach ($t in $Selection.Tasks) {
        try {
            if ($t.Checked) { Disable-BraveTask -Name $t.Name }
            else { Enable-BraveTask -Name $t.Name }
        } catch {
            Write-BfoLog "Task $($t.Name): $_" 'WARN'
        }
    }

    foreach ($s in $Selection.Services) {
        try {
            if ($s.Checked) { Disable-BraveService -Name $s.Name }
            else { Reset-BraveService -Name $s.Name }
        } catch {
            Write-BfoLog "Service $($s.Name): $_" 'WARN'
        }
    }

    try {
        Save-AppliedRecord (New-AppliedRecord -Selection $Selection -Previous (Read-AppliedRecord) -FlagResults $flagResults -BraveVersion (Get-BraveVersion))
    } catch {
        Write-BfoLog "Could not save the record of this apply: $_" 'WARN'
    }

    Write-BfoLog "Done. Applied $applied policies, cleared $cleared. Restart Brave to take effect." 'DONE'

    return [pscustomobject]@{
        Applied      = $applied
        Cleared      = $cleared
        FlagsSkipped = @($flagResults | Where-Object { $_.Status -eq 'running' -or $_.Status -eq 'failed' } | ForEach-Object { $_.Channel })
    }
}

# Puts the machine back to stock: removes the policy key and the old
# per-channel keys, the hosts block and the flags the app manages, and turns
# Brave's update tasks and services back on. The window clears its own
# selection afterwards.
function Invoke-FullRestore {
    param([bool]$Backup)

    if ($Backup) { [void](Export-Backup) }

    $path = $script:PolicyPath
    try {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-BfoLog "Removed policy key $path" 'OK'
        } else {
            Write-BfoLog 'No policy key - skipped.' 'INFO'
        }
    } catch {
        Write-BfoLog "Full restore policy remove: $_" 'ERR'
    }
    Remove-LegacyPolicyKeys

    $currentHosts = @(Get-HostsCurrentDomains)
    if ($currentHosts.Count -gt 0) {
        try { Clear-HostsBlock } catch { Write-BfoLog "Full restore hosts clear: $_" 'ERR' }
    } else {
        Write-BfoLog 'No Brave-Free-Origin hosts block present.' 'INFO'
    }

    [void](Invoke-FlagsApply -Flags @())

    foreach ($t in $script:ScheduledTasks) {
        try {
            Enable-BraveTask -Name $t.Name
        } catch {
            Write-BfoLog "Full restore task $($t.Name): $_" 'WARN'
        }
    }

    foreach ($s in $script:Services) {
        try {
            Reset-BraveService -Name $s.Name
        } catch {
            Write-BfoLog "Full restore service $($s.Name): $_" 'WARN'
        }
    }

    try { Remove-AppliedRecord } catch { Write-BfoLog "Could not remove the record of the last apply: $_" 'WARN' }

    Write-BfoLog 'Full restore completed. Restart Brave to see stock behavior.' 'DONE'
}
