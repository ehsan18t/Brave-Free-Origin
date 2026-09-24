# ============================================================================
#  One-click modes: preset policy lists, payloads and applying a preset to the checkboxes.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

$script:ActiveProfile = 'Custom'
$script:MinimalPolicies = @(
    'HardwareAccelerationModeEnabled',
    'BraveRewardsDisabled','BraveWalletDisabled','BraveVPNDisabled',
    'BraveAIChatEnabled','PasswordManagerEnabled'
)
$script:OriginPolicies = @(
    'HardwareAccelerationModeEnabled',
    'BraveAIChatEnabled',
    'BraveNewsDisabled',
    'BraveP3AEnabled',
    'BravePlaylistEnabled',
    'BraveRewardsDisabled',
    'BraveSpeedreaderEnabled',
    'BraveStatsPingEnabled',
    'BraveTalkDisabled',
    'BraveVPNDisabled',
    'BraveWalletDisabled',
    'BraveWaybackMachineEnabled',
    'BraveWebDiscoveryEnabled',
    'MetricsReportingEnabled',
    'TorDisabled',
    # Shields / privacy-engine policies - keeping ad-block ON is a *performance* win
    # (fewer requests, less DOM, less JS). It's also Brave's identity. Origin Mode
    # and everything that derives from it (Privacy + Boost) now enforces these.
    'DefaultBraveAdblockSetting',
    'DefaultBraveFingerprintingV2Setting',
    'DefaultBraveReferrersSetting',
    'BraveTrackingQueryParametersFilteringEnabled',
    'BraveDeAmpEnabled',
    'BraveDebouncingEnabled'
)
$script:PerformancePolicies = @(
    $script:OriginPolicies +
    @(
        'BackgroundModeEnabled',
        'BrowserLabsEnabled',
        'CloudPrintSubmitEnabled',
        'DiskCacheSize',
        'HardwareAccelerationModeEnabled',
        'HighEfficiencyModeEnabled',
        'HomepageIsNewTabPage',
        'HomepageLocation',
        'IPFSEnabled',
        'LiveCaptionEnabled',
        'MediaRouterEnabled',
        'NetworkPredictionOptions',
        'NewTabPageLocation',
        'NTPCustomBackgroundEnabled',
        'PromotionalTabsEnabled',
        'QuicAllowed',
        'ReadingListEnabled',
        'RestoreOnStartup',
        'WebRtcEventLogCollectionAllowed',
        'WebTorrentDisabled',
        'WelcomePageOnOSUpgradeEnabled'
    )
) | Select-Object -Unique
$script:MaxPrivacyPolicies = @(
    foreach ($cat in $script:Policies.Keys) {
        foreach ($policy in $script:Policies[$cat]) {
            if ($policy.MaxPrivacy) { $policy.Name }
        }
    }
) | Select-Object -Unique
$script:MaxPerformancePolicies = @(
    $script:MaxPrivacyPolicies +
    $script:PerformancePolicies +
    @(
        'BookmarkBarEnabled',
        'PromptForDownloadLocation',
        'ShowHomeButton',
        'SpellcheckEnabled'
    )
) | Select-Object -Unique
# Preset ids are stable and language independent; the labels come from the
# string catalog under preset.<Id>.name / .description / .risk.
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

function Get-PresetPayload {
    param([string]$Preset)

    # Hosts groups: only auto-tick a group when the corresponding feature is
    # ALSO disabled by policy in this preset. No orphan blocks.
    $hostsAlwaysSafe   = @('p3a','variations','stats','webDiscovery')
    $hostsRewards      = @('rewards')
    $hostsNews         = @('news')
    $hostsComponents   = @('components')

    switch ($Preset) {
        'Recommended' {
            return @{
                Policies = @(
                    foreach ($cat in $script:Policies.Keys) {
                        foreach ($policy in $script:Policies[$cat]) {
                            if ($policy.Recommended) { $policy.Name }
                        }
                    }
                )
                Tasks    = @($script:ScheduledTasks.Name)
                Services = @()
                Hosts    = $hostsAlwaysSafe + $hostsRewards + $hostsNews
            }
        }
        'MaxPrivacy' {
            return @{
                Policies = @($script:MaxPrivacyPolicies)
                Tasks    = @($script:ScheduledTasks.Name)
                Services = @($script:Services.Name)
                Hosts    = $hostsAlwaysSafe + $hostsRewards + $hostsNews + $hostsComponents
            }
        }
        'Minimal' {
            return @{
                Policies = @($script:MinimalPolicies)
                Tasks    = @()
                Services = @()
                Hosts    = $hostsAlwaysSafe + $hostsRewards   # Quick disables Rewards, leaves News on
            }
        }
        'Origin' {
            return @{
                Policies = @($script:OriginPolicies)
                Tasks    = @()
                Services = @()
                Hosts    = $hostsAlwaysSafe + $hostsRewards + $hostsNews   # Origin disables both
            }
        }
        'Performance' {
            return @{
                Policies = @($script:PerformancePolicies)
                Tasks    = @($script:ScheduledTasks.Name)
                Services = @()
                Hosts    = $hostsAlwaysSafe + $hostsRewards + $hostsNews
            }
        }
        'MaxPerformance' {
            return @{
                Policies = @($script:MaxPerformancePolicies)
                Tasks    = @($script:ScheduledTasks.Name)
                Services = @($script:Services.Name)
                Hosts    = $hostsAlwaysSafe + $hostsRewards + $hostsNews + $hostsComponents
            }
        }
        default {
            return @{
                Policies = @()
                Tasks    = @()
                Services = @()
                Hosts    = @()
            }
        }
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
        # Hosts checkboxes (created later in the GUI; guard if not yet built)
        if ($script:HostsCheckBoxes) {
            foreach ($cb in $script:HostsCheckBoxes) {
                $cb.Checked = $payload.Hosts -contains $cb.Tag.Id
            }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = $Preset
    Update-SelectionSummary
    Update-ConfigurationFilter
    Write-Log "Loaded mode: $(Get-PresetNameEn $Preset)"
}
