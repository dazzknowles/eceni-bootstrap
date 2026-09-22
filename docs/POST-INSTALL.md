# Catwoman follow-up checklist

These are intentional v0.1 manual/deferred items, not silently completed installs. Preview with `Bootstrap.ps1 -Stage Manual`; IDE, database and container follow-ups also appear with their own stages.

## Codex first launch and UAC

Finish Windows Update and driver installation, then reboot until Windows no longer reports an update or restart in progress **before launching Codex for the first time**. Codex creates its managed Windows sandbox accounts during first launch, and that one-time setup needs an administrator approval. Approve the prompt once and allow setup to finish; repeatedly pressing the setup control can queue duplicate attempts while Windows is still servicing the machine.

If the prompt loops or setup appears stuck:

1. Close Codex.
2. Let Windows Update finish, including driver installs, and restart Windows.
3. Open Codex again and allow the sandbox setup to resume.
4. Run `codex doctor` in a normal terminal if Codex still reports that setup is incomplete.

Do not disable UAC, lower its notification level, delete the Codex sandbox accounts, or keep reinstalling the Store app. Those actions do not resolve a pending Windows servicing operation. A completed setup normally leaves the `CodexSandboxUsers` local group and the managed `CodexSandboxOffline` and `CodexSandboxOnline` accounts in place for later launches.

- [ ] In JetBrains Toolbox, sign in and install Rider, DataGrip, dotMemory, dotTrace, GoLand, WebStorm, PyCharm, IntelliJ IDEA and RustRover. Toolbox owns their updates and licensing.
- [ ] Install [dbForge Studio for MySQL](https://www.devart.com/dbforge/mysql/studio/download.html) using your licence or chosen trial. The official installer supports `/verysilent`; v0.1 leaves vendor download/licensing interactive instead of guessing a package ID or unattended edition. No payment is made by this project.
- [ ] Launch `RockyLinux-10` once after the Containers stage and any requested reboot, then choose its Linux username and password. The bootstrap downloads Rocky's official WSL image, verifies its published SHA-256 checksum, installs it without launching the interactive first-run flow, and makes it the default distro.
- [ ] Install MariaDB **client** tools inside Rocky (`sudo dnf install mariadb`). Do not install a native Windows MariaDB server. DataGrip and dbForge supply GUI access.
- [ ] Launch Docker Desktop after the Containers stage and any requested reboot. Accept its required terms, confirm it is using the WSL 2 backend, and enable Rocky integration under **Settings > Resources > WSL Integration** if you want to run Docker commands from `RockyLinux-10`.
- [ ] Install the current [ChatGPT Windows app](https://chatgpt.com/download/). The previously used Store ID `9NT1R1C2HH7J` is now labelled **ChatGPT Classic**, so v0.1 does not silently choose it.
- [ ] Select the correct notebook GPU/Windows version at [NVIDIA Drivers](https://www.nvidia.com/en-gb/drivers/) and install the **Studio Driver**. Game Ready is not the baseline.
- [ ] Launch MSI Center and SteelSeries GG. Accept their required vendor terms, then enable only the hardware, lighting and audio modules you need. Review MSI Center's driver suggestions rather than allowing it to replace the selected NVIDIA Studio Driver automatically.
- [ ] Sign in to 1Password, GitHub, Google Drive for desktop, JetBrains, Claude/Claude Code, ChatGPT/Codex, Tailscale, Windscribe, Steam and Store apps as needed. For Google Drive, choose streaming or mirroring deliberately; streaming is Google's default and uses less local storage. Store entitlement/region or paid utility purchases remain interactive.
- [ ] Run `gh auth login`. The bootstrap configures the global Git identity as `Dazz Knowles <me@dazzknowles.co.uk>` and preserves Git for Windows' configured credential helper. Optionally generate a Catwoman-specific SSH key and add its public key to GitHub.
- [ ] Review `.aws/config.eceni-example`; choose the region and add a `catwoman-bootstrap` AWS profile. Use `aws configure --profile catwoman-bootstrap` privately. Its access key should have permission only to read the intended Secrets Manager secret (and the specific KMS decrypt permission if required). Do not store the useful credentials, bootstrap key or private SSH keys in Git or the release ZIP. No SSO or paid infrastructure is provisioned.
- [ ] Select Chrome as default browser and Windows Terminal as default terminal; choose PowerShell 7 as Terminal's default profile. Use a suitable font for Oh My Posh if you choose a glyph-heavy theme.
- [ ] Pin `D:\Source` and `D:\Config` to Explorer Quick Access/Home. Choose `D:\Source` for GitHub Desktop clones and JetBrains project defaults. VS Code can open it directly; `csrc` opens it in PowerShell.
- [ ] Check Update settings and policy behaviour on Catwoman. Keep restart notifications visible and perform manual updates/restarts. The original blanket no-automatic-reboot requirement cannot be guaranteed by the proposed policy pair; see POLICIES.md.
- [ ] If Windows offers Edge's normal Uninstall action, use it if still desired. Do not force-remove WebView2/system components.
- [ ] Launch applications once, then rerun ConfigLinks so newly created settings directories become available.
- [ ] When Git/GitHub are working, initialize the eventual source repository. Never include `D:\Config`, credentials, local logs or test scratch data.
