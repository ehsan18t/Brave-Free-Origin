# Policy tab: Passwords, autofill and sync
@{
    Category = 'autofillPasswords'
    Policies = @(
        @{ Name = 'PasswordManagerEnabled';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 8;  Effect = 'feature'; Impacts = @('noAutofill') },
        @{ Name = 'AutofillAddressEnabled';       Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 69; Effect = 'feature'; Impacts = @('noAutofill') },
        @{ Name = 'AutofillCreditCardEnabled';    Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 63; Effect = 'feature'; Impacts = @('noAutofill') },
        @{ Name = 'PasswordLeakDetectionEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 79; Effect = 'privacy'; Impacts = @('lessProtection') },
        @{ Name = 'SyncDisabled';                 Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 8;  Effect = 'feature'; Impacts = @('noSync') },
        @{ Name = 'BrowserSignin';                Type = 'DWORD'; ApplyValue = 0;                   MinChromium = 70; Effect = 'feature'; Impacts = @('noSync') }
    )
}
