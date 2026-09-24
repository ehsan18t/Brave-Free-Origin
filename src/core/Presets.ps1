# ============================================================================
#  One-click modes: preset names, policy lists and payloads.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

$script:ActiveProfile = 'Custom'
# Preset ids are stable and language independent; the labels come from the
# string catalog under preset.<Id>.name / .description / .risk. What each one
# ticks is defined in tweaks\presets.psd1.
$script:PresetKeys = @('Minimal','Recommended','Origin','Performance','MaxPerformance','MaxPrivacy','None','CurrentState','Custom')

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

# Include, then Flag, then Policies; see tweaks\presets.psd1 for the rules.
function Get-PresetPolicyNames {
    param([string]$Preset)
    $definition = $script:PresetDefinitions[$Preset]
    if (-not $definition) { return @() }
    $names = @()
    foreach ($included in @($definition.Include)) {
        if ($included) { $names += @(Get-PresetPolicyNames -Preset $included) }
    }
    if ($definition.Flag) {
        foreach ($cat in $script:Policies.Keys) {
            foreach ($policy in $script:Policies[$cat]) {
                if ($policy[$definition.Flag]) { $names += $policy.Name }
            }
        }
    }
    $names += @($definition.Policies | Where-Object { $_ })
    return @($names | Select-Object -Unique)
}

function Get-PresetPayload {
    param([string]$Preset)

    $definition = $script:PresetDefinitions[$Preset]
    if (-not $definition) {
        # Current State and Custom have no payload of their own.
        return @{
            Policies = @()
            Tasks    = @()
            Services = @()
            Hosts    = @()
        }
    }
    return @{
        Policies = @(Get-PresetPolicyNames -Preset $Preset)
        Tasks    = $(if ($definition.Tasks)    { @($script:ScheduledTasks.Name) } else { @() })
        Services = $(if ($definition.Services) { @($script:Services.Name) }       else { @() })
        Hosts    = @($definition.Hosts | Where-Object { $_ })
    }
}
