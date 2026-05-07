@echo off
chcp 65001 >nul
title 打包 APK

echo ========================================
echo  开始打包两个 APK
echo ========================================
echo.

cd /d "%~dp0"

set "OUTPUT_DIR=build\app\outputs\flutter-apk"

for /f "tokens=5" %%v in ('findstr /C:"const String kAppVersion" "lib\pages\vpn_home\data\api_config.dart"') do set "APP_VERSION=%%v"
set "APP_VERSION=%APP_VERSION:'=%"
set "APP_VERSION=%APP_VERSION:;=%"

if "%APP_VERSION%"=="" (
    echo.
    echo [错误] 读取 kAppVersion 失败！
    pause
    exit /b 1
)

set "VPN_APK=9.9vpn_%APP_VERSION%.apk"
set "ACC_APK=9.9jsq_%APP_VERSION%.apk"

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
if not exist "%OUTPUT_DIR%\app-vpn-release.apk" (
    echo.
    echo [错误] 未找到 VPN 输出 APK！
    pause
    exit /b 1
)
move /Y "%OUTPUT_DIR%\app-vpn-release.apk" "%OUTPUT_DIR%\%VPN_APK%" >nul
echo [1/2] VPN 打包完成
echo.

echo [2/2] 正在打包 9点9 加速器...
call fvm flutter build apk --release --flavor acc --dart-define=FLAVOR=acc
if %errorlevel% neq 0 (
    echo.
    echo [错误] 加速器 打包失败！
    pause
    exit /b 1
)
if not exist "%OUTPUT_DIR%\app-acc-release.apk" (
    echo.
    echo [错误] 未找到 加速器 输出 APK！
    pause
    exit /b 1
)
move /Y "%OUTPUT_DIR%\app-acc-release.apk" "%OUTPUT_DIR%\%ACC_APK%" >nul
echo [2/2] 加速器 打包完成
echo.

echo ========================================
echo  打包完成！输出文件：
echo ========================================
echo.
echo VPN:
echo %OUTPUT_DIR%\%VPN_APK%
echo.
echo 加速器:
echo %OUTPUT_DIR%\%ACC_APK%
echo.

pause
