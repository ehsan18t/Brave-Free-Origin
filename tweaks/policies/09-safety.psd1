# Policy tab: Safety and updates
@{
    Category = 'safetyUpdates'
    Policies = @(
        @{ Name = 'SafeBrowsingProtectionLevel';          Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 83;  Effect = 'protection'
           Prefs = @(
               @{ Path = 'safebrowsing.enabled'; Map = @{ 0 = $false; 1 = $true; 2 = $true } },
               @{ Path = 'safebrowsing.enhanced'; Map = @{ 0 = $false; 1 = $false; 2 = $true } }) },
        @{ Name = 'SafeBrowsingExtendedReportingEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 66;  Effect = 'privacy'; Lock = $true },
        @{ Name = 'SafeBrowsingDeepScanningEnabled';      Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 119; Effect = 'privacy'; Lock = $true },
        @{ Name = 'SafeBrowsingSurveysEnabled';           Type = 'DWORD'; ApplyValue = 0;                   MinChromium = 117; Effect = 'clutter'; Lock = $true },
        @{ Name = 'DefaultBrowserSettingEnabled';         Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 11;  Effect = 'clutter'; Lock = $true },
        @{ Name = 'ComponentUpdatesEnabled';              Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 54;  Effect = 'updates'; Impacts = @('noDrm', 'staleFilters'); Lock = $true }
    )
}
