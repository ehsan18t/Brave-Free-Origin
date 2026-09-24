# ============================================================================
#  In-window dialogs, the report viewer, toasts and file pickers.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Dialogs are drawn inside the window (a card over a dimmed page) instead of
# system message boxes, so they follow the theme. Show-BfoDialog still blocks
# its caller until a button is pressed: it runs a nested dispatcher frame, so
# the window keeps painting and background jobs keep reporting meanwhile.
$script:DialogOpen = $false
$script:DialogFrame = $null
$script:DialogResult = $null

$script:DialogIcons = @{
    Information = @{ Glyph = 0xE946; Brush = 'AccentText' }
    Question    = @{ Glyph = 0xE9CE; Brush = 'AccentText' }
    Warning     = @{ Glyph = 0xE7BA; Brush = 'CautionText' }
    Error       = @{ Glyph = 0xEA39; Brush = 'DangerText' }
    Success     = @{ Glyph = 0xE930; Brush = 'SuccessText' }
}

function Start-BfoFade {
    param($Element, [double]$From, [double]$To, [int]$Milliseconds = 150)
    $animation = [System.Windows.Media.Animation.DoubleAnimation]::new($From, $To, [TimeSpan]::FromMilliseconds($Milliseconds))
    $Element.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animation)
}

function New-BfoEase {
    $ease = [System.Windows.Media.Animation.CubicEase]::new()
    $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
    return $ease
}

# Buttons is a list of hashtables: Id, Text, Style ('Accent', 'Danger' or
# empty), IsDefault (Enter), IsCancel (Esc), and optionally Action - a scriptblock that runs
# without closing the dialog (Copy, Save). Returns the Id of the button that
# closed it. Report shows Message as a read-only, scrollable text block.
# Summary (entries from src\ui\Summary.ps1) adds a plain-language tab in front
# of the report, and opens on it.
function Show-BfoDialog {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet('None', 'Information', 'Question', 'Warning', 'Error', 'Success')][string]$Icon = 'Information',
        [object[]]$Buttons,
        [switch]$Report,
        $Summary
    )
    if ($script:DialogOpen -or -not $script:Window) { return $null }
    $ui = $script:Ui

    $ui.DialogTitle.Text = $Title
    if ($Icon -eq 'None') {
        $ui.DialogIcon.Visibility = $script:Collapsed
    } else {
        $spec = $script:DialogIcons[$Icon]
        $ui.DialogIcon.Text = [string][char]$spec.Glyph
        $ui.DialogIcon.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $spec.Brush)
        $ui.DialogIcon.Visibility = $script:Visible
    }

    $card = $ui.DialogCard
    if ($Report) {
        $ui.DialogReport.Text = $Message
        $ui.DialogReport.ScrollToHome()
        $ui.DialogReport.Visibility = $script:Visible
        $ui.DialogBodyScroll.Visibility = $script:Collapsed
        $card.MaxWidth = 1000
        $card.Width = [Math]::Max(480, [Math]::Min(1000, $script:Window.ActualWidth - 120))
        $card.Height = [Math]::Max(360, $script:Window.ActualHeight * 0.8)
    } else {
        $ui.DialogBody.Text = $Message
        $ui.DialogBodyScroll.ScrollToHome()
        $ui.DialogBodyScroll.Visibility = $script:Visible
        $ui.DialogReport.Visibility = $script:Collapsed
        $card.MaxWidth = 560
        $card.Width = [double]::NaN
        $card.Height = [double]::NaN
    }
    $ui.DialogSummary.ItemsSource = $Summary
    $ui.DialogTabs.Visibility = ConvertTo-Visibility ($null -ne $Summary)
    $ui.DialogTabSummary.IsChecked = $true
    Update-DialogTab

    $ui.DialogButtons.Children.Clear()
    $focus = $null
    $script:DialogCancel = $null
    foreach ($spec in $Buttons) {
        $button = [System.Windows.Controls.Button]::new()
        $button.Content = $spec.Text
        $button.MinWidth = 100
        $button.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
        if ($spec.Style -eq 'Accent') { $button.Style = $script:Window.FindResource('AccentButton') }
        if ($spec.Style -eq 'Danger') { $button.Style = $script:Window.FindResource('DangerButton') }
        $button.IsDefault = [bool]$spec.IsDefault
        # Not Button.IsCancel: the main window is shown with ShowDialog, and in
        # a modal window a cancel button also sets the window's DialogResult,
        # which closes the whole app. Esc is handled in src\ui\Window.ps1.
        if ($spec.IsCancel) { $script:DialogCancel = $spec }
        $button.Tag = $spec
        $button.Add_Click({ Complete-BfoDialog $this.Tag })
        [void]$ui.DialogButtons.Children.Add($button)
        if ($spec.IsDefault -or -not $focus) { $focus = $button }
    }

    $script:DialogResult = $null
    $script:DialogOpen = $true
    $ui.DialogLayer.Visibility = $script:Visible
    Start-BfoFade $ui.DialogScrim 0 1 120
    Start-BfoFade $card 0 1 160
    $zoom = [System.Windows.Media.Animation.DoubleAnimation]::new(0.96, 1, [TimeSpan]::FromMilliseconds(200))
    $zoom.EasingFunction = New-BfoEase
    $card.RenderTransform.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $zoom)
    $card.RenderTransform.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $zoom)
    if ($focus) { [void]$focus.Focus() }

    $script:DialogFrame = [System.Windows.Threading.DispatcherFrame]::new()
    try {
        [System.Windows.Threading.Dispatcher]::PushFrame($script:DialogFrame)
    } finally {
        $script:DialogOpen = $false
        $ui.DialogLayer.Visibility = $script:Collapsed
        $ui.DialogButtons.Children.Clear()
        $ui.DialogReport.Text = ''
        $ui.DialogSummary.ItemsSource = $null
        $ui.DialogTabs.Visibility = $script:Collapsed
    }
    return $script:DialogResult
}

# With a summary, the tabs decide which of it and the report is visible.
function Update-DialogTab {
    $ui = $script:Ui
    if ($null -eq $ui.DialogSummary.ItemsSource) {
        $ui.DialogSummaryScroll.Visibility = $script:Collapsed
        return
    }
    $summary = [bool]$ui.DialogTabSummary.IsChecked
    $ui.DialogSummaryScroll.Visibility = ConvertTo-Visibility $summary
    $ui.DialogReport.Visibility = ConvertTo-Visibility (-not $summary)
    if ($summary) { $ui.DialogSummaryScroll.ScrollToHome() }
}

# Copy and Save export the tab being read.
function Get-DialogExportText {
    if ($null -ne $script:Ui.DialogSummary.ItemsSource -and $script:Ui.DialogTabSummary.IsChecked) {
        return (ConvertTo-SummaryText $script:Ui.DialogSummary.ItemsSource)
    }
    return $script:ReportText
}

function Complete-BfoDialog {
    param($Spec)
    if ($Spec.Action) {
        & $Spec.Action
        return
    }
    $script:DialogResult = $Spec.Id
    if ($script:DialogFrame) { $script:DialogFrame.Continue = $false }
}

# Every message box: text and title are string keys. With -YesNo it returns
# $true when the user answered Yes; otherwise it returns nothing. -Danger
# paints the Yes button red for destructive confirmations.
function Show-BfoMessage {
    param(
        [string]$Key,
        [object[]]$FormatArgs,
        [string]$TitleKey = 'msg.title.app',
        [ValidateSet('None', 'Information', 'Question', 'Warning', 'Error', 'Success')][string]$Icon = 'Information',
        [switch]$YesNo,
        [switch]$Danger
    )
    if ($YesNo) {
        $answer = Show-BfoDialog -Title (T $TitleKey) -Message (T $Key $FormatArgs) -Icon $Icon -Buttons @(
            @{ Id = 'yes'; Text = (T 'dialog.yes'); Style = $(if ($Danger) { 'Danger' } else { 'Accent' }); IsDefault = (-not $Danger) }
            @{ Id = 'no';  Text = (T 'dialog.no');  IsCancel = $true; IsDefault = [bool]$Danger }
        )
        return ($answer -eq 'yes')
    }
    [void](Show-BfoDialog -Title (T $TitleKey) -Message (T $Key $FormatArgs) -Icon $Icon -Buttons @(
        @{ Id = 'ok'; Text = (T 'dialog.ok'); Style = 'Accent'; IsDefault = $true; IsCancel = $true }
    ))
}

function Show-TextReport {
    param(
        [string]$Title,
        [string]$Text,
        [string]$DefaultFileName = 'brave-free-origin-report.txt',
        $Summary
    )
    $script:ReportText = $Text
    $script:ReportFileName = $DefaultFileName
    [void](Show-BfoDialog -Title $Title -Message $Text -Icon None -Report -Summary $Summary -Buttons @(
        @{ Id = 'copy'; Text = (T 'report.copy'); Action = {
            # Clipboard.SetText throws on an empty string, and when another
            # program holds the clipboard.
            try {
                $export = Get-DialogExportText
                if ($export) { [System.Windows.Clipboard]::SetText($export) }
                Write-Log 'Report copied to the clipboard.' 'OK'
            } catch { Write-Log "Copy failed: $_" 'WARN' }
        } }
        @{ Id = 'save'; Text = (T 'report.save'); Action = {
            $file = Show-SaveDialog -FilterKey 'dialog.filter.textReport' -Extension 'txt' -FileName $script:ReportFileName
            if ($file) {
                Set-Content -Path $file -Value (Get-DialogExportText) -Encoding UTF8
                Write-Log "Report saved: $file" 'OK'
            }
        } }
        @{ Id = 'close'; Text = (T 'report.close'); Style = 'Accent'; IsDefault = $true; IsCancel = $true }
    ))
}

# ---- Toasts ------------------------------------------------------------------------
# A short, non-blocking confirmation in the corner. Success and info fade out
# on their own; warnings and errors stay a little longer.
$script:ToastTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:ToastTimer.Add_Tick({
    $script:ToastTimer.Stop()
    Hide-BfoToast
})

function Show-BfoToast {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet('Success', 'Information', 'Warning', 'Error')][string]$Severity = 'Success'
    )
    if (-not $script:Ui) { return }
    $ui = $script:Ui
    $spec = $script:DialogIcons[$Severity]
    $ui.ToastIcon.Text = [string][char]$spec.Glyph
    $ui.ToastIcon.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $spec.Brush)
    $ui.ToastTitle.Text = $Title
    $ui.ToastText.Text = $Message
    $ui.ToastText.Visibility = ConvertTo-Visibility (-not [string]::IsNullOrWhiteSpace($Message))
    $ui.Toast.Visibility = $script:Visible
    Start-BfoFade $ui.Toast 0 1 160
    $slide = [System.Windows.Media.Animation.DoubleAnimation]::new(16, 0, [TimeSpan]::FromMilliseconds(260))
    $slide.EasingFunction = New-BfoEase
    $ui.Toast.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $slide)
    $seconds = switch ($Severity) { 'Error' { 14 } 'Warning' { 10 } default { 6 } }
    $script:ToastTimer.Stop()
    $script:ToastTimer.Interval = [TimeSpan]::FromSeconds($seconds)
    $script:ToastTimer.Start()
}

function Hide-BfoToast {
    $toast = $script:Ui.Toast
    if ($toast.Visibility -ne $script:Visible) { return }
    $fade = [System.Windows.Media.Animation.DoubleAnimation]::new(1, 0, [TimeSpan]::FromMilliseconds(160))
    $fade.Add_Completed({ $script:Ui.Toast.Visibility = $script:Collapsed })
    $toast.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
}

# ---- File pickers ------------------------------------------------------------------
# Only the human-readable half of a filter is translated; the *.ext glob is
# added here, so a translation can never produce a filter Windows rejects.
function Show-SaveDialog {
    param([string]$FilterKey, [string]$Extension, [string]$FileName, [string]$InitialDirectory = (Get-BackupDir -Create))
    $dialog = [Microsoft.Win32.SaveFileDialog]::new()
    $dialog.Filter = '{0} (*.{1})|*.{1}' -f (T $FilterKey), $Extension
    $dialog.FileName = $FileName
    if ($InitialDirectory) { $dialog.InitialDirectory = $InitialDirectory }
    if ($dialog.ShowDialog($script:Window) -eq $true) { return $dialog.FileName }
    return $null
}

function Show-OpenDialog {
    param([string]$FilterKey, [string]$Extension, [string]$InitialDirectory)
    $dialog = [Microsoft.Win32.OpenFileDialog]::new()
    $dialog.Filter = '{0} (*.{1})|*.{1}' -f (T $FilterKey), $Extension
    if ($InitialDirectory -and (Test-Path -LiteralPath $InitialDirectory)) { $dialog.InitialDirectory = $InitialDirectory }
    if ($dialog.ShowDialog($script:Window) -eq $true) { return $dialog.FileName }
    return $null
}

# WPF on .NET Framework has no folder picker; the Windows Forms one is loaded
# only when somebody actually browses.
function Show-FolderDialog {
    param([string]$DescriptionKey, [string]$SelectedPath)
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = T $DescriptionKey
    if ($SelectedPath -and (Test-Path -LiteralPath $SelectedPath)) { $dialog.SelectedPath = $SelectedPath }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.SelectedPath }
    return $null
}
