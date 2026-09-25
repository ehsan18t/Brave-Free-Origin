# ============================================================================
#  One-click modes: preset names, what each one ticks, and old mode ids.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

$script:ActiveProfile = 'Custom'
# Preset ids are stable and language independent; the labels come from the
# string catalog under preset.<Id>.name / .description / .risk. What each one
# ticks is defined in tweaks\presets.psd1. Current State and Custom have no
# payload: they describe a selection instead of making one.
$script:PresetKeys = @($script:PresetOrder) + @('CurrentState', 'Custom')

function Get-PresetName        { param([string]$Key) if ($script:PresetKeys -contains $Key) { T "preset.$Key.name" }        else { $Key } }
function Get-PresetDescription { param([string]$Key) if ($script:PresetKeys -contains $Key) { T "preset.$Key.description" } else { '' } }
function Get-PresetRisk        { param([string]$Key) if ($script:PresetKeys -contains $Key) { T "preset.$Key.risk" }        else { '' } }

# Reports and the log stay English so a translated install still produces
# bug reports the maintainer can read.
function Get-PresetNameEn {
    param([string]$Key)
    $k = "preset.$Key.name"
    if ($script:EnglishStrings.ContainsKey($k)) { return $script:EnglishStrings[$k] }
    return $Key
}

# A mode id from a config or the drift record, mapped onto today's modes.
# Ids of earlier versions go through LegacyIds; anything unknown is Custom.
function Resolve-PresetId {
    param([string]$Id)
    if ($script:PresetKeys -contains $Id) { return $Id }
    if ($Id -and $script:LegacyPresetIds.ContainsKey($Id)) { return $script:LegacyPresetIds[$Id] }
    return 'Custom'
}

# Everything a mode ticks, with the modes it includes merged in first.
#   Policies  names to tick
#   Values    name -> value for choice policies that differ from ApplyValue
#   Flags     flag names to tick
#   Hosts     hosts group ids to tick
#   Startup   startup mode id to set, or $null
#   Reset     $true for Default, which unticks everything
function Get-PresetPayload {
    param([string]$Preset)
    $payload = @{ Policies = @(); Values = @{}; Flags = @(); Hosts = @(); Startup = $null; Reset = $false }
    $definition = $script:PresetDefinitions[$Preset]
    if (-not $definition) { return $payload }
    if ($definition.Include) {
        $base = Get-PresetPayload -Preset $definition.Include
        $payload.Policies = @($base.Policies)
        foreach ($key in $base.Values.Keys) { $payload.Values[$key] = $base.Values[$key] }
        $payload.Flags = @($base.Flags)
        $payload.Hosts = @($base.Hosts)
        $payload.Startup = $base.Startup
    }
    $payload.Policies = @(@($payload.Policies) + @($definition.Policies | Where-Object { $_ }) | Select-Object -Unique)
    if ($definition.Values) { foreach ($key in $definition.Values.Keys) { $payload.Values[$key] = $definition.Values[$key] } }
    $payload.Flags = @(@($payload.Flags) + @($definition.Flags | Where-Object { $_ }) | Select-Object -Unique)
    $payload.Hosts = @(@($payload.Hosts) + @($definition.Hosts | Where-Object { $_ }) | Select-Object -Unique)
    if ($definition.Startup) { $payload.Startup = $definition.Startup }
    $payload.Reset = [bool]$definition.Reset
    return $payload
}
