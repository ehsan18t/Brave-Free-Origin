# Tweak reference and sources

Every change Brave Free Origin can make, how it works inside Brave, and the source code it was verified against. `tweaks/README.md` explains the data format; this file explains the tweaks themselves.

Everything here was checked on 2026-09-25 against **Chromium 154.0.8037.58** and **brave-core 7489b1cc14** (master, Brave 1.98.30, the Chromium version Brave pinned at the time). Links point at those exact versions, so they keep working after the files move. The installed Brave used for live checks was 1.95 / Chromium 153, then 1.96 / Chromium 154.

## How to use this file

- The source links are the evidence. When Brave changes something, start from the linked file, not from memory or third-party lists.
- The tables are generated from `tweaks\` and `src\strings\en-US.ps1`; the notes and mechanism sections are hand-written. If a table disagrees with `tweaks\`, the data files win.
- [Re-verifying](#re-verifying-after-a-brave-update) at the end lists the checks to repeat when Brave moves to a new Chromium.

## Mechanisms

### Group policies (registry)

- **Where:** `HKLM\Software\Policies\BraveSoftware\Brave`. Every channel (Stable, Beta, Nightly, Dev) reads this one key. Brave hardcodes it in [generate_policy_source.py](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/chromium_src/components/policy/tools/generate_policy_source.py) (`CHROMIUM_POLICY_KEY`) and strips the channel suffix in [user_data_dir.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/chromium_src/chrome/install_static/user_data_dir.cc). Keys such as `Brave-Beta` are never read; the app removes them if an old version wrote them.
- **Types:** DWORD for booleans and enums, STRING for text, and LIST as a subkey named after the policy with values `1`, `2`, `3`... (the same layout as `RestoreOnStartupURLs`).
- **Brave's own policies** are defined in [policy_definitions/BraveSoftware](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware) and mapped to prefs in [brave_simple_policy_map.h](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/policy/brave_simple_policy_map.h). Many are wrapped in build flags (`ENABLE_BRAVE_REWARDS`, `ENABLE_TOR`...), so a Brave build without the feature simply ignores them.
- **Chromium policies** are defined in [policy_definitions](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions). Each YAML's `supported_on` gives the Chromium version range (the app's `MinChromium`), and `deprecated: true` marks policies on their way out.
- **Mandatory or recommended:** values in the key itself are mandatory: Brave applies them and greys the setting out. Values in its `Recommended` subkey are recommended: Brave starts from them and the user can change the setting, and a change wins until the user resets it ([policy_loader_win.cc](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/core/common/policy_loader_win.cc) reads the subkey as `POLICY_LEVEL_RECOMMENDED`). The settings page shows a building icon, not a lock, with "Your administrator recommends a specific value" ([cr_policy_pref_indicator.ts](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:ui/webui/resources/cr_elements/policy/cr_policy_pref_indicator.ts)).
- **`can_be_recommended` is not enforced for most policies:** every Brave policy and many Chromium ones say `can_be_recommended: false`, but that flag only feeds the ADMX templates and documentation. At runtime a recommended value is refused only by handlers that check the level. Tested on Brave 1.96.59 (Chromium 154): pref-mapped policies such as `BraveDeAmpEnabled`, `BraveWaybackMachineEnabled`, `SpellcheckEnabled` and `WebRtcIPHandling` come out as `RECOMMENDED` and stay changeable, and a change made in Brave sticks.
- **Where a recommendation does not work:** content setting defaults (`Default*Setting`, `DefaultBrave*Setting`) are applied as enforced even from the `Recommended` subkey, because `content_settings::PolicyProvider` reads them without checking the level (tested: the site settings API reports `source: policy`). Rewards, Wallet, VPN, News and Leo check `IsManagedPreference`, so a recommended value does nothing; these are real kill switches and are always mandatory.
- **A stored value beats a recommendation:** a value the user (or Brave's welcome screen) already stored in the profile wins over a recommended policy, so the app also writes Brave's own pref (next section).
- **Side effect:** any mandatory machine policy makes Brave show "Managed by your organization" in its menu. Removing every policy (Default mode or Full restore) is the only way to clear it.
- **Check:** `brave://policy` shows each value with `Status: OK` and its level, or "Unknown policy" for a name Brave does not know.

### Brave's own settings (Preferences and Local State)

- **Why:** for a setting Brave has a toggle for, the app writes the value where that toggle would, so it takes effect over anything stored earlier and stays changeable. Each row's `Prefs` in `tweaks\policies` lists them, mapped from brave-core's [brave_simple_policy_map.h](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/policy/brave_simple_policy_map.h) and Chromium's [configuration_policy_handler_list_factory.cc](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:chrome/browser/policy/configuration_policy_handler_list_factory.cc).
- **Where:** each profile's `Preferences` for per-profile prefs, and the channel's `Local State` for browser-wide ones (`brave.p3a.enabled`, `brave.stats.reporting_enabled`, `tor.tor_disabled`, `user_experience_metrics.reporting_enabled`, the performance and hardware acceleration prefs).
- **Shields defaults** are content settings. Ads and trackers (`shieldsAds`, `trackers`) and fingerprinting (`fingerprintingV2`) are stored as a rule for every site under `profile.content_settings.exceptions.<type>` with the pattern `*,*`; HTTPS upgrade (`httpsUpgrades`), forget me (`brave_remember_1p_storage`), cookies and the site permission defaults are plain values under `profile.default_content_setting_values`.
- **Signed prefs are never written:** the home button, homepage, startup pages and default search engine are tracked prefs, kept with a MAC in `Secure Preferences` (Chromium's `kTrackedPrefs`); a direct write would be reset. They are recommended policies only, and Preview warns when the user's own value would win.
- **Brave must be closed:** the same rules as flags. Only the managed members are changed in place; every other byte is written back, the text is read back before it is written, and the file is swapped in one step (`src\core\Prefs.ps1`).
- **Check:** tested by writing every row's prefs into a fresh Brave 1.96.59 profile with no policies: `chrome.settingsPrivate` reported each value with no enforcement, the site settings API reported the permission defaults as `block` without a policy source, and Brave's Shields handlers reported the applied defaults.

### brave://flags (Local State)

- **Where:** `%LOCALAPPDATA%\BraveSoftware\Brave-Browser{-Beta,-Nightly,-Dev}\User Data\Local State`, JSON key `browser.enabled_labs_experiments`, a list of `"name@option"` strings. For on/off flags, option 1 is Enabled and 2 is Disabled (`FeatureEntry::NameForOption` in [feature_entry.cc](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/webui/flags/feature_entry.cc)).
- **Brave must be closed:** Brave rewrites Local State on exit, so the app refuses to write while that channel's `brave.exe` runs. It edits only that one list in place, keeps every other byte, backs the file up first and swaps it in one step (`src\core\Flags.ps1`).
- **Removed flags are harmless:** on start, `FlagsState::SanitizeList` drops any name Brave no longer knows ([flags_state.cc](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/webui/flags/flags_state.cc)). The drift check then reports it as retired.
- **Brave's flag list:** [browser/about_flags.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/about_flags.cc). Brave flags have no expiry metadata, so "stable" was measured by sampling that file at release tags v1.45.134, v1.50.127, v1.55.102, v1.60.127, v1.65.133, v1.70.133, v1.75.181, v1.80.126, v1.85.120, v1.88.138, v1.90.130, v1.92.144 and v1.95.104. The rule is: present since 1.85 or earlier.

### Hosts file

- **Where:** `C:\Windows\System32\drivers\etc\hosts`, inside the `# === Brave-Free-Origin START ... END ===` block, as `0.0.0.0 domain`. Written only by the Hosts page, never by the main Apply.
- **Source of truth for domains:** [brave_network_audit_allowed_lists.h](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/net/brave_network_audit_allowed_lists.h) lists every URL prefix Brave may contact at startup; features build their hostnames with `brave_domains::GetServicesDomain("prefix")` plus the `brave.com` services domain. [input_file_parsers.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/chromium_src/net/tools/transport_security_state_generator/input_file_parsers.cc) (Brave's HTTPS pin list) is a good index of Brave hostnames, but a name there is not proof the browser calls it.

### Scheduled tasks and services

- **Updater:** Windows Brave still uses the Omaha 3 updater. Omaha 4 is macOS only (`enable_omaha4 = enable_updater && is_mac` in [browser/updater/buildflags.gni](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/updater/buildflags.gni)). The Omaha 3 source is not in brave-core, so task names come from a real install (Task Scheduler).
- **Matching:** each row has `Match` patterns (`tweaks\system.psd1`), because task names end in a `{GUID}` and services get a per-channel prefix.

### Search & Startup overrides

The only writer of `DefaultSearchProvider*`, `NewTabPageLocation`, `HomepageIsNewTabPage` + `HomepageLocation` and `RestoreOnStartup` + `RestoreOnStartupURLs` (codes: 1 = last session, 4 = specific pages, 5 = new tab, 6 = both). Brave's own default startup is "continue where you left off" (`kPrefValueLast` in `OverrideDefaultPrefValues`, [brave_profile_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_profile_prefs.cc)).

### Drift record

`%ProgramData%\Brave-Free-Origin\applied.json` holds what the last Apply enforced (policies, overrides, disabled tasks and services, flags per Local State path, hosts domains, and a re-apply counter per item). It is compared with the machine when the app opens (`src\core\Drift.ps1`). Deleting it only silences the Home warning until the next Apply.

## Brave Origin reference

The Origin mode copies [brave_origin_service_factory.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_origin/brave_origin_service_factory.cc) (`kBraveOriginBrowserMetadata` and `kBraveOriginProfileMetadata`). Each entry there has a default and `user_settable`:

| Feature | Policy the app uses | Real Origin |
|---|---|---|
| Tor | `TorDisabled` | off, locked |
| Rewards (and Ads) | `BraveRewardsDisabled` | off, locked |
| Wallet | `BraveWalletDisabled` | off, locked |
| Leo | `BraveAIChatEnabled` | off, locked |
| News | `BraveNewsDisabled` | off, locked |
| VPN | `BraveVPNDisabled` | off, locked |
| Talk | `BraveTalkDisabled` | off, locked |
| Email Aliases | `EmailAliasesEnabled` | off, locked |
| PSST | `PsstEnabled` | off, locked |
| Usage ping | `BraveStatsPingEnabled` | off, changeable in settings |
| P3A | `BraveP3AEnabled` | off, changeable in settings |
| Local AI | `BraveLocalAIEnabled` | off, changeable in settings |
| Wayback Machine | `BraveWaybackMachineEnabled` | off, changeable in settings |
| Speedreader | `BraveSpeedreaderEnabled` | off, changeable in settings |
| Playlist | `BravePlaylistEnabled` | off, changeable in settings |
| Web Discovery | `BraveWebDiscoveryEnabled` | off, changeable in settings |

The separate Origin-branded build (`is_brave_origin_branded`) also compiles out Brave Ads, Brave Education, the stats updater, Rewards, Wallet, VPN, News, Talk, Tor, Wayback, Speedreader, Playlist, PSST, Email Aliases, local AI and Web Discovery (each feature's `buildflags.gni`), hides the sidebar and side panel button by default ([sidebar_utils.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/ui/sidebar/sidebar_utils.cc), [brave_profile_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_profile_prefs.cc)), and forces metrics reporting off. The sidebar defaults are prefs, not policies, so the app cannot copy them.

## Policies

Columns: what ticking the row does, the value written, Brave's value when the policy is unset ("not fixed" when Brave has none), the first Chromium version that reads it, and its definition file. A row whose default equals the written value only locks Brave's default.

### Brave Features

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `BraveRewardsDisabled` | Turn off Brave Rewards and Brave Ads, and hide their buttons. | 1 | 0 | 105 | [BraveSoftware/BraveRewardsDisabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveRewardsDisabled.yaml) |
| `BraveWalletDisabled` | Turn off the built-in crypto wallet. | 1 | 0 | 106 | [BraveSoftware/BraveWalletDisabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveWalletDisabled.yaml) |
| `BraveVPNDisabled` | Turn off Brave VPN and hide its button. | 1 | 0 | 112 | [BraveSoftware/BraveVPNDisabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveVPNDisabled.yaml) |
| `BraveNewsDisabled` | Turn off Brave News on the new tab page. | 1 | 0 | 138 | [BraveSoftware/BraveNewsDisabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveNewsDisabled.yaml) |
| `BraveTalkDisabled` | Turn off Brave Talk video calls. | 1 | 0 | 138 | [BraveSoftware/BraveTalkDisabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveTalkDisabled.yaml) |
| `TorDisabled` | Turn off private windows with Tor. (For real anonymity, use Tor Browser.) | 1 | 0 | 78 | [BraveSoftware/TorDisabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/TorDisabled.yaml) |
| `BraveWaybackMachineEnabled` | Stop offering the Wayback Machine on missing pages. | 0 | 1 | 138 | [BraveSoftware/BraveWaybackMachineEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveWaybackMachineEnabled.yaml) |
| `BraveSpeedreaderEnabled` | Turn off Speedreader, the simplified reading view. | 0 | 1 | 138 | [BraveSoftware/BraveSpeedreaderEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveSpeedreaderEnabled.yaml) |
| `BravePlaylistEnabled` | Turn off Playlist (saving videos and audio for later). | 0 | 1 | 139 | [BraveSoftware/BravePlaylistEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BravePlaylistEnabled.yaml) |
| `EmailAliasesEnabled` | Turn off Email Aliases (forwarding addresses from Brave). | 0 | not fixed | 147 | [BraveSoftware/EmailAliasesEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/EmailAliasesEnabled.yaml) |
| `PsstEnabled` | Turn off PSST, which offers to change privacy settings on sites you visit. | 0 | not fixed | 147 | [BraveSoftware/PsstEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/PsstEnabled.yaml) |

- **`BraveRewardsDisabled`:** Also stops Brave Ads: brave-core notes that `AdsServiceImpl::MaybeStartBatAdsService` evaluates this policy ([brave_origin_service_factory.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_origin/brave_origin_service_factory.cc)).
- **`TorDisabled`:** Supported on Windows since Chromium 78 (older than the Brave-wide policies).
- **`EmailAliasesEnabled`:** The feature itself is still behind a flag that is off by default (`kEmailAliases`), so this mostly pre-empts it. Brave Origin locks it off.
- **`PsstEnabled`:** Behind the `enable-psst` flag, off by default. Brave Origin locks it off.

### AI

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `BraveAIChatEnabled` | Turn off Leo, the AI assistant. | 0 | 1 | 121 | [BraveSoftware/BraveAIChatEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveAIChatEnabled.yaml) |
| `BraveLocalAIEnabled` | Turn off on-device AI models, such as the one behind AI history search, and stop downloading them. | 0 | 1 | 149 | [BraveSoftware/BraveLocalAIEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveLocalAIEnabled.yaml) |

- **`BraveLocalAIEnabled`:** A Local State pref, default on ([local_ai/core/pref_names.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/local_ai/core/pref_names.cc)). Covers AI history search (history embeddings) and future on-device AI.

### Telemetry

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `BraveP3AEnabled` | Stop sending P3A product analytics. | 0 | 1 | 138 | [BraveSoftware/BraveP3AEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveP3AEnabled.yaml) |
| `BraveStatsPingEnabled` | Stop the daily, weekly and monthly usage ping. | 0 | 1 | 138 | [BraveSoftware/BraveStatsPingEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveStatsPingEnabled.yaml) |
| `BraveWebDiscoveryEnabled` | Keep Web Discovery off (it contributes browsing data to Brave Search). | 0 | 0 | 138 | [BraveSoftware/BraveWebDiscoveryEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveWebDiscoveryEnabled.yaml) |
| `MetricsReportingEnabled` | Keep usage and crash reports off. | 0 | 0 | 8 | [Miscellaneous/MetricsReportingEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/MetricsReportingEnabled.yaml) |
| `UrlKeyedAnonymizedDataCollectionEnabled` | Keep "make searches and browsing better" URL reporting off. | 0 | 0 | 69 | [Miscellaneous/UrlKeyedAnonymizedDataCollectionEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/UrlKeyedAnonymizedDataCollectionEnabled.yaml) |
| `UserFeedbackAllowed` | Remove the Send feedback option, which uploads diagnostics. | 0 | 1 | 77 | [Miscellaneous/UserFeedbackAllowed.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/UserFeedbackAllowed.yaml) |
| `WebRtcEventLogCollectionAllowed` | Keep WebRTC call logs from being collected. | 0 | 0 | 70 | [Miscellaneous/WebRtcEventLogCollectionAllowed.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/WebRtcEventLogCollectionAllowed.yaml) |
| `ChromeVariations` | Limit the remote experiments Brave can switch on for this browser. "Critical fixes only" keeps emergency fixes working. | 1 (choices: 1, 2) | 0 | 83 | [Miscellaneous/ChromeVariations.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/ChromeVariations.yaml) |

- **`BraveWebDiscoveryEnabled`:** Web Discovery is opt-in, so the default is already off; ticking locks it.
- **`MetricsReportingEnabled`:** Brave's default is off on the Stable channel and on for Beta, Dev and Nightly ([metrics_reporting_util.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/metrics/metrics_reporting_util.cc)). Brave also removed `sensitive: true` from this policy with a patch.
- **`WebRtcEventLogCollectionAllowed`:** Brave sets the default to false in `OverrideDefaultPrefValues` ([brave_profile_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_profile_prefs.cc)).
- **`ChromeVariations`:** 0 = all variations, 1 = critical fixes only, 2 = none. Brave's seed comes from `variations.brave.com/seed`. 1 keeps emergency kill switches working.

### Shields and Tracking

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `DefaultBraveAdblockSetting` | Keep Shields ad and tracker blocking on by default. | 2 | 2 | 142 | [BraveSoftware/DefaultBraveAdblockSetting.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/DefaultBraveAdblockSetting.yaml) |
| `DefaultBraveFingerprintingV2Setting` | Keep fingerprinting protection on by default. A policy can only set Standard; the Strict option is a flag. | 3 | 3 | 141 | [BraveSoftware/DefaultBraveFingerprintingV2Setting.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/DefaultBraveFingerprintingV2Setting.yaml) |
| `DefaultBraveReferrersSetting` | Keep cross-site referrers trimmed by default. | 2 | 2 | 142 | [BraveSoftware/DefaultBraveReferrersSetting.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/DefaultBraveReferrersSetting.yaml) |
| `DefaultBraveHttpsUpgradeSetting` | Upgrade sites to HTTPS. Strict warns before opening any site that has no HTTPS. | 2 (choices: 2, 3) | 3 | 142 | [BraveSoftware/DefaultBraveHttpsUpgradeSetting.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/DefaultBraveHttpsUpgradeSetting.yaml) |
| `BraveGlobalPrivacyControlEnabled` | Keep the Global Privacy Control "do not sell or share" signal on. | 1 | 1 | 142 | [BraveSoftware/BraveGlobalPrivacyControlEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveGlobalPrivacyControlEnabled.yaml) |
| `BraveReduceLanguageEnabled` | Keep your language preferences from being used to fingerprint you. | 1 | 1 | 140 | [BraveSoftware/BraveReduceLanguageEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveReduceLanguageEnabled.yaml) |
| `BraveTrackingQueryParametersFilteringEnabled` | Keep tracking parameters (utm_, fbclid and similar) stripped from links. | 1 | 1 | 142 | [BraveSoftware/BraveTrackingQueryParametersFilteringEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveTrackingQueryParametersFilteringEnabled.yaml) |
| `BraveDeAmpEnabled` | Keep Google AMP pages skipped in favor of the real site. | 1 | 1 | 140 | [BraveSoftware/BraveDeAmpEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveDeAmpEnabled.yaml) |
| `BraveDebouncingEnabled` | Keep bounce-tracking redirects skipped. | 1 | 1 | 140 | [BraveSoftware/BraveDebouncingEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/BraveDebouncingEnabled.yaml) |

- **`DefaultBraveAdblockSetting`:** 1 = allow ads, 2 = block. Default* policies set the default but still allow per-site exceptions.
- **`DefaultBraveFingerprintingV2Setting`:** Only accepts 1 (off) and 3 (standard). There is no policy value for Strict; the `brave-show-strict-fingerprinting-mode` flag exposes it in Shields instead.
- **`DefaultBraveHttpsUpgradeSetting`:** 1 = disabled, 2 = strict (warn before HTTP), 3 = standard (Brave's default).

### Site Permissions

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `DefaultNotificationsSetting` | Stop sites from asking to show notifications. | 2 | 3 | 10 | [ContentSettings/DefaultNotificationsSetting.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/ContentSettings/DefaultNotificationsSetting.yaml) |
| `DefaultGeolocationSetting` | Stop sites from asking for your location. | 2 | 3 | 10 | [ContentSettings/DefaultGeolocationSetting.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/ContentSettings/DefaultGeolocationSetting.yaml) |
| `DefaultSensorsSetting` | Stop sites from reading motion and light sensors. | 2 | 3 | 88 | [ContentSettings/DefaultSensorsSetting.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/ContentSettings/DefaultSensorsSetting.yaml) |
| `DefaultWebUsbGuardSetting` | Stop sites from asking for USB devices. | 2 | 3 | 67 | [ContentSettings/DefaultWebUsbGuardSetting.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/ContentSettings/DefaultWebUsbGuardSetting.yaml) |
| `DefaultWebBluetoothGuardSetting` | Stop sites from asking for Bluetooth devices. | 2 | 3 | 50 | [ContentSettings/DefaultWebBluetoothGuardSetting.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/ContentSettings/DefaultWebBluetoothGuardSetting.yaml) |
| `DefaultWebHidGuardSetting` | Stop sites from asking for HID devices (game controllers, keyboards and similar). | 2 | 3 | 100 | [ContentSettings/DefaultWebHidGuardSetting.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/ContentSettings/DefaultWebHidGuardSetting.yaml) |
| `DefaultSerialGuardSetting` | Stop sites from asking for serial ports. | 2 | 3 | 86 | [ContentSettings/DefaultSerialGuardSetting.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/ContentSettings/DefaultSerialGuardSetting.yaml) |
| `DefaultLocalFontsSetting` | Stop sites from asking for the list of fonts on this PC. | 2 | 3 | 103 | [ContentSettings/DefaultLocalFontsSetting.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/ContentSettings/DefaultLocalFontsSetting.yaml) |
| `PaymentMethodQueryEnabled` | Stop sites from checking whether you have saved payment methods. | 0 | 1 | 80 | [Miscellaneous/PaymentMethodQueryEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/PaymentMethodQueryEnabled.yaml) |
| `AutoplayAllowed` | Stop video and audio from playing on their own. | 0 | 1 | 66 | [Miscellaneous/AutoplayAllowed.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/AutoplayAllowed.yaml) |

- **`DefaultNotificationsSetting`:** Content-setting defaults: 1 = allow, 2 = block, 3 = ask. The Guard settings (USB, Bluetooth, HID, serial) only accept 2 and 3. Per-site exceptions still work.

### History and Site Data

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `SavingBrowserHistoryDisabled` | Never save browsing history. | 1 | 0 | 8 | [Miscellaneous/SavingBrowserHistoryDisabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/SavingBrowserHistoryDisabled.yaml) |
| `DefaultCookiesSetting` | Keep cookies only until Brave closes. | 4 | 1 | 10 | [ContentSettings/DefaultCookiesSetting.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/ContentSettings/DefaultCookiesSetting.yaml) |
| `DefaultBraveRemember1PStorageSetting` | Forget a site's cookies and storage as soon as you close its tabs. | 2 | 1 | 142 | [BraveSoftware/DefaultBraveRemember1PStorageSetting.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/DefaultBraveRemember1PStorageSetting.yaml) |
| `ClearBrowsingDataOnExitList` | When Brave closes, wipe history, the downloads list, cookies, cache, saved passwords, autofill, site permissions and app data. | list of 8 items | not fixed | 89 | [Miscellaneous/ClearBrowsingDataOnExitList.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/ClearBrowsingDataOnExitList.yaml) |

- **`SavingBrowserHistoryDisabled`:** History is never written, which also covers a crash (unlike clear-on-exit).
- **`DefaultCookiesSetting`:** 4 = session only. Session restore brings session cookies back, which is why Max also forces `RestoreOnStartup` = 5 through Search & Startup.
- **`DefaultBraveRemember1PStorageSetting`:** 1 = remember, 2 = forget first-party storage when the site's tabs close.
- **`ClearBrowsingDataOnExitList`:** A LIST policy: subkey `ClearBrowsingDataOnExitList` with values 1..8. Only runs when Brave exits normally, not after a crash. Since Chromium 115 it turns off sync for the data types it clears. Not yet confirmed on a live Brave.

### Passwords, Autofill and Sync

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `PasswordManagerEnabled` | Turn off the built-in password manager (use Bitwarden or another manager instead). | 0 | 1 | 8 | [PasswordManager/PasswordManagerEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/PasswordManager/PasswordManagerEnabled.yaml) |
| `AutofillAddressEnabled` | Turn off address and contact autofill. | 0 | 1 | 69 | [Miscellaneous/AutofillAddressEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/AutofillAddressEnabled.yaml) |
| `AutofillCreditCardEnabled` | Turn off payment card autofill. | 0 | 1 | 63 | [Miscellaneous/AutofillCreditCardEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/AutofillCreditCardEnabled.yaml) |
| `PasswordLeakDetectionEnabled` | Keep the leaked-password check off (it sends hashed passwords to be checked). | 0 | 0 | 79 | [PasswordManager/PasswordLeakDetectionEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/PasswordManager/PasswordLeakDetectionEnabled.yaml) |
| `SyncDisabled` | Turn off Brave Sync. | 1 | 0 | 8 | [Miscellaneous/SyncDisabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/SyncDisabled.yaml) |
| `BrowserSignin` | Turn off browser sign-in. | 0 | not fixed | 70 | [Miscellaneous/BrowserSignin.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/BrowserSignin.yaml) |

- **`PasswordLeakDetectionEnabled`:** Brave's default is already off ([brave_profile_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_profile_prefs.cc)).
- **`SyncDisabled`:** Brave Sync, not Google sync.
- **`BrowserSignin`:** Brave has no Google sign-in (`kSigninAllowedOnNextStartup` defaults to false in [pref_service_builder_utils.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/chromium_src/chrome/browser/profiles/pref_service_builder_utils.cc)), so this is a lock, and has no fixed Brave default.

### Search and Language

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `SearchSuggestEnabled` | Keep search suggestions off, so what you type is not sent while you type it. | 0 | 0 | 8 | [Miscellaneous/SearchSuggestEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/SearchSuggestEnabled.yaml) |
| `AlternateErrorPagesEnabled` | Keep suggestion pages for unreachable sites off. | 0 | 0 | 8 | [Miscellaneous/AlternateErrorPagesEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/AlternateErrorPagesEnabled.yaml) |
| `SpellCheckServiceEnabled` | Keep the online spelling service off. | 0 | 0 | 22 | [Miscellaneous/SpellCheckServiceEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/SpellCheckServiceEnabled.yaml) |
| `SpellcheckEnabled` | Turn off spell checking completely. | 0 | 1 | 65 | [Miscellaneous/SpellcheckEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/SpellcheckEnabled.yaml) |
| `TranslateEnabled` | Turn off the offer to translate pages. | 0 | 1 | 12 | [Miscellaneous/TranslateEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/TranslateEnabled.yaml) |

- **`SearchSuggestEnabled`:** Brave sets the default to false in `OverrideDefaultPrefValues` ([brave_profile_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_profile_prefs.cc)).
- **`AlternateErrorPagesEnabled`:** Default false in `OverrideDefaultPrefValues` ([brave_profile_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_profile_prefs.cc)).
- **`SpellCheckServiceEnabled`:** Brave turns the spelling service off by default ([pref_service_builder_utils.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/chromium_src/chrome/browser/profiles/pref_service_builder_utils.cc)).
- **`TranslateEnabled`:** Brave's translate goes through Brave's own servers, not Google's; this turns the offer off entirely.

### Safety and Updates

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `SafeBrowsingProtectionLevel` | Keep Safe Browsing on its standard level. | 1 | 1 | 83 | [SafeBrowsing/SafeBrowsingProtectionLevel.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/SafeBrowsing/SafeBrowsingProtectionLevel.yaml) |
| `SafeBrowsingExtendedReportingEnabled` | Keep extended Safe Browsing reporting off. | 0 | 0 | 66 | [SafeBrowsing/SafeBrowsingExtendedReportingEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/SafeBrowsing/SafeBrowsingExtendedReportingEnabled.yaml) |
| `SafeBrowsingDeepScanningEnabled` | Keep downloads from being uploaded for deep scanning. | 0 | 0 | 119 | [SafeBrowsing/SafeBrowsingDeepScanningEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/SafeBrowsing/SafeBrowsingDeepScanningEnabled.yaml) |
| `SafeBrowsingSurveysEnabled` | Turn off Safe Browsing surveys. | 0 | not fixed | 117 | [SafeBrowsing/SafeBrowsingSurveysEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/SafeBrowsing/SafeBrowsingSurveysEnabled.yaml) |
| `DefaultBrowserSettingEnabled` | Stop Brave from asking to be the default browser. It can no longer be made default from its settings either. | 0 | 1 | 11 | [Miscellaneous/DefaultBrowserSettingEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/DefaultBrowserSettingEnabled.yaml) |
| `ComponentUpdatesEnabled` | Stop component updates. Shields filter lists, Widevine and other components stop updating. | 0 | 1 | 54 | [Miscellaneous/ComponentUpdatesEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/ComponentUpdatesEnabled.yaml) |

- **`SafeBrowsingExtendedReportingEnabled`:** Brave defaults opt-in and reporting to false ([brave_profile_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_profile_prefs.cc)).
- **`SafeBrowsingDeepScanningEnabled`:** Default false in [brave_profile_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_profile_prefs.cc). Enterprise connector feature.
- **`SafeBrowsingSurveysEnabled`:** Brave disables several Google survey features in its `rewrite/` files; whether any Safe Browsing survey can still fire was not confirmed, so there is no Brave default listed.
- **`DefaultBrowserSettingEnabled`:** Also blocks setting Brave as default from its own settings page.
- **`ComponentUpdatesEnabled`:** Stops Shields filter lists too, not just Widevine: Brave's component and extension update server is `go-updater.brave.com/extensions`.

### Network and Background

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `BackgroundModeEnabled` | Stop Brave from running in the background after its last window closes. | 0 | 1 | 19 | [Miscellaneous/BackgroundModeEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/BackgroundModeEnabled.yaml) |
| `NetworkPredictionOptions` | Keep link preloading off. | 2 | 2 | 38 | [Miscellaneous/NetworkPredictionOptions.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/NetworkPredictionOptions.yaml) |
| `WebRtcIPHandling` | Stop WebRTC from revealing your local IP address. | default_public_interface_only (choices: default_public_interface_only, disable_non_proxied_udp) | default | 91 | [WebRtc/WebRtcIPHandling.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/WebRtc/WebRtcIPHandling.yaml) |
| `EnableMediaRouter` | Turn off casting (Google Cast) and its network discovery. | 0 | 1 | 52 | [GoogleCast/EnableMediaRouter.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/GoogleCast/EnableMediaRouter.yaml) |
| `DnsOverHttpsMode` | Secure DNS. Automatic uses DNS over HTTPS whenever your DNS provider supports it. | automatic (choices: automatic, off) | automatic | 78 | [Miscellaneous/DnsOverHttpsMode.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/DnsOverHttpsMode.yaml) |
| `BuiltInDnsClientEnabled` | Use Windows for DNS instead of Brave's own resolver. | 0 | 1 | 25 | [Miscellaneous/BuiltInDnsClientEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/BuiltInDnsClientEnabled.yaml) |
| `QuicAllowed` | Allow or block the QUIC (HTTP/3) protocol. | 1 (choices: 1, 0) | 1 | 43 | [Miscellaneous/QuicAllowed.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/QuicAllowed.yaml) |

- **`BackgroundModeEnabled`:** Windows and Linux only. Important for Max: clear-on-exit only runs when the browser really exits.
- **`NetworkPredictionOptions`:** 0 = always, 1 = Wi-Fi only, 2 = never. Brave's default is already 2 ([brave_profile_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_profile_prefs.cc)).
- **`WebRtcIPHandling`:** Brave only changes WebRTC IP handling in Tor windows ([tor_profile_manager.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/tor/tor_profile_manager.cc)); normal windows use Chromium's `default`.
- **`EnableMediaRouter`:** The real name of the Cast policy (versions before 2.0 used `MediaRouterEnabled`, which does not exist). Brave defaults it to true ([brave_profile_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_profile_prefs.cc)).
- **`DnsOverHttpsMode`:** Brave patches out Chromium's `default_for_enterprise_users: off` ([DnsOverHttpsMode.yaml.patch](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/patches/components-policy-resources-templates-policy_definitions-Miscellaneous-DnsOverHttpsMode.yaml.patch)), so having other policies set does not turn DoH off. `secure` is not offered: it needs `DnsOverHttpsTemplates` and breaks captive portals.
- **`QuicAllowed`:** A choice row only; no mode sets it.

### Performance

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `HardwareAccelerationModeEnabled` | GPU hardware acceleration. Pick Disable to work around GPU driver glitches or crashes. | 1 (choices: 1, 0) | 1 | 46 | [Miscellaneous/HardwareAccelerationModeEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/HardwareAccelerationModeEnabled.yaml) |
| `HighEfficiencyModeEnabled` | Turn on Memory Saver, which puts inactive tabs to sleep. | 1 | 0 | 108 | [Miscellaneous/HighEfficiencyModeEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/HighEfficiencyModeEnabled.yaml) |
| `BatterySaverModeAvailability` | Turn on Energy Saver whenever the PC runs on battery. | 2 | 1 | 108 | [Miscellaneous/BatterySaverModeAvailability.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/BatterySaverModeAvailability.yaml) |
| `DiskCacheSize` | Cap the disk cache at 250 MB. | 262144000 | not fixed | 17 | [Miscellaneous/DiskCacheSize.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/DiskCacheSize.yaml) |

- **`HardwareAccelerationModeEnabled`:** A choice row only; disabling helps with buggy GPU drivers.
- **`DiskCacheSize`:** Bytes; 262144000 = 250 MB. No fixed Brave default (Chromium sizes the cache automatically).

### Interface and Clutter

| Policy | Ticking it | Writes | Brave default | Since | Definition |
|---|---|---|---|---|---|
| `PromotionsEnabled` | Hide promotional content in the browser. | 0 | 1 | 128 | [Miscellaneous/PromotionsEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/PromotionsEnabled.yaml) |
| `ShowHomeButton` | Keep the home button hidden. | 0 | 0 | 8 | [Startup/ShowHomeButton.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Startup/ShowHomeButton.yaml) |
| `BookmarkBarEnabled` | Hide the bookmarks bar. | 0 | not fixed | 12 | [Miscellaneous/BookmarkBarEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/BookmarkBarEnabled.yaml) |
| `PromptForDownloadLocation` | Save downloads straight to the Downloads folder without asking where. | 0 | 1 | 64 | [Miscellaneous/PromptForDownloadLocation.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/PromptForDownloadLocation.yaml) |
| `NTPCustomBackgroundEnabled` | Stop your own images from being used as the new tab background. | 0 | 1 | 80 | [Miscellaneous/NTPCustomBackgroundEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/NTPCustomBackgroundEnabled.yaml) |
| `AccessibilityImageLabelsEnabled` | Keep image descriptions for screen readers off (they send images to a server). | 0 | 0 | 84 | [Miscellaneous/AccessibilityImageLabelsEnabled.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/AccessibilityImageLabelsEnabled.yaml) |
| `ImportBookmarks` | Stop importing bookmarks from other browsers. | 0 | 1 | 15 | [Miscellaneous/ImportBookmarks.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/ImportBookmarks.yaml) |
| `ImportHistory` | Stop importing history from other browsers. | 0 | 1 | 15 | [Miscellaneous/ImportHistory.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/ImportHistory.yaml) |
| `ImportSavedPasswords` | Stop importing saved passwords from other browsers. | 0 | 1 | 15 | [Miscellaneous/ImportSavedPasswords.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/ImportSavedPasswords.yaml) |
| `ImportAutofillFormData` | Stop importing autofill data from other browsers. | 0 | 1 | 39 | [Miscellaneous/ImportAutofillFormData.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/ImportAutofillFormData.yaml) |
| `ImportSearchEngine` | Stop importing the search engine from other browsers. | 0 | 1 | 15 | [Miscellaneous/ImportSearchEngine.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/Miscellaneous/ImportSearchEngine.yaml) |

- **`PromotionsEnabled`:** Replaces the deprecated `PromotionalTabsEnabled` (Chromium 128+).
- **`ShowHomeButton`:** Brave hides the home button by default, so this is a lock.
- **`BookmarkBarEnabled`:** No fixed default listed: Brave's bookmarks bar setting has its own "only on new tab" mode.
- **`PromptForDownloadLocation`:** Brave defaults to asking ([brave_profile_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_profile_prefs.cc)).
- **`NTPCustomBackgroundEnabled`:** Brave reads it as a managed `kNtpCustomBackgroundDict` and turns off custom image backgrounds ([brave_ntp_custom_background_service_delegate.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/ntp_background/brave_ntp_custom_background_service_delegate.cc)). It does not stop Brave's own wallpapers.
- **`AccessibilityImageLabelsEnabled`:** Opt-in in Chromium, so the default is already off.

## Flags

Written to Local State as `name@1` (Enabled) or `name@2` (Disabled); unticked removes the entry (Default). "In Brave since" is the first sampled release tag that had the flag.

| Flag | Ticking sets | Does | Feature | In Brave since | Notes |
|---|---|---|---|---|---|
| `brave-round-time-stamps` | Enabled | Round high-resolution timers to the millisecond, so sites cannot use them to fingerprint you. | `blink::features::kBraveRoundTimeStamps` | 1.50 | Off by default. Rounds `DOMHighResTimeStamp` to the millisecond. Defined in brave-core `chromium_src/third_party/blink/common/features.cc`. |
| `brave-show-strict-fingerprinting-mode` | Enabled | Show the Strict option for fingerprinting protection in Shields. Pick it there after applying. | `brave_shields::features::kBraveShowStrictFingerprintingMode` | 1.65 | Off by default. Only reveals the Strict option; the user still picks it in Shields. Policy cannot set Strict. |
| `brave-clean-link-js-api` | Enabled | Strip tracking parameters from links that sites copy or share for you. | `features::kBraveCopyCleanLinkFromJs` | 1.80 | Off by default on Windows (the related copy-clean-link hotkey flag is already on outside macOS). |
| `brave-extension-network-blocking` | Enabled | Let Shields block trackers in requests made by extensions. | `brave_shields::features::kBraveExtensionNetworkBlocking` | 1.45 | Off by default. Can stop extensions that rely on tracker domains. |
| `brave-adblock-default-1p-blocking` | Enabled | Let Shields block first-party requests in Standard mode too, not only in Aggressive. | `brave_shields::features::kBraveAdblockDefault1pBlocking` | 1.45 | Off by default. First-party blocking in Standard mode can break logins and embedded video. |
| `brave-adblock-experimental-list-default` | Enabled | Turn on Brave's experimental ad-block rules. | `brave_shields::features::kBraveAdblockExperimentalListDefault` | 1.70 | Off by default. Turns on the "Brave Experimental Adblock Rules" list unless the user already toggled it. |
| `brave-request-otr-tab` | Enabled | Offer a private tab when you open a sensitive site. | `request_otr::features::kBraveRequestOTRTab` | 1.55 | Off by default. Suggests a private tab for sensitive URLs. |
| `brave-news-peek` | Disabled | Stop Brave News from peeking up on the new tab page. | `brave_news::features::kBraveNewsCardPeekFeature` | 1.45 | On by default; the row turns it off. Only matters while News is on. |
| `brave-ntp-search-widget` | Disabled | Remove the search box from the new tab page. | `features::kBraveNtpSearchWidget` | 1.70 | On by default; the row turns it off. |

Useful flags left out, and why:

- `brave-strip-image-metadata-v1`, `brave-webgl-balanced-fingerprinting-protections`, `brave-extension-malware-blocklist`, `brave-shred`: added after 1.85, so they fail the one-year rule. Re-check them in a later release.
- `fallback-dns-over-https`: enabling it does nothing on its own; its provider parameter `BraveFallbackDoHProviderEndpoint` defaults to none ([net/base/features.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/chromium_src/net/base/features.cc)).
- `brave-v8-jitless-mode`: only affects sites where V8 optimizations were already turned off per site.
- Flags already in the privacy-friendly state by default (screen fingerprinting block, CNAME uncloaking, cookie list, GPC, debounce, De-AMP, HTTPS by default, `navigator.connection`, File System Access, Web Bluetooth) are not listed, since ticking them would change nothing.
- `brave-webcompat-exceptions-service` must stay on (turning it off breaks sites), and `use-dev-updater-url` and `brave-override-download-danger-level` are for testing or unsafe.

## Hosts groups

| Group | Domains | Source | Notes |
|---|---|---|---|
| P3A analytics (`p3a`) | collector.bsg.brave.com, star-randsrv.bsg.brave.com | [p3a_config.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/p3a/p3a_config.cc) (`kConstellationCollectorHostPrefix`, `kRandomnessHostPrefix`) | P3A reports through STAR / Constellation. The old `p3a.brave.com` and `p2a` names are no longer used. |
| Usage ping (`stats`) | usage-ping.brave.com | [brave_stats/buildflags.gni](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_stats/buildflags.gni) (`brave_stats_updater_url`) | Replaced `laptop-updates.brave.com`. |
| Web Discovery (`webDiscovery`) | collector.wdp.brave.com, quorum.wdp.brave.com, patterns.wdp.brave.com, star.wdp.brave.com | [web_discovery/browser/util.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/web_discovery/browser/util.cc) (collector, quorum, patterns) | `star.wdp` was only found in the HTTPS pin list. |
| Rewards and Ads (`rewards`) | rewards, api.rewards, grant.rewards, payment.rewards, creators; static.ads, geo.ads, anonymous.ads, search.anonymous.ads, ohttp.ads, mywallet.ads (all .brave.com) | [environment_config.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/brave_rewards/core/engine/util/environment_config.cc), [brave_ads .../host/hosts](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/brave_ads/core/internal/common/url/request_builder/host/hosts), [oblivious_http_constants.h](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/brave_ads/core/browser/network/oblivious_http_constants.h) | `creators.brave.com` was only found in the HTTPS pin list. Only modes that turn Rewards off tick this. |
| Brave News (`news`) | brave-today-cdn.brave.com | [brave_news/browser/urls.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/brave_news/browser/urls.cc) | Replaced the unused `brave-today.brave.com`. |
| Variations (`variations`, manual only) | variations.brave.com | [variations/buildflags.gni](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/variations/buildflags.gni), audit list | Blocking also cuts emergency fixes; the `ChromeVariations` policy set to 1 is the gentler option. |
| Component updates (`components`, manual only) | go-updater.brave.com, componentupdater.brave.com, crxdownload.brave.com, brave-core-ext.s3.brave.com | [update_client/BUILD.gn](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/update_client/BUILD.gn) (`updater_prod_endpoint = "https://go-updater.brave.com/extensions"`), audit list | Serves Shields filter lists, Widevine, Tor and extension updates. Before 2.0, `go-updater` sat in the Variations group and Recommended blocked it. |

Browser updates themselves come from `updates.bravesoftware.com` (Omaha), which no group blocks.

## System page

| Row | Matches | Source | Notes |
|---|---|---|---|
| `BraveSoftwareUpdateTaskMachineCore`, `...UA` | `BraveSoftwareUpdateTaskMachine{Core,UA}*`, `BraveSoftwareUpdateTaskUser*{Core,UA}*` | A real install's Task Scheduler (Omaha 3 is not in brave-core) | Names end in `{GUID}`. The per-user patterns follow Omaha's naming for per-user installs but were not seen on a real machine. |
| `brave`, `bravem` | exact names | `legacy_service_name_prefix = "brave"` in [updater/branding.gni](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/chromium_src/chrome/updater/branding.gni) | One Omaha for all channels. |
| `BraveVPNService` | `Brave{,Beta,Nightly,Dev}VpnService` | [brave_vpn_helper_utils.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_vpn/win/brave_vpn_helper/brave_vpn_helper_utils.cc) (base app name + " Vpn Service", spaces removed); base names in [chromium_install_modes.h](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/chromium_src/chrome/install_static/chromium_install_modes.h) | Present only after Brave VPN was set up. |
| `BraveVpnWireguardService` | `Brave{,Beta,Nightly,Dev}VpnWireguardService` | [service_details.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_vpn/win/service_details.cc) | A separate `BraveVpn*WireguardTunnelService` exists only while connected. |

**Never add the Brave Elevation Service** (`BraveElevationService`, `BraveBetaElevationService`...). Chromium uses it for app-bound encryption of cookies and saved passwords on system-wide installs ([app_bound_encryption_provider_win.cc](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:chrome/browser/os_crypt/app_bound_encryption_provider_win.cc), [app_bound_encryption_win.cc](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:chrome/browser/os_crypt/app_bound_encryption_win.cc)); Brave does not override it, and a real install had `os_crypt.app_bound_encrypted_key` in Local State. Brave also uses it to install its VPN services ([elevator.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/chromium_src/chrome/elevation_service/elevator.cc)). `Test-Tweaks.ps1` rejects any pattern that matches it.

## Retired policies

Listed in `tweaks\retired.psd1`. Apply removes them if present; the drift check offers Clean up.

| Policy | Why it was dropped | Evidence |
|---|---|---|
| `WebTorrentDisabled` | WebTorrent was removed from Brave in May 2025; never a policy in current definitions. | [browser_prefs.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/chromium_src/chrome/browser/prefs/browser_prefs.cc) clears `kWebTorrentEnabled` ("Added 2025-05") |
| `IPFSEnabled` | IPFS removed; policy kept only for the deprecation path. | `deprecated: true` in [IPFSEnabled.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware/IPFSEnabled.yaml), `deprecate_ipfs` in [ipfs/buildflags.gni](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/ipfs/buildflags/buildflags.gni) |
| `ReadingListEnabled` | No such policy in Chromium 154. | absent from `policy_definitions` |
| `CloudPrintSubmitEnabled` | Expired. | `supported_on: chrome.*:17-101` |
| `WelcomePageOnOSUpgradeEnabled` | Expired. | `supported_on: chrome.win:45-62` |
| `ChromeCleanupEnabled, ChromeCleanupReportingEnabled` | Expired (Chrome Cleanup was removed). | `supported_on: chrome.win:68-118` |
| `TabOrganizerSettings` | Expired. | `supported_on: chrome.*:121-136` |
| `SigninAllowed` | Deprecated in favor of `BrowserSignin`. | `deprecated: true` |
| `PromotionalTabsEnabled` | Deprecated; replaced by `PromotionsEnabled`. | `deprecated: true` |
| `MediaRouterEnabled` | Was never a policy; the real one is `EnableMediaRouter`. | absent; see [GoogleCast/EnableMediaRouter.yaml](https://source.chromium.org/chromium/chromium/src/+/refs/tags/154.0.8037.58:components/policy/resources/templates/policy_definitions/GoogleCast/EnableMediaRouter.yaml) |
| `LensDesktopNTPSearchEnabled, LensRegionSearchEnabled, LensOverlaySettings` | Deprecated, and Brave builds Lens out. | `kLensOverlay`, `kLensStandalone` off in [lens_features.cc.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/rewrite/components/lens/lens_features.cc.yaml) |
| `HelpMeWriteSettings` | Brave builds Compose out. | `kEnableCompose` off in [compose_features.cc.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/rewrite/components/compose/core/browser/compose_features.cc.yaml) |
| `HistorySearchSettings` | Brave builds Chromium history embeddings out (its own AI history search is `BraveLocalAIEnabled`). | `kHistoryEmbeddings` off in [history_embeddings_features.cc.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/rewrite/components/history_embeddings/core/history_embeddings_features.cc.yaml) |
| `DevToolsGenAiSettings` | Brave turns DevTools AI off. | `kDevToolsConsoleInsights`, `kDevToolsAiCodeCompletion` off in [devtools/features.cc.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/rewrite/chrome/browser/devtools/features.cc.yaml) |
| `GenAiDefaultSettings, CreateThemesSettings` | Chromium GenAI needs model execution, which Brave turns off. | `kOptimizationGuideModelExecution` off in [optimization_guide_features.cc.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/rewrite/components/optimization_guide/core/optimization_guide_features.cc.yaml) |
| `LiveCaptionEnabled` | Brave turns Live Caption off. | `kLiveCaption` off in [media_switches.cc.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/rewrite/media/base/media_switches.cc.yaml) |
| `BrowserLabsEnabled` | Brave hard-disables the Chrome Labs button. | `IsChromeLabsEnabled()` returns false in [chrome_labs_utils.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/chromium_src/chrome/browser/ui/toolbar/chrome_labs/chrome_labs_utils.cc) |
| `CloudReportingEnabled` | Only affects browsers enrolled in Chrome Enterprise cloud management. | policy description |

Also not worth adding (checked, and Brave already covers them): `DomainReliabilityAllowed` (Brave passes `--disable-domain-reliability` in [brave_main_delegate.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/app/brave_main_delegate.cc)), the Privacy Sandbox policies (deprecated, and `kBrowsingTopics` and the ads APIs are off in Brave's `rewrite/` files), and `ShoppingListEnabled` (`kShoppingList` off in [commerce_feature_list.cc.yaml](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/rewrite/components/commerce/core/commerce_feature_list.cc.yaml)).

Brave now overrides Chromium feature defaults through `rewrite/**/*.yaml` files (`set_feature_flag_default_state`), not the old `OVERRIDE_FEATURE_DEFAULT_STATES` macro. Searching those files for a feature name is the quickest way to see whether Brave builds a Chromium feature out.

## Re-verifying after a Brave update

1. **Chromium version:** `package.json` in brave-core, `config.projects.chrome.tag`. The installed version is `brave.exe`'s file version, `<Chromium>.<Brave major>.<Brave minor>.<build>` (for example `153.1.95.104`).
2. **Policies:** for each name in `tools\known-policies.psd1`, check its YAML still exists, is not `deprecated`, and that `supported_on` still has no end. Update `Min`/`Max` there and `MinChromium`/`MaxChromium` in `tweaks\policies\`. `Test-Tweaks.ps1` fails until they agree.
3. **New Brave policies:** list [policy_definitions/BraveSoftware](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/components/policy/resources/templates/policy_definitions/BraveSoftware) and compare with the rows.
4. **Brave Origin:** diff [brave_origin_service_factory.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/brave_origin/brave_origin_service_factory.cc) against the Origin mode in `tweaks\presets.psd1`.
5. **Built-out features:** search brave-core `rewrite/` for the feature behind a Chromium policy before adding it.
6. **Flags:** re-read [about_flags.cc](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/about_flags.cc); drop a listed flag that disappeared (the drift check will also show it as retired) and consider flags that have now passed the one-year mark.
7. **Hosts:** re-read [brave_network_audit_allowed_lists.h](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/net/brave_network_audit_allowed_lists.h) and the per-feature host constants above.
8. **Updater:** check `enable_omaha4` in [browser/updater/buildflags.gni](https://github.com/brave/brave-core/blob/7489b1cc1467addb754a36848db055b0130faf5e/browser/updater/buildflags.gni). When Windows moves to Omaha 4, the task and service names change completely.
9. **Run the checks:** `tools\Test-Tweaks.ps1`, `tools\Test-Locales.ps1`, `tools\Export-EnglishLocale.ps1`, and PSScriptAnalyzer.

Handy commands, run from a partial checkout:

```sh
# brave-core without file contents; fetch only what you read
git clone --depth 1 --filter=blob:none --no-checkout https://github.com/brave/brave-core.git
git -C brave-core config core.longpaths true   # Windows: some paths exceed 260 characters

# Chromium policy definitions for one tag, as a tarball (much faster than git)
curl -L https://chromium.googlesource.com/chromium/src/+archive/refs/tags/154.0.8037.58/components/policy/resources/templates/policy_definitions.tar.gz | tar xz

# One Chromium file (Gitiles returns it base64-encoded)
curl -s 'https://chromium.googlesource.com/chromium/src/+/refs/tags/154.0.8037.58/components/webui/flags/flags_state.cc?format=TEXT' | base64 -d
```

## Not yet confirmed on a live Brave

These were checked in source and in dry runs only:

- Brave honoring `ClearBrowsingDataOnExitList`, and how session-only cookies interact with Shields' "forget on close".
- A real flag write into Local State and Brave picking it up (the editor was tested on sample files and read-only against a real Local State).
- Re-apply and Clean up against the real registry.
- The per-user update task names (`BraveSoftwareUpdateTaskUser*`).
