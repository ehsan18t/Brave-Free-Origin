<#
.SYNOPSIS
    Builds dist\Brave-Free-Origin.cmd: the whole app in one file that runs on
    a double-click.

.DESCRIPTION
    The output is tools\Bundle-Stub.ps1 with every file the app needs at run
    time appended as plain text: Brave-Free-Origin.ps1, src\, the .psd1 data
    in tweaks\ and locales\*.json. When run, it unpacks them into a temporary
    folder, runs the app from there and deletes the folder again; see the
    stub for how.

    Files are embedded as here-strings, not base64, so the bundle stays as
    readable as the repository. Each one records its line ending and final
    newline, so it unpacks byte for byte. A line starting with '@ would end
    its here-string early, so it is stored with one | in front ('@ becomes
    |'@, |'@ becomes ||'@, and so on) and the stub takes it off again. The
    build stops on a file it cannot embed exactly: a UTF-8 BOM, invalid UTF-8
    or mixed line endings.

    Runs on Windows PowerShell 5.1 and on PowerShell 7.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\Build-Bundle.ps1

.EXAMPLE
    pwsh -File tools\Build-Bundle.ps1 -OutFile C:\out\Brave-Free-Origin.cmd
#>
[CmdletBinding()]
param(
    # Left empty on purpose: $PSScriptRoot is not yet populated while param()
    # defaults are evaluated under Windows PowerShell 5.1.
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutFile) { $OutFile = Join-Path $repoRoot 'dist\Brave-Free-Origin.cmd' }

$stubPath = Join-Path $PSScriptRoot 'Bundle-Stub.ps1'
$entryPath = Join-Path $repoRoot 'Brave-Free-Origin.ps1'
$versionMatch = [regex]::Match([System.IO.File]::ReadAllText($entryPath), "\`$script:AppVersion = '([^']+)'")
if (-not $versionMatch.Success) { throw 'Could not read $script:AppVersion from Brave-Free-Origin.ps1.' }
$version = $versionMatch.Groups[1].Value

# Everything the app reads at run time. Docs in tweaks\ (README, SOURCES) are
# for maintainers and stay out, as does tools\.
$files = @(Get-Item -LiteralPath $entryPath)
$files += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src') -Recurse -File)
$files += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tweaks') -Recurse -File -Filter '*.psd1')
$files += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'locales') -File -Filter '*.json')
$entries = @($files | ForEach-Object {
    [pscustomobject]@{ Path = $_.FullName.Substring($repoRoot.Length).TrimStart('\', '/') -replace '/', '\'; FullName = $_.FullName }
} | Sort-Object Path)

$strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
$payload = New-Object System.Text.StringBuilder
[void]$payload.Append("`$bundleFiles = @(`r`n")
foreach ($entry in $entries) {
    $bytes = [System.IO.File]::ReadAllBytes($entry.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        throw "$($entry.Path) has a UTF-8 BOM. Save it without one."
    }
    try { $text = $strictUtf8.GetString($bytes) } catch { throw "$($entry.Path) is not valid UTF-8." }

    $crlf = [regex]::Matches($text, "`r`n").Count
    $lf = [regex]::Matches($text, "(?<!`r)`n").Count
    if ([regex]::IsMatch($text, "`r(?!`n)")) { throw "$($entry.Path) has a carriage return without a line feed." }
    if ($crlf -gt 0 -and $lf -gt 0) { throw "$($entry.Path) mixes CRLF and LF line endings." }
    $eol = if ($lf -gt 0) { 'LF' } else { 'CRLF' }
    $eolText = if ($eol -eq 'LF') { "`n" } else { "`r`n" }

    $finalNewline = $text.EndsWith($eolText)
    if ($finalNewline) { $text = $text.Substring(0, $text.Length - $eolText.Length) }
    $text = [regex]::Replace($text, "(?m)^(\|*'@)", '|$1')

    $body = ($text -split "`r?`n") -join "`r`n"
    [void]$payload.Append(("    @{{ Path = '{0}'; Eol = '{1}'; FinalNewline = `${2}; Text = @'`r`n" -f
        ($entry.Path -replace "'", "''"), $eol, $finalNewline.ToString().ToLowerInvariant()))
    [void]$payload.Append($body)
    [void]$payload.Append("`r`n'@ }`r`n")
}
[void]$payload.Append(')')

# The template is filled in by exact text, so a changed line in the stub fails
# here instead of producing a bundle that silently holds nothing.
$stub = [System.IO.File]::ReadAllText($stubPath) -replace "(?<!`r)`n", "`r`n"
$replacements = [ordered]@{
    'REM  Brave Free Origin - single-file edition' = "REM  Brave Free Origin $version - single-file edition"
    "`$bundleVersion = 'dev'"                      = "`$bundleVersion = '$version'"
    '$bundleFiles = @()'                           = $payload.ToString()
}
foreach ($find in $replacements.Keys) {
    $count = ([regex]::Matches($stub, [regex]::Escape($find))).Count
    if ($count -ne 1) { throw "tools\Bundle-Stub.ps1 must contain '$find' exactly once (found $count)." }
    $stub = $stub.Replace($find, $replacements[$find])
}

# The result has to be valid PowerShell, or the batch part runs into an error
# on every double-click.
$tokens = $null; $parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseInput($stub, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors) {
    throw "The bundle does not parse, line $($parseErrors[0].Extent.StartLineNumber): $($parseErrors[0].Message)"
}

$outDir = Split-Path -Parent $OutFile
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { [void](New-Item -ItemType Directory -Path $outDir) }
[System.IO.File]::WriteAllText($OutFile, $stub, (New-Object System.Text.UTF8Encoding($false)))

$hash = (Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash
Write-Output ("Built {0} (v{1}, {2} files, {3:N0} KB)" -f $OutFile, $version, $entries.Count, ((Get-Item -LiteralPath $OutFile).Length / 1KB))
Write-Output "SHA256 $hash"
