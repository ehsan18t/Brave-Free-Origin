# ============================================================================
#  The window: loading the XAML, strings, navigation, search, language and
#  theme switching, the Activity panel and keyboard shortcuts.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# ---- Load ----------------------------------------------------------------------
$script:XamlDir = Join-Path $script:AppRoot 'src\ui\xaml'
$windowXaml = [System.IO.File]::ReadAllText((Join-Path $script:XamlDir 'Window.xaml'))
$windowXaml = $windowXaml.Replace('__THEME_URI__', ([Uri](Join-Path $script:XamlDir 'Theme.xaml')).AbsoluteUri)
$script:Window = [System.Windows.Markup.XamlReader]::Parse($windowXaml)

# Every named element, by name. Names inside templates are not reachable this
# way and are skipped.
$script:Ui = @{}
foreach ($match in [regex]::Matches($windowXaml, 'x:Name="([^"]+)"')) {
    $element = $script:Window.FindName($match.Groups[1].Value)
    if ($element) { $script:Ui[$match.Groups[1].Value] = $element }
}
$ui = $script:Ui

# ---- Strings ------------------------------------------------------------------
# Static text in the XAML is {DynamicResource <key>}. Every string goes into
# one dictionary that replaces the previous one in a single step, so a
# language switch re-texts the whole window in one pass.
$script:StringDictionary = $null
function Publish-BfoStrings {
    $dictionary = [System.Windows.ResourceDictionary]::new()
    foreach ($key in $script:EnglishStrings.Keys) {
        $text = [string](T $key)
        # A bare resource is never formatted, so resolve {{ }} escapes here.
        if ($text -notmatch '\{\d+\}' -and ($text.Contains('{{') -or $text.Contains('}}'))) {
            try { $text = [string]($text -f @()) } catch { }
        }
        $dictionary[$key] = $text
    }
    $merged = $script:Window.Resources.MergedDictionaries
    if ($script:StringDictionary) { [void]$merged.Remove($script:StringDictionary) }
    $merged.Add($dictionary)
    $script:StringDictionary = $dictionary
    $script:Window.Title = [string](T 'app.title' @($script:AppVersion))
}

Publish-BfoStrings
Set-BfoTheme -Force
$script:Window.DataContext = $script:Vm
$ui.NavList.ItemsSource = $script:NavItems
$ui.LogList.ItemsSource = $script:LogItems
$ui.HostsItems.ItemsSource = $script:PageRows['hosts']

# ---- Pages ---------------------------------------------------------------------
$script:Pages = @($ui.PageHome, $ui.PageList, $ui.PageHosts, $ui.PageSearch, $ui.PageScriptlets, $ui.PageSettings)
foreach ($page in $script:Pages) { $page.RenderTransform = [System.Windows.Media.TranslateTransform]::new() }
$script:CurrentPage = $null
$script:LastPage = 'home'
$script:NavSyncing = $false
$script:ResultRows = New-BfoList

function Get-PagePanel {
    param([string]$Id)
    switch -Wildcard ($Id) {
        'home'       { return $script:Ui.PageHome }
        'hosts'      { return $script:Ui.PageHosts }
        'search'     { return $script:Ui.PageSearch }
        'scriptlets' { return $script:Ui.PageScriptlets }
        'settings'   { return $script:Ui.PageSettings }
        default      { return $script:Ui.PageList }
    }
}

function Update-ListSubtitle {
    $vm = $script:Vm
    $page = $script:CurrentPage
    if ($page -eq 'results') { return }
    $on = 0; $all = 0
    foreach ($row in $script:PageRows[$page]) {
        if ($row.Kind -eq 'Header') { continue }
        $all++
        if ($row.Checked) { $on++ }
    }
    $vm.ListSubtitle = [string](T 'list.selectedCount' @($on, $all))
}

# The list page shows a policy category, the System page or search results.
function Set-ListPage {
    param([string]$Id)
    $vm = $script:Vm
    $vm.ListIntroVisibility = $script:Collapsed
    $vm.SelectedOnlyVisibility = $script:Collapsed
    $vm.SelectButtonsVisibility = $script:Collapsed
    $vm.ListEmptyVisibility = $script:Collapsed
    if ($Id -eq 'results') {
        $query = $script:Ui.NavSearch.Text.Trim()
        $count = 0
        foreach ($row in $script:ResultRows) { if ($row.Kind -ne 'Header') { $count++ } }
        $vm.ListTitle = if ($query) { [string](T 'search.title' @($query)) } else { [string](T 'search.selectedTitle') }
        $vm.ListSubtitle = [string](T 'search.count' @($count))
        $vm.SelectedOnlyVisibility = $script:Visible
        $vm.ListEmptyVisibility = ConvertTo-Visibility ($count -eq 0)
        $script:Ui.ListItems.ItemsSource = $script:ResultRows
        return
    }
    if ($Id -eq 'system') {
        $vm.ListTitle = [string](T 'tab.system')
        $vm.ListIntro = [string](T 'system.intro')
        $vm.ListIntroVisibility = $script:Visible
    } else {
        $vm.ListTitle = [string](T ('category.' + $Id.Substring(4)))
        $vm.SelectButtonsVisibility = $script:Visible
    }
    $script:Ui.ListItems.ItemsSource = $script:PageRows[$Id]
    $script:CurrentPage = $Id
    Update-ListSubtitle
}

function Show-BfoPage {
    param([string]$Id, [switch]$NoAnimation)
    $panel = Get-PagePanel $Id
    $changed = ($Id -ne $script:CurrentPage)
    if ($Id -ne 'results') { $script:LastPage = $Id }
    if ($panel -eq $script:Ui.PageList) { Set-ListPage $Id }
    $script:CurrentPage = $Id
    foreach ($page in $script:Pages) { $page.Visibility = ConvertTo-Visibility ($page -eq $panel) }

    if ($changed) {
        if ($panel -is [System.Windows.Controls.ScrollViewer]) { $panel.ScrollToHome() }
        if (-not $NoAnimation) {
            # The page fades in and settles upward, like a Windows 11 page load.
            Start-BfoFade $panel 0 1 170
            $rise = [System.Windows.Media.Animation.DoubleAnimation]::new(18, 0, [TimeSpan]::FromMilliseconds(260))
            $rise.EasingFunction = New-BfoEase
            $panel.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $rise)
        }
    }

    # Keep the side navigation pointing at the page, without re-navigating.
    $script:NavSyncing = $true
    try {
        $target = $null
        foreach ($item in $script:NavItems) { if ($item.Kind -eq 'Item' -and $item.Id -eq $Id) { $target = $item; break } }
        $script:Ui.NavList.SelectedItem = $target
    } finally { $script:NavSyncing = $false }
}

$ui.NavList.Add_SelectionChanged({
    if ($script:NavSyncing) { return }
    $item = $script:Ui.NavList.SelectedItem
    if (-not $item -or $item.Kind -ne 'Item') { return }
    # Picking a page leaves search.
    if ($script:Ui.NavSearch.Text) {
        $script:SearchQuiet = $true
        $script:Ui.NavSearch.Text = ''
        $script:SearchQuiet = $false
    }
    $script:Vm.SelectedOnly = $false
    Show-BfoPage $item.Id
})

# ---- Search ---------------------------------------------------------------------
# Every row of every page at once: each term must appear in the name, the
# description, the category or the domains. Results are the same row objects,
# so ticking one here ticks it on its own page too.
$script:SearchQuiet = $false
$script:SearchTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:SearchTimer.Interval = [TimeSpan]::FromMilliseconds(160)
$script:SearchTimer.Add_Tick({
    $script:SearchTimer.Stop()
    Update-SearchResults
})

function Update-SearchResults {
    $query = $script:Ui.NavSearch.Text.Trim()
    $selectedOnly = [bool]$script:Vm.SelectedOnly
    if (-not $query -and -not $selectedOnly) {
        if ($script:CurrentPage -eq 'results') { Show-BfoPage $script:LastPage }
        return
    }
    $terms = @($query.ToLowerInvariant() -split '\s+' | Where-Object { $_ })
    $results = New-BfoList
    foreach ($item in $script:NavItems) {
        if ($item.Kind -ne 'Item' -or -not $script:PageRows.ContainsKey($item.Id)) { continue }
        $header = $null
        foreach ($row in $script:PageRows[$item.Id]) {
            if ($row.Kind -eq 'Header') { continue }
            if ($selectedOnly -and -not $row.Checked) { continue }
            $hit = $true
            foreach ($term in $terms) { if (-not $row.Search.Contains($term)) { $hit = $false; break } }
            if (-not $hit) { continue }
            if (-not $header) {
                $header = New-HeaderRow -Title $item.Label
                $results.Add($header)
            }
            $results.Add($row)
        }
    }
    $script:ResultRows = $results
    Show-BfoPage 'results' -NoAnimation:($script:CurrentPage -eq 'results')
}

$ui.NavSearch.Add_TextChanged({
    if ($script:SearchQuiet) { return }
    $script:SearchTimer.Stop()
    $script:SearchTimer.Start()
})
$ui.ChkSelectedOnly.Add_Click({ Update-SearchResults })

# ---- Row changes ------------------------------------------------------------------
# A click on a setting card flips its switch through the binding; this only
# has to react. Click is raised for user input only, never for code that sets
# Checked, so presets and state loads do not come through here.
$script:OnRowClick = [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    $row = $e.OriginalSource.DataContext
    if ($e.OriginalSource -isnot [System.Windows.Controls.CheckBox] -or $row -isnot [System.Dynamic.ExpandoObject]) { return }
    if ($row.Kind -ne 'Hosts') { Set-CustomMode }
    Update-SelectionSummary
}

# A value picker on a policy row. None of these count as a user pick: the
# first selection when a row is drawn (nothing removed), a picker being thrown
# away when the page swaps its rows (nothing added, row already detached), and
# code-driven changes, which run muted.
$script:OnRowChoice = [System.Windows.Controls.SelectionChangedEventHandler]{
    param($sender, $e)
    if ($e.OriginalSource -isnot [System.Windows.Controls.ComboBox]) { return }
    $e.Handled = $true
    if ($script:SuppressSelectionEvents -or $e.RemovedItems.Count -eq 0 -or $e.AddedItems.Count -eq 0) { return }
    if ($e.OriginalSource.DataContext -isnot [System.Dynamic.ExpandoObject]) { return }
    Set-CustomMode
    Update-SelectionSummary
}

foreach ($list in @($ui.ListItems, $ui.HostsItems)) {
    $list.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, $script:OnRowClick)
    $list.AddHandler([System.Windows.Controls.Primitives.Selector]::SelectionChangedEvent, $script:OnRowChoice)
}

function Set-PageRowsChecked {
    param([bool]$Checked)
    foreach ($row in $script:PageRows[$script:CurrentPage]) {
        if ($row.Kind -ne 'Header') { $row.Checked = $Checked }
    }
    Set-CustomMode
    Update-SelectionSummary
}
$ui.BtnSelectAll.Add_Click({ Set-PageRowsChecked $true })
$ui.BtnSelectNone.Add_Click({ Set-PageRowsChecked $false })

# ---- Home ------------------------------------------------------------------------
$ui.PresetCards.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    $card = $e.OriginalSource.DataContext
    if (-not $card -or -not $card.Id) { return }
    Invoke-BfoPreset $card.Id
})

# As many columns as fit at 210 px or more each.
$ui.PresetCards.Add_SizeChanged({
    param($sender, $e)
    $columns = [Math]::Max(2, [Math]::Min(4, [int][Math]::Floor($e.NewSize.Width / 210)))
    if ($script:Vm.PresetColumns -ne $columns) { $script:Vm.PresetColumns = $columns }
})

$ui.BtnReviewSelected.Add_Click({
    $script:SearchQuiet = $true
    $script:Ui.NavSearch.Text = ''
    $script:SearchQuiet = $false
    $script:Vm.SelectedOnly = $true
    Update-SearchResults
})

# ---- Language and theme -----------------------------------------------------------
# A language switch is a pure re-text: it must not move one switch, one picker
# or the active mode.
function Switch-BfoLanguage {
    param([string]$Code)
    if ($Code -eq $script:CurrentLocale) { return }
    if (-not (Set-BfoLocale -Code $Code)) {
        # The file could not be loaded (Set-BfoLocale logged why): point the
        # picker back at the language still in use.
        $script:Vm.LanguageIndex = Get-ChoiceIndex $script:Vm.LanguageItems $script:CurrentLocale
        return
    }
    Publish-BfoStrings
    Update-ModelText
    Update-SelectionSummary
    if ($script:CurrentPage) { Show-BfoPage $script:CurrentPage -NoAnimation }
    Update-ScriptletStatusText
    Save-BfoSetting 'language' $Code
    $name = ($script:LocaleList | Where-Object { $_.Code -eq $Code } | Select-Object -First 1).Name
    Write-Log (T 'msg.language.switched' @($name)) 'OK'
}

function Save-BfoSetting {
    param([string]$Name, $Value)
    $settings = Get-BfoSettings -Path $BfoSettingsPath
    $settings[$Name] = $Value
    Save-BfoSettings -Path $BfoSettingsPath -Settings $settings
}

$ui.CmbLanguage.Add_SelectionChanged({
    param($sender, $e)
    if ($e.RemovedItems.Count -eq 0) { return }
    $id = Get-ChoiceId $script:Vm.LanguageItems $script:Vm.LanguageIndex
    if ($id) { Switch-BfoLanguage $id }
})

$ui.CmbTheme.Add_SelectionChanged({
    param($sender, $e)
    if ($e.RemovedItems.Count -eq 0) { return }
    $mode = Get-ChoiceId $script:Vm.ThemeItems $script:Vm.ThemeIndex
    if (-not $mode) { return }
    Set-BfoTheme -Mode $mode
    Save-BfoSetting 'theme' $mode
})

# Windows switched between light and dark while the app was in the background.
$script:Window.Add_Activated({ Set-BfoTheme })
$script:Window.Add_SourceInitialized({ Update-BfoTitleBar })
$script:Window.Add_ContentRendered({ Update-BfoWindowIcon })

# ---- Target channel -----------------------------------------------------------------
foreach ($combo in @($ui.BarChannel, $ui.CmbChannel)) {
    $combo.Add_SelectionChanged({
        param($sender, $e)
        if ($e.RemovedItems.Count -eq 0) { return }
        if (Set-TargetFromChannelIndex) { Write-Log "Target channel(s): $($script:TargetChannels -join ', ')" }
    })
}

# ---- Activity panel ----------------------------------------------------------------
$script:ActivityOpen = $false
function Set-ActivityPanel {
    param([bool]$Open)
    $script:ActivityOpen = $Open
    $height = [System.Windows.Media.Animation.DoubleAnimation]::new($(if ($Open) { 220 } else { 0 }), [TimeSpan]::FromMilliseconds(200))
    $height.EasingFunction = New-BfoEase
    $script:Ui.ActivityPanel.BeginAnimation([System.Windows.FrameworkElement]::HeightProperty, $height)
    if ($Open) {
        $script:UnseenAlerts = 0
        Update-AlertBadge
        if ($script:LogItems.Count -gt 0) { $script:Ui.LogList.ScrollIntoView($script:LogItems[$script:LogItems.Count - 1]) }
    }
}
$ui.BtnActivity.Add_Click({ Set-ActivityPanel (-not $script:ActivityOpen) })
$ui.BtnLogClose.Add_Click({ Set-ActivityPanel $false })
$ui.BtnLogClear.Add_Click({ $script:LogItems.Clear() })
$ui.BtnLogCopy.Add_Click({
    $text = ($script:LogItems | ForEach-Object { "[$($_.Time)] [$($_.Level)] $($_.Message)" }) -join "`r`n"
    try { if ($text) { [System.Windows.Clipboard]::SetText($text) } } catch { }
})
$ui.ToastClose.Add_Click({
    $script:ToastTimer.Stop()
    Hide-BfoToast
})

# ---- Keyboard -------------------------------------------------------------------------
# Ctrl+F finds a setting, Esc leaves search, F5 reloads the state of this PC.
# While a dialog is open, Esc presses its cancel button and nothing else runs.
$script:Window.Add_PreviewKeyDown({
    param($sender, $e)
    if ($script:DialogOpen) {
        if ($e.Key -eq [System.Windows.Input.Key]::Escape -and $script:DialogCancel) {
            $e.Handled = $true
            Complete-BfoDialog $script:DialogCancel
        }
        return
    }
    $ctrl = ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -ne 0
    if ($ctrl -and $e.Key -eq [System.Windows.Input.Key]::F) {
        [void]$script:Ui.NavSearch.Focus()
        $script:Ui.NavSearch.SelectAll()
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::Escape -and $script:Ui.NavSearch.Text) {
        $script:Ui.NavSearch.Text = ''
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::F5 -and $script:Vm.IsIdle) {
        Invoke-BfoLoadState
        $e.Handled = $true
    }
})

# Closing mid-apply would leave half a loadout written: ask the first time.
$script:Window.Add_Closing({
    param($sender, $e)
    if ((Test-BfoBusy) -and -not $script:CloseRequested) {
        $script:CloseRequested = $true
        $e.Cancel = $true
        Show-BfoToast -Severity Warning -Title (T 'toast.busyTitle') -Message (T 'toast.busyClose')
    }
})

# A handler that throws must not take the whole window down with it.
$script:Window.Dispatcher.Add_UnhandledException({
    param($sender, $e)
    $inner = $e.Exception
    while ($inner.InnerException) { $inner = $inner.InnerException }
    Write-Log "UI error: $($inner.Message)" 'ERR'
    $e.Handled = $true
})
