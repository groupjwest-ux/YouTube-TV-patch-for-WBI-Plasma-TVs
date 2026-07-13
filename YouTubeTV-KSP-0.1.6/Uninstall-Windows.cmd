@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Uninstall-Windows.ps1" %*
set "RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %RESULT%
