@echo off
rem install.cmd — double-click entry point for the PWA installer.
rem install.ps1 self-terminates the moment Edge fires 'appinstalled'
rem (it pings /installed; the PS listener exits its loop). On success
rem this window closes automatically. Only pause when PowerShell
rem exits with an error so the user can read the message.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
if errorlevel 1 (
  echo.
  echo Installer exited with error %errorlevel%. Press any key to close.
  pause >nul
)
exit /b %errorlevel%
