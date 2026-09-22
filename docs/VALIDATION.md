# v0.1 validation — 22 September 2026

- PowerShell 7.6.5 and Windows PowerShell 5.1.26100.9444: **114 checks passed** under each runtime.
- All PowerShell source files parse with the declared Windows PowerShell 5.1-compatible syntax.
- Default Catwoman plan: **152 operations** across 11 stages, including explicitly manual/deferred items.
- Microsoft official WinGet repository: **36 package IDs verified**, including Docker Desktop. Six additional Microsoft Store utility/media IDs are managed by exact product ID.
- Copy helper: `-WhatIf` created no destination; real copy to an isolated workspace test directory copied and SHA-256 verified all release files present at the time of testing. Existing destination contents are rejected.
- Bootstrap default and `-Apply -WhatIf` generated plans without creating logs or applying changes.
- Package install/update/version-lock/error/reboot tests use mocks. Windows feature, network-profile and registry tests use mocks. Directory/junction/profile tests use isolated scratch paths.
- One-command setup preview covers the machine and user batches, including both Containers contexts. The updater preview covers the exact managed package allowlist without making changes.

The first Catwoman acceptance run successfully installed the Foundations, Toolchains, IDEs and Database packages listed in its reports. It exposed a Windows-stage context defect: several HKCU Explorer writes were denied and WinGet refused to remove the user-scoped OneDrive package from an elevated token. The bootstrap now classifies operations as `User` or `Machine`, enforces the matching terminal context and has regression coverage for that routing. Toolchains also now verifies Node directly through `NVM_SYMLINK` after a same-process NVM install.

The working project is now in `D:\Source\eceni-bootstrap`. The copy helper remains for moving a clean release into that location when starting elsewhere.

First acceptance pass: preview, run live package verification, then use either the documented per-stage context commands or `tools\Install-All.ps1 -Apply` from a normal PowerShell window. Review `Manual`, `Warning`, `Failed` and reboot-required results. Rerun after any requested reboot to verify remaining changes have converged. Complete Toolbox, distro, driver, identity and application sign-in steps from POST-INSTALL.md.
