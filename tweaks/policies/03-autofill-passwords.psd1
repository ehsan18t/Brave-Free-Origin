# Policy tab: Autofill / Passwords
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'autofillPasswords'
    Policies = @(
        @{ Name = 'PasswordManagerEnabled';       Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature'; Impacts = @('noAutofill') },
        @{ Name = 'PasswordLeakDetectionEnabled'; Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy'; Impacts = @('lessProtection') },
        @{ Name = 'AutofillAddressEnabled';       Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature'; Impacts = @('noAutofill') },
        @{ Name = 'AutofillCreditCardEnabled';    Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature'; Impacts = @('noAutofill') },
        @{ Name = 'PaymentMethodQueryEnabled';    Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'AutoplayAllowed';              Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $true; Effect = 'behavior' }
    )
}
