# ============================================================================
#  Hosts file blocklist: sentinel block management and its preview report.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

$script:HostsSentinelStart = '# === Brave-Free-Origin START - managed block, do not edit between sentinels ==='
$script:HostsSentinelEnd   = '# === Brave-Free-Origin END ==='
$script:HostsFile = "$env:WINDIR\System32\drivers\etc\hosts"

# ---- Hosts file helpers (v1.5) ----------------------------------------------
function Backup-HostsFile {
    if (-not (Test-Path $script:HostsFile)) { return $null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $file = Join-Path (Get-BackupDir -Create) "hosts-backup-$stamp.bak"
    Copy-Item $script:HostsFile $file -Force
    Write-Log "Hosts backup saved: $file" 'OK'
    return $file
}

# Splits the hosts file into the lines this app does not own (Kept) and the
# domains inside its sentinel block (Domains).
function Read-HostsFile {
    $kept = New-Object System.Collections.ArrayList
    $domains = @()
    if (Test-Path $script:HostsFile) {
        $inBlock = $false
        foreach ($line in (Get-Content $script:HostsFile -ErrorAction SilentlyContinue)) {
            if ($line -eq $script:HostsSentinelStart) { $inBlock = $true; continue }
            if ($line -eq $script:HostsSentinelEnd)   { $inBlock = $false; continue }
            if (-not $inBlock) { [void]$kept.Add($line) }
            elseif ($line -match '^\s*0\.0\.0\.0\s+(\S+)') { $domains += $Matches[1] }
        }
    }
    return [pscustomobject]@{ Kept = $kept; Domains = $domains }
}

function Get-HostsCurrentDomains {
    return (Read-HostsFile).Domains
}

function Set-HostsBlockDomains {
    param([string[]]$Domains)
    [void](Backup-HostsFile)

    # Everything outside our existing sentinel block (if any) is kept as is.
    $kept = (Read-HostsFile).Kept

    # Trim trailing blank lines from existing content for tidiness
    while ($kept.Count -gt 0 -and [string]::IsNullOrWhiteSpace($kept[$kept.Count - 1])) {
        $kept.RemoveAt($kept.Count - 1)
    }

    if ($Domains -and $Domains.Count -gt 0) {
        [void]$kept.Add('')
        [void]$kept.Add($script:HostsSentinelStart)
        [void]$kept.Add("# Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') by Brave Free Origin. Remove via the GUI.")
        foreach ($d in ($Domains | Sort-Object -Unique)) {
            [void]$kept.Add("0.0.0.0 $d")
        }
        [void]$kept.Add($script:HostsSentinelEnd)
    }

    # ASCII encoding - matches what Windows expects for hosts. Some AVs flag UTF-16 hosts.
    Set-Content -Path $script:HostsFile -Value $kept -Encoding ASCII -Force

    # Flush DNS so the change takes effect immediately for new connections
    & ipconfig.exe /flushdns | Out-Null
    Write-Log "Hosts block written: $($Domains.Count) domain(s). DNS cache flushed." 'OK'
}

function Clear-HostsBlock {
    Set-HostsBlockDomains -Domains @()
    Write-Log 'Hosts sentinel block removed.' 'OK'
}

# Desired is every domain of the ticked groups; GroupCount is how many groups
# are ticked, for the report header only.
function New-HostsPlanReport {
    param([string[]]$Desired, [int]$GroupCount)
    $desired = @($Desired | Where-Object { $_ } | Sort-Object -Unique)
    $current = @(Get-HostsCurrentDomains)
    $toAdd = @($desired | Where-Object { $current -notcontains $_ })
    $toKeep = @($desired | Where-Object { $current -contains $_ })
    $toRemove = @($current | Where-Object { $desired -notcontains $_ })

    $report = New-Object System.Text.StringBuilder
    [void]$report.AppendLine('Brave Free Origin hosts preview')
    [void]$report.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$report.AppendLine("File: $($script:HostsFile)")
    [void]$report.AppendLine('')
    [void]$report.AppendLine("Selected groups: $GroupCount")
    [void]$report.AppendLine("Current managed domains: $($current.Count)")
    [void]$report.AppendLine("Desired managed domains: $($desired.Count)")
    [void]$report.AppendLine('')
    [void]$report.AppendLine("Add: $($toAdd.Count)")
    foreach ($d in $toAdd) { [void]$report.AppendLine("  + $d") }
    [void]$report.AppendLine("Keep: $($toKeep.Count)")
    foreach ($d in $toKeep) { [void]$report.AppendLine("  = $d") }
    [void]$report.AppendLine("Remove from managed block: $($toRemove.Count)")
    foreach ($d in $toRemove) { [void]$report.AppendLine("  - $d") }
    [void]$report.AppendLine('')
    [void]$report.AppendLine('No other hosts entries are touched. The GUI only replaces the Brave-Free-Origin sentinel block.')
    return $report.ToString()
}
