# Policy tab: Shields and tracking
#
# Brave's tracking protections. Most rows only lock Brave's own default, so it
# cannot be turned off globally; sites can still be given exceptions.
@{
    Category = 'shields'
    Policies = @(
        @{ Name = 'DefaultBraveAdblockSetting';                   Type = 'DWORD'; ApplyValue = 2; BraveDefault = 2; MinChromium = 142; Effect = 'protection' },
        @{ Name = 'DefaultBraveFingerprintingV2Setting';          Type = 'DWORD'; ApplyValue = 3; BraveDefault = 3; MinChromium = 141; Effect = 'protection' },
        @{ Name = 'DefaultBraveReferrersSetting';                 Type = 'DWORD'; ApplyValue = 2; BraveDefault = 2; MinChromium = 142; Effect = 'protection' },
        @{ Name = 'DefaultBraveHttpsUpgradeSetting';              Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 142; Effect = 'protection'; Impacts = @('mayBreakSites')
           Choices = @(@{ Id = 'strict'; Value = 2 }, @{ Id = 'standard'; Value = 3 }) },
        @{ Name = 'BraveGlobalPrivacyControlEnabled';             Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 142; Effect = 'protection' },
        @{ Name = 'BraveReduceLanguageEnabled';                   Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 140; Effect = 'protection' },
        @{ Name = 'BraveTrackingQueryParametersFilteringEnabled'; Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 142; Effect = 'protection' },
        @{ Name = 'BraveDeAmpEnabled';                            Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 140; Effect = 'protection' },
        @{ Name = 'BraveDebouncingEnabled';                       Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 140; Effect = 'protection' }
    )
}
