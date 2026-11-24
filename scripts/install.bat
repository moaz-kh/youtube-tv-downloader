@echo off
rem Double-click to install yt-dlp and ffmpeg (needed once).
rem Runs install.ps1 without changing Windows script policy.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
