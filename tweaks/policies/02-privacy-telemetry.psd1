# Policy tab: Privacy / Telemetry
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'privacyTelemetry'
    Policies = @(
        @{ Name = 'BraveP3AEnabled';                              Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'BraveStatsPingEnabled';                        Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'BraveWebDiscoveryEnabled';                     Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'MetricsReportingEnabled';                      Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'BraveGlobalPrivacyControlEnabled';             Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'protection' },
        @{ Name = 'BraveReduceLanguageEnabled';                   Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'protection' },
        @{ Name = 'BraveTrackingQueryParametersFilteringEnabled'; Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'protection' },
        @{ Name = 'BraveDeAmpEnabled';                            Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'protection' },
        @{ Name = 'BraveDebouncingEnabled';                       Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'protection' },
        @{ Name = 'DefaultBraveFingerprintingV2Setting';          Type = 'DWORD'; ApplyValue = 3; Recommended = $true;  MaxPrivacy = $true; Effect = 'protection' },
        @{ Name = 'DefaultBraveAdblockSetting';                   Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true; Effect = 'protection' },
        @{ Name = 'DefaultBraveHttpsUpgradeSetting';              Type = 'DWORD'; ApplyValue = 2; Recommended = $false; MaxPrivacy = $true; Effect = 'protection' },
        @{ Name = 'DefaultBraveReferrersSetting';                 Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true; Effect = 'protection' },
        @{ Name = 'DefaultBraveRemember1PStorageSetting';         Type = 'DWORD'; ApplyValue = 2; Recommended = $false; MaxPrivacy = $true; Effect = 'protection'; Impacts = @('forgetsLogins') },
        @{ Name = 'ChromeVariations';                             Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'CloudReportingEnabled';                        Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'UserFeedbackAllowed';                          Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' }
    )
}
