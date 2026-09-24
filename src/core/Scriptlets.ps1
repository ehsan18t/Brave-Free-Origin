# ============================================================================
#  Default scriptlet engine: scanning Brave filter lists and toggling rules.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

$script:ScriptletUserDataRoots = [ordered]@{
    'Stable'  = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
    'Beta'    = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser-Beta\User Data"
    'Nightly' = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser-Nightly\User Data"
    'Dev'     = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser-Dev\User Data"
}
$script:ScriptletDisablePrefix = '! BFO disabled: '
$script:ScriptletRules = @()
$script:ScriptletVisibleRules = @()
$script:ScriptletScanState = $null
$script:ScriptletScanTimer = $null
$script:ScriptletRenderState = $null
$script:ScriptletRenderTimer = $null
$script:ScriptletFilterTimer = $null
$script:ScriptletCheckedKeys = @{}
$script:SuppressScriptletStatusEvents = $false
$script:ScriptletComponentNames = @{
    'iodkpdagapdfkphljnddpjlldadblomo' = 'uBlock filters'
    'adcocjohghhfpidemphmcmlmhnfgikei' = 'Brave Firstparty specific filters'
    'cdbbhgbmjhfnhnmgeddbliobbofkgdhe' = 'EasyList Cookie'
    'kihnoaefogbkmblfimmibknnmkllbhlf' = 'EasyPrivacy'
    'flnkmpokemfpaajmiimmjeiandgoodgg' = 'AdGuard French'
}

function Get-ScriptletDefaultRoot {
    $channel = if ($script:TargetChannels -and $script:TargetChannels.Count -gt 0) { $script:TargetChannels[0] } else { 'Stable' }
    if ($script:ScriptletUserDataRoots.Contains($channel)) { return $script:ScriptletUserDataRoots[$channel] }
    return $script:ScriptletUserDataRoots['Stable']
}

function Get-ScriptletComponentInfo {
    param([string]$File, [string]$Root)

    $componentId = 'unknown'
    $version = 'unknown'
    $source = 'Unknown filter list'
    try {
        $full = [System.IO.Path]::GetFullPath($File)
        $base = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
        if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relative = $full.Substring($base.Length)
            $parts = $relative -split '[\\/]'
            if ($parts.Count -ge 1) { $componentId = $parts[0] }
            if ($parts.Count -ge 2) { $version = $parts[1] }
        }
        if ($script:ScriptletComponentNames.ContainsKey($componentId)) {
            $source = $script:ScriptletComponentNames[$componentId]
        } elseif ($componentId -ne 'unknown') {
            $source = $componentId
        }
    } catch {}

    return [pscustomobject]@{
        ComponentId = $componentId
        Version     = $version
        Source      = $source
    }
}

function Get-BfoDisabledScriptletRule {
    param([string]$Line)
    if ($Line -match '^\s*!\s*BFO disabled:\s*(?<rule>.+)$') {
        return $Matches.rule.Trim()
    }
    return $null
}

function Get-ScriptletRuleFromLine {
    param([string]$Line)
    $disabled = Get-BfoDisabledScriptletRule -Line $Line
    if ($disabled) { return $disabled }

    $trimmed = $Line.Trim()
    if ($trimmed.StartsWith('!')) { return $null }
    return $trimmed
}

function ConvertTo-ScriptletRecord {
    param(
        [string]$File,
        [string]$Root,
        [string]$Line,
        [int]$LineNumber
    )

    # Nearly every line of a filter list is not a scriptlet rule. Any accepted
    # rule is a substring of the line, so this cheap check cannot reject one.
    if ($Line.IndexOf('##+js(', [System.StringComparison]::Ordinal) -lt 0) { return $null }

    $disabledRule = Get-BfoDisabledScriptletRule -Line $Line
    $enabled = -not [bool]$disabledRule
    $rule = if ($disabledRule) { $disabledRule } else { $Line.Trim() }
    if ([string]::IsNullOrWhiteSpace($rule)) { return $null }
    if ($rule.StartsWith('!')) { return $null }
    if ($rule -notmatch '##\+js\((?<body>.*)\)') { return $null }

    # The regex above guarantees the marker is present.
    $marker = $rule.IndexOf('##+js(', [System.StringComparison]::Ordinal)
    $domain = $rule.Substring(0, $marker)
    $body = $Matches.body
    $arguments = ''
    $comma = $body.IndexOf(',')
    if ($comma -ge 0) {
        $scriptlet = $body.Substring(0, $comma).Trim()
        $arguments = $body.Substring($comma + 1).Trim()
    } else {
        $scriptlet = $body.Trim()
    }

    $info = Get-ScriptletComponentInfo -File $File -Root $Root
    return [pscustomobject]@{
        Enabled     = $enabled
        Domain      = $domain
        Scriptlet   = $scriptlet
        Arguments   = $arguments
        Source      = $info.Source
        ComponentId = $info.ComponentId
        Version     = $info.Version
        File        = $File
        LineNumber  = $LineNumber
        Rule        = $rule
    }
}

function Get-ScriptletListFiles {
    param([string]$Root)

    if ([string]::IsNullOrWhiteSpace($Root)) { throw 'User Data folder is empty.' }
    if (-not (Test-Path $Root)) { throw "User Data folder not found: $Root" }

    $files = @()
    $componentDirs = @(Get-ChildItem -Path $Root -Directory -ErrorAction Stop | Where-Object { $_.Name -match '^[a-z]{32}$' })
    foreach ($dir in $componentDirs) {
        try {
            $files += Get-ChildItem -Path $dir.FullName -Recurse -Filter 'list.txt' -File -ErrorAction Stop
        } catch {
            Write-Log "Scriptlet scan skipped $($dir.FullName): $_" 'WARN'
        }
    }
    return @($files | Sort-Object FullName)
}

function Backup-ScriptletFile {
    param([string]$File)

    if (-not (Test-Path $File)) { throw "Scriptlet list file not found: $File" }
    $backup = "$File.bfo-backup"
    if (-not (Test-Path $backup)) {
        Copy-Item -LiteralPath $File -Destination $backup -Force
        Write-Log "Scriptlet backup created: $backup" 'OK'
    }
    return $backup
}

function Test-ScriptletAdvancedWriteAllowed {
    if (-not $script:ChkScriptletAdvanced -or -not $script:ChkScriptletAdvanced.Checked) {
        Show-BfoMessage 'msg.scriptlet.locked' -TitleKey 'msg.title.scriptlet' -Icon Warning
        return $false
    }

    # Brave may rewrite or cache the lists while running; editing them then is
    # allowed, but only after the user confirms.
    $braveProcesses = @(Get-Process -Name brave -ErrorAction SilentlyContinue)
    if ($braveProcesses.Count -gt 0) {
        return (Show-BfoMessage 'msg.scriptlet.braveRunning' @($braveProcesses.Count) -TitleKey 'msg.title.scriptlet' -Icon Warning -YesNo)
    }

    return $true
}

# Brave's filter lists are edited in place without disturbing anything else:
# each line keeps its own ending (LF or CRLF) and a missing final newline stays
# missing, so a save changes only the lines that were actually edited. Lines is
# a string[] that callers edit in place; Crlf remembers which lines ended in CR.
function Read-ScriptletListFile {
    param([string]$Path)
    $parts = [System.IO.File]::ReadAllText($Path) -split "`n"
    $crlf = New-Object bool[] $parts.Length
    for ($i = 0; $i -lt $parts.Length; $i++) {
        if ($parts[$i].EndsWith("`r")) {
            $crlf[$i] = $true
            $parts[$i] = $parts[$i].Substring(0, $parts[$i].Length - 1)
        }
    }
    return [pscustomobject]@{ Lines = [string[]]$parts; Crlf = $crlf }
}

function Write-ScriptletListFile {
    param([string]$Path, $Document)
    $text = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $Document.Lines.Length; $i++) {
        if ($i -gt 0) { [void]$text.Append("`n") }
        [void]$text.Append($Document.Lines[$i])
        if ($Document.Crlf[$i]) { [void]$text.Append("`r") }
    }
    [System.IO.File]::WriteAllText($Path, $text.ToString(), (New-Object System.Text.UTF8Encoding($false)))
}

# Enables or disables the rule on one line of a list file, in place: disabling
# comments it out behind the BFO marker, enabling restores the original rule.
# Returns $true when the line changed.
function Set-ScriptletLine {
    param([string[]]$Lines, [int]$Index, [bool]$Enable)
    $disabledRule = Get-BfoDisabledScriptletRule -Line $Lines[$Index]
    if ($Enable -and $disabledRule) {
        $Lines[$Index] = $disabledRule
        return $true
    }
    if (-not $Enable -and -not $disabledRule) {
        $Lines[$Index] = "$($script:ScriptletDisablePrefix)$(Get-ScriptletRuleFromLine -Line $Lines[$Index])"
        return $true
    }
    return $false
}

function Set-ScriptletRuleState {
    param(
        [object[]]$Records,
        [bool]$Enable,
        [bool]$AffectDuplicates
    )

    if (-not $Records -or $Records.Count -eq 0) { return 0 }
    $changed = 0
    $byFile = $Records | Group-Object File

    foreach ($group in $byFile) {
        $file = $group.Name
        $doc = Read-ScriptletListFile -Path $file
        $lines = $doc.Lines
        $fileChanges = 0

        if ($AffectDuplicates) {
            # Every line carrying one of the selected rules, wherever it is.
            $wanted = @{}
            foreach ($record in $group.Group) { $wanted[$record.Rule] = $true }
            for ($i = 0; $i -lt $lines.Length; $i++) {
                $original = Get-ScriptletRuleFromLine -Line $lines[$i]
                if (-not $original -or -not $wanted.ContainsKey($original)) { continue }
                if (Set-ScriptletLine -Lines $lines -Index $i -Enable $Enable) { $fileChanges++ }
            }
        } else {
            # Only the exact lines selected, and only if they still hold that rule.
            foreach ($record in $group.Group) {
                $idx = [int]$record.LineNumber - 1
                if ($idx -lt 0 -or $idx -ge $lines.Length) { continue }
                if ((Get-ScriptletRuleFromLine -Line $lines[$idx]) -ne $record.Rule) { continue }
                if (Set-ScriptletLine -Lines $lines -Index $idx -Enable $Enable) { $fileChanges++ }
            }
        }

        # A file with nothing to change is neither backed up nor rewritten.
        if ($fileChanges -gt 0) {
            [void](Backup-ScriptletFile -File $file)
            Write-ScriptletListFile -Path $file -Document $doc
            $changed += $fileChanges
        }
    }

    return $changed
}

function Restore-ScriptletBackup {
    param([string]$File)

    $backup = "$File.bfo-backup"
    if (-not (Test-Path $backup)) { throw "No backup exists for: $File" }
    Copy-Item -LiteralPath $backup -Destination $File -Force
}

function Restore-AllScriptletBackups {
    param([string]$Root)

    if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path $Root)) { throw "User Data folder not found: $Root" }
    $backups = @(Get-ChildItem -Path $Root -Recurse -Filter 'list.txt.bfo-backup' -File -ErrorAction SilentlyContinue)
    $count = 0
    foreach ($backup in $backups) {
        $target = $backup.FullName.Substring(0, $backup.FullName.Length - '.bfo-backup'.Length)
        Copy-Item -LiteralPath $backup.FullName -Destination $target -Force
        $count++
    }
    return $count
}

function Export-ScriptletDisabledPreferences {
    param([string]$File)

    $disabled = @($script:ScriptletRules | Where-Object { -not $_.Enabled } | Sort-Object Rule -Unique)
    $payload = [ordered]@{
        version       = '1.9'
        exported      = (Get-Date -Format 's')
        disabledRules = @(
            foreach ($r in $disabled) {
                [ordered]@{
                    rule      = $r.Rule
                    domain    = $r.Domain
                    scriptlet = $r.Scriptlet
                    source    = $r.Source
                }
            }
        )
    }
    $payload | ConvertTo-Json -Depth 5 | Set-Content -Path $File -Encoding UTF8
    return $disabled.Count
}

function Import-ScriptletPreferencesAndReapply {
    param([string]$PrefsFile, [string]$Root)

    if (-not (Test-Path $PrefsFile)) { throw "Preference file not found: $PrefsFile" }
    $prefs = Get-Content $PrefsFile -Raw | ConvertFrom-Json
    if (-not $prefs.disabledRules) { throw 'Preference file has no disabledRules array.' }

    $wanted = @{}
    foreach ($entry in $prefs.disabledRules) {
        if ($entry.rule) { $wanted["$($entry.rule)"] = $true }
    }
    if ($wanted.Count -eq 0) { return 0 }

    $changed = 0
    foreach ($file in (Get-ScriptletListFiles -Root $Root)) {
        $doc = Read-ScriptletListFile -Path $file.FullName
        $lines = $doc.Lines
        $fileChanged = $false
        for ($i = 0; $i -lt $lines.Length; $i++) {
            $original = Get-ScriptletRuleFromLine -Line $lines[$i]
            if (-not $original -or -not $wanted.ContainsKey($original)) { continue }
            if (Get-BfoDisabledScriptletRule -Line $lines[$i]) { continue }
            # Backed up lazily: files with nothing to disable are never touched.
            if (-not $fileChanged) {
                [void](Backup-ScriptletFile -File $file.FullName)
                $fileChanged = $true
            }
            [void](Set-ScriptletLine -Lines $lines -Index $i -Enable $false)
            $changed++
        }
        if ($fileChanged) {
            Write-ScriptletListFile -Path $file.FullName -Document $doc
        }
    }
    return $changed
}
