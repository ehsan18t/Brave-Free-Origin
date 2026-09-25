# Hosts Blocklist tab: domain groups written to the Windows hosts file.
#
# DNS-level kill switch. Every domain is one brave-core actually contacts
# (browser/net/brave_network_audit_allowed_lists.h and the endpoint constants
# of each feature). Id is the stable key used by modes and by exported configs;
# the visible name and description are the strings hosts.<Id>.name and
# hosts.<Id>.description. LegacyName is the English label that v1.5 to v1.11
# exports stored, so importing an old config keeps working. ManualOnly groups
# are never ticked or unticked by a mode (Default excepted). Effect and Impacts
# are tags from tweaks\tags.psd1.
@{
    Groups = @(
        @{
            Id          = 'p3a'
            Effect      = 'privacy'
            Recommended = $true
            LegacyName  = 'Brave P3A telemetry'
            # P3A reports through the STAR / Constellation servers.
            Domains     = @('collector.bsg.brave.com', 'star-randsrv.bsg.brave.com')
        },
        @{
            Id          = 'stats'
            Effect      = 'privacy'
            Recommended = $true
            LegacyName  = 'Brave Stats ping'
            Domains     = @('usage-ping.brave.com')
        },
        @{
            Id          = 'webDiscovery'
            Effect      = 'privacy'
            Recommended = $true
            LegacyName  = 'Web Discovery'
            Domains     = @('collector.wdp.brave.com', 'quorum.wdp.brave.com', 'patterns.wdp.brave.com', 'star.wdp.brave.com')
        },
        @{
            Id          = 'rewards'
            Effect      = 'feature'
            Recommended = $false
            LegacyName  = 'Brave Rewards / BAT'
            # Rewards and the Brave Ads it switches on.
            Domains     = @(
                'rewards.brave.com', 'api.rewards.brave.com', 'grant.rewards.brave.com', 'payment.rewards.brave.com', 'creators.brave.com',
                'static.ads.brave.com', 'geo.ads.brave.com', 'anonymous.ads.brave.com', 'search.anonymous.ads.brave.com', 'ohttp.ads.brave.com', 'mywallet.ads.brave.com'
            )
        },
        @{
            Id          = 'news'
            Effect      = 'feature'
            Recommended = $false
            LegacyName  = 'Brave News CDN'
            Domains     = @('brave-today-cdn.brave.com')
        },
        @{
            Id          = 'variations'
            Effect      = 'privacy'
            Recommended = $false
            ManualOnly  = $true
            LegacyName  = 'Brave Variations'
            Domains     = @('variations.brave.com')
        },
        @{
            Id          = 'components'
            Effect      = 'updates'
            Impacts     = @('staleFilters', 'noDrm')
            Recommended = $false
            ManualOnly  = $true
            LegacyName  = 'Component Updates'
            # go-updater.brave.com/extensions is the production component and
            # extension update server; componentupdater.brave.com redirects to it.
            Domains     = @('go-updater.brave.com', 'componentupdater.brave.com', 'crxdownload.brave.com', 'brave-core-ext.s3.brave.com')
        }
    )
}
