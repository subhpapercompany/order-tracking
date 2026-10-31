@echo off
title Subh Paper Company - Order Tracking
cd /d "%~dp0"

:: 1. Check if server is already responding cleanly
curl.exe -s --max-time 1 http://localhost:8080/api/ping | findstr "ok" >nul 2>&1
if %errorlevel% equ 0 (
    goto :tunnel_check
)

echo Starting Subh Order Tracking Server...

:: 2. If port 8080 is blocked by a frozen/zombie process, clear it
netstat -ano | findstr ":8080" | findstr "LISTENING" >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8080" ^| findstr "LISTENING"') do (
        taskkill /F /PID %%a >nul 2>&1
    )
)

:: 3. Locate pythonw or python
set "PY_BIN="
if exist "%LocalAppData%\Programs\Python\Python313\pythonw.exe" (
    set "PY_BIN=%LocalAppData%\Programs\Python\Python313\pythonw.exe"
) else (
    where pythonw.exe >nul 2>&1 && set "PY_BIN=pythonw.exe"
)
if "%PY_BIN%"=="" (
    where python.exe >nul 2>&1 && set "PY_BIN=python.exe"
)

if "%PY_BIN%"=="" (
    echo [ERROR] Python not found on system!
    pause
    exit /b 1
)

:: 4. Start server quietly in background
start "" "%PY_BIN%" "%~dp0server.py"

:: 5. Wait safely for server to bind port
ping -n 3 127.0.0.1 >nul 2>&1

:: 6. Ensure Cloudflare public tunnel is active for 4G/Mobile global access
:tunnel_check
tasklist | findstr /i "cloudflared.exe" >nul 2>&1
if %errorlevel% neq 0 (
    if exist "%~dp0cloudflared.exe" (
        if not exist "%~dp0data" mkdir "%~dp0data"
        :: --logfile flag cloudflared me fail hota hai, isliye cmd redirect use karte hain
        del /f /q "data\cf.log" >nul 2>&1
        start "" cmd /c "cloudflared.exe tunnel --url http://localhost:8080 > data\cf.log 2>&1"
    )
)

:launch_browser
echo Launching Subh Paper Application...
start http://localhost:8080/
