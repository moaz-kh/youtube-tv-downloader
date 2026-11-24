@echo off
rem Double-click to paste links, or run:  download.bat "LINK1" "LINK2"
rem Videos are saved in the "downloads" folder of this project (use -OutDir to change it).
rem Runs download.ps1 without changing Windows' script policy.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0download.ps1" %*
echo.
pause
