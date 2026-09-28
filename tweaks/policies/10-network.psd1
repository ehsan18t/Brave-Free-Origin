# Policy tab: Network and background
@{
    Category = 'webServicesBackground'
    Policies = @(
        @{ Name = 'BackgroundModeEnabled';    Type = 'DWORD';  ApplyValue = 0; BraveDefault = 1; MinChromium = 19; Effect = 'performance'
           Prefs = @(@{ File = 'LocalState'; Path = 'background_mode.enabled' }) },
        @{ Name = 'NetworkPredictionOptions'; Type = 'DWORD';  ApplyValue = 2; BraveDefault = 2; MinChromium = 38; Effect = 'privacy'
           Prefs = @(@{ Path = 'net.network_prediction_options'; Map = 'same' }) },
        @{ Name = 'WebRtcIPHandling';         Type = 'STRING'; ApplyValue = 'default_public_interface_only'; BraveDefault = 'default'; MinChromium = 91; Effect = 'privacy'
           Choices = @(@{ Id = 'publicOnly'; Value = 'default_public_interface_only' }, @{ Id = 'proxyOnly'; Value = 'disable_non_proxied_udp' })
           Prefs = @(@{ Path = 'webrtc.ip_handling_policy'; Map = 'same' }) },
        @{ Name = 'EnableMediaRouter';        Type = 'DWORD';  ApplyValue = 0; BraveDefault = 1; MinChromium = 52; Effect = 'feature'; LegacyNames = @('MediaRouterEnabled')
           Prefs = @(
               @{ Path = 'media_router.enable_media_router' },
               @{ Path = 'brave.enable_media_router_on_restart' }) },
        @{ Name = 'DnsOverHttpsMode';         Type = 'STRING'; ApplyValue = 'automatic'; BraveDefault = 'automatic'; MinChromium = 78; Effect = 'protection'
           Choices = @(@{ Id = 'automatic'; Value = 'automatic' }, @{ Id = 'off'; Value = 'off' })
           Prefs = @(@{ File = 'LocalState'; Path = 'dns_over_https.mode'; Map = 'same' }) },
        @{ Name = 'BuiltInDnsClientEnabled';  Type = 'DWORD';  ApplyValue = 0; BraveDefault = 1; MinChromium = 25; Effect = 'behavior'; Lock = $true },
        @{ Name = 'QuicAllowed';              Type = 'DWORD';  ApplyValue = 1; BraveDefault = 1; MinChromium = 43; Effect = 'behavior'
           Choices = @(@{ Id = 'enable'; Value = 1 }, @{ Id = 'disable'; Value = 0 }); Lock = $true }
    )
}
