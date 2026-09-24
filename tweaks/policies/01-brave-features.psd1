# Policy tab: Brave Features
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'braveFeatures'
    Policies = @(
        @{ Name = 'HardwareAccelerationModeEnabled'; Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Choices = @(@{ Id = 'enable'; Value = 1 }, @{ Id = 'disable'; Value = 0 }); Effect = 'behavior' },
        @{ Name = 'BraveRewardsDisabled';            Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'BraveWalletDisabled';             Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'BraveVPNDisabled';                Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'BraveAIChatEnabled';              Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'BraveNewsDisabled';               Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'BraveTalkDisabled';               Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'BraveWaybackMachineEnabled';      Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'BravePlaylistEnabled';            Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $false; Effect = 'feature' },
        @{ Name = 'BraveSpeedreaderEnabled';         Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $false; Effect = 'feature' },
        @{ Name = 'TorDisabled';                     Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $false; Effect = 'feature' },
        @{ Name = 'IPFSEnabled';                     Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'WebTorrentDisabled';              Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' }
    )
}
