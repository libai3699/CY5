@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_all.ps1" %*
endlocal
