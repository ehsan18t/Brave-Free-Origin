# ============================================================================
#  Colors: light and dark palettes, the Windows accent color, the title bar
#  and the window icon.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Every brush the XAML asks for by DynamicResource. The values follow the
# Windows 11 design tokens, flattened to solid colors (no Mica: the window
# paints its own background).
$script:Palettes = @{
    Light = @{
        WindowBg = '#F3F3F3'; LayerBg = '#F9F9F9'; LayerStroke = '#E5E5E5'
        CardBg = '#FFFFFF'; CardBgHover = '#F7F7F7'; CardBgPressed = '#F2F2F2'; CardStroke = '#E5E5E5'
        TextPrimary = '#1A1A1A'; TextSecondary = '#5D5D5D'; TextTertiary = '#8A8A8A'
        ControlBg = '#FDFDFD'; ControlBgHover = '#F6F6F6'; ControlBgPressed = '#F0F0F0'; ControlBgFocused = '#FFFFFF'
        ControlStroke = '#DCDCDC'
        SubtleHover = '#EAEAEA'; SubtlePressed = '#E2E2E2'; SubtleSelected = '#E6E6E6'
        MenuBg = '#FAFAFA'; MenuStroke = '#E0E0E0'; MenuHover = '#EFEFEF'; MenuSelected = '#EAEAEA'; RowSelected = '#EBEBEB'
        SwitchOffBg = '#F7F7F7'; SwitchOffStroke = '#8A8A8A'; SwitchOffKnob = '#5E5E5E'
        Danger = '#C42B1C'; DangerHover = '#B3261A'; DangerPressed = '#A02216'; OnDanger = '#FFFFFF'; DangerText = '#C42B1C'
        SuccessText = '#0F7B0F'; CautionText = '#9D5D00'
        InfoBg = '#F4F4F4'; CautionBg = '#FFF4CE'; CriticalBg = '#FDE7E9'; InfoBarStroke = '#E5E5E5'
        Scrim = '#4D000000'; Divider = '#E5E5E5'; FocusStroke = '#1A1A1A'
        ScrollThumb = '#8A8A8A'; ProgressTrack = '#D9D9D9'
        ChipBg = '#F7F7F7'; ChipStroke = '#E3E3E3'
        RiskLowBg = '#DFF6DD'; RiskLowFg = '#0F7B0F'; RiskMediumBg = '#FFF4CE'; RiskMediumFg = '#8A5300'
        RiskHighBg = '#FDE7E9'; RiskHighFg = '#B3261E'; RiskNeutralBg = '#EFEFEF'; RiskNeutralFg = '#5D5D5D'
    }
    Dark = @{
        WindowBg = '#202020'; LayerBg = '#272727'; LayerStroke = '#1C1C1C'
        CardBg = '#2C2C2C'; CardBgHover = '#323232'; CardBgPressed = '#292929'; CardStroke = '#1F1F1F'
        TextPrimary = '#FFFFFF'; TextSecondary = '#C8C8C8'; TextTertiary = '#9A9A9A'
        ControlBg = '#363636'; ControlBgHover = '#3C3C3C'; ControlBgPressed = '#303030'; ControlBgFocused = '#1F1F1F'
        ControlStroke = '#444444'
        SubtleHover = '#2B2B2B'; SubtlePressed = '#262626'; SubtleSelected = '#2F2F2F'
        MenuBg = '#2C2C2C'; MenuStroke = '#3E3E3E'; MenuHover = '#383838'; MenuSelected = '#353535'; RowSelected = '#383838'
        SwitchOffBg = '#262626'; SwitchOffStroke = '#9A9A9A'; SwitchOffKnob = '#D0D0D0'
        Danger = '#C42B1C'; DangerHover = '#D23A2B'; DangerPressed = '#B3261A'; OnDanger = '#FFFFFF'; DangerText = '#FF99A4'
        SuccessText = '#6CCB5F'; CautionText = '#FCE100'
        InfoBg = '#2B2B2B'; CautionBg = '#433519'; CriticalBg = '#442726'; InfoBarStroke = '#1F1F1F'
        Scrim = '#99000000'; Divider = '#383838'; FocusStroke = '#FFFFFF'
        ScrollThumb = '#9F9F9F'; ProgressTrack = '#4A4A4A'
        ChipBg = '#2F2F2F'; ChipStroke = '#3A3A3A'
        RiskLowBg = '#393D1B'; RiskLowFg = '#8FD483'; RiskMediumBg = '#433519'; RiskMediumFg = '#F5C84C'
        RiskHighBg = '#442726'; RiskHighFg = '#FF99A4'; RiskNeutralBg = '#333333'; RiskNeutralFg = '#C8C8C8'
    }
}

# 'system' follows the Windows app theme; 'light' and 'dark' pin one.
$script:ThemeModes = @('system', 'light', 'dark')
$script:ThemeMode = 'system'
$script:ThemeIsDark = $false
$script:ThemeDictionary = $null
$script:ThemeSignature = ''

function ConvertTo-BfoColor {
    param([string]$Hex)
    return [System.Windows.Media.ColorConverter]::ConvertFromString($Hex)
}

function Test-WindowsDarkMode {
    try {
        $value = Get-ItemPropertyValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction Stop
        return ($value -eq 0)
    } catch { return $false }
}

# AccentColor is stored as 0xAABBGGRR. Windows' own default blue when unset.
function Get-WindowsAccentColor {
    try {
        $value = Get-ItemPropertyValue -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'AccentColor' -ErrorAction Stop
        $bytes = [BitConverter]::GetBytes([int]$value)
        return [System.Windows.Media.Color]::FromRgb($bytes[0], $bytes[1], $bytes[2])
    } catch {
        return [System.Windows.Media.Color]::FromRgb(0x00, 0x78, 0xD4)
    }
}

# ---- Accent shades --------------------------------------------------------------
# Windows derives lighter and darker accent shades for each theme. The same
# idea here: keep the hue and saturation, move the lightness into a band that
# reads well on that theme's background.
function ConvertTo-Hsl {
    param([System.Windows.Media.Color]$Color)
    $r = $Color.R / 255.0; $g = $Color.G / 255.0; $b = $Color.B / 255.0
    $max = [Math]::Max($r, [Math]::Max($g, $b)); $min = [Math]::Min($r, [Math]::Min($g, $b))
    $l = ($max + $min) / 2
    if ($max -eq $min) { return @(0.0, 0.0, $l) }
    $d = $max - $min
    $s = if ($l -gt 0.5) { $d / (2 - $max - $min) } else { $d / ($max + $min) }
    if ($max -eq $r)     { $h = ($g - $b) / $d + $(if ($g -lt $b) { 6 } else { 0 }) }
    elseif ($max -eq $g) { $h = ($b - $r) / $d + 2 }
    else                 { $h = ($r - $g) / $d + 4 }
    return @(($h / 6), $s, $l)
}

function ConvertFrom-Hsl {
    param([double]$H, [double]$S, [double]$L)
    $L = [Math]::Max(0.0, [Math]::Min(1.0, $L))
    if ($S -le 0) {
        $v = [byte][Math]::Round($L * 255)
        return [System.Windows.Media.Color]::FromRgb($v, $v, $v)
    }
    $q = if ($L -lt 0.5) { $L * (1 + $S) } else { $L + $S - $L * $S }
    $p = 2 * $L - $q
    $channels = foreach ($t in @(($H + 1.0 / 3), $H, ($H - 1.0 / 3))) {
        if ($t -lt 0) { $t += 1 }
        if ($t -gt 1) { $t -= 1 }
        if ($t -lt 1.0 / 6)     { $v = $p + ($q - $p) * 6 * $t }
        elseif ($t -lt 0.5)     { $v = $q }
        elseif ($t -lt 2.0 / 3) { $v = $p + ($q - $p) * (2.0 / 3 - $t) * 6 }
        else                    { $v = $p }
        [byte][Math]::Round($v * 255)
    }
    return [System.Windows.Media.Color]::FromRgb($channels[0], $channels[1], $channels[2])
}

function Get-RelativeLuminance {
    param([System.Windows.Media.Color]$Color)
    $sum = 0.0
    foreach ($pair in @(@($Color.R, 0.2126), @($Color.G, 0.7152), @($Color.B, 0.0722))) {
        $c = $pair[0] / 255.0
        $linear = if ($c -le 0.03928) { $c / 12.92 } else { [Math]::Pow(($c + 0.055) / 1.055, 2.4) }
        $sum += $linear * $pair[1]
    }
    return $sum
}

function Get-MixedColor {
    param([System.Windows.Media.Color]$Base, [System.Windows.Media.Color]$Over, [double]$Amount)
    $mix = { param($a, $b) [byte][Math]::Round($a + ($b - $a) * $Amount) }
    return [System.Windows.Media.Color]::FromRgb((& $mix $Base.R $Over.R), (& $mix $Base.G $Over.G), (& $mix $Base.B $Over.B))
}

function Get-AccentShades {
    param([System.Windows.Media.Color]$Accent, [bool]$Dark, [System.Windows.Media.Color]$CardBg)
    $hsl = ConvertTo-Hsl $Accent
    $h = $hsl[0]; $s = $hsl[1]; $l = $hsl[2]
    if ($Dark) {
        $fill    = [Math]::Min(0.78, [Math]::Max(0.62, $l + 0.27))
        $hover   = $fill - 0.05
        $pressed = $fill - 0.10
    } else {
        $fill    = [Math]::Min(0.40, [Math]::Max(0.25, $l * 0.87))
        $hover   = $fill + 0.05
        $pressed = $fill + 0.10
    }
    $fillColor = ConvertFrom-Hsl $h $s $fill
    # Whichever of black and white contrasts more with the fill.
    $luminance = Get-RelativeLuminance $fillColor
    $onAccent = if ((1.05 / ($luminance + 0.05)) -ge (($luminance + 0.05) / 0.05)) { '#FFFFFF' } else { '#000000' }
    return @{
        Accent         = $fillColor
        AccentHover    = (ConvertFrom-Hsl $h $s $hover)
        AccentPressed  = (ConvertFrom-Hsl $h ($s * 0.85) $pressed)
        AccentText     = $fillColor
        OnAccent       = (ConvertTo-BfoColor $onAccent)
        AccentSubtleBg = (Get-MixedColor $CardBg $fillColor $(if ($Dark) { 0.16 } else { 0.08 }))
    }
}

# ---- Applying a theme -----------------------------------------------------------
# All brushes go into one new dictionary that replaces the previous one in a
# single step, so a theme switch re-colors the window in one pass instead of
# one pass per brush.
function Set-BfoTheme {
    param([string]$Mode = $script:ThemeMode, [switch]$Force)
    if ($script:ThemeModes -notcontains $Mode) { $Mode = 'system' }
    $script:ThemeMode = $Mode
    $dark = switch ($Mode) { 'dark' { $true } 'light' { $false } default { Test-WindowsDarkMode } }
    $accent = Get-WindowsAccentColor

    # Cheap to call often (every time the window is activated): nothing is
    # rebuilt unless the theme or the accent actually changed.
    $signature = "$dark|$accent"
    if (-not $Force -and $signature -eq $script:ThemeSignature) { return }
    $script:ThemeSignature = $signature
    $script:ThemeIsDark = $dark

    $palette = $script:Palettes[$(if ($dark) { 'Dark' } else { 'Light' })]
    $colors = @{}
    foreach ($key in $palette.Keys) { $colors[$key] = ConvertTo-BfoColor $palette[$key] }
    $shades = Get-AccentShades -Accent $accent -Dark $dark -CardBg $colors['CardBg']
    foreach ($key in $shades.Keys) { $colors[$key] = $shades[$key] }

    $dictionary = [System.Windows.ResourceDictionary]::new()
    foreach ($key in $colors.Keys) {
        $brush = [System.Windows.Media.SolidColorBrush]::new($colors[$key])
        $brush.Freeze()
        $dictionary[$key] = $brush
    }
    $script:ThemeColors = $colors

    if ($script:Window) {
        $merged = $script:Window.Resources.MergedDictionaries
        if ($script:ThemeDictionary) { [void]$merged.Remove($script:ThemeDictionary) }
        $merged.Add($dictionary)
        Update-BfoTitleBar
        # Before the first paint the icon is drawn later (ContentRendered):
        # it loads the icon font, which is not worth delaying the window for.
        if ($script:Window.IsLoaded) { Update-BfoWindowIcon }
    }
    $script:ThemeDictionary = $dictionary
}

# ---- Native touches: dark title bar, taskbar identity ------------------------------
# A few Win32 calls, compiled once at startup. Everything here is cosmetic, so
# any failure (older Windows, a locked-down machine) just skips it.
$script:NativeReady = $null

function Initialize-BfoNative {
    if ($null -ne $script:NativeReady) { return $script:NativeReady }
    try {
        Add-Type -Namespace BraveFreeOrigin -Name Native -ErrorAction Stop -MemberDefinition @'
[DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
[DllImport("shell32.dll", CharSet = CharSet.Unicode)]
public static extern int SetCurrentProcessExplicitAppUserModelID(string appId);
'@
        # Its own taskbar button and icon, instead of grouping with PowerShell.
        [void][BraveFreeOrigin.Native]::SetCurrentProcessExplicitAppUserModelID('BraveFreeOrigin.App')
        $script:NativeReady = $true
    } catch {
        $script:NativeReady = $false
    }
    return $script:NativeReady
}

function Get-WindowsBuild {
    try { return [int](Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'CurrentBuildNumber' -ErrorAction Stop) }
    catch { return 0 }
}

function Update-BfoTitleBar {
    if (-not $script:Window -or -not $script:NativeReady) { return }
    $hwnd = ([System.Windows.Interop.WindowInteropHelper]::new($script:Window)).Handle
    if ($hwnd -eq [IntPtr]::Zero) { return }
    try {
        # Immersive dark mode is attribute 20, or 19 on builds before 20H1.
        $dark = [int]$script:ThemeIsDark
        if ([BraveFreeOrigin.Native]::DwmSetWindowAttribute($hwnd, 20, [ref]$dark, 4) -ne 0) {
            [void][BraveFreeOrigin.Native]::DwmSetWindowAttribute($hwnd, 19, [ref]$dark, 4)
        }
        # Windows 11: paint the caption in the window color so the title bar
        # and the side navigation read as one surface.
        if ((Get-WindowsBuild) -ge 22000) {
            $bg = $script:ThemeColors['WindowBg']
            $caption = [int]$bg.R -bor ([int]$bg.G -shl 8) -bor ([int]$bg.B -shl 16)
            [void][BraveFreeOrigin.Native]::DwmSetWindowAttribute($hwnd, 35, [ref]$caption, 4)
            $fg = $script:ThemeColors['TextPrimary']
            $text = [int]$fg.R -bor ([int]$fg.G -shl 8) -bor ([int]$fg.B -shl 16)
            [void][BraveFreeOrigin.Native]::DwmSetWindowAttribute($hwnd, 36, [ref]$text, 4)
        }
    } catch { }
}

# The shield from the side bar, drawn in the accent color, so the taskbar and
# Alt+Tab show the app instead of the PowerShell icon.
function Update-BfoWindowIcon {
    if (-not $script:Window) { return }
    try {
        $size = 64
        $visual = [System.Windows.Media.DrawingVisual]::new()
        $dc = $visual.RenderOpen()
        $fill = [System.Windows.Media.SolidColorBrush]::new($script:ThemeColors['Accent'])
        $ink = [System.Windows.Media.SolidColorBrush]::new($script:ThemeColors['OnAccent'])
        $dc.DrawRoundedRectangle($fill, $null, [System.Windows.Rect]::new(0, 0, $size, $size), 14, 14)
        $typeface = [System.Windows.Media.Typeface]::new('Segoe Fluent Icons, Segoe MDL2 Assets')
        $glyph = [System.Windows.Media.FormattedText]::new([string][char]0xEA18, [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Windows.FlowDirection]::LeftToRight, $typeface, 36, $ink)
        $dc.DrawText($glyph, [System.Windows.Point]::new(($size - $glyph.Width) / 2, ($size - $glyph.Height) / 2))
        $dc.Close()
        $bitmap = [System.Windows.Media.Imaging.RenderTargetBitmap]::new($size, $size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($visual)
        $bitmap.Freeze()
        $script:Window.Icon = $bitmap
    } catch { }
}
