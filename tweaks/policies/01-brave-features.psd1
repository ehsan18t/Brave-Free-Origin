# Policy tab: Brave Features
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\Brave when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'braveFeatures'
    Policies = @(
        @{ Name = 'BraveRewardsDisabled';       Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 105; Effect = 'feature'; Lock = $true },
        @{ Name = 'BraveWalletDisabled';        Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 106; Effect = 'feature'; Lock = $true },
        @{ Name = 'BraveVPNDisabled';           Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 112; Effect = 'feature'; Lock = $true },
        @{ Name = 'BraveNewsDisabled';          Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 138; Effect = 'feature'; Lock = $true },
        @{ Name = 'BraveTalkDisabled';          Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 138; Effect = 'feature'; Lock = $true },
        @{ Name = 'TorDisabled';                Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 78;  Effect = 'feature'
           Prefs = @(@{ File = 'LocalState'; Path = 'tor.tor_disabled' }) },
        @{ Name = 'BraveWaybackMachineEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 138; Effect = 'feature'
           Prefs = @(@{ Path = 'brave.wayback_machine_enabled' }) },
        @{ Name = 'BraveSpeedreaderEnabled';    Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 138; Effect = 'feature'
           Prefs = @(@{ Path = 'brave.speedreader.feature_enabled' }) },
        @{ Name = 'BravePlaylistEnabled';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 139; Effect = 'feature'
           Prefs = @(@{ Path = 'brave.playlist.enabled' }) },
        @{ Name = 'EmailAliasesEnabled';        Type = 'DWORD'; ApplyValue = 0;                   MinChromium = 147; Effect = 'feature'; Lock = $true },
        @{ Name = 'PsstEnabled';                Type = 'DWORD'; ApplyValue = 0;                   MinChromium = 147; Effect = 'feature'
           Prefs = @(@{ Path = 'brave.psst.settings.enable_psst' }) }
    )
}
