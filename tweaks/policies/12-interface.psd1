# Policy tab: Interface and clutter
@{
    Category = 'uiBloatExtras'
    Policies = @(
        @{ Name = 'PromotionsEnabled';               Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 128; Effect = 'clutter' },
        @{ Name = 'ShowHomeButton';                  Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 8;   Effect = 'clutter' },
        @{ Name = 'BookmarkBarEnabled';              Type = 'DWORD'; ApplyValue = 0;                   MinChromium = 12;  Effect = 'clutter' },
        @{ Name = 'PromptForDownloadLocation';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 64;  Effect = 'behavior' },
        @{ Name = 'NTPCustomBackgroundEnabled';      Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 80;  Effect = 'behavior' },
        @{ Name = 'AccessibilityImageLabelsEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 84;  Effect = 'privacy' },
        @{ Name = 'ImportBookmarks';                 Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 15;  Effect = 'clutter' },
        @{ Name = 'ImportHistory';                   Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 15;  Effect = 'clutter' },
        @{ Name = 'ImportSavedPasswords';            Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 15;  Effect = 'clutter' },
        @{ Name = 'ImportAutofillFormData';          Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 39;  Effect = 'clutter' },
        @{ Name = 'ImportSearchEngine';              Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 15;  Effect = 'clutter' }
    )
}
