# ============================================================================
#  Full backups: a snapshot of everything the app can change on this PC, and
#  putting it back.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# One backup is one folder under Documents\Brave-Free-Origin-Backups\backups:
#   policies.reg        the whole Brave policy key (reg.exe export), so values
#                       the app does not manage come back too; absent when the
#                       key did not exist
#   local-state-*.json  each channel's Local State as it was, for recovery by
#                       hand; Restore only puts the flag list back
#   backup.json         when and why it was taken, whether it is pinned, and
#                       the rest of the state: the app's hosts block, each
#                       channel's flag list, the state of every Brave update
#                       task and service, and the drift record
# Automatic backups are taken before anything that writes (see the callers)
# and only the newest $script:BackupKeep are kept; manual and pinned backups
# are never deleted automatically.

$script:BackupKeep = 20

function Get-BackupRoot {
    param([switch]$Create)
    $root = Join-Path (Get-BackupDir -Create:$Create) 'backups'
    if ($Create -and -not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    return $root
}

function Write-BackupManifest {
    param([string]$Folder, $Manifest)
    $json = $Manifest | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText((Join-Path $Folder 'backup.json'), $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Read-BackupManifest {
    param([string]$Folder)
    $file = Join-Path $Folder 'backup.json'
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    try { return ([System.IO.File]::ReadAllText($file, (New-Object System.Text.UTF8Encoding($false))) | ConvertFrom-Json) }
    catch { return $null }
}

# The state of Brave's update tasks and services, by real Windows name.
function Get-SystemSnapshot {
    $tasks = [ordered]@{}
    foreach ($t in $script:ScheduledTasks) {
        $state = Get-BraveTaskState -Name $t.Name
        if ($state) { foreach ($match in $state.Tasks) { $tasks[$match.Name] = ($match.State -eq 'Disabled') } }
    }
    $services = [ordered]@{}
    foreach ($s in $script:Services) {
        foreach ($svc in @(Get-BraveServices -Name $s.Name)) { $services[$svc.Name] = "$($svc.StartType)" }
    }
    return [pscustomobject]@{ Tasks = $tasks; Services = $services }
}

# Takes a backup. Kind is 'auto' or 'manual'; Reason says what was about to
# happen (apply, hosts, restore...), for the list in Settings. Returns the
# backup's id (its folder name).
function New-BfoBackup {
    param([ValidateSet('auto', 'manual')][string]$Kind = 'auto', [string]$Reason = 'manual')
    $root = Get-BackupRoot -Create
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $id = $stamp
    $n = 1
    while (Test-Path -LiteralPath (Join-Path $root $id)) { $id = "$stamp-$n"; $n++ }
    $folder = Join-Path $root $id
    New-Item -ItemType Directory -Path $folder -Force | Out-Null

    $policyCount = 0
    $hasKey = Test-Path $script:PolicyPath
    if ($hasKey) {
        # reg.exe wants HKLM\..., not the PowerShell drive form HKLM:\...
        $regKey = $script:PolicyPath -replace '^(HK[A-Z]+):', '$1'
        & reg.exe EXPORT $regKey (Join-Path $folder 'policies.reg') /y 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "reg.exe could not export $regKey." }
        $policyCount = (Get-RegistryValueTable -Path $script:PolicyPath).Count + @(Get-ChildItem -Path $script:PolicyPath -ErrorAction SilentlyContinue).Count
    }

    $flags = [ordered]@{}
    foreach ($channel in @(Get-FlagChannels)) {
        $path = $script:Channels[$channel].LocalState
        $entries = Get-LocalStateFlags -Path $path
        if ($null -eq $entries) { continue }
        $flags[$channel] = [ordered]@{ entries = [string[]]@($entries) }
        Copy-Item -LiteralPath $path -Destination (Join-Path $folder "local-state-$($channel.ToLowerInvariant()).json") -Force
    }

    $system = Get-SystemSnapshot
    $hosts = [string[]]@(Get-HostsCurrentDomains)
    $drift = Read-AppliedRecord
    $flagCount = 0
    foreach ($c in $flags.Values) { $flagCount = [Math]::Max($flagCount, @($c.entries).Count) }

    Write-BackupManifest -Folder $folder -Manifest ([ordered]@{
        version    = 1
        appVersion = $script:AppVersion
        created    = (Get-Date -Format 's')
        kind       = $Kind
        reason     = $Reason
        pinned     = $false
        policyKey  = $hasKey
        counts     = [ordered]@{ policies = $policyCount; flags = $flagCount; hosts = $hosts.Count }
        hosts      = $hosts
        flags      = $flags
        tasks      = $system.Tasks
        services   = $system.Services
        drift      = $drift
    })
    Write-BfoLog "Backup saved: $folder" 'OK'
    Invoke-BackupPrune
    return $id
}

# Every backup, newest first: Id, Folder, Created, Kind, Reason, Pinned, Counts.
# Folders without a readable backup.json are skipped.
function Get-BfoBackups {
    $root = Get-BackupRoot
    if (-not (Test-Path -LiteralPath $root)) { return @() }
    $list = @(foreach ($dir in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
        $m = Read-BackupManifest -Folder $dir.FullName
        if (-not $m) { continue }
        [pscustomobject]@{
            Id = $dir.Name; Folder = $dir.FullName; Created = "$($m.created)"; Kind = "$($m.kind)"; Reason = "$($m.reason)"
            Pinned = [bool]$m.pinned; Policies = [int]$m.counts.policies; Flags = [int]$m.counts.flags; Hosts = [int]$m.counts.hosts
        }
    })
    return @($list | Sort-Object Id -Descending)
}

# Keeps the newest $script:BackupKeep automatic backups that are not pinned.
function Invoke-BackupPrune {
    $auto = @(Get-BfoBackups | Where-Object { $_.Kind -eq 'auto' -and -not $_.Pinned })
    foreach ($old in @($auto | Select-Object -Skip $script:BackupKeep)) {
        try {
            Remove-Item -LiteralPath $old.Folder -Recurse -Force -ErrorAction Stop
            Write-BfoLog "Old automatic backup removed: $($old.Id)" 'INFO'
        } catch { Write-BfoLog "Could not remove old backup $($old.Id): $_" 'WARN' }
    }
}

function Get-BackupFolder {
    param([string]$Id)
    if ($Id -notmatch '^[0-9-]+$') { throw "Not a backup id: $Id" }
    $folder = Join-Path (Get-BackupRoot) $Id
    if (-not (Test-Path -LiteralPath (Join-Path $folder 'backup.json'))) { throw "Backup $Id was not found." }
    return $folder
}

function Set-BfoBackupPinned {
    param([string]$Id, [bool]$Pinned)
    $folder = Get-BackupFolder $Id
    $m = Read-BackupManifest -Folder $folder
    $m.pinned = $Pinned
    Write-BackupManifest -Folder $folder -Manifest $m
}

function Remove-BfoBackup {
    param([string]$Id)
    Remove-Item -LiteralPath (Get-BackupFolder $Id) -Recurse -Force -ErrorAction Stop
    Write-BfoLog "Backup deleted: $Id" 'OK'
}

# The channels a restore would write flags to and that are running now, so
# the window can ask before starting.
function Get-BackupRunningChannels {
    param([string]$Id)
    $m = Read-BackupManifest -Folder (Get-BackupFolder $Id)
    $channels = @(if ($m.flags) { $m.flags.PSObject.Properties.Name })
    return @($channels | Where-Object { $script:Channels.Contains($_) -and @(Get-ChannelProcesses $_).Count -gt 0 })
}

# Puts this PC back to a backup. A backup of the current state is taken first
# (reason 'restore'), so the restore itself can be undone. WriteFlags is
# $false when the user chose to skip flags because Brave is running. Returns
# the id of the backup taken first and the channels whose flags were skipped.
function Restore-BfoBackup {
    param([string]$Id, [bool]$WriteFlags = $true)
    $folder = Get-BackupFolder $Id
    $m = Read-BackupManifest -Folder $folder
    $before = New-BfoBackup -Kind auto -Reason 'restore'

    # The policy key: exactly what the backup had, nothing more.
    if (Test-Path $script:PolicyPath) { Remove-Item -Path $script:PolicyPath -Recurse -Force -ErrorAction Stop }
    $regFile = Join-Path $folder 'policies.reg'
    if ($m.policyKey -and (Test-Path -LiteralPath $regFile)) {
        & reg.exe IMPORT $regFile 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "reg.exe could not import $regFile." }
    }
    Write-BfoLog "Restored the policy key from backup $Id" 'OK'

    # Only the app's own block in the hosts file.
    Set-HostsBlockDomains -Domains ([string[]]@($m.hosts | Where-Object { $_ }))

    $skipped = @()
    if ($m.flags) {
        foreach ($p in $m.flags.PSObject.Properties) {
            $channel = $p.Name
            if (-not $script:Channels.Contains($channel) -or -not (Test-Path -LiteralPath $script:Channels[$channel].LocalState)) { continue }
            if (-not $WriteFlags -or @(Get-ChannelProcesses $channel).Count -gt 0) { $skipped += $channel; continue }
            $wanted = [string[]]@($p.Value.entries | Where-Object { $_ })
            $current = @(Get-LocalStateFlags -Path $script:Channels[$channel].LocalState)
            # Every name either side has, so the list comes back exactly.
            $names = [string[]]@(@($current) + @($wanted) | ForEach-Object { ($_ -split '@')[0] } | Select-Object -Unique)
            try {
                [void](Write-LocalStateFlags -Channel $channel -Managed $names -Wanted $wanted)
                Write-BfoLog "[$channel] Flags restored from backup $Id" 'OK'
            } catch {
                Write-BfoLog "[$channel] Flags: $_" 'ERR'
                $skipped += $channel
            }
        }
    }

    if ($m.tasks) {
        $now = @(Get-RootTaskList)
        foreach ($p in $m.tasks.PSObject.Properties) {
            $task = @($now | Where-Object { $_.Name -eq $p.Name })
            if ($task.Count -eq 0) { continue }
            $isDisabled = ($task[0].State -eq 'Disabled')
            try {
                if ([bool]$p.Value -and -not $isDisabled) { Disable-ScheduledTask -TaskPath '\' -TaskName $p.Name -ErrorAction Stop | Out-Null; Write-BfoLog "DISABLED task $($p.Name)" 'OK' }
                elseif (-not [bool]$p.Value -and $isDisabled) { Enable-ScheduledTask -TaskPath '\' -TaskName $p.Name -ErrorAction Stop | Out-Null; Write-BfoLog "ENABLED task $($p.Name)" 'OK' }
            } catch { Write-BfoLog "Task $($p.Name): $_" 'WARN' }
        }
    }
    if ($m.services) {
        foreach ($p in $m.services.PSObject.Properties) {
            $svc = Get-Service -Name $p.Name -ErrorAction SilentlyContinue
            if (-not $svc -or "$($svc.StartType)" -eq "$($p.Value)") { continue }
            try {
                if ("$($p.Value)" -eq 'Disabled' -and $svc.Status -eq 'Running') { Stop-Service -Name $p.Name -Force -ErrorAction SilentlyContinue }
                Set-Service -Name $p.Name -StartupType "$($p.Value)" -ErrorAction Stop
                Write-BfoLog "Service $($p.Name) set to $($p.Value)" 'OK'
            } catch { Write-BfoLog "Service $($p.Name): $_" 'WARN' }
        }
    }

    # The drift record goes back too, so the Home warning matches.
    try {
        if ($m.drift) { Save-AppliedRecord $m.drift } else { Remove-AppliedRecord }
    } catch { Write-BfoLog "Could not restore the record of the last apply: $_" 'WARN' }

    Write-BfoLog "Restore of backup $Id completed. Restart Brave to see it." 'DONE'
    return [pscustomobject]@{ Before = $before; FlagsSkipped = $skipped }
}
