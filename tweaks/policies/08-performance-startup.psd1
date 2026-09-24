# Policy tab: Performance / Startup
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'performanceStartup'
    Policies = @(
        @{ Name = 'QuicAllowed';                  Type = 'DWORD';  ApplyValue = 1;             Recommended = $true;  MaxPrivacy = $true; Effect = 'performance' },
        @{ Name = 'HighEfficiencyModeEnabled';    Type = 'DWORD';  ApplyValue = 1;             Recommended = $true;  MaxPrivacy = $true; Effect = 'performance' },
        @{ Name = 'BatterySaverModeAvailability'; Type = 'DWORD';  ApplyValue = 2;             Recommended = $true;  MaxPrivacy = $true; Effect = 'performance' },
        @{ Name = 'MediaRouterEnabled';           Type = 'DWORD';  ApplyValue = 0;             Recommended = $true;  MaxPrivacy = $true; Effect = 'performance' },
        @{ Name = 'DiskCacheSize';                Type = 'DWORD';  ApplyValue = 262144000;     Recommended = $true;  MaxPrivacy = $false; Effect = 'performance' },
        @{ Name = 'BrowserLabsEnabled';           Type = 'DWORD';  ApplyValue = 0;             Recommended = $true;  MaxPrivacy = $true; Effect = 'clutter' },
        @{ Name = 'RestoreOnStartup';             Type = 'DWORD';  ApplyValue = 5;             Recommended = $true;  MaxPrivacy = $true; Effect = 'behavior' },
        @{ Name = 'HomepageIsNewTabPage';         Type = 'DWORD';  ApplyValue = 0;             Recommended = $true;  MaxPrivacy = $true; Effect = 'behavior' },
        @{ Name = 'HomepageLocation';             Type = 'STRING'; ApplyValue = 'about:blank'; Recommended = $true;  MaxPrivacy = $true; Effect = 'behavior' },
        @{ Name = 'NewTabPageLocation';           Type = 'STRING'; ApplyValue = 'about:blank'; Recommended = $false; MaxPrivacy = $true; Effect = 'behavior' },
        @{ Name = 'NTPCustomBackgroundEnabled';   Type = 'DWORD';  ApplyValue = 0;             Recommended = $true;  MaxPrivacy = $true; Effect = 'clutter' },
        @{ Name = 'ShowHomeButton';               Type = 'DWORD';  ApplyValue = 0;             Recommended = $false; MaxPrivacy = $false; Effect = 'clutter' }
    )
}
