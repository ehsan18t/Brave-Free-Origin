# ============================================================================
#  Brave's own settings files: reading and writing single prefs in each
#  profile's Preferences and each channel's Local State.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# A tweak that Brave shows as a toggle in its settings is not locked by a
# policy: Apply writes the chosen value where Brave's own toggle would, so it
# takes effect at once and stays changeable in Brave (see core\Apply.ps1).
# Each value is written once, when the row is new or its value changed; after
# that, whatever Brave holds is the user's choice and no later Apply touches
# it (Select-FreshPrefs).
# Both files are Brave's own and Brave rewrites them on exit, so the rules of
# core\Flags.ps1 apply here too:
#   * a channel's files are only written while that channel is closed;
#   * only the members being set are touched: the text is scanned, each value
#     is swapped or inserted in place and every other byte is written back
#     exactly as it was read;
#   * the file is replaced in one step, so a failure leaves the original.
# A pref path is an array of member names from the top of the file, for
# example @('brave', 'de_amp', 'enabled'). Names are matched exactly, so a
# name with a dot in it, such as a content setting pattern '*,*', is one step.

# Strings and the structural characters of a JSON text, with their positions.
$script:PrefTokenPattern = [regex]'"(?:[^"\\]|\\.)*"|[{}\[\],:]'

function ConvertTo-JsonStringLiteral {
    param([string]$Value)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in $Value.ToCharArray()) {
        switch ($ch) {
            '"'  { [void]$sb.Append('\"') }
            '\'  { [void]$sb.Append('\\') }
            "`n" { [void]$sb.Append('\n') }
            "`r" { [void]$sb.Append('\r') }
            "`t" { [void]$sb.Append('\t') }
            default {
                if ([int]$ch -lt 0x20) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) } else { [void]$sb.Append($ch) }
            }
        }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

# The JSON text for a value: $true/$false, whole numbers, strings, arrays of
# those, and hashtables (written in key order, for content setting entries).
function ConvertTo-PrefJson {
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [int] -or $Value -is [long]) { return ([string]$Value) }
    if ($Value -is [string]) { return (ConvertTo-JsonStringLiteral $Value) }
    if ($Value -is [System.Collections.IDictionary]) {
        $members = @(foreach ($k in $Value.Keys) { (ConvertTo-JsonStringLiteral ([string]$k)) + ':' + (ConvertTo-PrefJson $Value[$k]) })
        return '{' + ($members -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return '[' + (@(foreach ($v in $Value) { ConvertTo-PrefJson $v }) -join ',') + ']'
    }
    throw "A pref value of type $($Value.GetType().Name) is not supported."
}

# The members of the object whose { is token Open: an ordered list of
#   Name       the member name, unescaped
#   KeyIndex   character index of the name's opening quote
#   ValueStart, ValueEnd   the value's characters (End exclusive), trimmed
#   ValueOpen  token index of the value's { when it is an object, else -1
#   Next       token index of the , or } that ends the member
# and Close, the token index of the object's }.
function Get-JsonObjectMembers {
    param([string]$Text, $Tokens, [int]$Open)
    $members = New-Object System.Collections.Generic.List[object]
    $i = $Open + 1
    while ($i -lt $Tokens.Count) {
        $t = $Tokens[$i].Value
        if ($t -eq '}') { return [pscustomobject]@{ Members = $members; Close = $i } }
        if ($t -eq ',') { $i++; continue }
        if (-not $t.StartsWith('"') -or $i + 1 -ge $Tokens.Count -or $Tokens[$i + 1].Value -ne ':') { throw 'Not a JSON object.' }
        $name = [regex]::Unescape($t.Substring(1, $t.Length - 2))
        $keyIndex = $Tokens[$i].Index
        $colonEnd = $Tokens[$i + 1].Index + 1
        $j = $i + 2
        $valueOpen = -1
        # Walk to the , or } that ends this member, at this object's level.
        $depth = 0
        $first = if ($j -lt $Tokens.Count) { $Tokens[$j].Value } else { '' }
        if ($first -eq '{') { $valueOpen = $j }
        while ($j -lt $Tokens.Count) {
            $v = $Tokens[$j].Value
            if ($v -eq '{' -or $v -eq '[') { $depth++ }
            elseif ($v -eq '}' -or $v -eq ']') {
                if ($depth -eq 0) { break }
                $depth--
            } elseif ($v -eq ',' -and $depth -eq 0) { break }
            $j++
        }
        if ($j -ge $Tokens.Count) { throw 'Unterminated JSON object.' }
        $raw = $Text.Substring($colonEnd, $Tokens[$j].Index - $colonEnd)
        $lead = $raw.Length - $raw.TrimStart().Length
        $start = $colonEnd + $lead
        $end = $start + $raw.Trim().Length
        $members.Add([pscustomobject]@{ Name = $name; KeyIndex = $keyIndex; ValueStart = $start; ValueEnd = $end; ValueOpen = $valueOpen; Next = $j })
        $i = $j
    }
    throw 'Unterminated JSON object.'
}

# Follows Path from the top object. Returns the deepest object reached:
#   Found    the whole path exists; Member is the last step
#   Open     token index of the { of the deepest object reached
#   Depth    how many steps of Path were found
#   Members  that object's members (see Get-JsonObjectMembers)
function Find-JsonPath {
    param([string]$Text, $Tokens, [string[]]$Path)
    if ($Tokens.Count -eq 0 -or $Tokens[0].Value -ne '{') { throw 'Not a JSON object.' }
    $open = 0
    for ($d = 0; $d -lt $Path.Count; $d++) {
        $info = Get-JsonObjectMembers -Text $Text -Tokens $Tokens -Open $open
        $member = $null
        foreach ($m in $info.Members) { if ($m.Name -ceq $Path[$d]) { $member = $m; break } }
        if (-not $member) { return [pscustomobject]@{ Found = $false; Open = $open; Depth = $d; Members = $info.Members; Member = $null } }
        if ($d -eq $Path.Count - 1) { return [pscustomobject]@{ Found = $true; Open = $open; Depth = $Path.Count; Members = $info.Members; Member = $member } }
        # Something that is not an object is in the way: treated as missing,
        # and Set-JsonPathInText refuses to overwrite it.
        if ($member.ValueOpen -lt 0) { return [pscustomobject]@{ Found = $false; Open = $open; Depth = $d; Members = $info.Members; Member = $member; Blocked = $true } }
        $open = $member.ValueOpen
    }
    throw 'An empty pref path.'
}

# The raw JSON text of the value at Path, or $null when it is not there.
function Get-JsonPathText {
    param([string]$Text, [string[]]$Path)
    $tokens = $script:PrefTokenPattern.Matches($Text)
    $spot = Find-JsonPath -Text $Text -Tokens $tokens -Path $Path
    if (-not $spot.Found) { return $null }
    return $Text.Substring($spot.Member.ValueStart, $spot.Member.ValueEnd - $spot.Member.ValueStart)
}

# Text with the value at Path set to ValueJson, creating the objects on the
# way. Throws rather than replace something that is not an object.
function Set-JsonPathInText {
    param([string]$Text, [string[]]$Path, [string]$ValueJson)
    $tokens = $script:PrefTokenPattern.Matches($Text)
    $spot = Find-JsonPath -Text $Text -Tokens $tokens -Path $Path
    if ($spot.Found) {
        $m = $spot.Member
        return $Text.Substring(0, $m.ValueStart) + $ValueJson + $Text.Substring($m.ValueEnd)
    }
    if ($spot.Blocked) { throw "$($Path[0..$spot.Depth] -join '.') is not an object." }
    # Build the missing steps inside out and insert them first in the object.
    $value = $ValueJson
    for ($d = $Path.Count - 1; $d -gt $spot.Depth; $d--) { $value = '{' + (ConvertTo-JsonStringLiteral $Path[$d]) + ':' + $value + '}' }
    $member = (ConvertTo-JsonStringLiteral $Path[$spot.Depth]) + ':' + $value
    $at = $tokens[$spot.Open].Index + 1
    if ($spot.Members.Count -gt 0) { $member += ',' }
    return $Text.Substring(0, $at) + $member + $Text.Substring($at)
}

# Text without the member at Path, or the text unchanged when it is not there.
function Remove-JsonPathInText {
    param([string]$Text, [string[]]$Path)
    $tokens = $script:PrefTokenPattern.Matches($Text)
    $spot = Find-JsonPath -Text $Text -Tokens $tokens -Path $Path
    if (-not $spot.Found) { return $Text }
    $m = $spot.Member
    $index = $spot.Members.IndexOf($m)
    $next = $tokens[$m.Next]
    if ($next.Value -eq ',') {
        # Remove from the name through the comma after the value.
        $end = $next.Index + 1
        return $Text.Substring(0, $m.KeyIndex) + $Text.Substring($end)
    }
    if ($index -gt 0) {
        # The last member: remove the comma before it too.
        $prev = $spot.Members[$index - 1]
        return $Text.Substring(0, $prev.ValueEnd) + $Text.Substring($m.ValueEnd)
    }
    return $Text.Substring(0, $m.KeyIndex) + $Text.Substring($m.ValueEnd)
}

# ---- Files --------------------------------------------------------------------

# One file's text after a list of edits, each @{ Path = [string[]]; Json =
# text } to set or @{ Path; Delete = $true }. Every edit is read back before
# the text is accepted, so a mistake in this code cannot reach Brave's file.
# Read with the indexer: $edit.Remove would find Hashtable.Remove().
function Update-PrefText {
    param([string]$Text, [object[]]$Edits)
    $new = $Text
    foreach ($e in $Edits) {
        if ($e['Delete']) { $new = Remove-JsonPathInText -Text $new -Path $e.Path }
        else { $new = Set-JsonPathInText -Text $new -Path $e['Path'] -ValueJson $e['Json'] }
    }
    foreach ($e in $Edits) {
        $back = Get-JsonPathText -Text $new -Path $e.Path
        $ok = if ($e['Delete']) { $null -eq $back } else { $back -eq $e.Json }
        if (-not $ok) { throw "Could not update $($e.Path -join '.') safely." }
    }
    return $new
}

# Applies edits to a file and replaces it in one step. Returns $true when the
# file changed. Throws when it cannot be read, understood or written.
function Update-PrefFile {
    param([string]$Path, [object[]]$Edits)
    $text = [System.IO.File]::ReadAllText($Path, $script:Utf8NoBom)
    $new = Update-PrefText -Text $text -Edits $Edits
    if ($new -ceq $text) { return $false }
    $temp = "$Path.bfo-tmp"
    [System.IO.File]::WriteAllText($temp, $new, $script:Utf8NoBom)
    [System.IO.File]::Replace($temp, $Path, [NullString]::Value)
    return $true
}

# The raw JSON of each path in one file, name -> text or $null. Empty when the
# file is missing or cannot be understood.
function Read-PrefValues {
    param([string]$Path, [hashtable]$Paths)
    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $values }
    try {
        $text = [System.IO.File]::ReadAllText($Path, $script:Utf8NoBom)
        foreach ($k in $Paths.Keys) { $values[$k] = Get-JsonPathText -Text $text -Path $Paths[$k] }
    } catch { Write-Verbose "Cannot read ${Path}: $_" }
    return $values
}

# ---- Profiles -------------------------------------------------------------------

# The profile folders of one channel that have a Preferences file: the ones
# Local State lists, plus any other folder that has one.
function Get-ChannelProfiles {
    param([string]$Channel)
    $userData = Split-Path -Parent $script:Channels[$Channel].LocalState
    if (-not (Test-Path -LiteralPath $userData)) { return @() }
    $names = @()
    try {
        $text = [System.IO.File]::ReadAllText($script:Channels[$Channel].LocalState, $script:Utf8NoBom)
        $tokens = $script:PrefTokenPattern.Matches($text)
        $spot = Find-JsonPath -Text $text -Tokens $tokens -Path @('profile', 'info_cache')
        if ($spot.Found -and $spot.Member.ValueOpen -ge 0) {
            $names = @((Get-JsonObjectMembers -Text $text -Tokens $tokens -Open $spot.Member.ValueOpen).Members | ForEach-Object { $_.Name })
        }
    } catch { Write-Verbose "Profile list of $Channel not read: $_" }
    $dirs = @(Get-ChildItem -LiteralPath $userData -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' } | ForEach-Object { $_.Name })
    $all = @(@($names) + @($dirs) | Select-Object -Unique)
    return @(foreach ($n in $all) {
        $prefs = Join-Path (Join-Path $userData $n) 'Preferences'
        if (Test-Path -LiteralPath $prefs) { [pscustomobject]@{ Channel = $Channel; Name = $n; Preferences = $prefs } }
    })
}

# Every profile of every channel the app writes prefs to.
function Get-PrefTargets {
    return @(foreach ($channel in @(Get-FlagChannels)) { Get-ChannelProfiles $channel })
}

# ---- What Apply writes ------------------------------------------------------------

# Chromium's time stamps: microseconds since 1601-01-01 UTC, as text.
function Get-ChromiumTimeText {
    return ([string]([long]([DateTime]::UtcNow.ToFileTimeUtc() / 10)))
}

# The JSON a pref gets for a policy value (see ConvertTo-PolicyPref in
# core\Tweaks.ps1 for the fields).
function ConvertTo-PrefValueJson {
    param($Pref, $PolicyValue)
    if ($Pref['Item']) {
        $value = (@($PolicyValue) -contains $Pref['Item'])
    } elseif ($Pref.Map -is [hashtable]) {
        $key = [int]$PolicyValue
        if (-not $Pref.Map.ContainsKey($key)) { throw "No pref value for $PolicyValue at $($Pref.Path -join '.')." }
        $value = $Pref.Map[$key]
    } elseif ($Pref.Map -eq 'same') {
        $value = if ($PolicyValue -is [string]) { [string]$PolicyValue } else { [int]$PolicyValue }
    } else {
        $value = ([int]$PolicyValue -ne 0)
    }
    # A Shields default is the rule for every site, stored the way Brave's
    # own Shields settings store it.
    if ($Pref.Rule) { $value = [ordered]@{ last_modified = (Get-ChromiumTimeText); setting = $value } }
    return (ConvertTo-PrefJson $value)
}

# Two pref values compared as Brave stores them: layout and a rule's time
# stamp do not count.
function Test-PrefJsonEqual {
    param([string]$A, [string]$B)
    if ([string]::IsNullOrEmpty($A) -or [string]::IsNullOrEmpty($B)) { return ([string]::IsNullOrEmpty($A) -and [string]::IsNullOrEmpty($B)) }
    $pattern = '"last_modified":"\d*",?'
    $a1 = ($A -replace '\s+', '') -replace $pattern, ''
    $b1 = ($B -replace '\s+', '') -replace $pattern, ''
    return ($a1 -ceq $b1)
}

function ConvertFrom-PrefKey {
    param([string]$Key)
    $parts = $Key -split '\|'
    return [pscustomobject]@{ File = $parts[0]; Path = [string[]]@($parts | Select-Object -Skip 1) }
}

# The prefs a selection wants written, one entry per pref: Name (the policy),
# Key, File, Path and Json. Only ticked rows that are not mandatory write
# prefs: a mandatory policy already wins over anything stored.
function Get-DesiredPrefs {
    param($Selection)
    $lock = [bool]$Selection.Lock
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($p in $Selection.Policies) {
        if (-not $p.Checked) { continue }
        $policy = $script:PolicyByName[$p.Name]
        if (-not $policy -or (Get-PolicyLevel -Policy $policy -Lock $lock) -eq 'mandatory') { continue }
        foreach ($pref in $policy.Prefs) {
            if ($pref.Protected) { continue }
            $list.Add([pscustomobject]@{ Name = $p.Name; Key = $pref.Key; File = $pref.File; Path = $pref.Path; Json = (ConvertTo-PrefValueJson -Pref $pref -PolicyValue $p.Value) })
        }
    }
    return $list.ToArray()
}

# The prefs an earlier Apply wrote that this selection no longer wants, from
# the record (core\Drift.ps1): Name, Key, File, Path and Json (the value the
# app wrote). A policy that is ticked but now locked keeps its prefs: the
# mandatory policy covers them and unlocking again rewrites them.
function Get-StalePrefs {
    param($Selection, $Previous, [object[]]$Desired)
    $list = New-Object System.Collections.Generic.List[object]
    if (-not $Previous -or -not $Previous.prefs) { return $list.ToArray() }
    $wanted = @{}
    foreach ($d in $Desired) { $wanted["$($d.Name)|$($d.Key)"] = $true }
    $checked = @{}
    foreach ($p in $Selection.Policies) { if ($p.Checked) { $checked[$p.Name] = $true } }
    foreach ($policy in $Previous.prefs.PSObject.Properties) {
        $lockedNow = $checked.ContainsKey($policy.Name) -and @($Desired | Where-Object { $_.Name -eq $policy.Name }).Count -eq 0
        if ($lockedNow) { continue }
        foreach ($entry in $policy.Value.PSObject.Properties) {
            if ($wanted.ContainsKey("$($policy.Name)|$($entry.Name)")) { continue }
            $spot = ConvertFrom-PrefKey $entry.Name
            $list.Add([pscustomobject]@{ Name = $policy.Name; Key = $entry.Name; File = $spot.File; Path = $spot.Path; Json = [string]$entry.Value })
        }
    }
    return $list.ToArray()
}

# The edits for one file: set every desired pref that does not already hold
# its value, and remove each stale one that still holds exactly what the app
# wrote (a value the user picked in Brave since is theirs and stays).
function Get-PrefFileEdits {
    param([string]$Text, [object[]]$Desired, [object[]]$Stale)
    $edits = @()
    foreach ($d in $Desired) {
        if (-not (Test-PrefJsonEqual (Get-JsonPathText -Text $Text -Path $d.Path) $d.Json)) { $edits += @{ Path = $d.Path; Json = $d.Json } }
    }
    foreach ($s in $Stale) {
        $current = Get-JsonPathText -Text $Text -Path $s.Path
        if ($null -ne $current -and (Test-PrefJsonEqual $current $s.Json)) { $edits += @{ Path = $s.Path; Delete = $true } }
    }
    return $edits
}

# Writes the desired prefs and removes the stale ones in one file. Returns
# $true when the file changed.
function Update-PrefTarget {
    param([string]$Path, [object[]]$Desired, [object[]]$Stale)
    if (@($Desired).Count -eq 0 -and @($Stale).Count -eq 0) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $text = [System.IO.File]::ReadAllText($Path, $script:Utf8NoBom)
    $edits = @(Get-PrefFileEdits -Text $text -Desired $Desired -Stale $Stale)
    if ($edits.Count -eq 0) { return $false }
    return (Update-PrefFile -Path $Path -Edits $edits)
}

# The desired prefs an earlier Apply has not written yet: new rows and changed
# values. One the record already holds with this value was written before,
# and whatever Brave holds for it now is the user's own choice, so Apply
# leaves it alone: a change made in Brave wins over every later Apply.
function Select-FreshPrefs {
    param([object[]]$Desired, $Previous)
    return @(foreach ($d in $Desired) {
        $was = $null
        if ($Previous -and $Previous.prefs) {
            $policy = $Previous.prefs.PSObject.Properties[$d.Name]
            if ($policy) { $entry = $policy.Value.PSObject.Properties[$d.Key]; if ($entry) { $was = [string]$entry.Value } }
        }
        if (-not (Test-PrefJsonEqual $was $d.Json)) { $d }
    })
}

# Writes Brave's own prefs for a selection into every profile and the Local
# State of every channel. A running channel is skipped and reported, never
# written, exactly like flags; WriteFiles $false skips them all. Returns
# Results (Channel, Status: written, unchanged, running, failed, none),
# Record, the prefs part of the next record (policy -> key -> JSON), Fresh,
# the prefs this Apply had to write, and Stale, the ones it had to undo.
function Invoke-PrefsApply {
    param($Selection, $Previous, [bool]$WriteFiles = $true)
    $desired = @(Get-DesiredPrefs -Selection $Selection)
    $fresh = @(Select-FreshPrefs -Desired $desired -Previous $Previous)
    $stale = @(Get-StalePrefs -Selection $Selection -Previous $Previous -Desired $desired)
    $results = @()
    $channels = @(Get-FlagChannels)
    foreach ($channel in $channels) {
        if (-not $WriteFiles -or @(Get-ChannelProcesses $channel).Count -gt 0) {
            if ($fresh.Count + $stale.Count -gt 0) { Write-BfoLog "[$channel] Brave is running - its settings files were not written. Close it and apply again." 'WARN' }
            $results += [pscustomobject]@{ Channel = $channel; Status = 'running' }
            continue
        }
        $changed = $false
        $failed = $false
        # Local State first, then each profile on its own: one file Brave
        # cannot take does not stop the others.
        $targets = @([pscustomobject]@{ Name = 'Local State'; Path = $script:Channels[$channel].LocalState; File = 'LocalState' })
        $targets += @(Get-ChannelProfiles $channel | ForEach-Object { [pscustomobject]@{ Name = "profile $($_.Name)"; Path = $_.Preferences; File = 'Profile' } })
        foreach ($target in $targets) {
            try {
                $mine = @($fresh | Where-Object { $_.File -eq $target.File })
                $old = @($stale | Where-Object { $_.File -eq $target.File })
                if (Update-PrefTarget -Path $target.Path -Desired $mine -Stale $old) {
                    $changed = $true
                    Write-BfoLog "[$channel] Brave settings written to $($target.Name)" 'OK'
                }
            } catch {
                $failed = $true
                Write-BfoLog "[$channel] Brave settings in $($target.Name): $_" 'ERR'
            }
        }
        $status = if ($failed) { 'failed' } elseif ($changed) { 'written' } else { 'unchanged' }
        $results += [pscustomobject]@{ Channel = $channel; Status = $status }
    }
    # Brave has never run: there is nothing to write the prefs into yet.
    if ($channels.Count -eq 0 -and $fresh.Count + $stale.Count -gt 0) {
        Write-BfoLog 'Brave has not created a profile yet, so its settings could not be written. Start Brave once, close it and apply again.' 'WARN'
        $results += [pscustomobject]@{ Channel = 'none'; Status = 'none' }
    }

    # The record keeps what is in place: every desired pref once all were
    # written, else only those written by an earlier Apply (the rest are
    # written next time). It also keeps the earlier prefs of rows that are
    # locked now and, while a channel could not be written, the stale prefs
    # still to undo.
    $pending = @($results | Where-Object { $_.Status -ne 'written' -and $_.Status -ne 'unchanged' }).Count -gt 0
    $record = [ordered]@{}
    foreach ($d in $desired) {
        if ($pending -and @($fresh | Where-Object { $_.Name -eq $d.Name -and $_.Key -eq $d.Key }).Count -gt 0) { continue }
        if (-not $record.Contains($d.Name)) { $record[$d.Name] = [ordered]@{} }
        $record[$d.Name][$d.Key] = $d.Json
    }
    if ($Previous -and $Previous.prefs) {
        $staleKeys = @{}
        foreach ($s in $stale) { $staleKeys["$($s.Name)|$($s.Key)"] = $true }
        foreach ($policy in $Previous.prefs.PSObject.Properties) {
            foreach ($entry in $policy.Value.PSObject.Properties) {
                if ($record.Contains($policy.Name) -and $record[$policy.Name].Contains($entry.Name)) { continue }
                if ($staleKeys.ContainsKey("$($policy.Name)|$($entry.Name)") -and -not $pending) { continue }
                if (-not $record.Contains($policy.Name)) { $record[$policy.Name] = [ordered]@{} }
                $record[$policy.Name][$entry.Name] = [string]$entry.Value
            }
        }
    }
    return [pscustomobject]@{ Results = $results; Record = $record; Desired = $desired; Fresh = $fresh; Stale = $stale }
}

# ---- Reading back --------------------------------------------------------------------

# The first channel that has a Local State and its Default (or first)
# profile: what Load current state and Preview read, like flags.
function Get-PrefReadTarget {
    foreach ($channel in @(Get-FlagChannels)) {
        $profiles = @(Get-ChannelProfiles $channel)
        $default = @($profiles | Where-Object { $_.Name -eq 'Default' })
        $first = if ($default.Count -gt 0) { $default[0] } elseif ($profiles.Count -gt 0) { $profiles[0] } else { $null }
        return [pscustomobject]@{
            Channel = $channel; LocalState = $script:Channels[$channel].LocalState; Profiles = $profiles.Count
            Preferences = $(if ($first) { $first.Preferences } else { $null })
            SecurePreferences = $(if ($first) { Join-Path (Split-Path -Parent $first.Preferences) 'Secure Preferences' } else { $null })
        }
    }
    return $null
}

# The raw JSON of each pref key in the read target, key -> text or $null. A
# Protected pref is looked up in Secure Preferences, where Brave keeps it.
function Read-PrefKeys {
    param([string[]]$Keys, $Target)
    $values = @{}
    if (-not $Target) { return $values }
    $texts = @{}
    foreach ($file in @('LocalState', 'Profile', 'Secure')) {
        $path = switch ($file) { 'LocalState' { $Target.LocalState } 'Profile' { $Target.Preferences } default { $Target.SecurePreferences } }
        $texts[$file] = $null
        if ($path -and (Test-Path -LiteralPath $path)) {
            try { $texts[$file] = [System.IO.File]::ReadAllText($path, $script:Utf8NoBom) } catch { Write-Verbose "Cannot read ${path}: $_" }
        }
    }
    foreach ($key in $Keys) {
        $spot = ConvertFrom-PrefKey $key
        $values[$key] = $null
        $files = if ($spot.File -eq 'Profile') { @('Profile', 'Secure') } else { @($spot.File) }
        foreach ($file in $files) {
            $text = $texts[$file]
            if ($null -eq $text -or $null -ne $values[$key]) { continue }
            try { $values[$key] = Get-JsonPathText -Text $text -Path $spot.Path } catch { Write-Verbose "Cannot read $key." }
        }
    }
    return $values
}
