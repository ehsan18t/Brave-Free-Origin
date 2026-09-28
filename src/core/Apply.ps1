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
# / startup overrides, then flags and Brave's own settings files, scheduled
# tasks and services. Hosts blocks and scriptlets are not touched; their own
# pages apply them. Each policy goes to the key its level picks (see
# Get-PolicyLevel in core\Registry.ps1) and is removed from the other one.
# WriteFlags is $false when the user chose to skip Brave's files (flags and
# settings) because Brave is running.
# Returns the counts for the confirmation message and saves the record the
# drift check compares against.
function Invoke-Apply {
    param($Selection, [bool]$WriteFlags = $true)

    # A failed backup stops the apply: nothing is written that could not be undone.
    if ($Selection.Backup) { [void](New-BfoBackup -Kind auto -Reason 'apply') }

    $lock = [bool]$Selection.Lock
    $previous = Read-AppliedRecord
    # A row written only as Brave's own pref has no policy behind it. While
    # those prefs cannot be written (Brave running, or never started), such a
    # row stays a locked policy so it keeps working; the next Apply with
    # Brave closed moves it.
    $prefsWritable = Test-PrefsWritable -WriteFiles $WriteFlags
    $keptLocked = 0
    $applied = 0
    $cleared = 0
    Write-BfoLog "--- Applying to $script:PolicyPath ($(if ($lock) { 'locked in Brave' } else { 'changeable in Brave' })) ---"
    foreach ($p in $Selection.Policies) {
        $policy = $script:PolicyByName[$p.Name]
        $level = Get-PolicyLevel -Policy $policy -Lock $lock
        if ($level -eq 'pref' -and -not $prefsWritable) {
            $level = 'mandatory'
            if ($p.Checked) { $keptLocked++ }
        }
        $target = if ($p.Checked) { Get-LevelPath $level } else { $null }
        try {
            # Out of every key it must not be in, which moves a value when
            # the lock switch changed.
            foreach ($key in @($script:PolicyPath, $script:RecommendedPath)) {
                if ($key -eq $target) { continue }
                if ((Remove-Policy -Path $key -Name $p.Name -Type $p.Type) -and -not $p.Checked) {
                    Write-BfoLog "CLEARED $($p.Name)" 'OK'
                    $cleared++
                }
            }
            if ($target) {
                Set-Policy -Path $target -Name $p.Name -Type $p.Type -Value $p.Value
                Write-BfoLog "SET $($p.Name) = $(Format-PolicyValueText $p.Value) ($level)" 'OK'
            }
            if ($p.Checked) { $applied++ }
        } catch {
            Write-BfoLog "FAIL $($p.Name): $_" 'ERR'
        }
    }
    if ($keptLocked -gt 0) { Write-BfoLog "Brave's settings files cannot be written now: $keptLocked Shields and permission default(s) stay locked until the next Apply with Brave closed." 'WARN' }
    foreach ($name in $script:RetiredPolicies.Keys) {
        if (Remove-PolicyEverywhere -Name $name -Type 'DWORD') {
            Write-BfoLog "CLEARED retired policy $name ($($script:RetiredPolicies[$name].Reason))" 'OK'
            $cleared++
        }
    }
    Remove-LegacyPolicyKeys

    # Each override helper clears its own values first, so unticking + Apply
    # truly removes them, and creates the policy key only when it has a value
    # to write. The other key is cleared first, for the same reason.
    $overrides = $Selection.Overrides
    $searchPath = Get-LevelPath (Get-OverrideLevel -Name 'DefaultSearchProviderEnabled' -Lock $lock)
    $ntpPath = Get-LevelPath (Get-OverrideLevel -Name 'NewTabPageLocation' -Lock $lock)
    foreach ($key in @($script:PolicyPath, $script:RecommendedPath)) {
        try { Clear-OverrideValues -Path $key -Search:($key -ne $searchPath) -Ntp:($key -ne $ntpPath) } catch { Write-BfoLog "Clearing overrides under ${key}: $_" 'ERR' }
    }
    try { [void](Write-SearchEngineOverride -Path $searchPath -Overrides $overrides) } catch { Write-BfoLog "Search override: $_" 'ERR' }
    try { [void](Write-NtpOverride          -Path $ntpPath    -Overrides $overrides) } catch { Write-BfoLog "NTP override: $_" 'ERR' }
    try { [void](Write-HomeOverride         -Path $searchPath -Overrides $overrides) } catch { Write-BfoLog "Homepage override: $_" 'ERR' }
    try { [void](Write-StartupOverride      -Path $searchPath -Overrides $overrides) } catch { Write-BfoLog "Startup override: $_" 'ERR' }
    Remove-EmptyRecommendedKey

    $flagResults = @()
    if ($WriteFlags) {
        $flagResults = @(Invoke-FlagsApply -Flags $Selection.Flags)
    } else {
        Write-BfoLog 'Flags skipped: Brave is running.' 'WARN'
        $flagResults = @(Get-FlagChannels | ForEach-Object { [pscustomobject]@{ Channel = $_; Status = 'running' } })
    }
    # Brave's own prefs, for the rows that stay changeable in Brave.
    try {
        $prefs = Invoke-PrefsApply -Selection $Selection -Previous $previous -WriteFiles $WriteFlags
    } catch {
        Write-BfoLog "Brave settings: $_" 'ERR'
        $kept = if ($previous -and $previous.prefs) { $previous.prefs } else { [ordered]@{} }
        $prefs = [pscustomobject]@{ Results = @([pscustomobject]@{ Channel = 'all'; Status = 'failed' }); Record = $kept; Desired = @(); Fresh = @(@(Get-DesiredPrefs -Selection $Selection)); Stale = @() }
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
        Save-AppliedRecord (New-AppliedRecord -Selection $Selection -Previous $previous -FlagResults $flagResults -BraveVersion (Get-BraveVersion) -Prefs $prefs.Record -PrefsWritable $prefsWritable)
    } catch {
        Write-BfoLog "Could not save the record of this apply: $_" 'WARN'
    }

    Write-BfoLog "Done. Applied $applied settings, cleared $cleared. Restart Brave to take effect." 'DONE'

    # The rows whose Brave settings could not be written stay pending, like
    # flags, so the next Apply finishes them.
    $prefsSkipped = @($prefs.Results | Where-Object { $_.Status -ne 'written' -and $_.Status -ne 'unchanged' } | ForEach-Object { $_.Channel })
    $prefRows = if ($prefsSkipped.Count -gt 0) { @(@($prefs.Fresh) + @($prefs.Stale) | ForEach-Object { $_.Name } | Select-Object -Unique) } else { @() }
    return [pscustomobject]@{
        Applied      = $applied
        Cleared      = $cleared
        FlagsSkipped = @($flagResults | Where-Object { $_.Status -eq 'running' -or $_.Status -eq 'failed' } | ForEach-Object { $_.Channel })
        PrefsSkipped = $(if ($prefRows.Count -gt 0) { $prefsSkipped } else { @() })
        PrefRows     = $prefRows
    }
}

# $true when Apply can write Brave's own settings files right now: allowed
# (WriteFiles), and at least one channel has run and none is running.
function Test-PrefsWritable {
    param([bool]$WriteFiles)
    if (-not $WriteFiles) { return $false }
    $channels = @(Get-FlagChannels)
    if ($channels.Count -eq 0) { return $false }
    return (@($channels | Where-Object { @(Get-ChannelProcesses $_).Count -gt 0 }).Count -eq 0)
}

# Deletes the Recommended subkey once nothing is left in it, so a machine the
# app no longer changes carries no empty key.
function Remove-EmptyRecommendedKey {
    $key = $script:RecommendedPath
    if (-not (Test-Path $key)) { return }
    $item = Get-Item -Path $key -ErrorAction SilentlyContinue
    if ($item -and $item.ValueCount -eq 0 -and $item.SubKeyCount -eq 0) {
        try { Remove-Item -Path $key -Force -ErrorAction Stop } catch { Write-Verbose "Could not remove the empty $key." }
    }
}

# Puts the machine back to stock: removes the policy key and the old
# per-channel keys, the hosts block and the flags the app manages, and turns
# Brave's update tasks and services back on. The window clears its own
# selection afterwards.
function Invoke-FullRestore {
    param([bool]$Backup)

    if ($Backup) { [void](New-BfoBackup -Kind auto -Reason 'fullRestore') }

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

    # Brave's own settings the app wrote go back to Brave's defaults, unless
    # the user has changed them in Brave since.
    $record = Read-AppliedRecord
    $prefsLeft = $null
    try {
        $reset = Invoke-PrefsApply -Selection ([pscustomobject]@{ Lock = $false; Policies = @() }) -Previous $record
        if ($reset.Record.Count -gt 0) { $prefsLeft = $reset.Record }
    } catch { Write-BfoLog "Full restore Brave settings: $_" 'ERR' }

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

    try {
        if ($prefsLeft) {
            # A running Brave kept some settings from being reset: remember
            # only those, so the next Apply or restore can finish the job.
            Save-AppliedRecord ([ordered]@{ version = 1; appVersion = $script:AppVersion; savedAt = (Get-Date -Format 's'); mode = 'Default'
                policies = @{}; overrides = @{}; tasks = @(); services = @(); flags = @{}; hosts = @(); repeats = @{}; lock = $false; prefs = $prefsLeft })
            Write-BfoLog 'Brave is running: some of its settings were not reset. Close it and run the full restore again.' 'WARN'
        } else {
            Remove-AppliedRecord
        }
    } catch { Write-BfoLog "Could not update the record of the last apply: $_" 'WARN' }

    Write-BfoLog 'Full restore completed. Restart Brave to see stock behavior.' 'DONE'
}
