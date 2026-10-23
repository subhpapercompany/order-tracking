$WshShell = New-Object -comObject WScript.Shell
$desktopPaths = @(
    [Environment]::GetFolderPath('Desktop'),
    'C:\Users\prem5\OneDrive\Desktop',
    'C:\Users\prem5\Desktop'
) | Select-Object -Unique

foreach ($dp in $desktopPaths) {
    if (Test-Path $dp) {
        # 1. Main Software Launcher
        $shortcutPath = Join-Path $dp 'Subh Paper - Order Tracking.lnk'
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = 'd:\New Project Tally Jaisa\Order tracking HTML\Order tracking HTML\Launch_Software.bat'
        $shortcut.WorkingDirectory = 'd:\New Project Tally Jaisa\Order tracking HTML\Order tracking HTML'
        $shortcut.Description = 'Subh Paper Company - Order Tracking & Production Management'
        $shortcut.IconLocation = 'imageres.dll,67'
        $shortcut.Save()
        Write-Host "Created desktop shortcut at: $shortcutPath"

        # 2. Mobile Access QR Hub Shortcut
        $mobileUrlPath = Join-Path $dp 'Subh Paper - Mobile QR & Links Hub.url'
        "[InternetShortcut]`nURL=http://localhost:8080/mobile_access.html`nIconIndex=0" | Out-File -FilePath $mobileUrlPath -Encoding ascii
        Write-Host "Created mobile hub shortcut at: $mobileUrlPath"

        # 3. Connect Mobile 1-Click Batch Shortcut
        $connectMobilePath = Join-Path $dp 'Subh Paper - Connect Mobile.lnk'
        $cShortcut = $WshShell.CreateShortcut($connectMobilePath)
        $cShortcut.TargetPath = 'd:\New Project Tally Jaisa\Order tracking HTML\Order tracking HTML\Connect_Mobile.bat'
        $cShortcut.WorkingDirectory = 'd:\New Project Tally Jaisa\Order tracking HTML\Order tracking HTML'
        $cShortcut.Description = 'Start Mobile Tunnel & Open QR Hub'
        $cShortcut.IconLocation = 'shell32.dll,13'
        $cShortcut.Save()
        Write-Host "Created Connect Mobile shortcut at: $connectMobilePath"
    }
}

# Also add to Windows Startup so the local server runs automatically when PC starts!
$startupPath = [Environment]::GetFolderPath('Startup')
if (Test-Path $startupPath) {
    $pywPath = "$env:LOCALAPPDATA\Programs\Python\Python313\pythonw.exe"
    if (-not (Test-Path $pywPath)) {
        $pywPath = 'pythonw.exe'
    }
    $startupShortcutPath = Join-Path $startupPath 'Subh Paper Server AutoStart.lnk'
    $startupShortcut = $WshShell.CreateShortcut($startupShortcutPath)
    $startupShortcut.TargetPath = $pywPath
    $startupShortcut.Arguments = 'server.py'
    $startupShortcut.WorkingDirectory = 'd:\New Project Tally Jaisa\Order tracking HTML\Order tracking HTML'
    $startupShortcut.Description = 'Subh Paper Company Local Server Auto-Start'
    $startupShortcut.WindowStyle = 7 # Minimized
    $startupShortcut.Save()
    Write-Host "Created Windows Startup shortcut at: $startupShortcutPath"
}
