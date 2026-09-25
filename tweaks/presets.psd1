# One-click modes (the cards on the Home page), in the order shown.
#
# Each mode builds on the one before it through Include, so a mode is
# everything the included mode ticks plus its own lists:
#   Include   the mode whose lists are merged in first
#   Policies  policy names to tick, at their ApplyValue
#   Values    optional name = value for choice policies that should use
#             another of their Choices in this mode
#   Flags     brave://flags names from tweaks\flags.psd1 to tick
#   Hosts     hosts group ids to tick; only groups without ManualOnly
#   Startup   optional startup mode id from tweaks\search.psd1 that the mode
#             sets on the Search & Startup page
#   Reset     $true for the mode that unticks everything (Default)
#
# A mode sets every policy, flag and hosts row: listed ones are ticked, the rest
# unticked. It never touches the System page, the ManualOnly hosts groups or
# the search engine and new tab picks; only Default resets those.
#
# Mode ids are stable and never translated; configs store them. Names,
# descriptions and risk labels are the strings preset.<Id>.name, .description
# and .risk. LegacyIds maps the ids of earlier versions onto these, for
# importing old configs. Nothing ever maps onto Max, because Max wipes data.
@{
    Order = @('Default', 'Origin', 'Recommended', 'Strict', 'Max')

    LegacyIds = @{
        None           = 'Default'
        Minimal        = 'Origin'
        Performance    = 'Recommended'
        MaxPerformance = 'Strict'
        MaxPrivacy     = 'Strict'
    }

    Modes = @{
        # Brave as it comes after a fresh install.
        Default = @{
            Reset = $true
        }

        # A copy of the paid Brave Origin: the 16 features it turns off
        # (brave-core browser/brave_origin/brave_origin_service_factory.cc).
        # Real Origin leaves 7 of them changeable in brave://settings; Brave's
        # policies can only lock, so here all 16 are locked.
        Origin = @{
            Policies = @(
                'TorDisabled', 'BraveRewardsDisabled', 'BraveWalletDisabled', 'BraveAIChatEnabled',
                'BraveNewsDisabled', 'BraveVPNDisabled', 'BraveTalkDisabled', 'EmailAliasesEnabled', 'PsstEnabled',
                'BraveStatsPingEnabled', 'BraveP3AEnabled', 'BraveLocalAIEnabled', 'BraveWaybackMachineEnabled',
                'BraveSpeedreaderEnabled', 'BravePlaylistEnabled', 'BraveWebDiscoveryEnabled'
            )
        }

        # Origin plus changes that never break a site or cost you data:
        # telemetry off, promos off, Brave's own protections locked on.
        Recommended = @{
            Include  = 'Origin'
            Policies = @(
                'MetricsReportingEnabled', 'UrlKeyedAnonymizedDataCollectionEnabled', 'UserFeedbackAllowed',
                'WebRtcEventLogCollectionAllowed', 'ChromeVariations',
                'SafeBrowsingExtendedReportingEnabled', 'SafeBrowsingSurveysEnabled',
                'AlternateErrorPagesEnabled', 'SpellCheckServiceEnabled', 'NetworkPredictionOptions',
                'PromotionsEnabled', 'BackgroundModeEnabled',
                'DefaultBraveAdblockSetting', 'DefaultBraveFingerprintingV2Setting', 'DefaultBraveReferrersSetting',
                'BraveGlobalPrivacyControlEnabled', 'BraveReduceLanguageEnabled',
                'BraveTrackingQueryParametersFilteringEnabled', 'BraveDeAmpEnabled', 'BraveDebouncingEnabled'
            )
            Hosts    = @('p3a', 'stats', 'webDiscovery', 'rewards', 'news')
        }

        # Recommended plus hardening that keeps your logins and history. Some
        # sites need a manual exception (HTTP pages, permission prompts).
        Strict = @{
            Include  = 'Recommended'
            Policies = @(
                'DefaultBraveHttpsUpgradeSetting',
                'DefaultNotificationsSetting', 'DefaultGeolocationSetting', 'DefaultSensorsSetting',
                'DefaultWebUsbGuardSetting', 'DefaultWebBluetoothGuardSetting', 'DefaultWebHidGuardSetting',
                'DefaultSerialGuardSetting', 'DefaultLocalFontsSetting',
                'WebRtcIPHandling', 'EnableMediaRouter', 'SearchSuggestEnabled', 'PaymentMethodQueryEnabled'
            )
            Flags    = @('brave-round-time-stamps', 'brave-show-strict-fingerprinting-mode', 'brave-clean-link-js-api')
        }

        # Strict plus forgetting: history is never saved, cookies last one
        # session, and closing Brave wipes the rest. Bookmarks, settings and
        # extensions survive. Startup opens a new tab, because restoring a
        # session would also restore its cookies.
        Max = @{
            Include  = 'Strict'
            Policies = @(
                'SavingBrowserHistoryDisabled', 'DefaultCookiesSetting', 'DefaultBraveRemember1PStorageSetting',
                'ClearBrowsingDataOnExitList',
                'PasswordManagerEnabled', 'AutofillAddressEnabled', 'AutofillCreditCardEnabled',
                'SyncDisabled', 'BrowserSignin'
            )
            Startup  = 'newTab'
        }
    }
}
