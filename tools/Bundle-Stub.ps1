<# :
@echo off
REM -----------------------------------------------------------------------
REM  Brave Free Origin - single-file edition
REM  Double-click this file. It is a batch file and a PowerShell script in
REM  one: this batch part hands the whole file to PowerShell, which unpacks
REM  the app into a temporary folder, runs it and deletes the folder again.
REM  Every file of the app is below in plain text, so it can be read before
REM  running. To unpack it without running anything:
REM      Brave-Free-Origin.cmd -BfoExtractTo C:\some\empty\folder
REM -----------------------------------------------------------------------
setlocal
set "BFO_BUNDLE=%~f0"

echo Launching Brave Free Origin...
echo If Windows shows a UAC prompt, click Yes.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create([IO.File]::ReadAllText($env:BFO_BUNDLE))) %*"
set "BFO_EXIT=%errorlevel%"

if not "%BFO_EXIT%"=="0" (
    echo.
    echo Brave Free Origin did not start. See the message above.
    pause
)
endlocal & exit /b %BFO_EXIT%
#>

# ============================================================================
#  From here on the file is PowerShell. tools\Build-Bundle.ps1 builds
#  dist\Brave-Free-Origin.cmd from this template: it fills in the version and
#  replaces the empty file list with every file of the app.
#
#  The app runs from real files on disk, exactly as it does from the ZIP, so
#  nothing in it knows it was bundled. The folder it runs from:
#    - is created by the elevated copy, readable and writable only by
#      Administrators and SYSTEM, so nothing without admin rights can change
#      the code between unpacking and running it
#    - lives in %TEMP% and is deleted when the window closes
#    - holds a lock file while the app runs; the next run deletes every
#      unlocked folder left behind by a crash or a power cut, whatever version
#      made it
# ============================================================================

[CmdletBinding()]
param(
    # Passed on to the app, e.g. -Lang zh-CN.
    [string]$Lang,

    # Resolved before elevation and forwarded across the UAC boundary, the
    # same way Brave-Free-Origin.ps1 does it.
    [string]$BfoSettingsPath,
    [string]$BfoLocalAppData,

    # This file. The batch part passes it in the environment, the elevated
    # copy as a parameter (an elevated process does not inherit it).
    [string]$BfoBundle,

    # Unpack into this folder and stop: no elevation, nothing runs. For
    # reading the app, and for CI to check the bundle.
    [string]$BfoExtractTo
)

$ErrorActionPreference = 'Stop'
$bundleVersion = 'dev'
$folderPrefix = 'Brave-Free-Origin-'

if (-not $BfoBundle) { $BfoBundle = $env:BFO_BUNDLE }

# ---- The app's files -------------------------------------------------------
# Each entry is one file: its path, its line ending and whether it ends with
# a newline, so it unpacks byte for byte as it is in the repository. A line
# of the file that starts with '@ has one | in front, since it would end the
# here-string early; Expand-BundleFile takes it off again.
$bundleFiles = @()

function Expand-BundleFile {
    param([string]$Destination)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    foreach ($file in $bundleFiles) {
        $path = Join-Path $Destination $file.Path
        $parent = Split-Path -Parent $path
        if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent) }
        $eol = if ($file.Eol -eq 'LF') { "`n" } else { "`r`n" }
        $text = [regex]::Replace($file.Text, "(?m)^\|(\|*'@)", '$1')
        $text = ($text -split "`r?`n") -join $eol
        if ($file.FinalNewline) { $text += $eol }
        [System.IO.File]::WriteAllText($path, $text, $utf8)
    }
}

# ---- Unpack only ---------------------------------------------------------------
if ($BfoExtractTo) {
    if ((Test-Path -LiteralPath $BfoExtractTo) -and (Get-ChildItem -LiteralPath $BfoExtractTo -Force)) {
        Write-Warning "$BfoExtractTo is not empty. Pick an empty or new folder."
        exit 1
    }
    [void](New-Item -ItemType Directory -Path $BfoExtractTo -Force)
    Expand-BundleFile -Destination (Resolve-Path -LiteralPath $BfoExtractTo).Path
    Write-Output "Unpacked Brave Free Origin $bundleVersion ($($bundleFiles.Count) files) into $BfoExtractTo"
    exit 0
}

# ---- Elevation -----------------------------------------------------------------
if (-not $BfoSettingsPath) {
    $BfoSettingsPath = Join-Path $env:LOCALAPPDATA 'Brave-Free-Origin\settings.json'
}
if (-not $BfoLocalAppData) { $BfoLocalAppData = $env:LOCALAPPDATA }

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if (-not $BfoBundle -or -not (Test-Path -LiteralPath $BfoBundle)) {
        Write-Warning 'Cannot find this file on disk. Run Brave-Free-Origin.cmd itself, not a copy of its text.'
        exit 1
    }
    # The elevated copy reads this file again and runs it with the same
    # parameters. Single quotes are doubled so any path survives; the command
    # has no double quotes, so wrapping it in them is safe.
    $quote = { param($value) "'" + ($value -replace "'", "''") + "'" }
    $command = "& ([scriptblock]::Create([IO.File]::ReadAllText({0}))) -BfoBundle {0} -BfoSettingsPath {1} -BfoLocalAppData {2}" -f `
        (& $quote $BfoBundle), (& $quote $BfoSettingsPath), (& $quote $BfoLocalAppData)
    if ($Lang) { $command += ' -Lang ' + (& $quote $Lang) }
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -ArgumentList @(
            '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', ('"{0}"' -f $command))
    } catch {
        Write-Warning "Brave Free Origin needs administrator rights to change Brave's policies. $($_.Exception.Message)"
        exit 1
    }
    exit 0
}

# ---- Elevated from here on ---------------------------------------------------
Add-Type -AssemblyName PresentationFramework

# The elevated copy has no console window, so a failure has to be a dialog.
function Show-BundleError {
    param([string]$Message)
    [void][System.Windows.MessageBox]::Show($Message, 'Brave Free Origin',
        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
}

$tempRoot = [System.IO.Path]::GetTempPath()

# Folders from earlier runs. A folder whose lock file is held belongs to a copy
# that is still running and is left alone. A folder with no lock file yet may
# be one another copy is creating this very moment, unless it is old.
foreach ($old in @(Get-ChildItem -LiteralPath $tempRoot -Directory -Filter "$folderPrefix*" -ErrorAction SilentlyContinue)) {
    if ($old.Name -notmatch '^Brave-Free-Origin-[\w.]+-[0-9a-f]{32}$') { continue }
    $oldLock = Join-Path $old.FullName '.lock'
    try {
        if (Test-Path -LiteralPath $oldLock) {
            [System.IO.File]::Open($oldLock, 'Open', 'ReadWrite', 'None').Dispose()
        } elseif ($old.CreationTimeUtc -gt [DateTime]::UtcNow.AddMinutes(-10)) {
            continue
        }
        Remove-Item -LiteralPath $old.FullName -Recurse -Force
    } catch {
        Write-Verbose "Left $($old.FullName) in place: $($_.Exception.Message)"
    }
}

$appDir = Join-Path $tempRoot ('{0}{1}-{2}' -f $folderPrefix, $bundleVersion, [guid]::NewGuid().ToString('N'))
$lock = $null
try {
    # Administrators and SYSTEM only, not inherited from %TEMP%, set as the
    # folder is created so there is no moment it is open to anyone else. The
    # name is random, so it cannot have been created in advance.
    $security = New-Object System.Security.AccessControl.DirectorySecurity
    $security.SetAccessRuleProtection($true, $false)
    foreach ($sid in @('S-1-5-32-544', 'S-1-5-18')) {
        $security.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            (New-Object System.Security.Principal.SecurityIdentifier($sid)), 'FullControl',
            'ContainerInherit, ObjectInherit', 'None', 'Allow')))
    }
    [void][System.IO.Directory]::CreateDirectory($appDir, $security)
    $lock = [System.IO.File]::Open((Join-Path $appDir '.lock'), 'CreateNew', 'ReadWrite', 'None')

    Expand-BundleFile -Destination $appDir

    $appArgs = @{
        BfoSettingsPath = $BfoSettingsPath
        BfoLocalAppData = $BfoLocalAppData
    }
    if ($Lang) { $appArgs['Lang'] = $Lang }
    & (Join-Path $appDir 'Brave-Free-Origin.ps1') @appArgs
} catch {
    Show-BundleError "Brave Free Origin could not start.`r`n`r`n$($_.Exception.Message)"
} finally {
    if ($lock) { $lock.Dispose() }
    if (Test-Path -LiteralPath $appDir) {
        # Whatever cannot go now is removed by the next run.
        Remove-Item -LiteralPath $appDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
