@echo off
rem install.cmd — double-click entry point for the PWA installer.
rem Launches install.ps1 with a sensible PowerShell policy and stays open
rem so the user can read its instructions / close it after install.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
