# Policy tab: Web Services / Background
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'webServicesBackground'
    Policies = @(
        @{ Name = 'BackgroundModeEnabled';           Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'NetworkPredictionOptions';        Type = 'DWORD';  ApplyValue = 2;           Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'CloudPrintSubmitEnabled';         Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'BuiltInDnsClientEnabled';         Type = 'DWORD';  ApplyValue = 0;           Recommended = $false; MaxPrivacy = $false },
        @{ Name = 'DnsOverHttpsMode';                Type = 'STRING'; ApplyValue = 'automatic'; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'WebRtcEventLogCollectionAllowed'; Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'SyncDisabled';                    Type = 'DWORD';  ApplyValue = 1;           Recommended = $false; MaxPrivacy = $true },
        @{ Name = 'SigninAllowed';                   Type = 'DWORD';  ApplyValue = 0;           Recommended = $false; MaxPrivacy = $true },
        @{ Name = 'BrowserSignin';                   Type = 'DWORD';  ApplyValue = 0;           Recommended = $false; MaxPrivacy = $true },
        @{ Name = 'PromotionalTabsEnabled';          Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'WelcomePageOnOSUpgradeEnabled';   Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'ImportAutofillFormData';          Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'ImportBookmarks';                 Type = 'DWORD';  ApplyValue = 0;           Recommended = $false; MaxPrivacy = $true },
        @{ Name = 'ImportHistory';                   Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'ImportSavedPasswords';            Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'ImportSearchEngine';              Type = 'DWORD';  ApplyValue = 0;           Recommended = $false; MaxPrivacy = $true }
    )
}
