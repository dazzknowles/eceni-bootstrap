# Installation sources and verification

Checked against primary vendor/catalogue sources on 16–18 September 2026. All 34 listed WinGet package directories returned HTTP 200 from Microsoft's official winget-pkgs repository. This confirms catalogue identifiers, not successful installation on Catwoman. Run tools/Verify-Packages.ps1 against the live WinGet sources before Apply; Store eligibility and installer availability can still vary.

| Package ID | Official catalogue |
| --- | --- |
| Microsoft.PowerShell | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/PowerShell) |
| Microsoft.WindowsTerminal | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/WindowsTerminal) |
| Git.Git | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/g/Git/Git) |
| GitHub.GitLFS | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/g/GitHub/GitLFS) |
| GitHub.cli | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/g/GitHub/cli) |
| GitHub.GitHubDesktop | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/g/GitHub/GitHubDesktop) |
| AgileBits.1Password | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/a/AgileBits/1Password) |
| Amazon.AWSCLI | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/a/Amazon/AWSCLI) |
| CoreyButler.NVMforWindows | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/c/CoreyButler/NVMforWindows) |
| Microsoft.DotNet.SDK.10 | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/DotNet/SDK/10) |
| Python.Python.3.14 | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/p/Python/Python/3/14) |
| astral-sh.uv | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/a/astral-sh/uv) |
| EclipseAdoptium.Temurin.25.JDK | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/e/EclipseAdoptium/Temurin/25/JDK) |
| GoLang.Go | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/g/GoLang/Go) |
| Rustlang.Rustup | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/r/Rustlang/Rustup) |
| Microsoft.VisualStudio.2022.BuildTools | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/VisualStudio/2022/BuildTools) |
| Kitware.CMake | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/k/Kitware/CMake) |
| JetBrains.Toolbox | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/j/JetBrains/Toolbox) |
| Microsoft.VisualStudioCode | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/VisualStudioCode) |
| Microsoft.SQLServerManagementStudio.22 | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/SQLServerManagementStudio/22) |
| Bruno.Bruno | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/b/Bruno/Bruno) |
| Anthropic.Claude | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/a/Anthropic/Claude) |
| Anthropic.ClaudeCode | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/a/Anthropic/ClaudeCode) |
| Termius.Termius | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/t/Termius/Termius) |
| JanDeDobbeleer.OhMyPosh | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/j/JanDeDobbeleer/OhMyPosh) |
| Notepad++.Notepad++ | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/n/Notepad++/Notepad++) |
| hluk.CopyQ | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/h/hluk/CopyQ) |
| Valve.Steam | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/v/Valve/Steam) |
| Microsoft.PowerToys | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/PowerToys) |
| Google.Chrome | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/g/Google/Chrome) |
| File-New-Project.EarTrumpet | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/f/File-New-Project/EarTrumpet) |
| Tailscale.Tailscale | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/t/Tailscale/Tailscale) |
| Windscribe.Windscribe | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/w/Windscribe/Windscribe) |
| Docker.DockerDesktop | [Manifest directory](https://github.com/microsoft/winget-pkgs/tree/master/manifests/d/Docker/DockerDesktop) |

Docker is verified but opt-in. The VS Build Tools entry supplies the C++ workload and recommended components; an additional workload check handles an existing installation missing MSVC.

## Other sources

- [NVIDIA App](https://apps.microsoft.com/detail/xp8clzl93f5z4p), [Apple Music](https://apps.microsoft.com/detail/9pfhdd62mxs1), [WhatsApp](https://apps.microsoft.com/detail/9nksqgp7f2nh), [Paste File for File Explorer](https://apps.microsoft.com/detail/9pp2mwpbzfgh), [Simple Screen Ruler](https://apps.microsoft.com/detail/9wzdncrdhvfg): verified official Store product pages and IDs. Entitlement/region/payment requirements are handled by Store; the bootstrap does not purchase apps.
- [JetBrains Toolbox installation](https://www.jetbrains.com/help/toolbox-app/installation.html): Toolbox owns the requested IDEs; choose them after sign-in. v0.1 does not use undocumented Toolbox automation APIs.
- [dbForge download](https://www.devart.com/dbforge/mysql/studio/download.html) and [command-line installer documentation](https://docs.devart.com/studio-for-mysql/getting-started/installing-from-the-command-line.html): manual vendor installation in v0.1. The official WinGet Devart namespace contained TMetric, not a verified dbForge MySQL package.
- [Claude Code setup](https://code.claude.com/docs/en/setup): official WinGet distribution is Anthropic.ClaudeCode.
- [Codex CLI](https://learn.chatgpt.com/docs/codex/cli): npm package @openai/codex; installed only after the selected NVM Node is active.
- [Windows Terminal JSON fragments](https://learn.microsoft.com/windows/terminal/json-fragment-extensions) and [profile settings](https://learn.microsoft.com/windows/terminal/customize-settings/profile-general): user-local profiles, starting directories and icons without replacing the user's main settings file.
- [Windows Terminal appearance settings](https://learn.microsoft.com/windows/terminal/customize-settings/profile-appearance): profile-specific tab colours.
- [Rocky Linux download](https://rockylinux.org/download), [official Rocky WSL image repository](https://download.rockylinux.org/pub/rocky/10/images/x86_64/) and [Rocky WSL release documentation](https://docs.rockylinux.org/releases/9_6/): the Containers user pass downloads the current image for the configured supported major and verifies its adjacent published SHA-256 checksum.
- [Microsoft WSL custom distribution documentation](https://learn.microsoft.com/windows/wsl/build-custom-distro): `.wsl` images install with `wsl --install --from-file`; Eceni also supplies a stable distro name, WSL2, and `--no-launch` so username/password creation remains an explicit first launch.
- [ChatGPT download](https://chatgpt.com/download/): follow-up instead of assuming the old Store product. [9NT1R1C2HH7J](https://apps.microsoft.com/detail/9nt1r1c2hh7j) was labelled ChatGPT Classic at verification.
- [NVM for Windows](https://github.com/coreybutler/nvm-windows): manage Node side by side; do not install a standalone Node package alongside NVM. [Node release index](https://nodejs.org/dist/index.json) resolves a current patch only within the profile's approved LTS major.
- [NVIDIA App](https://apps.microsoft.com/detail/xp8clzl93f5z4p) is installed for the desktop user through its Microsoft Store product ID `XP8CLZL93F5Z4P`. Hardware-specific [Studio driver selection](https://www.nvidia.com/en-gb/drivers/) remains manual.
- [Get-NetConnectionProfile](https://learn.microsoft.com/en-us/powershell/module/netconnection/get-netconnectionprofile) and [Set-NetConnectionProfile](https://learn.microsoft.com/en-us/powershell/module/netconnection/set-netconnectionprofile): when the exact active profile `TheBatCave` exists, its network category is set to Private; disconnected and domain-authenticated profiles are not changed.
- [WinGet upgrade](https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade) and [pinning](https://learn.microsoft.com/en-us/windows/package-manager/winget/pinning): managed updates target exact IDs individually; profile locks exclude a package from this updater. WinGet notes that vendor self-updates can occur outside its pinning controls.
- [WinGet return codes](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/AppInstallerErrors.h): absence is 0x8A150014; no applicable update is 0x8A15002B; reboot-to-finish is 0x8A150109; reboot-before-install is 0x8A15010A. Other failures are not treated as success.

Windows policy sources and applicability are documented in POLICIES.md. GitHub directory checks were performed using the official API, without installing packages. The local WinGet executable could not run successfully in this Codex environment, so live winget show/install checks were not claimed.
