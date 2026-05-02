#!/usr/bin/env python3
"""
Flutter Logo 替换脚本
自动将根目录的 logo.png 替换到 Android 和 Windows 的所有图标位置
"""

from PIL import Image
import os

# 定义路径
ROOT_LOGO = "logo.png"
FLUTTER_DIR = "flutter"

# Android 图标尺寸配置
ANDROID_ICONS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Windows 图标尺寸
WINDOWS_ICON_SIZES = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]

def generate_android_icons(source_logo):
    """生成 Android 各分辨率的图标"""
    print("🤖 开始生成 Android 图标...")
    
    # 打开源图片
    img = Image.open(source_logo)
    
    # 确保是 RGBA 模式
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    for folder, size in ANDROID_ICONS.items():
        output_dir = os.path.join(FLUTTER_DIR, "android", "app", "src", "main", "res", folder)
        output_path = os.path.join(output_dir, "ic_launcher.png")
        
        # 创建目录（如果不存在）
        os.makedirs(output_dir, exist_ok=True)
        
        # 调整大小并保存
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(output_path, "PNG")
        print(f"  ✅ {folder}/ic_launcher.png ({size}x{size})")

def generate_windows_icon(source_logo):
    """生成 Windows .ico 图标"""
    print("\n🪟 开始生成 Windows 图标...")
    
    # 打开源图片
    img = Image.open(source_logo)
    
    # 确保是 RGBA 模式
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # 生成多个尺寸的图标
    icon_images = []
    for size in WINDOWS_ICON_SIZES:
        resized = img.resize(size, Image.Resampling.LANCZOS)
        icon_images.append(resized)
    
    # 保存为 .ico 文件
    output_path = os.path.join(FLUTTER_DIR, "windows", "runner", "resources", "app_icon.ico")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # 保存多尺寸 ICO
    icon_images[0].save(
        output_path,
        format='ICO',
        sizes=[img.size for img in icon_images]
    )
    print(f"  ✅ app_icon.ico (包含 {len(WINDOWS_ICON_SIZES)} 个尺寸)")

def main():
    print("=" * 60)
    print("🎨 Flutter Logo 替换工具")
    print("=" * 60)
    
    # 检查源文件是否存在
    if not os.path.exists(ROOT_LOGO):
        print(f"❌ 错误：找不到源文件 {ROOT_LOGO}")
        return
    
    print(f"\n📁 源文件：{ROOT_LOGO}")
    
    # 显示源图片信息
    with Image.open(ROOT_LOGO) as img:
        print(f"📐 尺寸：{img.size[0]}x{img.size[1]}")
        print(f"🎨 模式：{img.mode}")
    
    print("\n" + "=" * 60)
    
    # 生成 Android 图标
    generate_android_icons(ROOT_LOGO)
    
    # 生成 Windows 图标
    generate_windows_icon(ROOT_LOGO)
    
    print("\n" + "=" * 60)
    print("✨ 所有图标替换完成！")
    print("=" * 60)
    print("\n📝 替换位置：")
    print("  • Android APK: flutter/android/app/src/main/res/mipmap-*/ic_launcher.png")
    print("  • Windows EXE: flutter/windows/runner/resources/app_icon.ico")
    print("\n💡 提示：")
    print("  • 重新构建应用以应用新图标")
    print("  • Android: flutter build apk")
    print("  • Windows: flutter build windows")

if __name__ == "__main__":
    main()
