# Search & Startup tab: the choices offered by its three dropdowns.
#
# Order here is the order in each dropdown. Visible labels are the strings
# engine.<Id>, destination.<Id> and startupMode.<Id>; brand names in
# ProviderName are never translated. LegacyName is the English label that
# v1.5 to v1.11 exports stored, so importing an old config keeps working.
@{
    # {searchTerms} is the standard Chromium placeholder Brave fills in.
    Engines = @(
        @{
            Id           = 'brave'
            ProviderName = 'Brave Search'
            URL          = 'https://search.brave.com/search?q={searchTerms}'
            Suggest      = 'https://search.brave.com/api/suggest?q={searchTerms}'
            Keyword      = 'brave'
            Home         = 'https://search.brave.com'
            LegacyName   = 'Brave Search'
        },
        @{
            Id           = 'duckduckgo'
            ProviderName = 'DuckDuckGo'
            URL          = 'https://duckduckgo.com/?q={searchTerms}'
            Suggest      = 'https://duckduckgo.com/ac/?q={searchTerms}&type=list'
            Keyword      = 'ddg'
            Home         = 'https://duckduckgo.com'
            LegacyName   = 'DuckDuckGo'
        },
        @{
            Id           = 'startpage'
            ProviderName = 'Startpage'
            URL          = 'https://www.startpage.com/do/search?q={searchTerms}'
            Suggest      = ''
            Keyword      = 'startpage'
            Home         = 'https://www.startpage.com'
            LegacyName   = 'Startpage'
        },
        @{
            Id           = 'qwant'
            ProviderName = 'Qwant'
            URL          = 'https://www.qwant.com/?q={searchTerms}'
            Suggest      = 'https://api.qwant.com/api/suggest?q={searchTerms}'
            Keyword      = 'qwant'
            Home         = 'https://www.qwant.com'
            LegacyName   = 'Qwant'
        },
        @{
            Id           = 'ecosia'
            ProviderName = 'Ecosia'
            URL          = 'https://www.ecosia.org/search?q={searchTerms}'
            Suggest      = 'https://ac.ecosia.org/?q={searchTerms}'
            Keyword      = 'ecosia'
            Home         = 'https://www.ecosia.org'
            LegacyName   = 'Ecosia'
        },
        @{
            Id           = 'mojeek'
            ProviderName = 'Mojeek'
            URL          = 'https://www.mojeek.com/search?q={searchTerms}'
            Suggest      = ''
            Keyword      = 'mojeek'
            Home         = 'https://www.mojeek.com'
            LegacyName   = 'Mojeek'
        },
        @{
            Id           = 'kagi'
            ProviderName = 'Kagi (paid)'
            URL          = 'https://kagi.com/search?q={searchTerms}'
            Suggest      = 'https://kagi.com/api/autosuggest?q={searchTerms}'
            Keyword      = 'kagi'
            Home         = 'https://kagi.com'
            LegacyName   = 'Kagi (paid)'
        },
        @{
            Id           = 'google'
            ProviderName = 'Google'
            URL          = 'https://www.google.com/search?q={searchTerms}'
            Suggest      = 'https://www.google.com/complete/search?output=chrome&q={searchTerms}'
            Keyword      = 'google'
            Home         = 'https://www.google.com'
            LegacyName   = 'Google'
        },
        @{
            Id           = 'bing'
            ProviderName = 'Bing'
            URL          = 'https://www.bing.com/search?q={searchTerms}'
            Suggest      = 'https://www.bing.com/osjson.aspx?query={searchTerms}'
            Keyword      = 'bing'
            Home         = 'https://www.bing.com'
            LegacyName   = 'Bing'
        },
        @{
            Id           = 'yandex'
            ProviderName = 'Yandex'
            URL          = 'https://yandex.com/search/?text={searchTerms}'
            Suggest      = 'https://suggest.yandex.com/suggest-ff.cgi?part={searchTerms}'
            Keyword      = 'yandex'
            Home         = 'https://yandex.com'
            LegacyName   = 'Yandex'
        },
        @{
            Id           = 'custom'
            ProviderName = 'Custom...'
            URL          = ''
            Suggest      = ''
            Keyword      = 'custom'
            Home         = ''
            IsCustom     = $true
            LegacyName   = 'Custom...'
        }
    )

    # Targets for the new tab page and the "specific page" startup mode.
    # Special values resolved at apply time: __SEARCH__ is the chosen engine's
    # Home URL, __CUSTOM__ is the URL typed by the user, and __SKIP__ leaves
    # the setting alone. ntpDefault is matched by Load current state but is
    # never offered in the new tab dropdown.
    Destinations = @(
        @{
            Id         = 'blank'
            Value      = 'about:blank'
            LegacyName = 'Blank page (about:blank)'
        },
        @{
            Id         = 'ntpDefault'
            Value      = '__SKIP__'
            LegacyName = 'Default new tab page (do not override)'
        },
        @{
            Id         = 'matchSearch'
            Value      = '__SEARCH__'
            LegacyName = 'Match the search engine I picked above'
        },
        @{
            Id         = 'braveSearchHome'
            Value      = 'https://search.brave.com'
            LegacyName = 'Brave Search homepage'
        },
        @{
            Id         = 'duckduckgoHome'
            Value      = 'https://duckduckgo.com'
            LegacyName = 'DuckDuckGo homepage'
        },
        @{
            Id         = 'googleHome'
            Value      = 'https://www.google.com'
            LegacyName = 'Google homepage'
        },
        @{
            Id         = 'custom'
            Value      = '__CUSTOM__'
            LegacyName = 'Custom URL...'
        }
    )

    # Startup behavior. Code is the RestoreOnStartup policy value.
    StartupModes = @(
        @{
            Id         = 'newTab'
            Code       = 5
            UsesURL    = $false
            LegacyName = 'Open the new tab page'
        },
        @{
            Id         = 'restoreSession'
            Code       = 1
            UsesURL    = $false
            LegacyName = 'Restore my last session'
        },
        @{
            Id         = 'blankPage'
            Code       = 4
            UsesURL    = $true
            FixedURL   = 'about:blank'
            LegacyName = 'Open a blank page'
        },
        @{
            Id         = 'specificPages'
            Code       = 4
            UsesURL    = $true
            FixedURL   = $null
            LegacyName = 'Open a specific page or set'
        }
    )
}
