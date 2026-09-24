# Translating Brave Free Origin

Thanks for helping. Adding a language means adding **one JSON file**. You never
need to touch the PowerShell.

---

## The short version

1. Copy `locales/en-US.json` to `locales/<your-locale>.json` (e.g. `fr-FR.json`,
   `de-DE.json`, `pt-BR.json`).
2. Edit the `meta` block.
3. Translate the values under `strings`. Leave the keys alone.
4. Save as **UTF-8 without a BOM**, LF line endings.
5. Open a PR. CI checks the file automatically.

Partial translations are fine and ship happily — anything you leave out falls
back to English at runtime, key by key.

---

## The `meta` block

```json
{
  "meta": {
    "locale": "fr-FR",
    "name": "Français",
    "englishName": "French",
    "appVersion": "2.0",
    "translators": ["your-github-handle"],
    "reviewed": false
  },
  "strings": {
    "action.apply": "Appliquer à Brave"
  }
}
```

| Field | Notes |
| --- | --- |
| `locale` | Must match the filename exactly. This is what `-Lang` accepts. |
| `name` | The language's own name. This is what the picker shows. |
| `englishName` | For maintainers who can't read `name`. |
| `translators` | Credit yourself. Only list people who actually wrote or reviewed the text — asking for a language in an issue is a request, not authorship, and gets recorded in `note` instead. Leave it `[]` if nobody has claimed the wording. |
| `reviewed` | Leave `false` until a second speaker of the language has read it. While `false` the app shows a small "community translation, unreviewed" note under the language picker. |
| `note` | Optional free text. Useful for recording provenance — who requested the language, what still needs review. |

Delete `generated` if you copied it from `en-US.json` — that flag is specific
to the generated reference file.

The shipped `zh-CN.json` is the worked example of this: `translators` is empty
and `reviewed` is `false`, because the language was requested in
[#4](https://github.com/TahaHydra/Brave-Free-Origin/issues/4) but the Chinese
wording has not been through a native speaker yet. If you can review it, that
is a very welcome PR.

---

## Rules that CI enforces

These aren't style preferences; a PR that breaks one will fail.

The **runtime** enforces the same rules independently, key by key, because
locale files are also just files a user can drop into `locales\` by hand. A key
that breaks a rule is dropped and its English text is used instead; a file that
is malformed, not UTF-8, or missing its `strings` block is ignored entirely and
the app stays in English rather than crashing. Nothing in a locale file is ever
executed — no `Invoke-Expression`, no `Import-LocalizedData`, just
`ConvertFrom-Json` over inert data. So a broken translation is a cosmetic
problem, never a broken app. CI exists so you find out before your users do.

**Keys are fixed.** You may only translate keys that already exist in English. A key CI doesn't recognise is a typo, and a typo that silently did nothing would be worse than a build failure. To *add* a key, the English catalog in `src\strings\en-US.ps1` has to change first, which is a maintainer change.

**Placeholders must survive.** `{0}`, `{1}` and so on get replaced with live
values. Keep every one, keep the numbers the same. You can reorder them if your
language needs a different word order:

```
"mode.system": "System: {0} tasks, {1} services"
"mode.system": "Système : {1} services, {0} tâches"     ← fine
"mode.system": "Système : {0} tâches"                    ← fails, {1} dropped
```

**Doubled braces stay doubled.** `{{searchTerms}}` renders as literal
`{searchTerms}`. If you write it with single braces the app will try to
substitute it and the help text will break.

**`\r\n` is a real line break** inside dialog text. Keep roughly the same number
of them so dialogs keep their shape.

**No control characters** other than tab, CR and LF.

**Values cap at 2000 characters.**

---

## What is *not* translatable, on purpose

None of these appear in the string catalog, so you won't run into them — but if
you're wondering why they stayed English:

- **Policy names** — `BraveRewardsDisabled`, `DefaultBraveAdblockSetting`, and
  the rest. Users cross-check these against `brave://policy`, and they're
  rendered in Consolas, which has no CJK coverage. The *description* next to
  each one is translatable; the identifier is not.
- **Scheduled task and Windows service names** — real system identifiers.
- **Domains, registry paths, URLs, `{searchTerms}`** — these live in the data
  model, not the catalog. A locale file structurally cannot change them. That's
  the whole point of keeping translations as inert data.
- **Search engine brand names** — "DuckDuckGo" is "DuckDuckGo". The only entry
  with real words is `engine.custom` ("Custom..."). Note that what gets written
  to the registry as `DefaultSearchProviderName` is a separate untranslated
  field, so Brave always shows a stable provider name.
- **Scriptlet raw rules and the `! BFO disabled: ` marker.** The marker is
  matched literally when re-enabling a rule and when reapplying an exported
  preference file. Translating it would orphan every edit a user had already
  made. Rule text itself is Brave's data, not ours.
- **`Write-BfoLog` output and the Preview / Verify reports.** Deliberate: a user
  running the app in Japanese should still be able to paste a report into a
  GitHub issue that the maintainer can read. If your users push back on this,
  open an issue and we'll reconsider.

Two things that *are* translatable and are easy to miss, because they are not
plain `Text` properties:

- **The Scriptlets table.** Its column headers (`scriptlet.col.*`) and the per-row `Enabled` / `Disabled` cell (`scriptlet.state.*`) are in the catalog and re-text live when you switch language.
- **File-dialog filters.** Only the human half is translatable
  (`dialog.filter.textReport` = "Text report"); the app concatenates the
  `(*.txt)|*.txt` part itself. Do not try to put a glob in a translation —
  you can't, and you'd break the dialog if you could.

---

## Strings worth extra care

Get these wrong and someone loses their DRM playback or their browser updates.
Please have a second pair of eyes on them before flipping `reviewed` to `true`:

- `policy.ComponentUpdatesEnabled.description`
- `hosts.components.description`
- `preset.MaxPrivacy.description` / `preset.MaxPrivacy.risk`
- `preset.MaxPerformance.description` / `preset.MaxPerformance.risk`
- `scriptlet.risk`
- `msg.restore.confirm`
- `msg.scriptlet.confirmDisable`, `msg.scriptlet.confirmRestoreAll`

A translation that makes a destructive option sound routine is worse than no
translation at all.

---

## Layout notes

The window lays itself out, so a longer translation wraps or makes a card taller instead of overlapping its neighbour. A few places are still worth keeping short:

- **Side navigation entries** (`category.*`, `tab.*`, `nav.*`) get about 26 characters before they are cut off with an ellipsis.
- **Mode card names** (`preset.*.name`) and the **bottom bar buttons** (`action.preview`, `action.apply`) read best at one short line.
- **Fonts**: the window asks for Segoe UI with Microsoft YaHei UI as the fallback, and Windows fills in any other script from its own font fallback, so there is no per-language font code any more. If your script still renders badly, mention it in the PR.

---

## Testing your file locally

```powershell
# Validate before opening the PR (same checks CI runs). No arguments needed.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Locales.ps1

# Run the app in your language
.\Brave-Free-Origin.ps1 -Lang fr-FR
```

`pwsh -File tools\Test-Locales.ps1` works too. CI runs it both ways, because
the app itself is launched by `powershell.exe` (Windows PowerShell 5.1) and
that is the host that has to work.

Maintainers only: after changing any `Add-Strings` entry in `src\strings\en-US.ps1`, regenerate the translator reference and commit it. The generator parses the catalog's syntax tree and never executes it, and its output is byte-identical under both hosts, so CI can diff it:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Export-EnglishLocale.ps1
```

`-Lang` survives the UAC elevation prompt, so you'll get your language in the
elevated window too.

Things worth clicking through:

- Every page in the side navigation, including the three sections on **Search & Startup**.
- The mode cards on **Home**: check that no description is cut off.
- **Find a setting**: type something, turn on **Selected only**.
- **Preview changes** and **Verify**: these stay English, that's expected.
- Switch back to English in **Settings**. Everything should re-text live, including pickers, tooltips and the mode cards.
- Export a config in your language, switch to English, import it. The switches must come back identical. If they don't, that's a bug in the app, not your translation, so please report it.

---

## Adding a language to the picker

Nothing to do. The picker enumerates `locales\*.json` at startup. Drop the file
in, restart, it's there.

Locale resolution order at startup: `-Lang`, then the saved preference in
`%LOCALAPPDATA%\Brave-Free-Origin\settings.json`, then the Windows UI culture,
then a same-language file, then English.

The same-language step is script-aware, and this matters if you are adding a
Chinese variant. `zh-CN`, `zh-SG`, `zh-MY`, `zh-Hans-*` and bare `zh` resolve
to `zh-CN.json`. `zh-TW`, `zh-HK`, `zh-MO` and `zh-Hant-*` resolve to a
Traditional Chinese file if one is installed, and to **English** if it is not —
Simplified text is not an acceptable substitute for a Traditional reader, so
the app will not quietly serve it. Add `zh-TW.json` and Traditional Chinese
users pick it up automatically. Languages without a Simplified/Traditional
split match on the language subtag alone, so `fr-FR.json` serves an `fr-CA`
machine.

---

## If something in English reads badly

Say so in the issue. Awkward source English usually means the string is doing
too much, and fixing it helps every translation. Don't paper over it.
