@{
    Packages = @(
        @{
            Name = 'SQL Server Management Studio 22'
            Id = 'Microsoft.SQLServerManagementStudio.22'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Database'
        }
        @{
            Name = 'Bruno'
            Id = 'Bruno.Bruno'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'Database'
        }
    )
    Manual = @(
        @{
            Name = 'dbForge Studio for MySQL'
            Stage = 'Database'
            Instructions = 'Download the Windows installer from Devart; install using your existing licence or selected trial. No guessed package ID. Vendor supports /verysilent.'
            Url = 'https://www.devart.com/dbforge/mysql/studio/download.html'
        }
        @{
            Name = 'MariaDB client only'
            Stage = 'Database'
            Instructions = 'Use MariaDB client tools in the chosen WSL distro (Ubuntu: sudo apt install mariadb-client; Rocky: sudo dnf install mariadb). Do not install MariaDB Server on Windows.'
            Url = 'https://mariadb.com/docs/server/clients-and-utilities/mariadb-client'
        }
    )
}
