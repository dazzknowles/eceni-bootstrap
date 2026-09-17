#requires -Version 5.1
<#
.SYNOPSIS
Plans or applies an Eceni machine profile. Default execution is read-only.
.EXAMPLE
.\Bootstrap.ps1 -Stage Foundations
.EXAMPLE
.\Bootstrap.ps1 -Apply -Stage Foundations
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$Profile = (Join-Path $PSScriptRoot 'profiles\Catwoman.psd1'),
    [ValidateSet('All','Windows','Foundations','Toolchains','IDEs','Database','AI','Apps','Containers','Development','ConfigLinks','Manual')]
    [string[]]$Stage = @('All'),
    [ValidateSet('Auto','User','Machine')]
    [string]$Context = 'Auto',
    [switch]$SkipManual,
    [switch]$Apply,
    [string]$LogRoot = (Join-Path $PSScriptRoot 'logs')
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'modules\Eceni.psm1') -Force
$machine = Import-EceniProfile -Path $Profile -Root $PSScriptRoot
$fullPlan = @(Get-EceniPlan -Profile $machine -Root $PSScriptRoot -Stage $Stage)
if ($SkipManual) { $fullPlan = @($fullPlan | Where-Object Kind -ne 'Manual') }
if (-not $Apply -or $WhatIfPreference) {
    $preview = $fullPlan
    if ($Context -ne 'Auto') { $preview = @($preview | Where-Object { (Get-EceniOperationContext $_) -in @($Context,'Any') }) }
    $preview | Select-Object Stage, @{Name='Context';Expression={Get-EceniOperationContext $_}}, Kind, Name, Detail
    return
}
$isAdministrator = Test-EceniAdministrator
$effectiveContext = $Context
if ($effectiveContext -eq 'Auto') { if ($isAdministrator) { $effectiveContext = 'Machine' } else { $effectiveContext = 'User' } }
Assert-EceniHost -Context $effectiveContext
$plan = @($fullPlan | Where-Object { (Get-EceniOperationContext $_) -in @($effectiveContext,'Any') })
$deferred = @($fullPlan | Where-Object { (Get-EceniOperationContext $_) -notin @($effectiveContext,'Any') })
if ($deferred.Count) {
    $otherContext = if ($effectiveContext -eq 'Machine') { 'User' } else { 'Machine' }
    $window = if ($otherContext -eq 'Machine') { 'an administrator PowerShell window' } else { 'a normal PowerShell window' }
    Write-Host "[$effectiveContext context] Applying $($plan.Count) operations; $($deferred.Count) $otherContext-context operations are deferred. Rerun this stage with -Context $otherContext from $window."
}
if (@($plan | Where-Object Kind -in 'Package','Uninstall').Count) {
    Assert-EceniPackageManager
}
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$logPath = Join-Path $LogRoot ($runId + '.jsonl')
$results = New-Object 'System.Collections.Generic.List[object]'
$uiChanged = $false
$rebootPending = $false
$blockingReboot = $false
foreach ($operation in $plan) {
    if ($operation.Kind -eq 'Manual' -or $PSCmdlet.ShouldProcess($operation.Detail, $operation.Name)) {
        if ($blockingReboot -and $operation.Kind -ne 'Manual') {
            $outcome = New-EceniResult 'Skipped' 'A prerequisite changed and requires a reboot. Reboot manually, then rerun this stage.'
        } elseif ($rebootPending -and $operation.Kind -notin @('Manual','Registry','Directory','Links','Appx','Feature','Power')) {
            $outcome = New-EceniResult 'Skipped' 'Reboot required by an earlier operation. Reboot manually, then rerun this stage.'
        } else {
            try { $outcome = Invoke-EceniOperation -Operation $operation -Profile $machine -LogRoot $LogRoot }
            catch { $outcome = New-EceniResult 'Failed' $_.Exception.Message }
        }
    } else { $outcome = New-EceniResult 'Skipped' 'Declined through ShouldProcess.' }
    if ($outcome.RebootRequired) {
        $rebootPending = $true
        if ($operation.Kind -eq 'Symlink' -and $outcome.Status -eq 'Changed') { $blockingReboot = $true }
    }
    if ($effectiveContext -eq 'User' -and $operation.Kind -eq 'Registry' -and $outcome.Status -eq 'Changed' -and $operation.Data.Path -like 'HKCU:*') { $uiChanged = $true }
    $record = [pscustomobject]@{
        Timestamp = [DateTime]::UtcNow.ToString('o'); Stage = $operation.Stage
        Name = $operation.Name; Status = $outcome.Status; Message = $outcome.Message
        RebootRequired = $outcome.RebootRequired
    }
    $results.Add($record)
    $record | ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $logPath -Encoding UTF8
    Write-Host ('[{0}] {1}: {2}' -f $record.Status, $record.Name, $record.Message)
}
if ($uiChanged -and $machine.Options.RestartExplorer -and $PSCmdlet.ShouldProcess('Explorer in the current session','Restart once to refresh UI settings')) {
    # Never stop another signed-in user's Explorer.
    $session = (Get-Process -Id $PID).SessionId
    Get-Process explorer -ErrorAction SilentlyContinue | Where-Object SessionId -eq $session | Stop-Process -ErrorAction Continue
}
$results | Group-Object Status | Select-Object Name,Count | Format-Table -AutoSize
Write-Host "Report: $logPath"
if ($rebootPending) { Write-Warning 'Reboot manually, then rerun the same stage. This script never reboots Windows.' }
if (@($results | Where-Object Status -eq 'Failed').Count) { exit 1 }
if ($rebootPending) { exit 3010 }
