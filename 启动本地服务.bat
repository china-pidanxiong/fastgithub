@echo off
title GitHub Hosts Server
cd /d "%~dp0"

echo ========================================
echo   GitHub Hosts Local Server
echo   For browser extension integration
echo ========================================
echo.

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Administrator privileges required!
    echo Please right-click this file and select "Run as administrator"
    echo.
    pause
    goto :eof
)

echo Starting server...
echo URL: http://localhost:17890
echo Press Ctrl+C to stop
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0GitHubHostsServer.ps1"

echo.
echo Server stopped.
pause
