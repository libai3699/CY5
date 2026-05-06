@echo off
chcp 65001 >nul
title 打包 APK

echo ========================================
echo  开始打包两个 APK
echo ========================================
echo.

cd /d "%~dp0flutter"

echo [准备] 正在 clean...
call fvm flutter clean
if %errorlevel% neq 0 (
    echo.
    echo [错误] flutter clean 失败！
    pause
    exit /b 1
)

echo [准备] 正在 pub get...
call fvm flutter pub get
if %errorlevel% neq 0 (
    echo.
    echo [错误] pub get 失败！
    pause
    exit /b 1
)

echo.
echo [1/2] 正在打包 9点9 VPN...
call fvm flutter build apk --release --flavor vpn --dart-define=FLAVOR=vpn
if %errorlevel% neq 0 (
    echo.
    echo [错误] VPN 打包失败！
    pause
    exit /b 1
)
echo [1/2] VPN 打包完成 ✓
echo.

echo [2/2] 正在打包 9点9 加速器...
call fvm flutter build apk --release --flavor acc --dart-define=FLAVOR=acc
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
echo VPN:
echo flutter\build\app\outputs\flutter-apk\app-vpn-release.apk
echo.
echo 加速器:
echo flutter\build\app\outputs\flutter-apk\app-acc-release.apk
echo.

pause