# =============================================================================
# Magic Factory · tools/dev/win_toast.ps1
# =============================================================================
#
# Windows 10/11 toast notification helper (PowerShell 5.1+, WinRT-based).
# Zero external dependencies — uses Windows.UI.Notifications with the
# canonical PowerShell AUMID so the toast shows up as "Windows PowerShell"
# in the Action Center.
#
# Why this design (vs. BurntToast / NotifyIcon / MessageBox):
#   • BurntToast: polished, but requires `Install-Module BurntToast` over
#     the network. We want zero runtime dep for the user to forget.
#   • NotifyIcon / MessageBox: built-in but look dated; tray balloon /
#     modal block.
#   • WinRT raw via [Type, Assembly, ContentType=WindowsRuntime] is
#     bundled with PowerShell 5.1+ on every Win10/11 install.
#
# Usage:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/dev/win_toast.ps1 -Title 'Build' -Message 'OK'
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/dev/win_toast.ps1 'Build Title' 'Body'
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/dev/win_toast.ps1 -Title x -Message y -Sound
#
# Exit codes:
#   0 = toast fired
#   1 = WinRT load failed (not Win10+ or PS < 5.1)
#   2 = toast fire raised an exception (rare; logs the error)
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Title = 'Codebuff',

    [Parameter(Position = 1)]
    [string]$Message = 'Long-running command finished.',

    [switch]$Sound
)

# Canonical AUMID for Windows PowerShell; pre-registered on every
# Win10/11 install — same path BurntToast uses for unattributed toasts.
$script:PowerShellAumId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'


# Sequential .Replace() — avoid backtick line-continuation on chained
# method calls (PS 5.1 parses those unreliably across editors/CRLF).
function Escape-Xml([string]$text) {
    if ($null -eq $text) { return '' }
    $out = $text.Replace('&', '&amp;')
    $out = $out.Replace('<', '&lt;')
    $out = $out.Replace('>', '&gt;')
    $out = $out.Replace('"', '&quot;')
    $out = $out.Replace("'", '&apos;')
    return $out
}


try {
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
} catch {
    Write-Host ('[win_toast] WinRT load failed: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host '[win_toast] (Windows 10+ with PowerShell 5.1+ required.)'
    exit 1
}


$safeTitle = Escape-Xml $Title
$safeMessage = Escape-Xml $Message

if ($Sound) {
    $audioXml = '    <audio src="ms-winsoundevent:Notification.Default" />'
} else {
    $audioXml = '    <audio silent="true" />'
}

$template = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$safeTitle</text>
            <text>$safeMessage</text>
        </binding>
    </visual>
$audioXml
</toast>
"@

try {
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($template)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [void][Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:PowerShellAumId).Show($toast)
    exit 0
} catch {
    Write-Host '[win_toast] toast fire failed' -ForegroundColor Red
    Write-Host ('[win_toast] ' + $_.Exception.Message)
    Write-Host ('[win_toast] Title=' + $Title)
    Write-Host ('[win_toast] Message=' + $Message)
    exit 2
}
