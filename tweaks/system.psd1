# System tab: Brave update tasks and Windows services.
#
# Ticked tasks are disabled; ticked services are stopped and set to Disabled.
# Unticking re-enables a disabled task and resets a disabled service to Manual.
# No mode ticks anything here: the page is for manual use only.
#
# Name is the row id, kept stable for exported configs. Match lists the Windows
# names the row acts on, with * as a wildcard; without Match the row acts on
# Name itself. Brave's updater adds a {GUID} to its task names
# (BraveSoftwareUpdateTaskMachineCore{8371973C-...}), and each channel gives its
# services its own prefix (BraveBetaVpnService), so most rows list patterns.
#
# The Brave Elevation Service is deliberately absent: Chromium uses it to
# decrypt cookies and saved passwords (app-bound encryption), so disabling it
# signs the user out of sites instead of stopping updates.
# Effect and Impacts are tags from tweaks\tags.psd1.
@{
    ScheduledTasks = @(
        @{ Name = 'BraveSoftwareUpdateTaskMachineCore'; Effect = 'updates'; Impacts = @('noUpdates')
           Match = @('BraveSoftwareUpdateTaskMachineCore*', 'BraveSoftwareUpdateTaskUser*Core*') }
        @{ Name = 'BraveSoftwareUpdateTaskMachineUA';   Effect = 'updates'; Impacts = @('noUpdates')
           Match = @('BraveSoftwareUpdateTaskMachineUA*', 'BraveSoftwareUpdateTaskUser*UA*') }
    )
    Services = @(
        @{ Name = 'brave';                    Effect = 'updates'; Impacts = @('noUpdates') }
        @{ Name = 'bravem';                   Effect = 'updates'; Impacts = @('noUpdates') }
        @{ Name = 'BraveVPNService';          Effect = 'feature'
           Match = @('BraveVpnService', 'BraveBetaVpnService', 'BraveNightlyVpnService', 'BraveDevVpnService') }
        @{ Name = 'BraveVpnWireguardService'; Effect = 'feature'
           Match = @('BraveVpnWireguardService', 'BraveBetaVpnWireguardService', 'BraveNightlyVpnWireguardService', 'BraveDevVpnWireguardService') }
    )
}
