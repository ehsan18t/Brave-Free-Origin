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
    'header.braveDetected'    = 'Brave detected: {0}'
    'header.channels'         = 'Installed: {0}'
    'header.noChannels'       = 'Brave is not installed'
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
    'home.statFlags'       = 'Flags'
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
    'toast.appliedNoFlags' = 'Set {0} policies and cleared {1}. Flags were not written because Brave is running ({2}): close it and apply again.'
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
    'settings.backupFolderDesc' = 'Registry, hosts and Local State backups, saved reports and exported configs.'
    'settings.config'           = 'Configuration'
    'settings.configDesc'       = 'Save your selection to a JSON file, or load one. Loading writes nothing until you apply.'
    'settings.configFile'       = 'Config file'
    'settings.language'         = 'Language'
    'settings.languageDesc'     = 'Reports and the activity log stay in English, so they can go into bug reports.'
    'settings.loadDesc'         = 'Switch on exactly what this PC already has: policies, tasks, services, the hosts block and overrides.'
    'settings.open'             = 'Open'
    'settings.policyDesc'       = 'See what Brave itself reports for every policy.'
    'settings.policyKey'        = 'Policy key'
    'settings.policyKeyDesc'    = 'Every Brave channel (Stable, Beta, Nightly, Dev) reads its policies from this one key, so they all get the same settings. Flags go into each installed channel''s own Local State.'
    'settings.restore'          = 'Restore'
    'settings.restoreDesc'      = 'Removes every Brave policy, the flags this app manages and the hosts block, and re-enables Brave update tasks and services.'
    'settings.target'           = 'Where changes go'
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
    'impact.mayBreakSites.explain' = 'Some sites may not load or work until you give them an exception in Shields or site settings.'
    'impact.mayBreakSites.name'   = 'Can break some sites'
    'impact.noAutofill.explain'   = 'Brave stops saving and filling in passwords, addresses or cards. Use a separate password manager if you rely on one.'
    'impact.noAutofill.name'      = 'Stops saving your details'
    'impact.noDrm.explain'        = 'Components such as Widevine stop updating, so Netflix, Spotify and other protected video or music can stop playing.'
    'impact.noDrm.name'           = 'Can break protected video'
    'impact.staleFilters.explain' = 'Shields filter lists stop updating, so new ads and trackers slip through over time.'
    'impact.staleFilters.name'    = 'Freezes ad-block lists'
    'impact.wipesData.explain'    = 'Browsing history is not kept, and closing Brave wipes cookies, cache, saved passwords and autofill. Bookmarks, settings and extensions stay.'
    'impact.wipesData.name'       = 'Wipes data on exit'
    'impact.noSync.explain'       = 'Brave Sync and account sign-in stop working on this PC.'
    'impact.noSync.name'          = 'Turns off sync and sign-in'
    'impact.noUpdates.explain'    = 'Brave will stop updating itself in the background. Check for updates yourself at brave://settings/help now and then.'
    'impact.noUpdates.name'       = 'Stops auto-updates'
}

# ---- Apply preview: the "What will happen" tab -----------------------------------------
Add-Strings @{
    'preview.changed'         = '{0}: currently {1}, becomes {2}'
    'preview.cleared'         = '{0}: currently {1}, will be removed'
    'preview.flagCleared'     = 'brave://flags {0}: back to Default'
    'preview.flagSet'         = 'brave://flags {0}'
    'preview.flagsBlocked'    = 'Brave is running ({0}). Flags can only be written while it is closed; Apply will ask what to do.'
    'preview.homeCleared'     = 'The home button goes back to your own setting'
    'preview.homeSet'         = 'The home button opens: {0}'
    'preview.lead'            = 'Applying {0} to Brave makes {1} change(s). {2} setting(s) are already in place and stay as they are.'
    'preview.leadNone'        = 'Everything is already in place. Applying now changes nothing.'
    'preview.legacyKey'       = 'Old policy key from an earlier version of this app (Brave never read it)'
    'preview.retired'         = '{0}: no longer used, will be removed'
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
# Preset ids (Default, Origin, ...) are stable and never translated.
Add-Strings @{
    'preset.CurrentState.description' = 'Read from this PC. Shows what is already set right now.'
    'preset.CurrentState.name'        = 'Current State'
    'preset.CurrentState.risk'        = 'Read only'
    'preset.Custom.description'       = 'Hand-picked mix. Use the pages on the left to build your own Brave loadout.'
    'preset.Custom.name'              = 'Custom'
    'preset.Custom.risk'              = 'Depends on your picks'
    'preset.Default.description'      = 'Brave as a fresh install leaves it. Unticks everything this app manages, so Apply removes it.'
    'preset.Default.name'             = 'Default'
    'preset.Default.risk'             = 'No changes'
    'preset.Max.description'          = 'Strict, plus Brave forgets you: history is never saved, cookies last one session and closing Brave wipes the rest. Bookmarks, settings and extensions stay. For shared or public PCs.'
    'preset.Max.name'                 = 'Max'
    'preset.Max.risk'                 = 'Forgets you on exit'
    'preset.Origin.description'       = 'The 16 features the paid Brave Origin turns off: Leo, Rewards and Ads, Wallet, VPN, News, Talk, Tor, Wayback, Speedreader, Playlist, Email Aliases, PSST, local AI, Web Discovery, P3A and the usage ping.'
    'preset.Origin.name'              = 'Origin'
    'preset.Origin.risk'              = 'Low risk'
    'preset.Recommended.description'  = 'Origin, plus telemetry and promos off and Brave''s tracking protections locked on. Nothing breaks, and you keep passwords, sync and updates.'
    'preset.Recommended.name'         = 'Recommended'
    'preset.Recommended.risk'         = 'Low risk'
    'preset.Strict.description'       = 'Recommended, plus HTTPS only, no permission prompts, WebRTC IP protection and stronger anti-fingerprinting. Keeps your logins and history; a few sites need an exception.'
    'preset.Strict.name'              = 'Strict'
    'preset.Strict.risk'              = 'Some friction'
}

# ---- Setting notes -----------------------------------------------------------
# The line under a policy or flag: why it is greyed out, or what Brave does
# when the row is left alone.
Add-Strings @{
    'row.braveDefault'   = 'Brave''s default: {0}.'
    'row.changesDefault' = 'Changes a Brave default.'
    'row.flagDefaultOff' = 'Off by default in brave://flags.'
    'row.flagDefaultOn'  = 'On by default in brave://flags; ticking turns it off.'
    'row.lockOnly'       = 'Already Brave''s default. Ticking locks it so it cannot be changed in Brave.'
    'row.needsBrave'     = 'Needs Brave 1.{0} or newer. This PC has 1.{1}.'
    'row.needsChromium'  = 'Needs a newer Brave (Chromium {0} or later). This PC has Chromium {1}.'
    'row.tooNew'         = 'Brave stopped reading this after Chromium {0}. This PC has Chromium {1}.'
}

# ---- Drift: applied settings no longer in effect ------------------------------
Add-Strings @{
    'drift.accept'          = 'Keep as is'
    'drift.cleanup'         = 'Clean up'
    'drift.done.Accept'     = 'Kept as is'
    'drift.done.Cleanup'    = 'Cleaned up'
    'drift.done.Reapply'    = 'Re-applied'
    'drift.doneText'        = 'Restart Brave to see the changes.'
    'drift.hostsTitle'      = 'Hosts blocklist'
    'drift.missing'         = 'not set'
    'drift.overrideTitle'   = 'Search & Startup: {0}'
    'drift.reapply'         = 'Re-apply'
    'drift.repeatDetail'    = '{0} was re-applied and undone again. Something keeps changing it back: another tweak tool, a Group Policy or security software.'
    'drift.retiredDetail'   = '{0} is no longer used by Brave. {1}'
    'drift.revertedDetail'  = '{0}: set to {1}, now {2}.'
    'drift.skippedRunning'  = 'Some flags were not changed because Brave is running. Close it and try again.'
    'drift.text'            = 'Compared with what was applied on {0}.'
    'drift.title'           = '{0}: {1} setting(s) are no longer in effect'
    'retired.reason.builtOut'   = 'Brave builds this feature out, so the policy changes nothing.'
    'retired.reason.expired'    = 'Chromium no longer reads this policy.'
    'retired.reason.notAPolicy' = 'Brave has no policy by this name.'
    'retired.reason.removed'    = 'Brave removed this feature.'
    'retired.reason.renamed'    = 'This policy has a new name.'
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
    'tab.flags'         = 'Flags (brave://flags)'
    'tab.hosts'         = 'Hosts Blocklist (DNS-level)'
    'tab.scriptlets'    = 'Default Scriptlets (Advanced)'
    'tab.searchStartup' = 'Search & Startup'
    'tab.system'        = 'System (Tasks / Services)'
}

# ---- Policy categories -------------------------------------------------------
Add-Strings @{
    'category.aiGenAi'               = 'AI'
    'category.autofillPasswords'     = 'Passwords, Autofill and Sync'
    'category.braveFeatures'         = 'Brave Features'
    'category.historyData'           = 'History and Site Data'
    'category.performanceStartup'    = 'Performance'
    'category.privacyTelemetry'      = 'Telemetry'
    'category.safetyUpdates'         = 'Safety and Updates'
    'category.searchSuggestions'     = 'Search and Language'
    'category.shields'               = 'Shields and Tracking'
    'category.sitePermissions'       = 'Site Permissions'
    'category.uiBloatExtras'         = 'Interface and Clutter'
    'category.webServicesBackground' = 'Network and Background'
}

# ---- Policy descriptions -----------------------------------------------------
# Keyed on the registry value name, which is never translated. Each says what
# ticking the row does; the note under it says whether that is already
# Brave's default.
Add-Strings @{
    'policy.AccessibilityImageLabelsEnabled.description'              = 'Keep image descriptions for screen readers off (they send images to a server).'
    'policy.AlternateErrorPagesEnabled.description'                   = 'Keep suggestion pages for unreachable sites off.'
    'policy.AutofillAddressEnabled.description'                       = 'Turn off address and contact autofill.'
    'policy.AutofillCreditCardEnabled.description'                    = 'Turn off payment card autofill.'
    'policy.AutoplayAllowed.description'                              = 'Stop video and audio from playing on their own.'
    'policy.BackgroundModeEnabled.description'                        = 'Stop Brave from running in the background after its last window closes.'
    'policy.BatterySaverModeAvailability.description'                 = 'Turn on Energy Saver whenever the PC runs on battery.'
    'policy.BookmarkBarEnabled.description'                           = 'Hide the bookmarks bar.'
    'policy.BraveAIChatEnabled.description'                           = 'Turn off Leo, the AI assistant.'
    'policy.BraveDeAmpEnabled.description'                            = 'Keep Google AMP pages skipped in favor of the real site.'
    'policy.BraveDebouncingEnabled.description'                       = 'Keep bounce-tracking redirects skipped.'
    'policy.BraveGlobalPrivacyControlEnabled.description'             = 'Keep the Global Privacy Control "do not sell or share" signal on.'
    'policy.BraveLocalAIEnabled.description'                          = 'Turn off on-device AI models, such as the one behind AI history search, and stop downloading them.'
    'policy.BraveNewsDisabled.description'                            = 'Turn off Brave News on the new tab page.'
    'policy.BraveP3AEnabled.description'                              = 'Stop sending P3A product analytics.'
    'policy.BravePlaylistEnabled.description'                         = 'Turn off Playlist (saving videos and audio for later).'
    'policy.BraveReduceLanguageEnabled.description'                   = 'Keep your language preferences from being used to fingerprint you.'
    'policy.BraveRewardsDisabled.description'                         = 'Turn off Brave Rewards and Brave Ads, and hide their buttons.'
    'policy.BraveSpeedreaderEnabled.description'                      = 'Turn off Speedreader, the simplified reading view.'
    'policy.BraveStatsPingEnabled.description'                        = 'Stop the daily, weekly and monthly usage ping.'
    'policy.BraveTalkDisabled.description'                            = 'Turn off Brave Talk video calls.'
    'policy.BraveTrackingQueryParametersFilteringEnabled.description' = 'Keep tracking parameters (utm_, fbclid and similar) stripped from links.'
    'policy.BraveVPNDisabled.description'                             = 'Turn off Brave VPN and hide its button.'
    'policy.BraveWalletDisabled.description'                          = 'Turn off the built-in crypto wallet.'
    'policy.BraveWaybackMachineEnabled.description'                   = 'Stop offering the Wayback Machine on missing pages.'
    'policy.BraveWebDiscoveryEnabled.description'                     = 'Keep Web Discovery off (it contributes browsing data to Brave Search).'
    'policy.BrowserSignin.description'                                = 'Turn off browser sign-in.'
    'policy.BuiltInDnsClientEnabled.description'                      = 'Use Windows for DNS instead of Brave''s own resolver.'
    'policy.ChromeVariations.choice.criticalOnly'                     = 'Critical fixes only'
    'policy.ChromeVariations.choice.none'                             = 'None'
    'policy.ChromeVariations.description'                             = 'Limit the remote experiments Brave can switch on for this browser. "Critical fixes only" keeps emergency fixes working.'
    'policy.ClearBrowsingDataOnExitList.description'                  = 'When Brave closes, wipe history, the downloads list, cookies, cache, saved passwords, autofill, site permissions and app data.'
    'policy.ComponentUpdatesEnabled.description'                      = 'Stop component updates. Shields filter lists, Widevine and other components stop updating.'
    'policy.DefaultBraveAdblockSetting.description'                   = 'Keep Shields ad and tracker blocking on by default.'
    'policy.DefaultBraveFingerprintingV2Setting.description'          = 'Keep fingerprinting protection on by default. A policy can only set Standard; the Strict option is a flag.'
    'policy.DefaultBraveHttpsUpgradeSetting.choice.standard'          = 'Standard'
    'policy.DefaultBraveHttpsUpgradeSetting.choice.strict'            = 'Strict'
    'policy.DefaultBraveHttpsUpgradeSetting.description'              = 'Upgrade sites to HTTPS. Strict warns before opening any site that has no HTTPS.'
    'policy.DefaultBraveReferrersSetting.description'                 = 'Keep cross-site referrers trimmed by default.'
    'policy.DefaultBraveRemember1PStorageSetting.description'         = 'Forget a site''s cookies and storage as soon as you close its tabs.'
    'policy.DefaultBrowserSettingEnabled.description'                 = 'Stop Brave from asking to be the default browser. It can no longer be made default from its settings either.'
    'policy.DefaultCookiesSetting.description'                        = 'Keep cookies only until Brave closes.'
    'policy.DefaultGeolocationSetting.description'                    = 'Stop sites from asking for your location.'
    'policy.DefaultLocalFontsSetting.description'                     = 'Stop sites from asking for the list of fonts on this PC.'
    'policy.DefaultNotificationsSetting.description'                  = 'Stop sites from asking to show notifications.'
    'policy.DefaultSensorsSetting.description'                        = 'Stop sites from reading motion and light sensors.'
    'policy.DefaultSerialGuardSetting.description'                    = 'Stop sites from asking for serial ports.'
    'policy.DefaultWebBluetoothGuardSetting.description'              = 'Stop sites from asking for Bluetooth devices.'
    'policy.DefaultWebHidGuardSetting.description'                    = 'Stop sites from asking for HID devices (game controllers, keyboards and similar).'
    'policy.DefaultWebUsbGuardSetting.description'                    = 'Stop sites from asking for USB devices.'
    'policy.DiskCacheSize.description'                                = 'Cap the disk cache at 250 MB.'
    'policy.DnsOverHttpsMode.choice.automatic'                        = 'Automatic'
    'policy.DnsOverHttpsMode.choice.off'                              = 'Off'
    'policy.DnsOverHttpsMode.description'                             = 'Secure DNS. Automatic uses DNS over HTTPS whenever your DNS provider supports it.'
    'policy.EmailAliasesEnabled.description'                          = 'Turn off Email Aliases (forwarding addresses from Brave).'
    'policy.EnableMediaRouter.description'                            = 'Turn off casting (Google Cast) and its network discovery.'
    'policy.HardwareAccelerationModeEnabled.choice.disable'           = 'Disable'
    'policy.HardwareAccelerationModeEnabled.choice.enable'            = 'Enable'
    'policy.HardwareAccelerationModeEnabled.description'              = 'GPU hardware acceleration. Pick Disable to work around GPU driver glitches or crashes.'
    'policy.HighEfficiencyModeEnabled.description'                    = 'Turn on Memory Saver, which puts inactive tabs to sleep.'
    'policy.ImportAutofillFormData.description'                       = 'Stop importing autofill data from other browsers.'
    'policy.ImportBookmarks.description'                              = 'Stop importing bookmarks from other browsers.'
    'policy.ImportHistory.description'                                = 'Stop importing history from other browsers.'
    'policy.ImportSavedPasswords.description'                         = 'Stop importing saved passwords from other browsers.'
    'policy.ImportSearchEngine.description'                           = 'Stop importing the search engine from other browsers.'
    'policy.MetricsReportingEnabled.description'                      = 'Keep usage and crash reports off.'
    'policy.NTPCustomBackgroundEnabled.description'                   = 'Stop your own images from being used as the new tab background.'
    'policy.NetworkPredictionOptions.description'                     = 'Keep link preloading off.'
    'policy.PasswordLeakDetectionEnabled.description'                 = 'Keep the leaked-password check off (it sends hashed passwords to be checked).'
    'policy.PasswordManagerEnabled.description'                       = 'Turn off the built-in password manager (use Bitwarden or another manager instead).'
    'policy.PaymentMethodQueryEnabled.description'                    = 'Stop sites from checking whether you have saved payment methods.'
    'policy.PromotionsEnabled.description'                            = 'Hide promotional content in the browser.'
    'policy.PromptForDownloadLocation.description'                    = 'Save downloads straight to the Downloads folder without asking where.'
    'policy.PsstEnabled.description'                                  = 'Turn off PSST, which offers to change privacy settings on sites you visit.'
    'policy.QuicAllowed.choice.disable'                               = 'Disable'
    'policy.QuicAllowed.choice.enable'                                = 'Enable'
    'policy.QuicAllowed.description'                                  = 'Allow or block the QUIC (HTTP/3) protocol.'
    'policy.SafeBrowsingDeepScanningEnabled.description'              = 'Keep downloads from being uploaded for deep scanning.'
    'policy.SafeBrowsingExtendedReportingEnabled.description'         = 'Keep extended Safe Browsing reporting off.'
    'policy.SafeBrowsingProtectionLevel.description'                  = 'Keep Safe Browsing on its standard level.'
    'policy.SafeBrowsingSurveysEnabled.description'                   = 'Turn off Safe Browsing surveys.'
    'policy.SavingBrowserHistoryDisabled.description'                 = 'Never save browsing history.'
    'policy.SearchSuggestEnabled.description'                         = 'Keep search suggestions off, so what you type is not sent while you type it.'
    'policy.ShowHomeButton.description'                               = 'Keep the home button hidden.'
    'policy.SpellCheckServiceEnabled.description'                     = 'Keep the online spelling service off.'
    'policy.SpellcheckEnabled.description'                            = 'Turn off spell checking completely.'
    'policy.SyncDisabled.description'                                 = 'Turn off Brave Sync.'
    'policy.TorDisabled.description'                                  = 'Turn off private windows with Tor. (For real anonymity, use Tor Browser.)'
    'policy.TranslateEnabled.description'                             = 'Turn off the offer to translate pages.'
    'policy.UrlKeyedAnonymizedDataCollectionEnabled.description'      = 'Keep "make searches and browsing better" URL reporting off.'
    'policy.UserFeedbackAllowed.description'                          = 'Remove the Send feedback option, which uploads diagnostics.'
    'policy.WebRtcEventLogCollectionAllowed.description'              = 'Keep WebRTC call logs from being collected.'
    'policy.WebRtcIPHandling.choice.proxyOnly'                        = 'Only through a proxy'
    'policy.WebRtcIPHandling.choice.publicOnly'                       = 'Public address only'
    'policy.WebRtcIPHandling.description'                             = 'Stop WebRTC from revealing your local IP address.'
}

# ---- Flags -------------------------------------------------------------------
# Keyed on the brave://flags id, which is never translated.
Add-Strings @{
    'flag.brave-adblock-default-1p-blocking.description'       = 'Let Shields block first-party requests in Standard mode too, not only in Aggressive.'
    'flag.brave-adblock-experimental-list-default.description' = 'Turn on Brave''s experimental ad-block rules.'
    'flag.brave-clean-link-js-api.description'                 = 'Strip tracking parameters from links that sites copy or share for you.'
    'flag.brave-extension-network-blocking.description'        = 'Let Shields block trackers in requests made by extensions.'
    'flag.brave-news-peek.description'                         = 'Stop Brave News from peeking up on the new tab page.'
    'flag.brave-ntp-search-widget.description'                 = 'Remove the search box from the new tab page.'
    'flag.brave-request-otr-tab.description'                   = 'Offer a private tab when you open a sensitive site.'
    'flag.brave-round-time-stamps.description'                 = 'Round high-resolution timers to the millisecond, so sites cannot use them to fingerprint you.'
    'flag.brave-show-strict-fingerprinting-mode.description'   = 'Show the Strict option for fingerprinting protection in Shields. Pick it there after applying.'
    'flags.intro'                                              = 'Flags go into each installed channel''s Local State, so Brave must be closed when you apply them; the rest applies either way. Only flags that do something useful and have been in Brave for at least a year are listed. If Brave removes one later, it simply ignores it.'
    'msg.flags.braveRunning'                                   = "Brave is running ({0}).`r`n`r`nFlags can only be written while it is closed. Apply everything else now and leave the flags for later?"
    'msg.title.flags'                                          = 'Flags'
}

# ---- Tasks and services ------------------------------------------------------
Add-Strings @{
    'service.BraveVPNService.description'                 = 'Brave VPN helper service, one per installed channel (present only once Brave VPN has been set up).'
    'service.BraveVpnWireguardService.description'        = 'Brave VPN WireGuard service, one per installed channel (present only once Brave VPN has been set up).'
    'service.brave.description'                           = 'Brave Update service: installs Brave updates in the background.'
    'service.bravem.description'                          = 'Brave Update service (on-demand helper for update checks started from Brave).'
    'system.intro'                                        = 'No mode touches this page: Brave''s updates bring security fixes, so turning them off is your call. The Brave Elevation Service is not listed on purpose: Brave uses it to decrypt your cookies and saved passwords, so disabling it signs you out of sites.'
    'system.svcHdr'                                       = 'Windows Services'
    'system.tasksHdr'                                     = 'Scheduled Tasks'
    'task.BraveSoftwareUpdateTaskMachineCore.description' = 'Brave''s regular background update check.'
    'task.BraveSoftwareUpdateTaskMachineUA.description'   = 'Brave''s hourly update check and download.'
}

# ---- Hosts blocklist ---------------------------------------------------------
Add-Strings @{
    'hosts.components.description'   = 'Brave''s component and extension update servers. Blocking them freezes Shields filter lists, Widevine (Netflix, Spotify) and extension updates. No mode ticks this.'
    'hosts.components.name'          = 'Component Updates'
    'hosts.news.description'         = 'Brave News feed server. Block only while News is turned off; unblock it if you turn News back on.'
    'hosts.news.name'                = 'Brave News'
    'hosts.p3a.description'          = 'The servers P3A analytics are sent to. Pure telemetry, nothing you use. Safe to block.'
    'hosts.p3a.name'                 = 'Brave P3A analytics'
    'hosts.rewards.description'      = 'Brave Rewards and Brave Ads servers. Block only if you do not use Rewards; it stops working while blocked.'
    'hosts.rewards.name'             = 'Brave Rewards and Ads'
    'hosts.stats.description'        = 'The daily, weekly and monthly usage ping. Safe to block.'
    'hosts.stats.name'               = 'Brave usage ping'
    'hosts.variations.description'   = 'Remote experiments and emergency fixes. The Telemetry page can limit these to critical fixes instead; blocking cuts off the fixes too. No mode ticks this.'
    'hosts.variations.name'          = 'Brave Variations'
    'hosts.webDiscovery.description' = 'Web Discovery Project servers. The policy already keeps it off; this is a second layer.'
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
    'searchTab.chkHome'           = 'Set the home button''s page (writes HomepageIsNewTabPage + HomepageLocation policies)'
    'searchTab.chkNtp'            = 'Override new tab page (writes NewTabPageLocation policy)'
    'searchTab.chkSearch'         = 'Force a default search engine (writes DefaultSearchProvider* policies)'
    'searchTab.chkStartup'        = 'Override startup behavior (writes RestoreOnStartup + RestoreOnStartupURLs policies)'
    'searchTab.conflictNote'      = 'This page is the only place that sets the search engine, new tab page, homepage and startup behavior. Turning a section off and applying gives the choice back to you in Brave''s own settings. The Max mode sets startup to open a new tab, because restoring a session would bring its cookies back.'
    'searchTab.customLabel'       = 'Custom search URL:'
    'searchTab.engineLabel'       = 'Engine:'
    'searchTab.intro'             = 'Pick the omnibox search engine and what opens when Brave launches / when you open a new tab. Each section is independent and only takes effect when its switch is on. Turning it off + Apply removes the override.'
    'searchTab.modeLabel'         = 'Mode:'
    'searchTab.ntpCustomLabel'    = 'Custom URL:'
    'searchTab.ntpOpenLabel'      = 'Open:'
    'searchTab.searchHelp'        = 'Custom must use {{searchTerms}} as the placeholder. Example: https://my-searx/search?q={{searchTerms}}'
    'searchTab.secHome'           = 'Homepage (the home button)'
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
    'msg.restore.confirm'             = "This will put Brave back to stock.`r`n`r`nIt removes the Brave policy key, the flags this app manages (for every channel that is closed), and the Brave-Free-Origin hosts block, re-enables Brave update tasks, and resets disabled Brave services to Manual.`r`n`r`nContinue?"
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
