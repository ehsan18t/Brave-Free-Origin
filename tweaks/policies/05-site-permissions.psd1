# Policy tab: Site permissions
#
# What websites may ask for. Brave asks each time (3) by default; ticking a
# row makes Brave refuse without asking (2). Per-site exceptions still work.
@{
    Category = 'sitePermissions'
    Policies = @(
        @{ Name = 'DefaultNotificationsSetting';     Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 10;  Effect = 'clutter'; PrefOnly = $true
           Prefs = @(@{ Path = 'profile.default_content_setting_values.notifications'; Map = 'same' }) },
        @{ Name = 'DefaultGeolocationSetting';       Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 10;  Effect = 'privacy'; PrefOnly = $true
           Prefs = @(@{ Path = 'profile.default_content_setting_values.geolocation'; Map = 'same' }) },
        @{ Name = 'DefaultSensorsSetting';           Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 88;  Effect = 'privacy'; PrefOnly = $true
           Prefs = @(@{ Path = 'profile.default_content_setting_values.sensors'; Map = 'same' }) },
        @{ Name = 'DefaultWebUsbGuardSetting';       Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 67;  Effect = 'protection'; PrefOnly = $true
           Prefs = @(@{ Path = 'profile.default_content_setting_values.usb_guard'; Map = 'same' }) },
        @{ Name = 'DefaultWebBluetoothGuardSetting'; Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 50;  Effect = 'protection'; PrefOnly = $true
           Prefs = @(@{ Path = 'profile.default_content_setting_values.bluetooth_guard'; Map = 'same' }) },
        @{ Name = 'DefaultWebHidGuardSetting';       Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 100; Effect = 'protection'; PrefOnly = $true
           Prefs = @(@{ Path = 'profile.default_content_setting_values.hid_guard'; Map = 'same' }) },
        @{ Name = 'DefaultSerialGuardSetting';       Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 86;  Effect = 'protection'; PrefOnly = $true
           Prefs = @(@{ Path = 'profile.default_content_setting_values.serial_guard'; Map = 'same' }) },
        @{ Name = 'DefaultLocalFontsSetting';        Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 103; Effect = 'privacy'; PrefOnly = $true
           Prefs = @(@{ Path = 'profile.default_content_setting_values.local_fonts'; Map = 'same' }) },
        @{ Name = 'PaymentMethodQueryEnabled';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 80;  Effect = 'privacy'
           Prefs = @(@{ Path = 'payments.can_make_payment_enabled' }) },
        @{ Name = 'AutoplayAllowed';                 Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 66;  Effect = 'behavior'; Lock = $true }
    )
}
