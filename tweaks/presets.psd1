# One-click modes (the colored buttons above the tabs).
#
# A mode's policy list is built from three optional parts, in this order:
#   Include   other modes whose policy lists are merged in first
#   Flag      every policy whose entry has this flag set to $true
#             (Recommended or MaxPrivacy in tweaks\policies\*.psd1)
#   Policies  policy names added on top
# Duplicates are dropped. Tasks and Services tick every entry in
# tweaks\system.psd1 when $true. Hosts lists hosts group ids from
# tweaks\hosts.psd1; a group is only ticked when the mode also disables the
# matching feature by policy, so no block is left orphaned.
#
# Mode ids are stable and never translated. Names, descriptions and risk labels
# are the strings preset.<Id>.name, preset.<Id>.description and preset.<Id>.risk.
# Current State and Custom are not listed: they have no payload of their own.
@{
    Minimal = @{
        Policies = @(
            'HardwareAccelerationModeEnabled',
            'BraveRewardsDisabled', 'BraveWalletDisabled', 'BraveVPNDisabled',
            'BraveAIChatEnabled', 'PasswordManagerEnabled'
        )
        Tasks    = $false
        Services = $false
        # Quick Debloat disables Rewards but leaves News on.
        Hosts    = @('p3a', 'variations', 'stats', 'webDiscovery', 'rewards')
    }

    Recommended = @{
        Flag     = 'Recommended'
        Tasks    = $true
        Services = $false
        Hosts    = @('p3a', 'variations', 'stats', 'webDiscovery', 'rewards', 'news')
    }

    Origin = @{
        Policies = @(
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
            # Shields / privacy-engine policies. Keeping ad-block ON is a
            # performance win (fewer requests, less DOM, less JS), and it is
            # Brave's identity. Origin Mode and everything that derives from it
            # (Privacy + Boost) enforces these.
            'DefaultBraveAdblockSetting',
            'DefaultBraveFingerprintingV2Setting',
            'DefaultBraveReferrersSetting',
            'BraveTrackingQueryParametersFilteringEnabled',
            'BraveDeAmpEnabled',
            'BraveDebouncingEnabled'
        )
        Tasks    = $false
        Services = $false
        # Origin disables both Rewards and News.
        Hosts    = @('p3a', 'variations', 'stats', 'webDiscovery', 'rewards', 'news')
    }

    # Privacy + Boost: Origin Mode plus startup and latency tuning.
    Performance = @{
        Include  = @('Origin')
        Policies = @(
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
        Tasks    = $true
        Services = $false
        Hosts    = @('p3a', 'variations', 'stats', 'webDiscovery', 'rewards', 'news')
    }

    # Max Performance: Max Privacy and Privacy + Boost combined, plus extra UI trims.
    MaxPerformance = @{
        Include  = @('MaxPrivacy', 'Performance')
        Policies = @(
            'BookmarkBarEnabled',
            'PromptForDownloadLocation',
            'ShowHomeButton',
            'SpellcheckEnabled'
        )
        Tasks    = $true
        Services = $true
        Hosts    = @('p3a', 'variations', 'stats', 'webDiscovery', 'rewards', 'news', 'components')
    }

    MaxPrivacy = @{
        Flag     = 'MaxPrivacy'
        Tasks    = $true
        Services = $true
        Hosts    = @('p3a', 'variations', 'stats', 'webDiscovery', 'rewards', 'news', 'components')
    }

    # Stock / None: unticks everything.
    None = @{
        Tasks    = $false
        Services = $false
        Hosts    = @()
    }
}
