# Policy tab: Privacy / Telemetry
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'privacyTelemetry'
    Policies = @(
        @{ Name = 'BraveP3AEnabled';                              Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveStatsPingEnabled';                        Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveWebDiscoveryEnabled';                     Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'MetricsReportingEnabled';                      Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveGlobalPrivacyControlEnabled';             Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveReduceLanguageEnabled';                   Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveTrackingQueryParametersFilteringEnabled'; Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveDeAmpEnabled';                            Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BraveDebouncingEnabled';                       Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'DefaultBraveFingerprintingV2Setting';          Type = 'DWORD'; ApplyValue = 3; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'DefaultBraveAdblockSetting';                   Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'DefaultBraveHttpsUpgradeSetting';              Type = 'DWORD'; ApplyValue = 2; Recommended = $false; MaxPrivacy = $true },
        @{ Name = 'DefaultBraveReferrersSetting';                 Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'DefaultBraveRemember1PStorageSetting';         Type = 'DWORD'; ApplyValue = 2; Recommended = $false; MaxPrivacy = $true },
        @{ Name = 'ChromeVariations';                             Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'CloudReportingEnabled';                        Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'UserFeedbackAllowed';                          Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true }
    )
}
