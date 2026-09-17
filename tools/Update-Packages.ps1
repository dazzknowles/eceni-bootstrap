#requires -Version 5.1
<# Updates only the exact WinGet package IDs managed by the selected profile. Default execution is a read-only plan. #>
[CmdletBinding()]
param(
    [string]$Profile = (Join-Path (Split-Path $PSScriptRoot -Parent) 'profiles\Catwoman.psd1'),
    [ValidateSet('Auto','User','Machine')][string]$Context = 'Auto',
    [switch]$Apply,
    [switch]$Worker
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'modules\Eceni.psm1') -Force
$machine = Import-EceniProfile $Profile $root
$packages = @(Get-EceniPlan $machine $root | Where-Object Kind -eq 'Package')

if (-not $Apply) {
    $packages | Select-Object Stage,@{Name='Context';Expression={Get-EceniOperationContext $_}},Name,@{Name='VersionLock';Expression={if ($_.Data.ContainsKey('VersionLock')) {$_.Data.VersionLock} else {'Latest'}}}
    return
}

function Invoke-EceniUpdateWorker {
    param([ValidateSet('User','Machine')][string]$WorkerContext)
    Assert-EceniHost -Context $WorkerContext
    $selected = @($packages | Where-Object { (Get-EceniOperationContext $_) -eq $WorkerContext })
    if (-not $selected.Count) { return 0 }
    Assert-EceniPackageManager
    $logRoot = Join-Path $root 'logs'
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    $logPath = Join-Path $logRoot (('updates-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)) + '.jsonl')
    $failed = $false
    foreach ($operation in $selected) {
        try { $outcome = Update-EceniPackage $operation.Data }
        catch { $outcome = New-EceniResult 'Failed' $_.Exception.Message; $failed = $true }
        $record = [pscustomobject]@{Timestamp=[DateTime]::UtcNow.ToString('o');Name=$operation.Name;Id=$operation.Data.Id;Status=$outcome.Status;Message=$outcome.Message;RebootRequired=$outcome.RebootRequired}
        $record | ConvertTo-Json -Compress | Add-Content -LiteralPath $logPath -Encoding UTF8
        Write-Host ('[{0}] {1}: {2}' -f $record.Status,$record.Name,$record.Message)
        if ($outcome.RebootRequired) { Write-Warning 'An update requires a reboot; remaining updates are deferred.'; Write-Host "Report: $logPath"; return 3010 }
    }
    Write-Host "Report: $logPath"
    if ($failed) { return 1 }
    return 0
}

if ($Worker -or $Context -ne 'Auto') {
    $workerContext = $Context
    if ($workerContext -eq 'Auto') { throw 'Worker mode requires an explicit context.' }
    $code = Invoke-EceniUpdateWorker $workerContext
    exit $code
}

if (Test-EceniAdministrator) { throw 'Run Update-Packages.ps1 from a normal, non-administrator PowerShell window. It requests elevation only when machine-scoped packages need updates.' }
$hostExe = (Get-Process -Id $PID).Path
if (-not $hostExe) { throw 'Cannot determine the current PowerShell executable.' }
function ConvertTo-EceniProcessArgument {
    param([string]$Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    '"' + $Value.Replace('"','\"') + '"'
}
foreach ($updateContext in 'Machine','User') {
    if (-not @($packages | Where-Object { (Get-EceniOperationContext $_) -eq $updateContext }).Count) { continue }
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Profile',$Profile,'-Apply','-Worker','-Context',$updateContext)
    if ($updateContext -eq 'Machine') {
        $argumentLine = (($arguments | ForEach-Object { ConvertTo-EceniProcessArgument ([string]$_) }) -join ' ')
        $process = Start-Process -FilePath $hostExe -ArgumentList $argumentLine -WorkingDirectory $root -Verb RunAs -Wait -PassThru
        $code = $process.ExitCode
    } else {
        & $hostExe @arguments
        $code = $LASTEXITCODE
    }
    if ($code -eq 3010) { Write-Warning 'Reboot manually, then rerun the updater.'; exit 3010 }
    if ($code -ne 0) { throw "$updateContext package updates failed with exit code $code." }
}
