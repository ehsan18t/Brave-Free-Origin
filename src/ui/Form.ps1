# ============================================================================
#  Main window.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(1180, 940)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(1080, 860)
$form.Font = Get-BfoUiFont -Size 9

# Tooltip provider is script-scoped so Set-LocTooltip can reach it.
$script:ToolTip = New-Object System.Windows.Forms.ToolTip
$script:ToolTip.AutoPopDelay = 30000
$script:ToolTip.InitialDelay = 300
$script:ToolTip.ReshowDelay  = 300

[void](Set-Loc $form 'app.title' -FormatArgs @($script:AppVersion))
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)

$braveVer = Get-BraveVersion
