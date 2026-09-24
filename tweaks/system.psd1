# System tab: Brave update tasks and Windows services.
#
# Ticked tasks are disabled with Disable-ScheduledTask; ticked services are
# stopped and set to Disabled. Unticking re-enables a disabled task and resets
# a disabled service to Manual. Names must match Windows exactly. Effect and
# Impacts are tags from tweaks\tags.psd1.
@{
    ScheduledTasks = @(
        @{ Name = 'BraveSoftwareUpdateTaskMachineCore'; Effect = 'updates'; Impacts = @('noUpdates') }
        @{ Name = 'BraveSoftwareUpdateTaskMachineUA';   Effect = 'updates'; Impacts = @('noUpdates') }
    )
    Services = @(
        @{ Name = 'brave';                    Effect = 'updates'; Impacts = @('noUpdates') }
        @{ Name = 'bravem';                   Effect = 'updates'; Impacts = @('noUpdates') }
        @{ Name = 'BraveElevationService';    Effect = 'updates'; Impacts = @('noUpdates') }
        @{ Name = 'BraveVPNService';          Effect = 'feature' }
        @{ Name = 'BraveVpnWireguardService'; Effect = 'feature' }
    )
}
