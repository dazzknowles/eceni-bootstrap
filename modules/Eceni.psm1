Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-EceniResult {
    param([ValidateSet('Changed','AlreadyOK','Skipped','Manual','Warning','Failed')][string]$Status,[string]$Message,[bool]$RebootRequired = $false)
    [pscustomobject]@{ Status=$Status; Message=$Message; RebootRequired=$RebootRequired }
}

function Import-EceniProfile {
    param([string]$Path,[string]$Root)
    $p = Import-PowerShellDataFile -LiteralPath $Path
    foreach ($key in 'SchemaVersion','Name','SourceRoot','ConfigRoot','Roles','Options','Keep','RemoveAppx','RemoveWinGet') {
        if (-not $p.ContainsKey($key)) { throw "Profile is missing $key." }
    }
    if ($p.SchemaVersion -ne 1) { throw 'Unsupported profile schema.' }
    foreach ($pathValue in @($p.SourceRoot,$p.ConfigRoot)) {
        if ($pathValue -notmatch '^[A-Za-z]:\\[^\r\n]+$' -or $pathValue -match '(^|\\)\.\.(\\|$)') { throw "Use an absolute, non-root Windows directory: $pathValue" }
    }
    if ($p.SourceRoot.TrimEnd('\') -eq $p.ConfigRoot.TrimEnd('\')) { throw 'SourceRoot and ConfigRoot must differ.' }
    foreach ($role in $p.Roles) {
        if ($role -notmatch '^[A-Za-z][A-Za-z0-9]*$' -or -not (Test-Path -LiteralPath (Join-Path $Root "roles\$role.psd1"))) { throw "Unknown role: $role" }
    }
    foreach ($name in $p.RemoveAppx) {
        if ($name -match '[*?\[\]]' -or $name -in $p.Keep -or $name -match 'Solitaire|WindowsStore|DesktopAppInstaller|WebView') { throw "Unsafe removal entry: $name" }
    }
    if ($p.Options.NodeMajor -notmatch '^\d+$') { throw 'NodeMajor must be a numeric LTS major.' }
    foreach ($key in 'GitUserName','GitUserEmail') {
        if ($p.Options.ContainsKey($key) -and ([string]::IsNullOrWhiteSpace([string]$p.Options[$key]) -or [string]$p.Options[$key] -match '[\r\n]')) {
            throw "$key must be a non-empty single-line value."
        }
    }
    if ($p.Options.ContainsKey('GitUserName') -xor $p.Options.ContainsKey('GitUserEmail')) { throw 'GitUserName and GitUserEmail must be configured together.' }
    if ($p.Options.ContainsKey('RockyWsl')) {
        $rocky = $p.Options.RockyWsl
        foreach ($key in 'Enabled','Major','DistroName','SetDefault') {
            if (-not $rocky.ContainsKey($key)) { throw "RockyWsl is missing $key." }
        }
        if ([string]$rocky.Major -notin @('9','10')) { throw 'RockyWsl.Major must be a currently supported WSL image major: 9 or 10.' }
        if ([string]$rocky.DistroName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') { throw 'RockyWsl.DistroName contains unsafe characters.' }
    }
    if (-not $p.Options.ContainsKey('PackageVersionLocks')) { $p.Options.PackageVersionLocks = @{} }
    $knownPackageIds = @(
        foreach ($role in $p.Roles) {
            $roleData = Import-PowerShellDataFile (Join-Path $Root "roles\$role.psd1")
            foreach ($package in $roleData.Packages) { $package.Id }
        }
    )
    foreach ($entry in $p.Options.PackageVersionLocks.GetEnumerator()) {
        if ($entry.Key -notin $knownPackageIds) { throw "Version lock refers to an unknown package: $($entry.Key)" }
        if ([string]$entry.Value -notmatch '^[0-9A-Za-z][0-9A-Za-z._+-]*$') { throw "Unsafe version lock for $($entry.Key): $($entry.Value)" }
    }
    if ($p.Options.ContainsKey('TerminalProfiles')) {
        $terminal = $p.Options.TerminalProfiles
        foreach ($key in 'Enabled','CodexTabColor','ClaudeTabColor') {
            if (-not $terminal.ContainsKey($key)) { throw "TerminalProfiles is missing $key." }
        }
        foreach ($key in 'CodexTabColor','ClaudeTabColor') {
            if ([string]$terminal[$key] -notmatch '^#[0-9A-Fa-f]{6}$') { throw "TerminalProfiles.$key must be a six-digit hex colour." }
        }
    }
    return $p
}

function New-EceniOperation {
    param([string]$Stage,[string]$Kind,[string]$Name,[string]$Detail,[hashtable]$Data = @{})
    [pscustomobject]@{ Stage=$Stage; Kind=$Kind; Name=$Name; Detail=$Detail; Data=$Data }
}

function Get-EceniPlan {
    param([hashtable]$Profile,[string]$Root,[string[]]$Stage = @('All'))
    $items = New-Object 'System.Collections.Generic.List[object]'
    $items.Add((New-EceniOperation 'Foundations' 'Directory' 'Source directory' $Profile.SourceRoot @{Path=$Profile.SourceRoot}))
    if ($Profile.Roles -contains 'WindowsBase') {
        $settings = Import-PowerShellDataFile (Join-Path $Root 'config\Windows.psd1')
        foreach ($setting in $settings.Registry) {
            $items.Add((New-EceniOperation 'Windows' 'Registry' $setting.Name "$($setting.Path) [$($setting.ValueName)] = $($setting.Value)" $setting))
        }
        $items.Add((New-EceniOperation 'Windows' 'SoundScheme' 'Windows sound scheme: No Sounds' 'Select the built-in No Sounds scheme and clear active Windows event sound mappings'))
        $items.Add((New-EceniOperation 'Windows' 'NetworkProfile' 'TheBatCave network is private' 'When connected to TheBatCave, set its Windows network category to Private' @{Name='TheBatCave';Category='Private'}))
        $items.Add((New-EceniOperation 'Windows' 'RemoteDesktop' 'Allow Remote Desktop connections' 'Enable RDP host access with Network Level Authentication and the built-in TCP/UDP firewall rules' @{
            RuleNames=@('RemoteDesktop-UserMode-In-TCP','RemoteDesktop-UserMode-In-UDP')
        }))
        $items.Add((New-EceniOperation 'Windows' 'AppLocker' 'Prevent Microsoft Copilot reinstall' 'Merge a Microsoft-recommended packaged-app deny rule for Microsoft.Copilot; preserve existing AppLocker rules'))
        foreach ($name in $Profile.RemoveAppx) { $items.Add((New-EceniOperation 'Windows' 'Appx' "Remove $name" 'Current-user package only; skip if absent or protected' @{Name=$name})) }
        foreach ($package in $Profile.RemoveWinGet) { $items.Add((New-EceniOperation 'Windows' 'Uninstall' "Remove $($package.Name)" $package.Id $package)) }
        $items.Add((New-EceniOperation 'Windows' 'Feature' 'Disable Recall component' 'Recall: disabled if available; no restart' @{Name='Recall';Enabled=$false}))
        $items.Add((New-EceniOperation 'Windows' 'Power' 'Laptop display and sleep' "AC: display $($Profile.Options.MonitorMinutesAC)m / sleep $($Profile.Options.SleepMinutesAC)m; battery: display $($Profile.Options.MonitorMinutesDC)m / sleep $($Profile.Options.SleepMinutesDC)m"))
        $items.Add((New-EceniOperation 'Windows' 'Manual' 'Verify Windows Update policy' 'Download-only configured; no universal no-reboot guarantee. Check Settings and gpresult; see docs/POLICIES.md.'))
    }
    $seen = @{}
    foreach ($role in $Profile.Roles) {
        $data = Import-PowerShellDataFile (Join-Path $Root "roles\$role.psd1")
        foreach ($package in $data.Packages) {
            if ($package.ContainsKey('Optional') -and -not $Profile.Options[$package.Optional]) { continue }
            $key = $package.Source + ':' + $package.Id
            if ($seen.ContainsKey($key)) { continue }; $seen[$key] = $true
            $packageData = $package.Clone()
            $detail = "$($package.Source):$($package.Id)"
            if ($Profile.Options.PackageVersionLocks.ContainsKey($package.Id)) {
                $packageData.VersionLock = [string]$Profile.Options.PackageVersionLocks[$package.Id]
                $detail += " locked to $($packageData.VersionLock)"
            }
            $items.Add((New-EceniOperation $package.Stage 'Package' "Install $($package.Name)" $detail $packageData))
        }
        foreach ($task in $data.Manual) {
            if ($task.Name -eq 'WSL distribution' -and $Profile.Options.ContainsKey('RockyWsl') -and $Profile.Options.RockyWsl.Enabled) { continue }
            $items.Add((New-EceniOperation $task.Stage 'Manual' $task.Name ($task.Instructions + ' ' + $task.Url) $task))
        }
    }
    if ($Profile.Roles -contains 'Developer') {
        $items.Add((New-EceniOperation 'Toolchains' 'Node' 'Node LTS via NVM' "Latest LTS patch in approved major $($Profile.Options.NodeMajor); existing matching installation reused"))
        $items.Add((New-EceniOperation 'Toolchains' 'Rust' 'Rust stable toolchain' 'Install if missing; do not update existing stable toolchain'))
        $items.Add((New-EceniOperation 'Toolchains' 'VCWorkload' 'Verify C++ workload' 'MSVC x64/x86 tools and recommended Windows SDK via Visual Studio Installer'))
        $items.Add((New-EceniOperation 'Containers' 'Symlink' 'Restore symlink evaluation defaults' 'Allow local-origin links; keep remote-origin links disabled; required by Windows component servicing'))
        foreach ($name in 'Microsoft-Windows-Subsystem-Linux','VirtualMachinePlatform') { $items.Add((New-EceniOperation 'Containers' 'Feature' "Enable $name" 'Enable WSL2 prerequisite; never reboot automatically' @{Name=$name;Enabled=$true})) }
        $items.Add((New-EceniOperation 'Containers' 'Wsl2' 'Default to WSL2' 'Set default version after features/reboot, before registering Rocky Linux'))
        if ($Profile.Options.ContainsKey('RockyWsl') -and $Profile.Options.RockyWsl.Enabled) {
            $rocky = $Profile.Options.RockyWsl
            $items.Add((New-EceniOperation 'Containers' 'WslDistro' "Install Rocky Linux $($rocky.Major) for WSL" "Download the official checksum-verified WSL image and register it as $($rocky.DistroName)" $rocky))
            $items.Add((New-EceniOperation 'Containers' 'Manual' 'Finish Rocky Linux first launch' "Launch $($rocky.DistroName) once and choose its Linux username and password."))
        }
        $gitIdentity = if ($Profile.Options.ContainsKey('GitUserName')) { "; identity=$($Profile.Options.GitUserName) <$($Profile.Options.GitUserEmail)>" } else { '; identity preserved' }
        $items.Add((New-EceniOperation 'Development' 'Git' 'Configure Git and LFS' "Default branch main; long paths; autocrlf=$($Profile.Options.GitAutoCrlf); LFS filters$gitIdentity"))
        $items.Add((New-EceniOperation 'Development' 'Shell' 'PowerShell navigation and prompt' 'Append managed csrc/Oh My Posh block to PowerShell 7 profile; preserve existing content'))
        $items.Add((New-EceniOperation 'Development' 'Npm' 'pnpm' 'pnpm (current selected NVM Node)' @{Package='pnpm'}))
    }
    if ($Profile.Roles -contains 'AIWorkstation') {
        $items.Add((New-EceniOperation 'Development' 'Npm' 'Codex CLI' '@openai/codex (current selected NVM Node)' @{Package='@openai/codex'}))
        if ($Profile.Options.ContainsKey('TerminalProfiles') -and $Profile.Options.TerminalProfiles.Enabled) {
            $items.Add((New-EceniOperation 'Development' 'TerminalProfiles' 'Codex and Claude Terminal profiles' "Launch Codex and Claude Code in $($Profile.SourceRoot) with managed icons and tab colours"))
        }
    }
    $items.Add((New-EceniOperation 'Development' 'Aws' 'AWS profile scaffold' 'Example only; no credentials, region or secret ARN invented'))
    $items.Add((New-EceniOperation 'ConfigLinks' 'Links' 'Config navigation' "$($Profile.ConfigRoot): directory junctions, file shortcuts and a secrets-aware index"))
    $order = @('Windows','Foundations','Toolchains','IDEs','Database','AI','Apps','Containers','Development','ConfigLinks','Manual')
    foreach ($s in $order) {
        if ('All' -in $Stage -or $s -in $Stage) {
            $selected = @($items | Where-Object Stage -eq $s)
            if ($s -eq 'Containers') {
                # Docker can only follow the WSL features and WSL2 default.
                foreach ($kind in 'Symlink','Feature','Wsl2','WslDistro','Package','Manual') { $selected | Where-Object Kind -eq $kind }
            } else { $selected }
        }
    }
}

function Test-EceniAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-EceniOperationContext {
    param($Operation)
    if ($Operation.Kind -eq 'Registry' -and $Operation.Data.Path -like 'HKCU:*') { return 'User' }
    if ($Operation.Kind -in @('Appx','SoundScheme','Wsl2','WslDistro','Git','Rust','Shell','Npm','TerminalProfiles','Aws','Links')) { return 'User' }
    if ($Operation.Kind -in @('Package','Uninstall') -and $Operation.Data.ContainsKey('Scope') -and $Operation.Data.Scope -eq 'User') { return 'User' }
    if ($Operation.Kind -eq 'Manual') { return 'Any' }
    return 'Machine'
}

function Assert-EceniHost {
    param([ValidateSet('User','Machine')][string]$Context = 'Machine')
    if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitProcess) { throw 'Apply requires 64-bit Windows PowerShell 5.1 or PowerShell 7 on Windows.' }
    $isAdministrator = Test-EceniAdministrator
    if ($Context -eq 'Machine' -and -not $isAdministrator) { throw 'Machine-context operations require PowerShell opened as administrator using your normal Windows account.' }
    if ($Context -eq 'User' -and $isAdministrator) { throw 'User-context operations require a normal, non-elevated PowerShell window so Windows and WinGet use your desktop user token.' }
    $os = Get-CimInstance Win32_OperatingSystem
    if ([int]$os.BuildNumber -lt 22000 -or $os.ProductType -ne 1) { throw 'v0.1 Apply is supported on Windows 11 workstations only.' }
    if ($env:USERPROFILE -like '*\systemprofile') { throw 'Do not run under SYSTEM: per-user settings require your normal account.' }
}

function Invoke-EceniNative {
    param([string]$File,[string[]]$Arguments)
    if (-not (Get-Command $File -ErrorAction SilentlyContinue)) { throw "Missing command: $File. Complete prerequisite stage and open a fresh terminal." }
    # Capture a native exit code without letting stderr change PowerShell's error semantics.
    $old = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $File @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $old }
    [pscustomobject]@{ Code=$code; Output=($output -join "`n") }
}

function Assert-EceniNativeSuccess {
    param($Result,[string]$Context)
    if ($Result.Code -ne 0) { throw "$Context failed (exit $($Result.Code)): $($Result.Output)" }
}

function Assert-EceniPackageManager {
    $r = Invoke-EceniNative 'winget.exe' @('--version')
    if ($r.Code -ne 0 -or $r.Output -notmatch 'v?\d+\.\d+') { throw 'WinGet is not working. Open Microsoft Store, install/update App Installer, then reopen PowerShell. No machine changes have been applied.' }
}

function Update-EceniProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path','Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    $env:Path = [Environment]::ExpandEnvironmentVariables("$machinePath;$userPath;$env:Path")
    foreach ($name in 'NVM_HOME','NVM_SYMLINK','JAVA_HOME') {
        $value = [Environment]::GetEnvironmentVariable($name,'User')
        if (-not $value) { $value = [Environment]::GetEnvironmentVariable($name,'Machine') }
        if ($value) { [Environment]::SetEnvironmentVariable($name,$value,'Process') }
    }
    if ($env:NVM_HOME) { $env:Path = "$env:NVM_HOME;$env:NVM_SYMLINK;$env:Path" }
    $env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
}

function Get-EceniPackageState {
    param([hashtable]$Package)
    $r = Invoke-EceniNative 'winget.exe' @('list','--id',$Package.Id,'--exact','--source',$Package.Source,'--accept-source-agreements','--disable-interactivity')
    if ($r.Code -eq 0) { return $true }
    if ($r.Code -eq -1978335212) { return $false }
    throw "Cannot determine installed state of $($Package.Id) (exit $($r.Code)). $($r.Output)"
}

function Invoke-EceniPackage {
    param([hashtable]$Package,[switch]$Uninstall)
    $installed = Get-EceniPackageState $Package
    if ($Uninstall -and -not $installed) { return New-EceniResult 'AlreadyOK' 'Not installed.' }
    if (-not $Uninstall -and $installed) { return New-EceniResult 'AlreadyOK' 'Installed; no automatic upgrade or reinstall.' }
    if ($Package.Id -eq 'CoreyButler.NVMforWindows' -and (Get-Command node.exe -ErrorAction SilentlyContinue) -and -not (Get-Command nvm.exe -ErrorAction SilentlyContinue)) {
        throw 'A non-NVM Node installation exists. Resolve it before installing NVM; no automatic removal was attempted.'
    }
    $verb = 'install'; if ($Uninstall) { $verb = 'uninstall' }
    $argsList = @($verb,'--id',$Package.Id,'--exact','--source',$Package.Source,'--silent','--accept-source-agreements','--disable-interactivity')
    if (-not $Uninstall) { $argsList += '--accept-package-agreements' }
    if (-not $Uninstall -and $Package.ContainsKey('VersionLock')) { $argsList += @('--version',$Package.VersionLock) }
    if (-not $Uninstall -and $Package.ContainsKey('Override')) { $argsList += @('--override',$Package.Override) }
    $r = Invoke-EceniNative 'winget.exe' $argsList
    # Never pass --allow-reboot. Stop dependent installs if a restart is requested.
    if ($r.Code -in @(3010,-1978334967)) { return New-EceniResult 'Changed' 'Installer requested a reboot; rerun to verify after reboot.' $true }
    if ($r.Code -eq -1978334966) { return New-EceniResult 'Skipped' 'Installer requires a reboot before it can proceed. Reboot manually and rerun.' $true }
    Assert-EceniNativeSuccess $r "$verb $($Package.Id)"
    Update-EceniProcessPath
    $nowInstalled = Get-EceniPackageState $Package
    if ($nowInstalled -eq [bool]$Uninstall) { throw 'Installer returned success but the requested package state was not observed.' }
    New-EceniResult 'Changed' "$verb completed and package state verified."
}

function Update-EceniPackage {
    param([hashtable]$Package)
    if ($Package.ContainsKey('VersionLock')) { return New-EceniResult 'Skipped' "Version locked to $($Package.VersionLock); managed update skipped." }
    if (-not (Get-EceniPackageState $Package)) { return New-EceniResult 'Skipped' 'Package is not installed.' }
    $argsList = @('upgrade','--id',$Package.Id,'--exact','--source',$Package.Source,'--silent','--accept-source-agreements','--accept-package-agreements','--disable-interactivity')
    $r = Invoke-EceniNative 'winget.exe' $argsList
    if ($r.Code -eq -1978335189) { return New-EceniResult 'AlreadyOK' 'No applicable update found.' }
    if ($r.Code -in @(3010,-1978334967)) { return New-EceniResult 'Changed' 'Upgrade requested a reboot.' $true }
    if ($r.Code -eq -1978334966) { return New-EceniResult 'Skipped' 'Upgrade requires a reboot before it can proceed.' $true }
    Assert-EceniNativeSuccess $r "upgrade $($Package.Id)"
    New-EceniResult 'Changed' 'Upgrade check completed successfully.'
}

function Set-EceniRegistry {
    param([hashtable]$Setting,[string]$LogRoot)
    $Setting = $Setting.Clone()
    if ($Setting.ContainsKey('Policy') -and $Setting.Policy) {
        $edition = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
        if ($edition -like 'Core*') { return New-EceniResult 'Warning' 'Windows Home: policy support is not guaranteed; this policy was not applied.' }
        if ($Setting.ValueName -eq 'AllowTelemetry' -and $edition -match 'Enterprise|Education|IoT') { $Setting.Value = 0 }
    }
    $existing = Get-ItemProperty -LiteralPath $Setting.Path -ErrorAction SilentlyContinue
    $property = $null
    if ($existing) { $property = $existing.PSObject.Properties[$Setting.ValueName] }
    if ($property -and $property.Value -eq $Setting.Value) { return New-EceniResult 'AlreadyOK' 'Registry value matches.' }
    $backup = [ordered]@{Time=[DateTime]::UtcNow.ToString('o');Path=$Setting.Path;Name=$Setting.ValueName;Existed=($null -ne $property);Value=$null;Kind=$null}
    if ($property) { $backup.Value=$property.Value; $backup.Kind=(Get-Item -LiteralPath $Setting.Path).GetValueKind($Setting.ValueName).ToString() }
    $backup | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $LogRoot 'registry-before.jsonl') -Encoding UTF8
    if (-not (Test-Path -LiteralPath $Setting.Path)) { New-Item -Path $Setting.Path -Force | Out-Null }
    New-ItemProperty -LiteralPath $Setting.Path -Name $Setting.ValueName -Value $Setting.Value -PropertyType DWord -Force | Out-Null
    $actual = Get-ItemPropertyValue -LiteralPath $Setting.Path -Name $Setting.ValueName
    if ($actual -ne $Setting.Value) { throw 'Registry write did not persist.' }
    New-EceniResult 'Changed' 'Registry value verified; policy effectiveness depends on Windows edition/build.'
}

function Set-EceniNoSoundsScheme {
    param([string]$LogRoot)
    $schemePath = 'HKCU:\AppEvents\Schemes'
    $appsPath = Join-Path $schemePath 'Apps'
    $changes = New-Object 'System.Collections.Generic.List[object]'
    $eventChanges = 0

    $scheme = Get-ItemProperty -LiteralPath $schemePath -ErrorAction SilentlyContinue
    $schemeProperty = if ($scheme) { $scheme.PSObject.Properties['(default)'] } else { $null }
    if (-not $schemeProperty -or [string]$schemeProperty.Value -ne '.None') {
        $changes.Add([pscustomobject]@{Path=$schemePath;Value='.None';Existing=$schemeProperty})
    }
    foreach ($key in @(Get-ChildItem -LiteralPath $appsPath -Recurse -ErrorAction SilentlyContinue | Where-Object PSChildName -eq '.Current')) {
        $current = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
        $property = if ($current) { $current.PSObject.Properties['(default)'] } else { $null }
        if ($property -and [string]$property.Value) {
            $changes.Add([pscustomobject]@{Path=$key.PSPath;Value='';Existing=$property})
            $eventChanges++
        }
    }
    if (-not $changes.Count) { return New-EceniResult 'AlreadyOK' 'The No Sounds scheme is selected and active event sounds are empty.' }

    foreach ($change in $changes) {
        $backup = [ordered]@{
            Time=[DateTime]::UtcNow.ToString('o');Path=$change.Path;Name='(default)'
            Existed=($null -ne $change.Existing);Value=$null;Kind=$null
        }
        if ($change.Existing) { $backup.Value=$change.Existing.Value; $backup.Kind='String' }
        $backup | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $LogRoot 'registry-before.jsonl') -Encoding UTF8
        if (-not (Test-Path -LiteralPath $change.Path)) { New-Item -Path $change.Path -Force | Out-Null }
        New-ItemProperty -LiteralPath $change.Path -Name '(default)' -Value $change.Value -PropertyType String -Force | Out-Null
        $actual = Get-ItemPropertyValue -LiteralPath $change.Path -Name '(default)'
        if ([string]$actual -ne $change.Value) { throw "Sound scheme registry write did not persist: $($change.Path)" }
    }
    New-EceniResult 'Changed' "Selected No Sounds and cleared $eventChanges active Windows event sound mappings."
}

function Invoke-EceniAppx {
    param([string]$Name)
    $packages = @(Get-AppxPackage -Name $Name -ErrorAction Stop | Where-Object Name -eq $Name)
    if (-not $packages.Count) { return New-EceniResult 'AlreadyOK' 'Absent for the current user.' }
    $changed = $false
    foreach ($package in $packages) {
        if ($package.NonRemovable) { return New-EceniResult 'Warning' 'Windows marks this component non-removable; left intact.' }
        Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
        $changed = $true
    }
    if (@(Get-AppxPackage -Name $Name -ErrorAction Stop | Where-Object Name -eq $Name).Count) { throw 'Package still present after removal.' }
    if ($changed) { return New-EceniResult 'Changed' 'Removed from current user; provisioned image and other accounts untouched.' }
}

function Set-EceniCopilotAppLockerPolicy {
    param([string]$LogRoot)
    $allowRuleId = '{A04EAA84-4C85-4D65-9D37-ECE100000001}'
    $denyRuleId = '{A04EAA84-4C85-4D65-9D37-ECE100000002}'
    if (-not (Get-Command Get-AppLockerPolicy -ErrorAction SilentlyContinue) -or -not (Get-Command Set-AppLockerPolicy -ErrorAction SilentlyContinue)) {
        throw 'AppLocker PowerShell cmdlets are unavailable on this Windows installation.'
    }
    $currentText = [string](Get-AppLockerPolicy -Local -Xml -ErrorAction Stop)
    $current = [xml]$currentText
    $appx = @()
    if ($current.AppLockerPolicy.PSObject.Properties['RuleCollection']) {
        $appx = @($current.AppLockerPolicy.RuleCollection | Where-Object Type -eq 'Appx')
    }
    $ruleIds = @()
    if ($appx.Count -and $appx[0].PSObject.Properties['FilePublisherRule']) {
        $ruleIds = @($appx[0].FilePublisherRule | ForEach-Object Id)
    }
    $policyReady = $appx.Count -eq 1 -and $appx[0].EnforcementMode -eq 'Enabled' -and $denyRuleId -in $ruleIds
    $service = Get-Service -Name AppIDSvc -ErrorAction Stop
    $serviceReady = $service.StartType -eq 'Automatic' -and $service.Status -eq 'Running'
    if ($policyReady -and $serviceReady) { return New-EceniResult 'AlreadyOK' 'Microsoft Copilot is blocked by the enforced packaged-app policy.' }

    $changed = $false
    if (-not $policyReady) {
        $allowRule = ''
        if (-not $ruleIds.Count) {
            $allowRule = @"
    <FilePublisherRule Id="$allowRuleId" Name="Eceni: allow signed packaged apps" Description="Required baseline so adding the first Appx deny rule does not block every other packaged app." UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePublisherCondition PublisherName="*" ProductName="*" BinaryName="*">
          <BinaryVersionRange LowSection="0.0.0.0" HighSection="*" />
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
"@
        }
        $policyXml = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Appx" EnforcementMode="Enabled">
$allowRule
    <FilePublisherRule Id="$denyRuleId" Name="Eceni: block Microsoft Copilot" Description="Prevent the consumer Microsoft Copilot package from installing or running." UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePublisherCondition PublisherName="CN=MICROSOFT CORPORATION, O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US" ProductName="MICROSOFT.COPILOT" BinaryName="*">
          <BinaryVersionRange LowSection="0.0.0.0" HighSection="*" />
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
  </RuleCollection>
</AppLockerPolicy>
"@
        $backup = Join-Path $LogRoot 'applocker-before.xml'
        if (-not (Test-Path -LiteralPath $backup)) { [IO.File]::WriteAllText($backup,$currentText) }
        $policyFile = Join-Path $LogRoot 'eceni-copilot-applocker.xml'
        try {
            [IO.File]::WriteAllText($policyFile,$policyXml)
            Set-AppLockerPolicy -XmlPolicy $policyFile -Merge -Confirm:$false -ErrorAction Stop
        } finally {
            Remove-Item -LiteralPath $policyFile -Force -ErrorAction SilentlyContinue
        }
        $changed = $true
        $verified = [xml]([string](Get-AppLockerPolicy -Local -Xml -ErrorAction Stop))
        $verifiedAppx = @($verified.AppLockerPolicy.RuleCollection | Where-Object Type -eq 'Appx')
        $verifiedIds = @($verifiedAppx.FilePublisherRule | ForEach-Object Id)
        if ($verifiedAppx.Count -ne 1 -or $verifiedAppx[0].EnforcementMode -ne 'Enabled' -or $denyRuleId -notin $verifiedIds) {
            throw 'The Copilot deny rule was not present in an enforced Appx collection after merge.'
        }
    }
    $service = Get-Service -Name AppIDSvc -ErrorAction Stop
    if ($service.StartType -ne 'Automatic') {
        $r = Invoke-EceniNative 'sc.exe' @('config','AppIDSvc','start=auto')
        Assert-EceniNativeSuccess $r 'Configure Application Identity service'
        $changed = $true
    }
    $service = Get-Service -Name AppIDSvc -ErrorAction Stop
    if ($service.Status -ne 'Running') { Start-Service -Name AppIDSvc -ErrorAction Stop; $changed = $true }
    $service = Get-Service -Name AppIDSvc -ErrorAction Stop
    if ($service.StartType -ne 'Automatic' -or $service.Status -ne 'Running') { throw 'Application Identity service is not automatic and running; the Copilot block cannot be enforced.' }
    if ($changed) { return New-EceniResult 'Changed' 'Microsoft Copilot removed separately and blocked from reinstalling or running; existing AppLocker rules preserved.' }
    New-EceniResult 'AlreadyOK' 'Microsoft Copilot is blocked by the enforced packaged-app policy.'
}

function Set-EceniNetworkProfile {
    param([hashtable]$Network)
    $profiles = @(Get-NetConnectionProfile -Name $Network.Name -ErrorAction SilentlyContinue | Where-Object Name -eq $Network.Name)
    if (-not $profiles.Count) { return New-EceniResult 'Skipped' "$($Network.Name) is not currently connected." }
    if (@($profiles | Where-Object { $_.NetworkCategory.ToString() -eq 'DomainAuthenticated' }).Count) {
        return New-EceniResult 'Warning' "$($Network.Name) is domain-authenticated; Windows owns that category and it was not changed."
    }
    $change = @($profiles | Where-Object { $_.NetworkCategory.ToString() -ne $Network.Category })
    if (-not $change.Count) { return New-EceniResult 'AlreadyOK' "$($Network.Name) is already $($Network.Category)." }
    foreach ($profile in $change) {
        Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory $Network.Category -ErrorAction Stop
    }
    foreach ($profile in $change) {
        $actual = Get-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -ErrorAction Stop
        if ($actual.NetworkCategory.ToString() -ne $Network.Category) { throw "Network category did not persist for interface $($profile.InterfaceIndex)." }
    }
    New-EceniResult 'Changed' "$($Network.Name) network category verified as $($Network.Category)."
}

function Invoke-EceniFeature {
    param([hashtable]$Feature)
    $features = @(Get-WindowsOptionalFeature -Online -ErrorAction Stop)
    $found = @($features | Where-Object FeatureName -eq $Feature.Name)
    if (-not $found.Count) {
        if ($Feature.Enabled) { throw "Required Windows feature not available: $($Feature.Name)" }
        return New-EceniResult 'Skipped' 'Optional component is not available on this build.'
    }
    $state = $found[0].State.ToString()
    if ($state -like '*Pending') { return New-EceniResult 'Skipped' "Feature state $state; reboot then rerun." $true }
    $desired = 'Disabled'; if ($Feature.Enabled) { $desired = 'Enabled' }
    if ($state -eq $desired -or (-not $Feature.Enabled -and $state -eq 'DisabledWithPayloadRemoved')) { return New-EceniResult 'AlreadyOK' $state }
    if ($Feature.Enabled) { $r = Enable-WindowsOptionalFeature -Online -FeatureName $Feature.Name -All -NoRestart -ErrorAction Stop }
    else { $r = Disable-WindowsOptionalFeature -Online -FeatureName $Feature.Name -NoRestart -ErrorAction Stop }
    New-EceniResult 'Changed' "Feature requested: $desired" ([bool]$r.RestartNeeded)
}

function Set-EceniSymlinkEvaluation {
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
    $desired = [ordered]@{
        SymlinkLocalToLocalEvaluation = @{Value=1;Token='L2L:1'}
        SymlinkLocalToRemoteEvaluation = @{Value=1;Token='L2R:1'}
        SymlinkRemoteToLocalEvaluation = @{Value=0;Token='R2L:0'}
        SymlinkRemoteToRemoteEvaluation = @{Value=0;Token='R2R:0'}
    }
    $state = Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
    $changed = $false
    foreach ($name in $desired.Keys) {
        $property = if ($state) { $state.PSObject.Properties[$name] } else { $null }
        $current = if ($property) { $property.Value } else { $null }
        if ($null -eq $current -or [int]$current -ne $desired[$name].Value) {
            $r = Invoke-EceniNative 'fsutil.exe' @('behavior','set','SymlinkEvaluation',$desired[$name].Token)
            Assert-EceniNativeSuccess $r "Set symbolic link evaluation $($desired[$name].Token)"
            $changed = $true
        }
    }
    $state = Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
    foreach ($name in $desired.Keys) {
        $property = if ($state) { $state.PSObject.Properties[$name] } else { $null }
        if (-not $property -or [int]$property.Value -ne $desired[$name].Value) { throw "fsutil returned success but $name was not set to $($desired[$name].Value)." }
    }
    if (-not $changed) { return New-EceniResult 'AlreadyOK' 'Symlink evaluation is complete: local-origin links enabled and remote-origin links disabled.' }
    New-EceniResult 'Changed' 'Symlink evaluation defaults restored; reboot before Windows component servicing.' $true
}

function Set-EceniPower {
    param([hashtable]$Options,[string]$LogRoot)
    $changed = $false
    foreach ($entry in @(
        @{Sub='SUB_VIDEO';Setting='VIDEOIDLE';AC=$Options.MonitorMinutesAC;DC=$Options.MonitorMinutesDC},
        @{Sub='SUB_SLEEP';Setting='STANDBYIDLE';AC=$Options.SleepMinutesAC;DC=$Options.SleepMinutesDC}
    )) {
        $query = Invoke-EceniNative 'powercfg.exe' @('/query','SCHEME_CURRENT',$entry.Sub,$entry.Setting)
        Assert-EceniNativeSuccess $query 'Read power settings'
        # The final two hexadecimal values are AC and DC, independent of display language.
        $values = [regex]::Matches($query.Output,'0x[0-9a-fA-F]+')
        if ($values.Count -lt 2) { throw 'Cannot parse powercfg AC/DC values.' }
        $current = @([Convert]::ToInt32($values[$values.Count-2].Value,16),[Convert]::ToInt32($values[$values.Count-1].Value,16))
        $index = 0
        foreach ($mode in 'AC','DC') {
            $seconds = [int]$entry[$mode] * 60
            if ($current[$index] -ne $seconds) {
                "$($entry.Sub)/$($entry.Setting) $mode before=$($current[$index]) seconds" | Add-Content (Join-Path $LogRoot 'power-before.txt')
                $r = Invoke-EceniNative 'powercfg.exe' @("/set$($mode.ToLower())valueindex",'SCHEME_CURRENT',$entry.Sub,$entry.Setting,"$seconds")
                Assert-EceniNativeSuccess $r 'Set power timeout'; $changed = $true
            }; $index++
        }
    }
    if ($changed) {
        $r = Invoke-EceniNative 'powercfg.exe' @('/setactive','SCHEME_CURRENT'); Assert-EceniNativeSuccess $r 'Activate power settings'
        return New-EceniResult 'Changed' 'Display/sleep timeouts set; lid actions and hibernation preserved.'
    }
    New-EceniResult 'AlreadyOK' 'Power timeouts match.'
}

function Set-EceniRemoteDesktop {
    param([hashtable]$Data,[string]$LogRoot)
    $edition = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
    if ($edition -like 'Core*') { return New-EceniResult 'Warning' 'Windows Home cannot accept incoming Remote Desktop connections; no RDP settings were changed.' }
    $changed = $false
    foreach ($setting in @(
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server';ValueName='fDenyTSConnections';Value=0;Name='Allow Remote Desktop connections'},
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp';ValueName='UserAuthentication';Value=1;Name='Require Network Level Authentication'}
    )) {
        $result = Set-EceniRegistry $setting $LogRoot
        if ($result.Status -eq 'Changed') { $changed = $true }
    }
    $rules = @(Get-NetFirewallRule -Name $Data.RuleNames -ErrorAction SilentlyContinue)
    $foundNames = @($rules | Select-Object -ExpandProperty Name)
    $missing = @($Data.RuleNames | Where-Object { $_ -notin $foundNames })
    if ($missing.Count) { throw 'Built-in Remote Desktop firewall rules were not found: ' + ($missing -join ', ') }
    foreach ($rule in $rules) {
        if ($rule.Enabled.ToString() -ne 'True') {
            Enable-NetFirewallRule -Name $rule.Name -ErrorAction Stop | Out-Null
            $changed = $true
        }
    }
    $disabled = @(Get-NetFirewallRule -Name $Data.RuleNames -ErrorAction Stop | Where-Object { $_.Enabled.ToString() -ne 'True' })
    if ($disabled.Count) { throw 'One or more Remote Desktop firewall rules remain disabled.' }
    if ($changed) { return New-EceniResult 'Changed' 'Remote Desktop enabled with Network Level Authentication and built-in TCP/UDP firewall rules.' }
    New-EceniResult 'AlreadyOK' 'Remote Desktop, Network Level Authentication and firewall rules are enabled.'
}

function Get-EceniWslDistroNames {
    $r = Invoke-EceniNative 'wsl.exe' @('--list','--quiet')
    Assert-EceniNativeSuccess $r 'List WSL distributions'
    @($r.Output.Replace(([char]0).ToString(),'') -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Get-EceniDefaultWslDistro {
    $root = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
    $state = Get-ItemProperty -LiteralPath $root -ErrorAction SilentlyContinue
    if (-not $state -or -not $state.PSObject.Properties['DefaultDistribution'] -or -not $state.DefaultDistribution) { return $null }
    $distro = Get-ItemProperty -LiteralPath (Join-Path $root $state.DefaultDistribution) -ErrorAction SilentlyContinue
    if ($distro -and $distro.PSObject.Properties['DistributionName']) { return [string]$distro.DistributionName }
    $null
}

function Invoke-EceniDownload {
    param([string]$Uri,[string]$OutFile)
    $r = Invoke-EceniNative 'curl.exe' @('--fail','--location','--silent','--show-error','--output',$OutFile,$Uri)
    Assert-EceniNativeSuccess $r "Download $Uri"
}

function Install-EceniRockyWsl {
    param(
        [hashtable]$Config,
        [string]$CacheRoot = (Join-Path $env:LOCALAPPDATA 'Eceni\Downloads')
    )
    $name = [string]$Config.DistroName
    $installed = @(Get-EceniWslDistroNames)
    if ($name -in $installed) {
        if ($Config.SetDefault -and (Get-EceniDefaultWslDistro) -ne $name) {
            $r = Invoke-EceniNative 'wsl.exe' @('--set-default',$name); Assert-EceniNativeSuccess $r "Set $name as default WSL distribution"
            return New-EceniResult 'Changed' "$name was already installed and is now the default WSL distribution."
        }
        return New-EceniResult 'AlreadyOK' "$name is installed$(if ($Config.SetDefault) { ' and is the default' })."
    }

    $help = Invoke-EceniNative 'wsl.exe' @('--help')
    $helpText = $help.Output.Replace(([char]0).ToString(),'')
    # Current Store WSL builds can print complete help and still return -1.
    # Capability flags are the reliable signal; a blank/error response still fails below.
    if ($helpText -notmatch '--from-file' -or $helpText -notmatch '--name') { throw 'The installed WSL runtime does not support .wsl images. Run wsl --update, reboot if requested, then rerun Containers.' }

    $major = [string]$Config.Major
    $architecture = switch ($env:PROCESSOR_ARCHITECTURE) {
        'ARM64' { 'aarch64' }
        'AMD64' { 'x86_64' }
        default { throw "Rocky WSL images are not configured for processor architecture: $env:PROCESSOR_ARCHITECTURE" }
    }
    $fileName = "Rocky-$major-WSL-Base.latest.$architecture.wsl"
    $baseUri = "https://download.rockylinux.org/pub/rocky/$major/images/$architecture"
    $imageUri = "$baseUri/$fileName"
    $checksumUri = "$imageUri.CHECKSUM"
    New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null
    $imagePath = Join-Path $CacheRoot $fileName
    $checksumPath = $imagePath + '.CHECKSUM'

    Invoke-EceniDownload $checksumUri $checksumPath
    $checksumText = [IO.File]::ReadAllText($checksumPath)
    $match = [regex]::Match($checksumText,'(?i)\b[0-9a-f]{64}\b')
    if (-not $match.Success) { throw "Rocky's checksum file did not contain a SHA-256 value: $checksumUri" }
    $expectedHash = $match.Value.ToUpperInvariant()
    $downloadRequired = $true
    if (Test-Path -LiteralPath $imagePath -PathType Leaf) {
        $downloadRequired = (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash -ne $expectedHash
    }
    if ($downloadRequired) {
        if (Test-Path -LiteralPath $imagePath) { Remove-Item -LiteralPath $imagePath -Force }
        Invoke-EceniDownload $imageUri $imagePath
    }
    $actualHash = (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) { throw "Rocky WSL image checksum mismatch. Expected $expectedHash but downloaded $actualHash. The image was not installed." }

    $r = Invoke-EceniNative 'wsl.exe' @('--install','--from-file',$imagePath,'--name',$name,'--version','2','--no-launch')
    Assert-EceniNativeSuccess $r "Install $name"
    if ($name -notin @(Get-EceniWslDistroNames)) { throw "$name was not listed after WSL reported a successful installation." }
    if ($Config.SetDefault) {
        $r = Invoke-EceniNative 'wsl.exe' @('--set-default',$name); Assert-EceniNativeSuccess $r "Set $name as default WSL distribution"
    }
    Remove-Item -LiteralPath $imagePath,$checksumPath -Force -ErrorAction SilentlyContinue
    New-EceniResult 'Changed' "$name installed from Rocky's checksum-verified WSL image$(if ($Config.SetDefault) { ' and set as default' }). Launch it once to create the Linux user."
}

function Set-EceniGit {
    param([hashtable]$Options)
    $changed = $false
    $settings = [ordered]@{
        'init.defaultBranch' = 'main'
        'core.longpaths' = 'true'
        'core.autocrlf' = $Options.GitAutoCrlf
    }
    if ($Options.ContainsKey('GitUserName')) {
        $settings['user.name'] = $Options.GitUserName
        $settings['user.email'] = $Options.GitUserEmail
    }
    foreach ($name in $settings.Keys) {
        $r = Invoke-EceniNative 'git.exe' @('config','--global','--get',$name)
        if ($r.Code -notin @(0,1)) { Assert-EceniNativeSuccess $r 'Read Git setting' }
        if ($r.Code -ne 0 -or $r.Output.Trim() -ne $settings[$name]) {
            $r = Invoke-EceniNative 'git.exe' @('config','--global',$name,$settings[$name]); Assert-EceniNativeSuccess $r 'Write Git setting'; $changed = $true
        }
    }
    $r = Invoke-EceniNative 'git.exe' @('config','--global','--get','filter.lfs.process')
    if ($r.Code -notin @(0,1)) { Assert-EceniNativeSuccess $r 'Read LFS setting' }
    if ($r.Output.Trim() -ne 'git-lfs filter-process') {
        $r = Invoke-EceniNative 'git.exe' @('lfs','install','--skip-repo'); Assert-EceniNativeSuccess $r 'Configure Git LFS'; $changed = $true
    }
    if ($changed) { return New-EceniResult 'Changed' "Git defaults and LFS set$(if ($Options.ContainsKey('GitUserName')) { '; user identity configured' } else { '; identity preserved' }); credential helper preserved." }
    New-EceniResult 'AlreadyOK' 'Git configuration matches.'
}

function Set-EceniNode {
    param([int]$Major)
    Update-EceniProcessPath
    $r = Invoke-EceniNative 'nvm.exe' @('list'); Assert-EceniNativeSuccess $r 'List NVM versions'
    $versions = @([regex]::Matches($r.Output,"\b$Major\.\d+\.\d+\b") | ForEach-Object { [version]$_.Value } | Sort-Object -Descending)
    $changed = $false
    if ($versions.Count) { $version = $versions[0].ToString() }
    else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $releases = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -UseBasicParsing
        $release = @($releases | Where-Object { $_.lts -and $_.version -match "^v$Major\." } | Sort-Object { [version]$_.version.TrimStart('v') } -Descending | Select-Object -First 1)
        if (-not $release.Count) { throw "No LTS release found for Node major $Major." }
        $version = $release[0].version.TrimStart('v')
        $r = Invoke-EceniNative 'nvm.exe' @('install',$version,'64'); Assert-EceniNativeSuccess $r 'Install Node LTS'; $changed = $true
    }
    $current = ''
    if (Get-Command node.exe -ErrorAction SilentlyContinue) { $r = Invoke-EceniNative 'node.exe' @('--version'); if ($r.Code -eq 0) { $current=$r.Output.Trim().TrimStart('v') } }
    if ($current -ne $version) {
        if ($env:NVM_SYMLINK -and (Test-Path -LiteralPath $env:NVM_SYMLINK)) {
            $link = Get-Item -LiteralPath $env:NVM_SYMLINK -Force
            if (-not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "NVM symlink path is a real directory: $env:NVM_SYMLINK. Resolve it manually; nothing was deleted." }
        }
        $r = Invoke-EceniNative 'nvm.exe' @('use',$version,'64'); Assert-EceniNativeSuccess $r 'Select Node'; $changed = $true
    }
    Update-EceniProcessPath
    $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
    $nodeFile = if ($nodeCommand) { $nodeCommand.Source } else { $null }
    if (-not $nodeFile -and $env:NVM_SYMLINK) {
        $nvmNode = Join-Path $env:NVM_SYMLINK 'node.exe'
        if (Test-Path -LiteralPath $nvmNode -PathType Leaf) { $nodeFile = $nvmNode }
    }
    if (-not $nodeFile) { throw "NVM selected Node $version but node.exe is not present at $env:NVM_SYMLINK. Reopen an administrator terminal and rerun Toolchains." }
    $r = Invoke-EceniNative $nodeFile @('--version'); Assert-EceniNativeSuccess $r 'Verify Node'
    if ($r.Output.Trim() -ne "v$version") { throw 'NVM did not select the expected Node version; check PATH conflicts.' }
    if ($changed) { return New-EceniResult 'Changed' "Node $version ready through NVM." }
    New-EceniResult 'AlreadyOK' "Node $version already selected."
}

function Set-EceniRust {
    Update-EceniProcessPath
    $r = Invoke-EceniNative 'rustup.exe' @('toolchain','list'); Assert-EceniNativeSuccess $r 'Read Rust toolchains'
    if ($r.Output -match '(?m)^stable-') { return New-EceniResult 'AlreadyOK' 'Stable installed; project overrides/default preserved.' }
    $r = Invoke-EceniNative 'rustup.exe' @('toolchain','install','stable','--profile','default'); Assert-EceniNativeSuccess $r 'Install Rust stable'
    New-EceniResult 'Changed' 'Rust stable installed.'
}

function Set-EceniVCWorkload {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $r = Invoke-EceniNative $vswhere @('-products','*','-requires','Microsoft.VisualStudio.Component.VC.Tools.x86.x64','-property','installationPath')
    Assert-EceniNativeSuccess $r 'Check MSVC workload'
    if ($r.Output.Trim()) { return New-EceniResult 'AlreadyOK' 'MSVC workload detected.' }
    $r = Invoke-EceniNative $vswhere @('-products','Microsoft.VisualStudio.Product.BuildTools','-latest','-property','installationPath')
    Assert-EceniNativeSuccess $r 'Find Build Tools'
    if (-not $r.Output.Trim()) { throw 'Build Tools not detected. Complete its install before adding the C++ workload.' }
    $setup = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\setup.exe'
    $installPath = $r.Output.Trim()
    $process = Start-Process -FilePath $setup -ArgumentList @('modify','--installPath',('"'+$installPath+'"'),'--add','Microsoft.VisualStudio.Workload.VCTools','--includeRecommended','--quiet','--norestart') -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -eq 3010) { return New-EceniResult 'Changed' 'C++ workload requests reboot.' $true }
    if ($process.ExitCode -ne 0) { throw "Visual Studio modify failed: $($process.ExitCode)" }
    $r = Invoke-EceniNative $vswhere @('-products','*','-requires','Microsoft.VisualStudio.Component.VC.Tools.x86.x64','-property','installationPath')
    if ($r.Code -ne 0 -or -not $r.Output.Trim()) { throw 'MSVC component was not detected after modification.' }
    New-EceniResult 'Changed' 'C++ workload verified.'
}

function Set-EceniNpm {
    param([string]$Package)
    Update-EceniProcessPath
    if (-not (Get-Command nvm.exe -ErrorAction SilentlyContinue) -or -not $env:NVM_SYMLINK) { throw 'Complete the NVM/Node Toolchains stage before installing global npm tools.' }
    $node = Get-Command node.exe -ErrorAction Stop
    if (-not $node.Source.StartsWith($env:NVM_SYMLINK.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Active Node is not supplied by the configured NVM symlink; resolve PATH conflicts first.' }
    $r = Invoke-EceniNative 'npm.cmd' @('list','--global','--depth=0','--json')
    Assert-EceniNativeSuccess $r 'Read global npm packages'
    $list = $r.Output | ConvertFrom-Json
    $deps = $list.PSObject.Properties['dependencies']
    if ($deps -and $deps.Value.PSObject.Properties[$Package]) { return New-EceniResult 'AlreadyOK' 'Installed for the active Node version.' }
    $r = Invoke-EceniNative 'npm.cmd' @('install','--global',$Package); Assert-EceniNativeSuccess $r "Install $Package"
    $r = Invoke-EceniNative 'npm.cmd' @('list','--global','--depth=0',$Package,'--json'); Assert-EceniNativeSuccess $r 'Verify npm package'
    New-EceniResult 'Changed' 'Installed for the active Node version; rerun after changing Node versions.'
}

function Set-EceniShell {
    param([hashtable]$Profile,[string]$DocumentsDirectory = [Environment]::GetFolderPath('MyDocuments'))
    $folder = Join-Path $DocumentsDirectory 'PowerShell'
    $path = Join-Path $folder 'Microsoft.PowerShell_profile.ps1'
    $start = '# BEGIN ECENI BOOTSTRAP'; $end = '# END ECENI BOOTSTRAP'
    $rootQuoted = $Profile.SourceRoot.Replace("'","''")
    $block = @($start,"function csrc { Set-Location -LiteralPath '$rootQuoted' }",'if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) { oh-my-posh init pwsh | Invoke-Expression }',$end) -join "`r`n"
    $content = ''; if (Test-Path -LiteralPath $path) { $content = [IO.File]::ReadAllText($path) }
    $pattern = '(?s)' + [regex]::Escape($start) + '.*?' + [regex]::Escape($end)
    if ($content.Contains($start) -xor $content.Contains($end)) { throw 'Incomplete managed shell block; inspect profile before retrying.' }
    if ($content -match $pattern) { $updated = [regex]::Replace($content,$pattern,[System.Text.RegularExpressions.MatchEvaluator]{param($m) $block}) }
    else { $updated = $content.TrimEnd() + "`r`n`r`n" + $block + "`r`n" }
    if ($updated -eq $content) { return New-EceniResult 'AlreadyOK' 'Managed PowerShell block matches.' }
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination ($path + '.eceni-' + [guid]::NewGuid().ToString('N') + '.bak') }
    [IO.File]::WriteAllText($path,$updated,(New-Object Text.UTF8Encoding($true)))
    New-EceniResult 'Changed' 'PowerShell 7 profile updated; existing contents backed up.'
}

function Set-EceniTerminalProfiles {
    param(
        [hashtable]$Profile,
        [string]$FragmentRoot = (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Eceni'),
        [hashtable]$IconSources = $null
    )
    $settings = $Profile.Options.TerminalProfiles
    New-Item -ItemType Directory -Path $FragmentRoot -Force | Out-Null
    $changed = $false

    if ($null -eq $IconSources) {
        $IconSources = @{}
        $codexPackage = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($codexPackage) {
            $candidate = Join-Path $codexPackage.InstallLocation 'Assets\Square44x44Logo.targetsize-32_altform-unplated.png'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $IconSources.Codex = $candidate }
        }
        $claudeCommand = Get-Command 'claude.exe' -ErrorAction SilentlyContinue
        if ($claudeCommand) { $IconSources.Claude = $claudeCommand.Source }
    }

    $codexIconPath = Join-Path $FragmentRoot 'codex.png'
    if ($IconSources.Codex -and (Test-Path -LiteralPath $IconSources.Codex -PathType Leaf)) {
        $bytes = $null
        $bytes = [IO.File]::ReadAllBytes($IconSources.Codex)
        $same = (Test-Path -LiteralPath $codexIconPath -PathType Leaf) -and
            ([Convert]::ToBase64String([IO.File]::ReadAllBytes($codexIconPath)) -eq [Convert]::ToBase64String($bytes))
        if (-not $same) { [IO.File]::WriteAllBytes($codexIconPath,$bytes); $changed=$true }
    }

    $claudeIconPath = Join-Path $FragmentRoot 'claude.png'
    if ($IconSources.Claude -and (Test-Path -LiteralPath $IconSources.Claude -PathType Leaf)) {
        $bytes = $null
        if ([IO.Path]::GetExtension([string]$IconSources.Claude) -ieq '.png') {
            $bytes = [IO.File]::ReadAllBytes($IconSources.Claude)
        } else {
            Add-Type -AssemblyName System.Drawing
            $icon = [Drawing.Icon]::ExtractAssociatedIcon([string]$IconSources.Claude)
            if ($icon) {
                $bitmap = $icon.ToBitmap(); $stream = New-Object IO.MemoryStream
                try { $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png); $bytes = $stream.ToArray() }
                finally { $stream.Dispose(); $bitmap.Dispose(); $icon.Dispose() }
            }
        }
        if ($bytes) {
            $same = (Test-Path -LiteralPath $claudeIconPath -PathType Leaf) -and
                ([Convert]::ToBase64String([IO.File]::ReadAllBytes($claudeIconPath)) -eq [Convert]::ToBase64String($bytes))
            if (-not $same) { [IO.File]::WriteAllBytes($claudeIconPath,$bytes); $changed=$true }
        }
    }

    $codexIcon = if (Test-Path -LiteralPath $codexIconPath -PathType Leaf) { $codexIconPath } else { [char]::ConvertFromUtf32(0x1F916) }
    $claudeIcon = if (Test-Path -LiteralPath $claudeIconPath -PathType Leaf) { $claudeIconPath } else { [char]::ConvertFromUtf32(0x2726) }
    $profiles = @(
        [ordered]@{
            name='Codex'; guid='{4a73bc20-f2c2-4d31-a71c-e32b58d6b50e}'
            commandline='pwsh.exe -NoLogo -NoExit -Command codex'; startingDirectory=$Profile.SourceRoot
            tabTitle='Codex'; tabColor=[string]$settings.CodexTabColor; icon=$codexIcon
        },
        [ordered]@{
            name='Claude Code'; guid='{6d09b226-46a0-44e2-8393-67f0a6b15da0}'
            commandline='pwsh.exe -NoLogo -NoExit -Command claude'; startingDirectory=$Profile.SourceRoot
            tabTitle='Claude Code'; tabColor=[string]$settings.ClaudeTabColor; icon=$claudeIcon
        }
    )
    $json = ([ordered]@{profiles=$profiles} | ConvertTo-Json -Depth 6) + "`r`n"
    $fragmentPath = Join-Path $FragmentRoot 'profiles.json'
    if (-not (Test-Path -LiteralPath $fragmentPath -PathType Leaf) -or [IO.File]::ReadAllText($fragmentPath) -ne $json) {
        [IO.File]::WriteAllText($fragmentPath,$json,(New-Object Text.UTF8Encoding($false)))
        $changed = $true
    }
    if ($changed) { return New-EceniResult 'Changed' 'Windows Terminal Codex and Claude Code profiles updated.' }
    New-EceniResult 'AlreadyOK' 'Windows Terminal Codex and Claude Code profiles match.'
}

function Set-EceniAws {
    param([hashtable]$Profile)
    $folder = Join-Path $env:USERPROFILE '.aws'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $example = Join-Path $folder 'config.eceni-example'
    if (Test-Path -LiteralPath $example) { return New-EceniResult 'AlreadyOK' 'Example already present; AWS config/credentials left intact.' }
    @("# Merge this profile into config after choosing your AWS region.","[profile $($Profile.Options.AwsProfile)]",'# region = <your-region>','output = json','# Add restricted bootstrap credentials with aws configure --profile catwoman-bootstrap.','# The key may read only the selected Secrets Manager secret. Never put credentials in this repository.') | Set-Content -LiteralPath $example -Encoding UTF8
    New-EceniResult 'Changed' 'Wrote .aws/config.eceni-example; no live AWS configuration or credentials changed.'
}

function Get-EceniLinkTargets {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    @(
        @{Name='Git';Path=(Join-Path $env:USERPROFILE '.gitconfig');Secrets='Possible includes/identity'}
        @{Name='SSH';Path=(Join-Path $env:USERPROFILE '.ssh');Secrets='YES: private keys'}
        @{Name='AWS';Path=(Join-Path $env:USERPROFILE '.aws');Secrets='YES: credentials'}
        @{Name='PowerShell';Path=(Join-Path $documents 'PowerShell');Secrets='Possible'}
        @{Name='VSCode';Path=(Join-Path $env:APPDATA 'Code\User');Secrets='Possible tokens/settings'}
        @{Name='JetBrains';Path=(Join-Path $env:APPDATA 'JetBrains');Secrets='Possible'}
        @{Name='WindowsTerminal';Path=(Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState');Secrets='Possible'}
        @{Name='WindowsTerminalUnpackaged';Path=(Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal');Secrets='Possible'}
        @{Name='NVM';Path=$env:NVM_HOME;Secrets='Possible'}
        @{Name='Tailscale';Path=(Join-Path $env:LOCALAPPDATA 'Tailscale');Secrets='YES: logs/state; service state remains under ProgramData'}
        @{Name='Codex';Path=(Join-Path $env:USERPROFILE '.codex');Secrets='YES: authentication/session data'}
        @{Name='Claude';Path=(Join-Path $env:USERPROFILE '.claude');Secrets='YES: authentication/session data'}
    )
}

function Set-EceniLinks {
    param([hashtable]$Profile)
    Update-EceniProcessPath
    $root = $Profile.ConfigRoot
    if (Test-Path -LiteralPath (Join-Path $root '.git')) { throw 'ConfigRoot is a Git repository; choose a navigation-only folder outside Git.' }
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $rows = New-Object 'System.Collections.Generic.List[string]'
    $rows.Add('# Local configuration navigation')
    $rows.Add('Do not commit or copy this tree as a repository. Links expose live configuration and secrets. Missing targets are left missing; rerun ConfigLinks after first launch/sign-in.')
    $rows.Add('')
    $rows.Add('| App | Real location | Friendly location | Secrets | State |')
    $rows.Add('| --- | --- | --- | --- | --- |')
    $changed = $false; $warnings = New-Object 'System.Collections.Generic.List[string]'
    foreach ($target in Get-EceniLinkTargets) {
        $dest = Join-Path $root $target.Name; $state = 'Missing; rerun later'
        if ($target.Path -and (Test-Path -LiteralPath $target.Path)) {
            $source = Get-Item -LiteralPath $target.Path -Force
            if ($source.PSIsContainer) {
                $existing = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
                if ($existing) {
                    if ($existing.LinkType -eq 'Junction' -and @($existing.Target)[0].TrimEnd('\') -eq $source.FullName.TrimEnd('\')) { $state='Already linked' }
                    else { $state='Conflict: preserved'; $warnings.Add($target.Name) }
                } else { New-Item -ItemType Junction -Path $dest -Target $source.FullName | Out-Null; $changed=$true; $state='Linked' }
            } else {
                $dest += '.lnk'
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($dest)
                if (Test-Path -LiteralPath $dest) {
                    if ($shortcut.TargetPath -eq $source.FullName) { $state='Already linked' }
                    else { $state='Conflict: preserved'; $warnings.Add($target.Name) }
                } else { $shortcut.TargetPath=$source.FullName; $shortcut.Save(); $changed=$true; $state='Shortcut' }
                [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
            }
        }
        $rows.Add("| $($target.Name) | $($target.Path) | $dest | $($target.Secrets) | $state |")
    }
    # Stable state labels ensure a second run doesn't rewrite an otherwise identical index.
    $text = ($rows -join "`r`n").Replace('Already linked','Linked').Replace('| Shortcut |','| Linked |') + "`r`n"
    $readme = Join-Path $root 'README.md'
    if ((Test-Path -LiteralPath $readme) -and -not ([IO.File]::ReadAllText($readme).StartsWith('# Local configuration navigation'))) { throw 'Existing Config README is not managed by Eceni; preserved.' }
    if (-not (Test-Path -LiteralPath $readme) -or [IO.File]::ReadAllText($readme) -ne $text) { [IO.File]::WriteAllText($readme,$text); $changed=$true }
    $ignore = Join-Path $root '.gitignore'
    if (-not (Test-Path -LiteralPath $ignore)) { [IO.File]::WriteAllText($ignore,"*`r`n"); $changed=$true }
    if ($warnings.Count) { return New-EceniResult 'Warning' ("Existing paths preserved: " + ($warnings -join ', ')) }
    if ($changed) { return New-EceniResult 'Changed' 'Navigation links/index created. Missing targets are listed for a later rerun.' }
    New-EceniResult 'AlreadyOK' 'Navigation links and index match.'
}

function Invoke-EceniOperation {
    param($Operation,[hashtable]$Profile,[string]$LogRoot)
    switch ($Operation.Kind) {
        'Manual' { return New-EceniResult 'Manual' $Operation.Detail }
        'Directory' {
            if (Test-Path -LiteralPath $Operation.Data.Path -PathType Container) { return New-EceniResult 'AlreadyOK' 'Directory exists.' }
            New-Item -ItemType Directory -Path $Operation.Data.Path -Force | Out-Null
            return New-EceniResult 'Changed' 'Directory created.'
        }
        'Registry' { return Set-EceniRegistry $Operation.Data $LogRoot }
        'SoundScheme' { return Set-EceniNoSoundsScheme $LogRoot }
        'Appx' { return Invoke-EceniAppx $Operation.Data.Name }
        'AppLocker' { return Set-EceniCopilotAppLockerPolicy $LogRoot }
        'NetworkProfile' { return Set-EceniNetworkProfile $Operation.Data }
        'Package' { return Invoke-EceniPackage $Operation.Data }
        'Uninstall' { return Invoke-EceniPackage $Operation.Data -Uninstall }
        'Symlink' { return Set-EceniSymlinkEvaluation }
        'Feature' { return Invoke-EceniFeature $Operation.Data }
        'Wsl2' {
            $state = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue
            if ($state -and $state.PSObject.Properties['DefaultVersion'] -and $state.DefaultVersion -eq 2) { return New-EceniResult 'AlreadyOK' 'WSL2 is the default.' }
            $r = Invoke-EceniNative 'wsl.exe' @('--set-default-version','2'); Assert-EceniNativeSuccess $r 'Set WSL2 default'
            return New-EceniResult 'Changed' 'Default version is WSL2.'
        }
        'WslDistro' { return Install-EceniRockyWsl $Operation.Data }
        'Power' { return Set-EceniPower $Profile.Options $LogRoot }
        'RemoteDesktop' { return Set-EceniRemoteDesktop $Operation.Data $LogRoot }
        'Git' { return Set-EceniGit $Profile.Options }
        'Node' { return Set-EceniNode $Profile.Options.NodeMajor }
        'Rust' { return Set-EceniRust }
        'VCWorkload' { return Set-EceniVCWorkload }
        'Npm' { return Set-EceniNpm $Operation.Data.Package }
        'Shell' { return Set-EceniShell $Profile }
        'TerminalProfiles' { return Set-EceniTerminalProfiles $Profile }
        'Aws' { return Set-EceniAws $Profile }
        'Links' { return Set-EceniLinks $Profile }
        default { throw "Unsupported operation: $($Operation.Kind)" }
    }
}

Export-ModuleMember -Function Import-EceniProfile,Get-EceniPlan,Get-EceniOperationContext,Test-EceniAdministrator,Assert-EceniHost,Assert-EceniPackageManager,Invoke-EceniOperation,Update-EceniPackage,New-EceniResult
