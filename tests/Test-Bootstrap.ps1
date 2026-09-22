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
Assert (@($plan | Where-Object { $_.Data.Id -eq 'Docker.DockerDesktop' }).Count -eq 1) 'Docker Desktop is enabled in the Catwoman profile'
Assert (@($plan | Where-Object { $_.Data.Id -match 'MariaDB.*Server|MariaDB.Server' }).Count -eq 0) 'No MariaDB server installer'
Assert (@($plan | Where-Object { $_.Kind -eq 'Appx' -and $_.Data.Name -match 'Solitaire|WindowsStore|DesktopAppInstaller' }).Count -eq 0) 'Solitaire, Store and App Installer are preserved'
Assert (@($plan | Where-Object { $_.Kind -eq 'Appx' -and $_.Data.Name -in @('Microsoft.Xbox.TCUI','Microsoft.BingWeather','Microsoft.MicrosoftStickyNotes','7EE7776C.LinkedInforWindows') }).Count -eq 4) 'Xbox Live, Weather, Sticky Notes and LinkedIn are removed for the current user'
Assert (@($plan | Where-Object { $_.Kind -eq 'AppLocker' -and $_.Name -eq 'Prevent Microsoft Copilot reinstall' }).Count -eq 1) 'Windows includes the machine-scoped Copilot AppLocker block'
Assert (@($plan | Where-Object { $_.Kind -eq 'Package' -and $_.Data.Id -eq 'hluk.CopyQ' -and $_.Stage -eq 'Apps' }).Count -eq 1) 'CopyQ is included in the Apps stage'
Assert (@($plan | Where-Object { $_.Kind -eq 'Package' -and $_.Data.Id -eq 'Google.GoogleDrive' -and $_.Stage -eq 'Apps' }).Count -eq 1) 'Google Drive for desktop is included in the Apps stage'
Assert (@($plan | Where-Object { $_.Kind -eq 'Package' -and $_.Data.Id -eq 'SteelSeries.GG' -and $_.Data.Source -eq 'winget' -and $_.Stage -eq 'Apps' }).Count -eq 1) 'SteelSeries GG is included in the Apps machine batch'
$msiCenter = @($plan | Where-Object { $_.Kind -eq 'Package' -and $_.Data.Id -eq '9NVMNJCR03XV' -and $_.Data.Source -eq 'msstore' -and $_.Stage -eq 'Apps' })
Assert ($msiCenter.Count -eq 1 -and (Get-EceniOperationContext $msiCenter[0]) -eq 'User') 'MSI Center uses its Microsoft Store product ID in user context'
$nvidiaApp = @($plan | Where-Object { $_.Name -eq 'Install NVIDIA App' -and $_.Stage -eq 'Apps' -and $_.Kind -eq 'Package' -and $_.Data.Id -eq 'XP8CLZL93F5Z4P' -and $_.Data.Source -eq 'msstore' })
Assert ($nvidiaApp.Count -eq 1 -and (Get-EceniOperationContext $nvidiaApp[0]) -eq 'User') 'NVIDIA App uses its Microsoft Store product ID in user context'
$batCave = @($plan | Where-Object { $_.Kind -eq 'NetworkProfile' -and $_.Data.Name -eq 'TheBatCave' -and $_.Data.Category -eq 'Private' })
Assert ($batCave.Count -eq 1 -and (Get-EceniOperationContext $batCave[0]) -eq 'Machine') 'TheBatCave is conditionally configured as a private network in machine context'
$profile.Options.PackageVersionLocks['Microsoft.PowerToys'] = '0.95.1'
$lockedPackage = @(Get-EceniPlan $profile $root | Where-Object { $_.Data.Id -eq 'Microsoft.PowerToys' })
Assert ($lockedPackage.Count -eq 1 -and $lockedPackage[0].Data.VersionLock -eq '0.95.1' -and $lockedPackage[0].Detail -match 'locked to 0\.95\.1') 'Profile version locks are attached to exact package operations'
$profile.Options.PackageVersionLocks.Remove('Microsoft.PowerToys')
$profile.Options.Docker = $false
Assert (@(Get-EceniPlan $profile $root | Where-Object { $_.Data.Id -eq 'Docker.DockerDesktop' }).Count -eq 0) 'Docker can still be disabled by profile'
$profile.Options.Docker = $true
$containerPlan = @(Get-EceniPlan $profile $root -Stage Containers)
Assert (($containerPlan[0..5].Kind -join ',') -eq 'Symlink,Feature,Feature,Wsl2,WslDistro,Package') 'Symlink repair, WSL features, WSL2 default and Rocky installation precede Docker install'
$stages = @(Get-EceniPlan $profile $root -Stage @('Foundations','AI') | Select-Object -ExpandProperty Stage -Unique)
Assert (($stages -join ',') -eq 'Foundations,AI') 'Stage selection preserves canonical order'
$packages = @($plan | Where-Object Kind -eq 'Package')
Assert (@($packages | Group-Object Detail | Where-Object Count -gt 1).Count -eq 0) 'No duplicate package installs'
Assert (@($plan | Where-Object { $_.Name -eq 'MSI and SteelSeries feature selection' -and $_.Kind -eq 'Manual' }).Count -eq 1) 'MSI and SteelSeries optional feature selection remains explicit'
$rockyWsl = @($plan | Where-Object Kind -eq 'WslDistro')
Assert ($rockyWsl.Count -eq 1 -and $rockyWsl[0].Data.Major -eq 10 -and $rockyWsl[0].Data.DistroName -eq 'RockyLinux-10') 'Rocky Linux 10 is the configured WSL distribution'
Assert ((Get-EceniOperationContext $rockyWsl[0]) -eq 'User') 'Rocky WSL registration uses normal user context'
Assert (@($plan | Where-Object Name -eq 'WSL distribution').Count -eq 0) 'Configured Rocky installation replaces the obsolete choose-a-distro follow-up'
Assert (@($plan | Where-Object { $_.Kind -eq 'TerminalProfiles' -and $_.Name -eq 'Codex and Claude Terminal profiles' }).Count -eq 1) 'Development includes managed Codex and Claude Windows Terminal profiles'
Assert ((Get-EceniOperationContext ($plan | Where-Object Kind -eq 'TerminalProfiles')) -eq 'User') 'Windows Terminal profiles use normal user context'
$gitPlan = @($plan | Where-Object { $_.Kind -eq 'Git' -and $_.Name -eq 'Configure Git and LFS' })
Assert ($gitPlan.Count -eq 1 -and $gitPlan[0].Detail -match 'Dazz Knowles <me@dazzknowles\.co\.uk>') 'Development configures the requested global Git identity'
Assert (@($plan | Where-Object { $_.Kind -eq 'Manual' -and $_.Name -eq 'Git identity and authentication' }).Count -eq 0) 'Configured Git identity is no longer a manual follow-up'
Assert ((Get-EceniOperationContext ($plan | Where-Object { $_.Name -eq 'Show file extensions' })) -eq 'User') 'HKCU settings use normal user context'
$desktopIcons = @($plan | Where-Object { $_.Name -eq 'Desktop icons hidden' })
Assert ($desktopIcons.Count -eq 1 -and $desktopIcons[0].Data.Path -eq 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -and $desktopIcons[0].Data.ValueName -eq 'HideIcons' -and $desktopIcons[0].Data.Value -eq 1) 'Desktop icons are hidden in the Windows plan'
$widgets = @($plan | Where-Object { $_.Name -eq 'Taskbar Widgets hidden' })
$widgetsPolicy = @($plan | Where-Object { $_.Name -eq 'Widgets allowed' })
Assert ($widgets.Count -eq 1 -and $widgets[0].Data.ValueName -eq 'TaskbarDa' -and $widgets[0].Data.Value -eq 0 -and $widgetsPolicy.Count -eq 1 -and $widgetsPolicy[0].Data.Value -eq 1) 'Widgets stay enabled while their taskbar button is hidden'
$notificationSound = @($plan | Where-Object { $_.Name -eq 'Notification sounds off' })
Assert ($notificationSound.Count -eq 1 -and $notificationSound[0].Data.Path -eq 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings' -and $notificationSound[0].Data.ValueName -eq 'NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND' -and $notificationSound[0].Data.Value -eq 0) 'Notification sounds are disabled in the Windows plan'
$noSounds = @($plan | Where-Object { $_.Kind -eq 'SoundScheme' -and $_.Name -eq 'Windows sound scheme: No Sounds' })
Assert ($noSounds.Count -eq 1 -and (Get-EceniOperationContext $noSounds[0]) -eq 'User') 'The complete No Sounds scheme is applied in user context'
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
$mixedContextStages = @($plan | Where-Object Kind -ne 'Manual' | Group-Object Stage | Where-Object { @($_.Group | ForEach-Object { Get-EceniOperationContext $_ } | Select-Object -Unique).Count -gt 1 } | Select-Object -ExpandProperty Name | Sort-Object)
Assert (($mixedContextStages -join ',') -eq 'Apps,Containers,Toolchains,Windows') 'Windows, Toolchains, Apps and Containers require both execution contexts'

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
$text.Replace('Major = 10','Major = 11') | Set-Content $bad
Assert-Throws { Import-EceniProfile $bad $root } 'Unsupported Rocky WSL major versions are rejected'

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

# Git defaults and the requested identity are written globally and converge.
& $module {
    $script:gitSettings = @{}
    $script:gitCalls = New-Object 'System.Collections.Generic.List[object]'
    function script:Invoke-EceniNative {
        param([string]$File,[string[]]$Arguments)
        $script:gitCalls.Add(@{File=$File;Arguments=$Arguments})
        if ($File -ne 'git.exe') { return [pscustomobject]@{Code=0;Output=''} }
        if ($Arguments[0] -eq 'config' -and $Arguments[2] -eq '--get') {
            $key = $Arguments[3]
            if ($script:gitSettings.ContainsKey($key)) { return [pscustomobject]@{Code=0;Output=$script:gitSettings[$key]} }
            return [pscustomobject]@{Code=1;Output=''}
        }
        if ($Arguments[0] -eq 'config') {
            $script:gitSettings[$Arguments[2]] = $Arguments[3]
            return [pscustomobject]@{Code=0;Output=''}
        }
        if ($Arguments[0] -eq 'lfs') {
            $script:gitSettings['filter.lfs.process'] = 'git-lfs filter-process'
            return [pscustomobject]@{Code=0;Output=''}
        }
        [pscustomobject]@{Code=0;Output=''}
    }
}
$a = & $module { param($o) Set-EceniGit $o } $profile.Options
$b = & $module { param($o) Set-EceniGit $o } $profile.Options
$gitState = & $module { $script:gitSettings.Clone() }
$gitCalls = & $module { $script:gitCalls.ToArray() }
Assert ($a.Status -eq 'Changed' -and $b.Status -eq 'AlreadyOK') 'Managed Git configuration is idempotent'
Assert ($gitState['user.name'] -eq 'Dazz Knowles' -and $gitState['user.email'] -eq 'me@dazzknowles.co.uk') 'Requested Git name and email are configured exactly'
Assert (@($gitCalls | Where-Object { $_.Arguments[0] -eq 'config' -and $_.Arguments[1] -ne '--global' }).Count -eq 0) 'Managed Git settings use the current user global config'

# The Copilot block merges a narrow packaged-app rule and enables its enforcement service.
$appLockerLog = Join-Path $tmp 'applocker-logs'
New-Item -ItemType Directory -Path $appLockerLog -Force | Out-Null
& $module {
    $script:appLockerText = '<AppLockerPolicy Version="1"></AppLockerPolicy>'
    $script:appIdStartType = 'Manual'
    $script:appIdStatus = 'Stopped'
    function script:Get-Command { param($Name,$ErrorAction) [pscustomobject]@{Name=$Name} }
    function script:Get-AppLockerPolicy { param([switch]$Local,[switch]$Xml,$ErrorAction) $script:appLockerText }
    function script:Set-AppLockerPolicy {
        param($XmlPolicy,[switch]$Merge,[switch]$Confirm,$ErrorAction)
        $script:appLockerText = [IO.File]::ReadAllText($XmlPolicy)
    }
    function script:Get-Service {
        param($Name,$ErrorAction)
        [pscustomobject]@{Name=$Name;StartType=$script:appIdStartType;Status=$script:appIdStatus}
    }
    function script:Start-Service { param($Name,$ErrorAction) $script:appIdStatus='Running' }
    function script:Invoke-EceniNative {
        param([string]$File,[string[]]$Arguments)
        if ($File -eq 'sc.exe' -and $Arguments[0] -eq 'config') { $script:appIdStartType='Automatic' }
        [pscustomobject]@{Code=0;Output=''}
    }
}
$a = & $module { param($l) Set-EceniCopilotAppLockerPolicy $l } $appLockerLog
$b = & $module { param($l) Set-EceniCopilotAppLockerPolicy $l } $appLockerLog
$appLockerXml = [xml](& $module { $script:appLockerText })
$appxRules = @($appLockerXml.AppLockerPolicy.RuleCollection.FilePublisherRule)
Assert ($a.Status -eq 'Changed' -and $b.Status -eq 'AlreadyOK') 'Copilot AppLocker policy and service configuration are idempotent'
Assert (@($appxRules | Where-Object { $_.Action -eq 'Deny' -and $_.Conditions.FilePublisherCondition.ProductName -eq 'MICROSOFT.COPILOT' }).Count -eq 1) 'AppLocker deny rule targets only the Microsoft Copilot package'
Assert (@($appxRules | Where-Object { $_.Action -eq 'Allow' -and $_.Conditions.FilePublisherCondition.ProductName -eq '*' }).Count -eq 1) 'Other signed packaged apps remain allowed'
Assert ((Test-Path (Join-Path $appLockerLog 'applocker-before.xml')) -and -not (Test-Path (Join-Path $appLockerLog 'eceni-copilot-applocker.xml'))) 'Existing AppLocker policy is backed up and the merge file is removed'

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

# Rocky WSL downloads are checksum-verified, installed once and made the default.
$rockyCache = Join-Path $tmp 'rocky-cache'
$rockySource = Join-Path $tmp 'rocky-source.wsl'
[IO.File]::WriteAllText($rockySource,'test Rocky WSL image')
$rockyHash = (Get-FileHash -LiteralPath $rockySource -Algorithm SHA256).Hash
& $module {
    param($source,$hash)
    $script:rockySource=$source; $script:rockyHash=$hash
    $script:rockyInstalled=@(); $script:rockyDefault=$null; $script:rockyDownloads=0
    $script:rockyNativeCalls = New-Object 'System.Collections.Generic.List[object]'
    function script:Get-EceniWslDistroNames { @($script:rockyInstalled) }
    function script:Get-EceniDefaultWslDistro { $script:rockyDefault }
    function script:Invoke-EceniDownload {
        param([string]$Uri,[string]$OutFile)
        $script:rockyDownloads++
        if ($Uri -like '*.CHECKSUM') { [IO.File]::WriteAllText($OutFile,"SHA256 = $script:rockyHash") }
        else { Copy-Item -LiteralPath $script:rockySource -Destination $OutFile }
    }
    function script:Invoke-EceniNative {
        param([string]$File,[string[]]$Arguments)
        $script:rockyNativeCalls.Add(@{File=$File;Arguments=$Arguments})
        if ($Arguments[0] -eq '--help') { return [pscustomobject]@{Code=-1;Output='--from-file --name'} }
        if ($Arguments[0] -eq '--install') { $script:rockyInstalled=@($Arguments[[Array]::IndexOf($Arguments,'--name')+1]) }
        if ($Arguments[0] -eq '--set-default') { $script:rockyDefault=$Arguments[1] }
        [pscustomobject]@{Code=0;Output=''}
    }
} $rockySource $rockyHash
$a = & $module { param($c,$r) Install-EceniRockyWsl $c -CacheRoot $r } $profile.Options.RockyWsl $rockyCache
$b = & $module { param($c,$r) Install-EceniRockyWsl $c -CacheRoot $r } $profile.Options.RockyWsl $rockyCache
$rockyCalls = & $module { $script:rockyNativeCalls.ToArray() }
Assert ($a.Status -eq 'Changed' -and $b.Status -eq 'AlreadyOK') 'Rocky WSL installation is idempotent'
Assert (@($rockyCalls | Where-Object { $_.Arguments[0] -eq '--help' }).Count -eq 1) 'Rocky WSL accepts the documented capabilities even when wsl --help returns its anomalous -1 exit code'
Assert ((& $module { $script:rockyDownloads }) -eq 2) 'Rocky WSL downloads one image and one checksum only for the initial install'
Assert (@($rockyCalls | Where-Object { $_.Arguments[0] -eq '--install' -and '--from-file' -in $_.Arguments -and '--no-launch' -in $_.Arguments -and '2' -in $_.Arguments }).Count -eq 1) 'Rocky WSL uses the modern file installer as WSL2 without launching OOBE'
Assert ((& $module { $script:rockyDefault }) -eq 'RockyLinux-10') 'Rocky Linux is made the default WSL distribution'
Assert (-not (Test-Path (Join-Path $rockyCache 'Rocky-10-WSL-Base.latest.x86_64.wsl'))) 'Verified Rocky installer cache is removed after successful registration'

# Restore the real module functions before the remaining isolated mocks.
Import-Module (Join-Path $root 'modules\Eceni.psm1') -Force
$module = Get-Module Eceni

# The No Sounds scheme clears active event mappings and logs only changed values.
$soundLog = Join-Path $tmp 'sound-logs'
New-Item -ItemType Directory -Path $soundLog -Force | Out-Null
& $module {
    $script:soundValues = @{
        'HKCU:\AppEvents\Schemes' = '.Default'
        'HKCU:\AppEvents\Schemes\Apps\.Default\DeviceConnect\.Current' = 'C:\Windows\media\Windows Hardware Insert.wav'
        'HKCU:\AppEvents\Schemes\Apps\.Default\Silent\.Current' = ''
    }
    function script:Get-ChildItem {
        param($LiteralPath,[switch]$Recurse,$ErrorAction)
        @($script:soundValues.Keys | Where-Object { $_ -like '*\.Current' } | ForEach-Object { [pscustomobject]@{PSPath=$_;PSChildName='.Current'} })
    }
    function script:Get-ItemProperty {
        param($LiteralPath,$ErrorAction)
        if (-not $script:soundValues.ContainsKey([string]$LiteralPath)) { return $null }
        $item = [pscustomobject]@{}
        $item | Add-Member -NotePropertyName '(default)' -NotePropertyValue $script:soundValues[[string]$LiteralPath]
        $item
    }
    function script:Test-Path { param($LiteralPath,$PathType) $script:soundValues.ContainsKey([string]$LiteralPath) }
    function script:New-Item { param($Path,[switch]$Force) $script:soundValues[[string]$Path]=''; [pscustomobject]@{} }
    function script:New-ItemProperty {
        param($LiteralPath,$Name,$Value,$PropertyType,[switch]$Force)
        $script:soundValues[[string]$LiteralPath]=[string]$Value
    }
    function script:Get-ItemPropertyValue { param($LiteralPath,$Name) $script:soundValues[[string]$LiteralPath] }
}
$a = & $module { param($l) Set-EceniNoSoundsScheme $l } $soundLog
$b = & $module { param($l) Set-EceniNoSoundsScheme $l } $soundLog
$soundBackups = @(Get-Content (Join-Path $soundLog 'registry-before.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
Assert ($a.Status -eq 'Changed' -and $b.Status -eq 'AlreadyOK') 'No Sounds scheme application is idempotent'
Assert ((& $module { $script:soundValues['HKCU:\AppEvents\Schemes'] }) -eq '.None') 'No Sounds becomes the selected Windows sound scheme'
Assert ((& $module { $script:soundValues.Values | Where-Object { $_ -like '*.wav' } }).Count -eq 0) 'All active Windows event sound mappings are cleared'
Assert ($soundBackups.Count -eq 2 -and @($soundBackups | Where-Object Existed).Count -eq 2) 'Changed sound scheme values are recorded before modification'

# Restore the real module functions before the remaining isolated mocks.
Import-Module (Join-Path $root 'modules\Eceni.psm1') -Force
$module = Get-Module Eceni

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
