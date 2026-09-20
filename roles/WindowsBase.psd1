@{
    Packages = @(
        @{
            Name = 'PowerShell 7'
            Id = 'Microsoft.PowerShell'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Foundations'
        }
        @{
            Name = 'Windows Terminal'
            Id = 'Microsoft.WindowsTerminal'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Foundations'
        }
        @{
            Name = 'Git for Windows'
            Id = 'Git.Git'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Foundations'
        }
        @{
            Name = 'Git LFS'
            Id = 'GitHub.GitLFS'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Foundations'
        }
        @{
            Name = 'GitHub CLI'
            Id = 'GitHub.cli'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Foundations'
        }
        @{
            Name = 'GitHub Desktop'
            Id = 'GitHub.GitHubDesktop'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Foundations'
        }
        @{
            Name = '1Password'
            Id = 'AgileBits.1Password'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Foundations'
        }
        @{
            Name = 'AWS CLI v2'
            Id = 'Amazon.AWSCLI'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Foundations'
        }
    )
    Manual = @(
        @{
            Name = 'NVIDIA Studio Driver'
            Stage = 'Manual'
            Instructions = 'Select the actual notebook GPU and Windows version, then Studio Driver. Do not select Game Ready.'
            Url = 'https://www.nvidia.com/en-gb/drivers/'
        }
        @{
            Name = 'MSI and SteelSeries feature selection'
            Stage = 'Manual'
            Instructions = 'Launch MSI Center and SteelSeries GG, accept any required vendor terms, then enable only the hardware, lighting and audio modules actually needed. Review driver suggestions rather than replacing the selected NVIDIA Studio Driver automatically.'
            Url = ''
        }
        @{
            Name = 'Default apps and terminal'
            Stage = 'Manual'
            Instructions = 'In Settings select Chrome as default browser, Windows Terminal as default terminal, and PowerShell 7 as its default profile.'
            Url = ''
        }
        @{
            Name = 'Sign-ins and secrets'
            Stage = 'Manual'
            Instructions = 'Sign in to 1Password, GitHub, JetBrains, Tailscale, Windscribe, Claude, ChatGPT and Store apps. Configure AWS bootstrap credentials manually with read access restricted to the chosen Secrets Manager secret.'
            Url = ''
        }
        @{
            Name = 'Quick Access'
            Stage = 'Manual'
            Instructions = 'Pin D:\Source and D:\Config to File Explorer Quick Access/Home.'
            Url = ''
        }
        @{
            Name = 'Edge removal'
            Stage = 'Manual'
            Instructions = 'If Windows Settings offers Uninstall for Edge, it can be removed there. Otherwise retain Edge/WebView2; background mode, startup boost and first-run prompts are disabled by policy.'
            Url = ''
        }
    )
}
