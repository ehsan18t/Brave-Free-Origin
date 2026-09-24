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

[void](New-LocControl Label $searchTab 'searchTab.intro' 10 8 1100 36 -FontSize 9 -ForeColor ([System.Drawing.Color]::FromArgb(70, 70, 90)))

# A dropdown whose items are translated labels over stable ids (see Set-ComboLabels).
function New-IdComboBox {
    param($Parent, [int]$X, [int]$Y, [int]$Width, $Ids, $LabelKeys)
    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.Location = New-Object System.Drawing.Point($X, $Y)
    $combo.Size = New-Object System.Drawing.Size($Width, 22)
    $combo.DropDownStyle = 'DropDownList'
    Set-ComboLabels -Combo $combo -Ids $Ids -LabelKeys $LabelKeys
    # Which custom-URL box is usable depends only on the selections.
    $combo.Add_SelectedIndexChanged({ Update-OverrideControlStates })
    $Parent.Controls.Add($combo)
    return $combo
}

# A URL text box; starts disabled until its dropdown selects a mode that uses it.
function New-UrlTextBox {
    param($Parent, [int]$X, [int]$Y, [int]$Width)
    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = New-Object System.Drawing.Point($X, $Y)
    $box.Size = New-Object System.Drawing.Size($Width, 22)
    $box.Font = New-Object System.Drawing.Font('Consolas', 8.5)
    $box.Enabled = $false
    $Parent.Controls.Add($box)
    return $box
}

# --- Section 1: Default search engine ---
$secSearch = New-LocControl GroupBox $searchTab 'searchTab.secSearch' 10 50 1110 110 -FontSize 9 -Semibold
$script:ChkSearchOverride = New-LocControl CheckBox $secSearch 'searchTab.chkSearch' 15 22 530 20 -FontSize 9
[void](New-LocControl Label $secSearch 'searchTab.engineLabel' 35 50 60 18 -FontSize 9)
$script:CmbSearchEngine = New-IdComboBox -Parent $secSearch -X 95 -Y 47 -Width 200 -Ids $script:SearchEngineIds -LabelKeys $script:SearchEngineLabelKeys
[void](New-LocControl Label $secSearch 'searchTab.customLabel' 310 50 115 18 -FontSize 9)
$script:TxtCustomSearchUrl = New-UrlTextBox -Parent $secSearch -X 425 -Y 47 -Width 370
[void](New-LocControl Label $secSearch 'searchTab.searchHelp' 35 78 900 18 -FontSize 8 -ForeColor 'DimGray')

# --- Section 2: New tab page ---
$secNtp = New-LocControl GroupBox $searchTab 'searchTab.secNtp' 10 168 1110 90 -FontSize 9 -Semibold
$script:ChkNtpOverride = New-LocControl CheckBox $secNtp 'searchTab.chkNtp' 15 22 450 20 -FontSize 9
[void](New-LocControl Label $secNtp 'searchTab.ntpOpenLabel' 35 50 50 18 -FontSize 9)
$script:CmbNtpDest = New-IdComboBox -Parent $secNtp -X 85 -Y 47 -Width 310 -Ids $script:DestinationIds -LabelKeys $script:DestinationLabelKeys
[void](New-LocControl Label $secNtp 'searchTab.ntpCustomLabel' 410 50 80 18 -FontSize 9)
$script:TxtNtpCustomUrl = New-UrlTextBox -Parent $secNtp -X 490 -Y 47 -Width 305

# --- Section 3: Startup behavior ---
$secStartup = New-LocControl GroupBox $searchTab 'searchTab.secStartup' 10 266 1110 110 -FontSize 9 -Semibold
$script:ChkStartupOverride = New-LocControl CheckBox $secStartup 'searchTab.chkStartup' 15 22 550 20 -FontSize 9
[void](New-LocControl Label $secStartup 'searchTab.modeLabel' 35 50 50 18 -FontSize 9)
$script:CmbStartupMode = New-IdComboBox -Parent $secStartup -X 85 -Y 47 -Width 310 -Ids $script:StartupModeIds -LabelKeys $script:StartupModeLabelKeys
[void](New-LocControl Label $secStartup 'searchTab.urlLabel' 410 50 60 18 -FontSize 9)
$script:TxtStartupUrl = New-UrlTextBox -Parent $secStartup -X 470 -Y 47 -Width 325
[void](New-LocControl Label $secStartup 'searchTab.startupHelp' 35 78 900 18 -FontSize 8 -ForeColor 'DimGray')

# Conflict note
[void](New-LocControl Label $searchTab 'searchTab.conflictNote' 10 384 1100 36 -FontSize 8 -ForeColor ([System.Drawing.Color]::FromArgb(120, 60, 30)))

# --- Section 4: Extensions (manual installs, no force-push) -----------------
$secExt = New-LocControl GroupBox $searchTab 'ext.section' 10 426 1110 130 -FontSize 9 -Semibold
[void](New-LocControl Label $secExt 'ext.intro' 15 22 1080 36 -FontSize 8.5 -ForeColor ([System.Drawing.Color]::FromArgb(60, 60, 60)))
[void](New-LocControl Label $secExt 'ext.warn' 15 60 1080 32 -FontSize 8 -ForeColor ([System.Drawing.Color]::FromArgb(160, 70, 30)))

# Store pages open in Brave when it is installed, otherwise in the default browser.
[void](New-LocControl Button $secExt 'ext.uboLite' 15 95 220 28 -OnClick {
    $url = 'https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh'
    if (-not (Open-BraveUrl $url)) { Start-Process $url }
    Write-Log 'Opened uBlock Origin Lite install page.'
})
[void](New-LocControl Button $secExt 'ext.shields' 245 95 200 28 -OnClick {
    if (-not (Open-BraveUrl 'brave://settings/shields')) { Write-Log 'Brave not found.' 'WARN' }
})
[void](New-LocControl Button $secExt 'ext.bitwarden' 455 95 240 28 -OnClick {
    $url = 'https://chromewebstore.google.com/detail/bitwarden-password-manage/nngceckbapebfimnlniiiahkandclblb'
    if (-not (Open-BraveUrl $url)) { Start-Process $url }
    Write-Log 'Opened Bitwarden install page.'
})

$tabs.TabPages.Add($searchTab)
