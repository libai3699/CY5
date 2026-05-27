fvm use 3.27.0

```powershell
flutter devices
```
# vpn flavor
flutter run --flavor vpn --dart-define=FLAVOR=vpn

# acc flavor
flutter run --flavor acc --dart-define=FLAVOR=acc

# 多设备时指定设备 ID（device-id 从 flutter devices 获取）
flutter run -d <device-id> --flavor vpn --dart-define=FLAVOR=vpn
```

### Windows 本地运行

Windows 不支持 --flavor，flavor 区分靠 --dart-define 在 Dart 层判断。

**推荐命令（支持热重载）：**

```powershell
# 清除中国镜像环境变量（如果遇到网络问题）
$env:FLUTTER_STORAGE_BASE_URL=""; $env:PUB_HOSTED_URL=""

# vpn flavor - 支持热重载
flutter run -d windows --dart-define=FLAVOR=vpn

# acc flavor - 支持热重载
flutter run -d windows --dart-define=FLAVOR=acc
```

**热重载快捷键：**
- 按 `r` 键：热重载（Hot Reload）- 快速更新 UI
- 按 `R` 键：热重启（Hot Restart）- 完全重启应用
- 按 `h` 键：显示所有可用命令
- 按 `q` 键：退出应用

**注意事项：**
- 首次运行需要下载依赖和编译，可能需要 5-10 分钟
- 后续运行会快很多（几秒钟）
- 修改代码后按 `r` 即可热重载，无需重启

**遇到编译错误时：**

如果遇到 CMake 错误或编译问题，运行以下命令清理缓存：

```powershell
# 清理 Flutter 缓存
flutter clean

# 删除 Windows 构建目录
Remove-Item -Recurse -Force build\windows

# 重新运行
flutter run -d windows --dart-define=FLAVOR=vpn
```

---

## 统一打包命令

```powershell
.\apk.bat
```

运行前会先执行 `clean`，并强制校验 Flutter 版本为 `3.27.0`。
Windows 安装器依赖 Inno Setup 的 `ISCC.exe`，可通过环境变量 `ISCC_PATH` 指定。

运行后会把 4 个产物统一放到 `dist/` 根目录：

- `dist/9.9vpn_<version>.apk`
- `dist/9.9acc_<version>.apk`
- `dist/9.9vpn_<version>_windows.exe`
- `dist/9.9acc_<version>_windows.exe`

Windows VPN 依赖 `xray.exe` 或 `v2ray.exe`。可以用任一方式提供：

- 放到 `windows/bin/windows/`
- 放到项目根目录的 `bin/windows/`
- 设置环境变量 `9.9_CORE_PATH`
- 设置环境变量 `XRAY_EXE_PATH`
- 设置环境变量 `V2RAY_EXE_PATH`

Windows 打包时会把找到的 core 一起带进最终安装器 exe，Android flavor 逻辑不受影响。

xray.exe 下载地址：https://github.com/XTLS/Xray-core/releases（下载 Xray-windows-64.zip 解压取 xray.exe）

---

## Windows 平台已知问题及修复记录

### 1. ChatGPT 页面崩溃（已修复）

**问题**：`webview_flutter` 在 Windows 上没有原生实现，打开 ChatGPT 页面会抛 `MissingPluginException` 崩溃。

**修复**：`chatgpt_page.dart` 加了平台判断。Android / iOS 继续使用内嵌 WebView，Windows 显示引导页面，点击按钮用系统默认浏览器打开 `https://chatgpt.com/`。Android 行为完全不变。

---

### 2. Windows 流量统计始终为 0（已修复）

**问题**：流量统计依赖 `flutter_v2ray` 的 `onStatusChanged` 回调，Windows 路径不走这个插件，导致心跳上报的 `traffic_bytes` 永远是 0。

**修复**：
- `windows_vpn_controller.dart`：连接成功后启动每秒轮询 xray stats HTTP API（`http://127.0.0.1:10085/debug/vars`），解析 `uplink` / `downlink` 累计字节数，断开时停止轮询并清零。
- `vpn_native_channel.dart`：Windows 连接成功后启动 `_startWindowsTrafficSync()`，每秒把 `WindowsVpnController.totalTrafficBytes` 同步到 `_currentTotalBytes`，让 `consumeTrafficDelta()` 和 `unconsumedBytes` 在 Windows 上正常工作。

> **注意**：xray stats API 需要在 xray config 里开启 `api` 和 `stats` 模块才会有数据。如果 xray 没有开启，轮询会静默失败，流量保持 0，不影响 VPN 连接功能。Android 流量统计逻辑完全不变。

---

### 3. Windows 设备 ID 重装后变化（已修复）

**问题**：Windows 上 `device_identity.dart` 走降级路径，生成随机 UUID 存到文件，每次重装应用会生成新 ID，设备识别失效。

**修复**：`_getSystemDeviceId()` 新增 Windows 分支，优先级如下：
1. 通过 PowerShell 读取机器 SID（`S-1-5-...` 格式），重装系统才会变
2. 降级读取注册表 `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid`，同样重装系统才变
3. 以上都失败才走原来的随机 UUID 降级路径

Android / iOS 的设备 ID 逻辑完全不变。

---

## Android 平台已知问题及修复记录

### 1. 联系客服空白页（已修复）

**问题**：国内用户未连 VPN 时无法访问服务器，`HttpClient` 超时时间过长，页面长时间转圈或显示空白。

**修复**：
- 新建 `data/contact_service.dart`，单例，三级缓存：内存 → 磁盘（`contact_cache.json`）→ 网络
- 首页启动时 `_bootstrap()` 后台静默预加载联系方式并写入磁盘缓存
- `ContactPage` 打开时优先读内存/磁盘缓存，毫秒级返回，同时后台刷新
- 网络超时从 8 秒缩短到 6 秒，失败自动降级到缓存，永远不会空白
- 右上角新增刷新按钮，用户可手动强制刷新

---

### 2. VPN 切换页面/切换 App 后断开（已修复）

**根因 1（最关键）**：`proguard-rules.pro` 文件不存在，但 `build.gradle` 开启了 `minifyEnabled true`。Release 包混淆时 V2Ray VPN Service 类名被改掉，Android 系统通过 Manifest 反射找不到该 Service，VPN 随即断开。这也是为什么开发模式（debug 不混淆）正常，用户用 Release APK 就断的原因。

**根因 2**：`onStatusChanged` 状态判断用 `s.contains('stop')` 模糊匹配，`"STOPPING"` 等过渡状态也会触发 `disconnected`，导致 UI 显示断开但 VPN 实际还在运行，用户手动重连反而真的断了。

**修复**：
- 创建 `android/app/proguard-rules.pro`，保留 `flutter_v2ray`、所有继承 `VpnService`/`Service` 的类、`SupportWebActivity`、Kotlin/Coroutines 等
- `vpn_native_channel.dart` 状态判断改为精确匹配，只有 `stopped/disconnected/none/idle/error/failed` 才触发断开，`reconnecting` 等过渡状态保持 `connecting`，未知状态不改变当前状态

---

### 3. 心跳流量统计 bug（已修复）

**问题 1**：`_pendingSeconds > 60` 时直接赋值 `_pendingSeconds = 60`，导致秒数永远在 60 附近徘徊，实际使用时长被严重低估。

**问题 2**：心跳里 `await _handleTokenExpired()` 没有 `mounted` 检查，widget dispose 后调用 `ScaffoldMessenger.of(context)` 会抛 `FlutterError`。

**问题 3**：`_displayTrafficRemaining` 每秒被 `_uiRefreshTimer` 触发，若服务端返回格式异常的流量字符串，解析抛异常会导致 UI 崩溃。

**修复**：
- 秒数截断改为只在发送时用局部变量截断，`_pendingSeconds` 正常累加，成功后才扣除
- `_handleTokenExpired()` 调用前加 `if (mounted)` 保护
- `_displayTrafficRemaining` 整体加 try-catch 兜底，异常时直接返回原始字符串
