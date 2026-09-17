#requires -Version 5.1
<# Checks live source availability only. Does not install packages. #>
[CmdletBinding()]
param([string]$Profile = (Join-Path (Split-Path $PSScriptRoot -Parent) 'profiles\Catwoman.psd1'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'modules\Eceni.psm1') -Force
$p = Import-EceniProfile $Profile $root
Assert-EceniPackageManager
$failed = 0
foreach ($op in Get-EceniPlan $p $root | Where-Object Kind -eq 'Package') {
    $output = & winget.exe show --id $op.Data.Id --exact --source $op.Data.Source --accept-source-agreements --disable-interactivity 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) { $failed++; Write-Warning "$($op.Data.Id): source verification failed ($code). $output" }
    else { Write-Host "Verified: $($op.Data.Source):$($op.Data.Id)" }
}
if ($failed) { throw "$failed packages could not be verified; resolve source/connectivity/region issues before Apply." }
