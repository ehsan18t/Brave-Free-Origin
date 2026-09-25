# Policy tab: Performance
#
# Startup, homepage and new tab settings are on the Search & Startup page,
# which is the only place that writes them.
@{
    Category = 'performanceStartup'
    Policies = @(
        @{ Name = 'HardwareAccelerationModeEnabled'; Type = 'DWORD'; ApplyValue = 1; BraveDefault = 1; MinChromium = 46; Effect = 'behavior'
           Choices = @(@{ Id = 'enable'; Value = 1 }, @{ Id = 'disable'; Value = 0 }) },
        @{ Name = 'HighEfficiencyModeEnabled';       Type = 'DWORD'; ApplyValue = 1; BraveDefault = 0; MinChromium = 108; Effect = 'performance' },
        @{ Name = 'BatterySaverModeAvailability';    Type = 'DWORD'; ApplyValue = 2; BraveDefault = 1; MinChromium = 108; Effect = 'performance' },
        @{ Name = 'DiskCacheSize';                   Type = 'DWORD'; ApplyValue = 262144000;           MinChromium = 17;  Effect = 'performance' }
    )
}
