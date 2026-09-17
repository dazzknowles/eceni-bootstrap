#requires -Version 5.1
[CmdletBinding()]
param([string]$ScratchRoot = (Join-Path $env:TEMP 'eceni-bootstrap-tests'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$script:checks = 0
function Assert([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
    Write-Host "PASS: $Message"
}
function Assert-Throws([scriptblock]$Action,[string]$Message) {
    $threw = $false
    try { & $Action | Out-Null } catch { $threw = $true }
    Assert $threw $Message
}
$sourceFiles = @((Get-Item (Join-Path $root 'Bootstrap.ps1')))
foreach ($folder in 'config','modules','profiles','roles','tests','tools') {
    $folderPath = Join-Path $root $folder
    if (Test-Path $folderPath) { $sourceFiles += @(Get-ChildItem $folderPath -Recurse -File | Where-Object Extension -in '.ps1','.psm1','.psd1') }
}
foreach ($file in $sourceFiles) {
    $tokens=$null; $errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    Assert ($errors.Count -eq 0) "Parses: $($file.Name)"
}
Import-Module (Join-Path $root 'modules\Eceni.psm1') -Force
$module = Get-Module Eceni
$profile = Import-EceniProfile (Join-Path $root 'profiles\Catwoman.psd1') $root
$plan = @(Get-EceniPlan $profile $root)
Assert ($plan.Count -gt 100) 'Complete profile produces more than 100 explicit operations'
Assert (@($plan | Where-Object { $_.Data.Id -eq 'Docker.DockerDesktop' }).Count -eq 0) 'Docker is not enabled by default'
Assert (@($plan | Where-Object { $_.Data.Id -match 'MariaDB.*Server|MariaDB.Server|MSI.Center' }).Count -eq 0) 'No MariaDB server or MSI Center installer'
Assert (@($plan | Where-Object { $_.Kind -eq 'Appx' -and $_.Data.Name -match 'Solitaire|WindowsStore|DesktopAppInstaller' }).Count -eq 0) 'Solitaire, Store and App Installer are preserved'
Assert (@($plan | Where-Object { $_.Name -eq 'NVIDIA App' -and $_.Stage -eq 'Apps' -and $_.Kind -eq 'Manual' -and $_.Data.Url -eq 'https://www.nvidia.com/en-gb/software/nvidia-app/' }).Count -eq 1) 'NVIDIA App is listed from the official vendor source'
$batCave = @($plan | Where-Object { $_.Kind -eq 'NetworkProfile' -and $_.Data.Name -eq 'TheBatCave' -and $_.Data.Category -eq 'Private' })
Assert ($batCave.Count -eq 1 -and (Get-EceniOperationContext $batCave[0]) -eq 'Machine') 'TheBatCave is conditionally configured as a private network in machine context'
$profile.Options.PackageVersionLocks['Microsoft.PowerToys'] = '0.95.1'
$lockedPackage = @(Get-EceniPlan $profile $root | Where-Object { $_.Data.Id -eq 'Microsoft.PowerToys' })
Assert ($lockedPackage.Count -eq 1 -and $lockedPackage[0].Data.VersionLock -eq '0.95.1' -and $lockedPackage[0].Detail -match 'locked to 0\.95\.1') 'Profile version locks are attached to exact package operations'
$profile.Options.PackageVersionLocks.Remove('Microsoft.PowerToys')
$profile.Options.Docker = $true
Assert (@(Get-EceniPlan $profile $root | Where-Object { $_.Data.Id -eq 'Docker.DockerDesktop' }).Count -eq 1) 'Docker opt-in includes exactly one installer'
$containerPlan = @(Get-EceniPlan $profile $root -Stage Containers)
Assert (($containerPlan[0..4].Kind -join ',') -eq 'Symlink,Feature,Feature,Wsl2,Package') 'Symlink repair, WSL features and version setup precede optional Docker install'
$profile.Options.Docker = $false
$stages = @(Get-EceniPlan $profile $root -Stage @('Foundations','AI') | Select-Object -ExpandProperty Stage -Unique)
Assert (($stages -join ',') -eq 'Foundations,AI') 'Stage selection preserves canonical order'
$packages = @($plan | Where-Object Kind -eq 'Package')
Assert (@($packages | Group-Object Detail | Where-Object Count -gt 1).Count -eq 0) 'No duplicate package installs'
Assert (@($plan | Where-Object { $_.Name -eq 'Keyboard lighting' -and $_.Kind -eq 'Manual' }).Count -eq 1) 'Keyboard lighting remains pending'
Assert (@($plan | Where-Object { $_.Kind -eq 'TerminalProfiles' -and $_.Name -eq 'Codex and Claude Terminal profiles' }).Count -eq 1) 'Development includes managed Codex and Claude Windows Terminal profiles'
Assert ((Get-EceniOperationContext ($plan | Where-Object Kind -eq 'TerminalProfiles')) -eq 'User') 'Windows Terminal profiles use normal user context'
Assert ((Get-EceniOperationContext ($plan | Where-Object { $_.Name -eq 'Show file extensions' })) -eq 'User') 'HKCU settings use normal user context'
$desktopIcons = @($plan | Where-Object { $_.Name -eq 'Desktop icons hidden' })
Assert ($desktopIcons.Count -eq 1 -and $desktopIcons[0].Data.Path -eq 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -and $desktopIcons[0].Data.ValueName -eq 'HideIcons' -and $desktopIcons[0].Data.Value -eq 1) 'Desktop icons are hidden in the Windows plan'
$notificationSound = @($plan | Where-Object { $_.Name -eq 'Notification sounds off' })
Assert ($notificationSound.Count -eq 1 -and $notificationSound[0].Data.Path -eq 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings' -and $notificationSound[0].Data.ValueName -eq 'NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND' -and $notificationSound[0].Data.Value -eq 0) 'Notification sounds are disabled in the Windows plan'
$updatePolicyValues = @{
    'AUOptions' = 3
    'NoAutoUpdate' = 0
    'NoAutoRebootWithLoggedOnUsers' = 1
    'AlwaysAutoRebootAtScheduledTime' = 0
    'SetAutoRestartNotificationConfig' = 0
    'SetAutoRestartNotificationDisable' = 1
    'SetAutoRestartRequiredNotificationDismissal' = 0
}
Assert (@($updatePolicyValues.GetEnumerator() | Where-Object { $entry=$_; @($plan | Where-Object { $_.Kind -eq 'Registry' -and $_.Data.ValueName -eq $entry.Key -and $_.Data.Value -eq $entry.Value }).Count -ne 1 }).Count -eq 0) 'Windows Update policy values match the supplied Group Policy states'
Assert (@($plan | Where-Object { $_.Kind -eq 'Registry' -and $_.Data.ValueName -in @('SetComplianceDeadline','SetUpdateNotificationLevel') -and $_.Data.Value -eq 0 }).Count -eq 2) 'Additional disabled Windows Update safeguards are retained'
Assert ((Get-EceniOperationContext ($plan | Where-Object { $_.Name -eq 'Fast Startup off' })) -eq 'Machine') 'HKLM settings use elevated machine context'
Assert ((Get-EceniOperationContext ($plan | Where-Object { $_.Name -eq 'Remove OneDrive' })) -eq 'User') 'User-scoped WinGet uninstall avoids elevation'
Assert (@($plan | Where-Object { (Get-EceniOperationContext $_) -eq 'User' }).Count -gt 20) 'Plan identifies per-user operations explicitly'
$mixedContextStages = @($plan | Where-Object Kind -ne 'Manual' | Group-Object Stage | Where-Object { @($_.Group | ForEach-Object { Get-EceniOperationContext $_ } | Select-Object -Unique).Count -gt 1 } | Select-Object -ExpandProperty Name)
Assert (($mixedContextStages -join ',') -eq 'Containers,Toolchains,Windows') 'Windows, Toolchains and Containers require both execution contexts'

# Plan and WhatIf must not create logs or invoke any privileged handler.
$tmp = Join-Path $ScratchRoot ('tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$log = Join-Path $tmp 'must-not-exist'
$preview = @(& (Join-Path $root 'Bootstrap.ps1') -LogRoot $log)
Assert ($preview.Count -eq $plan.Count -and -not (Test-Path $log)) 'Default invocation is a full plan with no log writes'
$userPreview = @(& (Join-Path $root 'Bootstrap.ps1') -Context User -LogRoot $log)
Assert ($userPreview.Count -lt $plan.Count -and @($userPreview | Where-Object Context -eq 'Machine').Count -eq 0) 'User-context preview excludes machine operations'
$preview = @(& (Join-Path $root 'Bootstrap.ps1') -Apply -WhatIf -LogRoot $log)
Assert ($preview.Count -eq $plan.Count -and -not (Test-Path $log)) 'Apply -WhatIf remains read-only, without administrator preflight'
$setupPreview = @(& (Join-Path $root 'tools\Install-All.ps1'))
Assert ($setupPreview.Count -eq 2 -and $setupPreview[0].Context -match 'Machine' -and $setupPreview[1].Context -match 'User' -and $setupPreview[0].Stages -match 'Containers' -and $setupPreview[1].Stages -match 'Containers') 'One-command setup plans machine and user batches including both Containers contexts'
$updatePreview = @(& (Join-Path $root 'tools\Update-Packages.ps1'))
Assert ($updatePreview.Count -eq $packages.Count -and @($updatePreview | Where-Object VersionLock -eq 'Latest').Count -eq $packages.Count) 'Updater preview covers the exact managed package allowlist without changing it'

# Reject broad removals before any execution.
$bad = Join-Path $tmp 'bad.psd1'
$text = Get-Content (Join-Path $root 'profiles\Catwoman.psd1') -Raw
$text.Replace("'Microsoft.Copilot'","'Microsoft.*'") | Set-Content $bad
Assert-Throws { Import-EceniProfile $bad $root } 'Wildcard removal is rejected'
$text.Replace("'Microsoft.Copilot'","'Microsoft.MicrosoftSolitaireCollection'") | Set-Content $bad
Assert-Throws { Import-EceniProfile $bad $root } 'Protected app removal is rejected'
$text.Replace('PackageVersionLocks = @{}',"PackageVersionLocks = @{'No.Such.Package'='1.0'}") | Set-Content $bad
Assert-Throws { Import-EceniProfile $bad $root } 'Version locks for unknown package IDs are rejected'

# Native mocks test exit-code handling without winget, UAC, network or installations.
& $module {
    $script:testQueue = New-Object 'System.Collections.Generic.Queue[object]'
    $script:testCalls = New-Object 'System.Collections.Generic.List[object]'
    function script:Invoke-EceniNative {
        param([string]$File,[string[]]$Arguments)
        $script:testCalls.Add(@{File=$File;Arguments=$Arguments})
        if (-not $script:testQueue.Count) { throw 'Unexpected native invocation.' }
        $script:testQueue.Dequeue()
    }
    function script:Update-EceniProcessPath {}
}
function Queue-Result([int]$Code,[string]$Output='') { & $module { param($c,$o) $script:testQueue.Enqueue([pscustomobject]@{Code=$c;Output=$o}) } $Code $Output }
$pkg = @{Id='Example.App';Source='winget';Name='Example'}
Queue-Result 0
$r = & $module { param($p) Invoke-EceniPackage $p } $pkg
Assert ($r.Status -eq 'AlreadyOK') 'Installed package is skipped without running installer'
Queue-Result -1978335212
Queue-Result 0
Queue-Result 0
$r = & $module { param($p) Invoke-EceniPackage $p } $pkg
Assert ($r.Status -eq 'Changed') 'Absent package is installed and rechecked'
Queue-Result -1978335212
$r = & $module { param($p) Invoke-EceniPackage $p -Uninstall } $pkg
Assert ($r.Status -eq 'AlreadyOK') 'Absent uninstall target is a no-op'
Queue-Result -42 'source/network error'
Assert-Throws { & $module { param($p) Invoke-EceniPackage $p } $pkg } 'Lookup error is not mistaken for absence or success'
Queue-Result -1978335212
Queue-Result 1603 'installer failure'
Assert-Throws { & $module { param($p) Invoke-EceniPackage $p } $pkg } 'Installer failure propagates'
Queue-Result -1978335212
Queue-Result 0
Queue-Result -1978335212
Assert-Throws { & $module { param($p) Invoke-EceniPackage $p } $pkg } 'False installer success fails post-install verification'
Queue-Result -1978335212
Queue-Result -1978334967
$r = & $module { param($p) Invoke-EceniPackage $p } $pkg
Assert ($r.RebootRequired -and $r.Status -eq 'Changed') 'WinGet reboot-required result is surfaced'
Queue-Result -1978335212
Queue-Result -1978334966
$r = & $module { param($p) Invoke-EceniPackage $p } $pkg
Assert ($r.RebootRequired -and $r.Status -eq 'Skipped') 'Reboot prerequisite is not reported as completed install'
$calls = & $module { $script:testCalls.ToArray() }
Assert (@($calls | Where-Object { '--allow-reboot' -in $_.Arguments -or '--force' -in $_.Arguments }).Count -eq 0) 'No forced installs or automatic reboot flags'
Assert (@($calls | Where-Object { $_.Arguments[0] -in 'install','uninstall' -and '--exact' -notin $_.Arguments }).Count -eq 0) 'All install/removal commands match exact package IDs'
& $module { $script:testCalls.Clear() }
$lockedPkg = @{Id='Example.Locked';Source='winget';Name='Locked example';VersionLock='1.2.3'}
Queue-Result -1978335212
Queue-Result 0
Queue-Result 0
$r = & $module { param($p) Invoke-EceniPackage $p } $lockedPkg
$calls = & $module { $script:testCalls.ToArray() }
Assert ($r.Status -eq 'Changed' -and @($calls | Where-Object { $_.Arguments[0] -eq 'install' -and '--version' -in $_.Arguments -and '1.2.3' -in $_.Arguments }).Count -eq 1) 'Fresh installs honor an exact configured version lock'
& $module { $script:testCalls.Clear() }
$r = & $module { param($p) Update-EceniPackage $p } $lockedPkg
$calls = & $module { $script:testCalls.ToArray() }
Assert ($r.Status -eq 'Skipped' -and $calls.Count -eq 0) 'Managed updater does not contact WinGet for version-locked packages'
Queue-Result 0
Queue-Result 0
$r = & $module { param($p) Update-EceniPackage $p } $pkg
$calls = & $module { $script:testCalls.ToArray() }
Assert ($r.Status -eq 'Changed' -and @($calls | Where-Object { $_.Arguments[0] -eq 'upgrade' -and '--exact' -in $_.Arguments -and '--force' -notin $_.Arguments }).Count -eq 1) 'Managed updater upgrades exact unpinned package IDs without forcing'
& $module { $script:testCalls.Clear() }
Queue-Result 0
Queue-Result -1978335189
$r = & $module { param($p) Update-EceniPackage $p } $pkg
Assert ($r.Status -eq 'AlreadyOK') 'No-applicable-update result is treated as current rather than failed'
Queue-Result 1 ''
Assert-Throws { & $module { Assert-EceniPackageManager } } 'Broken WinGet is caught in preflight'
Queue-Result 0 'v1.12.350'
& $module { Assert-EceniPackageManager }
Assert $true 'Working WinGet passes preflight'

# Filesystem behaviour tested only under this project's work directory.
Import-Module (Join-Path $root 'modules\Eceni.psm1') -Force
$module = Get-Module Eceni
$dir = Join-Path $tmp 'source'
$op = [pscustomobject]@{Kind='Directory';Data=@{Path=$dir}}
$a = Invoke-EceniOperation $op $profile $tmp
$b = Invoke-EceniOperation $op $profile $tmp
Assert ($a.Status -eq 'Changed' -and $b.Status -eq 'AlreadyOK') 'Directory creation is idempotent'
$target = Join-Path $tmp 'real-config'
New-Item -ItemType Directory -Path $target | Out-Null
Set-Content (Join-Path $target 'settings.txt') 'keep me'
$profile.ConfigRoot = Join-Path $tmp 'navigation'
& $module {
    param($t)
    $script:fakeTarget = $t
    function script:Get-EceniLinkTargets { @(@{Name='Demo';Path=$script:fakeTarget;Secrets='Possible'},@{Name='Missing';Path=($script:fakeTarget+'-absent');Secrets='Possible'}) }
    function script:Update-EceniProcessPath {}
} $target
$op = [pscustomobject]@{Kind='Links';Data=@{}}
$a = Invoke-EceniOperation $op $profile $tmp
$b = Invoke-EceniOperation $op $profile $tmp
Assert ($a.Status -eq 'Changed' -and $b.Status -eq 'AlreadyOK') 'Config junctions and README are idempotent'
Assert ((Get-Content (Join-Path $profile.ConfigRoot 'Demo\settings.txt')) -eq 'keep me') 'Friendly junction reads the original config'
Assert (-not (Test-Path (Join-Path $profile.ConfigRoot 'Missing'))) 'Missing config target is not fabricated'
$profile.ConfigRoot = Join-Path $tmp 'conflict'
New-Item -ItemType Directory -Path (Join-Path $profile.ConfigRoot 'Demo') -Force | Out-Null
Set-Content (Join-Path $profile.ConfigRoot 'Demo\keep.txt') 'do not overwrite'
$r = Invoke-EceniOperation $op $profile $tmp
Assert ($r.Status -eq 'Warning' -and (Get-Content (Join-Path $profile.ConfigRoot 'Demo\keep.txt')) -eq 'do not overwrite') 'Existing config paths are preserved and reported'

# Managed profile edits preserve user content and remain stable on reruns.
$docs = Join-Path $tmp 'documents'
$shellFile = Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'
New-Item -ItemType Directory -Path (Split-Path $shellFile -Parent) -Force | Out-Null
Set-Content $shellFile '# my personal configuration'
$a = & $module { param($p,$d) Set-EceniShell $p -DocumentsDirectory $d } $profile $docs
$b = & $module { param($p,$d) Set-EceniShell $p -DocumentsDirectory $d } $profile $docs
$shellText = Get-Content $shellFile -Raw
Assert ($a.Status -eq 'Changed' -and $b.Status -eq 'AlreadyOK') 'Managed PowerShell profile is idempotent'
Assert ($shellText.Contains('# my personal configuration') -and [regex]::Matches($shellText,'# BEGIN ECENI BOOTSTRAP').Count -eq 1) 'Personal shell config preserved without duplicate managed blocks'
Assert (@(Get-ChildItem (Split-Path $shellFile -Parent) -Filter '*.bak').Count -eq 1) 'Existing shell configuration backed up only when changed'
$profile.SourceRoot = "D:\Source\O'Brien"
$r = & $module { param($p,$d) Set-EceniShell $p -DocumentsDirectory $d } $profile $docs
$tokens=$null; $errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($shellFile,[ref]$tokens,[ref]$errors)
Assert ($errors.Count -eq 0) 'Source directory with apostrophe is safely quoted in shell profile'
Set-Content $shellFile '# BEGIN ECENI BOOTSTRAP'
Assert-Throws { & $module { param($p,$d) Set-EceniShell $p -DocumentsDirectory $d } $profile $docs } 'Malformed existing managed block is preserved for inspection'

# Terminal fragment creation preserves the main settings file and is stable on reruns.
$terminalRoot = Join-Path $tmp 'terminal-fragments\Eceni'
$iconRoot = Join-Path $tmp 'terminal-icons'
New-Item -ItemType Directory -Path $iconRoot -Force | Out-Null
$codexIcon = Join-Path $iconRoot 'codex.png'; [IO.File]::WriteAllBytes($codexIcon,[byte[]](1,2,3))
$claudeIcon = Join-Path $iconRoot 'claude.png'; [IO.File]::WriteAllBytes($claudeIcon,[byte[]](4,5,6))
$profile.SourceRoot = 'D:\Source'
$a = & $module { param($p,$r,$i) Set-EceniTerminalProfiles $p -FragmentRoot $r -IconSources $i } $profile $terminalRoot @{Codex=$codexIcon;Claude=$claudeIcon}
$b = & $module { param($p,$r,$i) Set-EceniTerminalProfiles $p -FragmentRoot $r -IconSources $i } $profile $terminalRoot @{Codex=$codexIcon;Claude=$claudeIcon}
$terminalJson = Get-Content (Join-Path $terminalRoot 'profiles.json') -Raw | ConvertFrom-Json
Assert ($a.Status -eq 'Changed' -and $b.Status -eq 'AlreadyOK') 'Windows Terminal fragment and icons are idempotent'
Assert ($terminalJson.profiles.Count -eq 2 -and ($terminalJson.profiles.name -join ',') -eq 'Codex,Claude Code') 'Windows Terminal fragment defines both AI profiles'
Assert ($terminalJson.profiles[0].startingDirectory -eq 'D:\Source' -and $terminalJson.profiles[0].tabColor -eq '#10A37F' -and $terminalJson.profiles[1].tabColor -eq '#D97757') 'Windows Terminal profiles use the configured source root and tab colours'
Assert ($terminalJson.profiles[0].commandline -match 'codex' -and $terminalJson.profiles[1].commandline -match 'claude') 'Windows Terminal profiles launch the corresponding CLI'
Assert ((Test-Path (Join-Path $terminalRoot 'codex.png')) -and (Test-Path (Join-Path $terminalRoot 'claude.png'))) 'Windows Terminal profile icons are stored beside the managed fragment'

# Optional-feature state handling without DISM or rebooting.
& $module {
    $script:fakeFeatures = @()
    function script:Get-WindowsOptionalFeature { param([switch]$Online,[string]$ErrorAction) $script:fakeFeatures }
}
$r = & $module { Invoke-EceniFeature @{Name='Recall';Enabled=$false} }
Assert ($r.Status -eq 'Skipped') 'Absent optional Recall component is skipped'
Assert-Throws { & $module { Invoke-EceniFeature @{Name='VirtualMachinePlatform';Enabled=$true} } } 'Absent required WSL feature is a failure'
& $module { $script:fakeFeatures = @([pscustomobject]@{FeatureName='VirtualMachinePlatform';State='EnablePending'}) }
$r = & $module { Invoke-EceniFeature @{Name='VirtualMachinePlatform';Enabled=$true} }
Assert ($r.RebootRequired -and $r.Status -eq 'Skipped') 'Pending Windows feature requires reboot before further setup'
& $module { $script:fakeFeatures = @([pscustomobject]@{FeatureName='VirtualMachinePlatform';State='Enabled'}) }
$r = & $module { Invoke-EceniFeature @{Name='VirtualMachinePlatform';Enabled=$true} }
Assert ($r.Status -eq 'AlreadyOK') 'Enabled WSL prerequisite is a no-op'

# Network profile handling changes only an active exact-name match.
& $module {
    $script:fakeNetworkProfiles = @()
    $script:networkWrites = 0
    function script:Get-NetConnectionProfile {
        param($Name,$InterfaceIndex,$ErrorAction)
        if ($PSBoundParameters.ContainsKey('InterfaceIndex')) { return @($script:fakeNetworkProfiles | Where-Object InterfaceIndex -eq $InterfaceIndex) }
        @($script:fakeNetworkProfiles | Where-Object Name -eq $Name)
    }
    function script:Set-NetConnectionProfile {
        param($InterfaceIndex,$NetworkCategory,$ErrorAction)
        foreach ($profile in $script:fakeNetworkProfiles | Where-Object InterfaceIndex -eq $InterfaceIndex) { $profile.NetworkCategory = $NetworkCategory }
        $script:networkWrites++
    }
}
$network = @{Name='TheBatCave';Category='Private'}
$missing = & $module { param($n) Set-EceniNetworkProfile $n } $network
& $module { $script:fakeNetworkProfiles = @([pscustomobject]@{Name='TheBatCave';InterfaceIndex=42;NetworkCategory='Public'}) }
$changed = & $module { param($n) Set-EceniNetworkProfile $n } $network
$same = & $module { param($n) Set-EceniNetworkProfile $n } $network
Assert ($missing.Status -eq 'Skipped' -and $changed.Status -eq 'Changed' -and $same.Status -eq 'AlreadyOK' -and (& $module { $script:networkWrites }) -eq 1) 'TheBatCave network profile is skipped when disconnected and changed idempotently when connected'

# Registry backups and idempotence using in-memory registry cmdlet mocks.
& $module {
    $script:registryValue = $null
    $script:registryWrites = 0
    function script:Get-ItemProperty {
        param($LiteralPath,$ErrorAction)
        if ($null -ne $script:registryValue) { [pscustomobject]@{TestValue=$script:registryValue} }
    }
    function script:New-Item { param($Path,[switch]$Force) }
    function script:New-ItemProperty {
        param($LiteralPath,$Name,$Value,$PropertyType,[switch]$Force)
        $script:registryValue=$Value; $script:registryWrites++
    }
    function script:Get-ItemPropertyValue { param($LiteralPath,$Name) $script:registryValue }
}
$setting = @{Path='HKCU:\Software\EceniTestFake';ValueName='TestValue';Value=1;Name='Fake preference'}
$a = & $module { param($s,$l) Set-EceniRegistry $s $l } $setting $tmp
$b = & $module { param($s,$l) Set-EceniRegistry $s $l } $setting $tmp
Assert ($a.Status -eq 'Changed' -and $b.Status -eq 'AlreadyOK') 'Registry handler writes only when state differs'
$backup = @(Get-Content (Join-Path $tmp 'registry-before.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
Assert ($backup.Count -eq 1 -and -not $backup[0].Existed) 'Before-state records absence once without inventing an old value'
Write-Host "All $script:checks checks passed. No machine settings or applications were changed."
