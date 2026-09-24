<#
.SYNOPSIS
    Validates the tweak data in tweaks\ against the app and its string catalog.

.DESCRIPTION
    Loads tweaks\ through the app's own loader (src\core\Tweaks.ps1), so a file
    that passes here is a file the app will accept, then checks what the loader
    alone cannot:

      * policy names are unique across every tweaks\policies file
      * every category, policy, choice, task, service, hosts group, search
        engine, destination and startup mode has its string in the English
        catalog (src\strings\en-US.ps1)
      * hosts group ids are unique and every domain looks like a host name
      * presets only name existing policies, hosts groups and other presets,
        Include has no cycles, Flag is Recommended or MaxPrivacy, and every
        preset button has a definition

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
# Both files only define functions and script-scope tables; neither touches the
# machine or creates a control.
$script:AppRoot = $AppRoot
$script:StartupError = $null
. (Join-Path $AppRoot 'src\core\Tweaks.ps1')
if ($script:StartupError) {
    Write-Host $script:StartupError
    exit 1
}
. (Join-Path $AppRoot 'src\core\Presets.ps1')

# ---- Tags --------------------------------------------------------------------
# The loader already rejects unknown tags; here every tag needs its wording.
foreach ($id in $script:EffectIds) { Test-Key "effect.$id.title" "Effect '$id' (tweaks\tags.psd1)" }
foreach ($id in $script:ImpactIds) {
    Test-Key "impact.$id.name" "Impact '$id' (tweaks\tags.psd1)"
    Test-Key "impact.$id.explain" "Impact '$id' (tweaks\tags.psd1)"
}

# ---- Policies ----------------------------------------------------------------
$seen = @{}
$policyCount = 0
foreach ($cat in $script:Policies.Keys) {
    Test-Key "category.$cat" "Policy category '$cat'"
    foreach ($p in $script:Policies[$cat]) {
        $policyCount++
        if ($seen.ContainsKey($p.Name)) { Add-Failure "Policy '$($p.Name)' is defined in both '$($seen[$p.Name])' and '$cat'." }
        $seen[$p.Name] = $cat
        Test-Key "policy.$($p.Name).description" "Policy '$($p.Name)'"
        foreach ($k in @('Recommended', 'MaxPrivacy')) {
            if ($p.ContainsKey($k) -and $p[$k] -isnot [bool]) { Add-Failure "Policy '$($p.Name)': $k must be `$true or `$false." }
        }
        if ($p.Type -eq 'DWORD' -and $p.ApplyValue -isnot [int]) { Add-Failure "Policy '$($p.Name)': a DWORD ApplyValue must be a number." }
        if ($p.Type -eq 'STRING' -and $p.ApplyValue -isnot [string]) { Add-Failure "Policy '$($p.Name)': a STRING ApplyValue must be quoted text." }
        if ($p.Choices) {
            foreach ($choiceId in $p.Choices.Keys) { Test-Key "policy.$($p.Name).choice.$choiceId" "Choice '$choiceId' of '$($p.Name)'" }
            if (@($p.Choices.Values) -notcontains $p.ApplyValue) { Add-Failure "Policy '$($p.Name)': ApplyValue is not one of its Choices." }
        }
    }
}

# ---- System ------------------------------------------------------------------
foreach ($t in $script:ScheduledTasks) { Test-Key "task.$($t.Name).description" "Scheduled task '$($t.Name)'" }
foreach ($s in $script:Services)       { Test-Key "service.$($s.Name).description" "Service '$($s.Name)'" }

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
$payloadless = @('CurrentState', 'Custom')
foreach ($id in $script:PresetKeys) {
    Test-Key "preset.$id.name" "Preset '$id'"
    if ($payloadless -notcontains $id -and -not $script:PresetDefinitions.ContainsKey($id)) {
        Add-Failure "Preset '$id' has a button but no entry in tweaks\presets.psd1."
    }
}
foreach ($id in $script:PresetDefinitions.Keys) {
    $def = $script:PresetDefinitions[$id]
    $where = "tweaks\presets.psd1, preset '$id'"
    if ($script:PresetKeys -notcontains $id -or $payloadless -contains $id) { Add-Failure "$where is not a preset the app offers." }
    foreach ($k in $def.Keys) {
        if (@('Include', 'Flag', 'Policies', 'Tasks', 'Services', 'Hosts') -notcontains $k) { Add-Failure "${where}: unknown field '$k'." }
    }
    if ($def.Flag -and @('Recommended', 'MaxPrivacy') -notcontains $def.Flag) { Add-Failure "${where}: Flag must be 'Recommended' or 'MaxPrivacy'." }
    foreach ($k in @('Tasks', 'Services')) { if ($def[$k] -isnot [bool]) { Add-Failure "${where}: $k must be `$true or `$false." } }
    foreach ($name in @($def.Policies | Where-Object { $_ })) { if (-not $seen.ContainsKey($name)) { Add-Failure "${where}: unknown policy '$name'." } }
    foreach ($h in @($def.Hosts | Where-Object { $_ })) { if ($hostsIds -notcontains $h) { Add-Failure "${where}: unknown hosts group '$h'." } }
    foreach ($inc in @($def.Include | Where-Object { $_ })) { if (-not $script:PresetDefinitions.ContainsKey($inc)) { Add-Failure "${where}: Include names unknown preset '$inc'." } }
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

# Resolving every preset exercises the same code the mode buttons run.
if (-not $cycleFound) {
    foreach ($id in $script:PresetDefinitions.Keys) {
        $payload = Get-PresetPayload -Preset $id
        if ($id -ne 'None' -and @($payload.Policies).Count -eq 0) { Add-Failure "Preset '$id' resolves to no policies." }
    }
}

if ($script:failures) {
    Write-Host ''
    Write-Host "Failures ($($script:failures.Count)):"
    $script:failures | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host "Tweak data OK: $policyCount policies in $($script:Policies.Count) tabs, $($script:ScheduledTasks.Count) tasks, $($script:Services.Count) services, $($script:HostsBlocks.Count) hosts groups, $($script:PresetDefinitions.Count) presets."
