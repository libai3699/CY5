import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/platform/windows_vpn_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 网页端不支持 dart:io 的 Platform，需先排除网页再判断桌面系统。
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    // 清理失败不能阻止应用启动，连接时会再次校验代理状态。
    try {
      await WindowsVpnController.forceCleanup();
    } catch (error) {
      debugPrint('[STARTUP] Windows proxy cleanup failed: $error');
    }
  }

  runApp(const YuexiaVpnApp());
}
