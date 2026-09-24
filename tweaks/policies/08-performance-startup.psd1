# Policy tab: Performance / Startup
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'performanceStartup'
    Policies = @(
        @{ Name = 'QuicAllowed';                  Type = 'DWORD';  ApplyValue = 1;             Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'HighEfficiencyModeEnabled';    Type = 'DWORD';  ApplyValue = 1;             Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BatterySaverModeAvailability'; Type = 'DWORD';  ApplyValue = 2;             Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'MediaRouterEnabled';           Type = 'DWORD';  ApplyValue = 0;             Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'DiskCacheSize';                Type = 'DWORD';  ApplyValue = 262144000;     Recommended = $true;  MaxPrivacy = $false },
        @{ Name = 'BrowserLabsEnabled';           Type = 'DWORD';  ApplyValue = 0;             Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'RestoreOnStartup';             Type = 'DWORD';  ApplyValue = 5;             Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'HomepageIsNewTabPage';         Type = 'DWORD';  ApplyValue = 0;             Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'HomepageLocation';             Type = 'STRING'; ApplyValue = 'about:blank'; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'NewTabPageLocation';           Type = 'STRING'; ApplyValue = 'about:blank'; Recommended = $false; MaxPrivacy = $true },
        @{ Name = 'NTPCustomBackgroundEnabled';   Type = 'DWORD';  ApplyValue = 0;             Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'ShowHomeButton';               Type = 'DWORD';  ApplyValue = 0;             Recommended = $false; MaxPrivacy = $false }
    )
}
