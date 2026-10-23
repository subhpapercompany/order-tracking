@echo off
title Subh Paper Company - Local Web Server
cd /d "%~dp0"
cls
echo ================================================================
echo   SUBH PAPER COMPANY - LOCAL NETWORK WEB SERVER
echo ================================================================
echo.
echo   Starting web server with dynamic Wi-Fi IP detection...
echo.
start http://localhost:8080/
python "%~dp0server.py"
pause
