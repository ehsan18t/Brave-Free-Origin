# Policy tab: Passwords, autofill and sync
@{
    Category = 'autofillPasswords'
    Policies = @(
        @{ Name = 'PasswordManagerEnabled';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 8;  Effect = 'feature'; Impacts = @('noAutofill')
           Prefs = @(@{ Path = 'credentials_enable_service' }) },
        @{ Name = 'AutofillAddressEnabled';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 69; Effect = 'feature'; Impacts = @('noAutofill')
           Prefs = @(@{ Path = 'autofill.profile_enabled' }) },
        @{ Name = 'AutofillCreditCardEnabled';    Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 63; Effect = 'feature'; Impacts = @('noAutofill')
           Prefs = @(@{ Path = 'autofill.credit_card_enabled' }) },
        @{ Name = 'PasswordLeakDetectionEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 79; Effect = 'privacy'; Impacts = @('lessProtection'); Lock = $true },
        @{ Name = 'SyncDisabled';                 Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 8;  Effect = 'feature'; Impacts = @('noSync'); Lock = $true },
        @{ Name = 'BrowserSignin';                Type = 'DWORD'; ApplyValue = 0;                   MinChromium = 70; Effect = 'feature'; Impacts = @('noSync')
           Prefs = @(@{ Path = 'signin.allowed_on_next_startup' }) }
    )
}
