# Policy tab: Safety / Updates
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'safetyUpdates'
    Policies = @(
        @{ Name = 'SafeBrowsingProtectionLevel';          Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $false; Effect = 'protection' },
        @{ Name = 'SafeBrowsingExtendedReportingEnabled'; Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'SafeBrowsingDeepScanningEnabled';      Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy'; Impacts = @('lessProtection') },
        @{ Name = 'SafeBrowsingSurveysEnabled';           Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'clutter' },
        @{ Name = 'ComponentUpdatesEnabled';              Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $false; Effect = 'updates'; Impacts = @('noDrm') },
        @{ Name = 'DefaultBrowserSettingEnabled';         Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'clutter' },
        @{ Name = 'ChromeCleanupEnabled';                 Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'performance' },
        @{ Name = 'ChromeCleanupReportingEnabled';        Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' }
    )
}
