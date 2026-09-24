# ============================================================================
#  English string catalog.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Runtime source of truth for every user-visible string.
# locales\en-US.json is GENERATED from this block (tools\Export-EnglishLocale.ps1)
# and exists only as a reference for translators - it is never loaded.

# ---- Application chrome ------------------------------------------------------
Add-Strings @{
    'app.name'                = 'Brave Free Origin'
    'app.title'               = 'Brave Free Origin v{0}  -  the free answer to Brave Origin''s paywalled minimal mode'
    'channel.installed'       = '{0}  (installed)'
    'channel.notInstalled'    = '{0}  (not installed)'
    'header.allChannels'      = 'All installed channels'
    'header.braveDetected'    = 'Brave detected: {0}'
    'header.hives'            = '-> {0} ({1} hives)'
    'header.originNote'       = 'Context: Brave described Origin on April 16, 2026 as a minimalist build, then put that stripped-down idea behind a paywall. This is the free local version.'
    'header.subtitle'         = 'Strip out the AI, crypto, VPN, promo junk, and background clutter Brave stuffed in, then tune it for a lighter desktop footprint.'
    'header.unreviewedLocale' = 'community translation, unreviewed'
}

# ---- Window: navigation, home page, bottom bar, activity --------------------------
Add-Strings @{
    'activity.clear'       = 'Clear'
    'activity.copy'        = 'Copy log'
    'activity.title'       = 'Activity'
    'bar.activity'         = 'Activity log'
    'bar.noPending'        = 'Everything is applied'
    'bar.pending'          = '{0} change(s) not applied yet'
    'bar.target'           = 'Target'
    'busy.applying'        = 'Applying to Brave...'
    'busy.hosts'           = 'Updating the hosts file...'
    'busy.loading'         = 'Reading the current state of this PC...'
    'busy.preview'         = 'Building the preview...'
    'busy.restoring'       = 'Restoring stock behavior...'
    'busy.scriptlets'      = 'Working on the scriptlet lists...'
    'busy.starting'        = 'Starting up...'
    'busy.verify'          = 'Reading the registry back...'
    'busy.working'         = 'Working...'
    'home.admin'           = 'Running as administrator'
    'home.modesTitle'      = 'Choose a mode'
    'home.reviewSelected'  = 'Review selected'
    'home.selectionTitle'  = 'Your selection'
    'home.statMode'        = 'Mode'
    'home.statPolicies'    = 'Policies'
    'home.statServices'    = 'Services'
    'home.statTasks'       = 'Scheduled tasks'
    'nav.advanced'         = 'Advanced'
    'nav.home'             = 'Home'
    'nav.policies'         = 'Policies'
    'nav.search'           = 'Find a setting'
    'nav.settings'         = 'Settings'
    'nav.systemNetwork'    = 'System and network'
    'search.count'         = '{0} setting(s)'
    'search.selectedTitle' = 'Selected settings'
    'search.title'         = 'Results for "{0}"'
    'toast.applied'        = '{0} applied'
    'toast.appliedText'    = 'Set {0} policies and cleared {1}. Restart Brave to see the changes.'
    'toast.busyClose'      = 'Wait for the current task to finish, or close again to quit anyway.'
    'toast.busyTitle'      = 'Still working'
    'toast.exported'       = 'Config exported'
    'toast.loaded'         = 'Current state loaded'
    'toast.loadedText'     = 'Every page now shows what this PC already has.'
    'toast.presetHosts'    = 'This mode also picks hosts groups. Write those from the Hosts page.'
    'toast.presetLoaded'   = '{0} loaded'
    'toast.presetText'     = 'Review the pages if you like, then Apply to Brave.'
}

# ---- Settings page -----------------------------------------------------------------
Add-Strings @{
    'settings.about'            = 'About'
    'settings.appearance'       = 'Appearance'
    'settings.backupDesc'       = 'Saves a .reg export of the current Brave policies to Documents\Brave-Free-Origin-Backups before every apply and full restore.'
    'settings.backupFolder'     = 'Backup folder'
    'settings.backupFolderDesc' = 'Registry and hosts backups, saved reports and exported configs.'
    'settings.channel'          = 'Brave channel to change'
    'settings.config'           = 'Configuration'
    'settings.configDesc'       = 'Save your selection to a JSON file, or load one. Loading writes nothing until you apply.'
    'settings.configFile'       = 'Config file'
    'settings.language'         = 'Language'
    'settings.languageDesc'     = 'Reports and the activity log stay in English, so they can go into bug reports.'
    'settings.loadDesc'         = 'Switch on exactly what this PC already has: policies, tasks, services, the hosts block and overrides.'
    'settings.open'             = 'Open'
    'settings.policyDesc'       = 'See what Brave itself reports for every policy.'
    'settings.restore'          = 'Restore'
    'settings.restoreDesc'      = 'Removes every Brave policy and the hosts block, and re-enables Brave update tasks and services.'
    'settings.target'           = 'Target'
    'settings.theme'            = 'Theme'
    'settings.themeDesc'        = 'Follow Windows, or pick light or dark.'
    'settings.verifyDesc'       = 'Read the registry back and compare it with your selection.'
    'settings.version'          = 'Version {0}'
    'theme.dark'                = 'Dark'
    'theme.light'               = 'Light'
    'theme.system'              = 'Use Windows setting'
}

# ---- Tags (tweaks\tags.psd1) ---------------------------------------------------------
# effect.<Id>.title heads a group in the preview; impact.<Id>.name is the chip on
# a setting card, impact.<Id>.explain the warning in the preview.
Add-Strings @{
    'effect.behavior.title'       = 'Browser behavior changed'
    'effect.clutter.title'        = 'Less clutter and fewer prompts'
    'effect.feature.title'        = 'Features removed or turned off'
    'effect.performance.title'    = 'Faster and lighter'
    'effect.privacy.title'        = 'Less data sent to Brave, Google or websites'
    'effect.protection.title'     = 'Privacy and security protections set'
    'effect.updates.title'        = 'Updates'
    'impact.forgetsLogins.explain' = 'Websites forget their saved data when you close their tabs, so you will be signed out more often.'
    'impact.forgetsLogins.name'   = 'Signs you out of sites'
    'impact.lessProtection.explain' = 'A check that warns about leaked passwords or dangerous downloads stops running.'
    'impact.lessProtection.name'  = 'Turns off a safety check'
    'impact.noAutofill.explain'   = 'Brave stops saving and filling in passwords, addresses or cards. Use a separate password manager if you rely on one.'
    'impact.noAutofill.name'      = 'Stops saving your details'
    'impact.noDrm.explain'        = 'Components such as Widevine stop updating, so Netflix, Spotify and other protected video or music can stop playing.'
    'impact.noDrm.name'           = 'Can break protected video'
    'impact.noSync.explain'       = 'Brave Sync and account sign-in stop working on this PC.'
    'impact.noSync.name'          = 'Turns off sync and sign-in'
    'impact.noUpdates.explain'    = 'Brave will stop updating itself in the background. Check for updates yourself at brave://settings/help now and then.'
    'impact.noUpdates.name'       = 'Stops auto-updates'
}

# ---- Apply preview: the "What will happen" tab -----------------------------------------
Add-Strings @{
    'preview.changed'         = '{0}: currently {1}, becomes {2}'
    'preview.cleared'         = '{0}: currently {1}, will be removed'
    'preview.lead'            = 'Applying {0} to Brave {1} makes {2} change(s). {3} setting(s) are already in place and stay as they are.'
    'preview.leadNone'        = 'Everything is already in place in Brave {0}. Applying now changes nothing.'
    'preview.noteBackup'      = 'Your current Brave policies are backed up first, so this can be undone.'
    'preview.noteHosts'       = 'Hosts groups are not part of this. Write them from the Hosts page.'
    'preview.noteNoBackup'    = 'Backups are turned off in Settings, so the current policies are not saved first.'
    'preview.noteRestart'     = 'Close and reopen Brave afterwards: running tabs only pick up policies on a restart.'
    'preview.ntpCleared'      = 'New tabs go back to your own setting'
    'preview.ntpSet'          = 'New tabs open: {0}'
    'preview.overrideSkipped' = 'Skipped because its settings are incomplete: {0}'
    'preview.searchCleared'   = 'Your own choice of search engine applies again'
    'preview.searchSet'       = 'Default search engine: {0}'
    'preview.secDefault'      = 'Back to Brave''s own setting'
    'preview.secHeadsUp'      = 'Worth knowing'
    'preview.secOverrides'    = 'Search and startup'
    'preview.serviceOff'      = 'Windows service {0}: will be stopped and disabled'
    'preview.serviceReset'    = 'Windows service {0}: will be set back to Manual'
    'preview.startupCleared'  = 'Startup goes back to your own setting'
    'preview.startupSet'      = 'When Brave starts: {0}'
    'preview.tabDetails'      = 'Technical details'
    'preview.tabSummary'      = 'What will happen'
    'preview.taskOff'         = 'Scheduled task {0}: will be disabled'
    'preview.taskOn'          = 'Scheduled task {0}: will be turned back on'
    'preview.yourSelection'   = 'your selection'
}

# ---- Dialog buttons ------------------------------------------------------------------
Add-Strings @{
    'dialog.cancel' = 'Cancel'
    'dialog.no'     = 'No'
    'dialog.ok'     = 'OK'
    'dialog.yes'    = 'Yes'
}

# ---- Mode deck ---------------------------------------------------------------
Add-Strings @{
    'mode.intro' = 'Pick a one-click mode, then fine-tune any page on the left if you want to go deeper. Nothing is written until you apply.'
    'mode.risk'  = 'Risk: {0}'
}

# ---- Presets -----------------------------------------------------------------
# Preset ids (Minimal, Origin, ...) are stable and never translated.
Add-Strings @{
    'preset.CurrentState.description'   = 'Read from this PC. Shows what is already disabled right now.'
    'preset.CurrentState.name'          = 'Current State'
    'preset.CurrentState.risk'          = 'Read only'
    'preset.Custom.description'         = 'Hand-picked mix. Use the pages on the left to build your own Brave loadout.'
    'preset.Custom.name'                = 'Custom'
    'preset.Custom.risk'                = 'Depends on your picks'
    'preset.MaxPerformance.description' = 'Full fusion mode: Origin Mode, Privacy + Boost, and the strong privacy set combined, plus a few extra UI trims. This is the closest thing to an all-in gamer build.'
    'preset.MaxPerformance.name'        = 'Max Performance'
    'preset.MaxPerformance.risk'        = 'High risk'
    'preset.MaxPrivacy.description'     = 'Aggressive lockdown. Great for hard privacy, but it can disable sync, sign-in, imports, and Brave update services.'
    'preset.MaxPrivacy.name'            = 'Max Privacy'
    'preset.MaxPrivacy.risk'            = 'High risk'
    'preset.Minimal.description'        = 'Quick debloat. Removes the loudest commercial extras without changing the whole browser.'
    'preset.Minimal.name'               = 'Quick Debloat'
    'preset.Minimal.risk'               = 'Low risk'
    'preset.None.description'           = 'Stock behavior. Nothing selected, nothing will be enforced.'
    'preset.None.name'                  = 'Stock / None'
    'preset.None.risk'                  = 'No changes'
    'preset.Origin.description'         = 'Matches Brave Origin''s stripped-down idea from April 2026: off by default for Leo, Rewards, Wallet, VPN, News, Talk, Tor, Wayback, Web Discovery, and related stats.'
    'preset.Origin.name'                = 'Origin Mode'
    'preset.Origin.risk'                = 'Low risk'
    'preset.Performance.description'    = 'Privacy + Boost. Origin-style debloat plus startup and latency tuning for a leaner browser during gaming, streaming, or music use.'
    'preset.Performance.name'           = 'Privacy + Boost'
    'preset.Performance.risk'           = 'Medium risk'
    'preset.Recommended.description'    = 'Balanced daily-driver setup. Good privacy, lighter UI, keeps core compatibility and media-friendly defaults.'
    'preset.Recommended.name'           = 'Recommended'
    'preset.Recommended.risk'           = 'Low risk'
}

# ---- Search and setting lists ------------------------------------------------
Add-Strings @{
    'filter.noMatches'     = 'No settings match this search.'
    'filter.placeholder'   = 'Searches every setting on every page: name, description, category, domains.'
    'filter.selectedOnly'  = 'Selected only'
    'list.selectedCount'   = '{0} of {1} selected'
    'policyTab.selectAll'  = 'Select all'
    'policyTab.selectNone' = 'Select none'
}

# ---- Tabs --------------------------------------------------------------------
Add-Strings @{
    'tab.hosts'         = 'Hosts Blocklist (DNS-level)'
    'tab.scriptlets'    = 'Default Scriptlets (Advanced)'
    'tab.searchStartup' = 'Search & Startup'
    'tab.system'        = 'System (Tasks / Services)'
}

# ---- Policy categories -------------------------------------------------------
Add-Strings @{
    'category.aiGenAi'               = 'AI / GenAI'
    'category.autofillPasswords'     = 'Autofill / Passwords'
    'category.braveFeatures'         = 'Brave Features'
    'category.performanceStartup'    = 'Performance / Startup'
    'category.privacyTelemetry'      = 'Privacy / Telemetry'
    'category.safetyUpdates'         = 'Safety / Updates'
    'category.searchSuggestions'     = 'Search / Suggestions'
    'category.uiBloatExtras'         = 'UI Bloat / Extras'
    'category.webServicesBackground' = 'Web Services / Background'
}

# ---- Policy descriptions -----------------------------------------------------
# Keyed on the registry value name, which is never translated.
Add-Strings @{
    'policy.AccessibilityImageLabelsEnabled.description'              = 'Disable cloud image-description service (sends images to Google).'
    'policy.AlternateErrorPagesEnabled.description'                   = 'Disable Google-hosted suggestion page on DNS errors.'
    'policy.AutofillAddressEnabled.description'                       = 'Disable autofill of addresses / contact info.'
    'policy.AutofillCreditCardEnabled.description'                    = 'Disable autofill of credit cards.'
    'policy.AutoplayAllowed.description'                              = 'Block autoplaying media site-wide.'
    'policy.BackgroundModeEnabled.description'                        = 'Stop Brave from running in the background after window close.'
    'policy.BatterySaverModeAvailability.description'                 = 'Allow Battery Saver on low battery (2). 1=always on unplugged, 0=disabled.'
    'policy.BookmarkBarEnabled.description'                           = 'Hide bookmark bar globally (small render win). Turn it off to show or hide it yourself.'
    'policy.BraveAIChatEnabled.description'                           = 'Disable Leo AI Chat assistant.'
    'policy.BraveDeAmpEnabled.description'                            = 'Bypass Google AMP pages to reach publisher directly. (Leave ON for privacy.)'
    'policy.BraveDebouncingEnabled.description'                       = 'Protect against bounce-tracking redirect chains. (Leave ON for privacy.)'
    'policy.BraveGlobalPrivacyControlEnabled.description'             = 'Enable Sec-GPC "do not sell/share" signal. (Leave ON for privacy.)'
    'policy.BraveNewsDisabled.description'                            = 'Disable Brave News feed on the new tab page.'
    'policy.BraveP3AEnabled.description'                              = 'Disable P3A privacy-preserving product analytics.'
    'policy.BravePlaylistEnabled.description'                         = 'Disable Playlist feature (save videos/audio).'
    'policy.BraveReduceLanguageEnabled.description'                   = 'Reduce language-preference fingerprinting. (Leave ON for privacy.)'
    'policy.BraveRewardsDisabled.description'                         = 'Disable Brave Rewards (BAT ads/tips) and hide all Rewards UI.'
    'policy.BraveSpeedreaderEnabled.description'                      = 'Disable Speedreader reading-mode feature.'
    'policy.BraveStatsPingEnabled.description'                        = 'Disable anonymous daily/weekly/monthly usage ping.'
    'policy.BraveTalkDisabled.description'                            = 'Disable Brave Talk (Jitsi-based video calls).'
    'policy.BraveTrackingQueryParametersFilteringEnabled.description' = 'Strip tracking params (utm_, fbclid, etc.) from URLs. (Leave ON for privacy.)'
    'policy.BraveVPNDisabled.description'                             = 'Disable Brave VPN integration and all VPN UI.'
    'policy.BraveWalletDisabled.description'                          = 'Disable the built-in crypto wallet (ETH/BTC/SOL/FIL/ZEC).'
    'policy.BraveWaybackMachineEnabled.description'                   = 'Disable the "Check Wayback Machine" prompt on 404 pages.'
    'policy.BraveWebDiscoveryEnabled.description'                     = 'Disable Web Discovery Project search index contribution.'
    'policy.BrowserLabsEnabled.description'                           = 'Hide the Labs / experimental features icon in the toolbar.'
    'policy.BrowserSignin.description'                                = 'Fully disable sign-in UI (0). 1=allow, 2=force.'
    'policy.BuiltInDnsClientEnabled.description'                      = 'Use OS resolver instead of async DoH client. Only turn on if you want OS DNS.'
    'policy.ChromeCleanupEnabled.description'                         = 'Disable the software-cleanup scanner (harmless on Brave).'
    'policy.ChromeCleanupReportingEnabled.description'                = 'Disable reporting from the cleanup scanner.'
    'policy.ChromeVariations.description'                             = 'Opt out of all Chromium field trials/experiments (2). 1=critical only, 0=all.'
    'policy.CloudPrintSubmitEnabled.description'                      = 'Disable legacy cloud-print submissions.'
    'policy.CloudReportingEnabled.description'                        = 'Disable enterprise cloud reporting.'
    'policy.ComponentUpdatesEnabled.description'                      = 'Disable Chromium component updates (e.g. Widevine). Only turn on if you know what this breaks.'
    'policy.CreateThemesSettings.description'                         = 'Disable AI-generated themes.'
    'policy.DefaultBraveAdblockSetting.description'                   = 'Force default ad-blocking to Block (2). 1=Allow.'
    'policy.DefaultBraveFingerprintingV2Setting.description'          = 'Set fingerprint protection to Standard (3). 1=Off.'
    'policy.DefaultBraveHttpsUpgradeSetting.description'              = 'Force HTTPS upgrade to Strict (2). 3=Standard, 1=Disabled.'
    'policy.DefaultBraveReferrersSetting.description'                 = 'Cap cross-site referrers to strict-origin-when-cross-origin (2).'
    'policy.DefaultBraveRemember1PStorageSetting.description'         = 'Forget first-party storage on tab close (2). 1=Remember.'
    'policy.DefaultBrowserSettingEnabled.description'                 = 'Disable the "make default browser" prompt.'
    'policy.DevToolsGenAiSettings.description'                        = 'Disable GenAI features inside DevTools.'
    'policy.DiskCacheSize.description'                                = 'Cap disk cache at 250 MB (value in bytes). Prevents unbounded cache growth on SSDs.'
    'policy.DnsOverHttpsMode.description'                             = 'Allow DoH ("automatic"). Set to "secure" to force, "off" to disable.'
    'policy.GenAiDefaultSettings.description'                         = 'Disable ALL upstream Chromium GenAI features (2).'
    'policy.HardwareAccelerationModeEnabled.choice.disable'           = 'Disable (0)'
    'policy.HardwareAccelerationModeEnabled.choice.enable'            = 'Enable (1)'
    'policy.HardwareAccelerationModeEnabled.description'              = 'GPU hardware acceleration. Enabled by default in every mode. Pick Disable (0) to fix GPU driver glitches, artifacts or crashes. Turn it off to leave Brave in control.'
    'policy.HelpMeWriteSettings.description'                          = 'Disable "Help me write" compose features.'
    'policy.HighEfficiencyModeEnabled.description'                    = 'Memory Saver: sleep inactive tabs to reclaim RAM/CPU.'
    'policy.HistorySearchSettings.description'                        = 'Disable AI-powered history search.'
    'policy.HomepageIsNewTabPage.description'                         = 'Decouple home button from the bloated NTP.'
    'policy.HomepageLocation.description'                             = 'Blank homepage = fastest possible startup.'
    'policy.IPFSEnabled.description'                                  = 'Disable IPFS protocol support.'
    'policy.ImportAutofillFormData.description'                       = 'Block autofill import on first run.'
    'policy.ImportBookmarks.description'                              = 'Block bookmark import prompt on first run.'
    'policy.ImportHistory.description'                                = 'Block history import on first run.'
    'policy.ImportSavedPasswords.description'                         = 'Block password import on first run.'
    'policy.ImportSearchEngine.description'                           = 'Block search-engine import on first run.'
    'policy.LensDesktopNTPSearchEnabled.description'                  = 'Hide Google Lens search box on new tab page.'
    'policy.LensOverlaySettings.description'                          = 'Disable the Lens overlay feature (1 = disabled).'
    'policy.LensRegionSearchEnabled.description'                      = 'Disable right-click Google Lens region search.'
    'policy.LiveCaptionEnabled.description'                           = 'Disable Live Caption (stops background download of speech-recognition model).'
    'policy.MediaRouterEnabled.description'                           = 'Disable Google Cast / Media Router. Stops background mDNS discovery and memory overhead.'
    'policy.MetricsReportingEnabled.description'                      = 'Disable Chromium UMA crash/usage metrics.'
    'policy.NTPCustomBackgroundEnabled.description'                   = 'Disable the custom new-tab-page background (stops wallpaper download).'
    'policy.NetworkPredictionOptions.description'                     = 'Never prefetch DNS/TCP/SSL (2). 0/1 = predict.'
    'policy.NewTabPageLocation.description'                           = 'Force new tab page to about:blank. Kills all NTP bloat.'
    'policy.PasswordLeakDetectionEnabled.description'                 = 'Disable leaked-credential check (avoids sending hashed pw to Google).'
    'policy.PasswordManagerEnabled.description'                       = 'Disable built-in password manager (use Bitwarden / Proton Pass instead).'
    'policy.PaymentMethodQueryEnabled.description'                    = 'Prevent sites from querying for saved payment methods.'
    'policy.PromotionalTabsEnabled.description'                       = 'Disable the welcome/promo new-tab content.'
    'policy.PromptForDownloadLocation.description'                    = 'Auto-save to Downloads without prompting. Set 1 if you prefer prompts.'
    'policy.QuicAllowed.description'                                  = 'Enable QUIC / HTTP/3 protocol. Faster TLS handshake, lower latency.'
    'policy.ReadingListEnabled.description'                           = 'Remove the Reading List UI.'
    'policy.RestoreOnStartup.description'                             = 'Open blank new-tab on launch (5). Faster than restoring last session (1).'
    'policy.SafeBrowsingDeepScanningEnabled.description'              = 'Disable uploading downloads to Google for deep scan.'
    'policy.SafeBrowsingExtendedReportingEnabled.description'         = 'Disable sending extra info to Google Safe Browsing.'
    'policy.SafeBrowsingProtectionLevel.description'                  = 'Set Safe Browsing to Standard (1). 0=Off, 2=Enhanced (sends more to Google).'
    'policy.SafeBrowsingSurveysEnabled.description'                   = 'Disable Safe Browsing user surveys.'
    'policy.SearchSuggestEnabled.description'                         = 'Disable search-engine autosuggest in the omnibox.'
    'policy.ShowHomeButton.description'                               = 'Hide the Home button (tiny UI/render win).'
    'policy.SigninAllowed.description'                                = 'Disable Google/Brave account sign-in.'
    'policy.SpellCheckServiceEnabled.description'                     = 'Disable the enhanced (cloud) spellcheck service.'
    'policy.SpellcheckEnabled.description'                            = 'Disable local spellcheck entirely.'
    'policy.SyncDisabled.description'                                 = 'Disable profile sync entirely.'
    'policy.TabOrganizerSettings.description'                         = 'Disable AI Tab Organizer.'
    'policy.TorDisabled.description'                                  = 'Disable "Private Window with Tor". (Brave Tor is not recommended over real Tor Browser.)'
    'policy.TranslateEnabled.description'                             = 'Disable the "translate this page" Google prompt.'
    'policy.UrlKeyedAnonymizedDataCollectionEnabled.description'      = 'Disable "Make searches and browsing better" URL reporting.'
    'policy.UserFeedbackAllowed.description'                          = 'Disable the "Send feedback" UI that uploads diagnostics to Brave/Google.'
    'policy.WebRtcEventLogCollectionAllowed.description'              = 'Block upload of WebRTC event logs to Google.'
    'policy.WebTorrentDisabled.description'                           = 'Disable WebTorrent / magnet link integration.'
    'policy.WelcomePageOnOSUpgradeEnabled.description'                = 'Disable the "welcome back after OS upgrade" tab.'
}

# ---- Tasks and services ------------------------------------------------------
Add-Strings @{
    'service.BraveElevationService.description'           = 'Brave Elevation Service - helper used by Omaha for per-machine updates.'
    'service.BraveVPNService.description'                 = 'Brave VPN Service (present only if VPN feature installed).'
    'service.BraveVpnWireguardService.description'        = 'Brave VPN Wireguard Service (present only if VPN feature installed).'
    'service.brave.description'                           = 'Brave Update Service - main Omaha update service.'
    'service.bravem.description'                          = 'Brave Update Service (medium-integrity on-demand helper).'
    'system.intro'                                        = 'Background updaters matter most for the Privacy + Boost, Max Performance, and Max Privacy modes. Disabling services is the riskiest step because it can block Brave auto-updates.'
    'system.svcHdr'                                       = 'Windows Services'
    'system.tasksHdr'                                     = 'Scheduled Tasks'
    'task.BraveSoftwareUpdateTaskMachineCore.description' = 'Hourly "core" update check launched by Brave Omaha.'
    'task.BraveSoftwareUpdateTaskMachineUA.description'   = 'The actual version-check/download task.'
}

# ---- Hosts blocklist ---------------------------------------------------------
Add-Strings @{
    'hosts.components.description'   = 'WARNING: blocking this stops Widevine/CRX/iOS-style components from updating. Use only if ComponentUpdatesEnabled is also off.'
    'hosts.components.name'          = 'Component Updates'
    'hosts.news.description'         = 'News content CDN. Block ONLY if you have disabled News - unblocking is needed if you ever re-enable it.'
    'hosts.news.name'                = 'Brave News CDN'
    'hosts.p3a.description'          = 'Privacy-preserving analytics endpoints. Pure telemetry, never user-facing. Safe to block.'
    'hosts.p3a.name'                 = 'Brave P3A telemetry'
    'hosts.rewards.description'      = 'Brave Rewards (BAT) servers. Block ONLY if you do not use Rewards. Will break the feature if you turn it on later.'
    'hosts.rewards.name'             = 'Brave Rewards / BAT'
    'hosts.stats.description'        = 'Daily/weekly/monthly anonymous usage ping. Safe to block.'
    'hosts.stats.name'               = 'Brave Stats ping'
    'hosts.variations.description'   = 'Field-trial / experiment config. Safe to block - matches ChromeVariations=2 policy.'
    'hosts.variations.name'          = 'Brave Variations'
    'hosts.webDiscovery.description' = 'Web Discovery Project endpoints. Already covered by BraveWebDiscoveryEnabled policy; only useful if policy is bypassed.'
    'hosts.webDiscovery.name'        = 'Web Discovery'
    'hostsTab.apply'                 = 'Apply hosts blocks'
    'hostsTab.groupLabel'            = '{0}  [{1} domain(s)]'
    'hostsTab.intro'                 = 'Optional second layer of defense: nullroute Brave telemetry domains in C:\Windows\System32\drivers\etc\hosts. Even if a policy is bypassed by an update, the network call still fails. Sentinel-tagged for clean revert. Backups land in Documents\Brave-Free-Origin-Backups.'
    'hostsTab.load'                  = 'Load current state'
    'hostsTab.open'                  = 'Open hosts file'
    'hostsTab.preview'               = 'Preview hosts'
    'hostsTab.remove'                = 'Remove hosts block'
    'hostsTab.inSync'                = 'The hosts file matches these groups.'
    'hostsTab.pending'               = '{0} group(s) changed and not written to the hosts file yet.'
    'hostsTab.warn'                  = 'Independent of the "Apply to Brave" button. Use the buttons on this page to apply or remove the hosts block.'
}

# ---- Scriptlet manager -------------------------------------------------------
Add-Strings @{
    'scriptlet.advancedMode'    = 'Advanced edit mode (allow list.txt modifications)'
    'scriptlet.affectDupes'     = 'Affect duplicate raw rules in the same file'
    'scriptlet.autoPath'        = 'Auto path'
    'scriptlet.backupAll'       = 'Backup all lists'
    'scriptlet.browse'          = 'Browse...'
    'scriptlet.checkFiltered'   = 'Check filtered'
    'scriptlet.clearChecks'     = 'Clear checks'
    'scriptlet.col.arguments'   = 'Arguments'
    'scriptlet.col.domain'      = 'Domain'
    'scriptlet.col.line'        = 'Line'
    'scriptlet.col.rawRule'     = 'Raw rule'
    'scriptlet.col.scriptlet'   = 'Scriptlet'
    'scriptlet.col.source'      = 'Source / version'
    'scriptlet.col.status'      = 'Status'
    'scriptlet.disableChecked'  = 'Disable checked'
    'scriptlet.disabledOnly'    = 'Show disabled by this app only'
    'scriptlet.enableChecked'   = 'Enable checked'
    'scriptlet.exportCsv'       = 'Export visible CSV'
    'scriptlet.exportPrefs'     = 'Export disabled prefs'
    'scriptlet.importPrefs'     = 'Import + reapply prefs'
    'scriptlet.more'            = 'More'
    'scriptlet.intro'           = 'Optional advanced tool: view Brave''s built-in adblock scriptlet rules from component filter lists. Editing is manual-only, never part of presets, and never triggered by Apply to Brave.'
    'scriptlet.openFolder'      = 'Open folder'
    'scriptlet.restoreAll'      = 'Restore all backups'
    'scriptlet.restoreSelected' = 'Restore selected file'
    'scriptlet.risk'            = 'Risk: disabling scriptlets can break adblocking, anti-annoyance fixes, cookie banners, video sites, or site compatibility. Brave updates may replace component versions; export disabled preferences and reapply after updates if needed.'
    'scriptlet.rootLabel'       = 'Brave User Data folder:'
    'scriptlet.scan'            = 'Scan'
    'scriptlet.scanDone'        = ' Scan completed in {0}s.'
    'scriptlet.searchPlaceholder' = 'Search domains, scriptlets, arguments and rules'
    'scriptlet.state.disabled'  = 'Disabled'
    'scriptlet.state.enabled'   = 'Enabled'
    'scriptlet.statusFinding'   = 'Finding Brave scriptlet list files...'
    'scriptlet.statusIdle'      = 'Scan a Brave User Data folder to list internal scriptlet rules.'
    'scriptlet.statusCancelled' = 'Scan cancelled.'
    'scriptlet.statusScanning'  = 'Scanning file {0} / {1}: {2}. Found {3} rule(s). {4}%. {5}s'
    'scriptlet.statusShowing'   = 'Showing {0} / {1}. Enabled: {2}. Disabled: {3}. Checked: {4}.'
    'scriptlet.tipAffectDupes'  = 'Brave lists can contain the same scriptlet rule multiple times. Leave this on unless you only want the exact selected line.'
    'scriptlet.tipCheckFiltered' = 'Checks every row matching the active search/show filters, including rows not currently painted in the table.'
    'scriptlet.viewSelected'    = 'View selected'
}

# ---- Search and startup ------------------------------------------------------
# Search engine brand names are labels only; ProviderName in the data model is what reaches the registry.
Add-Strings @{
    'destination.blank'           = 'Blank page (about:blank)'
    'destination.braveSearchHome' = 'Brave Search homepage'
    'destination.custom'          = 'Custom URL...'
    'destination.duckduckgoHome'  = 'DuckDuckGo homepage'
    'destination.googleHome'      = 'Google homepage'
    'destination.matchSearch'     = 'Match the search engine I picked above'
    'engine.bing'                 = 'Bing'
    'engine.brave'                = 'Brave Search'
    'engine.custom'               = 'Custom...'
    'engine.duckduckgo'           = 'DuckDuckGo'
    'engine.ecosia'               = 'Ecosia'
    'engine.google'               = 'Google'
    'engine.kagi'                 = 'Kagi (paid)'
    'engine.mojeek'               = 'Mojeek'
    'engine.qwant'                = 'Qwant'
    'engine.startpage'            = 'Startpage'
    'engine.yandex'               = 'Yandex'
    'searchTab.chkNtp'            = 'Override new tab page (writes NewTabPageLocation policy)'
    'searchTab.chkSearch'         = 'Force a default search engine (writes DefaultSearchProvider* policies)'
    'searchTab.chkStartup'        = 'Override startup behavior (writes RestoreOnStartup + RestoreOnStartupURLs policies)'
    'searchTab.conflictNote'      = 'These overrides are written AFTER the Performance / Startup policies, so they cleanly override any ''NewTabPageLocation'' / ''HomepageLocation'' / ''RestoreOnStartup'' values set there. Turning one off + Apply removes the override and lets your Performance / Startup values (or stock Brave) take back over.'
    'searchTab.customLabel'       = 'Custom search URL:'
    'searchTab.engineLabel'       = 'Engine:'
    'searchTab.intro'             = 'Pick the omnibox search engine and what opens when Brave launches / when you open a new tab. Each section is independent and only takes effect when its switch is on. Turning it off + Apply removes the override.'
    'searchTab.modeLabel'         = 'Mode:'
    'searchTab.ntpCustomLabel'    = 'Custom URL:'
    'searchTab.ntpOpenLabel'      = 'Open:'
    'searchTab.searchHelp'        = 'Custom must use {{searchTerms}} as the placeholder. Example: https://my-searx/search?q={{searchTerms}}'
    'searchTab.secNtp'            = 'New Tab Page'
    'searchTab.secSearch'         = 'Default search engine (omnibox / address bar)'
    'searchTab.secStartup'        = 'Startup Behavior (what opens when you launch Brave)'
    'searchTab.startupHelp'       = 'For "specific page or set", separate multiple URLs with a comma. Each opens in its own tab.'
    'searchTab.urlLabel'          = 'URL(s):'
    'startupMode.blankPage'       = 'Open a blank page'
    'startupMode.newTab'          = 'Open the new tab page'
    'startupMode.restoreSession'  = 'Restore my last session'
    'startupMode.specificPages'   = 'Open a specific page or set'
}

# ---- Extensions --------------------------------------------------------------
Add-Strings @{
    'ext.bitwarden' = 'Install Bitwarden (password manager)'
    'ext.intro'     = 'Brave Shields is already a native ad/tracker blocker (same filter-list lineage as uBlock Origin, runs in-engine so slightly faster). We do NOT force-install anything - that would show a ''Managed by your organization'' banner and lock the extension on. These buttons just open the install pages in Brave so you can decide.'
    'ext.section'   = 'Extensions (optional, manual install)'
    'ext.shields'   = 'Open Brave Shields settings'
    'ext.uboLite'   = 'Install uBlock Origin Lite (MV3)'
    'ext.warn'      = 'Caution: running uBlock Origin on top of Shields = double-blocking. Wastes CPU per tab and can break sites Shields handles fine. If you install uBO, consider switching Shields to Standard (not Aggressive) to reduce overlap.'
}

# ---- Utility bar -------------------------------------------------------------
Add-Strings @{
    'action.apply'       = 'Apply to Brave'
    'action.backup'      = 'Backup existing policies before applying'
    'action.fullRestore' = 'Full restore / stock'
    'action.preview'     = 'Preview changes'
    'util.export'        = 'Export config'
    'util.import'        = 'Import config'
    'util.loadState'     = 'Load current state'
    'util.openPolicy'    = 'Open brave://policy'
    'util.verify'        = 'Verify'
}

# ---- Reports -----------------------------------------------------------------
# Report bodies stay English on purpose - they get pasted into bug reports.
Add-Strings @{
    'report.close'          = 'Close'
    'report.copy'           = 'Copy'
    'report.hostsTitle'     = 'Hosts preview'
    'report.previewTitle'   = 'Preview apply changes'
    'report.save'           = 'Save report'
    'report.scriptletTitle' = 'Scriptlet details'
    'report.verifyTitle'    = 'Verify - registry vs selections'
}

# ---- File dialogs ------------------------------------------------------------
# Only the human-readable half of a filter is translatable. The *.txt / *.json
# glob is concatenated in code, so a translation can never produce a filter
# string that Windows refuses to parse.
Add-Strings @{
    'dialog.browseUserData'        = 'Select Brave User Data folder'
    'dialog.filter.config'         = 'JSON config'
    'dialog.filter.csv'            = 'CSV'
    'dialog.filter.scriptletPrefs' = 'Scriptlet preferences'
    'dialog.filter.textReport'     = 'Text report'
}

# ---- Dialogs -----------------------------------------------------------------
Add-Strings @{
    'msg.braveMissing'                = 'Brave not found on this machine.'
    'msg.config.badJson'              = 'Bad JSON: {0}'
    'msg.config.imported'             = 'Nothing is written until you click Apply to Brave (and Apply hosts blocks on the Hosts page, if needed).'
    'msg.failed'                      = 'Failed: {0}'
    'msg.hosts.applied'               = "Hosts file updated. {0} domain(s) blocked.`r`nDNS cache flushed."
    'msg.hosts.confirmApply'          = "About to add {0} entries to:`r`n{1}`r`n`r`nA timestamped backup will be saved first. Continue?"
    'msg.hosts.confirmRemove'         = "Remove the Brave-Free-Origin sentinel block from hosts?`r`n(Your other hosts entries are not touched.)"
    'msg.hosts.noGroups'              = 'No groups ticked. This will remove the existing hosts block (if any). Continue?'
    'msg.hosts.removed'               = 'Sentinel block removed.'
    'msg.language.switched'           = 'Language switched to {0}.'
    'msg.restore.confirm'             = "This will restore stock behavior for: {0}`r`n`r`nIt removes Brave policy keys, clears the Brave-Free-Origin hosts block, re-enables known Brave update tasks, and resets known disabled Brave services to Manual.`r`n`r`nContinue?"
    'msg.restore.done'                = 'Full restore completed. Restart Brave to see stock behavior.'
    'msg.scriptlet.backupDone'        = 'Backups checked/created for {0} list file(s).'
    'msg.scriptlet.backupFailed'      = "Backup failed:`r`n{0}"
    'msg.scriptlet.braveRunning'      = "Brave is currently running ({0} process(es)).`r`n`r`nClose Brave first if you want the safest patch. Continue anyway?"
    'msg.scriptlet.confirmDisable'    = "Disable {0} checked/selected scriptlet rule(s)?`r`n`r`nThis comments rules with: {1}`r`nBackups are created as list.txt.bfo-backup before the first edit."
    'msg.scriptlet.confirmReapply'    = "Reapply disabled scriptlet preferences to the current component lists under:`r`n{0}`r`n`r`nThis comments active rules whose raw text matches the preference file. Continue?"
    'msg.scriptlet.confirmRestoreAll' = "Restore every list.txt.bfo-backup under:`r`n{0}`r`n`r`nThis discards all BFO scriptlet edits in backed-up lists. Continue?"
    'msg.scriptlet.confirmRestoreSel' = "Restore {0} selected list file(s) from .bfo-backup?`r`nThis discards BFO scriptlet edits in those file(s)."
    'msg.scriptlet.disableFailed'     = "Disable failed:`r`n{0}"
    'msg.scriptlet.enableFailed'      = "Enable failed:`r`n{0}"
    'msg.scriptlet.exportFailed'      = "Export failed:`r`n{0}"
    'msg.scriptlet.folderMissing'     = 'Folder not found. Use Browse to choose the correct Brave User Data folder.'
    'msg.scriptlet.locked'            = "Editing Brave's internal filter-list files is disabled.`r`n`r`nTurn on 'Advanced edit mode' on the Scriptlets page first."
    'msg.scriptlet.noFiles'           = "No Brave filter-list files were found in:`r`n{0}`r`n`r`nUse Browse if your Brave User Data folder lives somewhere else."
    'msg.scriptlet.noRules'           = "No Brave scriptlet rules were found in:`r`n{0}`r`n`r`nUse Browse if your Brave User Data folder lives somewhere else."
    'msg.scriptlet.noRulesLoaded'     = 'Scan first; there are no scriptlet rules loaded.'
    'msg.scriptlet.nothingVisible'    = 'Nothing visible to export. Scan or change the filter first.'
    'msg.scriptlet.reapplyFailed'     = "Reapply failed:`r`n{0}"
    'msg.scriptlet.restoreAllFailed'  = "Restore all failed:`r`n{0}"
    'msg.scriptlet.restoreFailed'     = "Restore failed:`r`n{0}"
    'msg.scriptlet.restoreSelectFile' = 'Select a rule from the file you want to restore.'
    'msg.scriptlet.scanFailed'        = "Could not scan scriptlets:`r`n{0}`r`n`r`nUse Browse to point Brave-Free-Origin at the correct Brave User Data folder."
    'msg.scriptlet.scanFirst'         = 'Scan first; no scriptlet list files are loaded.'
    'msg.scriptlet.selectFirst'       = 'Check or select one or more scriptlet rules first.'
    'msg.scriptlet.selectOne'         = 'Select a scriptlet rule first.'
    'msg.title.app'                   = 'Brave Free Origin'
    'msg.title.done'                  = 'Done'
    'msg.title.error'                 = 'Error'
    'msg.title.fullRestore'           = 'Full restore / stock'
    'msg.title.hosts'                 = 'Hosts blocklist'
    'msg.title.importError'           = 'Import error'
    'msg.title.imported'              = 'Imported'
    'msg.title.info'                  = 'Info'
    'msg.title.scriptlet'             = 'Scriptlet manager'
}
