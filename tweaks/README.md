# Tweak data

Everything Brave Free Origin can change on your machine is listed in this folder as plain data. The code in `src\` reads these files and builds the tabs, checkboxes and one-click modes from them. Nothing here is ever executed: each `.psd1` file is read with `Import-PowerShellDataFile`, which only accepts literal values (text, numbers, `$true`, `$false`, `$null`, lists and tables).

| File | What it controls |
|---|---|
| `policies\NN-name.psd1` | One file per policy tab. The number prefix sets the tab order. |
| `system.psd1` | Brave update scheduled tasks and Windows services on the System tab. |
| `hosts.psd1` | Domain groups on the Hosts Blocklist tab. |
| `search.psd1` | Search engines, new tab destinations and startup modes on the Search & Startup tab. |
| `presets.psd1` | What each one-click mode button ticks. |
| `tags.psd1` | The tags every entry above carries: what kind of change it is, and its side effects. |

## Rules for every file

- **ASCII only.** Windows PowerShell 5.1 reads these files with the system code page, so any accented or non-Latin character would be garbled on other machines. CI rejects non-ASCII bytes. Translated text belongs in `locales\*.json`.
- **No visible text.** Labels and descriptions live in the English string catalog, `src\strings\en-US.ps1`, under keys derived from each entry's id (listed below), so they can be translated.
- **Ids are stable.** Policy names, hosts group ids, engine ids and preset ids are stored in exported configs. Renaming one breaks imports of older configs.

## Policies (`policies\*.psd1`)

```powershell
@{
    Category = 'braveFeatures'
    Policies = @(
        @{ Name = 'BraveVPNDisabled'; Type = 'DWORD'; ApplyValue = 1; Recommended = $true; MaxPrivacy = $true }
    )
}
```

| Field | Meaning |
|---|---|
| `Category` | Tab id. The tab title is the string `category.<Category>`. |
| `Name` | Registry value name under `HKLM\Software\Policies\BraveSoftware\<channel>`. Written when ticked, removed when unticked. |
| `Type` | `'DWORD'` (a number) or `'STRING'` (quoted text). |
| `ApplyValue` | The value written when ticked. |
| `Recommended` | `$true` to include it in the Recommended mode. |
| `MaxPrivacy` | `$true` to include it in the Max Privacy mode. |
| `Effect` | Required tag: what kind of change this is (see [Tags](#tags-tagspsd1)). |
| `Impacts` | Optional tags for side effects worth a warning, for example `@('noSync')`. |
| `Choices` | Optional. Shows a dropdown next to the checkbox, for example `@(@{ Id = 'enable'; Value = 1 }, @{ Id = 'disable'; Value = 0 })`. `ApplyValue` must be one of the values. Each label is the string `policy.<Name>.choice.<Id>`. |

The row description is the string `policy.<Name>.description`.

## System (`system.psd1`)

`ScheduledTasks` and `Services` are lists of entries such as `@{ Name = 'brave'; Effect = 'updates'; Impacts = @('noUpdates') }`, where `Name` is the exact Windows name and `Effect` and `Impacts` are tags. A ticked task is disabled; a ticked service is stopped and set to Disabled. Unticking re-enables the task, or resets the service to Manual. Descriptions are the strings `task.<Name>.description` and `service.<Name>.description`.

## Hosts groups (`hosts.psd1`)

| Field | Meaning |
|---|---|
| `Id` | Stable id used by presets and exported configs. Labels are `hosts.<Id>.name` and `hosts.<Id>.description`. |
| `Recommended` | `$true` to pre-tick the group when the Hosts tab opens. |
| `LegacyName` | English label that v1.5 to v1.11 exports stored. Keeps old configs importable; leave it out for new groups. |
| `Domains` | Host names written to the managed block of the Windows hosts file. |
| `Effect`, `Impacts` | Tags, as for policies. |

## Search & Startup (`search.psd1`)

`Engines`, `Destinations` and `StartupModes` are lists; their order is the dropdown order. Labels are `engine.<Id>`, `destination.<Id>` and `startupMode.<Id>`. Engine `URL` and `Suggest` use Chromium's `{searchTerms}` placeholder. Destination values `__SEARCH__` (the chosen engine's home page) and `__CUSTOM__` (the URL typed by the user) are resolved when the settings are applied. A startup mode's `Code` is the `RestoreOnStartup` policy value.

## Presets (`presets.psd1`)

| Field | Meaning |
|---|---|
| `Include` | Other modes whose policy lists are merged in first. |
| `Flag` | `'Recommended'` or `'MaxPrivacy'`: adds every policy with that flag set to `$true`. |
| `Policies` | Policy names added on top. Duplicates are dropped. |
| `Tasks`, `Services` | `$true` ticks every entry in `system.psd1`. |
| `Hosts` | Hosts group ids to tick. |

The mode cards on the Home page (their order and risk color) are listed in `src\ui\Model.ps1`, and their names in the string catalog under `preset.<Id>`.

## Tags (`tags.psd1`)

Tags are how the app explains a change in plain language instead of registry values. Every policy, task, service and hosts group names one `Effect` and may list `Impacts`:

- **`Effect`** says what kind of change it is: `feature` (a feature is removed or turned off), `privacy` (less data is sent), `protection` (a privacy or security protection is set), `performance`, `clutter`, `behavior` or `updates`. The `What will happen` tab of the Apply preview groups its changes by Effect, in the order `tags.psd1` lists them.
- **`Impacts`** are side effects a normal user would not guess: `noUpdates`, `noDrm`, `noSync`, `noAutofill`, `lessProtection`, `forgetsLogins`. Each one shows as a small warning chip on the setting card, and as a warning in the preview whenever a change with that Impact is about to be enforced.

The wording is in the string catalog: `effect.<Id>.title`, `impact.<Id>.name` (the chip) and `impact.<Id>.explain` (the warning). To add a tag, add its id to `tags.psd1` and its strings to `src\strings\en-US.ps1`. An unknown tag, or a tag without its strings, stops the app and fails `Test-Tweaks.ps1`.

## Adding a policy

1. Add an entry to the right `policies\*.psd1` file, with its `Effect` and any `Impacts`.
2. Add its description to `src\strings\en-US.ps1` as `'policy.<Name>.description'`.
3. Optionally add its name to a mode in `presets.psd1`.
4. Run the checks:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\Test-Tweaks.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\Export-EnglishLocale.ps1
```

`Test-Tweaks.ps1` loads this folder through the app's own loader and reports missing strings, unknown names in presets, duplicate policies and bad host names. `Export-EnglishLocale.ps1` regenerates `locales\en-US.json` so translators see the new string.

If a file here has a mistake, the app refuses to start and shows the file and line to fix, rather than running with half its settings missing.
