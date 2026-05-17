import 'package:flutter/material.dart';
import 'dart:io';

import 'app.dart';
import 'core/platform/windows_vpn_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows) {
    // 启动时强制清理上次可能的代理残留
    await WindowsVpnController.forceCleanup();
  }

  runApp(const YuexiaVpnApp());
}
