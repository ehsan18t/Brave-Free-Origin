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
        Write-Log "Backup saved: $file" 'OK'
        return $file
    } else {
        Write-Log "Backup skipped (no existing policies)." 'INFO'
        return $null
    }
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
