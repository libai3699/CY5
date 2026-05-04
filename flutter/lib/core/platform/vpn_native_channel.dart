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
        final s = status.state.toLowerCase();
        print('[V2RAY] status changed: ${status.state}');
        if (s.contains('connect') && !s.contains('disconnect')) {
          _statusController.add('connected');
        } else if (s.contains('disconnect') || s.contains('stop')) {
          _statusController.add('disconnected');
        } else if (s.contains('connecting')) {
          _statusController.add('connecting');
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
      final success = await WindowsVpnController.start(node);
      if (!success) {
        _statusController.add('disconnected');
        return '启动失败';
      }
      _statusController.add('connected');
      return null;
    }

    await _ensureInitialized();
    try {
      final rawUri = node.rawUri.trim();
      print('[V2RAY] startVpn rawUri: ${rawUri.substring(0, rawUri.length.clamp(0, 80))}');
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
    try {
      await _v2ray!.stopV2Ray();
      print('[V2RAY] stopV2Ray called');
    } catch (e) {
      print('[V2RAY] stopV2Ray error: $e');
    }
    // 手动触发断开状态，防止回调不触发
    _statusController.add('disconnected');
    return null;
  }

  Future<void> openSupportH5() async {
    if (kIsWeb || !Platform.isAndroid) return;
    const channel = MethodChannel('cy_vpn/native');
    return channel.invokeMethod<void>('openSupportH5');
  }

  Stream<String> get statusStream => _statusController.stream;
}
