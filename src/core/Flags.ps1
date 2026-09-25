# ============================================================================
#  brave://flags: reading and writing the flag list in Brave's Local State.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Brave keeps the flags a user set in brave://flags in the Local State file of
# each channel, as browser.enabled_labs_experiments: a list of "name@option"
# strings where option 1 is Enabled and 2 is Disabled. Local State is Brave's
# own file and Brave rewrites it on exit, so:
#   * it is only written while that channel's Brave is closed;
#   * only that one list is touched: the file is scanned, the list is swapped
#     in place and every other byte is written back exactly as it was read;
#   * a copy goes to the backup folder first, and the file is replaced in one
#     step, so a failure leaves the original in place.
# Flags the app does not manage are kept as they are.

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Strings and the structural characters of a JSON text, with their positions.
# Numbers and literals are skipped: they never change the nesting. A regex
# pass is fast even on a Local State of a few megabytes.
$script:JsonTokenPattern = [regex]'"(?:[^"\\]|\\.)*"|[{}\[\],:]'

# Where browser.enabled_labs_experiments sits in a Local State text.
#   Found   the list exists: Start and End bound its [ ... ] (End exclusive)
#   Browser the top-level browser object exists: BrowserOpen is the index of
#           its {, BrowserEmpty whether it has no members yet
# $null when the text is not a JSON object.
function Find-LabsList {
    param([string]$Text)
    $tokens = $script:JsonTokenPattern.Matches($Text)
    if ($tokens.Count -eq 0 -or $tokens[0].Value -ne '{') { return $null }
    $result = [pscustomobject]@{ Found = $false; Start = -1; End = -1; Browser = $false; BrowserOpen = -1; BrowserEmpty = $false }
    $depth = 0
    $browserDepth = -1
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $value = $tokens[$i].Value
        if ($value -eq '{' -or $value -eq '[') { $depth++; continue }
        if ($value -eq '}' -or $value -eq ']') {
            # The browser object closed without the list in it.
            if ($value -eq '}' -and $depth -eq $browserDepth) { return $result }
            $depth--
            continue
        }
        if ($value -eq ',' -or $value -eq ':') { continue }
        # A string: only a key (a string followed by ':') at the level being
        # searched matters.
        $isKey = ($i + 1 -lt $tokens.Count -and $tokens[$i + 1].Value -eq ':')
        if (-not $isKey) { continue }
        if ($depth -eq 1 -and $value -eq '"browser"' -and $browserDepth -lt 0) {
            if ($i + 2 -lt $tokens.Count -and $tokens[$i + 2].Value -eq '{') {
                $result.Browser = $true
                $result.BrowserOpen = $tokens[$i + 2].Index
                $result.BrowserEmpty = ($i + 3 -lt $tokens.Count -and $tokens[$i + 3].Value -eq '}')
                $browserDepth = 2
            }
        } elseif ($depth -eq $browserDepth -and $value -eq '"enabled_labs_experiments"') {
            if ($i + 2 -lt $tokens.Count -and $tokens[$i + 2].Value -eq '[') {
                $open = $i + 2
                $level = 0
                for ($j = $open; $j -lt $tokens.Count; $j++) {
                    if ($tokens[$j].Value -eq '[') { $level++ }
                    elseif ($tokens[$j].Value -eq ']') {
                        $level--
                        if ($level -eq 0) {
                            $result.Found = $true
                            $result.Start = $tokens[$open].Index
                            $result.End = $tokens[$j].Index + 1
                            return $result
                        }
                    }
                }
            }
            return $result
        }
    }
    return $result
}

function ConvertFrom-JsonStringList {
    param([string]$Json)
    $items = @()
    foreach ($m in [regex]::Matches($Json, '"((?:[^"\\]|\\.)*)"')) { $items += [regex]::Unescape($m.Groups[1].Value) }
    return $items
}

function ConvertTo-JsonStringList {
    param([string[]]$Items)
    $quoted = @(foreach ($item in @($Items)) { '"' + ($item -replace '\\', '\\' -replace '"', '\"') + '"' })
    return '[' + ($quoted -join ',') + ']'
}

# The flag list of one Local State file, or $null when the file does not exist
# or cannot be understood.
function Get-LocalStateFlags {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $text = [System.IO.File]::ReadAllText($Path, $script:Utf8NoBom)
    $spot = Find-LabsList -Text $text
    if (-not $spot) { return $null }
    if (-not $spot.Found) { return @() }
    return @(ConvertFrom-JsonStringList -Json $text.Substring($spot.Start, $spot.End - $spot.Start))
}

# The Local State text with its flag list replaced by Entries, or $null when
# the text is not a Local State this code understands.
function Set-LabsListInText {
    param([string]$Text, [string[]]$Entries)
    $spot = Find-LabsList -Text $Text
    if (-not $spot) { return $null }
    $list = ConvertTo-JsonStringList -Items $Entries
    if ($spot.Found) {
        return $Text.Substring(0, $spot.Start) + $list + $Text.Substring($spot.End)
    }
    $member = '"enabled_labs_experiments":' + $list
    if ($spot.Browser) {
        $at = $spot.BrowserOpen + 1
        $insert = if ($spot.BrowserEmpty) { $member } else { $member + ',' }
        return $Text.Substring(0, $at) + $insert + $Text.Substring($at)
    }
    $at = $Text.IndexOf('{') + 1
    $isEmpty = ($Text.Substring($at).Trim() -eq '}')
    $insert = '"browser":{' + $member + '}' + $(if ($isEmpty) { '' } else { ',' })
    return $Text.Substring(0, $at) + $insert + $Text.Substring($at)
}

# The entries a Local State should hold: everything that is there now, minus
# every option of the flags the app manages, plus the Wanted entries.
function Merge-FlagEntries {
    param([string[]]$Current, [string[]]$Managed, [string[]]$Wanted)
    $kept = @(@($Current) | Where-Object { $_ -and ($Managed -notcontains (($_ -split '@')[0])) })
    return [string[]]@(@($kept) + @($Wanted | Where-Object { $_ }) | Select-Object -Unique)
}

# Writes one channel's flag list. Throws when the file cannot be written; the
# caller decides what to report.
function Write-LocalStateFlags {
    param([string]$Channel, [string[]]$Managed, [string[]]$Wanted)
    $path = $script:Channels[$Channel].LocalState
    $text = [System.IO.File]::ReadAllText($path, $script:Utf8NoBom)
    $spot = Find-LabsList -Text $text
    if (-not $spot) { throw "The Local State of $Channel is not in a format this app understands." }
    $current = if ($spot.Found) { @(ConvertFrom-JsonStringList -Json $text.Substring($spot.Start, $spot.End - $spot.Start)) } else { @() }
    $entries = Merge-FlagEntries -Current $current -Managed $Managed -Wanted $Wanted
    if (($current -join "`n") -eq ($entries -join "`n")) { return $false }

    $newText = Set-LabsListInText -Text $text -Entries $entries
    # Read the result back before it goes anywhere near Brave's file.
    $check = Find-LabsList -Text $newText
    $readBack = if ($check -and $check.Found) { @(ConvertFrom-JsonStringList -Json $newText.Substring($check.Start, $check.End - $check.Start)) } else { $null }
    if ($null -eq $readBack -or ($readBack -join "`n") -ne ($entries -join "`n")) { throw "Could not update the flag list in the Local State of $Channel safely." }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = Join-Path (Get-BackupDir -Create) "local-state-$($Channel.ToLowerInvariant())-$stamp.json"
    Copy-Item -LiteralPath $path -Destination $backup -Force
    $temp = "$path.bfo-tmp"
    [System.IO.File]::WriteAllText($temp, $newText, $script:Utf8NoBom)
    [System.IO.File]::Replace($temp, $path, $null)
    Write-BfoLog "Local State backup saved: $backup" 'OK'
    return $true
}

# Channels whose flags the app manages: installed, with a Local State (Brave
# has run at least once).
function Get-FlagChannels {
    return @(Get-DetectedChannels | Where-Object { Test-Path -LiteralPath $script:Channels[$_].LocalState })
}

# The flag entries of the first channel that has a Local State, for loading
# the current state. Empty when none does.
function Get-MachineFlagEntries {
    foreach ($channel in @(Get-FlagChannels)) {
        $entries = Get-LocalStateFlags -Path $script:Channels[$channel].LocalState
        if ($null -ne $entries) { return @($entries) }
    }
    return @()
}

# Writes the ticked flags to every channel. A running channel is skipped and
# reported, never written. Returns what happened per channel.
function Invoke-FlagsApply {
    param([object[]]$Flags)
    $managed = [string[]]@($script:Flags | ForEach-Object { $_.Name })
    $wanted = [string[]]@($Flags | Where-Object { $_.Checked } | ForEach-Object { $_.Entry })
    $results = @()
    foreach ($channel in @(Get-FlagChannels)) {
        if (@(Get-ChannelProcesses $channel).Count -gt 0) {
            Write-BfoLog "[$channel] Brave is running - flags not written. Close it and apply again." 'WARN'
            $results += [pscustomobject]@{ Channel = $channel; Status = 'running' }
            continue
        }
        try {
            $changed = Write-LocalStateFlags -Channel $channel -Managed $managed -Wanted $wanted
            if ($changed) { Write-BfoLog "[$channel] Flags written: $(if ($wanted.Count) { $wanted -join ', ' } else { 'none' })" 'OK' }
            $results += [pscustomobject]@{ Channel = $channel; Status = $(if ($changed) { 'written' } else { 'unchanged' }) }
        } catch {
            Write-BfoLog "[$channel] Flags: $_" 'ERR'
            $results += [pscustomobject]@{ Channel = $channel; Status = 'failed' }
        }
    }
    return $results
}
