# =====================================================================
# SUBH PAPER COMPANY - Desktop shortcuts + Windows auto-start
# ---------------------------------------------------------------------
# Portable: every path is derived from THIS script's own folder, so it
# works from any location (no hardcoded drive / user names).
# Run:  powershell -ExecutionPolicy Bypass -File .\create_shortcuts.ps1
#
# Creates:
#   Desktop : "Subh Paper - Order Tracking.lnk"   -> Launch_Software.bat
#             "Subh Paper - Connect Mobile.lnk"    -> Connect_Mobile.bat
#             "Subh Paper - Mobile QR & Links Hub.url"
#   Startup : "Subh Paper Server AutoStart.lnk"    -> pythonw server.py
#             (local realtime sync + autosave always available)
#   Startup : "Subh Paper AutoPush.lnk"            -> AutoPush_Watcher.ps1
#             (auto git commit + push code changes to GitHub)
# =====================================================================

$AppDir   = $PSScriptRoot
if (-not $AppDir) { $AppDir = (Get-Location).Path }
$WshShell = New-Object -ComObject WScript.Shell

function New-Shortcut {
    param(
        [string]$LnkPath,
        [string]$Target,
        [string]$Arguments = '',
        [string]$WorkDir   = '',
        [string]$Desc      = '',
        [string]$Icon      = '',
        [int]$WinStyle     = 1
    )
    $lnk = $WshShell.CreateShortcut($LnkPath)
    $lnk.TargetPath = $Target
    if ($Arguments) { $lnk.Arguments = $Arguments }
    if ($WorkDir)   { $lnk.WorkingDirectory = $WorkDir }
    if ($Desc)      { $lnk.Description = $Desc }
    if ($Icon)      { $lnk.IconLocation = $Icon }
    if ($WinStyle -gt 1) { $lnk.WindowStyle = $WinStyle }
    $lnk.Save()
    Write-Host "  + $LnkPath"
}

# ---------------- Desktop shortcuts ----------------
$desktop = [Environment]::GetFolderPath('Desktop')
if ($desktop -and (Test-Path $desktop)) {
    Write-Host "Desktop : $desktop"

    # 1. Main launcher (starts server if needed, then opens the app)
    New-Shortcut -LnkPath (Join-Path $desktop 'Subh Paper - Order Tracking.lnk') `
                 -Target  (Join-Path $AppDir 'Launch_Software.bat') `
                 -WorkDir $AppDir `
                 -Desc    'Subh Paper Company - Order Tracking & Production Management' `
                 -Icon    'imageres.dll,67'

    # 2. Mobile Access QR / links hub
    $urlPath = Join-Path $desktop 'Subh Paper - Mobile QR & Links Hub.url'
    "[InternetShortcut]`nURL=http://localhost:8080/mobile_access.html`nIconIndex=0" |
        Out-File -FilePath $urlPath -Encoding ascii
    Write-Host "  + $urlPath"

    # 3. Connect Mobile one-click (tunnel + QR hub)
    New-Shortcut -LnkPath (Join-Path $desktop 'Subh Paper - Connect Mobile.lnk') `
                 -Target  (Join-Path $AppDir 'Connect_Mobile.bat') `
                 -WorkDir $AppDir `
                 -Desc    'Start Mobile Tunnel & Open QR Hub' `
                 -Icon    'shell32.dll,13'
} else {
    Write-Host "  [WARN] Desktop folder not found - desktop shortcuts skipped"
}

# ---------------- Windows Startup (auto-start on login) ----------------
$startupPath = [Environment]::GetFolderPath('Startup')
if ($startupPath -and (Test-Path $startupPath)) {
    Write-Host "Startup : $startupPath"

    # -- A) Local server auto-start -> realtime sync + autosave --
    $pyw = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python313\pythonw.exe'
    if (-not (Test-Path $pyw)) {
        $c = Get-Command pythonw.exe -ErrorAction SilentlyContinue
        if ($c) { $pyw = $c.Source }
    }
    if (-not (Test-Path $pyw)) {
        $c = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($c) { $pyw = $c.Source }
    }

    if ($pyw -and (Test-Path $pyw)) {
        New-Shortcut -LnkPath  (Join-Path $startupPath 'Subh Paper Server AutoStart.lnk') `
                     -Target   $pyw `
                     -Arguments 'server.py' `
                     -WorkDir  $AppDir `
                     -Desc     'Subh Paper Company Local Server Auto-Start' `
                     -WinStyle 7
    } else {
        Write-Host "  [WARN] pythonw/python not found - server auto-start skipped"
    }

    # -- B) Auto git push watcher -> commits+pushes code changes --
    $watcher = Join-Path $AppDir 'AutoPush_Watcher.ps1'
    if (Test-Path $watcher) {
        New-Shortcut -LnkPath  (Join-Path $startupPath 'Subh Paper AutoPush.lnk') `
                     -Target   'powershell.exe' `
                     -Arguments "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$watcher`"" `
                     -WorkDir  $AppDir `
                     -Desc     'Auto commit + push code changes to GitHub' `
                     -WinStyle 7
    } else {
        Write-Host "  [WARN] AutoPush_Watcher.ps1 not found - auto-push auto-start skipped"
    }
} else {
    Write-Host "  [WARN] Startup folder not found"
}

Write-Host ''
Write-Host 'Done. Log out & in (or restart) once so the auto-start entries take effect.'
