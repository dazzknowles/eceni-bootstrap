#requires -Version 5.1
<# Runs the complete bootstrap from a normal PowerShell window, using one UAC-approved machine batch followed by the normal-user batch. #>
[CmdletBinding()]
param(
    [string]$Profile = (Join-Path (Split-Path $PSScriptRoot -Parent) 'profiles\Catwoman.psd1'),
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$bootstrap = Join-Path $root 'Bootstrap.ps1'
Import-Module (Join-Path $root 'modules\Eceni.psm1') -Force
$machine = Import-EceniProfile $Profile $root
$plan = @(Get-EceniPlan $machine $root | Where-Object { $_.Stage -ne 'Manual' })
$machineStages = @($plan | Where-Object { $_.Kind -ne 'Manual' -and (Get-EceniOperationContext $_) -eq 'Machine' } | Select-Object -ExpandProperty Stage -Unique)
$userStages = @($plan | Where-Object { $_.Kind -ne 'Manual' -and (Get-EceniOperationContext $_) -eq 'User' } | Select-Object -ExpandProperty Stage -Unique)
$manual = @($plan | Where-Object Kind -eq 'Manual') + @(Get-EceniPlan $machine $root -Stage Manual | Where-Object Kind -eq 'Manual')

if (-not $Apply) {
    [pscustomobject]@{ Order=1; Context='Machine (one UAC prompt)'; Stages=($machineStages -join ', ') }
    [pscustomobject]@{ Order=2; Context='User (normal window)'; Stages=($userStages -join ', ') }
    Write-Host "`nManual follow-up items: $($manual.Count)"
    return
}
if (Test-EceniAdministrator) { throw 'Run Install-All.ps1 from a normal, non-administrator PowerShell window. It requests elevation only for the machine batch.' }
$hostExe = (Get-Process -Id $PID).Path
if (-not $hostExe) { throw 'Cannot determine the current PowerShell executable.' }

function ConvertTo-EceniProcessArgument {
    param([string]$Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    '"' + $Value.Replace('"','\"') + '"'
}
function Invoke-EceniBootstrapBatch {
    param([ValidateSet('User','Machine')][string]$Context,[string[]]$Stages)
    if (-not $Stages.Count) { return 0 }
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$bootstrap,'-Profile',$Profile,'-Apply','-SkipManual','-Stage') + $Stages + @('-Context',$Context)
    Write-Host "`nStarting $Context context: $($Stages -join ', ')"
    if ($Context -eq 'Machine') {
        $argumentLine = (($arguments | ForEach-Object { ConvertTo-EceniProcessArgument ([string]$_) }) -join ' ')
        $process = Start-Process -FilePath $hostExe -ArgumentList $argumentLine -WorkingDirectory $root -Verb RunAs -Wait -PassThru
        return $process.ExitCode
    }
    & $hostExe @arguments
    return $LASTEXITCODE
}

$machineCode = Invoke-EceniBootstrapBatch Machine $machineStages
if ($machineCode -eq 3010) {
    Write-Warning 'Machine setup requires a reboot. Reboot manually, then run this same command again; completed work is idempotent.'
    exit 3010
}
if ($machineCode -ne 0) { throw "Machine setup failed with exit code $machineCode. Review the newest logs entry before retrying." }
$userCode = Invoke-EceniBootstrapBatch User $userStages
if ($userCode -eq 3010) {
    Write-Warning 'User setup requires a reboot. Reboot manually, then run this same command again.'
    exit 3010
}
if ($userCode -ne 0) { throw "User setup failed with exit code $userCode. Review the newest logs entry before retrying." }

Write-Host "`nAutomated setup is complete. Manual follow-up items:"
$manual | Select-Object Stage,Name,Detail | Format-Table -Wrap -AutoSize
