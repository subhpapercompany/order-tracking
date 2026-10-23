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
    start /min "" pythonw server.py
    ping -n 3 127.0.0.1 >nul 2>&1
)

echo   [2] Checking 4G/Mobile Cloudflare Tunnel...
tasklist | findstr /i "cloudflared.exe" >nul 2>&1
if %errorlevel% neq 0 (
    if exist "%~dp0cloudflared.exe" (
        echo       Starting mobile tunnel...
        start /min "" "%~dp0cloudflared.exe" tunnel --url http://localhost:8080 --logfile "%~dp0data\cloudflared.log"
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
