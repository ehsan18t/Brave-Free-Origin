# Policy tab: Search / Suggestions
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'searchSuggestions'
    Policies = @(
        @{ Name = 'SearchSuggestEnabled';                    Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'UrlKeyedAnonymizedDataCollectionEnabled'; Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'SpellCheckServiceEnabled';                Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'SpellcheckEnabled';                       Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $false; Effect = 'feature' },
        @{ Name = 'TranslateEnabled';                        Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'AlternateErrorPagesEnabled';              Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' }
    )
}
