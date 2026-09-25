# Policy tab: Site permissions
#
# What websites may ask for. Brave asks each time (3) by default; ticking a
# row makes Brave refuse without asking (2). Per-site exceptions still work.
@{
    Category = 'sitePermissions'
    Policies = @(
        @{ Name = 'DefaultNotificationsSetting';     Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 10;  Effect = 'clutter' },
        @{ Name = 'DefaultGeolocationSetting';       Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 10;  Effect = 'privacy' },
        @{ Name = 'DefaultSensorsSetting';           Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 88;  Effect = 'privacy' },
        @{ Name = 'DefaultWebUsbGuardSetting';       Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 67;  Effect = 'protection' },
        @{ Name = 'DefaultWebBluetoothGuardSetting'; Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 50;  Effect = 'protection' },
        @{ Name = 'DefaultWebHidGuardSetting';       Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 100; Effect = 'protection' },
        @{ Name = 'DefaultSerialGuardSetting';       Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 86;  Effect = 'protection' },
        @{ Name = 'DefaultLocalFontsSetting';        Type = 'DWORD'; ApplyValue = 2; BraveDefault = 3; MinChromium = 103; Effect = 'privacy' },
        @{ Name = 'PaymentMethodQueryEnabled';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 80;  Effect = 'privacy' },
        @{ Name = 'AutoplayAllowed';                 Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 66;  Effect = 'behavior' }
    )
}
