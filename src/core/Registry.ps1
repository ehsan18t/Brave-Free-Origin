# ============================================================================
#  Registry policy reads, writes and .reg backups.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Writes one policy value, creating the policy key first if needed.
function Set-PolicyValue {
    param([string]$Path, [string]$Name, [string]$Type, $Value)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    $regType = if ($Type -eq 'DWORD') { 'DWord' } else { 'String' }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $regType -Force | Out-Null
}

# Removes one policy value. Returns $true only when there was one to remove.
function Remove-PolicyValue {
    param([string]$Path, [string]$Name)
    try {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $true
    } catch { return $false }
}

# A LIST policy is a subkey named after the policy holding the strings as
# values 1, 2, 3 and so on, the same layout as RestoreOnStartupURLs.
function Set-PolicyList {
    param([string]$Path, [string]$Name, [string[]]$Values)
    $listPath = Join-Path $Path $Name
    if (Test-Path $listPath) { Remove-Item -Path $listPath -Recurse -Force }
    New-Item -Path $listPath -Force | Out-Null
    $i = 1
    foreach ($value in @($Values)) {
        New-ItemProperty -Path $listPath -Name "$i" -Value $value -PropertyType String -Force | Out-Null
        $i++
    }
}

function Remove-PolicyList {
    param([string]$Path, [string]$Name)
    $listPath = Join-Path $Path $Name
    if (-not (Test-Path $listPath)) { return $false }
    Remove-Item -Path $listPath -Recurse -Force -ErrorAction Stop
    return $true
}

# One policy, whatever its type. Set-/Remove-Policy are what Apply, Re-apply
# and Clean up call, so a LIST policy is never written as a plain value.
function Set-Policy {
    param([string]$Path, [string]$Name, [string]$Type, $Value)
    if ($Type -eq 'LIST') { Set-PolicyList -Path $Path -Name $Name -Values ([string[]]@($Value)) }
    else { Set-PolicyValue -Path $Path -Name $Name -Type $Type -Value $Value }
}

function Remove-Policy {
    param([string]$Path, [string]$Name, [string]$Type)
    if ($Type -eq 'LIST') { return (Remove-PolicyList -Path $Path -Name $Name) }
    return (Remove-PolicyValue -Path $Path -Name $Name)
}

# A value as reports show it: a list as its items joined by commas.
function Format-PolicyValueText {
    param($Value)
    if ($Value -is [array]) { return (@($Value) -join ', ') }
    return "$Value"
}

# Registry DWORDs come back as Int32 and lists as string arrays, so two values
# are compared as text; lists item by item, in order.
function Test-PolicyValueEqual {
    param($Actual, $Expected)
    if ($Actual -is [array] -or $Expected -is [array]) {
        return ((@($Actual) -join "`n") -eq (@($Expected) -join "`n"))
    }
    return ("$Actual" -eq "$Expected")
}

# Writes a table built by one of the Get-Desired*Override functions:
# name -> @{ Type = 'DWORD' or 'STRING'; Value = ... }, in table order.
function Write-DesiredValues {
    param([string]$Path, [System.Collections.IDictionary]$Desired)
    foreach ($name in $Desired.Keys) {
        Set-PolicyValue -Path $Path -Name $name -Type $Desired[$name].Type -Value $Desired[$name].Value
    }
}

function Export-Backup {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $file = Join-Path (Get-BackupDir -Create) "brave-policies-backup-$stamp.reg"
    $regKey = 'HKLM\Software\Policies\BraveSoftware'
    & reg.exe EXPORT $regKey $file /y 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-BfoLog "Backup saved: $file" 'OK'
        return $file
    } else {
        Write-BfoLog "Backup skipped (no existing policies)." 'INFO'
        return $null
    }
}

# Every value under a key in one read, name -> value. Empty when the key does
# not exist. Reading 92 policies one by one took about a quarter of a second.
$script:RegistryProviderProperties = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')

function Get-RegistryValueTable {
    param([string]$Path)
    $values = @{}
    if (Test-Path $Path) {
        $props = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
        if ($props) {
            foreach ($p in $props.PSObject.Properties) {
                if ($script:RegistryProviderProperties -notcontains $p.Name) { $values[$p.Name] = $p.Value }
            }
        }
    }
    return $values
}

# Every policy under the policy key: the plain values, plus each LIST policy
# the app knows as a string array. One read serves a whole preview or check.
function Get-PolicyValueTable {
    param([string]$Path)
    $values = Get-RegistryValueTable -Path $Path
    foreach ($cat in $script:Policies.Keys) {
        foreach ($p in $script:Policies[$cat]) {
            if ($p.Type -ne 'LIST') { continue }
            $listPath = Join-Path $Path $p.Name
            if (Test-Path $listPath) { $values[$p.Name] = [string[]]@(Get-RegistryNumberedValues -Path $listPath) }
        }
    }
    return $values
}

# The same answer as Get-RegistryValueState, from a table read beforehand.
function Get-TableValueState {
    param([hashtable]$Values, [string]$Name)
    if ($Values.ContainsKey($Name)) { return [pscustomobject]@{ Exists = $true; Value = $Values[$Name] } }
    return [pscustomobject]@{ Exists = $false; Value = $null }
}

function Get-RegistryValueState {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path $Path)) {
        return [pscustomobject]@{ Exists = $false; Value = $null }
    }
    try {
        $props = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return [pscustomobject]@{ Exists = $true; Value = $props.PSObject.Properties[$Name].Value }
    } catch {
        return [pscustomobject]@{ Exists = $false; Value = $null }
    }
}

function Get-RegistryNumberedValues {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return @() }
    $props = Get-ItemProperty -Path $Path
    $items = @()
    foreach ($p in $props.PSObject.Properties) {
        if ($p.Name -match '^\d+$') {
            $items += [pscustomobject]@{ Index = [int]$p.Name; Value = $p.Value }
        }
    }
    return @($items | Sort-Object Index | ForEach-Object { $_.Value })
}
