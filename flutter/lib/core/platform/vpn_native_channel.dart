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

  // 流量追踪：记录上次心跳时的累计字节数，用于计算增量
  static int _lastReportedBytes = 0;
  // 当前累计流量（upload + download），由 onStatusChanged 实时更新
  static int _currentTotalBytes = 0;
  
  // 额外防御缓存：直接在 Dart 层累加速度（因为速度本质上就是这1秒内的字节增量）
  // 防止底层 Java 层的 totalUpload/totalDownload 累加器损坏
  static int _accumulatedFromSpeeds = 0;

  /// 获取当前还未被消费（提交到挂起队列）的实时流量增量（字节）
  /// 用于前端 UI 进行秒级的乐观更新
  static int get unconsumedBytes {
    final delta = _currentTotalBytes - _lastReportedBytes;
    return delta > 0 ? delta : 0;
  }

  /// 获取并重置自上次调用以来的流量增量（字节）
  /// 每次心跳调用一次，返回本周期内的新增流量
  static int consumeTrafficDelta() {
    final delta = _currentTotalBytes - _lastReportedBytes;
    _lastReportedBytes = _currentTotalBytes;
    return delta > 0 ? delta : 0;
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        // 直接在 Dart 层累加每秒的真实上下行速度（速度即等于过去1秒的精确字节数）
        // 这样可以完全无视 flutter_v2ray Java 层的 cumulative_bytes bug
        if (status.uploadSpeed > 0 || status.downloadSpeed > 0) {
          _accumulatedFromSpeeds += status.uploadSpeed + status.downloadSpeed;
        }
        
        // 实时更新累计流量：取底层累加器和 Dart 累加器之间的最大值，做到双重保险
        final nativeTotal = status.upload + status.download;
        _currentTotalBytes = _accumulatedFromSpeeds > nativeTotal 
            ? _accumulatedFromSpeeds 
            : nativeTotal;

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
          // 断开时重置流量基准，下次连接重新计算
          _lastReportedBytes = 0;
          _currentTotalBytes = 0;
          _accumulatedFromSpeeds = 0;
          _statusController.add('disconnected');
        } else if (s == 'connecting' || s.contains('connecting')) {
          _statusController.add('connecting');
        } else if (s == 'connected' || s.contains('connect') || s == 'running') {
          // 只有明确 connected 或 running 才发 connected，避免误判
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
