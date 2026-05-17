import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 平台适配工具类
class PlatformUtils {
  /// 是否为移动平台（Android/iOS）
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 是否为桌面平台（Windows/macOS/Linux）
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// 是否为 Windows
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// 是否为 Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// 获取适配后的抽屉宽度
  /// 移动端：屏幕宽度的 75%
  /// 桌面端：固定 320px
  static double getDrawerWidth(double screenWidth) {
    if (isDesktop) {
      return 320.0;
    }
    return screenWidth * 0.75;
  }

  /// 获取适配后的对话框宽度
  /// 移动端：屏幕宽度的 90%（最大 400）
  /// 桌面端：固定 450px
  static double getDialogWidth(double screenWidth) {
    if (isDesktop) {
      return 450.0;
    }
    return (screenWidth * 0.9).clamp(0, 400);
  }

  /// 获取适配后的内容最大宽度
  /// 移动端：无限制
  /// 桌面端：600px
  static double? getContentMaxWidth() {
    if (isDesktop) {
      return 600.0;
    }
    return null;
  }

  /// 获取适配后的页面内边距
  /// 移动端：水平 28，垂直 16
  /// 桌面端：水平 48，垂直 32
  static EdgeInsets getPagePadding() {
    if (isDesktop) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 32);
    }
    return const EdgeInsets.symmetric(horizontal: 28, vertical: 16);
  }
}
