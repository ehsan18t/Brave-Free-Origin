# ============================================================================
#  One-click modes: preset policy lists, payloads and applying a preset to the checkboxes.
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

function Update-SelectionSummary {
    if (-not $script:ModeLabel) { return }

    $selectedPolicies = @($script:CheckBoxes | Where-Object { $_.Checked })
    $selectedTasks = @($script:TaskCheckBoxes | Where-Object { $_.Checked })
    $selectedServices = @($script:ServiceCheckBoxes | Where-Object { $_.Checked })
    $modeKey = if ([string]::IsNullOrWhiteSpace($script:ActiveProfile)) { 'Custom' } else { $script:ActiveProfile }
    $script:ModeLabel.Text       = T 'mode.label'    @((Get-PresetName $modeKey))
    $script:SelectionLabel.Text  = T 'mode.policies' @($selectedPolicies.Count, $script:CheckBoxes.Count)
    $script:SystemLabel.Text     = T 'mode.system'   @($selectedTasks.Count, $selectedServices.Count)
    $script:RiskLabel.Text       = T 'mode.risk'     @((Get-PresetRisk $modeKey))
    $script:ModeDescription.Text = Get-PresetDescription $modeKey
}

function Set-CustomMode {
    if ($script:SuppressSelectionEvents) { return }
    $script:ActiveProfile = 'Custom'
    Update-SelectionSummary
}

function Apply-Preset {
    param([string]$Preset)

    $payload = Get-PresetPayload -Preset $Preset
    # Suppressed for correctness (no "Custom" downgrade) and for speed: the
    # per-checkbox handler re-runs the whole configuration filter, and there
    # are ninety-odd checkboxes. One recompute at the end is enough.
    Push-SuppressSelectionEvents
    try {
        foreach ($cb in $script:CheckBoxes) {
            $policyName = $cb.Tag.Policy.Name
            $cb.Checked = $payload.Policies -contains $policyName
        }
        foreach ($cb in $script:TaskCheckBoxes) {
            $cb.Checked = $payload.Tasks -contains $cb.Tag.Name
        }
        foreach ($cb in $script:ServiceCheckBoxes) {
            $cb.Checked = $payload.Services -contains $cb.Tag.Name
        }
        foreach ($cb in $script:HostsCheckBoxes) {
            $cb.Checked = $payload.Hosts -contains $cb.Tag.Id
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = $Preset
    Update-SelectionSummary
    Update-ConfigurationFilter
    Write-Log "Loaded mode: $(Get-PresetNameEn $Preset)"
}
