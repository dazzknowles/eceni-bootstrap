@{
    Packages = @(
        @{
            Name = 'NVM for Windows'
            Id = 'CoreyButler.NVMforWindows'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Toolchains'
        }
        @{
            Name = '.NET 10 SDK'
            Id = 'Microsoft.DotNet.SDK.10'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Toolchains'
        }
        @{
            Name = 'Python 3.14'
            Id = 'Python.Python.3.14'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Toolchains'
        }
        @{
            Name = 'uv'
            Id = 'astral-sh.uv'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Toolchains'
        }
        @{
            Name = 'Temurin JDK 25 LTS'
            Id = 'EclipseAdoptium.Temurin.25.JDK'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Toolchains'
        }
        @{
            Name = 'Go'
            Id = 'GoLang.Go'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Toolchains'
        }
        @{
            Name = 'Rustup'
            Id = 'Rustlang.Rustup'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Toolchains'
        }
        @{
            Name = 'Visual Studio C++ Build Tools'
            Id = 'Microsoft.VisualStudio.2022.BuildTools'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Toolchains'
            Override = '--wait --quiet --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
        }
        @{
            Name = 'CMake'
            Id = 'Kitware.CMake'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Toolchains'
        }
        @{
            Name = 'JetBrains Toolbox'
            Id = 'JetBrains.Toolbox'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'IDEs'
        }
        @{
            Name = 'VS Code'
            Id = 'Microsoft.VisualStudioCode'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'IDEs'
        }
        @{
            Name = 'Docker Desktop'
            Id = 'Docker.DockerDesktop'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Containers'
            Optional = 'Docker'
        }
    )
    Manual = @(
        @{
            Name = 'Rider'
            Stage = 'IDEs'
            Instructions = 'Install Rider using JetBrains Toolbox after signing in; let Toolbox manage versions and licensing.'
            Url = 'https://www.jetbrains.com/toolbox-app/'
        }
        @{
            Name = 'DataGrip'
            Stage = 'IDEs'
            Instructions = 'Install DataGrip using JetBrains Toolbox after signing in; let Toolbox manage versions and licensing.'
            Url = 'https://www.jetbrains.com/toolbox-app/'
        }
        @{
            Name = 'dotMemory'
            Stage = 'IDEs'
            Instructions = 'Install dotMemory using JetBrains Toolbox after signing in; let Toolbox manage versions and licensing.'
            Url = 'https://www.jetbrains.com/toolbox-app/'
        }
        @{
            Name = 'dotTrace'
            Stage = 'IDEs'
            Instructions = 'Install dotTrace using JetBrains Toolbox after signing in; let Toolbox manage versions and licensing.'
            Url = 'https://www.jetbrains.com/toolbox-app/'
        }
        @{
            Name = 'GoLand'
            Stage = 'IDEs'
            Instructions = 'Install GoLand using JetBrains Toolbox after signing in; let Toolbox manage versions and licensing.'
            Url = 'https://www.jetbrains.com/toolbox-app/'
        }
        @{
            Name = 'WebStorm'
            Stage = 'IDEs'
            Instructions = 'Install WebStorm using JetBrains Toolbox after signing in; let Toolbox manage versions and licensing.'
            Url = 'https://www.jetbrains.com/toolbox-app/'
        }
        @{
            Name = 'PyCharm'
            Stage = 'IDEs'
            Instructions = 'Install PyCharm using JetBrains Toolbox after signing in; let Toolbox manage versions and licensing.'
            Url = 'https://www.jetbrains.com/toolbox-app/'
        }
        @{
            Name = 'IntelliJ IDEA'
            Stage = 'IDEs'
            Instructions = 'Install IntelliJ IDEA using JetBrains Toolbox after signing in; let Toolbox manage versions and licensing.'
            Url = 'https://www.jetbrains.com/toolbox-app/'
        }
        @{
            Name = 'RustRover'
            Stage = 'IDEs'
            Instructions = 'Install RustRover using JetBrains Toolbox after signing in; let Toolbox manage versions and licensing.'
            Url = 'https://www.jetbrains.com/toolbox-app/'
        }
        @{
            Name = 'Development locations'
            Stage = 'Manual'
            Instructions = 'Use D:\Source in GitHub Desktop clone dialogs and JetBrains new-project defaults. The shell gets a csrc helper; existing preferences are not overwritten.'
            Url = ''
        }
        @{
            Name = 'WSL distribution'
            Stage = 'Containers'
            Instructions = 'WSL2 features are enabled by the Containers stage. Reboot manually if requested, then choose Rocky or Ubuntu: wsl --list --online; wsl --install -d <exact-name>. Docker remains opt-in.'
            Url = ''
        }
    )
}
