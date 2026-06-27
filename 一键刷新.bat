@echo off
title GitHub Hosts Update
cd /d "%~dp0"

echo ========================================
echo   GitHub Hosts Quick Refresh
echo ========================================
echo.

net session >nul 2>&1
if errorlevel 1 (
    echo [INFO] Not running as Admin, requesting elevation...
    powershell -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0Update-GitHubHosts.ps1""' -Verb runas"
    goto :eof
)

echo Updating GitHub hosts, please wait...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-GitHubHosts.ps1"

echo.
echo Done. Press any key to exit...
pause >nul
