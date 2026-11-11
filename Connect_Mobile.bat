@echo off
title Subh Paper Company - Staff Mobile Access Hub
cd /d "%~dp0"
cls
echo ================================================================
echo   SUBH PAPER COMPANY - STAFF MOBILE ACCESS HUB
echo ================================================================
echo.
echo   [1] Checking local server...
curl.exe -s --max-time 1 http://localhost:8080/api/ping | findstr "ok" >nul 2>&1
if %errorlevel% neq 0 (
    echo       Starting local server...
    where pythonw.exe >nul 2>&1
    if %errorlevel% equ 0 (
        start /min "" pythonw server.py
    ) else (
        :: Python nahi hai — built-in PowerShell server (LAN/Wi-Fi safe)
        start "" powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0serve_local.ps1"
    )
    ping -n 3 127.0.0.1 >nul 2>&1
)

echo   [2] Checking 4G/Mobile Cloudflare Tunnel...
tasklist | findstr /i "cloudflared.exe" >nul 2>&1
if %errorlevel% neq 0 (
    if exist "%~dp0cloudflared.exe" (
        echo       Starting mobile tunnel...
        :: --logfile flag cloudflared me fail hota hai — cmd redirect use karte hain
        if not exist "%~dp0data" mkdir "%~dp0data"
        start "" cmd /c "cloudflared.exe tunnel --url http://localhost:8080 > data\cf.log 2>&1"
        ping -n 4 127.0.0.1 >nul 2>&1
    )
)

echo   [3] Opening Mobile Access QR Code Hub...
start http://localhost:8080/mobile_access.html
echo.
echo ================================================================
echo   SUCCESS! Mobile Access Hub is open in your browser.
echo   Staff can scan QR Code or open the links displayed on screen.
echo ================================================================
echo.
pause
