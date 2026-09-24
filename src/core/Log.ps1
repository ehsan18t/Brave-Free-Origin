# ============================================================================
#  Log line writer shared by every part of the app.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Log lines are queued, never written to a control: Write-BfoLog also runs on the
# background runspace (src\ui\Jobs.ps1), which must not touch the window. The
# window drains the queue into the Activity panel on a timer, and hands the
# same queue to the background runspace, so lines from both end up in order.
# Lines logged during startup wait in the queue until the window exists.
$script:LogSink = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()

function Write-BfoLog {
    param([string]$Message, [string]$Level = 'INFO')
    $script:LogSink.Enqueue([pscustomobject]@{
        Time    = (Get-Date -Format 'HH:mm:ss')
        Level   = $Level
        Message = $Message
    })
}
