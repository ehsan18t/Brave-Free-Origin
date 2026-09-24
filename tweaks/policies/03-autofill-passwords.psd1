# Policy tab: Autofill / Passwords
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'autofillPasswords'
    Policies = @(
        @{ Name = 'PasswordManagerEnabled';       Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'PasswordLeakDetectionEnabled'; Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'AutofillAddressEnabled';       Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'AutofillCreditCardEnabled';    Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'PaymentMethodQueryEnabled';    Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'AutoplayAllowed';              Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $true }
    )
}
