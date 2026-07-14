import 'package:flutter/material.dart';
import 'dart:io';

import 'app.dart';
import 'core/platform/windows_vpn_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    // 清理失败不能阻止应用启动，连接时会再次校验代理状态。
    try {
      await WindowsVpnController.forceCleanup();
    } catch (error) {
      debugPrint('[STARTUP] Windows proxy cleanup failed: $error');
    }
  }

  runApp(const YuexiaVpnApp());
}
