# System tab: Brave update tasks and Windows services.
#
# Ticked tasks are disabled with Disable-ScheduledTask; ticked services are
# stopped and set to Disabled. Unticking re-enables a disabled task and resets
# a disabled service to Manual. Names must match Windows exactly.
@{
    ScheduledTasks = @(
        'BraveSoftwareUpdateTaskMachineCore'
        'BraveSoftwareUpdateTaskMachineUA'
    )
    Services = @(
        'brave'
        'bravem'
        'BraveElevationService'
        'BraveVPNService'
        'BraveVpnWireguardService'
    )
}
