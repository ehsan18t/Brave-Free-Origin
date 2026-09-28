# Policy tab: Interface and clutter
@{
    Category = 'uiBloatExtras'
    Policies = @(
        @{ Name = 'PromotionsEnabled';               Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 128; Effect = 'clutter'; Lock = $true },
        @{ Name = 'ShowHomeButton';                  Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 8;   Effect = 'clutter'
           Prefs = @(@{ Path = 'browser.show_home_button'; Protected = $true }) },
        @{ Name = 'BookmarkBarEnabled';              Type = 'DWORD'; ApplyValue = 0;                   MinChromium = 12;  Effect = 'clutter'
           Prefs = @(@{ Path = 'bookmark_bar.show_on_all_tabs' }) },
        @{ Name = 'PromptForDownloadLocation';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 64;  Effect = 'behavior'
           Prefs = @(@{ Path = 'download.prompt_for_download' }) },
        @{ Name = 'NTPCustomBackgroundEnabled';      Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 80;  Effect = 'behavior'; Lock = $true },
        @{ Name = 'AccessibilityImageLabelsEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 84;  Effect = 'privacy'; Lock = $true },
        @{ Name = 'ImportBookmarks';                 Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 15;  Effect = 'clutter'
           Prefs = @(
               @{ Path = 'import_bookmarks' },
               @{ Path = 'import_dialog_bookmarks' }) },
        @{ Name = 'ImportHistory';                   Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 15;  Effect = 'clutter'
           Prefs = @(
               @{ Path = 'import_history' },
               @{ Path = 'import_dialog_history' }) },
        @{ Name = 'ImportSavedPasswords';            Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 15;  Effect = 'clutter'
           Prefs = @(
               @{ Path = 'import_saved_passwords' },
               @{ Path = 'import_dialog_saved_passwords' }) },
        @{ Name = 'ImportAutofillFormData';          Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 39;  Effect = 'clutter'
           Prefs = @(
               @{ Path = 'import_autofill_form_data' },
               @{ Path = 'import_dialog_autofill_form_data' }) },
        @{ Name = 'ImportSearchEngine';              Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 15;  Effect = 'clutter'
           Prefs = @(
               @{ Path = 'import_search_engine' },
               @{ Path = 'import_dialog_search_engine' }) }
    )
}
