# Policy tab: Telemetry
#
# Data Brave and Chromium send about how the browser is used.
@{
    Category = 'privacyTelemetry'
    Policies = @(
        @{ Name = 'BraveP3AEnabled';                         Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 138; Effect = 'privacy' },
        @{ Name = 'BraveStatsPingEnabled';                   Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 138; Effect = 'privacy' },
        @{ Name = 'BraveWebDiscoveryEnabled';                Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 138; Effect = 'privacy' },
        @{ Name = 'MetricsReportingEnabled';                 Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 8;   Effect = 'privacy' },
        @{ Name = 'UrlKeyedAnonymizedDataCollectionEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 69;  Effect = 'privacy' },
        @{ Name = 'UserFeedbackAllowed';                     Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 77;  Effect = 'privacy' },
        @{ Name = 'WebRtcEventLogCollectionAllowed';         Type = 'DWORD'; ApplyValue = 0; BraveDefault = 0; MinChromium = 70;  Effect = 'privacy' },
        @{ Name = 'ChromeVariations';                        Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 83;  Effect = 'privacy'
           Choices = @(@{ Id = 'criticalOnly'; Value = 1 }, @{ Id = 'none'; Value = 2 }) }
    )
}
