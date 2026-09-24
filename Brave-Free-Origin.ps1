# ============================================================================
#  Brave Free Origin - GUI edition for Windows
#  Applies Brave Browser group policies via the registry with a checkbox UI.
#  Source policies researched from brave/brave-core and Chromium enterprise docs.
#
#  This file is the entry point and table of contents: it elevates, loads the
#  code in src\ in a fixed order (see "Load order" below), then shows the window.
#
#  Every .ps1 and .psd1 in this project is deliberately pure ASCII. Windows
#  PowerShell 5.1 decodes a BOM-less script using the system ANSI code page, so
#  any literal non-ASCII text would mojibake on machines with a different code
#  page. Translations live in locales\*.json and are read with an explicit
#  UTF-8 decoder.
# ============================================================================

[CmdletBinding()]
param(
    # Force a UI language, e.g. -Lang zh-CN. Falls back to the saved setting,
    # then the Windows UI culture, then English.
    [string]$Lang,

    # Resolved before elevation and forwarded across the UAC boundary, so an
    # elevated administrator account still reads and writes the original
    # user's preference file instead of its own.
    [string]$BfoSettingsPath
)

#region Elevation -------------------------------------------------------------
if (-not $BfoSettingsPath) {
    $BfoSettingsPath = Join-Path $env:LOCALAPPDATA 'Brave-Free-Origin\settings.json'
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Forward our own parameters. The old code rebuilt a fixed command line, so
    # anything passed on the command line vanished at the UAC boundary.
    $relaunchArgs = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $PSCommandPath)
        '-BfoSettingsPath', ('"{0}"' -f $BfoSettingsPath)
    )
    if ($Lang) { $relaunchArgs += @('-Lang', ('"{0}"' -f $Lang)) }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $relaunchArgs
    exit
}
#endregion

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppVersion = '1.12'

#region Load order ------------------------------------------------------------
# The app is split across src\ and dot-sourced here, so every file shares this
# script's scope exactly as if it were one file. Order matters:
#   core\     logic and the data model, no controls are created
#   strings\  the English string catalog
#   ui\       the window, built top to bottom in the order it appears on screen
$script:AppRoot = $PSScriptRoot
$script:SourceFiles = @(
    'core\Log.ps1'
    'core\I18n.ps1'
    'core\Settings.ps1'
    'core\Channels.ps1'
    'core\Data.ps1'
    'core\Registry.ps1'
    'core\Hosts.ps1'
    'core\SearchStartup.ps1'
    'core\Presets.ps1'
    'core\Plan.ps1'
    'core\Apply.ps1'
    'core\Scriptlets.ps1'
    'strings\en-US.ps1'
    'ui\Localization.ps1'
    'ui\Controls.ps1'
    'ui\Filter.ps1'
    'ui\ScriptletList.ps1'
    'ui\Form.ps1'
    'ui\Header.ps1'
    'ui\ModeDeck.ps1'
    'ui\FilterBar.ps1'
    'ui\Tab.Policies.ps1'
    'ui\Tab.System.ps1'
    'ui\Tab.Hosts.ps1'
    'ui\Tab.Scriptlets.ps1'
    'ui\Tab.SearchStartup.ps1'
    'ui\UtilityBar.ps1'
    'ui\ActionBar.ps1'
)

# A copy of this file on its own is the most likely way to get here, so say
# that plainly instead of failing on the first missing function.
$missingSourceFiles = @($script:SourceFiles | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $script:AppRoot "src\$_"))
})
if ($missingSourceFiles.Count -gt 0) {
    [System.Windows.Forms.MessageBox]::Show(
        ("Brave Free Origin cannot start because these files are missing:`r`n`r`n" +
         (($missingSourceFiles | ForEach-Object { "src\$_" }) -join "`r`n") +
         "`r`n`r`nExtract the whole folder from the ZIP and run Brave-Free-Origin.bat again."),
        'Brave Free Origin',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}

foreach ($sourceFile in $script:SourceFiles) {
    . (Join-Path $script:AppRoot "src\$sourceFile")
}
#endregion

# ---- Locale bootstrap -------------------------------------------------------
# Order: -Lang, then the saved preference, then the Windows UI culture, then
# English. Applied after the whole UI exists so one pass re-texts everything.
$script:BfoSettings = Get-BfoSettings -Path $BfoSettingsPath
$startupLocale = Resolve-StartupLocale -Requested $Lang -Saved "$($script:BfoSettings['language'])"
if ($startupLocale -ne 'en-US') {
    if (Set-BfoLocale -Code $startupLocale) {
        $form.Font = Get-BfoUiFont -Size 9
        Update-UiLanguage
    }
}
for ($i = 0; $i -lt $script:LocaleList.Count; $i++) {
    if ($script:LocaleList[$i].Code -eq $script:CurrentLocale) { $script:LanguageCombo.SelectedIndex = $i; break }
}
if ($script:LanguageCombo.SelectedIndex -lt 0) { $script:LanguageCombo.SelectedIndex = 0 }
Update-LocaleNote

$script:FilterReady = $true
Update-SelectionSummary
Update-ConfigurationFilter

# ---- Startup ---------------------------------------------------------------
$form.Add_Shown({
    Write-Log "Brave Free Origin v$($script:AppVersion) - running as administrator, OK."
    Write-Log "Brave version: $braveVer"
    Write-Log "UI locale: $($script:CurrentLocale)"
    Write-Log 'Loading current policy state...'
    $btnLoad.PerformClick()
})

[void]$form.ShowDialog()
