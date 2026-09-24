# Hosts Blocklist tab: domain groups written to the Windows hosts file.
#
# DNS-level kill switch. Conservative on purpose: only the safest groups are
# pre-ticked. Id is the stable key used by presets and by exported configs;
# the visible name and description are the strings hosts.<Id>.name and
# hosts.<Id>.description. LegacyName is the English label that v1.5 to v1.11
# exports stored, so importing an old config keeps working.
@{
    Groups = @(
        @{
            Id          = 'p3a'
            Recommended = $true
            LegacyName  = 'Brave P3A telemetry'
            Domains     = @('p3a.brave.com', 'p3a-creative.brave.com', 'p2a.brave.com', 'p2a-creative.brave.com')
        },
        @{
            Id          = 'variations'
            Recommended = $true
            LegacyName  = 'Brave Variations'
            Domains     = @('variations.brave.com', 'go-updater.brave.com')
        },
        @{
            Id          = 'stats'
            Recommended = $true
            LegacyName  = 'Brave Stats ping'
            Domains     = @('laptop-updates.brave.com')
        },
        @{
            Id          = 'rewards'
            Recommended = $false
            LegacyName  = 'Brave Rewards / BAT'
            Domains     = @('rewards.brave.com', 'grant.rewards.brave.com', 'creators.brave.com')
        },
        @{
            Id          = 'news'
            Recommended = $false
            LegacyName  = 'Brave News CDN'
            Domains     = @('brave-today-cdn.brave.com', 'brave-today.brave.com')
        },
        @{
            Id          = 'components'
            Recommended = $false
            LegacyName  = 'Component Updates'
            Domains     = @('componentupdater.brave.com', 'brave-core-ext.s3.brave.com')
        },
        @{
            Id          = 'webDiscovery'
            Recommended = $false
            LegacyName  = 'Web Discovery'
            Domains     = @('search.anonymous.brave.com', 'wdp.brave.com')
        }
    )
}
