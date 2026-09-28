# Policy tab: Search and language
@{
    Category = 'searchSuggestions'
    Policies = @(
        @{ Name = 'SearchSuggestEnabled';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 8;  Effect = 'privacy'
           Prefs = @(@{ Path = 'search.suggest_enabled' }) },
        @{ Name = 'AlternateErrorPagesEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 8;  Effect = 'privacy'; Lock = $true },
        @{ Name = 'SpellCheckServiceEnabled';   Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 22; Effect = 'privacy'
           Prefs = @(@{ Path = 'spellcheck.use_spelling_service' }) },
        @{ Name = 'SpellcheckEnabled';          Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 65; Effect = 'feature'
           Prefs = @(@{ Path = 'browser.enable_spellchecking' }) },
        @{ Name = 'TranslateEnabled';           Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 12; Effect = 'feature'
           Prefs = @(@{ Path = 'translate.enabled' }) }
    )
}
