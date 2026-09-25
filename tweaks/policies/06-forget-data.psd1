# Policy tab: History and site data
#
# What Brave keeps between sessions. Together these are what the Max mode
# uses to forget you when Brave closes.
@{
    Category = 'historyData'
    Policies = @(
        @{ Name = 'SavingBrowserHistoryDisabled';         Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 8;   Effect = 'privacy'; Impacts = @('wipesData') },
        @{ Name = 'DefaultCookiesSetting';                Type = 'DWORD'; ApplyValue = 4; BraveDefault = 1; MinChromium = 10;  Effect = 'privacy'; Impacts = @('forgetsLogins') },
        @{ Name = 'DefaultBraveRemember1PStorageSetting'; Type = 'DWORD'; ApplyValue = 2; BraveDefault = 1; MinChromium = 142; Effect = 'privacy'; Impacts = @('forgetsLogins') },
        @{ Name = 'ClearBrowsingDataOnExitList';          Type = 'LIST';  MinChromium = 89; Effect = 'privacy'; Impacts = @('wipesData', 'forgetsLogins')
           ApplyValue = @('browsing_history', 'download_history', 'cookies_and_other_site_data', 'cached_images_and_files', 'password_signin', 'autofill', 'site_settings', 'hosted_app_data') }
    )
}
