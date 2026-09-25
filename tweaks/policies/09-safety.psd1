# Policy tab: Safety and updates
@{
    Category = 'safetyUpdates'
    Policies = @(
        @{ Name = 'SafeBrowsingProtectionLevel';          Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 83;  Effect = 'protection' },
        @{ Name = 'SafeBrowsingExtendedReportingEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 66;  Effect = 'privacy' },
        @{ Name = 'SafeBrowsingDeepScanningEnabled';      Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 119; Effect = 'privacy' },
        @{ Name = 'SafeBrowsingSurveysEnabled';           Type = 'DWORD'; ApplyValue = 0;                   MinChromium = 117; Effect = 'clutter' },
        @{ Name = 'DefaultBrowserSettingEnabled';         Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 11;  Effect = 'clutter' },
        @{ Name = 'ComponentUpdatesEnabled';              Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 54;  Effect = 'updates'; Impacts = @('noDrm', 'staleFilters') }
    )
}
