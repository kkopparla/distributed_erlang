@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0project1.ps1" %*
endlocal
