# Policy tab: Brave Features
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\Brave when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'braveFeatures'
    Policies = @(
        @{ Name = 'BraveRewardsDisabled';       Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 105; Effect = 'feature' },
        @{ Name = 'BraveWalletDisabled';        Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 106; Effect = 'feature' },
        @{ Name = 'BraveVPNDisabled';           Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 112; Effect = 'feature' },
        @{ Name = 'BraveNewsDisabled';          Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 138; Effect = 'feature' },
        @{ Name = 'BraveTalkDisabled';          Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 138; Effect = 'feature' },
        @{ Name = 'TorDisabled';                Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 78;  Effect = 'feature' },
        @{ Name = 'BraveWaybackMachineEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 138; Effect = 'feature' },
        @{ Name = 'BraveSpeedreaderEnabled';    Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 138; Effect = 'feature' },
        @{ Name = 'BravePlaylistEnabled';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 139; Effect = 'feature' },
        @{ Name = 'EmailAliasesEnabled';        Type = 'DWORD'; ApplyValue = 0;                   MinChromium = 147; Effect = 'feature' },
        @{ Name = 'PsstEnabled';                Type = 'DWORD'; ApplyValue = 0;                   MinChromium = 147; Effect = 'feature' }
    )
}
