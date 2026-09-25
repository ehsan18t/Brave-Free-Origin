# Tags: the plain-language layer on top of every tweak.
#
# Every policy, flag, scheduled task, service and hosts group names one Effect
# (what kind of change it is) and may list Impacts (side effects worth a
# warning). The Apply preview groups its "What will happen" tab by Effect and
# turns each Impact into a warning; setting cards show their Impacts as small
# chips. See tweaks\README.md for how to tag an entry.
#
# Wording lives in the string catalog, like every other visible text:
#   effect.<Id>.title    heading of that group in the preview
#   impact.<Id>.name     short label on the chip
#   impact.<Id>.explain  the warning sentence in the preview
@{
    # The order here is the order of the groups in the preview.
    Effects = @(
        @{ Id = 'feature' }
        @{ Id = 'privacy' }
        @{ Id = 'protection' }
        @{ Id = 'performance' }
        @{ Id = 'clutter' }
        @{ Id = 'behavior' }
        @{ Id = 'updates' }
    )

    Impacts = @(
        @{ Id = 'noUpdates' }
        @{ Id = 'staleFilters' }
        @{ Id = 'noDrm' }
        @{ Id = 'noSync' }
        @{ Id = 'noAutofill' }
        @{ Id = 'lessProtection' }
        @{ Id = 'forgetsLogins' }
        @{ Id = 'wipesData' }
        @{ Id = 'mayBreakSites' }
    )
}
