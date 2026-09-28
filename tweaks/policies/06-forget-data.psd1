# Policy tab: History and site data
#
# What Brave keeps between sessions. Together these are what the Max mode
# uses to forget you when Brave closes.
@{
    Category = 'historyData'
    Policies = @(
        @{ Name = 'SavingBrowserHistoryDisabled';         Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 8;   Effect = 'privacy'; Impacts = @('wipesData'); Lock = $true },
        @{ Name = 'DefaultCookiesSetting';                Type = 'DWORD'; ApplyValue = 4; BraveDefault = 1; MinChromium = 10;  Effect = 'privacy'; Impacts = @('forgetsLogins'); PrefOnly = $true
           Prefs = @(@{ Path = 'profile.default_content_setting_values.cookies'; Map = 'same' }) },
        @{ Name = 'DefaultBraveRemember1PStorageSetting'; Type = 'DWORD'; ApplyValue = 2; BraveDefault = 1; MinChromium = 142; Effect = 'privacy'; Impacts = @('forgetsLogins'); PrefOnly = $true
           Prefs = @(@{ Path = 'profile.default_content_setting_values.brave_remember_1p_storage'; Map = 'same' }) },
        @{ Name = 'ClearBrowsingDataOnExitList';          Type = 'LIST';  MinChromium = 89; Effect = 'privacy'; Impacts = @('wipesData', 'forgetsLogins')
           ApplyValue = @('browsing_history', 'download_history', 'cookies_and_other_site_data', 'cached_images_and_files', 'password_signin', 'autofill', 'site_settings', 'hosted_app_data'); PrefOnly = $true
           Prefs = @(
               @{ Path = 'browser.clear_data.browsing_history_on_exit'; Item = 'browsing_history' },
               @{ Path = 'browser.clear_data.download_history_on_exit'; Item = 'download_history' },
               @{ Path = 'browser.clear_data.cookies_on_exit'; Item = 'cookies_and_other_site_data' },
               @{ Path = 'browser.clear_data.cache_on_exit'; Item = 'cached_images_and_files' },
               @{ Path = 'browser.clear_data.passwords_on_exit'; Item = 'password_signin' },
               @{ Path = 'browser.clear_data.form_data_on_exit'; Item = 'autofill' },
               @{ Path = 'browser.clear_data.site_settings_on_exit'; Item = 'site_settings' },
               @{ Path = 'browser.clear_data.hosted_apps_data_on_exit'; Item = 'hosted_app_data' }) }
    )
}
