# Policies earlier versions of the app could write, and why they were dropped.
#
# Apply removes any of these it finds under the policy key, so an upgrade does
# not leave dead values behind, and the drift check offers to clean them up.
# Reason picks the explanation shown to the user, the string
# retired.reason.<Reason>:
#   removed     Brave removed the feature
#   builtOut    Brave builds the feature out, so the policy changes nothing
#   expired     Chromium no longer reads the policy
#   renamed     the policy now has another name (Replacement)
#   notAPolicy  Brave has no policy by this name (Replacement when the app
#               meant another one)
@{
    Policies = @(
        @{ Name = 'WebTorrentDisabled';            Reason = 'removed' }
        @{ Name = 'IPFSEnabled';                   Reason = 'removed' }
        @{ Name = 'ReadingListEnabled';            Reason = 'notAPolicy' }
        @{ Name = 'CloudPrintSubmitEnabled';       Reason = 'expired' }
        @{ Name = 'WelcomePageOnOSUpgradeEnabled'; Reason = 'expired' }
        @{ Name = 'ChromeCleanupEnabled';          Reason = 'expired' }
        @{ Name = 'ChromeCleanupReportingEnabled'; Reason = 'expired' }
        @{ Name = 'TabOrganizerSettings';          Reason = 'expired' }
        @{ Name = 'SigninAllowed';                 Reason = 'expired' }
        @{ Name = 'CloudReportingEnabled';         Reason = 'builtOut' }
        @{ Name = 'BrowserLabsEnabled';            Reason = 'builtOut' }
        @{ Name = 'LensDesktopNTPSearchEnabled';   Reason = 'builtOut' }
        @{ Name = 'LensRegionSearchEnabled';       Reason = 'builtOut' }
        @{ Name = 'LensOverlaySettings';           Reason = 'builtOut' }
        @{ Name = 'HelpMeWriteSettings';           Reason = 'builtOut' }
        @{ Name = 'HistorySearchSettings';         Reason = 'builtOut' }
        @{ Name = 'DevToolsGenAiSettings';         Reason = 'builtOut' }
        @{ Name = 'GenAiDefaultSettings';          Reason = 'builtOut' }
        @{ Name = 'CreateThemesSettings';          Reason = 'builtOut' }
        @{ Name = 'LiveCaptionEnabled';            Reason = 'builtOut' }
        @{ Name = 'PromotionalTabsEnabled';        Reason = 'renamed'; Replacement = 'PromotionsEnabled' }
        @{ Name = 'MediaRouterEnabled';            Reason = 'notAPolicy'; Replacement = 'EnableMediaRouter' }
    )
}
