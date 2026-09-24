# Policy tab: Web Services / Background
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'webServicesBackground'
    Policies = @(
        @{ Name = 'BackgroundModeEnabled';           Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true; Effect = 'performance' },
        @{ Name = 'NetworkPredictionOptions';        Type = 'DWORD';  ApplyValue = 2;           Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'CloudPrintSubmitEnabled';         Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'BuiltInDnsClientEnabled';         Type = 'DWORD';  ApplyValue = 0;           Recommended = $false; MaxPrivacy = $false; Effect = 'behavior' },
        @{ Name = 'DnsOverHttpsMode';                Type = 'STRING'; ApplyValue = 'automatic'; Recommended = $true;  MaxPrivacy = $true; Effect = 'protection' },
        @{ Name = 'WebRtcEventLogCollectionAllowed'; Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'SyncDisabled';                    Type = 'DWORD';  ApplyValue = 1;           Recommended = $false; MaxPrivacy = $true; Effect = 'feature'; Impacts = @('noSync') },
        @{ Name = 'SigninAllowed';                   Type = 'DWORD';  ApplyValue = 0;           Recommended = $false; MaxPrivacy = $true; Effect = 'feature'; Impacts = @('noSync') },
        @{ Name = 'BrowserSignin';                   Type = 'DWORD';  ApplyValue = 0;           Recommended = $false; MaxPrivacy = $true; Effect = 'feature'; Impacts = @('noSync') },
        @{ Name = 'PromotionalTabsEnabled';          Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true; Effect = 'clutter' },
        @{ Name = 'WelcomePageOnOSUpgradeEnabled';   Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true; Effect = 'clutter' },
        @{ Name = 'ImportAutofillFormData';          Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true; Effect = 'clutter' },
        @{ Name = 'ImportBookmarks';                 Type = 'DWORD';  ApplyValue = 0;           Recommended = $false; MaxPrivacy = $true; Effect = 'clutter' },
        @{ Name = 'ImportHistory';                   Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true; Effect = 'clutter' },
        @{ Name = 'ImportSavedPasswords';            Type = 'DWORD';  ApplyValue = 0;           Recommended = $true;  MaxPrivacy = $true; Effect = 'clutter' },
        @{ Name = 'ImportSearchEngine';              Type = 'DWORD';  ApplyValue = 0;           Recommended = $false; MaxPrivacy = $true; Effect = 'clutter' }
    )
}
