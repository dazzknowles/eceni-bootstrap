@{
    Packages = @(
        @{
            Name = 'Claude desktop'
            Id = 'Anthropic.Claude'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'AI'
        }
        @{
            Name = 'Claude Code'
            Id = 'Anthropic.ClaudeCode'
            Type = 'WinGet'
            Source = 'winget'
            Stage = 'AI'
        }
    )
    Manual = @(
        @{
            Name = 'ChatGPT desktop'
            Stage = 'AI'
            Instructions = 'Install the current Windows desktop app from the official download page. The older Store product is now labelled ChatGPT Classic; do not silently substitute it.'
            Url = 'https://chatgpt.com/download/'
        }
    )
}
