#requires -Version 5.1
<# Copies this release to the requested source drive. It does not run Bootstrap.ps1. #>
[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$Destination = 'D:\Source\eceni-bootstrap')
$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
$target = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
if ($target -eq $source) { Write-Host 'Already in the requested location.'; return }
if ($target -eq [IO.Path]::GetPathRoot($target).TrimEnd('\') -or $target.StartsWith($source+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Choose a project directory outside this release, not a drive root.' }
if (Test-Path -LiteralPath $target) {
    if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw 'Destination is an existing file.' }
    if (@(Get-ChildItem -LiteralPath $target -Force).Count) { throw 'Destination is not empty. Existing work is preserved; copy/merge manually.' }
}
$files = @('Bootstrap.ps1','README.md','.gitignore')
foreach ($folder in 'config','docs','modules','profiles','roles','tests','tools') {
    $files += @(Get-ChildItem -LiteralPath (Join-Path $source $folder) -Recurse -File | ForEach-Object { $_.FullName.Substring($source.Length+1) })
}
if ($PSCmdlet.ShouldProcess($target,'Create project directory and copy verified release files')) {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    foreach ($relative in $files) {
        $to = Join-Path $target $relative
        New-Item -ItemType Directory -Path (Split-Path $to -Parent) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $source $relative) -Destination $to
        if ((Get-FileHash -LiteralPath $to).Hash -ne (Get-FileHash -LiteralPath (Join-Path $source $relative)).Hash) { throw "Copy verification failed: $relative" }
    }
    Write-Host "Copied and hash-verified $($files.Count) files to $target. No applications installed or Windows settings changed."
}
