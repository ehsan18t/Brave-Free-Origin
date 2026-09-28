# Policy tab: Shields and tracking
#
# Brave's tracking protections. Most rows only lock Brave's own default, so it
# cannot be turned off globally; sites can still be given exceptions.
@{
    Category = 'shields'
    Policies = @(
        @{ Name = 'DefaultBraveAdblockSetting';                   Type = 'DWORD'; ApplyValue = 2; BraveDefault = 2; MinChromium = 142; Effect = 'protection'; PrefOnly = $true
           Prefs = @(
               @{ Path = 'profile.content_settings.exceptions.shieldsAds'; Map = 'same'; Rule = $true },
               @{ Path = 'profile.content_settings.exceptions.trackers'; Map = 'same'; Rule = $true }) },
        @{ Name = 'DefaultBraveFingerprintingV2Setting';          Type = 'DWORD'; ApplyValue = 3; BraveDefault = 3; MinChromium = 141; Effect = 'protection'; PrefOnly = $true
           Prefs = @(@{ Path = 'profile.content_settings.exceptions.fingerprintingV2'; Map = 'same'; Rule = $true }) },
        @{ Name = 'DefaultBraveReferrersSetting';                 Type = 'DWORD'; ApplyValue = 2; BraveDefault = 2; MinChromium = 142; Effect = 'protection'; Lock = $true },
        @{ Name = 'DefaultBraveHttpsUpgradeSetting';              Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 142; Effect = 'protection'; Impacts = @('mayBreakSites')
           Choices = @(@{ Id = 'strict'; Value = 2 }, @{ Id = 'standard'; Value = 3 }); PrefOnly = $true
           Prefs = @(@{ Path = 'profile.default_content_setting_values.httpsUpgrades'; Map = 'same' }) },
        @{ Name = 'BraveGlobalPrivacyControlEnabled';             Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 142; Effect = 'protection'; Lock = $true },
        @{ Name = 'BraveReduceLanguageEnabled';                   Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 140; Effect = 'protection'
           Prefs = @(@{ Path = 'brave.reduce_language' }) },
        @{ Name = 'BraveTrackingQueryParametersFilteringEnabled'; Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 142; Effect = 'protection'; Lock = $true },
        @{ Name = 'BraveDeAmpEnabled';                            Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 140; Effect = 'protection'
           Prefs = @(@{ Path = 'brave.de_amp.enabled' }) },
        @{ Name = 'BraveDebouncingEnabled';                       Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 140; Effect = 'protection'
           Prefs = @(@{ Path = 'brave.debounce.enabled' }) }
    )
}
