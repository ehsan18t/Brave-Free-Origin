# Policy names verified against the source, for tools\Test-Tweaks.ps1.
#
# Each entry is a policy that exists, is not deprecated and supports Windows in
# the sources below, with the Chromium versions it is supported in (Min, and
# Max when it has an end). Test-Tweaks.ps1 fails when tweaks\policies uses a
# name missing here or a MinChromium that disagrees, so a dead or mistyped
# policy cannot slip back in. Refresh it when Brave moves to a new Chromium:
#   chromium  components/policy/resources/templates/policy_definitions
#   brave     brave-core components/policy/resources/templates/policy_definitions
# Verified against Chromium 154.0.8037.58 and brave-core 1.98.30 (2026-09-25).
@{
    Policies = @{
        AccessibilityImageLabelsEnabled               = @{ Min = 84; Source = 'chromium' }
        AlternateErrorPagesEnabled                    = @{ Min = 8; Source = 'chromium' }
        AutofillAddressEnabled                        = @{ Min = 69; Source = 'chromium' }
        AutofillCreditCardEnabled                     = @{ Min = 63; Source = 'chromium' }
        AutoplayAllowed                               = @{ Min = 66; Source = 'chromium' }
        BackgroundModeEnabled                         = @{ Min = 19; Source = 'chromium' }
        BatterySaverModeAvailability                  = @{ Min = 108; Source = 'chromium' }
        BookmarkBarEnabled                            = @{ Min = 12; Source = 'chromium' }
        BraveAIChatEnabled                            = @{ Min = 121; Source = 'brave' }
        BraveDeAmpEnabled                             = @{ Min = 140; Source = 'brave' }
        BraveDebouncingEnabled                        = @{ Min = 140; Source = 'brave' }
        BraveGlobalPrivacyControlEnabled              = @{ Min = 142; Source = 'brave' }
        BraveLocalAIEnabled                           = @{ Min = 149; Source = 'brave' }
        BraveNewsDisabled                             = @{ Min = 138; Source = 'brave' }
        BraveP3AEnabled                               = @{ Min = 138; Source = 'brave' }
        BravePlaylistEnabled                          = @{ Min = 139; Source = 'brave' }
        BraveReduceLanguageEnabled                    = @{ Min = 140; Source = 'brave' }
        BraveRewardsDisabled                          = @{ Min = 105; Source = 'brave' }
        BraveSpeedreaderEnabled                       = @{ Min = 138; Source = 'brave' }
        BraveStatsPingEnabled                         = @{ Min = 138; Source = 'brave' }
        BraveTalkDisabled                             = @{ Min = 138; Source = 'brave' }
        BraveTrackingQueryParametersFilteringEnabled  = @{ Min = 142; Source = 'brave' }
        BraveVPNDisabled                              = @{ Min = 112; Source = 'brave' }
        BraveWalletDisabled                           = @{ Min = 106; Source = 'brave' }
        BraveWaybackMachineEnabled                    = @{ Min = 138; Source = 'brave' }
        BraveWebDiscoveryEnabled                      = @{ Min = 138; Source = 'brave' }
        BrowserSignin                                 = @{ Min = 70; Source = 'chromium' }
        BuiltInDnsClientEnabled                       = @{ Min = 25; Source = 'chromium' }
        ChromeVariations                              = @{ Min = 83; Source = 'chromium' }
        ClearBrowsingDataOnExitList                   = @{ Min = 89; Source = 'chromium' }
        ComponentUpdatesEnabled                       = @{ Min = 54; Source = 'chromium' }
        DefaultBraveAdblockSetting                    = @{ Min = 142; Source = 'brave' }
        DefaultBraveFingerprintingV2Setting           = @{ Min = 141; Source = 'brave' }
        DefaultBraveHttpsUpgradeSetting               = @{ Min = 142; Source = 'brave' }
        DefaultBraveReferrersSetting                  = @{ Min = 142; Source = 'brave' }
        DefaultBraveRemember1PStorageSetting          = @{ Min = 142; Source = 'brave' }
        DefaultBrowserSettingEnabled                  = @{ Min = 11; Source = 'chromium' }
        DefaultCookiesSetting                         = @{ Min = 10; Source = 'chromium' }
        DefaultGeolocationSetting                     = @{ Min = 10; Source = 'chromium' }
        DefaultLocalFontsSetting                      = @{ Min = 103; Source = 'chromium' }
        DefaultNotificationsSetting                   = @{ Min = 10; Source = 'chromium' }
        DefaultSearchProviderEnabled                  = @{ Min = 8; Source = 'chromium' }
        DefaultSearchProviderKeyword                  = @{ Min = 8; Source = 'chromium' }
        DefaultSearchProviderName                     = @{ Min = 8; Source = 'chromium' }
        DefaultSearchProviderSearchURL                = @{ Min = 8; Source = 'chromium' }
        DefaultSearchProviderSuggestURL               = @{ Min = 8; Source = 'chromium' }
        DefaultSensorsSetting                         = @{ Min = 88; Source = 'chromium' }
        DefaultSerialGuardSetting                     = @{ Min = 86; Source = 'chromium' }
        DefaultWebBluetoothGuardSetting               = @{ Min = 50; Source = 'chromium' }
        DefaultWebHidGuardSetting                     = @{ Min = 100; Source = 'chromium' }
        DefaultWebUsbGuardSetting                     = @{ Min = 67; Source = 'chromium' }
        DiskCacheSize                                 = @{ Min = 17; Source = 'chromium' }
        DnsOverHttpsMode                              = @{ Min = 78; Source = 'chromium' }
        EmailAliasesEnabled                           = @{ Min = 147; Source = 'brave' }
        EnableMediaRouter                             = @{ Min = 52; Source = 'chromium' }
        HardwareAccelerationModeEnabled               = @{ Min = 46; Source = 'chromium' }
        HighEfficiencyModeEnabled                     = @{ Min = 108; Source = 'chromium' }
        HomepageIsNewTabPage                          = @{ Min = 8; Source = 'chromium' }
        HomepageLocation                              = @{ Min = 8; Source = 'chromium' }
        ImportAutofillFormData                        = @{ Min = 39; Source = 'chromium' }
        ImportBookmarks                               = @{ Min = 15; Source = 'chromium' }
        ImportHistory                                 = @{ Min = 15; Source = 'chromium' }
        ImportSavedPasswords                          = @{ Min = 15; Source = 'chromium' }
        ImportSearchEngine                            = @{ Min = 15; Source = 'chromium' }
        MetricsReportingEnabled                       = @{ Min = 8; Source = 'chromium' }
        NetworkPredictionOptions                      = @{ Min = 38; Source = 'chromium' }
        NewTabPageLocation                            = @{ Min = 58; Source = 'chromium' }
        NTPCustomBackgroundEnabled                    = @{ Min = 80; Source = 'chromium' }
        PasswordLeakDetectionEnabled                  = @{ Min = 79; Source = 'chromium' }
        PasswordManagerEnabled                        = @{ Min = 8; Source = 'chromium' }
        PaymentMethodQueryEnabled                     = @{ Min = 80; Source = 'chromium' }
        PromotionsEnabled                             = @{ Min = 128; Source = 'chromium' }
        PromptForDownloadLocation                     = @{ Min = 64; Source = 'chromium' }
        PsstEnabled                                   = @{ Min = 147; Source = 'brave' }
        QuicAllowed                                   = @{ Min = 43; Source = 'chromium' }
        RestoreOnStartup                              = @{ Min = 8; Source = 'chromium' }
        RestoreOnStartupURLs                          = @{ Min = 8; Source = 'chromium' }
        SafeBrowsingDeepScanningEnabled               = @{ Min = 119; Source = 'chromium' }
        SafeBrowsingExtendedReportingEnabled          = @{ Min = 66; Source = 'chromium' }
        SafeBrowsingProtectionLevel                   = @{ Min = 83; Source = 'chromium' }
        SafeBrowsingSurveysEnabled                    = @{ Min = 117; Source = 'chromium' }
        SavingBrowserHistoryDisabled                  = @{ Min = 8; Source = 'chromium' }
        SearchSuggestEnabled                          = @{ Min = 8; Source = 'chromium' }
        ShowHomeButton                                = @{ Min = 8; Source = 'chromium' }
        SpellcheckEnabled                             = @{ Min = 65; Source = 'chromium' }
        SpellCheckServiceEnabled                      = @{ Min = 22; Source = 'chromium' }
        SyncDisabled                                  = @{ Min = 8; Source = 'chromium' }
        TorDisabled                                   = @{ Min = 78; Source = 'brave' }
        TranslateEnabled                              = @{ Min = 12; Source = 'chromium' }
        UrlKeyedAnonymizedDataCollectionEnabled       = @{ Min = 69; Source = 'chromium' }
        UserFeedbackAllowed                           = @{ Min = 77; Source = 'chromium' }
        WebRtcEventLogCollectionAllowed               = @{ Min = 70; Source = 'chromium' }
        WebRtcIPHandling                              = @{ Min = 91; Source = 'chromium' }
    }
}
