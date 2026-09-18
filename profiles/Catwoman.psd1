@{
    SchemaVersion = 1
    Version = '0.1.0'
    Name = 'Catwoman'
    SourceRoot = 'D:\Source'
    ConfigRoot = 'D:\Config'
    Roles = @(
        'WindowsBase'
        'Developer'
        'DatabaseTools'
        'AIWorkstation'
        'Everyday'
    )
    Options = @{
        Docker = $false
        RockyWsl = @{
            Enabled = $true
            Major = 10
            DistroName = 'RockyLinux-10'
            SetDefault = $true
        }
        NodeMajor = 24
        RestartExplorer = $true
        MonitorMinutesAC = 20
        MonitorMinutesDC = 10
        SleepMinutesAC = 60
        SleepMinutesDC = 20
        GitAutoCrlf = 'input'
        GitUserName = 'Dazz Knowles'
        GitUserEmail = 'me@dazzknowles.co.uk'
        AwsProfile = 'catwoman-bootstrap'
        AwsRegion = ''
        TerminalProfiles = @{
            Enabled = $true
            CodexTabColor = '#10A37F'
            ClaudeTabColor = '#D97757'
        }
        # Add exact WinGet versions here to exclude packages from managed updates.
        # Example: 'Microsoft.PowerToys' = '0.95.1'
        PackageVersionLocks = @{}
    }
    Keep = @(
        'Microsoft.MicrosoftSolitaireCollection'
        'Microsoft.WindowsCalculator'
        'Microsoft.Windows.Photos'
        'Microsoft.Paint'
        'Microsoft.ScreenSketch'
        'Microsoft.WindowsCamera'
        'Microsoft.WindowsStore'
        'Microsoft.DesktopAppInstaller'
        'Microsoft.EdgeWebView2'
    )
    RemoveAppx = @(
        'Microsoft.Copilot'
        'Microsoft.Windows.Ai.Copilot.Provider'
        '7EE7776C.LinkedInforWindows'
        'MSTeams'
        'MicrosoftTeams'
        'Microsoft.BingNews'
        'MicrosoftCorporationII.MicrosoftFamily'
        'Microsoft.Todos'
        'Microsoft.YourPhone'
        'Microsoft.XboxGamingOverlay'
        'Microsoft.XboxGameOverlay'
        'Microsoft.Xbox.TCUI'
        'Microsoft.GamingApp'
        'Microsoft.XboxApp'
        'Microsoft.XboxIdentityProvider'
        'Microsoft.XboxSpeechToTextOverlay'
        'Microsoft.BingWeather'
        'Microsoft.MicrosoftStickyNotes'
        'Clipchamp.Clipchamp'
        'Microsoft.Windows.DevHome'
    )
    RemoveWinGet = @(
        @{
            Name = 'OneDrive'
            Id = 'Microsoft.OneDrive'
            Source = 'winget'
            Scope = 'User'
        }
    )
}
