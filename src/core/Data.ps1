# ============================================================================
#  Tweak data model.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Each policy: Name (registry value name, never translated), Type (DWORD/STRING),
#              ApplyValue (what to write when ticked), Recommended, MaxPrivacy.
# Human-readable text lives in the string catalog under 'policy.<Name>.description'
# so it can be localized without ever touching the technical identifiers.
$script:Policies = [ordered]@{
    'braveFeatures' = @(
        @{Name='HardwareAccelerationModeEnabled'; Type='DWORD'; ApplyValue=1; Recommended=$true;  MaxPrivacy=$true;  Choices=([ordered]@{'enable'=1; 'disable'=0})},
        @{Name='BraveRewardsDisabled';         Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveWalletDisabled';          Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveVPNDisabled';             Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveAIChatEnabled';           Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveNewsDisabled';            Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveTalkDisabled';            Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveWaybackMachineEnabled';   Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true},
        @{Name='BravePlaylistEnabled';         Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='BraveSpeedreaderEnabled';      Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='TorDisabled';                  Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$false},
        @{Name='IPFSEnabled';                  Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='WebTorrentDisabled';           Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true}
    )
    'privacyTelemetry' = @(
        @{Name='BraveP3AEnabled';                             Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveStatsPingEnabled';                       Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveWebDiscoveryEnabled';                    Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='MetricsReportingEnabled';                     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveGlobalPrivacyControlEnabled';            Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveReduceLanguageEnabled';                  Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveTrackingQueryParametersFilteringEnabled';Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveDeAmpEnabled';                           Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BraveDebouncingEnabled';                      Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='DefaultBraveFingerprintingV2Setting';         Type='DWORD';  ApplyValue=3; Recommended=$true;  MaxPrivacy=$true},
        @{Name='DefaultBraveAdblockSetting';                  Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='DefaultBraveHttpsUpgradeSetting';             Type='DWORD';  ApplyValue=2; Recommended=$false; MaxPrivacy=$true},
        @{Name='DefaultBraveReferrersSetting';                Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='DefaultBraveRemember1PStorageSetting';        Type='DWORD';  ApplyValue=2; Recommended=$false; MaxPrivacy=$true},
        @{Name='ChromeVariations';                            Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='CloudReportingEnabled';                       Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='UserFeedbackAllowed';                         Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true}
    )
    'autofillPasswords' = @(
        @{Name='PasswordManagerEnabled';        Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='PasswordLeakDetectionEnabled';  Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='AutofillAddressEnabled';        Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='AutofillCreditCardEnabled';     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='PaymentMethodQueryEnabled';     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='AutoplayAllowed';               Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true}
    )
    'searchSuggestions' = @(
        @{Name='SearchSuggestEnabled';                        Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='UrlKeyedAnonymizedDataCollectionEnabled';     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='SpellCheckServiceEnabled';                    Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='SpellcheckEnabled';                           Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='TranslateEnabled';                            Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='AlternateErrorPagesEnabled';                  Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true}
    )
    'safetyUpdates' = @(
        @{Name='SafeBrowsingProtectionLevel';         Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$false},
        @{Name='SafeBrowsingExtendedReportingEnabled';Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='SafeBrowsingDeepScanningEnabled';     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='SafeBrowsingSurveysEnabled';          Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ComponentUpdatesEnabled';             Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='DefaultBrowserSettingEnabled';        Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ChromeCleanupEnabled';                Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ChromeCleanupReportingEnabled';       Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true}
    )
    'aiGenAi' = @(
        @{Name='GenAiDefaultSettings';      Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='HelpMeWriteSettings';       Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='TabOrganizerSettings';      Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='CreateThemesSettings';      Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='HistorySearchSettings';     Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='DevToolsGenAiSettings';     Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true}
    )
    'webServicesBackground' = @(
        @{Name='BackgroundModeEnabled';           Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='NetworkPredictionOptions';        Type='DWORD';  ApplyValue=2; Recommended=$true;  MaxPrivacy=$true},
        @{Name='CloudPrintSubmitEnabled';         Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='BuiltInDnsClientEnabled';         Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='DnsOverHttpsMode';                Type='STRING'; ApplyValue='automatic'; Recommended=$true;  MaxPrivacy=$true},
        @{Name='WebRtcEventLogCollectionAllowed'; Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='SyncDisabled';                    Type='DWORD';  ApplyValue=1; Recommended=$false; MaxPrivacy=$true},
        @{Name='SigninAllowed';                   Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true},
        @{Name='BrowserSignin';                   Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true},
        @{Name='PromotionalTabsEnabled';          Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='WelcomePageOnOSUpgradeEnabled';   Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ImportAutofillFormData';          Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ImportBookmarks';                 Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true},
        @{Name='ImportHistory';                   Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ImportSavedPasswords';            Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ImportSearchEngine';              Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$true}
    )
    'performanceStartup' = @(
        @{Name='QuicAllowed';                     Type='DWORD';  ApplyValue=1;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='HighEfficiencyModeEnabled';       Type='DWORD';  ApplyValue=1;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='BatterySaverModeAvailability';    Type='DWORD';  ApplyValue=2;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='MediaRouterEnabled';              Type='DWORD';  ApplyValue=0;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='DiskCacheSize';                   Type='DWORD';  ApplyValue=262144000;  Recommended=$true;  MaxPrivacy=$false},
        @{Name='BrowserLabsEnabled';              Type='DWORD';  ApplyValue=0;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='RestoreOnStartup';                Type='DWORD';  ApplyValue=5;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='HomepageIsNewTabPage';            Type='DWORD';  ApplyValue=0;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='HomepageLocation';                Type='STRING'; ApplyValue='about:blank'; Recommended=$true;  MaxPrivacy=$true},
        @{Name='NewTabPageLocation';              Type='STRING'; ApplyValue='about:blank'; Recommended=$false; MaxPrivacy=$true},
        @{Name='NTPCustomBackgroundEnabled';      Type='DWORD';  ApplyValue=0;          Recommended=$true;  MaxPrivacy=$true},
        @{Name='ShowHomeButton';                  Type='DWORD';  ApplyValue=0;          Recommended=$false; MaxPrivacy=$false}
    )
    'uiBloatExtras' = @(
        @{Name='LiveCaptionEnabled';              Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='AccessibilityImageLabelsEnabled'; Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='LensDesktopNTPSearchEnabled';     Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='LensRegionSearchEnabled';         Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='LensOverlaySettings';             Type='DWORD';  ApplyValue=1; Recommended=$true;  MaxPrivacy=$true},
        @{Name='ReadingListEnabled';              Type='DWORD';  ApplyValue=0; Recommended=$true;  MaxPrivacy=$true},
        @{Name='PromptForDownloadLocation';       Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false},
        @{Name='BookmarkBarEnabled';              Type='DWORD';  ApplyValue=0; Recommended=$false; MaxPrivacy=$false}
    )
}

# Task / service descriptions live under task.<Name>.description and
# service.<Name>.description in the string catalog.
$script:ScheduledTasks = @(
    @{Name='BraveSoftwareUpdateTaskMachineCore'},
    @{Name='BraveSoftwareUpdateTaskMachineUA'}
)

$script:Services = @(
    @{Name='brave'},
    @{Name='bravem'},
    @{Name='BraveElevationService'},
    @{Name='BraveVPNService'},
    @{Name='BraveVpnWireguardService'}
)

# ---- Hosts blocklist groups (v1.5, ID-keyed since v1.12) --------------------
# DNS-level kill switch via the Windows hosts file. Conservative on purpose -
# only the safest groups are pre-ticked. Id is the stable key used by presets
# and by exported configs; the visible name is a translatable string.
$script:HostsBlocks = @(
    @{Id='p3a'; NameKey='hosts.p3a.name'; DescriptionKey='hosts.p3a.description'; Recommended=$true; Domains=@('p3a.brave.com', 'p3a-creative.brave.com', 'p2a.brave.com', 'p2a-creative.brave.com')},
    @{Id='variations'; NameKey='hosts.variations.name'; DescriptionKey='hosts.variations.description'; Recommended=$true; Domains=@('variations.brave.com', 'go-updater.brave.com')},
    @{Id='stats'; NameKey='hosts.stats.name'; DescriptionKey='hosts.stats.description'; Recommended=$true; Domains=@('laptop-updates.brave.com')},
    @{Id='rewards'; NameKey='hosts.rewards.name'; DescriptionKey='hosts.rewards.description'; Recommended=$false; Domains=@('rewards.brave.com', 'grant.rewards.brave.com', 'creators.brave.com')},
    @{Id='news'; NameKey='hosts.news.name'; DescriptionKey='hosts.news.description'; Recommended=$false; Domains=@('brave-today-cdn.brave.com', 'brave-today.brave.com')},
    @{Id='components'; NameKey='hosts.components.name'; DescriptionKey='hosts.components.description'; Recommended=$false; Domains=@('componentupdater.brave.com', 'brave-core-ext.s3.brave.com')},
    @{Id='webDiscovery'; NameKey='hosts.webDiscovery.name'; DescriptionKey='hosts.webDiscovery.description'; Recommended=$false; Domains=@('search.anonymous.brave.com', 'wdp.brave.com')}
)

# ---- Search engines (v1.6, ID-keyed since v1.12) ---------------------------
# {searchTerms} is the standard Chromium placeholder Brave fills in.
# Brand names are NOT translated; only the "Custom..." entry has a real label.
$script:SearchEngines = [ordered]@{
    'brave'       = @{ LabelKey='engine.brave'; ProviderName='Brave Search'; URL='https://search.brave.com/search?q={searchTerms}';     Suggest='https://search.brave.com/api/suggest?q={searchTerms}';                       Keyword='brave';     Home='https://search.brave.com' }
    'duckduckgo'  = @{ LabelKey='engine.duckduckgo'; ProviderName='DuckDuckGo'; URL='https://duckduckgo.com/?q={searchTerms}';             Suggest='https://duckduckgo.com/ac/?q={searchTerms}&type=list';                      Keyword='ddg';       Home='https://duckduckgo.com' }
    'startpage'   = @{ LabelKey='engine.startpage'; ProviderName='Startpage'; URL='https://www.startpage.com/do/search?q={searchTerms}';  Suggest='';                                                                          Keyword='startpage'; Home='https://www.startpage.com' }
    'qwant'       = @{ LabelKey='engine.qwant'; ProviderName='Qwant'; URL='https://www.qwant.com/?q={searchTerms}';               Suggest='https://api.qwant.com/api/suggest?q={searchTerms}';                         Keyword='qwant';     Home='https://www.qwant.com' }
    'ecosia'      = @{ LabelKey='engine.ecosia'; ProviderName='Ecosia'; URL='https://www.ecosia.org/search?q={searchTerms}';        Suggest='https://ac.ecosia.org/?q={searchTerms}';                                    Keyword='ecosia';    Home='https://www.ecosia.org' }
    'mojeek'      = @{ LabelKey='engine.mojeek'; ProviderName='Mojeek'; URL='https://www.mojeek.com/search?q={searchTerms}';        Suggest='';                                                                          Keyword='mojeek';    Home='https://www.mojeek.com' }
    'kagi'        = @{ LabelKey='engine.kagi'; ProviderName='Kagi (paid)'; URL='https://kagi.com/search?q={searchTerms}';              Suggest='https://kagi.com/api/autosuggest?q={searchTerms}';                          Keyword='kagi';      Home='https://kagi.com' }
    'google'      = @{ LabelKey='engine.google'; ProviderName='Google'; URL='https://www.google.com/search?q={searchTerms}';        Suggest='https://www.google.com/complete/search?output=chrome&q={searchTerms}';     Keyword='google';    Home='https://www.google.com' }
    'bing'        = @{ LabelKey='engine.bing'; ProviderName='Bing'; URL='https://www.bing.com/search?q={searchTerms}';          Suggest='https://www.bing.com/osjson.aspx?query={searchTerms}';                      Keyword='bing';      Home='https://www.bing.com' }
    'yandex'      = @{ LabelKey='engine.yandex'; ProviderName='Yandex'; URL='https://yandex.com/search/?text={searchTerms}';        Suggest='https://suggest.yandex.com/suggest-ff.cgi?part={searchTerms}';             Keyword='yandex';    Home='https://yandex.com' }
    'custom'      = @{ LabelKey='engine.custom'; ProviderName='Custom...'; URL='';                                                     Suggest='';                                                                          Keyword='custom';    Home='';                                IsCustom=$true }
}

# Destination presets for "new tab" and "startup specific page" dropdowns.
# '__SEARCH__' resolves at apply-time to the chosen engine's home URL.
$script:DestinationOptions = [ordered]@{
    'blank'           = @{ LabelKey='destination.blank'; Value='about:blank' }
    'ntpDefault'      = @{ LabelKey='destination.ntpDefault'; Value='__SKIP__' }
    'matchSearch'     = @{ LabelKey='destination.matchSearch'; Value='__SEARCH__' }
    'braveSearchHome' = @{ LabelKey='destination.braveSearchHome'; Value='https://search.brave.com' }
    'duckduckgoHome'  = @{ LabelKey='destination.duckduckgoHome'; Value='https://duckduckgo.com' }
    'googleHome'      = @{ LabelKey='destination.googleHome'; Value='https://www.google.com' }
    'custom'          = @{ LabelKey='destination.custom'; Value='__CUSTOM__' }
}

# Startup behavior modes (RestoreOnStartup policy values).
$script:StartupModes = [ordered]@{
    'newTab'          = @{ LabelKey='startupMode.newTab'; Code=5; UsesURL=$false }
    'restoreSession'  = @{ LabelKey='startupMode.restoreSession'; Code=1; UsesURL=$false }
    'blankPage'       = @{ LabelKey='startupMode.blankPage'; Code=4; UsesURL=$true; FixedURL='about:blank' }
    'specificPages'   = @{ LabelKey='startupMode.specificPages'; Code=4; UsesURL=$true; FixedURL=$null }
}

# ---- Stable id arrays that back the ComboBoxes -----------------------------
# Item order in each ComboBox matches the order of these arrays; the link is
# SelectedIndex, which is the one binding WinForms guarantees for a
# non-data-bound ComboBox and which survives re-translation intact.
$script:SearchEngineIds       = @($script:SearchEngines.Keys)
$script:SearchEngineLabelKeys = @($script:SearchEngineIds | ForEach-Object { $script:SearchEngines[$_].LabelKey })
# 'ntpDefault' stays in the data model for Load current state matching but is
# never offered in the new-tab dropdown (parity with v1.11).
$script:DestinationIds        = @($script:DestinationOptions.Keys | Where-Object { $_ -ne 'ntpDefault' })
$script:DestinationLabelKeys  = @($script:DestinationIds | ForEach-Object { $script:DestinationOptions[$_].LabelKey })
$script:StartupModeIds        = @($script:StartupModes.Keys)
$script:StartupModeLabelKeys  = @($script:StartupModeIds | ForEach-Object { $script:StartupModes[$_].LabelKey })

# Legacy config migration: v1.5-v1.11 exports stored the English display
# label. Importing those must keep working.
$script:LegacyHostsIds = @{
    'Brave P3A telemetry' = 'p3a'
    'Brave Variations' = 'variations'
    'Brave Stats ping' = 'stats'
    'Brave Rewards / BAT' = 'rewards'
    'Brave News CDN' = 'news'
    'Component Updates' = 'components'
    'Web Discovery' = 'webDiscovery'
}
$script:LegacySearchEngineIds = @{
    'Brave Search' = 'brave'
    'DuckDuckGo' = 'duckduckgo'
    'Startpage' = 'startpage'
    'Qwant' = 'qwant'
    'Ecosia' = 'ecosia'
    'Mojeek' = 'mojeek'
    'Kagi (paid)' = 'kagi'
    'Google' = 'google'
    'Bing' = 'bing'
    'Yandex' = 'yandex'
    'Custom...' = 'custom'
}
$script:LegacyDestinationIds = @{
    'Blank page (about:blank)' = 'blank'
    'Default new tab page (do not override)' = 'ntpDefault'
    'Match the search engine I picked above' = 'matchSearch'
    'Brave Search homepage' = 'braveSearchHome'
    'DuckDuckGo homepage' = 'duckduckgoHome'
    'Google homepage' = 'googleHome'
    'Custom URL...' = 'custom'
}
$script:LegacyStartupModeIds = @{
    'Open the new tab page' = 'newTab'
    'Restore my last session' = 'restoreSession'
    'Open a blank page' = 'blankPage'
    'Open a specific page or set' = 'specificPages'
}
