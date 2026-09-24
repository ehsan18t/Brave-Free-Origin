# Hosts Blocklist tab: domain groups written to the Windows hosts file.
#
# DNS-level kill switch. Conservative on purpose: only the safest groups are
# pre-ticked. Id is the stable key used by presets and by exported configs;
# the visible name and description are the strings hosts.<Id>.name and
# hosts.<Id>.description. LegacyName is the English label that v1.5 to v1.11
# exports stored, so importing an old config keeps working. Effect and
# Impacts are tags from tweaks\tags.psd1.
@{
    Groups = @(
        @{
            Id          = 'p3a'
            Effect      = 'privacy'
            Recommended = $true
            LegacyName  = 'Brave P3A telemetry'
            Domains     = @('p3a.brave.com', 'p3a-creative.brave.com', 'p2a.brave.com', 'p2a-creative.brave.com')
        },
        @{
            Id          = 'variations'
            Effect      = 'privacy'
            Impacts     = @('noUpdates')
            Recommended = $true
            LegacyName  = 'Brave Variations'
            Domains     = @('variations.brave.com', 'go-updater.brave.com')
        },
        @{
            Id          = 'stats'
            Effect      = 'privacy'
            Recommended = $true
            LegacyName  = 'Brave Stats ping'
            Domains     = @('laptop-updates.brave.com')
        },
        @{
            Id          = 'rewards'
            Effect      = 'feature'
            Recommended = $false
            LegacyName  = 'Brave Rewards / BAT'
            Domains     = @('rewards.brave.com', 'grant.rewards.brave.com', 'creators.brave.com')
        },
        @{
            Id          = 'news'
            Effect      = 'feature'
            Recommended = $false
            LegacyName  = 'Brave News CDN'
            Domains     = @('brave-today-cdn.brave.com', 'brave-today.brave.com')
        },
        @{
            Id          = 'components'
            Effect      = 'updates'
            Impacts     = @('noDrm')
            Recommended = $false
            LegacyName  = 'Component Updates'
            Domains     = @('componentupdater.brave.com', 'brave-core-ext.s3.brave.com')
        },
        @{
            Id          = 'webDiscovery'
            Effect      = 'privacy'
            Recommended = $false
            LegacyName  = 'Web Discovery'
            Domains     = @('search.anonymous.brave.com', 'wdp.brave.com')
        }
    )
}
