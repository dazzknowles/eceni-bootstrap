@{
    Registry = @(
        @{
            Name = 'Show file extensions'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            ValueName = 'HideFileExt'
            Value = 0
        }
        @{
            Name = 'Show hidden files'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            ValueName = 'Hidden'
            Value = 1
        }
        @{
            Name = 'Explorer opens to This PC'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            ValueName = 'LaunchTo'
            Value = 1
        }
        @{
            Name = 'Desktop icons hidden'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            ValueName = 'HideIcons'
            Value = 1
        }
        @{
            Name = 'Taskbar window sharing off'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            ValueName = 'TaskbarSn'
            Value = 0
        }
        @{
            Name = 'Taskbar search hidden'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
            ValueName = 'SearchboxTaskbarMode'
            Value = 0
        }
        @{
            Name = 'Taskbar Widgets hidden'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            ValueName = 'TaskbarDa'
            Value = 0
        }
        @{
            Name = 'Notification sounds off'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
            ValueName = 'NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND'
            Value = 0
        }
        @{
            Name = 'Windows dark mode'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
            ValueName = 'SystemUsesLightTheme'
            Value = 0
        }
        @{
            Name = 'Apps dark mode'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
            ValueName = 'AppsUseLightTheme'
            Value = 0
        }
        @{
            Name = 'Start web search off'
            Path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
            ValueName = 'DisableSearchBoxSuggestions'
            Value = 1
        }
        @{
            Name = 'Fast Startup off'
            Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
            ValueName = 'HiberbootEnabled'
            Value = 0
        }
        @{
            Name = 'Long Win32 paths'
            Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
            ValueName = 'LongPathsEnabled'
            Value = 1
        }
        @{
            Name = 'Developer Mode'
            Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
            ValueName = 'AllowDevelopmentWithoutDevLicense'
            Value = 1
        }
        @{
            Name = 'Download updates; notify to install'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            ValueName = 'AUOptions'
            Value = 3
            Policy = $true
        }
        @{
            Name = 'Windows Update remains enabled'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            ValueName = 'NoAutoUpdate'
            Value = 0
            Policy = $true
        }
        @{
            Name = 'Legacy scheduled-install restart guard'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            ValueName = 'NoAutoRebootWithLoggedOnUsers'
            Value = 1
            Policy = $true
        }
        @{
            Name = 'Scheduled-time automatic restart disabled'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            ValueName = 'AlwaysAutoRebootAtScheduledTime'
            Value = 0
            Policy = $true
        }
        @{
            Name = 'Auto-restart reminder schedule disabled'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            ValueName = 'SetAutoRestartNotificationConfig'
            Value = 0
            Policy = $true
        }
        @{
            Name = 'Auto-restart notifications off'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            ValueName = 'SetAutoRestartNotificationDisable'
            Value = 1
            Policy = $true
        }
        @{
            Name = 'Auto-restart required notification uses default dismissal'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            ValueName = 'SetAutoRestartRequiredNotificationDismissal'
            Value = 0
            Policy = $true
        }
        @{
            Name = 'Disable forced update deadlines'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            ValueName = 'SetComplianceDeadline'
            Value = 0
            Policy = $true
        }
        @{
            Name = 'Keep update notification display defaults'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            ValueName = 'SetUpdateNotificationLevel'
            Value = 0
            Policy = $true
        }
        @{
            Name = 'Required diagnostic data only'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
            ValueName = 'AllowTelemetry'
            Value = 1
            Policy = $true
        }
        @{
            Name = 'No tailored experiences'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'
            ValueName = 'TailoredExperiencesWithDiagnosticDataEnabled'
            Value = 0
        }
        @{
            Name = 'Advertising ID off'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
            ValueName = 'Enabled'
            Value = 0
        }
        @{
            Name = 'Finish setting up suggestions off'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'
            ValueName = 'ScoobeSystemSettingEnabled'
            Value = 0
        }
        @{
            Name = 'Suggestions off: SoftLandingEnabled'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            ValueName = 'SoftLandingEnabled'
            Value = 0
        }
        @{
            Name = 'Suggestions off: SystemPaneSuggestionsEnabled'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            ValueName = 'SystemPaneSuggestionsEnabled'
            Value = 0
        }
        @{
            Name = 'Suggestions off: RotatingLockScreenEnabled'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            ValueName = 'RotatingLockScreenEnabled'
            Value = 0
        }
        @{
            Name = 'Suggestions off: RotatingLockScreenOverlayEnabled'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            ValueName = 'RotatingLockScreenOverlayEnabled'
            Value = 0
        }
        @{
            Name = 'Suggestions off: SubscribedContent-310093Enabled'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            ValueName = 'SubscribedContent-310093Enabled'
            Value = 0
        }
        @{
            Name = 'Suggestions off: SubscribedContent-338388Enabled'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            ValueName = 'SubscribedContent-338388Enabled'
            Value = 0
        }
        @{
            Name = 'Suggestions off: SubscribedContent-338389Enabled'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            ValueName = 'SubscribedContent-338389Enabled'
            Value = 0
        }
        @{
            Name = 'Suggestions off: SubscribedContent-338393Enabled'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            ValueName = 'SubscribedContent-338393Enabled'
            Value = 0
        }
        @{
            Name = 'Suggestions off: SubscribedContent-353694Enabled'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            ValueName = 'SubscribedContent-353694Enabled'
            Value = 0
        }
        @{
            Name = 'Suggestions off: SubscribedContent-353696Enabled'
            Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            ValueName = 'SubscribedContent-353696Enabled'
            Value = 0
        }
        @{
            Name = 'No consumer app promotions'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
            ValueName = 'DisableWindowsConsumerFeatures'
            Value = 1
            Policy = $true
        }
        @{
            Name = 'Recall snapshots disabled'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
            ValueName = 'DisableAIDataAnalysis'
            Value = 1
            Policy = $true
        }
        @{
            Name = 'Click to Do disabled'
            Path = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI'
            ValueName = 'DisableClickToDo'
            Value = 1
            Policy = $true
        }
        @{
            Name = 'Legacy Copilot off'
            Path = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'
            ValueName = 'TurnOffWindowsCopilot'
            Value = 1
            Policy = $true
        }
        @{
            Name = 'Widgets allowed'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
            ValueName = 'AllowNewsAndInterests'
            Value = 1
            Policy = $true
        }
        @{
            Name = 'Game DVR off'
            Path = 'HKCU:\System\GameConfigStore'
            ValueName = 'GameDVR_Enabled'
            Value = 0
        }
        @{
            Name = 'Edge StartupBoostEnabled'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
            ValueName = 'StartupBoostEnabled'
            Value = 0
        }
        @{
            Name = 'Edge BackgroundModeEnabled'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
            ValueName = 'BackgroundModeEnabled'
            Value = 0
        }
        @{
            Name = 'Edge HideFirstRunExperience'
            Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
            ValueName = 'HideFirstRunExperience'
            Value = 1
        }
    )
}
