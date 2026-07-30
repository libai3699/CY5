@echo off
setlocal
REM Usage:
REM   apk.bat        build all (vpn+acc apk + windows)
REM   apk.bat 1      vpn apk only
REM   apk.bat 2      vpn windows exe only
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_all.ps1" %*
endlocal
