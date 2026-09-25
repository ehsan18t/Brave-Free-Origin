# ============================================================================
#  Drift: remembering what Apply set, and noticing when it stops being true.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Every Apply records what it enforced: each ticked policy and override with
# its value, the tasks and services it disabled, the flags it wrote to each
# channel. Applying hosts blocks records the blocked domains. When the app
# opens, the record is compared with the machine and every difference is
# sorted into one of three kinds:
#   reverted  something changed it back (a Brave update, another tool, a
#             hand edit); Re-apply writes it again
#   repeat    it was re-applied before and has been undone again, so
#             something keeps undoing it; re-applying forever will not help
#   retired   the installed Brave no longer supports it; Clean up removes it
# The record covers the whole machine, so it lives in ProgramData. Flags are
# per user, and the record stores the Local State file they were written to.
# Only what was enforced is recorded: a policy Apply removed is not watched.

$script:AppliedRecordPath = Join-Path $env:ProgramData 'Brave-Free-Origin\applied.json'

function Read-AppliedRecord {
    if (-not (Test-Path -LiteralPath $script:AppliedRecordPath)) { return $null }
    try {
        return ([System.IO.File]::ReadAllText($script:AppliedRecordPath, (New-Object System.Text.UTF8Encoding($false))) | ConvertFrom-Json)
    } catch {
        Write-BfoLog "The record of the last apply could not be read: $_" 'WARN'
        return $null
    }
}

function Save-AppliedRecord {
    param($Record)
    $dir = Split-Path -Parent $script:AppliedRecordPath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = $Record | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($script:AppliedRecordPath, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Remove-AppliedRecord {
    if (Test-Path -LiteralPath $script:AppliedRecordPath) { Remove-Item -LiteralPath $script:AppliedRecordPath -Force }
}

# ConvertFrom-Json gives PSCustomObjects; the record is edited as hashtables.
function ConvertTo-RecordTable {
    param($Object)
    $table = [ordered]@{}
    if ($Object) { foreach ($p in $Object.PSObject.Properties) { $table[$p.Name] = $p.Value } }
    return $table
}

function New-RecordValue {
    param([string]$Type, $Value)
    if ($Type -eq 'LIST') { return [ordered]@{ type = 'LIST'; value = [string[]]@($Value) } }
    return [ordered]@{ type = $Type; value = $Value }
}

# The record of a finished Apply. Hosts and repeat counts carry over from the
# previous record: hosts have their own Apply, and a count only resets when
# what it counts changes.
function New-AppliedRecord {
    param($Selection, $Previous, [object[]]$FlagResults, [string]$BraveVersion)
    $version = ConvertTo-BraveVersionInfo $BraveVersion
    $policies = [ordered]@{}
    foreach ($p in $Selection.Policies) { if ($p.Checked) { $policies[$p.Name] = New-RecordValue -Type $p.Type -Value $p.Value } }

    $overrides = [ordered]@{}
    $o = $Selection.Overrides
    foreach ($getter in @({ Get-DesiredSearchOverride -Overrides $o }, { Get-DesiredNtpOverride -Overrides $o }, { Get-DesiredHomeOverride -Overrides $o })) {
        try { $desired = & $getter } catch { continue }
        foreach ($name in $desired.Keys) { $overrides[$name] = New-RecordValue -Type $desired[$name].Type -Value $desired[$name].Value }
    }
    try {
        $startup = Get-DesiredStartupOverride -Overrides $o
        if ($startup.Enabled) {
            $overrides['RestoreOnStartup'] = New-RecordValue -Type 'DWORD' -Value $startup.Code
            if ($startup.Urls.Count -gt 0) { $overrides['RestoreOnStartupURLs'] = New-RecordValue -Type 'LIST' -Value $startup.Urls }
        }
    } catch { Write-Verbose "Startup override not recorded: $_" }

    # Flags: channels written or already right take the new list; a channel
    # that was skipped (running, failed) keeps what the last record said.
    $flags = [ordered]@{}
    $previousFlags = if ($Previous) { ConvertTo-RecordTable $Previous.flags } else { @{} }
    $wanted = [string[]]@($Selection.Flags | Where-Object { $_.Checked } | ForEach-Object { $_.Entry })
    foreach ($r in @($FlagResults)) {
        $path = $script:Channels[$r.Channel].LocalState
        if ($r.Status -eq 'written' -or $r.Status -eq 'unchanged') {
            if ($wanted.Count -gt 0) { $flags[$r.Channel] = [ordered]@{ path = $path; entries = $wanted } }
        } elseif ($previousFlags.Contains($r.Channel)) {
            $flags[$r.Channel] = $previousFlags[$r.Channel]
        }
    }

    $record = [ordered]@{
        version    = 1
        appVersion = $script:AppVersion
        savedAt    = (Get-Date -Format 's')
        mode       = $Selection.Profile
        chromium   = $version.Chromium
        braveMinor = $version.BraveMinor
        policies   = $policies
        overrides  = $overrides
        tasks      = [string[]]@($Selection.Tasks | Where-Object { $_.Checked } | ForEach-Object { $_.Name })
        services   = [string[]]@($Selection.Services | Where-Object { $_.Checked } | ForEach-Object { $_.Name })
        flags      = $flags
        hosts      = $(if ($Previous -and $Previous.hosts) { [string[]]@($Previous.hosts) } else { [string[]]@() })
        repeats    = [ordered]@{}
    }
    # Keep a repeat count only while the recorded value is unchanged.
    if ($Previous -and $Previous.repeats) {
        $oldPolicies = ConvertTo-RecordTable $Previous.policies
        $oldOverrides = ConvertTo-RecordTable $Previous.overrides
        foreach ($p in $Previous.repeats.PSObject.Properties) {
            $keep = $false
            $kind, $name = $p.Name -split ':', 2
            switch ($kind) {
                'P' { $keep = $policies.Contains($name) -and $oldPolicies.Contains($name) -and (Test-PolicyValueEqual $oldPolicies[$name].value $policies[$name].value) }
                'O' { $keep = $overrides.Contains($name) -and $oldOverrides.Contains($name) -and (Test-PolicyValueEqual $oldOverrides[$name].value $overrides[$name].value) }
                'T' { $keep = $record.tasks -contains $name }
                'S' { $keep = $record.services -contains $name }
                default { $keep = $true }
            }
            if ($keep) { $record.repeats[$p.Name] = $p.Value }
        }
    }
    return $record
}

# Called by the hosts Apply: records the domains now blocked. An empty list
# clears the hosts part.
function Save-AppliedHosts {
    param([string[]]$Domains)
    $record = Read-AppliedRecord
    $table = if ($record) { ConvertTo-RecordTable $record } else {
        [ordered]@{ version = 1; appVersion = $script:AppVersion; savedAt = (Get-Date -Format 's'); mode = 'Custom'; policies = @{}; overrides = @{}; tasks = @(); services = @(); flags = @{}; repeats = @{} }
    }
    $table['hosts'] = [string[]]@($Domains | Sort-Object -Unique)
    Save-AppliedRecord $table
}

# ---- The check ---------------------------------------------------------------
function New-DriftItem {
    param([string]$Key, [string]$Kind, [string]$Name, [string]$Status, $Expected, $Actual, [string]$Reason, [string]$Channel)
    return [pscustomobject]@{
        Key = $Key; Kind = $Kind; Name = $Name; Status = $Status; Reason = $Reason; Channel = $Channel
        Expected = (Format-PolicyValueText $Expected); Actual = $(if ($null -eq $Actual) { $null } else { Format-PolicyValueText $Actual })
    }
}

function Get-RecordedValue {
    param([hashtable]$Values, [string]$Name, [string]$Type)
    if ($Type -eq 'LIST') {
        $listPath = Join-Path $script:PolicyPath $Name
        if (-not (Test-Path $listPath)) { return [pscustomobject]@{ Exists = $false; Value = $null } }
        return [pscustomobject]@{ Exists = $true; Value = [string[]]@(Get-RegistryNumberedValues -Path $listPath) }
    }
    return (Get-TableValueState -Values $Values -Name $Name)
}

# Compares the record with this PC. Returns Mode, SavedAt and Items (see
# New-DriftItem); no Items means everything is still in place.
function Get-DriftReport {
    param([string]$BraveVersion)
    $record = Read-AppliedRecord
    if (-not $record) { return [pscustomobject]@{ Mode = $null; SavedAt = $null; Items = @() } }
    $version = ConvertTo-BraveVersionInfo $BraveVersion
    $repeats = ConvertTo-RecordTable $record.repeats
    $values = Get-RegistryValueTable -Path $script:PolicyPath
    $items = @()

    $status = { param([string]$Key) if ($repeats.Contains($Key) -and [int]$repeats[$Key] -ge 1) { 'repeat' } else { 'reverted' } }

    foreach ($p in (ConvertTo-RecordTable $record.policies).GetEnumerator()) {
        $name = $p.Key; $type = $p.Value.type; $expected = $p.Value.value
        $state = Get-RecordedValue -Values $values -Name $name -Type $type
        $policy = $script:PolicyByName[$name]
        $retiredEntry = $script:RetiredPolicies[$name]
        if ($retiredEntry -or -not $policy) {
            if ($state.Exists) {
                $reason = if ($retiredEntry) { $retiredEntry.Reason } else { 'removed' }
                $items += New-DriftItem -Key "P:$name" -Kind 'Policy' -Name $name -Status 'retired' -Expected $expected -Actual $state.Value -Reason $reason
            }
            continue
        }
        if ($policy.MaxChromium -and $version.Chromium -gt $policy.MaxChromium) {
            if ($state.Exists) { $items += New-DriftItem -Key "P:$name" -Kind 'Policy' -Name $name -Status 'retired' -Expected $expected -Actual $state.Value -Reason 'expired' }
            continue
        }
        if (-not $state.Exists -or -not (Test-PolicyValueEqual $state.Value $expected)) {
            $items += New-DriftItem -Key "P:$name" -Kind 'Policy' -Name $name -Status (& $status "P:$name") -Expected $expected -Actual $(if ($state.Exists) { $state.Value } else { $null })
        }
    }

    foreach ($o in (ConvertTo-RecordTable $record.overrides).GetEnumerator()) {
        $name = $o.Key; $type = $o.Value.type; $expected = $o.Value.value
        $state = Get-RecordedValue -Values $values -Name $name -Type $type
        if (-not $state.Exists -or -not (Test-PolicyValueEqual $state.Value $expected)) {
            $items += New-DriftItem -Key "O:$name" -Kind 'Override' -Name $name -Status (& $status "O:$name") -Expected $expected -Actual $(if ($state.Exists) { $state.Value } else { $null })
        }
    }

    foreach ($name in @($record.tasks | Where-Object { $_ })) {
        $task = Get-BraveTaskState -Name $name
        if ($task -and $task.State -ne 'Disabled') {
            $items += New-DriftItem -Key "T:$name" -Kind 'Task' -Name $name -Status (& $status "T:$name") -Expected 'Disabled' -Actual $task.State
        }
    }
    foreach ($name in @($record.services | Where-Object { $_ })) {
        if (@(Get-BraveServices -Name $name).Count -gt 0 -and -not (Test-BraveServiceDisabled -Name $name)) {
            $items += New-DriftItem -Key "S:$name" -Kind 'Service' -Name $name -Status (& $status "S:$name") -Expected 'Disabled' -Actual 'Enabled'
        }
    }

    $known = @($script:Flags | ForEach-Object { $_.Name })
    foreach ($c in (ConvertTo-RecordTable $record.flags).GetEnumerator()) {
        $current = Get-LocalStateFlags -Path $c.Value.path
        if ($null -eq $current) { continue }
        foreach ($entry in @($c.Value.entries)) {
            if ($current -contains $entry) { continue }
            $flagName = ($entry -split '@')[0]
            $key = "F:$($c.Key):$flagName"
            $kind = if ($known -notcontains $flagName) { 'retired' } else { & $status $key }
            $items += New-DriftItem -Key $key -Kind 'Flag' -Name $flagName -Status $kind -Expected $entry -Actual $null -Channel $c.Key -Reason $(if ($kind -eq 'retired') { 'removed' } else { '' })
        }
    }

    $recordedHosts = @($record.hosts | Where-Object { $_ })
    if ($recordedHosts.Count -gt 0) {
        $currentHosts = @(Get-HostsCurrentDomains)
        $missing = @($recordedHosts | Where-Object { $currentHosts -notcontains $_ })
        if ($missing.Count -gt 0) {
            $items += New-DriftItem -Key 'H:hosts' -Kind 'Hosts' -Name 'hosts' -Status (& $status 'H:hosts') -Expected ($missing -join ', ') -Actual $null
        }
    }

    return [pscustomobject]@{ Mode = $record.mode; SavedAt = $record.savedAt; Items = $items }
}

# ---- Acting on it ---------------------------------------------------------------
# Each takes the items to act on, as Get-DriftReport returned them, and returns
# the keys it could not handle (a running Brave, for flags).

# Writes the recorded value of each item again and counts the re-apply, so a
# second revert shows as "keeps coming back".
function Invoke-DriftReapply {
    param([object[]]$Items)
    $record = Read-AppliedRecord
    if (-not $record) { return @() }
    $table = ConvertTo-RecordTable $record
    $repeats = ConvertTo-RecordTable $record.repeats
    $policies = ConvertTo-RecordTable $record.policies
    $overrides = ConvertTo-RecordTable $record.overrides
    $flags = ConvertTo-RecordTable $record.flags
    $skipped = @()
    foreach ($item in $Items) {
        try {
            if ($item.Kind -eq 'Flag' -and @(Get-ChannelProcesses $item.Channel).Count -gt 0) {
                $skipped += $item.Key
                continue
            }
            if ($item.Kind -eq 'Policy') {
                $v = $policies[$item.Name]
                Set-Policy -Path $script:PolicyPath -Name $item.Name -Type $v.type -Value $v.value
            } elseif ($item.Kind -eq 'Override') {
                $v = $overrides[$item.Name]
                Set-Policy -Path $script:PolicyPath -Name $item.Name -Type $v.type -Value $v.value
            } elseif ($item.Kind -eq 'Task') {
                Disable-BraveTask -Name $item.Name
            } elseif ($item.Kind -eq 'Service') {
                Disable-BraveService -Name $item.Name
            } elseif ($item.Kind -eq 'Flag') {
                $entries = [string[]]@($flags[$item.Channel].entries)
                [void](Write-LocalStateFlags -Channel $item.Channel -Managed ([string[]]@($script:Flags | ForEach-Object { $_.Name })) -Wanted $entries)
            } elseif ($item.Kind -eq 'Hosts') {
                Set-HostsBlockDomains -Domains ([string[]]@(@(Get-HostsCurrentDomains) + @($record.hosts) | Sort-Object -Unique))
            }
            $repeats[$item.Key] = [int]$repeats[$item.Key] + 1
            Write-BfoLog "Re-applied $($item.Kind) $($item.Name)" 'OK'
        } catch {
            Write-BfoLog "Re-apply $($item.Kind) $($item.Name): $_" 'ERR'
            $skipped += $item.Key
        }
    }
    $table['repeats'] = $repeats
    Save-AppliedRecord $table
    return $skipped
}

# Removes retired items from this PC and from the record.
function Invoke-DriftCleanup {
    param([object[]]$Items)
    $skipped = @()
    $done = @()
    foreach ($item in $Items) {
        try {
            if ($item.Kind -eq 'Flag' -and @(Get-ChannelProcesses $item.Channel).Count -gt 0) {
                $skipped += $item.Key
                continue
            }
            if ($item.Kind -eq 'Policy') {
                $type = if ($script:PolicyByName[$item.Name]) { $script:PolicyByName[$item.Name].Type } else { 'DWORD' }
                [void](Remove-Policy -Path $script:PolicyPath -Name $item.Name -Type $type)
            } elseif ($item.Kind -eq 'Flag') {
                [void](Write-LocalStateFlags -Channel $item.Channel -Managed ([string[]]@($item.Name)) -Wanted ([string[]]@()))
            }
            $done += $item
            Write-BfoLog "Cleaned up $($item.Kind) $($item.Name)" 'OK'
        } catch {
            Write-BfoLog "Clean up $($item.Kind) $($item.Name): $_" 'ERR'
            $skipped += $item.Key
        }
    }
    Remove-DriftItemsFromRecord -Items $done
    return $skipped
}

# Accepts the current state: the items leave the record, so they are no
# longer watched.
function Remove-DriftItemsFromRecord {
    param([object[]]$Items)
    $record = Read-AppliedRecord
    if (-not $record -or @($Items).Count -eq 0) { return }
    $table = ConvertTo-RecordTable $record
    $policies = ConvertTo-RecordTable $record.policies
    $overrides = ConvertTo-RecordTable $record.overrides
    $flags = ConvertTo-RecordTable $record.flags
    $repeats = ConvertTo-RecordTable $record.repeats
    $tasks = [System.Collections.Generic.List[string]]::new([string[]]@($record.tasks | Where-Object { $_ }))
    $services = [System.Collections.Generic.List[string]]::new([string[]]@($record.services | Where-Object { $_ }))
    $hosts = @($record.hosts | Where-Object { $_ })
    foreach ($item in $Items) {
        switch ($item.Kind) {
            'Policy'   { $policies.Remove($item.Name) }
            'Override' { $overrides.Remove($item.Name) }
            'Task'     { [void]$tasks.Remove($item.Name) }
            'Service'  { [void]$services.Remove($item.Name) }
            'Flag'     {
                if ($flags.Contains($item.Channel)) {
                    $channelFlags = $flags[$item.Channel]
                    $left = [string[]]@(@($channelFlags.entries) | Where-Object { (($_ -split '@')[0]) -ne $item.Name })
                    if ($left.Count -gt 0) { $flags[$item.Channel] = [ordered]@{ path = $channelFlags.path; entries = $left } }
                    else { $flags.Remove($item.Channel) }
                }
            }
            'Hosts'    { $missing = @($item.Expected -split ', '); $hosts = @($hosts | Where-Object { $missing -notcontains $_ }) }
        }
        $repeats.Remove($item.Key)
    }
    $table['policies'] = $policies
    $table['overrides'] = $overrides
    $table['tasks'] = [string[]]$tasks.ToArray()
    $table['services'] = [string[]]$services.ToArray()
    $table['flags'] = $flags
    $table['hosts'] = [string[]]$hosts
    $table['repeats'] = $repeats
    Save-AppliedRecord $table
}
