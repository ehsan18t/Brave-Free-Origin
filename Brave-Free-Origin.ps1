# ============================================================================
#  Brave Free Origin - GUI edition for Windows
#  Applies Brave Browser group policies via the registry with a checkbox UI.
#  Source policies researched from brave/brave-core and Chromium enterprise docs.
#
#  This file is the entry point and table of contents: it elevates, loads the
#  code in src\ in a fixed order (see "Load order" below), then shows the window.
#
#  Every .ps1, .psd1 and .xaml in this project is deliberately pure ASCII.
#  Windows PowerShell 5.1 decodes a BOM-less script using the system ANSI code
#  page, so any literal non-ASCII text would mojibake on machines with a
#  different code page. Translations live in locales\*.json and are read with
#  an explicit UTF-8 decoder.
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
    # anything passed on the command line vanished at the UAC boundary. The
    # elevated copy runs without a console window: the app is the window.
    $relaunchArgs = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $PSCommandPath)
        '-BfoSettingsPath', ('"{0}"' -f $BfoSettingsPath)
    )
    if ($Lang) { $relaunchArgs += @('-Lang', ('"{0}"' -f $Lang)) }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -ArgumentList $relaunchArgs
    exit
}
#endregion

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$script:AppVersion = '2.0'

#region Load order ------------------------------------------------------------
# The app is split across src\ and dot-sourced here, so every file shares this
# script's scope exactly as if it were one file. Order matters:
#   core\     logic and the data model, no controls are created. The
#             background runspace (ui\Jobs.ps1) loads core\ and strings\ too.
#   strings\  the English string catalog
#   ui\       the window: theme, view model, jobs, dialogs, then the window
#             itself (ui\xaml\*.xaml) and the code behind each page
# What the app can change (policies, tasks, services, hosts groups, search
# engines, presets) is plain data in tweaks\, read by core\Tweaks.ps1.
$script:AppRoot = $PSScriptRoot
$script:SourceFiles = @(
    'core\Log.ps1'
    'core\I18n.ps1'
    'core\Settings.ps1'
    'core\Channels.ps1'
    'core\Tweaks.ps1'
    'core\Registry.ps1'
    'core\Hosts.ps1'
    'core\SearchStartup.ps1'
    'core\Presets.ps1'
    'core\Plan.ps1'
    'core\Apply.ps1'
    'core\Scriptlets.ps1'
    'core\State.ps1'
    'strings\en-US.ps1'
    'ui\Theme.ps1'
    'ui\Model.ps1'
    'ui\Jobs.ps1'
    'ui\Dialogs.ps1'
    'ui\Window.ps1'
    'ui\Actions.ps1'
    'ui\Scriptlets.ps1'
)

$script:RequiredFiles = @(
    'src\ui\xaml\Theme.xaml'
    'src\ui\xaml\Window.xaml'
    'tweaks\system.psd1'
    'tweaks\hosts.psd1'
    'tweaks\search.psd1'
    'tweaks\presets.psd1'
)

# Shown before the string catalog exists, so it is English only. A startup
# failure has to be visible: there is no console window to read it from.
function Show-StartupError {
    param([string]$Message)
    [void][System.Windows.MessageBox]::Show($Message, 'Brave Free Origin',
        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
}

# A copy of this file on its own is the most likely way to get here, so say
# that plainly instead of failing on the first missing function.
$missingFiles = @(
    @($script:SourceFiles | ForEach-Object { "src\$_" }) + $script:RequiredFiles |
        Where-Object { -not (Test-Path -LiteralPath (Join-Path $script:AppRoot $_)) }
)
if (-not (Get-ChildItem -LiteralPath (Join-Path $script:AppRoot 'tweaks\policies') -Filter '*.psd1' -File -ErrorAction SilentlyContinue)) {
    $missingFiles += 'tweaks\policies\*.psd1'
}
if ($missingFiles.Count -gt 0) {
    Show-StartupError ("Brave Free Origin cannot start because these files are missing:`r`n`r`n" +
        ($missingFiles -join "`r`n") +
        "`r`n`r`nExtract the whole folder from the ZIP and run Brave-Free-Origin.bat again.")
    exit 1
}

# A loader that cannot continue (for example a typo in a tweaks\ file) sets
# $script:StartupError instead of throwing, so the message stays readable.
# The UI language is settled between core\ and ui\, so the window is built in
# the right language the first time.
$script:StartupError = $null
foreach ($sourceFile in $script:SourceFiles) {
    if ($sourceFile -eq 'ui\Theme.ps1') {
        # Order: -Lang, then the saved preference, then the Windows UI
        # culture, then English.
        $script:BfoSettings = Get-BfoSettings -Path $BfoSettingsPath
        $startupLocale = Resolve-StartupLocale -Requested $Lang -Saved "$($script:BfoSettings['language'])"
        if ($startupLocale -ne 'en-US') { [void](Set-BfoLocale -Code $startupLocale) }
        $script:BraveVersion = Get-BraveVersion
    }
    try {
        . (Join-Path $script:AppRoot "src\$sourceFile")
    } catch {
        $script:StartupError = "Brave Free Origin could not start ($sourceFile).`r`n`r`n$($_.Exception.Message)"
    }
    if ($script:StartupError) {
        Show-StartupError $script:StartupError
        exit 1
    }
}
#endregion

# ---- Startup ---------------------------------------------------------------
# Before the window gets a handle: the taskbar identity only counts if it is
# set before any window appears, and the title bar colors need the helper.
[void](Initialize-BfoNative)
$vm = $script:Vm
$vm.LanguageIndex = [Math]::Max(0, (Get-ChoiceIndex $vm.LanguageItems $script:CurrentLocale))
$savedTheme = "$($script:BfoSettings['theme'])"
if ($script:ThemeModes -contains $savedTheme) {
    $vm.ThemeIndex = Get-ChoiceIndex $vm.ThemeItems $savedTheme
    Set-BfoTheme -Mode $savedTheme
}
Update-ModelText
Update-OverrideStates
Set-Baseline -Scope All
Update-SelectionSummary
Show-BfoPage 'home' -NoAnimation

Write-Log "Brave Free Origin v$($script:AppVersion) - running as administrator, OK."
Write-Log "Brave version: $($script:BraveVersion)"
Write-Log "UI locale: $($script:CurrentLocale)"
Write-Log 'Loading current policy state...'

# The worker starts loading core\ while the window paints; reading the current
# state is queued right behind it.
Start-BfoWorker
Invoke-BfoLoadState -Quiet
$script:JobTimer.Start()

[void]$script:Window.ShowDialog()
