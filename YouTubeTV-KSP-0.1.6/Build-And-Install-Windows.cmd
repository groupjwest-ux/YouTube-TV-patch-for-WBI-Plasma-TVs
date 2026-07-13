@echo off
setlocal
cd /d "%~dp0"
echo YouTube TV for Windows KSP - build 0.1.5
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Build-And-Install-Windows.ps1" %*
set "RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %RESULT%
