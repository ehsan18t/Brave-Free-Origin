# ============================================================================
#  Search and startup tab.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- Search & Startup tab (v1.6) -------------------------------------------
# Three independent, opt-in sections. Each has its own "Override" checkbox.
# Off by default: Brave's user-chosen search engine and startup behavior stay
# untouched unless the user actively ticks an override.
$searchTab = New-Object System.Windows.Forms.TabPage
$searchTab.Name = 'searchTab'
[void](Set-Loc $searchTab 'tab.searchStartup')
$searchTab.AutoScroll = $true
$searchTab.BackColor = [System.Drawing.Color]::White

$searchIntro = New-Object System.Windows.Forms.Label
[void](Set-Loc $searchIntro 'searchTab.intro')
[void](Set-LocFont $searchIntro -Size 9)
$searchIntro.Location = New-Object System.Drawing.Point(10, 8)
$searchIntro.Size = New-Object System.Drawing.Size(1100, 36)
$searchIntro.ForeColor = [System.Drawing.Color]::FromArgb(70, 70, 90)
$searchTab.Controls.Add($searchIntro)

# --- Section 1: Default search engine ---
$secSearch = New-Object System.Windows.Forms.GroupBox
[void](Set-Loc $secSearch 'searchTab.secSearch')
$secSearch.Location = New-Object System.Drawing.Point(10, 50)
$secSearch.Size = New-Object System.Drawing.Size(1110, 110)
[void](Set-LocFont $secSearch -Size 9 -Semibold)
$searchTab.Controls.Add($secSearch)

$script:ChkSearchOverride = New-Object System.Windows.Forms.CheckBox
[void](Set-Loc $script:ChkSearchOverride 'searchTab.chkSearch')
$script:ChkSearchOverride.Location = New-Object System.Drawing.Point(15, 22)
$script:ChkSearchOverride.Size = New-Object System.Drawing.Size(530, 20)
[void](Set-LocFont $script:ChkSearchOverride -Size 9)
$secSearch.Controls.Add($script:ChkSearchOverride)

$lblEngine = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblEngine 'searchTab.engineLabel')
$lblEngine.Location = New-Object System.Drawing.Point(35, 50)
$lblEngine.Size = New-Object System.Drawing.Size(60, 18)
[void](Set-LocFont $lblEngine -Size 9)
$secSearch.Controls.Add($lblEngine)

$script:CmbSearchEngine = New-Object System.Windows.Forms.ComboBox
$script:CmbSearchEngine.Location = New-Object System.Drawing.Point(95, 47)
$script:CmbSearchEngine.Size = New-Object System.Drawing.Size(200, 22)
$script:CmbSearchEngine.DropDownStyle = 'DropDownList'
Set-ComboLabels -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds -LabelKeys $script:SearchEngineLabelKeys
$script:CmbSearchEngine.SelectedIndex = 0
$secSearch.Controls.Add($script:CmbSearchEngine)

$lblCustomSearch = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblCustomSearch 'searchTab.customLabel')
$lblCustomSearch.Location = New-Object System.Drawing.Point(310, 50)
$lblCustomSearch.Size = New-Object System.Drawing.Size(115, 18)
[void](Set-LocFont $lblCustomSearch -Size 9)
$secSearch.Controls.Add($lblCustomSearch)

$script:TxtCustomSearchUrl = New-Object System.Windows.Forms.TextBox
$script:TxtCustomSearchUrl.Location = New-Object System.Drawing.Point(425, 47)
$script:TxtCustomSearchUrl.Size = New-Object System.Drawing.Size(370, 22)
$script:TxtCustomSearchUrl.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$script:TxtCustomSearchUrl.Enabled = $false
$secSearch.Controls.Add($script:TxtCustomSearchUrl)

$searchHelp = New-Object System.Windows.Forms.Label
[void](Set-Loc $searchHelp 'searchTab.searchHelp')
$searchHelp.Location = New-Object System.Drawing.Point(35, 78)
$searchHelp.Size = New-Object System.Drawing.Size(900, 18)
$searchHelp.ForeColor = [System.Drawing.Color]::DimGray
[void](Set-LocFont $searchHelp -Size 8)
$secSearch.Controls.Add($searchHelp)

$script:CmbSearchEngine.Add_SelectedIndexChanged({
    $isCustom = ((Get-ComboId -Combo $script:CmbSearchEngine -Ids $script:SearchEngineIds) -eq 'custom')
    $script:TxtCustomSearchUrl.Enabled = $isCustom
})

# --- Section 2: New tab page ---
$secNtp = New-Object System.Windows.Forms.GroupBox
[void](Set-Loc $secNtp 'searchTab.secNtp')
$secNtp.Location = New-Object System.Drawing.Point(10, 168)
$secNtp.Size = New-Object System.Drawing.Size(1110, 90)
[void](Set-LocFont $secNtp -Size 9 -Semibold)
$searchTab.Controls.Add($secNtp)

$script:ChkNtpOverride = New-Object System.Windows.Forms.CheckBox
[void](Set-Loc $script:ChkNtpOverride 'searchTab.chkNtp')
$script:ChkNtpOverride.Location = New-Object System.Drawing.Point(15, 22)
$script:ChkNtpOverride.Size = New-Object System.Drawing.Size(450, 20)
[void](Set-LocFont $script:ChkNtpOverride -Size 9)
$secNtp.Controls.Add($script:ChkNtpOverride)

$lblNtpDest = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblNtpDest 'searchTab.ntpOpenLabel')
[void](Set-LocFont $lblNtpDest -Size 9)
$lblNtpDest.Location = New-Object System.Drawing.Point(35, 50)
$lblNtpDest.Size = New-Object System.Drawing.Size(50, 18)
$secNtp.Controls.Add($lblNtpDest)

$script:CmbNtpDest = New-Object System.Windows.Forms.ComboBox
$script:CmbNtpDest.Location = New-Object System.Drawing.Point(85, 47)
$script:CmbNtpDest.Size = New-Object System.Drawing.Size(310, 22)
$script:CmbNtpDest.DropDownStyle = 'DropDownList'
Set-ComboLabels -Combo $script:CmbNtpDest -Ids $script:DestinationIds -LabelKeys $script:DestinationLabelKeys
$script:CmbNtpDest.SelectedIndex = 0
$secNtp.Controls.Add($script:CmbNtpDest)

$lblNtpCustom = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblNtpCustom 'searchTab.ntpCustomLabel')
[void](Set-LocFont $lblNtpCustom -Size 9)
$lblNtpCustom.Location = New-Object System.Drawing.Point(410, 50)
$lblNtpCustom.Size = New-Object System.Drawing.Size(80, 18)
$secNtp.Controls.Add($lblNtpCustom)

$script:TxtNtpCustomUrl = New-Object System.Windows.Forms.TextBox
$script:TxtNtpCustomUrl.Location = New-Object System.Drawing.Point(490, 47)
$script:TxtNtpCustomUrl.Size = New-Object System.Drawing.Size(305, 22)
$script:TxtNtpCustomUrl.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$script:TxtNtpCustomUrl.Enabled = $false
$secNtp.Controls.Add($script:TxtNtpCustomUrl)

$script:CmbNtpDest.Add_SelectedIndexChanged({
    $isCustom = ((Get-ComboId -Combo $script:CmbNtpDest -Ids $script:DestinationIds) -eq 'custom')
    $script:TxtNtpCustomUrl.Enabled = $isCustom
})

# --- Section 3: Startup behavior ---
$secStartup = New-Object System.Windows.Forms.GroupBox
[void](Set-Loc $secStartup 'searchTab.secStartup')
$secStartup.Location = New-Object System.Drawing.Point(10, 266)
$secStartup.Size = New-Object System.Drawing.Size(1110, 110)
[void](Set-LocFont $secStartup -Size 9 -Semibold)
$searchTab.Controls.Add($secStartup)

$script:ChkStartupOverride = New-Object System.Windows.Forms.CheckBox
[void](Set-Loc $script:ChkStartupOverride 'searchTab.chkStartup')
$script:ChkStartupOverride.Location = New-Object System.Drawing.Point(15, 22)
$script:ChkStartupOverride.Size = New-Object System.Drawing.Size(550, 20)
[void](Set-LocFont $script:ChkStartupOverride -Size 9)
$secStartup.Controls.Add($script:ChkStartupOverride)

$lblStartMode = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblStartMode 'searchTab.modeLabel')
[void](Set-LocFont $lblStartMode -Size 9)
$lblStartMode.Location = New-Object System.Drawing.Point(35, 50)
$lblStartMode.Size = New-Object System.Drawing.Size(50, 18)
$secStartup.Controls.Add($lblStartMode)

$script:CmbStartupMode = New-Object System.Windows.Forms.ComboBox
$script:CmbStartupMode.Location = New-Object System.Drawing.Point(85, 47)
$script:CmbStartupMode.Size = New-Object System.Drawing.Size(310, 22)
$script:CmbStartupMode.DropDownStyle = 'DropDownList'
Set-ComboLabels -Combo $script:CmbStartupMode -Ids $script:StartupModeIds -LabelKeys $script:StartupModeLabelKeys
$script:CmbStartupMode.SelectedIndex = 0
$secStartup.Controls.Add($script:CmbStartupMode)

$lblStartUrl = New-Object System.Windows.Forms.Label
[void](Set-Loc $lblStartUrl 'searchTab.urlLabel')
[void](Set-LocFont $lblStartUrl -Size 9)
$lblStartUrl.Location = New-Object System.Drawing.Point(410, 50)
$lblStartUrl.Size = New-Object System.Drawing.Size(60, 18)
$secStartup.Controls.Add($lblStartUrl)

$script:TxtStartupUrl = New-Object System.Windows.Forms.TextBox
$script:TxtStartupUrl.Location = New-Object System.Drawing.Point(470, 47)
$script:TxtStartupUrl.Size = New-Object System.Drawing.Size(325, 22)
$script:TxtStartupUrl.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$script:TxtStartupUrl.Enabled = $false
$secStartup.Controls.Add($script:TxtStartupUrl)

$startupHelp = New-Object System.Windows.Forms.Label
[void](Set-Loc $startupHelp 'searchTab.startupHelp')
$startupHelp.Location = New-Object System.Drawing.Point(35, 78)
$startupHelp.Size = New-Object System.Drawing.Size(900, 18)
$startupHelp.ForeColor = [System.Drawing.Color]::DimGray
[void](Set-LocFont $startupHelp -Size 8)
$secStartup.Controls.Add($startupHelp)

$script:CmbStartupMode.Add_SelectedIndexChanged({
    $mode = $script:StartupModes[(Get-ComboId -Combo $script:CmbStartupMode -Ids $script:StartupModeIds)]
    $script:TxtStartupUrl.Enabled = ($mode -and $mode.UsesURL -and -not $mode.FixedURL)
})

# Conflict note
$conflictNote = New-Object System.Windows.Forms.Label
[void](Set-Loc $conflictNote 'searchTab.conflictNote')
$conflictNote.Location = New-Object System.Drawing.Point(10, 384)
$conflictNote.Size = New-Object System.Drawing.Size(1100, 36)
$conflictNote.ForeColor = [System.Drawing.Color]::FromArgb(120, 60, 30)
[void](Set-LocFont $conflictNote -Size 8)
$searchTab.Controls.Add($conflictNote)

# --- Section 4: Extensions (manual installs, no force-push) -----------------
$secExt = New-Object System.Windows.Forms.GroupBox
[void](Set-Loc $secExt 'ext.section')
$secExt.Location = New-Object System.Drawing.Point(10, 426)
$secExt.Size = New-Object System.Drawing.Size(1110, 130)
[void](Set-LocFont $secExt -Size 9 -Semibold)
$searchTab.Controls.Add($secExt)

$extIntro = New-Object System.Windows.Forms.Label
[void](Set-Loc $extIntro 'ext.intro')
$extIntro.Location = New-Object System.Drawing.Point(15, 22)
$extIntro.Size = New-Object System.Drawing.Size(1080, 36)
[void](Set-LocFont $extIntro -Size 8.5)
$extIntro.ForeColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$secExt.Controls.Add($extIntro)

$extWarn = New-Object System.Windows.Forms.Label
[void](Set-Loc $extWarn 'ext.warn')
$extWarn.Location = New-Object System.Drawing.Point(15, 60)
$extWarn.Size = New-Object System.Drawing.Size(1080, 32)
[void](Set-LocFont $extWarn -Size 8)
$extWarn.ForeColor = [System.Drawing.Color]::FromArgb(160, 70, 30)
$secExt.Controls.Add($extWarn)

$btnUboLite = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnUboLite 'ext.uboLite')
$btnUboLite.Size = New-Object System.Drawing.Size(220, 28)
$btnUboLite.Location = New-Object System.Drawing.Point(15, 95)
$btnUboLite.Add_Click({
    $exe = Test-BraveInstalled
    $url = 'https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh'
    if ($exe) { Start-Process $exe $url } else { Start-Process $url }
    Write-Log 'Opened uBlock Origin Lite install page.'
})
$secExt.Controls.Add($btnUboLite)

$btnShieldsSettings = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnShieldsSettings 'ext.shields')
$btnShieldsSettings.Size = New-Object System.Drawing.Size(200, 28)
$btnShieldsSettings.Location = New-Object System.Drawing.Point(245, 95)
$btnShieldsSettings.Add_Click({
    $exe = Test-BraveInstalled
    if ($exe) { Start-Process $exe 'brave://settings/shields' } else { Write-Log 'Brave not found.' 'WARN' }
})
$secExt.Controls.Add($btnShieldsSettings)

$btnBitwarden = New-Object System.Windows.Forms.Button
[void](Set-Loc $btnBitwarden 'ext.bitwarden')
$btnBitwarden.Size = New-Object System.Drawing.Size(240, 28)
$btnBitwarden.Location = New-Object System.Drawing.Point(455, 95)
$btnBitwarden.Add_Click({
    $exe = Test-BraveInstalled
    $url = 'https://chromewebstore.google.com/detail/bitwarden-password-manage/nngceckbapebfimnlniiiahkandclblb'
    if ($exe) { Start-Process $exe $url } else { Start-Process $url }
    Write-Log 'Opened Bitwarden install page.'
})
$secExt.Controls.Add($btnBitwarden)

$tabs.TabPages.Add($searchTab)
