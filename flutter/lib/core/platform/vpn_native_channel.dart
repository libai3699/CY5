import 'dart:async';
import 'dart:convert';
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

  static int _lastReportedBytes = 0;
  static int _currentTotalBytes = 0;
  static int? _nativeTrafficBaselineBytes;
  static int _lastNativeTotal = 0;
  static bool _useAndroidTrafficStats = false;
  static Timer? _androidTrafficStatsTimer;

  static const int _maxLocalTrafficDeltaBytes = 200 * 1024 * 1024;
  static Timer? _androidHealthTimer;
  static DateTime? _lastAndroidStatusAt;
  static int _androidHealthFailCount = 0;

  static int _vpnSessionId = 0;
  static int _activeVpnSessionId = 0;

  static int get unconsumedBytes {
    final delta = _currentTotalBytes - _lastReportedBytes;
    if (delta <= 0) return 0;
    if (delta > _maxLocalTrafficDeltaBytes) return 0;
    return delta;
  }

  static int consumeTrafficDelta() {
    final delta = _currentTotalBytes - _lastReportedBytes;
    _lastReportedBytes = _currentTotalBytes;
    if (delta <= 0) return 0;
    if (delta > _maxLocalTrafficDeltaBytes) {
      return 0;
    }
    return delta;
  }

  static Future<void> resetTrafficBaseline() async {
    _lastReportedBytes = 0;
    _currentTotalBytes = 0;
    _nativeTrafficBaselineBytes = await _readNativeTrafficBytes();

    if (Platform.isAndroid && _useAndroidTrafficStats) {
      try {
        const channel = MethodChannel('9.9/native');
        await channel.invokeMethod<void>('resetTrafficBaseline');
      } catch (_) {}
    }
  }

  static Future<int> pollTrafficDelta() async {
    final nativeBytes = await _readNativeTrafficBytes();

    if (nativeBytes > 0) {
      _nativeTrafficBaselineBytes ??= nativeBytes;
      final nativeTotal = nativeBytes - _nativeTrafficBaselineBytes!;
      final normalizedTotal = nativeTotal > 0 ? nativeTotal : 0;

      if (normalizedTotal > _currentTotalBytes) {
        _currentTotalBytes = normalizedTotal;
      }
    }
    return consumeTrafficDelta();
  }

  static Future<int> _readNativeTrafficBytes() async {
    if (kIsWeb) return _currentTotalBytes;
    if (Platform.isWindows) return WindowsVpnController.totalTrafficBytes;

    if (Platform.isAndroid && _useAndroidTrafficStats) {
      try {
        const channel = MethodChannel('9.9/native');
        final bytes = await channel.invokeMethod<int>('getTrafficBytes');
        return bytes ?? 0;
      } catch (_) {
        return 0;
      }
    }

    return _lastNativeTotal;
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        final s = status.state.toLowerCase().trim();
        if (Platform.isAndroid && _activeVpnSessionId == 0) {
          const staleActive = {
            'connected',
            'running',
            'connecting',
            'reconnecting',
          };
          if (staleActive.contains(s)) {
            return;
          }
        }

        final nativeTotal = status.upload + status.download;
        _lastNativeTotal = nativeTotal;

        if (nativeTotal >= 0 && !_useAndroidTrafficStats) {
          if (_nativeTrafficBaselineBytes == null) {
            _nativeTrafficBaselineBytes = nativeTotal;
            _currentTotalBytes = 0;
          } else {
            final normalizedTotal = nativeTotal - _nativeTrafficBaselineBytes!;
            if (normalizedTotal > _currentTotalBytes) {
              _currentTotalBytes = normalizedTotal;
            }
          }
        }

        if (Platform.isAndroid) {
          _lastAndroidStatusAt = DateTime.now();
        }

        if (s == 'stopped' ||
            s == 'disconnected' ||
            s == 'none' ||
            s == 'idle' ||
            s == 'error' ||
            s == 'failed') {
          _resetTrafficCounters();
          _stopAndroidHealthCheck();
          _stopAndroidTrafficStats();
          if (_activeVpnSessionId > 0) {
            _activeVpnSessionId = 0;
            _statusController.add('disconnected');
          }
        } else if (s == 'connecting' || s == 'reconnecting') {
          if (_activeVpnSessionId > 0) {
            _statusController.add('connecting');
          }
        } else if (s == 'connected' || s == 'running') {
          if (_activeVpnSessionId > 0) {
            _statusController.add('connected');
          }
        } else if (s.contains('connect') && !s.contains('disconnect')) {
          if (_activeVpnSessionId > 0) {
            _statusController.add('connecting');
          }
        } else if (s.contains('stop') ||
            s.contains('disconnect') ||
            s.contains('fail')) {
          _resetTrafficCounters();
          _stopAndroidHealthCheck();
          _stopAndroidTrafficStats();
          if (_activeVpnSessionId > 0) {
            _activeVpnSessionId = 0;
            _statusController.add('disconnected');
          }
        }
      },
    );
    await _v2ray!.initializeV2Ray();
    _initialized = true;
  }

  static Timer? _trafficStatsCheckTimer;

  static Future<void> _stopAndroidTrafficStats() async {
    if (!Platform.isAndroid) return;

    _androidTrafficStatsTimer?.cancel();
    _androidTrafficStatsTimer = null;
    _trafficStatsCheckTimer?.cancel();
    _trafficStatsCheckTimer = null;

    if (_useAndroidTrafficStats) {
      try {
        const channel = MethodChannel('9.9/native');
        await channel.invokeMethod<void>('stopTrafficTracking');
      } catch (_) {}
      _useAndroidTrafficStats = false;
    }
  }

  static void _resetTrafficCounters() {
    _lastReportedBytes = 0;
    _currentTotalBytes = 0;
    _nativeTrafficBaselineBytes = null;
    _lastNativeTotal = 0;
    _useAndroidTrafficStats = false;
    _trafficStatsCheckTimer?.cancel();
    _trafficStatsCheckTimer = null;
  }

  static Future<void> _ensureVpnStopped() async {
    final hadActiveSession = _activeVpnSessionId > 0;
    _activeVpnSessionId = 0;
    _stopAndroidHealthCheck();
    _stopAndroidTrafficStats();
    _resetTrafficCounters();
    if (!hadActiveSession) {
      return;
    }
    if (!_initialized || _v2ray == null) return;
    try {
      await _v2ray!.stopV2Ray();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<String?> prepareVpn() async {
    if (kIsWeb) return null;
    if (!Platform.isAndroid) return null;
    const channel = MethodChannel('9.9/native');
    final notificationError =
        await channel.invokeMethod<String>('ensureNotificationPermission');
    if (notificationError != null && notificationError.isNotEmpty) {
      return notificationError;
    }
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
        final originalConfig = FlutterV2ray.parseFromURL(node.rawUri.trim())
            .getFullConfiguration();
        final config = _injectDnsAndSniffing(originalConfig);
        final success =
            await WindowsVpnController.start(node, configJson: config);
        if (!success) {
          _statusController.add('disconnected');
          return WindowsVpnController.consumeLastErrorMessage() ?? '启动失败';
        }
        _statusController.add('connected');
        _startWindowsTrafficSync();
        return null;
      } catch (e) {
        _statusController.add('disconnected');
        return '连接失败: $e';
      }
    }

    await _ensureInitialized();
    try {
      final rawUri = node.rawUri.trim();
      if (rawUri.isEmpty) {
        return '线路配置无效：缺少连接地址';
      }
      await _ensureVpnStopped();
      _activeVpnSessionId = ++_vpnSessionId;
      _resetTrafficCounters();
      final parser = FlutterV2ray.parseFromURL(rawUri);
      final originalConfig = parser.getFullConfiguration();
      final optimizedConfig = _injectDnsAndSniffing(originalConfig);
      _statusController.add('connecting');
      await _v2ray!.startV2Ray(
        remark: node.name,
        config: optimizedConfig,
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );
      _startAndroidHealthCheck();
      return null;
    } catch (e) {
      _activeVpnSessionId = 0;
      _stopAndroidHealthCheck();
      _resetTrafficCounters();
      _statusController.add('disconnected');

      final errorMsg = e.toString();
      if (errorMsg.contains('process is bad')) {
        return '系统服务异常，请重启APP后重试';
      }

      return '连接失败: $e';
    }
  }

  Future<String?> stopVpn() async {
    if (kIsWeb) {
      _statusController.add('disconnected');
      return null;
    }
    if (!Platform.isAndroid) {
      _stopWindowsTrafficSync();
      await WindowsVpnController.stop();
      _statusController.add('disconnected');
      return null;
    }
    await _ensureInitialized();
    _activeVpnSessionId = 0;
    _stopAndroidHealthCheck();
    _stopAndroidTrafficStats();
    _resetTrafficCounters();
    try {
      await _v2ray!.stopV2Ray();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _statusController.add('disconnected');
    return null;
  }

  Future<void> openSupportH5() async {
    if (kIsWeb || !Platform.isAndroid) return;
    const channel = MethodChannel('9.9/native');
    return channel.invokeMethod<void>('openSupportH5');
  }

  Stream<String> get statusStream => _statusController.stream;

  static Timer? _windowsTrafficSyncTimer;

  static void _startWindowsTrafficSync() {
    _windowsTrafficSyncTimer?.cancel();
    _windowsTrafficSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final total = WindowsVpnController.totalTrafficBytes;
      final baseline = _nativeTrafficBaselineBytes;
      final normalizedTotal = baseline == null ? total : total - baseline;
      if (normalizedTotal > _currentTotalBytes) {
        _currentTotalBytes = normalizedTotal;
      }
    });
  }

  static void _stopWindowsTrafficSync() {
    _windowsTrafficSyncTimer?.cancel();
    _windowsTrafficSyncTimer = null;
    _lastReportedBytes = 0;
    _currentTotalBytes = 0;
    _nativeTrafficBaselineBytes = null;
    _lastNativeTotal = 0;
    _useAndroidTrafficStats = false;
  }

  static void _startAndroidHealthCheck() {
    _androidHealthTimer?.cancel();
    _androidHealthFailCount = 0;
    _lastAndroidStatusAt = DateTime.now();
    _androidHealthTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _checkAndroidHealth();
    });
  }

  static void _stopAndroidHealthCheck() {
    _androidHealthTimer?.cancel();
    _androidHealthTimer = null;
    _androidHealthFailCount = 0;
    _lastAndroidStatusAt = null;
  }

  static Future<void> _checkAndroidHealth() async {
    if (!Platform.isAndroid || _v2ray == null) return;

    final lastStatusAt = _lastAndroidStatusAt;
    final statusStale = lastStatusAt == null ||
        DateTime.now().difference(lastStatusAt) > const Duration(seconds: 14);

    if (!statusStale) {
      _androidHealthFailCount = 0;
      return;
    }

    try {
      final delay = await _v2ray!
          .getConnectedServerDelay(url: 'https://www.gstatic.com/generate_204')
          .timeout(const Duration(seconds: 5), onTimeout: () => -1);
      if (delay >= 0) {
        _androidHealthFailCount = 0;
        _lastAndroidStatusAt = DateTime.now();
        return;
      }
      _androidHealthFailCount++;
    } catch (_) {
      _androidHealthFailCount++;
    }
  }

  static String _injectDnsAndSniffing(String configJson) {
    try {
      final config = jsonDecode(configJson) as Map<String, dynamic>;

      // DNS：localhost 优先（V2Ray 内部直连解析）；8.8.8.8/1.1.1.1 用对象形式，
      // 原生 Android 层会跳过它们（非字符串），不向系统 TUN 注入外部 DNS。
      config['dns'] = {
        'servers': [
          'localhost',
          {
            'address': '8.8.8.8',
            'port': 53,
          },
          {
            'address': '1.1.1.1',
            'port': 53,
          },
        ],
        'queryStrategy': 'UseIPv4',
      };

      // 域名嗅探：让 V2Ray 从 TLS/HTTP 中识别真实域名，按域名路由。
      final inbounds = config['inbounds'];
      if (inbounds is List) {
        for (final inbound in inbounds) {
          if (inbound is Map<String, dynamic>) {
            inbound['sniffing'] = {
              'enabled': true,
              'destOverride': ['http', 'tls'],
              'routeOnly': false,
            };
          }
        }
      }

      // 不使用 geoip:private（依赖 geoip.dat，本项目未打包该文件，会导致
      // 核心加载路由失败、TUN 无法建立）。改用显式私网 CIDR 走直连，
      // 其余全部走 proxy，确保公网流量经隧道出海、IP 改变。
      final proxyRules = <Map<String, dynamic>>[
        {
          'type': 'field',
          'ip': [
            '127.0.0.0/8',
            '10.0.0.0/8',
            '172.16.0.0/12',
            '192.168.0.0/16',
            '169.254.0.0/16',
            '224.0.0.0/4',
          ],
          'outboundTag': 'direct',
        },
        {
          'type': 'field',
          'network': 'tcp,udp',
          'outboundTag': 'proxy',
        },
      ];

      if (config['routing'] == null) {
        config['routing'] = {
          'domainStrategy': 'AsIs',
          'rules': proxyRules,
        };
      } else if (config['routing'] is Map<String, dynamic>) {
        final routing = config['routing'] as Map<String, dynamic>;
        routing['domainStrategy'] = 'AsIs';
        final existing = routing['rules'];
        if (existing is! List || existing.isEmpty) {
          routing['rules'] = proxyRules;
        }
      }

      return jsonEncode(config);
    } catch (_) {
      return configJson;
    }
  }
}
