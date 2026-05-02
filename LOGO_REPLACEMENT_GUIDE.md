# Flutter Logo 替换指南

## ✅ 已完成的替换

### 📱 Android APK 图标
所有 Android 应用图标已替换为新的 logo.png：

| 分辨率 | 路径 | 尺寸 | 状态 |
|--------|------|------|------|
| MDPI | `flutter/android/app/src/main/res/mipmap-mdpi/ic_launcher.png` | 48x48 | ✅ |
| HDPI | `flutter/android/app/src/main/res/mipmap-hdpi/ic_launcher.png` | 72x72 | ✅ |
| XHDPI | `flutter/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` | 96x96 | ✅ |
| XXHDPI | `flutter/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` | 144x144 | ✅ |
| XXXHDPI | `flutter/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` | 192x192 | ✅ |

### 🪟 Windows EXE 图标
Windows 应用图标已替换：

| 类型 | 路径 | 包含尺寸 | 状态 |
|------|------|----------|------|
| ICO | `flutter/windows/runner/resources/app_icon.ico` | 16x16, 32x32, 48x48, 64x64, 128x128, 256x256 | ✅ |

## 🔨 如何应用新图标

### Android APK
```bash
cd flutter
flutter clean
flutter build apk --release
```

生成的 APK 位置：`flutter/build/app/outputs/flutter-apk/app-release.apk`

### Windows EXE
```bash
cd flutter
flutter clean
flutter build windows --release
```

生成的 EXE 位置：`flutter/build/windows/x64/runner/Release/cy_vpn.exe`

## 🔄 如何再次替换 Logo

如果需要更换新的 logo，只需：

1. 将新的 logo 图片替换根目录的 `logo.png`
2. 运行替换脚本：
   ```bash
   python replace_logo.py
   ```
3. 重新构建应用（参考上面的构建命令）

## 📋 技术说明

### 源文件要求
- **格式**：PNG（推荐）或其他常见图片格式
- **尺寸**：建议 1024x1024 或更大（正方形）
- **透明度**：支持透明背景（RGBA）

### 自动生成的尺寸
脚本会自动将源图片缩放到以下尺寸：

**Android：**
- 48x48 (MDPI)
- 72x72 (HDPI)
- 96x96 (XHDPI)
- 144x144 (XXHDPI)
- 192x192 (XXXHDPI)

**Windows：**
- 16x16, 32x32, 48x48, 64x64, 128x128, 256x256（打包在单个 .ico 文件中）

## 🎨 设计建议

1. **简洁明了**：图标应该在小尺寸下也清晰可辨
2. **正方形**：确保 logo 是正方形，避免变形
3. **透明背景**：使用透明背景可以更好地适配不同主题
4. **高分辨率**：源文件至少 1024x1024，确保缩放后清晰

## 📝 注意事项

- ✅ 图标已自动生成所有必需的分辨率
- ✅ 支持透明背景
- ✅ 使用高质量的 Lanczos 重采样算法
- ⚠️ 修改图标后需要重新构建应用才能生效
- ⚠️ 已安装的应用需要卸载重装才能看到新图标

## 🛠️ 脚本依赖

替换脚本需要 Python 3 和 Pillow 库：

```bash
pip install Pillow
```

## 📞 问题排查

### 图标没有更新？
1. 确认已运行 `flutter clean`
2. 确认已重新构建应用
3. Android：卸载旧应用后重新安装
4. Windows：删除旧的 build 目录

### 图标模糊？
1. 检查源文件分辨率是否足够高（建议 ≥1024x1024）
2. 确保源文件是高质量的图片

### 脚本运行失败？
1. 确认已安装 Pillow：`pip install Pillow`
2. 确认 logo.png 文件存在于根目录
3. 检查文件权限

---

**最后更新时间**：2026-05-02  
**脚本版本**：1.0  
**状态**：✅ 所有图标已成功替换
