# Tweak data

Everything Brave Free Origin can change on your machine is listed in this folder as plain data. The code in `src\` reads these files and builds the tabs, checkboxes and one-click modes from them. Nothing here is ever executed: each `.psd1` file is read with `Import-PowerShellDataFile`, which only accepts literal values (text, numbers, `$true`, `$false`, `$null`, lists and tables).

| File | What it controls |
|---|---|
| `policies\NN-name.psd1` | One file per policy tab. The number prefix sets the tab order. |
| `flags.psd1` | The brave://flags entries on the Flags tab. |
| `retired.psd1` | Policies earlier versions wrote. Apply removes them. |
| `system.psd1` | Brave update scheduled tasks and Windows services on the System tab. |
| `hosts.psd1` | Domain groups on the Hosts Blocklist tab. |
| `search.psd1` | Search engines, new tab and homepage destinations, and startup modes on the Search & Startup tab. |
| `presets.psd1` | The one-click modes: their order and what each one ticks. |
| `tags.psd1` | The tags every entry above carries: what kind of change it is, and its side effects. |

## Rules for every file

- **ASCII only.** Windows PowerShell 5.1 reads these files with the system code page, so any accented or non-Latin character would be garbled on other machines. CI rejects non-ASCII bytes. Translated text belongs in `locales\*.json`.
- **No visible text.** Labels and descriptions live in the English string catalog, `src\strings\en-US.ps1`, under keys derived from each entry's id (listed below), so they can be translated.
- **Ids are stable.** Policy names, flag names, hosts group ids, engine ids and mode ids are stored in exported configs. Renaming one breaks imports of older configs; see `LegacyNames` and `LegacyIds` for the supported way to rename.

## Policies (`policies\*.psd1`)

```powershell
@{
    Category = 'braveFeatures'
    Policies = @(
        @{ Name = 'BraveVPNDisabled'; Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 112; Effect = 'feature' }
    )
}
```

| Field | Meaning |
|---|---|
| `Category` | Tab id. The tab title is the string `category.<Category>`. |
| `Name` | Registry value name under `HKLM\Software\Policies\BraveSoftware\Brave`, the key every Brave channel reads. Written when ticked, removed when unticked. |
| `Type` | `'DWORD'` (a number), `'STRING'` (quoted text) or `'LIST'` (a list of quoted text, written as a subkey of numbered values, like `RestoreOnStartupURLs`). |
| `ApplyValue` | The value written when ticked. |
| `BraveDefault` | Optional. The value Brave behaves as when the policy is not set. The card then says whether ticking changes Brave's default or only locks it. Leave it out when Brave has no fixed default. |
| `MinChromium` | The first Chromium version that reads the policy, from its `supported_on` in the policy definition. On an older Brave the row is greyed out. |
| `MaxChromium` | Optional. The last Chromium version that reads it, when the definition has an end. |
| `Effect` | Required tag: what kind of change this is (see [Tags](#tags-tagspsd1)). |
| `Impacts` | Optional tags for side effects worth a warning, for example `@('noSync')`. |
| `Choices` | Optional. Shows a dropdown next to the checkbox, for example `@(@{ Id = 'enable'; Value = 1 }, @{ Id = 'disable'; Value = 0 })`. `ApplyValue` must be one of the values. Each label is the string `policy.<Name>.choice.<Id>`. |
| `LegacyNames` | Optional. Names an earlier version used for this setting, so old configs land on this row. |

The row description is the string `policy.<Name>.description`. Startup, homepage and new tab policies are not rows: the Search & Startup page is their only writer.

Every policy must also be listed in `tools\known-policies.psd1`, the names verified against the Chromium and brave-core policy definitions with their supported versions. `Test-Tweaks.ps1` fails when a row's name is missing there or its `MinChromium` disagrees, so a dead or mistyped policy cannot get in.

## Retired policies (`retired.psd1`)

When a policy leaves `policies\`, add it here with a `Reason`: `removed` (Brave removed the feature), `builtOut` (Brave builds the feature out), `expired` (Chromium no longer reads it), `renamed` or `notAPolicy`, plus `Replacement` when another row replaces it. Apply removes these values if an earlier version wrote them, and the drift check offers to clean them up. The explanation shown is the string `retired.reason.<Reason>`.

## Flags (`flags.psd1`)

```powershell
@{ Name = 'brave-round-time-stamps'; State = 'enabled'; MinBrave = 50; Effect = 'protection' }
```

| Field | Meaning |
|---|---|
| `Name` | The brave://flags id. |
| `State` | `'enabled'` or `'disabled'`: what a ticked row sets. Unticked puts the flag back to Default. |
| `MinBrave` | The Brave minor version (the 50 of 1.50) the flag first shipped in. A flag is only listed when it is useful and has been in Brave since 1.85 or earlier; `Test-Tweaks.ps1` enforces the version. |
| `Effect`, `Impacts` | Tags, as for policies. |

Flags are written to `browser.enabled_labs_experiments` in each installed channel's Local State, only while that channel is closed. The description is the string `flag.<Name>.description`.

## System (`system.psd1`)

`ScheduledTasks` and `Services` are lists of entries such as `@{ Name = 'brave'; Effect = 'updates'; Impacts = @('noUpdates') }`. `Name` is the row id, kept stable for exported configs. `Match` lists the Windows names the row acts on, with `*` as a wildcard; without it, the row acts on `Name` itself. Brave's installer adds a GUID to its task names (`BraveSoftwareUpdateTaskMachineCore{8371973C-...}`) and gives each channel's services their own prefix (`BraveBetaVpnService`), so most rows list patterns. A ticked task is disabled; a ticked service is stopped and set to Disabled. Unticking re-enables the task, or resets the service to Manual. Descriptions are the strings `task.<Name>.description` and `service.<Name>.description`.

No mode ticks anything here. The Brave Elevation Service must never be listed: Chromium decrypts cookies and saved passwords through it, and `Test-Tweaks.ps1` rejects a pattern that matches it.

## Hosts groups (`hosts.psd1`)

| Field | Meaning |
|---|---|
| `Id` | Stable id used by modes and exported configs. Labels are `hosts.<Id>.name` and `hosts.<Id>.description`. |
| `Recommended` | `$true` to pre-tick the group when the Hosts tab opens. |
| `ManualOnly` | `$true` for groups no mode may tick or untick (Variations, Component Updates). |
| `LegacyName` | English label that v1.5 to v1.11 exports stored. Keeps old configs importable; leave it out for new groups. |
| `Domains` | Host names written to the managed block of the Windows hosts file. Only list domains brave-core actually contacts. |
| `Effect`, `Impacts` | Tags, as for policies. |

## Search & Startup (`search.psd1`)

`Engines`, `Destinations` and `StartupModes` are lists; their order is the dropdown order. Labels are `engine.<Id>`, `destination.<Id>` and `startupMode.<Id>`. Engine `URL` and `Suggest` use Chromium's `{searchTerms}` placeholder. Destinations serve both the new tab page and the homepage; the values `__SEARCH__` (the chosen engine's home page) and `__CUSTOM__` (the URL typed by the user) are resolved when the settings are applied. A startup mode's `Code` is the `RestoreOnStartup` policy value.

## Modes (`presets.psd1`)

`Order` lists the mode ids in card order. `Modes` holds one entry per mode:

| Field | Meaning |
|---|---|
| `Include` | The mode whose lists are merged in first. |
| `Policies` | Policy names to tick, at their `ApplyValue`. |
| `Values` | Optional `name = value` for a choice policy that should use another of its `Choices` in this mode. |
| `Flags` | Flag names to tick. |
| `Hosts` | Hosts group ids to tick; never a `ManualOnly` group. |
| `Startup` | Optional startup mode id the mode sets on the Search & Startup page. |
| `Reset` | `$true` for the mode that unticks everything (Default). |

A mode sets every policy, flag and hosts row: listed ones are ticked, the rest unticked. It never touches the System page, the `ManualOnly` hosts groups or the search engine and new tab picks; only `Reset` clears those. `LegacyIds` maps the mode ids of earlier versions onto today's, for importing old configs; nothing may map onto `Max`, because it wipes data. Names, descriptions and risk labels are the strings `preset.<Id>.name`, `.description` and `.risk`; the risk color of each card is in `src\ui\Model.ps1`.

## Tags (`tags.psd1`)

Tags are how the app explains a change in plain language instead of registry values. Every policy, flag, task, service and hosts group names one `Effect` and may list `Impacts`:

- **`Effect`** says what kind of change it is: `feature` (a feature is removed or turned off), `privacy` (less data is sent), `protection` (a privacy or security protection is set), `performance`, `clutter`, `behavior` or `updates`. The `What will happen` tab of the Apply preview groups its changes by Effect, in the order `tags.psd1` lists them.
- **`Impacts`** are side effects a normal user would not guess: `noUpdates`, `staleFilters`, `noDrm`, `noSync`, `noAutofill`, `lessProtection`, `forgetsLogins`, `wipesData`, `mayBreakSites`. Each one shows as a small warning chip on the setting card, and as a warning in the preview whenever a change with that Impact is about to be enforced.

The wording is in the string catalog: `effect.<Id>.title`, `impact.<Id>.name` (the chip) and `impact.<Id>.explain` (the warning). To add a tag, add its id to `tags.psd1` and its strings to `src\strings\en-US.ps1`. An unknown tag, or a tag without its strings, stops the app and fails `Test-Tweaks.ps1`.

## Adding a policy

1. Find it in the Chromium or brave-core policy definitions. Check it is not deprecated, supports Windows, and changes something in Brave (Brave builds some Chromium features out, and their policies then do nothing).
2. Add it to `tools\known-policies.psd1` with the versions from its `supported_on`.
3. Add an entry to the right `policies\*.psd1` file, with `MinChromium`, `BraveDefault` if Brave has one, its `Effect` and any `Impacts`.
4. Add its description to `src\strings\en-US.ps1` as `'policy.<Name>.description'`.
5. Optionally add its name to a mode in `presets.psd1`.
6. Run the checks:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\Test-Tweaks.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\Export-EnglishLocale.ps1
```

`Test-Tweaks.ps1` loads this folder through the app's own loader and reports missing strings, names not in `known-policies.psd1`, unknown names in modes, duplicate policies and bad host names. `Export-EnglishLocale.ps1` regenerates `locales\en-US.json` so translators see the new string.

If a file here has a mistake, the app refuses to start and shows the file and line to fix, rather than running with half its settings missing.
