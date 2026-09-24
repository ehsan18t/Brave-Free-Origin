# Policy tab: AI / GenAI
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'aiGenAi'
    Policies = @(
        @{ Name = 'GenAiDefaultSettings';  Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'HelpMeWriteSettings';   Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'TabOrganizerSettings';  Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'CreateThemesSettings';  Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'HistorySearchSettings'; Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'DevToolsGenAiSettings'; Type = 'DWORD'; ApplyValue = 2; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' }
    )
}
