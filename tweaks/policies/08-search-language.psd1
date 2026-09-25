# Policy tab: Search and language
@{
    Category = 'searchSuggestions'
    Policies = @(
        @{ Name = 'SearchSuggestEnabled';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 8;  Effect = 'privacy' },
        @{ Name = 'AlternateErrorPagesEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 8;  Effect = 'privacy' },
        @{ Name = 'SpellCheckServiceEnabled';   Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 22; Effect = 'privacy' },
        @{ Name = 'SpellcheckEnabled';          Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 65; Effect = 'feature' },
        @{ Name = 'TranslateEnabled';           Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 12; Effect = 'feature' }
    )
}
