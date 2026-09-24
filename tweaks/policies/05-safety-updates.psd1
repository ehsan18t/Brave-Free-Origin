# Policy tab: Safety / Updates
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'safetyUpdates'
    Policies = @(
        @{ Name = 'SafeBrowsingProtectionLevel';          Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $false },
        @{ Name = 'SafeBrowsingExtendedReportingEnabled'; Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'SafeBrowsingDeepScanningEnabled';      Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'SafeBrowsingSurveysEnabled';           Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'ComponentUpdatesEnabled';              Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $false },
        @{ Name = 'DefaultBrowserSettingEnabled';         Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'ChromeCleanupEnabled';                 Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'ChromeCleanupReportingEnabled';        Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true }
    )
}
