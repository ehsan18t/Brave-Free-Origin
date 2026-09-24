# PSScriptAnalyzer settings for this repository. The VS Code PowerShell
# extension picks this file up automatically from the workspace root, and CI
# runs the analyzer with it, so both report the same thing.
#
# Every default rule applies except the two below. Both are guidelines for
# commands published in a PowerShell module, and this is a GUI app whose
# functions are all internal:
#
#   PSUseShouldProcessForStateChangingFunctions
#       Wants -WhatIf / -Confirm support on every function named Set-, New-,
#       Update-, Remove-, Start- and so on. Nobody calls these functions from a
#       prompt, and the app has its own dry run: the Preview button. Adding
#       ShouldProcess would be dead code, and renaming the functions to dodge
#       the rule would make the code harder to read.
#
#   PSUseSingularNouns
#       Wants Get-DetectedChannel instead of Get-DetectedChannels. For internal
#       functions that return several things, the plural says what comes back.
@{
    ExcludeRules = @(
        'PSUseShouldProcessForStateChangingFunctions'
        'PSUseSingularNouns'
    )
}
