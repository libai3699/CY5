@echo off
chcp 65001 >nul
title 打包 APK

echo ========================================
echo  开始打包两个 APK
echo ========================================
echo.

cd /d "%~dp0flutter"

echo [1/2] 正在打包 9点9 VPN...
call flutter build apk --release --flavor vpn --dart-define=FLAVOR=vpn
if %errorlevel% neq 0 (
    echo.
    echo [错误] VPN 打包失败！
    pause
    exit /b 1
)
echo [1/2] VPN 打包完成 ✓
echo.

echo [2/2] 正在打包 9点9 加速器...
call flutter build apk --release --flavor acc --dart-define=FLAVOR=acc
if %errorlevel% neq 0 (
    echo.
    echo [错误] 加速器打包失败！
    pause
    exit /b 1
)
echo [2/2] 加速器打包完成 ✓
echo.

echo ========================================
echo  打包完成！输出文件：
echo ========================================
echo.
echo  VPN:    flutter\build\app\outputs\flutter-apk\app-vpn-release.apk
echo  加速器: flutter\build\app\outputs\flutter-apk\app-acc-release.apk
echo.

:: 复制到根目录 dist 文件夹方便取用
if not exist "..\dist" mkdir "..\dist"
copy "build\app\outputs\flutter-apk\app-vpn-release.apk" "..\dist\9点9VPN.apk" >nul
copy "build\app\outputs\flutter-apk\app-acc-release.apk" "..\dist\9点9加速器.apk" >nul

echo  已复制到根目录 dist\ 文件夹：
echo  dist\9点9VPN.apk
echo  dist\9点9加速器.apk
echo.
pause
