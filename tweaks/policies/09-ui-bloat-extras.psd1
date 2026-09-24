# Policy tab: UI Bloat / Extras
#
# One entry per Brave group policy, written under
# HKLM\Software\Policies\BraveSoftware\<channel> when ticked and removed when
# unticked. See tweaks\README.md for the field reference.
@{
    Category = 'uiBloatExtras'
    Policies = @(
        @{ Name = 'LiveCaptionEnabled';              Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'AccessibilityImageLabelsEnabled'; Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'LensDesktopNTPSearchEnabled';     Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'LensRegionSearchEnabled';         Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'LensOverlaySettings';             Type = 'DWORD'; ApplyValue = 1; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'ReadingListEnabled';              Type = 'DWORD'; ApplyValue = 0; Recommended = $true;  MaxPrivacy = $true },
        @{ Name = 'PromptForDownloadLocation';       Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $false },
        @{ Name = 'BookmarkBarEnabled';              Type = 'DWORD'; ApplyValue = 0; Recommended = $false; MaxPrivacy = $false }
    )
}
