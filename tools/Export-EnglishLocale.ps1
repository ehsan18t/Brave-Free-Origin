<#
.SYNOPSIS
    Regenerates locales\en-US.json from the English catalog in
    src\strings\en-US.ps1.

.DESCRIPTION
    The embedded catalog is the single runtime source of truth. en-US.json is
    a generated reference artifact for translators; the app never loads it.
    Run this after adding or changing any Add-Strings entry, then commit the
    result so translators can diff it.

    The catalog is parsed, never executed - it only makes sense inside the app,
    which self-elevates and opens a GUI. The app version is read from
    Brave-Free-Origin.ps1 the same way.

    Output is byte-for-byte deterministic: keys are sorted, indentation is
    fixed at two spaces, line endings are LF and there is no BOM. The JSON is
    written by a small serializer in this file rather than by ConvertTo-Json,
    because ConvertTo-Json formats differently between Windows PowerShell 5.1
    and PowerShell 7 - which would make the CI drift check depend on which
    host happened to run it.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\Export-EnglishLocale.ps1

.EXAMPLE
    pwsh -File tools\Export-EnglishLocale.ps1 -OutputPath D:\tmp\en-US.json
#>
[CmdletBinding()]
param(
    # Left empty on purpose. $PSScriptRoot is not yet populated while param()
    # default expressions are evaluated under Windows PowerShell 5.1, so a
    # default of (Join-Path $PSScriptRoot ...) makes the script unusable
    # without explicit paths. Defaults are resolved in the body instead.
    [string]$ScriptPath,
    [string]$CatalogPath,
    [string]$OutputPath,
    [string]$AppVersion
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $ScriptPath)  { $ScriptPath  = Join-Path $repoRoot 'Brave-Free-Origin.ps1' }
if (-not $CatalogPath) { $CatalogPath = Join-Path $repoRoot 'src\strings\en-US.ps1' }
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot 'locales\en-US.json' }

function Get-EmbeddedCatalog {
    param([string]$Path)

    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path $Path).Path, [ref]$tokens, [ref]$errors)
    if ($errors) {
        $errors | ForEach-Object { Write-Error $_.Message }
        throw "$Path does not parse."
    }

    $calls = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Add-Strings'
    }, $true)

    $catalog = [ordered]@{}
    foreach ($call in $calls) {
        $table = $call.CommandElements |
                 Where-Object { $_ -is [System.Management.Automation.Language.HashtableAst] } |
                 Select-Object -First 1
        if (-not $table) { continue }
        foreach ($pair in $table.KeyValuePairs) {
            $key = $pair.Item1.SafeGetValue()
            # SafeGetValue refuses anything that is not a literal, which is
            # exactly the guarantee we want: no catalog entry may be computed.
            try   { $value = $pair.Item2.SafeGetValue() }
            catch { throw "Catalog entry '$key' is not a plain string literal." }
            if ($catalog.Contains($key)) { throw "Duplicate catalog key: $key" }
            $catalog[$key] = [string]$value
        }
    }
    return $catalog
}

function Get-AppVersion {
    param([string]$Path)
    $line = Select-String -Path $Path -Pattern "^\`$script:AppVersion\s*=\s*'([^']+)'" |
            Select-Object -First 1
    if ($line) { return $line.Matches[0].Groups[1].Value }
    return '0.0'
}

# ---- deterministic JSON -----------------------------------------------------
# Minimal writer for exactly the shapes this file needs: string, bool, string
# array, ordered dictionary. Escapes per RFC 8259 and leaves printable
# non-ASCII alone so a translated file stays readable in a diff.
function ConvertTo-JsonString {
    param([string]$Value)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in $Value.ToCharArray()) {
        switch ([int]$ch) {
            0x22 { [void]$sb.Append('\"'); }
            0x5C { [void]$sb.Append('\\'); }
            0x08 { [void]$sb.Append('\b'); }
            0x09 { [void]$sb.Append('\t'); }
            0x0A { [void]$sb.Append('\n'); }
            0x0C { [void]$sb.Append('\f'); }
            0x0D { [void]$sb.Append('\r'); }
            default {
                if ([int]$ch -lt 0x20) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) }
                else                   { [void]$sb.Append($ch) }
            }
        }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function ConvertTo-JsonValue {
    param($Value, [int]$Depth)
    $pad     = ' ' * (2 * $Depth)
    $padIn   = ' ' * (2 * ($Depth + 1))

    if ($Value -is [System.Collections.IDictionary]) {
        $keys = @($Value.Keys)
        if ($keys.Count -eq 0) { return '{}' }
        $lines = foreach ($k in $keys) {
            '{0}{1}: {2}' -f $padIn, (ConvertTo-JsonString ([string]$k)), (ConvertTo-JsonValue -Value $Value[$k] -Depth ($Depth + 1))
        }
        return "{`n" + ($lines -join ",`n") + "`n$pad}"
    }
    if ($Value -is [bool])   { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [string]) { return ConvertTo-JsonString $Value }
    if ($null -eq $Value)    { return 'null' }
    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @($Value)
        if ($items.Count -eq 0) { return '[]' }
        $lines = foreach ($i in $items) { $padIn + (ConvertTo-JsonValue -Value $i -Depth ($Depth + 1)) }
        return "[`n" + ($lines -join ",`n") + "`n$pad]"
    }
    return ConvertTo-JsonString ([string]$Value)
}

# ---- run --------------------------------------------------------------------
$catalog = Get-EmbeddedCatalog -Path $CatalogPath
if ($catalog.Count -eq 0) { throw 'No Add-Strings blocks found - catalog extraction failed.' }
if (-not $AppVersion) { $AppVersion = Get-AppVersion -Path $ScriptPath }

# Ordinal, not Sort-Object. Sort-Object is culture-sensitive, and Windows
# PowerShell 5.1 collates with NLS while PowerShell 7 collates with ICU - the
# two disagree about where '.' sorts, which would make the generated key order
# depend on the host and break the CI drift check.
$keys = [string[]]@($catalog.Keys)
[Array]::Sort($keys, [System.StringComparer]::Ordinal)

$strings = [ordered]@{}
foreach ($key in $keys) { $strings[$key] = $catalog[$key] }

$doc = [ordered]@{
    meta = [ordered]@{
        locale      = 'en-US'
        name        = 'English'
        englishName = 'English'
        appVersion  = $AppVersion
        translators = @()
        reviewed    = $true
        generated   = $true
        note        = 'Reference only. The app never loads this file - the English catalog is src/strings/en-US.ps1. Regenerate with tools/Export-EnglishLocale.ps1.'
    }
    strings = $strings
}

# LF, UTF-8 without BOM: matches .gitattributes (*.json text eol=lf).
$json = (ConvertTo-JsonValue -Value $doc -Depth 0) + "`n"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$full = [System.IO.Path]::GetFullPath($OutputPath)
[System.IO.File]::WriteAllText($full, $json, $utf8)

Write-Output "Wrote $($strings.Count) keys to $full (app version $AppVersion)."
