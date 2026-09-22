# Eceni Bootstrap 0.1.0 — Catwoman

A reusable Windows provisioning framework with a Catwoman machine profile, recovered from **Incubator III Continuation**, including the final Bruno, NVIDIA Studio and config-navigation additions. Catwoman is the first profile; the framework is named for Eceni.

**Default execution only displays a plan.** No installation, registry change, directory creation, download, UAC prompt or log write occurs until `-Apply` is supplied. The project has been tested without applying it to this workstation. Actual installers and Windows policy effectiveness still need a staged Catwoman run.

## Put the project on D:

If this release is still in the Codex output folder, run its copy helper from PowerShell:

```powershell
& .\tools\Copy-Project.ps1
```

It creates `D:\Source\eceni-bootstrap`, copies the release and verifies file hashes. It stops if the destination contains existing work. No provisioning runs during the copy. Skip this step when the project is already in `D:\Source\eceni-bootstrap`.

## First run

Use 64-bit Windows PowerShell 5.1 (included in Windows) or PowerShell 7. Operations are labelled `User` or `Machine`. Run user operations from a normal PowerShell window so HKCU, AppX and user-scoped WinGet packages use your desktop token. Run machine operations from PowerShell opened **as administrator using your normal Windows account**; do not use SYSTEM or a different administrator account. The script does not elevate itself or retry UAC. Windows 11 workstation is the supported v0.1 target; Windows Pro or above is needed for the intended policy controls.

```powershell
Set-Location D:\Source\eceni-bootstrap
.\Bootstrap.ps1                              # Read-only complete plan
.\Bootstrap.ps1 -Stage Foundations           # Read-only stage preview
.\tools\Verify-Packages.ps1                  # Live catalogue check; no installs
.\Bootstrap.ps1 -Apply -Stage Windows -Context User       # normal window
.\Bootstrap.ps1 -Apply -Stage Windows -Context Machine    # administrator window
.\Bootstrap.ps1 -Apply -Stage Foundations -Context Machine
```

If script execution is blocked, launch a session with `powershell.exe -NoProfile -ExecutionPolicy Bypass` for this reviewed local release. No permanent execution-policy change is needed. If WinGet is missing/broken, install or update **App Installer** from Microsoft Store and reopen PowerShell. Package stages check that WinGet runs before applying changes.

`-Context Auto` is the default for Apply: it selects `User` in a normal window and `Machine` in an elevated window, and reports how many operations belong in the other context. `-Context User` refuses elevation; `-Context Machine` requires it. The read-only plan shows each operation's context.

The actual context split is:

| Stage | Context |
| --- | --- |
| Windows | User and Machine |
| Foundations | Machine |
| Toolchains | Machine and User |
| IDEs, Database, AI | Machine, plus displayed manual items where applicable |
| Apps | Machine and User |
| Containers | Machine and User |
| Development, ConfigLinks | User |
| Manual | Read-only follow-up list |

Continue one stage at a time when running `Bootstrap.ps1` directly. Run Windows, Toolchains, Apps and Containers in both contexts. The Apps user pass installs the Microsoft Store NVIDIA App with the desktop user's Store identity. Containers must run its machine work before its user work: symlink evaluation and WSL features are machine-scoped, while setting WSL2 as the default and registering Rocky Linux are user-scoped. After a reboot request, reboot yourself and rerun that stage. Open a fresh terminal after foundations or runtime installs if PATH still needs refreshing.

On a fresh Windows installation, finish Windows Update and driver installation and clear all pending restarts before Codex's first launch. Its one-time sandbox setup requests administrator approval and can loop if Windows is still servicing the machine. Recovery steps are in [the follow-up checklist](docs/POST-INSTALL.md#codex-first-launch-and-uac).

```powershell
.\Bootstrap.ps1 -Apply -Stage Toolchains -Context Machine   # administrator window
.\Bootstrap.ps1 -Apply -Stage Toolchains -Context User      # normal window
.\Bootstrap.ps1 -Apply -Stage IDEs
.\Bootstrap.ps1 -Apply -Stage Database
.\Bootstrap.ps1 -Apply -Stage AI
.\Bootstrap.ps1 -Apply -Stage Apps -Context Machine       # administrator window
.\Bootstrap.ps1 -Apply -Stage Apps -Context User          # normal window; includes NVIDIA App
.\Bootstrap.ps1 -Apply -Stage Containers -Context Machine   # administrator window; reboot if requested
.\Bootstrap.ps1 -Apply -Stage Containers -Context User      # normal window, after any reboot
wsl -d RockyLinux-10                                        # first launch: choose Linux username/password
.\Bootstrap.ps1 -Apply -Stage Development
.\Bootstrap.ps1 -Apply -Stage ConfigLinks
.\Bootstrap.ps1 -Stage Manual
```

Run each explicitly labelled Machine command in an administrator window and each User command in a normal window. If the Containers machine pass requests a reboot, reboot before its user pass; the latter downloads, verifies and registers Rocky Linux. The final `wsl` command completes Rocky's interactive first-launch account setup.

`-Apply -WhatIf` is also read-only. `-Stage` accepts multiple stage names. A stage does not silently install all earlier prerequisites: complete Foundations before Toolchains, then Development after Toolchains and Apps. `-Apply` without `-Stage` executes all stages in the order above. Prefer separate stages for the first run.

## One-command setup

From a normal, non-administrator PowerShell window, preview the two execution batches:

```powershell
.\tools\Install-All.ps1
```

Apply the complete automated portion with:

```powershell
.\tools\Install-All.ps1 -Apply
```

The launcher requests one UAC approval for the machine batch, waits for it, then runs the user batch with the original desktop token. It never bypasses UAC or reboots automatically. If Windows or an installer requests a reboot, the launcher stops; reboot manually and run the same command again. Completed operations are designed to be idempotent. Manual downloads, sign-ins, licence choices, Store entitlement and hardware-specific choices remain in the follow-up list.

## Managed application updates

Preview updates for the exact package IDs managed by the profile:

```powershell
.\tools\Update-Packages.ps1
```

Run the updates from a normal PowerShell window:

```powershell
.\tools\Update-Packages.ps1 -Apply
```

The updater requests elevation only for machine-scoped packages, processes each exact ID separately, uses silent/non-interactive WinGet flags, never uses `--force`, and stops when a reboot is required. It does not update manual installations such as ChatGPT, dbForge or Toolbox-managed IDEs; use those vendors' own update mechanisms. Store and vendor self-updaters can also operate independently of this script.

To lock a managed package, add its exact WinGet ID and exact version to `Options.PackageVersionLocks` in `profiles\Catwoman.psd1`:

```powershell
PackageVersionLocks = @{
    'Microsoft.PowerToys' = '0.95.1'
}
```

A lock pins a fresh bootstrap install to that version and makes the managed updater skip the package. It does not downgrade an existing installation and cannot prevent a Store app or vendor self-updater from changing itself outside Eceni. Remove the entry when the package may update again.

## What is included

| Stage | Work |
| --- | --- |
| Windows | Exact current-user removal list including Xbox Live, Weather, Sticky Notes and LinkedIn; Copilot removal plus an AppLocker reinstall block; dark mode; Explorer preferences with desktop icons hidden; complete **No Sounds** Windows sound scheme plus notification sounds off; TheBatCave set Private when connected; hidden taskbar search/Widgets button/window-sharing while the Widgets board remains available; privacy/suggestions; download-and-notify Windows Update policy with the selected restart-notification controls; long paths; Developer Mode; Fast Startup off; Recall feature disabled; laptop power defaults |
| Foundations | Source directory, PowerShell 7, Terminal, Git/LFS, GitHub CLI/Desktop, 1Password, AWS CLI v2 |
| Toolchains | NVM plus Node 24 LTS, .NET 10 SDK, Python 3.14, uv, Temurin JDK 25 LTS, Go, Rust stable, C++ Build Tools and recommended SDK, CMake |
| IDEs | VS Code and JetBrains Toolbox; all nine requested JetBrains products are listed for installation through Toolbox |
| Database | SSMS 22 and Bruno; explicit dbForge and MariaDB-client follow-up |
| AI | Claude desktop and Claude Code; current ChatGPT desktop download is a manual step |
| Apps | Termius, Oh My Posh, Notepad++, CopyQ, Steam, PowerToys, Chrome, Google Drive for desktop, EarTrumpet, SteelSeries GG, Tailscale, Windscribe, NVIDIA App, MSI Center, Apple Music, WhatsApp, Paste File and Simple Screen Ruler; Store apps use their verified product IDs |
| Containers | Machine-scoped symlink repair, WSL/Virtual Machine Platform features and Docker Desktop; user-scoped WSL2 default; checksum-verified Rocky Linux 10 WSL image, registered as the default distro |
| Development | Git defaults/LFS and global identity for Dazz Knowles, PowerShell `csrc` navigation helper and Oh My Posh initialization, pnpm, Codex CLI, Codex/Claude Windows Terminal profiles, credential-free AWS profile example |
| ConfigLinks | Flat navigation tree at `D:\Config`; directory junctions and file shortcuts; generated location/secrets index |
| Manual | Sign-ins, defaults, NVIDIA Studio selection, MSI/SteelSeries optional feature selection, Quick Access, development-location preferences |

The exact package manifest lives in `roles/`. Every item from the discussion is either implemented or explicitly listed in [the follow-up checklist](docs/POST-INSTALL.md). No MariaDB server, Office install/removal, or old context-menu hack is included. Solitaire, Calculator, Photos, Paint, Snipping Tool, Camera, Store and App Installer stay. Edge/WebView2 remain unless Windows offers a supported Edge uninstall.

## Edit preferences and reuse

Edit `profiles/Catwoman.psd1`: paths, role selection, Node major, Rocky WSL major/name/default choice, Docker toggle, package version locks, Git line endings, power timeouts and Explorer restart preference are near the top. Rocky major 10 is the default; major 9 is also accepted. Default timeouts are AC display 20 minutes/sleep 60 minutes; battery display 10 minutes/sleep 20 minutes. These are initial implementation choices because exact timings were not specified. The new Windows 11 context menu is untouched.

`config/Windows.psd1` contains named registry preferences. `roles/*.psd1` contains package and manual entries. `modules/Eceni.psm1` implements the operations. To add another workstation, copy the profile and supply `-Profile .\profiles\Other.psd1`. Future Linux/server engines are an architectural extension, not a claim of v0.1 support.

WinGet installations use exact IDs and, unless a profile lock is present, the current source release. Normal bootstrap reruns do not implicitly upgrade installed packages; `Update-Packages.ps1` is the explicit update path. Major-version package IDs bound .NET, Python and Java. NVM chooses an installed matching Node 24 version, or the latest 24.x LTS patch when absent. Existing stable Rust is retained. This is a repeatable desired-state baseline, **not a byte-for-byte locked image**. Global npm tools are per selected Node version; rerun Development after switching versions.

The Development user-context pass adds separate **Codex** and **Claude Code** Windows Terminal profiles through an Eceni JSON fragment, leaving the main Terminal `settings.json` untouched. Both start in `SourceRoot`; their tab colours are configured under `Options.TerminalProfiles`. Where available, the official installed application icons are copied locally beside the fragment, with built-in glyph fallbacks when an application icon is not yet available. Rerun Development after installing or updating the desktop/CLI applications to refresh the icons.

## Results, reruns and recovery

Each Apply operation returns `Changed`, `AlreadyOK`, `Skipped`, `Manual`, `Warning` or `Failed`. Setup reports are written incrementally to `logs/<run>.jsonl`, and updater reports to `logs/updates-<run>.jsonl`. Registry values before changes are appended to `logs/registry-before.jsonl`; power settings get a before-state file; an existing PowerShell profile gets a uniquely named backup before editing. Keep these local. No credentials are read into reports.

Failed operations do not become success markers. Reruns inspect live state. Package queries distinguish absence from source failure; successful installs are checked again. A failed operation does not stop unrelated operations; the final exit code is 1. Exit 3010 requests a manual reboot, after which the same stage should be rerun. Exit 0 means no operation failed, **not that manual or warning items are finished**. The script never reboots, never passes WinGet `--allow-reboot`, and defers dependent installer/CLI steps after a reboot request.

For a setting rollback, consult the before-state record: restore the old value and type when `Existed` was true, or remove the added value when false. Records are append-only, so use the record preceding the run you want to undo. This is not an automatic transaction rollback; app removals may require Store reinstallation. Config links never move real files and preserve conflicting paths. Missing targets are listed in the index and linked on a later rerun. `D:\Config` is navigation into live secrets, not a Git repository or backup set.

See [Windows policy limitations](docs/POLICIES.md) before relying on update/restart behaviour. Registry write verification does not prove the OS honours a policy.

## Validation and release

```powershell
.\tests\Test-Bootstrap.ps1
```

The dependency-free suite exercises planning, stage selection, rejected unsafe removals, package failures/reboots/postconditions, folder idempotence and config-link conflicts using mocks and temporary files. It runs on Windows PowerShell 5.1 and PowerShell 7 without administrator rights. Live installations, hardware drivers, Store entitlement and post-reboot OS behaviour require the first Catwoman acceptance run. [Source verification](docs/SOURCES.md) records catalogue and vendor checks.

No credentials, cloud infrastructure, purchase or subscription is created by the bootstrap. Release publication and any future ZIP/S3 distribution are separate operations.
