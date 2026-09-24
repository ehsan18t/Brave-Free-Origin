# ============================================================================
#  Utility bar: load state, verify, export and import config, backups.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- Utility buttons --------------------------------------------------------
$utilityPanel = New-Object System.Windows.Forms.Panel
$utilityPanel.Location = New-Object System.Drawing.Point(10, 716)
$utilityPanel.Size = New-Object System.Drawing.Size(1145, 40)
$utilityPanel.Anchor = 'Left, Right, Bottom'
$form.Controls.Add($utilityPanel)

# Export config to JSON
$btnExport = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnExport 'util.export')
$btnExport.Size = New-Object System.Drawing.Size(110, 30)
$btnExport.Location = New-Object System.Drawing.Point(420, 5)
$btnExport.Add_Click({
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Filter = '{0} (*.json)|*.json' -f (T 'dialog.filter.config')
    $sfd.FileName = "brave-free-origin-config-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $sfd.InitialDirectory = Join-Path $env:USERPROFILE 'Documents\Brave-Free-Origin-Backups'
    if (-not (Test-Path $sfd.InitialDirectory)) { New-Item -ItemType Directory -Path $sfd.InitialDirectory | Out-Null }
    if ($sfd.ShowDialog() -ne 'OK') { return }

    # schemaVersion tracks the config format, appVersion tracks the app. They
    # move independently: gaining a button must not force a config migration.
    $cfg = [ordered]@{
        schemaVersion = 2
        appVersion    = $script:AppVersion
        exported      = (Get-Date -Format 's')
        channel       = $script:TargetChannels
        profile       = $script:ActiveProfile
        policies      = [ordered]@{}
        policyValues  = [ordered]@{}
        tasks         = [ordered]@{}
        services      = [ordered]@{}
        hosts         = [ordered]@{}
        search   = [ordered]@{
            enabled   = [bool]$script:ChkSearchOverride.Checked
            engineId  = "$(Get-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds)"
            customUrl = "$($script:TxtCustomSearchUrl.Text)"
        }
        ntp = [ordered]@{
            enabled       = [bool]$script:ChkNtpOverride.Checked
            destinationId = "$(Get-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds)"
            customUrl     = "$($script:TxtNtpCustomUrl.Text)"
        }
        startup = [ordered]@{
            enabled = [bool]$script:ChkStartupOverride.Checked
            modeId  = "$(Get-ComboId -Combo $script:CmbStartupMode -Ids $script:StartupModeIds)"
            urls    = "$($script:TxtStartupUrl.Text)"
        }
    }
    foreach ($cb in $script:CheckBoxes)        {
        $cfg.policies[$cb.Tag.Policy.Name] = [bool]$cb.Checked
        # Remember the picked value for choice policies (e.g. hardware accel).
        if ($cb.Tag.Policy.Choices) { $cfg.policyValues[$cb.Tag.Policy.Name] = $cb.Tag.Policy.ApplyValue }
    }
    foreach ($cb in $script:TaskCheckBoxes)    { $cfg.tasks[$cb.Tag.Name]            = [bool]$cb.Checked }
    foreach ($cb in $script:ServiceCheckBoxes) { $cfg.services[$cb.Tag.Name]         = [bool]$cb.Checked }
    foreach ($cb in $script:HostsCheckBoxes)   { $cfg.hosts[$cb.Tag.Id]              = [bool]$cb.Checked }

    $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $sfd.FileName -Encoding UTF8
    Write-Log "Config exported: $($sfd.FileName)" 'OK'
})
$utilityPanel.Controls.Add($btnExport)

# Import config from JSON
$btnImport = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnImport 'util.import')
$btnImport.Size = New-Object System.Drawing.Size(110, 30)
$btnImport.Location = New-Object System.Drawing.Point(535, 5)
$btnImport.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = '{0} (*.json)|*.json' -f (T 'dialog.filter.config')
    $ofd.InitialDirectory = Join-Path $env:USERPROFILE 'Documents\Brave-Free-Origin-Backups'
    if ($ofd.ShowDialog() -ne 'OK') { return }
    try {
        $cfg = Get-Content $ofd.FileName -Raw | ConvertFrom-Json
    } catch {
        [System.Windows.Forms.MessageBox]::Show((T 'msg.config.badJson' @("$_")), (T 'msg.title.importError'), 'OK', 'Error') | Out-Null
        return
    }
    Push-SuppressSelectionEvents
    try {
        if ($cfg.policies) {
            foreach ($cb in $script:CheckBoxes) {
                $name = $cb.Tag.Policy.Name
                if ($cfg.policies.PSObject.Properties.Name -contains $name) { $cb.Checked = [bool]$cfg.policies.$name }
            }
        }
        if ($cfg.policyValues) {
            # Restore the picked value for choice policies (e.g. hardware accel).
            foreach ($cb in $script:CheckBoxes) {
                $p = $cb.Tag.Policy
                if (-not $p.Choices) { continue }
                if ($cfg.policyValues.PSObject.Properties.Name -notcontains $p.Name) { continue }
                $wanted = "$($cfg.policyValues.$($p.Name))"
                foreach ($cid in $p.Choices.Keys) {
                    if ("$($p.Choices[$cid])" -eq $wanted) {
                        [void](Set-PolicyChoiceId -Policy $p -ChoiceId $cid)
                        break
                    }
                }
            }
        }
        if ($cfg.tasks) {
            foreach ($cb in $script:TaskCheckBoxes) {
                $name = $cb.Tag.Name
                if ($cfg.tasks.PSObject.Properties.Name -contains $name) { $cb.Checked = [bool]$cfg.tasks.$name }
            }
        }
        if ($cfg.services) {
            foreach ($cb in $script:ServiceCheckBoxes) {
                $name = $cb.Tag.Name
                if ($cfg.services.PSObject.Properties.Name -contains $name) { $cb.Checked = [bool]$cfg.services.$name }
            }
        }
        if ($cfg.hosts) {
            # Accept both schema 2 ids and the pre-1.12 English display names.
            $hostsById = @{}
            foreach ($p in $cfg.hosts.PSObject.Properties) {
                $id = $p.Name
                if ($script:LegacyHostsIds.ContainsKey($id)) { $id = $script:LegacyHostsIds[$id] }
                $hostsById[$id] = [bool]$p.Value
            }
            foreach ($cb in $script:HostsCheckBoxes) {
                if ($hostsById.ContainsKey($cb.Tag.Id)) { $cb.Checked = $hostsById[$cb.Tag.Id] }
            }
        }
        if ($cfg.search) {
            $script:ChkSearchOverride.Checked = [bool]$cfg.search.enabled
            $engineId = if ($cfg.search.engineId) { "$($cfg.search.engineId)" }
                        elseif ($cfg.search.engine -and $script:LegacySearchEngineIds.ContainsKey("$($cfg.search.engine)")) {
                            $script:LegacySearchEngineIds["$($cfg.search.engine)"]
                        } else { $null }
            if ($engineId) { [void](Set-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds -Id $engineId) }
            if ($cfg.search.customUrl) { $script:TxtCustomSearchUrl.Text = $cfg.search.customUrl }
        }
        if ($cfg.ntp) {
            $script:ChkNtpOverride.Checked = [bool]$cfg.ntp.enabled
            $destId = if ($cfg.ntp.destinationId) { "$($cfg.ntp.destinationId)" }
                      elseif ($cfg.ntp.destination -and $script:LegacyDestinationIds.ContainsKey("$($cfg.ntp.destination)")) {
                          $script:LegacyDestinationIds["$($cfg.ntp.destination)"]
                      } else { $null }
            if ($destId) { [void](Set-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds -Id $destId) }
            if ($cfg.ntp.customUrl) { $script:TxtNtpCustomUrl.Text = $cfg.ntp.customUrl }
        }
        if ($cfg.startup) {
            $script:ChkStartupOverride.Checked = [bool]$cfg.startup.enabled
            $modeId = if ($cfg.startup.modeId) { "$($cfg.startup.modeId)" }
                      elseif ($cfg.startup.mode -and $script:LegacyStartupModeIds.ContainsKey("$($cfg.startup.mode)")) {
                          $script:LegacyStartupModeIds["$($cfg.startup.mode)"]
                      } else { $null }
            if ($modeId) { [void](Set-ComboId -Combo $script:CmbStartupMode -Ids $script:StartupModeIds -Id $modeId) }
            if ($cfg.startup.urls) { $script:TxtStartupUrl.Text = $cfg.startup.urls }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = if ($cfg.profile) { "$($cfg.profile)" } else { 'Custom' }
    Update-OverrideControlStates
    Update-SelectionSummary
    $schema = if ($cfg.schemaVersion) { $cfg.schemaVersion } else { 1 }
    Write-Log "Config imported from $($ofd.FileName) (schema $schema, app $($cfg.appVersion)$(if (-not $cfg.appVersion) { $cfg.version }))" 'OK'
    Update-ConfigurationFilter
    [System.Windows.Forms.MessageBox]::Show(
        (T 'msg.config.imported'),
        (T 'msg.title.imported'), 'OK', 'Information') | Out-Null
})
$utilityPanel.Controls.Add($btnImport)

# Verify - read registry, compare to UI selections
$btnVerify = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnVerify 'util.verify')
$btnVerify.Size = New-Object System.Drawing.Size(80, 30)
$btnVerify.Location = New-Object System.Drawing.Point(650, 5)
$btnVerify.Add_Click({
    $report = New-Object System.Text.StringBuilder
    foreach ($channel in $script:TargetChannels) {
        $path = $script:Channels[$channel].Path
        [void]$report.AppendLine("=== $channel  ($path) ===")
        if (-not (Test-Path $path)) {
            [void]$report.AppendLine('  (no policy key exists - nothing applied)')
            [void]$report.AppendLine('')
            continue
        }
        $matchCount = 0; $missingCount = 0; $mismatchCount = 0; $tickedCount = 0
        $missingList = @(); $mismatchList = @()
        foreach ($cb in $script:CheckBoxes) {
            if (-not $cb.Checked) { continue }
            $tickedCount++
            $p = $cb.Tag.Policy
            try {
                $cur = (Get-ItemProperty -Path $path -Name $p.Name -ErrorAction Stop).$($p.Name)
                if ("$cur" -eq "$($p.ApplyValue)") { $matchCount++ }
                else { $mismatchCount++; $mismatchList += "$($p.Name): registry=$cur, expected=$($p.ApplyValue)" }
            } catch {
                $missingCount++; $missingList += $p.Name
            }
        }
        [void]$report.AppendLine("  Ticked in UI: $tickedCount")
        [void]$report.AppendLine("  Match in registry: $matchCount")
        [void]$report.AppendLine("  Missing (not in registry): $missingCount")
        [void]$report.AppendLine("  Mismatch (wrong value): $mismatchCount")
        if ($missingList) {
            [void]$report.AppendLine('  -- missing:')
            foreach ($n in $missingList) { [void]$report.AppendLine("     - $n") }
        }
        if ($mismatchList) {
            [void]$report.AppendLine('  -- mismatch:')
            foreach ($n in $mismatchList) { [void]$report.AppendLine("     - $n") }
        }
        [void]$report.AppendLine('')
    }

    # Hosts state
    $hostsCurrent = Get-HostsCurrentDomains
    [void]$report.AppendLine("=== Hosts blocklist ===")
    [void]$report.AppendLine("  Currently blocked domains: $($hostsCurrent.Count)")
    if ($hostsCurrent.Count -gt 0) {
        foreach ($d in $hostsCurrent) { [void]$report.AppendLine("     - $d") }
    }
    [void]$report.AppendLine('')

    # Search / NTP / Startup overrides
    [void]$report.AppendLine('=== Search & Startup overrides ===')
    foreach ($channel in $script:TargetChannels) {
        $path = $script:Channels[$channel].Path
        [void]$report.AppendLine("  [$channel]")
        if (-not (Test-Path $path)) { [void]$report.AppendLine('     (no policy key - nothing set)'); continue }
        try {
            $se = (Get-ItemProperty -Path $path -Name 'DefaultSearchProviderEnabled' -ErrorAction Stop).DefaultSearchProviderEnabled
            $name = (Get-ItemProperty -Path $path -Name 'DefaultSearchProviderName' -ErrorAction SilentlyContinue).DefaultSearchProviderName
            $url  = (Get-ItemProperty -Path $path -Name 'DefaultSearchProviderSearchURL' -ErrorAction SilentlyContinue).DefaultSearchProviderSearchURL
            if ($se -eq 1) { [void]$report.AppendLine("     Search engine forced: $name ($url)") }
            else           { [void]$report.AppendLine('     Search engine override: not set') }
        } catch { [void]$report.AppendLine('     Search engine override: not set') }
        try {
            $ntp = (Get-ItemProperty -Path $path -Name 'NewTabPageLocation' -ErrorAction Stop).NewTabPageLocation
            [void]$report.AppendLine("     New tab page forced: $ntp")
        } catch { [void]$report.AppendLine('     New tab page override: not set') }
        try {
            $rc = (Get-ItemProperty -Path $path -Name 'RestoreOnStartup' -ErrorAction Stop).RestoreOnStartup
            $listPath = Join-Path $path 'RestoreOnStartupURLs'
            $urls = @()
            if (Test-Path $listPath) {
                $props = Get-ItemProperty -Path $listPath
                foreach ($p in $props.PSObject.Properties) {
                    if ($p.Name -match '^\d+$') { $urls += $p.Value }
                }
            }
            $extra = if ($urls.Count -gt 0) { " URLs: $($urls -join ', ')" } else { '' }
            [void]$report.AppendLine("     Startup forced: code $rc$extra")
        } catch { [void]$report.AppendLine('     Startup override: not set') }
    }

    Show-TextReport -Title (T 'report.verifyTitle') -Text ($report.ToString()) -DefaultFileName "brave-free-origin-verify-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
})
$utilityPanel.Controls.Add($btnVerify)

$btnLoad = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnLoad 'util.loadState')
$btnLoad.Size = New-Object System.Drawing.Size(145, 30)
$btnLoad.Location = New-Object System.Drawing.Point(0, 5)
$btnLoad.Add_Click({
    Push-SuppressSelectionEvents
    try {
        # Read from the FIRST target channel (loading is single-source by design)
        $loadPath = $script:Channels[$script:TargetChannels[0]].Path
        $originalPath = $script:BravePolicyPath
        $script:BravePolicyPath = $loadPath
        foreach ($cb in $script:CheckBoxes) {
            $p = $cb.Tag.Policy
            $cur = Get-ExistingPolicy $p.Name
            if ($p.Choices) {
                # A choice policy counts as "on" whenever a value is present; point
                # the picker at whatever the registry actually holds.
                if ($null -ne $cur) {
                    foreach ($cid in $p.Choices.Keys) {
                        if ("$($p.Choices[$cid])" -eq "$cur") {
                            [void](Set-PolicyChoiceId -Policy $p -ChoiceId $cid)
                            break
                        }
                    }
                    $cb.Checked = $true
                } else {
                    $cb.Checked = $false
                }
            } else {
                $cb.Checked = ($null -ne $cur -and "$cur" -eq "$($p.ApplyValue)")
            }
        }
        $script:BravePolicyPath = $originalPath
        foreach ($cb in $script:TaskCheckBoxes) {
            $t = $cb.Tag
            $task = Get-ScheduledTask -TaskName $t.Name -ErrorAction SilentlyContinue
            $cb.Checked = ($task -and $task.State -eq 'Disabled')
        }
        foreach ($cb in $script:ServiceCheckBoxes) {
            $s = $cb.Tag
            $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            $cb.Checked = ($svc -and $svc.StartType -eq 'Disabled')
        }
        # Hosts state
        if ($script:HostsCheckBoxes) {
            $current = Get-HostsCurrentDomains
            foreach ($cb in $script:HostsCheckBoxes) {
                $blockDomains = $cb.Tag.Domains
                $allPresent = $true
                foreach ($d in $blockDomains) { if ($current -notcontains $d) { $allPresent = $false; break } }
                $cb.Checked = $allPresent
            }
        }
        # Search engine override state
        if ($script:ChkSearchOverride) {
            $sePath = $loadPath
            $seEnabled = $false
            try {
                $val = (Get-ItemProperty -Path $sePath -Name 'DefaultSearchProviderEnabled' -ErrorAction Stop).DefaultSearchProviderEnabled
                $seEnabled = ($val -eq 1)
            } catch { $seEnabled = $false }
            $script:ChkSearchOverride.Checked = $seEnabled
            if ($seEnabled) {
                try {
                    $url = (Get-ItemProperty -Path $sePath -Name 'DefaultSearchProviderSearchURL' -ErrorAction Stop).DefaultSearchProviderSearchURL
                    $matched = $false
                    foreach ($key in $script:SearchEngines.Keys) {
                        if (-not $script:SearchEngines[$key].IsCustom -and $script:SearchEngines[$key].URL -eq $url) {
                            [void](Set-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds -Id $key)
                            $matched = $true; break
                        }
                    }
                    if (-not $matched) {
                        [void](Set-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds -Id 'custom')
                        $script:TxtCustomSearchUrl.Text = $url
                    }
                } catch {}
            }
        }
        # NTP override state
        if ($script:ChkNtpOverride) {
            try {
                $ntpUrl = (Get-ItemProperty -Path $loadPath -Name 'NewTabPageLocation' -ErrorAction Stop).NewTabPageLocation
                $script:ChkNtpOverride.Checked = $true
                $matched = $false
                foreach ($k in $script:DestinationOptions.Keys) {
                    if ($script:DestinationOptions[$k].Value -eq $ntpUrl) {
                        $matched = [bool](Set-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds -Id $k)
                        if ($matched) { break }
                    }
                }
                if (-not $matched) {
                    [void](Set-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds -Id 'custom')
                    $script:TxtNtpCustomUrl.Text = $ntpUrl
                }
            } catch { $script:ChkNtpOverride.Checked = $false }
        }
        # Startup override state
        if ($script:ChkStartupOverride) {
            try {
                $code = (Get-ItemProperty -Path $loadPath -Name 'RestoreOnStartup' -ErrorAction Stop).RestoreOnStartup
                $script:ChkStartupOverride.Checked = $true
                foreach ($k in $script:StartupModes.Keys) {
                    if ($script:StartupModes[$k].Code -eq $code) {
                        [void](Set-ComboId -Combo $script:CmbStartupMode -Ids $script:StartupModeIds -Id $k); break
                    }
                }
                $listPath = Join-Path $loadPath 'RestoreOnStartupURLs'
                if (Test-Path $listPath) {
                    $props = Get-ItemProperty -Path $listPath
                    $urls = @()
                    foreach ($p in $props.PSObject.Properties) {
                        if ($p.Name -match '^\d+$') { $urls += $p.Value }
                    }
                    if ($urls.Count -gt 0) { $script:TxtStartupUrl.Text = ($urls -join ', ') }
                }
            } catch { $script:ChkStartupOverride.Checked = $false }
        }
    } finally {
        Pop-SuppressSelectionEvents
    }
    $script:ActiveProfile = 'CurrentState'
    Update-OverrideControlStates
    Update-SelectionSummary
    Update-ConfigurationFilter
    Write-Log 'Loaded current system state.'
})
$utilityPanel.Controls.Add($btnLoad)

$btnOpenBrave = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnOpenBrave 'util.openPolicy')
$btnOpenBrave.Size = New-Object System.Drawing.Size(150, 30)
$btnOpenBrave.Location = New-Object System.Drawing.Point(155, 5)
$btnOpenBrave.Add_Click({
    $exe = Test-BraveInstalled
    if ($exe) { Start-Process $exe 'brave://policy' }
    else { [System.Windows.Forms.MessageBox]::Show((T 'msg.braveMissing'), (T 'msg.title.info')) | Out-Null }
})
$utilityPanel.Controls.Add($btnOpenBrave)

$btnClose = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnClose 'util.close')
$btnClose.Size = New-Object System.Drawing.Size(95, 30)
$btnClose.Location = New-Object System.Drawing.Point(315, 5)
$btnClose.Add_Click({ $form.Close() })
$utilityPanel.Controls.Add($btnClose)

$flowLabel = New-Object System.Windows.Forms.Label
[void](Set-Loc $flowLabel 'util.flow')
[void](Set-LocFont $flowLabel -Size 9)
$flowLabel.Location = New-Object System.Drawing.Point(740, 11)
$flowLabel.Size = New-Object System.Drawing.Size(400, 18)
$flowLabel.ForeColor = [System.Drawing.Color]::DimGray
$utilityPanel.Controls.Add($flowLabel)
