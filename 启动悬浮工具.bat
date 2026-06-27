@echo off
title GitHub Hosts Widget
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
    echo [INFO] Not running as Admin, requesting elevation...
    powershell -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%~dp0GitHubHostsWidget.ps1""' -Verb runas"
    goto :eof
)

echo Starting floating widget...
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0GitHubHostsWidget.ps1"
