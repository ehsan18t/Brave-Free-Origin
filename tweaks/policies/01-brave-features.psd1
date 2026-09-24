# Policy tab: Brave Features
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'braveFeatures'
    Policies = @(
        @{ Name = 'HardwareAccelerationModeEnabled'; Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Choices = @(@{ Id = 'enable'; Value = 1 }, @{ Id = 'disable'; Value = 0 }) },
        @{ Name = 'BraveRewardsDisabled';            Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveWalletDisabled';             Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveVPNDisabled';                Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveAIChatEnabled';              Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveNewsDisabled';               Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveTalkDisabled';               Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveWaybackMachineEnabled';      Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $true },
        @{ Name = 'BravePlaylistEnabled';            Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $false },
        @{ Name = 'BraveSpeedreaderEnabled';         Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $false },
        @{ Name = 'TorDisabled';                     Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $false },
        @{ Name = 'IPFSEnabled';                     Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'WebTorrentDisabled';              Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true }
    )
}
