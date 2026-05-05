import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

import '../../pages/vpn_home/models/vpn_node.dart';
import 'windows_vpn_controller.dart';

class VpnNativeChannel {
  const VpnNativeChannel();

  static final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  static FlutterV2ray? _v2ray;
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        final s = status.state.toLowerCase().trim();
        print('[V2RAY] status changed: "${status.state}" → normalized: "$s"');
        // 明确匹配各种断开状态
        if (s == 'stopped' ||
            s == 'disconnected' ||
            s.contains('disconnect') ||
            s.contains('stop') ||
            s == 'none' ||
            s == 'idle' ||
            s == 'error' ||
            s.contains('fail')) {
          _statusController.add('disconnected');
        } else if (s == 'connecting' || s.contains('connecting')) {
          _statusController.add('connecting');
        } else if (s == 'connected' || s.contains('connect')) {
          // 只有明确 connected 才发 connected，避免误判
          _statusController.add('connected');
        } else {
          // 未知状态也视为断开，更安全
          print('[V2RAY] unknown status treated as disconnected: "${status.state}"');
          _statusController.add('disconnected');
        }
      },
    );
    await _v2ray!.initializeV2Ray();
    _initialized = true;
  }

  Future<String?> prepareVpn() async {
    if (kIsWeb) return null;
    if (!Platform.isAndroid) return null;
    await _ensureInitialized();
    final granted = await _v2ray!.requestPermission();
    if (!granted) return 'VPN 权限被拒绝';
    return null;
  }

  Future<String?> startVpn(VpnNode node) async {
    if (kIsWeb) {
      _statusController.add('connected');
      return null;
    }
    if (!Platform.isAndroid) {
      _statusController.add('connecting');
      WindowsVpnController.onProcessExit = () {
        _statusController.add('disconnected');
      };
      try {
        final config =
            FlutterV2ray.parseFromURL(node.rawUri.trim()).getFullConfiguration();
        final success = await WindowsVpnController.start(node, configJson: config);
        if (!success) {
          _statusController.add('disconnected');
          return '启动失败';
        }
        _statusController.add('connected');
        return null;
      } catch (e) {
        _statusController.add('disconnected');
        return '连接失败: $e';
      }
    }

    await _ensureInitialized();
    try {
      final rawUri = node.rawUri.trim();
      print(
        '[V2RAY] startVpn rawUri: ${rawUri.substring(0, rawUri.length.clamp(0, 80))}',
      );
      final parser = FlutterV2ray.parseFromURL(rawUri);
      _statusController.add('connecting');
      await _v2ray!.startV2Ray(
        remark: node.name,
        config: parser.getFullConfiguration(),
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );
      print('[V2RAY] startV2Ray called');
      return null;
    } catch (e) {
      print('[V2RAY] startVpn error: $e');
      _statusController.add('disconnected');
      return '连接失败: $e';
    }
  }

  Future<String?> stopVpn() async {
    if (kIsWeb) {
      _statusController.add('disconnected');
      return null;
    }
    if (!Platform.isAndroid) {
      await WindowsVpnController.stop();
      _statusController.add('disconnected');
      return null;
    }
    await _ensureInitialized();
    // 先发 disconnected，防止 stopV2Ray 触发的回调覆盖状态
    _statusController.add('disconnected');
    try {
      await _v2ray!.stopV2Ray();
      print('[V2RAY] stopV2Ray called');
    } catch (e) {
      print('[V2RAY] stopV2Ray error: $e');
    }
    return null;
  }

  Future<void> openSupportH5() async {
    if (kIsWeb || !Platform.isAndroid) return;
    const channel = MethodChannel('cy_vpn/native');
    return channel.invokeMethod<void>('openSupportH5');
  }

  Stream<String> get statusStream => _statusController.stream;
}
