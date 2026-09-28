# Changelog

What changed in each version of Brave Free Origin, newest first. How to use the app is in the [README](README.md).

## What's new in v2.0

A new interface, every setting checked against Brave's source code, new modes, brave://flags, and a warning when applied settings stop being in effect.

### Interface

- **A native-feeling window.** The WinForms window is replaced by a WPF one modeled on Windows 11 Settings: side navigation with a live count per page and a back arrow, setting cards you click anywhere to flip, a Home page with one card per mode and a summary of your selection, and a bottom bar that slides up with Discard, Preview and Apply whenever something is not applied yet.
- **Light and dark themes.** Follows the Windows app mode by default, title bar included on Windows 11, with Windows' default blue as the accent. Settings can pin Light or Dark.
- **No more frozen window.** Reading the current state, Preview, Apply, Verify, Full restore, the hosts buttons and every scriptlet operation run on a background runspace. The window keeps responding, and a progress line in the bottom bar says what is running. Closing the window while something is being written asks you to close a second time.
- **Pending changes.** The bottom bar shows how many changes are not applied yet, compared with what was last read from or written to this PC, and hides when there are none. The Hosts page does the same for hosts groups, which it writes separately.
- **Preview in plain language.** Preview opens on a **What will happen** tab that groups the changes by what they do and warns about side effects, next to the technical report. Every setting in `tweaks\` carries tags for this (an Effect, and Impacts for side effects, see [tweaks/README.md](tweaks/README.md)); the same side effects show as small warning chips on the setting cards.
- **Find a setting** replaces the filter bar: one grouped list of matches from every page, `Ctrl+F` to jump to it, `Esc` to clear it.
- **A much faster scriptlet scan.** Scriptlet lines are found with compiled code instead of reading every line of every list in script, and the table is virtualized, so there is no chunked rendering any more. On a real Brave profile, 22,645 rules scan in about four seconds and the search box filters them in well under a tenth of a second. A running scan can be cancelled.
- **Dialogs and notifications inside the window.** Confirmations and reports follow the theme instead of using system message boxes, and routine results (applied, loaded, exported) are short notifications that fade out on their own.
- **Activity panel.** The log is a collapsible panel with colored levels. Warnings and errors show a badge until you open it.
- **Under the hood.** `src\core` no longer touches any control: everything that reads or writes the machine takes a snapshot of the selection (documented in `src\core\State.ps1`), which is what lets it run in the background.

### Settings and modes

- **Checked against the source.** Every policy was compared with Chromium 154 and brave-core 1.98. `tools\known-policies.psd1` records the verified names, and `Test-Tweaks.ps1` fails when a setting uses a name or version range that is not in it.
- **Dead settings removed.** Settings that did nothing in Brave are gone: `WebTorrentDisabled`, `IPFSEnabled` and `ReadingListEnabled` (no longer policies), `MediaRouterEnabled` (the real name is `EnableMediaRouter`, so Cast was never actually turned off), expired Chromium policies (Cloud Print, Chrome Cleanup, the OS upgrade welcome page, Tab Organizer, `SigninAllowed`, `PromotionalTabsEnabled`), and Chromium AI and Lens policies for features Brave builds out. Apply removes these values if an earlier version wrote them.
- **New settings.** Local AI, Email Aliases and PSST (the three Brave Origin disables that were missing), `PromotionsEnabled`, WebRTC IP handling, eight site permission defaults, and a new History and Site Data page (never save history, session-only cookies, wipe data on exit).
- **New modes.** Default, Origin, Recommended, Strict and Max replace the seven old modes. Old config files still import: Stock becomes Default, Quick Debloat becomes Origin, Privacy + Boost becomes Recommended, and Max Performance and Max Privacy become Strict. An old config never lands on Max, because Max wipes data.
- **Settings stay changeable in Brave.** Earlier versions locked every setting, so Brave greyed it out as "Managed by your organization" and changing it meant coming back to the app. Now a setting Brave has a toggle for stays changeable: Apply writes it as a recommended policy (`HKLM\Software\Policies\BraveSoftware\Brave\Recommended`) and sets Brave's own value in every profile, so it takes effect right away and a change you make in Brave later sticks. Shields and site permission defaults, which Brave would lock even as a recommendation, are written only as Brave's own values. Removed features and settings with no toggle in Brave stay locked. **Lock settings so they can't be changed in Brave** on Home brings back the old behavior for everything. A PC set up by an earlier version shows the move as one pending change. Brave protects its search engine, homepage, startup pages and home button with a signature, so the app never writes those directly: if you already picked your own there, Preview says so, and your choice wins until you change it in Brave or lock.
- **Every Brave channel shares one policy key.** Brave reads `HKLM\Software\Policies\BraveSoftware\Brave` for Stable, Beta, Nightly and Dev alike, so the channel picker is gone. The `Brave-Beta`, `Brave-Nightly` and `Brave-Dev` keys earlier versions wrote were never read by Brave; Apply removes them.
- **Flags page.** Nine brave://flags entries that do something useful and have been in Brave for at least a year (since 1.85 or earlier). They are written to each installed channel's Local State, only while that channel is closed, with a backup first. Flags other than these nine, and everything else in Local State, are left untouched.
- **Warnings when settings stop being in effect.** Apply records what it set in `%ProgramData%\Brave-Free-Origin\applied.json`. When the app opens, a warning on Home lists anything reverted, anything that keeps coming back after a re-apply, and anything the installed Brave no longer supports, with Re-apply, Clean up and Keep as is.
- **Brave's default on every setting.** Each card says whether ticking it changes Brave's default or keeps it. Settings the installed Brave does not support yet are greyed out with the version they need.
- **One place for startup settings.** Startup, homepage and new tab settings are only on the Search & Startup page, which gained a Homepage section.
- **Fixed hosts groups.** P3A now blocks the STAR servers it actually uses, the usage ping blocks `usage-ping.brave.com`, and Web Discovery blocks its four real servers. `go-updater.brave.com`, which serves Shields filter-list and component updates, moved from the Variations group into Component Updates. No mode ticks Variations or Component Updates any more.
- **System page.** The Brave Elevation Service is no longer listed: Chromium uses it to decrypt cookies and saved passwords, so disabling it signed people out of sites. VPN services are found for every channel. No mode changes this page.
- **Easier to find your way.** A back arrow at the top left walks back through the pages you visited, including search results with their query, and `Alt+Left` and the mouse's back button do the same. The bottom bar only slides up while something is pending or running, with a new **Discard** button, and the Activity log button moved next to the back arrow. The sidebar scroll bar no longer covers the page counts.
- **Custom remembers where it started.** A selection changed after picking a mode reads "Custom: Origin + 3 changes" everywhere (Home, the bar, the preview, reports and exported configs), with Show changes and Reset to Origin on Home. Undoing the edits makes it plain Origin again. On startup the app names this PC's mode the same way. Only policy switches, their values, flags and Max's startup setting count as changes; the System page, hosts groups and search picks do not.
- **English only for now.** The Simplified Chinese translation was removed; the translation system stays for new languages.

### Backups and moving to another PC

- **Full backups.** A backup is a snapshot of everything the app can change: the whole Brave policy key, the hosts block, each channel's brave://flags, the update tasks and services, and the record of the last apply. One is taken automatically before every change (Apply, Re-apply, the hosts buttons, Full restore, an import and a restore), and **Back up now** in Settings takes one whenever you like.
- **Restore in one click.** Settings > Backups lists every backup with its date, what triggered it and what it holds. **Restore** puts this PC back exactly as it was then, including policies this app does not know about, and takes a fresh backup first so a restore can itself be undone. Flags are only restored for channels that are closed.
- **Old backups clean themselves up.** The newest 20 automatic backups are kept. Pinned backups and the ones you made with Back up now are never removed.
- **Export everything, import everything.** **Export everything** saves one file with your whole selection, the app's own settings (language, theme and automatic backups) and the scriptlet rules you disabled. **Import** on the new PC loads it and opens the preview with an **Apply everything** button, which writes the settings, the hosts block and the scriptlet rules in one go. If Brave has not downloaded its filter lists yet, the scriptlet rules wait, and a banner on the Scriptlets page applies them once the lists are there.

## What's new in v1.12

Two user-facing features, and a large internal refactor that had to land first.

- **Translatable interface.** A `Language` dropdown in the header switches the
  whole UI live. Simplified Chinese (`zh-CN`) ships in the box — support added
  in response to [#4](https://github.com/TahaHydra/Brave-Free-Origin/issues/4),
  opened by [@A81N9](https://github.com/A81N9). The Chinese wording has **not**
  been reviewed by a native speaker yet, so `locales/zh-CN.json` carries
  `"reviewed": false` and the app shows a small *community translation,
  unreviewed* note under the picker. Review PRs are very welcome.
  Adding a language is one JSON file — see [TRANSLATING.md](TRANSLATING.md).
- **Global configuration filter.** A search box above the tabs filters
  policies, scheduled tasks, Windows services and hosts groups at the same
  time, matching on name, description and category — in whichever language the
  UI is currently in, and on the untranslated policy identifier either way.
  Hidden rows collapse instead of leaving gaps, each tab caption shows its
  match count, and the view jumps to the first tab with a hit. Filtering is
  purely presentational: it never changes a selection. A **Selected only**
  checkbox shows just what is currently ticked — pair it with a preset to
  review exactly what is about to be enforced. `Search & Startup` and the
  Scriptlets tab are not part of this index; Scriptlets keeps its own
  dedicated scanner, which handles thousands of rows and is already tuned.
- **Stable internal ids, separated from labels.** Presets, hosts groups,
  search engines, new-tab destinations, startup modes, policy categories and
  the channel selector previously used their English display text as the
  lookup key. Translating the UI would have silently broken preset behaviour
  and config import. Everything now keys off a language-independent id and the
  visible label is looked up separately.
- **Config schema v2.** Exports now carry `schemaVersion` (the file format)
  and `appVersion` (the app) as separate fields, so gaining a button no longer
  looks like a format change. Hosts groups, search engines, new-tab
  destinations and startup modes are stored by id. **Configs exported by
  v1.5-v1.11 still import correctly** — the old English names are mapped on
  the way in. A config exported in Chinese imports identically in English and
  vice versa.
- **`-Lang` and settings survive elevation.** The relaunch after the UAC
  prompt used to rebuild a fixed command line and drop every parameter. It now
  forwards `-Lang` and the resolved settings path, so an elevated
  administrator account still reads the original user's preference file.
- **Switching language changes nothing but text.** Relabelling a dropdown
  means clearing and refilling its items, and WinForms reports that as a user
  selection change — which would have quietly demoted `Recommended` to
  `Custom` and could have moved the hardware-acceleration value. Every bulk
  update (language switch, preset, config import, *Load current state*, full
  restore) now runs with the change handlers muted, restores the exact
  selected id, and re-asserts the active mode afterwards.
- **CJK layout handling.** Microsoft YaHei UI is used for `zh-*` when
  installed, with taller rows and a larger description font, and every
  localized control re-resolves its font on a switch instead of staying pinned
  to Segoe UI, which has no CJK coverage. Row geometry is recalculated from
  the *active* locale in both directions, so going back to English shrinks the
  rows again rather than leaving tall labels inside short rows. The preset
  button row measures its captions and re-flows instead of using fixed X
  positions, so a longer translated label cannot overlap its neighbour.
- **Traditional Chinese is never served Simplified.** Locale matching is
  script-aware: `zh-CN` / `zh-SG` / `zh-Hans-*` resolve to `zh-CN`, while
  `zh-TW` / `zh-HK` / `zh-MO` / `zh-Hant-*` fall back to English until a
  Traditional Chinese file exists.
- **The script stays pure ASCII.** Windows PowerShell 5.1 decodes a BOM-less
  `.ps1` with the system ANSI code page, so literal Chinese in the app would
  mojibake on machines with a different code page. Translations live in
  `locales\*.json` and are read with an explicit UTF-8 decoder.
- **Community locale files are treated as hostile data.** A file dropped into
  `locales\` by hand is parsed as inert JSON — never executed, never through
  `Invoke-Expression` or `Import-LocalizedData`. It may only replace keys
  English already defines, so it cannot introduce a registry path, policy
  name, domain, URL or numeric value. Unknown keys, non-strings, over-long
  values, control characters and mismatched `{0}` placeholders are rejected
  key by key and fall back to English; a malformed or invalid file leaves the
  app in English instead of crashing it.
- **Locale tooling and CI.** `tools\Test-Locales.ps1` validates encoding,
  JSON, duplicate keys, unknown keys, placeholder parity, escaped braces,
  control characters, value length and metadata.
  `tools\Export-EnglishLocale.ps1` regenerates `locales\en-US.json` from the
  embedded catalog by parsing the app's syntax tree — it never executes the
  app — and writes byte-identical output under Windows PowerShell 5.1 and
  PowerShell 7. CI runs both tools under **Windows PowerShell 5.1**, which is
  what the launcher actually uses, as well as under PowerShell 7, and enforces
  the ASCII rule, the locale encoding rules and the portable-zip contents.

Behaviour is otherwise unchanged: the same policies, the same registry writes,
the same hosts handling. Every preset's policy / task / service / hosts payload
was diffed against v1.11 as part of this release and is identical once the
hosts groups are mapped from their old English names to the new ids, as are the
search-provider names, URLs, suggest URLs, keywords, homepages, new-tab
destination values and `RestoreOnStartup` codes that reach the registry. The
Scriptlets tab remains manual-only: it is never touched by a preset, by
`Apply to Brave`, or by anything that runs at startup. If you find any
difference in what gets applied between v1.11 and v1.12, that is a bug —
please open an issue.

One genuine fix landed alongside: the 32-bit `Program Files (x86)` probe for
`brave.exe` was written `"$env:ProgramFiles(x86)\..."`, which PowerShell
expands as `$env:ProgramFiles` followed by a literal `(x86)`, so it could
never match. It is now `"${env:ProgramFiles(x86)}\..."`.

## What's new in v1.11

This fixes the scriptlet scan hang from v1.10.

- **Chunked in-app scanner.** Replaces the background-job scan with a timer-based chunk scanner, avoiding the slow PowerShell job serialization step that could sit on `Loading scriptlet scan results...` for minutes.
- **Real progress bar.** The Scriptlets tab now shows a blue progress bar and live status based on files/bytes processed, current file, elapsed seconds, and rules found.
- **Responsive during scan.** The scan yields back to the GUI every small chunk, so Windows should not mark the app as Not Responding while large Brave lists are being read.
- **Chunked table rendering.** Large scriptlet result sets render in batches instead of locking the whole window while thousands of rows are painted.
- **Safer bulk checking.** `Check filtered` now checks every scanned rule matching the current search/filter, including rows that are not currently painted in the table yet.
- **Clearer filtered workflow.** If `Show disabled by this app only` is enabled, `Check filtered` only checks the disabled subset currently being shown. Untick it and clear the search box before bulk-disabling every scriptlet rule.

## What's new in v1.10

This is the scriptlet-manager usability fix.

- **Background scriptlet scan.** Loading Brave's internal scriptlet lists now runs in a background PowerShell job instead of freezing the whole GUI.
- **Faster table refresh.** Search/filter updates use debouncing and bulk row loading, so toggling filters no longer feels like the app died.
- **Checkbox selection.** Scriptlet rows now have checkboxes. Checked rows are used first; normal highlighted selection still works as a fallback.
- **Check filtered / clear checks.** Search for something like `youtube`, click `Check filtered`, then disable or enable the filtered set in one action.
- **Clearer wording.** The UI says `disabled by this app` / `Disabled by Brave Free Origin` instead of assuming everyone knows what `BFO` means. The internal file marker remains `! BFO disabled:` for compatibility with existing backups and disabled rules.
- **Adaptive columns.** The scriptlet table now resizes its columns with the window instead of staying stuck at the original widths.

## What's new in v1.9

This is the advanced scriptlet transparency release. It adds a separate manager for Brave's built-in adblock scriptlets without mixing that risky workflow into the normal presets.

- **Default Scriptlets (Advanced) tab.** Scans Brave `User Data` component folders for filter-list `list.txt` files and lists internal `##+js(...)` scriptlet rules.
- **Viewer columns for auditability.** Shows enabled state, domain, scriptlet name, arguments, source/version, line number, and raw rule.
- **Portable path handling.** Auto-detects Brave Stable/Beta/Nightly/Dev User Data locations from `%LOCALAPPDATA%`, with manual `Browse...` support when Brave lives somewhere unusual.
- **Manual-only advanced editing.** Scriptlet edits are not part of Quick Debloat, Recommended, Origin Mode, Max Performance, Max Privacy, presets, config apply, or the main `Apply to Brave` button. You must open the advanced tab, scan, tick `Advanced edit mode`, select rules, and confirm the action.
- **Per-scriptlet disable/enable.** Disabling comments rules with `! BFO disabled:`. Enabling restores the original rule text.
- **Duplicate handling.** Brave lists can contain the same raw scriptlet rule more than once; the manager can affect duplicate raw rules in the same file so one selection does not leave a twin active by accident.
- **Backup and restore.** Creates `list.txt.bfo-backup` before edits, with buttons to back up all loaded lists, restore the selected file, or restore all scriptlet backups under the selected User Data folder.
- **Export and reapply preferences.** Exports currently disabled raw rules to JSON and can reapply those disabled preferences after Brave updates replace component versions.
- **CSV export.** Saves the visible filtered scriptlet table for inspection, bug reports, or GitHub issue evidence.

## What's new in v1.8

This is the trust-and-restore release. No random checkbox pile-on; the point is making the tool safer to use and easier to audit.

- **Preview changes button.** Generates a dry-run report before writing anything. It shows per-channel policy adds, changes, clears, already-correct values, search/new-tab/startup override changes, scheduled task actions, service actions, and a reminder that hosts are managed separately.
- **Preview hosts button.** The Hosts tab now shows what domains will be added, kept, or removed from the Brave-Free-Origin sentinel block before editing `hosts`.
- **Full restore / stock button.** Replaces the old narrow "Remove ALL policies" behavior. It now removes Brave policy keys, clears the Brave-Free-Origin hosts block, re-enables known Brave update scheduled tasks, and resets known disabled Brave services to Manual.
- **Copy/save reports.** Preview and Verify reports open in a scrollable dialog with Copy and Save report buttons. This makes support/debugging cleaner.
- **Config export version bumped to `1.8`.** Exported JSON now reflects the current app generation.

## What's new in v1.7

Two fixes / additions, both about the ad blocker.

- **Preset bug fix: Origin Mode and Privacy + Boost now enforce ad blocking.** Earlier versions used a hand-curated list that omitted the Shields policies, so picking those modes left ad blocking at Brave's default instead of `Block`. Ad blocking is a **performance win** (fewer requests, less DOM, less JS) on top of being Brave's whole identity, so it belongs in the boost preset. Origin Mode and everything that derives from it now also force `DefaultBraveAdblockSetting=Block`, fingerprint protection to Standard, strict referrers, tracking-param stripping, De-AMP, and debouncing.
- **Extensions section in the Search & Startup tab.** Two convenience buttons that just open install pages in Brave — no force-install, no "Managed by your organization" banner. uBlock Origin Lite (MV3-safe), Brave Shields settings, Bitwarden. Includes a one-line warning about double-blocking if you stack uBO on top of Shields.

### Why we don't auto-install uBlock Origin

Brave Shields and uBO are roughly equivalent — same filter-list lineage, Shields runs native in the engine so it's marginally faster than uBO-as-an-extension. Stacking both wastes CPU per tab and breaks sites Shields handles fine because their default filter sets differ. Force-installing extensions via `ExtensionInstallForcelist` shows users a "Managed by your organization" banner and locks the extension on, which is invasive UX. Manifest V2 is also being deprecated, so pinning users to full uBO would age badly. uBO Lite (MV3) is the future-proof choice if you want a second blocker, hence the button.

## What's new in v1.6

Two additions, both opt-in.

- **Search & Startup tab.** Three independent sections, each gated by its own checkbox so nothing fires unless you explicitly tick it.
  - **Default search engine** for the omnibox: Brave Search, DuckDuckGo, Startpage, Qwant, Ecosia, Mojeek, Kagi, Google, Bing, Yandex, or a custom URL (must contain `{searchTerms}`). Writes the `DefaultSearchProvider*` policies. Untick + Apply removes the override and lets Brave's user-chosen engine come back.
  - **New tab page**: blank / search engine homepage / custom URL. Writes `NewTabPageLocation`. Replaces and overrides anything the Performance tab set.
  - **Startup behavior**: open new tab / restore last session / open blank / open a specific page or comma-separated set. Writes `RestoreOnStartup` and (when applicable) the `RestoreOnStartupURLs` list policy.
  - All three run **last** in the apply order, so they cleanly win over any matching policy ticks in the Performance / Startup tab. They also clear their own keys before writing, so unticking + Apply truly removes the override (no orphan registry entries).
  - Round-trips through Export/Import config and is included in the Verify report.

- **Hosts blocks now wire into presets, with a strict no-orphan rule.** Picking a mode now also pre-ticks the hosts groups whose underlying feature is *also* being disabled by that mode's policies. Specifically:
  - Quick Debloat → P3A, Variations, Stats ping, Web Discovery, Rewards (matches its policy set; News stays unblocked because Quick leaves News policy on).
  - Recommended / Origin / Privacy + Boost → above + News CDN.
  - Max Performance / Max Privacy → above + Component Updates (matches `ComponentUpdatesEnabled = 0`).
  - Stock / None → all unticked.
  - Hosts apply still has its own button in the Hosts tab — presets only suggest, they never write hosts entries silently.

## What's new in v1.5

Four additions, all opt-in and reversible. Nothing changes in existing modes — the new features sit alongside what you already know.

- **Multi-channel target selector.** A dropdown in the header now lets you point the apply at Brave Stable, Beta, Nightly, Dev, or all installed channels at once. Other channels share the same policy schema but live under separate registry hives.
- **Hosts file blocklist tab.** Optional DNS-level kill switch for Brave telemetry domains. Even if a Brave update bypasses a policy, the network call still fails. Sentinel-tagged in the hosts file (`# === Brave-Free-Origin START ===` / `=== END ===`) so removal is surgical and never touches your other entries. Auto-backs up `hosts` before any write. Has its own Apply / Remove buttons inside the tab — does **not** fire from the main "Apply to Brave" button, so you can never edit hosts by accident.
- **Export / Import config.** Save your tuned checkbox state to a JSON file and reuse it on another machine, or share a community preset. Round-trips policies, tasks, services, and hosts groups.
- **Verify button.** Reads the registry of every target channel and reports back which selected policies are present, missing, or have a wrong value. Also lists currently-blocked hosts entries. Useful when [Brave bug 45106](https://github.com/brave/brave-browser/issues/45106) leaves a feature visible despite the policy being set — `Verify` proves the registry is correct so you know whose problem it is.

### Will antivirus flag any of this?

It might. No tool can promise otherwise — a PowerShell script that writes to
`HKLM` and edits the `hosts` file is exactly the shape heuristic detection
looks for, and heuristic detections are not statements about what the code
actually does. What this project can promise is that it is built to minimise
false positives, and that you can verify every claim below by reading the
source:

- No executable modification, no code-signing changes, no hex-edited binaries.
- No obfuscation, no encoded payloads, no `Invoke-Expression` on downloaded content.
- No downloader: nothing is fetched from the network at runtime.
- No new scheduled tasks, no auto-startup entries, no persistence mechanism.
- No attempt to disable, exclude itself from, or evade any security product.
- Registry writes target the documented enterprise-policy paths under
  `HKLM\Software\Policies\BraveSoftware\Brave` — exactly what corporate IT does to manage browsers.
- Hosts file edits are explicit, listed in the UI before they happen, wrapped in
  a clearly-labeled sentinel block an admin can read or remove with Notepad, and
  reversible from the same tab. They are written as ASCII, the format Windows
  expects, rather than UTF-16.
- Every change is preceded by a full backup, into `Documents\Brave-Free-Origin-Backups\backups\`, that Settings can restore in one click.
- The whole thing is plain open-source PowerShell you can read end to end. `Brave-Free-Origin.ps1` lists every file it loads from `src\`, and every setting it can change is listed as plain data in `tweaks\`, which is read as data and never executed.

If your AV does flag it, that flag is about "a PowerShell script is writing
policy registry values", which is the tool working as documented. Read the
script, or run `Preview changes` first — it prints every write it intends to
make without performing any of them.

### Conflict notes

The new features don't conflict with each other or with the existing modes. A few things to know:

- Hosts blocking is a layered defense **on top of** policies, not a replacement. Picking a mode + ticking hosts blocks is the intended use.
- The **Components** hosts group will stop Widevine and similar from updating. Only tick it if you also have `ComponentUpdatesEnabled` policy off (the same caveat as in Max Privacy mode).
- Multi-channel apply does the same set of policies to every selected channel. If you only have Stable installed, leave the target on Stable.
- `Verify` reads from the selected target channel(s). Switch the target, click Verify again to check a different channel.
