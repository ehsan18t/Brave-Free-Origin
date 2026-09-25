<#
.SYNOPSIS
    Validates the tweak data in tweaks\ against the app and its string catalog.

.DESCRIPTION
    Loads tweaks\ through the app's own loader (src\core\Tweaks.ps1), so a file
    that passes here is a file the app will accept, then checks what the loader
    alone cannot:

      * policy names are unique across every tweaks\policies file, and every
        policy is in tools\known-policies.psd1 (verified against the Chromium
        and brave-core sources) with the same MinChromium
      * every category, policy, choice, flag, task, service, hosts group,
        retired reason, search engine, destination and startup mode has its
        string in the English catalog (src\strings\en-US.ps1)
      * hosts group ids are unique and every domain looks like a host name
      * modes only name existing policies, flags, hosts groups, startup modes
        and other modes, Include has no cycles, modes never tick a ManualOnly
        hosts group, and old mode ids never map onto Max

    Nothing is written and nothing is applied to the machine.
    Runs on Windows PowerShell 5.1 and on PowerShell 7 with identical results.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\Test-Tweaks.ps1
#>
[CmdletBinding()]
param(
    # Left empty on purpose. $PSScriptRoot is not yet populated while param()
    # default expressions are evaluated under Windows PowerShell 5.1, so a
    # default of (Join-Path $PSScriptRoot ...) makes the script unusable
    # without explicit paths. Defaults are resolved in the body instead.
    [string]$AppRoot
)

$ErrorActionPreference = 'Stop'

if (-not $AppRoot) { $AppRoot = Split-Path -Parent $PSScriptRoot }

$script:failures = @()
function Add-Failure { param([string]$Message) $script:failures += $Message }

# ---- English catalog ---------------------------------------------------------
# Parsed, never executed: the same extraction Test-Locales.ps1 uses.
$catalogPath = Join-Path $AppRoot 'src\strings\en-US.ps1'
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($catalogPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors) { throw "$catalogPath does not parse." }
$english = @{}
$calls = $ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -eq 'Add-Strings'
}, $true)
foreach ($call in $calls) {
    $table = $call.CommandElements |
             Where-Object { $_ -is [System.Management.Automation.Language.HashtableAst] } |
             Select-Object -First 1
    if ($table) { foreach ($pair in $table.KeyValuePairs) { $english[$pair.Item1.SafeGetValue()] = $true } }
}
if ($english.Count -eq 0) { throw 'No Add-Strings blocks found - catalog extraction failed.' }

function Test-Key {
    param([string]$Key, [string]$Where)
    if (-not $english.ContainsKey($Key)) { Add-Failure "$Where needs the string '$Key' in src\strings\en-US.ps1." }
}

# ---- Load through the app ----------------------------------------------------
# These files only define functions and script-scope tables; none touches the
# machine or creates a control.
$script:AppRoot = $AppRoot
$script:StartupError = $null
. (Join-Path $AppRoot 'src\core\Registry.ps1')
. (Join-Path $AppRoot 'src\core\Tweaks.ps1')
if ($script:StartupError) {
    Write-Output $script:StartupError
    exit 1
}
. (Join-Path $AppRoot 'src\core\SearchStartup.ps1')
. (Join-Path $AppRoot 'src\core\Presets.ps1')

# ---- Tags --------------------------------------------------------------------
# The loader already rejects unknown tags; here every tag needs its wording.
foreach ($id in $script:EffectIds) { Test-Key "effect.$id.title" "Effect '$id' (tweaks\tags.psd1)" }
foreach ($id in $script:ImpactIds) {
    Test-Key "impact.$id.name" "Impact '$id' (tweaks\tags.psd1)"
    Test-Key "impact.$id.explain" "Impact '$id' (tweaks\tags.psd1)"
}

# ---- Policies ----------------------------------------------------------------
$knownData = Import-PowerShellDataFile -LiteralPath (Join-Path $AppRoot 'tools\known-policies.psd1')
$known = $knownData.Policies
$allowedFields = @('Name', 'Type', 'ApplyValue', 'BraveDefault', 'MinChromium', 'MaxChromium', 'Choices', 'LegacyNames', 'Effect', 'Impacts')
$seen = @{}
$policyCount = 0
foreach ($cat in $script:Policies.Keys) {
    Test-Key "category.$cat" "Policy category '$cat'"
    foreach ($p in $script:Policies[$cat]) {
        $policyCount++
        $where = "Policy '$($p.Name)'"
        if ($seen.ContainsKey($p.Name)) { Add-Failure "$where is defined in both '$($seen[$p.Name])' and '$cat'." }
        $seen[$p.Name] = $cat
        Test-Key "policy.$($p.Name).description" $where
        foreach ($k in $p.Keys) { if ($allowedFields -notcontains $k) { Add-Failure "${where}: unknown field '$k'." } }
        if (-not $known.ContainsKey($p.Name)) {
            Add-Failure "$where is not in tools\known-policies.psd1. Check it exists, is not deprecated and supports Windows in the Chromium or brave-core policy definitions, then add it there."
        } else {
            if ($known[$p.Name].Min -ne $p.MinChromium) { Add-Failure "${where}: MinChromium $($p.MinChromium) disagrees with the source ($($known[$p.Name].Min))." }
            if ($known[$p.Name].Max -and $known[$p.Name].Max -ne $p.MaxChromium) { Add-Failure "${where}: MaxChromium must be $($known[$p.Name].Max), as in the source." }
        }
        if ($p.Type -eq 'DWORD' -and $p.ApplyValue -isnot [int]) { Add-Failure "${where}: a DWORD ApplyValue must be a number." }
        if ($p.Type -eq 'STRING' -and $p.ApplyValue -isnot [string]) { Add-Failure "${where}: a STRING ApplyValue must be quoted text." }
        if ($p.Type -eq 'LIST' -and @($p.ApplyValue | Where-Object { $_ -isnot [string] }).Count -gt 0) { Add-Failure "${where}: a LIST ApplyValue must be a list of quoted text." }
        if ($p.Choices) {
            foreach ($choiceId in $p.Choices.Keys) { Test-Key "policy.$($p.Name).choice.$choiceId" "Choice '$choiceId' of '$($p.Name)'" }
            if (@($p.Choices.Values) -notcontains $p.ApplyValue) { Add-Failure "${where}: ApplyValue is not one of its Choices." }
        }
    }
}

# The Search & Startup page writes these itself; they must be real too.
foreach ($name in @($script:SearchOverrideValueNames) + @('NewTabPageLocation', 'HomepageIsNewTabPage', 'HomepageLocation', 'RestoreOnStartup', 'RestoreOnStartupURLs')) {
    if (-not $known.ContainsKey($name)) { Add-Failure "Search & Startup writes '$name', which is not in tools\known-policies.psd1." }
    if ($seen.ContainsKey($name)) { Add-Failure "'$name' belongs to the Search & Startup page and must not be a policy row too." }
}

# ---- Retired policies ------------------------------------------------------------
foreach ($name in $script:RetiredPolicies.Keys) {
    $entry = $script:RetiredPolicies[$name]
    Test-Key "retired.reason.$($entry.Reason)" "Retired policy '$name'"
    if ($entry.Replacement -and -not $seen.ContainsKey($entry.Replacement)) { Add-Failure "Retired policy '$name': Replacement '$($entry.Replacement)' is not a policy row." }
}

# ---- Flags -----------------------------------------------------------------------
$flagNames = @()
foreach ($f in $script:Flags) {
    if ($flagNames -contains $f.Name) { Add-Failure "Flag '$($f.Name)' is listed twice." }
    $flagNames += $f.Name
    Test-Key "flag.$($f.Name).description" "Flag '$($f.Name)'"
    if ($f.MinBrave -gt 85) { Add-Failure "Flag '$($f.Name)': flags must have been in Brave since 1.85 or earlier (MinBrave $($f.MinBrave))." }
}

# ---- System ------------------------------------------------------------------
foreach ($t in $script:ScheduledTasks) { Test-Key "task.$($t.Name).description" "Scheduled task '$($t.Name)'" }
foreach ($s in $script:Services) {
    Test-Key "service.$($s.Name).description" "Service '$($s.Name)'"
    # Chromium decrypts cookies and passwords through this service.
    if (@($s.Match) -like '*ElevationService*') { Add-Failure "Service '$($s.Name)' matches the Brave Elevation Service, which must never be disabled." }
}

# ---- Hosts -------------------------------------------------------------------
$hostsIds = @()
foreach ($b in $script:HostsBlocks) {
    if ($hostsIds -contains $b.Id) { Add-Failure "Hosts group id '$($b.Id)' is used twice." }
    $hostsIds += $b.Id
    Test-Key $b.NameKey "Hosts group '$($b.Id)'"
    Test-Key $b.DescriptionKey "Hosts group '$($b.Id)'"
    if (@($b.Domains).Count -eq 0) { Add-Failure "Hosts group '$($b.Id)' has no domains." }
    foreach ($d in @($b.Domains)) {
        if ($d -notmatch '^(?=.{1,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$') { Add-Failure "Hosts group '$($b.Id)': '$d' is not a valid host name." }
    }
}

# ---- Search & Startup ----------------------------------------------------------
foreach ($table in @($script:SearchEngines, $script:DestinationOptions, $script:StartupModes)) {
    foreach ($id in $table.Keys) { Test-Key $table[$id].LabelKey "Search & Startup entry '$id'" }
}

# ---- Presets -----------------------------------------------------------------
foreach ($id in $script:PresetKeys) {
    foreach ($part in @('name', 'description', 'risk')) { Test-Key "preset.$id.$part" "Mode '$id'" }
}
$manualHosts = @($script:HostsBlocks | Where-Object { $_.ManualOnly } | ForEach-Object { $_.Id })
foreach ($id in $script:PresetDefinitions.Keys) {
    $def = $script:PresetDefinitions[$id]
    $where = "tweaks\presets.psd1, mode '$id'"
    if ($script:PresetOrder -notcontains $id) { Add-Failure "$where is not in Order, so it has no card." }
    foreach ($k in $def.Keys) {
        if (@('Include', 'Policies', 'Values', 'Flags', 'Hosts', 'Startup', 'Reset') -notcontains $k) { Add-Failure "${where}: unknown field '$k'." }
    }
    if ($def.ContainsKey('Reset') -and $def.Reset -isnot [bool]) { Add-Failure "${where}: Reset must be `$true or `$false." }
    foreach ($name in @($def.Policies | Where-Object { $_ })) { if (-not $seen.ContainsKey($name)) { Add-Failure "${where}: unknown policy '$name'." } }
    foreach ($name in @($def.Flags | Where-Object { $_ })) { if ($flagNames -notcontains $name) { Add-Failure "${where}: unknown flag '$name'." } }
    foreach ($h in @($def.Hosts | Where-Object { $_ })) {
        if ($hostsIds -notcontains $h) { Add-Failure "${where}: unknown hosts group '$h'." }
        if ($manualHosts -contains $h) { Add-Failure "${where}: hosts group '$h' is ManualOnly; no mode may tick it." }
    }
    if ($def.Startup -and -not $script:StartupModes.Contains($def.Startup)) { Add-Failure "${where}: unknown startup mode '$($def.Startup)'." }
    if ($def.Values) {
        foreach ($name in $def.Values.Keys) {
            $policy = $script:PolicyByName[$name]
            if (-not $policy -or -not $policy.Choices) { Add-Failure "${where}: Values names '$name', which is not a choice policy." }
            elseif (@($policy.Choices.Values) -notcontains $def.Values[$name]) { Add-Failure "${where}: '$($def.Values[$name])' is not one of the Choices of '$name'." }
        }
    }
    foreach ($inc in @($def.Include | Where-Object { $_ })) { if (-not $script:PresetDefinitions.ContainsKey($inc)) { Add-Failure "${where}: Include names unknown mode '$inc'." } }
}
foreach ($old in $script:LegacyPresetIds.Keys) {
    $target = $script:LegacyPresetIds[$old]
    if ($script:PresetOrder -notcontains $target) { Add-Failure "tweaks\presets.psd1: LegacyIds maps '$old' onto unknown mode '$target'." }
    # Max wipes data on exit; an old config must never land there silently.
    if ($target -eq 'Max') { Add-Failure "tweaks\presets.psd1: LegacyIds must not map '$old' onto Max." }
}

# Include cycles would make the preset resolver recurse forever.
function Test-IncludeCycle {
    param([string]$Id, [string[]]$Path)
    if ($Path -contains $Id) { return ($Path + $Id) -join ' -> ' }
    $def = $script:PresetDefinitions[$Id]
    if (-not $def) { return $null }
    foreach ($inc in @($def.Include | Where-Object { $_ })) {
        $cycle = Test-IncludeCycle -Id $inc -Path ($Path + $Id)
        if ($cycle) { return $cycle }
    }
    return $null
}
$cycleFound = $false
foreach ($id in $script:PresetDefinitions.Keys) {
    $cycle = Test-IncludeCycle -Id $id -Path @()
    if ($cycle) { Add-Failure "tweaks\presets.psd1: Include cycle $cycle."; $cycleFound = $true; break }
}

# Resolving every mode exercises the same code the mode cards run.
if (-not $cycleFound) {
    foreach ($id in $script:PresetDefinitions.Keys) {
        $payload = Get-PresetPayload -Preset $id
        if (-not $payload.Reset -and @($payload.Policies).Count -eq 0) { Add-Failure "Mode '$id' resolves to no policies." }
    }
}

if ($script:failures) {
    Write-Output ''
    Write-Output "Failures ($($script:failures.Count)):"
    $script:failures | ForEach-Object { Write-Output "  - $_" }
    exit 1
}
Write-Output "Tweak data OK: $policyCount policies in $($script:Policies.Count) tabs, $($script:Flags.Count) flags, $($script:RetiredPolicies.Count) retired, $($script:ScheduledTasks.Count) tasks, $($script:Services.Count) services, $($script:HostsBlocks.Count) hosts groups, $($script:PresetDefinitions.Count) modes."
