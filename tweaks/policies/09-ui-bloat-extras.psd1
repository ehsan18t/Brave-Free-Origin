# Policy tab: UI Bloat / Extras
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'uiBloatExtras'
    Policies = @(
        @{ Name = 'LiveCaptionEnabled';              Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'AccessibilityImageLabelsEnabled'; Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'privacy' },
        @{ Name = 'LensDesktopNTPSearchEnabled';     Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'LensRegionSearchEnabled';         Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'LensOverlaySettings';             Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true; Effect = 'feature' },
        @{ Name = 'ReadingListEnabled';              Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true; Effect = 'clutter' },
        @{ Name = 'PromptForDownloadLocation';       Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $false; Effect = 'behavior' },
        @{ Name = 'BookmarkBarEnabled';              Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $false; Effect = 'clutter' }
    )
}
