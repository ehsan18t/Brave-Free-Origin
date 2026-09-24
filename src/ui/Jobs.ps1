# ============================================================================
#  Background work: one worker runspace, a queue of jobs, and the timer that
#  finishes them and drains the log into the Activity panel.
#  Dot-sourced by Brave-Free-Origin.ps1; see the load order there.
# ============================================================================

# Anything that can take more than a moment (reading tasks and services,
# applying, the scriptlet scan, file edits) runs on a second runspace, so the
# window keeps painting and responding meanwhile. The worker dot-sources the
# same core\ and strings\ files as the window, but never touches a control: a
# job gets plain data in ($In) and returns plain data, which its OnSuccess
# handler applies on the UI thread. Jobs run one at a time, in order.
#
# Shared with the worker: the log queue (core\Log.ps1) and JobProgress, a
# synchronized hashtable a long job writes its progress into.
$script:JobProgress = [hashtable]::Synchronized(@{})
$script:JobQueue = [System.Collections.Generic.Queue[object]]::new()
$script:CurrentJob = $null
$script:Worker = $null
$script:LogItems = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$script:LogLimit = 2000
$script:UnseenAlerts = 0

$script:WorkerBootstrap = @'
$script:AppRoot = $BfoAppRoot
$script:StartupError = $null
foreach ($bfoFile in $BfoFiles) { . (Join-Path $BfoAppRoot "src\$bfoFile") }
$script:LogSink = $BfoLogSink
$script:JobProgress = $BfoProgress
'@

function Start-BfoWorker {
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $runspace.Open()
    $proxy = $runspace.SessionStateProxy
    $proxy.SetVariable('BfoAppRoot', $script:AppRoot)
    $proxy.SetVariable('BfoFiles', [string[]]@($script:SourceFiles | Where-Object { $_ -like 'core\*' -or $_ -like 'strings\*' }))
    $proxy.SetVariable('BfoLogSink', $script:LogSink)
    $proxy.SetVariable('BfoProgress', $script:JobProgress)
    $script:Worker = $runspace
    Start-BfoJob -Name 'Start' -BusyKey 'busy.starting' -Code $script:WorkerBootstrap
}

# Script is a scriptblock whose text runs on the worker, with Argument bound
# to its $In parameter. It does not close over anything from the window: pass
# what it needs in Argument. Code is the same as raw text. Tag is anything the
# handlers need back: OnSuccess gets the result and the job, OnError the
# message and the job, so two queued jobs never share state through a script
# variable.
function Start-BfoJob {
    param(
        [string]$Name,
        [scriptblock]$Script,
        [string]$Code,
        $Argument,
        $Tag,
        [string]$BusyKey = 'busy.working',
        [scriptblock]$OnSuccess,
        [scriptblock]$OnError,
        [scriptblock]$OnProgress
    )
    if (-not $Code) { $Code = $Script.ToString() }
    $script:JobQueue.Enqueue([pscustomobject]@{
        Name = $Name; Code = $Code; Argument = $Argument; Tag = $Tag; BusyKey = $BusyKey
        OnSuccess = $OnSuccess; OnError = $OnError; OnProgress = $OnProgress
        PowerShell = $null; Handle = $null
    })
    Step-BfoJobs
}

function Test-BfoBusy { return [bool]($script:CurrentJob -or $script:JobQueue.Count -gt 0) }

function Update-BusyState {
    $vm = $script:Vm
    $busy = Test-BfoBusy
    $vm.IsBusy = $busy
    $vm.IsIdle = -not $busy
    $vm.BusyVisibility = ConvertTo-Visibility $busy
    $job = if ($script:CurrentJob) { $script:CurrentJob } elseif ($script:JobQueue.Count -gt 0) { $script:JobQueue.Peek() } else { $null }
    $vm.BusyText = if ($job) { [string](T $job.BusyKey) } else { '' }
    Update-BarText
}

# Timer tick: finish the running job if it is done, start the next one, and
# move new log lines into the Activity panel.
function Step-BfoJobs {
    Receive-BfoLog
    $job = $script:CurrentJob
    if ($job) {
        if ($job.OnProgress) { try { & $job.OnProgress $script:JobProgress } catch { } }
        if (-not $job.Handle.IsCompleted) { return }
        # A job's result may open a dialog; never stack one on top of another.
        if ($script:DialogOpen) { return }
        $script:CurrentJob = $null
        $result = $null
        $failure = $null
        try {
            $output = $job.PowerShell.EndInvoke($job.Handle)
            foreach ($problem in $job.PowerShell.Streams.Error) { Write-Log "$($job.Name): $problem" 'WARN' }
            if ($output -and $output.Count -gt 0) { $result = $output[$output.Count - 1] }
        } catch {
            $inner = $_.Exception
            while ($inner.InnerException) { $inner = $inner.InnerException }
            $failure = $inner.Message
        } finally {
            $job.PowerShell.Dispose()
        }
        Receive-BfoLog
        Update-BusyState
        if ($failure) {
            Write-Log "$($job.Name) failed: $failure" 'ERR'
            if ($job.OnError) { & $job.OnError $failure $job }
            else { Show-BfoToast -Severity Error -Title (T 'msg.title.error') -Message (T 'msg.failed' @($failure)) }
        } elseif ($job.OnSuccess) {
            & $job.OnSuccess $result $job
        }
    }

    if (-not $script:CurrentJob -and $script:JobQueue.Count -gt 0) {
        $next = $script:JobQueue.Dequeue()
        $script:JobProgress.Clear()
        $shell = [powershell]::Create()
        $shell.Runspace = $script:Worker
        [void]$shell.AddScript($next.Code, $false)
        if ($null -ne $next.Argument) { [void]$shell.AddParameter('In', $next.Argument) }
        $next.PowerShell = $shell
        $next.Handle = $shell.BeginInvoke()
        $script:CurrentJob = $next
        Update-BusyState
    }
}

function Receive-BfoLog {
    $item = $null
    $added = $false
    while ($script:LogSink.TryDequeue([ref]$item)) {
        $script:LogItems.Add($item)
        $added = $true
        if (($item.Level -eq 'WARN' -or $item.Level -eq 'ERR') -and -not $script:ActivityOpen) { $script:UnseenAlerts++ }
    }
    if (-not $added) { return }
    while ($script:LogItems.Count -gt $script:LogLimit) { $script:LogItems.RemoveAt(0) }
    Update-AlertBadge
    if ($script:ActivityOpen -and $script:Ui.LogList) {
        $script:Ui.LogList.ScrollIntoView($script:LogItems[$script:LogItems.Count - 1])
    }
}

function Update-AlertBadge {
    $script:Vm.AlertCount = if ($script:UnseenAlerts -gt 99) { '99+' } else { [string]$script:UnseenAlerts }
    $script:Vm.AlertVisibility = ConvertTo-Visibility ($script:UnseenAlerts -gt 0)
}

$script:JobTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:JobTimer.Interval = [TimeSpan]::FromMilliseconds(50)
$script:JobTimer.Add_Tick({ Step-BfoJobs })
